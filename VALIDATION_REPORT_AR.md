# SARI iOS — تقرير الإصلاح والتحقق

الهدف: إصلاح فشل GitHub Actions/Xcode عند بناء التطبيق على Xcode 16.4 / Swift 6.

## الإصلاح المطبق
- حذف النسخة القديمة المكررة `SharedResources/data/scholars.json`.
- الإبقاء على النسخة الحديثة المستخدمة فعليًا: `SARI/Resources/data/scholars.json`.
- الإبقاء على `SharedResources/data/travel_directory_schema.json` ضمن موارد التطبيق.
- اعتماد إعدادات `SWIFT_VERSION: 6.0` و `IPHONEOS_DEPLOYMENT_TARGET: 17.0` في `project.yml`.
- اعتماد إصدار التطبيق والـ Widget: `0.9.1 (10)`.
- إضافة/الإبقاء على فحص `scripts/preflight_ios.py` قبل XcodeGen لمنع تكرار تصادم موارد Bundle مستقبلًا.
- GitHub Actions يعيد توليد `SARI.xcodeproj` من `project.yml` في كل تشغيل لتجنب أي مشروع مولد قديم.

## الفحوصات التي نجحت في بيئة التسليم
- `python3 scripts/preflight_ios.py`: ناجح.
- `swiftc -parse` لكل ملفات Swift: ناجح (42 ملف Swift).
- جميع ملفات JSON: سليمة (51 ملفًا بعد الإصلاح).
- ملفات Info.plist / PrivacyInfo.xcprivacy / entitlements: سليمة.
- SQLite integrity / الصفحات / بيانات القرآن / الدول / الأذكار / المشايخ: ناجحة ضمن preflight.
- فحص أسماء موارد Bundle: لا توجد تصادمات.
- `git diff --check`: ناجح.
- `scripts/build_ios_device.sh`: صياغة Bash سليمة.

## الاختبار النهائي
الاختبار النهائي للـ type-check/link/build الخاص بـ SwiftUI وSDK iOS لا يمكن تشغيله إلا على macOS مع Xcode. Workflow الموجود في `.github/workflows/ios-build.yml` ينفذ هذا الاختبار تلقائيًا على GitHub Actions باستخدام Xcode 16.4 عند توفره، ثم ينشئ `SARI-unsigned.ipa` إذا نجح البناء.
