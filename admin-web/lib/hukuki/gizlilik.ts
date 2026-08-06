import type { BelgeSeti } from "./tipler";

// (P113) GIZLILIK POLITIKASI — 7 dil. Kaynak ve BAGLAYICI surum: Turkce.
//
// ICERIKTEKI EN ONEMLI KARAR — ROL AYRIMI: Yonetio bir YAZILIMDIR ve
// cok-kiracili calisir. KVKK anlaminda **veri sorumlusu her tesisin
// yonetimidir**; biz **veri isleyeniz**. Bunu yazmamak, 200 tesisin
// verisinin sorumlulugunu platforma yikmak ve kullaniciya da yanlis
// muhatabi gostermek olurdu (silme/duzeltme talebi once tesise gider).
//
// IKINCI KARAR — ISLEYICILER ADIYLA sayilir ve **su an gecerli olmayanlar
// "gecerli degil" diye isaretlenir**. "Odeme saglayicisi kullanabiliriz"
// gibi ihtimalli bir cumle, App Store gizlilik anketiyle CELISIRDI:
// ankette "odeme verisi toplanmiyor" derken metinde "toplanabilir" yazmak
// denetimde tutarsizlik olarak okunur.
export const GIZLILIK: BelgeSeti = {
  tr: {
    baslik: "Gizlilik Politikası",
    guncelleme: "Son güncelleme: 2 Ağustos 2026",
    kaynakBaglayici: "",
    giris:
      "Bu politika, Yönetio uygulamasını ve yönetim panelini kullandığınızda hangi kişisel verilerin işlendiğini, neden işlendiğini ve haklarınızı açıklar.",
    bolumler: [
      {
        baslik: "1. Kim veri sorumlusudur?",
        paragraflar: [
          "Yönetio bir yazılım hizmetidir ve her tesis (site, apartman, rezidans) kendi verisini kendi alanında tutar.",
          "KVKK anlamında **veri sorumlusu, hesabınızın bağlı olduğu tesisin yönetimidir**. Yönetio, o yönetim adına veriyi işleyen taraftır (veri işleyen).",
          "Bu ayrım pratikte şu anlama gelir: verinizin silinmesi, düzeltilmesi ya da kime gösterildiği konusundaki talepleriniz önce tesis yönetimine iletilir. Yönetio, yönetimin talimatı dışında verinizi kullanmaz.",
        ],
      },
      {
        baslik: "2. Hangi veriler işlenir?",
        paragraflar: [
          "**Kimlik ve iletişim:** ad, telefon numarası, varsa e-posta adresi, daire/blok bilgisi, profil fotoğrafı (isteğe bağlı).",
          "**Kullanım kayıtları:** giriş kayıtları, uygulamada yaptığınız işlemlerin denetim kaydı (kim, ne zaman, hangi kaydı değiştirdi).",
          "**Finansal kayıtlar:** aidat tahakkukları, ödemeler, kasa hareketleri.",
          "**Konum (yalnızca saha personeli):** devriye turu okutmalarında konum bir KANIT olarak kaydedilir. Konum izni verilmese de okutma kaydedilir; uygulama arka planda sizi izlemez.",
          "**Kamera ve fotoğraf:** görev/talep/etkinlik fotoğrafları yalnız siz seçtiğinizde yüklenir.",
          "**NFC:** tur noktalarındaki etiketleri okutmak için kullanılır; etiketten kişisel veri okunmaz.",
        ],
      },
      {
        baslik: "3. Neden işlenir?",
        paragraflar: [
          "Tesis yönetim hizmetinin yürütülmesi: aidat tahakkuku ve tahsilatı, talep/şikâyet takibi, duyuru ve etkinlik yönetimi, güvenlik turlarının kaydı.",
          "Yasal yükümlülüklerin yerine getirilmesi: defter ve muhasebe kayıtlarının saklanması.",
          "Hizmetin güvenliği: yetkisiz erişimin tespiti, denetim kaydı.",
          "Pazarlama iletileri **yalnızca açık rızanızla** gönderilir ve rızayı istediğiniz an Ayarlar'dan geri alabilirsiniz.",
        ],
      },
      {
        baslik: "4. Kimlerle paylaşılır?",
        paragraflar: [
          "**Barındırma:** veriler Yönetio'nun kendi sunucularında tutulur.",
          "**Otomatik çeviri:** kendi altyapımızda çalışan LibreTranslate kullanılır. Metinleriniz çeviri için **üçüncü bir şirkete gönderilmez**; sunucularımızın dışına çıkmaz.",
          "**Ödeme:** kart ile ödeme özelliği **şu anda etkin değildir**. Etkinleştirildiğinde ödeme bilgileri doğrudan lisanslı ödeme kuruluşuna (iyzico) gider ve kart verisi bizim sistemimizde tutulmaz; bu politika o gün güncellenir.",
          "**Bildirim:** anlık bildirim altyapısı (Firebase Cloud Messaging) **şu anda etkin değildir**. Etkinleştirildiğinde cihaz bildirim jetonu Google'a iletilir; bildirim içeriği kişisel veri taşımayacak şekilde kurgulanır.",
          "Bunların dışında verileriniz hiçbir üçüncü tarafa satılmaz, reklam amacıyla paylaşılmaz.",
        ],
      },
      {
        baslik: "5. Yapay zekâ ve otomatik çeviri",
        paragraflar: [
          "Uygulamada **üretken yapay zekâ (metin/görsel üreten model) kullanılmamaktadır**.",
          "Kullanılan tek otomatik işlem, duyuru/site kuralı/etkinlik metinlerinin **makine çevirisidir** ve kendi sunucumuzda çalışır.",
          "Otomatik çevrilen her içerik uygulamada **\"Bu içerik otomatik çevrilmiştir\"** notunu ve **\"Orijinali gör\"** seçeneğini taşır. Çeviri bir yorumdur; bağlayıcı metin her zaman orijinaldir.",
          "Kararlarınızı etkileyen otomatik bir profilleme ya da tamamen otomatik karar verme süreci yoktur.",
        ],
      },
      {
        baslik: "6. Ne kadar süre saklanır?",
        paragraflar: [
          "Ziyaretçi ve kargo kayıtları 24 ay, tamamlanmış rezervasyonlar 24 ay, çözülmüş talep/şikâyetler 36 ay, denetim kaydı 24 ay saklanır ve süre dolunca otomatik olarak silinir veya anonimleştirilir.",
          "Muhasebe ve finans kayıtları, ilgili mevzuatın öngördüğü süre boyunca saklanır.",
        ],
      },
      {
        baslik: "7. Haklarınız",
        paragraflar: [
          "KVKK md. 11 ve GDPR kapsamında: verilerinize erişme, düzeltilmesini isteme, silinmesini isteme, işlemeye itiraz etme ve rızanızı geri alma haklarına sahipsiniz.",
          "**Hesabınızı uygulama içinden silebilirsiniz:** Ayarlar → Hesabımı sil. Adınız, telefonunuz, e-postanız, profil fotoğrafınız ve cihaz kayıtlarınız silinir; giriş yapamaz hâle gelirsiniz.",
          "**Devriye okutmalarında kaydedilen konum bilgileri ve yüklediğiniz fotoğraflar silinmez:** bunlar tesisin operasyonel ve denetim kaydıdır ve silinmeleri o kaydın geçmişini bozardı. Silme sonrasında bu kayıtlar sizinle ilişkilendirilemez hâle gelir. Ayrıntı: yonetiyor.com/hesap-silme",
          "Yasal olarak saklanması zorunlu olan aidat/ödeme ve denetim kayıtları silinemez; bu kayıtlar **adınızla ilişkisi kesilerek anonim** hâlde saklanmaya devam eder. Bu, tesisin diğer sakinlerinin doğru hesap görme hakkının korunması için zorunludur.",
          "Diğer talepleriniz için önce tesis yönetiminize, sonuç alamazsanız aşağıdaki adrese başvurabilirsiniz.",
        ],
      },
      {
        baslik: "8. Çerezler ve izleme",
        paragraflar: [
          "Yönetim panelinde yalnızca **oturum** ve **dil tercihi** çerezleri kullanılır.",
          "Reklam çerezi, üçüncü taraf analitik ya da cihazlar arası izleme **kullanılmaz**. Mobil uygulama reklam kimliği (IDFA) toplamaz.",
        ],
      },
      {
        baslik: "9. Güvenlik",
        paragraflar: [
          "Tüm bağlantılar HTTPS ile şifrelenir. Parolalar geri döndürülemez biçimde (bcrypt) saklanır.",
          "Her tesisin verisi veritabanı düzeyinde satır bazlı güvenlikle (RLS) ayrılır: bir tesisin kullanıcısı başka bir tesisin verisini göremez.",
          "Kişisel veriye erişen işlemler denetim kaydına yazılır ve bu kayıt değiştirilemez.",
        ],
      },
      {
        baslik: "10. Çocuklar",
        paragraflar: [
          "Hizmet 13 yaşından küçüklere yönelik değildir ve hesaplar tesis yönetimi tarafından yetişkin sakinler/çalışanlar için açılır.",
        ],
      },
      {
        baslik: "11. Değişiklikler ve iletişim",
        paragraflar: [
          "Bu politika değişirse yukarıdaki güncelleme tarihi değişir; önemli değişiklikler uygulama içinde duyurulur.",
          "Sorularınız için: **kvkk@yonetio.site**",
        ],
      },
    ],
  },

  en: {
    baslik: "Privacy Policy",
    guncelleme: "Last updated: 2 August 2026",
    kaynakBaglayici:
      "This is a translation provided for information. The binding version of this policy is the Turkish one.",
    giris:
      "This policy explains which personal data is processed when you use the Yönetio app and management panel, why it is processed, and what your rights are.",
    bolumler: [
      {
        baslik: "1. Who is the data controller?",
        paragraflar: [
          "Yönetio is a software service and operates multi-tenant: every site (apartment building, residence) keeps its data in its own space.",
          "Under Turkish data protection law (KVKK) and the GDPR, **the data controller is the management of the site your account belongs to**. Yönetio acts as the data processor on that management's behalf.",
          "In practice this means requests about deleting, correcting or sharing your data go to your site management first. Yönetio does not use your data outside the management's instructions.",
        ],
      },
      {
        baslik: "2. What data is processed?",
        paragraflar: [
          "**Identity and contact:** name, phone number, e-mail address (if any), unit/block information, profile photo (optional).",
          "**Usage records:** sign-in records and an audit trail of the actions you take (who changed which record, and when).",
          "**Financial records:** dues assessments, payments, cash movements.",
          "**Location (field staff only):** during patrol checkpoint scans, location is recorded as evidence. A scan is recorded even if location permission is denied; the app does not track you in the background.",
          "**Camera and photos:** task, request and event photos are uploaded only when you choose them.",
          "**NFC:** used to read checkpoint tags; no personal data is read from a tag.",
        ],
      },
      {
        baslik: "3. Why is it processed?",
        paragraflar: [
          "To run the site management service: dues assessment and collection, request/complaint tracking, announcements and events, security patrol records.",
          "To meet legal obligations: keeping accounting and statutory books.",
          "To keep the service secure: detecting unauthorised access, keeping an audit trail.",
          "Marketing messages are sent **only with your explicit consent**, which you can withdraw at any time from Settings.",
        ],
      },
      {
        baslik: "4. Who is it shared with?",
        paragraflar: [
          "**Hosting:** data is kept on Yönetio's own servers.",
          "**Automatic translation:** we run LibreTranslate on our own infrastructure. Your text is **not sent to any third-party company** for translation and never leaves our servers.",
          "**Payments:** card payment is **not currently enabled**. When it is enabled, payment details will go directly to a licensed payment institution (iyzico) and card data will not be stored in our system; this policy will be updated on that day.",
          "**Notifications:** push notification infrastructure (Firebase Cloud Messaging) is **not currently enabled**. When enabled, the device notification token will be sent to Google; notification content is designed to carry no personal data.",
          "Beyond these, your data is never sold or shared for advertising purposes.",
        ],
      },
      {
        baslik: "5. Artificial intelligence and automatic translation",
        paragraflar: [
          "The app does **not use generative artificial intelligence** (no text- or image-generating model).",
          "The only automated processing is **machine translation** of announcement, site-rule and event texts, and it runs on our own server.",
          "Every automatically translated item carries the note **\"This content has been translated automatically\"** together with a **\"View original\"** option. A translation is an interpretation; the binding text is always the original.",
          "There is no automated profiling or fully automated decision-making that affects you.",
        ],
      },
      {
        baslik: "6. How long is it kept?",
        paragraflar: [
          "Visitor and parcel records are kept for 24 months, completed reservations for 24 months, resolved requests/complaints for 36 months and the audit trail for 24 months; after that they are automatically deleted or anonymised.",
          "Accounting and financial records are kept for the period required by applicable legislation.",
        ],
      },
      {
        baslik: "7. Your rights",
        paragraflar: [
          "Under KVKK art. 11 and the GDPR you have the right to access your data, to have it corrected or deleted, to object to processing and to withdraw your consent.",
          "**You can delete your account from inside the app:** Settings → Delete my account. Your name, phone number, e-mail address, profile photo and device records are deleted and you can no longer sign in.",
          "**Location recorded during patrol scans and photos you uploaded are not deleted:** they are the building's operational and audit record, and deleting them would break that record's history. After deletion these records can no longer be linked to you. Details: yonetiyor.com/hesap-silme",
          "Dues/payment and audit records that we are legally required to keep cannot be deleted; they remain stored **anonymously, with the link to your name removed**. This is necessary to protect the other residents' right to correct accounts.",
          "For other requests, contact your site management first and, if that does not resolve the matter, the address below.",
        ],
      },
      {
        baslik: "8. Cookies and tracking",
        paragraflar: [
          "The management panel uses only **session** and **language preference** cookies.",
          "No advertising cookies, third-party analytics or cross-device tracking are used. The mobile app does not collect an advertising identifier (IDFA).",
        ],
      },
      {
        baslik: "9. Security",
        paragraflar: [
          "All connections are encrypted with HTTPS. Passwords are stored irreversibly (bcrypt).",
          "Each site's data is separated at database level by row-level security: a user of one site cannot see another site's data.",
          "Operations that access personal data are written to an audit trail that cannot be modified.",
        ],
      },
      {
        baslik: "10. Children",
        paragraflar: [
          "The service is not directed at children under 13; accounts are created by site management for adult residents and staff.",
        ],
      },
      {
        baslik: "11. Changes and contact",
        paragraflar: [
          "If this policy changes, the update date above changes; significant changes are announced inside the app.",
          "Questions: **kvkk@yonetio.site**",
        ],
      },
    ],
  },

  ar: {
    baslik: "سياسة الخصوصية",
    guncelleme: "آخر تحديث: 2 أغسطس 2026",
    kaynakBaglayici:
      "هذه ترجمة مقدَّمة للاطلاع فقط. النسخة المُلزِمة من هذه السياسة هي النسخة التركية.",
    giris:
      "توضّح هذه السياسة البيانات الشخصية التي تتم معالجتها عند استخدامك تطبيق Yönetio ولوحة الإدارة، وسبب معالجتها، وحقوقك.",
    bolumler: [
      {
        baslik: "١. من هو المسؤول عن البيانات؟",
        paragraflar: [
          "Yönetio خدمة برمجية متعددة المستأجرين: كل موقع (مجمّع سكني، عمارة) يحتفظ ببياناته في مساحته الخاصة.",
          "بموجب قانون حماية البيانات التركي (KVKK) واللائحة الأوروبية، **المسؤول عن البيانات هو إدارة الموقع التابع له حسابك**. تعمل Yönetio كمعالج للبيانات نيابة عن تلك الإدارة.",
          "عمليًا: تُوجَّه طلبات الحذف أو التصحيح أو الاطلاع إلى إدارة موقعك أولًا. ولا تستخدم Yönetio بياناتك خارج تعليمات الإدارة.",
        ],
      },
      {
        baslik: "٢. ما البيانات التي تتم معالجتها؟",
        paragraflar: [
          "**الهوية والتواصل:** الاسم، رقم الهاتف، البريد الإلكتروني إن وُجد، معلومات الوحدة/العمارة، صورة الملف الشخصي (اختيارية).",
          "**سجلات الاستخدام:** سجلات الدخول وسجل تدقيق للإجراءات التي تقوم بها.",
          "**السجلات المالية:** استحقاقات الرسوم والمدفوعات وحركات الصندوق.",
          "**الموقع (لموظفي الميدان فقط):** يُسجَّل الموقع كدليل أثناء مسح نقاط الدورية. يُسجَّل المسح حتى لو رُفض إذن الموقع؛ والتطبيق لا يتتبعك في الخلفية.",
          "**الكاميرا والصور:** تُرفع صور المهام والطلبات والفعاليات فقط عندما تختارها بنفسك.",
          "**NFC:** تُستخدم لقراءة بطاقات نقاط الدورية؛ ولا تُقرأ منها أي بيانات شخصية.",
        ],
      },
      {
        baslik: "٣. لماذا تتم معالجتها؟",
        paragraflar: [
          "لتشغيل خدمة إدارة الموقع: احتساب الرسوم وتحصيلها، متابعة الطلبات والشكاوى، الإعلانات والفعاليات، تسجيل الدوريات الأمنية.",
          "للوفاء بالالتزامات القانونية: حفظ الدفاتر والسجلات المحاسبية.",
          "لأمن الخدمة: كشف الوصول غير المصرّح به وحفظ سجل التدقيق.",
          "لا تُرسل الرسائل التسويقية إلا **بموافقتك الصريحة**، ويمكنك سحبها في أي وقت من الإعدادات.",
        ],
      },
      {
        baslik: "٤. مع من تتم المشاركة؟",
        paragraflar: [
          "**الاستضافة:** تُحفظ البيانات على خوادم Yönetio الخاصة.",
          "**الترجمة الآلية:** نشغّل LibreTranslate على بنيتنا التحتية. **لا تُرسل نصوصك إلى أي شركة خارجية** للترجمة ولا تغادر خوادمنا.",
          "**المدفوعات:** الدفع بالبطاقة **غير مفعّل حاليًا**. وعند تفعيله ستذهب بيانات الدفع مباشرة إلى مؤسسة دفع مرخّصة (iyzico) ولن تُخزَّن بيانات البطاقة لدينا؛ وستُحدَّث هذه السياسة حينها.",
          "**الإشعارات:** بنية الإشعارات الفورية (Firebase Cloud Messaging) **غير مفعّلة حاليًا**. وعند تفعيلها يُرسل رمز الجهاز إلى Google، ويُصمَّم محتوى الإشعار بحيث لا يحمل بيانات شخصية.",
          "فيما عدا ذلك، لا تُباع بياناتك ولا تُشارَك لأغراض إعلانية.",
        ],
      },
      {
        baslik: "٥. الذكاء الاصطناعي والترجمة الآلية",
        paragraflar: [
          "التطبيق **لا يستخدم ذكاءً اصطناعيًا توليديًا** (لا نماذج تولّد نصًا أو صورًا).",
          "المعالجة الآلية الوحيدة هي **الترجمة الآلية** لنصوص الإعلانات وقواعد الموقع والفعاليات، وتعمل على خادمنا.",
          "كل محتوى مترجَم آليًا يحمل ملاحظة **«تمت ترجمة هذا المحتوى آليًا»** مع خيار **«عرض النص الأصلي»**. الترجمة تفسير؛ والنص المُلزِم هو الأصل دائمًا.",
          "لا توجد ملفات تعريف آلية ولا قرارات آلية بالكامل تؤثر عليك.",
        ],
      },
      {
        baslik: "٦. مدة الحفظ",
        paragraflar: [
          "تُحفظ سجلات الزوار والطرود 24 شهرًا، والحجوزات المكتملة 24 شهرًا، والطلبات/الشكاوى المُغلقة 36 شهرًا، وسجل التدقيق 24 شهرًا، ثم تُحذف أو تُجهَّل تلقائيًا.",
          "تُحفظ السجلات المحاسبية والمالية للمدة التي تفرضها التشريعات ذات الصلة.",
        ],
      },
      {
        baslik: "٧. حقوقك",
        paragraflar: [
          "بموجب المادة 11 من KVKK واللائحة الأوروبية: لك حق الاطلاع والتصحيح والحذف والاعتراض وسحب الموافقة.",
          "**يمكنك حذف حسابك من داخل التطبيق:** الإعدادات ← حذف حسابي. يُحذف اسمك ورقم هاتفك وبريدك وصورتك وسجلات أجهزتك ولن تتمكن من تسجيل الدخول.",
          "**بيانات الموقع المسجَّلة أثناء مسح الدوريات والصور التي رفعتها لا تُحذف:** فهي السجل التشغيلي والرقابي للمجمّع، وحذفها يُفسد تاريخ ذلك السجل. بعد الحذف لا يمكن ربط هذه السجلات بك. التفاصيل: yonetiyor.com/hesap-silme",
          "لا يمكن حذف سجلات الرسوم والمدفوعات والتدقيق التي يلزمنا القانون بحفظها؛ تبقى مخزَّنة **بشكل مجهول بعد فصلها عن اسمك**. هذا ضروري لحماية حق بقية السكان في حسابات صحيحة.",
          "للطلبات الأخرى راجع إدارة موقعك أولًا، ثم العنوان أدناه إن لم تُحل المسألة.",
        ],
      },
      {
        baslik: "٨. ملفات تعريف الارتباط والتتبع",
        paragraflar: [
          "تستخدم لوحة الإدارة ملفات تعريف ارتباط **الجلسة** و**تفضيل اللغة** فقط.",
          "لا تُستخدم ملفات إعلانية ولا تحليلات طرف ثالث ولا تتبع بين الأجهزة. ولا يجمع التطبيق معرّف الإعلانات (IDFA).",
        ],
      },
      {
        baslik: "٩. الأمان",
        paragraflar: [
          "جميع الاتصالات مشفّرة عبر HTTPS، وتُخزَّن كلمات المرور بصيغة غير قابلة للاسترجاع (bcrypt).",
          "تُفصل بيانات كل موقع على مستوى قاعدة البيانات بأمان على مستوى الصفوف: لا يرى مستخدم موقعٍ بيانات موقع آخر.",
          "تُسجَّل العمليات التي تصل إلى البيانات الشخصية في سجل تدقيق غير قابل للتعديل.",
        ],
      },
      {
        baslik: "١٠. الأطفال",
        paragraflar: [
          "الخدمة غير موجَّهة لمن هم دون 13 عامًا؛ وتُنشئ الإدارة الحسابات للسكان والموظفين البالغين.",
        ],
      },
      {
        baslik: "١١. التغييرات والتواصل",
        paragraflar: [
          "عند تغيّر هذه السياسة يتغيّر تاريخ التحديث أعلاه، وتُعلَن التغييرات المهمة داخل التطبيق.",
          "للاستفسارات: **kvkk@yonetio.site**",
        ],
      },
    ],
  },

  ru: {
    baslik: "Политика конфиденциальности",
    guncelleme: "Последнее обновление: 2 августа 2026 г.",
    kaynakBaglayici:
      "Это перевод, предоставленный для ознакомления. Обязательной является турецкая версия политики.",
    giris:
      "Эта политика объясняет, какие персональные данные обрабатываются при использовании приложения и панели управления Yönetio, зачем они обрабатываются и какие у вас права.",
    bolumler: [
      {
        baslik: "1. Кто является оператором данных?",
        paragraflar: [
          "Yönetio — программный сервис с мультиарендной архитектурой: данные каждого объекта хранятся в отдельном пространстве.",
          "Согласно турецкому закону KVKK и GDPR, **оператором данных является управление того объекта, к которому относится ваша учётная запись**. Yönetio выступает обработчиком данных по поручению этого управления.",
          "На практике: запросы об удалении, исправлении или раскрытии данных сначала направляются в управление вашего объекта. Yönetio не использует ваши данные вне указаний управления.",
        ],
      },
      {
        baslik: "2. Какие данные обрабатываются?",
        paragraflar: [
          "**Идентификация и контакты:** имя, номер телефона, адрес электронной почты (при наличии), сведения о квартире/блоке, фотография профиля (по желанию).",
          "**Записи об использовании:** записи о входах и журнал аудита выполненных вами действий.",
          "**Финансовые записи:** начисления взносов, платежи, кассовые движения.",
          "**Местоположение (только для персонала):** при отметке точек обхода местоположение фиксируется как доказательство. Отметка сохраняется даже при отказе в разрешении; приложение не отслеживает вас в фоновом режиме.",
          "**Камера и фотографии:** фотографии задач, заявок и мероприятий загружаются только по вашему выбору.",
          "**NFC:** используется для считывания меток контрольных точек; персональные данные с метки не считываются.",
        ],
      },
      {
        baslik: "3. Зачем они обрабатываются?",
        paragraflar: [
          "Для оказания услуги управления объектом: начисление и сбор взносов, обработка заявок и жалоб, объявления и мероприятия, учёт охранных обходов.",
          "Для выполнения требований закона: хранение бухгалтерских книг и записей.",
          "Для безопасности сервиса: выявление несанкционированного доступа, ведение журнала аудита.",
          "Маркетинговые сообщения отправляются **только с вашего явного согласия**, которое можно отозвать в любой момент в Настройках.",
        ],
      },
      {
        baslik: "4. Кому передаются данные?",
        paragraflar: [
          "**Хостинг:** данные хранятся на собственных серверах Yönetio.",
          "**Автоматический перевод:** мы используем LibreTranslate на собственной инфраструктуре. Ваши тексты **не передаются сторонним компаниям** и не покидают наши серверы.",
          "**Платежи:** оплата картой **сейчас не включена**. При включении платёжные данные будут поступать напрямую в лицензированную платёжную организацию (iyzico), а данные карты не будут храниться у нас; политика будет обновлена в тот же день.",
          "**Уведомления:** инфраструктура push-уведомлений (Firebase Cloud Messaging) **сейчас не включена**. При включении токен устройства будет передаваться в Google; содержимое уведомлений проектируется без персональных данных.",
          "В остальном ваши данные не продаются и не передаются в рекламных целях.",
        ],
      },
      {
        baslik: "5. Искусственный интеллект и автоматический перевод",
        paragraflar: [
          "Приложение **не использует генеративный искусственный интеллект** (нет моделей, создающих текст или изображения).",
          "Единственная автоматическая обработка — **машинный перевод** текстов объявлений, правил объекта и мероприятий; он выполняется на нашем сервере.",
          "Каждый автоматически переведённый материал сопровождается пометкой **«Этот материал переведён автоматически»** и кнопкой **«Показать оригинал»**. Перевод — это интерпретация; обязательным всегда остаётся оригинал.",
          "Автоматического профилирования и полностью автоматизированных решений, затрагивающих вас, нет.",
        ],
      },
      {
        baslik: "6. Сроки хранения",
        paragraflar: [
          "Записи о посетителях и посылках хранятся 24 месяца, завершённые бронирования — 24 месяца, закрытые заявки и жалобы — 36 месяцев, журнал аудита — 24 месяца; затем они автоматически удаляются или обезличиваются.",
          "Бухгалтерские и финансовые записи хранятся в течение срока, установленного законодательством.",
        ],
      },
      {
        baslik: "7. Ваши права",
        paragraflar: [
          "Согласно ст. 11 KVKK и GDPR вы вправе получить доступ к данным, потребовать их исправления или удаления, возразить против обработки и отозвать согласие.",
          "**Учётную запись можно удалить прямо в приложении:** Настройки → Удалить мою учётную запись. Ваше имя, телефон, e-mail, фотография профиля и записи об устройствах удаляются, и вход становится невозможным.",
          "**Данные о местоположении, записанные при сканировании обходов, и загруженные вами фотографии не удаляются:** это операционные и контрольные записи объекта, их удаление нарушило бы историю записи. После удаления эти записи невозможно связать с вами. Подробнее: yonetiyor.com/hesap-silme",
          "Записи о взносах, платежах и аудите, которые мы обязаны хранить по закону, удалить нельзя; они остаются в системе **обезличенными, без связи с вашим именем**. Это необходимо для защиты права других жильцов на корректные расчёты.",
          "По остальным вопросам обращайтесь сначала в управление объекта, а затем по адресу ниже.",
        ],
      },
      {
        baslik: "8. Файлы cookie и отслеживание",
        paragraflar: [
          "В панели управления используются только файлы cookie **сессии** и **выбора языка**.",
          "Рекламные cookie, сторонняя аналитика и межустройственное отслеживание **не используются**. Мобильное приложение не собирает рекламный идентификатор (IDFA).",
        ],
      },
      {
        baslik: "9. Безопасность",
        paragraflar: [
          "Все соединения шифруются по HTTPS. Пароли хранятся необратимо (bcrypt).",
          "Данные каждого объекта разделены на уровне базы данных построчной безопасностью: пользователь одного объекта не видит данные другого.",
          "Операции доступа к персональным данным записываются в неизменяемый журнал аудита.",
        ],
      },
      {
        baslik: "10. Дети",
        paragraflar: [
          "Сервис не предназначен для детей младше 13 лет; учётные записи создаёт управление объекта для взрослых жильцов и сотрудников.",
        ],
      },
      {
        baslik: "11. Изменения и контакты",
        paragraflar: [
          "При изменении политики меняется дата обновления выше; о существенных изменениях сообщается в приложении.",
          "Вопросы: **kvkk@yonetio.site**",
        ],
      },
    ],
  },

  de: {
    baslik: "Datenschutzerklärung",
    guncelleme: "Zuletzt aktualisiert: 2. August 2026",
    kaynakBaglayici:
      "Dies ist eine Übersetzung zu Informationszwecken. Verbindlich ist die türkische Fassung dieser Erklärung.",
    giris:
      "Diese Erklärung beschreibt, welche personenbezogenen Daten bei der Nutzung der Yönetio-App und des Verwaltungsportals verarbeitet werden, warum sie verarbeitet werden und welche Rechte Sie haben.",
    bolumler: [
      {
        baslik: "1. Wer ist verantwortlich?",
        paragraflar: [
          "Yönetio ist ein Softwaredienst und arbeitet mandantenfähig: Jede Anlage speichert ihre Daten in einem eigenen Bereich.",
          "Nach dem türkischen Datenschutzgesetz (KVKK) und der DSGVO ist **die Verwaltung der Anlage, zu der Ihr Konto gehört, der Verantwortliche**. Yönetio handelt als Auftragsverarbeiter für diese Verwaltung.",
          "Praktisch heißt das: Anfragen zu Löschung, Berichtigung oder Offenlegung richten Sie zuerst an Ihre Verwaltung. Yönetio nutzt Ihre Daten nicht außerhalb der Weisungen der Verwaltung.",
        ],
      },
      {
        baslik: "2. Welche Daten werden verarbeitet?",
        paragraflar: [
          "**Identität und Kontakt:** Name, Telefonnummer, ggf. E-Mail-Adresse, Wohnungs-/Blockangaben, Profilbild (freiwillig).",
          "**Nutzungsdaten:** Anmeldevorgänge und ein Protokoll Ihrer Aktionen.",
          "**Finanzdaten:** Beitragsforderungen, Zahlungen, Kassenbewegungen.",
          "**Standort (nur Servicepersonal):** Beim Scannen von Rundgangspunkten wird der Standort als Nachweis erfasst. Der Scan wird auch ohne Standortfreigabe gespeichert; die App verfolgt Sie nicht im Hintergrund.",
          "**Kamera und Fotos:** Fotos zu Aufgaben, Anliegen und Veranstaltungen werden nur hochgeladen, wenn Sie sie auswählen.",
          "**NFC:** dient dem Lesen von Kontrollpunkt-Tags; personenbezogene Daten werden dabei nicht gelesen.",
        ],
      },
      {
        baslik: "3. Zu welchen Zwecken?",
        paragraflar: [
          "Erbringung der Verwaltungsleistung: Beitragsabrechnung und -einzug, Bearbeitung von Anliegen, Ankündigungen und Veranstaltungen, Dokumentation von Sicherheitsrundgängen.",
          "Erfüllung gesetzlicher Pflichten: Aufbewahrung von Büchern und Buchhaltungsunterlagen.",
          "Sicherheit des Dienstes: Erkennung unbefugter Zugriffe, Führung des Prüfprotokolls.",
          "Werbenachrichten werden **nur mit Ihrer ausdrücklichen Einwilligung** versendet; diese können Sie jederzeit in den Einstellungen widerrufen.",
        ],
      },
      {
        baslik: "4. Wer erhält die Daten?",
        paragraflar: [
          "**Hosting:** Die Daten liegen auf eigenen Servern von Yönetio.",
          "**Automatische Übersetzung:** Wir betreiben LibreTranslate auf eigener Infrastruktur. Ihre Texte werden **an kein Drittunternehmen** übermittelt und verlassen unsere Server nicht.",
          "**Zahlungen:** Kartenzahlung ist **derzeit nicht aktiv**. Bei Aktivierung gehen Zahlungsdaten direkt an ein lizenziertes Zahlungsinstitut (iyzico); Kartendaten werden bei uns nicht gespeichert. Diese Erklärung wird dann aktualisiert.",
          "**Benachrichtigungen:** Die Push-Infrastruktur (Firebase Cloud Messaging) ist **derzeit nicht aktiv**. Bei Aktivierung wird das Gerätetoken an Google übermittelt; Benachrichtigungsinhalte werden ohne personenbezogene Daten gestaltet.",
          "Darüber hinaus werden Ihre Daten nicht verkauft und nicht zu Werbezwecken weitergegeben.",
        ],
      },
      {
        baslik: "5. Künstliche Intelligenz und automatische Übersetzung",
        paragraflar: [
          "Die App verwendet **keine generative künstliche Intelligenz** (keine Text- oder Bildgenerierung).",
          "Die einzige automatisierte Verarbeitung ist die **maschinelle Übersetzung** von Ankündigungen, Hausordnungen und Veranstaltungstexten; sie läuft auf unserem eigenen Server.",
          "Jeder automatisch übersetzte Inhalt trägt den Hinweis **„Dieser Inhalt wurde automatisch übersetzt“** und die Option **„Original anzeigen“**. Eine Übersetzung ist eine Auslegung; verbindlich ist stets das Original.",
          "Es findet kein automatisiertes Profiling und keine ausschließlich automatisierte Entscheidung statt, die Sie betrifft.",
        ],
      },
      {
        baslik: "6. Speicherdauer",
        paragraflar: [
          "Besucher- und Paketdaten werden 24 Monate, abgeschlossene Reservierungen 24 Monate, erledigte Anliegen 36 Monate und das Prüfprotokoll 24 Monate aufbewahrt und danach automatisch gelöscht oder anonymisiert.",
          "Buchhaltungs- und Finanzunterlagen werden für die gesetzlich vorgeschriebene Dauer aufbewahrt.",
        ],
      },
      {
        baslik: "7. Ihre Rechte",
        paragraflar: [
          "Nach KVKK Art. 11 und DSGVO haben Sie das Recht auf Auskunft, Berichtigung, Löschung, Widerspruch und Widerruf Ihrer Einwilligung.",
          "**Sie können Ihr Konto in der App löschen:** Einstellungen → Mein Konto löschen. Name, Telefonnummer, E-Mail-Adresse, Profilbild und Geräteeinträge werden gelöscht; eine Anmeldung ist danach nicht mehr möglich.",
          "**Bei Rundgang-Scans erfasste Standortdaten und von Ihnen hochgeladene Fotos werden nicht gelöscht:** Sie sind der betriebliche und Prüf-Nachweis des Objekts; ihre Löschung würde dessen Historie zerstören. Nach der Löschung sind diese Datensätze Ihnen nicht mehr zuordenbar. Details: yonetiyor.com/hesap-silme",
          "Beitrags-, Zahlungs- und Prüfunterlagen, zu deren Aufbewahrung wir gesetzlich verpflichtet sind, können nicht gelöscht werden; sie bleiben **anonymisiert und ohne Bezug zu Ihrem Namen** gespeichert. Das schützt das Recht der übrigen Bewohner auf korrekte Abrechnungen.",
          "Für weitere Anliegen wenden Sie sich zuerst an Ihre Verwaltung und anschließend an die untenstehende Adresse.",
        ],
      },
      {
        baslik: "8. Cookies und Tracking",
        paragraflar: [
          "Im Verwaltungsportal werden ausschließlich **Sitzungs-** und **Sprachpräferenz-Cookies** verwendet.",
          "Werbe-Cookies, Analysedienste Dritter oder geräteübergreifendes Tracking werden **nicht** eingesetzt. Die mobile App erhebt keine Werbe-ID (IDFA).",
        ],
      },
      {
        baslik: "9. Sicherheit",
        paragraflar: [
          "Alle Verbindungen sind mit HTTPS verschlüsselt. Passwörter werden unumkehrbar (bcrypt) gespeichert.",
          "Die Daten jeder Anlage sind auf Datenbankebene durch zeilenbasierte Sicherheit getrennt: Nutzer einer Anlage sehen keine Daten einer anderen.",
          "Zugriffe auf personenbezogene Daten werden in einem unveränderlichen Prüfprotokoll erfasst.",
        ],
      },
      {
        baslik: "10. Kinder",
        paragraflar: [
          "Der Dienst richtet sich nicht an Kinder unter 13 Jahren; Konten werden von der Verwaltung für erwachsene Bewohner und Beschäftigte angelegt.",
        ],
      },
      {
        baslik: "11. Änderungen und Kontakt",
        paragraflar: [
          "Bei Änderungen ändert sich das oben genannte Datum; wesentliche Änderungen werden in der App angekündigt.",
          "Fragen: **kvkk@yonetio.site**",
        ],
      },
    ],
  },

  fr: {
    baslik: "Politique de confidentialité",
    guncelleme: "Dernière mise à jour : 2 août 2026",
    kaynakBaglayici:
      "Ceci est une traduction fournie à titre d'information. La version turque de cette politique fait foi.",
    giris:
      "Cette politique explique quelles données personnelles sont traitées lorsque vous utilisez l'application et le portail de gestion Yönetio, pourquoi elles le sont et quels sont vos droits.",
    bolumler: [
      {
        baslik: "1. Qui est responsable du traitement ?",
        paragraflar: [
          "Yönetio est un service logiciel multi-locataire : chaque site conserve ses données dans son propre espace.",
          "Au sens de la loi turque KVKK et du RGPD, **le responsable du traitement est la gestion du site auquel votre compte est rattaché**. Yönetio agit comme sous-traitant pour le compte de cette gestion.",
          "Concrètement : vos demandes de suppression, de rectification ou de communication sont adressées d'abord à la gestion de votre site. Yönetio n'utilise pas vos données en dehors de ses instructions.",
        ],
      },
      {
        baslik: "2. Quelles données sont traitées ?",
        paragraflar: [
          "**Identité et contact :** nom, numéro de téléphone, adresse e-mail le cas échéant, informations de lot/bâtiment, photo de profil (facultative).",
          "**Journaux d'utilisation :** connexions et journal d'audit des actions que vous effectuez.",
          "**Données financières :** appels de charges, paiements, mouvements de caisse.",
          "**Localisation (personnel de terrain uniquement) :** lors des relevés de points de ronde, la position est enregistrée comme preuve. Le relevé est enregistré même si l'autorisation est refusée ; l'application ne vous suit pas en arrière-plan.",
          "**Appareil photo et photos :** les photos de tâches, de demandes et d'événements ne sont téléversées que si vous les sélectionnez.",
          "**NFC :** sert à lire les badges des points de contrôle ; aucune donnée personnelle n'y est lue.",
        ],
      },
      {
        baslik: "3. Pourquoi sont-elles traitées ?",
        paragraflar: [
          "Pour fournir le service de gestion : appels et encaissement des charges, suivi des demandes et réclamations, annonces et événements, traçabilité des rondes de sécurité.",
          "Pour respecter les obligations légales : conservation des livres et pièces comptables.",
          "Pour la sécurité du service : détection des accès non autorisés, tenue du journal d'audit.",
          "Les messages marketing ne sont envoyés **qu'avec votre consentement explicite**, que vous pouvez retirer à tout moment dans les Paramètres.",
        ],
      },
      {
        baslik: "4. Avec qui sont-elles partagées ?",
        paragraflar: [
          "**Hébergement :** les données sont conservées sur les serveurs de Yönetio.",
          "**Traduction automatique :** nous exploitons LibreTranslate sur notre propre infrastructure. Vos textes **ne sont transmis à aucune société tierce** et ne quittent pas nos serveurs.",
          "**Paiements :** le paiement par carte **n'est pas activé actuellement**. Lors de son activation, les données de paiement iront directement à un établissement de paiement agréé (iyzico) et aucune donnée de carte ne sera stockée chez nous ; cette politique sera alors mise à jour.",
          "**Notifications :** l'infrastructure de notifications push (Firebase Cloud Messaging) **n'est pas activée actuellement**. À son activation, le jeton de l'appareil sera transmis à Google ; le contenu des notifications est conçu sans données personnelles.",
          "En dehors de cela, vos données ne sont ni vendues ni partagées à des fins publicitaires.",
        ],
      },
      {
        baslik: "5. Intelligence artificielle et traduction automatique",
        paragraflar: [
          "L'application **n'utilise pas d'intelligence artificielle générative** (aucun modèle générant du texte ou des images).",
          "Le seul traitement automatisé est la **traduction automatique** des annonces, règlements et événements ; elle s'exécute sur notre propre serveur.",
          "Tout contenu traduit automatiquement porte la mention **« Ce contenu a été traduit automatiquement »** et l'option **« Voir l'original »**. Une traduction est une interprétation ; le texte qui fait foi reste l'original.",
          "Il n'existe aucun profilage automatisé ni décision entièrement automatisée vous concernant.",
        ],
      },
      {
        baslik: "6. Durées de conservation",
        paragraflar: [
          "Les registres de visiteurs et de colis sont conservés 24 mois, les réservations terminées 24 mois, les demandes et réclamations closes 36 mois et le journal d'audit 24 mois ; ils sont ensuite supprimés ou anonymisés automatiquement.",
          "Les pièces comptables et financières sont conservées pendant la durée prévue par la réglementation applicable.",
        ],
      },
      {
        baslik: "7. Vos droits",
        paragraflar: [
          "Au titre de l'art. 11 de la KVKK et du RGPD, vous disposez d'un droit d'accès, de rectification, d'effacement, d'opposition et de retrait du consentement.",
          "**Vous pouvez supprimer votre compte depuis l'application :** Paramètres → Supprimer mon compte. Vos nom, téléphone, e-mail, photo de profil et enregistrements d'appareils sont supprimés et la connexion devient impossible.",
          "**Les données de localisation enregistrées lors des rondes et les photos que vous avez téléversées ne sont pas supprimées :** elles constituent le registre opérationnel et d'audit du site, et les supprimer romprait l'historique de ce registre. Après suppression, ces enregistrements ne peuvent plus vous être rattachés. Détails : yonetiyor.com/hesap-silme",
          "Les pièces de charges, de paiement et d'audit que la loi nous impose de conserver ne peuvent pas être supprimées ; elles restent stockées **de façon anonyme, sans lien avec votre nom**. C'est nécessaire pour protéger le droit des autres résidents à des comptes exacts.",
          "Pour toute autre demande, adressez-vous d'abord à la gestion de votre site, puis à l'adresse ci-dessous.",
        ],
      },
      {
        baslik: "8. Cookies et suivi",
        paragraflar: [
          "Le portail de gestion n'utilise que des cookies de **session** et de **préférence de langue**.",
          "Aucun cookie publicitaire, aucune analyse tierce et aucun suivi inter-appareils ne sont utilisés. L'application mobile ne collecte pas d'identifiant publicitaire (IDFA).",
        ],
      },
      {
        baslik: "9. Sécurité",
        paragraflar: [
          "Toutes les connexions sont chiffrées en HTTPS. Les mots de passe sont stockés de manière irréversible (bcrypt).",
          "Les données de chaque site sont isolées au niveau de la base par une sécurité au niveau des lignes : un utilisateur d'un site ne voit pas les données d'un autre.",
          "Les opérations accédant à des données personnelles sont inscrites dans un journal d'audit non modifiable.",
        ],
      },
      {
        baslik: "10. Enfants",
        paragraflar: [
          "Le service ne s'adresse pas aux enfants de moins de 13 ans ; les comptes sont créés par la gestion pour des résidents et employés adultes.",
        ],
      },
      {
        baslik: "11. Modifications et contact",
        paragraflar: [
          "En cas de modification, la date ci-dessus change ; les changements importants sont annoncés dans l'application.",
          "Questions : **kvkk@yonetio.site**",
        ],
      },
    ],
  },

  es: {
    baslik: "Política de privacidad",
    guncelleme: "Última actualización: 2 de agosto de 2026",
    kaynakBaglayici:
      "Esta es una traducción proporcionada a título informativo. La versión vinculante de esta política es la turca.",
    giris:
      "Esta política explica qué datos personales se tratan cuando utiliza la aplicación y el panel de gestión de Yönetio, por qué se tratan y cuáles son sus derechos.",
    bolumler: [
      {
        baslik: "1. ¿Quién es el responsable del tratamiento?",
        paragraflar: [
          "Yönetio es un servicio de software multiinquilino: cada comunidad guarda sus datos en su propio espacio.",
          "Conforme a la ley turca KVKK y al RGPD, **el responsable del tratamiento es la administración de la comunidad a la que pertenece su cuenta**. Yönetio actúa como encargado del tratamiento por cuenta de esa administración.",
          "En la práctica: sus solicitudes de supresión, rectificación o comunicación se dirigen primero a la administración de su comunidad. Yönetio no utiliza sus datos fuera de esas instrucciones.",
        ],
      },
      {
        baslik: "2. ¿Qué datos se tratan?",
        paragraflar: [
          "**Identidad y contacto:** nombre, número de teléfono, correo electrónico si lo hay, datos de vivienda/bloque, foto de perfil (opcional).",
          "**Registros de uso:** inicios de sesión y registro de auditoría de las acciones que realiza.",
          "**Datos financieros:** liquidaciones de cuotas, pagos y movimientos de caja.",
          "**Ubicación (solo personal de campo):** al registrar los puntos de ronda, la ubicación se guarda como prueba. El registro se guarda aunque se deniegue el permiso; la aplicación no le rastrea en segundo plano.",
          "**Cámara y fotografías:** las fotos de tareas, incidencias y eventos solo se suben cuando usted las selecciona.",
          "**NFC:** se usa para leer las etiquetas de los puntos de control; no se leen datos personales de ellas.",
        ],
      },
      {
        baslik: "3. ¿Por qué se tratan?",
        paragraflar: [
          "Para prestar el servicio de administración: liquidación y cobro de cuotas, seguimiento de incidencias, avisos y eventos, registro de rondas de seguridad.",
          "Para cumplir obligaciones legales: conservación de libros y documentación contable.",
          "Para la seguridad del servicio: detección de accesos no autorizados y registro de auditoría.",
          "Los mensajes comerciales se envían **solo con su consentimiento explícito**, que puede retirar en cualquier momento desde Ajustes.",
        ],
      },
      {
        baslik: "4. ¿Con quién se comparten?",
        paragraflar: [
          "**Alojamiento:** los datos se guardan en servidores propios de Yönetio.",
          "**Traducción automática:** utilizamos LibreTranslate en nuestra propia infraestructura. Sus textos **no se envían a ninguna empresa externa** ni salen de nuestros servidores.",
          "**Pagos:** el pago con tarjeta **no está activado actualmente**. Cuando se active, los datos de pago irán directamente a una entidad de pago autorizada (iyzico) y los datos de tarjeta no se almacenarán en nuestro sistema; esta política se actualizará ese día.",
          "**Notificaciones:** la infraestructura de notificaciones push (Firebase Cloud Messaging) **no está activada actualmente**. Al activarse, el token del dispositivo se enviará a Google; el contenido de las notificaciones se diseña sin datos personales.",
          "Fuera de esto, sus datos no se venden ni se comparten con fines publicitarios.",
        ],
      },
      {
        baslik: "5. Inteligencia artificial y traducción automática",
        paragraflar: [
          "La aplicación **no utiliza inteligencia artificial generativa** (ningún modelo que genere texto o imágenes).",
          "El único tratamiento automatizado es la **traducción automática** de avisos, normas de la comunidad y eventos, y se ejecuta en nuestro propio servidor.",
          "Todo contenido traducido automáticamente lleva la nota **«Este contenido se ha traducido automáticamente»** y la opción **«Ver original»**. Una traducción es una interpretación; el texto vinculante es siempre el original.",
          "No existe elaboración de perfiles automatizada ni decisiones totalmente automatizadas que le afecten.",
        ],
      },
      {
        baslik: "6. Plazos de conservación",
        paragraflar: [
          "Los registros de visitantes y paquetes se conservan 24 meses, las reservas finalizadas 24 meses, las incidencias resueltas 36 meses y el registro de auditoría 24 meses; después se eliminan o anonimizan automáticamente.",
          "La documentación contable y financiera se conserva durante el plazo que exige la normativa aplicable.",
        ],
      },
      {
        baslik: "7. Sus derechos",
        paragraflar: [
          "Conforme al art. 11 de la KVKK y al RGPD, tiene derecho de acceso, rectificación, supresión, oposición y retirada del consentimiento.",
          "**Puede eliminar su cuenta desde la aplicación:** Ajustes → Eliminar mi cuenta. Se eliminan su nombre, teléfono, correo electrónico, foto de perfil y registros de dispositivos, y ya no podrá iniciar sesión.",
          "**Los datos de ubicación registrados en las rondas y las fotos que subió no se eliminan:** son el registro operativo y de auditoría del edificio, y eliminarlos rompería su historial. Tras la eliminación, estos registros ya no pueden vincularse con usted. Detalles: yonetiyor.com/hesap-silme",
          "Los registros de cuotas, pagos y auditoría que la ley nos obliga a conservar no pueden eliminarse; permanecen almacenados **de forma anónima, sin vínculo con su nombre**. Esto es necesario para proteger el derecho de los demás vecinos a cuentas correctas.",
          "Para el resto de solicitudes, diríjase primero a la administración de su comunidad y después a la dirección indicada abajo.",
        ],
      },
      {
        baslik: "8. Cookies y seguimiento",
        paragraflar: [
          "El panel de gestión solo utiliza cookies de **sesión** y de **preferencia de idioma**.",
          "No se utilizan cookies publicitarias, analítica de terceros ni seguimiento entre dispositivos. La aplicación móvil no recopila identificador publicitario (IDFA).",
        ],
      },
      {
        baslik: "9. Seguridad",
        paragraflar: [
          "Todas las conexiones se cifran con HTTPS. Las contraseñas se almacenan de forma irreversible (bcrypt).",
          "Los datos de cada comunidad se separan a nivel de base de datos mediante seguridad por filas: un usuario de una comunidad no ve los datos de otra.",
          "Las operaciones que acceden a datos personales se registran en un registro de auditoría no modificable.",
        ],
      },
      {
        baslik: "10. Menores",
        paragraflar: [
          "El servicio no está dirigido a menores de 13 años; las cuentas las crea la administración para vecinos y empleados adultos.",
        ],
      },
      {
        baslik: "11. Cambios y contacto",
        paragraflar: [
          "Si esta política cambia, cambiará la fecha indicada arriba; los cambios relevantes se anuncian dentro de la aplicación.",
          "Consultas: **kvkk@yonetio.site**",
        ],
      },
    ],
  },
};
