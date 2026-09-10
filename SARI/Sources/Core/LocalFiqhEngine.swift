import Foundation
import SwiftLlama

enum LocalFiqhEngineError: LocalizedError, Sendable {
    case busy
    case questionTooLong
    case promptTooLarge
    case runtimeValidationFailed

    var errorDescription: String? {
        switch self {
        case .busy:
            return "The local assistant is already processing a request."
        case .questionTooLong:
            return "The question is too long for the safe local context window."
        case .promptTooLarge:
            return "The retrieved evidence exceeded the safe local context budget."
        case .runtimeValidationFailed:
            return "The local model did not pass the runtime validation check."
        }
    }
}

actor LocalFiqhEngine {
    static let shared = LocalFiqhEngine()

    /// SwiftLlama 0.1.0 currently prepares the prompt in one prefill batch. The crash
    /// report from the affected iPhone ended in LlamaContext.addTokenToBatch(). Keep
    /// the complete user prompt below a conservative UTF-8 byte ceiling. A tokenizer
    /// token cannot represent less than one input byte, so this is intentionally safer
    /// than estimating tokens from character count and leaves room for ChatML markers.
    private static let maxPromptUTF8Bytes = 1_800
    private static let maxQuestionUTF8Bytes = 700
    private static let maxEvidenceSources = 3
    private static let minimumEvidenceUTF8Bytes = 320
    private static let outputTokenLimit = 640
    private static let contextSize = 3_072

    private var llama: LlamaActor?
    private var loadedPath: String?
    private var inferenceInProgress = false

    struct Result {
        let level: String
        let answer: String
        /// Source metadata remains internal for verification/persistence. The UI only
        /// renders the supporting text and never exposes book/page/source identifiers.
        let sources: [LocalFiqhSource]
        let reason: String
        let confidence: Int
    }

    private struct ModelEnvelope: Decodable {
        let level: String?
        let answer: String?
        let basis: String?
    }

    func ask(question: String, language: SariLanguage) async throws -> Result {
        guard !inferenceInProgress else { throw LocalFiqhEngineError.busy }
        inferenceInProgress = true
        defer { inferenceInProgress = false }

        let cleanQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuestion.isEmpty else { throw LocalFiqhEngineError.questionTooLong }
        guard cleanQuestion.utf8.count <= Self.maxQuestionUTF8Bytes else {
            throw LocalFiqhEngineError.questionTooLong
        }

        let state = await MainActor.run {
            let pack = LocalFiqhPack.shared
            return (
                installed: pack.installed,
                ready: pack.readyForInference,
                modelURL: pack.modelURL,
                dbURL: pack.libraryURL
            )
        }

        guard state.installed else { throw URLError(.fileDoesNotExist) }
        guard state.ready else { throw URLError(.cannotLoadFromNetwork) }

        let model = try loadModel(at: state.modelURL)
        let retrievalQuestion = try await makeArabicRetrievalQuery(
            question: cleanQuestion,
            language: language,
            model: model
        )

        // The corpus is Arabic. Arabic questions are searched as-is; other languages
        // get a short Arabic retrieval query first so the final evidence stays relevant.
        let searchText = language == .ar ? cleanQuestion : retrievalQuestion
        let candidates = try LocalFiqhSearch(dbURL: state.dbURL)
            .search(searchText, language: .ar, limit: 5)

        guard !candidates.isEmpty else {
            return .init(
                level: "insufficient",
                answer: insufficient(language),
                sources: [],
                reason: insufficientReason(language),
                confidence: 0
            )
        }

        let prepared = try buildPrompt(
            question: cleanQuestion,
            language: language,
            candidates: candidates
        )

        await SariDiagnostics.shared.log(
            "fiqh.ask promptBytes=\(prepared.prompt.utf8.count) evidenceSources=\(prepared.sources.count) context=\(Self.contextSize) outputLimit=\(Self.outputTokenLimit)"
        )

        let output = try await generate(prompt: prepared.prompt, model: model)
        let parsed = parseEnvelope(output)

        var level: String
        var rawAnswer: String
        var reason: String

        if let parsed {
            level = normalizedLevel(parsed.level)
            rawAnswer = cleanModelText(parsed.answer ?? "")
            reason = cleanModelText(parsed.basis ?? "")
            if rawAnswer.isEmpty {
                level = "insufficient"
                rawAnswer = insufficient(language)
            }
            if reason.isEmpty { reason = modelReason(language) }
        } else {
            // Malformed model output is not promoted to a ruling. This is safer than
            // showing free-form text that bypassed the source-marker contract.
            level = "insufficient"
            rawAnswer = insufficient(language)
            reason = malformedOutputReason(language)
        }

        var visibleSources: [LocalFiqhSource] = []
        if level != "insufficient" {
            let citationIndexes = validCitationIndexes(
                in: rawAnswer,
                sourceCount: prepared.sources.count
            )
            guard !citationIndexes.isEmpty else {
                level = "insufficient"
                rawAnswer = insufficient(language)
                reason = citationValidationReason(language)
                return .init(
                    level: level,
                    answer: rawAnswer,
                    sources: [],
                    reason: reason,
                    confidence: 30
                )
            }
            visibleSources = citationIndexes.map { prepared.sources[$0] }
        } else {
            rawAnswer = insufficient(language)
        }

        // Validate markers internally first, then remove every [S#] marker from what
        // the user sees. Source identity/page data never needs to appear in the answer.
        let visibleAnswer = stripSourceMarkers(rawAnswer)
        let visibleReason = stripSourceMarkers(reason)

        let confidence: Int
        switch level {
        case "explicit": confidence = min(96, 76 + visibleSources.count * 5)
        case "inference": confidence = min(90, 66 + visibleSources.count * 5)
        default: confidence = min(45, 22 + prepared.sources.count * 3)
        }

        return .init(
            level: level,
            answer: visibleAnswer,
            sources: visibleSources,
            reason: visibleReason,
            confidence: confidence
        )
    }

    /// A very small inference performed after installation/update. The model is not
    /// marked ready until model loading + tokenization + generation all succeed.
    func validateRuntime(modelURL: URL) async throws {
        guard !inferenceInProgress else { throw LocalFiqhEngineError.busy }
        inferenceInProgress = true
        defer {
            inferenceInProgress = false
            // Do not keep ~2 GB of model mappings alive merely because installation
            // completed. The first real question loads it again on demand.
            llama = nil
            loadedPath = nil
        }

        let model = try loadModel(at: modelURL)
        let prompt = "/no_think\nReply with exactly: OK"
        guard prompt.utf8.count < Self.maxPromptUTF8Bytes else {
            throw LocalFiqhEngineError.promptTooLarge
        }
        let output = try await generate(prompt: prompt, model: model)
        let normalized = cleanModelText(output).uppercased()
        guard normalized.contains("OK") else {
            throw LocalFiqhEngineError.runtimeValidationFailed
        }
    }

    func releaseModelIfIdle() {
        guard !inferenceInProgress else { return }
        llama = nil
        loadedPath = nil
    }

    private func loadModel(at url: URL) throws -> LlamaActor {
        if let llama, loadedPath == url.path { return llama }

        let threads = max(2, min(6, ProcessInfo.processInfo.activeProcessorCount / 2))
        let config: ModelConfig

        #if targetEnvironment(simulator)
        config = .init(
            contextSize: Self.contextSize,
            gpuLayers: .none,
            threads: threads
        )
        #else
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        if physicalMemory >= 7_500_000_000 {
            config = .init(
                contextSize: Self.contextSize,
                gpuLayers: .all,
                threads: threads
            )
        } else if physicalMemory >= 5_500_000_000 {
            config = .init(
                contextSize: Self.contextSize,
                gpuLayers: .count(20),
                threads: threads
            )
        } else {
            config = .init(
                contextSize: Self.contextSize,
                gpuLayers: .count(8),
                threads: threads
            )
        }
        #endif

        let model = try LlamaModel(path: url.path, config: config)
        let params = SamplingParams(
            temperature: 0.1,
            topP: 0.9,
            topK: 40,
            maxTokens: Self.outputTokenLimit
        )
        let actor = try LlamaActor(model: model, params: params)
        llama = actor
        loadedPath = url.path
        return actor
    }

    private func buildPrompt(
        question: String,
        language: SariLanguage,
        candidates: [LocalFiqhSource]
    ) throws -> (prompt: String, sources: [LocalFiqhSource]) {
        let header = """
/no_think
SARI: answer ONLY from EVIDENCE. Never add outside fiqh knowledge. Preserve conditions and negation. If support is insufficient, level=insufficient. Answer in \(language.displayName). A supported answer MUST cite [S#]. JSON only, no markdown or hidden reasoning:
{\"level\":\"explicit|inference|insufficient\",\"answer\":\"answer with [S#]\",\"basis\":\"short basis\"}
EVIDENCE:
"""
        let footer = "\nQUESTION:\n\(question)"
        let fixedBytes = header.utf8.count + footer.utf8.count
        let available = Self.maxPromptUTF8Bytes - fixedBytes
        guard available >= Self.minimumEvidenceUTF8Bytes else {
            throw LocalFiqhEngineError.questionTooLong
        }

        let chosen = Array(candidates.prefix(Self.maxEvidenceSources))
        var blocks: [String] = []
        var usedSources: [LocalFiqhSource] = []
        var remaining = available

        for (offset, source) in chosen.enumerated() {
            let remainingCount = max(1, chosen.count - offset)
            let marker = "[S\(usedSources.count + 1)]\n"
            let separatorBytes = blocks.isEmpty ? 0 : 2
            let usable = max(0, remaining / remainingCount - marker.utf8.count - separatorBytes)
            guard usable >= 90 else { break }

            let excerpt = focusedExcerpt(
                source.text,
                question: question,
                maxUTF8Bytes: min(usable, 720)
            )
            guard !excerpt.isEmpty else { continue }

            let block = marker + excerpt
            let cost = block.utf8.count + separatorBytes
            guard cost <= remaining else { continue }
            blocks.append(block)
            usedSources.append(
                LocalFiqhSource(
                    id: source.id,
                    part: source.part,
                    page: source.page,
                    text: excerpt,
                    pdfFile: source.pdfFile
                )
            )
            remaining -= cost
        }

        guard !usedSources.isEmpty else { throw LocalFiqhEngineError.promptTooLarge }
        let prompt = header + blocks.joined(separator: "\n\n") + footer
        guard prompt.utf8.count <= Self.maxPromptUTF8Bytes else {
            throw LocalFiqhEngineError.promptTooLarge
        }
        return (prompt, usedSources)
    }

    private func focusedExcerpt(
        _ text: String,
        question: String,
        maxUTF8Bytes: Int
    ) -> String {
        guard maxUTF8Bytes > 0 else { return "" }
        let terms = question
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 3 }
            .sorted { $0.count > $1.count }

        var candidate = text
        for term in terms.prefix(8) {
            if let range = text.range(
                of: term,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) {
                let radius = max(90, min(260, maxUTF8Bytes / 3))
                let lower = text.index(range.lowerBound, offsetBy: -radius, limitedBy: text.startIndex) ?? text.startIndex
                let upper = text.index(range.upperBound, offsetBy: radius, limitedBy: text.endIndex) ?? text.endIndex
                candidate = String(text[lower..<upper])
                break
            }
        }

        return prefixUTF8(candidate, maxBytes: maxUTF8Bytes)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func prefixUTF8(_ text: String, maxBytes: Int) -> String {
        guard text.utf8.count > maxBytes else { return text }
        var result = ""
        var bytes = 0
        for character in text {
            let piece = String(character)
            let next = piece.utf8.count
            if bytes + next > maxBytes { break }
            result.append(character)
            bytes += next
        }
        return result
    }

    /// The source database is Arabic. For non-Arabic UI languages the local model
    /// creates a compact Arabic retrieval query before the source search.
    private func makeArabicRetrievalQuery(
        question: String,
        language: SariLanguage,
        model: LlamaActor
    ) async throws -> String {
        guard language != .ar else { return question }

        let prompt = """
/no_think
Convert this fiqh question to 4-8 concise Arabic search terms. Do not answer or add a ruling. Arabic terms only.
Language: \(language.displayName)
Question: \(question)
"""
        guard prompt.utf8.count <= Self.maxPromptUTF8Bytes else {
            throw LocalFiqhEngineError.questionTooLong
        }

        let output = try await generate(prompt: prompt, model: model)
        let cleaned = cleanModelText(output).replacingOccurrences(of: "\n", with: " ")
        return prefixUTF8(cleaned, maxBytes: 320)
    }

    private func generate(prompt: String, model: LlamaActor) async throws -> String {
        guard prompt.utf8.count <= Self.maxPromptUTF8Bytes else {
            throw LocalFiqhEngineError.promptTooLarge
        }
        var output = ""
        for try await chunk in await model.chat(messages: [.user(prompt)], template: .chatML) {
            try Task.checkCancellation()
            if case .text(let token) = chunk { output += token }
        }
        return output
    }

    private func parseEnvelope(_ output: String) -> ModelEnvelope? {
        let cleaned = cleanModelText(output)
        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}") else { return nil }
        let json = String(cleaned[start...end])
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ModelEnvelope.self, from: data)
    }

    private func normalizedLevel(_ raw: String?) -> String {
        switch raw?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "explicit": return "explicit"
        case "inference": return "inference"
        default: return "insufficient"
        }
    }

    private func cleanModelText(_ text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.replacingOccurrences(
            of: "(?s)<think>.*?</think>",
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(of: "```json", with: "")
        value = value.replacingOccurrences(of: "```", with: "")
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func validCitationIndexes(in text: String, sourceCount: Int) -> [Int] {
        guard sourceCount > 0,
              let regex = try? NSRegularExpression(pattern: #"\[S(\d+)\]"#) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        guard !matches.isEmpty else { return [] }

        var seen = Set<Int>()
        var indexes: [Int] = []
        for match in matches {
            guard match.numberOfRanges > 1,
                  let numberRange = Range(match.range(at: 1), in: text),
                  let number = Int(text[numberRange]),
                  (1...sourceCount).contains(number) else {
                return []
            }
            let index = number - 1
            if seen.insert(index).inserted { indexes.append(index) }
        }
        return indexes
    }

    private func stripSourceMarkers(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"\s*\[S\d+\]"#,
            with: "",
            options: .regularExpression
        )
        .replacingOccurrences(of: "  ", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func citationValidationReason(_ l: SariLanguage) -> String {
        SariContentText.pick(l, [
            .ar: "لم أتمكن من ربط الخلاصة بالنصوص المسترجعة بشكل آمن، لذلك لم أعرضها كحكم موثوق.",
            .en: "The conclusion could not be safely tied to the retrieved text, so it was not presented as a reliable ruling.",
            .tr: "Sonuç getirilen metinle güvenli biçimde ilişkilendirilemediği için güvenilir hüküm olarak sunulmadı.",
            .ms: "Kesimpulan tidak dapat dipautkan dengan selamat kepada teks yang ditemui, jadi ia tidak dipaparkan sebagai hukum yang boleh dipercayai.",
            .id: "Kesimpulan tidak dapat ditautkan dengan aman ke teks yang ditemukan, sehingga tidak ditampilkan sebagai hukum yang dapat dipercaya.",
            .ja: "結論を取得した本文に安全に結び付けられなかったため、信頼できる判断として表示しませんでした。",
            .zh: "结论无法安全对应到检索到的文本，因此未作为可靠判断展示。",
            .ru: "Вывод не удалось надёжно связать с найденным текстом, поэтому он не показан как достоверное постановление.",
            .fr: "La conclusion n’a pas pu être reliée de façon sûre au texte retrouvé ; elle n’est donc pas présentée comme un jugement fiable."
        ])
    }

    private func malformedOutputReason(_ l: SariLanguage) -> String {
        SariContentText.pick(l, [
            .ar: "لم يكتمل تنسيق الإجابة المحلية بصورة يمكن التحقق منها، لذلك تم إيقاف عرض الحكم احتياطًا.",
            .en: "The local answer format could not be verified, so the ruling was withheld as a precaution."
        ])
    }

    private func modelReason(_ l: SariLanguage) -> String {
        SariContentText.pick(l, [
            .ar: "صيغت الخلاصة محليًا من النصوص المسترجعة على الجهاز.",
            .en: "The conclusion was generated locally from text retrieved on the device.",
            .tr: "Sonuç cihazda getirilen metinlerden yerel olarak oluşturuldu.",
            .ms: "Kesimpulan dibentuk secara tempatan daripada teks yang ditemui pada peranti.",
            .id: "Kesimpulan dibuat secara lokal dari teks yang ditemukan di perangkat.",
            .ja: "端末内で取得した本文を基に、結論をローカルで生成しました。",
            .zh: "结论由设备内检索到的文本在本地生成。",
            .ru: "Вывод сформирован локально на основе текста, найденного на устройстве.",
            .fr: "La conclusion a été formulée localement à partir du texte retrouvé sur l’appareil."
        ])
    }

    private func insufficientReason(_ l: SariLanguage) -> String {
        SariContentText.pick(l, [
            .ar: "لم تُسترجع نصوص كافية لبناء حكم موثوق.",
            .en: "The local text did not provide enough evidence for a reliable ruling.",
            .tr: "Yerel metin güvenilir bir hüküm için yeterli delil sağlamadı.",
            .ms: "Teks tempatan tidak memberikan bukti yang mencukupi untuk hukum yang boleh dipercayai.",
            .id: "Teks lokal tidak memberikan bukti yang cukup untuk kesimpulan hukum yang andal.",
            .ja: "信頼できる判断に十分な根拠をローカル本文から取得できませんでした。",
            .zh: "本地文本未提供足够依据来形成可靠判断。",
            .ru: "Локальный текст не дал достаточно оснований для надёжного постановления.",
            .fr: "Le texte local n’a pas fourni suffisamment d’éléments pour un jugement fiable."
        ])
    }

    private func insufficient(_ l: SariLanguage) -> String {
        switch l {
        case .ar: return "لم أجد في النصوص المحلية ما يكفي للإجابة بثقة."
        case .en: return "I could not find enough support in the local text to answer confidently."
        case .tr: return "Yerel metinde güvenle cevap vermek için yeterli dayanak bulamadım."
        case .ms: return "Saya tidak menemui sokongan yang mencukupi dalam teks tempatan untuk menjawab dengan yakin."
        case .id: return "Saya tidak menemukan dukungan yang cukup dalam teks lokal untuk menjawab dengan yakin."
        case .ja: return "ローカル本文には、確信をもって回答するための十分な根拠が見つかりませんでした。"
        case .zh: return "本地文本中没有找到足够依据来有把握地回答。"
        case .ru: return "В локальном тексте недостаточно оснований для уверенного ответа."
        case .fr: return "Je n’ai pas trouvé suffisamment d’éléments dans le texte local pour répondre avec confiance."
        }
    }
}
