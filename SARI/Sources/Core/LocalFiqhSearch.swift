import Foundation
import SQLite3

struct LocalFiqhSource: Identifiable {
    let id: Int
    let part: Int
    let page: Int
    let text: String
    let pdfFile: String

    var label: String {
        "السلسبيل — الجزء \(part)، الصفحة \(page)"
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

    func search(_ question: String, limit: Int = 4) throws -> [LocalFiqhSource] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            throw LocalFiqhSearchError.openFailed
        }
        defer { sqlite3_close(db) }

        let terms = Self.terms(question)
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

    private static func terms(_ question: String) -> [String] {
        let normalized = question.lowercased()
            .replacingOccurrences(of: "أ", with: "ا")
            .replacingOccurrences(of: "إ", with: "ا")
            .replacingOccurrences(of: "آ", with: "ا")
            .replacingOccurrences(of: "ة", with: "ه")
        let stop: Set<String> = [
            "من", "في", "على", "الى", "إلى", "هل", "ما", "هو", "هي", "عن", "ثم", "بعد", "قبل",
            "the", "a", "an", "is", "are", "to", "of", "in", "and", "or"
        ]
        return normalized
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 3 && !stop.contains($0) }
            .prefix(8)
            .map { $0 }
    }
}
