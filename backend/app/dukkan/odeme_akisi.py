"""(DUKKAN F8c) ODEME AKISI — reklam satin alma ve abonelik cekimi.

===========================================================================
SAGLAYICIDAN HABERSIZ
===========================================================================
Bu dosya `app.odeme.odeme_saglayicisi()` disinda hicbir saglayici adi
bilmiyor. Sanal POS secildiginde burasi DEGISMEYECEK.

===========================================================================
SIRA: ODEME ONCE, REKLAM SONRA — VE ARADAKI BOSLUK GORUNUR
===========================================================================
Once reklami acip sonra tahsil etmek daha basit olurdu; yapilmadi.
Tahsilat basarisiz olursa yayinda duran bir reklami geri almak gerekirdi
ve o arada gosterim ZATEN olmus olurdu.

Tersi de risksiz degil: odeme basarili olup reklam acma adimi patlarsa
(or. bu arada slot doldu) SAHIPSIZ BIR TAHSILAT kalir. Bu durum
GIZLENMIYOR — `reklam_satin_alma.reklam_id` NULL kalir ve o satirlar icin
kismi indeks var (`ix_reklam_satin_alma_sahipsiz`). Iade edilecek para
odur ve GORUNUR olmasi sarttir.

===========================================================================
SAGLAYICI BAGLI DEGILSE 503 — 200 DEGIL
===========================================================================
`{"basarili": false}` ile 200 donmek, istemciyi "basarili yanit geldi"
dalina sokar ve kullaniciya "odeme alindi" ekrani gosterir. SMS turunde
olculen kusurun ayni sinifi; odemede bedeli cok daha agir.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from ..odeme import KURUS_UST_SINIRI, odeme_saglayicisi
from .isletme import _denetim, _sahiplik_dogrula
from .kimlik import DukkanKimlik, kimlik_zorunlu
from .reklam import KAPSAM_SUTUNU, ReklamIstek, _bolge_sec, reklam_ac
from .veritabani import get_dukkan_session

router = APIRouter(prefix="/dukkan", tags=["dukkan"])


class FaturaBilgisi(BaseModel):
    """Fatura icin gereken alanlar — SATIN ALMA ANINDA dondurulur.

    Isletme tablosuna JOIN atilmiyor: fatura kesildigi ANDAKI bilgilerle
    kesilir ve isletme yarin unvan degistirirse gecen ayin faturasi
    DEGISMEMELI.
    """
    unvan: str = Field(min_length=2, max_length=300)
    vkn: str = Field(min_length=10, max_length=11, pattern=r"^\d{10,11}$")
    vergi_dairesi: str | None = Field(default=None, max_length=120)
    adres: str = Field(min_length=5, max_length=500)
    il: str | None = Field(default=None, max_length=80)
    ilce: str | None = Field(default=None, max_length=80)
    eposta: str | None = Field(default=None, max_length=200)


class OdemeliReklamIstek(ReklamIstek):
    fatura: FaturaBilgisi
    #: Doluysa SAKLANAN KARTLA cekilir (tekrarlayan odemenin de yolu).
    odeme_yontemi_id: uuid.UUID | None = None
    #: true ise donem sonunda OTOMATIK YENILENIR.
    #:
    #: VARSAYILAN false ve bu bir URUN KARARI: sessizce kart cekmek en cok
    #: sikayet ureten seydir (F8b). Altyapi tekrarlayan cekimi destekler;
    #: urun onu VARSAYILAN yapmaz.
    otomatik_yenile: bool = False


def _kdv_hesapla(tutar_kurus: int, oran) -> tuple[int, int]:
    """KDV ve toplami hesaplar. Doner: (kdv_kurus, toplam_kurus).

    TAM SAYI ARITMETIGI: `float` ile hesaplanan KDV, yuvarlama farkiyla
    faturayi bir kurus kaydirir ve mutabakati bozar.
    """
    kdv = (tutar_kurus * int(round(float(oran) * 100))) // 10000
    return kdv, tutar_kurus + kdv


@router.post("/reklam/satin-al", status_code=201)
async def reklam_satin_al_odemeli(
    govde: OdemeliReklamIstek,
    istek: Request,
    isletme_id: uuid.UUID = Query(...),
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Reklami ODEYEREK satin alir.

    Doner: {"satin_alma_id", "durum", "reklam_id"|None,
            "yonlendirme_url"|None}

    503 `odeme_yapilandirilmadi`: sanal POS bagli degil. Saglayici
    secilene kadar prod'da BU doner ve arayuz "odeme henuz acilmadi" der.
    """
    saglayici = odeme_saglayicisi()
    if not saglayici.yapilandirildi_mi():
        # KULLANICIYI FORMA SOKMADAN ONCE SOYLE. 200 + "basarili: false"
        # donmek, istemciyi basarili dalina sokar ve "odeme alindi"
        # ekrani gosterirdi.
        raise HTTPException(status_code=503,
                            detail="odeme_yapilandirilmadi")

    isl = await _sahiplik_dogrula(db, kimlik.kullanici_id, isletme_id)
    if isl["durum"] != "onayli":
        raise HTTPException(status_code=403, detail="isletme_onayli_degil")

    paket = (
        await db.execute(
            text("SELECT id, kapsam, gun, fiyat_kurus, kdv_orani "
                 "FROM reklam_paketi WHERE id = :p AND aktif"),
            {"p": govde.paket_id},
        )
    ).mappings().first()
    if paket is None:
        raise HTTPException(status_code=404, detail="paket_yok")
    if paket["fiyat_kurus"] > KURUS_UST_SINIRI:
        # Bir yazim hatasi (fazladan sifir) veritabanina girmis olabilir;
        # cekimden ONCE durdur.
        raise HTTPException(status_code=409, detail="fiyat_makul_degil")

    kategori_id = (
        await db.execute(
            text("SELECT id FROM kategori WHERE slug = :s AND ust_id IS NOT NULL"),
            {"s": govde.kategori_slug},
        )
    ).scalar_one_or_none()
    if kategori_id is None:
        raise HTTPException(status_code=404, detail="kategori_yok")
    bolge_id = _bolge_sec(govde, paket["kapsam"])

    # ------------------------------------------------------------------ #
    # SLOT KONTROLU CEKIMDEN ONCE
    # ------------------------------------------------------------------ #
    # Once cekip sonra "bolge dolu" demek, parayi alip iade surecine
    # sokmak olurdu. Yine de yaris ihtimali var (iki isletme ayni anda);
    # o durumda odeme alinir ve SAHIPSIZ TAHSILAT olarak gorunur.
    from .reklam import slot_durumu

    d = await slot_durumu(db, kapsam=paket["kapsam"], bolge_id=bolge_id,
                          kategori_id=kategori_id)
    if d["bos"] <= 0:
        raise HTTPException(status_code=409, detail="bolge_dolu")

    kdv_kurus, toplam = _kdv_hesapla(paket["fiyat_kurus"], paket["kdv_orani"])
    siparis_no = f"DK-{uuid.uuid4().hex[:16].upper()}"

    # ------------------------------------------------------------------ #
    # SATIN ALMA SATIRI ONCE YAZILIYOR — CEKIMDEN ONCE
    # ------------------------------------------------------------------ #
    # Cekim sirasinda surec olurse (deploy, OOM) elimizde HICBIR IZ
    # kalmamasindansa "beklemede" bir satir kalmasi yeglenir: o satir bir
    # sorudur ve sorulabilir. Iz birakmayan tahsilat sorulamaz.
    f = govde.fatura
    satin_alma_id = (
        await db.execute(
            text("""
                INSERT INTO reklam_satin_alma
                  (isletme_id, paket_id, tutar_kurus, kdv_orani, kdv_kurus,
                   toplam_kurus, fatura_unvan, fatura_vkn,
                   fatura_vergi_dairesi, fatura_adres, fatura_il,
                   fatura_ilce, fatura_eposta, saglayici, siparis_no,
                   durum)
                VALUES (:i, :p, :t, :ko, :kk, :top, :unvan, :vkn, :vd,
                        :adres, :il, :ilce, :eposta, :sg, :sip, 'beklemede')
                RETURNING id
            """),
            {"i": isletme_id, "p": paket["id"], "t": paket["fiyat_kurus"],
             "ko": paket["kdv_orani"], "kk": kdv_kurus, "top": toplam,
             "unvan": f.unvan, "vkn": f.vkn, "vd": f.vergi_dairesi,
             "adres": f.adres, "il": f.il, "ilce": f.ilce,
             "eposta": f.eposta, "sg": saglayici.ad, "sip": siparis_no},
        )
    ).scalar_one()
    # COMMIT: cekim uzun surebilir ve surec olursa satir KALMALI.
    await db.commit()

    # ------------------------------------------------------------------ #
    # CEKIM
    # ------------------------------------------------------------------ #
    if govde.odeme_yontemi_id is not None:
        kart = (
            await db.execute(
                text("SELECT kart_token, kullanici_token FROM odeme_yontemi "
                     "WHERE id = :i AND kullanici_id = :k AND durum='aktif'"),
                {"i": govde.odeme_yontemi_id, "k": kimlik.kullanici_id},
            )
        ).mappings().first()
        if kart is None:
            raise HTTPException(status_code=404, detail="odeme_yontemi_yok")
        sonuc = saglayici.sakli_kartla_cek(
            kart_token=kart["kart_token"],
            kullanici_token=kart["kullanici_token"] or "",
            tutar_kurus=toplam, aciklama=f"Dukkan reklam {paket['gun']} gun",
            siparis_no=siparis_no,
        )
    else:
        from ..config import settings

        sonuc = saglayici.odeme_baslat(
            tutar_kurus=toplam,
            aciklama=f"Dukkan reklam {paket['gun']} gun",
            siparis_no=siparis_no,
            donus_url=settings.odeme_donus_adresi,
            # KART BILGISI YOK — yalniz fatura alanlari.
            alici={"unvan": f.unvan, "vkn": f.vkn, "adres": f.adres},
        )

    await db.execute(
        text("UPDATE reklam_satin_alma SET durum = :d, "
             " saglayici_islem_id = :iid, hata = :h, saglayici_kodu = :sk, "
             " odendi_at = CASE WHEN :d = 'basarili' THEN now() END, "
             " updated_at = now() WHERE id = :i"),
        {"d": "basarili" if sonuc.basarili else
              ("yapilandirilmadi" if sonuc.durum == "yapilandirilmadi"
               else "reddedildi"),
         "iid": sonuc.islem_id, "h": sonuc.hata,
         "sk": sonuc.saglayici_kodu, "i": satin_alma_id},
    )

    if not sonuc.basarili:
        await db.commit()
        if sonuc.yonlendirme_url:
            # 3DS: islem BITMEDI, kullanici yonlendirilecek.
            return {"satin_alma_id": str(satin_alma_id),
                    "durum": "dogrulama_gerekli",
                    "reklam_id": None,
                    "yonlendirme_url": sonuc.yonlendirme_url}
        raise HTTPException(status_code=402, detail="odeme_reddedildi")

    # ------------------------------------------------------------------ #
    # ODEME BASARILI -> REKLAMI AC
    # ------------------------------------------------------------------ #
    reklam_id = await reklam_ac(
        db, isletme_id=isletme_id, paket_id=paket["id"],
        kapsam=paket["kapsam"], bolge_id=bolge_id,
        kategori_id=kategori_id, gun=paket["gun"])
    await db.execute(
        text("UPDATE reklam_satin_alma SET reklam_id = :r, updated_at=now() "
             "WHERE id = :i"),
        {"r": reklam_id, "i": satin_alma_id},
    )

    if govde.otomatik_yenile and govde.odeme_yontemi_id is not None:
        # ABONELIK ANCAK ACIKCA ISTENDIGINDE ve SAKLI KART VARSA dogar.
        # Kart yoksa yenileme yapilamaz; sessizce "acildi" demek, isletme
        # yenilendigini sanirken reklamin dusmesi demekti.
        sutun = KAPSAM_SUTUNU[paket["kapsam"]]
        await db.execute(
            text(f"INSERT INTO abonelik (isletme_id, paket_id, "
                 f" odeme_yontemi_id, kapsam, {sutun}, kategori_id, "
                 " sonraki_cekim) VALUES (:i, :p, :oy, :kap, :b, :kid, "
                 " now() + make_interval(days => :g))"),
            {"i": isletme_id, "p": paket["id"],
             "oy": govde.odeme_yontemi_id, "kap": paket["kapsam"],
             "b": bolge_id, "kid": kategori_id, "g": paket["gun"]},
        )

    await _denetim(db, aktor_id=kimlik.kullanici_id,
                   eylem="reklam_satin_alindi", hedef_tip="reklam",
                   hedef_id=reklam_id, istek=istek)
    return {"satin_alma_id": str(satin_alma_id), "durum": "basarili",
            "reklam_id": str(reklam_id), "yonlendirme_url": None}


# ===================================================================== #
# ODEME YONTEMI (SAKLANAN KART) — KART BILGISI ALINMAZ
# ===================================================================== #

class KartSaklaIstek(BaseModel):
    """Kart ALANLARI YOK — bilerek.

    Bu model kart numarasi, CVV ya da son kullanma tarihi TASIMIYOR ve
    tasimamali. Kullanici o bilgileri SAGLAYICININ sayfasinda girer;
    biz yalniz donen token'i saklariz.

    Modelin bu hali, kisiti TIP DUZEYINDE goruunur kiliyor: birisi kart
    numarasi eklemek isterse, once bu baslgi silmek zorunda kalir.
    """
    takma_ad: str = Field(min_length=1, max_length=60)


@router.post("/odeme-yontemi", status_code=201)
async def kart_sakla(
    govde: KartSaklaIstek,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Kart saklama akisini baslatir. Doner: {"id", "son_dort", "marka"}
    ya da {"yonlendirme_url"}.

    503 `odeme_yapilandirilmadi`: saglayici bagli degil.
    """
    saglayici = odeme_saglayicisi()
    if not saglayici.yapilandirildi_mi():
        raise HTTPException(status_code=503,
                            detail="odeme_yapilandirilmadi")

    from ..config import settings

    mevcut = (
        await db.execute(
            text("SELECT kullanici_token FROM odeme_yontemi "
                 "WHERE kullanici_id = :k AND kullanici_token IS NOT NULL "
                 "LIMIT 1"),
            {"k": kimlik.kullanici_id},
        )
    ).scalar_one_or_none()

    sonuc = saglayici.kart_sakla(
        kullanici_token=mevcut, kart_takma_ad=govde.takma_ad,
        donus_url=settings.odeme_donus_adresi,
    )
    if not sonuc.basarili or not sonuc.kart_token:
        raise HTTPException(status_code=502, detail="kart_saklanamadi")

    yeni = (
        await db.execute(
            text("INSERT INTO odeme_yontemi (kullanici_id, saglayici, "
                 " kart_token, kullanici_token, son_dort, marka, takma_ad) "
                 "VALUES (:k, :sg, :kt, :ut, :sd, :m, :ta) "
                 "ON CONFLICT (saglayici, kart_token) DO UPDATE SET "
                 "  durum='aktif', updated_at=now() "
                 "RETURNING id"),
            {"k": kimlik.kullanici_id, "sg": sonuc.saglayici,
             "kt": sonuc.kart_token, "ut": sonuc.kullanici_token,
             "sd": sonuc.son_dort, "m": sonuc.marka, "ta": govde.takma_ad},
        )
    ).scalar_one()
    return {"id": str(yeni), "son_dort": sonuc.son_dort,
            "marka": sonuc.marka}


@router.get("/odeme-yontemi")
async def odeme_yontemleri(
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Kullanicinin saklanan kartlari. Doner: {"items": [...]}.

    TOKEN DONMUYOR: token bir sirdir ve arayuzun ona ihtiyaci yok.
    Kullanici karti `id` ile secer; token yalniz sunucuda kullanilir.
    """
    satirlar = (
        await db.execute(
            text("SELECT id, son_dort, marka, takma_ad, varsayilan, "
                 "       created_at FROM odeme_yontemi "
                 "WHERE kullanici_id = :k AND durum = 'aktif' "
                 "ORDER BY varsayilan DESC, created_at DESC"),
            {"k": kimlik.kullanici_id},
        )
    ).mappings().all()
    return {"items": [dict(x) for x in satirlar]}


@router.delete("/odeme-yontemi/{yontem_id}")
async def kart_sil(
    yontem_id: uuid.UUID,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Karti kaldirir. Doner: {"silinen": n, "etkilenen_abonelik": n}.

    ABONELIK ETKISI DONUYOR: karti silen kullanici, o kartla yenilenen
    aboneliklerin duracagini BILMELI. Sessizce silmek, ay sonunda
    "reklamim neden dustu" sorusu uretirdi.
    """
    r = await db.execute(
        text("UPDATE odeme_yontemi SET durum='silindi', varsayilan=false, "
             " updated_at=now() "
             "WHERE id = :i AND kullanici_id = :k AND durum='aktif'"),
        {"i": yontem_id, "k": kimlik.kullanici_id},
    )
    # ==================================================================
    # IDOR — OLCULEN KUSUR (F8c, guvenlik taramasi)
    # ==================================================================
    # Ilk yazimda abonelik guncellemesi YALNIZ `odeme_yontemi_id` ile
    # eslesiyordu; sahiplik kosulu YOKTU.
    #
    # Sonuc: baskasinin kart kimligini gonderen bir saldirgan `silinen:
    # 0` alirdi (kart guncellemesi sahibe bagli) AMA O KULLANICININ
    # ABONELIKLERI DURAKLATILIRDI. Yani rakip bir isletmenin reklam
    # yenilemesi disaridan durdurulabilirdi — para kaybi ve gorunurluk
    # kaybi.
    #
    # Iki katmanli duzeltme:
    #   1. Kart silinmediyse HIC DEVAM ETME (erken donus).
    #   2. Abonelik sorgusu da SAHIPLIGE bagli (`oy.kullanici_id`)
    #      — birinci katman bir gun degisirse ikincisi hala korur.
    if r.rowcount == 0:
        return {"silinen": 0, "etkilenen_abonelik": 0}
    etkilenen = await db.execute(
        text("UPDATE abonelik a SET durum='duraklatildi', updated_at=now() "
             "FROM odeme_yontemi oy "
             "WHERE a.odeme_yontemi_id = oy.id AND oy.id = :i "
             "  AND oy.kullanici_id = :k AND a.durum = 'aktif'"),
        {"i": yontem_id, "k": kimlik.kullanici_id},
    )
    return {"silinen": r.rowcount, "etkilenen_abonelik": etkilenen.rowcount}


@router.post("/abonelik/{abonelik_id}/iptal")
async def abonelik_iptal(
    abonelik_id: uuid.UUID,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Otomatik yenilemeyi durdurur. Doner: {"iptal": n}.

    YAYINDAKI REKLAMI DUSURMEZ: isletme donemin parasini odedi, sonuna
    kadar yayinda kalir. Iptal, YENILENMEYECEGINI soyler.
    """
    isletme_id = (
        await db.execute(
            text("SELECT isletme_id FROM abonelik WHERE id = :i"),
            {"i": abonelik_id},
        )
    ).scalar_one_or_none()
    if isletme_id is None:
        raise HTTPException(status_code=404, detail="abonelik_yok")
    await _sahiplik_dogrula(db, kimlik.kullanici_id, isletme_id)
    r = await db.execute(
        text("UPDATE abonelik SET durum='iptal', iptal_at=now(), "
             " iptal_sebebi='kullanici', updated_at=now() "
             "WHERE id = :i AND durum IN ('aktif','duraklatildi',"
             "                            'odeme_basarisiz')"),
        {"i": abonelik_id},
    )
    return {"iptal": r.rowcount}
