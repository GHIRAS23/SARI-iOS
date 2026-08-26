import SwiftUI

enum SariAppearance:String,CaseIterable,Identifiable {
    case system,light,dark
    var id:String{rawValue}
    var scheme:ColorScheme?{self == .dark ? .dark : self == .light ? .light : nil}
    func title(_ l:SariLanguage)->String {
        switch (self,l) {
        case (.system,.ar):return SariUIStrings.text("automatic", SariLanguage.selected); case (.light,.ar):return "فاتح"; case (.dark,.ar):return "داكن"
        case (.system,.tr):return "Sistem"; case (.light,.tr):return "Açık"; case (.dark,.tr):return "Koyu"
        case (.system,.fr):return "Système"; case (.light,.fr):return "Clair"; case (.dark,.fr):return "Sombre"
        case (.system,.ru):return "Система"; case (.light,.ru):return "Светлая"; case (.dark,.ru):return "Тёмная"
        case (.system,.ja):return "システム"; case (.light,.ja):return "ライト"; case (.dark,.ja):return "ダーク"
        case (.system,.zh):return "跟随系统"; case (.light,.zh):return "浅色"; case (.dark,.zh):return "深色"
        case (.system,.ms),(.system,.id):return "Sistem"; case (.light,.ms),(.light,.id):return "Cerah"; case (.dark,.ms),(.dark,.id):return "Gelap"
        default:return self == .system ? "System" : self == .light ? "Light" : "Dark"
        }
    }
}
