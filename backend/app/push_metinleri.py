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
        return sablon.format(**params)
    except (KeyError, IndexError, ValueError):
        return sablon


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
}
