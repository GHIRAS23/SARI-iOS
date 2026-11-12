# SARI — Stage 15A: Static Integrity & Readiness Audit

هذه أول دفعة من Stage 15. الهدف هنا تدقيق الملفات والبنية قبل اختبارات الهاتف الحقيقي.

## القرآن والتفسير
iOS: [('SARI/Resources/data/quran_tafseer.json', 6236, 114, 6236, 0, '759c8cf69ad703e8a0c830386f5d5dd7a502330b5034dda3d4917bced93a8584')]
Android: [('app/src/main/assets/data/quran_tafseer.json', 6236, 114, 6236, 0, '759c8cf69ad703e8a0c830386f5d5dd7a502330b5034dda3d4917bced93a8584')]

النتيجة البنيوية: ملفات القرآن الموجودة قابلة للقراءة، وسيتم فصل التحقق الشرعي/النصي عن مجرد صحة JSON.
لا نعتبر التطابق البنيوي دليلاً على صحة النص أو التفسير.

## نطاق الاختبارات في Stage 15
- القرآن والتفسير والأذكار: سلامة النصوص والمصادر.
- الصلاة: طرق الحساب، العصر، offsets، ومدن متعددة.
- القبلة: حساب الاتجاه مقابل نقاط مرجعية.
- التاريخ: Gregorian + Umm al-Qura + ±2 adjustment.
- اللغات التسع: ar/en/tr/ms/id/ja/zh/ru/fr.
- RTL/LTR وDynamic Type/Font scaling.
- Offline/airplane/failure states.
- أحجام الهاتف والتابلت/الـiPad والواجهات الواسعة.

## ملاحظة
الاختبارات التي تعتمد على GPS، البوصلة، الإشعارات، الحرارة، RAM أو تشغيل Qwen فعليًا لا يمكن اعتمادها من فحص ملفات فقط؛ ستبقى لاختبار الجهاز الحقيقي.

## Platform
Native iOS / SwiftUI
