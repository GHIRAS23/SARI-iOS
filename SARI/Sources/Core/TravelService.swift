import Foundation
import SwiftUI

struct SariNationality: Identifiable, Hashable {
    let code: String
    let nameArabic: String
    let flag: String
    var id: String { code }
}

struct TravelAppRecommendation: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let noteArabic: String
    let systemImage: String
}

struct TravelDestination: Identifiable, Hashable {
    let code: String
    let nameArabic: String
    let flag: String
    let capitalArabic: String
    let currency: String
    let languagesArabic: String
    let timeZoneNoteArabic: String
    let plugsArabic: String
    let latitude: Double
    let longitude: Double
    let muslimMajority: Bool
    let emergencyGeneral: String?
    let emergencyNoteArabic: String
    let apps: [TravelAppRecommendation]
    var id: String { code }
}

struct MissionContact: Identifiable, Hashable {
    let id: String
    let titleArabic: String
    let phone: String?
    let emergencyPhone: String?
    let addressArabic: String?
    let officialSource: String?
    let verifiedAt: Date?
}

struct TripChecklistItem: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
}

enum TravelCatalog {
    static let nationalities: [SariNationality] = [
        .init(code: "SA", nameArabic: "السعودية", flag: "🇸🇦"),
        .init(code: "QA", nameArabic: "قطر", flag: "🇶🇦"),
        .init(code: "BH", nameArabic: "البحرين", flag: "🇧🇭"),
        .init(code: "KW", nameArabic: "الكويت", flag: "🇰🇼"),
        .init(code: "AE", nameArabic: "الإمارات", flag: "🇦🇪"),
        .init(code: "OM", nameArabic: "عُمان", flag: "🇴🇲")
    ]

    static let destinations: [TravelDestination] = [
        .init(code: "PL", nameArabic: "بولندا", flag: "🇵🇱", capitalArabic: "وارسو", currency: "الزلوتي البولندي (PLN)", languagesArabic: "البولندية", timeZoneNoteArabic: "أوروبا الوسطى", plugsArabic: "C / E • 230V", latitude: 52.2297, longitude: 21.0122, muslimMajority: false, emergencyGeneral: "112", emergencyNoteArabic: "رقم الطوارئ الأوروبي الموحد.", apps: [
            .init(id:"pl1", name:"Jakdojade", category:"النقل", noteArabic:"مفيد للنقل العام والمسارات داخل المدن البولندية.", systemImage:"tram.fill"),
            .init(id:"pl2", name:"KOLEO", category:"القطارات", noteArabic:"البحث عن رحلات القطارات المحلية وتذاكرها.", systemImage:"train.side.front.car"),
            .init(id:"pl3", name:"Bolt / Uber", category:"التنقل", noteArabic:"خيارات شائعة لطلب السيارات في المدن الكبرى.", systemImage:"car.fill")
        ]),
        .init(code: "JP", nameArabic: "اليابان", flag: "🇯🇵", capitalArabic: "طوكيو", currency: "الين الياباني (JPY)", languagesArabic: "اليابانية", timeZoneNoteArabic: "JST", plugsArabic: "A / B • 100V", latitude: 35.6762, longitude: 139.6503, muslimMajority: false, emergencyGeneral: nil, emergencyNoteArabic: "للشرطة 110، وللإسعاف والإطفاء 119. تحقق دائمًا من الإرشادات الرسمية عند الحاجة.", apps: [
            .init(id:"jp1", name:"Japan Travel by NAVITIME", category:"النقل", noteArabic:"تخطيط القطارات والمترو والتنقل بين المدن.", systemImage:"train.side.front.car"),
            .init(id:"jp2", name:"GO", category:"سيارات الأجرة", noteArabic:"من تطبيقات طلب سيارات الأجرة المحلية.", systemImage:"car.fill"),
            .init(id:"jp3", name:"Google Maps", category:"الخرائط", noteArabic:"مفيد للتنقل والبحث عن الأماكن ومواعيد النقل.", systemImage:"map.fill")
        ]),
        .init(code: "IT", nameArabic: "إيطاليا", flag: "🇮🇹", capitalArabic: "روما", currency: "اليورو (EUR)", languagesArabic: "الإيطالية", timeZoneNoteArabic: "أوروبا الوسطى", plugsArabic: "C / F / L • 230V", latitude: 41.9028, longitude: 12.4964, muslimMajority: false, emergencyGeneral: "112", emergencyNoteArabic: "رقم الطوارئ الأوروبي الموحد.", apps: [
            .init(id:"it1", name:"Trenitalia", category:"القطارات", noteArabic:"القطارات الوطنية والحجوزات.", systemImage:"train.side.front.car"),
            .init(id:"it2", name:"Italo", category:"القطارات", noteArabic:"قطارات سريعة بين مدن إيطالية عديدة.", systemImage:"train.side.front.car"),
            .init(id:"it3", name:"Moovit", category:"النقل", noteArabic:"مسارات النقل العام في مدن متعددة.", systemImage:"bus.fill")
        ]),
        .init(code: "AT", nameArabic: "النمسا", flag: "🇦🇹", capitalArabic: "فيينا", currency: "اليورو (EUR)", languagesArabic: "الألمانية", timeZoneNoteArabic: "أوروبا الوسطى", plugsArabic: "C / F • 230V", latitude: 48.2082, longitude: 16.3738, muslimMajority: false, emergencyGeneral: "112", emergencyNoteArabic: "رقم الطوارئ الأوروبي الموحد.", apps: [
            .init(id:"at1", name:"ÖBB", category:"القطارات", noteArabic:"القطارات والنقل بين المدن.", systemImage:"train.side.front.car"),
            .init(id:"at2", name:"WienMobil", category:"النقل", noteArabic:"مفيد للتنقل داخل فيينا.", systemImage:"tram.fill")
        ]),
        .init(code: "DE", nameArabic: "ألمانيا", flag: "🇩🇪", capitalArabic: "برلين", currency: "اليورو (EUR)", languagesArabic: "الألمانية", timeZoneNoteArabic: "أوروبا الوسطى", plugsArabic: "C / F • 230V", latitude: 52.5200, longitude: 13.4050, muslimMajority: false, emergencyGeneral: "112", emergencyNoteArabic: "112 للطوارئ الطبية والإطفاء؛ أرقام الجهات قد تختلف حسب نوع الحالة.", apps: [
            .init(id:"de1", name:"DB Navigator", category:"القطارات", noteArabic:"القطارات والنقل العام في ألمانيا.", systemImage:"train.side.front.car"),
            .init(id:"de2", name:"BVG", category:"النقل", noteArabic:"مفيد للنقل العام في برلين.", systemImage:"tram.fill")
        ]),
        .init(code: "FR", nameArabic: "فرنسا", flag: "🇫🇷", capitalArabic: "باريس", currency: "اليورو (EUR)", languagesArabic: "الفرنسية", timeZoneNoteArabic: "أوروبا الوسطى", plugsArabic: "C / E • 230V", latitude: 48.8566, longitude: 2.3522, muslimMajority: false, emergencyGeneral: "112", emergencyNoteArabic: "رقم الطوارئ الأوروبي الموحد.", apps: [
            .init(id:"fr1", name:"Bonjour RATP", category:"النقل", noteArabic:"النقل العام في باريس وما حولها.", systemImage:"tram.fill"),
            .init(id:"fr2", name:"SNCF Connect", category:"القطارات", noteArabic:"القطارات والحجوزات داخل فرنسا.", systemImage:"train.side.front.car")
        ]),
        .init(code: "TR", nameArabic: "تركيا", flag: "🇹🇷", capitalArabic: "أنقرة", currency: "الليرة التركية (TRY)", languagesArabic: "التركية", timeZoneNoteArabic: "TRT", plugsArabic: "C / F • 230V", latitude: 39.9334, longitude: 32.8597, muslimMajority: true, emergencyGeneral: "112", emergencyNoteArabic: "رقم الطوارئ الموحد.", apps: [
            .init(id:"tr1", name:"BiTaksi", category:"التنقل", noteArabic:"طلب سيارات الأجرة في عدد من المدن.", systemImage:"car.fill"),
            .init(id:"tr2", name:"Moovit", category:"النقل", noteArabic:"مسارات النقل العام.", systemImage:"bus.fill")
        ]),
        .init(code: "MY", nameArabic: "ماليزيا", flag: "🇲🇾", capitalArabic: "كوالالمبور", currency: "الرينغيت (MYR)", languagesArabic: "الماليزية ولغات أخرى", timeZoneNoteArabic: "MYT", plugsArabic: "G • 240V", latitude: 3.1390, longitude: 101.6869, muslimMajority: true, emergencyGeneral: "999", emergencyNoteArabic: "رقم طوارئ عام؛ تحقق من تعليمات السلطات المحلية عند الحاجة.", apps: [
            .init(id:"my1", name:"Grab", category:"التنقل", noteArabic:"سيارات وتوصيل وخدمات محلية.", systemImage:"car.fill"),
            .init(id:"my2", name:"MyRapid PULSE", category:"النقل", noteArabic:"مفيد للنقل العام في كوالالمبور.", systemImage:"tram.fill")
        ])
    ]

    // Mission contacts are intentionally not guessed. Production data must be synchronized from an official/curated directory.
    static func mission(for nationalityCode: String, in destinationCode: String) -> MissionContact? { nil }

    static func checklist(nationality: SariNationality?, destination: TravelDestination, tripDate: Date?) -> [TripChecklistItem] {
        var items: [TripChecklistItem] = [
            .init(id:"entry", title:"متطلبات الدخول", detail:"تحقق من التأشيرة وصلاحية الجواز ومتطلبات الدخول من مصدر رسمي قبل السفر.", systemImage:"person.text.rectangle"),
            .init(id:"apps", title:"نزّل التطبيقات المهمة", detail:"راجع تطبيقات النقل والخرائط والخدمات المقترحة للوجهة.", systemImage:"square.and.arrow.down.fill"),
            .init(id:"weather", title:"راجع الطقس ولباس الرحلة", detail:"افتح طقس الوجهة قبل المغادرة وحدث البيانات عند اقتراب موعد السفر.", systemImage:"cloud.sun.fill"),
            .init(id:"mission", title:"احفظ بيانات بعثتك", detail:nationality == nil ? "اختر جنسيتك مرة واحدة ليعرض ساري بعثتك المناسبة." : "سيعرض ساري بيانات بعثة دولتك عند توفر بيانات موثقة للوجهة.", systemImage:"building.columns.fill")
        ]
        if let tripDate { items.insert(.init(id:"date", title:"موعد الرحلة", detail:tripDate.formatted(date: .long, time: .omitted), systemImage:"calendar"), at:0) }
        return items
    }
}

@MainActor final class TravelProfileStore: ObservableObject {
    @Published var nationalityCode: String { didSet { UserDefaults.standard.set(nationalityCode, forKey:"sari.travel.nationality") } }
    @Published var destinationCode: String { didSet { UserDefaults.standard.set(destinationCode, forKey:"sari.travel.destination") } }
    @Published var tripDate: Date? { didSet { UserDefaults.standard.set(tripDate, forKey:"sari.travel.tripDate") } }

    init() {
        nationalityCode = UserDefaults.standard.string(forKey:"sari.travel.nationality") ?? ""
        destinationCode = UserDefaults.standard.string(forKey:"sari.travel.destination") ?? "PL"
        tripDate = UserDefaults.standard.object(forKey:"sari.travel.tripDate") as? Date
    }

    var nationality: SariNationality? { TravelCatalog.nationalities.first { $0.code == nationalityCode } }
    var destination: TravelDestination { TravelCatalog.destinations.first { $0.code == destinationCode } ?? TravelCatalog.destinations[0] }
}
