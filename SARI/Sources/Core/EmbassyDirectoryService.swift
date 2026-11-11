import Foundation
import Combine

struct EmbassyRecord: Codable, Identifiable, Hashable {
    let nationalityCode: String
    let destinationCode: String
    let officialName: String
    let city: String?
    let address: String?
    let phone: String?
    let emergencyPhone: String?
    let email: String?
    let website: String?
    let workingHours: String?
    let sourceUrl: String
    let verifiedAt: String?
    let isOfficiallyVerified: Bool?

    var id: String { "\(nationalityCode)-\(destinationCode)-\(city ?? officialName)" }
    var source: URL? { URL(string: sourceUrl).flatMap { $0.scheme == "https" ? $0 : nil } }
}

private struct EmbassyDirectoryPayload: Decodable {
    let missions: [EmbassyRecord]
}

private struct CachedEmbassyDirectory: Codable {
    let savedAt: Date
    let records: [EmbassyRecord]
}

@MainActor
final class EmbassyDirectoryStore: ObservableObject {
    @Published private(set) var records: [EmbassyRecord] = []
    @Published private(set) var isLoading = false
    @Published private(set) var message: String?
    @Published private(set) var sourceIsBackend = false
    private var activeRequestID: UUID?

    func load(nationalityCode: String, destinationCode: String) async {
        let requestID = UUID()
        activeRequestID = requestID
        let cachedRecords = loadCached(nationalityCode: nationalityCode, destinationCode: destinationCode)
        records = cachedRecords ?? []
        let hasCachedRecords = !(cachedRecords ?? []).isEmpty
        message = hasCachedRecords ? SariTravelFeatureText.text(
            arabic: "تعرض بيانات بعثات محفوظة من آخر تحديث ناجح. تحقق من المصدر الرسمي قبل الزيارة.",
            english: "Showing a saved directory snapshot from the last successful update. Confirm details with the official source before visiting.",
            language: SariLanguage.selected
        ) : nil
        sourceIsBackend = records.contains { $0.isOfficiallyVerified == true }
        guard !nationalityCode.isEmpty else {
            message = SariTravelFeatureText.text(arabic: "اختر جنسيتك لعرض البعثات الدبلوماسية.", english: "Choose your nationality to view diplomatic missions.", language: SariLanguage.selected)
            return
        }
        let base = Bundle.main.object(forInfoDictionaryKey: "SARI_API_BASE_URL") as? String
        let baseURL = base.flatMap { URL(string: $0) }
        let backendConfigured = baseURL?.scheme == "https"
            && !(base ?? "").contains("YOUR-SARI-BACKEND")
            && !(base ?? "").contains("example")

        isLoading = true
        defer { if activeRequestID == requestID { isLoading = false } }
        if backendConfigured, let baseURL {
            do {
                var components = URLComponents(url: baseURL.appendingPathComponent("v1/embassies"), resolvingAgainstBaseURL: false)
                components?.queryItems = [
                    URLQueryItem(name: "nationality", value: nationalityCode),
                    URLQueryItem(name: "destination", value: destinationCode)
                ]
                guard let url = components?.url else { throw URLError(.badURL) }
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let payload = try decoder.decode(EmbassyDirectoryPayload.self, from: data)
                guard activeRequestID == requestID else { return }
                let freshRecords = payload.missions.filter {
                    $0.nationalityCode.uppercased() == nationalityCode.uppercased()
                        && $0.destinationCode.uppercased() == destinationCode.uppercased()
                        && $0.source != nil
                }
                if !freshRecords.isEmpty {
                    records = freshRecords
                    sourceIsBackend = records.contains { $0.isOfficiallyVerified == true }
                    saveCache(records, nationalityCode: nationalityCode, destinationCode: destinationCode)
                    message = nil
                    return
                }
            } catch {
                // Try public map discovery; keep a previously cached list if available.
            }
        }

        do {
            let discovered = try await searchOpenStreetMap(nationalityCode: nationalityCode, destinationCode: destinationCode)
            guard activeRequestID == requestID else { return }
            if !discovered.isEmpty {
                records = discovered
                sourceIsBackend = false
                saveCache(discovered, nationalityCode: nationalityCode, destinationCode: destinationCode)
                message = SariTravelFeatureText.text(
                    arabic: "هذه بيانات دليل خرائط مجتمعي وليست تأكيدًا رسميًا. تحقق من الموقع الحكومي قبل الاتصال أو الزيارة.",
                    english: "This is a community map listing, not official verification. Confirm details on the government website before contacting or visiting.",
                    language: SariLanguage.selected
                )
            } else if records.isEmpty {
                message = SariTravelFeatureText.text(
                    arabic: "لم نعثر على سجل بعثة بهذه الجنسية قرب عاصمة الوجهة في بيانات الخرائط. استخدم رابط وزارة الخارجية الرسمي أدناه.",
                    english: "No matching mission listing was found near the destination capital in map data. Use the official foreign-ministry directory below.",
                    language: SariLanguage.selected
                )
            } else {
                message = SariTravelFeatureText.text(
                    arabic: "لم يظهر تحديث أحدث؛ يتم عرض آخر بيانات محفوظة وقد تكون قديمة.",
                    english: "No newer listing was found; the last saved data is shown and may be outdated.",
                    language: SariLanguage.selected
                )
            }
        } catch {
            guard activeRequestID == requestID else { return }
            if records.isEmpty {
                message = SariTravelFeatureText.text(arabic: "تعذر جلب بيانات البعثات. لم يتم اختلاق عناوين أو أرقام اتصال.", english: "Mission listings are unavailable. No addresses or contact numbers were fabricated.", language: SariLanguage.selected)
            } else {
                message = SariTravelFeatureText.text(arabic: "تعذر التحديث؛ يتم عرض آخر بيانات محفوظة وقد تكون قديمة.", english: "Update failed; displaying the last saved directory data, which may be outdated.", language: SariLanguage.selected)
            }
        }
    }

    private func cacheKey(nationalityCode: String, destinationCode: String) -> String {
        "sari.embassy.directory.\(nationalityCode.uppercased()).\(destinationCode.uppercased())"
    }

    private func loadCached(nationalityCode: String, destinationCode: String) -> [EmbassyRecord]? {
        let key = cacheKey(nationalityCode: nationalityCode, destinationCode: destinationCode)
        guard let data = UserDefaults.standard.data(forKey: key),
              let cached = try? JSONDecoder().decode(CachedEmbassyDirectory.self, from: data),
              Date().timeIntervalSince(cached.savedAt) <= 30 * 24 * 60 * 60 else { return nil }
        return cached.records
    }

    private func saveCache(_ records: [EmbassyRecord], nationalityCode: String, destinationCode: String) {
        let cached = CachedEmbassyDirectory(savedAt: Date(), records: records)
        guard let data = try? JSONEncoder().encode(cached) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(nationalityCode: nationalityCode, destinationCode: destinationCode))
    }

    private func searchOpenStreetMap(nationalityCode: String, destinationCode: String) async throws -> [EmbassyRecord] {
        guard let destination = TravelCatalog.destinations.first(where: { $0.code == destinationCode }) else { return [] }
        let capital = TravelCatalog.capital(for: destination, language: .en)
        guard !capital.isEmpty, capital != "—" else { return [] }
        var geocoder = URLComponents(string: "https://nominatim.openstreetmap.org/search")
        geocoder?.queryItems = [
            URLQueryItem(name: "q", value: "\(capital), \(destination.name(.en))"),
            URLQueryItem(name: "format", value: "jsonv2"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let geocodeURL = geocoder?.url else { return [] }
        var geoRequest = URLRequest(url: geocodeURL)
        geoRequest.timeoutInterval = 12
        geoRequest.setValue("SARI iOS travel directory", forHTTPHeaderField: "User-Agent")
        let (geoData, geoResponse) = try await URLSession.shared.data(for: geoRequest)
        guard let geoHTTP = geoResponse as? HTTPURLResponse, (200..<300).contains(geoHTTP.statusCode),
              let geos = try JSONSerialization.jsonObject(with: geoData) as? [[String: Any]],
              let first = geos.first,
              let latString = first["lat"] as? String, let lat = Double(latString),
              let lonString = first["lon"] as? String, let lon = Double(lonString) else { return [] }

        let query = """
        [out:json][timeout:25];
        (
          node["office"="diplomatic"](around:18000,\(lat),\(lon));
          way["office"="diplomatic"](around:18000,\(lat),\(lon));
          relation["office"="diplomatic"](around:18000,\(lat),\(lon));
          node["diplomatic"="embassy"](around:18000,\(lat),\(lon));
          way["diplomatic"="embassy"](around:18000,\(lat),\(lon));
          relation["diplomatic"="embassy"](around:18000,\(lat),\(lon));
          node["diplomatic"~"consulate|consulate_general"](around:18000,\(lat),\(lon));
          way["diplomatic"~"consulate|consulate_general"](around:18000,\(lat),\(lon));
          relation["diplomatic"~"consulate|consulate_general"](around:18000,\(lat),\(lon));
        ); out center tags;
        """
        guard let overpassURL = URL(string: "https://overpass-api.de/api/interpreter") else { return [] }
        var request = URLRequest(url: overpassURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 35
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        var form = URLComponents()
        form.queryItems = [URLQueryItem(name: "data", value: query)]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = object["elements"] as? [[String: Any]] else { return [] }

        let aliases = Self.nationalityAliases[nationalityCode.uppercased()] ?? [TravelCatalog.nationalities.first(where: { $0.code == nationalityCode })?.name(.en) ?? nationalityCode]
        return elements.compactMap { element in
            guard let tags = element["tags"] as? [String: Any] else { return nil }
            let name = (tags["name:en"] as? String) ?? (tags["name"] as? String) ?? ""
            guard !name.isEmpty, aliases.contains(where: { name.localizedCaseInsensitiveContains($0) }) else { return nil }
            let id = element["id"] as? Int ?? 0
            let type = element["type"] as? String ?? "node"
            let street = [tags["addr:housenumber"] as? String, tags["addr:street"] as? String].compactMap { $0 }.joined(separator: " ")
            let city = (tags["addr:city"] as? String) ?? capital
            let address = [street, city].filter { !$0.isEmpty }.joined(separator: ", ")
            let phone = (tags["contact:phone"] as? String) ?? (tags["phone"] as? String)
            let email = (tags["contact:email"] as? String) ?? (tags["email"] as? String)
            let websiteString = (tags["contact:website"] as? String) ?? (tags["website"] as? String)
            let website = websiteString.flatMap { value -> String? in
                let normalized = value.hasPrefix("http") ? value : "https://\(value)"
                return URL(string: normalized)?.scheme == "https" ? normalized : nil
            }
            return EmbassyRecord(
                nationalityCode: nationalityCode,
                destinationCode: destinationCode,
                officialName: name,
                city: city,
                address: address.isEmpty ? nil : address,
                phone: phone,
                emergencyPhone: nil,
                email: email,
                website: website,
                workingHours: tags["opening_hours"] as? String,
                sourceUrl: "https://www.openstreetmap.org/\(type)/\(id)",
                verifiedAt: nil,
                isOfficiallyVerified: false
            )
        }
    }

    private static let nationalityAliases: [String: [String]] = [
        "SA":["Saudi Arabia","Saudi"], "KW":["Kuwait","Kuwaiti"], "GB":["United Kingdom","British","United Kingdom of Great Britain"],
        "US":["United States","United States of America","USA","American"], "AE":["United Arab Emirates","UAE","Emirati"],
        "QA":["Qatar","Qatari"], "BH":["Bahrain","Bahraini"], "OM":["Oman","Omani"], "EG":["Egypt","Egyptian"],
        "FR":["France","French"], "DE":["Germany","German"], "IT":["Italy","Italian"], "JP":["Japan","Japanese"],
        "TR":["Turkey","Türkiye","Turkish"], "IN":["India","Indian"], "PK":["Pakistan","Pakistani"],
        "MY":["Malaysia","Malaysian"], "ID":["Indonesia","Indonesian"], "CA":["Canada","Canadian"], "AU":["Australia","Australian"],
        "PL":["Poland","Polish"], "ES":["Spain","Spanish"], "NL":["Netherlands","Dutch"], "CH":["Switzerland","Swiss"]
    ]
}

/// API contract for the optional SARI backend:
/// GET /v1/embassies?nationality=SA&destination=GB
/// { "missions": [{ "nationality_code":"SA", "destination_code":"GB",
///   "official_name":"...", "city":"...", "address":"...", "phone":"...",
///   "emergency_phone":"...", "email":"...", "website":"https://...",
///   "working_hours":"...", "source_url":"https://official.gov/...",
///   "verified_at":"2026-01-01" }] }
