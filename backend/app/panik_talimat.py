"""(P249 §1b) SOS TALIMATLARI — TEK KAYNAK (mobil + web + push basligi).

===========================================================================
NEDEN SUNUCUDA
===========================================================================
Ayni talimat uc yerde okunur: mobil tam ekran, web gelen alarm katmani ve
push basligi. Uc ayri sozlukte tutmak, bir gun depremde "asansor" cumlesi
bir yuzeyde duzeltilip otekinde eski kalmasi demekti. Istemci metni
`GET /panik/...` yanitindan (`baslik`, `talimat`) istegin diliyle alir.

===========================================================================
IKI DENEYIM (istegin ayrimi)
===========================================================================
* TOPLU UYARI — deprem, yangin, gaz, tahliye: kimse "yardim" istemiyor,
  herkese NE YAPACAGI soyleniyor. Tam ekran ADIM ADIM talimat.
* YARDIM CAGRISI — saglik, guvenlik tehdidi, diger: bir kisi yardim
  istiyor; alici guvenlik ve yonetim. Kisa tek cumle + kim/nerede.

===========================================================================
KAYNAKLAR — UYDURULMADI (docs/P249-kararlar.md §1b tablosu)
===========================================================================
* DEPREM: AFAD "Deprem Aninda Yapilmasi Gerekenler" — Cok-Kapan-Tutun;
  pencere/cam ve devrilebilecek esyadan uzak durma; sarsinti surerken
  merdivene, balkona, asansore YONELMEME. AFAD "Deprem Sonrasi" — gaz,
  elektrik ve suyu kapatma; hasarli binaya geri GIRMEME; artci
  sarsintilar.
* YANGIN: itfaiye yangin guvenligi yonergeleri (112 Acil; asansor
  yasagi; dumanda egilerek ve agzi islak bezle kapatarak ilerleme;
  kapiyi acmadan elin tersiyle yoklama; kapilari kapatarak yayilimi
  yavaslatma; esya icin geri donmeme).
* GAZ: dogal gaz dagitim sirketlerinin kacak talimati ve 187 Dogal Gaz
  Acil hatti — kivilcim kaynaklarina (elektrik dugmesi, priz, zil,
  ates) dokunmama; havalandirma; guvenliyse vanayi kapatma; binayi terk
  etme; ihbari BINA DISINDAN yapma.
* TAHLIYE: AFAD tahliye/toplanma alani yonergesi — asansor yasagi,
  yardima ihtiyaci olanlara destek, toplanma alanina gitme, izin
  verilmeden geri donmeme.

KURUMLARA DOGRULATILMADI: yonergelerin ozetidir; sitenin kendi acil
durum plani farkliysa metinler gozden gecirilmelidir (P243 notu surer).
"""
from __future__ import annotations

from typing import Final

from .panik import SITE_GENELI

#: TOPLU UYARI kategorileri = bina geneli tehlikeler (tum siteye gider).
TOPLU: Final[frozenset[str]] = SITE_GENELI


def toplu_mu(kategori: str | None) -> bool:
    return kategori in TOPLU


#: "TATBIKAT" — her dilde. Gercek alarmla karistirilamasin diye basligin
#: ONUNE gelir ve ekranda ayri bir serit olarak da cizilir.
TATBIKAT: Final[dict[str, str]] = {
    "tr": "TATBİKAT", "en": "DRILL", "de": "ÜBUNG", "fr": "EXERCICE",
    "es": "SIMULACRO", "ar": "تمرين", "ru": "УЧЕНИЯ",
}

#: Kategori basligi — alici bunu UC SANIYEDE okumali.
BASLIK: Final[dict[str, dict[str, str]]] = {
    "deprem": {
        "tr": "DEPREM ALARMI", "en": "EARTHQUAKE ALERT", "de": "ERDBEBENALARM",
        "fr": "ALERTE SÉISME", "es": "ALERTA DE TERREMOTO",
        "ar": "إنذار زلزال", "ru": "ТРЕВОГА: ЗЕМЛЕТРЯСЕНИЕ",
    },
    "yangin": {
        "tr": "YANGIN ALARMI", "en": "FIRE ALARM", "de": "FEUERALARM",
        "fr": "ALARME INCENDIE", "es": "ALARMA DE INCENDIO",
        "ar": "إنذار حريق", "ru": "ПОЖАРНАЯ ТРЕВОГА",
    },
    "gaz": {
        "tr": "GAZ KAÇAĞI ALARMI", "en": "GAS LEAK ALERT", "de": "GASALARM",
        "fr": "ALERTE FUITE DE GAZ", "es": "ALERTA DE FUGA DE GAS",
        "ar": "إنذار تسرب غاز", "ru": "ТРЕВОГА: УТЕЧКА ГАЗА",
    },
    "tahliye": {
        "tr": "TAHLİYE ALARMI", "en": "EVACUATION ALERT",
        "de": "EVAKUIERUNGSALARM", "fr": "ALERTE ÉVACUATION",
        "es": "ALERTA DE EVACUACIÓN", "ar": "إنذار إخلاء",
        "ru": "ТРЕВОГА: ЭВАКУАЦИЯ",
    },
    "saglik": {
        "tr": "SAĞLIK ACİLİ", "en": "MEDICAL EMERGENCY",
        "de": "MEDIZINISCHER NOTFALL", "fr": "URGENCE MÉDICALE",
        "es": "EMERGENCIA MÉDICA", "ar": "حالة طبية طارئة",
        "ru": "МЕДИЦИНСКАЯ ПОМОЩЬ",
    },
    "guvenlik_tehdidi": {
        "tr": "GÜVENLİK TEHDİDİ", "en": "SECURITY THREAT",
        "de": "SICHERHEITSBEDROHUNG", "fr": "MENACE DE SÉCURITÉ",
        "es": "AMENAZA DE SEGURIDAD", "ar": "تهديد أمني",
        "ru": "УГРОЗА БЕЗОПАСНОСТИ",
    },
    "diger": {
        "tr": "ACİL DURUM", "en": "EMERGENCY", "de": "NOTFALL",
        "fr": "URGENCE", "es": "EMERGENCIA", "ar": "حالة طارئة",
        "ru": "ЧРЕЗВЫЧАЙНАЯ СИТУАЦИЯ",
    },
}

#: Kategorisiz (P240 donemi) alarmin basligi.
KATEGORISIZ_BASLIK: Final[dict[str, str]] = {
    "tr": "ACİL DURUM ÇAĞRISI", "en": "EMERGENCY CALL", "de": "NOTRUF",
    "fr": "APPEL D’URGENCE", "es": "LLAMADA DE EMERGENCIA",
    "ar": "نداء طوارئ", "ru": "ЭКСТРЕННЫЙ ВЫЗОВ",
}

#: ADIM ADIM TALIMAT. Toplu uyarida tam ekran bunu SIRAYLA cizer; yardim
#: cagrisinda tek cumle (alici guvenlik/yonetim).
TALIMAT: Final[dict[str, dict[str, tuple[str, ...]]]] = {
    "deprem": {
        "tr": (
            "Sarsıntı sürerken ÇÖK, KAPAN, TUTUN: sağlam bir eşyanın yanına çökün, başınızı ve boynunuzu koruyun.",
            "Pencerelerden, camlardan ve devrilebilecek eşyalardan uzak durun.",
            "Sarsıntı sürerken merdivene, balkona ya da dışarı koşmayın. Asansör kullanmayın.",
            "Sarsıntı bitince gazı ve elektriği kapatın, merdivenle çıkıp toplanma alanına gidin.",
            "Artçı sarsıntılara hazır olun; hasarlı binaya geri girmeyin.",
        ),
        "en": (
            "While shaking: DROP, COVER, HOLD ON next to something sturdy; protect your head and neck.",
            "Stay away from windows, glass and anything that could fall.",
            "Do not run to the stairs, balcony or outside while shaking. Do not use the lift.",
            "When shaking stops, turn off gas and power, take the stairs to the assembly point.",
            "Expect aftershocks; do not go back into a damaged building.",
        ),
        "de": (
            "Während des Bebens: DUCKEN, SCHÜTZEN, FESTHALTEN neben etwas Stabilem; Kopf und Nacken schützen.",
            "Von Fenstern, Glas und umstürzenden Gegenständen fernhalten.",
            "Während des Bebens nicht zur Treppe, auf den Balkon oder ins Freie rennen. Keinen Aufzug.",
            "Nach dem Beben Gas und Strom abschalten, über die Treppe zum Sammelplatz gehen.",
            "Mit Nachbeben rechnen; beschädigte Gebäude nicht wieder betreten.",
        ),
        "fr": (
            "Pendant la secousse : BAISSEZ-VOUS, PROTÉGEZ-VOUS, ACCROCHEZ-VOUS près d’un meuble solide ; protégez tête et nuque.",
            "Éloignez-vous des fenêtres, des vitres et de ce qui peut tomber.",
            "Ne courez pas vers l’escalier, le balcon ou dehors pendant la secousse. Pas d’ascenseur.",
            "Après la secousse, coupez gaz et électricité, descendez par l’escalier au point de rassemblement.",
            "Attendez-vous à des répliques ; ne rentrez pas dans un bâtiment endommagé.",
        ),
        "es": (
            "Durante el temblor: AGÁCHESE, CÚBRASE, SUJÉTESE junto a algo firme; proteja cabeza y cuello.",
            "Aléjese de ventanas, cristales y objetos que puedan caer.",
            "No corra a las escaleras, al balcón ni afuera durante el temblor. No use el ascensor.",
            "Cuando pare, corte el gas y la luz y baje por las escaleras al punto de reunión.",
            "Espere réplicas; no vuelva a entrar en un edificio dañado.",
        ),
        "ar": (
            "أثناء الهزة: انبطح، احتمِ، تمسّك بجوار شيء متين، واحمِ رأسك ورقبتك.",
            "ابتعد عن النوافذ والزجاج وكل ما قد يسقط.",
            "لا تركض إلى الدرج أو الشرفة أو الخارج أثناء الهزة. لا تستخدم المصعد.",
            "بعد توقف الهزة أغلق الغاز والكهرباء، وانزل بالدرج إلى نقطة التجمع.",
            "توقّع الهزات الارتدادية، ولا تعد إلى مبنى متضرر.",
        ),
        "ru": (
            "Во время толчков: ПРИГНИТЕСЬ, УКРОЙТЕСЬ, ДЕРЖИТЕСЬ рядом с прочным предметом; защитите голову и шею.",
            "Держитесь подальше от окон, стекла и того, что может упасть.",
            "Во время толчков не бегите к лестнице, на балкон или на улицу. Лифтом не пользуйтесь.",
            "Когда толчки прекратятся, перекройте газ и свет, по лестнице идите к месту сбора.",
            "Ожидайте повторных толчков; не возвращайтесь в повреждённое здание.",
        ),
    },
    "yangin": {
        "tr": (
            "112'yi arayın ve yangını bildirin.",
            "Asansör kullanmayın; binadan merdivenle çıkın.",
            "Duman varsa eğilerek, ağzınızı ıslak bir bezle kapatarak ilerleyin.",
            "Kapıyı açmadan önce elinizin tersiyle yoklayın; sıcaksa açmayın. Çıkarken kapıları kapatın.",
            "Toplanma alanına gidin; eşya için geri dönmeyin.",
        ),
        "en": (
            "Call 112 and report the fire.",
            "Do not use the lift; leave the building by the stairs.",
            "If there is smoke, stay low and cover your mouth with a wet cloth.",
            "Feel a door with the back of your hand before opening; if hot, keep it shut. Close doors behind you.",
            "Go to the assembly point; do not go back for belongings.",
        ),
        "de": (
            "Rufen Sie 112 an und melden Sie den Brand.",
            "Keinen Aufzug benutzen; das Gebäude über die Treppe verlassen.",
            "Bei Rauch gebückt gehen und den Mund mit einem nassen Tuch bedecken.",
            "Tür vor dem Öffnen mit dem Handrücken prüfen; ist sie heiß, nicht öffnen. Türen hinter sich schließen.",
            "Zum Sammelplatz gehen; nicht für Sachen zurückkehren.",
        ),
        "fr": (
            "Appelez le 112 et signalez l’incendie.",
            "Pas d’ascenseur ; quittez le bâtiment par l’escalier.",
            "En présence de fumée, baissez-vous et couvrez-vous la bouche d’un linge mouillé.",
            "Touchez la porte du dos de la main avant d’ouvrir ; si elle est chaude, n’ouvrez pas. Fermez les portes derrière vous.",
            "Rendez-vous au point de rassemblement ; ne revenez pas chercher vos affaires.",
        ),
        "es": (
            "Llame al 112 y avise del incendio.",
            "No use el ascensor; salga por las escaleras.",
            "Si hay humo, avance agachado y cúbrase la boca con un paño húmedo.",
            "Toque la puerta con el dorso de la mano antes de abrir; si está caliente, no abra. Cierre las puertas al salir.",
            "Vaya al punto de reunión; no vuelva por sus pertenencias.",
        ),
        "ar": (
            "اتصل بالرقم 112 وأبلغ عن الحريق.",
            "لا تستخدم المصعد، وغادر المبنى عبر الدرج.",
            "إذا وُجد دخان فتقدّم منحنيًا وغطِّ فمك بقطعة قماش مبللة.",
            "المس الباب بظهر يدك قبل فتحه؛ إن كان ساخنًا فلا تفتحه. أغلق الأبواب خلفك.",
            "توجّه إلى نقطة التجمع ولا تعد لأخذ أغراضك.",
        ),
        "ru": (
            "Позвоните 112 и сообщите о пожаре.",
            "Не пользуйтесь лифтом; покиньте здание по лестнице.",
            "При задымлении двигайтесь пригнувшись, закрыв рот мокрой тканью.",
            "Перед тем как открыть дверь, потрогайте её тыльной стороной ладони; если горячая — не открывайте. Закрывайте двери за собой.",
            "Идите к месту сбора; не возвращайтесь за вещами.",
        ),
    },
    "gaz": {
        "tr": (
            "Elektrik düğmelerine, prizlere ve zillere dokunmayın; ateş yakmayın.",
            "Kapı ve pencereleri açarak ortamı havalandırın.",
            "Güvenliyse doğal gaz vanasını kapatın.",
            "Binayı terk edin; asansör kullanmayın.",
            "187 Doğal Gaz Acil'i bina dışından arayın.",
        ),
        "en": (
            "Do not touch light switches, sockets or doorbells; no open flames.",
            "Open doors and windows to ventilate.",
            "If it is safe, close the gas valve.",
            "Leave the building; do not use the lift.",
            "Call the gas emergency line (187) from outside the building.",
        ),
        "de": (
            "Keine Lichtschalter, Steckdosen oder Klingeln berühren; kein offenes Feuer.",
            "Türen und Fenster öffnen und lüften.",
            "Wenn gefahrlos möglich, den Gashahn schließen.",
            "Gebäude verlassen; keinen Aufzug benutzen.",
            "Den Gas-Notruf (187) von außerhalb des Gebäudes anrufen.",
        ),
        "fr": (
            "Ne touchez ni interrupteurs, ni prises, ni sonnettes ; aucune flamme.",
            "Ouvrez portes et fenêtres pour aérer.",
            "Si c’est sans danger, fermez la vanne de gaz.",
            "Quittez le bâtiment ; pas d’ascenseur.",
            "Appelez l’urgence gaz (187) depuis l’extérieur du bâtiment.",
        ),
        "es": (
            "No toque interruptores, enchufes ni timbres; no encienda llamas.",
            "Abra puertas y ventanas para ventilar.",
            "Si es seguro, cierre la llave del gas.",
            "Salga del edificio; no use el ascensor.",
            "Llame a la emergencia de gas (187) desde fuera del edificio.",
        ),
        "ar": (
            "لا تلمس مفاتيح الكهرباء أو المقابس أو الأجراس، ولا تشعل نارًا.",
            "افتح الأبواب والنوافذ للتهوية.",
            "إن كان ذلك آمنًا فأغلق صمام الغاز.",
            "غادر المبنى ولا تستخدم المصعد.",
            "اتصل بطوارئ الغاز (187) من خارج المبنى.",
        ),
        "ru": (
            "Не трогайте выключатели, розетки и звонки; не зажигайте огонь.",
            "Откройте двери и окна для проветривания.",
            "Если это безопасно, перекройте газовый кран.",
            "Покиньте здание; не пользуйтесь лифтом.",
            "Позвоните в аварийную газовую службу (187) с улицы.",
        ),
    },
    "tahliye": {
        "tr": (
            "Sakin olun ve binayı derhal terk edin.",
            "Asansör kullanmayın; merdiveni kullanın.",
            "Yaşlı, engelli ve çocuk komşularınıza yardım edin.",
            "Toplanma alanına gidin ve 'Güvendeyim' düğmesine basın.",
            "Görevliler izin vermeden binaya geri dönmeyin.",
        ),
        "en": (
            "Stay calm and leave the building immediately.",
            "Do not use the lift; use the stairs.",
            "Help elderly, disabled and young neighbours.",
            "Go to the assembly point and press 'I am safe'.",
            "Do not re-enter until staff say it is safe.",
        ),
        "de": (
            "Ruhe bewahren und das Gebäude sofort verlassen.",
            "Keinen Aufzug benutzen; die Treppe nehmen.",
            "Älteren, behinderten Nachbarn und Kindern helfen.",
            "Zum Sammelplatz gehen und „Ich bin in Sicherheit“ drücken.",
            "Erst nach Freigabe durch das Personal zurückkehren.",
        ),
        "fr": (
            "Restez calme et quittez le bâtiment immédiatement.",
            "Pas d’ascenseur ; prenez l’escalier.",
            "Aidez les voisins âgés, handicapés et les enfants.",
            "Allez au point de rassemblement et appuyez sur « Je suis en sécurité ».",
            "Ne revenez pas sans l’accord du personnel.",
        ),
        "es": (
            "Mantenga la calma y salga del edificio de inmediato.",
            "No use el ascensor; use las escaleras.",
            "Ayude a vecinos mayores, con discapacidad y a los niños.",
            "Vaya al punto de reunión y pulse «Estoy a salvo».",
            "No vuelva a entrar sin permiso del personal.",
        ),
        "ar": (
            "حافظ على هدوئك وغادر المبنى فورًا.",
            "لا تستخدم المصعد، واستخدم الدرج.",
            "ساعد الجيران المسنين وذوي الإعاقة والأطفال.",
            "توجّه إلى نقطة التجمع واضغط «أنا بأمان».",
            "لا تعد إلى المبنى قبل إذن الموظفين.",
        ),
        "ru": (
            "Сохраняйте спокойствие и немедленно покиньте здание.",
            "Не пользуйтесь лифтом; идите по лестнице.",
            "Помогите пожилым соседям, людям с инвалидностью и детям.",
            "Идите к месту сбора и нажмите «Я в безопасности».",
            "Не возвращайтесь без разрешения персонала.",
        ),
    },
    # ------------------------------------------------------------------ #
    # YARDIM CAGRISI — alici guvenlik ve yonetim. TEK cumle: o kisinin
    # isi "nereye gidecegim"i okumak ve kosmaktir.
    # ------------------------------------------------------------------ #
    "saglik": {
        "tr": ("112 arandı mı kontrol edin; ambulans ekibini kapıda karşılayın.",),
        "en": ("Check that 112 was called; meet the ambulance crew at the gate.",),
        "de": ("Prüfen, ob 112 gerufen wurde; den Rettungsdienst am Tor empfangen.",),
        "fr": ("Vérifiez que le 112 a été appelé ; accueillez les secours à l’entrée.",),
        "es": ("Compruebe que se llamó al 112; reciba a la ambulancia en la entrada.",),
        "ar": ("تحقق من الاتصال بالرقم 112، واستقبل فريق الإسعاف عند البوابة.",),
        "ru": ("Проверьте, вызвана ли скорая (112); встретьте бригаду у ворот.",),
    },
    "guvenlik_tehdidi": {
        "tr": ("Kendinizi tehlikeye atmayın; 155'i arayın ve sakinleri yerinde kalmaya yönlendirin.",),
        "en": ("Do not put yourself at risk; call the police and keep residents where they are.",),
        "de": ("Bringen Sie sich nicht in Gefahr; Polizei rufen und Bewohner drinnen halten.",),
        "fr": ("Ne vous mettez pas en danger ; appelez la police et gardez les résidents à l’abri.",),
        "es": ("No se ponga en riesgo; llame a la policía y mantenga a los residentes resguardados.",),
        "ar": ("لا تعرّض نفسك للخطر؛ اتصل بالشرطة ووجّه السكان للبقاء في أماكنهم.",),
        "ru": ("Не подвергайте себя опасности; вызовите полицию и попросите жильцов оставаться на месте.",),
    },
    "diger": {
        "tr": ("Olay yerine gidin; ayrıntı için alarmı açanla iletişime geçin.",),
        "en": ("Go to the location; contact the person who raised the alarm for details.",),
        "de": ("Zum Ort gehen; für Einzelheiten die meldende Person kontaktieren.",),
        "fr": ("Rendez-vous sur place ; contactez l’auteur de l’alerte pour les détails.",),
        "es": ("Vaya al lugar; contacte con quien dio la alarma para más detalles.",),
        "ar": ("توجّه إلى المكان، وتواصل مع من أطلق الإنذار لمعرفة التفاصيل.",),
        "ru": ("Идите на место; за подробностями свяжитесь с тем, кто подал тревогу.",),
    },
}

#: KISA TALIMAT — push GOVDESI. Bildirim ekraninda TAM okunmali (<=110
#: karakter, P243 kurali); tam ekrandaki adimlarin ozu.
KISA: Final[dict[str, dict[str, str]]] = {
    "deprem": {
        "tr": "Çök, kapan, tutun. Sarsıntı bitince merdivenle çıkın; asansör kullanmayın.",
        "en": "Drop, cover, hold on. When shaking stops use the stairs; no lift.",
        "de": "Ducken, schützen, festhalten. Danach Treppe nehmen, keinen Aufzug.",
        "fr": "Baissez-vous, protégez-vous, accrochez-vous. Puis l’escalier, pas l’ascenseur.",
        "es": "Agáchese, cúbrase, sujétese. Después use las escaleras, no el ascensor.",
        "ar": "انبطح، احتمِ، تمسّك. بعد توقف الهزة استخدم الدرج لا المصعد.",
        "ru": "Пригнитесь, укройтесь, держитесь. Затем по лестнице, без лифта.",
    },
    "yangin": {
        "tr": "Binayı merdivenden terk edin. Asansör kullanmayın, kapıları kapatın.",
        "en": "Leave by the stairs. No lift; close doors behind you.",
        "de": "Über die Treppe verlassen. Kein Aufzug, Türen schließen.",
        "fr": "Sortez par l’escalier. Pas d’ascenseur, fermez les portes.",
        "es": "Salga por las escaleras. Sin ascensor, cierre las puertas.",
        "ar": "غادر عبر الدرج. لا تستخدم المصعد وأغلق الأبواب.",
        "ru": "Уходите по лестнице. Без лифта, закрывайте двери.",
    },
    "gaz": {
        "tr": "Ateş yakmayın, elektrik düğmelerine dokunmayın. Binayı terk edin.",
        "en": "No flames, do not touch switches. Leave the building.",
        "de": "Kein Feuer, keine Schalter berühren. Gebäude verlassen.",
        "fr": "Pas de flamme, ne touchez pas les interrupteurs. Sortez.",
        "es": "Sin llamas, no toque interruptores. Salga del edificio.",
        "ar": "لا تشعل نارًا ولا تلمس مفاتيح الكهرباء. غادر المبنى.",
        "ru": "Без огня, не трогайте выключатели. Покиньте здание.",
    },
    "tahliye": {
        "tr": "Binayı derhal terk edin. Asansör kullanmayın, toplanma alanına gidin.",
        "en": "Leave the building now. No lift; go to the assembly point.",
        "de": "Gebäude sofort verlassen. Kein Aufzug, zum Sammelplatz.",
        "fr": "Quittez le bâtiment. Pas d’ascenseur, point de rassemblement.",
        "es": "Salga ya. Sin ascensor, vaya al punto de reunión.",
        "ar": "غادر المبنى فورًا. بلا مصعد، إلى نقطة التجمع.",
        "ru": "Немедленно выйдите. Без лифта, к месту сбора.",
    },
    "saglik": {
        "tr": "112 arandı mı kontrol edin, ekibi kapıda karşılayın.",
        "en": "Check 112 was called; meet the crew at the gate.",
        "de": "112 gerufen? Rettungsdienst am Tor empfangen.",
        "fr": "Le 112 est-il appelé ? Accueillez les secours.",
        "es": "¿Se llamó al 112? Reciba a la ambulancia.",
        "ar": "تحقق من الاتصال بـ112 واستقبل الإسعاف.",
        "ru": "Скорая вызвана? Встретьте бригаду.",
    },
    "guvenlik_tehdidi": {
        "tr": "Kendinizi riske atmayın, 155'i arayın.",
        "en": "Do not put yourself at risk; call the police.",
        "de": "Nicht in Gefahr bringen, Polizei rufen.",
        "fr": "Ne prenez pas de risque, appelez la police.",
        "es": "No se arriesgue, llame a la policía.",
        "ar": "لا تعرّض نفسك للخطر، اتصل بالشرطة.",
        "ru": "Не рискуйте, вызовите полицию.",
    },
    "diger": {
        "tr": "Olay yerine gidin.",
        "en": "Go to the location.",
        "de": "Zum Ort gehen.",
        "fr": "Rendez-vous sur place.",
        "es": "Vaya al lugar.",
        "ar": "توجّه إلى المكان.",
        "ru": "Идите на место.",
    },
}


def _dil(sozluk: dict[str, object], dil: str):
    return sozluk.get(dil) or sozluk["tr"]


def baslik(kategori: str | None, dil: str, *, tatbikat: bool = False) -> str:
    """Tam ekran / web katmani basligi. Tatbikatta "TATBIKAT — " onekli."""
    ana = (
        _dil(BASLIK[kategori], dil)
        if kategori in BASLIK
        else _dil(KATEGORISIZ_BASLIK, dil)
    )
    return f"{_dil(TATBIKAT, dil)} — {ana}" if tatbikat else ana


def talimat(kategori: str | None, dil: str) -> list[str]:
    """Adim adim talimat. Kategorisiz alarmda BOS: uydurma talimat yok."""
    if kategori not in TALIMAT:
        return []
    return list(_dil(TALIMAT[kategori], dil))
