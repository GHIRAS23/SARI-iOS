import SwiftUI

struct PlacesLocalView:View {
    let destination:TravelDestination
    @StateObject private var store=PlacesStore()
    @State private var kind:SariPlaceKind = .food
    @Environment(\.openURL) private var openURL

    var body:some View {
        ScrollView {
            VStack(spacing:16) {
                VStack(alignment:.trailing,spacing:8) {
                    Text(destination.muslimMajority ? SariUIStrings.text("special_nearby", SariLanguage.selected):SariUIStrings.text("useful_places", SariLanguage.selected)).font(.title2.bold())
                    Text(destination.muslimMajority ? SariUIStrings.text("places_quality_note",SariLanguage.selected):SariUIStrings.text("halal_strict_note",SariLanguage.selected))
                        .foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                }.p7card()

                ScrollView(.horizontal,showsIndicators:false) {
                    HStack { ForEach(SariPlaceKind.allCases) { k in
                        Button { kind=k } label:{
                            Label(k.titleArabic,systemImage:k.systemImage).padding(.horizontal,13).padding(.vertical,9)
                                .background(kind==k ? Color.accentColor:Color(.secondarySystemBackground),in:Capsule())
                                .foregroundStyle(kind==k ? .white:.primary)
                        }.buttonStyle(.plain)
                    }}
                }

                VStack(alignment:.trailing,spacing:12) {
                    Text(kind.titleArabic).font(.title3.bold())
                    Text(store.message ?? SariUIStrings.text("no_verified_results",SariLanguage.selected)).foregroundStyle(.secondary)
                    HStack {
                        Button { if let u=MapLauncher.appleMapsURL(query:mapQuery,destination:destination){openURL(u)} } label:{Label("Apple Maps",systemImage:"map.fill")}.buttonStyle(.borderedProminent)
                        Button { if let u=MapLauncher.googleMapsURL(query:mapQuery,destination:destination){openURL(u)} } label:{Label("Google Maps",systemImage:"location.magnifyingglass")}.buttonStyle(.bordered)
                    }
                }.p7card()

                VStack(alignment:.trailing,spacing:12) {
                    Text(SariUIStrings.text("destination_services_apps",SariLanguage.selected)).font(.title3.bold())
                    ForEach(destination.apps) { app in
                        HStack { Image(systemName:app.systemImage).foregroundStyle(Color.accentColor); Spacer()
                            VStack(alignment:.trailing){Text(app.name).font(.headline);Text(app.noteArabic).font(.caption).foregroundStyle(.secondary)}
                        }
                    }
                }.p7card()

                Text(SariUIStrings.text("dynamic_maps_note",SariLanguage.selected))
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding(18)
        }.navigationTitle(SariUIStrings.format("around_you",SariLanguage.selected,["country":destination.nameArabic])).environment(\.layoutDirection,SariLanguage.selected.isArabic ? .rightToLeft : .leftToRight)
        .task(id:kind){await store.load(kind:kind,destination:destination)}
    }

    private var mapQuery:String {
        switch kind { case .food:return destination.muslimMajority ? "best restaurants":"halal restaurants"; case .mosque:return "mosque"; case .pharmacy:return "pharmacy"; case .hospital:return "hospital"; case .grocery:return "grocery"; case .transport:return "public transport" }
    }
}
private extension View { func p7card()->some View { self.frame(maxWidth:.infinity,alignment:.trailing).padding(18).background(.regularMaterial,in:RoundedRectangle(cornerRadius:22,style:.continuous)) } }
