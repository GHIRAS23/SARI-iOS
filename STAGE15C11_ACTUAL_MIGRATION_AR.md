# SARI Stage 15C11 — Actual localization migration

هذه الدفعة بدأت الاستبدال الفعلي، وليس إضافة قاموس فقط.
تم تحويل كل literal عربي مطابق حرفيًا لمفتاح موجود مسبقًا في القاموس المركزي داخل ملفات iOS المستهدفة.
في Android تم التحويل فقط عندما كان Context + Language واضحين في الملف لتجنب كسر Compose.
وأزيل maxLines=1 من شاشة Fiqh لتجنب قص الفرنسية/الروسية.

المتبقي iOS: [('SARI/Sources/Features/Travel/TravelView.swift', 39), ('SARI/Sources/Features/Settings/PrayerSettingsView.swift', 23), ('SARI/Sources/Features/Home/HomeView.swift', 22), ('SARI/Sources/Features/Settings/SettingsView.swift', 19), ('SARI/Sources/Features/Quran/QuranView.swift', 18), ('SARI/Sources/Features/Fiqh/FiqhAssistantView.swift', 15), ('SARI/Sources/Features/Fiqh/FiqhPackSetupView.swift', 10), ('SARI/Sources/Features/Settings/CalendarSettingsView.swift', 8), ('SARI/Sources/Features/Onboarding/OnboardingView.swift', 8), ('SARIWidget/SARIWidget.swift', 7), ('SARI/Sources/Features/Weather/WeatherDetailView.swift', 7), ('SARI/Sources/Features/Adhkar/AdhkarView.swift', 6)]
المتبقي Android: [('app/src/main/java/com/sari/app/travel/TravelScreen.kt', 42), ('app/src/main/java/com/sari/app/ui/SariApp.kt', 40), ('app/src/main/java/com/sari/app/prayer/PrayerSettingsScreen.kt', 15), ('app/src/main/java/com/sari/app/ui/SettingsScreen.kt', 13), ('app/src/main/java/com/sari/app/fiqh/FiqhScreen.kt', 13), ('app/src/main/java/com/sari/app/fiqh/FiqhPackSetupScreen.kt', 9), ('app/src/main/java/com/sari/app/ui/OnboardingScreen.kt', 8), ('app/src/main/java/com/sari/app/weather/WeatherDetailScreen.kt', 6), ('app/src/main/java/com/sari/app/travel/PlacesLocalScreen.kt', 5), ('app/src/main/java/com/sari/app/adhkar/AdhkarScreen.kt', 5), ('app/src/main/java/com/sari/app/prayer/QiblaScreen.kt', 3), ('app/src/main/java/com/sari/app/ui/SariCalendar.kt', 2)]

لا يزال Release Gate = IN_PROGRESS لأن النصوص غير المطابقة للقاموس تحتاج مفاتيح/ترجمات صريحة، وليس استبدالًا آليًا أعمى.
