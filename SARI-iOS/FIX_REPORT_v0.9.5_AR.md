# SARI iOS v0.9.5 (Build 14) — تقرير الإصلاح والتحقق

## سبب فشل v0.9.4
سجل Xcode 16.4 أظهر خطأ Type-check واحد فعليًا في `LocalFiqhPack.swift`:

`URLError.Code` لا يحتوي على العضو `.cannotResume`.

هذا النوع من الأخطاء لا يظهر في `swiftc -parse` لأنه صحيح نحويًا لكنه غير صحيح عند فحص الأنواع بواسطة Xcode/Swift 6.

## ما تم إصلاحه
- إزالة الاعتماد على `.cannotResume` بالكامل.
- نقل التعامل مع Resume Data إلى `ResumableFileDownloader` نفسه.
- إذا كانت بيانات الاستئناف قديمة/تالفة وفشلت دون إنتاج Resume Data جديدة، يتم حذفها تلقائيًا حتى تبدأ المحاولة التالية بطلب نظيف بدل التكرار على ملف تالف.
- الحفاظ على Resume Data الجديدة عند الانقطاع الحقيقي حتى لا يعاد تنزيل نموذج Qwen من الصفر.
- الإبقاء على التحقق من SHA-256 قبل تفعيل النموذج.
- تحديث الإصدار إلى `0.9.5 (14)` للتطبيق والـWidget معًا.
- إضافة Release Gate جديد في `preflight_ios.py` يمنع رجوع `.cannotResume` مستقبلًا.

## فحوص الإصدار قبل التسليم
تم تشغيل الفحوص التالية على المشروع الكامل:

- `scripts/preflight_ios.py` ✅
- `scripts/validate_prayer_math.py` ✅
- `swiftc -parse` لجميع ملفات Swift ✅
- فحص كل ملفات JSON (51 ملفًا) ✅
- فحص plist / privacy / entitlements ✅
- `PRAGMA integrity_check` لقاعدة SQLite ✅
- التحقق من جميع `URLError.Code` المستخدمة عبر Swift 6/Foundation ✅
- YAML (`project.yml` وGitHub Actions) ✅
- عدم وجود `.cannotResume` في أي مصدر Swift ✅
- فحص ملفات الأذان CAF كصوت فعلي وأقل من 30 ثانية ✅

مدد ملفات الأذان التي تم التحقق منها عبر ffprobe:
- AdhanAliMulla.caf: 20.387 ثانية
- AdhanBaafif.caf: 25.612 ثانية
- AdhanDughariri.caf: 16.672 ثانية
- AdhanQatami.caf: 23.917 ثانية

## ملاحظة مهمة
التحقق النهائي من Type-check/Link لجميع Apple frameworks لا يمكن تنفيذه في بيئة Linux الحالية؛ الاختبار الحاسم يبقى `xcodebuild` على Xcode 16.4 داخل GitHub Actions. لكن خطأ v0.9.4 المحدد تم إزالته، وبقية الملفات الجديدة الخاصة بالتنزيل والأذان وصلت لمرحلة SwiftCompile في سجل Xcode السابق دون ظهور أخطاء خاصة بها.
