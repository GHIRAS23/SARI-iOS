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

    private static let sqliteTransient = unsafeBitCast(
        -1,
        to: sqlite3_destructor_type.self
    )

    init(dbURL: URL) {
        self.dbURL = dbURL
    }

    func search(_ question: String, language: SariLanguage = .ar, limit: Int = 4) throws -> [LocalFiqhSource] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            throw LocalFiqhSearchError.openFailed
        }
        defer { sqlite3_close(db) }

        let terms = Self.terms(question, language: language)
        guard !terms.isEmpty else { return [] }

        let score = terms.map { _ in
            "(CASE WHEN normalized LIKE ? THEN 1 ELSE 0 END)"
        }.joined(separator: "+")
        let whereClause = terms.map { _ in "normalized LIKE ?" }.joined(separator: " OR ")
        let sql = "SELECT id,part,page,text,pdf_file,(\(score)) AS score FROM pages WHERE \(whereClause) ORDER BY score DESC,id ASC LIMIT ?"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw LocalFiqhSearchError.queryFailed
        }
        defer { sqlite3_finalize(statement) }

        var index: Int32 = 1
        for term in terms {
            sqlite3_bind_text(statement, index, "%\(term)%", -1, Self.sqliteTransient)
            index += 1
        }
        for term in terms {
            sqlite3_bind_text(statement, index, "%\(term)%", -1, Self.sqliteTransient)
            index += 1
        }
        sqlite3_bind_int(statement, index, Int32(limit))

        var result: [LocalFiqhSource] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let textPointer = sqlite3_column_text(statement, 3),
                  let pdfPointer = sqlite3_column_text(statement, 4) else { continue }
            result.append(.init(
                id: Int(sqlite3_column_int(statement, 0)),
                part: Int(sqlite3_column_int(statement, 1)),
                page: Int(sqlite3_column_int(statement, 2)),
                text: String(cString: textPointer),
                pdfFile: String(cString: pdfPointer)
            ))
        }
        return result
    }

    private static func terms(_ question: String, language: SariLanguage) -> [String] {
        let normalized = normalizeArabic(question.lowercased())
        let stop: Set<String> = [
            "من", "في", "على", "الى", "هل", "ما", "هو", "هي", "عن", "ثم", "بعد", "قبل",
            "the", "a", "an", "is", "are", "to", "of", "in", "and", "or", "for", "with"
        ]
        var output = normalized
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 3 && !stop.contains($0) }

        // For non-Arabic UI languages, add conservative Arabic fiqh keywords for common topics.
        // This does not translate rulings; it only helps retrieve relevant Arabic source passages.
        if language != .ar {
            let lower = question.lowercased()
            for (aliases, arabic) in multilingualAliases where aliases.contains(where: { lower.contains($0) }) {
                output.append(contentsOf: arabic.map(normalizeArabic))
            }
        }

        var seen = Set<String>()
        return output.filter { seen.insert($0).inserted }.prefix(10).map { $0 }
    }

    private static func normalizeArabic(_ value: String) -> String {
        value
            .replacingOccurrences(of: "أ", with: "ا")
            .replacingOccurrences(of: "إ", with: "ا")
            .replacingOccurrences(of: "آ", with: "ا")
            .replacingOccurrences(of: "ة", with: "ه")
    }

    private static let multilingualAliases: [([String], [String])] = [
        (["prayer", "salah", "salat", "namaz", "namazı", "solat", "礼拝", "礼拜", "молит", "prière"], ["صلاة"]),
        (["fajr", "subuh", "fecr", "фаджр"], ["فجر", "صلاة"]),
        (["fast", "fasting", "ramadan", "oruç", "puasa", "断食", "斋戒", "пост", "jeûne"], ["صيام", "صوم"]),
        (["wudu", "wudhu", "ablution", "abdest", "وضوء", "小净", "омовен", "ablutions"], ["وضوء", "طهارة"]),
        (["tayammum", "teyemmüm", "tayamum", "土净", "таяммум"], ["تيمم"]),
        (["travel", "traveler", "journey", "sefer", "seyahat", "musafir", "perjalanan", "旅行", "旅行中", "путеше", "voyage"], ["سفر"]),
        (["qasr", "shorten", "kısalt", "jamak", "jama", "combine", "جمع", "قصر", "сокращ", "regrouper"], ["قصر", "جمع", "سفر"]),
        (["zakat", "zekât", "zakat", "天课", "закят"], ["زكاة"]),
        (["hajj", "hac", "haji", "朝觐", "хадж"], ["حج"]),
        (["umrah", "umre", "umrah", "副朝", "умра"], ["عمرة"]),
        (["marriage", "nikah", "nikâh", "nikah", "婚姻", "брак", "mariage"], ["نكاح", "زواج"]),
        (["divorce", "talaq", "talak", "boşan", "离婚", "развод", "divorce"], ["طلاق"]),
        (["interest", "riba", "faiz", "usury", "利息", "риба", "intérêt"], ["ربا"]),
        (["halal", "haram", "helal", "haram", "清真", "حلال", "халяль"], ["حلال", "حرام"]),
        (["slaughter", "zabiha", "zabihah", "kesim", "sembelih", "屠宰", "забой", "abattage"], ["ذبح"]),
        (["menstru", "haid", "hayız", "月经", "менстру", "menstru"], ["حيض"]),
        (["friday", "jumu", "cuma", "jumaat", "jumat", "星期五", "пятнич", "vendredi"], ["جمعة", "صلاة"]),
        (["mosque", "masjid", "cami", "masjid", "清真寺", "мечет", "mosquée"], ["مسجد"])
    ]

}
