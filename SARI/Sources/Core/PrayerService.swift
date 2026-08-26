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

    func next(after now: Date = .now) -> (String, Date) {
        let items = [
            ("الفجر", fajr),
            ("الشروق", sunrise),
            ("الظهر", dhuhr),
            ("العصر", asr),
            ("المغرب", maghrib),
            ("العشاء", isha)
        ]

        if let next = items.first(where: { $0.1 > now }) {
            return next
        }

        return (
            "الفجر",
            Calendar.current.date(
                byAdding: .day,
                value: 1,
                to: fajr
            ) ?? fajr
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
            let defaults = UserDefaults(
                suiteName: "group.sa.sari.app"
            )

            return (
                defaults?.double(
                    forKey: "customFajrAngle"
                ) ?? 18,
                defaults?.double(
                    forKey: "customIshaAngle"
                ) ?? 17,
                0
            )
        }
    }

    static func autoMethod(
        latitude: Double,
        longitude: Double
    ) -> PrayerCalculationMethod {

        if latitude >= 16,
           latitude <= 33,
           longitude >= 34,
           longitude <= 56 {
            return .ummAlQura
        }

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

    var factor: Double {
        self == .hanafi ? 2 : 1
    }
}

enum PrayerCalculator {

    static func calculate(
        date: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone = .current,
        method: PrayerCalculationMethod = .auto,
        asrMethod: AsrJuristicMethod = .standard,
        offsets: [String: Int] = [:]
    ) -> PrayerTimes {

        let calendar = Calendar(
            identifier: .gregorian
        )

        let components = calendar.dateComponents(
            in: timeZone,
            from: date
        )

        let year = components.year!
        let month = components.month!
        let day = components.day!

        let julian = julianDay(
            year,
            month,
            day
        ) - longitude / 360.0

        let n = julian - 2451545.0 + 0.0008
        let jStar = n - longitude / 360.0

        let meanAnomaly = norm(
            357.5291 + 0.98560028 * jStar
        )

        let equationCenter =
            1.9148 * sinD(meanAnomaly)
            + 0.0200 * sinD(2 * meanAnomaly)
            + 0.0003 * sinD(3 * meanAnomaly)

        let lambda = norm(
            meanAnomaly
            + equationCenter
            + 180
            + 102.9372
        )

        let jTransit =
            2451545.0
            + jStar
            + 0.0053 * sinD(meanAnomaly)
            - 0.0069 * sinD(2 * lambda)

        let delta =
            asin(
                sinD(lambda) * sinD(23.44)
            ) * 180 / .pi

        func hourAngle(
            _ altitude: Double
        ) -> Double {

            let numerator =
                sinD(altitude)
                - sinD(latitude) * sinD(delta)

            let denominator =
                cosD(latitude) * cosD(delta)

            return acos(
                max(
                    -1,
                    min(
                        1,
                        numerator / denominator
                    )
                )
            ) * 180 / .pi
        }

        let parameters = method.parameters(
            latitude: latitude,
            longitude: longitude
        )

        let sunAngle = hourAngle(-0.833)
        let fajrAngle = hourAngle(
            -parameters.fajr
        )

        let transit = fromJulian(
            jTransit,
            timeZone
        )

        let sunrise = fromJulian(
            jTransit - sunAngle / 360,
            timeZone
        )

        let sunset = fromJulian(
            jTransit + sunAngle / 360,
            timeZone
        )

        let fajr = fromJulian(
            jTransit - fajrAngle / 360,
            timeZone
        )

        let isha: Date

        if let angle = parameters.ishaAngle {
            isha = fromJulian(
                jTransit
                + hourAngle(-angle) / 360,
                timeZone
            )
        } else {
            isha = Calendar.current.date(
                byAdding: .minute,
                value: parameters.ishaMinutes,
                to: sunset
            ) ?? sunset
        }

        let asrAltitude =
            -atan(
                1.0 / (
                    asrMethod.factor
                    + tan(
                        abs(
                            (latitude - delta)
                            * .pi / 180
                        )
                    )
                )
            ) * 180 / .pi

        let asr = fromJulian(
            jTransit
            + hourAngle(asrAltitude) / 360,
            timeZone
        )

        func adjusted(
            _ date: Date,
            _ key: String
        ) -> Date {
            Calendar.current.date(
                byAdding: .minute,
                value: offsets[key] ?? 0,
                to: date
            ) ?? date
        }

        return PrayerTimes(
            fajr: adjusted(fajr, "fajr"),
            sunrise: adjusted(
                sunrise,
                "sunrise"
            ),
            dhuhr: adjusted(
                transit,
                "dhuhr"
            ),
            asr: adjusted(asr, "asr"),
            maghrib: adjusted(
                sunset,
                "maghrib"
            ),
            isha: adjusted(isha, "isha")
        )
    }

    private static func julianDay(
        _ year: Int,
        _ month: Int,
        _ day: Int
    ) -> Double {

        var y = year
        var m = month

        if m <= 2 {
            y -= 1
            m += 12
        }

        let a = y / 100
        let b = 2 - a + a / 4

        return floor(
            365.25 * Double(y + 4716)
        )
        + floor(
            30.6001 * Double(m + 1)
        )
        + Double(day + b)
        - 1524.5
    }

    private static func fromJulian(
        _ julian: Double,
        _ timeZone: TimeZone
    ) -> Date {
        Date(
            timeIntervalSince1970:
                (julian - 2440587.5)
                * 86400.0
        )
    }

    private static func norm(
        _ value: Double
    ) -> Double {
        var result = value
            .truncatingRemainder(
                dividingBy: 360
            )

        if result < 0 {
            result += 360
        }

        return result
    }

    private static func sinD(
        _ value: Double
    ) -> Double {
        sin(value * .pi / 180)
    }

    private static func cosD(
        _ value: Double
    ) -> Double {
        cos(value * .pi / 180)
    }
}

@MainActor
final class PrayerStore:
    NSObject,
    ObservableObject,
    CLLocationManagerDelegate {

    @Published var locationName = "موقعك"
    @Published var coordinate:
        CLLocationCoordinate2D?
    @Published var times: PrayerTimes?
    @Published var qiblaBearing:
        Double = 0
    @Published var locationMessage:
        String?
    @Published var locationDenied = false

    private let manager =
        CLLocationManager()

    private let suite =
        UserDefaults(
            suiteName: "group.sa.sari.app"
        )

    override init() {
        super.init()

        manager.delegate = self
        manager.desiredAccuracy =
            kCLLocationAccuracyKilometer

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

            locationMessage =
                "يتم استخدام آخر موقع محفوظ حتى يتم تحديث الموقع."
        }
    }

    func start() {
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
            locationMessage =
                "صلاحية الموقع غير متاحة. يمكن الاستمرار بآخر موقع محفوظ أو تفعيل الموقع من إعدادات الجهاز."

        @unknown default:
            locationMessage =
                "تعذر تحديد حالة صلاحية الموقع."
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

            locationMessage =
                "صلاحية الموقع غير متاحة. يمكن الاستمرار بآخر موقع محفوظ."

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
                location
            ) { [weak self] placemarks, _ in

                let name =
                    placemarks?.first?.locality
                    ?? placemarks?.first?
                        .administrativeArea
                    ?? "موقعك"

                Task { @MainActor in
                    self?.locationName = name
                    self?.saveWidget()
                }
            }
    }

    private func handleLocationFailure() {
        locationMessage =
            coordinate == nil
            ? "تعذر تحديد الموقع ولا يوجد موقع محفوظ بعد."
            : "تعذر تحديث الموقع؛ يتم استخدام آخر موقع محفوظ."
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

        times =
            PrayerCalculator.calculate(
                date: .now,
                latitude:
                    coordinate.latitude,
                longitude:
                    coordinate.longitude,
                method: method,
                asrMethod: asrMethod,
                offsets: offsets
            )
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

        let next = times.next()

        suite?.set(
            next.0,
            forKey: "nextPrayer"
        )

        suite?.set(
            next.1.timeIntervalSince1970,
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
        UNUserNotificationCenter.current()
            .requestAuthorization(
                options: [
                    .alert,
                    .sound,
                    .badge
                ]
            ) { _, _ in }
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

        let soundName =
            suite?.string(
                forKey: "adhanSound"
            ) ?? "Alimula_29s.caf"

        let prayers = [
            ("fajr", "الفجر", times.fajr),
            ("dhuhr", "الظهر", times.dhuhr),
            ("asr", "العصر", times.asr),
            (
                "maghrib",
                "المغرب",
                times.maghrib
            ),
            ("isha", "العشاء", times.isha)
        ]

        for (
            identifier,
            name,
            date
        ) in prayers {

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
                    title:
                        "اقتربت صلاة \(name)",
                    body:
                        "متبقي نحو \(preMinutes) دقائق",
                    date: preDate,
                    sound: nil
                )
            }

            if date > .now {
                addNotification(
                    center: center,
                    id: identifier,
                    title:
                        "حان وقت صلاة \(name)",
                    body:
                        "ساري يذكّرك بالصلاة",
                    date: date,
                    sound: soundName
                )
            }

            if iqamaEnabled,
               let iqamaDate =
                Calendar.current.date(
                    byAdding: .minute,
                    value: iqamaMinutes,
                    to: date
                ),
               iqamaDate > .now {

                addNotification(
                    center: center,
                    id:
                        "\(identifier)_iqama",
                    title:
                        "تنبيه الإقامة — \(name)",
                    body:
                        "حان موعد الإقامة الذي حددته",
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

        let components =
            Calendar.current
                .dateComponents(
                    [
                        .year,
                        .month,
                        .day,
                        .hour,
                        .minute
                    ],
                    from: date
                )

        let trigger =
            UNCalendarNotificationTrigger(
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