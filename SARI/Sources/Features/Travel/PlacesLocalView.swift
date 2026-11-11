import SwiftUI
import CoreLocation

struct PlacesLocalView: View {
    let destination: TravelDestination
    @StateObject private var store = PlacesStore()
    @StateObject private var locationManager = SariLocationManager()
    @State private var currentCountryCode: String?
    @State private var geocoding = false
    @Environment(\.openURL) private var openURL
    private var language: SariLanguage { SariLanguage.selected }
    private var locationKey: String {
        guard let location = locationManager.location else { return "none" }
        return "\(location.coordinate.latitude),\(location.coordinate.longitude)"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                introCard
                if let location = locationManager.location {
                    if store.isLoading {
                        HStack { ProgressView(); Text(title("جاري البحث عن المطاعم القريبة…", "Finding nearby restaurants…")) }
                            .frame(maxWidth: .infinity).travelFeatureCard()
                    }
                    if let message = store.message {
                        Text(message).font(.subheadline).foregroundStyle(.secondary).travelFeatureCard()
                    }
                    ForEach(store.places) { place in placeCard(place) }
                    if !store.places.isEmpty {
                        Text(title("يتم عرض أول خمسة مطاعم. للحصول على خيارات إضافية افتح خرائط Google.", "The first five results are shown. Open Google Maps for more options."))
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    Button {
                        if let url = MapLauncher.googleMapsURL(query: "halal restaurants", latitude: location.coordinate.latitude, longitude: location.coordinate.longitude) { openURL(url) }
                    } label: {
                        Label(title("عرض المزيد على خرائط Google", "See more on Google Maps"), systemImage: "map.fill")
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .travelFeatureCard()
                    Button { locationManager.requestLocation() } label: {
                        Label(title("تحديث موقعي والبحث مجددًا", "Refresh location and search again"), systemImage: "location.fill")
                    }
                    .buttonStyle(.bordered)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "location.circle.fill").font(.system(size: 42)).foregroundStyle(Color.accentColor)
                        Text(title("نحتاج إلى موقعك لعرض المطاعم القريبة", "Your location is needed to show nearby restaurants")).font(.headline)
                        Text(title("لن يتم طلب الموقع إلا للبحث عن الأماكن القريبة. تُرسل إحداثيات البحث إلى خدمة OpenStreetMap لجلب النتائج. يمكنك استخدام خرائط Google يدويًا إذا لم ترغب في مشاركة موقعك.", "Location is requested only for nearby search. Search coordinates are sent to OpenStreetMap to retrieve results. You can search manually in Google Maps if you prefer not to share them.")).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button { locationManager.requestLocation() } label: {
                            Label(title("السماح بتحديد الموقع", "Allow location access"), systemImage: "location.fill")
                        }.buttonStyle(.borderedProminent)
                        if let error = locationManager.errorMessage { Text(error).font(.caption).foregroundStyle(.orange) }
                        Button {
                            if let url = MapLauncher.googleMapsURL(query: "halal restaurants", destination: destination) { openURL(url) }
                        } label: { Label(title("البحث في خرائط Google", "Search Google Maps"), systemImage: "map") }
                    }
                    .frame(maxWidth: .infinity).travelFeatureCard()
                }
                Text(title("مصدر بيانات الأماكن: OpenStreetMap / Overpass. تصنيف السعودية والكويت افتراضي وفق سياسة ساري وليس شهادة حلال مستقلة لكل مطعم.", "Place data: OpenStreetMap / Overpass. Saudi Arabia and Kuwait use SARI's default-country policy, not independent halal certification for each restaurant."))
                    .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 8)
            }
            .padding(18)
        }
        .navigationTitle(title("المطاعم الحلال القريبة", "Nearby halal restaurants"))
        .onAppear { locationManager.requestLocation() }
        .task(id: locationKey) {
            guard let location = locationManager.location else { return }
            geocoding = true
            defer { geocoding = false }
            let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
            let detected = placemarks?.first?.isoCountryCode?.uppercased()
            currentCountryCode = detected ?? destination.code
            await store.loadHalalRestaurants(near: location, countryCode: currentCountryCode ?? destination.code)
        }
        .sariLanguageEnvironment(language)
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title("العثور على المطاعم القريبة", "Find restaurants near you")).font(.title3.bold())
            Text(title("يعرض ساري ما يصل إلى خمسة مطاعم موثقة بوسم حلال في بيانات الخرائط خارج السعودية والكويت. في السعودية والكويت تُطبق سياسة التصنيف الافتراضي التي اخترتها.", "SARI shows up to five nearby restaurants tagged halal in map data outside Saudi Arabia and Kuwait. Your default-country policy is applied in Saudi Arabia and Kuwait."))
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .travelFeatureCard()
    }

    private func placeCard(_ place: SariPlace) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            if let imageURL = place.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure: EmptyView()
                    case .empty: ProgressView().frame(maxWidth: .infinity).frame(height: 90)
                    @unknown default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 120).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            HStack(alignment: .top) {
                Image(systemName: "fork.knife.circle.fill").font(.title2).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(place.name).font(.headline)
                    Text(place.category.replacingOccurrences(of: ";", with: ", ")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(distanceText(place.distanceMeters)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            if let address = place.address, !address.isEmpty { Label(address, systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(.secondary) }
            if let rating = place.rating { Label(String(format: "%.1f", rating), systemImage: "star.fill").font(.caption).foregroundStyle(.orange) }
            Label(place.halalStatus == .defaultCountryPolicy
                  ? title("تصنيف افتراضي للدولة", "Default country policy")
                  : title("وسم حلال في بيانات الخرائط", "Halal tag in map data"), systemImage: "checkmark.seal.fill")
                .font(.caption).foregroundStyle(place.halalStatus == .defaultCountryPolicy ? .orange : .green)
            if let url = MapLauncher.googleMapsURL(query: place.name, latitude: place.latitude, longitude: place.longitude) {
                Link(destination: url) { Label(title("الاتجاهات", "Directions"), systemImage: "arrow.triangle.turn.up.right.diamond.fill") }
                    .font(.subheadline.weight(.semibold))
            }
        }
        .travelFeatureCard()
    }

    private func distanceText(_ meters: Double) -> String {
        meters < 1000 ? "\(Int(meters.rounded())) m" : String(format: "%.1f km", meters / 1000)
    }
    private func title(_ arabic: String, _ english: String) -> String { SariTravelFeatureText.text(arabic: arabic, english: english, language: language) }
}

private extension View {
    func travelFeatureCard() -> some View {
        self.frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.primary.opacity(0.045)))
    }
}
