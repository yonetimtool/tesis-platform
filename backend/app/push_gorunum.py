"""(P247 §5) BILDIRIMIN GORUNUMU — gruplama, kaynak, aciliyet, kilit ekrani.

===========================================================================
TEMEL KARAR: `notification` GOVDESI KALIR (data-only'ye GECILMEDI)
===========================================================================
"WhatsApp gibi" bir gorunumun tam hali (Android MessagingStyle, eylem
dugmeleri, avatar) bildirimi UYGULAMANIN KENDISININ cizmesini ister: sunucu
yalniz `data` gonderir, uygulama arka planda uyanip yerel bildirim kurar.
Bu, P247 §4'un "uygulama kapaliyken push" sartiyla CATISIR:

  * `notification` govdesini isletim sistemi / FCM SDK'si Flutter motoru
    hic baslamadan cizer. Uygulama kapaliyken (kaydirilip kapatilmis) de
    gorunur.
  * data-only mesajda Flutter motoru arka planda ACILMAK zorundadir;
    bazi ureticiler (Xiaomi/Huawei pil yoneticileri) bunu oldurur ve
    bildirim SESSIZCE KAYBOLUR. iOS'ta kapali uygulamaya data-only mesaj
    HIC teslim edilmez.

Panik alarminin "gorunmemesi" ile "WhatsApp gibi gorunmemesi" ayni agirlikta
degildir. Bu yuzden gorunum `notification` govdesinin TASIYABILDIGI her seyle
zenginlestirildi; TASIYAMADIKLARI `docs/P247-kararlar.md` §5'te yazili.

===========================================================================
NE TASINIYOR
===========================================================================
* GRUP (iOS `thread-id`): ayni tesisin ayni konudaki bildirimleri tek
  yiginda toplanir — "Acil", "Kargo", "Finans"... Tesis kimligi anahtarin
  parcasidir: iki tesiste gorevli kisinin yiginlari karismaz.
* ETIKET (Android `tag`): AYNI KAYDIN yeni bildirimi eskisinin YERINI alir
  (ayni panik alarmi "yanlis alarm"a donunce iki kart degil tek kart;
  tekrar eden gecikme alarmi yigilmaz). Kayit kimligi yoksa etiket yok.
  Android, ayni uygulamanin 4+ bildirimini zaten kendisi demetler.
* KAYNAK: tesis adi — iOS `subtitle`, Android'de basliga ek. Birden cok
  tesiste olan kisi "hangi site?" sorusunu bildirimi acmadan yanitlar.
* ACIL (panik, yangin, gurultu eskalasyonu): Android `priority=high` SES
  KAPALI OLSA BILE (Doze'da geciktirilmez) + `PRIORITY_MAX`; iOS
  `interruption-level=time-sensitive` + `apns-priority: 10`.
* KILIT EKRANI: acil tipler `PUBLIC` (kilitliyken okunabilmeli — panigin
  bilgisi saniyeler icinde lazim); digerleri `PRIVATE`: kullanici Android'de
  "hassas icerigi gizle" dediyse kilitte yalniz "Yonetio" gorunur.
  Govdelerde telefon/e-posta TASINMAZ (P247 §6 panik telefonu duzeltmesi).
* ROZET: kisinin okunmamis bildirim sayisi (iOS `badge`, Android
  `notification_count`). Uygulama acildiginda gercek sayiyla DUZELTILIR.
* HEDEF ROL (`data.hedef_rol`): P247 §2 — iki rollu kisi (yonetici+sakin)
  bildirime dokununca uygulama DOGRU MODA gecer.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from collections.abc import Mapping

from .push_kanal import PANIK_KATEGORI_ONEK

#: Kilit ekraninda icerigi ACIK gosterilen ve Odak modunu delen tipler.
ACIL_TIPLER: frozenset[str] = frozenset({
    "panik_alarm",
    "panik_yanlis_alarm",
    "akilli_ev_yangin",
    "gurultu_eskalasyon_guvenlik",
    "gurultu_eskalasyon_yonetim",
})


def acil_mi(kimlik: str | None) -> bool:
    return bool(kimlik) and (
        kimlik in ACIL_TIPLER or kimlik.startswith(PANIK_KATEGORI_ONEK)
    )


#: Kimlik -> grup. ONEK eslesmesi, ilk eslesen kazanir (sira onemli).
_GRUP_ONEKLERI: tuple[tuple[str, str], ...] = (
    ("panik_", "acil"),
    ("akilli_ev_yangin", "acil"),
    ("gurultu_", "gurultu"),
    ("kacirilan_tur", "devriye"),
    ("gecikmis_okutma", "devriye"),
    ("uzak_okutma", "devriye"),
    ("eksik_checkpoint", "devriye"),
    ("vardiya_", "vardiya"),
    ("gorev_", "is"),
    ("is_emri_", "is"),
    ("yeni_talep", "talep"),
    ("talep_", "talep"),
    ("sikayet_", "talep"),
    ("kargo", "kargo"),
    ("ziyaretci", "ziyaretci"),
    ("aidat_", "finans"),
    ("aylik_ozet", "finans"),
    ("gider_onay", "finans"),
    ("tahsilat", "finans"),
    ("duyuru", "duyuru"),
    ("anket_", "duyuru"),
    ("etkinlik", "duyuru"),
    ("rezervasyon", "rezervasyon"),
    ("bakim_", "bakim"),
    ("akilli_ev_", "akilli_ev"),
    ("entegrasyon_", "akilli_ev"),
    ("erisim_", "erisim"),
    ("dukkan_", "dukkan"),
)


def grup(kimlik: str | None) -> str:
    for onek, ad in _GRUP_ONEKLERI:
        if kimlik and kimlik.startswith(onek):
            return ad
    return "genel"


#: Android `tag` icin kayit kimligi anahtarlari — ONCELIK SIRASIYLA.
#: `unit_id` BILEREK YOK: daire kimligi bir KAYDI degil bir haneyi
#: gosterir; onunla etiketlemek o dairenin FARKLI kargolarini birbirinin
#: yerine yazardi.
_KAYIT_ANAHTARLARI: tuple[str, ...] = (
    "panik_id", "task_id", "complaint_id", "request_id", "kargo_id",
    "visitor_id", "rezervasyon_id", "patrol_window_id", "anket_id",
    "announcement_id", "etkinlik_id", "cihaz_id", "ekipman_id",
    "shift_id", "receipt_id",
)


def kayit_etiketi(kimlik: str | None, data: Mapping[str, str] | None) -> str | None:
    for anahtar in _KAYIT_ANAHTARLARI:
        deger = (data or {}).get(anahtar)
        if deger:
            return f"{grup(kimlik)}:{deger}"
    return None


#: Iki rollu (yonetici+sakin) kisiye KISI OLARAK giden ve SAKIN modunda
#: acilmasi gereken bildirimler. Rol yayini (`target_roles`) ile gelenler
#: zaten rolun kendisidir; ayrim yalniz kisi hedefli gonderimde gerekir.
SAKIN_KIMLIKLERI: frozenset[str] = frozenset({
    "kargo", "kargo_teslim", "ziyaretci", "rezervasyon",
    "sikayet_cozuldu", "talep_is_emri", "talep_cozuldu", "talep_reddedildi",
    "erisim_onaylandi", "erisim_reddedildi",
    "aidat_borc", "aidat_odendi", "aidat_hatirlatma",
    "gurultu_uyari_sakin", "akilli_ev_kacak", "akilli_ev_yangin",
})


def hedef_rol(kimlik: str, rol: str, *, kisi_hedefli: bool) -> str:
    """Bildirime dokununca uygulamanin hangi MODDA acilacagi."""
    if rol == "yonetici" and kisi_hedefli and kimlik in SAKIN_KIMLIKLERI:
        return "resident"
    return rol


#: Android basligina eklenen kaynagin tavani: uzun site adi olay basligini
#: ekrandan itmesin.
KAYNAK_TAVANI = 28


def kaynak_kisalt(ad: str | None) -> str | None:
    if not ad:
        return None
    ad = ad.strip()
    return ad if len(ad) <= KAYNAK_TAVANI else ad[: KAYNAK_TAVANI - 1].rstrip() + "…"


@dataclass(frozen=True)
class PushGorunum:
    """Saglayiciya giden gorunum bilgisi (saglayicidan bagimsiz)."""

    kimlik: str
    thread: str | None = None
    etiket: str | None = None
    kaynak: str | None = None
    acil: bool = False
    #: token -> okunmamis sayisi (bu bildirim dahil).
    rozet: Mapping[str, int] = field(default_factory=dict)


def gorunum_kur(
    kimlik: str,
    *,
    tenant_id: object | None,
    data: Mapping[str, str] | None,
    kaynak: str | None,
    rozet: Mapping[str, int] | None = None,
) -> PushGorunum:
    return PushGorunum(
        kimlik=kimlik,
        thread=f"{tenant_id}:{grup(kimlik)}" if tenant_id else grup(kimlik),
        etiket=kayit_etiketi(kimlik, data),
        kaynak=kaynak_kisalt(kaynak),
        acil=acil_mi(kimlik),
        rozet=dict(rozet or {}),
    )
