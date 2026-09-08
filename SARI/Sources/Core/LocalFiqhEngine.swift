import Foundation
import SwiftLlama

actor LocalFiqhEngine {
    static let shared = LocalFiqhEngine()

    private var llama: LlamaActor?
    private var loadedPath: String?

    struct Result {
        let level: String
        let answer: String
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

        let modelURL = state.modelURL
        let dbURL = state.dbURL

        let model = try loadModel(at: modelURL)
        let retrievalQuestion = try await makeArabicRetrievalQuery(
            question: question,
            language: language,
            model: model
        )

        // The indexed fiqh corpus is Arabic. For non-Arabic questions, retrieval uses only
        // the model-generated Arabic query so Latin/CJK tokens cannot dilute SQLite scoring.
        let searchText = language == .ar ? question : retrievalQuestion
        let sources = try LocalFiqhSearch(dbURL: dbURL)
            .search(searchText, language: .ar, limit: 5)

        guard !sources.isEmpty else {
            return .init(
                level: "insufficient",
                answer: insufficient(language),
                sources: [],
                reason: insufficientReason(language),
                confidence: 0
            )
        }

        let evidence = sources.enumerated().map { index, source in
            let text = String(source.text.prefix(1_250))
            return "[S\(index + 1)] Al-Salsabil, part \(source.part), page \(source.page)\n\(text)"
        }.joined(separator: "\n\n")

        let prompt = """
/no_think
You are SARI, an offline source-bound fiqh assistant.

STRICT RULES:
1. Use ONLY the Arabic evidence supplied below. Never use outside fiqh knowledge.
2. Never invent a ruling, condition, exception, scholar, quotation, page, or source.
3. Preserve negation and conditions exactly. If evidence does not support a confident answer, use level "insufficient".
4. Distinguish an explicit ruling from an inference:
   - "explicit": the evidence states the ruling directly.
   - "inference": the conclusion is a careful synthesis of the supplied passages.
5. Answer in this language: \(language.displayName).
6. Keep source markers such as [S1] and [S2] in the answer where they support the conclusion.
7. Do not output chain-of-thought, hidden reasoning, <think> tags, markdown fences, or text outside the JSON.
8. The "basis" field is only a short user-facing explanation of how the cited passages support the answer, not private reasoning.

Return valid JSON exactly in this shape:
{"level":"explicit|inference|insufficient","answer":"concise ruling and explanation in the requested language with [S#] citations","basis":"short source-based explanation in the requested language"}

EVIDENCE:
\(evidence)

QUESTION:
\(question)
"""

        let output = try await generate(prompt: prompt, model: model)
        let parsed = parseEnvelope(output)

        var level: String
        var answer: String
        var reason: String

        if let parsed {
            let normalized = normalizedLevel(parsed.level)
            level = normalized
            answer = cleanModelText(parsed.answer ?? "").isEmpty
                ? insufficient(language)
                : cleanModelText(parsed.answer ?? "")
            reason = cleanModelText(parsed.basis ?? "").isEmpty
                ? modelReason(language)
                : cleanModelText(parsed.basis ?? "")
        } else {
            let cleaned = cleanModelText(output)
            level = cleaned.isEmpty ? "insufficient" : "inference"
            answer = cleaned.isEmpty ? insufficient(language) : cleaned
            reason = modelReason(language)
        }

        // Source markers are part of the safety contract. A ruling that cites no supplied
        // passage (or cites an out-of-range marker) is downgraded instead of being presented
        // as a source-grounded conclusion.
        if level != "insufficient" && !hasValidSourceCitations(answer, sourceCount: sources.count) {
            level = "insufficient"
            answer = insufficient(language)
            reason = citationValidationReason(language)
        } else if level == "insufficient" {
            answer = insufficient(language)
        }

        let confidence: Int
        switch level {
        case "explicit": confidence = min(96, 72 + sources.count * 4)
        case "inference": confidence = min(90, 62 + sources.count * 4)
        default: confidence = min(45, 20 + sources.count * 4)
        }

        return .init(
            level: level,
            answer: answer,
            sources: sources,
            reason: reason,
            confidence: confidence
        )
    }

    private func loadModel(at url: URL) throws -> LlamaActor {
        if let llama, loadedPath == url.path { return llama }

        let model = try LlamaModel(
            path: url.path,
            config: .init(
                contextSize: 4096,
                gpuLayers: .all,
                threads: max(2, ProcessInfo.processInfo.activeProcessorCount / 2)
            )
        )
        let actor = try LlamaActor(model: model, params: .greedy)
        llama = actor
        loadedPath = url.path
        return actor
    }

    /// The source database is Arabic. For every non-Arabic UI language the same local model
    /// first creates a tiny Arabic search query, then the final answer is generated in the user's language.
    private func makeArabicRetrievalQuery(
        question: String,
        language: SariLanguage,
        model: LlamaActor
    ) async throws -> String {
        guard language != .ar else { return question }

        let prompt = """
/no_think
Convert the user's fiqh question into 4 to 8 concise Arabic search keywords or short phrases for searching an Arabic fiqh book.
Do not answer the question. Do not add a ruling. Output Arabic search terms only, separated by spaces.
User language: \(language.displayName)
Question: \(question)
"""

        let output = try await generate(prompt: prompt, model: model)
        let cleaned = cleanModelText(output)
            .replacingOccurrences(of: "\n", with: " ")
        return String(cleaned.prefix(320))
    }

    private func generate(prompt: String, model: LlamaActor) async throws -> String {
        var output = ""
        for try await chunk in await model.chat(messages: [.user(prompt)], template: .chatML) {
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


    private func hasValidSourceCitations(_ text: String, sourceCount: Int) -> Bool {
        guard sourceCount > 0,
              let regex = try? NSRegularExpression(pattern: #"\[S(\d+)\]"#) else {
            return false
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        guard !matches.isEmpty else { return false }

        for match in matches {
            guard match.numberOfRanges > 1,
                  let numberRange = Range(match.range(at: 1), in: text),
                  let number = Int(text[numberRange]),
                  (1...sourceCount).contains(number) else {
                return false
            }
        }
        return true
    }

    private func citationValidationReason(_ l: SariLanguage) -> String {
        SariContentText.pick(l, [
            .ar: "لم أتمكن من ربط الخلاصة بإحالة صحيحة إلى المقاطع المسترجعة، لذلك لم أعرضها كحكم موثوق.",
            .en: "The conclusion could not be tied to a valid retrieved-source citation, so it was not presented as a reliable ruling.",
            .tr: "Sonuç, getirilen kaynaklarda geçerli bir atfa bağlanamadığı için güvenilir hüküm olarak sunulmadı.",
            .ms: "Kesimpulan tidak dapat dipautkan kepada rujukan sumber yang sah, jadi ia tidak dipaparkan sebagai hukum yang boleh dipercayai.",
            .id: "Kesimpulan tidak dapat ditautkan ke rujukan sumber yang valid, sehingga tidak ditampilkan sebagai hukum yang dapat dipercaya.",
            .ja: "結論を取得済み資料の有効な引用に結び付けられなかったため、信頼できる判断として表示しませんでした。",
            .zh: "结论无法对应到有效的检索来源引用，因此未将其作为可靠判断展示。",
            .ru: "Вывод не удалось связать с корректной ссылкой на найденный источник, поэтому он не показан как надёжное постановление.",
            .fr: "La conclusion n’a pas pu être reliée à une citation valide des passages retrouvés ; elle n’est donc pas présentée comme un jugement fiable."
        ])
    }

    private func modelReason(_ l: SariLanguage) -> String {
        SariContentText.pick(l, [
            .ar: "صيغت الخلاصة محليًا من المقاطع المسترجعة من المصادر المثبتة على الجهاز.",
            .en: "The conclusion was generated locally from passages retrieved from sources installed on the device.",
            .tr: "Sonuç, cihazdaki kaynaklardan getirilen bölümler kullanılarak yerel olarak oluşturuldu.",
            .ms: "Kesimpulan dibentuk secara tempatan daripada petikan sumber yang disimpan pada peranti.",
            .id: "Kesimpulan dibuat secara lokal dari bagian sumber yang tersimpan di perangkat.",
            .ja: "端末内の資料から取得した箇所を基に、結論をローカルで生成しました。",
            .zh: "结论由设备内已安装来源中检索到的段落在本地生成。",
            .ru: "Вывод сформирован локально на основе фрагментов из источников, установленных на устройстве.",
            .fr: "La conclusion a été formulée localement à partir des passages retrouvés dans les sources installées sur l’appareil."
        ])
    }

    private func insufficientReason(_ l: SariLanguage) -> String {
        SariContentText.pick(l, [
            .ar: "لم تُسترجع مقاطع كافية من المصدر المحلي لبناء حكم موثوق.",
            .en: "The local source did not return enough evidence for a reliable ruling.",
            .tr: "Yerel kaynak güvenilir bir hüküm için yeterli delil döndürmedi.",
            .ms: "Sumber tempatan tidak memberikan bukti yang mencukupi untuk hukum yang boleh dipercayai.",
            .id: "Sumber lokal tidak memberikan bukti yang cukup untuk kesimpulan hukum yang andal.",
            .ja: "信頼できる判断に十分な根拠をローカル資料から取得できませんでした。",
            .zh: "本地资料未检索到足够证据来形成可靠判断。",
            .ru: "Локальный источник не дал достаточно оснований для надёжного постановления.",
            .fr: "La source locale n’a pas fourni suffisamment d’éléments pour un jugement fiable."
        ])
    }

    private func insufficient(_ l: SariLanguage) -> String {
        switch l {
        case .ar: return "لم أجد في المصادر المحلية نصًا كافيًا للإجابة بثقة."
        case .en: return "I could not find enough support in the local sources to answer confidently."
        case .tr: return "Yerel kaynaklarda güvenle cevap vermek için yeterli dayanak bulamadım."
        case .ms: return "Saya tidak menemui sokongan yang mencukupi dalam sumber tempatan untuk menjawab dengan yakin."
        case .id: return "Saya tidak menemukan dukungan yang cukup dalam sumber lokal untuk menjawab dengan yakin."
        case .ja: return "ローカル資料には、確信をもって回答するための十分な根拠が見つかりませんでした。"
        case .zh: return "本地资料中没有找到足够依据来有把握地回答。"
        case .ru: return "В локальных источниках недостаточно оснований для уверенного ответа."
        case .fr: return "Je n’ai pas trouvé suffisamment d’éléments dans les sources locales pour répondre avec confiance."
        }
    }
}
