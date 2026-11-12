# إعداد تكامل خادم SARI — دليل السفارات

تطبيق iOS يحتوي على عميل اختياري لدليل السفارات. لا توجد قاعدة بيانات سفارات رسمية مدمجة في التطبيق. للإنتاج، اربط التطبيق بخادم SARI يُحدّث سجلاته من مواقع وزارات الخارجية والسفارات ويحتفظ بمصدر وتاريخ تحقق لكل سجل.

## إعداد عنوان الخادم

غيّر قيمة `SARI_API_BASE_URL` في `SARI/Info.plist` و`project.yml` من:

`https://YOUR-SARI-BACKEND.example`

إلى عنوان HTTPS الفعلي. لا تضع مفاتيح سرية في Info.plist أو تطبيق iOS. إذا كان المسار يتطلب صلاحيات، استخدم آلية جلسة/رمز آمن من الخادم.

## المسار المطلوب

`GET /v1/embassies?nationality=SA&destination=GB`

المعاملات ISO 3166-1 alpha-2:
- `nationality`: جنسية المستخدم.
- `destination`: دولة الوجهة.

## بنية الاستجابة

```json
{
  "missions": [
    {
      "nationality_code": "SA",
      "destination_code": "GB",
      "official_name": "Embassy name as listed by the official source",
      "city": "London",
      "address": "Officially verified address",
      "phone": "+44...",
      "emergency_phone": null,
      "email": "official@example.gov",
      "website": "https://official-government-domain.example",
      "working_hours": "As published by the mission",
      "source_url": "https://official-government-domain.example/source",
      "verified_at": "2026-11-06",
      "is_officially_verified": true
    }
  ]
}
```

القيم الواردة أعلاه مثال توضيحي لبنية JSON فقط، وليست بيانات سفارة حقيقية. لا تستخدمها كسجلات إنتاج.

## قواعد التحقق

1. لا تجعل `is_officially_verified=true` إلا بعد مراجعة المصدر الحكومي الأصلي.
2. يجب أن يكون `source_url` رابط HTTPS للمصدر الذي يدعم بيانات السجل.
3. لا تملأ رقم الطوارئ أو البريد أو ساعات العمل بالتخمين.
4. استخدم `verified_at` لتاريخ آخر مراجعة بشرية أو آلية ناجحة للمصدر.
5. إذا لم تتوفر معلومة، أرسل `null` بدل قيمة افتراضية.
6. أعد فقط السجلات المطابقة تمامًا للجنسية والوجهة المطلوبتين.
7. ضع سياسة تحديث وتنبيه عند تغيير صفحات الجهات الحكومية.

## مصدر احتياطي

إذا لم يرد الخادم بيانات، يحاول التطبيق اكتشاف إدراجات خرائط OpenStreetMap في عاصمة الوجهة. هذه الإدراجات تظل غير رسمية وتظهر للمستخدم بهذه الصفة. لا تعتبرها اعتمادًا من وزارة الخارجية.
