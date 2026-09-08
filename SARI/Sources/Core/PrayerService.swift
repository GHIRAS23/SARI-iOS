import Foundation
import CoreLocation
import UserNotifications
import WidgetKit

struct PrayerTimes: Codable {
    let fajr: Date
    let sunrise: Date
    let dhuhr: Date
    let asr: Date
    let maghrib: Date
    let isha: Date

    func next(after now: Date = .now, timeZone: TimeZone = .current) -> (id: String, date: Date) {
        let items: [(String, Date)] = [
            ("fajr", fajr),
            ("dhuhr", dhuhr),
            ("asr", asr),
            ("maghrib", maghrib),
            ("isha", isha)
        ]

        if let next = items.first(where: { $0.1 > now }) {
            return (next.0, next.1)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return (
            "fajr",
            calendar.date(byAdding: .day, value: 1, to: fajr) ?? fajr
        )
    }
}

enum PrayerCalculationMethod: String, CaseIterable, Identifiable {
    case auto
    case ummAlQura
    case muslimWorldLeague
    case isna
    case egyptian
    case karachi
    case dubai
    case qatar
    case kuwait
    case singapore
    case turkey
    case tehran
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:
            return "تلقائي حسب الموقع"
        case .ummAlQura:
            return "أم القرى — مكة المكرمة"
        case .muslimWorldLeague:
            return "رابطة العالم الإسلامي"
        case .isna:
            return "ISNA — أمريكا الشمالية"
        case .egyptian:
            return "الهيئة المصرية العامة للمساحة"
        case .karachi:
            return "جامعة العلوم الإسلامية — كراتشي"
        case .dubai:
            return "دبي"
        case .qatar:
            return "قطر"
        case .kuwait:
            return "الكويت"
        case .singapore:
            return "سنغافورة"
        case .turkey:
            return "رئاسة الشؤون الدينية التركية"
        case .tehran:
            return "طهران"
        case .custom:
            return "مخصص"
        }
    }

    func title(_ language: SariLanguage) -> String {
        switch self {
        case .auto:
            return SariContentText.pick(language,[.ar:"تلقائي حسب الموقع",.en:"Automatic by location",.tr:"Konuma göre otomatik",.ms:"Automatik mengikut lokasi",.id:"Otomatis berdasarkan lokasi",.ja:"位置情報で自動",.zh:"按位置自动选择",.ru:"Автоматически по местоположению",.fr:"Automatique selon la position"])
        case .ummAlQura:
            return SariContentText.pick(language,[.ar:"أم القرى — مكة المكرمة",.en:"Umm al-Qura — Makkah",.tr:"Ümmü'l-Kurâ — Mekke",.ms:"Umm al-Qura — Makkah",.id:"Umm al-Qura — Makkah",.ja:"ウム・アルクラー — マッカ",.zh:"乌姆古拉 — 麦加",.ru:"Умм аль-Кура — Мекка",.fr:"Umm al-Qura — La Mecque"])
        case .muslimWorldLeague:
            return SariContentText.pick(language,[.ar:"رابطة العالم الإسلامي",.en:"Muslim World League",.tr:"Dünya İslam Birliği",.ms:"Liga Dunia Islam",.id:"Liga Muslim Dunia",.ja:"ムスリム世界連盟",.zh:"世界穆斯林联盟",.ru:"Всемирная исламская лига",.fr:"Ligue islamique mondiale"])
        case .isna:
            return SariContentText.pick(language,[.ar:"ISNA — أمريكا الشمالية",.en:"ISNA — North America",.tr:"ISNA — Kuzey Amerika",.ms:"ISNA — Amerika Utara",.id:"ISNA — Amerika Utara",.ja:"ISNA — 北米",.zh:"ISNA — 北美",.ru:"ISNA — Северная Америка",.fr:"ISNA — Amérique du Nord"])
        case .egyptian:
            return SariContentText.pick(language,[.ar:"الهيئة المصرية العامة للمساحة",.en:"Egyptian General Authority of Survey",.tr:"Mısır Genel Ölçüm Kurumu",.ms:"Pihak Berkuasa Ukur Mesir",.id:"Otoritas Survei Mesir",.ja:"エジプト測量庁",.zh:"埃及测绘总局",.ru:"Египетское управление геодезии",.fr:"Autorité égyptienne de topographie"])
        case .karachi:
            return SariContentText.pick(language,[.ar:"جامعة العلوم الإسلامية — كراتشي",.en:"University of Islamic Sciences — Karachi",.tr:"İslami İlimler Üniversitesi — Karaçi",.ms:"Universiti Sains Islam — Karachi",.id:"Universitas Ilmu Islam — Karachi",.ja:"イスラム科学大学 — カラチ",.zh:"伊斯兰科学大学 — 卡拉奇",.ru:"Университет исламских наук — Карачи",.fr:"Université des sciences islamiques — Karachi"])
        case .dubai: return SariContentText.pick(language,[.ar:"دبي",.en:"Dubai",.tr:"Dubai",.ms:"Dubai",.id:"Dubai",.ja:"ドバイ",.zh:"迪拜",.ru:"Дубай",.fr:"Dubaï"])
        case .qatar: return SariContentText.pick(language,[.ar:"قطر",.en:"Qatar",.tr:"Katar",.ms:"Qatar",.id:"Qatar",.ja:"カタール",.zh:"卡塔尔",.ru:"Катар",.fr:"Qatar"])
        case .kuwait: return SariContentText.pick(language,[.ar:"الكويت",.en:"Kuwait",.tr:"Kuveyt",.ms:"Kuwait",.id:"Kuwait",.ja:"クウェート",.zh:"科威特",.ru:"Кувейт",.fr:"Koweït"])
        case .singapore: return SariContentText.pick(language,[.ar:"سنغافورة",.en:"Singapore",.tr:"Singapur",.ms:"Singapura",.id:"Singapura",.ja:"シンガポール",.zh:"新加坡",.ru:"Сингапур",.fr:"Singapour"])
        case .turkey: return SariContentText.pick(language,[.ar:"رئاسة الشؤون الدينية التركية",.en:"Türkiye Diyanet",.tr:"Diyanet İşleri Başkanlığı",.ms:"Diyanet Türkiye",.id:"Diyanet Türkiye",.ja:"トルコ宗務庁",.zh:"土耳其宗教事务局",.ru:"Управление по делам религии Турции",.fr:"Présidence turque des affaires religieuses"])
        case .tehran: return SariContentText.pick(language,[.ar:"طهران",.en:"Tehran",.tr:"Tahran",.ms:"Tehran",.id:"Teheran",.ja:"テヘラン",.zh:"德黑兰",.ru:"Тегеран",.fr:"Téhéran"])
        case .custom: return SariContentText.pick(language,[.ar:"مخصص",.en:"Custom",.tr:"Özel",.ms:"Tersuai",.id:"Kustom",.ja:"カスタム",.zh:"自定义",.ru:"Пользовательский",.fr:"Personnalisé"])
        }
    }

    func parameters(
        latitude: Double,
        longitude: Double
    ) -> (
        fajr: Double,
        ishaAngle: Double?,
        ishaMinutes: Int
    ) {
        switch self {
        case .auto:
            return PrayerCalculationMethod
                .autoMethod(
                    latitude: latitude,
                    longitude: longitude
                )
                .parameters(
                    latitude: latitude,
                    longitude: longitude
                )

        case .ummAlQura:
            return (18.5, nil, 90)

        case .muslimWorldLeague:
            return (18, 17, 0)

        case .isna:
            return (15, 15, 0)

        case .egyptian:
            return (19.5, 17.5, 0)

        case .karachi:
            return (18, 18, 0)

        case .dubai:
            return (18.2, 18.2, 0)

        case .qatar:
            return (18, nil, 90)

        case .kuwait:
            return (18, 17.5, 0)

        case .singapore:
            return (20, 18, 0)

        case .turkey:
            return (18, 17, 0)

        case .tehran:
            return (17.7, 14, 0)

        case .custom:
            let defaults = UserDefaults(suiteName: "group.sa.sari.app")
            let fajr = defaults?.object(forKey: "customFajrAngle") != nil
                ? defaults?.double(forKey: "customFajrAngle") ?? 18
                : 18
            let isha = defaults?.object(forKey: "customIshaAngle") != nil
                ? defaults?.double(forKey: "customIshaAngle") ?? 17
                : 17
            return (fajr, isha, 0)
        }
    }

    static func autoMethod(
        latitude: Double,
        longitude: Double
    ) -> PrayerCalculationMethod {

        // Check the smaller Gulf regions before the wider Saudi bounding box.
        if latitude >= 24,
           latitude <= 27,
           longitude >= 50,
           longitude <= 52 {
            return .qatar
        }

        if latitude >= 28,
           latitude <= 31,
           longitude >= 46,
           longitude <= 49 {
            return .kuwait
        }

        if latitude >= 24,
           latitude <= 26.5,
           longitude >= 54,
           longitude <= 56.5 {
            return .dubai
        }

        if latitude >= 16,
           latitude <= 33,
           longitude >= 34,
           longitude <= 56 {
            return .ummAlQura
        }

        if latitude >= 1,
           latitude <= 2,
           longitude >= 103,
           longitude <= 105 {
            return .singapore
        }

        if latitude >= 35,
           latitude <= 43,
           longitude >= 25,
           longitude <= 45 {
            return .turkey
        }

        if latitude >= 24,
           latitude <= 50,
           longitude >= -170,
           longitude <= -50 {
            return .isna
        }

        return .muslimWorldLeague
    }
}

enum AsrJuristicMethod: String, CaseIterable, Identifiable {
    case standard
    case hanafi

    var id: String { rawValue }

    var title: String {
        self == .hanafi
            ? "حنفي — ظلّان"
            : "الجمهور — ظل واحد"
    }

    func title(_ language: SariLanguage) -> String {
        if self == .hanafi {
            return SariContentText.pick(language,[.ar:"حنفي — ظلّان",.en:"Hanafi — double shadow",.tr:"Hanefi — iki gölge",.ms:"Hanafi — dua bayang",.id:"Hanafi — dua bayangan",.ja:"ハナフィー — 影2倍",.zh:"哈乃斐 — 双影",.ru:"Ханафитский — двойная тень",.fr:"Hanafite — double ombre"])
        }
        return SariContentText.pick(language,[.ar:"الجمهور — ظل واحد",.en:"Standard — single shadow",.tr:"Standart — tek gölge",.ms:"Standard — satu bayang",.id:"Standar — satu bayangan",.ja:"標準 — 影1倍",.zh:"标准 — 单影",.ru:"Стандарт — одна тень",.fr:"Standard — une ombre"])
    }

    var factor: Double {
        self == .hanafi ? 2 : 1
    }
}

enum PrayerCalculator {

    /// NOAA-style solar calculation using local civil time.
    /// The previous implementation double-applied longitude in Julian-day conversion,
    /// which shifted Makkah prayer times by many hours. This implementation derives
    /// solar noon, sunrise/sunset and twilight angles directly in local minutes.
    static func calculate(
        date: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone = .current,
        method: PrayerCalculationMethod = .auto,
        asrMethod: AsrJuristicMethod = .standard,
        offsets: [String: Int] = [:]
    ) -> PrayerTimes {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let daysInYear = calendar.range(of: .day, in: .year, for: date)?.count ?? 365
        let gamma = 2.0 * Double.pi / Double(daysInYear) * Double(dayOfYear - 1)

        let equationOfTime = 229.18 * (
            0.000075
            + 0.001868 * cos(gamma)
            - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma)
            - 0.040849 * sin(2 * gamma)
        )

        let declination =
            0.006918
            - 0.399912 * cos(gamma)
            + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma)
            + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma)
            + 0.00148 * sin(3 * gamma)

        let zoneMinutes = Double(timeZone.secondsFromGMT(for: date)) / 60.0
        let solarNoonMinutes = 720.0 - (4.0 * longitude) - equationOfTime + zoneMinutes

        func hourAngle(altitudeDegrees: Double) -> Double {
            let latitudeRadians = latitude * Double.pi / 180
            let altitudeRadians = altitudeDegrees * Double.pi / 180
            let numerator = sin(altitudeRadians) - sin(latitudeRadians) * sin(declination)
            let denominator = cos(latitudeRadians) * cos(declination)
            guard abs(denominator) > 0.0000001 else { return 90 }
            let cosine = max(-1.0, min(1.0, numerator / denominator))
            return acos(cosine) * 180 / Double.pi
        }

        func localDate(minutes: Double) -> Date {
            let start = calendar.startOfDay(for: date)
            return start.addingTimeInterval(minutes * 60.0)
        }

        let effectiveMethod = method == .auto
            ? PrayerCalculationMethod.autoMethod(latitude: latitude, longitude: longitude)
            : method
        let parameters = effectiveMethod.parameters(latitude: latitude, longitude: longitude)

        let sunriseAngle = hourAngle(altitudeDegrees: -0.833)
        let fajrHourAngle = hourAngle(altitudeDegrees: -parameters.fajr)

        let declinationDegrees = declination * 180 / Double.pi
        let asrAltitude = atan(
            1.0 / (
                asrMethod.factor
                + tan(abs((latitude - declinationDegrees) * Double.pi / 180))
            )
        ) * 180 / Double.pi
        let asrHourAngle = hourAngle(altitudeDegrees: asrAltitude)

        let fajr = localDate(minutes: solarNoonMinutes - 4.0 * fajrHourAngle)
        let sunrise = localDate(minutes: solarNoonMinutes - 4.0 * sunriseAngle)
        let dhuhr = localDate(minutes: solarNoonMinutes)
        let asr = localDate(minutes: solarNoonMinutes + 4.0 * asrHourAngle)
        let sunset = localDate(minutes: solarNoonMinutes + 4.0 * sunriseAngle)

        let isha: Date
        if let angle = parameters.ishaAngle {
            let angleValue = hourAngle(altitudeDegrees: -angle)
            isha = localDate(minutes: solarNoonMinutes + 4.0 * angleValue)
        } else {
            // Umm al-Qura uses 90 minutes after Maghrib, commonly 120 in Ramadan.
            var islamic = Calendar(identifier: .islamicUmmAlQura)
            islamic.timeZone = timeZone
            let ramadan = islamic.component(.month, from: date) == 9
            let minutes = effectiveMethod == .ummAlQura && ramadan
                ? 120
                : parameters.ishaMinutes
            isha = calendar.date(byAdding: .minute, value: minutes, to: sunset) ?? sunset
        }

        func adjusted(_ value: Date, _ key: String) -> Date {
            calendar.date(byAdding: .minute, value: offsets[key] ?? 0, to: value) ?? value
        }

        return PrayerTimes(
            fajr: adjusted(fajr, "fajr"),
            sunrise: adjusted(sunrise, "sunrise"),
            dhuhr: adjusted(dhuhr, "dhuhr"),
            asr: adjusted(asr, "asr"),
            maghrib: adjusted(sunset, "maghrib"),
            isha: adjusted(isha, "isha")
        )
    }
}

@MainActor
final class PrayerStore:
    NSObject,
    ObservableObject,
    CLLocationManagerDelegate {

    @Published var locationName = SariContentText.pick(SariLanguage.selected,[.ar:"موقعك",.en:"Your location",.tr:"Konumunuz",.ms:"Lokasi anda",.id:"Lokasi Anda",.ja:"現在地",.zh:"您的位置",.ru:"Ваше местоположение",.fr:"Votre position"])
    @Published var coordinate:
        CLLocationCoordinate2D?
    @Published var times: PrayerTimes?
    @Published var qiblaBearing:
        Double = 0
    @Published var locationMessage:
        String?
    @Published var locationDenied = false
    @Published private(set) var timeZone: TimeZone = .current
    @Published private(set) var lastCalculationDate: Date?

    private var lastCalculatedDayKey: String?

    private let manager =
        CLLocationManager()

    private let suite =
        UserDefaults(
            suiteName: "group.sa.sari.app"
        )

    override init() {
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        if let savedTimeZoneID = suite?.string(forKey: "lastTimeZone"),
           let savedTimeZone = TimeZone(identifier: savedTimeZoneID) {
            timeZone = savedTimeZone
        }

        if let latitude =
            suite?.object(
                forKey: "lastLatitude"
            ) as? Double,
           let longitude =
            suite?.object(
                forKey: "lastLongitude"
            ) as? Double {

            applyCoordinate(
                CLLocationCoordinate2D(
                    latitude: latitude,
                    longitude: longitude
                ),
                persist: false
            )

            locationMessage = SariContentText.pick(SariLanguage.selected,[.ar:"يتم استخدام آخر موقع محفوظ حتى يتم تحديث الموقع.",.en:"Using the last saved location until it can be updated.",.tr:"Konum güncellenene kadar son kayıtlı konum kullanılıyor.",.ms:"Menggunakan lokasi terakhir yang disimpan sehingga dikemas kini.",.id:"Menggunakan lokasi tersimpan terakhir sampai diperbarui.",.ja:"更新されるまで最後に保存した位置を使用します。",.zh:"在更新前使用上次保存的位置。",.ru:"Используется последнее сохранённое местоположение до обновления.",.fr:"La dernière position enregistrée est utilisée jusqu’à la mise à jour."])
        }
    }

    func start() {
        refreshForToday()

        switch manager.authorizationStatus {

        case .notDetermined:
            manager
                .requestWhenInUseAuthorization()

        case .authorizedAlways,
             .authorizedWhenInUse:
            manager.requestLocation()

        case .denied,
             .restricted:
            locationDenied = true
            locationMessage = SariContentText.pick(SariLanguage.selected,[.ar:"صلاحية الموقع غير متاحة. يمكن الاستمرار بآخر موقع محفوظ أو تفعيل الموقع من إعدادات الجهاز.",.en:"Location access is unavailable. SARI can use the last saved location, or you can enable access in Settings.",.tr:"Konum erişimi yok. Son kayıtlı konum kullanılabilir veya Ayarlar’dan izin verebilirsiniz.",.ms:"Akses lokasi tidak tersedia. SARI boleh menggunakan lokasi terakhir atau anda boleh membenarkannya dalam Tetapan.",.id:"Akses lokasi tidak tersedia. SARI dapat memakai lokasi terakhir atau aktifkan akses di Pengaturan.",.ja:"位置情報を利用できません。最後の保存位置を使うか、設定で許可してください。",.zh:"无法访问位置。可使用上次保存的位置，或在设置中启用位置权限。",.ru:"Доступ к геопозиции недоступен. Можно использовать последнее сохранённое место или включить доступ в настройках.",.fr:"L’accès à la position est indisponible. SARI peut utiliser la dernière position ou vous pouvez l’activer dans Réglages."])

        @unknown default:
            locationMessage = SariContentText.pick(SariLanguage.selected,[.ar:"تعذر تحديد حالة صلاحية الموقع.",.en:"Could not determine location permission status.",.tr:"Konum izni durumu belirlenemedi.",.ms:"Status kebenaran lokasi tidak dapat ditentukan.",.id:"Status izin lokasi tidak dapat ditentukan.",.ja:"位置情報の許可状態を確認できませんでした。",.zh:"无法确定位置权限状态。",.ru:"Не удалось определить статус разрешения геопозиции.",.fr:"Impossible de déterminer l’état de l’autorisation de localisation."])
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        let status = manager.authorizationStatus

        Task { @MainActor [weak self] in
            self?.handleAuthorizationChange(
                status
            )
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations:
            [CLLocation]
    ) {
        guard let location =
            locations.last else {
            return
        }

        let latitude =
            location.coordinate.latitude

        let longitude =
            location.coordinate.longitude

        Task { @MainActor [weak self] in
            self?.handleLocationUpdate(
                latitude: latitude,
                longitude: longitude
            )
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.handleLocationFailure()
        }
    }

    private func handleAuthorizationChange(
        _ status:
            CLAuthorizationStatus
    ) {
        switch status {

        case .authorizedAlways,
             .authorizedWhenInUse:
            locationDenied = false
            locationMessage = nil
            manager.requestLocation()

        case .denied,
             .restricted:
            locationDenied = true

            locationMessage = SariContentText.pick(SariLanguage.selected,[.ar:"صلاحية الموقع غير متاحة. يمكن الاستمرار بآخر موقع محفوظ.",.en:"Location access is unavailable. The last saved location can still be used.",.tr:"Konum erişimi yok. Son kayıtlı konum kullanılabilir.",.ms:"Akses lokasi tidak tersedia. Lokasi terakhir masih boleh digunakan.",.id:"Akses lokasi tidak tersedia. Lokasi terakhir masih dapat digunakan.",.ja:"位置情報を利用できません。最後の保存位置を使用できます。",.zh:"无法访问位置，仍可使用上次保存的位置。",.ru:"Геопозиция недоступна; можно использовать последнее сохранённое место.",.fr:"L’accès à la position est indisponible ; la dernière position peut être utilisée."])

        default:
            break
        }
    }

    private func handleLocationUpdate(
        latitude: Double,
        longitude: Double
    ) {
        let coordinate =
            CLLocationCoordinate2D(
                latitude: latitude,
                longitude: longitude
            )

        let location =
            CLLocation(
                latitude: latitude,
                longitude: longitude
            )

        applyCoordinate(
            coordinate,
            persist: true
        )

        locationDenied = false
        locationMessage = nil

        saveWidget()
        schedulePrayerNotifications()

        CLGeocoder()
            .reverseGeocodeLocation(
                location,
                preferredLocale: Locale(identifier: SariContentText.localeIdentifier(SariLanguage.selected))
            ) { [weak self] placemarks, _ in

                let name =
                    placemarks?.first?.locality
                    ?? placemarks?.first?
                        .administrativeArea
                    ?? SariContentText.pick(SariLanguage.selected,[.ar:"موقعك",.en:"Your location",.tr:"Konumunuz",.ms:"Lokasi anda",.id:"Lokasi Anda",.ja:"現在地",.zh:"您的位置",.ru:"Ваше местоположение",.fr:"Votre position"])

                let resolvedTimeZone = placemarks?.first?.timeZone

                Task { @MainActor in
                    guard let self else { return }
                    self.locationName = name
                    if let resolvedTimeZone {
                        self.timeZone = resolvedTimeZone
                        self.suite?.set(resolvedTimeZone.identifier, forKey: "lastTimeZone")
                    }
                    self.recalculate()
                }
            }
    }

    private func handleLocationFailure() {
        locationMessage = coordinate == nil
            ? SariContentText.pick(SariLanguage.selected,[.ar:"تعذر تحديد الموقع ولا يوجد موقع محفوظ بعد.",.en:"Could not determine your location and no saved location is available yet.",.tr:"Konum belirlenemedi ve kayıtlı konum yok.",.ms:"Lokasi tidak dapat ditentukan dan belum ada lokasi disimpan.",.id:"Lokasi tidak dapat ditentukan dan belum ada lokasi tersimpan.",.ja:"現在地を特定できず、保存済みの位置もありません。",.zh:"无法确定位置，且尚无已保存的位置。",.ru:"Не удалось определить местоположение, сохранённого места пока нет.",.fr:"Impossible de déterminer la position et aucune position n’est encore enregistrée."])
            : SariContentText.pick(SariLanguage.selected,[.ar:"تعذر تحديث الموقع؛ يتم استخدام آخر موقع محفوظ.",.en:"Could not update location; using the last saved location.",.tr:"Konum güncellenemedi; son kayıtlı konum kullanılıyor.",.ms:"Lokasi tidak dapat dikemas kini; lokasi terakhir digunakan.",.id:"Lokasi tidak dapat diperbarui; menggunakan lokasi terakhir.",.ja:"位置を更新できないため、最後の保存位置を使用します。",.zh:"无法更新位置；正在使用上次保存的位置。",.ru:"Не удалось обновить геопозицию; используется последнее сохранённое место.",.fr:"Impossible de mettre à jour la position ; la dernière position est utilisée."])
    }

    private func applyCoordinate(
        _ coordinate:
            CLLocationCoordinate2D,
        persist: Bool
    ) {
        self.coordinate = coordinate

        qiblaBearing =
            qibla(from: coordinate)

        if persist {
            suite?.set(
                coordinate.latitude,
                forKey: "lastLatitude"
            )

            suite?.set(
                coordinate.longitude,
                forKey: "lastLongitude"
            )
        }

        let method =
            PrayerCalculationMethod(
                rawValue:
                    suite?.string(
                        forKey:
                            "calculationMethod"
                    ) ?? "auto"
            ) ?? .auto

        let asrMethod =
            AsrJuristicMethod(
                rawValue:
                    suite?.string(
                        forKey: "asrMethod"
                    ) ?? "standard"
            ) ?? .standard

        let identifiers = [
            "fajr",
            "sunrise",
            "dhuhr",
            "asr",
            "maghrib",
            "isha"
        ]

        let offsets =
            Dictionary(
                uniqueKeysWithValues:
                    identifiers.map {
                        (
                            $0,
                            suite?.integer(
                                forKey:
                                    "offset_\($0)"
                            ) ?? 0
                        )
                    }
            )

        let now = Date()
        times = PrayerCalculator.calculate(
            date: now,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            timeZone: timeZone,
            method: method,
            asrMethod: asrMethod,
            offsets: offsets
        )
        lastCalculationDate = now
        lastCalculatedDayKey = dayKey(for: now)
    }

    /// Recalculate whenever the civil day changes, when the app becomes active,
    /// or when settings/location/time-zone change. This prevents stale "fixed" times.
    func refreshForToday(force: Bool = false) {
        guard let coordinate else { return }
        let currentKey = dayKey(for: Date())
        if force || currentKey != lastCalculatedDayKey {
            applyCoordinate(coordinate, persist: false)
            saveWidget()
            schedulePrayerNotifications()
        }
    }

    /// Refresh localized place name and widget text after an in-app language switch.
    func refreshForLanguage() {
        guard let coordinate else {
            saveWidget()
            return
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let language = SariLanguage.selected
        CLGeocoder().reverseGeocodeLocation(
            location,
            preferredLocale: Locale(identifier: SariContentText.localeIdentifier(language))
        ) { [weak self] placemarks, _ in
            let name = placemarks?.first?.locality
                ?? placemarks?.first?.administrativeArea
            let resolvedTimeZone = placemarks?.first?.timeZone
            Task { @MainActor in
                guard let self else { return }
                if let name { self.locationName = name }
                if let resolvedTimeZone {
                    self.timeZone = resolvedTimeZone
                    self.suite?.set(resolvedTimeZone.identifier, forKey: "lastTimeZone")
                }
                self.refreshForToday(force: true)
            }
        }
    }

    private func dayKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)-\(timeZone.identifier)"
    }

    private func qibla(
        from coordinate:
            CLLocationCoordinate2D
    ) -> Double {

        let kaaba = (
            lat: 21.4225,
            lon: 39.8262
        )

        let latitude1 =
            coordinate.latitude
            * .pi / 180

        let latitude2 =
            kaaba.lat
            * .pi / 180

        let deltaLongitude =
            (kaaba.lon
             - coordinate.longitude)
            * .pi / 180

        let y =
            sin(deltaLongitude)
            * cos(latitude2)

        let x =
            cos(latitude1)
            * sin(latitude2)
            - sin(latitude1)
            * cos(latitude2)
            * cos(deltaLongitude)

        return (
            atan2(y, x)
            * 180 / .pi
            + 360
        )
        .truncatingRemainder(
            dividingBy: 360
        )
    }

    private func saveWidget() {
        guard let times else {
            return
        }

        let next = times.next(timeZone: timeZone)
        let prayerID = next.id

        suite?.set(
            SariContentText.prayerName(prayerID, language: SariLanguage.selected),
            forKey: "nextPrayer"
        )
        suite?.set(prayerID, forKey: "nextPrayerID")
        suite?.set(SariLanguage.selected.rawValue, forKey: "widgetLanguage")
        suite?.set(timeZone.identifier, forKey: "timeZoneID")

        suite?.set(
            next.date.timeIntervalSince1970,
            forKey: "nextPrayerTime"
        )

        suite?.set(
            locationName,
            forKey: "location"
        )

        suite?.set(
            Date().timeIntervalSince1970,
            forKey: "updatedAt"
        )

        suite?.set(
            qiblaBearing,
            forKey: "qiblaBearing"
        )

        WidgetCenter.shared.reloadTimelines(
            ofKind: "SARI.PrayerWidget"
        )
    }

    var effectiveCalculationMethod:
        PrayerCalculationMethod {

        let selected =
            PrayerCalculationMethod(
                rawValue:
                    suite?.string(
                        forKey:
                            "calculationMethod"
                    ) ?? "auto"
            ) ?? .auto

        guard selected == .auto,
              let coordinate else {
            return selected
        }

        return PrayerCalculationMethod
            .autoMethod(
                latitude:
                    coordinate.latitude,
                longitude:
                    coordinate.longitude
            )
    }

    func recalculate() {
        guard let coordinate else {
            return
        }

        applyCoordinate(
            coordinate,
            persist: false
        )

        saveWidget()
        schedulePrayerNotifications()
    }

    func requestNotifications() {
        Task { @MainActor in
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(
                    options: [
                        .alert,
                        .sound,
                        .badge
                    ]
                )
        }
    }

    func schedulePrayerNotifications() {
        guard let times else {
            return
        }

        let center =
            UNUserNotificationCenter.current()

        let prayerIDs = [
            "fajr",
            "dhuhr",
            "asr",
            "maghrib",
            "isha"
        ]

        center
            .removePendingNotificationRequests(
                withIdentifiers:
                    prayerIDs.flatMap {
                        [
                            $0,
                            "\($0)_pre",
                            "\($0)_iqama"
                        ]
                    }
            )

        let iqamaMinutes =
            suite?.integer(
                forKey: "iqamaMinutes"
            ) ?? 15

        let preMinutes =
            suite?.integer(
                forKey:
                    "prePrayerMinutes"
            ) ?? 10

        let iqamaEnabled =
            suite?.object(
                forKey: "iqamaEnabled"
            ) == nil
            ? true
            : suite?.bool(
                forKey: "iqamaEnabled"
            ) ?? true

        let preEnabled =
            suite?.object(
                forKey:
                    "prePrayerEnabled"
            ) == nil
            ? true
            : suite?.bool(
                forKey:
                    "prePrayerEnabled"
            ) ?? true

        let savedSound =
            suite?.string(
                forKey: "adhanSound"
            ) ?? "AdhanAliMulla.caf"

        let validSounds: Set<String> = [
            "AdhanDughariri.caf",
            "AdhanQatami.caf",
            "AdhanBaafif.caf",
            "AdhanAliMulla.caf"
        ]
        let soundName = validSounds.contains(savedSound) ? savedSound : "AdhanAliMulla.caf"
        if soundName != savedSound { suite?.set(soundName, forKey: "adhanSound") }

        let prayers = [
            ("fajr", times.fajr),
            ("dhuhr", times.dhuhr),
            ("asr", times.asr),
            ("maghrib", times.maghrib),
            ("isha", times.isha)
        ]

        for (identifier, date) in prayers {
            let language = SariLanguage.selected
            let name = SariContentText.prayerName(identifier, language: language)

            let enabled =
                suite?.object(
                    forKey:
                        "adhan_\(identifier)"
                ) == nil
                ? true
                : suite?.bool(
                    forKey:
                        "adhan_\(identifier)"
                ) ?? true

            guard enabled else {
                continue
            }

            if preEnabled,
               let preDate =
                Calendar.current.date(
                    byAdding: .minute,
                    value: -preMinutes,
                    to: date
                ),
               preDate > .now {

                addNotification(
                    center: center,
                    id:
                        "\(identifier)_pre",
                    title: SariContentText.pick(language,[.ar:"اقتربت صلاة \(name)",.en:"\(name) is approaching",.tr:"\(name) yaklaşıyor",.ms:"\(name) semakin hampir",.id:"\(name) semakin dekat",.ja:"\(name) までまもなく",.zh:"\(name) 即将到来",.ru:"Скоро \(name)",.fr:"\(name) approche"]),
                    body: SariContentText.pick(language,[.ar:"متبقي نحو \(preMinutes) دقائق",.en:"About \(preMinutes) minutes remaining",.tr:"Yaklaşık \(preMinutes) dakika kaldı",.ms:"Kira-kira \(preMinutes) minit lagi",.id:"Sekitar \(preMinutes) menit lagi",.ja:"あと約\(preMinutes)分",.zh:"约剩 \(preMinutes) 分钟",.ru:"Осталось около \(preMinutes) мин.",.fr:"Environ \(preMinutes) min restantes"]),
                    date: preDate,
                    sound: nil
                )
            }

            if date > .now {
                addNotification(
                    center: center,
                    id: identifier,
                    title: SariContentText.pick(language,[.ar:"حان وقت صلاة \(name)",.en:"It is time for \(name)",.tr:"\(name) vakti",.ms:"Waktu \(name)",.id:"Waktu \(name)",.ja:"\(name) の時間です",.zh:"\(name) 时间到了",.ru:"Время \(name)",.fr:"C’est l’heure de \(name)"]),
                    body: SariContentText.pick(language,[.ar:"ساري يذكّرك بالصلاة",.en:"SARI reminds you to pray",.tr:"SARI namazı hatırlatıyor",.ms:"SARI mengingatkan anda untuk solat",.id:"SARI mengingatkan Anda untuk salat",.ja:"SARIから礼拝のお知らせです",.zh:"SARI 提醒您礼拜",.ru:"SARI напоминает о молитве",.fr:"SARI vous rappelle la prière"]),
                    date: date,
                    sound: soundName
                )
            }

            let customIqama = suite?.integer(forKey: "iqama_\(identifier)") ?? 0
            let effectiveIqama = customIqama > 0 ? customIqama : (iqamaMinutes > 0 ? iqamaMinutes : 15)

            if iqamaEnabled,
               let iqamaDate =
                Calendar.current.date(
                    byAdding: .minute,
                    value: effectiveIqama,
                    to: date
                ),
               iqamaDate > .now {

                addNotification(
                    center: center,
                    id:
                        "\(identifier)_iqama",
                    title: SariContentText.pick(language,[.ar:"تنبيه الإقامة — \(name)",.en:"Iqama — \(name)",.tr:"Kamet — \(name)",.ms:"Iqamah — \(name)",.id:"Iqamah — \(name)",.ja:"イカーマ — \(name)",.zh:"成拜 — \(name)",.ru:"Икамат — \(name)",.fr:"Iqama — \(name)"]),
                    body: SariContentText.pick(language,[.ar:"حان موعد الإقامة الذي حددته",.en:"Your selected Iqama time has arrived",.tr:"Ayarladığınız kamet zamanı geldi",.ms:"Masa Iqamah yang ditetapkan telah tiba",.id:"Waktu Iqamah yang Anda atur telah tiba",.ja:"設定したイカーマ時刻です",.zh:"您设定的成拜时间到了",.ru:"Наступило выбранное время икамата",.fr:"L’heure d’Iqama choisie est arrivée"]),
                    date: iqamaDate,
                    sound: nil
                )
            }
        }
    }

    private func addNotification(
        center:
            UNUserNotificationCenter,
        id: String,
        title: String,
        body: String,
        date: Date,
        sound: String?
    ) {
        let content =
            UNMutableNotificationContent()

        content.title = title
        content.body = body

        if let sound {
            content.sound =
                UNNotificationSound(
                    named:
                        UNNotificationSoundName(
                            rawValue: sound
                        )
                )
        } else {
            content.sound = .default
        }

        // Build notification components in the prayer-location time zone. Using
        // Calendar.current here can schedule the correct absolute Date at the wrong
        // wall-clock time while travelling or when automatic time-zone switching lags.
        var notificationCalendar = Calendar(identifier: .gregorian)
        notificationCalendar.timeZone = timeZone
        var components = notificationCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        components.timeZone = timeZone

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let request =
            UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: trigger
            )

        center.add(request)
    }
}