import Foundation

struct LocalFoodRecipe: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let imageURL: URL?
    let area: String
    let category: String?
    let ingredients: [String]
    let instructions: String?
    let sourceURL: URL?
}

enum FoodIngredientRisk: Sendable {
    case noListedConcern
    case needsVerification([String])
    case possibleNonHalal([String])

    var ingredients: [String] {
        switch self {
        case .noListedConcern: return []
        case .needsVerification(let values), .possibleNonHalal(let values): return values
        }
    }
}

enum LocalFoodRiskChecker {
    private static let explicitConcernTerms = [
        "pork", "bacon", "ham", "lard", "prosciutto", "pancetta", "wine", "beer", "rum", "brandy", "vodka", "whisky", "whiskey", "gin", "sherry"
    ]
    private static let verificationTerms = [
        "gelatin", "gelatine", "beef", "chicken", "lamb", "mutton", "veal", "meat", "sausage", "stock", "broth", "poultry", "pepperoni", "salami"
    ]

    static func assess(_ ingredients: [String]) -> FoodIngredientRisk {
        let values = ingredients.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        func tokens(_ value: String) -> Set<String> {
            Set(value.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
        }
        func matches(_ value: String, terms: [String]) -> Bool {
            let wordSet = tokens(value)
            return terms.contains { term in
                let termWords = tokens(term)
                return !termWords.isEmpty && termWords.isSubset(of: wordSet)
            }
        }
        let explicit = values.filter { matches($0, terms: explicitConcernTerms) }
        if !explicit.isEmpty { return .possibleNonHalal(explicit) }
        let uncertain = values.filter { matches($0, terms: verificationTerms) }
        if !uncertain.isEmpty { return .needsVerification(uncertain) }
        return .noListedConcern
    }
}

private struct LocalFoodAreaConfiguration: Decodable {
    let schema: Int
    let country_to_area: [String: String]
}

enum LocalFoodArea {
    static func mealDBArea(countryCode: String) -> String? {
        guard let url = Bundle.main.sariResourceURL(name: "local_food_areas", extension: "json", subdirectory: "data"),
              let data = try? Data(contentsOf: url),
              let configuration = try? JSONDecoder().decode(LocalFoodAreaConfiguration.self, from: data),
              configuration.schema == 1 else { return nil }
        return configuration.country_to_area[countryCode.uppercased()]
    }
}

enum LocalFoodServiceError: LocalizedError {
    case unsupportedCountry
    case noMeals
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unsupportedCountry: return "The food provider does not currently support this country's cuisine area."
        case .noMeals: return "No recipes were returned for this cuisine area."
        case .invalidResponse: return "The food provider returned an invalid response."
        }
    }
}

enum LocalFoodService {
    private static var baseURL: String {
        let configured = Bundle.main.object(forInfoDictionaryKey: "SARI_MEALDB_API_BASE_URL") as? String
        return configured.flatMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: trimmed), url.scheme == "https", url.host != nil else { return nil }
            return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        } ?? "https://www.themealdb.com/api/json/v1/1"
    }

    static func fetchRecipes(countryCode: String, limit: Int = 8) async throws -> [LocalFoodRecipe] {
        guard let area = LocalFoodArea.mealDBArea(countryCode: countryCode) else {
            throw LocalFoodServiceError.unsupportedCountry
        }
        guard let filterURL = URL(string: "\(baseURL)/filter.php?a=\(area.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? area)") else {
            throw LocalFoodServiceError.invalidResponse
        }
        let filterData = try await get(filterURL)
        guard let object = try JSONSerialization.jsonObject(with: filterData) as? [String: Any] else {
            throw LocalFoodServiceError.invalidResponse
        }
        guard let meals = object["meals"] as? [[String: Any]], !meals.isEmpty else { throw LocalFoodServiceError.noMeals }
        let ids = meals.prefix(max(1, min(limit, 12))).compactMap { $0["idMeal"] as? String }
        let recipes = await withTaskGroup(of: LocalFoodRecipe?.self, returning: [LocalFoodRecipe].self) { group in
            for id in ids {
                group.addTask { try? await fetchDetails(id: id, area: area) }
            }
            var collected: [LocalFoodRecipe] = []
            for await recipe in group {
                if let recipe { collected.append(recipe) }
            }
            return collected.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        guard !recipes.isEmpty else { throw LocalFoodServiceError.noMeals }
        return recipes
    }

    private static func fetchDetails(id: String, area: String) async throws -> LocalFoodRecipe {
        guard let url = URL(string: "\(baseURL)/lookup.php?i=\(id)") else { throw LocalFoodServiceError.invalidResponse }
        let data = try await get(url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = object["meals"] as? [[String: Any]],
              let meal = rows.first,
              let name = meal["strMeal"] as? String else { throw LocalFoodServiceError.invalidResponse }
        let ingredients = (1...20).compactMap { index -> String? in
            guard let ingredient = meal["strIngredient\(index)"] as? String else { return nil }
            let trimmed = ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        let imageURL = (meal["strMealThumb"] as? String).flatMap { raw -> URL? in
            guard let url = URL(string: raw), url.scheme == "https", url.host != nil else { return nil }
            return url
        }
        let sourceURL = (meal["strSource"] as? String).flatMap { URL(string: $0) }.flatMap { $0.scheme == "https" && $0.host != nil ? $0 : nil }
        let category = meal["strCategory"] as? String
        let instructions = (meal["strInstructions"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return LocalFoodRecipe(id: id, name: name, imageURL: imageURL, area: area, category: category, ingredients: ingredients, instructions: instructions?.isEmpty == false ? instructions : nil, sourceURL: sourceURL)
    }

    private static func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LocalFoodServiceError.invalidResponse
        }
        return data
    }
}
