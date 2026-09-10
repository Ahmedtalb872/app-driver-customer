# نشر تطبيق الزبون على Google Play

اسم الحزمة (لا يمكن تغييره بعد أول رفع): `com.alhudhud.customerapp`

## بصمات شهادات التوقيع

هذه بصمات علنية مشتقة من شهادات عامة — ليست أسراراً، وGoogle تعرضها في
لوحاتها. تُستخدم لتقييد مفتاح خرائط Google
(`APIs & Services → Credentials → Android apps`)، ولا بد أن تكون
البصمات الثلاث كلها مضافة مع اسم الحزمة أعلاه.

| الشهادة | SHA-1 | تُستخدم في |
|---|---|---|
| **مفتاح توقيع التطبيق** (App signing key) | `EF:CE:C4:2C:E4:AD:AB:E9:BF:39:AE:96:BC:AB:72:C8:BC:1A:C1:78` | **كل نسخة يُحمّلها المستخدمون من Play** |
| مفتاح التحميل (Upload key, `CN=Al Hodhod`) | `E5:A9:AC:36:D0:C9:47:DC:7E:ED:B4:AA:35:AF:FD:64:4F:4B:09:BB` | توقيع ملف `.aab` قبل رفعه |
| مفتاح التصحيح (Android debug key) | `51:50:6D:30:6A:37:0A:79:9C:20:DB:F2:6C:78:D1:7F:29:1C:B7:BA` | ملف APK المبني في `build-customer-apk.yml` للتثبيت المباشر |

### لماذا الثلاثة وليس واحداً

Play App Signing يعيد توقيع الـ `.aab` بمفتاح Google الخاص قبل توصيله
للأجهزة، فالبصمة التي تصل لهاتف المستخدم هي **مفتاح توقيع التطبيق**، لا
مفتاح التحميل الذي وقّعنا به. إغفال هذه البصمة هو السبب الأشيع لخريطة
رمادية فارغة تظهر فقط في النسخة المنشورة بينما تعمل محلياً.

مفتاح التصحيح مطلوب لأن `build-customer-apk.yml` يبني ملف APK **قبل**
كتابة `android/key.properties` عمداً، ليبقى موقّعاً بمفتاح التصحيح
وقابلاً للتثبيت فوق النسخ السابقة التي جرّبها المختبِرون.

## مصدر كل بصمة

- مفتاح توقيع التطبيق ومفتاح التحميل:
  Play Console → **Setup → App integrity → App signing**
- مفتاح التصحيح: `keytool -list -v -keystore ~/.android/debug.keystore`
  (كلمة المرور `android`)

## الروابط المطلوبة في Play Console

- سياسة الخصوصية:
  `https://ahmedtalb872.github.io/app-driver-customer/customer-app/privacy.html`
- حذف الحساب (حقل "Data deletion URL" في استبيان Data safety):
  `https://ahmedtalb872.github.io/app-driver-customer/customer-app/delete-account.html`

## قبل أول نشر

يجب تنفيذ ترحيل `20260818000081_customer_delete_account.sql` على قاعدة
البيانات. بدونه يوجد `customer_delete_account()` في الكود فقط ولا يحذف
زر "حذف الحساب" شيئاً فعلياً، بينما صفحة حذف الحساب المنشورة تَعِد
بالحذف — وهو تناقض ترفضه Google (Play Data deletion) وApple
(App Store 5.1.1(v)) معاً.

## من أين يأتي ملف `.aab`

من `build-customer-apk.yml` عند كل دفعة على الفرع، ويُنشر في الإصدار
المتدحرج `customer-apk-latest`. رقم `versionCode` يساوي رقم تشغيل
الـ workflow، فيزيد دائماً — وهو شرط Play لكل رفع جديد.
