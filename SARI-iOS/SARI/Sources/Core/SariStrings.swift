import Foundation

enum SariStrings {
    private static let table:[String:[String:String]]=[
        "home":["ar":"الرئيسية","en":"Home","tr":"Ana Sayfa","ms":"Utama","id":"Beranda","ja":"ホーム","zh":"首页","ru":"Главная","fr":"Accueil"],
        "quran":["ar":"القرآن","en":"Quran","tr":"Kur'an","ms":"Al-Quran","id":"Al-Qur'an","ja":"クルアーン","zh":"古兰经","ru":"Коран","fr":"Coran"],
        "ask":["ar":"اسأل ساري","en":"Ask SARI","tr":"SARI'ye Sor","ms":"Tanya SARI","id":"Tanya SARI","ja":"SARIに質問","zh":"询问 SARI","ru":"Спросить SARI","fr":"Demander à SARI"],
        "travel":["ar":"السفر","en":"Travel","tr":"Seyahat","ms":"Perjalanan","id":"Perjalanan","ja":"旅行","zh":"旅行","ru":"Путешествие","fr":"Voyage"],
        "more":["ar":"المزيد","en":"More","tr":"Daha Fazla","ms":"Lagi","id":"Lainnya","ja":"その他","zh":"更多","ru":"Ещё","fr":"Plus"],
        "settings":["ar":"الإعدادات","en":"Settings","tr":"Ayarlar","ms":"Tetapan","id":"Pengaturan","ja":"設定","zh":"设置","ru":"Настройки","fr":"Réglages"],
        "inCountry":["ar":"في بلدي","en":"At home","tr":"Ülkemde","ms":"Di negara saya","id":"Di negara saya","ja":"自国","zh":"在本国","ru":"В своей стране","fr":"Dans mon pays"],
        "traveler":["ar":"أنا مسافر","en":"I'm traveling","tr":"Seyahatteyim","ms":"Saya bermusafir","id":"Saya bepergian","ja":"旅行中","zh":"我在旅行","ru":"Я путешествую","fr":"Je voyage"],
        "nextPrayer":["ar":"الصلاة القادمة","en":"Next prayer","tr":"Sonraki namaz","ms":"Solat seterusnya","id":"Salat berikutnya","ja":"次の礼拝","zh":"下一次礼拜","ru":"Следующая молитва","fr":"Prochaine prière"],
        "qibla":["ar":"القبلة","en":"Qibla","tr":"Kıble","ms":"Kiblat","id":"Kiblat","ja":"キブラ","zh":"朝向","ru":"Кибла","fr":"Qibla"],
        "weather":["ar":"طقس اليوم","en":"Today's weather","tr":"Bugünün havası","ms":"Cuaca hari ini","id":"Cuaca hari ini","ja":"今日の天気","zh":"今日天气","ru":"Погода сегодня","fr":"Météo du jour"],
        "clothes":["ar":"لباس اليوم","en":"What to wear","tr":"Bugün ne giyilmeli","ms":"Pakaian hari ini","id":"Pakaian hari ini","ja":"今日の服装","zh":"今日穿着","ru":"Что надеть","fr":"Tenue du jour"],
        "adhkar":["ar":"الأذكار","en":"Adhkar","tr":"Zikirler","ms":"Zikir","id":"Zikir","ja":"アズカール","zh":"赞念","ru":"Азкары","fr":"Adhkar"],
        "fiqhSubtitle":["ar":"مساعد فقهي موثّق","en":"Source-bound fiqh assistant","tr":"Kaynaklı fıkıh asistanı","ms":"Pembantu fiqh bersumber","id":"Asisten fikih bersumber","ja":"出典に基づくフィクフ助手","zh":"基于来源的教法助手","ru":"Фикх-помощник по источникам","fr":"Assistant fiqh sourcé"],
        "quranSubtitle":["ar":"المصحف والتفسير","en":"Mushaf & tafsir","tr":"Mushaf ve tefsir","ms":"Mushaf & tafsir","id":"Mushaf & tafsir","ja":"ムスハフとタフスィール","zh":"古兰经与经注","ru":"Мусхаф и тафсир","fr":"Mushaf et tafsir"],
        "adhkarSubtitle":["ar":"حصنك اليومي","en":"Your daily remembrance","tr":"Günlük zikirlerin","ms":"Zikir harian anda","id":"Zikir harian Anda","ja":"毎日のズィクル","zh":"每日赞念","ru":"Ежедневные поминания","fr":"Vos invocations quotidiennes"]
        ,"search":["ar":"البحث","en":"Search","tr":"Ara","ms":"Cari","id":"Cari","ja":"検索","zh":"搜索","ru":"Поиск","fr":"Recherche"],
        "bookmarks":["ar":"المحفوظات","en":"Bookmarks","tr":"Yer imleri","ms":"Penanda","id":"Penanda","ja":"ブックマーク","zh":"书签","ru":"Закладки","fr":"Favoris"],
        "continueReading":["ar":"متابعة القراءة","en":"Continue reading","tr":"Okumaya devam et","ms":"Teruskan membaca","id":"Lanjutkan membaca","ja":"続きを読む","zh":"继续阅读","ru":"Продолжить чтение","fr":"Continuer la lecture"],
        "tafsir":["ar":"التفسير","en":"Tafsir","tr":"Tefsir","ms":"Tafsir","id":"Tafsir","ja":"タフスィール","zh":"经注","ru":"Тафсир","fr":"Tafsir"],
        "destination":["ar":"وجهتك","en":"Destination","tr":"Varış noktası","ms":"Destinasi","id":"Tujuan","ja":"目的地","zh":"目的地","ru":"Направление","fr":"Destination"],
        "countryInfo":["ar":"معلومات البلد","en":"Country information","tr":"Ülke bilgileri","ms":"Maklumat negara","id":"Informasi negara","ja":"国情報","zh":"国家信息","ru":"Информация о стране","fr":"Informations sur le pays"],
        "requirements":["ar":"متطلبات الرحلة","en":"Trip requirements","tr":"Seyahat gereksinimleri","ms":"Keperluan perjalanan","id":"Persyaratan perjalanan","ja":"旅行要件","zh":"旅行要求","ru":"Требования поездки","fr":"Formalités du voyage"],
        "localApps":["ar":"التطبيقات المحلية المهمة","en":"Important local apps","tr":"Önemli yerel uygulamalar","ms":"Aplikasi tempatan penting","id":"Aplikasi lokal penting","ja":"重要な現地アプリ","zh":"重要本地应用","ru":"Важные местные приложения","fr":"Applications locales utiles"],
        "muslimTools":["ar":"أدوات المسلم","en":"Muslim tools","tr":"Müslüman araçları","ms":"Alat Muslim","id":"Alat Muslim","ja":"ムスリム向けツール","zh":"穆斯林工具","ru":"Инструменты мусульманина","fr":"Outils du musulman"],
        "embassy":["ar":"السفارة والقنصلية","en":"Embassy & consulate","tr":"Büyükelçilik ve konsolosluk","ms":"Kedutaan & konsulat","id":"Kedutaan & konsulat","ja":"大使館・領事館","zh":"使领馆","ru":"Посольство и консульство","fr":"Ambassade et consulat"],
        "humidity":["ar":"الرطوبة","en":"Humidity","tr":"Nem","ms":"Kelembapan","id":"Kelembapan","ja":"湿度","zh":"湿度","ru":"Влажность","fr":"Humidité"],
        "wind":["ar":"الرياح","en":"Wind","tr":"Rüzgâr","ms":"Angin","id":"Angin","ja":"風","zh":"风速","ru":"Ветер","fr":"Vent"],
        "prayerTimes":["ar":"مواقيت الصلاة","en":"Prayer times","tr":"Namaz vakitleri","ms":"Waktu solat","id":"Waktu salat","ja":"礼拝時刻","zh":"礼拜时间","ru":"Время молитв","fr":"Horaires de prière"],
        "fajr":["ar":"الفجر","en":"Fajr","tr":"Sabah","ms":"Subuh","id":"Subuh","ja":"ファジュル","zh":"晨礼","ru":"Фаджр","fr":"Fajr"],
        "dhuhr":["ar":"الظهر","en":"Dhuhr","tr":"Öğle","ms":"Zohor","id":"Zuhur","ja":"ズフル","zh":"晌礼","ru":"Зухр","fr":"Dhuhr"],
        "asr":["ar":"العصر","en":"Asr","tr":"İkindi","ms":"Asar","id":"Asar","ja":"アスル","zh":"晡礼","ru":"Аср","fr":"Asr"],
        "maghrib":["ar":"المغرب","en":"Maghrib","tr":"Akşam","ms":"Maghrib","id":"Magrib","ja":"マグリブ","zh":"昏礼","ru":"Магриб","fr":"Maghrib"],
        "isha":["ar":"العشاء","en":"Isha","tr":"Yatsı","ms":"Isyak","id":"Isya","ja":"イシャー","zh":"宵礼","ru":"Иша","fr":"Isha"],
        "localAssistant":["ar":"المساعد الفقهي المحلي","en":"Local fiqh assistant","tr":"Yerel fıkıh asistanı","ms":"Pembantu fiqh tempatan","id":"Asisten fikih lokal","ja":"ローカル・フィクフ助手","zh":"本地教法助手","ru":"Локальный фикх-помощник","fr":"Assistant fiqh local"],
        "sources":["ar":"المصادر","en":"Sources","tr":"Kaynaklar","ms":"Sumber","id":"Sumber","ja":"出典","zh":"来源","ru":"Источники","fr":"Sources"]

    ]
    static func t(_ key:String,_ lang:SariLanguage = .selected)->String {
        table[key]?[lang.rawValue] ?? table[key]?["en"] ?? key
    }
}
