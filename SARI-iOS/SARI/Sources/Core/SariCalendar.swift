import Foundation

enum SariDateDisplayMode: String, CaseIterable, Identifiable {
    case dual
    case hijri
    case gregorian

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .dual:
            return "هجري + ميلادي"
        case .hijri:
            return "هجري — أم القرى"
        case .gregorian:
            return "ميلادي"
        }
    }
}

enum SariCalendar {

    private static var suite: UserDefaults? {
        UserDefaults(
            suiteName: "group.sa.sari.app"
        )
    }

    static var mode: SariDateDisplayMode {
        SariDateDisplayMode(
            rawValue:
                suite?.string(
                    forKey: "dateDisplayMode"
                ) ?? "dual"
        ) ?? .dual
    }

    static var hijriAdjustment: Int {
        suite?.integer(
            forKey: "hijriAdjustment"
        ) ?? 0
    }

    static func adjustedDate(
        _ date: Date
    ) -> Date {
        Calendar.current.date(
            byAdding: .day,
            value: hijriAdjustment,
            to: date
        ) ?? date
    }

    static func hijri(
        _ date: Date = .now,
        language: SariLanguage = .selected
    ) -> String {

        let formatter = DateFormatter()

        formatter.calendar = Calendar(
            identifier: .islamicUmmAlQura
        )

        formatter.locale = Locale(
            identifier:
                language.isArabic
                    ? "ar_SA"
                    : language.rawValue
        )

        formatter.dateFormat =
            language.isArabic
                ? "EEEE، d MMMM y 'هـ'"
                : "EEEE, d MMMM y 'AH'"

        return formatter.string(
            from: adjustedDate(date)
        )
    }

    static func gregorian(
        _ date: Date = .now,
        language: SariLanguage = .selected
    ) -> String {

        let formatter = DateFormatter()

        formatter.calendar = Calendar(
            identifier: .gregorian
        )

        formatter.locale = Locale(
            identifier:
                language.isArabic
                    ? "ar_SA"
                    : language.rawValue
        )

        formatter.dateStyle = .full

        return formatter.string(
            from: date
        )
    }

    static func lines(
        _ date: Date = .now,
        language: SariLanguage = .selected
    ) -> [String] {

        switch mode {
        case .dual:
            return [
                hijri(
                    date,
                    language: language
                ),
                gregorian(
                    date,
                    language: language
                )
            ]

        case .hijri:
            return [
                hijri(
                    date,
                    language: language
                )
            ]

        case .gregorian:
            return [
                gregorian(
                    date,
                    language: language
                )
            ]
        }
    }
}