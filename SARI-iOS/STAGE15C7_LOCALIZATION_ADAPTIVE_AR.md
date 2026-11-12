# SARI — Stage 15C7: Localization + Adaptive UI foundation

تم إنشاء قاموس UI مركزي مشترك المفهوم للغات التسع، مع مفاتيح أساسية للتنقل والخدمات.
تم إنشاء بيئة iOS تضبط Locale + RTL/LTR + typesetting التلقائي.
تم إنشاء wrapper في Android يضبط LayoutDirection حسب لغة SARI.
تم إنشاء مصفوفة QA من 320dp حتى 1024dp مع تكبير الخط.

## نتائج الفحص
Fixed-width risks iOS: [('SARI/Sources/Features/Onboarding/OnboardingView.swift', 3)]
Fixed-width risks Android: [('app/src/main/java/com/sari/app/fiqh/FiqhScreen.kt', 1)]

## ملاحظة جودة
هذه الدفعة تؤسس طبقة صحيحة، لكنها لا تدّعي أن كل النصوص القديمة نُقلت بعد.
سنحوّل الشاشات تدريجيًا إلى SariUIStrings بدل استبدال آلي واسع قد يكسر المنطق.
Apple توصي بواجهات محلية تراعي اتجاه النص وDynamic Type، وAndroid يوصي بتغيير التخطيط حسب مساحة النافذة بدل تمديد واجهة الهاتف.
