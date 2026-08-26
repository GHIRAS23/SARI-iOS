import Foundation
import CoreLocation
import UserNotifications
import WidgetKit

struct PrayerTimes: Codable {
    let fajr: Date; let sunrise: Date; let dhuhr: Date; let asr: Date; let maghrib: Date; let isha: Date
    func next(after now: Date = .now) -> (String, Date) {
        let items = [("الفجر",fajr),("الشروق",sunrise),("الظهر",dhuhr),("العصر",asr),("المغرب",maghrib),("العشاء",isha)]
        if let n = items.first(where: { $0.1 > now }) { return n }
        return ("الفجر", Calendar.current.date(byAdding: .day, value: 1, to: fajr) ?? fajr)
    }
}

enum PrayerCalculationMethod:String,CaseIterable,Identifiable {
    case auto, ummAlQura, muslimWorldLeague, isna, egyptian, karachi, dubai, qatar, kuwait, singapore, turkey, tehran, custom
    var id:String{rawValue}
    var title:String {
        switch self {
        case .auto:return "تلقائي حسب الموقع"; case .ummAlQura:return "أم القرى — مكة المكرمة"
        case .muslimWorldLeague:return "رابطة العالم الإسلامي"; case .isna:return "ISNA — أمريكا الشمالية"
        case .egyptian:return "الهيئة المصرية العامة للمساحة"; case .karachi:return "جامعة العلوم الإسلامية — كراتشي"
        case .dubai:return "دبي"; case .qatar:return "قطر"; case .kuwait:return "الكويت"; case .singapore:return "سنغافورة"
        case .turkey:return "رئاسة الشؤون الدينية التركية"; case .tehran:return "طهران"; case .custom:return "مخصص"
        }
    }
    func parameters(latitude:Double,longitude:Double)->(fajr:Double,ishaAngle:Double?,ishaMinutes:Int) {
        switch self {
        case .auto: return PrayerCalculationMethod.autoMethod(latitude:latitude,longitude:longitude).parameters(latitude:latitude,longitude:longitude)
        case .ummAlQura:return (18.5,nil,90)
        case .muslimWorldLeague:return (18,17,0)
        case .isna:return (15,15,0)
        case .egyptian:return (19.5,17.5,0)
        case .karachi:return (18,18,0)
        case .dubai:return (18.2,18.2,0)
        case .qatar:return (18,nil,90)
        case .kuwait:return (18,17.5,0)
        case .singapore:return (20,18,0)
        case .turkey:return (18,17,0)
        case .tehran:return (17.7,14,0)
        case .custom:
            let d=UserDefaults(suiteName:"group.sa.sari.app")
            return (d?.double(forKey:"customFajrAngle") ?? 18, d?.double(forKey:"customIshaAngle") ?? 17,0)
        }
    }
    static func autoMethod(latitude:Double,longitude:Double)->PrayerCalculationMethod {
        // Conservative geographic defaults; user can always override.
        if latitude >= 16 && latitude <= 33 && longitude >= 34 && longitude <= 56 { return .ummAlQura }
        if latitude >= 24 && latitude <= 27 && longitude >= 50 && longitude <= 52 { return .qatar }
        if latitude >= 28 && latitude <= 31 && longitude >= 46 && longitude <= 49 { return .kuwait }
        if latitude >= 24 && latitude <= 26.5 && longitude >= 54 && longitude <= 56.5 { return .dubai }
        if latitude >= 1 && latitude <= 2 && longitude >= 103 && longitude <= 105 { return .singapore }
        if latitude >= 35 && latitude <= 43 && longitude >= 25 && longitude <= 45 { return .turkey }
        if latitude >= 24 && latitude <= 50 && longitude >= -170 && longitude <= -50 { return .isna }
        return .muslimWorldLeague
    }
}

enum AsrJuristicMethod:String,CaseIterable,Identifiable {
    case standard, hanafi
    var id:String{rawValue}
    var title:String{self == .hanafi ? "حنفي — ظلّان" : "الجمهور — ظل واحد"}
    var factor:Double{self == .hanafi ? 2 : 1}
}

enum PrayerCalculator {
    static func calculate(date: Date, latitude: Double, longitude: Double, timeZone: TimeZone = .current,
                          method:PrayerCalculationMethod = .auto, asrMethod:AsrJuristicMethod = .standard,
                          offsets:[String:Int] = [:]) -> PrayerTimes {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents(in: timeZone, from: date)
        let y = comps.year!, m = comps.month!, d = comps.day!
        let jd = julianDay(y,m,d) - longitude / 360.0
        let n = jd - 2451545.0 + 0.0008
        let jStar = n - longitude / 360.0
        let M = norm(357.5291 + 0.98560028 * jStar)
        let C = 1.9148*sinD(M) + 0.0200*sinD(2*M) + 0.0003*sinD(3*M)
        let lambda = norm(M + C + 180 + 102.9372)
        let jTransit = 2451545.0 + jStar + 0.0053*sinD(M) - 0.0069*sinD(2*lambda)
        let delta = asin(sinD(lambda) * sinD(23.44)) * 180 / .pi
        func hourAngle(_ altitude: Double) -> Double {
            let num = sinD(altitude) - sinD(latitude)*sinD(delta), den = cosD(latitude)*cosD(delta)
            return acos(max(-1,min(1,num/den))) * 180 / .pi
        }
        let params=method.parameters(latitude:latitude,longitude:longitude)
        let hSun=hourAngle(-0.833), hFajr=hourAngle(-params.fajr)
        let transit=fromJulian(jTransit,timeZone), sunrise=fromJulian(jTransit-hSun/360,timeZone), sunset=fromJulian(jTransit+hSun/360,timeZone)
        let fajr=fromJulian(jTransit-hFajr/360,timeZone)
        let isha:Date
        if let a=params.ishaAngle { isha=fromJulian(jTransit+hourAngle(-a)/360,timeZone) }
        else { isha=Calendar.current.date(byAdding:.minute,value:params.ishaMinutes,to:sunset) ?? sunset }
        let asrAlt = -atan(1.0 / (asrMethod.factor + tan(abs((latitude-delta) * .pi/180)))) * 180 / .pi
        let asr=fromJulian(jTransit+hourAngle(asrAlt)/360,timeZone)
        func off(_ d:Date,_ key:String)->Date{Calendar.current.date(byAdding:.minute,value:offsets[key] ?? 0,to:d) ?? d}
        return .init(fajr:off(fajr,"fajr"),sunrise:off(sunrise,"sunrise"),dhuhr:off(transit,"dhuhr"),asr:off(asr,"asr"),maghrib:off(sunset,"maghrib"),isha:off(isha,"isha"))
    }
    private static func julianDay(_ y:Int,_ m:Int,_ d:Int)->Double { var yy=y; var mm=m; if mm<=2 {yy-=1;mm+=12}; let a=yy/100; let b=2-a+a/4; return floor(365.25*Double(yy+4716))+floor(30.6001*Double(mm+1))+Double(d+b)-1524.5 }
    private static func fromJulian(_ jd:Double,_ tz:TimeZone)->Date { Date(timeIntervalSince1970: (jd - 2440587.5) * 86400.0) }
    private static func norm(_ x:Double)->Double { var v=x.truncatingRemainder(dividingBy:360); if v<0{v+=360}; return v }
    private static func sinD(_ x:Double)->Double { sin(x * .pi/180) }
    private static func cosD(_ x:Double)->Double { cos(x * .pi/180) }
}
@MainActor final class PrayerStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var locationName = "موقعك"
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var times: PrayerTimes?
    @Published var qiblaBearing: Double = 0
    @Published var locationMessage:String?
    @Published var locationDenied=false
    private let manager = CLLocationManager()
    private let suite = UserDefaults(suiteName: "group.sa.sari.app")

    override init() {
        super.init(); manager.delegate=self; manager.desiredAccuracy=kCLLocationAccuracyKilometer
        if let lat=suite?.object(forKey:"lastLatitude") as? Double,let lon=suite?.object(forKey:"lastLongitude") as? Double {
            applyCoordinate(CLLocationCoordinate2D(latitude:lat,longitude:lon),persist:false)
            locationMessage="يتم استخدام آخر موقع محفوظ حتى يتم تحديث الموقع."
        }
    }
    func start() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways,.authorizedWhenInUse: manager.requestLocation()
        case .denied,.restricted: locationDenied=true;locationMessage="صلاحية الموقع غير متاحة. يمكن الاستمرار بآخر موقع محفوظ أو تفعيل الموقع من إعدادات الجهاز."
        @unknown default: locationMessage="تعذر تحديد حالة صلاحية الموقع."
        }
    }
    func locationManagerDidChangeAuthorization(_ manager:CLLocationManager){
        switch manager.authorizationStatus {
        case .authorizedAlways,.authorizedWhenInUse: locationDenied=false;locationMessage=nil;manager.requestLocation()
        case .denied,.restricted: locationDenied=true;locationMessage="صلاحية الموقع غير متاحة. يمكن الاستمرار بآخر موقع محفوظ."
        default: break
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc=locations.last else{return}; applyCoordinate(loc.coordinate,persist:true);locationDenied=false;locationMessage=nil
        let method=PrayerCalculationMethod(rawValue:suite?.string(forKey:"calculationMethod") ?? "auto") ?? .auto
        let asr=AsrJuristicMethod(rawValue:suite?.string(forKey:"asrMethod") ?? "standard") ?? .standard
        let ids=["fajr","sunrise","dhuhr","asr","maghrib","isha"]
        let offsets=Dictionary(uniqueKeysWithValues:ids.map{($0,suite?.integer(forKey:"offset_\($0)") ?? 0)})
        times=PrayerCalculator.calculate(date:.now, latitude:loc.coordinate.latitude, longitude:loc.coordinate.longitude, method:method, asrMethod:asr, offsets:offsets)
        qiblaBearing = qibla(from: loc.coordinate)
        saveWidget(); schedulePrayerNotifications()
        CLGeocoder().reverseGeocodeLocation(loc) { [weak self] p,_ in
            if let p=p?.first { Task { @MainActor in self?.locationName = p.locality ?? p.administrativeArea ?? "موقعك"; self?.saveWidget() } }
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationMessage = coordinate == nil ? "تعذر تحديد الموقع ولا يوجد موقع محفوظ بعد." : "تعذر تحديث الموقع؛ يتم استخدام آخر موقع محفوظ."
    }
    private func applyCoordinate(_ c:CLLocationCoordinate2D,persist:Bool){
        coordinate=c;qiblaBearing=qibla(from:c)
        if persist {suite?.set(c.latitude,forKey:"lastLatitude");suite?.set(c.longitude,forKey:"lastLongitude")}
        let method=PrayerCalculationMethod(rawValue:suite?.string(forKey:"calculationMethod") ?? "auto") ?? .auto
        let asr=AsrJuristicMethod(rawValue:suite?.string(forKey:"asrMethod") ?? "standard") ?? .standard
        let ids=["fajr","sunrise","dhuhr","asr","maghrib","isha"];let offsets=Dictionary(uniqueKeysWithValues:ids.map{($0,suite?.integer(forKey:"offset_\($0)") ?? 0)})
        times=PrayerCalculator.calculate(date:.now,latitude:c.latitude,longitude:c.longitude,method:method,asrMethod:asr,offsets:offsets)
    }
    private func qibla(from c:CLLocationCoordinate2D)->Double { let kaaba=(lat:21.4225,lon:39.8262); let p1=c.latitude * .pi/180, p2=kaaba.lat * .pi/180, dl=(kaaba.lon-c.longitude)*.pi/180; let y=sin(dl)*cos(p2), x=cos(p1)*sin(p2)-sin(p1)*cos(p2)*cos(dl); return (atan2(y,x)*180/.pi+360).truncatingRemainder(dividingBy:360) }
    private func saveWidget(){
        guard let t=times else{return}; let n=t.next()
        suite?.set(n.0,forKey:"nextPrayer"); suite?.set(n.1.timeIntervalSince1970,forKey:"nextPrayerTime")
        suite?.set(locationName,forKey:"location"); suite?.set(Date().timeIntervalSince1970,forKey:"updatedAt")
        suite?.set(qiblaBearing,forKey:"qiblaBearing")
        WidgetCenter.shared.reloadTimelines(ofKind: "SARI.PrayerWidget")
    }

    var effectiveCalculationMethod:PrayerCalculationMethod {
        let selected=PrayerCalculationMethod(rawValue:suite?.string(forKey:"calculationMethod") ?? "auto") ?? .auto
        guard selected == .auto, let c=coordinate else{return selected}
        return PrayerCalculationMethod.autoMethod(latitude:c.latitude,longitude:c.longitude)
    }
    func recalculate(){ if let c=coordinate {
        let method=PrayerCalculationMethod(rawValue:suite?.string(forKey:"calculationMethod") ?? "auto") ?? .auto
        let asr=AsrJuristicMethod(rawValue:suite?.string(forKey:"asrMethod") ?? "standard") ?? .standard
        let ids=["fajr","sunrise","dhuhr","asr","maghrib","isha"]; let offsets=Dictionary(uniqueKeysWithValues:ids.map{($0,suite?.integer(forKey:"offset_\($0)") ?? 0)})
        times=PrayerCalculator.calculate(date:.now,latitude:c.latitude,longitude:c.longitude,method:method,asrMethod:asr,offsets:offsets); saveWidget(); schedulePrayerNotifications()
    }}
    func requestNotifications(){ UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound,.badge]){_,_ in} }
    func schedulePrayerNotifications(){
        guard let t=times else{return}
        let center=UNUserNotificationCenter.current()
        let prayerIDs=["fajr","dhuhr","asr","maghrib","isha"]
        center.removePendingNotificationRequests(withIdentifiers:prayerIDs.flatMap{[$0,"\($0)_pre","\($0)_iqama"]})
        let iqamaMinutes = suite?.integer(forKey:"iqamaMinutes") ?? 15
        let preMinutes = suite?.integer(forKey:"prePrayerMinutes") ?? 10
        let iqamaEnabled = suite?.object(forKey:"iqamaEnabled") == nil ? true : (suite?.bool(forKey:"iqamaEnabled") ?? true)
        let preEnabled = suite?.object(forKey:"prePrayerEnabled") == nil ? true : (suite?.bool(forKey:"prePrayerEnabled") ?? true)
        let soundName = suite?.string(forKey:"adhanSound") ?? "Alimula_29s.caf"
        let items=[("fajr","الفجر",t.fajr),("dhuhr","الظهر",t.dhuhr),("asr","العصر",t.asr),("maghrib","المغرب",t.maghrib),("isha","العشاء",t.isha)]
        for (id,name,date) in items {
            let enabled = suite?.object(forKey:"adhan_\(id)") == nil ? true : (suite?.bool(forKey:"adhan_\(id)") ?? true)
            guard enabled else { continue }
            if preEnabled, let pre=Calendar.current.date(byAdding:.minute,value:-preMinutes,to:date), pre > .now {
                addNotification(center:center,id:"\(id)_pre",title:"اقتربت صلاة \(name)",body:"متبقي نحو \(preMinutes) دقائق",date:pre,sound:nil)
            }
            if date > .now { addNotification(center:center,id:id,title:"حان وقت صلاة \(name)",body:"ساري يذكّرك بالصلاة",date:date,sound:soundName) }
            if iqamaEnabled, let iqama=Calendar.current.date(byAdding:.minute,value:iqamaMinutes,to:date), iqama > .now {
                addNotification(center:center,id:"\(id)_iqama",title:"تنبيه الإقامة — \(name)",body:"حان موعد الإقامة الذي حددته",date:iqama,sound:nil)
            }
        }
    }
    private func addNotification(center:UNUserNotificationCenter,id:String,title:String,body:String,date:Date,sound:String?){
        let c=UNMutableNotificationContent(); c.title=title; c.body=body
        if let sound { c.sound=UNNotificationSound(named: UNNotificationSoundName(rawValue:sound)) } else { c.sound = .default }
        let comps=Calendar.current.dateComponents([.year,.month,.day,.hour,.minute],from:date)
        let trig=UNCalendarNotificationTrigger(dateMatching:comps,repeats:false)
        center.add(UNNotificationRequest(identifier:id,content:c,trigger:trig))
    }
}
