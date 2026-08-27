import Foundation

struct AdhkarDataFile: Codable {
    let schema: Int
    let review_status: String
    let categories: [AdhkarDataCategory]
}
struct AdhkarDataCategory: Codable {
    let id: String
    let titles: [String:String]
    let items: [AdhkarDataItem]
}
struct AdhkarSource: Codable {
    let status: String
    let collection: String?
    let reference: String?
    let hisn_reference: String?
    let note_ar: String?
    let evidence_ar: String?
}
struct AdhkarDataItem: Codable {
    let id: String
    let arabic: String
    let transliteration: String
    let target: Int
    let meanings: [String:String]
    let source: AdhkarSource?
}

enum AdhkarRepository {
    static func loadBundled() -> AdhkarDataFile? {
        guard let url=Bundle.main.sariResourceURL(name:"adhkar",extension:"json",subdirectory:"data"),
              let data=try? Data(contentsOf:url) else { return nil }
        return try? JSONDecoder().decode(AdhkarDataFile.self,from:data)
    }
}
