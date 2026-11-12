import Foundation

private struct HalalCountryPolicyFile: Decodable {
    let schema: Int
    let country_codes: [String]
    let restaurant_exceptions: [String]?
}

enum HalalCountryPolicy {
    static var defaultCountryCodes: Set<String> {
        guard let url = Bundle.main.sariResourceURL(name: "halal_default_countries", extension: "json", subdirectory: "data"),
              let data = try? Data(contentsOf: url),
              let policy = try? JSONDecoder().decode(HalalCountryPolicyFile.self, from: data),
              policy.schema == 1 else { return ["SA", "KW"] }
        return Set(policy.country_codes.map { $0.uppercased() })
    }

    static var restaurantExceptions: Set<String> {
        guard let url = Bundle.main.sariResourceURL(name: "halal_default_countries", extension: "json", subdirectory: "data"),
              let data = try? Data(contentsOf: url),
              let policy = try? JSONDecoder().decode(HalalCountryPolicyFile.self, from: data) else { return [] }
        return Set(policy.restaurant_exceptions ?? [])
    }
}
