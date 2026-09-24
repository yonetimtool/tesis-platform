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
    TIP_BOLUM,
    TIP_EYLEM,
    KopruArayuzu,
    KopruSonuc,
    eylem_gecerli,
    tip_bolumu,
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
    return _KapiliKopru(
        kayit.host, HomeAssistantKopru(host=kayit.host, port=kayit.port, token=token)
    )


class _KapiliKopru:
    """(E2E 2026-09) Hedef kapisi — `diyafon._KapiliDiyafon` ile ayni karar.

    Kopru `komut` ile sitede KAPI ACAR; platformun kendi agina (redis,
    db, api...) giden bir "komut" hem bir port tarayicisi hem de ic
    servislere keyfi yollu istek demekti. Engel "ulasilamiyor" ile ayirt
    edilemez.
    """

    def __init__(self, host: str | None, ic) -> None:
        self._host = host
        self._ic = ic
        self.tur = ic.tur

    def _engelli(self) -> KopruSonuc | None:
        from ..safe_http import SAHA_ENGEL_AYRINTI, saha_hedefi_engelli

        if saha_hedefi_engelli(self._host):
            return KopruSonuc(False, HATA_ULASILAMIYOR, SAHA_ENGEL_AYRINTI)
        return None

    def saglik(self) -> KopruSonuc:
        return self._engelli() or self._ic.saglik()

    def durum(self, dis_kimlik: str) -> KopruSonuc:
        return self._engelli() or self._ic.durum(dis_kimlik)

    def komut(self, dis_kimlik: str, eylem: str, tip: str) -> KopruSonuc:
        return self._engelli() or self._ic.komut(dis_kimlik, eylem, tip)


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
