# SARI iOS — نسخة Build Ready

هذه النسخة مبنية على آخر مشروع مرفوع وآخر سجل Xcode كامل.

## ما تم إصلاحه في هذه النسخة
- إصلاح سبب الفشل الأخير: عدم إنشاء `SARI.app/Info.plist`.
- إنشاء وربط `Info.plist` للتطبيق والـWidget بشكل صريح عبر XcodeGen.
- تعريف WidgetKit extension بشكل صحيح داخل `NSExtension`.
- توحيد أرقام الإصدار بين التطبيق والـWidget.
- تثبيت SwiftLlama على `0.1.0` بالضبط.
- تثبيت GitHub Actions على Xcode 16.4.
- إدراج الموارد بشكل صريح في Copy Bundle Resources.
- إضافة فحوصات CI تمنع إنتاج IPA إذا كانت Info.plist أو الموارد أو إعدادات الـWidget غير صحيحة.
- جعل تحميل ملفات JSON والصوت يعمل سواء نسخها Xcode في مجلدها أو في جذر Bundle.

## طريقة الاستخدام
انسخ كل محتويات هذا المجلد فوق مجلد مشروعك الحالي `SARI-iOS` مع اختيار Replace، لكن لا تحذف مجلد `.git` الموجود عندك.

ثم نفذ:

```powershell
& "$env:LOCALAPPDATA\GitHubDesktop\app-*\resources\app\git\cmd\git.exe" status
& "$env:LOCALAPPDATA\GitHubDesktop\app-*\resources\app\git\cmd\git.exe" add .
& "$env:LOCALAPPDATA\GitHubDesktop\app-*\resources\app\git\cmd\git.exe" commit -m "Fix final iOS bundle and build validation"
& "$env:LOCALAPPDATA\GitHubDesktop\app-*\resources\app\git\cmd\git.exe" push origin main
```

بعدها افتح GitHub Actions. عند نجاح التشغيل ستجد Artifact باسم `SARI-iPhone-unsigned` ويحتوي `SARI-unsigned.ipa` وسجل البناء وإعدادات التطبيق والـWidget.

## ملاحظة مهمة
نجاح هذا الـBuild لا يجهز تلقائياً خدمة backend أو حزمة نموذج الفقه المحلية؛ هذه تحتاج روابط استضافة حقيقية وملفات الإنتاج كما هو موضح في تقرير التدقيق.
