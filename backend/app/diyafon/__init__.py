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
        return KuruKontakDiyafon(
            host=kayit.host,
            port=kayit.port,
            kullanici=kayit.kullanici,
            sifre=sifre,
            zil_yolu=kayit.zil_yolu,
            kapi_yolu=kayit.kapi_yolu,
        )
    return SipDiyafon(
        host=kayit.host,
        port=kayit.port,
        hedef=kayit.hedef,
        yontem=kayit.yontem,
    )
