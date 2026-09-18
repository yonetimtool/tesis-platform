"""(P240 §3) Akilli ev — kopru katmani."""
from .taban import (  # noqa: F401
    EYLEM_AC,
    EYLEM_KAPAT,
    EYLEM_KILIT_AC,
    EYLEM_VANA_KAPAT,
    EYLEMLER,
    HATA_DESTEKLENMIYOR,
    HATA_REDDEDILDI,
    HATA_ULASILAMIYOR,
    HATA_YAPILANDIRMA,
    HOME_ASSISTANT,
    HTTP,
    MQTT,
    TIP_EYLEM,
    KopruArayuzu,
    KopruSonuc,
    eylem_gecerli,
)


def kopru(kayit) -> KopruArayuzu:
    """Kayittan kopru uretir — CAGIRAN PROTOKOLU BILMEZ.

    MQTT bu turda UYGULANMADI ve sessizce HTTP'ye dusmez: yapilandirma
    hatasi dondurur. Sessiz dusus, MQTT sectigini sanan kullaniciya
    calismayan bir kurulum vermek olurdu.
    """
    from ..crypto import decrypt_secret
    from .home_assistant import HomeAssistantKopru

    token = decrypt_secret(kayit.token_enc) if kayit.token_enc else None
    if kayit.tur == MQTT:
        return _UygulanmayanKopru(MQTT)
    # `http` de HA istemcisiyle konusur: ikisi de duz HTTP; fark
    # YOLLARDADIR ve `http` turunde cihazin kendi yolu `dis_kimlik`te
    # tutulur (bkz. routers/akilli_ev.py).
    return HomeAssistantKopru(host=kayit.host, port=kayit.port, token=token)


class _UygulanmayanKopru:
    """MQTT — bu turda yok. ACIKCA soyler, sessizce baskasina DUSMEZ."""

    def __init__(self, tur: str) -> None:
        self.tur = tur

    def saglik(self) -> KopruSonuc:
        return KopruSonuc(False, HATA_YAPILANDIRMA, f"{self.tur} bu surumde yok")

    def durum(self, dis_kimlik: str) -> KopruSonuc:
        return self.saglik()

    def komut(self, dis_kimlik: str, eylem: str, tip: str) -> KopruSonuc:
        return self.saglik()
