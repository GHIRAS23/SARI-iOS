import SwiftUI

enum SariUIStrings {

    private static let cache: [String: [String: String]] = {

        guard let url = Bundle.main.url(
            forResource: "ui_strings",
            withExtension: "json",
            subdirectory: "data"
        ),
        let data = try? Data(contentsOf: url),
        let decoded = try? JSONDecoder().decode(
            [String: [String: String]].self,
            from: data
        ) else {
            return [:]
        }

        return decoded
    }()

    static func format(
        _ key: String,
        _ language: SariLanguage,
        _ values: [String: String]
    ) -> String {

        var value = text(key, language)

        for (name, replacement) in values {
            value = value.replacingOccurrences(
                of: "{\(name)}",
                with: replacement
            )
        }

        return value
    }

    static func text(
        _ key: String,
        _ language: SariLanguage
    ) -> String {

        cache[key]?[language.rawValue]
            ?? cache[key]?["en"]
            ?? key
    }
}

struct SariLanguageEnvironment: ViewModifier {

    let language: SariLanguage

    func body(content: Content) -> some View {
        content
            .environment(
                \.locale,
                Locale(identifier: language.rawValue)
            )
            .environment(
                \.layoutDirection,
                language.isArabic
                    ? .rightToLeft
                    : .leftToRight
            )
            .typesettingLanguage(.automatic)
    }
}

extension View {

    func sariLanguageEnvironment(
        _ language: SariLanguage
    ) -> some View {
        modifier(
            SariLanguageEnvironment(
                language: language
            )
        )
    }
}