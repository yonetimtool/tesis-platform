"""(P155r2 / §3) YONETICI SELF-SIGNUP — tesis UYGULAMADAN acilir.

===========================================================================
NE DEGISTI
===========================================================================
Once: tesisi ADMIN acardi (`POST /tenants`), icine bir yonetici ON
TANIMLAR, ona tek kullanimlik bir kod verirdi; yonetici ilk giriste
tesisi adlandirirdi. Yani bir yoneticinin platforma girmesi icin bizim
elle bir sey yapmamiz gerekiyordu.

Simdi: yonetici "Tesis adini giriniz" der, ILERI'ye basar, tesis O ANDA
olusur ve oturumu ACILIR. Admin adimi YOKTUR.

`POST /tenants` KALDIRILMADI ve bu bilincli: platform sahibinin destek
islerinde (bir tesisi elle acmak, demo/tohum verisi kurmak) hâlâ tek
yoldur ve KILITLI KURAL 2 geregi demo hesaplarinin ayakta kalmasi ona
bagli. Kaldirilan sey onun BIRINCIL olmasidir — yonetici artik ondan
gecmiyor.

===========================================================================
TESIS KODU ISTEMCIDEN ALINMAZ, TETIKLEYICI URETIR
===========================================================================
Kod = adin ilk 4 harfi + '-' + YYAAGG (goc 0037, yerelden bagimsiz hâle
getirilmesi goc 0041). Kural VERITABANINDA bir tetikleyicide duruyor;
buradan uretmek onu ikinci bir yere kopyalamak, cakisma cozumunu
(rastgele iki haneli ek) da istemciye yikmak olurdu.

Turkce harf donusumu, 4 harften kisa adlar, rakamla baslayan adlar ve
ayni gun ayni ad cakismasi O TETIKLEYICIDE cozulmus durumda; bu uc
yalnizca adi verir.

===========================================================================
TESIS + YONETICI + (VARSA) SOSYAL KIMLIK — TEK TRANSACTION
===========================================================================
Sartname soruyor: "Kayit yarida kesilirse ne olur (tesis olustu ama
yonetici tamamlamadi)?"

YANIT: BOYLE BIR ARA DURUM YOK. Ucu de ayni transaction'da yazilir;
biri patlarsa hicbiri kalmaz. Kullanici yanit almadan cikarsa geriye
tesis DE kalmaz. Yanit aldiysa hesabi calisiyordur ve normal girisle
devam eder — "yarim kayit" diye bir durum uretmedik.

Bu, sosyal yolda ozellikle onemli: once tesisi acip sonra kimligi
baglamak, kimlik baglama patladiginda (orn. o Google hesabi baskasina
bagli) SAHIPSIZ bir tesis birakirdi.

===========================================================================
"ZATEN BIR SITEM VAR" NEDEN BURADA DEGIL
===========================================================================
Sartname §3: "Bu alanin ALTINDA 'Zaten bir sitem var' bagi → tesis kodu
girme ekrani. Ayni tesise ikinci, ucuncu yonetici boyle katilir."

O yol BU MODULDE DEGIL, `auth.rol_kayit_*` icinde — cunku KISITLAR
maddesi onu belirliyor: "Kod bilen biri kayit olamamali, yalniz onceden
eklenmis telefonla eslesen kaydolur." Yani ikinci yonetici de once
mevcut yonetici tarafindan EKLENMIS olmali; katilma, `rol='yonetici'`
ile yapilan sirdan bir rol eslesmesidir.

Aksi tasarim — "tesis kodunu bilen yonetici olur" — tesis kodu kamuya
acik ve tahmin edilebilir oldugundan (goc 0037 guvenlik notu) tesisin
TAMAMEN devralinmasi demekti. Sartnamenin iki maddesi arasindaki bu
gerilim KISITLAR lehine cozuldu.
"""
from __future__ import annotations

import json
import uuid

import redis.asyncio as aioredis
from fastapi import APIRouter, Depends
from sqlalchemy import select, text
from sqlalchemy.exc import IntegrityError

from ..audit import Action, record_audit
from ..db import SessionLocal, set_tenant
from ..deps import get_redis
from ..errors import APIError
from ..hiz_siniri import kod_istegi_say
from ..models import AppUser, OauthKimlik
from ..schemas import TesisOlusturRequest, TesisOlusturResponse
from ..security import hash_password, normalize_phone, slugify_tenant
from .auth import _issue_token_pair
from .oauth import _baglama_coz

router = APIRouter(prefix="/auth/kayit", tags=["auth"])

#: Numara zaten platformda. SIZDIRIYOR MU? Evet, bir bit: "bu numara
#: kayitli". Yine de AYIRT EDICI bir hata seciliyor ve gerekcesi su:
#: kullanicinin numarasi KENDI numarasidir, ona "zaten kayitlisin, giris
#: yap" demek onu dogru kapiya yollar. Belirsiz bir hata verseydik,
#: hesabi olan yonetici tesisini ikinci kez acmaya calisip her seferinde
#: ayni duvara carpar ve destege yazardi. Numara taramasini engelleyen
#: sey burada hata metni degil, ONUNDEKI HIZ SINIRIDIR.
_TELEFON_KAYITLI = APIError(409, "conflict", "telefon_zaten_kayitli")

#: Sosyal kimlik baska bir hesaba bagli — o hesapla giris yapilmali.
_KIMLIK_BASKASINDA = APIError(409, "conflict", "oauth_baska_hesaba_bagli")

#: Hiz siniri kapsami. `kayit`/`giris`ten AYRI: tesis acmak farkli bir
#: eylemdir ve birinin sayaci otekini tuketmemeli.
_HIZ_KAPSAMI = "tesis_olustur"


@router.post("/tesis-olustur", response_model=TesisOlusturResponse, status_code=201)
async def tesis_olustur(
    body: TesisOlusturRequest,
    redis: aioredis.Redis = Depends(get_redis),
) -> TesisOlusturResponse:
    """Tesisi acar, ilk yoneticiyi yazar ve OTURUM ACAR.

    `kurulum_tamamlandi=true` DONUYOR ve bu bilincli: o bayragin tek isi
    "birincil yonetici tesisi adlandirdi mi" sorusunu yanitlamakti
    (mobil `setup_tenant_screen` onu bekler). Ad ARTIK BU ISTEKTE
    geliyor, yani adim zaten yapilmis durumda. `false` biraksaydik
    kullaniciyi az once yazdigi adi tekrar yazdigi bir ekrana
    dusururduk — sartname §3 ADIM 4 acikca "Ana ekran" diyor.

    Kurulum SIHIRBAZI (blok/daire/sakin/...) bundan AYRIDIR ve
    dokunulmadi; o zaten veriden sayiliyor, bayraktan degil.
    """
    try:
        telefon = normalize_phone(body.telefon)
    except ValueError:
        raise APIError(422, "validation_error", "telefon_gecersiz")

    # HIZ SINIRI DOGRULAMADAN ONCE — depodaki oteki kayit uclariyla ayni
    # sira. Sonra saymak, "bu numara kayitli mi" sorusunu sinirsiz
    # sordurup 409/201 farkindan yanit okumaya izin verirdi.
    await kod_istegi_say(redis, telefon, kapsam=_HIZ_KAPSAMI)

    # Sosyal yolda kimlik ONCE cozulur: gecersiz bir jeton yuzunden tesis
    # acip sonra geri almak yerine, hic acmamak.
    kimlik: dict | None = None
    if body.baglama_jetonu:
        kimlik = _baglama_coz(body.baglama_jetonu)

    async with SessionLocal() as session:
        async with session.begin():
            # --- 1) Numara bos mu? (RLS bootstrap: SECURITY DEFINER) ---
            if (
                await session.execute(
                    text("SELECT public.tenant_id_by_phone(:p)"), {"p": telefon}
                )
            ).scalar_one_or_none() is not None:
                raise _TELEFON_KAYITLI

            # --- 2) Sosyal kimlik baskasinda mi? ---
            if kimlik is not None:
                if (
                    await session.execute(
                        text("SELECT public.tenant_id_by_oauth(:s, :sub)"),
                        {"s": kimlik["saglayici"], "sub": kimlik["subject"]},
                    )
                ).scalar_one_or_none() is not None:
                    raise _KIMLIK_BASKASINDA

            # --- 3) Tesis + birincil yonetici ---
            # PAROLA DURUMU YONTEME GORE: elle kayitta kullanici parolayi
            # ZATEN girdi (`password_set=true`, gecici kod YOK). Sosyal
            # yolda parola HIC YOK ve olmamali — kimlik saglayicidadir.
            yonetici = {
                "ad": body.ad.strip(),
                "telefon": telefon,
                "password_hash": hash_password(body.parola) if body.parola else None,
                "temp_code_hash": None,
                "password_set": bool(body.parola),
            }
            try:
                satirlar = (
                    await session.execute(
                        text(
                            "SELECT tenant_id, user_id FROM "
                            "public.create_tenant_with_yoneticis("
                            ":ad, :slug, :tz, :kur, :yem, CAST(:yon AS jsonb))"
                        ),
                        {
                            "ad": body.tesis_ad.strip(),
                            "slug": slugify_tenant(body.tesis_ad),
                            "tz": "Europe/Istanbul",
                            "kur": True,
                            "yem": None,
                            "yon": json.dumps([yonetici]),
                        },
                    )
                ).all()
            except IntegrityError:
                # Yaris: ayni numarayla es zamanli iki istek. Adim 1'in
                # kontrolu ile INSERT arasindaki pencereyi veritabaninin
                # benzersizlik kisiti kapatir; kullaniciya AYNI hatayi
                # veriyoruz ki iki yol ayirt edilemesin.
                raise _TELEFON_KAYITLI

            tenant_id: uuid.UUID = satirlar[0].tenant_id
            user_id: uuid.UUID = satirlar[0].user_id

            # --- 4) Ayni transaction'da: baglam + sosyal kimlik + denetim ---
            await set_tenant(session, tenant_id)

            if kimlik is not None:
                session.add(
                    OauthKimlik(
                        tenant_id=tenant_id,
                        user_id=user_id,
                        saglayici=kimlik["saglayici"],
                        subject=kimlik["subject"],
                        eposta=kimlik.get("eposta"),
                    )
                )

            kayit_kodu = (
                await session.execute(
                    text("SELECT kayit_kodu FROM public.tenant WHERE id = :t"),
                    {"t": tenant_id},
                )
            ).scalar_one()

            await record_audit(
                session,
                action=Action.LOGIN_OK,
                tenant_id=tenant_id,
                actor_user_id=user_id,
                actor_rol="yonetici",
                resource_type="app_user",
                resource_id=user_id,
                meta={
                    "method": (
                        f"self_signup:oauth:{kimlik['saglayici']}"
                        if kimlik
                        else "self_signup:parola"
                    )
                },
            )

            # ORM nesnesi olarak yukleniyor: `_issue_token_pair` bir
            # `AppUser` bekliyor ve elde kurulmus bir nesne vermek, alan
            # eklendiginde sessizce eksik kalirdi. Transaction disinda
            # kullanilabilir cunku `SessionLocal` `expire_on_commit=False`.
            user = (
                await session.execute(select(AppUser).where(AppUser.id == user_id))
            ).scalar_one()

    # Jeton uretimi transaction DISINDA — depodaki oteki giris yollariyla
    # ayni desen (`_issue_token_pair` Redis'e yazar).
    cift = await _issue_token_pair(redis, user)
    return TesisOlusturResponse(
        tesis_ad=body.tesis_ad.strip(), tesis_kodu=kayit_kodu, jetonlar=cift
    )
