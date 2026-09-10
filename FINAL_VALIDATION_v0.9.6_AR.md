# SARI v0.9.6 Build 15 — Final Validation Handoff

## تم التحقق محليًا
- بنية الموارد وعدم وجود تعارضات نسخ Resources.
- صحة plists وPrivacyInfo.xcprivacy.
- ملفات الأذان والصوت والبيانات الأساسية.
- حساب مواقيت الصلاة regression test.
- قواعد أمان المساعد المحلي وميزانية المدخلات.
- عدم إظهار أسماء المصادر في واجهة الإجابة.
- فصل سجل المحادثات عن مجلد النموذج القابل للحذف.
- ربط Background URLSession مع UIApplicationDelegate.
- فحص Swift syntax لجميع المصادر.
- فحص Swift 6 لواجهات SwiftLlama المستخدمة في LocalFiqhEngine.

## بوابة GitHub/Xcode
الـworkflow يجب أن يمر بالمراحل التالية:
1. macOS 15 + Xcode 16.4.
2. preflight + fiqh validation + prayer regression + Swift parse.
3. XcodeGen.
4. Swift Package resolution لـSwiftLlama 0.1.0.
5. `xcodebuild` للـscheme SARI على `generic/platform=iOS` مع `CODE_SIGNING_ALLOWED=NO`.
6. التحقق من SARI.app والـWidget والموارد.
7. إنشاء `SARI-unsigned.ipa` ورفعها ضمن Artifacts.

## بوابة الآيفون
- التنزيل يستمر عند الانتقال بين واجهات SARI، ولا يرتبط بواجهة «اسأل ساري».
- بعد انقطاع الشبكة يعود للاستكمال قدر ما يسمح به iOS.
- لا يظهر «جاهز» إلا بعد SHA-256 + Self-Test.
- إرسال عدة أسئلة لا يغلق التطبيق.
- تظهر الإجابة ثم «النص المستند إليه» بدون بيانات المصدر.
- سجل المحادثات يبقى بعد حذف حزمة النموذج.
