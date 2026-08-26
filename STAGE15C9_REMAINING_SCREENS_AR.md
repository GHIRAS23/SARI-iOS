# SARI — Stage 15C9: Quran / Prayer / Fiqh / Settings localization pass

تم توسيع قاموس اللغات التسع للمفاتيح المشتركة الخاصة بالقرآن والتفسير والصلاة والإعدادات والمساعد الفقهي.
أضيفت أدوات تمنع قص النصوص الطويلة وتحد عرض القراءة على الشاشات الكبيرة.

## فصل مهم
ليس كل نص عربي داخل الكود خطأ ترجمة:
- نص القرآن والأذكار والمحتوى الفقهي المصدر يبقى عربيًا حسب نوعه.
- أسماء/رسائل الواجهة يجب أن تمر عبر طبقة اللغات.
لذلك تم فصل تقرير الدين التقني بين UI debt وDomain Arabic لتجنب ترجمة النص الديني آليًا بالخطأ.

## المتبقي
iOS UI debt الأعلى: [('SARI/Sources/Features/Travel/TravelView.swift', 44), ('SARI/Sources/Core/TravelService.swift', 38), ('SARI/Sources/Core/SariStrings.swift', 36), ('SARI/Sources/Core/WeatherService.swift', 30), ('SARI/Sources/Features/Settings/PrayerSettingsView.swift', 23), ('SARI/Sources/Features/Home/HomeView.swift', 22), ('SARI/Sources/Features/Settings/SettingsView.swift', 19), ('SARI/Sources/Features/Quran/QuranView.swift', 18)]
Android UI debt الأعلى: [('app/src/main/java/com/sari/app/travel/TravelScreen.kt', 42), ('app/src/main/java/com/sari/app/ui/SariApp.kt', 41), ('app/src/main/java/com/sari/app/prayer/PrayerSettingsScreen.kt', 15), ('app/src/main/java/com/sari/app/ui/SariStrings.kt', 13), ('app/src/main/java/com/sari/app/ui/SettingsScreen.kt', 13), ('app/src/main/java/com/sari/app/ui/SariFeatureStrings.kt', 13), ('app/src/main/java/com/sari/app/fiqh/FiqhScreen.kt', 13), ('app/src/main/java/com/sari/app/fiqh/FiqhPackSetupScreen.kt', 9)]

لن نعلن اكتمال اللغات التسع حتى تنتهي هذه القائمة وتنجح مراجعة RTL/LTR والنص الطويل.
