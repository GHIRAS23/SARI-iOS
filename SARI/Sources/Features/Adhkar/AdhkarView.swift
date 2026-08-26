import SwiftUI

private enum AdhkarUI {
    static let strings:[String:[String:String]]=[
        "adhkar":["ar":SariUIStrings.text("adhkar", SariLanguage.selected),"en":"Adhkar","tr":"Zikirler","ms":"Zikir","id":"Zikir","ja":"アズカール","zh":"赞念","ru":"Азкары","fr":"Adhkar"],
        "repeat":["ar":"التكرار","en":"Repeat","tr":"Tekrar","ms":"Ulangan","id":"Ulangi","ja":"回数","zh":"重复","ru":"Повтор","fr":"Répétition"],
        "meaning":["ar":"المعنى","en":"Meaning","tr":"Anlamı","ms":"Makna","id":"Makna","ja":"意味","zh":"含义","ru":"Смысл","fr":"Sens"],
        "pron":["ar":"النطق النصي","en":"Transliteration","tr":"Okunuş","ms":"Transliterasi","id":"Transliterasi","ja":"ローマ字読み","zh":"拉丁转写","ru":"Транслитерация","fr":"Translittération"],
        "done":["ar":"تم ✓","en":"Done ✓","tr":"Tamam ✓","ms":"Selesai ✓","id":"Selesai ✓","ja":"完了 ✓","zh":"完成 ✓","ru":"Готово ✓","fr":"Terminé ✓"],
        "unavailable":["ar":"تعذر تحميل الأذكار","en":"Adhkar could not be loaded","tr":"Zikirler yüklenemedi","ms":"Zikir tidak dapat dimuatkan","id":"Zikir tidak dapat dimuat","ja":"アズカールを読み込めませんでした","zh":"无法加载赞念","ru":"Не удалось загрузить азкары","fr":"Impossible de charger les adhkar"]
    ]
    static func text(_ key:String,_ l:SariLanguage)->String { strings[key]?[l.rawValue] ?? strings[key]?["en"] ?? key }
}
struct AdhkarView:View {
    @AppStorage("sariLanguage") private var savedLanguage=""
    private var language:SariLanguage { SariLanguage(rawValue:savedLanguage) ?? SariLanguage.selected }
    private let categories=AdhkarRepository.loadBundled()?.categories ?? []
    var body:some View {
        NavigationStack {
            Group {
                if categories.isEmpty {
                    ContentUnavailableView(AdhkarUI.text("unavailable",language),systemImage:"exclamationmark.triangle")
                } else {
                    List(categories,id:\.id){cat in
                        NavigationLink { DhikrCategoryDataView(category:cat,language:language) } label:{
                            HStack {
                                Image(systemName:icon(cat.id)).foregroundStyle(SariDesign.emerald)
                                VStack(alignment:language.isArabic ? .trailing:.leading) {
                                    Text(cat.titles[language.rawValue] ?? cat.titles["en"] ?? cat.id).font(.headline)
                                    Text("\(cat.items.count)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(AdhkarUI.text("adhkar",language))
            .environment(\.layoutDirection,language.isArabic ? .rightToLeft:.leftToRight)
        }
    }
    private func icon(_ id:String)->String {
        ["morning":"sunrise.fill","evening":"sunset.fill","afterPrayer":"hands.sparkles.fill","sleep":"bed.double.fill","wake":"alarm.fill","travel":"airplane"].first(where:{$0.key==id})?.value ?? "heart.fill"
    }
}
private struct DhikrCategoryDataView:View {
    let category:AdhkarDataCategory;let language:SariLanguage
    @AppStorage("adhkarFavorites") private var favoritesRaw=""
    @State private var counts:[String:Int]=[:]
    private var favorites:Set<String>{Set(favoritesRaw.split(separator:",").map(String.init))}
    var body:some View {
        ScrollView {
            LazyVStack(spacing:14) {
                ForEach(category.items,id:\.id){item in
                    SariCard {
                        VStack(alignment:language.isArabic ? .trailing:.leading,spacing:14) {
                            HStack {
                                Button{toggle(item.id)}label:{Image(systemName:favorites.contains(item.id) ? "heart.fill":"heart")}
                                Spacer()
                                Text("\(AdhkarUI.text("repeat",language)) \(item.target)").font(.caption.bold()).foregroundStyle(.secondary)
                            }
                            Text(item.arabic).font(.title3).multilineTextAlignment(.trailing).frame(maxWidth:.infinity,alignment:.trailing).environment(\.layoutDirection,.rightToLeft)
                            if !language.isArabic {
                                Divider()
                                Text(AdhkarUI.text("pron",language)).font(.caption.bold()).foregroundStyle(.secondary)
                                Text(item.transliteration).font(.subheadline).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)
                                Text(AdhkarUI.text("meaning",language)).font(.caption.bold()).foregroundStyle(.secondary)
                                Text(item.meanings[language.rawValue] ?? item.meanings["en"] ?? "").frame(maxWidth:.infinity,alignment:.leading)
                            }
                            Button {
                                counts[item.id]=min(item.target,(counts[item.id] ?? 0)+1)
                            } label:{
                                Text((counts[item.id] ?? 0)>=item.target ? AdhkarUI.text("done",language) : "\((counts[item.id] ?? 0))/\(item.target)")
                                    .frame(maxWidth:.infinity).padding(.vertical,10)
                            }.buttonStyle(.borderedProminent).tint(SariDesign.emerald)
                        }
                    }
                }
            }.padding()
        }
        .navigationTitle(category.titles[language.rawValue] ?? category.titles["en"] ?? category.id)
        .environment(\.layoutDirection,language.isArabic ? .rightToLeft:.leftToRight)
    }
    private func toggle(_ id:String){
        var f=favorites
        if f.contains(id){f.remove(id)}else{f.insert(id)}
        favoritesRaw=f.sorted().joined(separator:",")
    }
}
