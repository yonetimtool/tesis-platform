"""Push + in-app bildirim metinleri — 7 dil (tur 16).

NEDEN AYRI BIR MODUL: hata metinleri (tur 14) istegin `Accept-Language`
basligina gore uretilir. Push ASENKRONDUR — istek yoktur. Bu yuzden dil
GONDERIM aninda **cihaz kaydindan** okunur (`user_device.dil`, migration
0008) ve gonderim dile gore GRUPLANIR: ayni olay, farkli dildeki cihazlara
farkli metinle gider.

Kalici `notification` satiri da metin degil KIMLIK tasir
(`mesaj_kimlik` + `mesaj_veri`): in-app liste metni OKUMA aninda, istegin
dilinde uretir. Cumleyi kayda dondurmak, kaydi ilk yazan kullanicinin dilini
sonsuza kadar sabitlerdi.

Her kimlik iki metin verir: `baslik` (push basligi / bildirim etiketi) ve
`govde` (govde metni; `{param}` alanlari `mesaj_veri`den gelir).

YENI BILDIRIM EKLERKEN: 7 dilin HEPSI yazilir; eksik dil calisma aninda
Turkce'ye duser ve `test_push_i18n.py` ile yakalanir.
"""
from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field

from app.ceviri import DESTEKLENEN_DILLER, VARSAYILAN_DIL


@dataclass(frozen=True)
class PushMetni:
    """Bir bildirim kimliginin 7 dildeki basligi + govdesi."""

    baslik: Mapping[str, str]
    govde: Mapping[str, str]
    #: Govdedeki `{...}` alanlari — testte tum dillerde ayni olmasi dogrulanir.
    params: tuple[str, ...] = field(default=())


def _coz(metinler: Mapping[str, str], dil: str) -> str:
    return metinler.get(dil) or metinler.get(VARSAYILAN_DIL) or ""


def dil_normalize(dil: str | None) -> str:
    """Cihaz kaydindaki dili desteklenen kumeye indirger (yoksa `tr`)."""
    return dil if dil in DESTEKLENEN_DILLER else VARSAYILAN_DIL


def push_basligi(kimlik: str, dil: str = VARSAYILAN_DIL) -> str:
    kayit = METINLER.get(kimlik)
    return _coz(kayit.baslik, dil_normalize(dil)) if kayit else kimlik


def push_govdesi(
    kimlik: str,
    dil: str = VARSAYILAN_DIL,
    params: Mapping[str, object] | None = None,
) -> str:
    """Kimlik + dil + parametre -> gosterilecek metin.

    Bilinmeyen kimlik kimligin KENDISINI dondurur; parametre eksikse ham
    sablon doner. Ikisi de "bos bildirim" gostermekten iyidir ve testlerle
    yakalanir.
    """
    kayit = METINLER.get(kimlik)
    if kayit is None:
        return kimlik
    sablon = _coz(kayit.govde, dil_normalize(dil))
    if not params:
        return sablon
    try:
        metin = sablon.format(**params)
    except (KeyError, IndexError, ValueError):
        return sablon
    # (E2E 2026-09) BOS YER TUTUCU KUYRUGU: konumu olmayan alarm
    # "... kapatildi — -" diye bitiyordu. Tire yer tutucusu metinde
    # anlam tasimaz; ayraciyla birlikte atilir.
    if metin.endswith(" — -"):
        metin = metin[: -len(" — -")]
    return metin


# --------------------------------------------------------------------------- #
# Katalog — kimlik, `data.tip` ile AYNI degerdir (istemci yonlendirmesi orada).
# --------------------------------------------------------------------------- #
METINLER: dict[str, PushMetni] = {
    "kacirilan_tur": PushMetni(
        baslik={
            "tr": "Kaçırılan tur",
            "en": "Missed patrol",
            "ar": "جولة فائتة",
            "ru": "Пропущенный обход",
            "de": "Verpasster Rundgang",
            "fr": "Ronde manquée",
            "es": "Ronda perdida",
        },
        govde={
            "tr": "{plan} turu kaçırıldı ({eksik} eksik kontrol noktası).",
            "en": "The {plan} patrol was missed ({eksik} checkpoints missing).",
            "ar": "تم تفويت جولة {plan} ({eksik} نقاط تفتيش ناقصة).",
            "ru": "Обход «{plan}» пропущен (не отмечено контрольных точек: {eksik}).",
            "de": "Der Rundgang {plan} wurde verpasst ({eksik} fehlende Kontrollpunkte).",
            "fr": "La ronde {plan} a été manquée ({eksik} points de contrôle manquants).",
            "es": "Se perdió la ronda {plan} ({eksik} puntos de control faltantes).",
        },
        params=('plan', 'eksik'),
    ),
    # (P181 Bölüm 10.2) VARDIYA OZETI — vardiya sonu TEK bildirim (batching):
    # o vardiyada kac noktanin okutuldugu. Okutmalar tek tek push URETMEZ.
    # ---------------- (P207 §3) VARDIYA HATIRLATMA -------------------- #
    "vardiya_hatirlatma": PushMetni(
        baslik={
            "tr": "Vardiya hatırlatması",
            "en": "Shift reminder",
            "ar": "تذكير بالوردية",
            "ru": "Напоминание о смене",
            "de": "Schichterinnerung",
            "fr": "Rappel de poste",
            "es": "Recordatorio de turno",
        },
        govde={
            "tr": "Vardiyanıza {dakika} dakika kaldı ({saat}).",
            "en": "Your shift starts in {dakika} minutes ({saat}).",
            "ar": "تبدأ ورديتك خلال {dakika} دقيقة ({saat}).",
            "ru": "Ваша смена начнётся через {dakika} мин. ({saat}).",
            "de": "Ihre Schicht beginnt in {dakika} Minuten ({saat}).",
            "fr": "Votre poste commence dans {dakika} minutes ({saat}).",
            "es": "Su turno comienza en {dakika} minutos ({saat}).",
        },
        params=('dakika', 'saat'),
    ),
    "vardiya_baslamadi": PushMetni(
        baslik={
            "tr": "Vardiya başlamadı",
            "en": "Shift not started",
            "ar": "لم تبدأ الوردية",
            "ru": "Смена не начата",
            "de": "Schicht nicht begonnen",
            "fr": "Poste non commencé",
            "es": "Turno no iniciado",
        },
        govde={
            "tr": "{kisi} ({saat}) vardiyasına başlamadı: {dakika} dakikadır okutma yok.",
            "en": "{kisi} has not started the {saat} shift: no scan for {dakika} minutes.",
            "ar": "{kisi} لم يبدأ وردية {saat}: لا يوجد مسح منذ {dakika} دقيقة.",
            "ru": "{kisi} не начал смену {saat}: нет отметок уже {dakika} мин.",
            "de": "{kisi} hat die Schicht um {saat} nicht begonnen: seit {dakika} Minuten keine Erfassung.",
            "fr": "{kisi} n'a pas commencé le poste de {saat} : aucun scan depuis {dakika} minutes.",
            "es": "{kisi} no ha iniciado el turno de {saat}: sin escaneos desde hace {dakika} minutos.",
        },
        params=('kisi', 'saat', 'dakika'),
    ),
    "vardiya_ozeti": PushMetni(
        baslik={
            "tr": "Vardiya özeti",
            "en": "Shift summary",
            "ar": "ملخص الوردية",
            "ru": "Итоги смены",
            "de": "Schichtzusammenfassung",
            "fr": "Résumé du service",
            "es": "Resumen del turno",
        },
        govde={
            "tr": "{vardiya} ({gun}) tamamlandı: {okutulan}/{beklenen} nokta okutuldu.",
            "en": "{vardiya} ({gun}) completed: {okutulan}/{beklenen} points scanned.",
            "ar": "اكتملت {vardiya} ({gun}): تم مسح {okutulan}/{beklenen} نقطة.",
            "ru": "{vardiya} ({gun}) завершена: отмечено точек {okutulan}/{beklenen}.",
            "de": "{vardiya} ({gun}) abgeschlossen: {okutulan}/{beklenen} Punkte erfasst.",
            "fr": "{vardiya} ({gun}) terminé : {okutulan}/{beklenen} points scannés.",
            "es": "{vardiya} ({gun}) completado: {okutulan}/{beklenen} puntos escaneados.",
        },
        params=('vardiya', 'gun', 'okutulan', 'beklenen'),
    ),
    # (P34) Gecikmis okutma: pencere ACILDI ama tolerans suresi icinde
    # okutma GELMEDI. "Kacirildi"dan farki: tur HALA KURTARILABILIR —
    # bu yuzden metin gecmis zaman degil UYARI dilidir.
    "gecikmis_okutma": PushMetni(
        baslik={
            "tr": "Tur başlamadı",
            "en": "Patrol not started",
            "ar": "لم تبدأ الجولة",
            "ru": "Обход не начат",
            "de": "Rundgang nicht begonnen",
            "fr": "Ronde non commencée",
            "es": "Ronda no iniciada",
        },
        govde={
            "tr": "{plan} turunda {dakika} dakikadır okutma yok.",
            "en": "No scan for {dakika} minutes on the {plan} patrol.",
            "ar": "لا يوجد مسح منذ {dakika} دقيقة في جولة {plan}.",
            "ru": "В обходе «{plan}» нет отметок уже {dakika} мин.",
            "de": "Seit {dakika} Minuten keine Erfassung im Rundgang {plan}.",
            "fr": "Aucun scan depuis {dakika} minutes sur la ronde {plan}.",
            "es": "Sin escaneos desde hace {dakika} minutos en la ronda {plan}.",
        },
        params=('plan', 'dakika'),
    ),
    # (P160) UZAK OKUTMA: okutma yapildi ve zamanindaydi ama noktadan
    # esikten uzakta yapildi. METIN OLCUM BILDIRIR, SUC ATFETMEZ —
    # "ihlal"/"supheli" gecmez ve gorevlinin ADI metne girmez (kayit
    # zaten kimin okuttugunu tutuyor).
    "uzak_okutma": PushMetni(
        baslik={
            "tr": "Uzak okutma",
            "en": "Distant scan",
            "ar": "مسح بعيد",
            "ru": "Отметка вдали от точки",
            "de": "Entfernte Erfassung",
            "fr": "Scan éloigné",
            "es": "Escaneo lejano",
        },
        govde={
            "tr": "{nokta} noktası {mesafe} m uzaktan okutuldu (eşik {esik} m).",
            "en": "{nokta} was scanned {mesafe} m away (threshold {esik} m).",
            "ar": "تم مسح {nokta} من مسافة {mesafe} م (الحد {esik} م).",
            "ru": "Точка «{nokta}» отмечена в {mesafe} м (порог {esik} м).",
            "de": "{nokta} wurde aus {mesafe} m Entfernung erfasst (Grenze {esik} m).",
            "fr": "{nokta} a été scanné à {mesafe} m (seuil {esik} m).",
            "es": "{nokta} se escaneó a {mesafe} m (umbral {esik} m).",
        },
        params=("nokta", "mesafe", "esik"),
    ),
    # (P37) MANUEL MOD: entegrasyonu olmayan sitede anonsu YONETICI yapar.
    # ---------------- (P208 §1) GURULTU: SAKIN + YONETIM ---------------- #
    #
    # SIKAYET EDENIN KIMLIGI ASLA GECMEZ. Metinde ne kisi, ne daire, ne
    # de SAYI var: sayi yazmak, sakini "kim sikayet etti" aramaya iter
    # (bes kisilik bir koridorda bes sikayet, herkesi isaret eder).
    # Mesajin isi DAVRANISI DEGISTIRMEK, muhasebe yapmak degil.
    #
    # TON NOTR: uyari bir CEZA DEGIL hatirlatmadir ve hakkinda haksiz
    # sikayet birikmis bir daireye de aynen gider (P37 karari).
    "gurultu_uyari_sakin": PushMetni(
        baslik={
            "tr": "Gürültü uyarısı",
            "en": "Noise notice",
            "ar": "تنبيه بشأن الضوضاء",
            "ru": "Уведомление о шуме",
            "de": "Lärmhinweis",
            "fr": "Avis de bruit",
            "es": "Aviso por ruido",
        },
        govde={
            "tr": "Daireniz hakkında gürültü şikâyeti alındı. Lütfen komşularınıza karşı dikkatli olun.",
            "en": "A noise complaint has been received about your home. Please be considerate of your neighbours.",
            "ar": "وردت شكوى بشأن الضوضاء من وحدتك. يرجى مراعاة جيرانك.",
            "ru": "Поступила жалоба на шум из вашей квартиры. Пожалуйста, будьте внимательны к соседям.",
            "de": "Zu Ihrer Wohnung ist eine Lärmbeschwerde eingegangen. Bitte nehmen Sie Rücksicht auf Ihre Nachbarn.",
            "fr": "Une plainte pour bruit concernant votre logement a été reçue. Merci d'être attentif à vos voisins.",
            "es": "Se ha recibido una queja por ruido sobre su vivienda. Por favor, tenga consideración con sus vecinos.",
        },
        params=(),
    ),
    # YONETIME GIDEN AYRI BILDIRIM: burada SAYI VAR cunku yoneticinin
    # isi ilgilenmek ve gerekirse yuz yuze konusmak — karar verebilmesi
    # icin buyuklugu bilmeli. Sikayet EDENIN kimligi burada da YOK.
    "gurultu_esik_yonetim": PushMetni(
        baslik={
            "tr": "Gürültü eşiği aşıldı",
            "en": "Noise threshold reached",
            "ar": "تم بلوغ حد الضوضاء",
            "ru": "Достигнут порог по шуму",
            "de": "Lärmschwelle erreicht",
            "fr": "Seuil de bruit atteint",
            "es": "Umbral de ruido alcanzado",
        },
        govde={
            "tr": "{daire} dairesi için {sayi} gürültü şikâyeti birikti; sakine uyarı bildirimi gönderildi.",
            "en": "{sayi} noise complaints have accumulated for unit {daire}; a notice was sent to the resident.",
            "ar": "تراكمت {sayi} شكاوى ضوضاء بشأن الوحدة {daire}؛ وأُرسل تنبيه إلى الساكن.",
            "ru": "По квартире {daire} накопилось жалоб на шум: {sayi}; жильцу отправлено уведомление.",
            "de": "Für Einheit {daire} liegen {sayi} Lärmbeschwerden vor; der Bewohner wurde benachrichtigt.",
            "fr": "{sayi} plaintes pour bruit concernent le logement {daire} ; un avis a été envoyé au résident.",
            "es": "Se han acumulado {sayi} quejas por ruido en la vivienda {daire}; se avisó al residente.",
        },
        params=('daire', 'sayi'),
    ),
    # ==================================================================
    # (P212 §3) ESKALASYON — IKINCI ESIKTE GUVENLIGE
    # ==================================================================
    # SIKAYET EDENIN KIMLIGI YINE YOK. Gecen sey DAIRE (guvenligin
    # gidecegi yer), SAYI ve KACINCI kez oldugu — guvenlik gorevlisinin
    # ne kadar ciddi bir durumla karsi karsiya oldugunu bilmesi icin.
    #
    # "POLISE HABER VERINIZ" METNI BILINCLI VE SINIRLI: sistem KIMSEYI
    # ARAMAZ. Arama karari ve eylemi gorevlinindir; yazilim yalnizca
    # bilgiyi ve onerilen adimi iletir. Otomatik arama, yanlis alarmda
    # kamu kaynagini bosuna mesgul etmek ve sorumlulugu yazilima
    # yuklemek olurdu.
    "gurultu_eskalasyon_guvenlik": PushMetni(
        baslik={
            "tr": "Gürültü: güvenlik müdahalesi gerekiyor",
            "en": "Noise: security response needed",
            "ar": "ضوضاء: مطلوب تدخل أمني",
            "ru": "Шум: требуется вмешательство охраны",
            "de": "Lärm: Sicherheitsmaßnahme erforderlich",
            "fr": "Bruit : intervention de sécurité nécessaire",
            "es": "Ruido: se requiere intervención de seguridad",
        },
        govde={
            "tr": "{daire} dairesi için {kez}. kez {sayi} gürültü şikâyeti birikti. Lütfen kontrol edin ve gerekirse polise haber veriniz.",
            "en": "Unit {daire} has reached {sayi} noise complaints for the {kez}. time. Please check and notify the police if necessary.",
            "ar": "بلغت الوحدة {daire} {sayi} شكاوى ضوضاء للمرة {kez}. يرجى التحقق وإبلاغ الشرطة عند الحاجة.",
            "ru": "По квартире {daire} уже {kez}-й раз накопилось жалоб на шум: {sayi}. Проверьте и при необходимости сообщите в полицию.",
            "de": "Für Einheit {daire} sind zum {kez}. Mal {sayi} Lärmbeschwerden eingegangen. Bitte prüfen und nötigenfalls die Polizei verständigen.",
            "fr": "Le logement {daire} atteint {sayi} plaintes pour bruit pour la {kez}e fois. Veuillez vérifier et prévenir la police si nécessaire.",
            "es": "La vivienda {daire} ha alcanzado {sayi} quejas por ruido por {kez}.ª vez. Compruébelo y avise a la policía si es necesario.",
        },
        params=('daire', 'sayi', 'kez'),
    ),
    # YONETIME AYRI BILGI: eskalasyonun OLDUGUNU bilmeli (guvenlik
    # gorevlisi vardiyada olmayabilir ve o zaman tek haberdar olan
    # yonetici olur — bkz. docs/P212-kararlar.md §3).
    "gurultu_eskalasyon_yonetim": PushMetni(
        baslik={
            "tr": "Gürültü eşiği yeniden aşıldı",
            "en": "Noise threshold reached again",
            "ar": "تم بلوغ حد الضوضاء مجددًا",
            "ru": "Порог по шуму снова достигнут",
            "de": "Lärmschwelle erneut erreicht",
            "fr": "Seuil de bruit à nouveau atteint",
            "es": "Umbral de ruido alcanzado de nuevo",
        },
        govde={
            "tr": "{daire} dairesi için {kez}. kez {sayi} gürültü şikâyeti birikti; güvenliğe bildirim gönderildi.",
            "en": "Unit {daire} reached {sayi} noise complaints for the {kez}. time; security has been notified.",
            "ar": "بلغت الوحدة {daire} {sayi} شكاوى ضوضاء للمرة {kez}؛ وتم إبلاغ الأمن.",
            "ru": "По квартире {daire} {kez}-й раз накопилось жалоб на шум: {sayi}; охрана уведомлена.",
            "de": "Für Einheit {daire} wurden zum {kez}. Mal {sayi} Lärmbeschwerden erreicht; die Sicherheit wurde benachrichtigt.",
            "fr": "Le logement {daire} atteint {sayi} plaintes pour bruit pour la {kez}e fois ; la sécurité a été prévenue.",
            "es": "La vivienda {daire} alcanzó {sayi} quejas por ruido por {kez}.ª vez; se avisó a seguridad.",
        },
        params=('daire', 'sayi', 'kez'),
    ),
    "gurultu_uyarisi": PushMetni(
        baslik={
            "tr": "Gürültü uyarısı gerekiyor",
            "en": "Noise warning needed",
            "ar": "مطلوب تحذير بشأن الضوضاء",
            "ru": "Требуется предупреждение о шуме",
            "de": "Lärmwarnung erforderlich",
            "fr": "Avertissement bruit requis",
            "es": "Se requiere aviso por ruido",
        },
        govde={
            "tr": "{daire} dairesi eşiğe ulaştı ({sayi} şikâyet). Lütfen uyarı anonsunu yapın.",
            "en": "Unit {daire} reached the threshold ({sayi} complaints). Please make the announcement.",
            "ar": "وصلت الوحدة {daire} إلى الحد ({sayi} شكاوى). يرجى إجراء الإعلان.",
            "ru": "Квартира {daire} достигла порога ({sayi} жалоб). Пожалуйста, сделайте объявление.",
            "de": "Einheit {daire} hat den Schwellenwert erreicht ({sayi} Beschwerden). Bitte Durchsage machen.",
            "fr": "Le logement {daire} a atteint le seuil ({sayi} plaintes). Veuillez faire l'annonce.",
            "es": "La vivienda {daire} alcanzó el umbral ({sayi} quejas). Haga el aviso, por favor.",
        },
        params=('daire', 'sayi'),
    ),
    # (P38) Portal iletisim formu — KAYIT ONCE, BILDIRIM SONRA.
    "portal_iletisim": PushMetni(
        baslik={
            "tr": "Site sayfasından mesaj",
            "en": "Message from the site page",
            "ar": "رسالة من صفحة الموقع",
            "ru": "Сообщение со страницы объекта",
            "de": "Nachricht von der Seite",
            "fr": "Message depuis la page du site",
            "es": "Mensaje desde la página del sitio",
        },
        govde={
            "tr": "{ad} iletişim formundan mesaj gönderdi.",
            "en": "{ad} sent a message through the contact form.",
            "ar": "أرسل {ad} رسالة عبر نموذج الاتصال.",
            "ru": "{ad} отправил(а) сообщение через форму связи.",
            "de": "{ad} hat eine Nachricht über das Kontaktformular gesendet.",
            "fr": "{ad} a envoyé un message via le formulaire de contact.",
            "es": "{ad} envió un mensaje mediante el formulario de contacto.",
        },
        params=('ad',),
    ),
    "yeni_talep": PushMetni(
        baslik={
            "tr": "Talep / Arıza",
            "en": "Request / Fault",
            "ar": "طلب / عطل",
            "ru": "Заявка / неисправность",
            "de": "Anfrage / Störung",
            "fr": "Demande / panne",
            "es": "Solicitud / avería",
        },
        govde={
            "tr": "Yeni talep: {baslik}",
            "en": "New request: {baslik}",
            "ar": "طلب جديد: {baslik}",
            "ru": "Новая заявка: {baslik}",
            "de": "Neue Anfrage: {baslik}",
            "fr": "Nouvelle demande : {baslik}",
            "es": "Nueva solicitud: {baslik}",
        },
        params=('baslik',),
    ),
    # Talep yanitlari: kimlik = `notification`/`data.tip` degeri ile AYNI.
    # Tek bir "talep_yaniti" + {durum} parametresi YERINE uc ayri kimlik:
    # durum bir SOZCUK olurdu ve onun da cevrilmesi gerekirdi (metni parametre
    # olarak tasimak, cevrilecek metni gizlemenin baska bir yoludur).
    "talep_is_emri": PushMetni(
        baslik={
            "tr": "Talebiniz güncellendi",
            "en": "Your request was updated",
            "ar": "تم تحديث طلبك",
            "ru": "Ваша заявка обновлена",
            "de": "Ihre Anfrage wurde aktualisiert",
            "fr": "Votre demande a été mise à jour",
            "es": "Su solicitud se actualizó",
        },
        govde={
            "tr": "Talebiniz iş emrine dönüştürüldü: {baslik}",
            "en": "Your request was turned into a work order: {baslik}",
            "ar": "تم تحويل طلبك إلى أمر عمل: {baslik}",
            "ru": "Ваша заявка преобразована в наряд: {baslik}",
            "de": "Ihre Anfrage wurde in einen Arbeitsauftrag umgewandelt: {baslik}",
            "fr": "Votre demande a été convertie en ordre de travail : {baslik}",
            "es": "Su solicitud se convirtió en una orden de trabajo: {baslik}",
        },
        params=("baslik",),
    ),
    "talep_cozuldu": PushMetni(
        baslik={
            "tr": "Talebiniz çözüldü",
            "en": "Your request was resolved",
            "ar": "تم حل طلبك",
            "ru": "Ваша заявка решена",
            "de": "Ihre Anfrage wurde gelöst",
            "fr": "Votre demande a été résolue",
            "es": "Su solicitud fue resuelta",
        },
        govde={
            "tr": "Talebiniz çözüldü: {baslik}",
            "en": "Your request was resolved: {baslik}",
            "ar": "تم حل طلبك: {baslik}",
            "ru": "Ваша заявка решена: {baslik}",
            "de": "Ihre Anfrage wurde gelöst: {baslik}",
            "fr": "Votre demande a été résolue : {baslik}",
            "es": "Su solicitud fue resuelta: {baslik}",
        },
        params=("baslik",),
    ),
    "talep_reddedildi": PushMetni(
        baslik={
            "tr": "Talebiniz reddedildi",
            "en": "Your request was rejected",
            "ar": "تم رفض طلبك",
            "ru": "Ваша заявка отклонена",
            "de": "Ihre Anfrage wurde abgelehnt",
            "fr": "Votre demande a été rejetée",
            "es": "Su solicitud fue rechazada",
        },
        govde={
            "tr": "Talebiniz reddedildi: {baslik}",
            "en": "Your request was rejected: {baslik}",
            "ar": "تم رفض طلبك: {baslik}",
            "ru": "Ваша заявка отклонена: {baslik}",
            "de": "Ihre Anfrage wurde abgelehnt: {baslik}",
            "fr": "Votre demande a été rejetée : {baslik}",
            "es": "Su solicitud fue rechazada: {baslik}",
        },
        params=("baslik",),
    ),
    "is_emri_atandi": PushMetni(
        baslik={
            "tr": "İş emri",
            "en": "Work order",
            "ar": "أمر عمل",
            "ru": "Наряд",
            "de": "Arbeitsauftrag",
            "fr": "Ordre de travail",
            "es": "Orden de trabajo",
        },
        govde={
            "tr": "Size iş emri atandı: {baslik}",
            "en": "A work order was assigned to you: {baslik}",
            "ar": "تم إسناد أمر عمل إليك: {baslik}",
            "ru": "Вам назначен наряд: {baslik}",
            "de": "Ihnen wurde ein Arbeitsauftrag zugewiesen: {baslik}",
            "fr": "Un ordre de travail vous a été attribué : {baslik}",
            "es": "Se le asignó una orden de trabajo: {baslik}",
        },
        params=('baslik',),
    ),
    "duyuru": PushMetni(
        baslik={
            "tr": "Duyuru",
            "en": "Announcement",
            "ar": "إعلان",
            "ru": "Объявление",
            "de": "Ankündigung",
            "fr": "Annonce",
            "es": "Anuncio",
        },
        govde={
            "tr": "{baslik}",
            "en": "{baslik}",
            "ar": "{baslik}",
            "ru": "{baslik}",
            "de": "{baslik}",
            "fr": "{baslik}",
            "es": "{baslik}",
        },
        params=('baslik',),
    ),
    "etkinlik": PushMetni(
        baslik={
            "tr": "Etkinlik",
            "en": "Event",
            "ar": "فعالية",
            "ru": "Мероприятие",
            "de": "Veranstaltung",
            "fr": "Événement",
            "es": "Evento",
        },
        govde={
            "tr": "Yeni etkinlik: {baslik} — {zaman}",
            "en": "New event: {baslik} — {zaman}",
            "ar": "فعالية جديدة: {baslik} — {zaman}",
            "ru": "Новое мероприятие: {baslik} — {zaman}",
            "de": "Neue Veranstaltung: {baslik} — {zaman}",
            "fr": "Nouvel événement : {baslik} — {zaman}",
            "es": "Nuevo evento: {baslik} — {zaman}",
        },
        params=('baslik', 'zaman'),
    ),
    "kargo": PushMetni(
        baslik={
            "tr": "Kargo",
            "en": "Parcel",
            "ar": "طرد",
            "ru": "Посылка",
            "de": "Paket",
            "fr": "Colis",
            "es": "Paquete",
        },
        govde={
            "tr": "Kargonuz geldi — {firma} ({daire})",
            "en": "Your parcel has arrived — {firma} ({daire})",
            "ar": "وصل طردك — {firma} ({daire})",
            "ru": "Ваша посылка прибыла — {firma} ({daire})",
            "de": "Ihr Paket ist angekommen — {firma} ({daire})",
            "fr": "Votre colis est arrivé — {firma} ({daire})",
            "es": "Su paquete ha llegado — {firma} ({daire})",
        },
        params=('firma', 'daire'),
    ),
    # (P247 §3) Guvenlik kargoyu sakine TESLIM ETTI — dairenin sakinlerine.
    "kargo_teslim": PushMetni(
        baslik={
            "tr": "Kargo teslim edildi",
            "en": "Parcel handed over",
            "ar": "تم تسليم الطرد",
            "ru": "Посылка выдана",
            "de": "Paket übergeben",
            "fr": "Colis remis",
            "es": "Paquete entregado",
        },
        govde={
            "tr": "Kargonuz güvenlik tarafından teslim edildi — {firma} ({daire})",
            "en": "Your parcel was handed over by security — {firma} ({daire})",
            "ar": "سلّم الأمن طردك — {firma} ({daire})",
            "ru": "Охрана выдала вашу посылку — {firma} ({daire})",
            "de": "Ihr Paket wurde vom Sicherheitsdienst übergeben — {firma} ({daire})",
            "fr": "Votre colis a été remis par la sécurité — {firma} ({daire})",
            "es": "Seguridad entregó su paquete — {firma} ({daire})",
        },
        params=('firma', 'daire'),
    ),
    "ziyaretci": PushMetni(
        baslik={
            "tr": "Ziyaretçi",
            "en": "Visitor",
            "ar": "زائر",
            "ru": "Посетитель",
            "de": "Besucher",
            "fr": "Visiteur",
            "es": "Visitante",
        },
        govde={
            "tr": "Ziyaretçiniz kaydedildi: {ad} — {daire}",
            "en": "Your visitor was registered: {ad} — {daire}",
            "ar": "تم تسجيل زائرك: {ad} — {daire}",
            "ru": "Ваш посетитель зарегистрирован: {ad} — {daire}",
            "de": "Ihr Besucher wurde erfasst: {ad} — {daire}",
            "fr": "Votre visiteur a été enregistré : {ad} — {daire}",
            "es": "Su visitante fue registrado: {ad} — {daire}",
        },
        params=('ad', 'daire'),
    ),
    "erisim_talebi": PushMetni(
        baslik={
            "tr": "Görüntüleme izni talebi",
            "en": "View permission request",
            "ar": "طلب إذن اطّلاع",
            "ru": "Запрос на доступ к просмотру",
            "de": "Anfrage für Anzeigeberechtigung",
            "fr": "Demande d'autorisation de consultation",
            "es": "Solicitud de permiso de consulta",
        },
        govde={
            "tr": "{ad}, {daire} ziyaretçi/kargo kayıtlarını görmek istiyor.",
            "en": "{ad} wants to view the visitor/parcel records of {daire}.",
            "ar": "يريد {ad} الاطّلاع على سجلات الزوار/الطرود للوحدة {daire}.",
            "ru": "{ad} хочет просмотреть записи о посетителях/посылках кв. {daire}.",
            "de": "{ad} möchte die Besucher-/Paketdatensätze von {daire} einsehen.",
            "fr": "{ad} souhaite consulter les enregistrements visiteurs/colis de {daire}.",
            "es": "{ad} quiere ver los registros de visitantes/paquetes de {daire}.",
        },
        params=('ad', 'daire'),
    ),
    # Sonuc bildirimi: karar (onay/red) KIMLIGE girer — "onaylandi" sozcugunu
    # parametre olarak tasimak, cevrilecek metni gizlemek olurdu.
    "erisim_onaylandi": PushMetni(
        baslik={
            "tr": "Görüntüleme izni sonucu",
            "en": "View permission result",
            "ar": "نتيجة إذن الاطّلاع",
            "ru": "Результат запроса на просмотр",
            "de": "Ergebnis der Anzeigeberechtigung",
            "fr": "Résultat de l'autorisation de consultation",
            "es": "Resultado del permiso de consulta",
        },
        govde={
            "tr": "{daire} görüntüleme izni onaylandı ({ad}).",
            "en": "View permission for {daire} was approved ({ad}).",
            "ar": "تمت الموافقة على إذن الاطّلاع للوحدة {daire} ({ad}).",
            "ru": "Доступ к просмотру кв. {daire} одобрен ({ad}).",
            "de": "Die Anzeigeberechtigung für {daire} wurde genehmigt ({ad}).",
            "fr": "L'autorisation de consultation pour {daire} a été approuvée ({ad}).",
            "es": "Se aprobó el permiso de consulta para {daire} ({ad}).",
        },
        params=("daire", "ad"),
    ),
    "erisim_reddedildi": PushMetni(
        baslik={
            "tr": "Görüntüleme izni sonucu",
            "en": "View permission result",
            "ar": "نتيجة إذن الاطّلاع",
            "ru": "Результат запроса на просмотр",
            "de": "Ergebnis der Anzeigeberechtigung",
            "fr": "Résultat de l'autorisation de consultation",
            "es": "Resultado del permiso de consulta",
        },
        govde={
            "tr": "{daire} görüntüleme izni reddedildi ({ad}).",
            "en": "View permission for {daire} was rejected ({ad}).",
            "ar": "تم رفض إذن الاطّلاع للوحدة {daire} ({ad}).",
            "ru": "Доступ к просмотру кв. {daire} отклонён ({ad}).",
            "de": "Die Anzeigeberechtigung für {daire} wurde abgelehnt ({ad}).",
            "fr": "L'autorisation de consultation pour {daire} a été refusée ({ad}).",
            "es": "Se rechazó el permiso de consulta para {daire} ({ad}).",
        },
        params=("daire", "ad"),
    ),
    "sikayet_cozuldu": PushMetni(
        baslik={
            "tr": "Şikayetiniz",
            "en": "Your complaint",
            "ar": "شكواك",
            "ru": "Ваша жалоба",
            "de": "Ihre Beschwerde",
            "fr": "Votre plainte",
            "es": "Su queja",
        },
        govde={
            "tr": "Şikayetiniz sonuçlandırıldı ({daire})",
            "en": "Your complaint has been resolved ({daire})",
            "ar": "تمت معالجة شكواك ({daire})",
            "ru": "Ваша жалоба рассмотрена ({daire})",
            "de": "Ihre Beschwerde wurde bearbeitet ({daire})",
            "fr": "Votre plainte a été traitée ({daire})",
            "es": "Su queja ha sido resuelta ({daire})",
        },
        params=('daire',),
    ),
    "rezervasyon": PushMetni(
        baslik={
            "tr": "Rezervasyon",
            "en": "Reservation",
            "ar": "حجز",
            "ru": "Бронирование",
            "de": "Reservierung",
            "fr": "Réservation",
            "es": "Reserva",
        },
        govde={
            "tr": "Rezervasyonunuz onaylandı: {alan} — {tarih} {baslangic}-{bitis}",
            "en": "Your reservation is confirmed: {alan} — {tarih} {baslangic}-{bitis}",
            "ar": "تم تأكيد حجزك: {alan} — {tarih} {baslangic}-{bitis}",
            "ru": "Ваше бронирование подтверждено: {alan} — {tarih} {baslangic}-{bitis}",
            "de": "Ihre Reservierung ist bestätigt: {alan} — {tarih} {baslangic}-{bitis}",
            "fr": "Votre réservation est confirmée : {alan} — {tarih} {baslangic}-{bitis}",
            "es": "Su reserva está confirmada: {alan} — {tarih} {baslangic}-{bitis}",
        },
        params=('alan', 'tarih', 'baslangic', 'bitis'),
    ),
    # ---------------------------------------------------------------- #
    # (P191 §2) EKSIK OLAN UC BILDIRIM.
    #
    # `gorev_atandi` ve `aidat_borc` icin push cagrisi HIC YOKTU — "gorev
    # olusturdum, telefona bildirim gelmedi" sikayetinin kok nedeni buydu.
    # `test` ise yoneticinin zinciri KENDI cihazinda denemesi icin
    # (`POST /push/test`): "calisiyor mu?" sorusu tahminle degil deneyerek
    # cevaplanmali.
    # ---------------------------------------------------------------- #
    "gorev_atandi": PushMetni(
        baslik={
            "tr": "Yeni görev",
            "en": "New task",
            "ar": "مهمة جديدة",
            "ru": "Новая задача",
            "de": "Neue Aufgabe",
            "fr": "Nouvelle tâche",
            "es": "Nueva tarea",
        },
        govde={
            "tr": "Size bir görev atandı: {baslik}",
            "en": "A task was assigned to you: {baslik}",
            "ar": "تم تعيين مهمة لك: {baslik}",
            "ru": "Вам назначена задача: {baslik}",
            "de": "Ihnen wurde eine Aufgabe zugewiesen: {baslik}",
            "fr": "Une tâche vous a été attribuée : {baslik}",
            "es": "Se le ha asignado una tarea: {baslik}",
        },
        params=('baslik',),
    ),
    # (P229 §3) Gorev TAMAMLANDI — yonetime.
    "gorev_tamamlandi": PushMetni(
        baslik={
            "tr": "Görev tamamlandı",
            "en": "Task completed",
            "ar": "اكتملت المهمة",
            "ru": "Задача выполнена",
            "de": "Aufgabe abgeschlossen",
            "fr": "Tâche terminée",
            "es": "Tarea completada",
        },
        govde={
            "tr": "{kisi} şu görevi tamamladı: {baslik}",
            "en": "{kisi} completed the task: {baslik}",
            "ar": "أنجز {kisi} المهمة: {baslik}",
            "ru": "{kisi} выполнил(а) задачу: {baslik}",
            "de": "{kisi} hat die Aufgabe abgeschlossen: {baslik}",
            "fr": "{kisi} a terminé la tâche : {baslik}",
            "es": "{kisi} ha completado la tarea: {baslik}",
        },
        params=('kisi', 'baslik'),
    ),
    # (P237 §2) ADIM ILERLEMESI — ESIKLI/TOPLU gonderilir (bkz. tasks.py
    # KARAR 4). Govde SON BITEN ADIMI ve TOPLAM ILERLEMEYI birlikte tasir:
    # bildirimler arasinda birden fazla adim bitmis olabilir, yalniz
    # sonuncuyu yazmak aradaki ilerlemeyi gizlerdi.
    "gorev_adim_ilerleme": PushMetni(
        baslik={
            "tr": "Görev ilerliyor",
            "en": "Task progress",
            "ar": "تقدم المهمة",
            "ru": "Ход задачи",
            "de": "Aufgabenfortschritt",
            "fr": "Avancement de la tâche",
            "es": "Progreso de la tarea",
        },
        govde={
            "tr": "{baslik}: {tamam}/{toplam} adım tamamlandı — son: {adim} ({kisi})",
            "en": "{baslik}: {tamam}/{toplam} steps done — latest: {adim} ({kisi})",
            "ar": "{baslik}: {tamam}/{toplam} خطوة مكتملة — الأخيرة: {adim} ({kisi})",
            "ru": "{baslik}: выполнено {tamam}/{toplam} шагов — последний: {adim} ({kisi})",
            "de": "{baslik}: {tamam}/{toplam} Schritte erledigt — zuletzt: {adim} ({kisi})",
            "fr": "{baslik} : {tamam}/{toplam} étapes terminées — dernière : {adim} ({kisi})",
            "es": "{baslik}: {tamam}/{toplam} pasos completados — último: {adim} ({kisi})",
        },
        params=('baslik', 'tamam', 'toplam', 'adim', 'kisi'),
    ),
    # (P237 §3) ANKET ACILDI — HEDEF KITLEYE. `duyuru`ya bindirilmedi:
    # bildirim tercihinde "duyurulari al, anket bildirimini alma" demek
    # mumkun kalmali.
    # (P240 §1) PANIK — UC TIP TEK KIMLIK.
    #
    # Tip (`sakin`/`guvenlik`/`yonetici_anons`) govdeye PARAMETRE olarak
    # girmez: push basligi UC SANIYEDE okunmali ve "ACIL" kelimesi
    # zaten en yuksek sinyaldir. Tipe gore uc ayri kimlik acmak,
    # kullaniciya bildirim ayarlarinda uc ayri anahtar gostermek ve
    # birini kapatabilmesi demekti — panikte bu kabul edilemez.
    "panik_alarm": PushMetni(
        baslik={
            "tr": "ACİL DURUM",
            "en": "EMERGENCY",
            "ar": "حالة طوارئ",
            "ru": "ЭКСТРЕННЫЙ ВЫЗОВ",
            "de": "NOTFALL",
            "fr": "URGENCE",
            "es": "EMERGENCIA",
        },
        govde={
            "tr": "{ad} yardım istedi — {yer}",
            "en": "{ad} called for help — {yer}",
            "ar": "{ad} طلب المساعدة — {yer}",
            "ru": "{ad} просит помощи — {yer}",
            "de": "{ad} braucht Hilfe — {yer}",
            "fr": "{ad} demande de l’aide — {yer}",
            "es": "{ad} pidió ayuda — {yer}",
        },
        params=('ad', 'yer'),
    ),
    "panik_yanlis_alarm": PushMetni(
        baslik={
            "tr": "Yanlış alarm",
            "en": "False alarm",
            "ar": "إنذار خاطئ",
            "ru": "Ложная тревога",
            "de": "Fehlalarm",
            "fr": "Fausse alerte",
            "es": "Falsa alarma",
        },
        govde={
            "tr": "{ad} alarmı geri aldı — {yer}",
            "en": "{ad} withdrew the alarm — {yer}",
            "ar": "{ad} تراجع عن الإنذار — {yer}",
            "ru": "{ad} отменил(а) тревогу — {yer}",
            "de": "{ad} hat den Alarm zurückgezogen — {yer}",
            "fr": "{ad} a retiré l’alerte — {yer}",
            "es": "{ad} retiró la alarma — {yer}",
        },
        params=('ad', 'yer'),
    ),
    "panik_kapandi": PushMetni(
        baslik={
            "tr": "Alarm kapandı",
            "en": "Alarm closed",
            "ar": "أُغلق الإنذار",
            "ru": "Тревога закрыта",
            "de": "Alarm geschlossen",
            "fr": "Alerte clôturée",
            "es": "Alarma cerrada",
        },
        govde={
            "tr": "{ad} tarafından açılan alarm kapatıldı — {yer}",
            "en": "The alarm raised by {ad} was closed — {yer}",
            "ar": "تم إغلاق الإنذار الذي أطلقه {ad} — {yer}",
            "ru": "Тревога, поднятая {ad}, закрыта — {yer}",
            "de": "Der von {ad} ausgelöste Alarm wurde geschlossen — {yer}",
            "fr": "L’alerte lancée par {ad} a été clôturée — {yer}",
            "es": "La alarma activada por {ad} fue cerrada — {yer}",
        },
        params=('ad', 'yer'),
    ),
    # (P240 §4) ENTEGRASYON KOPTU — yoneticiye.
    #
    # KRITIK KANALDA DEGIL (bkz. push_kanal): kopan bir diyafon
    # baglantisi onemlidir ama gece 03:00'te uyandirmayi gerektirmez.
    # Panik bildirimiyle ayni sesi vermek, kritik kanali degersizlestirir.
    # (P240 §3) AKILLI EV — kacak ve yangin.
    #
    # IKISI AYRI TIP: yangin her zaman saha mudahalesi ister ve kritik
    # kanaldan gider; kacak onemlidir ama gece 03:00'te uyandirmayi
    # gerektirmeyebilir. Tek tipe indirmek, ikisini ayni sesle
    # duyurmak olurdu.
    "akilli_ev_kacak": PushMetni(
        baslik={
            "tr": "Kaçak algılandı",
            "en": "Leak detected",
            "ar": "تم رصد تسرب",
            "ru": "Обнаружена утечка",
            "de": "Leck erkannt",
            "fr": "Fuite détectée",
            "es": "Fuga detectada",
        },
        govde={
            "tr": "{cihaz} sensörü kaçak bildirdi — {yer}",
            "en": "Sensor {cihaz} reported a leak — {yer}",
            "ar": "أبلغ الحساس {cihaz} عن تسرب — {yer}",
            "ru": "Датчик {cihaz} сообщил об утечке — {yer}",
            "de": "Sensor {cihaz} meldet ein Leck — {yer}",
            "fr": "Le capteur {cihaz} signale une fuite — {yer}",
            "es": "El sensor {cihaz} detectó una fuga — {yer}",
        },
        params=('cihaz', 'yer'),
    ),
    "akilli_ev_yangin": PushMetni(
        baslik={
            "tr": "YANGIN / DUMAN",
            "en": "FIRE / SMOKE",
            "ar": "حريق / دخان",
            "ru": "ПОЖАР / ДЫМ",
            "de": "FEUER / RAUCH",
            "fr": "INCENDIE / FUMÉE",
            "es": "INCENDIO / HUMO",
        },
        govde={
            "tr": "{cihaz} sensörü duman algıladı — {yer}",
            "en": "Sensor {cihaz} detected smoke — {yer}",
            "ar": "رصد الحساس {cihaz} دخانًا — {yer}",
            "ru": "Датчик {cihaz} обнаружил дым — {yer}",
            "de": "Sensor {cihaz} hat Rauch erkannt — {yer}",
            "fr": "Le capteur {cihaz} a détecté de la fumée — {yer}",
            "es": "El sensor {cihaz} detectó humo — {yer}",
        },
        params=('cihaz', 'yer'),
    ),
    # ===================================================================== #
    # (P243 §5c) PANIK KATEGORILERI — HER BIRI KENDI TALIMATIYLA
    # ===================================================================== #
    #
    # NEDEN AYRI METINLER: alan kisi NE YAPACAGINI bilmeli. Deprem ile
    # gaz kacagi BIRBIRINI DISLAYAN talimatlar tasir — depremde asansor
    # yasak, gazda ELEKTRIK DUGMESI yasak. Tek bir "acil durum var"
    # cumlesi, dogru davranisi kullanicinin tahminine birakirdi.
    #
    # KAYNAK: AFAD "Cok - Kapan - Tutun" temel hareketi ve deprem
    # sonrasi "asansor kullanmayin, merdiveni kullanin" yonergesi;
    # dogal gaz dagitim sirketlerinin (or. IGDAS) kacak talimati
    # "ates yakmayin, elektrik dugmelerine dokunmayin, havalandirin,
    # binayi terk edin"; itfaiye tahliye yonergesi "asansor kullanmayin".
    # UYDURULMADI: her cumle bu yonergelerin kisaltilmis halidir.
    #
    # KISA TUTULDU: bildirim ekraninda TAM OKUNMALI. Uzun bir metin
    # "..." ile kesilir ve kesilen yer tam da talimatin oldugu yerdir.
    "panik_kategori_deprem": PushMetni(
        baslik={
            "tr": "DEPREM", "en": "EARTHQUAKE", "ar": "زلزال",
            "ru": "ЗЕМЛЕТРЯСЕНИЕ", "de": "ERDBEBEN", "fr": "SÉISME",
            "es": "TERREMOTO",
        },
        govde={
            "tr": "Çök, kapan, tutun. Sarsıntı bitince merdivenle çıkın; asansör kullanmayın.",
            "en": "Drop, cover, hold on. When shaking stops use the stairs; do not use the lift.",
            "ar": "انبطح، احتمِ، تمسّك. بعد توقف الهزة استخدم الدرج ولا تستخدم المصعد.",
            "ru": "Упади, укройся, держись. После толчков — по лестнице, лифтом не пользуйтесь.",
            "de": "Ducken, schützen, festhalten. Danach Treppe nehmen, keinen Aufzug.",
            "fr": "Baissez-vous, protégez-vous, accrochez-vous. Ensuite l’escalier, pas l’ascenseur.",
            "es": "Agáchese, cúbrase, sujétese. Después use las escaleras, no el ascensor.",
        },
        params=(),
    ),
    "panik_kategori_yangin": PushMetni(
        baslik={
            "tr": "YANGIN", "en": "FIRE", "ar": "حريق", "ru": "ПОЖАР",
            "de": "FEUER", "fr": "INCENDIE", "es": "INCENDIO",
        },
        govde={
            "tr": "Binayı merdivenden terk edin. Asansör kullanmayın, kapıları kapatın.",
            "en": "Leave the building by the stairs. Do not use the lift; close doors behind you.",
            "ar": "غادر المبنى عبر الدرج. لا تستخدم المصعد وأغلق الأبواب خلفك.",
            "ru": "Покиньте здание по лестнице. Лифтом не пользуйтесь, закрывайте двери.",
            "de": "Gebäude über die Treppe verlassen. Keinen Aufzug, Türen schließen.",
            "fr": "Quittez le bâtiment par l’escalier. Pas d’ascenseur, fermez les portes.",
            "es": "Salga por las escaleras. No use el ascensor y cierre las puertas.",
        },
        params=(),
    ),
    "panik_kategori_gaz": PushMetni(
        baslik={
            "tr": "GAZ KAÇAĞI", "en": "GAS LEAK", "ar": "تسرب غاز",
            "ru": "УТЕЧКА ГАЗА", "de": "GASLECK", "fr": "FUITE DE GAZ",
            "es": "FUGA DE GAS",
        },
        govde={
            "tr": "Ateş yakmayın, elektrik düğmelerine dokunmayın. Binayı terk edin.",
            "en": "No flames, do not touch light switches. Leave the building.",
            "ar": "لا تشعل نارًا ولا تلمس مفاتيح الكهرباء. غادر المبنى.",
            "ru": "Не зажигайте огонь, не трогайте выключатели. Покиньте здание.",
            "de": "Kein Feuer, keine Lichtschalter berühren. Gebäude verlassen.",
            "fr": "Pas de flamme, ne touchez pas les interrupteurs. Quittez le bâtiment.",
            "es": "Sin llamas, no toque los interruptores. Salga del edificio.",
        },
        params=(),
    ),
    "panik_kategori_tahliye": PushMetni(
        baslik={
            "tr": "TAHLİYE", "en": "EVACUATION", "ar": "إخلاء",
            "ru": "ЭВАКУАЦИЯ", "de": "EVAKUIERUNG", "fr": "ÉVACUATION",
            "es": "EVACUACIÓN",
        },
        govde={
            "tr": "Binayı derhal terk edin. Asansör kullanmayın, toplanma alanına gidin.",
            "en": "Leave the building now. Do not use the lift; go to the assembly point.",
            "ar": "غادر المبنى فورًا. لا تستخدم المصعد وتوجّه إلى نقطة التجمع.",
            "ru": "Немедленно покиньте здание. Без лифта, идите к месту сбора.",
            "de": "Gebäude sofort verlassen. Kein Aufzug, zum Sammelpunkt gehen.",
            "fr": "Quittez le bâtiment immédiatement. Pas d’ascenseur, point de rassemblement.",
            "es": "Salga del edificio ya. Sin ascensor, vaya al punto de reunión.",
        },
        params=(),
    ),
    "panik_kategori_saglik": PushMetni(
        baslik={
            "tr": "SAĞLIK ACİLİ", "en": "MEDICAL EMERGENCY",
            "ar": "حالة طبية طارئة", "ru": "МЕДИЦИНСКАЯ ПОМОЩЬ",
            "de": "MEDIZINISCHER NOTFALL", "fr": "URGENCE MÉDICALE",
            "es": "EMERGENCIA MÉDICA",
        },
        govde={
            "tr": "Sağlık acili. 112 arandı mı kontrol edin, ekibi kapıda karşılayın.",
            "en": "Medical emergency. Check the ambulance was called and meet it at the gate.",
            "ar": "حالة طبية طارئة. تأكد من طلب الإسعاف واستقبله عند البوابة.",
            "ru": "Медицинский случай. Проверьте вызов скорой и встретьте её у ворот.",
            "de": "Medizinischer Notfall. Rettungsdienst gerufen? Am Tor empfangen.",
            "fr": "Urgence médicale. Vérifiez l’appel des secours et accueillez-les à l’entrée.",
            "es": "Emergencia médica. Verifique la llamada al 112 y reciba a la ambulancia.",
        },
        params=(),
    ),
    "panik_kategori_guvenlik_tehdidi": PushMetni(
        baslik={
            "tr": "GÜVENLİK TEHDİDİ", "en": "SECURITY THREAT",
            "ar": "تهديد أمني", "ru": "УГРОЗА БЕЗОПАСНОСТИ",
            "de": "SICHERHEITSBEDROHUNG", "fr": "MENACE DE SÉCURITÉ",
            "es": "AMENAZA DE SEGURIDAD",
        },
        govde={
            "tr": "Güvenlik tehdidi. Bulunduğunuz yerde kalın, kapıyı kilitleyin, 155'i arayın.",
            "en": "Security threat. Stay where you are, lock the door, call the police.",
            "ar": "تهديد أمني. ابقَ مكانك، أغلق الباب، واتصل بالشرطة.",
            "ru": "Угроза безопасности. Оставайтесь на месте, заприте дверь, звоните в полицию.",
            "de": "Sicherheitsbedrohung. Bleiben Sie, Tür verriegeln, Polizei rufen.",
            "fr": "Menace de sécurité. Restez sur place, verrouillez, appelez la police.",
            "es": "Amenaza de seguridad. Quédese donde está, cierre con llave y llame a la policía.",
        },
        params=(),
    ),
    "panik_kategori_diger": PushMetni(
        baslik={
            "tr": "ACİL DURUM", "en": "EMERGENCY", "ar": "حالة طارئة",
            "ru": "ЧРЕЗВЫЧАЙНАЯ СИТУАЦИЯ", "de": "NOTFALL", "fr": "URGENCE",
            "es": "EMERGENCIA",
        },
        govde={
            "tr": "Acil durum bildirildi. Takip ekranından ayrıntıya bakın.",
            "en": "An emergency was reported. Open the tracking screen for details.",
            "ar": "تم الإبلاغ عن حالة طارئة. افتح شاشة المتابعة للتفاصيل.",
            "ru": "Сообщено о ЧС. Откройте экран отслеживания для деталей.",
            "de": "Ein Notfall wurde gemeldet. Details im Verfolgungsbildschirm.",
            "fr": "Une urgence a été signalée. Voir l’écran de suivi.",
            "es": "Se notificó una emergencia. Consulte la pantalla de seguimiento.",
        },
        params=(),
    ),
    # (P241 §2e) VARDIYA PLANI YAYINLANDI — ETKILENEN KISIYE.
    #
    # Sayi KISIYE OZEL: "18 vardiya yayinlandi" herkese ayni gitseydi,
    # kisiye kendi planiyla ilgisiz bir sayi verirdi. Tarih araligi da
    # o kisinin yayinlanan vardiyalarinin araligidir.
    "vardiya_yayinlandi": PushMetni(
        baslik={
            "tr": "Vardiya planın güncellendi",
            "en": "Your shift plan was updated",
            "ar": "تم تحديث خطة مناوباتك",
            "ru": "Ваш график смен обновлён",
            "de": "Ihr Schichtplan wurde aktualisiert",
            "fr": "Votre planning a été mis à jour",
            "es": "Su plan de turnos se actualizó",
        },
        govde={
            "tr": "{n} vardiya yayınlandı ({aralik})",
            "en": "{n} shifts published ({aralik})",
            "ar": "تم نشر {n} مناوبة ({aralik})",
            "ru": "Опубликовано смен: {n} ({aralik})",
            "de": "{n} Schichten veröffentlicht ({aralik})",
            "fr": "{n} services publiés ({aralik})",
            "es": "{n} turnos publicados ({aralik})",
        },
        params=("n", "aralik"),
    ),
    # (P241 §1) PERIYODIK BAKIM — UC KADEME AYRI METIN.
    #
    # Ucunu tek metne indirmek ("bakim hatirlatmasi") en onemli ayrimi
    # silerdi: gecikmis bir yasal kontrol ile 30 gun sonraki bir filtre
    # degisimi ayni cumleyle gelmemeli.
    "bakim_yaklasti": PushMetni(
        baslik={
            "tr": "Bakım yaklaşıyor",
            "en": "Maintenance due soon",
            "ar": "موعد صيانة يقترب",
            "ru": "Скоро техобслуживание",
            "de": "Wartung steht an",
            "fr": "Entretien à venir",
            "es": "Mantenimiento próximo",
        },
        govde={
            "tr": "{ekipman} bakımına {gun} gün kaldı",
            "en": "{ekipman} maintenance is due in {gun} days",
            "ar": "بقي {gun} يومًا على صيانة {ekipman}",
            "ru": "До техобслуживания «{ekipman}» осталось {gun} дн.",
            "de": "Wartung von {ekipman} in {gun} Tagen fällig",
            "fr": "Entretien de {ekipman} dans {gun} jours",
            "es": "El mantenimiento de {ekipman} vence en {gun} días",
        },
        params=("ekipman", "gun"),
    ),
    "bakim_bugun": PushMetni(
        baslik={
            "tr": "Bakım günü",
            "en": "Maintenance today",
            "ar": "يوم الصيانة",
            "ru": "День техобслуживания",
            "de": "Wartungstag",
            "fr": "Jour d’entretien",
            "es": "Día de mantenimiento",
        },
        govde={
            "tr": "{ekipman} bakımı bugün yapılmalı",
            "en": "{ekipman} maintenance is due today",
            "ar": "يجب إجراء صيانة {ekipman} اليوم",
            "ru": "Техобслуживание «{ekipman}» назначено на сегодня",
            "de": "Wartung von {ekipman} ist heute fällig",
            "fr": "L’entretien de {ekipman} est prévu aujourd’hui",
            "es": "El mantenimiento de {ekipman} corresponde hoy",
        },
        params=("ekipman",),
    ),
    "bakim_gecikti": PushMetni(
        baslik={
            "tr": "Bakım gecikti",
            "en": "Maintenance overdue",
            "ar": "تأخرت الصيانة",
            "ru": "Техобслуживание просрочено",
            "de": "Wartung überfällig",
            "fr": "Entretien en retard",
            "es": "Mantenimiento vencido",
        },
        govde={
            "tr": "{ekipman} bakımı {gun} gündür gecikmiş durumda",
            "en": "{ekipman} maintenance is {gun} days overdue",
            "ar": "تأخرت صيانة {ekipman} منذ {gun} يومًا",
            "ru": "Техобслуживание «{ekipman}» просрочено на {gun} дн.",
            "de": "Wartung von {ekipman} ist seit {gun} Tagen überfällig",
            "fr": "L’entretien de {ekipman} est en retard de {gun} jours",
            "es": "El mantenimiento de {ekipman} lleva {gun} días vencido",
        },
        params=("ekipman", "gun"),
    ),
    "entegrasyon_koptu": PushMetni(
        baslik={
            "tr": "Bağlantı koptu",
            "en": "Connection lost",
            "ar": "انقطع الاتصال",
            "ru": "Соединение потеряно",
            "de": "Verbindung unterbrochen",
            "fr": "Connexion perdue",
            "es": "Conexión perdida",
        },
        govde={
            "tr": "{ad} entegrasyonuna ulaşılamıyor.",
            "en": "The {ad} integration is unreachable.",
            "ar": "تعذّر الوصول إلى تكامل {ad}.",
            "ru": "Интеграция {ad} недоступна.",
            "de": "Die Integration {ad} ist nicht erreichbar.",
            "fr": "L’intégration {ad} est injoignable.",
            "es": "No se puede acceder a la integración {ad}.",
        },
        params=('ad',),
    ),
    "anket_acildi": PushMetni(
        baslik={
            "tr": "Yeni anket",
            "en": "New poll",
            "ar": "استطلاع جديد",
            "ru": "Новый опрос",
            "de": "Neue Umfrage",
            "fr": "Nouveau sondage",
            "es": "Nueva encuesta",
        },
        govde={
            "tr": "Oyunuz bekleniyor: {baslik}",
            "en": "Your vote is awaited: {baslik}",
            "ar": "صوتك مطلوب: {baslik}",
            "ru": "Ждём вашего голоса: {baslik}",
            "de": "Ihre Stimme wird erwartet: {baslik}",
            "fr": "Votre vote est attendu : {baslik}",
            "es": "Se espera su voto: {baslik}",
        },
        params=('baslik',),
    ),
    "aidat_borc": PushMetni(
        baslik={
            "tr": "Yeni borç",
            "en": "New charge",
            "ar": "مستحق جديد",
            "ru": "Новое начисление",
            "de": "Neue Forderung",
            "fr": "Nouvelle charge",
            "es": "Nuevo cargo",
        },
        govde={
            "tr": "{donem} dönemi için {tutar} tutarında borç tanımlandı.",
            "en": "A charge of {tutar} was created for the {donem} period.",
            "ar": "تم إنشاء مستحق بقيمة {tutar} لفترة {donem}.",
            "ru": "За период {donem} начислено {tutar}.",
            "de": "Für den Zeitraum {donem} wurde eine Forderung über {tutar} erstellt.",
            "fr": "Une charge de {tutar} a été créée pour la période {donem}.",
            "es": "Se creó un cargo de {tutar} para el período {donem}.",
        },
        params=('donem', 'tutar'),
    ),
    # ----------------------- (P192 §4) OTOMASYON ------------------------- #
    #
    # Dordu de OTOMATIK gorevlerden dogar. Metinler burada cunku push
    # asenkrondur: dil istekten degil CIHAZ KAYDINDAN okunur.
    "aidat_hatirlatma": PushMetni(
        baslik={
            "tr": "Aidat hatırlatması",
            "en": "Payment reminder",
            "ar": "تذكير بالدفع",
            "ru": "Напоминание об оплате",
            "de": "Zahlungserinnerung",
            "fr": "Rappel de paiement",
            "es": "Recordatorio de pago",
        },
        govde={
            "tr": "{tutar} tutarında ödenmemiş borcunuz var (son ödeme: {vade}).",
            "en": "You have an unpaid balance of {tutar} (due: {vade}).",
            "ar": "لديك رصيد غير مدفوع بقيمة {tutar} (الاستحقاق: {vade}).",
            "ru": "У вас есть неоплаченная задолженность {tutar} (срок: {vade}).",
            "de": "Sie haben einen offenen Betrag von {tutar} (fällig: {vade}).",
            "fr": "Vous avez un solde impayé de {tutar} (échéance : {vade}).",
            "es": "Tiene un saldo pendiente de {tutar} (vencimiento: {vade}).",
        },
        params=("tutar", "vade"),
    ),
    "aidat_onizleme": PushMetni(
        baslik={
            "tr": "Yaklaşan tahakkuk",
            "en": "Upcoming charge run",
            "ar": "استحقاق قادم",
            "ru": "Предстоящее начисление",
            "de": "Bevorstehende Sollstellung",
            "fr": "Prochaine facturation",
            "es": "Próximo cargo",
        },
        govde={
            "tr": "{gun} gün sonra {daire} daireye toplam {tutar} tahakkuk edilecek.",
            "en": "In {gun} days, {tutar} will be charged to {daire} units.",
            "ar": "بعد {gun} أيام سيتم تحميل {tutar} على {daire} وحدة.",
            "ru": "Через {gun} дн. будет начислено {tutar} на {daire} квартир.",
            "de": "In {gun} Tagen werden {tutar} auf {daire} Einheiten gebucht.",
            "fr": "Dans {gun} jours, {tutar} seront imputés à {daire} lots.",
            "es": "En {gun} días se cargarán {tutar} a {daire} unidades.",
        },
        params=("gun", "daire", "tutar"),
    ),
    "aylik_ozet": PushMetni(
        baslik={
            "tr": "Aylık özet",
            "en": "Monthly summary",
            "ar": "الملخص الشهري",
            "ru": "Месячная сводка",
            "de": "Monatsübersicht",
            "fr": "Résumé mensuel",
            "es": "Resumen mensual",
        },
        govde={
            "tr": "{donem}: tahsilat {tahsilat}, gider {gider}, tahsilat oranı %{oran}.",
            "en": "{donem}: collected {tahsilat}, spent {gider}, collection rate {oran}%.",
            "ar": "{donem}: التحصيل {tahsilat}، المصروف {gider}، نسبة التحصيل {oran}%.",
            "ru": "{donem}: собрано {tahsilat}, расходы {gider}, собираемость {oran}%.",
            "de": "{donem}: Einnahmen {tahsilat}, Ausgaben {gider}, Inkassoquote {oran}%.",
            "fr": "{donem} : encaissé {tahsilat}, dépensé {gider}, taux {oran} %.",
            "es": "{donem}: cobrado {tahsilat}, gastado {gider}, tasa {oran}%.",
        },
        params=("donem", "tahsilat", "gider", "oran"),
    ),
    "gider_onay": PushMetni(
        baslik={
            "tr": "Onay bekleyen gider",
            "en": "Expense awaiting approval",
            "ar": "مصروف بانتظار الموافقة",
            "ru": "Расход ожидает утверждения",
            "de": "Ausgabe zur Genehmigung",
            "fr": "Dépense en attente d'approbation",
            "es": "Gasto pendiente de aprobación",
        },
        govde={
            "tr": "{ad} için {tutar} tutarında gider onayınızı bekliyor.",
            "en": "An expense of {tutar} for {ad} is awaiting your approval.",
            "ar": "مصروف بقيمة {tutar} لـ {ad} بانتظار موافقتك.",
            "ru": "Расход {tutar} по «{ad}» ожидает вашего утверждения.",
            "de": "Eine Ausgabe über {tutar} für {ad} wartet auf Ihre Genehmigung.",
            "fr": "Une dépense de {tutar} pour {ad} attend votre approbation.",
            "es": "Un gasto de {tutar} para {ad} espera su aprobación.",
        },
        params=("ad", "tutar"),
    ),
    "test": PushMetni(
        baslik={
            "tr": "Test bildirimi",
            "en": "Test notification",
            "ar": "إشعار تجريبي",
            "ru": "Тестовое уведомление",
            "de": "Testbenachrichtigung",
            "fr": "Notification de test",
            "es": "Notificación de prueba",
        },
        govde={
            "tr": "Bu bir test bildirimidir. Bunu gördüyseniz bildirimler çalışıyor.",
            "en": "This is a test notification. If you can see it, notifications work.",
            "ar": "هذا إشعار تجريبي. إذا رأيته فالإشعارات تعمل.",
            "ru": "Это тестовое уведомление. Если вы его видите, уведомления работают.",
            "de": "Dies ist eine Testbenachrichtigung. Wenn Sie sie sehen, funktionieren Benachrichtigungen.",
            "fr": "Ceci est une notification de test. Si vous la voyez, les notifications fonctionnent.",
            "es": "Esta es una notificación de prueba. Si la ve, las notificaciones funcionan.",
        },
    ),
    "aidat_odendi": PushMetni(
        baslik={
            "tr": "Ödemeniz alındı",
            "en": "Payment received",
            "ar": "تم استلام دفعتك",
            "ru": "Платёж получен",
            "de": "Zahlung erhalten",
            "fr": "Paiement reçu",
            "es": "Pago recibido",
        },
        govde={
            # (E2E 2026-09, FINANS-02) "Banka odemeniz" DEGIL: ayni bildirim
            # artik vezne ve aidat ucundan alinan odemede de gidiyor.
            "tr": "Ödemeniz hesabınıza işlendi. Makbuzunuz hazır.",
            "en": "Your payment has been applied to your account. Your receipt is ready.",
            "ar": "تمت معالجة دفعتك في حسابك. الإيصال جاهز.",
            "ru": "Ваш платёж зачислен. Квитанция готова.",
            "de": "Ihre Zahlung wurde verbucht. Ihre Quittung ist bereit.",
            "fr": "Votre paiement a été enregistré. Votre reçu est prêt.",
            "es": "Su pago se ha registrado. Su recibo está listo.",
        },
    ),
}
