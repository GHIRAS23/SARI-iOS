import Foundation
import Combine
import CoreLocation

struct SariPlace: Identifiable, Hashable {
    enum HalalStatus: String, Hashable {
        case explicitTag
        case defaultCountryPolicy
    }

    let id: String
    let name: String
    let category: String
    let latitude: Double
    let longitude: Double
    let address: String?
    let tags: [String: String]
    let distanceMeters: Double
    let halalStatus: HalalStatus
    let imageURL: URL?
    let rating: Double?

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    var verificationLabelArabic: String {
        halalStatus == .defaultCountryPolicy ? "افتراضيًا وفق سياسة الدولة، وليس شهادة لكل مطعم" : "وسم حلال صريح في بيانات الخرائط"
    }
}

enum SariPlaceKind: String, CaseIterable, Identifiable {
    case food, mosque, pharmacy, hospital, grocery, transport
    var id: String { rawValue }
    var titleArabic: String {
        switch self {
        case .food: return "المطاعم"
        case .mosque: return "المساجد"
        case .pharmacy: return "الصيدليات"
        case .hospital: return "المستشفيات"
        case .grocery: return "البقالات"
        case .transport: return "النقل"
        }
    }
    var systemImage: String {
        switch self {
        case .food: return "fork.knife"
        case .mosque: return "building.columns.fill"
        case .pharmacy: return "cross.case.fill"
        case .hospital: return "heart.text.square.fill"
        case .grocery: return "cart.fill"
        case .transport: return "tram.fill"
        }
    }
}

@MainActor
final class SariLocationManager: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var errorMessage: String?
    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        errorMessage = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            errorMessage = SariTravelFeatureText.text(arabic: "فعّل إذن الموقع للعثور على المطاعم القريبة.", english: "Enable location permission to find nearby restaurants.", language: SariLanguage.selected)
        @unknown default:
            errorMessage = SariTravelFeatureText.text(arabic: "تعذر تحديد حالة إذن الموقع.", english: "The location permission status is unknown.", language: SariLanguage.selected)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
        errorMessage = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = SariTravelFeatureText.text(arabic: "تعذر تحديد موقعك الحالي. تحقق من خدمات الموقع وحاول مجددًا.", english: "Your current location could not be determined. Check Location Services and try again.", language: SariLanguage.selected)
    }
}

@MainActor
final class PlacesStore: ObservableObject {
    @Published private(set) var places: [SariPlace] = []
    @Published private(set) var isLoading = false
    @Published private(set) var message: String?
    @Published private(set) var usedDefaultCountryPolicy = false

    private let session: URLSession
    private let defaultHalalCountries = HalalCountryPolicy.defaultCountryCodes
    private var activeRequestID: UUID?

    init(session: URLSession = .shared) { self.session = session }

    func loadHalalRestaurants(near location: CLLocation, countryCode: String) async {
        let requestID = UUID()
        activeRequestID = requestID
        isLoading = true
        places = []
        message = nil
        let requestUsesDefaultPolicy = defaultHalalCountries.contains(countryCode.uppercased())
        usedDefaultCountryPolicy = requestUsesDefaultPolicy
        defer { if activeRequestID == requestID { isLoading = false } }

        do {
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude
            let query = """
            [out:json][timeout:25];
            (
              node[\"amenity\"=\"restaurant\"](around:10000,\(lat),\(lon));
              way[\"amenity\"=\"restaurant\"](around:10000,\(lat),\(lon));
              relation[\"amenity\"=\"restaurant\"](around:10000,\(lat),\(lon));
            );
            out center tags;
            """
            guard let endpoint = URL(string: "https://overpass-api.de/api/interpreter") else { throw URLError(.badURL) }
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 35
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            var form = URLComponents()
            form.queryItems = [URLQueryItem(name: "data", value: query)]
            request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)
            let origin = location
            let candidates = decoded.elements.compactMap { element -> SariPlace? in
                guard let coordinate = element.resolvedCoordinate else { return nil }
                let tags = element.tags ?? [:]
                guard let name = tags["name"], !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                let explicitlyHalal = Self.isExplicitlyHalal(tags)
                let knownNegative = [tags["halal"], tags["diet:halal"]].compactMap { $0?.lowercased() }.contains("no")
                if knownNegative { return nil }
                let status: SariPlace.HalalStatus
                if requestUsesDefaultPolicy {
                    guard !HalalCountryPolicy.restaurantExceptions.contains("\(countryCode.uppercased()):\(element.type)-\(element.id)") else { return nil }
                    status = .defaultCountryPolicy
                } else {
                    guard explicitlyHalal else { return nil }
                    status = .explicitTag
                }
                let placeLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let addressParts = [tags["addr:housenumber"], tags["addr:street"], tags["addr:city"]].compactMap { $0 }.filter { !$0.isEmpty }
                let address = addressParts.isEmpty ? tags["addr:full"] : addressParts.joined(separator: " ")
                return SariPlace(
                    id: "\(element.type)-\(element.id)",
                    name: name,
                    category: tags["cuisine"] ?? "restaurant",
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    address: address,
                    tags: tags,
                    distanceMeters: origin.distance(from: placeLocation),
                    halalStatus: status,
                    imageURL: Self.safeImageURL(tags["image"]),
                    rating: Double(tags["stars"] ?? tags["rating"] ?? "")
                )
            }
            guard activeRequestID == requestID else { return }
            places = Array(Dictionary(grouping: candidates, by: \.id).compactMap { $0.value.first }.sorted { $0.distanceMeters < $1.distanceMeters }.prefix(5))
            if places.isEmpty {
                message = requestUsesDefaultPolicy
                    ? SariTravelFeatureText.text(arabic: "لم يُرجع مصدر الخرائط مطاعم قريبة مسجلة. جرّب عرض المزيد في خرائط Google.", english: "The map provider returned no nearby restaurants. Try Google Maps for more results.", language: SariLanguage.selected)
                    : SariTravelFeatureText.text(arabic: "لم نعثر على مطاعم تحمل وسم حلال صريح في بيانات الخرائط القريبة. هذا لا يعني عدم وجود مطاعم حلال.", english: "No nearby restaurants with an explicit halal tag were found. This does not mean halal restaurants are unavailable.", language: SariLanguage.selected)
            }
        } catch {
            guard activeRequestID == requestID else { return }
            message = SariTravelFeatureText.text(arabic: "تعذر جلب بيانات المطاعم حاليًا. يمكنك فتح خرائط Google للبحث المباشر.", english: "Restaurant data is temporarily unavailable. Open Google Maps to search directly.", language: SariLanguage.selected)
        }
    }

    private static func safeImageURL(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw), url.scheme == "https" else { return nil }
        return url
    }

    private static func isExplicitlyHalal(_ tags: [String: String]) -> Bool {
        if [tags["halal"], tags["diet:halal"]].compactMap({ $0?.lowercased() }).contains("yes") { return true }
        let cuisine = (tags["cuisine"] ?? "").lowercased()
        let name = (tags["name"] ?? "").lowercased()
        return cuisine.contains("halal") || name.contains("halal") || name.contains("حلال")
    }
}

private struct OverpassResponse: Decodable {
    let elements: [OverpassElement]
}

private struct OverpassElement: Decodable {
    let id: Int64
    let type: String
    let lat: Double?
    let lon: Double?
    let center: OverpassCenter?
    let tags: [String: String]?

    var resolvedCoordinate: (latitude: Double, longitude: Double)? {
        if let lat, let lon { return (lat, lon) }
        if let center { return (center.lat, center.lon) }
        return nil
    }
}

private struct OverpassCenter: Decodable {
    let lat: Double
    let lon: Double
}

enum MapLauncher {
    static func googleMapsURL(query: String, latitude: Double, longitude: Double) -> URL? {
        var components = URLComponents(string: "https://www.google.com/maps/search/")
        components?.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: "\(query) @\(latitude),\(longitude)")
        ]
        components?.queryItems?.append(URLQueryItem(name: "center", value: "\(latitude),\(longitude)"))
        components?.queryItems?.append(URLQueryItem(name: "zoom", value: "14"))
        return components?.url
    }

    static func googleMapsURL(query: String, destination: TravelDestination) -> URL? {
        googleMapsURL(query: query, latitude: destination.latitude, longitude: destination.longitude)
    }
}
