import Foundation

struct SariPlace: Identifiable, Hashable, Codable {
    let id:String; let name:String; let category:String
    let latitude:Double; let longitude:Double
    let address:String?; let tags:[String:String]
    var isExplicitlyHalal:Bool {
        let text=([name,category]+tags.flatMap{[$0.key,$0.value]}).joined(separator:" ").lowercased()
        return text.contains("halal") || text.contains("حلال")
    }
}

enum SariPlaceKind:String,CaseIterable,Identifiable {
    case food,mosque,pharmacy,hospital,grocery,transport
    var id:String{rawValue}
    var titleArabic:String {
        switch self { case .food:return "المطاعم"; case .mosque:return "المساجد"; case .pharmacy:return "الصيدليات"; case .hospital:return "المستشفيات"; case .grocery:return "البقالات"; case .transport:return "النقل" }
    }
    var systemImage:String {
        switch self { case .food:return "fork.knife"; case .mosque:return "building.columns.fill"; case .pharmacy:return "cross.case.fill"; case .hospital:return "heart.text.square.fill"; case .grocery:return "cart.fill"; case .transport:return "tram.fill" }
    }
}

@MainActor final class PlacesStore:ObservableObject {
    @Published var places:[SariPlace]=[]
    @Published var isLoading=false
    @Published var message:String?=nil
    func load(kind:SariPlaceKind,destination:TravelDestination) async {
        isLoading=true; defer{isLoading=false}
        places=[]
        message="افتح البحث على الخريطة للحصول على نتائج حية حول وجهتك."
    }
}

enum MapLauncher {
    static func appleMapsURL(query:String,destination:TravelDestination)->URL? {
        var c=URLComponents(string:"https://maps.apple.com/")
        c?.queryItems=[URLQueryItem(name:"q",value:query),URLQueryItem(name:"near",value:"\(destination.latitude),\(destination.longitude)")]
        return c?.url
    }
    static func googleMapsURL(query:String,destination:TravelDestination)->URL? {
        var c=URLComponents(string:"https://www.google.com/maps/search/")
        c?.queryItems=[URLQueryItem(name:"api",value:"1"),URLQueryItem(name:"query",value:"\(query) \(destination.capitalArabic)")]
        return c?.url
    }
}
