import Foundation
import SQLite3

struct LocalFiqhSource: Identifiable {
    let id: Int
    let part: Int
    let page: Int
    let text: String
    let pdfFile: String

    func label(_ language: SariLanguage) -> String {
        SariContentText.pick(language, [
            .ar: "السلسبيل — الجزء \(part)، الصفحة \(page)",
            .en: "Al-Salsabil — part \(part), page \(page)",
            .tr: "Es-Selsebil — bölüm \(part), sayfa \(page)",
            .ms: "Al-Salsabil — bahagian \(part), halaman \(page)",
            .id: "Al-Salsabil — bagian \(part), halaman \(page)",
            .ja: "アル・サルサビール — 第\(part)部・\(page)ページ",
            .zh: "《السلسبيل》— 第\(part)册，第\(page)页",
            .ru: "«Ас-Сальсабиль» — часть \(part), стр. \(page)",
            .fr: "Al-Salsabil — partie \(part), page \(page)"
        ])
    }
}

enum LocalFiqhSearchError: Error {
    case openFailed
    case queryFailed
}

final class LocalFiqhSearch {
    private let dbURL: URL

    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(dbURL: URL) {
        self.dbURL = dbURL
    }

    /// Retrieves a wider candidate set from SQLite, then ranks it locally by term density.
    /// This avoids the old id-order tie breaker that could put an index or incidental page
    /// ahead of the actual fiqh discussion even when both contained the same keywords.
    func search(_ question: String, language: SariLanguage = .ar, limit: Int = 4) throws -> [LocalFiqhSource] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            throw LocalFiqhSearchError.openFailed
        }
        defer { sqlite3_close(db) }

        let terms = Self.terms(question, language: language)
        let focusTerms = Self.focusTerms(question)
        guard !terms.isEmpty else { return [] }

        let whereClause = terms.map { _ in "normalized LIKE ?" }.joined(separator: " OR ")
        let sql = """
        SELECT id, part, page, text, pdf_file, normalized
        FROM pages
        WHERE (\(whereClause))
          AND normalized NOT LIKE '%فهرس%'
        LIMIT 260
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw LocalFiqhSearchError.queryFailed
        }
        defer { sqlite3_finalize(statement) }

        var bindIndex: Int32 = 1
        for term in terms {
            sqlite3_bind_text(statement, bindIndex, "%\(term)%", -1, Self.sqliteTransient)
            bindIndex += 1
        }

        struct Candidate {
            let source: LocalFiqhSource
            let normalized: String
            let score: Int
        }

        var candidates: [Candidate] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let textPointer = sqlite3_column_text(statement, 3),
                  let pdfPointer = sqlite3_column_text(statement, 4),
                  let normalizedPointer = sqlite3_column_text(statement, 5) else { continue }

            let normalized = String(cString: normalizedPointer)
            let score = Self.rank(normalized: normalized, terms: terms, focusTerms: focusTerms)
            let source = LocalFiqhSource(
                id: Int(sqlite3_column_int(statement, 0)),
                part: Int(sqlite3_column_int(statement, 1)),
                page: Int(sqlite3_column_int(statement, 2)),
                text: String(cString: textPointer),
                pdfFile: String(cString: pdfPointer)
            )
            candidates.append(.init(source: source, normalized: normalized, score: score))
        }

        return candidates
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                // Prefer later pages only as a final deterministic tie-breaker; the main sort
                // is relevance density rather than database id.
                return $0.source.id < $1.source.id
            }
            .prefix(max(1, limit))
            .map(\.source)
    }

    private static func rank(normalized: String, terms: [String], focusTerms: [String]) -> Int {
        var score = 0
        var matchedImportant = 0

        for term in terms {
            let count = min(6, occurrenceCount(of: term, in: normalized))
            guard count > 0 else { continue }
            let weight = genericTerms.contains(term) ? 1 : (term.count >= 5 ? 4 : 3)
            score += count * weight
            if !genericTerms.contains(term) { matchedImportant += 1 }
        }

        // Pages discussing several distinct focused terms are more useful than pages where
        // one word appears repeatedly in an unrelated passage.
        score += matchedImportant * matchedImportant * 2

        // Strong topic words explicitly present in the user's Arabic retrieval query should
        // dominate incidental mentions. Example: a page about wiping over socks may mention
        // that a sinful traveller cannot "shorten" prayer once, but it should rank below the
        // actual chapter explaining qasr. OCR makes hard filtering risky, so use a large boost
        // instead of rejecting pages that miss the anchor.
        for focus in focusTerms {
            let count = min(8, occurrenceCount(of: focus, in: normalized))
            if count > 0 {
                score += 50 + (count * 10)
            } else {
                score -= 40
            }
        }
        return score
    }

    private static func focusTerms(_ question: String) -> [String] {
        let value = normalizeArabic(question.lowercased())
        let groups: [([String], String)] = [
            (["قصر"], "قصر"),
            (["جمع"], "جمع"),
            (["وضوء", "وضو"], "وضوء"),
            (["تيمم"], "تيمم"),
            (["صيام", "صوم"], "صيام"),
            (["زكاه"], "زكاه"),
            (["حج"], "حج"),
            (["عمره"], "عمره"),
            (["طلاق"], "طلاق"),
            (["نكاح", "زواج"], "نكاح"),
            (["ربا"], "ربا"),
            (["حيض"], "حيض"),
            (["جمعه"], "جمعه")
        ]

        var output: [String] = []
        for (triggers, anchor) in groups where triggers.contains(where: { value.contains($0) }) {
            let normalizedAnchor = normalizeArabic(anchor)
            if !output.contains(normalizedAnchor) { output.append(normalizedAnchor) }
        }
        return output
    }

    private static func occurrenceCount(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        return max(0, haystack.components(separatedBy: needle).count - 1)
    }

    private static func terms(_ question: String, language: SariLanguage) -> [String] {
        let normalized = normalizeArabic(question.lowercased())
        let stop: Set<String> = [
            "من", "في", "على", "الى", "هل", "ما", "هو", "هي", "عن", "ثم", "بعد", "قبل", "هذا", "هذه",
            "the", "a", "an", "is", "are", "to", "of", "in", "and", "or", "for", "with", "what", "can"
        ]

        var output = normalized
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 3 && !stop.contains($0) }

        // Add topic-focused Arabic variants. They improve OCR-tolerant retrieval without
        // adding any ruling or outside fiqh conclusion.
        for (triggers, arabic) in arabicTopicAliases where triggers.contains(where: { normalized.contains($0) }) {
            output.append(contentsOf: arabic.map(normalizeArabic))
        }

        if language != .ar {
            let lower = question.lowercased()
            for (aliases, arabic) in multilingualAliases where aliases.contains(where: { lower.contains($0) }) {
                output.append(contentsOf: arabic.map(normalizeArabic))
            }
        }

        var seen = Set<String>()
        return output.filter { seen.insert($0).inserted }.prefix(16).map { $0 }
    }

    private static let genericTerms: Set<String> = [
        "حكم", "الصلاه", "صلاه", "يجوز", "جواز", "المساله", "مساله", "الدليل", "قول"
    ]

    private static func normalizeArabic(_ value: String) -> String {
        var result = value
            .replacingOccurrences(of: "أ", with: "ا")
            .replacingOccurrences(of: "إ", with: "ا")
            .replacingOccurrences(of: "آ", with: "ا")
            .replacingOccurrences(of: "ة", with: "ه")
            .replacingOccurrences(of: "ى", with: "ي")
            .replacingOccurrences(of: "ـ", with: "")

        // Arabic harakat and Quranic annotation marks should not affect retrieval.
        result = result.unicodeScalars.filter { scalar in
            !(0x064B...0x065F).contains(Int(scalar.value)) &&
            !(0x0670...0x0670).contains(Int(scalar.value)) &&
            !(0x06D6...0x06ED).contains(Int(scalar.value))
        }.map(String.init).joined()
        return result
    }

    private static let arabicTopicAliases: [([String], [String])] = [
        (["قصر"], ["قصر", "يقصر", "القصر", "سفر", "مسافر", "المسافر", "ركعات"]),
        (["جمع"], ["جمع", "يجمع", "الجمع", "سفر", "مسافر"]),
        (["مسافر", "سفر"], ["سفر", "مسافر", "المسافر"]),
        (["وضوء", "طهاره"], ["وضوء", "الوضوء", "طهاره"]),
        (["تيمم"], ["تيمم", "التيمم", "طهاره"]),
        (["صيام", "صوم"], ["صيام", "صوم", "الصيام"]),
        (["زكاه"], ["زكاه", "الزكاه"]),
        (["حج"], ["حج", "الحج"]),
        (["عمره"], ["عمره", "العمره"]),
        (["طلاق"], ["طلاق", "الطلاق"]),
        (["نكاح", "زواج"], ["نكاح", "زواج"]),
        (["ربا"], ["ربا", "الربا"]),
        (["حيض"], ["حيض", "الحيض"]),
        (["جمعه"], ["جمعه", "الجمعه", "صلاه"])
    ]

    private static let multilingualAliases: [([String], [String])] = [
        (["prayer", "salah", "salat", "namaz", "namazı", "solat", "礼拝", "礼拜", "молит", "prière"], ["صلاة"]),
        (["fajr", "subuh", "fecr", "фаджр"], ["فجر", "صلاة"]),
        (["fast", "fasting", "ramadan", "oruç", "puasa", "断食", "斋戒", "пост", "jeûne"], ["صيام", "صوم"]),
        (["wudu", "wudhu", "ablution", "abdest", "وضوء", "小净", "омовен", "ablutions"], ["وضوء", "طهارة"]),
        (["tayammum", "teyemmüm", "tayamum", "土净", "таяммум"], ["تيمم"]),
        (["travel", "traveler", "journey", "sefer", "seyahat", "musafir", "perjalanan", "旅行", "旅行中", "путеше", "voyage"], ["سفر", "مسافر"]),
        (["qasr", "shorten", "kısalt", "jamak", "jama", "combine", "جمع", "قصر", "сокращ", "regrouper"], ["قصر", "جمع", "سفر", "مسافر"]),
        (["zakat", "zekât", "天课", "закят"], ["زكاة"]),
        (["hajj", "hac", "haji", "朝觐", "хадж"], ["حج"]),
        (["umrah", "umre", "副朝", "умра"], ["عمرة"]),
        (["marriage", "nikah", "nikâh", "婚姻", "брак", "mariage"], ["نكاح", "زواج"]),
        (["divorce", "talaq", "talak", "boşan", "离婚", "развод"], ["طلاق"]),
        (["interest", "riba", "faiz", "usury", "利息", "риба", "intérêt"], ["ربا"]),
        (["halal", "haram", "helal", "清真", "халяль"], ["حلال", "حرام"]),
        (["slaughter", "zabiha", "zabihah", "kesim", "sembelih", "屠宰", "забой", "abattage"], ["ذبح"]),
        (["menstru", "haid", "hayız", "月经", "менстру"], ["حيض"]),
        (["friday", "jumu", "cuma", "jumaat", "jumat", "星期五", "пятнич", "vendredi"], ["جمعة", "صلاة"]),
        (["mosque", "masjid", "cami", "清真寺", "мечет", "mosquée"], ["مسجد"])
    ]
}
