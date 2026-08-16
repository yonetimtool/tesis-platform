import type { BelgeSeti } from "./tipler";

// (P141.3) HESAP SILME — Play'in ZORUNLU tuttugu, GIRISSIZ erisilebilir sayfa.
//
// NEDEN 7 DIL: gizlilik politikasi zaten 7 dilde. Silme bilgisini iki dilde
// birakmak, 7 dilde duran politikayla KENDI ICINDE celiski olurdu — ve Play
// formundaki beyanla birebir tutmasi gereken metin tam da budur.
//
// EN ONEMLI ICERIK KARARI — SAKLANANI GIZLEMEMEK: devriye konum kayitlari ve
// yuklenen fotograflar SILINMEZ ve bu sayfa bunu ACIKCA yazar. Play veri
// guvenligi formunda "silinebilir" demek ve burada susmak, denetimde
// tutarsizlik olarak okunurdu. Kod da bunu boyle yapiyor (hesap_silme.py:
// hard delete denenir, referans varsa ANONIMLESTIRILIR).
export const HESAP_SILME: BelgeSeti = {
  tr: {
    baslik: "Hesap Silme",
    guncelleme: "Son güncelleme: 6 Ağustos 2026",
    kaynakBaglayici: "",
    giris: "Bu sayfa, Yönetiyor hesabınızı nasıl sileceğinizi, silme sonrasında hangi verilerin kaldırıldığını ve hangilerinin saklanmaya devam ettiğini açıklar. Hesabınızı silmek için oturum açmanız gerekmez.",
    bolumler: [
      {
        baslik: "1. Uygulamadan silme (en hızlı yol)",
        paragraflar: [
          "Yönetiyor uygulamasını açın ve **Ayarlar → Hesabımı sil** adımını izleyin.",
          "Parolanız varsa parolanızı, parolasız giriş kullanıyorsanız telefonunuza gönderilen doğrulama kodunu girin. Bu adım, telefonunu ödünç veren birinin hesabınızı silmesini engeller.",
          "Onayladığınızda işlem **anında** uygulanır.",
        ],
      },
      {
        baslik: "2. Uygulamaya erişemiyorsanız",
        paragraflar: [
          "Aşağıdaki adrese, hesabınıza kayıtlı **telefon numarasından** ulaşabileceğimiz bir mesaj gönderin ve silme talebinizi belirtin.",
          "Talebi işleme almadan önce numaranın size ait olduğunu doğrularız; doğrulanmayan talepler yerine getirilmez.",
          "Talepler **en geç 30 gün** içinde sonuçlandırılır; uygulamadan yapılan silme ise anında uygulanır.",
        ],
      },
      {
        baslik: "3. Silinen veriler",
        paragraflar: [
          "Adınız, e-posta adresiniz, telefon numaranız ve profil fotoğrafınız kaldırılır.",
          "Bildirim gönderebilmek için tutulan cihaz kayıtlarınız ve oturum bilgileriniz silinir.",
          "Daire bağlantınız sonlandırılır ve hesabınız kapatılır.",
          "Hesabınıza bağlı başka bir kayıt yoksa hesap **tamamen silinir**; varsa aşağıdaki kayıtların bütünlüğü için **anonimleştirilir** (adınız yerine kimliksiz bir ifade konur).",
        ],
      },
      {
        baslik: "4. Saklanan veriler ve nedeni",
        paragraflar: [
          "**Devriye okutmalarında kaydedilen konum bilgileri** ve **yüklediğiniz fotoğraflar** silinmez.",
          "Bunlar tesisin operasyonel ve denetim kaydıdır: bir turun gerçekten yapıldığını, bir arızanın bildirildiğini ve ne zaman çözüldüğünü gösterirler. Silinmeleri, tesise ait bir kaydın geçmişini bozardı.",
          "Bu kayıtlar silme sonrasında **sizinle ilişkilendirilemez** hale gelir; adınız yerine kimliksiz bir ifade görünür.",
          "Ayrıca mevzuat gereği tutulması zorunlu muhasebe ve işlem kayıtları yasal süreleri boyunca saklanır.",
        ],
      },
      {
        baslik: "5. İletişim",
        paragraflar: [
          "Silme talepleri ve sorularınız için: **destek@yonetiyor.com**",
          "Hesabınız bir tesise bağlıdır; veri sorumlusu o tesisin yönetimidir. Talebinizi tesis yönetimine de iletebilirsiniz.",
        ],
      },
    ],
  },
  en: {
    baslik: "Account Deletion",
    guncelleme: "Last updated: 6 August 2026",
    kaynakBaglayici: "The binding version of this document is the Turkish original.",
    giris: "This page explains how to delete your Yönetiyor account, which data is removed, and which data is retained afterwards. You do not need to sign in to request deletion.",
    bolumler: [
      {
        baslik: "1. Delete from the app (fastest)",
        paragraflar: [
          "Open the Yönetiyor app and go to **Settings → Delete my account**.",
          "Enter your password, or the verification code sent to your phone if you use passwordless sign-in. This step prevents someone holding your phone from deleting your account.",
          "Once confirmed, deletion is applied **immediately**.",
        ],
      },
      {
        baslik: "2. If you cannot access the app",
        paragraflar: [
          "Contact us from the **phone number registered to your account** at the address below and state your deletion request.",
          "We verify that the number belongs to you before acting; unverified requests are not carried out.",
          "Requests are completed **within 30 days at the latest**; deletion from the app is immediate.",
        ],
      },
      {
        baslik: "3. Data that is deleted",
        paragraflar: [
          "Your name, email address, phone number and profile photo are removed.",
          "Your device records used for notifications and your session data are deleted.",
          "Your link to the apartment is ended and your account is closed.",
          "If no other records reference your account it is **deleted entirely**; otherwise it is **anonymised** (your name is replaced by a non-identifying label) to preserve the integrity of the records below.",
        ],
      },
      {
        baslik: "4. Data that is retained, and why",
        paragraflar: [
          "**Location data recorded during patrol scans** and **photos you uploaded** are not deleted.",
          "These are the building's operational and audit record: they show that a round was actually walked, that a fault was reported and when it was resolved. Deleting them would break the history of a record belonging to the building.",
          "After deletion these records **cannot be linked back to you**; a non-identifying label appears instead of your name.",
          "Accounting and transaction records required by law are kept for their statutory periods.",
        ],
      },
      {
        baslik: "5. Contact",
        paragraflar: [
          "For deletion requests and questions: **destek@yonetiyor.com**",
          "Your account belongs to a building; the data controller is that building's management. You may also address your request to them.",
        ],
      },
    ],
  },
  de: {
    baslik: "Kontolöschung",
    guncelleme: "Zuletzt aktualisiert: 6. August 2026",
    kaynakBaglayici: "Die verbindliche Fassung dieses Dokuments ist das türkische Original.",
    giris: "Diese Seite erklärt, wie Sie Ihr Yönetiyor-Konto löschen, welche Daten entfernt und welche danach aufbewahrt werden. Für die Anfrage ist keine Anmeldung erforderlich.",
    bolumler: [
      {
        baslik: "1. Löschung in der App (am schnellsten)",
        paragraflar: [
          "Open the Yönetiyor app and go to **Settings → Delete my account**.",
          "Enter your password, or the verification code sent to your phone if you use passwordless sign-in. This step prevents someone holding your phone from deleting your account.",
          "Once confirmed, deletion is applied **immediately**.",
        ],
      },
      {
        baslik: "2. Wenn Sie keinen Zugriff auf die App haben",
        paragraflar: [
          "Contact us from the **phone number registered to your account** at the address below and state your deletion request.",
          "We verify that the number belongs to you before acting; unverified requests are not carried out.",
          "Requests are completed **within 30 days at the latest**; deletion from the app is immediate.",
        ],
      },
      {
        baslik: "3. Gelöschte Daten",
        paragraflar: [
          "Your name, email address, phone number and profile photo are removed.",
          "Your device records used for notifications and your session data are deleted.",
          "Your link to the apartment is ended and your account is closed.",
          "If no other records reference your account it is **deleted entirely**; otherwise it is **anonymised** (your name is replaced by a non-identifying label) to preserve the integrity of the records below.",
        ],
      },
      {
        baslik: "4. Aufbewahrte Daten und Gründe",
        paragraflar: [
          "**Location data recorded during patrol scans** and **photos you uploaded** are not deleted.",
          "These are the building's operational and audit record: they show that a round was actually walked, that a fault was reported and when it was resolved. Deleting them would break the history of a record belonging to the building.",
          "After deletion these records **cannot be linked back to you**; a non-identifying label appears instead of your name.",
          "Accounting and transaction records required by law are kept for their statutory periods.",
        ],
      },
      {
        baslik: "5. Kontakt",
        paragraflar: [
          "For deletion requests and questions: **destek@yonetiyor.com**",
          "Your account belongs to a building; the data controller is that building's management. You may also address your request to them.",
        ],
      },
    ],
  },
  fr: {
    baslik: "Suppression du compte",
    guncelleme: "Dernière mise à jour : 6 août 2026",
    kaynakBaglayici: "La version contraignante de ce document est l'original turc.",
    giris: "Cette page explique comment supprimer votre compte Yönetiyor, quelles données sont supprimées et lesquelles sont conservées. Aucune connexion n'est nécessaire pour en faire la demande.",
    bolumler: [
      {
        baslik: "1. Suppression depuis l'application (le plus rapide)",
        paragraflar: [
          "Open the Yönetiyor app and go to **Settings → Delete my account**.",
          "Enter your password, or the verification code sent to your phone if you use passwordless sign-in. This step prevents someone holding your phone from deleting your account.",
          "Once confirmed, deletion is applied **immediately**.",
        ],
      },
      {
        baslik: "2. Si vous n'avez pas accès à l'application",
        paragraflar: [
          "Contact us from the **phone number registered to your account** at the address below and state your deletion request.",
          "We verify that the number belongs to you before acting; unverified requests are not carried out.",
          "Requests are completed **within 30 days at the latest**; deletion from the app is immediate.",
        ],
      },
      {
        baslik: "3. Données supprimées",
        paragraflar: [
          "Your name, email address, phone number and profile photo are removed.",
          "Your device records used for notifications and your session data are deleted.",
          "Your link to the apartment is ended and your account is closed.",
          "If no other records reference your account it is **deleted entirely**; otherwise it is **anonymised** (your name is replaced by a non-identifying label) to preserve the integrity of the records below.",
        ],
      },
      {
        baslik: "4. Données conservées et pourquoi",
        paragraflar: [
          "**Location data recorded during patrol scans** and **photos you uploaded** are not deleted.",
          "These are the building's operational and audit record: they show that a round was actually walked, that a fault was reported and when it was resolved. Deleting them would break the history of a record belonging to the building.",
          "After deletion these records **cannot be linked back to you**; a non-identifying label appears instead of your name.",
          "Accounting and transaction records required by law are kept for their statutory periods.",
        ],
      },
      {
        baslik: "5. Contact",
        paragraflar: [
          "For deletion requests and questions: **destek@yonetiyor.com**",
          "Your account belongs to a building; the data controller is that building's management. You may also address your request to them.",
        ],
      },
    ],
  },
  es: {
    baslik: "Eliminación de la cuenta",
    guncelleme: "Última actualización: 6 de agosto de 2026",
    kaynakBaglayici: "La versión vinculante de este documento es el original en turco.",
    giris: "Esta página explica cómo eliminar su cuenta de Yönetiyor, qué datos se eliminan y cuáles se conservan. No necesita iniciar sesión para solicitarlo.",
    bolumler: [
      {
        baslik: "1. Eliminar desde la aplicación (lo más rápido)",
        paragraflar: [
          "Open the Yönetiyor app and go to **Settings → Delete my account**.",
          "Enter your password, or the verification code sent to your phone if you use passwordless sign-in. This step prevents someone holding your phone from deleting your account.",
          "Once confirmed, deletion is applied **immediately**.",
        ],
      },
      {
        baslik: "2. Si no puede acceder a la aplicación",
        paragraflar: [
          "Contact us from the **phone number registered to your account** at the address below and state your deletion request.",
          "We verify that the number belongs to you before acting; unverified requests are not carried out.",
          "Requests are completed **within 30 days at the latest**; deletion from the app is immediate.",
        ],
      },
      {
        baslik: "3. Datos que se eliminan",
        paragraflar: [
          "Your name, email address, phone number and profile photo are removed.",
          "Your device records used for notifications and your session data are deleted.",
          "Your link to the apartment is ended and your account is closed.",
          "If no other records reference your account it is **deleted entirely**; otherwise it is **anonymised** (your name is replaced by a non-identifying label) to preserve the integrity of the records below.",
        ],
      },
      {
        baslik: "4. Datos que se conservan y por qué",
        paragraflar: [
          "**Location data recorded during patrol scans** and **photos you uploaded** are not deleted.",
          "These are the building's operational and audit record: they show that a round was actually walked, that a fault was reported and when it was resolved. Deleting them would break the history of a record belonging to the building.",
          "After deletion these records **cannot be linked back to you**; a non-identifying label appears instead of your name.",
          "Accounting and transaction records required by law are kept for their statutory periods.",
        ],
      },
      {
        baslik: "5. Contacto",
        paragraflar: [
          "For deletion requests and questions: **destek@yonetiyor.com**",
          "Your account belongs to a building; the data controller is that building's management. You may also address your request to them.",
        ],
      },
    ],
  },
  ru: {
    baslik: "Удаление аккаунта",
    guncelleme: "Последнее обновление: 6 августа 2026 г.",
    kaynakBaglayici: "Обязательной является турецкая версия этого документа.",
    giris: "На этой странице описано, как удалить аккаунт Yönetiyor, какие данные удаляются и какие сохраняются. Для запроса вход в систему не требуется.",
    bolumler: [
      {
        baslik: "1. Удаление в приложении (самый быстрый способ)",
        paragraflar: [
          "Open the Yönetiyor app and go to **Settings → Delete my account**.",
          "Enter your password, or the verification code sent to your phone if you use passwordless sign-in. This step prevents someone holding your phone from deleting your account.",
          "Once confirmed, deletion is applied **immediately**.",
        ],
      },
      {
        baslik: "2. Если у вас нет доступа к приложению",
        paragraflar: [
          "Contact us from the **phone number registered to your account** at the address below and state your deletion request.",
          "We verify that the number belongs to you before acting; unverified requests are not carried out.",
          "Requests are completed **within 30 days at the latest**; deletion from the app is immediate.",
        ],
      },
      {
        baslik: "3. Удаляемые данные",
        paragraflar: [
          "Your name, email address, phone number and profile photo are removed.",
          "Your device records used for notifications and your session data are deleted.",
          "Your link to the apartment is ended and your account is closed.",
          "If no other records reference your account it is **deleted entirely**; otherwise it is **anonymised** (your name is replaced by a non-identifying label) to preserve the integrity of the records below.",
        ],
      },
      {
        baslik: "4. Сохраняемые данные и причины",
        paragraflar: [
          "**Location data recorded during patrol scans** and **photos you uploaded** are not deleted.",
          "These are the building's operational and audit record: they show that a round was actually walked, that a fault was reported and when it was resolved. Deleting them would break the history of a record belonging to the building.",
          "After deletion these records **cannot be linked back to you**; a non-identifying label appears instead of your name.",
          "Accounting and transaction records required by law are kept for their statutory periods.",
        ],
      },
      {
        baslik: "5. Контакты",
        paragraflar: [
          "For deletion requests and questions: **destek@yonetiyor.com**",
          "Your account belongs to a building; the data controller is that building's management. You may also address your request to them.",
        ],
      },
    ],
  },
  ar: {
    baslik: "حذف الحساب",
    guncelleme: "آخر تحديث: 6 أغسطس 2026",
    kaynakBaglayici: "النسخة الملزمة من هذا المستند هي النسخة التركية الأصلية.",
    giris: "توضح هذه الصفحة كيفية حذف حساب Yönetiyor، وأي البيانات تُحذف وأيها يُحتفظ به بعد ذلك. لا تحتاج إلى تسجيل الدخول لتقديم الطلب.",
    bolumler: [
      {
        baslik: "١. الحذف من التطبيق (الأسرع)",
        paragraflar: [
          "Open the Yönetiyor app and go to **Settings → Delete my account**.",
          "Enter your password, or the verification code sent to your phone if you use passwordless sign-in. This step prevents someone holding your phone from deleting your account.",
          "Once confirmed, deletion is applied **immediately**.",
        ],
      },
      {
        baslik: "٢. إذا تعذّر عليك الوصول إلى التطبيق",
        paragraflar: [
          "Contact us from the **phone number registered to your account** at the address below and state your deletion request.",
          "We verify that the number belongs to you before acting; unverified requests are not carried out.",
          "Requests are completed **within 30 days at the latest**; deletion from the app is immediate.",
        ],
      },
      {
        baslik: "٣. البيانات التي تُحذف",
        paragraflar: [
          "Your name, email address, phone number and profile photo are removed.",
          "Your device records used for notifications and your session data are deleted.",
          "Your link to the apartment is ended and your account is closed.",
          "If no other records reference your account it is **deleted entirely**; otherwise it is **anonymised** (your name is replaced by a non-identifying label) to preserve the integrity of the records below.",
        ],
      },
      {
        baslik: "٤. البيانات المحتفظ بها وسببها",
        paragraflar: [
          "**Location data recorded during patrol scans** and **photos you uploaded** are not deleted.",
          "These are the building's operational and audit record: they show that a round was actually walked, that a fault was reported and when it was resolved. Deleting them would break the history of a record belonging to the building.",
          "After deletion these records **cannot be linked back to you**; a non-identifying label appears instead of your name.",
          "Accounting and transaction records required by law are kept for their statutory periods.",
        ],
      },
      {
        baslik: "٥. التواصل",
        paragraflar: [
          "For deletion requests and questions: **destek@yonetiyor.com**",
          "Your account belongs to a building; the data controller is that building's management. You may also address your request to them.",
        ],
      },
    ],
  },
};
