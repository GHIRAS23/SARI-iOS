import SwiftUI

private enum AdhkarUI {
    static func text(_ key:String,_ language:SariLanguage)->String {
        let values:[String:[SariLanguage:String]]=[
            "title":[.ar:"الأذكار",.en:"Adhkar",.tr:"Zikirler",.ms:"Zikir",.id:"Zikir",.ja:"アズカール",.zh:"赞念",.ru:"Азкары",.fr:"Adhkar"],
            "repeat":[.ar:"التكرار",.en:"Repeat",.tr:"Tekrar",.ms:"Ulangan",.id:"Ulangi",.ja:"回数",.zh:"重复",.ru:"Повтор",.fr:"Répétition"],
            "source":[.ar:"الدليل والمصدر",.en:"Evidence & source",.tr:"Delil ve kaynak",.ms:"Dalil & sumber",.id:"Dalil & sumber",.ja:"根拠と出典",.zh:"依据与来源",.ru:"Доказательство и источник",.fr:"Preuve et source"],
            "complete":[.ar:"مكتمل ✓",.en:"Complete ✓",.tr:"Tamam ✓",.ms:"Selesai ✓",.id:"Selesai ✓",.ja:"完了 ✓",.zh:"完成 ✓",.ru:"Готово ✓",.fr:"Terminé ✓"],
            "tap":[.ar:"اضغط على الدائرة للعد",.en:"Tap the circle to count",.tr:"Saymak için daireye dokunun",.ms:"Tekan bulatan untuk mengira",.id:"Ketuk lingkaran untuk menghitung",.ja:"円をタップして数えます",.zh:"点击圆环计数",.ru:"Нажимайте на круг для счёта",.fr:"Touchez le cercle pour compter"],
            "reset":[.ar:"إعادة العداد",.en:"Reset counter",.tr:"Sayacı sıfırla",.ms:"Tetapkan semula",.id:"Atur ulang",.ja:"カウンターをリセット",.zh:"重置计数",.ru:"Сбросить счётчик",.fr:"Réinitialiser"],
            "items":[.ar:"ذكر",.en:"items",.tr:"zikir",.ms:"zikir",.id:"zikir",.ja:"項目",.zh:"项",.ru:"азкаров",.fr:"invocations"],
            "unavailable":[.ar:"تعذر تحميل الأذكار",.en:"Adhkar could not be loaded",.tr:"Zikirler yüklenemedi",.ms:"Zikir tidak dapat dimuatkan",.id:"Zikir tidak dapat dimuat",.ja:"アズカールを読み込めませんでした",.zh:"无法加载赞念",.ru:"Не удалось загрузить азкары",.fr:"Impossible de charger les adhkar"]
        ]
        return values[key]?[language] ?? values[key]?[.en] ?? key
    }
}

struct AdhkarView: View {
    @AppStorage("sariLanguage") private var savedLanguage=""
    private var language:SariLanguage { SariLanguage(rawValue:savedLanguage) ?? SariLanguage.selected }
    private let categories=AdhkarRepository.loadBundled()?.categories ?? []

    var body:some View {
        NavigationStack {
            Group {
                if categories.isEmpty {
                    ContentUnavailableView(AdhkarUI.text("unavailable",language),systemImage:"exclamationmark.triangle")
                } else {
                    ScrollView(showsIndicators:false) {
                        LazyVStack(spacing:12) {
                            ForEach(categories,id:\.id){cat in
                                NavigationLink { DhikrCategoryDataView(category:cat,language:language) } label:{
                                    HStack(spacing:14) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius:14).fill(SariDesign.emerald.opacity(0.11)).frame(width:48,height:48)
                                            Image(systemName:icon(cat.id)).font(.title3).foregroundStyle(SariDesign.emerald)
                                        }
                                        VStack(alignment:language.isArabic ? .trailing:.leading,spacing:4) {
                                            Text(cat.titles[language.rawValue] ?? cat.titles["en"] ?? cat.id).font(.headline).foregroundStyle(.primary)
                                            Text("\(cat.items.count) \(AdhkarUI.text("items",language))").font(.caption).foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth:.infinity,alignment:language.isArabic ? .trailing:.leading)
                                        Image(systemName:language.isArabic ? "chevron.left":"chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
                                    }
                                    .padding(16)
                                    .background(.regularMaterial,in:RoundedRectangle(cornerRadius:22,style:.continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }.padding(18)
                    }
                }
            }
            .navigationTitle(AdhkarUI.text("title",language))
            .sariLanguageEnvironment(language)
        }
    }

    private func icon(_ id:String)->String {
        ["morning":"sunrise.fill","evening":"sunset.fill","afterPrayer":"hands.sparkles.fill","sleep":"bed.double.fill","wake":"alarm.fill","travel":"airplane"].first(where:{$0.key==id})?.value ?? "heart.fill"
    }
}

private struct DhikrCategoryDataView: View {
    let category:AdhkarDataCategory
    let language:SariLanguage
    @AppStorage("adhkarFavorites") private var favoritesRaw=""
    @State private var counts:[String:Int]=[:]
    @State private var completedID:String?
    private var favorites:Set<String>{Set(favoritesRaw.split(separator:",").map(String.init))}

    var body:some View {
        ScrollView(showsIndicators:false) {
            LazyVStack(spacing:16) {
                ForEach(category.items,id:\.id){item in
                    dhikrCard(item)
                }
            }.padding(18)
        }
        .navigationTitle(category.titles[language.rawValue] ?? category.titles["en"] ?? category.id)
        .sariLanguageEnvironment(language)
        .sensoryFeedback(.success, trigger: completedID)
    }

    private func dhikrCard(_ item:AdhkarDataItem) -> some View {
        let count=counts[item.id] ?? 0
        let target=max(1,item.target)
        let progress=min(1,Double(count)/Double(target))
        let isDone=count>=target
        return VStack(alignment:language.isArabic ? .trailing:.leading,spacing:16) {
            HStack {
                Button{toggle(item.id)}label:{Image(systemName:favorites.contains(item.id) ? "heart.fill":"heart").foregroundStyle(favorites.contains(item.id) ? .red : .secondary)}
                    .buttonStyle(.plain)
                Spacer()
                Text("\(AdhkarUI.text("repeat",language)): \(target)").font(.caption.bold()).foregroundStyle(.secondary)
            }

            Text(item.arabic)
                .font(.system(size:22,weight:.medium,design:.rounded))
                .lineSpacing(7)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth:.infinity,alignment:.trailing)
                .environment(\.layoutDirection,.rightToLeft)
                .textSelection(.enabled)

            Button {
                let next=min(target,count+1)
                withAnimation(.snappy){counts[item.id]=next}
                if next == target { completedID=item.id }
            } label: {
                ZStack {
                    Circle().stroke(Color.accentColor.opacity(0.12),lineWidth:10)
                    Circle().trim(from:0,to:progress)
                        .stroke(isDone ? SariDesign.emerald : Color.accentColor,style:StrokeStyle(lineWidth:10,lineCap:.round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing:3) {
                        if isDone { Image(systemName:"checkmark").font(.title2.bold()) }
                        Text(isDone ? AdhkarUI.text("complete",language) : "\(count)/\(target)")
                            .font(isDone ? .caption.bold() : .title2.bold())
                    }
                    .foregroundStyle(isDone ? SariDesign.emerald : Color.accentColor)
                }
                .frame(width:118,height:118)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth:.infinity)
            .accessibilityLabel(AdhkarUI.text("tap",language))

            HStack {
                Text(AdhkarUI.text("tap",language)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if count > 0 {
                    Button(AdhkarUI.text("reset",language)) { withAnimation{counts[item.id]=0} }
                        .font(.caption.bold())
                }
            }

            if let meaning=item.meanings[language.rawValue] ?? item.meanings["en"], !meaning.isEmpty {
                Divider(); Text(meaning).font(.subheadline).foregroundStyle(.secondary)
            }
            if !item.transliteration.isEmpty && !language.isArabic {
                Text(item.transliteration).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
            if let source=item.source {
                Divider()
                DisclosureGroup(AdhkarUI.text("source",language)) {
                    VStack(alignment:.trailing,spacing:8) {
                        if let evidence=source.evidence_ar,!evidence.isEmpty { Text(evidence).font(.footnote).lineSpacing(4).textSelection(.enabled) }
                        if let collection=source.collection { Label(collection,systemImage:"doc.text").font(.caption).foregroundStyle(.secondary) }
                        if let note=source.note_ar { Text(note).font(.caption2).foregroundStyle(.secondary) }
                    }
                    .padding(.top,8)
                    .environment(\.layoutDirection,.rightToLeft)
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth:.infinity,alignment:language.isArabic ? .trailing:.leading)
        .padding(18)
        .background(.regularMaterial,in:RoundedRectangle(cornerRadius:24,style:.continuous))
        .overlay(RoundedRectangle(cornerRadius:24).stroke(Color.primary.opacity(0.05)))
    }

    private func toggle(_ id:String){
        var f=favorites
        if f.contains(id){f.remove(id)}else{f.insert(id)}
        favoritesRaw=f.sorted().joined(separator:",")
    }
}
