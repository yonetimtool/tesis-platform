"""(DUKKAN F6) BILDIRIM — kalici satir + anlik push, YAN YANA.

===========================================================================
IKI KAYIT, BIR OLAY
===========================================================================
Push anlik gonderilir ve GERIYE HICBIR SEY BIRAKMAZ: o an telefonu kapali
olan kullanici icin olay YOK OLUR. Bu yuzden her olay hem `bildirim`
tablosuna yazilir hem push edilir.

Ayni karar Yonetiyor'da `sakin_bildirimi.py` basliginda yazili — ve orada
"anlik push'un kalici ikizi" diye adlandirilmis.

===========================================================================
METIN KAYDA DONDURULMAZ
===========================================================================
Satir `tip` + `veri` tutar; metin OKUMA aninda, ISTEGIN dilinde uretilir.
7 dilli bir uygulamada kaydedilmis metin, kullanici dilini degistirdiginde
ESKI dilde kalirdi.

===========================================================================
PUSH SAGLAYICISI PAYLASILIYOR
===========================================================================
`app.push.get_push_provider()` — FCM kimligi, HTTP katmani ve hata
eslemesi iki urunde de ayni. Ayrisan sey KIME gonderildigi.

P191'de olculen tuzak burada da gecerli: `PUSH_PROVIDER=noop` sessizce
"gonderildi" gibi davranirsa bildirimler HIC gitmez ve kimse fark etmez.
`gonderildi_at` yalnizca saglayici KABUL ettiginde doluyor — noop'ta
NULL kaliyor ve bu, teshiste "hic gitmemis" olarak GORULUYOR.
"""
from __future__ import annotations

import uuid
from collections.abc import Mapping

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

#: Bildirim tipleri ve varsayilan hedef yollari.
#:
#: HEDEF YOL BURADA, ISTEMCIDE DEGIL: mobil ve web ayni degeri okur.
#: Iki istemcide ayri ayri eslestirmek, birinin bir gun otekinden
#: ayrismasi ve bildirime tiklayinca YANLIS EKRANA gidilmesi demekti
#: (P217'de push yonlendirmesi tam bu sinif bir kusurdu).
#: TIPLER `dukkan_` ONEKLI ve bu ZORUNLU: `push_kanal.kanal_sec` bu
#: oneke bakip Dukkan kanalini seciyor. Onek olmayan bir tip SESSIZCE
#: Yonetiyor kanalindan gider ve kullanici pazar yeri bildirimlerini
#: kapattigini sanip almaya devam ederdi.
#:
#: Ayrica `yeni_talep` Yonetiyor'da ZATEN VAR (sakinin actigi talep,
#: KRITIK kanaldan gider). Oneksiz birakmak iki urunun tipini
#: CAKISTIRIRDI — bir Dukkan talebi, yoneticinin telefonunda site
#: sikayeti sesiyle calardi.
TIPLER: dict[str, str] = {
    "dukkan_teklif_geldi": "/taleplerim/{talep_id}",
    "dukkan_is_verildi": "/panel/{isletme_id}",
    "dukkan_isletme_onaylandi": "/panel/{isletme_id}",
    "dukkan_isletme_reddedildi": "/panel/{isletme_id}",
    "dukkan_isletme_askiya_alindi": "/panel/{isletme_id}",
    "dukkan_yorum_yayinlandi": "/isletme/{isletme_slug}",
    "dukkan_yeni_talep": "/panel/{isletme_id}",
}


def _hedef_yol(tip: str, veri: Mapping[str, object]) -> str | None:
    sablon = TIPLER.get(tip)
    if not sablon:
        return None
    try:
        return sablon.format(**veri)
    except KeyError:
        # Eksik anahtar SESSIZ GECMEZ ama isteği de KIRMAZ: bildirim
        # yolsuz gider (uygulama listeye acilir), kayit yine de yazilir.
        # Bildirimi hic yazmamak, olayin tamamen kaybolmasi olurdu.
        return None


async def bildir(
    db: AsyncSession,
    *,
    kullanici_id: uuid.UUID,
    tip: str,
    baslik: str,
    govde: str,
    veri: Mapping[str, object] | None = None,
) -> uuid.UUID:
    """Bildirim satirini yazar ve push gonderir. Doner: bildirim kimligi.

    PUSH BASARISIZ OLSA BILE SATIR KALIR — olay kaybolmaz. `gonderildi_at`
    yalnizca saglayici KABUL ettiginde dolar; NULL olmasi "gitmedi"
    demektir ve teshiste gorunur.
    """
    veri = dict(veri or {})
    yeni = (
        await db.execute(
            text("INSERT INTO bildirim (kullanici_id, tip, veri, hedef_yol) "
                 "VALUES (:k, :t, CAST(:v AS jsonb), :y) RETURNING id"),
            {"k": kullanici_id, "t": tip,
             "v": __import__("json").dumps(veri, default=str),
             "y": _hedef_yol(tip, veri)},
        )
    ).scalar_one()

    # ==================================================================
    # KULLANICI TERCIHI — SATIR YAZILDIKTAN SONRA BAKILIYOR
    # ==================================================================
    # Sira onemli: bildirim KAPALI olsa bile KALICI SATIR yaziliyor.
    # Kullanici push almak istemiyor olabilir ama uygulamayi actiginda
    # olayi GORMELI. "Kapali" push'u susturur, olayi SILMEZ — Yonetiyor'da
    # `bildirim_mobil` icin de ayni ayrim yazili.
    tercih = (
        await db.execute(
            text("SELECT bildirim_acik, bildirim_sesli FROM dukkan_kullanici "
                 "WHERE id = :k"),
            {"k": kullanici_id},
        )
    ).mappings().first()
    if tercih is None or not tercih["bildirim_acik"]:
        return yeni

    jetonlar = [
        r[0] for r in (
            await db.execute(
                text("SELECT fcm_token FROM dukkan_cihaz WHERE kullanici_id = :k"),
                {"k": kullanici_id},
            )
        ).all()
    ]
    if not jetonlar:
        return yeni

    from ..push import get_push_provider
    from ..push_kanal import kanal_sec, ses_adi

    sesli = bool(tercih["bildirim_sesli"])
    sonuc = get_push_provider().send(
        jetonlar, title=baslik, body=govde,
        data={"tip": tip, "bildirim_id": str(yeni),
              "yol": _hedef_yol(tip, veri) or ""},
        # KANAL VE SES SUNUCUDA SECILIYOR (P207 kalibi): Android'de ses
        # kanalin ozelligidir ve istemci onu degistiremez.
        kanal=kanal_sec(tip, sesli=sesli),
        ses=ses_adi(tip, sesli=sesli),
    )
    if sonuc.sent > 0:
        await db.execute(
            text("UPDATE bildirim SET gonderildi_at = now() WHERE id = :i"),
            {"i": yeni},
        )
    # GECERSIZ JETONLAR BUDANIR: saglayici "bu cihaz kayitli degil"
    # dediyse jeton olu demektir ve her gonderimde tekrar denemek
    # bosuna maliyet. Gecici hatalarda jeton KORUNUR (push.py ayrimi).
    if sonuc.gecersiz:
        await db.execute(
            text("DELETE FROM dukkan_cihaz WHERE fcm_token = ANY(:t)"),
            {"t": list(sonuc.gecersiz)},
        )
    return yeni
