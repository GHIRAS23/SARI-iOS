import SwiftUI

struct EmbassyDirectoryView: View {
    let nationalityCode: String
    let destinationCode: String
    @StateObject private var store = EmbassyDirectoryStore()
    private var language: SariLanguage { SariLanguage.selected }
    private var nationality: SariNationality { SariNationality(code: nationalityCode) }
    private var destination: TravelDestination { TravelCatalog.destinations.first { $0.code == destinationCode } ?? TravelCatalog.destinations.first! }

    var body: some View {
        List {
            Section(title("بيانات الاختيار", "Selected countries")) {
                LabeledContent(title("الجنسية", "Nationality"), value: "\(nationality.flag) \(nationality.name(language))")
                LabeledContent(title("دولة الوجهة", "Destination"), value: "\(destination.flag) \(destination.name(language))")
            }
            Section(title("السفارات والقنصليات", "Embassies and consulates")) {
                if store.isLoading { ProgressView(title("جاري البحث عن البعثة…", "Searching diplomatic directory…")) }
                if let message = store.message { Text(message).font(.subheadline).foregroundStyle(.secondary) }
                ForEach(store.records) { record in
                    VStack(alignment: .leading, spacing: 9) {
                        Text(record.officialName).font(.headline)
                        Label(record.isOfficiallyVerified == true
                              ? title("معلومات معتمدة من دليل ساري", "Verified by SARI directory")
                              : title("قائمة خرائط غير رسمية", "Unverified community map listing"),
                              systemImage: record.isOfficiallyVerified == true ? "checkmark.seal.fill" : "info.circle")
                            .font(.caption).foregroundStyle(record.isOfficiallyVerified == true ? .green : .orange)
                        if let city = record.city, !city.isEmpty { Label(city, systemImage: "building.2") }
                        if let address = record.address, !address.isEmpty { Label(address, systemImage: "mappin.and.ellipse") }
                        if let phone = record.phone, let url = URL(string: "tel:\(phone)") { Link(phone, destination: url).font(.callout) }
                        if let emergency = record.emergencyPhone, let url = URL(string: "tel:\(emergency)") { Link(title("رقم الطوارئ القنصلي: ", "Consular emergency: ") + emergency, destination: url) }
                        if let email = record.email, let url = URL(string: "mailto:\(email)") { Link(email, destination: url) }
                        if let website = record.website, let url = URL(string: website), url.scheme == "https" { Link(title("الموقع المذكور في بيانات الدليل", "Website listed in directory"), destination: url) }
                        if let hours = record.workingHours, !hours.isEmpty { Label(hours, systemImage: "clock") }
                        if let verified = record.verifiedAt { Text(title("آخر تحقق: ", "Last verified: ") + verified).font(.caption).foregroundStyle(.secondary) }
                        if let source = record.source { Link(title("مصدر سجل المكان", "Place listing source"), destination: source).font(.caption) }
                    }
                    .padding(.vertical, 5)
                }
            }
            Section(title("المصادر الرسمية", "Official sources")) {
                if nationalityCode == "SA" {
                    Link(title("دليل بعثات وزارة الخارجية السعودية", "Saudi Ministry of Foreign Affairs mission directory"), destination: TravelCatalog.saudiMissionsURL)
                    Link(title("خدمات مساعدة السعوديين في الخارج", "Saudi citizens assistance abroad"), destination: TravelCatalog.saudiAssistanceURL)
                } else if let searchURL = officialSearchURL {
                    Link(title("البحث عن الدليل الرسمي لوزارة خارجية الجنسية", "Find the nationality's official foreign-ministry directory"), destination: searchURL)
                    Text(title("نتائج البحث ليست اعتمادًا بحد ذاتها؛ تحقق من أن الموقع تابع للحكومة أو وزارة الخارجية.", "Search results are not verification by themselves; confirm the website belongs to the government or foreign ministry."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(title("دليل السفارات", "Embassy directory"))
        .task(id: "\(nationalityCode)-\(destinationCode)") {
            await store.load(nationalityCode: nationalityCode, destinationCode: destinationCode)
        }
        .sariLanguageEnvironment(language)
    }

    private var officialSearchURL: URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: "official foreign ministry embassy \(nationality.name(.en)) in \(destination.name(.en))")]
        return components?.url
    }

    private func title(_ arabic: String, _ english: String) -> String { SariTravelFeatureText.text(arabic: arabic, english: english, language: language) }
}
