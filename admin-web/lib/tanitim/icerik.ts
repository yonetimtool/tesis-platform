import type { Dil } from "@/lib/i18n/diller";

// (P127) TANITIM SITESI ICERIGI — 7 dil.
//
// NEDEN SOZLUKTE DEGIL (hukuki belgelerle ayni gerekce): `lib/i18n/sozluk`
// ARAYUZ dizgeleridir (dugme, etiket, hata). Burasi PAZARLAMA METNIDIR:
// baslikli, paragrafli ve urunun sesini tasiyan bir icerik. Sozluge
// koymak, 40 satirlik degeri onerilerini dugme etiketleriyle ayni dosyaya
// doldurmak ve `SozlukAnahtari` tipini okunmaz kilmak olurdu.
//
// IKI AYRI DEGER ONERISI — gorevin acik sarti: site yoneticisi ile sakin
// ayni sayfaya bakar ama AYNI SEYI aramaz. Yonetici "isimi kolaylastirir
// mi", sakin "hakkimi gorebilir miyim" diye bakar. Tek bir genel cumle
// ("her sey tek yerde") ikisine de bir sey soylemezdi.
//
// SOMUT OL, SIFAT KULLANMA: "guclu", "modern", "yenilikci" gibi sozcukler
// olcusuzdur ve her rakip ayni seyi yazar. Her madde URUNDE GERCEKTEN
// OLAN bir seyi anlatir — yoksa satir yazilmaz.
export interface TanitimOzellik {
  baslik: string;
  metin: string;
}

export interface TanitimIcerik {
  /** <title> ve OG basligi. */
  metaBaslik: string;
  metaAciklama: string;

  yoneticiBaslik: string;
  yoneticiAlt: string;
  sakinBaslik: string;
  sakinAlt: string;

  ozelliklerBaslik: string;
  ozellikler: TanitimOzellik[];

  hakkimizdaBaslik: string;
  hakkimizdaParagraflar: string[];

  iletisimBaslik: string;
  iletisimMetin: string;
  iletisimEposta: string;

  girisBaslik: string;
  girisYonetim: string;
  girisTesis: string;

  uygulamaBaslik: string;
  /** Magaza baglantilari YOKKEN gosterilen durust cumle. */
  uygulamaYakinda: string;

  gizlilik: string;
  kosullar: string;
}

export type TanitimSeti = Record<Dil, TanitimIcerik>;

export const TANITIM: TanitimSeti = {
  tr: {
    metaBaslik: "Yönetiyor — site ve tesis yönetim platformu",
    metaAciklama:
      "Aidat takibi, arıza ve talep yönetimi, güvenlik turu, ziyaretçi ve kargo kaydı, duyuru ve şeffaflık panosu. Yönetim web'de, saha mobilde.",
    yoneticiBaslik: "Sitenizin işini tek yerden yürütün",
    yoneticiAlt:
      "Tahakkuk ve tahsilat, gelir-gider defteri, görev atama, güvenlik turu planı ve raporlar. Denetçiye salt-okuma erişimi verirsiniz; kayıtlarınız değişmeden incelenir.",
    sakinBaslik: "Borcunuzu, talebinizi ve sitenizi cebinizden görün",
    sakinAlt:
      "Aidat borcunuz ve ödeme geçmişiniz, açtığınız talebin durumu, duyurular, site kuralları ve ortak alan rezervasyonu — hepsi mobil uygulamada.",

    ozelliklerBaslik: "Neler var?",
    ozellikler: [
      {
        baslik: "Aidat ve tahsilat",
        metin:
          "Toplu tahakkuk, gecikme faizi ayarı, kasa ve banka hareketleri, tahakkuk-tahsilat karşılaştırması.",
      },
      {
        baslik: "Talep ve iş emri",
        metin:
          "Sakin talebi açar, yönetim iş emrine çevirir, saha fotoğraf kanıtıyla kapatır — tüm adımlar kayıtlı.",
      },
      {
        baslik: "Güvenlik turu",
        metin:
          "NFC etiketli kontrol noktaları, vardiya planı, kaçırılan tur uyarısı ve tur raporu.",
      },
      {
        baslik: "Ziyaretçi ve kargo",
        metin:
          "Kapıda daire numarasıyla kayıt; sakinin kendi kayıtları kendisine açık, yönetime varsayılan kapalı (KVKK).",
      },
      {
        baslik: "Kameralar",
        metin:
          "Rol süzgeçli kamera listesi, ızgarada canlı kare ve tarayıcıda oynatma; plaka okuma (ANPR) entegrasyonu.",
      },
      {
        baslik: "Şeffaflık panosu",
        metin:
          "Aylık gelir-gider özeti, kişi verisi olmadan yayımlanır; sakin sitenin parasının nereye gittiğini görür.",
      },
    ],

    hakkimizdaBaslik: "Hakkımızda",
    hakkimizdaParagraflar: [
      "Yönetiyor, site ve tesis yönetiminin günlük işini yazılıma taşımak için kuruldu: aidatın tahsili, arızanın takibi, turun kaydı ve sakinle iletişim.",
      "Ürün iki yüzeyden çalışır: masabaşı işi (tahakkuk, rapor, tanımlar) web'de, saha işi (tur, görev, kapı) mobil uygulamada. Her tesisin verisi kendi alanında durur ve roller yalnız işlerinin gerektirdiği kadarını görür.",
    ],

    iletisimBaslik: "İletişim",
    iletisimMetin:
      "Demo talebi, fiyat ve kurulum soruları için yazın; aynı gün dönüyoruz.",
    iletisimEposta: "iletisim@yonetiyor.com",

    girisBaslik: "Giriş",
    girisYonetim: "Platform yönetimi",
    girisTesis: "Site yöneticisi ve denetçi girişi",

    uygulamaBaslik: "Mobil uygulama",
    uygulamaYakinda:
      "Sakin, güvenlik ve tesis görevlisi hesapları mobil uygulamada çalışır. Uygulama mağazalarda yayına hazırlanıyor.",

    gizlilik: "Gizlilik politikası",
    kosullar: "Kullanım koşulları",
  },

  en: {
    metaBaslik: "Yönetiyor — property and facility management platform",
    metaAciklama:
      "Dues tracking, maintenance requests, security patrols, visitor and parcel logs, announcements and a transparency board. Management on the web, field work on mobile.",
    yoneticiBaslik: "Run your building from one place",
    yoneticiAlt:
      "Assessments and collections, income-expense ledger, task assignment, patrol plans and reports. Give your auditor read-only access; records are reviewed without being changed.",
    sakinBaslik: "See your dues, your requests and your building from your phone",
    sakinAlt:
      "Your balance and payment history, the status of the request you opened, announcements, house rules and common-area booking — all in the mobile app.",

    ozelliklerBaslik: "What's inside",
    ozellikler: [
      {
        baslik: "Dues and collections",
        metin:
          "Bulk assessments, late-fee settings, cash and bank movements, assessment-versus-collection comparison.",
      },
      {
        baslik: "Requests and work orders",
        metin:
          "A resident opens a request, management turns it into a work order, the field closes it with photo evidence — every step recorded.",
      },
      {
        baslik: "Security patrols",
        metin:
          "NFC checkpoints, shift plans, missed-patrol alerts and patrol reports.",
      },
      {
        baslik: "Visitors and parcels",
        metin:
          "Logged at the gate by unit number; a resident sees their own records, management is closed by default (privacy law).",
      },
      {
        baslik: "Cameras",
        metin:
          "Role-filtered camera list, live tiles in the grid and playback in the browser; licence-plate (ANPR) integration.",
      },
      {
        baslik: "Transparency board",
        metin:
          "A monthly income-expense summary published without personal data; residents see where the building's money goes.",
      },
    ],

    hakkimizdaBaslik: "About us",
    hakkimizdaParagraflar: [
      "Yönetiyor was built to move the daily work of property management into software: collecting dues, tracking faults, recording patrols and talking to residents.",
      "The product works from two surfaces: desk work (assessments, reports, definitions) on the web, field work (patrols, tasks, the gate) in the mobile app. Each site's data stays in its own space and each role sees only what its job requires.",
    ],

    iletisimBaslik: "Contact",
    iletisimMetin:
      "Write to us for a demo, pricing or onboarding questions; we reply the same day.",
    iletisimEposta: "iletisim@yonetiyor.com",

    girisBaslik: "Sign in",
    girisYonetim: "Platform administration",
    girisTesis: "Site manager and auditor sign-in",

    uygulamaBaslik: "Mobile app",
    uygulamaYakinda:
      "Resident, security and facility-staff accounts work in the mobile app. The app is being prepared for the stores.",

    gizlilik: "Privacy policy",
    kosullar: "Terms of use",
  },

  ar: {
    metaBaslik: "Yönetiyor — منصة إدارة المجمعات والمنشآت",
    metaAciklama:
      "متابعة الرسوم، طلبات الصيانة، جولات الأمن، سجلات الزوار والطرود، الإعلانات ولوحة الشفافية. الإدارة على الويب والعمل الميداني على الهاتف.",
    yoneticiBaslik: "أدر مجمعك من مكان واحد",
    yoneticiAlt:
      "الاستحقاقات والتحصيل، دفتر الإيرادات والمصروفات، إسناد المهام، خطط الجولات والتقارير. امنح المدقق صلاحية قراءة فقط؛ تُراجَع السجلات دون تغييرها.",
    sakinBaslik: "اطّلع على رسومك وطلباتك ومجمعك من هاتفك",
    sakinAlt:
      "رصيدك وسجل مدفوعاتك، وحالة الطلب الذي فتحته، والإعلانات وقواعد المجمع وحجز المساحات المشتركة — كلها في التطبيق.",

    ozelliklerBaslik: "ماذا يوجد؟",
    ozellikler: [
      {
        baslik: "الرسوم والتحصيل",
        metin:
          "استحقاقات جماعية، إعداد فائدة التأخير، حركات الصندوق والبنك، ومقارنة الاستحقاق بالتحصيل.",
      },
      {
        baslik: "الطلبات وأوامر العمل",
        metin:
          "يفتح الساكن طلبًا، وتحوّله الإدارة إلى أمر عمل، ويغلقه الميدان بإثبات مصوّر — وكل خطوة مسجّلة.",
      },
      {
        baslik: "جولات الأمن",
        metin: "نقاط تفتيش NFC، وخطط الورديات، وتنبيهات الجولات الفائتة، وتقارير الجولات.",
      },
      {
        baslik: "الزوار والطرود",
        metin:
          "تُسجَّل عند البوابة برقم الوحدة؛ يرى الساكن سجلاته الخاصة، والإدارة مغلقة افتراضيًا (حماية البيانات).",
      },
      {
        baslik: "الكاميرات",
        metin:
          "قائمة كاميرات مُرشَّحة حسب الدور، لقطات حية في الشبكة وتشغيل داخل المتصفح؛ وتكامل قراءة اللوحات (ANPR).",
      },
      {
        baslik: "لوحة الشفافية",
        metin:
          "ملخّص شهري للإيرادات والمصروفات يُنشر دون بيانات شخصية؛ فيرى السكان أين تُصرف أموال المجمع.",
      },
    ],

    hakkimizdaBaslik: "من نحن",
    hakkimizdaParagraflar: [
      "أُنشئت Yönetiyor لنقل العمل اليومي لإدارة المجمعات إلى البرمجيات: تحصيل الرسوم، متابعة الأعطال، تسجيل الجولات، والتواصل مع السكان.",
      "يعمل المنتج من واجهتين: العمل المكتبي (الاستحقاقات، التقارير، التعريفات) على الويب، والعمل الميداني (الجولات، المهام، البوابة) في التطبيق. تبقى بيانات كل موقع في مساحته، ويرى كل دور ما يحتاجه عمله فقط.",
    ],

    iletisimBaslik: "اتصل بنا",
    iletisimMetin: "اكتب إلينا لطلب عرض توضيحي أو للأسعار أو أسئلة التركيب؛ نردّ في اليوم نفسه.",
    iletisimEposta: "iletisim@yonetiyor.com",

    girisBaslik: "تسجيل الدخول",
    girisYonetim: "إدارة المنصة",
    girisTesis: "دخول مدير الموقع والمدقق",

    uygulamaBaslik: "تطبيق الهاتف",
    uygulamaYakinda:
      "تعمل حسابات الساكن والأمن وموظف المنشأة في تطبيق الهاتف. ويجري تجهيز التطبيق للنشر في المتاجر.",

    gizlilik: "سياسة الخصوصية",
    kosullar: "شروط الاستخدام",
  },

  ru: {
    metaBaslik: "Yönetiyor — платформа управления жилыми комплексами",
    metaAciklama:
      "Учёт взносов, заявки на ремонт, обходы охраны, журналы посетителей и посылок, объявления и доска прозрачности. Управление в вебе, работа на объекте — в приложении.",
    yoneticiBaslik: "Ведите дела дома из одного места",
    yoneticiAlt:
      "Начисления и сборы, книга доходов и расходов, назначение задач, планы обходов и отчёты. Аудитору выдаётся доступ только на чтение — записи изучаются без изменений.",
    sakinBaslik: "Смотрите начисления, заявки и жизнь дома с телефона",
    sakinAlt:
      "Ваш баланс и история платежей, статус вашей заявки, объявления, правила дома и бронирование общих зон — всё в мобильном приложении.",

    ozelliklerBaslik: "Что внутри",
    ozellikler: [
      {
        baslik: "Взносы и сборы",
        metin:
          "Массовые начисления, настройка пени, движения кассы и банка, сравнение начислено-собрано.",
      },
      {
        baslik: "Заявки и наряды",
        metin:
          "Житель открывает заявку, управление превращает её в наряд, на объекте её закрывают с фотодоказательством — каждый шаг записан.",
      },
      {
        baslik: "Обходы охраны",
        metin: "Контрольные точки NFC, графики смен, оповещения о пропущенных обходах и отчёты.",
      },
      {
        baslik: "Посетители и посылки",
        metin:
          "Регистрация на входе по номеру квартиры; житель видит свои записи, управлению по умолчанию закрыто (защита данных).",
      },
      {
        baslik: "Камеры",
        metin:
          "Список камер с фильтром по ролям, живые плитки в сетке и воспроизведение в браузере; интеграция распознавания номеров (ANPR).",
      },
      {
        baslik: "Доска прозрачности",
        metin:
          "Ежемесячная сводка доходов и расходов публикуется без персональных данных; жители видят, куда уходят деньги дома.",
      },
    ],

    hakkimizdaBaslik: "О нас",
    hakkimizdaParagraflar: [
      "Yönetiyor создан, чтобы перенести ежедневную работу управляющих в программу: сбор взносов, отслеживание неисправностей, запись обходов и общение с жителями.",
      "Продукт работает с двух поверхностей: кабинетная работа (начисления, отчёты, справочники) — в вебе, работа на объекте (обходы, задачи, вход) — в приложении. Данные каждого объекта остаются в своём пространстве, и каждая роль видит лишь необходимое.",
    ],

    iletisimBaslik: "Контакты",
    iletisimMetin: "Напишите нам о демо, ценах или подключении; отвечаем в тот же день.",
    iletisimEposta: "iletisim@yonetiyor.com",

    girisBaslik: "Вход",
    girisYonetim: "Администрирование платформы",
    girisTesis: "Вход управляющего и аудитора",

    uygulamaBaslik: "Мобильное приложение",
    uygulamaYakinda:
      "Учётные записи жителя, охраны и технического персонала работают в мобильном приложении. Приложение готовится к публикации в магазинах.",

    gizlilik: "Политика конфиденциальности",
    kosullar: "Условия использования",
  },

  de: {
    metaBaslik: "Yönetiyor — Plattform für Immobilien- und Objektverwaltung",
    metaAciklama:
      "Hausgeldverwaltung, Störungsmeldungen, Sicherheitsrundgänge, Besucher- und Paketprotokolle, Aushänge und Transparenztafel. Verwaltung im Web, Außendienst mobil.",
    yoneticiBaslik: "Führen Sie Ihre Anlage von einem Ort aus",
    yoneticiAlt:
      "Sollstellungen und Zahlungseingänge, Einnahmen-Ausgaben-Buch, Aufgabenvergabe, Rundgangspläne und Berichte. Dem Rechnungsprüfer geben Sie Lesezugriff — Belege werden geprüft, ohne verändert zu werden.",
    sakinBaslik: "Hausgeld, Anliegen und Anlage — auf dem Telefon",
    sakinAlt:
      "Ihr Saldo und Zahlungsverlauf, der Stand Ihres Anliegens, Aushänge, Hausordnung und die Buchung von Gemeinschaftsflächen — alles in der App.",

    ozelliklerBaslik: "Was drin ist",
    ozellikler: [
      {
        baslik: "Hausgeld und Zahlungen",
        metin:
          "Sammel-Sollstellungen, Verzugszinseinstellung, Kassen- und Bankbewegungen, Soll-Ist-Vergleich.",
      },
      {
        baslik: "Anliegen und Aufträge",
        metin:
          "Bewohner meldet, Verwaltung macht einen Auftrag daraus, der Außendienst schließt ihn mit Fotonachweis — jeder Schritt protokolliert.",
      },
      {
        baslik: "Sicherheitsrundgänge",
        metin: "NFC-Kontrollpunkte, Schichtpläne, Warnungen bei verpassten Rundgängen und Berichte.",
      },
      {
        baslik: "Besucher und Pakete",
        metin:
          "Erfassung am Eingang über die Einheitennummer; Bewohner sehen ihre eigenen Einträge, die Verwaltung standardmäßig nicht (Datenschutz).",
      },
      {
        baslik: "Kameras",
        metin:
          "Rollengefilterte Kameraliste, Livekacheln im Raster und Wiedergabe im Browser; Kennzeichenerkennung (ANPR).",
      },
      {
        baslik: "Transparenztafel",
        metin:
          "Monatliche Einnahmen-Ausgaben-Übersicht ohne personenbezogene Daten; Bewohner sehen, wohin das Geld fließt.",
      },
    ],

    hakkimizdaBaslik: "Über uns",
    hakkimizdaParagraflar: [
      "Yönetiyor entstand, um die tägliche Arbeit der Verwaltung in Software zu überführen: Hausgeld einziehen, Störungen verfolgen, Rundgänge dokumentieren und mit Bewohnern sprechen.",
      "Das Produkt arbeitet auf zwei Oberflächen: Schreibtischarbeit (Sollstellungen, Berichte, Stammdaten) im Web, Außendienst (Rundgänge, Aufgaben, Eingang) in der App. Die Daten jeder Anlage bleiben in ihrem eigenen Bereich, und jede Rolle sieht nur das Nötige.",
    ],

    iletisimBaslik: "Kontakt",
    iletisimMetin:
      "Schreiben Sie uns wegen einer Demo, Preisen oder der Einrichtung; wir antworten am selben Tag.",
    iletisimEposta: "iletisim@yonetiyor.com",

    girisBaslik: "Anmeldung",
    girisYonetim: "Plattformverwaltung",
    girisTesis: "Anmeldung für Verwalter und Prüfer",

    uygulamaBaslik: "Mobile App",
    uygulamaYakinda:
      "Konten für Bewohner, Sicherheit und Objektpersonal laufen in der App. Die App wird für die Stores vorbereitet.",

    gizlilik: "Datenschutzerklärung",
    kosullar: "Nutzungsbedingungen",
  },

  fr: {
    metaBaslik: "Yönetiyor — plateforme de gestion immobilière",
    metaAciklama:
      "Suivi des charges, demandes d'intervention, rondes de sécurité, registres des visiteurs et colis, annonces et tableau de transparence. Gestion sur le web, terrain sur mobile.",
    yoneticiBaslik: "Gérez votre résidence depuis un seul endroit",
    yoneticiAlt:
      "Appels de charges et encaissements, livre des recettes et dépenses, affectation des tâches, plans de ronde et rapports. L'auditeur reçoit un accès en lecture seule : les écritures sont examinées sans être modifiées.",
    sakinBaslik: "Vos charges, vos demandes et votre résidence depuis le téléphone",
    sakinAlt:
      "Votre solde et l'historique des paiements, l'état de votre demande, les annonces, le règlement intérieur et la réservation des espaces communs — dans l'application.",

    ozelliklerBaslik: "Ce que vous trouverez",
    ozellikler: [
      {
        baslik: "Charges et encaissements",
        metin:
          "Appels de charges en masse, paramétrage des pénalités, mouvements de caisse et de banque, comparaison appelé/encaissé.",
      },
      {
        baslik: "Demandes et ordres de travail",
        metin:
          "Le résident ouvre une demande, la gestion la transforme en ordre de travail, le terrain la clôture avec une preuve photo — chaque étape enregistrée.",
      },
      {
        baslik: "Rondes de sécurité",
        metin: "Points de contrôle NFC, plannings d'équipe, alertes de ronde manquée et rapports.",
      },
      {
        baslik: "Visiteurs et colis",
        metin:
          "Enregistrés à l'entrée par numéro de lot ; le résident voit ses propres entrées, la gestion est fermée par défaut (protection des données).",
      },
      {
        baslik: "Caméras",
        metin:
          "Liste filtrée par rôle, vignettes en direct dans la grille et lecture dans le navigateur ; intégration de lecture de plaques (ANPR).",
      },
      {
        baslik: "Tableau de transparence",
        metin:
          "Synthèse mensuelle des recettes et dépenses publiée sans données personnelles ; les résidents voient où va l'argent.",
      },
    ],

    hakkimizdaBaslik: "À propos",
    hakkimizdaParagraflar: [
      "Yönetiyor a été créé pour porter le travail quotidien de la gestion immobilière dans un logiciel : encaisser les charges, suivre les pannes, consigner les rondes et parler aux résidents.",
      "Le produit fonctionne depuis deux surfaces : le travail de bureau (appels de charges, rapports, référentiels) sur le web, le terrain (rondes, tâches, entrée) dans l'application. Les données de chaque site restent dans leur espace et chaque rôle ne voit que le nécessaire.",
    ],

    iletisimBaslik: "Contact",
    iletisimMetin:
      "Écrivez-nous pour une démo, les tarifs ou la mise en place ; nous répondons le jour même.",
    iletisimEposta: "iletisim@yonetiyor.com",

    girisBaslik: "Connexion",
    girisYonetim: "Administration de la plateforme",
    girisTesis: "Connexion gestionnaire et auditeur",

    uygulamaBaslik: "Application mobile",
    uygulamaYakinda:
      "Les comptes résident, sécurité et personnel technique fonctionnent dans l'application. Elle est en préparation pour les stores.",

    gizlilik: "Politique de confidentialité",
    kosullar: "Conditions d'utilisation",
  },

  es: {
    metaBaslik: "Yönetiyor — plataforma de gestión de comunidades",
    metaAciklama:
      "Control de cuotas, incidencias, rondas de seguridad, registro de visitas y paquetes, avisos y panel de transparencia. Gestión en la web, trabajo de campo en el móvil.",
    yoneticiBaslik: "Gestione su comunidad desde un solo sitio",
    yoneticiAlt:
      "Derramas y cobros, libro de ingresos y gastos, asignación de tareas, planes de ronda e informes. Al auditor se le da acceso de solo lectura: los registros se revisan sin modificarse.",
    sakinBaslik: "Sus cuotas, sus incidencias y su comunidad desde el móvil",
    sakinAlt:
      "Su saldo e historial de pagos, el estado de su incidencia, los avisos, las normas y la reserva de zonas comunes — todo en la aplicación.",

    ozelliklerBaslik: "Qué incluye",
    ozellikler: [
      {
        baslik: "Cuotas y cobros",
        metin:
          "Derramas masivas, ajuste de intereses de demora, movimientos de caja y banco, comparación entre lo emitido y lo cobrado.",
      },
      {
        baslik: "Incidencias y órdenes de trabajo",
        metin:
          "El vecino abre una incidencia, la administración la convierte en orden de trabajo y el campo la cierra con prueba fotográfica — cada paso queda registrado.",
      },
      {
        baslik: "Rondas de seguridad",
        metin: "Puntos de control NFC, planes de turno, avisos de ronda perdida e informes.",
      },
      {
        baslik: "Visitas y paquetes",
        metin:
          "Se registran en la puerta por número de vivienda; el vecino ve sus propios registros y la administración está cerrada por defecto (protección de datos).",
      },
      {
        baslik: "Cámaras",
        metin:
          "Lista filtrada por rol, mosaicos en vivo en la cuadrícula y reproducción en el navegador; integración de lectura de matrículas (ANPR).",
      },
      {
        baslik: "Panel de transparencia",
        metin:
          "Resumen mensual de ingresos y gastos publicado sin datos personales; los vecinos ven adónde va el dinero.",
      },
    ],

    hakkimizdaBaslik: "Sobre nosotros",
    hakkimizdaParagraflar: [
      "Yönetiyor nació para llevar el trabajo diario de la administración de fincas al software: cobrar las cuotas, seguir las averías, registrar las rondas y hablar con los vecinos.",
      "El producto funciona desde dos superficies: el trabajo de despacho (derramas, informes, maestros) en la web y el de campo (rondas, tareas, portería) en la aplicación. Los datos de cada comunidad permanecen en su espacio y cada rol ve solo lo necesario.",
    ],

    iletisimBaslik: "Contacto",
    iletisimMetin:
      "Escríbanos para una demo, precios o la puesta en marcha; respondemos el mismo día.",
    iletisimEposta: "iletisim@yonetiyor.com",

    girisBaslik: "Acceso",
    girisYonetim: "Administración de la plataforma",
    girisTesis: "Acceso de administrador y auditor",

    uygulamaBaslik: "Aplicación móvil",
    uygulamaYakinda:
      "Las cuentas de vecino, seguridad y personal técnico funcionan en la aplicación. La app se está preparando para las tiendas.",

    gizlilik: "Política de privacidad",
    kosullar: "Condiciones de uso",
  },
};
