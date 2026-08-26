import SwiftUI

struct Scholar: Codable, Identifiable { var id: String { phone }; let name: String; let phone: String }

struct ScholarsView: View {
    private let scholars: [Scholar] = {
        guard let url = Bundle.main.url(forResource: "scholars", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Scholar].self, from: data) else { return [] }
        return list
    }()
    var body: some View {
        NavigationStack {
            List(scholars) { scholar in
                VStack(alignment: .leading, spacing: 6) {
                    Text(scholar.name).font(.headline)
                    Text(scholar.phone).font(.callout).foregroundStyle(.secondary)
                    if let url = URL(string: "tel:\(scholar.phone)") {
                        Link(SariUIStrings.text("call",SariLanguage.selected), destination: url)
                    }
                }.padding(.vertical, 4)
            }.navigationTitle(SariUIStrings.text("scholars_title",SariLanguage.selected))
        }
    }
}
