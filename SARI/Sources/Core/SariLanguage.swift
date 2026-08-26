import Foundation

enum SariLanguage:String,CaseIterable,Identifiable {
    case ar,en,tr,ms,id,ja,zh,ru,fr
    var id:String{rawValue}
    static var device:SariLanguage {
        let code=Locale.current.language.languageCode?.identifier.lowercased() ?? "ar"
        return SariLanguage(rawValue:code) ?? .en
    }
    static var selected:SariLanguage {
        let raw=UserDefaults.standard.string(forKey:"sariLanguage") ?? ""
        return SariLanguage(rawValue:raw) ?? device
    }
    var isArabic:Bool{self == .ar}
    var displayName:String {
        switch self {
        case .ar:return "العربية"; case .en:return "English"; case .tr:return "Türkçe"
        case .ms:return "Bahasa Melayu"; case .id:return "Bahasa Indonesia"; case .ja:return "日本語"
        case .zh:return "中文"; case .ru:return "Русский"; case .fr:return "Français"
        }
    }
}
