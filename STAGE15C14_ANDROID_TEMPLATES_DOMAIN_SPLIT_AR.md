# SARI Stage 15C14

تم تطبيق localized dynamic templates فعليًا على Android في Travel/Home/Prayer Settings.
عدد الاستبدالات: Travel=1, Home/App=0, Prayer Settings=1.

تم إنشاء `travel_domain_data.json` وفصل 30 قيمة سفر/بلد/مدينة/عملة/لغة عن مفهوم UI debt.
القيم الداخلية لا تُترجم عشوائيًا؛ الترجمة تكون لاسم العرض فقط مع الحفاظ على المعرف/الكود الداخلي.

أعيد فحص Quran/Fiqh/Settings:
iOS: [('SARI/Sources/Features/Settings/SettingsView.swift', 19), ('SARI/Sources/Features/Quran/QuranView.swift', 18), ('SARI/Sources/Features/Settings/PrayerSettingsView.swift', 16), ('SARI/Sources/Features/Fiqh/FiqhAssistantView.swift', 15), ('SARI/Sources/Features/Fiqh/FiqhPackSetupView.swift', 10), ('SARI/Sources/Features/Settings/CalendarSettingsView.swift', 8), ('SARI/Sources/Core/LocalFiqhPack.swift', 7), ('SARI/Sources/Core/LocalFiqhSearch.swift', 4), ('SARI/Sources/Core/LocalFiqhEngine.swift', 3)]
Android: [('app/src/main/java/com/sari/app/ui/SettingsScreen.kt', 13), ('app/src/main/java/com/sari/app/fiqh/FiqhScreen.kt', 13), ('app/src/main/java/com/sari/app/prayer/PrayerSettingsScreen.kt', 10), ('app/src/main/java/com/sari/app/fiqh/FiqhPackSetupScreen.kt', 9), ('app/src/main/java/com/sari/app/fiqh/LocalFiqhEngine.kt', 5), ('app/src/main/java/com/sari/app/fiqh/LocalFiqhPack.kt', 3), ('app/src/main/java/com/sari/app/fiqh/LocalFiqhSearch.kt', 1)]

Release Gate يبقى IN_PROGRESS إلى أن نُنهي نصوص الواجهة الحقيقية ونختبر RTL/LTR والنصوص الطويلة.
