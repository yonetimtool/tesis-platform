"""(P240 §2) Diyafon — uc yontem, tek soyutlama."""
from .taban import (  # noqa: F401
    KURU_KONTAK,
    SIP,
    SIP_KOPRU,
    VARSAYILAN_PORT,
    DiyafonSaglayici,
    DiyafonSonuc,
    Yetenekler,
    yetenekler,
)


def saglayici(kayit) -> DiyafonSaglayici:
    """Kayittan saglayici uretir — CAGIRAN YONTEMI BILMEZ.

    `kayit` bir `models.Diyafon`dur; sifre BURADA cozulur cunku
    saglayicilar veritabanini bilmez (ve bilmemeli).
    """
    from ..crypto import decrypt_secret
    from .kuru_kontak import KuruKontakDiyafon
    from .sip import SipDiyafon

    sifre = decrypt_secret(kayit.sifre_enc) if kayit.sifre_enc else None
    if kayit.yontem == KURU_KONTAK:
        return _KapiliDiyafon(kayit.host, KuruKontakDiyafon(
            host=kayit.host,
            port=kayit.port,
            kullanici=kayit.kullanici,
            sifre=sifre,
            zil_yolu=kayit.zil_yolu,
            kapi_yolu=kayit.kapi_yolu,
        ))
    return _KapiliDiyafon(kayit.host, SipDiyafon(
        host=kayit.host,
        port=kayit.port,
        hedef=kayit.hedef,
        yontem=kayit.yontem,
    ))


class _KapiliDiyafon:
    """(E2E 2026-09) Her islemden ONCE hedef kapisi (`safe_http.saha_hedefi_engelli`).

    Kapi FABRIKADA, saglayicida degil: saglik ucu, zil/kapi/anons ve
    beat'teki kopus izlemesi AYNI yoldan gecer — bir tanesini unutmak
    kapiyi delerdi. Denetim cagrinin ICINDE (thread havuzunda) yapilir:
    DNS cozumu olay dongusunu bloklamasin.

    ENGELLENEN HEDEF "ulasilamiyor" ile AYNI kimligi ve AYNI ayrintiyi
    dondurur (bkz. safe_http): "engellendi" ile "kapali port" farki da
    bir tarama bilgisidir.
    """

    def __init__(self, host: str | None, ic: DiyafonSaglayici) -> None:
        self._host = host
        self._ic = ic
        self.yontem = ic.yontem

    def _engelli(self) -> DiyafonSonuc | None:
        from ..safe_http import SAHA_ENGEL_AYRINTI, saha_hedefi_engelli
        from .taban import HATA_ULASILAMIYOR

        if saha_hedefi_engelli(self._host):
            return DiyafonSonuc(False, HATA_ULASILAMIYOR, SAHA_ENGEL_AYRINTI)
        return None

    def saglik(self) -> DiyafonSonuc:
        return self._engelli() or self._ic.saglik()

    def metin_anons(self, mesaj: str) -> DiyafonSonuc:
        return self._engelli() or self._ic.metin_anons(mesaj)

    def kapi_ac(self) -> DiyafonSonuc:
        return self._engelli() or self._ic.kapi_ac()

    def zil_cal(self) -> DiyafonSonuc:
        return self._engelli() or self._ic.zil_cal()
