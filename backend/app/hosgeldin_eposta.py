"""(P250 §3) Hoş geldiniz e-postası — ROLE GÖRE içerik, 7 dil, HTML + düz metin.

Her rol farklı modülleri kullanır; e-posta kişinin KENDİ yapabildiklerini
sayar. Ortak: mağaza bağlantıları ve "İstek ve önerileriniz için
destek@yonetiyor.com" satırı. Yönetici e-postası ayrıca web paneli
adresini ve (yeni tesis açtıysa) Tesis ID'sini taşır.

Saf fonksiyon: DB/ağ/saat yok. Kabuk `eposta_kabugu.py`de.
"""
from __future__ import annotations

from . import eposta_kabugu as K

DESTEK_EPOSTA = "destek@yonetiyor.com"

#: rol -> içerik grubu
ROL_GRUBU = {
    "resident": "sakin",
    "security": "guvenlik",
    "guvenlik_amiri": "guvenlik",
    "tesis_gorevlisi": "gorevli",
    "yonetici": "yonetici",
    "admin": "yonetici",
    "denetci": "denetci",
}

_ORTAK = {
    "tr": {
        "konu": "{tesis} — Yönetiyor'a hoş geldiniz",
        "selam": "Merhaba {ad},",
        "giris": "{tesis} hesabınız hazır. Yönetiyor'da sizin için neler var:",
        "uygulama": "Uygulamayı telefonunuza indirin ve kayıt olduğunuz bilgilerle giriş yapın.",
        "web": "Web paneli",
        "kod": "Tesis ID",
        "kod_ipucu": "Sitenizdeki kişiler kayıt olurken bu kodu girecek.",
        "destek": "İstek ve önerileriniz için: {destek}",
    },
    "en": {
        "konu": "{tesis} — welcome to Yönetiyor",
        "selam": "Hello {ad},",
        "giris": "Your {tesis} account is ready. Here is what Yönetiyor offers you:",
        "uygulama": "Download the app to your phone and sign in with the details you registered with.",
        "web": "Web panel",
        "kod": "Facility ID",
        "kod_ipucu": "People at your site will enter this code when they register.",
        "destek": "For requests and suggestions: {destek}",
    },
    "de": {
        "konu": "{tesis} — willkommen bei Yönetiyor",
        "selam": "Hallo {ad},",
        "giris": "Ihr Konto bei {tesis} ist bereit. Das bietet Ihnen Yönetiyor:",
        "uygulama": "Laden Sie die App auf Ihr Telefon und melden Sie sich mit Ihren Registrierungsdaten an.",
        "web": "Web-Panel",
        "kod": "Anlagen-ID",
        "kod_ipucu": "Die Personen in Ihrer Anlage geben diesen Code bei der Registrierung ein.",
        "destek": "Für Wünsche und Vorschläge: {destek}",
    },
    "fr": {
        "konu": "{tesis} — bienvenue sur Yönetiyor",
        "selam": "Bonjour {ad},",
        "giris": "Votre compte {tesis} est prêt. Voici ce que Yönetiyor vous propose :",
        "uygulama": "Téléchargez l'application et connectez-vous avec les informations utilisées lors de l'inscription.",
        "web": "Panneau web",
        "kod": "Identifiant de la résidence",
        "kod_ipucu": "Les personnes de votre résidence saisiront ce code lors de leur inscription.",
        "destek": "Pour vos demandes et suggestions : {destek}",
    },
    "es": {
        "konu": "{tesis} — bienvenido a Yönetiyor",
        "selam": "Hola {ad}:",
        "giris": "Su cuenta de {tesis} está lista. Esto es lo que Yönetiyor le ofrece:",
        "uygulama": "Descargue la aplicación en su teléfono e inicie sesión con los datos con los que se registró.",
        "web": "Panel web",
        "kod": "ID del complejo",
        "kod_ipucu": "Las personas de su complejo introducirán este código al registrarse.",
        "destek": "Para solicitudes y sugerencias: {destek}",
    },
    "ar": {
        "konu": "{tesis} — مرحبًا بك في Yönetiyor",
        "selam": "مرحبًا {ad}،",
        "giris": "حسابك في {tesis} جاهز. إليك ما يقدمه لك Yönetiyor:",
        "uygulama": "حمّل التطبيق على هاتفك وسجّل الدخول بالبيانات التي سجلت بها.",
        "web": "لوحة الويب",
        "kod": "معرّف المنشأة",
        "kod_ipucu": "سيُدخل الأشخاص في موقعك هذا الرمز عند التسجيل.",
        "destek": "للطلبات والاقتراحات: {destek}",
    },
    "ru": {
        "konu": "{tesis} — добро пожаловать в Yönetiyor",
        "selam": "Здравствуйте, {ad}!",
        "giris": "Ваш аккаунт в {tesis} готов. Вот что предлагает Yönetiyor:",
        "uygulama": "Установите приложение на телефон и войдите с данными, указанными при регистрации.",
        "web": "Веб-панель",
        "kod": "ID объекта",
        "kod_ipucu": "Жители вашего объекта будут вводить этот код при регистрации.",
        "destek": "Пожелания и предложения: {destek}",
    },
}

#: grup -> dil -> yapabildikleri (kısa maddeler)
_MADDELER: dict[str, dict[str, list[str]]] = {
    "sakin": {
        "tr": ["Aidat borcunuzu, ödemelerinizi ve kişisel ödeme kodunuzu görün.", "Duyuruları ve anketleri takip edin.", "Arıza ve taleplerinizi bildirin, durumunu izleyin.", "Ortak alan rezervasyonu yapın.", "Kapıdaki ziyaretçinizi uygulamadan onaylayın.", "Acil durumda tek dokunuşla yardım çağırın."],
        "en": ["See your dues, payments and personal payment code.", "Follow announcements and polls.", "Report faults and requests and track their status.", "Book common areas.", "Approve visitors at the gate from the app.", "Call for help with one tap in an emergency."],
        "de": ["Sehen Sie Hausgeld, Zahlungen und Ihren persönlichen Zahlungscode.", "Verfolgen Sie Mitteilungen und Umfragen.", "Melden Sie Störungen und Anliegen und verfolgen Sie den Status.", "Reservieren Sie Gemeinschaftsflächen.", "Geben Sie Besucher am Tor in der App frei.", "Rufen Sie im Notfall mit einem Tippen Hilfe."],
        "fr": ["Consultez vos charges, vos paiements et votre code de paiement personnel.", "Suivez les annonces et les sondages.", "Signalez pannes et demandes et suivez leur état.", "Réservez les espaces communs.", "Validez vos visiteurs à l'entrée depuis l'application.", "Appelez à l'aide d'un geste en cas d'urgence."],
        "es": ["Consulte sus cuotas, pagos y su código de pago personal.", "Siga los anuncios y las encuestas.", "Comunique averías y solicitudes y siga su estado.", "Reserve las zonas comunes.", "Apruebe a sus visitas en la entrada desde la app.", "Pida ayuda con un toque en una emergencia."],
        "ar": ["اطّلع على رسومك ومدفوعاتك ورمز الدفع الشخصي.", "تابع الإعلانات والاستطلاعات.", "أبلغ عن الأعطال والطلبات وتابع حالتها.", "احجز المرافق المشتركة.", "وافق على زوارك عند البوابة من التطبيق.", "اطلب المساعدة بلمسة واحدة في حالات الطوارئ."],
        "ru": ["Смотрите взносы, платежи и личный платёжный код.", "Следите за объявлениями и опросами.", "Сообщайте о неисправностях и заявках и следите за статусом.", "Бронируйте общие зоны.", "Подтверждайте посетителей у входа в приложении.", "Вызывайте помощь одним касанием в экстренной ситуации."],
    },
    "guvenlik": {
        "tr": ["Ziyaretçi ve araç girişlerini kaydedin, daireye onay sorun.", "Devriye turlarını kontrol noktalarında okutarak yapın.", "Vardiyanızı ve görevlerinizi görün.", "Acil durum çağrılarını anında alın ve takip edin.", "Kargoları kaydedin, sahibine bildirin.", "Gerektiğinde daireye sesli mesaj bırakın."],
        "en": ["Log visitors and vehicles and ask the unit for approval.", "Do patrols by scanning checkpoints.", "See your shifts and tasks.", "Receive and follow emergency calls instantly.", "Log parcels and notify their owners.", "Leave a voice message for a unit when needed."],
        "de": ["Erfassen Sie Besucher und Fahrzeuge und holen Sie die Freigabe der Wohnung ein.", "Machen Sie Rundgänge durch Scannen der Kontrollpunkte.", "Sehen Sie Ihre Schichten und Aufgaben.", "Erhalten und verfolgen Sie Notrufe sofort.", "Erfassen Sie Pakete und benachrichtigen Sie die Empfänger.", "Hinterlassen Sie bei Bedarf eine Sprachnachricht für eine Wohnung."],
        "fr": ["Enregistrez visiteurs et véhicules et demandez l'accord du logement.", "Faites les rondes en scannant les points de contrôle.", "Consultez vos gardes et vos tâches.", "Recevez et suivez les appels d'urgence instantanément.", "Enregistrez les colis et prévenez leurs destinataires.", "Laissez un message vocal à un logement si nécessaire."],
        "es": ["Registre visitas y vehículos y pida la aprobación de la vivienda.", "Haga las rondas escaneando los puntos de control.", "Consulte sus turnos y tareas.", "Reciba y siga las llamadas de emergencia al instante.", "Registre paquetes y avise a sus destinatarios.", "Deje un mensaje de voz a una vivienda cuando sea necesario."],
        "ar": ["سجّل الزوار والمركبات واطلب موافقة الوحدة.", "نفّذ جولات الحراسة بمسح نقاط التفتيش.", "اطّلع على مناوباتك ومهامك.", "استقبل نداءات الطوارئ وتابعها فورًا.", "سجّل الطرود وأبلغ أصحابها.", "اترك رسالة صوتية للوحدة عند الحاجة."],
        "ru": ["Регистрируйте посетителей и транспорт и запрашивайте подтверждение квартиры.", "Совершайте обходы, сканируя контрольные точки.", "Смотрите свои смены и задачи.", "Мгновенно получайте и отслеживайте экстренные вызовы.", "Регистрируйте посылки и уведомляйте получателей.", "При необходимости оставляйте квартире голосовое сообщение."],
    },
    "gorevli": {
        "tr": ["Size atanan görevleri ve iş emirlerini görün, fotoğrafla tamamlayın.", "Sakinlerin arıza ve taleplerini takip edin.", "Bakım planını ve hatırlatmaları izleyin.", "Sayaç okumalarını girin.", "Vardiyanızı ve mesainizi görün."],
        "en": ["See the tasks and work orders assigned to you and complete them with a photo.", "Follow residents' faults and requests.", "Track the maintenance plan and reminders.", "Enter meter readings.", "See your shifts and working hours."],
        "de": ["Sehen Sie Ihnen zugewiesene Aufgaben und Arbeitsaufträge und schließen Sie sie mit Foto ab.", "Verfolgen Sie Störungen und Anliegen der Bewohner.", "Behalten Sie Wartungsplan und Erinnerungen im Blick.", "Erfassen Sie Zählerstände.", "Sehen Sie Ihre Schichten und Arbeitszeiten."],
        "fr": ["Consultez les tâches et ordres de travail qui vous sont attribués et clôturez-les avec une photo.", "Suivez les pannes et demandes des résidents.", "Suivez le plan de maintenance et les rappels.", "Saisissez les relevés de compteurs.", "Consultez vos gardes et vos heures."],
        "es": ["Vea las tareas y órdenes de trabajo asignadas y complételas con una foto.", "Siga las averías y solicitudes de los residentes.", "Siga el plan de mantenimiento y los recordatorios.", "Introduzca las lecturas de contadores.", "Consulte sus turnos y horas."],
        "ar": ["اطّلع على المهام وأوامر العمل المسندة إليك وأنجزها بصورة.", "تابع أعطال السكان وطلباتهم.", "تابع خطة الصيانة والتذكيرات.", "أدخل قراءات العدادات.", "اطّلع على مناوباتك وساعات عملك."],
        "ru": ["Смотрите назначенные вам задачи и наряды и закрывайте их с фото.", "Следите за неисправностями и заявками жильцов.", "Следите за планом обслуживания и напоминаниями.", "Вносите показания счётчиков.", "Смотрите свои смены и рабочее время."],
    },
    "yonetici": {
        "tr": ["Kurulum sihirbazıyla bloklarınızı, dairelerinizi ve sakinlerinizi ekleyin; her adımın kısa videosu var.", "Aidat planı, tahsilat, banka eşleştirme ve gider takibi.", "Duyuru, anket ve SMS/e-posta ile sakinlerinize ulaşın.", "Personel, vardiya, devriye ve görevleri yönetin.", "Otomatik borç yazma ve ödeme hatırlatmalarını açın.", "Raporlar ve şeffaflık panosu."],
        "en": ["Add your blocks, units and residents with the setup wizard; each step has a short video.", "Dues plans, collections, bank matching and expense tracking.", "Reach residents through announcements, polls and SMS/email.", "Manage staff, shifts, patrols and tasks.", "Turn on automatic dues and payment reminders.", "Reports and the transparency board."],
        "de": ["Legen Sie Gebäude, Wohnungen und Bewohner mit dem Einrichtungsassistenten an; zu jedem Schritt gibt es ein kurzes Video.", "Hausgeldpläne, Inkasso, Bankabgleich und Ausgaben.", "Erreichen Sie Bewohner mit Mitteilungen, Umfragen und SMS/E-Mail.", "Verwalten Sie Personal, Schichten, Rundgänge und Aufgaben.", "Aktivieren Sie automatische Sollstellungen und Zahlungserinnerungen.", "Berichte und Transparenztafel."],
        "fr": ["Ajoutez bâtiments, logements et résidents avec l'assistant d'installation ; chaque étape a une courte vidéo.", "Plans de charges, encaissements, rapprochement bancaire et suivi des dépenses.", "Touchez les résidents par annonces, sondages et SMS/e-mail.", "Gérez le personnel, les gardes, les rondes et les tâches.", "Activez les appels de charges et rappels de paiement automatiques.", "Rapports et tableau de transparence."],
        "es": ["Añada bloques, viviendas y residentes con el asistente de configuración; cada paso tiene un vídeo corto.", "Planes de cuotas, cobros, conciliación bancaria y gastos.", "Llegue a los residentes con anuncios, encuestas y SMS/correo.", "Gestione personal, turnos, rondas y tareas.", "Active los cargos automáticos y los recordatorios de pago.", "Informes y panel de transparencia."],
        "ar": ["أضف المباني والوحدات والسكان عبر معالج الإعداد؛ لكل خطوة فيديو قصير.", "خطط الرسوم والتحصيل ومطابقة البنك وتتبع المصروفات.", "تواصل مع السكان عبر الإعلانات والاستطلاعات والرسائل والبريد.", "أدر الموظفين والمناوبات والجولات والمهام.", "فعّل تسجيل الرسوم التلقائي وتذكيرات الدفع.", "التقارير ولوحة الشفافية."],
        "ru": ["Добавьте корпуса, квартиры и жильцов с помощью мастера настройки; к каждому шагу есть короткое видео.", "Планы взносов, сборы, сверка с банком и учёт расходов.", "Связывайтесь с жильцами через объявления, опросы и SMS/e-mail.", "Управляйте персоналом, сменами, обходами и задачами.", "Включите автоматические начисления и напоминания об оплате.", "Отчёты и панель прозрачности."],
    },
    "denetci": {
        "tr": ["Finans kayıtlarını, tahsilatları ve giderleri inceleyin.", "Raporları görüntüleyin ve dışa aktarın.", "Karar defterini ve belgeleri görün."],
        "en": ["Review financial records, collections and expenses.", "View and export reports.", "See the decision book and documents."],
        "de": ["Prüfen Sie Finanzbuchungen, Einnahmen und Ausgaben.", "Sehen und exportieren Sie Berichte.", "Sehen Sie das Beschlussbuch und Dokumente."],
        "fr": ["Examinez les écritures financières, les encaissements et les dépenses.", "Consultez et exportez les rapports.", "Consultez le registre des décisions et les documents."],
        "es": ["Revise los registros financieros, los cobros y los gastos.", "Consulte y exporte los informes.", "Consulte el libro de actas y los documentos."],
        "ar": ["راجع السجلات المالية والتحصيلات والمصروفات.", "اعرض التقارير وصدّرها.", "اطّلع على سجل القرارات والمستندات."],
        "ru": ["Проверяйте финансовые записи, сборы и расходы.", "Просматривайте и выгружайте отчёты.", "Смотрите книгу решений и документы."],
    },
}


def rol_grubu(rol: str) -> str:
    return ROL_GRUBU.get(rol, "sakin")


def maddeler(rol: str, dil: str) -> list[str]:
    return _MADDELER[rol_grubu(rol)][K.dil_coz(dil)]


def hosgeldin_eposta(
    *,
    dil: str | None,
    rol: str,
    tesis_ad: str,
    ad: str,
    yil: int,
    tesis_kodu: str | None = None,
    web_url: str | None = None,
) -> tuple[str, str, str]:
    """(konu, düz metin, html). `web_url` ve `tesis_kodu` yalnız yönetim
    rollerinde gösterilir (sakine web paneli adresi göstermek P179'dan beri
    yanlış yönlendirme: sakin web'e giremez)."""
    d = K.dil_coz(dil)
    m = _ORTAK[d]
    h = K.Hizalama(d)
    yonetim = rol_grubu(rol) in ("yonetici", "denetci")
    liste = maddeler(rol, d)
    konu = m["konu"].format(tesis=tesis_ad)
    destek = m["destek"].format(destek=DESTEK_EPOSTA)

    govde = (
        K.paragraf(h, K.e(m["selam"].format(ad=ad)), kalin=True, boyut=16)
        + K.paragraf(h, K.e(m["giris"].format(tesis=tesis_ad)))
        + K.madde_listesi(h, liste)
    )
    if yonetim and tesis_kodu:
        govde += K.kod_cipi(m["kod"], tesis_kodu, m["kod_ipucu"])
    if yonetim and web_url:
        govde += K.bilgi_tablosu(h, [(m["web"], web_url)])
    govde += (
        K.paragraf(h, K.e(m["uygulama"]), boyut=14)
        + K.magaza_butonlari()
        + K.paragraf(h, K.e(destek), boyut=14)
    )
    html_govde = K.kabuk(dil=d, konu=konu, govde_html=govde, yil=yil)

    satirlar = [m["selam"].format(ad=ad), "", m["giris"].format(tesis=tesis_ad), ""]
    satirlar += [f"- {x}" for x in liste]
    satirlar.append("")
    if yonetim and tesis_kodu:
        satirlar.append(f"{m['kod']}: {tesis_kodu}")
    if yonetim and web_url:
        satirlar.append(f"{m['web']}: {web_url}")
    satirlar.append(m["uygulama"])
    if K.settings.play_store_url:
        satirlar.append(f"Google Play: {K.settings.play_store_url}")
    if K.settings.app_store_url:
        satirlar.append(f"App Store: {K.settings.app_store_url}")
    satirlar += ["", destek, "", K.altbilgi_metni(d, yil)]
    return konu, "\n".join(satirlar), html_govde
