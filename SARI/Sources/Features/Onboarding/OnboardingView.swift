import SwiftUI

private struct OnboardingCopy {
    let title:String,subtitle:String
}
private struct OnboardingPage:Identifiable {
    let id:Int,icon:String,copies:[String:OnboardingCopy]
    func copy(_ l:SariLanguage)->OnboardingCopy { copies[l.rawValue] ?? copies["en"]! }
}
private let sariOnboardingPages:[OnboardingPage] = [
    .init(id:0,icon:"sparkles",copies:[
        "ar":.init(title:SariUIStrings.text("welcome", SariLanguage.selected),subtitle:SariUIStrings.text("onboarding_tagline",SariLanguage.selected)),
        "en":.init(title:"Welcome to SARI",subtitle:"Your Muslim companion at home and while traveling"),
        "tr":.init(title:"SARI'ye hoş geldiniz",subtitle:"Evde ve seyahatte Müslüman yol arkadaşınız"),
        "ms":.init(title:"Selamat datang ke SARI",subtitle:"Teman Muslim anda di negara sendiri dan ketika bermusafir"),
        "id":.init(title:"Selamat datang di SARI",subtitle:"Pendamping Muslim Anda di rumah dan saat bepergian"),
        "ja":.init(title:"SARIへようこそ",subtitle:"日常でも旅先でも、ムスリムのためのコンパニオン"),
        "zh":.init(title:"欢迎使用 SARI",subtitle:"无论在家还是旅行，陪伴穆斯林的实用助手"),
        "ru":.init(title:"Добро пожаловать в SARI",subtitle:"Ваш помощник-мусульманин дома и в путешествии"),
        "fr":.init(title:"Bienvenue dans SARI",subtitle:"Votre compagnon musulman au quotidien et en voyage")]),
    .init(id:1,icon:"moon.stars.fill",copies:[
        "ar":.init(title:SariUIStrings.text("onboarding_prayer_title",SariLanguage.selected),subtitle:SariUIStrings.text("onboarding_prayer_desc",SariLanguage.selected)),
        "en":.init(title:"Your prayer, wherever you are",subtitle:"Prayer times, Qibla, calculation methods and reminders in one place"),
        "tr":.init(title:"Nerede olursanız olun namazınız",subtitle:"Namaz vakitleri, kıble, hesaplama yöntemleri ve hatırlatmalar"),
        "ms":.init(title:"Solat anda di mana sahaja",subtitle:"Waktu solat, kiblat, kaedah pengiraan dan peringatan"),
        "id":.init(title:"Salat Anda di mana saja",subtitle:"Waktu salat, kiblat, metode perhitungan dan pengingat"),
        "ja":.init(title:"どこにいても礼拝を",subtitle:"礼拝時刻、キブラ、計算方式、通知をひとつに"),
        "zh":.init(title:"无论身在何处，安心礼拜",subtitle:"礼拜时间、朝向、计算方式与提醒集中呈现"),
        "ru":.init(title:"Молитва, где бы вы ни были",subtitle:"Время молитв, Кибла, методы расчёта и напоминания"),
        "fr":.init(title:"Votre prière, où que vous soyez",subtitle:"Horaires, Qibla, méthodes de calcul et rappels réunis")]),
    .init(id:2,icon:"book.closed.fill",copies:[
        "ar":.init(title:SariUIStrings.text("onboarding_quran_title",SariLanguage.selected),subtitle:SariUIStrings.text("onboarding_quran_desc", SariLanguage.selected)),
        "en":.init(title:"Quran and Adhkar with you",subtitle:"Mushaf, tafsir and daily remembrance in an experience suited to your language"),
        "tr":.init(title:"Kur'an ve zikirler yanınızda",subtitle:"Mushaf, tefsir ve günlük zikirler dilinize uygun bir deneyimde"),
        "ms":.init(title:"Al-Quran dan zikir bersama anda",subtitle:"Mushaf, tafsir dan zikir harian dalam pengalaman yang sesuai dengan bahasa anda"),
        "id":.init(title:"Al-Qur'an dan zikir bersama Anda",subtitle:"Mushaf, tafsir dan zikir harian dengan pengalaman sesuai bahasa Anda"),
        "ja":.init(title:"クルアーンとアズカールをいつもそばに",subtitle:"ムスハフ、タフスィール、日々のズィクルをあなたの言語で"),
        "zh":.init(title:"古兰经与赞念常伴左右",subtitle:"古兰经、经注与日常赞念，适配你的语言"),
        "ru":.init(title:"Коран и азкары всегда с вами",subtitle:"Мусхаф, тафсир и ежедневные поминания на удобном вам языке"),
        "fr":.init(title:"Coran et Adhkar avec vous",subtitle:"Mushaf, tafsir et invocations quotidiennes adaptés à votre langue")]),
    .init(id:3,icon:"airplane.departure",copies:[
        "ar":.init(title:SariUIStrings.text("onboarding_travel_title",SariLanguage.selected),subtitle:SariUIStrings.text("onboarding_travel_desc",SariLanguage.selected)),
        "en":.init(title:"Travel prepared",subtitle:"Destination, weather, what to wear, country information, trip requirements and useful local apps"),
        "tr":.init(title:"Hazırlıklı seyahat edin",subtitle:"Varış noktası, hava, kıyafet önerisi, ülke bilgileri, gereksinimler ve yerel uygulamalar"),
        "ms":.init(title:"Bermusafir dengan bersedia",subtitle:"Destinasi, cuaca, pakaian, maklumat negara, keperluan perjalanan dan aplikasi penting"),
        "id":.init(title:"Bepergian dengan siap",subtitle:"Tujuan, cuaca, pakaian, informasi negara, persyaratan perjalanan dan aplikasi penting"),
        "ja":.init(title:"準備万全で旅へ",subtitle:"目的地、天気、服装、国情報、旅行要件、重要な現地アプリ"),
        "zh":.init(title:"准备充分再出发",subtitle:"目的地、天气、穿着建议、国家信息、旅行要求与重要本地应用"),
        "ru":.init(title:"Путешествуйте подготовленными",subtitle:"Направление, погода, одежда, информация о стране, требования и полезные приложения"),
        "fr":.init(title:"Voyagez bien préparé",subtitle:"Destination, météo, tenue, informations pays, formalités et applications utiles")]),
    .init(id:4,icon:"building.columns.fill",copies:[
        "ar":.init(title:SariUIStrings.text("onboarding_embassy_title",SariLanguage.selected),subtitle:SariUIStrings.text("onboarding_embassy_desc",SariLanguage.selected)),
        "en":.init(title:"Important help while traveling",subtitle:"SARI can surface embassy or consulate information based on your nationality and destination"),
        "tr":.init(title:"Seyahatte önemli bilgiler",subtitle:"SARI, uyruğunuza ve varış noktanıza göre büyükelçilik veya konsolosluk bilgilerini gösterir"),
        "ms":.init(title:"Maklumat penting ketika bermusafir",subtitle:"SARI memaparkan maklumat kedutaan atau konsulat berdasarkan kewarganegaraan dan destinasi"),
        "id":.init(title:"Informasi penting saat bepergian",subtitle:"SARI menampilkan informasi kedutaan atau konsulat sesuai kewarganegaraan dan tujuan"),
        "ja":.init(title:"旅行中に役立つ重要情報",subtitle:"国籍と目的地に応じて大使館・領事館情報を表示"),
        "zh":.init(title:"旅行中的重要信息",subtitle:"SARI 可根据国籍和目的地显示使领馆信息"),
        "ru":.init(title:"Важная информация в поездке",subtitle:"SARI показывает данные посольства или консульства с учётом гражданства и направления"),
        "fr":.init(title:"Informations importantes en voyage",subtitle:"SARI affiche les informations d’ambassade ou de consulat selon votre nationalité et destination")]),
    .init(id:5,icon:"cpu.fill",copies:[
        "ar":.init(title:SariUIStrings.text("onboarding_fiqh_title",SariLanguage.selected),subtitle:SariUIStrings.text("onboarding_fiqh_desc",SariLanguage.selected)),
        "en":.init(title:"Your fiqh assistant on your device",subtitle:"Download the assistant pack so the model and sources can work locally on your device"),
        "tr":.init(title:"Fıkıh asistanınız cihazınızda",subtitle:"Model ve kaynakların cihazınızda yerel çalışması için asistan paketini indirin"),
        "ms":.init(title:"Pembantu fiqh pada peranti anda",subtitle:"Muat turun pek pembantu supaya model dan sumber berfungsi secara setempat"),
        "id":.init(title:"Asisten fikih di perangkat Anda",subtitle:"Unduh paket asisten agar model dan sumber dapat bekerja secara lokal"),
        "ja":.init(title:"端末上で動くフィクフ助手",subtitle:"アシスタントパックをダウンロードするとモデルと資料を端末内で利用できます"),
        "zh":.init(title:"设备端的教法助手",subtitle:"下载助手包后，模型与资料可在设备本地运行"),
        "ru":.init(title:"Фикх-помощник на вашем устройстве",subtitle:"Загрузите пакет, чтобы модель и источники работали локально"),
        "fr":.init(title:"Votre assistant fiqh sur l’appareil",subtitle:"Téléchargez le pack pour utiliser localement le modèle et les sources")])
]

struct SariOnboardingView:View {
    @Binding var completed:Bool
    @State private var page=0
    @State private var language:SariLanguage = .selected
    @State private var languageMenu=false
    private var rtl:Bool{language.isArabic}
    private func word(_ ar:String,_ en:String)->String {
        if language == .ar{return ar}
        let d:[SariLanguage:[String:String]]=[
            .tr:["Skip":"Atla","Next":"İleri","Start":"SARI'yi Başlat"],
            .ms:["Skip":"Langkau","Next":"Seterusnya","Start":"Mulakan SARI"],
            .id:["Skip":"Lewati","Next":"Berikutnya","Start":"Mulai SARI"],
            .ja:["Skip":"スキップ","Next":"次へ","Start":"SARIを始める"],
            .zh:["Skip":"跳过","Next":"下一步","Start":"开始使用 SARI"],
            .ru:["Skip":"Пропустить","Next":"Далее","Start":"Начать SARI"],
            .fr:["Skip":"Passer","Next":"Suivant","Start":"Commencer SARI"]]
        return d[language]?[en] ?? en
    }
    private func finish(){UserDefaults.standard.set(true,forKey:"sariOnboardingCompleted");completed=true}
    var body:some View {
        ZStack {
            LinearGradient(colors:[Color(red:0.025,green:0.22,blue:0.19),Color(red:0.04,green:0.38,blue:0.31),Color(red:0.82,green:0.68,blue:0.35)],startPoint:.topLeading,endPoint:.bottomTrailing).ignoresSafeArea()
            Circle().fill(.white.opacity(0.08)).frame(maxWidth:330,maxHeight:330).blur(radius:1).offset(x:150,y:-260)
            VStack(spacing:18) {
                HStack {
                    Menu {
                        ForEach(SariLanguage.allCases){l in Button(l.displayName){language=l;UserDefaults.standard.set(l.rawValue,forKey:"sariLanguage")}}
                    } label:{Label(language.displayName,systemImage:"globe").font(.subheadline.bold()).padding(.horizontal,13).padding(.vertical,9).background(.white.opacity(0.14),in:Capsule())}
                    Spacer()
                    Button(word(SariUIStrings.text("skip",SariLanguage.selected),"Skip")){finish()}.fontWeight(.semibold)
                }.foregroundStyle(.white)
                TabView(selection:$page) {
                    ForEach(sariOnboardingPages){p in
                        let c=p.copy(language)
                        VStack(spacing:26) {
                            Spacer()
                            ZStack {
                                RoundedRectangle(cornerRadius:42).fill(.white.opacity(0.13)).frame(minWidth:140,maxWidth:180,minHeight:140,maxHeight:180).rotationEffect(.degrees(8))
                                RoundedRectangle(cornerRadius:42).stroke(.white.opacity(0.24),lineWidth:1).frame(minWidth:140,maxWidth:180,minHeight:140,maxHeight:180).rotationEffect(.degrees(-5))
                                Image(systemName:p.icon).font(.system(size:68,weight:.medium)).foregroundStyle(.white)
                            }
                            VStack(spacing:12) {
                                Text(c.title).font(.system(size:32,weight:.black,design:.rounded)).multilineTextAlignment(.center)
                                Text(c.subtitle).font(.title3).foregroundStyle(.white.opacity(0.84)).multilineTextAlignment(.center).lineSpacing(5)
                            }.padding(.horizontal,12)
                            Spacer()
                        }.tag(p.id)
                    }
                }.tabViewStyle(.page(indexDisplayMode:.never))
                HStack(spacing:8){ForEach(0..<sariOnboardingPages.count,id:\.self){i in Capsule().fill(.white.opacity(i==page ? 1:0.3)).frame(width:i==page ? 26:8,height:8).animation(.spring(response:0.35),value:page)}}
                Button {
                    if page == sariOnboardingPages.count-1 {finish()} else {withAnimation{page+=1}}
                } label:{
                    HStack{Text(page == sariOnboardingPages.count-1 ? word(SariUIStrings.text("start_sari",SariLanguage.selected),"Start") : word(SariUIStrings.text("next", SariLanguage.selected),"Next")).fontWeight(.bold);Image(systemName:rtl ? "arrow.left":"arrow.right")}
                        .frame(maxWidth:.infinity).padding(.vertical,16).foregroundStyle(Color(red:0.03,green:0.29,blue:0.24)).background(.white,in:RoundedRectangle(cornerRadius:20))
                }
            }.padding(22)
            .environment(\.layoutDirection,rtl ? .rightToLeft:.leftToRight)
        }.preferredColorScheme(.dark)
    }
}
