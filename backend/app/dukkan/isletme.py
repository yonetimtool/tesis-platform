"""(DUKKAN F2) ISLETME UCLARI — arz tarafi.

===========================================================================
IZOLASYON SINIRI: SAHIPLIK
===========================================================================
Dukkan cok-kiracili degil; RLS yok (docs/dukkan/00-mimari.md K4). Sinir
`isletme.sahip_kullanici_id` ve TEK bir yardimcidan gecer:
`_sahiplik_dogrula`.

Ikinci bir yol ACILMAZ. Acilirsa, kontrolun atlandigi yer orasi olur.

**KURAL:** bu dosyadaki her `/isletme/{id}/...` ucu icin, BASKA bir
isletmenin sahibiyle cagrildiginda 403 bekleyen bir test ZORUNLUDUR.
`tests/test_dukkan_isletme_idor.py` bunu hem tek tek olcer hem de
"her ucun testi var mi" diye TARAR — testsiz uc eklenirse tarama duser.
"""
from __future__ import annotations

import re
import unicodedata
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from .kimlik import DukkanKimlik, kimlik_zorunlu
from .lokasyon_yukle import slugla
from .veritabani import get_dukkan_session

router = APIRouter(prefix="/dukkan", tags=["dukkan"])


# --------------------------------------------------------------------- #
# YARDIMCILAR
# --------------------------------------------------------------------- #

async def _sahiplik_dogrula(
    db: AsyncSession, kullanici_id: uuid.UUID, isletme_id: uuid.UUID
) -> dict:
    """Isletme bu kullaniciya mi ait? Doner: isletme satiri (dict).

    Ait DEGILSE 403, YOKSA 404.

    404 ile 403'u ayirmak bilincli: var olmayan bir kimlige 403 demek,
    "bu kimlik var ama senin degil" bilgisini sizdirirdi. Var olan ama
    baskasina ait olana 404 demek ise sahibine yanlis teshis verirdi.
    """
    satir = (
        await db.execute(
            text(
                "SELECT id, sahip_kullanici_id, ad, slug, durum, "
                "dogrulama_seviyesi FROM isletme WHERE id = :i"
            ),
            {"i": isletme_id},
        )
    ).mappings().first()
    if satir is None:
        raise HTTPException(status_code=404, detail="isletme_bulunamadi")
    if satir["sahip_kullanici_id"] != kullanici_id:
        raise HTTPException(status_code=403, detail="isletme_size_ait_degil")
    return dict(satir)


async def _benzersiz_slug(db: AsyncSession, ad: str) -> str:
    """Isletme adindan KALICI slug uretir. Doner: benzersiz slug.

    Cakisirsa sonuna sayi eklenir. Slug URL'in parcasi ve bir kez
    uretilip SAKLANIR; isletme adini degistirse bile slug degismez —
    degisseydi calisan bir baglanti sessizce olurdu.
    """
    taban = slugla(ad) or "isletme"
    aday = taban
    for n in range(2, 200):
        var = (
            await db.execute(
                text("SELECT 1 FROM isletme WHERE slug = :s"), {"s": aday}
            )
        ).first()
        if var is None:
            return aday
        aday = f"{taban}-{n}"
    # 200 denemede bulunamadiysa rastgele son ek. Sessizce cakisan bir
    # slug dondurmek yerine kesin benzersiz bir sey uretiyoruz.
    return f"{taban}-{uuid.uuid4().hex[:6]}"


async def _denetim(
    db: AsyncSession,
    *,
    aktor_id: uuid.UUID | None,
    eylem: str,
    hedef_tip: str,
    hedef_id: uuid.UUID,
    gerekce: str | None = None,
    istek: Request | None = None,
) -> None:
    """Denetim satiri yazar. Doner: None. Tablo APPEND-ONLY (goc 0115)."""
    await db.execute(
        text(
            "INSERT INTO denetim (aktor_id, eylem, hedef_tip, hedef_id, gerekce, ip) "
            "VALUES (:a, :e, :ht, :hi, :g, :ip)"
        ),
        {
            "a": aktor_id, "e": eylem, "ht": hedef_tip, "hi": hedef_id,
            "g": gerekce,
            "ip": (istek.headers.get("x-forwarded-for", "").split(",")[0].strip()
                   or None) if istek else None,
        },
    )


# --------------------------------------------------------------------- #
# SEMALAR
# --------------------------------------------------------------------- #

class IsletmeOlustur(BaseModel):
    ad: str = Field(min_length=2, max_length=160)
    telefon: str = Field(min_length=7, max_length=32)
    aciklama: str | None = Field(default=None, max_length=4000)
    eposta: str | None = None
    whatsapp: str | None = None
    vergi_no: str | None = Field(default=None, max_length=11)
    vergi_dairesi: str | None = None
    adres_mahalle_slug: str | None = None
    adres_il_slug: str | None = None
    adres_ilce_slug: str | None = None
    adres_detay: str | None = None


class IsletmeGuncelle(BaseModel):
    ad: str | None = Field(default=None, min_length=2, max_length=160)
    telefon: str | None = None
    aciklama: str | None = Field(default=None, max_length=4000)
    eposta: str | None = None
    whatsapp: str | None = None
    vergi_no: str | None = Field(default=None, max_length=11)
    vergi_dairesi: str | None = None
    adres_detay: str | None = None


class SlugListesi(BaseModel):
    slugler: list[str] = Field(default_factory=list, max_length=500)


class MahalleListesi(BaseModel):
    # Mahalle KIMLIKLERI (slug degil): mahalle slug'i yalniz ILCE ICINDE
    # benzersiz, dolayisiyla tek basina bir mahalleyi tanimlamaz.
    mahalle_idler: list[uuid.UUID] = Field(default_factory=list, max_length=2000)


def _vergi_no_gecerli(v: str) -> bool:
    """VKN/TCKN bicim kontrolu. Doner: True/False.

    YALNIZCA BICIM. Gercekten var olan bir mukellefi gostermez —
    dogrulama V1'de INSAN incelemesiyle yapiliyor
    (docs/dukkan/03-guven-ve-fraud.md §3). Burada 'dogrulandi' izlenimi
    UYANDIRMAMAK icin ad bilerek `_gecerli` degil bicim kontrolu.
    """
    return v.isdigit() and len(v) in (10, 11)


# --------------------------------------------------------------------- #
# UCLAR
# --------------------------------------------------------------------- #

@router.post("/isletme", status_code=201)
async def isletme_olustur(
    govde: IsletmeOlustur,
    istek: Request,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Yeni isletme kaydi acar. Doner: {"id", "slug", "durum", ...}.

    Kayit `taslak` baslar — `onay_bekliyor` DEGIL. Sebep: profil eksikken
    kuyruga dusen basvuru moderatorun zamanini harcar ve reddedilir;
    kullanici da neden reddedildigini anlamaz. Basvuru ACIK bir eylemle
    yapilir (`/basvur`).
    """
    if govde.vergi_no and not _vergi_no_gecerli(govde.vergi_no):
        raise HTTPException(status_code=422, detail="vergi_no_bicimi_gecersiz")

    mahalle_id = None
    if govde.adres_mahalle_slug:
        satir = (
            await db.execute(
                text(
                    "SELECT m.id FROM mahalle m "
                    "JOIN ilce ic ON ic.id = m.ilce_id "
                    "JOIN il i ON i.id = ic.il_id "
                    "WHERE i.slug = :il AND ic.slug = :ilce AND m.slug = :m"
                ),
                {
                    "il": govde.adres_il_slug,
                    "ilce": govde.adres_ilce_slug,
                    "m": govde.adres_mahalle_slug,
                },
            )
        ).first()
        if satir is None:
            raise HTTPException(status_code=422, detail="mahalle_bulunamadi")
        mahalle_id = satir[0]

    slug = await _benzersiz_slug(db, govde.ad)
    yeni = (
        await db.execute(
            text(
                "INSERT INTO isletme (sahip_kullanici_id, ad, slug, telefon, "
                " aciklama, eposta, whatsapp, vergi_no, vergi_dairesi, "
                " adres_mahalle_id, adres_detay) "
                "VALUES (:s, :ad, :slug, :tel, :ac, :ep, :wa, :vn, :vd, :mid, :adet) "
                "RETURNING id, slug, durum, dogrulama_seviyesi"
            ),
            {
                "s": kimlik.kullanici_id, "ad": govde.ad, "slug": slug,
                "tel": govde.telefon, "ac": govde.aciklama, "ep": govde.eposta,
                "wa": govde.whatsapp, "vn": govde.vergi_no,
                "vd": govde.vergi_dairesi, "mid": mahalle_id,
                "adet": govde.adres_detay,
            },
        )
    ).mappings().one()

    # Kullanici artik isletme sahibi.
    await db.execute(
        text("UPDATE dukkan_kullanici SET tip = 'isletme_sahibi', "
             "updated_at = now() WHERE id = :k"),
        {"k": kimlik.kullanici_id},
    )
    await _denetim(db, aktor_id=kimlik.kullanici_id, eylem="isletme_olustur",
                   hedef_tip="isletme", hedef_id=yeni["id"], istek=istek)
    return dict(yeni)


@router.get("/isletme/benim")
async def benim_isletmelerim(
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Kullanicinin KENDI isletmeleri. Doner: {"items": [...]}.

    Yol `/isletme/benim` — `/isletme/{id}` deseninden ONCE tanimli olmali
    yoksa "benim" bir kimlik sanilir. Router sirasi bunu sagliyor.
    """
    satirlar = (
        await db.execute(
            text(
                "SELECT id, ad, slug, durum, dogrulama_seviyesi, telefon, "
                "       red_sebebi, askiya_alma_sebebi, created_at "
                "FROM isletme WHERE sahip_kullanici_id = :k "
                "ORDER BY created_at DESC"
            ),
            {"k": kimlik.kullanici_id},
        )
    ).mappings().all()
    return {"items": [dict(x) for x in satirlar]}


@router.get("/isletme/{isletme_id}")
async def isletme_detay(
    isletme_id: uuid.UUID,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Sahibinin gordugu TAM detay. Doner: isletme + kategoriler + alanlar.

    Kamu profili AYRI bir uctur (F3): burada vergi no ve red sebebi gibi
    YALNIZ SAHIBE ait alanlar var.
    """
    await _sahiplik_dogrula(db, kimlik.kullanici_id, isletme_id)
    satir = (
        await db.execute(
            text("SELECT * FROM isletme WHERE id = :i"), {"i": isletme_id}
        )
    ).mappings().one()
    kategoriler = [
        r[0] for r in (
            await db.execute(
                text("SELECT k.slug FROM isletme_kategori ik "
                     "JOIN kategori k ON k.id = ik.kategori_id "
                     "WHERE ik.isletme_id = :i ORDER BY k.slug"),
                {"i": isletme_id},
            )
        ).all()
    ]
    alanlar = (
        await db.execute(
            text(
                "SELECT m.id, m.ad, ic.ad AS ilce, i.ad AS il "
                "FROM isletme_hizmet_alani ha "
                "JOIN mahalle m ON m.id = ha.mahalle_id "
                "JOIN ilce ic ON ic.id = m.ilce_id "
                "JOIN il i ON i.id = ic.il_id "
                "WHERE ha.isletme_id = :i ORDER BY i.ad, ic.ad, m.ad"
            ),
            {"i": isletme_id},
        )
    ).mappings().all()
    d = dict(satir)
    d["kategoriler"] = kategoriler
    d["hizmet_alanlari"] = [dict(x) for x in alanlar]
    return d


@router.patch("/isletme/{isletme_id}")
async def isletme_guncelle(
    isletme_id: uuid.UUID,
    govde: IsletmeGuncelle,
    istek: Request,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Isletme alanlarini gunceller. Doner: {"guncellenen": <alan sayisi>}.

    SAYI DONDURUYOR (P217 dersi): sifir alan guncellendiyse arayuz
    "Kaydedildi" DEMEMELI. Sessizce hicbir sey yapmamak, hata vermekten
    daha kotudur — kullanici kaydettigini saNIr.
    """
    mevcut = await _sahiplik_dogrula(db, kimlik.kullanici_id, isletme_id)

    alanlar = govde.model_dump(exclude_unset=True)
    if govde.vergi_no is not None and govde.vergi_no != "" and not _vergi_no_gecerli(
        govde.vergi_no
    ):
        raise HTTPException(status_code=422, detail="vergi_no_bicimi_gecersiz")
    if not alanlar:
        raise HTTPException(status_code=422, detail="guncellenecek_alan_yok")

    # TELEFON DEGISTIRILIRSE DOGRULAMA DUSER. Aksi halde bir isletme
    # dogrulanmis bir numarayla seviye 1 alip sonra numarayi degistirerek
    # rozeti DOGRULANMAMIS bir numaraya tasiyabilirdi.
    telefon_degisti = "telefon" in alanlar and alanlar["telefon"]

    set_parcalari = [f"{k} = :{k}" for k in alanlar]
    if telefon_degisti:
        set_parcalari.append("telefon_dogrulandi_at = NULL")
        if mevcut["dogrulama_seviyesi"] == 1:
            set_parcalari.append("dogrulama_seviyesi = 0")
    set_parcalari.append("updated_at = now()")

    sonuc = await db.execute(
        text(f"UPDATE isletme SET {', '.join(set_parcalari)} WHERE id = :__id"),
        {**alanlar, "__id": isletme_id},
    )
    await _denetim(db, aktor_id=kimlik.kullanici_id, eylem="isletme_guncelle",
                   hedef_tip="isletme", hedef_id=isletme_id, istek=istek)
    return {
        "guncellenen": len(alanlar),
        "satir": sonuc.rowcount,
        "telefon_dogrulamasi_dustu": bool(telefon_degisti),
    }


@router.put("/isletme/{isletme_id}/kategoriler")
async def kategorileri_ayarla(
    isletme_id: uuid.UUID,
    govde: SlugListesi,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Isletmenin kategorilerini TAMAMEN degistirir.

    Doner: {"eklenen": n, "bulunamayan": [...]}.

    BULUNAMAYAN SLUGLER SESSIZCE YUTULMAZ: yanlis yazilmis bir slug
    listeden dusup "kaydedildi" denseydi, isletme sahibi kategorisini
    sectigini sanip hic talep almazdi — ve sebebini asla ogrenemezdi.
    """
    await _sahiplik_dogrula(db, kimlik.kullanici_id, isletme_id)

    bulunan: dict[str, uuid.UUID] = {}
    if govde.slugler:
        satirlar = (
            await db.execute(
                text("SELECT id, slug FROM kategori "
                     "WHERE slug = ANY(:s) AND aktif AND ust_id IS NOT NULL"),
                {"s": list(govde.slugler)},
            )
        ).all()
        bulunan = {s: i for i, s in satirlar}

    bulunamayan = [s for s in govde.slugler if s not in bulunan]
    if bulunamayan:
        raise HTTPException(
            status_code=422,
            detail=f"kategori_bulunamadi:{','.join(sorted(bulunamayan)[:10])}",
        )

    await db.execute(
        text("DELETE FROM isletme_kategori WHERE isletme_id = :i"),
        {"i": isletme_id},
    )
    for kid in bulunan.values():
        await db.execute(
            text("INSERT INTO isletme_kategori (isletme_id, kategori_id) "
                 "VALUES (:i, :k)"),
            {"i": isletme_id, "k": kid},
        )
    return {"eklenen": len(bulunan)}


@router.put("/isletme/{isletme_id}/hizmet-alanlari")
async def hizmet_alanlarini_ayarla(
    isletme_id: uuid.UUID,
    govde: MahalleListesi,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Hizmet verilen mahalleleri TAMAMEN degistirir.

    Doner: {"eklenen": n}.

    Bu tablo ESLESME MOTORUNUN TAMAMI: bir talep mahalleye duser ve
    isletmeler buradan bulunur. Bos birakilan bir isletme HICBIR talep
    gormez — bu yuzden `/basvur` bos hizmet alanini reddeder.
    """
    await _sahiplik_dogrula(db, kimlik.kullanici_id, isletme_id)

    idler = list({str(x) for x in govde.mahalle_idler})
    gecerli: list[uuid.UUID] = []
    if idler:
        gecerli = [
            r[0] for r in (
                await db.execute(
                    text("SELECT id FROM mahalle WHERE id = ANY(CAST(:m AS uuid[]))"),
                    {"m": idler},
                )
            ).all()
        ]
        if len(gecerli) != len(idler):
            # Sessizce dusurmek, isletmenin sectigini sandigi bir bolgeden
            # hic talep almamasi demekti.
            raise HTTPException(status_code=422, detail="mahalle_bulunamadi")

    await db.execute(
        text("DELETE FROM isletme_hizmet_alani WHERE isletme_id = :i"),
        {"i": isletme_id},
    )
    for mid in gecerli:
        await db.execute(
            text("INSERT INTO isletme_hizmet_alani (isletme_id, mahalle_id) "
                 "VALUES (:i, :m)"),
            {"i": isletme_id, "m": mid},
        )
    return {"eklenen": len(gecerli)}


@router.post("/isletme/{isletme_id}/basvur")
async def onaya_gonder(
    isletme_id: uuid.UUID,
    istek: Request,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Isletmeyi moderasyon kuyruguna gonderir. Doner: {"durum": ...}.

    ON KOSULLAR BURADA VE ACIKCA: eksikleri kuyruga birakip moderatore
    reddettirmek, hem moderatorun zamanini harcar hem kullaniciya
    gerekcesiz bir ret gosterirdi. Eksikler TEK SEFERDE ve ADIYLA doner.
    """
    isl = await _sahiplik_dogrula(db, kimlik.kullanici_id, isletme_id)
    if isl["durum"] == "askida":
        raise HTTPException(status_code=409, detail="isletme_askida")
    if isl["durum"] == "onayli":
        raise HTTPException(status_code=409, detail="isletme_zaten_onayli")

    eksikler: list[str] = []
    kat = (await db.execute(
        text("SELECT count(*) FROM isletme_kategori WHERE isletme_id = :i"),
        {"i": isletme_id})).scalar_one()
    if not kat:
        eksikler.append("kategori")
    alan = (await db.execute(
        text("SELECT count(*) FROM isletme_hizmet_alani WHERE isletme_id = :i"),
        {"i": isletme_id})).scalar_one()
    if not alan:
        eksikler.append("hizmet_alani")
    tel_ok = (await db.execute(
        text("SELECT telefon_dogrulandi_at FROM isletme WHERE id = :i"),
        {"i": isletme_id})).scalar_one()
    if tel_ok is None:
        eksikler.append("telefon_dogrulama")

    if eksikler:
        raise HTTPException(
            status_code=422, detail=f"basvuru_eksik:{','.join(eksikler)}"
        )

    await db.execute(
        text("UPDATE isletme SET durum = 'onay_bekliyor', red_sebebi = NULL, "
             "updated_at = now() WHERE id = :i"),
        {"i": isletme_id},
    )
    await _denetim(db, aktor_id=kimlik.kullanici_id, eylem="isletme_basvuru",
                   hedef_tip="isletme", hedef_id=isletme_id, istek=istek)
    return {"durum": "onay_bekliyor"}


# --------------------------------------------------------------------- #
# BELGE
# --------------------------------------------------------------------- #

#: Kabul edilen belge tipleri. `vergi_levhasi` OZEL: onaylandiginda
#: isletmeyi seviye 2'ye ("Dogrulanmis isletme") tasir (moderasyon.py).
BELGE_TIPLERI = ("vergi_levhasi", "ustalik_belgesi", "sicil", "diger")

#: Belge bir GORSEL ya da PDF olabilir. Liste DAR tutuluyor: genis bir
#: liste, tarayicida calisabilecek bir icerik tipini (orn. SVG) depoya
#: sokar ve moderatorun tarayicisinda calisan bir dosya olurdu.
BELGE_ICERIK_TIPLERI = (
    "image/jpeg", "image/png", "image/webp", "application/pdf",
)


class BelgeYukleIstek(BaseModel):
    tip: str = Field(pattern="^(vergi_levhasi|ustalik_belgesi|sicil|diger)$")
    content_type: str
    dosya_adi: str | None = None


@router.post("/isletme/{isletme_id}/belge/presign")
async def belge_presign(
    isletme_id: uuid.UUID,
    govde: BelgeYukleIstek,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Belge yuklemek icin imzali PUT adresi uretir.

    Doner: {"belge_id", "key", "url", "expires_in"}

    PRESIGN, sunucu uzerinden yukleme DEGIL: sunucuyu megabaytlarca ikili
    veriye araci yapmamak icin (`app/storage.py` ayni gerekceyi tasiyor).

    Belge satiri `bekliyor` durumunda ONCEDEN acilir. Sebep: PUT
    tamamlanmazsa ortada sahipsiz bir dosya degil, durumu belli bir KAYIT
    kalir — moderator "yuklenmis ama acilmiyor" diyebilir. Once dosya
    yuklenip sonra kayit acilsaydi, yarim kalan yuklemeler depoda
    izlenemez cop birakirdi.
    """
    await _sahiplik_dogrula(db, kimlik.kullanici_id, isletme_id)
    if govde.content_type not in BELGE_ICERIK_TIPLERI:
        raise HTTPException(status_code=422, detail="belge_turu_desteklenmiyor")

    from ..storage import presign_put_anahtar

    # Anahtari BURADA uretiyoruz. `presign_put` `{id}/tasks/...` bicimini
    # dayatiyor ve bir isletme belgesi "tasks" altinda yasamamali: depoda
    # hangi dosyanin nereye ait oldugu YOLDAN okunabilmeli, iki urunun ad
    # alani birbirine karismamali.
    uzanti = {
        "image/jpeg": ".jpg", "image/png": ".png",
        "image/webp": ".webp", "application/pdf": ".pdf",
    }[govde.content_type]
    key = f"dukkan/isletme/{isletme_id}/belge/{uuid.uuid4().hex}{uzanti}"
    key, url, sure = presign_put_anahtar(key, govde.content_type)
    yeni = (
        await db.execute(
            text(
                "INSERT INTO isletme_belge (isletme_id, tip, dosya_yolu) "
                "VALUES (:i, :t, :k) RETURNING id"
            ),
            {"i": isletme_id, "t": govde.tip, "k": key},
        )
    ).mappings().one()
    return {
        "belge_id": str(yeni["id"]), "key": key, "url": url, "expires_in": sure,
    }


@router.get("/isletme/{isletme_id}/belge")
async def belgeler(
    isletme_id: uuid.UUID,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Isletmenin belgeleri ve INCELEME DURUMU. Doner: {"items": [...]}.

    Isletme sahibi belgesinin incelenip incelenmedigini GOREBILMELI —
    goremezse "yukledim ama bir sey olmuyor" durumunda kalir ve destek
    yuku yaratir. Moderatorun ADI donmuyor, yalnizca durum ve tarih:
    moderator kimligi isletme sahibine karsi korunmali.
    """
    await _sahiplik_dogrula(db, kimlik.kullanici_id, isletme_id)
    satirlar = (
        await db.execute(
            text(
                "SELECT id, tip, durum, not_metni, incelendi_at, created_at "
                "FROM isletme_belge WHERE isletme_id = :i ORDER BY created_at DESC"
            ),
            {"i": isletme_id},
        )
    ).mappings().all()
    return {"items": [dict(x) for x in satirlar]}


@router.post("/isletme/{isletme_id}/telefon/kod")
async def isletme_telefon_kod(
    isletme_id: uuid.UUID,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Isletme telefonuna dogrulama kodu uretir. Doner: {"gonderildi": ...}.

    ISLETME TELEFONU, SAHIBIN TELEFONUNDAN AYRI dogrulanir. Sahibin kendi
    numarasi dogrulanmis olsa bile isletmenin numarasi baska bir
    numaradir ve kullanicinin ARAYACAGI numara odur.
    """
    await _sahiplik_dogrula(db, kimlik.kullanici_id, isletme_id)
    from .kimlik import (
        gonderilmis_kod_sayisi,
        kod_gonder_ve_kaydet,
        telefon_normalize,
    )

    tam = (
        await db.execute(
            text("SELECT telefon FROM isletme WHERE id = :i"), {"i": isletme_id}
        )
    ).scalar_one()
    telefon = telefon_normalize(tam)

    # Sinir YALNIZ gonderilmis kodlari sayar (bkz. `kod_gonder_ve_kaydet`).
    if await gonderilmis_kod_sayisi(
        db, telefon=telefon, amac="isletme_telefon"
    ) >= 5:
        raise HTTPException(status_code=429, detail="kod_istegi_cok_sik")

    yanit = await kod_gonder_ve_kaydet(
        db, telefon=telefon, amac="isletme_telefon"
    )
    if not yanit["gonderildi"]:
        # Gerekce `auth_uclar.py`de yazili: 200 + `gonderildi: false`
        # istemciyi "basarili" dalina sokar ve kullaniciya gelmeyecek bir
        # kodun bekleme ekranini gosterirdi.
        raise HTTPException(status_code=503, detail=f"sms_{yanit['gonderim']}")
    return yanit


class TelefonDogrula(BaseModel):
    kod: str = Field(min_length=6, max_length=6)


@router.post("/isletme/{isletme_id}/telefon/dogrula")
async def isletme_telefon_dogrula(
    isletme_id: uuid.UUID,
    govde: TelefonDogrula,
    istek: Request,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Isletme telefonunu dogrular. Doner: {"dogrulama_seviyesi": n}.

    Basarida seviye en az 1 olur -> isletme ARAMADA GORUNEBILIR hale
    gelir (moderator onayindan sonra). Seviye 0 aramada cikmaz cunku
    kayit ucretsiz ve aninda; gorunur kilmak sahte isletmeyi davet
    etmek olurdu.
    """
    await _sahiplik_dogrula(db, kimlik.kullanici_id, isletme_id)
    from .kimlik import OTP_MAKS_DENEME, kod_dogru_mu, telefon_normalize

    tam = (
        await db.execute(
            text("SELECT telefon FROM isletme WHERE id = :i"), {"i": isletme_id}
        )
    ).scalar_one()
    telefon = telefon_normalize(tam)

    kayit = (
        await db.execute(
            text("SELECT id, kod_hash, deneme, gecerlilik, kullanildi_at "
                 "FROM telefon_dogrulama WHERE telefon = :t "
                 "AND amac = 'isletme_telefon' ORDER BY created_at DESC LIMIT 1"),
            {"t": telefon},
        )
    ).mappings().first()
    if kayit is None:
        raise HTTPException(status_code=404, detail="kod_bulunamadi")
    if kayit["kullanildi_at"] is not None:
        raise HTTPException(status_code=409, detail="kod_kullanilmis")
    if kayit["deneme"] >= OTP_MAKS_DENEME:
        raise HTTPException(status_code=429, detail="cok_fazla_deneme")

    from datetime import datetime, timezone

    if kayit["gecerlilik"] < datetime.now(timezone.utc):
        raise HTTPException(status_code=410, detail="kod_suresi_doldu")

    if not kod_dogru_mu(govde.kod, telefon, kayit["kod_hash"]):
        await db.execute(
            text("UPDATE telefon_dogrulama SET deneme = deneme + 1 WHERE id = :i"),
            {"i": kayit["id"]},
        )
        raise HTTPException(status_code=401, detail="kod_hatali")

    await db.execute(
        text("UPDATE telefon_dogrulama SET kullanildi_at = now() WHERE id = :i"),
        {"i": kayit["id"]},
    )
    await db.execute(
        text("UPDATE isletme SET telefon_dogrulandi_at = now(), "
             "dogrulama_seviyesi = GREATEST(dogrulama_seviyesi, 1), "
             "updated_at = now() WHERE id = :i"),
        {"i": isletme_id},
    )
    await _denetim(db, aktor_id=kimlik.kullanici_id,
                   eylem="isletme_telefon_dogrulandi", hedef_tip="isletme",
                   hedef_id=isletme_id, istek=istek)
    seviye = (
        await db.execute(
            text("SELECT dogrulama_seviyesi FROM isletme WHERE id = :i"),
            {"i": isletme_id},
        )
    ).scalar_one()
    return {"dogrulama_seviyesi": seviye, "telefon_dogrulandi": True}
