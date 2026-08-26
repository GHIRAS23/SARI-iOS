import Foundation
enum SariLocalized {
    static func text(_ key:String, fallback:String)->String {
        let lang=SariLanguage.selected.rawValue
        // Existing SariStrings remains the primary app dictionary.
        // This helper guarantees a visible fallback while screens migrate away from hard-coded strings.
        if lang == "ar" { return fallback }
        return NSLocalizedString(key, tableName:nil, bundle:.main, value:fallback, comment:"SARI UI")
    }
}
