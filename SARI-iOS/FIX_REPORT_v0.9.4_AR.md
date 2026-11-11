# SARI iOS — v0.9.4 Build 13

## سبب فشل Build السابق
أظهر سجل GitHub Actions أن Xcode 16.4 / Swift 6 رفض تنفيذ
`UNUserNotificationCenterDelegate` داخل نفس `UIApplicationDelegate` لأن الأول غير معزول
بينما `UIApplicationDelegate` معزول على `MainActor`. الخطأ كان في
`SARI/Sources/App/SariAppDelegate.swift` ولم يكن من SwiftLlama أو ملفات الأذان.

## الإصلاح
- فصل `UNUserNotificationCenterDelegate` إلى كائن مستقل `SariNotificationDelegate`.
- الإبقاء على `SariAppDelegate` مخصصًا لـ `UIApplicationDelegate` فقط ومعزولًا على `MainActor`.
- استخدام callback التقليدي `willPresent(...withCompletionHandler:)` لتفادي تعارضات Sendable/Actor في Xcode 16.4.
- الاحتفاظ بمندوب الإشعارات بقوة لأن `UNUserNotificationCenter.delegate` مرجع ضعيف.
- الإبقاء على عرض banner/list والصوت عند وصول الإشعار والتطبيق مفتوح.

## فحص ملفات الأذان
ملفات CAF الأربعة موجودة مباشرة في موارد التطبيق وبأسماء مطابقة للكود:
- AdhanAliMulla.caf — PCM 16-bit mono 22050 Hz — ~20.39s
- AdhanBaafif.caf — PCM 16-bit mono 22050 Hz — ~25.61s
- AdhanDughariri.caf — PCM 16-bit mono 22050 Hz — ~16.67s
- AdhanQatami.caf — PCM 16-bit mono 22050 Hz — ~23.92s

جميعها أقل من 30 ثانية، والكود يتحقق من وجود الملف قبل استخدامه ويعود لصوت النظام
إذا لم يجده. كما توجد معاينات M4A منفصلة داخل `SARI/Resources/audio`.

## رقم الإصدار
- MARKETING_VERSION: 0.9.4
- CURRENT_PROJECT_VERSION: 13
