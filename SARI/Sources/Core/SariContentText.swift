import Foundation

enum SariContentText {
    static func pick(_ language: SariLanguage, _ values: [SariLanguage: String]) -> String {
        values[language] ?? values[.en] ?? ""
    }

    static func prayerName(_ id: String, language: SariLanguage) -> String {
        let names: [String: [SariLanguage: String]] = [
            "fajr": [.ar:"الفجر",.en:"Fajr",.tr:"Fecr",.ms:"Subuh",.id:"Subuh",.ja:"ファジュル",.zh:"晨礼 Fajr",.ru:"Фаджр",.fr:"Fajr"],
            "sunrise": [.ar:"الشروق",.en:"Sunrise",.tr:"Güneş",.ms:"Syuruk",.id:"Terbit matahari",.ja:"日の出",.zh:"日出",.ru:"Восход",.fr:"Lever du soleil"],
            "dhuhr": [.ar:"الظهر",.en:"Dhuhr",.tr:"Öğle",.ms:"Zohor",.id:"Zuhur",.ja:"ズフル",.zh:"晌礼 Dhuhr",.ru:"Зухр",.fr:"Dhuhr"],
            "asr": [.ar:"العصر",.en:"Asr",.tr:"İkindi",.ms:"Asar",.id:"Asar",.ja:"アスル",.zh:"晡礼 Asr",.ru:"Аср",.fr:"Asr"],
            "maghrib": [.ar:"المغرب",.en:"Maghrib",.tr:"Akşam",.ms:"Maghrib",.id:"Magrib",.ja:"マグリブ",.zh:"昏礼 Maghrib",.ru:"Магриб",.fr:"Maghrib"],
            "isha": [.ar:"العشاء",.en:"Isha",.tr:"Yatsı",.ms:"Isyak",.id:"Isya",.ja:"イシャー",.zh:"宵礼 Isha",.ru:"Иша",.fr:"Isha"]
        ]
        return names[id]?[language] ?? names[id]?[.en] ?? id
    }

    static func weatherCondition(_ code: Int, language: SariLanguage) -> String {
        let key: String
        switch code {
        case 0: key = "clear"
        case 1,2: key = "partly"
        case 3: key = "cloudy"
        case 45,48: key = "fog"
        case 51,53,55,56,57: key = "drizzle"
        case 61,63,65,66,67: key = "rain"
        case 71,73,75,77: key = "snow"
        case 80,81,82: key = "showers"
        case 85,86: key = "snowShowers"
        case 95,96,99: key = "storm"
        default: key = "variable"
        }
        let table: [String:[SariLanguage:String]] = [
            "clear":[.ar:"صحو",.en:"Clear",.tr:"Açık",.ms:"Cerah",.id:"Cerah",.ja:"快晴",.zh:"晴朗",.ru:"Ясно",.fr:"Dégagé"],
            "partly":[.ar:"غائم جزئيًا",.en:"Partly cloudy",.tr:"Parçalı bulutlu",.ms:"Separa mendung",.id:"Berawan sebagian",.ja:"晴れ時々曇り",.zh:"局部多云",.ru:"Переменная облачность",.fr:"Partiellement nuageux"],
            "cloudy":[.ar:"غائم",.en:"Cloudy",.tr:"Bulutlu",.ms:"Mendung",.id:"Berawan",.ja:"曇り",.zh:"多云",.ru:"Облачно",.fr:"Nuageux"],
            "fog":[.ar:"ضباب",.en:"Fog",.tr:"Sis",.ms:"Kabus",.id:"Kabut",.ja:"霧",.zh:"雾",.ru:"Туман",.fr:"Brouillard"],
            "drizzle":[.ar:"رذاذ",.en:"Drizzle",.tr:"Çiseleme",.ms:"Gerimis",.id:"Gerimis",.ja:"霧雨",.zh:"毛毛雨",.ru:"Морось",.fr:"Bruine"],
            "rain":[.ar:"أمطار",.en:"Rain",.tr:"Yağmur",.ms:"Hujan",.id:"Hujan",.ja:"雨",.zh:"降雨",.ru:"Дождь",.fr:"Pluie"],
            "snow":[.ar:"ثلوج",.en:"Snow",.tr:"Kar",.ms:"Salji",.id:"Salju",.ja:"雪",.zh:"降雪",.ru:"Снег",.fr:"Neige"],
            "showers":[.ar:"زخات مطر",.en:"Rain showers",.tr:"Sağanak",.ms:"Hujan renyai",.id:"Hujan singkat",.ja:"にわか雨",.zh:"阵雨",.ru:"Ливни",.fr:"Averses"],
            "snowShowers":[.ar:"زخات ثلج",.en:"Snow showers",.tr:"Kar sağanağı",.ms:"Hujan salji",.id:"Hujan salju",.ja:"にわか雪",.zh:"阵雪",.ru:"Снежные заряды",.fr:"Averses de neige"],
            "storm":[.ar:"عواصف رعدية",.en:"Thunderstorms",.tr:"Gök gürültülü fırtına",.ms:"Ribut petir",.id:"Badai petir",.ja:"雷雨",.zh:"雷暴",.ru:"Гроза",.fr:"Orages"],
            "variable":[.ar:"طقس متغير",.en:"Variable weather",.tr:"Değişken hava",.ms:"Cuaca berubah",.id:"Cuaca berubah",.ja:"変わりやすい天気",.zh:"天气多变",.ru:"Переменная погода",.fr:"Temps variable"]
        ]
        return table[key]?[language] ?? table[key]?[.en] ?? ""
    }

    static func clothingAdvice(apparent: Double, rain: Bool, windy: Bool, swing: Bool, uvHigh: Bool, language: SariLanguage) -> String {
        let warmth: String
        switch apparent {
        case 34...:
            warmth = pick(language,[.ar:"ملابس خفيفة وفضفاضة",.en:"Light, loose clothing",.tr:"Hafif ve bol kıyafetler",.ms:"Pakaian ringan dan longgar",.id:"Pakaian ringan dan longgar",.ja:"薄手でゆったりした服",.zh:"轻薄宽松的衣物",.ru:"Лёгкая свободная одежда",.fr:"Vêtements légers et amples"])
        case 27..<34:
            warmth = pick(language,[.ar:"ملابس صيفية خفيفة",.en:"Light summer clothing",.tr:"Hafif yazlık kıyafet",.ms:"Pakaian musim panas yang ringan",.id:"Pakaian musim panas yang ringan",.ja:"薄手の夏服",.zh:"轻薄夏装",.ru:"Лёгкая летняя одежда",.fr:"Tenue d’été légère"])
        case 20..<27:
            warmth = pick(language,[.ar:"ملابس خفيفة مع طبقة بسيطة للمساء",.en:"Light clothing with an extra layer for evening",.tr:"Hafif kıyafet ve akşam için ince bir katman",.ms:"Pakaian ringan dengan lapisan tambahan untuk petang",.id:"Pakaian ringan dengan lapisan tambahan untuk malam",.ja:"軽装＋夕方用の薄い上着",.zh:"轻装，晚间备一层薄外套",.ru:"Лёгкая одежда и дополнительный слой на вечер",.fr:"Tenue légère avec une couche pour le soir"])
        case 13..<20:
            warmth = pick(language,[.ar:"جاكيت خفيف أو كنزة",.en:"Light jacket or sweater",.tr:"İnce ceket veya kazak",.ms:"Jaket ringan atau baju sejuk",.id:"Jaket ringan atau sweater",.ja:"薄手のジャケットかセーター",.zh:"薄夹克或毛衣",.ru:"Лёгкая куртка или свитер",.fr:"Veste légère ou pull"])
        case 6..<13:
            warmth = pick(language,[.ar:"جاكيت متوسط وملابس دافئة",.en:"Warm clothes and a medium jacket",.tr:"Sıcak kıyafet ve orta kalınlıkta ceket",.ms:"Pakaian hangat dan jaket sederhana",.id:"Pakaian hangat dan jaket sedang",.ja:"暖かい服と中厚手の上着",.zh:"保暖衣物和中等厚度外套",.ru:"Тёплая одежда и куртка",.fr:"Vêtements chauds et veste"])
        default:
            warmth = pick(language,[.ar:"معطف دافئ وطبقات متعددة",.en:"Warm coat and multiple layers",.tr:"Kalın mont ve katmanlı giyim",.ms:"Kot hangat dan beberapa lapisan",.id:"Mantel hangat dan beberapa lapisan",.ja:"暖かいコートと重ね着",.zh:"保暖大衣并多层穿着",.ru:"Тёплое пальто и несколько слоёв",.fr:"Manteau chaud et plusieurs couches"])
        }
        var items=[warmth]
        if rain { items.append(pick(language,[.ar:"خذ مظلة أو معطفًا مقاومًا للمطر",.en:"Take an umbrella or rain jacket",.tr:"Şemsiye veya yağmurluk alın",.ms:"Bawa payung atau jaket hujan",.id:"Bawa payung atau jas hujan",.ja:"傘かレインジャケットを携帯",.zh:"携带雨伞或防雨外套",.ru:"Возьмите зонт или дождевик",.fr:"Prenez un parapluie ou un imperméable"])) }
        if windy { items.append(pick(language,[.ar:"الرياح قوية؛ اختر طبقة خارجية ثابتة",.en:"Strong wind; use a secure outer layer",.tr:"Rüzgâr güçlü; koruyucu bir dış katman giyin",.ms:"Angin kuat; gunakan lapisan luar yang sesuai",.id:"Angin kuat; gunakan lapisan luar yang sesuai",.ja:"風が強いため防風の上着を",.zh:"风较强，建议穿防风外层",.ru:"Сильный ветер; нужна плотная верхняя одежда",.fr:"Vent fort : prévoyez une couche coupe-vent"])) }
        if swing { items.append(pick(language,[.ar:"الحرارة تتغير اليوم؛ خذ طبقة إضافية",.en:"Temperatures vary today; take an extra layer",.tr:"Sıcaklık değişiyor; ek bir katman alın",.ms:"Suhu berubah hari ini; bawa lapisan tambahan",.id:"Suhu berubah hari ini; bawa lapisan tambahan",.ja:"寒暖差があるため上着を一枚追加",.zh:"今天温差较大，备一层衣物",.ru:"Температура меняется; возьмите дополнительный слой",.fr:"La température varie : prévoyez une couche en plus"])) }
        if uvHigh { items.append(pick(language,[.ar:"الأشعة قوية؛ استخدم قبعة وواقي شمس",.en:"Strong UV; consider a hat and sunscreen",.tr:"UV yüksek; şapka ve güneş kremi kullanın",.ms:"UV tinggi; gunakan topi dan pelindung matahari",.id:"UV tinggi; gunakan topi dan tabir surya",.ja:"紫外線が強いため帽子と日焼け止めを",.zh:"紫外线较强，建议帽子和防晒",.ru:"Высокий УФ: головной убор и солнцезащитный крем",.fr:"UV élevé : chapeau et crème solaire"])) }
        let separator = language.isArabic ? "، " : "; "
        return items.joined(separator: separator) + "."
    }

    static func smartWeatherAlert(rain: Bool, wind: Bool, uv: Bool, heat: Bool, language: SariLanguage) -> String? {
        if rain { return pick(language,[.ar:"احتمال المطر مرتفع اليوم؛ خطط للخروج مع مظلة.",.en:"High rain chance today; plan for an umbrella.",.tr:"Bugün yağmur olasılığı yüksek; şemsiye alın.",.ms:"Kebarangkalian hujan tinggi; bawa payung.",.id:"Peluang hujan tinggi; bawa payung.",.ja:"雨の可能性が高いため傘を準備してください。",.zh:"今天降雨概率较高，请备雨伞。",.ru:"Высока вероятность дождя; возьмите зонт.",.fr:"Risque de pluie élevé : prévoyez un parapluie."]) }
        if wind { return pick(language,[.ar:"هبات الرياح قوية؛ انتبه في الأماكن المفتوحة.",.en:"Strong wind gusts; take care in open areas.",.tr:"Kuvvetli rüzgâr; açık alanlarda dikkatli olun.",.ms:"Tiupan angin kuat; berhati-hati di kawasan terbuka.",.id:"Hembusan angin kuat; berhati-hati di area terbuka.",.ja:"強い突風に注意してください。",.zh:"阵风较强，在开阔区域请注意。",.ru:"Сильные порывы ветра; будьте осторожны на открытых местах.",.fr:"Fortes rafales : prudence dans les espaces ouverts."]) }
        if uv { return pick(language,[.ar:"مؤشر الأشعة فوق البنفسجية مرتفع؛ قلل التعرض المباشر وقت الظهيرة.",.en:"UV is high; limit direct midday exposure.",.tr:"UV yüksek; öğle saatlerinde doğrudan güneşi sınırlayın.",.ms:"UV tinggi; kurangkan pendedahan langsung tengah hari.",.id:"UV tinggi; kurangi paparan langsung saat siang.",.ja:"紫外線が強いため昼の直射日光を避けてください。",.zh:"紫外线较高，中午减少阳光直射。",.ru:"Высокий УФ; ограничьте пребывание на солнце в полдень.",.fr:"UV élevé : limitez l’exposition directe à midi."]) }
        if heat { return pick(language,[.ar:"حرارة شديدة متوقعة؛ تجنب المجهود الطويل وقت الذروة.",.en:"Extreme heat expected; avoid prolonged exertion at peak heat.",.tr:"Aşırı sıcak bekleniyor; en sıcak saatlerde uzun efordan kaçının.",.ms:"Cuaca sangat panas; elakkan aktiviti berat pada waktu puncak.",.id:"Panas ekstrem; hindari aktivitas berat saat puncak.",.ja:"猛暑の予報です。暑さのピーク時の長時間活動を避けてください。",.zh:"预计高温，炎热时段避免长时间剧烈活动。",.ru:"Ожидается сильная жара; избегайте долгих нагрузок в пик жары.",.fr:"Forte chaleur prévue : évitez les efforts prolongés aux heures les plus chaudes."]) }
        return nil
    }

    static func localeIdentifier(_ language: SariLanguage) -> String {
        language.localeIdentifier
    }

    static func countryName(_ code: String, language: SariLanguage) -> String {
        if code.uppercased() == "PS" {
            return pick(language, [
                .ar: "فلسطين", .en: "Palestine", .tr: "Filistin", .ms: "Palestin", .id: "Palestina",
                .ja: "パレスチナ", .zh: "巴勒斯坦", .ru: "Палестина", .fr: "Palestine"
            ])
        }
        if code.uppercased() == "XK" {
            return pick(language, [
                .ar: "كوسوفو", .en: "Kosovo", .tr: "Kosova", .ms: "Kosovo", .id: "Kosovo",
                .ja: "コソボ", .zh: "科索沃", .ru: "Косово", .fr: "Kosovo"
            ])
        }
        return Locale(identifier: localeIdentifier(language)).localizedString(forRegionCode: code) ?? code
    }

    static func flag(_ code: String) -> String {
        code.uppercased().unicodeScalars.compactMap { UnicodeScalar(127397 + Int($0.value)) }.map(String.init).joined()
    }
}
