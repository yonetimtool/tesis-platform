"""(P240 §3) AKILLI EV KOPRU SOYUTLAMASI.

===========================================================================
KOPRU NEDEN ZORUNLU — mimari karar
===========================================================================
Matter, Zigbee ve Z-Wave RADYO protokolleridir: kendi frekanslarinda
konusur ve bir USB anten ister. Bir sunucu uygulamasinin bunlara
DOGRUDAN baglanmasi fiziksel olarak mumkun degildir — radyo SITEDEDIR,
sunucu veri merkezinde.

Sektorun cozumu kopruDUR: sitedeki hub (Home Assistant, Zigbee2MQTT,
Homey) radyoyu dinler, bize HTTP/MQTT konusur. Yani "Zigbee destegi"
demek, "Zigbee cihazi hub uzerinden gorunur ve komut alir" demektir ve
bu dosya tam olarak o kapidir.

===========================================================================
BU TURDA NE UYGULANDI
===========================================================================
  * `home_assistant` — REST API (`/api/states`, `/api/services/...`).
    UYGULANDI ve taklit bir HA sunucusuyla uctan uca olculdu.
  * `http`           — kendi HTTP kapisi olan cihaz/role. UYGULANDI.
  * `mqtt`           — UYGULANMADI. Bir MQTT istemcisi kalici oturum,
    yeniden baglanma ve QoS secimi ister; ayrica olay AKISI (broker'dan
    bize push) bu turun kapsamindaki istek/yanit modeline uymuyor.
    Zigbee2MQTT kullanan kurulumlar Home Assistant araciligiyla BUGUN
    de baglanabilir — yani hicbir kurulum disarida kalmiyor.

===========================================================================
EYLEM KIMLIKLERI — serbest metin DEGIL
===========================================================================
Senaryo tablosundaki `eylem` alani bu kumeden gelir. Serbest metin,
yazim hatasinda SESSIZCE calismayan bir senaryo uretirdi; kume
disindaki bir deger uygulama katmaninda REDDEDILIR.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Final, Protocol

HOME_ASSISTANT: Final = "home_assistant"
MQTT: Final = "mqtt"
HTTP: Final = "http"

#: Eylem kimlikleri.
EYLEM_AC: Final = "ac"
EYLEM_KAPAT: Final = "kapat"
EYLEM_KILIT_AC: Final = "kilit_ac"
EYLEM_VANA_KAPAT: Final = "vana_kapat"
EYLEMLER: Final[frozenset[str]] = frozenset(
    {EYLEM_AC, EYLEM_KAPAT, EYLEM_KILIT_AC, EYLEM_VANA_KAPAT}
)

#: Hangi cihaz tipi hangi eylemi alir.
#:
#: Bir vanaya "ac" demek ile bir isiga "vana_kapat" demek ayni sinif
#: hatadir: hub 400 doner ve kullanici NEDEN oldugunu anlamaz. Kume
#: BURADA yazili ve uc onu dogruluyor.
TIP_EYLEM: Final[dict[str, frozenset[str]]] = {
    "isik": frozenset({EYLEM_AC, EYLEM_KAPAT}),
    "role": frozenset({EYLEM_AC, EYLEM_KAPAT}),
    "sulama": frozenset({EYLEM_AC, EYLEM_KAPAT}),
    "kilit": frozenset({EYLEM_KILIT_AC}),
    "vana": frozenset({EYLEM_VANA_KAPAT, EYLEM_AC}),
    "termostat": frozenset({EYLEM_AC, EYLEM_KAPAT}),
    "asansor": frozenset({EYLEM_AC, EYLEM_KAPAT}),
    # SENSORLER KOMUT ALMAZ: okuma yaparlar. Bir duman dedektorune
    # "ac" demek anlamsizdir ve arayuz de dugme cizmez.
    "sensor_su": frozenset(),
    "sensor_gaz": frozenset(),
    "sensor_duman": frozenset(),
    "sensor_hareket": frozenset(),
    "sayac": frozenset(),
}

#: Hata kimlikleri — metin `hata_metinleri`nden.
HATA_ULASILAMIYOR: Final = "akilli_ev_ulasilamiyor"
HATA_REDDEDILDI: Final = "akilli_ev_reddedildi"
HATA_YAPILANDIRMA: Final = "akilli_ev_yapilandirma_eksik"
HATA_DESTEKLENMIYOR: Final = "akilli_ev_eylem_desteklenmiyor"


@dataclass(frozen=True)
class KopruSonuc:
    ok: bool
    kod: str | None = None
    ayrinti: str | None = None
    #: Okuma sonucu (durum sorgusu) — ham hub yaniti.
    veri: dict | None = None


class KopruArayuzu(Protocol):
    """Kopru davranisi.

    ADI `AkilliEvKopru` DEGIL: o ad `models`te TABLOYA ait ve iki ayri
    seyin ayni adi tasimasi, hangi nesneyle calistigini import
    satirindan anlamayi imkansiz kilardi.
    """

    tur: str

    def saglik(self) -> KopruSonuc: ...

    def durum(self, dis_kimlik: str) -> KopruSonuc: ...

    def komut(self, dis_kimlik: str, eylem: str, tip: str) -> KopruSonuc: ...


def eylem_gecerli(tip: str, eylem: str) -> bool:
    return eylem in TIP_EYLEM.get(tip, frozenset())
