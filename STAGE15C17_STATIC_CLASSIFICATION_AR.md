# SARI — Stage 15C17: Final static classification before device QA

Platform: iOS

## Classification result
- Files containing Arabic literals: 27
- Likely UI lines: 133
- Domain/data lines: 129
- Religious/source lines: 8

Top remaining likely UI files:
- SARI/Sources/Features/Travel/TravelView.swift: 31
- SARI/Sources/Features/Home/HomeView.swift: 18
- SARI/Sources/Features/Settings/PrayerSettingsView.swift: 16
- SARI/Sources/Features/Settings/SettingsView.swift: 9
- SARI/Sources/Features/Fiqh/FiqhAssistantView.swift: 8
- SARI/Sources/Features/Onboarding/OnboardingView.swift: 8
- SARI/Sources/Features/Settings/CalendarSettingsView.swift: 7
- SARI/Sources/Features/Weather/WeatherDetailView.swift: 7
- SARI/Sources/Features/Travel/PlacesLocalView.swift: 6
- SARI/Sources/Features/Adhkar/AdhkarView.swift: 5
- SARI/Sources/Features/Fiqh/FiqhPackSetupView.swift: 4
- SARI/Sources/Features/Prayer/PrayerTimesView.swift: 4

## Important
This is a heuristic static classification, not a rendered-device test.
Remaining Arabic in domain/religious categories is not automatically a localization bug.
Stage 15C cannot be closed until the device/emulator matrix is executed for RTL/LTR and large text.
