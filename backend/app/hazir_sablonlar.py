"""(P250 §8) HAZIR MESAJ ŞABLONLARI — platformun sunduğu kütüphane.

Yönetici bir şablon seçer; metin kendi dilinde forma gelir, isterse
düzenleyip KENDİ şablonu olarak kaydeder (`POST /mesaj-sablonlari`).
Değişkenler gönderim anında kişi başına dolar (`mesajlasma.ETIKETLER`):
{adi_soyadi}, {adres} (daire), {site_adi}, {tarih}, {borc}, {bakiye},
{aidat_tutari}, {odeme_kodu}, {odeme_linki}.

[KÖŞELİ PARANTEZ] = yöneticinin doldurması gereken yer (saat, tarih,
gündem). Süslü parantez etiketi değil: bilinmeyen etiket metinde olduğu
gibi kalır ve gönderilen mesajda "{saat}" görünürdü; köşeli parantez
düzenleme formunda göze çarpar ve "doldurulmadı" diye ayrıca uyarılır.

SMS sürümleri KISA: Türkçe harf (ı, ğ, ş) GSM-7'de olmadığından mesaj
70 karakterlik parçalara bölünür; her şablon en fazla 2 parça hedefler.
Kütüphane koda gömülü (tablo değil): platformun ürün metnidir, sürümle
birlikte çevirileri gözden geçirilir; yöneticinin değiştirdiği metin
zaten kendi `mesaj_sablonu` satırına yazılır.
"""
from __future__ import annotations

KODLAR: tuple[str, ...] = (
    "aidat_hatirlatma", "toplanti_duyurusu", "su_kesintisi",
    "elektrik_kesintisi", "bakim_bildirimi", "bayram_tebrigi",
    "hosgeldiniz", "odeme_kodu",
)

# kod -> dil -> {"ad", "konu", "eposta", "sms"}
_S: dict[str, dict[str, dict[str, str]]] = {
    "aidat_hatirlatma": {
        "tr": {"ad": "Aidat hatırlatma", "konu": "{site_adi} — aidat hatırlatması",
               "eposta": "Sayın {adi_soyadi},\n\n{adres} numaralı dairenizin {borc} TL tutarındaki aidat borcu henüz ödenmemiş görünüyor. Havale açıklamasına ödeme kodunuzu ({odeme_kodu}) yazmanız yeterlidir.\n\nÖdemenizi yaptıysanız bu mesajı dikkate almayın.\n\n{site_adi} Yönetimi",
               "sms": "{site_adi}: {adres} için {borc} TL aidat borcu görünüyor. Ödeme kodu: {odeme_kodu}. Ödediyseniz dikkate almayın."},
        "en": {"ad": "Dues reminder", "konu": "{site_adi} — dues reminder",
               "eposta": "Dear {adi_soyadi},\n\nThe dues of {borc} TL for unit {adres} appear to be unpaid. Please write your payment code ({odeme_kodu}) in the transfer description.\n\nIf you have already paid, please disregard this message.\n\n{site_adi} Management",
               "sms": "{site_adi}: dues of {borc} TL for {adres} appear unpaid. Payment code: {odeme_kodu}. Ignore if paid."},
        "de": {"ad": "Hausgeld-Erinnerung", "konu": "{site_adi} — Erinnerung an das Hausgeld",
               "eposta": "Sehr geehrte/r {adi_soyadi},\n\ndas Hausgeld von {borc} TL für Wohnung {adres} scheint noch offen zu sein. Bitte geben Sie im Verwendungszweck Ihren Zahlungscode ({odeme_kodu}) an.\n\nFalls Sie bereits gezahlt haben, betrachten Sie diese Nachricht als gegenstandslos.\n\nVerwaltung {site_adi}",
               "sms": "{site_adi}: Hausgeld {borc} TL für {adres} offen. Zahlungscode: {odeme_kodu}. Bei Zahlung bitte ignorieren."},
        "fr": {"ad": "Rappel de charges", "konu": "{site_adi} — rappel de charges",
               "eposta": "Bonjour {adi_soyadi},\n\nLes charges de {borc} TL du logement {adres} semblent impayées. Indiquez votre code de paiement ({odeme_kodu}) dans le libellé du virement.\n\nSi vous avez déjà payé, merci de ne pas tenir compte de ce message.\n\nLa gestion de {site_adi}",
               "sms": "{site_adi} : charges de {borc} TL impayées pour {adres}. Code : {odeme_kodu}. Ignorez si payé."},
        "es": {"ad": "Recordatorio de cuota", "konu": "{site_adi} — recordatorio de cuota",
               "eposta": "Estimado/a {adi_soyadi}:\n\nLa cuota de {borc} TL de la vivienda {adres} parece pendiente. Escriba su código de pago ({odeme_kodu}) en el concepto de la transferencia.\n\nSi ya ha pagado, no tenga en cuenta este mensaje.\n\nAdministración de {site_adi}",
               "sms": "{site_adi}: cuota de {borc} TL pendiente en {adres}. Código: {odeme_kodu}. Ignore si ya pagó."},
        "ar": {"ad": "تذكير بالرسوم", "konu": "{site_adi} — تذكير بالرسوم",
               "eposta": "عزيزي {adi_soyadi}،\n\nيبدو أن رسوم الوحدة {adres} بقيمة {borc} TL لم تُدفع بعد. اكتب رمز الدفع ({odeme_kodu}) في وصف التحويل.\n\nإذا كنت قد دفعت فتجاهل هذه الرسالة.\n\nإدارة {site_adi}",
               "sms": "{site_adi}: رسوم {borc} TL غير مدفوعة للوحدة {adres}. الرمز: {odeme_kodu}. تجاهل إن دفعت."},
        "ru": {"ad": "Напоминание о взносе", "konu": "{site_adi} — напоминание о взносе",
               "eposta": "Уважаемый(ая) {adi_soyadi},\n\nвзнос {borc} TL за квартиру {adres}, по-видимому, не оплачен. Укажите платёжный код ({odeme_kodu}) в назначении платежа.\n\nЕсли вы уже оплатили, не обращайте внимания на это письмо.\n\nУправление {site_adi}",
               "sms": "{site_adi}: не оплачен взнос {borc} TL за {adres}. Код: {odeme_kodu}. Если оплатили — игнорируйте."},
    },
    "toplanti_duyurusu": {
        "tr": {"ad": "Toplantı duyurusu", "konu": "{site_adi} — kat malikleri toplantısı",
               "eposta": "Sayın {adi_soyadi},\n\nKat malikleri toplantısı [TARİH] günü saat [SAAT]'te [YER]'de yapılacaktır.\n\nGündem:\n[GÜNDEM]\n\nKatılımınızı rica ederiz.\n\n{site_adi} Yönetimi",
               "sms": "{site_adi}: Kat malikleri toplantısı [TARİH] [SAAT], [YER]. Katılımınızı rica ederiz."},
        "en": {"ad": "Meeting notice", "konu": "{site_adi} — owners' meeting",
               "eposta": "Dear {adi_soyadi},\n\nThe owners' meeting will be held on [DATE] at [TIME] in [PLACE].\n\nAgenda:\n[AGENDA]\n\nWe kindly ask you to attend.\n\n{site_adi} Management",
               "sms": "{site_adi}: Owners' meeting [DATE] [TIME], [PLACE]. Please attend."},
        "de": {"ad": "Versammlungseinladung", "konu": "{site_adi} — Eigentümerversammlung",
               "eposta": "Sehr geehrte/r {adi_soyadi},\n\ndie Eigentümerversammlung findet am [DATUM] um [UHRZEIT] in [ORT] statt.\n\nTagesordnung:\n[TAGESORDNUNG]\n\nWir bitten um Ihre Teilnahme.\n\nVerwaltung {site_adi}",
               "sms": "{site_adi}: Eigentümerversammlung [DATUM] [UHRZEIT], [ORT]. Bitte nehmen Sie teil."},
        "fr": {"ad": "Avis de réunion", "konu": "{site_adi} — assemblée des copropriétaires",
               "eposta": "Bonjour {adi_soyadi},\n\nL'assemblée des copropriétaires aura lieu le [DATE] à [HEURE] à [LIEU].\n\nOrdre du jour :\n[ORDRE DU JOUR]\n\nNous comptons sur votre présence.\n\nLa gestion de {site_adi}",
               "sms": "{site_adi} : assemblée [DATE] [HEURE], [LIEU]. Merci de votre présence."},
        "es": {"ad": "Aviso de reunión", "konu": "{site_adi} — junta de propietarios",
               "eposta": "Estimado/a {adi_soyadi}:\n\nLa junta de propietarios se celebrará el [FECHA] a las [HORA] en [LUGAR].\n\nOrden del día:\n[ORDEN DEL DÍA]\n\nLe rogamos su asistencia.\n\nAdministración de {site_adi}",
               "sms": "{site_adi}: Junta de propietarios [FECHA] [HORA], [LUGAR]. Rogamos asistencia."},
        "ar": {"ad": "إشعار اجتماع", "konu": "{site_adi} — اجتماع الملاك",
               "eposta": "عزيزي {adi_soyadi}،\n\nسيُعقد اجتماع الملاك يوم [التاريخ] الساعة [الساعة] في [المكان].\n\nجدول الأعمال:\n[جدول الأعمال]\n\nنرجو حضوركم.\n\nإدارة {site_adi}",
               "sms": "{site_adi}: اجتماع الملاك [التاريخ] [الساعة]، [المكان]. نرجو الحضور."},
        "ru": {"ad": "Объявление о собрании", "konu": "{site_adi} — собрание собственников",
               "eposta": "Уважаемый(ая) {adi_soyadi},\n\nсобрание собственников состоится [ДАТА] в [ВРЕМЯ], место: [МЕСТО].\n\nПовестка:\n[ПОВЕСТКА]\n\nПросим принять участие.\n\nУправление {site_adi}",
               "sms": "{site_adi}: собрание собственников [ДАТА] [ВРЕМЯ], [МЕСТО]. Просим прийти."},
    },
    "su_kesintisi": {
        "tr": {"ad": "Su kesintisi", "konu": "{site_adi} — planlı su kesintisi",
               "eposta": "Sayın {adi_soyadi},\n\n[TARİH] günü [BAŞLANGIÇ]–[BİTİŞ] saatleri arasında [NEDEN] nedeniyle su kesintisi olacaktır. Önceden su ayırmanızı öneririz.\n\nAnlayışınız için teşekkür ederiz.\n\n{site_adi} Yönetimi",
               "sms": "{site_adi}: [TARİH] [BAŞLANGIÇ]-[BİTİŞ] arası su kesintisi olacaktır."},
        "en": {"ad": "Water outage", "konu": "{site_adi} — planned water outage",
               "eposta": "Dear {adi_soyadi},\n\nThere will be a water outage on [DATE] between [START] and [END] due to [REASON]. We recommend storing some water in advance.\n\nThank you for your understanding.\n\n{site_adi} Management",
               "sms": "{site_adi}: Water outage on [DATE], [START]-[END]."},
        "de": {"ad": "Wasserabschaltung", "konu": "{site_adi} — geplante Wasserabschaltung",
               "eposta": "Sehr geehrte/r {adi_soyadi},\n\nam [DATUM] wird das Wasser von [BEGINN] bis [ENDE] wegen [GRUND] abgestellt. Bitte legen Sie vorher etwas Wasser bereit.\n\nVielen Dank für Ihr Verständnis.\n\nVerwaltung {site_adi}",
               "sms": "{site_adi}: Wasserabschaltung am [DATUM], [BEGINN]-[ENDE]."},
        "fr": {"ad": "Coupure d'eau", "konu": "{site_adi} — coupure d'eau programmée",
               "eposta": "Bonjour {adi_soyadi},\n\nL'eau sera coupée le [DATE] de [DÉBUT] à [FIN] en raison de [MOTIF]. Nous vous conseillons de prévoir de l'eau.\n\nMerci de votre compréhension.\n\nLa gestion de {site_adi}",
               "sms": "{site_adi} : coupure d'eau le [DATE], [DÉBUT]-[FIN]."},
        "es": {"ad": "Corte de agua", "konu": "{site_adi} — corte de agua programado",
               "eposta": "Estimado/a {adi_soyadi}:\n\nEl [FECHA] habrá un corte de agua de [INICIO] a [FIN] por [MOTIVO]. Le recomendamos reservar agua con antelación.\n\nGracias por su comprensión.\n\nAdministración de {site_adi}",
               "sms": "{site_adi}: corte de agua el [FECHA], [INICIO]-[FIN]."},
        "ar": {"ad": "انقطاع المياه", "konu": "{site_adi} — انقطاع مياه مجدول",
               "eposta": "عزيزي {adi_soyadi}،\n\nستنقطع المياه يوم [التاريخ] من [البداية] إلى [النهاية] بسبب [السبب]. ننصح بتخزين بعض المياه مسبقًا.\n\nشكرًا لتفهمكم.\n\nإدارة {site_adi}",
               "sms": "{site_adi}: انقطاع المياه يوم [التاريخ] من [البداية] إلى [النهاية]."},
        "ru": {"ad": "Отключение воды", "konu": "{site_adi} — плановое отключение воды",
               "eposta": "Уважаемый(ая) {adi_soyadi},\n\n[ДАТА] с [НАЧАЛО] до [КОНЕЦ] будет отключена вода (причина: [ПРИЧИНА]). Рекомендуем заранее запастись водой.\n\nСпасибо за понимание.\n\nУправление {site_adi}",
               "sms": "{site_adi}: отключение воды [ДАТА], [НАЧАЛО]-[КОНЕЦ]."},
    },
    "elektrik_kesintisi": {
        "tr": {"ad": "Elektrik kesintisi", "konu": "{site_adi} — planlı elektrik kesintisi",
               "eposta": "Sayın {adi_soyadi},\n\n[TARİH] günü [BAŞLANGIÇ]–[BİTİŞ] saatleri arasında [NEDEN] nedeniyle elektrik kesintisi olacaktır. Asansörler bu sürede çalışmayacaktır.\n\nAnlayışınız için teşekkür ederiz.\n\n{site_adi} Yönetimi",
               "sms": "{site_adi}: [TARİH] [BAŞLANGIÇ]-[BİTİŞ] arası elektrik kesintisi; asansörler çalışmaz."},
        "en": {"ad": "Power outage", "konu": "{site_adi} — planned power outage",
               "eposta": "Dear {adi_soyadi},\n\nThere will be a power outage on [DATE] between [START] and [END] due to [REASON]. Lifts will not operate during this time.\n\nThank you for your understanding.\n\n{site_adi} Management",
               "sms": "{site_adi}: Power outage on [DATE], [START]-[END]; lifts will not run."},
        "de": {"ad": "Stromabschaltung", "konu": "{site_adi} — geplante Stromabschaltung",
               "eposta": "Sehr geehrte/r {adi_soyadi},\n\nam [DATUM] wird der Strom von [BEGINN] bis [ENDE] wegen [GRUND] abgeschaltet. Die Aufzüge sind in dieser Zeit außer Betrieb.\n\nVielen Dank für Ihr Verständnis.\n\nVerwaltung {site_adi}",
               "sms": "{site_adi}: Stromabschaltung am [DATUM], [BEGINN]-[ENDE]; Aufzüge außer Betrieb."},
        "fr": {"ad": "Coupure d'électricité", "konu": "{site_adi} — coupure d'électricité programmée",
               "eposta": "Bonjour {adi_soyadi},\n\nL'électricité sera coupée le [DATE] de [DÉBUT] à [FIN] en raison de [MOTIF]. Les ascenseurs seront à l'arrêt.\n\nMerci de votre compréhension.\n\nLa gestion de {site_adi}",
               "sms": "{site_adi} : coupure d'électricité le [DATE], [DÉBUT]-[FIN] ; ascenseurs à l'arrêt."},
        "es": {"ad": "Corte de luz", "konu": "{site_adi} — corte de luz programado",
               "eposta": "Estimado/a {adi_soyadi}:\n\nEl [FECHA] habrá un corte de luz de [INICIO] a [FIN] por [MOTIVO]. Los ascensores no funcionarán.\n\nGracias por su comprensión.\n\nAdministración de {site_adi}",
               "sms": "{site_adi}: corte de luz el [FECHA], [INICIO]-[FIN]; ascensores parados."},
        "ar": {"ad": "انقطاع الكهرباء", "konu": "{site_adi} — انقطاع كهرباء مجدول",
               "eposta": "عزيزي {adi_soyadi}،\n\nستنقطع الكهرباء يوم [التاريخ] من [البداية] إلى [النهاية] بسبب [السبب]. لن تعمل المصاعد خلال هذه المدة.\n\nشكرًا لتفهمكم.\n\nإدارة {site_adi}",
               "sms": "{site_adi}: انقطاع الكهرباء يوم [التاريخ] من [البداية] إلى [النهاية]؛ المصاعد متوقفة."},
        "ru": {"ad": "Отключение электричества", "konu": "{site_adi} — плановое отключение электричества",
               "eposta": "Уважаемый(ая) {adi_soyadi},\n\n[ДАТА] с [НАЧАЛО] до [КОНЕЦ] будет отключено электричество (причина: [ПРИЧИНА]). Лифты в это время работать не будут.\n\nСпасибо за понимание.\n\nУправление {site_adi}",
               "sms": "{site_adi}: отключение электричества [ДАТА], [НАЧАЛО]-[КОНЕЦ]; лифты не работают."},
    },
    "bakim_bildirimi": {
        "tr": {"ad": "Bakım bildirimi", "konu": "{site_adi} — bakım çalışması",
               "eposta": "Sayın {adi_soyadi},\n\n[TARİH] günü [ALAN] için bakım çalışması yapılacaktır. Çalışma süresince [ETKİ].\n\nAnlayışınız için teşekkür ederiz.\n\n{site_adi} Yönetimi",
               "sms": "{site_adi}: [TARİH] [ALAN] bakım çalışması yapılacaktır."},
        "en": {"ad": "Maintenance notice", "konu": "{site_adi} — maintenance work",
               "eposta": "Dear {adi_soyadi},\n\nMaintenance work will be carried out on [AREA] on [DATE]. During the work, [IMPACT].\n\nThank you for your understanding.\n\n{site_adi} Management",
               "sms": "{site_adi}: Maintenance on [AREA] on [DATE]."},
        "de": {"ad": "Wartungshinweis", "konu": "{site_adi} — Wartungsarbeiten",
               "eposta": "Sehr geehrte/r {adi_soyadi},\n\nam [DATUM] finden Wartungsarbeiten an [BEREICH] statt. Während der Arbeiten [AUSWIRKUNG].\n\nVielen Dank für Ihr Verständnis.\n\nVerwaltung {site_adi}",
               "sms": "{site_adi}: Wartung an [BEREICH] am [DATUM]."},
        "fr": {"ad": "Avis de maintenance", "konu": "{site_adi} — travaux de maintenance",
               "eposta": "Bonjour {adi_soyadi},\n\nDes travaux de maintenance auront lieu sur [ZONE] le [DATE]. Pendant les travaux, [IMPACT].\n\nMerci de votre compréhension.\n\nLa gestion de {site_adi}",
               "sms": "{site_adi} : maintenance de [ZONE] le [DATE]."},
        "es": {"ad": "Aviso de mantenimiento", "konu": "{site_adi} — trabajos de mantenimiento",
               "eposta": "Estimado/a {adi_soyadi}:\n\nEl [FECHA] se realizarán trabajos de mantenimiento en [ZONA]. Durante los trabajos, [IMPACTO].\n\nGracias por su comprensión.\n\nAdministración de {site_adi}",
               "sms": "{site_adi}: mantenimiento de [ZONA] el [FECHA]."},
        "ar": {"ad": "إشعار صيانة", "konu": "{site_adi} — أعمال صيانة",
               "eposta": "عزيزي {adi_soyadi}،\n\nستُجرى أعمال صيانة في [المنطقة] يوم [التاريخ]. خلال الأعمال [الأثر].\n\nشكرًا لتفهمكم.\n\nإدارة {site_adi}",
               "sms": "{site_adi}: صيانة [المنطقة] يوم [التاريخ]."},
        "ru": {"ad": "Уведомление о ремонте", "konu": "{site_adi} — ремонтные работы",
               "eposta": "Уважаемый(ая) {adi_soyadi},\n\n[ДАТА] будут проводиться работы: [ЗОНА]. Во время работ [ВЛИЯНИЕ].\n\nСпасибо за понимание.\n\nУправление {site_adi}",
               "sms": "{site_adi}: ремонтные работы ([ЗОНА]) [ДАТА]."},
    },
    "bayram_tebrigi": {
        "tr": {"ad": "Bayram tebriği", "konu": "{site_adi} — iyi bayramlar",
               "eposta": "Sayın {adi_soyadi},\n\n[BAYRAM] bayramınızı en içten dileklerimizle kutlar, sevdiklerinizle birlikte sağlıklı ve mutlu bir bayram geçirmenizi dileriz.\n\n{site_adi} Yönetimi",
               "sms": "{site_adi} Yönetimi [BAYRAM] bayramınızı kutlar, sağlıklı ve mutlu bayramlar diler."},
        "en": {"ad": "Holiday greeting", "konu": "{site_adi} — happy holidays",
               "eposta": "Dear {adi_soyadi},\n\nWe wish you and your loved ones a happy and healthy [HOLIDAY].\n\n{site_adi} Management",
               "sms": "{site_adi} Management wishes you a happy and healthy [HOLIDAY]."},
        "de": {"ad": "Festtagsgruß", "konu": "{site_adi} — frohe Feiertage",
               "eposta": "Sehr geehrte/r {adi_soyadi},\n\nwir wünschen Ihnen und Ihren Lieben ein frohes und gesundes [FEST].\n\nVerwaltung {site_adi}",
               "sms": "Die Verwaltung {site_adi} wünscht frohe und gesunde [FEST]."},
        "fr": {"ad": "Vœux de fête", "konu": "{site_adi} — bonnes fêtes",
               "eposta": "Bonjour {adi_soyadi},\n\nNous vous souhaitons, à vous et à vos proches, une belle et heureuse [FÊTE].\n\nLa gestion de {site_adi}",
               "sms": "La gestion de {site_adi} vous souhaite une belle [FÊTE]."},
        "es": {"ad": "Felicitación festiva", "konu": "{site_adi} — felices fiestas",
               "eposta": "Estimado/a {adi_soyadi}:\n\nLe deseamos a usted y a los suyos unas felices y saludables [FIESTA].\n\nAdministración de {site_adi}",
               "sms": "La administración de {site_adi} le desea felices [FIESTA]."},
        "ar": {"ad": "تهنئة بالعيد", "konu": "{site_adi} — عيد سعيد",
               "eposta": "عزيزي {adi_soyadi}،\n\nنهنئكم بـ[العيد] ونتمنى لكم ولأحبائكم عيدًا سعيدًا وصحيًا.\n\nإدارة {site_adi}",
               "sms": "إدارة {site_adi} تهنئكم بـ[العيد] وتتمنى لكم عيدًا سعيدًا."},
        "ru": {"ad": "Поздравление с праздником", "konu": "{site_adi} — с праздником",
               "eposta": "Уважаемый(ая) {adi_soyadi},\n\nпоздравляем вас и ваших близких с праздником [ПРАЗДНИК] и желаем здоровья и счастья.\n\nУправление {site_adi}",
               "sms": "Управление {site_adi} поздравляет с праздником [ПРАЗДНИК]!"},
    },
    "hosgeldiniz": {
        "tr": {"ad": "Hoş geldiniz", "konu": "{site_adi}'ne hoş geldiniz",
               "eposta": "Sayın {adi_soyadi},\n\n{site_adi} ailesine hoş geldiniz! Duyuruları, aidatınızı ve taleplerinizi Yönetiyor uygulamasından takip edebilirsiniz. Ödeme kodunuz: {odeme_kodu}.\n\nHerhangi bir konuda yönetimle uygulamadan iletişime geçebilirsiniz.\n\n{site_adi} Yönetimi",
               "sms": "{site_adi}'ne hoş geldiniz! Duyuru ve aidat takibi için Yönetiyor uygulamasını kullanabilirsiniz."},
        "en": {"ad": "Welcome", "konu": "Welcome to {site_adi}",
               "eposta": "Dear {adi_soyadi},\n\nWelcome to {site_adi}! You can follow announcements, your dues and your requests in the Yönetiyor app. Your payment code: {odeme_kodu}.\n\nYou can contact management through the app at any time.\n\n{site_adi} Management",
               "sms": "Welcome to {site_adi}! Use the Yönetiyor app for announcements and dues."},
        "de": {"ad": "Willkommen", "konu": "Willkommen in {site_adi}",
               "eposta": "Sehr geehrte/r {adi_soyadi},\n\nwillkommen in {site_adi}! Mitteilungen, Hausgeld und Anliegen verfolgen Sie in der Yönetiyor-App. Ihr Zahlungscode: {odeme_kodu}.\n\nDie Verwaltung erreichen Sie jederzeit über die App.\n\nVerwaltung {site_adi}",
               "sms": "Willkommen in {site_adi}! Nutzen Sie die Yönetiyor-App für Mitteilungen und Hausgeld."},
        "fr": {"ad": "Bienvenue", "konu": "Bienvenue à {site_adi}",
               "eposta": "Bonjour {adi_soyadi},\n\nBienvenue à {site_adi} ! Suivez les annonces, vos charges et vos demandes dans l'application Yönetiyor. Votre code de paiement : {odeme_kodu}.\n\nVous pouvez joindre la gestion à tout moment via l'application.\n\nLa gestion de {site_adi}",
               "sms": "Bienvenue à {site_adi} ! Utilisez l'application Yönetiyor pour les annonces et charges."},
        "es": {"ad": "Bienvenida", "konu": "Bienvenido a {site_adi}",
               "eposta": "Estimado/a {adi_soyadi}:\n\n¡Bienvenido a {site_adi}! Puede seguir los anuncios, sus cuotas y sus solicitudes en la app Yönetiyor. Su código de pago: {odeme_kodu}.\n\nPuede contactar con la administración en cualquier momento desde la app.\n\nAdministración de {site_adi}",
               "sms": "¡Bienvenido a {site_adi}! Use la app Yönetiyor para anuncios y cuotas."},
        "ar": {"ad": "ترحيب", "konu": "مرحبًا بك في {site_adi}",
               "eposta": "عزيزي {adi_soyadi}،\n\nمرحبًا بك في {site_adi}! يمكنك متابعة الإعلانات والرسوم والطلبات في تطبيق Yönetiyor. رمز الدفع: {odeme_kodu}.\n\nيمكنك التواصل مع الإدارة عبر التطبيق في أي وقت.\n\nإدارة {site_adi}",
               "sms": "مرحبًا بك في {site_adi}! استخدم تطبيق Yönetiyor للإعلانات والرسوم."},
        "ru": {"ad": "Приветствие", "konu": "Добро пожаловать в {site_adi}",
               "eposta": "Уважаемый(ая) {adi_soyadi},\n\nдобро пожаловать в {site_adi}! Объявления, взносы и заявки — в приложении Yönetiyor. Ваш платёжный код: {odeme_kodu}.\n\nСвязаться с управлением можно в приложении в любое время.\n\nУправление {site_adi}",
               "sms": "Добро пожаловать в {site_adi}! Объявления и взносы — в приложении Yönetiyor."},
    },
    "odeme_kodu": {
        "tr": {"ad": "Ödeme kodu", "konu": "{site_adi} — ödeme kodunuz",
               "eposta": "Sayın {adi_soyadi},\n\n{adres} numaralı daireniz için ödeme kodunuz: {odeme_kodu}\n\nHavale/EFT yaparken açıklama alanına yalnızca bu kodu yazın; ödemeniz dairenize otomatik işlenir.\n\n{site_adi} Yönetimi",
               "sms": "{site_adi}: {adres} için ödeme kodunuz {odeme_kodu}. Havale açıklamasına yalnızca bu kodu yazın."},
        "en": {"ad": "Payment code", "konu": "{site_adi} — your payment code",
               "eposta": "Dear {adi_soyadi},\n\nYour payment code for unit {adres} is: {odeme_kodu}\n\nWrite only this code in the transfer description; your payment will be recorded automatically.\n\n{site_adi} Management",
               "sms": "{site_adi}: your payment code for {adres} is {odeme_kodu}. Write only this code in the transfer description."},
        "de": {"ad": "Zahlungscode", "konu": "{site_adi} — Ihr Zahlungscode",
               "eposta": "Sehr geehrte/r {adi_soyadi},\n\nIhr Zahlungscode für Wohnung {adres}: {odeme_kodu}\n\nGeben Sie im Verwendungszweck nur diesen Code an; die Zahlung wird automatisch zugeordnet.\n\nVerwaltung {site_adi}",
               "sms": "{site_adi}: Zahlungscode für {adres}: {odeme_kodu}. Nur diesen Code im Verwendungszweck angeben."},
        "fr": {"ad": "Code de paiement", "konu": "{site_adi} — votre code de paiement",
               "eposta": "Bonjour {adi_soyadi},\n\nVotre code de paiement pour le logement {adres} : {odeme_kodu}\n\nIndiquez uniquement ce code dans le libellé du virement ; le paiement sera affecté automatiquement.\n\nLa gestion de {site_adi}",
               "sms": "{site_adi} : code de paiement pour {adres} : {odeme_kodu}. Indiquez seulement ce code au virement."},
        "es": {"ad": "Código de pago", "konu": "{site_adi} — su código de pago",
               "eposta": "Estimado/a {adi_soyadi}:\n\nSu código de pago para la vivienda {adres} es: {odeme_kodu}\n\nEscriba solo este código en el concepto de la transferencia; el pago se asignará automáticamente.\n\nAdministración de {site_adi}",
               "sms": "{site_adi}: su código de pago para {adres} es {odeme_kodu}. Escriba solo este código en el concepto."},
        "ar": {"ad": "رمز الدفع", "konu": "{site_adi} — رمز الدفع الخاص بك",
               "eposta": "عزيزي {adi_soyadi}،\n\nرمز الدفع للوحدة {adres}: {odeme_kodu}\n\nاكتب هذا الرمز فقط في وصف التحويل؛ ستُسجَّل دفعتك تلقائيًا.\n\nإدارة {site_adi}",
               "sms": "{site_adi}: رمز الدفع للوحدة {adres} هو {odeme_kodu}. اكتب هذا الرمز فقط في وصف التحويل."},
        "ru": {"ad": "Платёжный код", "konu": "{site_adi} — ваш платёжный код",
               "eposta": "Уважаемый(ая) {adi_soyadi},\n\nваш платёжный код для квартиры {adres}: {odeme_kodu}\n\nУкажите в назначении платежа только этот код — оплата зачислится автоматически.\n\nУправление {site_adi}",
               "sms": "{site_adi}: платёжный код для {adres}: {odeme_kodu}. В назначении укажите только его."},
    },
}

DILLER = ("tr", "en", "de", "fr", "es", "ar", "ru")


def listele(kanal: str, dil: str) -> list[dict[str, str | None]]:
    """Kanal ve dilde hazir sablonlar: {kod, kanal, ad, konu, govde}."""
    d = dil if dil in DILLER else "tr"
    cikti: list[dict[str, str | None]] = []
    for kod in KODLAR:
        m = _S[kod][d]
        cikti.append({
            "kod": kod,
            "kanal": kanal,
            "ad": m["ad"],
            "konu": m["konu"] if kanal == "eposta" else None,
            "govde": m["eposta"] if kanal == "eposta" else m["sms"],
        })
    return cikti
