"""(DUKKAN F2) KIMLIK — Dukkan jetonu, OTP ve rol cozumu.

===========================================================================
NEDEN DUKKAN'IN KENDI JETONU VAR
===========================================================================
Yonetiyor JWT'si `sub` + **`tenant_id`** + `role` tasiyor ve `tenant_id`
ZORUNLU (olculdu: `app.security.create_access_token`). Bagimsiz bir Dukkan
kullanicisinin tesisi YOKTUR — Yonetiyor jetonu burada kullanilamaz.

Iki jeton dunyasi var; koprusu `/dukkan/auth/yonetiyor`.

Dukkan jetonunda `tenant_id` YOK cunku Dukkan cok-kiracili degil: bir
isletme Istanbul'daki 40 siteye birden hizmet verir
(docs/dukkan/00-mimari.md K4).

===========================================================================
`isletme_sahibi` JETONA GOMULMEZ
===========================================================================
Sahiplik bir SORGU SONUCUDUR, jeton iddiasi degil. Gomulseydi:
  * sahiplik degistiginde jeton eskimis kalirdi,
  * askiya alinan bir isletmenin sahibi jetonu dolana kadar yetkisini
    KULLANMAYA DEVAM ederdi.
Ayni gerekce `moderator` icin de gecerli.
"""
from __future__ import annotations

import hashlib
import hmac
import secrets
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, Header, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import settings
from .veritabani import get_dukkan_session

JETON_TURU = "dukkan"
#: Dukkan jetonu Yonetiyor jetonundan UZUN yasar. Gerekce: pazar yeri
#: seyrek kullanilir (yilda birkac kez usta aranir); her seferinde yeniden
#: OTP istemek, kullaniciyi akisin basinda kaybetmek demek. Yonetiyor ise
#: gunluk bir calisma araci ve orada kisa omur dogru.
JETON_OMRU_GUN = 30

OTP_OMRU_DK = 10
OTP_MAKS_DENEME = 5


@dataclass(frozen=True)
class DukkanKimlik:
    """Istegi yapan Dukkan kullanicisi."""

    kullanici_id: uuid.UUID
    telefon: str


def jeton_uret(kullanici_id: uuid.UUID | str, telefon: str) -> str:
    """Dukkan erisim jetonu. Doner: imzali JWT dizgesi.

    `tur: "dukkan"` iddiasi ZORUNLU ve dogrulamada aranir: boylece bir
    Yonetiyor jetonu (ayni sirri kullaniyor) Dukkan uclarinda GECERLI
    SAYILMAZ. Iki dunyayi ayirmadan tek sir kullanmak, Yonetiyor
    jetonuyla Dukkan'a girilmesi demekti.
    """
    simdi = datetime.now(timezone.utc)
    return jwt.encode(
        {
            "sub": str(kullanici_id),
            "tur": JETON_TURU,
            "tel": telefon,
            "iat": int(simdi.timestamp()),
            "exp": int((simdi + timedelta(days=JETON_OMRU_GUN)).timestamp()),
        },
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )


def _jetonu_coz(jeton: str) -> dict:
    try:
        veri = jwt.decode(
            jeton, settings.jwt_secret, algorithms=[settings.jwt_algorithm]
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="jeton_suresi_doldu")
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="jeton_gecersiz")
    if veri.get("tur") != JETON_TURU:
        # Yonetiyor jetonu buraya gecemez.
        raise HTTPException(status_code=401, detail="jeton_gecersiz")
    return veri


async def kimlik_zorunlu(
    authorization: str | None = Header(default=None),
    db: AsyncSession = Depends(get_dukkan_session),
) -> DukkanKimlik:
    """Dukkan jetonu ZORUNLU olan uclar icin bagimlilik.

    Doner: `DukkanKimlik`. Jeton yok/gecersiz/suresi dolmussa 401;
    kullanici askidaysa 403.
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="kimlik_gerekli")
    veri = _jetonu_coz(authorization.split(" ", 1)[1].strip())

    satir = (
        await db.execute(
            text("SELECT id, telefon, durum FROM dukkan_kullanici WHERE id = :i"),
            {"i": veri["sub"]},
        )
    ).first()
    # Jeton gecerli ama kullanici SILINMIS olabilir. Jetona guvenip
    # devam etmek, silinmis bir hesabin 30 gun daha islem yapmasi demekti.
    if satir is None:
        raise HTTPException(status_code=401, detail="jeton_gecersiz")
    if satir[2] != "aktif":
        raise HTTPException(status_code=403, detail="hesap_askida")
    return DukkanKimlik(kullanici_id=satir[0], telefon=satir[1])


async def moderator_zorunlu(
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> DukkanKimlik:
    """Moderasyon uclari icin. Doner: `DukkanKimlik`; degilse 403."""
    var = (
        await db.execute(
            text("SELECT 1 FROM moderator WHERE kullanici_id = :k"),
            {"k": kimlik.kullanici_id},
        )
    ).first()
    if var is None:
        raise HTTPException(status_code=403, detail="moderator_gerekli")
    return kimlik


# --------------------------------------------------------------------- #
# OTP
# --------------------------------------------------------------------- #

def kod_uret() -> str:
    """6 haneli dogrulama kodu. Doner: '000000'-'999999'.

    `secrets` kullaniliyor, `random` DEGIL: `random` ongorulebilir ve bir
    kimlik dogrulayicisi icin uygun degil.
    """
    return f"{secrets.randbelow(1_000_000):06d}"


def kod_hashle(kod: str, telefon: str) -> str:
    """Kodu HASH'ler. Doner: hex ozet.

    Telefon TUZ olarak kullaniliyor: ayni kod farkli numaralar icin
    farkli ozet uretir, boylece ozet tablosundan kod geri okunamaz.
    Duz metin saklamak, veritabanini okuyabilen birinin baskasinin
    hesabina girmesi demekti.
    """
    return hashlib.sha256(f"{telefon}:{kod}:{settings.jwt_secret}".encode()).hexdigest()


def kod_dogru_mu(kod: str, telefon: str, ozet: str) -> bool:
    """Sabit zamanli karsilastirma. Doner: True/False."""
    return hmac.compare_digest(kod_hashle(kod, telefon), ozet)


def telefon_normalize(ham: str) -> str:
    """Telefonu tek bicime cevirir. Doner: '+90XXXXXXXXXX'.

    NEDEN ZORUNLU: `dukkan_kullanici.telefon` UNIQUE ve kimligin
    CAPASI. "0555 111 22 33", "555 111 22 33" ve "+905551112233"
    normalize edilmezse AYNI kisi UC HESAP olurdu — kimlik capasinin
    tamamen anlamsizlasmasi.

    Ayrica Yonetiyor'dan gelen telefonla eslesme buna bagli: koprüden
    gelen numara farkli bicimdeyse SSO her seferinde YENI hesap acardi.
    """
    rakam = "".join(c for c in ham if c.isdigit())
    if rakam.startswith("90") and len(rakam) == 12:
        return f"+{rakam}"
    if rakam.startswith("0") and len(rakam) == 11:
        return f"+90{rakam[1:]}"
    if len(rakam) == 10:
        return f"+90{rakam}"
    # Taninmayan bicim: OLDUGU GIBI birakmak yerine acikca reddediyoruz.
    # Sessizce kabul etmek, kimlik capasina cop veri sokardi.
    raise HTTPException(status_code=422, detail="telefon_bicimi_gecersiz")


# --------------------------------------------------------------------- #
# KOD URETIMI + GONDERIM — TEK YER
# --------------------------------------------------------------------- #

#: OTP SMS metni. Basligi ICERIR cunku kullanici kodu hangi hizmetten
#: aldigini gormeli; onaysiz basliklarla gelen kod "kim gonderdi" sorusunu
#: cevapsiz birakir ve spam sanilir.
OTP_METNI = "Dukkan dogrulama kodunuz: {kod}. Kimseyle paylasmayin."


async def kod_gonder_ve_kaydet(
    db,
    *,
    telefon: str,
    amac: str,
    ip: str | None = None,
) -> dict:
    """Kod uretir, HASH'leyerek kaydeder, GONDERMEYE CALISIR ve sonucu doner.

    Doner:
      {"gonderildi": bool, "gonderim": <durum>, "gecerlilik_dk": int,
       "dev_kod": <yalniz noop + acik ayar>}

    ==================================================================
    `gonderildi` GERCEK SONUCU YANSITIR
    ==================================================================
    Ilk yazimda yanit `{"gonderildi": true, "gonderim":
    "saglayici_bagli_degil"}` idi ve bu IKI ALAN BIRBIRIYLE CELISIYORDU:
    istemci hangisine bakacagini bilemez. Kullanici bunu kusur olarak
    bildirdi ve haklıydi — tam da "sessiz basarisizlik" sinifi,
    ustelik onu engellemek icin yazilmis bir alanin icinde.

    Artik `gonderildi` YALNIZCA saglayici mesaji kabul ettiyse `true`.
    `gonderim` ise NEDENI soyluyor ve ikisi asla celismiyor.

    ==================================================================
    BASARISIZ GONDERIM KOTAYI YEMEZ
    ==================================================================
    Kayit her halukarda yazilir (teshis icin) ama `gonderim_durumu`
    ile isaretlenir. Saatlik sinir YALNIZ 'gonderildi' satirlarini
    sayar: saglayici kesintisinde kullanici bes kez deneyip hicbirini
    ALAMADAN bir saatligine kilitlenmemeli — kendi hatasi olmayan bir
    sey yuzunden.
    """
    from sqlalchemy import text as _text

    from ..config import settings
    from ..mesajlasma import dukkan_sms_saglayicisi

    kod = kod_uret()
    saglayici = dukkan_sms_saglayicisi()
    sonuc = saglayici.gonder(telefon, None, OTP_METNI.format(kod=kod))

    # `GonderimSonucu.durum`: 'gonderildi' | 'yapilandirilmadi' | 'hata'
    if sonuc.durum == "gonderildi":
        gonderim_durumu = "gonderildi"
    elif sonuc.hata == "baslik_yok":
        gonderim_durumu = "baslik_yok"
    elif sonuc.durum == "yapilandirilmadi":
        gonderim_durumu = "saglayici_yok"
    else:
        gonderim_durumu = "basarisiz"

    await db.execute(
        _text(
            "INSERT INTO telefon_dogrulama "
            "(telefon, kod_hash, amac, gecerlilik, ip, gonderim_durumu, "
            " gonderim_hatasi, saglayici) "
            "VALUES (:t, :h, :a, now() + make_interval(mins => :d), :ip, "
            "        :gd, :gh, :sg)"
        ),
        {
            "t": telefon, "h": kod_hashle(kod, telefon), "a": amac,
            "d": OTP_OMRU_DK, "ip": ip, "gd": gonderim_durumu,
            "gh": sonuc.hata, "sg": sonuc.saglayici,
        },
    )

    yanit: dict = {
        "gonderildi": gonderim_durumu == "gonderildi",
        "gonderim": gonderim_durumu,
        "gecerlilik_dk": OTP_OMRU_DK,
    }

    # ==================================================================
    # KODUN YANITTA DONMESI: IKI KOSUL BIRDEN
    # ==================================================================
    # `DUKKAN_OTP_YANITTA` tek basina YETMEZ — gercek bir saglayici da
    # OLMAMALI. Prod'da Verimor yapilandirili oldugu icin ikinci kosul
    # YAPISAL OLARAK tutmaz: ayar yanlislikla acilsa bile kod SIZMAZ.
    #
    # Bir yapilandirma hatasinin TEK BASINA yeterli olmamasi, savunmanin
    # kendisidir. "Ayar prod'da kapali olmali" diye BEKLEMEK degil.
    gercek_saglayici = (
        settings.dukkan_sms_saglayici or ""
    ).strip().lower() in ("verimor", "netgsm")
    if settings.dukkan_otp_yanitta and not gercek_saglayici:
        yanit["dev_kod"] = kod
    return yanit


async def gonderilmis_kod_sayisi(db, *, telefon: str, amac: str) -> int:
    """Son bir saatte BASARIYLA GONDERILMIS kod sayisi. Doner: int.

    Basarisiz denemeler SAYILMAZ (bkz. `kod_gonder_ve_kaydet`).
    """
    from sqlalchemy import text as _text

    return (
        await db.execute(
            _text(
                "SELECT count(*) FROM telefon_dogrulama "
                "WHERE telefon = :t AND amac = :a "
                "  AND gonderim_durumu = 'gonderildi' "
                "  AND created_at > now() - interval '1 hour'"
            ),
            {"t": telefon, "a": amac},
        )
    ).scalar_one()
