import Foundation
import SwiftUI

struct SariNationality: Identifiable, Hashable {
    let code: String
    var id: String { code }
    var flag: String { SariContentText.flag(code) }
    var nameArabic: String { SariContentText.countryName(code, language: .ar) }
    func name(_ language: SariLanguage) -> String { SariContentText.countryName(code, language: language) }
}

struct TravelAppRecommendation: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let noteArabic: String
    let systemImage: String
}

struct EmergencyContact: Identifiable, Hashable {
    let id: String
    let service: String
    let number: String
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
    var hasDetailedData: Bool { latitude != 0 || longitude != 0 }
    func name(_ language: SariLanguage) -> String { SariContentText.countryName(code, language: language) }
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

private struct CountryMetadata: Codable {
    let code: String
    let capital: String
    let currencies: [String]
    let languages: [String]
    let timezones: [String]
    let latitude: Double
    let longitude: Double
}

enum TravelCatalog {
    // Full travel selector. Israel (IL) is intentionally excluded by product requirement; Palestine (PS) remains.
    // Kosovo (XK) is included as a travel destination, yielding 195 selectable entries.
    private static let sovereignCodes: [String] = """
AF AL DZ AD AO AG AR AM AU AT AZ BS BH BD BB BY BE BZ BJ BT BO BA BW BR BN BG BF BI CV KH CM CA CF TD CL CN CO KM CG CD CR CI HR CU CY CZ DK DJ DM DO EC EG SV GQ ER EE SZ ET FJ FI FR GA GM GE DE GH GR GD GT GN GW GY HT HN HU IS IN ID IR IQ IE IT JM JP JO KZ KE KI KP KR KW KG LA LV LB LS LR LY LI LT LU MG MW MY MV ML MT MH MR MU MX FM MD MC MN ME MA MZ MM NA NR NP NL NZ NI NE NG MK NO OM PK PW PA PG PY PE PH PL PT QA RO RU RW KN LC VC WS SM ST SA SN RS SC SL SG SK SI SB SO ZA SS ES LK SD SR SE CH SY TJ TZ TH TL TG TO TT TN TR TM TV UG UA AE GB US UY UZ VU VA VE VN YE ZM ZW PS XK
""".split(whereSeparator: { $0.isWhitespace }).map(String.init)

    static var nationalities: [SariNationality] {
        sovereignCodes
            .map { SariNationality(code: $0) }
            .sorted { $0.name(SariLanguage.selected).localizedStandardCompare($1.name(SariLanguage.selected)) == .orderedAscending }
    }

    private static let detailed: [TravelDestination] = [
        .init(code:"PL",nameArabic:"بولندا",flag:"🇵🇱",capitalArabic:"وارسو",currency:"الزلوتي البولندي (PLN)",languagesArabic:"البولندية",timeZoneNoteArabic:"أوروبا الوسطى",plugsArabic:"C / E • 230V",latitude:52.2297,longitude:21.0122,muslimMajority:false,emergencyGeneral:"112",emergencyNoteArabic:"رقم الطوارئ الأوروبي الموحد.",apps:[
            .init(id:"pl1",name:"Jakdojade",category:"النقل",noteArabic:"مفيد للنقل العام والمسارات داخل المدن البولندية.",systemImage:"tram.fill"),
            .init(id:"pl2",name:"KOLEO",category:"القطارات",noteArabic:"البحث عن رحلات القطارات المحلية وتذاكرها.",systemImage:"train.side.front.car"),
            .init(id:"pl3",name:"Bolt / Uber",category:"التنقل",noteArabic:"خيارات شائعة لطلب السيارات في المدن الكبرى.",systemImage:"car.fill")]),
        .init(code:"JP",nameArabic:"اليابان",flag:"🇯🇵",capitalArabic:"طوكيو",currency:"الين الياباني (JPY)",languagesArabic:"اليابانية",timeZoneNoteArabic:"JST",plugsArabic:"A / B • 100V",latitude:35.6762,longitude:139.6503,muslimMajority:false,emergencyGeneral:nil,emergencyNoteArabic:"الشرطة 110، والإسعاف والإطفاء 119.",apps:[
            .init(id:"jp1",name:"Japan Travel by NAVITIME",category:"النقل",noteArabic:"تخطيط القطارات والمترو والتنقل بين المدن.",systemImage:"train.side.front.car"),
            .init(id:"jp2",name:"GO",category:"سيارات الأجرة",noteArabic:"من تطبيقات طلب سيارات الأجرة المحلية.",systemImage:"car.fill"),
            .init(id:"jp3",name:"Google Maps",category:"الخرائط",noteArabic:"مفيد للتنقل والبحث عن الأماكن ومواعيد النقل.",systemImage:"map.fill")]),
        .init(code:"IT",nameArabic:"إيطاليا",flag:"🇮🇹",capitalArabic:"روما",currency:"اليورو (EUR)",languagesArabic:"الإيطالية",timeZoneNoteArabic:"أوروبا الوسطى",plugsArabic:"C / F / L • 230V",latitude:41.9028,longitude:12.4964,muslimMajority:false,emergencyGeneral:"112",emergencyNoteArabic:"رقم الطوارئ الأوروبي الموحد.",apps:[.init(id:"it1",name:"Trenitalia",category:"القطارات",noteArabic:"القطارات الوطنية والحجوزات.",systemImage:"train.side.front.car"),.init(id:"it2",name:"Italo",category:"القطارات",noteArabic:"قطارات سريعة بين مدن إيطالية عديدة.",systemImage:"train.side.front.car"),.init(id:"it3",name:"Moovit",category:"النقل",noteArabic:"مسارات النقل العام في مدن متعددة.",systemImage:"bus.fill")]),
        .init(code:"AT",nameArabic:"النمسا",flag:"🇦🇹",capitalArabic:"فيينا",currency:"اليورو (EUR)",languagesArabic:"الألمانية",timeZoneNoteArabic:"أوروبا الوسطى",plugsArabic:"C / F • 230V",latitude:48.2082,longitude:16.3738,muslimMajority:false,emergencyGeneral:"112",emergencyNoteArabic:"رقم الطوارئ الأوروبي الموحد.",apps:[.init(id:"at1",name:"ÖBB",category:"القطارات",noteArabic:"القطارات والنقل بين المدن.",systemImage:"train.side.front.car"),.init(id:"at2",name:"WienMobil",category:"النقل",noteArabic:"مفيد للتنقل داخل فيينا.",systemImage:"tram.fill")]),
        .init(code:"DE",nameArabic:"ألمانيا",flag:"🇩🇪",capitalArabic:"برلين",currency:"اليورو (EUR)",languagesArabic:"الألمانية",timeZoneNoteArabic:"أوروبا الوسطى",plugsArabic:"C / F • 230V",latitude:52.52,longitude:13.405,muslimMajority:false,emergencyGeneral:"112",emergencyNoteArabic:"112 للطوارئ الطبية والإطفاء.",apps:[.init(id:"de1",name:"DB Navigator",category:"القطارات",noteArabic:"القطارات والنقل العام في ألمانيا.",systemImage:"train.side.front.car"),.init(id:"de2",name:"BVG",category:"النقل",noteArabic:"مفيد للنقل العام في برلين.",systemImage:"tram.fill")]),
        .init(code:"FR",nameArabic:"فرنسا",flag:"🇫🇷",capitalArabic:"باريس",currency:"اليورو (EUR)",languagesArabic:"الفرنسية",timeZoneNoteArabic:"أوروبا الوسطى",plugsArabic:"C / E • 230V",latitude:48.8566,longitude:2.3522,muslimMajority:false,emergencyGeneral:"112",emergencyNoteArabic:"رقم الطوارئ الأوروبي الموحد.",apps:[.init(id:"fr1",name:"Bonjour RATP",category:"النقل",noteArabic:"النقل العام في باريس وما حولها.",systemImage:"tram.fill"),.init(id:"fr2",name:"SNCF Connect",category:"القطارات",noteArabic:"القطارات والحجوزات داخل فرنسا.",systemImage:"train.side.front.car")]),
        .init(code:"TR",nameArabic:"تركيا",flag:"🇹🇷",capitalArabic:"أنقرة",currency:"الليرة التركية (TRY)",languagesArabic:"التركية",timeZoneNoteArabic:"TRT",plugsArabic:"C / F • 230V",latitude:39.9334,longitude:32.8597,muslimMajority:true,emergencyGeneral:"112",emergencyNoteArabic:"رقم الطوارئ الموحد.",apps:[.init(id:"tr1",name:"BiTaksi",category:"التنقل",noteArabic:"طلب سيارات الأجرة في عدد من المدن.",systemImage:"car.fill"),.init(id:"tr2",name:"Moovit",category:"النقل",noteArabic:"مسارات النقل العام.",systemImage:"bus.fill")]),
        .init(code:"MY",nameArabic:"ماليزيا",flag:"🇲🇾",capitalArabic:"كوالالمبور",currency:"الرينغيت (MYR)",languagesArabic:"الماليزية ولغات أخرى",timeZoneNoteArabic:"MYT",plugsArabic:"G • 240V",latitude:3.139,longitude:101.6869,muslimMajority:true,emergencyGeneral:"999",emergencyNoteArabic:"رقم طوارئ عام؛ تحقق من تعليمات السلطات المحلية عند الحاجة.",apps:[.init(id:"my1",name:"Grab",category:"التنقل",noteArabic:"سيارات وتوصيل وخدمات محلية.",systemImage:"car.fill"),.init(id:"my2",name:"MyRapid PULSE",category:"النقل",noteArabic:"مفيد للنقل العام في كوالالمبور.",systemImage:"tram.fill")])
    ]

    private static var detailedByCode: [String:TravelDestination] { Dictionary(uniqueKeysWithValues:detailed.map{($0.code,$0)}) }

    private static let countryMetadata: [String:CountryMetadata] = {
        guard let url = Bundle.main.sariResourceURL(name: "countries", extension: "json", subdirectory: "data"),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([CountryMetadata].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.code, $0) })
    }()

    private static let muslimMajorityCodes: Set<String> = [
        "AF","AL","DZ","AZ","BH","BD","BN","BF","TD","KM","DJ","EG","GM","GN","ID","IR","IQ","JO","KZ","KW","KG","LB","LY","MY","MV","ML","MR","MA","NE","OM","PK","PS","QA","SA","SN","SL","SO","SD","SY","TJ","TN","TR","TM","AE","UZ","YE"
    ]

    private static func localizedLanguages(_ codes: [String], language: SariLanguage) -> String {
        let locale = Locale(identifier: SariContentText.localeIdentifier(language))
        let values = codes.compactMap { locale.localizedString(forLanguageCode: $0) }.filter { !$0.isEmpty }
        return values.isEmpty ? "—" : values.joined(separator: language.isArabic ? "، " : ", ")
    }

    static var destinations: [TravelDestination] {
        sovereignCodes.map { code in
            if let known=detailedByCode[code] { return known }
            let meta = countryMetadata[code]
            return TravelDestination(
                code: code,
                nameArabic: SariContentText.countryName(code, language:.ar),
                flag: SariContentText.flag(code),
                capitalArabic: meta?.capital.isEmpty == false ? (meta?.capital ?? "—") : "—",
                currency: (meta?.currencies.isEmpty == false ? meta?.currencies.joined(separator: " / ") : nil) ?? "—",
                languagesArabic: localizedLanguages(meta?.languages ?? [], language: SariLanguage.selected),
                timeZoneNoteArabic: (meta?.timezones.isEmpty == false ? meta?.timezones.joined(separator: " / ") : nil) ?? "—",
                plugsArabic: SariContentText.pick(SariLanguage.selected,[.ar:"تحقق من نوع القابس والجهد من المصدر الرسمي للوجهة",.en:"Check plug type and voltage from the destination's official guidance",.tr:"Priz tipini ve voltajı resmî kaynaktan kontrol edin",.ms:"Semak jenis palam dan voltan daripada sumber rasmi",.id:"Periksa jenis steker dan voltase dari sumber resmi",.ja:"プラグ形状と電圧は公式情報で確認してください",.zh:"请从官方信息确认插头类型和电压",.ru:"Уточните тип розетки и напряжение по официальному источнику",.fr:"Vérifiez le type de prise et la tension auprès d’une source officielle"]),
                latitude: meta?.latitude ?? 0, longitude: meta?.longitude ?? 0,
                muslimMajority: muslimMajorityCodes.contains(code),
                emergencyGeneral:nil,
                emergencyNoteArabic:SariContentText.pick(SariLanguage.selected,[.ar:"أرقام الطوارئ تختلف حسب الدولة والخدمة. استخدم المصدر الرسمي المحلي عند الحاجة.",.en:"Emergency numbers vary by country and service. Use the official local source when needed.",.tr:"Acil numaralar ülkeye ve hizmete göre değişir. Gerektiğinde resmî yerel kaynağı kullanın.",.ms:"Nombor kecemasan berbeza mengikut negara dan perkhidmatan. Gunakan sumber rasmi tempatan apabila perlu.",.id:"Nomor darurat berbeda menurut negara dan layanan. Gunakan sumber resmi setempat saat diperlukan.",.ja:"緊急番号は国やサービスにより異なります。必要時は現地の公式情報を確認してください。",.zh:"紧急号码因国家和服务而异，需要时请使用当地官方来源。",.ru:"Экстренные номера зависят от страны и службы. При необходимости используйте официальный местный источник.",.fr:"Les numéros d’urgence varient selon le pays et le service. Utilisez la source officielle locale si nécessaire."]),
                apps:[]
            )
        }.sorted { $0.name(SariLanguage.selected).localizedStandardCompare($1.name(SariLanguage.selected)) == .orderedAscending }
    }

    static func capital(for destination: TravelDestination, language: SariLanguage) -> String {
        guard language != .ar else { return destination.capitalArabic }
        if let value = countryMetadata[destination.code]?.capital, !value.isEmpty { return value }
        return destination.capitalArabic
    }

    static func currencyText(for destination: TravelDestination, language: SariLanguage) -> String {
        guard language != .ar else { return destination.currency }
        if let values = countryMetadata[destination.code]?.currencies, !values.isEmpty { return values.joined(separator: " / ") }
        return destination.currency
    }

    static func languagesText(for destination: TravelDestination, language: SariLanguage) -> String {
        if let values = countryMetadata[destination.code]?.languages, !values.isEmpty { return localizedLanguages(values, language: language) }
        return destination.languagesArabic
    }

    static func timeZoneText(for destination: TravelDestination, language: SariLanguage) -> String {
        if let values = countryMetadata[destination.code]?.timezones, !values.isEmpty { return values.joined(separator: " / ") }
        return destination.timeZoneNoteArabic
    }

    static func appNote(_ app: TravelAppRecommendation, language: SariLanguage) -> String {
        if language == .ar { return app.noteArabic }
        return SariContentText.pick(language,[
            .ar: app.noteArabic, .en:"Useful local app for transport or travel services.", .tr:"Ulaşım veya seyahat hizmetleri için yararlı yerel uygulama.",
            .ms:"Aplikasi tempatan berguna untuk pengangkutan atau perkhidmatan perjalanan.", .id:"Aplikasi lokal berguna untuk transportasi atau layanan perjalanan.",
            .ja:"交通や旅行サービスに役立つ現地アプリです。", .zh:"适用于交通或旅行服务的实用本地应用。", .ru:"Полезное местное приложение для транспорта или поездки.", .fr:"Application locale utile pour les transports ou les services de voyage."
        ])
    }

    static func emergencyContacts(for destination: TravelDestination, language: SariLanguage) -> [EmergencyContact] {
        if destination.code == "JP" {
            return [
                .init(id:"police",service:SariContentText.pick(language,[.ar:"الشرطة",.en:"Police",.tr:"Polis",.ms:"Polis",.id:"Polisi",.ja:"警察",.zh:"警察",.ru:"Полиция",.fr:"Police"]),number:"110",systemImage:"shield.fill"),
                .init(id:"ambulance",service:SariContentText.pick(language,[.ar:"الإسعاف",.en:"Ambulance",.tr:"Ambulans",.ms:"Ambulans",.id:"Ambulans",.ja:"救急",.zh:"急救",.ru:"Скорая помощь",.fr:"Ambulance"]),number:"119",systemImage:"cross.case.fill"),
                .init(id:"fire",service:SariContentText.pick(language,[.ar:"الإطفاء",.en:"Fire",.tr:"İtfaiye",.ms:"Bomba",.id:"Pemadam",.ja:"消防",.zh:"消防",.ru:"Пожарная служба",.fr:"Pompiers"]),number:"119",systemImage:"flame.fill")
            ]
        }
        if let number=destination.emergencyGeneral {
            return [.init(id:"general",service:SariContentText.pick(language,[.ar:"الطوارئ",.en:"Emergency",.tr:"Acil",.ms:"Kecemasan",.id:"Darurat",.ja:"緊急",.zh:"紧急服务",.ru:"Экстренная служба",.fr:"Urgences"]),number:number,systemImage:"sos.circle.fill")]
        }
        return []
    }

    static func mission(for nationalityCode:String,in destinationCode:String)->MissionContact? {
        guard nationalityCode == "SA" else { return nil }
        // The ministry directory remains the authoritative source for the exact mission.
        // A ministry assistance contact is always available so the travel screen never becomes an empty dead end.
        return MissionContact(
            id:"sa-\(destinationCode.lowercased())",
            titleArabic:"وزارة الخارجية السعودية — مساعدة السعوديين في الخارج",
            phone:"+966920011114",
            emergencyPhone:nil,
            addressArabic:nil,
            officialSource:saudiAssistanceURL.absoluteString,
            verifiedAt:nil
        )
    }

    static let saudiMissionsURL = URL(string:"https://www.mofa.gov.sa/ar/embassies/Pages/default.aspx")!
    static let saudiAssistanceURL = URL(string:"https://www.mofa.gov.sa/ar/eservices/Pages/svc3.aspx")!
    static let saudiMofaURL = saudiMissionsURL
    static let ituEmergencyURL = URL(string:"https://www.itu.int/net/itu-t/inrdb/e129_important_numbers.aspx")!

    static func checklist(nationality:SariNationality?,destination:TravelDestination,tripDate:Date?)->[TripChecklistItem] {
        let l=SariLanguage.selected
        var items:[TripChecklistItem]=[
            .init(id:"entry",title:SariContentText.pick(l,[.ar:"متطلبات الدخول",.en:"Entry requirements"]),detail:SariContentText.pick(l,[.ar:"تحقق من التأشيرة وصلاحية الجواز ومتطلبات الدخول من مصدر رسمي قبل السفر.",.en:"Check visa, passport validity, and entry rules from an official source before travel."]),systemImage:"person.text.rectangle"),
            .init(id:"apps",title:SariContentText.pick(l,[.ar:"التطبيقات المهمة",.en:"Useful apps"]),detail:SariContentText.pick(l,[.ar:"راجع تطبيقات النقل والخرائط والخدمات المقترحة للوجهة.",.en:"Review transport, maps, and useful local apps for the destination."]),systemImage:"square.and.arrow.down.fill"),
            .init(id:"weather",title:SariContentText.pick(l,[.ar:"الطقس واللباس",.en:"Weather & clothing"]),detail:SariContentText.pick(l,[.ar:"راجع طقس الوجهة قبل المغادرة.",.en:"Review destination weather before departure."]),systemImage:"cloud.sun.fill"),
            .init(id:"mission",title:SariContentText.pick(l,[.ar:"بيانات البعثة",.en:"Mission details"]),detail:nationality == nil ? SariContentText.pick(l,[.ar:"اختر جنسيتك ليعرض ساري بيانات البعثة عند توفرها.",.en:"Choose your nationality so SARI can show mission details when available."]) : SariContentText.pick(l,[.ar:"استخدم البيانات الموثقة أو رابط وزارة الخارجية الرسمي.",.en:"Use verified mission details or the official foreign ministry directory."]),systemImage:"building.columns.fill")
        ]
        if let tripDate { items.insert(.init(id:"date",title:SariUIStrings.text("trip_date",l),detail:tripDate.formatted(date:.long,time:.omitted),systemImage:"calendar"),at:0) }
        return items
    }
}

@MainActor final class TravelProfileStore:ObservableObject {
    @Published var nationalityCode:String { didSet{UserDefaults.standard.set(nationalityCode,forKey:"sari.travel.nationality")} }
    @Published var destinationCode:String { didSet{UserDefaults.standard.set(destinationCode,forKey:"sari.travel.destination")} }
    @Published var tripDate:Date? { didSet{UserDefaults.standard.set(tripDate,forKey:"sari.travel.tripDate")} }
    init(){nationalityCode=UserDefaults.standard.string(forKey:"sari.travel.nationality") ?? "";destinationCode=UserDefaults.standard.string(forKey:"sari.travel.destination") ?? "PL";tripDate=UserDefaults.standard.object(forKey:"sari.travel.tripDate") as? Date}
    var nationality:SariNationality?{TravelCatalog.nationalities.first{$0.code==nationalityCode}}
    var destination:TravelDestination{TravelCatalog.destinations.first{$0.code==destinationCode} ?? TravelCatalog.destinations.first{$0.code=="PL"}!}
}
