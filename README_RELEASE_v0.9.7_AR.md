# ساري SARI — حزمة التطوير 0.9.7

هذه النسخة هي مشروع iOS، وتشمل التفسير الميسر، والمساعد الفقهي المحلي والتنزيل في الخلفية، وخدمات الأذكار والسفر الجديدة.

## البدء

- افتح `project.yml` باستخدام XcodeGen: `xcodegen generate`.
- افتح `SARI.xcodeproj` في Xcode 16.4 أو أحدث متوافق مع إعداد المشروع.
- نفذ الاختبارات الثابتة:

```bash
python3 scripts/preflight_ios.py
python3 scripts/validate_fiqh_release.py
python3 scripts/validate_prayer_math.py
python3 scripts/validate_travel_release.py
```

- للبناء دون توقيع:

```bash
xcodebuild -project SARI.xcodeproj -scheme SARI -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## وثائق مهمة

- `RELEASE_NOTES_v0.9.7_AR.md` — ملاحظات الإصدار والحدود المعروفة.
- `FULL_MODIFICATION_REPORT_AR.md` — تقرير التعديلات والاختبارات.
- `SARI_BACKEND_INTEGRATION_AR.md` — عقد API المطلوب لدليل السفارات.
- `QURAN_TAFSIR_RESTORATION_AR.md` — استعادة التفسير الميسر.

## قبل الاعتماد

راجع ملاحظات الإصدار. توجد خدمات تحتاج إعدادًا خارجيًا، ولا توجد بيانات رسمية عالمية للسفارات مدمجة داخل المشروع. كما أن ترجمة الأذكار وتغطية الأكلات لا تزالان جزئيتين بحسب المصادر الحالية.
