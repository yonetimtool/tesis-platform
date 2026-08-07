import type { BelgeSeti } from "./tipler";

// (P113) KULLANIM KOSULLARI — 7 dil. Kaynak ve BAGLAYICI surum: Turkce.
//
// ICERIKTEKI KRITIK MADDE — ODEME MODELI (App Store 3.1.3(e)): aidat,
// uygulama disinda tuketilen **gercek dunya hizmetinin** bedelidir (tesis
// yonetimi, temizlik, guvenlik, bakim). Bu yuzden uygulama ici satin alma
// (IAP) kullanilmaz ve kullanilamaz. Kosullarda bunu ACIKCA yazmak,
// denetimde "neden IAP yok" sorusunun yanitini kullanicinin de gordugu bir
// yere koymak demektir.
export const KOSULLAR: BelgeSeti = {
  tr: {
    baslik: "Kullanım Koşulları",
    guncelleme: "Son güncelleme: 2 Ağustos 2026",
    kaynakBaglayici: "",
    giris:
      "Yönetio'yu kullanarak aşağıdaki koşulları kabul etmiş olursunuz. Lütfen dikkatlice okuyun.",
    bolumler: [
      {
        baslik: "1. Hizmet nedir?",
        paragraflar: [
          "Yönetio; site, apartman ve rezidans yönetimi için bir yazılım hizmetidir. Aidat takibi, talep ve şikâyet yönetimi, duyuru, etkinlik, ziyaretçi ve güvenlik turu kayıtlarını tek yerde toplar.",
          "Yönetio tesisin kendisini yönetmez: kararları ve hizmetleri sağlayan taraf **tesis yönetimidir**. Yönetio bu işi kolaylaştıran araçtır.",
        ],
      },
      {
        baslik: "2. Hesaplar",
        paragraflar: [
          "Hesaplar tesis yönetimi tarafından açılır; herkese açık bir kayıt formu yoktur.",
          "Hesabınızın güvenliğinden siz sorumlusunuz. Parolanızı paylaşmayın; şüpheli bir durumda tesis yönetimine bildirin.",
          "Bir hesabı yalnızca size verilen yetki kapsamında kullanabilirsiniz.",
        ],
      },
      {
        baslik: "3. Ödemeler ve aidat",
        paragraflar: [
          "Uygulamada görünen aidat, gecikme ve ödeme tutarları **tesis yönetiminin belirlediği, uygulama dışında tüketilen gerçek dünya hizmetlerinin** bedelidir (yönetim, temizlik, güvenlik, bakım, ortak gider).",
          "Bu nedenle **uygulama içi satın alma (in-app purchase) kullanılmaz**; ödeme, tesisin kendi tahsilat yöntemiyle yapılır.",
          "Yönetio bu tutarları belirlemez, tahsil etmez ve bunlardan pay almaz; yalnızca kaydını tutar. Tutarlara ilişkin itirazlarınızı tesis yönetimine iletirsiniz.",
        ],
      },
      {
        baslik: "4. Kabul edilmeyen kullanım",
        paragraflar: [
          "Başkasının hesabını kullanmak, sistemi yetkiniz dışında bir veriye erişmek için zorlamak, hizmeti aşırı yükleyecek otomatik istek göndermek yasaktır.",
          "Yüklediğiniz içerik hakaret, tehdit, ayrımcılık ya da hukuka aykırı unsur içeremez. Başkalarının kişisel verisini izinsiz paylaşamazsınız.",
          "Bu kurallara aykırı kullanım hâlinde tesis yönetimi hesabınızı askıya alabilir.",
        ],
      },
      {
        baslik: "5. İçerik ve sorumluluk",
        paragraflar: [
          "Duyuru, talep, fotoğraf gibi içeriklerin doğruluğundan bunları giren kullanıcı sorumludur.",
          "Otomatik çeviriler bilgilendirme amaçlıdır ve bağlayıcı metin her zaman orijinaldir; çevrilen her içerik uygulamada bu notu taşır.",
          "Yönetio, hizmetin kesintisiz ve hatasız olacağını taahhüt etmez; makul çabayı gösterir ve bilinen sorunları giderir.",
        ],
      },
      {
        baslik: "6. Hizmette değişiklik",
        paragraflar: [
          "Özellikler zamanla değişebilir, eklenebilir veya kaldırılabilir. Önemli değişiklikler uygulama içinde duyurulur.",
          "Bakım nedeniyle kısa süreli kesintiler olabilir.",
        ],
      },
      {
        baslik: "7. Hesabın sona ermesi",
        paragraflar: [
          "**Hesabınızı istediğiniz an uygulama içinden silebilirsiniz:** Ayarlar → Hesabımı sil.",
          "Yasal olarak saklanması zorunlu olan aidat/ödeme ve denetim kayıtları, kimliğinizle bağlantısı kesilerek anonim biçimde saklanmaya devam eder. Ayrıntı için Gizlilik Politikası.",
          "Tesisten ayrılmanız hâlinde yönetim hesabınızı kapatabilir.",
        ],
      },
      {
        baslik: "8. Uygulanacak hukuk ve iletişim",
        paragraflar: [
          "Bu koşullara Türkiye Cumhuriyeti hukuku uygulanır.",
          "İletişim: **destek@yonetiyor.com**",
        ],
      },
    ],
  },

  en: {
    baslik: "Terms of Use",
    guncelleme: "Last updated: 2 August 2026",
    kaynakBaglayici:
      "This is a translation provided for information. The binding version of these terms is the Turkish one.",
    giris:
      "By using Yönetio you accept the terms below. Please read them carefully.",
    bolumler: [
      {
        baslik: "1. What the service is",
        paragraflar: [
          "Yönetio is a software service for managing apartment buildings, gated communities and residences. It brings dues tracking, requests and complaints, announcements, events, visitors and security patrol records into one place.",
          "Yönetio does not manage the property itself: decisions and services are provided by **the site management**. Yönetio is the tool that makes that work easier.",
        ],
      },
      {
        baslik: "2. Accounts",
        paragraflar: [
          "Accounts are created by the site management; there is no public sign-up form.",
          "You are responsible for the security of your account. Do not share your password; report anything suspicious to your site management.",
          "You may use an account only within the permissions granted to you.",
        ],
      },
      {
        baslik: "3. Payments and dues",
        paragraflar: [
          "Dues, late fees and payment amounts shown in the app are the price of **real-world services consumed outside the app** and set by the site management (management, cleaning, security, maintenance, shared costs).",
          "For this reason **in-app purchase is not used**; payment is made through the site's own collection method.",
          "Yönetio does not set, collect or take a share of these amounts; it only keeps the record. Objections about amounts go to your site management.",
        ],
      },
      {
        baslik: "4. Unacceptable use",
        paragraflar: [
          "Using someone else's account, attempting to reach data beyond your permissions, or sending automated requests that overload the service is prohibited.",
          "Content you upload must not contain insults, threats, discrimination or unlawful material. You may not share other people's personal data without their permission.",
          "In case of violation, the site management may suspend your account.",
        ],
      },
      {
        baslik: "5. Content and liability",
        paragraflar: [
          "The user who enters content (announcements, requests, photos) is responsible for its accuracy.",
          "Automatic translations are provided for information and the binding text is always the original; every translated item carries this note in the app.",
          "Yönetio does not guarantee uninterrupted or error-free operation; it applies reasonable effort and fixes known issues.",
        ],
      },
      {
        baslik: "6. Changes to the service",
        paragraflar: [
          "Features may change, be added or be removed over time. Significant changes are announced inside the app.",
          "Short interruptions may occur due to maintenance.",
        ],
      },
      {
        baslik: "7. Ending your account",
        paragraflar: [
          "**You can delete your account from inside the app at any time:** Settings → Delete my account.",
          "Dues/payment and audit records we are legally required to keep remain stored anonymously, with the link to your identity removed. See the Privacy Policy for details.",
          "If you leave the site, management may close your account.",
        ],
      },
      {
        baslik: "8. Governing law and contact",
        paragraflar: [
          "These terms are governed by the laws of the Republic of Türkiye.",
          "Contact: **destek@yonetiyor.com**",
        ],
      },
    ],
  },

  ar: {
    baslik: "شروط الاستخدام",
    guncelleme: "آخر تحديث: 2 أغسطس 2026",
    kaynakBaglayici:
      "هذه ترجمة مقدَّمة للاطلاع فقط. النسخة المُلزِمة من هذه الشروط هي النسخة التركية.",
    giris: "باستخدامك Yönetio فإنك تقبل الشروط أدناه. يُرجى قراءتها بعناية.",
    bolumler: [
      {
        baslik: "١. ما هي الخدمة؟",
        paragraflar: [
          "Yönetio خدمة برمجية لإدارة المجمّعات والعمارات السكنية: تجمع متابعة الرسوم والطلبات والشكاوى والإعلانات والفعاليات والزوار وسجلات الدوريات الأمنية في مكان واحد.",
          "لا تدير Yönetio العقار نفسه؛ القرارات والخدمات تقدّمها **إدارة الموقع**، وYönetio هي الأداة التي تسهّل ذلك.",
        ],
      },
      {
        baslik: "٢. الحسابات",
        paragraflar: [
          "تُنشئ إدارة الموقع الحسابات، ولا يوجد نموذج تسجيل عام.",
          "أنت مسؤول عن أمان حسابك. لا تشارك كلمة المرور، وأبلغ الإدارة عند أي شبهة.",
          "لا يجوز استخدام الحساب إلا في حدود الصلاحيات الممنوحة لك.",
        ],
      },
      {
        baslik: "٣. المدفوعات والرسوم",
        paragraflar: [
          "الرسوم والغرامات والمبالغ الظاهرة في التطبيق هي ثمن **خدمات واقعية تُستهلك خارج التطبيق** وتحدّدها إدارة الموقع (الإدارة، النظافة، الأمن، الصيانة، المصاريف المشتركة).",
          "لذلك **لا تُستخدم المشتريات داخل التطبيق**؛ ويتم الدفع بوسيلة التحصيل الخاصة بالموقع.",
          "لا تحدّد Yönetio هذه المبالغ ولا تحصّلها ولا تأخذ حصة منها، بل تحفظ سجلها فقط. وتُوجَّه الاعتراضات إلى إدارة الموقع.",
        ],
      },
      {
        baslik: "٤. الاستخدام غير المقبول",
        paragraflar: [
          "يُحظر استخدام حساب شخص آخر، أو محاولة الوصول إلى بيانات خارج صلاحيتك، أو إرسال طلبات آلية تُثقل الخدمة.",
          "يجب ألا يتضمن ما ترفعه إهانة أو تهديدًا أو تمييزًا أو مادة غير قانونية، ولا يجوز نشر بيانات الآخرين الشخصية دون إذنهم.",
          "عند المخالفة يجوز لإدارة الموقع تعليق حسابك.",
        ],
      },
      {
        baslik: "٥. المحتوى والمسؤولية",
        paragraflar: [
          "المستخدم الذي يُدخل المحتوى (إعلان، طلب، صورة) مسؤول عن صحته.",
          "الترجمات الآلية للاطلاع فقط، والنص المُلزِم هو الأصل دائمًا، ويحمل كل محتوى مترجَم هذه الملاحظة داخل التطبيق.",
          "لا تضمن Yönetio عملًا دون انقطاع أو أخطاء، لكنها تبذل الجهد المعقول وتعالج المشكلات المعروفة.",
        ],
      },
      {
        baslik: "٦. التغييرات على الخدمة",
        paragraflar: [
          "قد تتغير الميزات أو تُضاف أو تُزال مع الوقت، وتُعلَن التغييرات المهمة داخل التطبيق.",
          "قد تحدث انقطاعات قصيرة بسبب الصيانة.",
        ],
      },
      {
        baslik: "٧. إنهاء الحساب",
        paragraflar: [
          "**يمكنك حذف حسابك من داخل التطبيق في أي وقت:** الإعدادات ← حذف حسابي.",
          "تبقى سجلات الرسوم والمدفوعات والتدقيق التي يلزمنا القانون بحفظها مخزَّنة بشكل مجهول بعد فصلها عن هويتك. راجع سياسة الخصوصية للتفاصيل.",
          "عند مغادرتك الموقع يجوز للإدارة إغلاق حسابك.",
        ],
      },
      {
        baslik: "٨. القانون الواجب التطبيق والتواصل",
        paragraflar: [
          "تخضع هذه الشروط لقوانين جمهورية تركيا.",
          "للتواصل: **destek@yonetiyor.com**",
        ],
      },
    ],
  },

  ru: {
    baslik: "Условия использования",
    guncelleme: "Последнее обновление: 2 августа 2026 г.",
    kaynakBaglayici:
      "Это перевод, предоставленный для ознакомления. Обязательной является турецкая версия условий.",
    giris:
      "Используя Yönetio, вы принимаете изложенные ниже условия. Пожалуйста, внимательно их прочитайте.",
    bolumler: [
      {
        baslik: "1. Что представляет собой сервис",
        paragraflar: [
          "Yönetio — программный сервис для управления жилыми комплексами и многоквартирными домами: учёт взносов, заявки и жалобы, объявления, мероприятия, посетители и записи охранных обходов в одном месте.",
          "Yönetio не управляет самим объектом: решения принимает и услуги оказывает **управление объекта**, а Yönetio — инструмент, который облегчает эту работу.",
        ],
      },
      {
        baslik: "2. Учётные записи",
        paragraflar: [
          "Учётные записи создаёт управление объекта; открытой формы регистрации нет.",
          "Вы отвечаете за безопасность своей учётной записи. Не сообщайте пароль другим; о подозрительных случаях сообщайте управлению.",
          "Использовать учётную запись можно только в пределах предоставленных вам прав.",
        ],
      },
      {
        baslik: "3. Платежи и взносы",
        paragraflar: [
          "Взносы, пени и суммы платежей, отображаемые в приложении, — это стоимость **реальных услуг, потребляемых вне приложения**, которые определяет управление объекта (управление, уборка, охрана, обслуживание, общие расходы).",
          "Поэтому **встроенные покупки не используются**; оплата производится способом, принятым в вашем объекте.",
          "Yönetio не устанавливает и не взимает эти суммы и не получает от них долю — только ведёт учёт. Возражения по суммам направляйте в управление объекта.",
        ],
      },
      {
        baslik: "4. Недопустимое использование",
        paragraflar: [
          "Запрещено использовать чужую учётную запись, пытаться получить данные вне своих прав или отправлять автоматические запросы, перегружающие сервис.",
          "Загружаемые материалы не должны содержать оскорблений, угроз, дискриминации или противоправного содержания. Нельзя публиковать персональные данные других лиц без их согласия.",
          "При нарушении управление объекта может приостановить вашу учётную запись.",
        ],
      },
      {
        baslik: "5. Содержание и ответственность",
        paragraflar: [
          "За достоверность внесённых материалов (объявлений, заявок, фотографий) отвечает разместивший их пользователь.",
          "Автоматические переводы носят информационный характер, обязательным всегда является оригинал; каждый переведённый материал сопровождается соответствующей пометкой.",
          "Yönetio не гарантирует бесперебойной и безошибочной работы, но прилагает разумные усилия и устраняет известные проблемы.",
        ],
      },
      {
        baslik: "6. Изменения сервиса",
        paragraflar: [
          "Функции со временем могут меняться, добавляться или удаляться. О существенных изменениях сообщается в приложении.",
          "Возможны кратковременные перерывы из-за обслуживания.",
        ],
      },
      {
        baslik: "7. Прекращение учётной записи",
        paragraflar: [
          "**Вы можете удалить учётную запись прямо в приложении в любое время:** Настройки → Удалить мою учётную запись.",
          "Записи о взносах, платежах и аудите, которые мы обязаны хранить по закону, остаются в системе обезличенными, без связи с вашей личностью. Подробности — в Политике конфиденциальности.",
          "При выезде из объекта управление может закрыть вашу учётную запись.",
        ],
      },
      {
        baslik: "8. Применимое право и контакты",
        paragraflar: [
          "К настоящим условиям применяется право Турецкой Республики.",
          "Контакт: **destek@yonetiyor.com**",
        ],
      },
    ],
  },

  de: {
    baslik: "Nutzungsbedingungen",
    guncelleme: "Zuletzt aktualisiert: 2. August 2026",
    kaynakBaglayici:
      "Dies ist eine Übersetzung zu Informationszwecken. Verbindlich ist die türkische Fassung dieser Bedingungen.",
    giris:
      "Mit der Nutzung von Yönetio akzeptieren Sie die folgenden Bedingungen. Bitte lesen Sie sie aufmerksam.",
    bolumler: [
      {
        baslik: "1. Was der Dienst ist",
        paragraflar: [
          "Yönetio ist ein Softwaredienst für die Verwaltung von Wohnanlagen und Mehrfamilienhäusern: Beitragsverwaltung, Anliegen und Beschwerden, Ankündigungen, Veranstaltungen, Besucher und Sicherheitsrundgänge an einem Ort.",
          "Yönetio verwaltet die Immobilie nicht selbst: Entscheidungen trifft und Leistungen erbringt **die Verwaltung der Anlage**; Yönetio ist das Werkzeug dafür.",
        ],
      },
      {
        baslik: "2. Konten",
        paragraflar: [
          "Konten werden von der Verwaltung angelegt; es gibt kein öffentliches Registrierungsformular.",
          "Für die Sicherheit Ihres Kontos sind Sie verantwortlich. Geben Sie Ihr Passwort nicht weiter und melden Sie Auffälligkeiten der Verwaltung.",
          "Ein Konto darf nur im Rahmen der Ihnen erteilten Berechtigungen genutzt werden.",
        ],
      },
      {
        baslik: "3. Zahlungen und Beiträge",
        paragraflar: [
          "Die in der App angezeigten Beiträge, Säumniszuschläge und Zahlungsbeträge sind das Entgelt für **außerhalb der App erbrachte reale Leistungen**, die die Verwaltung festlegt (Verwaltung, Reinigung, Sicherheit, Instandhaltung, Gemeinschaftskosten).",
          "Deshalb werden **keine In-App-Käufe verwendet**; die Zahlung erfolgt über das Einzugsverfahren der Anlage.",
          "Yönetio legt diese Beträge weder fest noch zieht es sie ein oder erhält einen Anteil; es führt nur die Aufzeichnung. Einwände richten Sie an Ihre Verwaltung.",
        ],
      },
      {
        baslik: "4. Unzulässige Nutzung",
        paragraflar: [
          "Die Nutzung fremder Konten, Versuche, auf Daten außerhalb Ihrer Berechtigung zuzugreifen, oder automatisierte Anfragen, die den Dienst überlasten, sind untersagt.",
          "Hochgeladene Inhalte dürfen keine Beleidigungen, Drohungen, Diskriminierung oder rechtswidrigen Inhalte enthalten. Personenbezogene Daten Dritter dürfen nicht ohne deren Zustimmung geteilt werden.",
          "Bei Verstößen kann die Verwaltung Ihr Konto sperren.",
        ],
      },
      {
        baslik: "5. Inhalte und Haftung",
        paragraflar: [
          "Für die Richtigkeit eingestellter Inhalte (Ankündigungen, Anliegen, Fotos) ist die einstellende Person verantwortlich.",
          "Automatische Übersetzungen dienen der Information; verbindlich ist stets das Original. Jeder übersetzte Inhalt trägt in der App einen entsprechenden Hinweis.",
          "Yönetio sichert keinen unterbrechungs- und fehlerfreien Betrieb zu, unternimmt aber angemessene Anstrengungen und behebt bekannte Probleme.",
        ],
      },
      {
        baslik: "6. Änderungen des Dienstes",
        paragraflar: [
          "Funktionen können sich ändern, hinzukommen oder entfallen. Wesentliche Änderungen werden in der App angekündigt.",
          "Wartungsbedingt sind kurze Unterbrechungen möglich.",
        ],
      },
      {
        baslik: "7. Beendigung des Kontos",
        paragraflar: [
          "**Sie können Ihr Konto jederzeit in der App löschen:** Einstellungen → Mein Konto löschen.",
          "Beitrags-, Zahlungs- und Prüfunterlagen, zu deren Aufbewahrung wir gesetzlich verpflichtet sind, bleiben anonymisiert und ohne Bezug zu Ihrer Person gespeichert. Einzelheiten in der Datenschutzerklärung.",
          "Bei Auszug kann die Verwaltung Ihr Konto schließen.",
        ],
      },
      {
        baslik: "8. Anwendbares Recht und Kontakt",
        paragraflar: [
          "Auf diese Bedingungen findet das Recht der Republik Türkei Anwendung.",
          "Kontakt: **destek@yonetiyor.com**",
        ],
      },
    ],
  },

  fr: {
    baslik: "Conditions d'utilisation",
    guncelleme: "Dernière mise à jour : 2 août 2026",
    kaynakBaglayici:
      "Ceci est une traduction fournie à titre d'information. La version turque de ces conditions fait foi.",
    giris:
      "En utilisant Yönetio, vous acceptez les conditions ci-dessous. Merci de les lire attentivement.",
    bolumler: [
      {
        baslik: "1. Ce qu'est le service",
        paragraflar: [
          "Yönetio est un service logiciel de gestion de copropriétés et de résidences : suivi des charges, demandes et réclamations, annonces, événements, visiteurs et rondes de sécurité en un seul endroit.",
          "Yönetio ne gère pas l'immeuble lui-même : les décisions et les prestations relèvent de **la gestion du site** ; Yönetio est l'outil qui facilite ce travail.",
        ],
      },
      {
        baslik: "2. Comptes",
        paragraflar: [
          "Les comptes sont créés par la gestion du site ; il n'existe pas de formulaire d'inscription public.",
          "Vous êtes responsable de la sécurité de votre compte. Ne communiquez pas votre mot de passe et signalez toute anomalie à la gestion.",
          "Un compte ne peut être utilisé que dans les limites des droits qui vous sont accordés.",
        ],
      },
      {
        baslik: "3. Paiements et charges",
        paragraflar: [
          "Les charges, pénalités et montants affichés dans l'application correspondent au prix de **services réels consommés en dehors de l'application**, fixés par la gestion du site (gestion, nettoyage, sécurité, entretien, charges communes).",
          "C'est pourquoi **aucun achat intégré n'est utilisé** ; le paiement s'effectue selon le mode d'encaissement propre au site.",
          "Yönetio ne fixe pas ces montants, ne les encaisse pas et n'en perçoit aucune part ; il en tient uniquement le registre. Les contestations sont à adresser à la gestion.",
        ],
      },
      {
        baslik: "4. Usages interdits",
        paragraflar: [
          "Il est interdit d'utiliser le compte d'autrui, de tenter d'accéder à des données hors de vos droits ou d'envoyer des requêtes automatisées surchargeant le service.",
          "Les contenus que vous publiez ne doivent comporter ni insultes, ni menaces, ni discrimination, ni élément illicite. Vous ne pouvez pas diffuser les données personnelles d'autrui sans son accord.",
          "En cas de manquement, la gestion peut suspendre votre compte.",
        ],
      },
      {
        baslik: "5. Contenus et responsabilité",
        paragraflar: [
          "L'utilisateur qui saisit un contenu (annonce, demande, photo) est responsable de son exactitude.",
          "Les traductions automatiques sont fournies à titre d'information et le texte qui fait foi reste l'original ; chaque contenu traduit porte cette mention dans l'application.",
          "Yönetio ne garantit pas un fonctionnement ininterrompu et sans erreur ; il met en œuvre des efforts raisonnables et corrige les problèmes connus.",
        ],
      },
      {
        baslik: "6. Évolutions du service",
        paragraflar: [
          "Les fonctionnalités peuvent évoluer, être ajoutées ou supprimées. Les changements importants sont annoncés dans l'application.",
          "De courtes interruptions peuvent survenir pour maintenance.",
        ],
      },
      {
        baslik: "7. Fin du compte",
        paragraflar: [
          "**Vous pouvez supprimer votre compte à tout moment depuis l'application :** Paramètres → Supprimer mon compte.",
          "Les pièces de charges, de paiement et d'audit que la loi nous impose de conserver restent stockées de façon anonyme, sans lien avec votre identité. Voir la Politique de confidentialité.",
          "En cas de départ du site, la gestion peut clôturer votre compte.",
        ],
      },
      {
        baslik: "8. Droit applicable et contact",
        paragraflar: [
          "Ces conditions sont régies par le droit de la République de Türkiye.",
          "Contact : **destek@yonetiyor.com**",
        ],
      },
    ],
  },

  es: {
    baslik: "Condiciones de uso",
    guncelleme: "Última actualización: 2 de agosto de 2026",
    kaynakBaglayici:
      "Esta es una traducción proporcionada a título informativo. La versión vinculante de estas condiciones es la turca.",
    giris:
      "Al usar Yönetio acepta las condiciones siguientes. Léalas con atención.",
    bolumler: [
      {
        baslik: "1. Qué es el servicio",
        paragraflar: [
          "Yönetio es un servicio de software para la administración de comunidades y edificios: seguimiento de cuotas, incidencias y reclamaciones, avisos, eventos, visitantes y rondas de seguridad en un solo lugar.",
          "Yönetio no administra el inmueble: las decisiones y los servicios corresponden a **la administración de la comunidad**; Yönetio es la herramienta que facilita ese trabajo.",
        ],
      },
      {
        baslik: "2. Cuentas",
        paragraflar: [
          "Las cuentas las crea la administración de la comunidad; no existe un formulario de registro público.",
          "Usted es responsable de la seguridad de su cuenta. No comparta su contraseña y comunique cualquier anomalía a la administración.",
          "Solo puede usar la cuenta dentro de los permisos que se le hayan concedido.",
        ],
      },
      {
        baslik: "3. Pagos y cuotas",
        paragraflar: [
          "Las cuotas, recargos e importes que se muestran en la aplicación son el precio de **servicios del mundo real consumidos fuera de la aplicación** y fijados por la administración (administración, limpieza, seguridad, mantenimiento, gastos comunes).",
          "Por ello **no se utilizan compras dentro de la aplicación**; el pago se realiza por el método de cobro propio de la comunidad.",
          "Yönetio no fija ni cobra estos importes ni percibe parte alguna; solo mantiene el registro. Las reclamaciones sobre importes se dirigen a la administración.",
        ],
      },
      {
        baslik: "4. Usos no permitidos",
        paragraflar: [
          "Está prohibido usar la cuenta de otra persona, intentar acceder a datos fuera de sus permisos o enviar peticiones automatizadas que sobrecarguen el servicio.",
          "El contenido que suba no puede incluir insultos, amenazas, discriminación ni material ilícito. No puede difundir datos personales de terceros sin su permiso.",
          "En caso de incumplimiento, la administración puede suspender su cuenta.",
        ],
      },
      {
        baslik: "5. Contenido y responsabilidad",
        paragraflar: [
          "El usuario que introduce el contenido (avisos, incidencias, fotos) es responsable de su exactitud.",
          "Las traducciones automáticas son informativas y el texto vinculante es siempre el original; todo contenido traducido lleva esta nota en la aplicación.",
          "Yönetio no garantiza un funcionamiento ininterrumpido y sin errores; aplica un esfuerzo razonable y corrige los problemas conocidos.",
        ],
      },
      {
        baslik: "6. Cambios en el servicio",
        paragraflar: [
          "Las funciones pueden cambiar, añadirse o retirarse con el tiempo. Los cambios relevantes se anuncian dentro de la aplicación.",
          "Pueden producirse interrupciones breves por mantenimiento.",
        ],
      },
      {
        baslik: "7. Finalización de la cuenta",
        paragraflar: [
          "**Puede eliminar su cuenta en cualquier momento desde la aplicación:** Ajustes → Eliminar mi cuenta.",
          "Los registros de cuotas, pagos y auditoría que la ley nos obliga a conservar permanecen almacenados de forma anónima, sin vínculo con su identidad. Consulte la Política de privacidad.",
          "Si abandona la comunidad, la administración puede cerrar su cuenta.",
        ],
      },
      {
        baslik: "8. Ley aplicable y contacto",
        paragraflar: [
          "Estas condiciones se rigen por la legislación de la República de Türkiye.",
          "Contacto: **destek@yonetiyor.com**",
        ],
      },
    ],
  },
};
