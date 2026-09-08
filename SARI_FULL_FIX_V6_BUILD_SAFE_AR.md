# SARI iOS — Full Fix v6 Build Safe

الإصدار: **0.9.1 (10)**

هذه النسخة تصلح خطأ GitHub Actions / Xcode الحالي:

`Multiple commands produce ... SARI.app/scholars.json`

## السبب
كان `scholars.json` موجودًا مرتين داخل موارد Target التطبيق:

- `SARI/Resources/data/scholars.json`
- `SharedResources/data/scholars.json`

وكان Xcode يحاول نسخ الملفين إلى نفس المسار داخل `SARI.app`، لذلك كان يتوقف قبل مرحلة تجميع Swift بخطأ `exit code 65`.

## الإصلاح
- الإبقاء على النسخة الحديثة الوحيدة: `SARI/Resources/data/scholars.json` (17 جهة اتصال).
- إزالة النسخة القديمة المكررة من `SharedResources/data`.
- إضافة `scripts/preflight_ios.py` لمنع تكرار أي مورد Bundle مستقبلًا قبل XcodeGen/Xcode.
- إضافة فحص JSON / SQLite / Plist / الدول / القرآن / الأذكار / المشايخ / ملفات الأذان.
- إضافة `swiftc -parse` لجميع ملفات Swift داخل GitHub Actions قبل البناء.
- إعادة إنشاء `SARI.xcodeproj` من الصفر في كل تشغيل حتى لا يبقى مشروع مولد قديم.
- جعل اختيار Xcode يفضّل 16.4 ويعود تلقائيًا إلى Xcode الافتراضي إذا لم يعد 16.4 موجودًا على runner مستقبلًا.
- التحقق من Bundle IDs وInfo.plist وموارد التطبيق والـWidget بعد البناء.
- توحيد إصدار التطبيق والـWidget على 0.9.1 (10).

## التحقق المحلي قبل التسليم
- `swiftc -parse` لجميع ملفات Swift: ناجح.
- `scripts/preflight_ios.py`: ناجح.
- جميع JSON: سليمة.
- قاعدة `fiqh_pages.sqlite3`: `integrity_check = ok` وعدد الصفحات 4099.
- القرآن: 6236 آية و604 صفحات.
- الدول: 195 رمزًا فريدًا، فلسطين موجودة، وIL غير موجود.
- المشايخ: 17 رقمًا بدون تكرار.
- لا يوجد أي resource collision حاليًا في Target التطبيق.
- ملفات CAF الأربعة موجودة ومددها أقل من 30 ثانية.

## ملاحظة
التحقق الكامل من Xcode نفسه لا يمكن تنفيذه على بيئة Linux الحالية. GitHub Actions على macOS/Xcode هو الاختبار النهائي للـtype-check/link/build. هذه النسخة أزيل منها سبب الخطأ الحالي وأضيفت فحوصات مبكرة لتقليل تكرار أخطاء مشابهة.
