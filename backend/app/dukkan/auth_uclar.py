"""(DUKKAN F2) KIMLIK UCLARI — telefon OTP + Yonetiyor SSO koprusu.

===========================================================================
NEDEN TELEFON, NEDEN E-POSTA DEGIL
===========================================================================
Olculdu: Yonetiyor'da `uq_app_user_telefon` telefonu GLOBAL benzersiz
yapar; e-posta yalnizca TESIS ICINDE benzersizdir. Dolayisiyla e-posta bir
KISIYI tekillestiremez ve iki tesisteki iki FARKLI insan tek Dukkan
hesabinda birlesebilirdi.

Ayrica telefon dogrulamasi bir MALIYET kapisi: her hesap bir SIM demek.
Cok hesaplilik (T8) sahte yorumun ve sahte isletmenin carpani; ucretsiz
e-posta hesabi bu carpani sinirsiz yapardi.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from .kimlik import (
    OTP_MAKS_DENEME,
    OTP_OMRU_DK,
    DukkanKimlik,
    kimlik_zorunlu,
    kod_dogru_mu,
    kod_hashle,
    kod_uret,
    jeton_uret,
    telefon_normalize,
)
from .kopru import yonetiyor_kimligi, yonetiyor_oturumu
from .veritabani import get_dukkan_session

router = APIRouter(prefix="/dukkan/auth", tags=["dukkan"])

#: Ayni numaraya saatte en fazla kac kod. Kotasiz birakmak, bir numarayi
#: SMS bombardimanina acmak (ve SMS maliyetini birinin faturasina yazmak)
#: demekti.
SAATLIK_KOD_SINIRI = 5


class KodIste(BaseModel):
    telefon: str = Field(min_length=7, max_length=32)


class KodDogrula(BaseModel):
    telefon: str = Field(min_length=7, max_length=32)
    kod: str = Field(min_length=6, max_length=6)
    ad_soyad: str | None = Field(default=None, max_length=120)


def _ip(istek: Request) -> str | None:
    return istek.headers.get("x-forwarded-for", "").split(",")[0].strip() or None


@router.post("/telefon/kod")
async def kod_gonder(
    govde: KodIste,
    istek: Request,
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Telefona dogrulama kodu uretir. Doner: {"gonderildi": true, ...}.

    KOD YANITTA DONMEZ (dev disinda): donseydi telefon dogrulamasinin
    tamami anlamsiz olurdu — kimligi kanitlamayan bir numaraya kod
    gonderip ayni yanittan okumak, dogrulama degil formalite olurdu.

    Gonderim saglayicisi F2'de BAGLI DEGIL; kod uretilir ve saklanir.
    Bu durum yanitta ACIKCA belirtiliyor (`gonderim`), sessizce
    "gonderildi" denmiyor.
    """
    telefon = telefon_normalize(govde.telefon)

    son_saat = (
        await db.execute(
            text(
                "SELECT count(*) FROM telefon_dogrulama "
                "WHERE telefon = :t AND created_at > now() - interval '1 hour'"
            ),
            {"t": telefon},
        )
    ).scalar_one()
    if son_saat >= SAATLIK_KOD_SINIRI:
        raise HTTPException(status_code=429, detail="kod_istegi_cok_sik")

    kod = kod_uret()
    await db.execute(
        text(
            "INSERT INTO telefon_dogrulama "
            "(telefon, kod_hash, amac, gecerlilik, ip) "
            "VALUES (:t, :h, 'giris', now() + make_interval(mins => :d), :ip)"
        ),
        {"t": telefon, "h": kod_hashle(kod, telefon), "d": OTP_OMRU_DK,
         "ip": _ip(istek)},
    )
    from ..config import settings

    yanit: dict = {
        "gonderildi": True,
        "gecerlilik_dk": OTP_OMRU_DK,
        # SESSIZ BASARISIZLIK YOK: SMS saglayicisi bagli degilse bunu
        # SOYLUYORUZ. "gonderildi: true" deyip hicbir sey gondermemek,
        # kullaniciyi olmayan bir SMS'i beklerken birakirdi.
        "gonderim": "saglayici_bagli_degil",
    }
    # KODU YANITTA DONDURMEK YALNIZ ACIK BIR AYARLA MUMKUN ve varsayilan
    # KAPALI. "ortam != production" gibi bir kosul kullanmadim bilerek:
    # ortam degiskeni prod'da yanlis/eksik gelirse kod SESSIZCE herkese
    # acilirdi — ve telefon dogrulamasinin tamami anlamsizlasirdi.
    # Guvenli yon: acikca acilmadikca KAPALI.
    if settings.dukkan_otp_yanitta:
        yanit["dev_kod"] = kod
    return yanit


@router.post("/telefon/dogrula")
async def kod_dogrula(
    govde: KodDogrula,
    istek: Request,
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Kodu dogrular, kullaniciyi acar/bulur ve jeton doner.

    Doner: {"access_token", "kullanici": {...}, "yeni_kayit": bool}
    """
    telefon = telefon_normalize(govde.telefon)
    kayit = (
        await db.execute(
            text(
                "SELECT id, kod_hash, deneme, gecerlilik, kullanildi_at "
                "FROM telefon_dogrulama "
                "WHERE telefon = :t AND amac = 'giris' "
                "ORDER BY created_at DESC LIMIT 1"
            ),
            {"t": telefon},
        )
    ).mappings().first()
    if kayit is None:
        raise HTTPException(status_code=404, detail="kod_bulunamadi")
    if kayit["kullanildi_at"] is not None:
        raise HTTPException(status_code=409, detail="kod_kullanilmis")
    if kayit["gecerlilik"] < datetime.now(timezone.utc):
        raise HTTPException(status_code=410, detail="kod_suresi_doldu")
    if kayit["deneme"] >= OTP_MAKS_DENEME:
        # Deneme siniri OLMASAYDI 6 haneli kod kaba kuvvetle kirilirdi.
        raise HTTPException(status_code=429, detail="cok_fazla_deneme")

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

    mevcut = (
        await db.execute(
            text("SELECT id, durum FROM dukkan_kullanici WHERE telefon = :t"),
            {"t": telefon},
        )
    ).mappings().first()
    yeni_kayit = mevcut is None
    if mevcut is None:
        satir = (
            await db.execute(
                text(
                    "INSERT INTO dukkan_kullanici "
                    "(telefon, telefon_dogrulandi_at, ad_soyad, kvkk_onay_at, "
                    " son_giris_at) "
                    "VALUES (:t, now(), :ad, now(), now()) RETURNING id"
                ),
                {"t": telefon, "ad": govde.ad_soyad},
            )
        ).mappings().one()
        kullanici_id = satir["id"]
    else:
        if mevcut["durum"] == "askida":
            raise HTTPException(status_code=403, detail="hesap_askida")
        kullanici_id = mevcut["id"]
        await db.execute(
            text("UPDATE dukkan_kullanici SET telefon_dogrulandi_at = "
                 "COALESCE(telefon_dogrulandi_at, now()), son_giris_at = now() "
                 "WHERE id = :i"),
            {"i": kullanici_id},
        )

    return {
        "access_token": jeton_uret(kullanici_id, telefon),
        "token_type": "bearer",
        "yeni_kayit": yeni_kayit,
        "kullanici": {"id": str(kullanici_id), "telefon": telefon},
    }


@router.post("/yonetiyor")
async def yonetiyor_sso(
    istek: Request,
    authorization: str | None = Header(default=None),
    db: AsyncSession = Depends(get_dukkan_session),
    yon_db: AsyncSession = Depends(yonetiyor_oturumu),
) -> dict:
    """Yonetiyor jetonuyla Dukkan'a giris. Doner: Dukkan jetonu ya da 409.

    IKI OTURUM ALIYOR ve bu SINIRIN GORUNUR HALI:
      * `yon_db` (app_rw)   -> yalniz `kopru.py` uzerinden okunur,
      * `db`    (dukkan_app) -> Dukkan tablolari; `public`e ERISEMEZ.

    409 `telefon_gerekli`: Yonetiyor kullanicisinin telefonu YOKSA
    bag kurulamaz. Bu NADIR BIR KENAR DURUM DEGIL — olculdu: 3104
    kullanicinin 837'sinde (%27) telefon yok. Istemci bunu bir hata
    ekrani gibi degil, akisin normal bir dali gibi ele almali ve
    `/telefon/kod` akisina yonlendirmeli.
    """
    from ..security import decode_token  # yerel import: dongusel bagimlilik yok

    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="kimlik_gerekli")
    try:
        veri = decode_token(
            authorization.split(" ", 1)[1].strip(), expected_type="access"
        )
    except Exception:
        raise HTTPException(status_code=401, detail="yonetiyor_jetonu_gecersiz")

    user_id = veri.get("sub")
    tenant_id = veri.get("tenant_id")
    if not user_id or not tenant_id:
        # Dukkan jetonu buraya gecemez: onda `tenant_id` YOK.
        raise HTTPException(status_code=401, detail="yonetiyor_jetonu_gecersiz")

    kimlik = await yonetiyor_kimligi(
        yon_db, user_id=user_id, tenant_id=tenant_id
    )
    if kimlik is None:
        raise HTTPException(status_code=401, detail="yonetiyor_kullanicisi_yok")
    if not kimlik.telefon:
        raise HTTPException(status_code=409, detail="telefon_gerekli")

    telefon = telefon_normalize(kimlik.telefon)
    mevcut = (
        await db.execute(
            text("SELECT id, durum FROM dukkan_kullanici WHERE telefon = :t"),
            {"t": telefon},
        )
    ).mappings().first()

    if mevcut is None:
        # TELEFON DOGRULAMASI DEVRALINIR: Yonetiyor onu zaten SMS ile
        # dogrulamis. Kullaniciyi bir kez daha OTP'ye sokmak, hicbir
        # guvenlik kazanci olmadan SSO'nun butun anlamini yok ederdi.
        satir = (
            await db.execute(
                text(
                    "INSERT INTO dukkan_kullanici "
                    "(telefon, telefon_dogrulandi_at, ad_soyad, kvkk_onay_at, "
                    " son_giris_at) VALUES (:t, now(), :ad, now(), now()) "
                    "RETURNING id"
                ),
                {"t": telefon, "ad": kimlik.ad_soyad or None},
            )
        ).mappings().one()
        kullanici_id = satir["id"]
    else:
        if mevcut["durum"] == "askida":
            raise HTTPException(status_code=403, detail="hesap_askida")
        kullanici_id = mevcut["id"]
        await db.execute(
            text("UPDATE dukkan_kullanici SET son_giris_at = now() WHERE id = :i"),
            {"i": kullanici_id},
        )

    # Bag: ayni kisi BIRDEN COK TESISTE olabilir -> her tesis icin bir satir.
    await db.execute(
        text(
            "INSERT INTO dukkan_yonetiyor_bag "
            "(dukkan_kullanici_id, yonetiyor_user_id, yonetiyor_tenant_id) "
            "VALUES (:d, :u, :t) "
            "ON CONFLICT (yonetiyor_user_id, yonetiyor_tenant_id) DO NOTHING"
        ),
        {"d": kullanici_id, "u": user_id, "t": tenant_id},
    )

    return {
        "access_token": jeton_uret(kullanici_id, telefon),
        "token_type": "bearer",
        "kullanici": {"id": str(kullanici_id), "telefon": telefon},
        # Bolge on-doldurma "EN IYI CABA": olculdu, 2239 tesisin YALNIZ
        # 1'inde `il` dolu. Bos gelmesi akisin NORMAL hali; istemci bunu
        # hata gibi gostermemeli.
        "bolge": {"il": kimlik.il, "ilce": kimlik.ilce},
    }


@router.get("/ben")
async def ben(
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Oturum acmis kullanicinin profili. Doner: kullanici + roller."""
    satir = (
        await db.execute(
            text(
                "SELECT id, telefon, ad_soyad, eposta, tip, durum, "
                "       kvkk_onay_at, created_at "
                "FROM dukkan_kullanici WHERE id = :i"
            ),
            {"i": kimlik.kullanici_id},
        )
    ).mappings().one()
    mod = (
        await db.execute(
            text("SELECT 1 FROM moderator WHERE kullanici_id = :i"),
            {"i": kimlik.kullanici_id},
        )
    ).first()
    isletme_sayisi = (
        await db.execute(
            text("SELECT count(*) FROM isletme WHERE sahip_kullanici_id = :i"),
            {"i": kimlik.kullanici_id},
        )
    ).scalar_one()
    d = dict(satir)
    d["moderator"] = mod is not None
    d["isletme_sayisi"] = isletme_sayisi
    return d
