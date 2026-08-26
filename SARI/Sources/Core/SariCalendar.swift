import Foundation

enum SariDateDisplayMode:String,CaseIterable,Identifiable {
    case dual,hijri,gregorian
    var id:String{rawValue}
    var title:String {
        switch self { case .dual:return "هجري + ميلادي";case .hijri:return "هجري — أم القرى";case .gregorian:return "ميلادي" }
    }
}
enum SariCalendar {
    private static let suite=UserDefaults(suiteName:"group.sa.sari.app")
    static var mode:SariDateDisplayMode { SariDateDisplayMode(rawValue:suite?.string(forKey:"dateDisplayMode") ?? "dual") ?? .dual }
    static var hijriAdjustment:Int { suite?.integer(forKey:"hijriAdjustment") ?? 0 }
    static func adjustedDate(_ date:Date)->Date { Calendar.current.date(byAdding:.day,value:hijriAdjustment,to:date) ?? date }
    static func hijri(_ date:Date = .now,language:SariLanguage = .selected)->String {
        let f=DateFormatter(); f.calendar=Calendar(identifier:.islamicUmmAlQura)
        f.locale=Locale(identifier:language.isArabic ? "ar_SA" : language.rawValue)
        f.dateFormat=language.isArabic ? "EEEE، d MMMM y 'هـ'" : "EEEE, d MMMM y 'AH'"
        return f.string(from:adjustedDate(date))
    }
    static func gregorian(_ date:Date = .now,language:SariLanguage = .selected)->String {
        let f=DateFormatter();f.calendar=Calendar(identifier:.gregorian)
        f.locale=Locale(identifier:language.isArabic ? "ar_SA" : language.rawValue)
        f.dateStyle = .full
        return f.string(from:date)
    }
    static func lines(_ date:Date = .now,language:SariLanguage = .selected)->[String] {
        switch mode {case .dual:return [hijri(date,language:language),gregorian(date,language:language)]
        case .hijri:return [hijri(date,language:language)];case .gregorian:return [gregorian(date,language:language)]}
    }
}
