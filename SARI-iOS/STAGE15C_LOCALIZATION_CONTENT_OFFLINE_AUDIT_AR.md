# SARI — Stage 15C: Localization / Content / Offline Audit

## اللغات
اللغات المستهدفة: ar, en, tr, ms, id, ja, zh, ru, fr.

## نتيجة مهمة
يوجد قدر معتبر من النصوص العربية المكتوبة مباشرة داخل ملفات الواجهة، وليس كلها عبر طبقة الترجمة.
هذا يعني أن إعلان "دعم كامل للغات التسع" غير صحيح بعد. تم تسجيل ذلك كعيب يجب إغلاقه قبل SARI 1.0.

أعلى ملفات iOS ذات النصوص العربية المباشرة:
- SARI/Sources/Features/Travel/TravelView.swift: 44 سطرًا تقريبًا
- SARI/Sources/Core/TravelService.swift: 38 سطرًا تقريبًا
- SARI/Sources/Core/SariStrings.swift: 36 سطرًا تقريبًا
- SARI/Sources/Core/WeatherService.swift: 30 سطرًا تقريبًا
- SARI/Sources/Features/Settings/PrayerSettingsView.swift: 23 سطرًا تقريبًا
- SARI/Sources/Features/Adhkar/AdhkarView.swift: 23 سطرًا تقريبًا
- SARI/Sources/Features/Home/HomeView.swift: 22 سطرًا تقريبًا
- SARI/Sources/Core/PrayerService.swift: 19 سطرًا تقريبًا
- SARI/Sources/Features/Settings/SettingsView.swift: 19 سطرًا تقريبًا
- SARI/Sources/Features/Quran/QuranView.swift: 18 سطرًا تقريبًا

أعلى ملفات Android:
- app/src/main/java/com/sari/app/travel/TravelScreen.kt: 42 سطرًا تقريبًا
- app/src/main/java/com/sari/app/ui/SariApp.kt: 41 سطرًا تقريبًا
- app/src/main/java/com/sari/app/adhkar/AdhkarScreen.kt: 23 سطرًا تقريبًا
- app/src/main/java/com/sari/app/prayer/PrayerSettingsScreen.kt: 15 سطرًا تقريبًا
- app/src/main/java/com/sari/app/ui/SariStrings.kt: 13 سطرًا تقريبًا
- app/src/main/java/com/sari/app/ui/SettingsScreen.kt: 13 سطرًا تقريبًا
- app/src/main/java/com/sari/app/ui/SariFeatureStrings.kt: 13 سطرًا تقريبًا
- app/src/main/java/com/sari/app/fiqh/FiqhScreen.kt: 13 سطرًا تقريبًا
- app/src/main/java/com/sari/app/fiqh/FiqhPackSetupScreen.kt: 9 سطرًا تقريبًا
- app/src/main/java/com/sari/app/ui/OnboardingScreen.kt: 8 سطرًا تقريبًا

## القرآن والتفسير
- القرآن العربي يبقى مستقلًا عن ترجمة التفسير.
- التفسير العربي هو المصدر الأصلي في التطبيق.
- حزم الترجمة اختيارية ومحلية، ولا تعتمد دون فحص SHA-256 + 6236 مدخلًا فريدًا غير فارغ.
- لا يتم في Stage 15C اختلاق ترجمات أو اعتماد ترجمة غير موثقة.

## الأذكار
نتيجة جرد ملفات JSON:
iOS: []
Android: []
إذا لم توجد قاعدة بيانات مستقلة للأذكار، فالنصوص الموجودة داخل الكود تحتاج نقلًا إلى مصدر بيانات موثق قبل المراجعة الشرعية النهائية.

## Offline / Error states
تم تثبيت مصفوفة اختبار للحالات: انقطاع الشبكة، رفض الموقع، غياب الموقع، حزمة تفسير مفقودة/تالفة، وحزمة المساعد الفقهي غير محملة.

## قرار الجودة
Stage 15C لا تعتبر اللغات أو الأذكار "مكتملة" بمجرد أن الشاشة تفتح. يجب إزالة hard-coded UI strings تدريجيًا وربطها بطبقة SariStrings/موارد محلية، ثم مراجعة المحتوى.
