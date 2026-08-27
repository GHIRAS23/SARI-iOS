import SwiftUI

struct TravelView: View {
    @StateObject private var profile = TravelProfileStore()
    @StateObject private var destinationWeather = WeatherStore()
    @State private var showProfile = false
    @State private var showHelp = false
    @State private var showChecklist = false
    @State private var showDestinationPicker = false
    private var language:SariLanguage { SariLanguage.selected }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors:[Color(.systemBackground),Color.accentColor.opacity(0.06),Color(.systemBackground)],startPoint:.top,endPoint:.bottom).ignoresSafeArea()
                ScrollView(showsIndicators:false) {
                    VStack(spacing:16) {
                        destinationHeader
                        preTripCard
                        countryInfo
                        destinationWeatherCard
                        missionAndEmergency
                        localApps
                        muslimTools
                        if profile.destination.hasDetailedData { foodCard }
                        helpButton
                        dataSafetyNote
                    }
                    .padding(18).padding(.bottom,30)
                }
            }
            .navigationTitle(SariStrings.t("travel",language))
            .toolbar { ToolbarItem(placement:.topBarLeading) { Button { showProfile=true } label:{ Image(systemName:"person.crop.circle") } } }
            .sheet(isPresented:$showProfile){TravelProfileSheet(profile:profile)}
            .sheet(isPresented:$showHelp){TravelHelpView(profile:profile)}
            .sheet(isPresented:$showChecklist){PreTripChecklistView(profile:profile)}
            .sheet(isPresented:$showDestinationPicker){
                CountryPickerView(title:SariUIStrings.text("destination",language),selectedCode:$profile.destinationCode,choices:destinationChoices)
            }
            .task(id:profile.destinationCode){
                let d=profile.destination
                guard d.hasDetailedData else { destinationWeather.snapshot=nil; return }
                await destinationWeather.load(latitude:d.latitude,longitude:d.longitude)
            }
        }
        .sariLanguageEnvironment(language)
    }

    private var destinationChoices:[CountryChoice] {
        TravelCatalog.destinations.map{CountryChoice(code:$0.code,flag:$0.flag,name:$0.name(language))}
    }

    private var destinationHeader: some View {
        VStack(alignment:language.isArabic ? .trailing:.leading,spacing:14) {
            HStack {
                Text(profile.destination.flag).font(.system(size:44))
                Spacer()
                VStack(alignment:language.isArabic ? .trailing:.leading,spacing:4) {
                    Text(SariUIStrings.text("destination",language)).font(.caption.bold()).foregroundStyle(.secondary)
                    Text(profile.destination.name(language)).font(.system(size:30,weight:.black,design:.rounded))
                    if TravelCatalog.capital(for:profile.destination,language:language) != "—" { Text(TravelCatalog.capital(for:profile.destination,language:language)).foregroundStyle(.secondary) }
                }
            }
            Button { showDestinationPicker=true } label:{
                HStack {
                    Image(systemName:"magnifyingglass")
                    Text(SariContentText.pick(language,[.ar:"تغيير الوجهة أو البحث بين الدول",.en:"Change destination or search countries",.tr:"Hedefi değiştir veya ülke ara",.ms:"Tukar destinasi atau cari negara",.id:"Ubah tujuan atau cari negara",.ja:"目的地を変更・国を検索",.zh:"更改目的地或搜索国家",.ru:"Изменить направление или найти страну",.fr:"Changer la destination ou rechercher un pays"]))
                    Spacer()
                    Image(systemName:language.isArabic ? "chevron.left":"chevron.right")
                }.frame(maxWidth:.infinity)
            }.buttonStyle(.bordered)
        }
        .padding(22).background(.regularMaterial,in:RoundedRectangle(cornerRadius:28,style:.continuous))
    }

    private var preTripCard: some View {
        Button{showChecklist=true}label:{
            HStack(spacing:14){
                Image(systemName:"checklist.checked").font(.title2).foregroundStyle(Color.accentColor)
                VStack(alignment:language.isArabic ? .trailing:.leading,spacing:5){
                    Text(SariUIStrings.text("before_travel",language)).font(.headline).foregroundStyle(.primary)
                    Text(SariUIStrings.text("travel_prepare_desc",language)).font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth:.infinity,alignment:language.isArabic ? .trailing:.leading)
                Image(systemName:language.isArabic ? "chevron.left":"chevron.right").foregroundStyle(.secondary)
            }.padding(18).background(Color.accentColor.opacity(0.08),in:RoundedRectangle(cornerRadius:22,style:.continuous))
        }.buttonStyle(.plain)
    }

    private var countryInfo: some View {
        VStack(alignment:language.isArabic ? .trailing:.leading,spacing:2) {
            Text(SariStrings.t("countryInfo",language)).font(.title3.bold()).padding(.bottom,8)
            infoRow(SariUIStrings.text("currency",language),TravelCatalog.currencyText(for:profile.destination,language:language),"creditcard.fill")
            Divider()
            infoRow(SariUIStrings.text("language",language),TravelCatalog.languagesText(for:profile.destination,language:language),"character.bubble.fill")
            Divider()
            infoRow(SariUIStrings.text("timing",language),TravelCatalog.timeZoneText(for:profile.destination,language:language),"clock.fill")
            Divider()
            infoRow(SariUIStrings.text("electricity",language),profile.destination.plugsArabic,"powerplug.fill")
            if !profile.destination.hasDetailedData { Text(genericDataNote).font(.caption).foregroundStyle(.secondary).padding(.top,8) }
        }.travelCard()
    }

    @ViewBuilder private var destinationWeatherCard: some View {
        VStack(alignment:language.isArabic ? .trailing:.leading,spacing:12) {
            HStack { Text(SariUIStrings.text("destination_weather",language)).font(.title3.bold()); Spacer(); Image(systemName:"cloud.sun.fill").symbolRenderingMode(.multicolor) }
            if !profile.destination.hasDetailedData {
                Label(genericDataNote,systemImage:"info.circle").font(.subheadline).foregroundStyle(.secondary)
            } else if let w=destinationWeather.snapshot {
                HStack { Text("\(Int(w.temperature.rounded()))°").font(.system(size:40,weight:.black)); Text(w.condition(language)).foregroundStyle(.secondary); Spacer(); Text(SariUIStrings.format("feels_like",language,["value":"\(Int(w.apparentTemperature.rounded()))"])).font(.subheadline) }
                Label(w.clothingAdvice(language),systemImage:"tshirt.fill").font(.subheadline).foregroundStyle(.secondary)
                if let alert=w.smartAlert(language){Label(alert,systemImage:"exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)}
            } else if destinationWeather.isLoading { HStack{ProgressView();Text(SariUIStrings.text("updating_destination_weather",language))} }
            else { Text(SariUIStrings.text("weather_unavailable",language)).foregroundStyle(.secondary) }
        }.travelCard()
    }

    private var missionAndEmergency: some View {
        VStack(alignment:language.isArabic ? .trailing:.leading,spacing:10) {
            Text(SariUIStrings.text("important_numbers2",language)).font(.title3.bold())
            if let nationality=profile.nationality {
                infoHeader(icon:"building.columns.fill",title:SariUIStrings.format("embassy_of",language,["country":"\(nationality.name(language)) \(nationality.flag)"]))
                if let mission=TravelCatalog.mission(for:nationality.code,in:profile.destination.code) {
                    infoValueRow(icon:"building.2.fill",title:saudiAssistanceLabel,value:mission.addressArabic ?? "")
                    if let phone=mission.phone { contactRow(icon:"phone.fill",title:SariUIStrings.text("call",language),number:phone) }
                    if let source=mission.officialSource,let url=URL(string:source){Link(destination:url){infoLinkLabel(officialSourceLabel,"checkmark.shield.fill")}}
                    if nationality.code == "SA" { Link(destination:TravelCatalog.saudiMissionsURL){infoLinkLabel(mofaDirectoryLabel,"building.columns.fill")} }
                } else if nationality.code == "SA" {
                    Link(destination:TravelCatalog.saudiMofaURL){infoLinkLabel(mofaDirectoryLabel,"safari.fill")}
                    Text(SariContentText.pick(language,[.ar:"إذا لم تكن بيانات البعثة مخزنة، افتح موقع وزارة الخارجية الرسمي بدل عرض رقم غير موثوق.",.en:"If mission details are not stored, use the official Ministry of Foreign Affairs site rather than an unverified number."])).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(SariUIStrings.text("no_verified_mission_cached",language)).font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Button{showProfile=true}label:{Label(SariUIStrings.text("travel_nationality_hint",language),systemImage:"flag.fill").frame(maxWidth:.infinity,alignment:language.isArabic ? .trailing:.leading)}
            }

            Divider().padding(.vertical,4)
            infoHeader(icon:"sos.circle.fill",title:SariUIStrings.format("emergency_in",language,["country":profile.destination.name(language)]))
            let contacts=TravelCatalog.emergencyContacts(for:profile.destination,language:language)
            if contacts.isEmpty {
                Text(emergencyFallbackNote).font(.caption).foregroundStyle(.secondary)
                Link(destination:TravelCatalog.ituEmergencyURL){infoLinkLabel(ituEmergencyLabel,"checkmark.shield.fill")}
            } else {
                ForEach(contacts){contact in contactRow(icon:contact.systemImage,title:contact.service,number:contact.number)}
            }
        }.travelCard()
    }

    private var localApps: some View {
        VStack(alignment:language.isArabic ? .trailing:.leading,spacing:10) {
            Text(SariStrings.t("localApps",language)).font(.title3.bold())
            if profile.destination.apps.isEmpty {
                Text(SariContentText.pick(language,[.ar:"لم تُخزن توصيات تطبيقات موثقة لهذه الوجهة بعد.",.en:"No curated local app recommendations are stored for this destination yet."])).font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(profile.destination.apps){app in
                    HStack(spacing:12){
                        Image(systemName:app.systemImage).foregroundStyle(Color.accentColor).frame(width:30)
                        VStack(alignment:language.isArabic ? .trailing:.leading,spacing:3){Text(app.name).font(.headline);Text(TravelCatalog.appNote(app,language:language)).font(.caption).foregroundStyle(.secondary)}
                            .frame(maxWidth:.infinity,alignment:language.isArabic ? .trailing:.leading)
                    }.padding(.vertical,6)
                    if app.id != profile.destination.apps.last?.id { Divider() }
                }
            }
            Text(SariUIStrings.text("verify_app_publisher",language)).font(.caption2).foregroundStyle(.secondary)
        }.travelCard()
    }

    private var muslimTools: some View {
        VStack(alignment:language.isArabic ? .trailing:.leading,spacing:6){
            Text(SariUIStrings.text("travel_muslim_tools",language)).font(.title3.bold()).padding(.bottom,4)
            NavigationLink(destination:PrayerTimesView()){travelLink(SariUIStrings.text("prayer_times",language),"clock.fill")}
            NavigationLink(destination:QiblaView()){travelLink(SariUIStrings.text("qibla",language),"location.north.circle.fill")}
            NavigationLink(destination:AdhkarView()){travelLink(SariUIStrings.text("travel_adhkar",language),"hands.sparkles.fill")}
            NavigationLink(destination:FiqhAssistantView()){travelLink(SariUIStrings.text("travel_fiqh_ask",language),"sparkles")}
        }.travelCard()
    }

    private var foodCard: some View {
        NavigationLink(destination:PlacesLocalView(destination:profile.destination)){
            HStack(spacing:14){
                Image(systemName:"fork.knife.circle.fill").font(.title2).foregroundStyle(Color.accentColor)
                VStack(alignment:language.isArabic ? .trailing:.leading,spacing:5){Text(profile.destination.muslimMajority ? SariUIStrings.text("featured_restaurants",language):SariUIStrings.text("halal_nearby",language)).font(.headline).foregroundStyle(.primary);Text(SariUIStrings.text("places_live_desc",language)).font(.subheadline).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:language.isArabic ? .trailing:.leading)
                Image(systemName:language.isArabic ? "chevron.left":"chevron.right").font(.caption).foregroundStyle(.secondary)
            }.travelCard()
        }.buttonStyle(.plain)
    }

    private var helpButton: some View { Button{showHelp=true}label:{Label(SariUIStrings.text("need_help",language),systemImage:"sos.circle.fill").font(.headline).frame(maxWidth:.infinity).padding(.vertical,15)}.buttonStyle(.borderedProminent).tint(.red) }
    private var dataSafetyNote: some View { Text(SariUIStrings.text("sensitive_data_note",language)).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal,8) }
    private var genericDataNote:String { SariContentText.pick(language,[.ar:"الدولة متاحة للاختيار، لكن التفاصيل المحلية لهذه الوجهة لم تُراجع وتُخزن بعد.",.en:"This country is selectable, but its local detail pack has not yet been curated.",.tr:"Bu ülke seçilebilir, ancak yerel ayrıntıları henüz derlenmedi.",.ms:"Negara ini boleh dipilih, tetapi butiran tempatannya belum disusun.",.id:"Negara ini dapat dipilih, tetapi detail lokalnya belum dikurasi.",.ja:"この国は選択できますが、現地情報はまだ整備されていません。",.zh:"该国家可选择，但本地详细数据尚未整理。",.ru:"Страну можно выбрать, но локальные данные ещё не подготовлены.",.fr:"Ce pays peut être sélectionné, mais ses données locales ne sont pas encore vérifiées."]) }
    private var officialSourceLabel:String { SariContentText.pick(language,[.ar:"فتح المصدر الرسمي",.en:"Open official source",.tr:"Resmî kaynağı aç",.ms:"Buka sumber rasmi",.id:"Buka sumber resmi",.ja:"公式情報を開く",.zh:"打开官方来源",.ru:"Открыть официальный источник",.fr:"Ouvrir la source officielle"]) }
    private var mofaDirectoryLabel:String { SariContentText.pick(language,[.ar:"وزارة الخارجية السعودية — البعثات",.en:"Saudi Ministry of Foreign Affairs — missions",.tr:"Suudi Dışişleri — temsilcilikler",.ms:"Kementerian Luar Saudi — misi",.id:"Kementerian Luar Negeri Saudi — misi",.ja:"サウジ外務省 — 在外公館",.zh:"沙特外交部 — 驻外使团",.ru:"МИД Саудовской Аравии — представительства",.fr:"Ministère saoudien des Affaires étrangères — missions"]) }
    private var saudiAssistanceLabel:String { SariContentText.pick(language,[.ar:"وزارة الخارجية السعودية — مساعدة السعوديين في الخارج",.en:"Saudi MOFA — assistance for Saudis abroad",.tr:"Suudi Dışişleri — yurt dışındaki Suudilere yardım",.ms:"Kementerian Luar Saudi — bantuan rakyat Saudi di luar negara",.id:"Kementerian Luar Saudi — bantuan warga Saudi di luar negeri",.ja:"サウジ外務省 — 海外のサウジ国民支援",.zh:"沙特外交部 — 海外沙特公民援助",.ru:"МИД Саудовской Аравии — помощь гражданам за рубежом",.fr:"Affaires étrangères saoudiennes — aide aux Saoudiens à l’étranger"]) }
    private var emergencyFallbackNote:String { SariContentText.pick(language,[.ar:"أرقام الطوارئ تختلف حسب الدولة والخدمة. استخدم المصدر الرسمي المحلي عند الحاجة.",.en:"Emergency numbers vary by country and service. Use the official local source when needed.",.tr:"Acil numaralar ülkeye ve hizmete göre değişir. Gerektiğinde resmî yerel kaynağı kullanın.",.ms:"Nombor kecemasan berbeza mengikut negara dan perkhidmatan. Gunakan sumber rasmi tempatan apabila perlu.",.id:"Nomor darurat berbeda menurut negara dan layanan. Gunakan sumber resmi setempat saat diperlukan.",.ja:"緊急番号は国やサービスにより異なります。必要時は現地の公式情報を確認してください。",.zh:"紧急号码因国家和服务而异，需要时请使用当地官方来源。",.ru:"Экстренные номера зависят от страны и службы. При необходимости используйте официальный местный источник.",.fr:"Les numéros d’urgence varient selon le pays et le service. Utilisez la source officielle locale si nécessaire."]) }
    private var ituEmergencyLabel:String { SariContentText.pick(language,[.ar:"قاعدة أرقام الطوارئ الرسمية — ITU",.en:"Official emergency-number database — ITU",.tr:"Resmî acil numara veritabanı — ITU",.ms:"Pangkalan nombor kecemasan rasmi — ITU",.id:"Basis nomor darurat resmi — ITU",.ja:"公式緊急番号データベース — ITU",.zh:"官方紧急号码数据库 — ITU",.ru:"Официальная база экстренных номеров — ITU",.fr:"Base officielle des numéros d’urgence — UIT"]) }

    private func infoRow(_ title:String,_ value:String,_ icon:String)->some View { HStack(spacing:12){Image(systemName:icon).foregroundStyle(Color.accentColor).frame(width:28);Text(title).font(.subheadline).foregroundStyle(.secondary);Spacer();Text(value).font(.subheadline.bold()).multilineTextAlignment(language.isArabic ? .trailing:.leading)}.padding(.vertical,8) }
    private func infoHeader(icon:String,title:String)->some View { HStack(spacing:10){Image(systemName:icon).foregroundStyle(Color.accentColor).frame(width:28);Text(title).font(.headline);Spacer()}.padding(.vertical,4) }
    private func infoValueRow(icon:String,title:String,value:String)->some View { HStack(alignment:.top,spacing:10){Image(systemName:icon).foregroundStyle(Color.accentColor).frame(width:28);VStack(alignment:language.isArabic ? .trailing:.leading,spacing:3){Text(title).font(.subheadline.bold());if !value.isEmpty{Text(value).font(.caption).foregroundStyle(.secondary)}}.frame(maxWidth:.infinity,alignment:language.isArabic ? .trailing:.leading)}.padding(.vertical,5) }
    private func contactRow(icon:String,title:String,number:String)->some View { HStack(spacing:10){Image(systemName:icon).foregroundStyle(.red).frame(width:28);Text(title).font(.subheadline);Spacer();if let url=URL(string:"tel:\(number)"){Link(number,destination:url).font(.system(.body,design:.monospaced).weight(.bold))}else{Text(number).font(.system(.body,design:.monospaced).weight(.bold))}}.padding(.vertical,8) }
    private func infoLinkLabel(_ title:String,_ icon:String)->some View { HStack{Image(systemName:icon);Text(title);Spacer();Image(systemName:"arrow.up.right.square")}.frame(maxWidth:.infinity).padding(.vertical,8) }
    private func travelLink(_ title:String,_ icon:String)->some View { HStack{Image(systemName:icon).foregroundStyle(Color.accentColor).frame(width:28);Text(title).fontWeight(.semibold).foregroundStyle(.primary);Spacer();Image(systemName:language.isArabic ? "chevron.left":"chevron.right").font(.caption).foregroundStyle(.secondary)}.padding(.vertical,9) }
}

private struct CountryChoice: Identifiable, Hashable { let code:String;let flag:String;let name:String;var id:String{code} }

private struct CountryPickerView: View {
    let title:String
    @Binding var selectedCode:String
    let choices:[CountryChoice]
    @Environment(\.dismiss) private var dismiss
    @State private var query=""
    private var language:SariLanguage{SariLanguage.selected}
    private var filtered:[CountryChoice]{
        let q=query.trimmingCharacters(in:.whitespacesAndNewlines)
        return q.isEmpty ? choices : choices.filter{$0.name.localizedCaseInsensitiveContains(q) || $0.code.localizedCaseInsensitiveContains(q)}
    }
    var body:some View{
        NavigationStack{
            List(filtered){item in
                Button{selectedCode=item.code;dismiss()}label:{
                    HStack{Text(item.flag).font(.title2);Text(item.name).foregroundStyle(.primary);Spacer();if selectedCode==item.code{Image(systemName:"checkmark.circle.fill").foregroundStyle(Color.accentColor)}}
                }
            }
            .searchable(text:$query,prompt:SariContentText.pick(language,[.ar:"ابحث عن دولة",.en:"Search countries",.tr:"Ülke ara",.ms:"Cari negara",.id:"Cari negara",.ja:"国を検索",.zh:"搜索国家",.ru:"Поиск страны",.fr:"Rechercher un pays"]))
            .navigationTitle(title)
            .toolbar{ToolbarItem(placement:.cancellationAction){Button(SariUIStrings.text("close",language)){dismiss()}}}
        }.sariLanguageEnvironment(language)
    }
}

private struct TravelProfileSheet: View {
    @ObservedObject var profile:TravelProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var showNationality=false
    @State private var showDestination=false
    private var language:SariLanguage{SariLanguage.selected}
    private var nationalityChoices:[CountryChoice]{TravelCatalog.nationalities.map{.init(code:$0.code,flag:$0.flag,name:$0.name(language))}}
    private var destinationChoices:[CountryChoice]{TravelCatalog.destinations.map{.init(code:$0.code,flag:$0.flag,name:$0.name(language))}}
    var body:some View{
        NavigationStack{
            Form{
                Section(SariUIStrings.text("nationality",language)){
                    Button{showNationality=true}label:{selectionRow(code:profile.nationalityCode,choices:nationalityChoices,empty:SariUIStrings.text("choose_nationality",language))}
                }
                Section(SariUIStrings.text("trip",language)){
                    Button{showDestination=true}label:{selectionRow(code:profile.destinationCode,choices:destinationChoices,empty:SariUIStrings.text("destination",language))}
                    DatePicker(SariUIStrings.text("trip_date",language),selection:Binding(get:{profile.tripDate ?? Date()},set:{profile.tripDate=$0}),displayedComponents:.date)
                    Button(SariUIStrings.text("remove_trip_date",language),role:.destructive){profile.tripDate=nil}
                }
                Section{Text(SariUIStrings.text("nationality_privacy",language)).font(.caption)}
            }
            .navigationTitle(SariUIStrings.text("travel_setup",language))
            .toolbar{ToolbarItem(placement:.confirmationAction){Button(SariUIStrings.text("done",language)){dismiss()}}}
            .sheet(isPresented:$showNationality){CountryPickerView(title:SariUIStrings.text("nationality",language),selectedCode:$profile.nationalityCode,choices:nationalityChoices)}
            .sheet(isPresented:$showDestination){CountryPickerView(title:SariUIStrings.text("destination",language),selectedCode:$profile.destinationCode,choices:destinationChoices)}
        }.sariLanguageEnvironment(language)
    }
    private func selectionRow(code:String,choices:[CountryChoice],empty:String)->some View{let choice=choices.first{$0.code==code};return HStack{if let choice{Text(choice.flag);Text(choice.name).foregroundStyle(.primary)}else{Text(empty).foregroundStyle(.secondary)};Spacer();Image(systemName:"magnifyingglass").foregroundStyle(.secondary)}}
}

private struct PreTripChecklistView:View {
    @ObservedObject var profile:TravelProfileStore
    @Environment(\.dismiss) private var dismiss
    private var language:SariLanguage{SariLanguage.selected}
    var body:some View{NavigationStack{List(TravelCatalog.checklist(nationality:profile.nationality,destination:profile.destination,tripDate:profile.tripDate)){item in HStack(spacing:12){Image(systemName:item.systemImage).foregroundStyle(Color.accentColor).frame(width:32);VStack(alignment:language.isArabic ? .trailing:.leading,spacing:4){Text(item.title).font(.headline);Text(item.detail).font(.subheadline).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:language.isArabic ? .trailing:.leading)}}.navigationTitle(SariUIStrings.text("before_travel",language)).toolbar{ToolbarItem(placement:.confirmationAction){Button(SariUIStrings.text("done",language)){dismiss()}}}}.sariLanguageEnvironment(language)}
}

private struct TravelHelpView: View {
    @ObservedObject var profile: TravelProfileStore
    @Environment(\.dismiss) private var dismiss
    private var language: SariLanguage { SariLanguage.selected }

    var body: some View {
        NavigationStack {
            List {
                Section(SariUIStrings.format("emergency_in", language, ["country": profile.destination.name(language)])) {
                    let contacts = TravelCatalog.emergencyContacts(for: profile.destination, language: language)
                    if contacts.isEmpty {
                        Text(SariContentText.pick(language,[.ar:"أرقام الطوارئ تختلف حسب الدولة والخدمة. استخدم المصدر الرسمي المحلي عند الحاجة.",.en:"Emergency numbers vary by country and service. Use the official local source when needed.",.tr:"Acil numaralar ülkeye ve hizmete göre değişir; resmî yerel kaynağı kullanın.",.ms:"Nombor kecemasan berbeza mengikut negara dan perkhidmatan; gunakan sumber rasmi tempatan.",.id:"Nomor darurat berbeda menurut negara dan layanan; gunakan sumber resmi setempat.",.ja:"緊急番号は国やサービスにより異なります。現地の公式情報を確認してください。",.zh:"紧急号码因国家和服务而异，请使用当地官方来源。",.ru:"Экстренные номера зависят от страны и службы; используйте официальный местный источник.",.fr:"Les numéros d’urgence varient selon le pays et le service ; utilisez la source officielle locale."]))
                            .foregroundStyle(.secondary)
                        Link(SariContentText.pick(language,[.ar:"فتح قاعدة أرقام الطوارئ الرسمية — ITU",.en:"Open official emergency-number database — ITU",.tr:"Resmî acil numara veritabanını aç — ITU",.ms:"Buka pangkalan nombor kecemasan rasmi — ITU",.id:"Buka basis nomor darurat resmi — ITU",.ja:"公式緊急番号データベースを開く — ITU",.zh:"打开官方紧急号码数据库 — ITU",.ru:"Открыть официальную базу экстренных номеров — ITU",.fr:"Ouvrir la base officielle des numéros d’urgence — UIT"]), destination: TravelCatalog.ituEmergencyURL)
                    } else {
                        ForEach(contacts) { contact in
                            HStack(spacing:12) {
                                Image(systemName: contact.systemImage).foregroundStyle(.red).frame(width:28)
                                Text(contact.service)
                                Spacer()
                                if let url = URL(string: "tel:\(contact.number)") {
                                    Link(contact.number, destination: url).font(.system(.body,design:.monospaced).weight(.semibold))
                                } else {
                                    Text(contact.number).font(.system(.body,design:.monospaced).weight(.semibold))
                                }
                            }.padding(.vertical,4)
                        }
                    }
                }

                Section(SariUIStrings.text("nationality", language)) {
                    if let nationality = profile.nationality {
                        Text("\(nationality.flag) \(nationality.name(language))")

                        if let mission = TravelCatalog.mission(for: nationality.code, in: profile.destination.code) {
                            Text(SariContentText.pick(language,[.ar:"وزارة الخارجية السعودية — مساعدة السعوديين في الخارج",.en:"Saudi MOFA — assistance for Saudis abroad",.tr:"Suudi Dışişleri — yurt dışındaki Suudilere yardım",.ms:"Kementerian Luar Saudi — bantuan rakyat Saudi di luar negara",.id:"Kementerian Luar Saudi — bantuan warga Saudi di luar negeri",.ja:"サウジ外務省 — 海外のサウジ国民支援",.zh:"沙特外交部 — 海外沙特公民援助",.ru:"МИД Саудовской Аравии — помощь гражданам за рубежом",.fr:"Affaires étrangères saoudiennes — aide aux Saoudiens à l’étranger"]))
                            if let phone = mission.phone, let url = URL(string: "tel:\(phone)") {
                                Link(phone, destination: url)
                            }
                        } else if nationality.code == "SA" {
                            Link(
                                SariContentText.pick(language, [
                                    .ar: "فتح وزارة الخارجية السعودية",
                                    .en: "Open Saudi Ministry of Foreign Affairs"
                                ]),
                                destination: TravelCatalog.saudiMofaURL
                            )
                        } else {
                            Text(SariUIStrings.text("no_verified_mission", language))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(SariUIStrings.text("select_nationality_first", language))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(SariUIStrings.text("need_help", language))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(SariUIStrings.text("close", language)) { dismiss() }
                }
            }
        }
        .sariLanguageEnvironment(language)
    }
}

private extension View { func travelCard()->some View{self.frame(maxWidth:.infinity,alignment:.trailing).padding(18).background(.regularMaterial,in:RoundedRectangle(cornerRadius:22,style:.continuous)).overlay(RoundedRectangle(cornerRadius:22).stroke(Color.primary.opacity(0.045))) } }
