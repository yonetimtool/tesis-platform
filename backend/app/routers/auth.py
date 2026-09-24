"""POST /auth/login + POST /auth/refresh — /contracts/auth.md + openapi.yaml.

Refresh rotation/iptal durumu Redis'te tutulur (sema'da refresh tablosu yok;
auth.md §3 server-side iptal listesini onerir):
  refresh:valid:<jti> = <fam>   (TTL = refresh suresi)  -> jti gecerli mi
  refresh:fam:<fam>   = <jti>    (TTL = refresh suresi)  -> ailenin guncel jti'si
Rotation: eski jti silinir, yeni jti uretilir. Reuse (gecersiz/eski jti) gelince
tum aile iptal edilir.
"""
from __future__ import annotations

import secrets

import jwt
import redis.asyncio as aioredis
from fastapi import APIRouter, Depends, Response
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import func, or_, select, text

from ..audit import Action, record_audit
from ..config import settings
from ..db import SessionLocal, set_tenant
from ..deps import get_redis, gorev_penceresi_disinda
from ..errors import APIError
from ..telefon_kodu import GECERSIZ as TK_GECERSIZ
from ..hiz_siniri import (
    DENEME_ASILDI,
    DENEME_SINIRI,
    giris_basarili,
    giris_basarisiz,
    giris_kilidi_denetle,
    kod_istegi_geri_al,
    kod_istegi_say,
)
from ..kimlik import kimligi_coz
from ..oturum_iptal import (
    erisim_jetonunu_kapat,
    iptal_edilmis_mi,
    tum_oturumlari_kapat,
)
from ..telefon_kodu import (
    eposta_kodu_uret_ve_gonder,
    eposta_kodunu_dogrula,
    kod_uret_ve_gonder,
    kodu_dogrula,
)
from ..models import (
    AppUser,
    Tenant,
    Unit,
    UnitResident,
)
from ..gonderim import tenant_ayari
from ..schemas import (
    CikisIstek,
    TesisDegistirIstek,
    TesisUyeligi,
    TesislerimIstek,
    TesislerimYanit,
    EpostaKodDogrulaIstek,
    EpostaKodIstek,
    TelefonIstek,
    TelefonKodIstek,
    KayitDurumResponse,
    RolKayitBaslaRequest,
    RolKayitBaslaResponse,
    RolKayitDogrulaRequest,
    RolKayitDogrulaResponse,
    LoginRequest,
    PhoneLoginRequest,
    PhoneLoginResponse,
    RefreshRequest,
    SetPasswordRequest,
    SifreKodIstek,
    SifreSifirlaIstek,
    TokenPair,
)
from ..security import (
    access_token_ttl_seconds,
    create_access_token,
    create_refresh_token,
    create_setup_token,
    decode_token,
    hash_password,
    normalize_phone,
    verify_password_async,
)

router = APIRouter(prefix="/auth", tags=["auth"])

#: Cikis ucunda Bearer ISTEGE BAGLI (suresi dolmus oturumla da cikilabilmeli).
_bearer_istege_bagli = HTTPBearer(auto_error=False)

# (P205 §1) TEK ALAN icin TURSUZ metin: "e-posta hatali" demek,
# saldirgana girdisinin hangi dala girdigini soylerdi. Eski
# `..._email` / `..._telefon` metinleri KALDI — telefon-ozel
# `login-phone` ucu onlari kullanmaya devam ediyor.
_INVALID_CREDS = APIError(401, "invalid_credentials", "giris_bilgileri_hatali")
# Telefon girisinde de hangi adimin patladigi sizdirilmaz (numara var mi, kod mu
# parola mi yanlis vb. ayirt ettirilmez) — personel akisiyla ayni ilke.
_INVALID_PHONE_CREDS = APIError(401, "invalid_credentials", "giris_bilgileri_hatali_telefon")
# (P128) Gorev suresi disindaki denetci: 401 DEGIL 403 ve AYRI mesaj.
# "Giris bilgileri hatali" demek, dogru parolayi giren kullaniciyi
# parolasini aramaya gonderirdi; sorun kimlik degil YETKI penceresidir.
_GOREV_SURESI_DISINDA = APIError(403, "forbidden", "gorev_suresi_disinda")


def _refresh_ttl() -> int:
    return settings.refresh_token_expire_days * 24 * 3600


async def _store_refresh(redis: aioredis.Redis, jti: str, fam: str) -> None:
    ttl = _refresh_ttl()
    await redis.set(f"refresh:valid:{jti}", fam, ex=ttl)
    await redis.set(f"refresh:fam:{fam}", jti, ex=ttl)


async def _revoke_family(redis: aioredis.Redis, fam: str, jti: str | None = None) -> None:
    await redis.delete(f"refresh:fam:{fam}")
    if jti:
        await redis.delete(f"refresh:valid:{jti}")


async def _audit_login_fail(tenant_id, *, method: str, user: AppUser | None = None) -> None:
    """login_fail'i AYRI (commit'lenen) transaction'da yazar — ana akis 401 ile
    raise ettiginden (ve read-only outer txn geri alindigindan) denetim satiri
    burada bagimsiz yazilir. Tenant COZULMEDIYSE (bilinmeyen slug/numara)
    cagrilmaz: kapsam yok. meta'da kisisel veri (e-posta/telefon) DEGERI YOK."""
    async with SessionLocal() as session:
        async with session.begin():
            await set_tenant(session, tenant_id)
            await record_audit(
                session,
                action=Action.LOGIN_FAIL,
                tenant_id=tenant_id,
                actor_user_id=(user.id if user else None),
                actor_rol=(user.role if user else None),
                meta={"method": method},
            )


# ===================== (P203 §2) COKLU TESIS ================================ #
#
# OLCUM ONCE: model bunu ZATEN destekliyor. `uq_app_user_tenant_email`
# e-postayi TESIS ICINDE benzersiz kilar, platform genelinde DEGIL —
# yani ayni kisi N tesiste N ayri satir olarak durur ve HER SATIRIN
# KENDI ROLU vardir. Sema degisikligi gerekmedi; eksik olan sey
# kullanicinin bu satirlari GOREBILMESI ve arasinda GECEBILMESIYDI.
#
# JETON `tenant_id` TASIR ve RLS onu kullanir. Tesis degistirmek =
# HEDEF TESIS ICIN YENI JETON almak. Izolasyon bu yuzden yapisal olarak
# korunur: degisen tek sey jetondaki tenant, veri yolu ayni.
async def _uyelikler(session, kimlik: str) -> list[dict]:
    """Kimligin TUM tesis uyelikleri (SECURITY DEFINER, goc 0092/0095).

    (P205 §1) `kimlik` E-POSTA ya da NORMALIZE TELEFON olabilir;
    fonksiyon ikisini de esler.
    """
    satirlar = (
        await session.execute(
            text(
                "SELECT tenant_id, slug, tenant_ad, user_id, rol, is_active, "
                "password_hash, eposta_dogrulandi "
                "FROM public.tenant_uyelikleri(:e)"
            ),
            {"e": kimlik},
        )
    ).mappings().all()
    return [dict(r) for r in satirlar]


@router.post("/tesislerim", response_model=TesislerimYanit)
async def tesislerim(
    body: TesislerimIstek,
    redis: aioredis.Redis = Depends(get_redis),
) -> TesislerimYanit:
    """Giris ekrani: "bu kimlik hangi tesislerde gecerli".

    PAROLA DOGRULANIR ve liste YALNIZ parolanin TUTTUGU uyelikleri
    tasir. Iki sebep:
      * SIZINTI: parolasiz sorulabilseydi uc, "bu e-posta hangi
        sitelerde oturuyor" sorgusuna donusurdu.
      * DOGRULUK: parolanin tutmadigi bir tesisi listelemek,
        kullaniciyi giremeyecegi bir kapiya yollamak olurdu.

    HIZ SINIRI login ile AYNI SINIFTA: uc, parola deneme yuzeyidir.

    BOS LISTE ile YANLIS PAROLA AYIRT EDILMEZ — ikisi de bos doner.
    """
    # (P205 §1) TEK ALAN: e-posta da olabilir telefon da.
    kimlik = kimligi_coz(body.kimlik)
    if kimlik is None:
        # COZULEMEYEN GIRDI DE BOS LISTE DONER — hata DEGIL.
        # "Bu bir e-posta degil" demek, saldirgana girdisinin hangi
        # dala girdigini soylerdi; gecersiz e-posta ile gecersiz
        # telefon AYNI yaniti almali (istegin acik sarti).
        return TesislerimYanit(tesisler=[])
    await kod_istegi_say(
        redis, kimlik.deger, kapsam="tesislerim",
        sinir=DENEME_SINIRI, hata=DENEME_ASILDI,
    )
    async with SessionLocal() as session:
        satirlar = await _uyelikler(session, kimlik.deger)
    tesisler = [
        TesisUyeligi(
            tenant_id=r["tenant_id"], slug=r["slug"], ad=r["tenant_ad"], rol=r["rol"]
        )
        for r in await _parolasi_tutanlar(satirlar, body.password)
    ]
    return TesislerimYanit(tesisler=tesisler)


async def _issue_token_pair(redis: aioredis.Redis, user: AppUser) -> TokenPair:
    """Dogrulanmis kullanici icin access+refresh cifti uret ve refresh'i kaydet."""
    # (P247 §2) Kullanici IKINCIL modda ise (sakin) refresh bu modu tasir.
    from ..rol_gecisi import asil_rol, ikincil_modda_mi

    access = create_access_token(
        user_id=user.id, tenant_id=user.tenant_id, role=user.role,
        asil_rol=asil_rol(user),
    )

    refresh_token, jti, fam = create_refresh_token(
        user_id=user.id, tenant_id=user.tenant_id,
        arol=user.role if ikincil_modda_mi(user) else None,
    )
    await _store_refresh(redis, jti, fam)
    return TokenPair(
        access_token=access,
        refresh_token=refresh_token,
        token_type="Bearer",
        expires_in=access_token_ttl_seconds(),
    )


async def _gecici_kod_eslesmesi(
    satirlar: list[dict], kod: str, slug: str | None
) -> str | None:
    """Parolasi HENUZ KURULMAMIS tek uyelikte gecici kod tutuyorsa setup_token.

    Birden fazla aday varsa (ayni kimlik iki tesiste parolasiz) kod her
    birinde denenir; tutan ILK uyelik alinir — kod kullaniciya ozel
    rastgele bir degerdir, iki tesiste ayni cikmasi pratikte olmaz.
    """
    for r in satirlar:
        if not r["is_active"] or r["password_hash"] is not None:
            continue
        if slug and r["slug"] != slug:
            continue
        async with SessionLocal() as session:
            async with session.begin():
                await set_tenant(session, r["tenant_id"])
                user = (
                    await session.execute(
                        select(AppUser).where(AppUser.id == r["user_id"])
                    )
                ).scalar_one_or_none()
                if (
                    user is None or user.password_set or not user.temp_code_hash
                    or gorev_penceresi_disinda(user)
                ):
                    continue
                if not await verify_password_async(kod, user.temp_code_hash):
                    continue
                await record_audit(
                    session, action=Action.LOGIN_OK, tenant_id=r["tenant_id"],
                    actor_user_id=user.id, actor_rol=user.role,
                    resource_type="app_user", resource_id=user.id,
                    meta={"method": "kimlik", "setup_required": True},
                )
                return create_setup_token(user_id=user.id, tenant_id=user.tenant_id)
    return None


async def _parolasi_tutanlar(satirlar: list[dict], parola: str) -> list[dict]:
    """Parolanin tuttugu AKTIF uyelikler — bcrypt olay dongusu DISINDA.

    Eslesme adayi hic yoksa bile bir kez (sahte hash'e karsi) bcrypt kosar:
    sure hesabin varligindan bagimsiz kalir (E2E 2026-09 olcumu).
    """
    adaylar = [r for r in satirlar if r["is_active"]]
    if not adaylar:
        await verify_password_async(parola, None)
        return []
    return [r for r in adaylar if await verify_password_async(parola, r["password_hash"])]


@router.post("/login", response_model=TokenPair)
async def login(
    body: LoginRequest,
    redis: aioredis.Redis = Depends(get_redis),
) -> TokenPair:
    """(P205 §1) E-POSTA VEYA TELEFONLA giris; slug OPSIYONEL.

    =======================================================================
    NEDEN TEK UC
    =======================================================================
    `login-phone` DURUYOR (eski istemciler kullaniyor) ama yeni tek alan
    BURAYA gelir. Ikinci bir uc yazmak, ayni kararin (kimlik turu) iki
    yerde verilmesi demekti.

    =======================================================================
    SIZDIRMAMA
    =======================================================================
    Cozulemeyen kimlik, bilinmeyen kimlik, yanlis parola, pasif hesap ve
    uyelik-yok — HEPSI ayni 401. Gecersiz e-posta ile gecersiz telefon
    AYNI yaniti alir (istegin acik sarti).
    """
    kimlik = kimligi_coz(body.kimlik)
    if kimlik is None:
        await verify_password_async(body.password, None)
        raise _INVALID_CREDS
    # (E2E 2026-09) KABA KUVVET SINIRI — parola DENENMEDEN once.
    await giris_kilidi_denetle(redis, kimlik.deger)

    async with SessionLocal() as session:
        satirlar = await _uyelikler(session, kimlik.deger)

    # PAROLASI TUTAN uyelikler. Parola tutmayan bir tesisi "var ama
    # giremezsin" diye ayirmak, hesabin varligini sizdirmakti.
    uygun = await _parolasi_tutanlar(satirlar, body.password)
    if body.tenant_slug:
        uygun = [r for r in uygun if r["slug"] == body.tenant_slug]
    if not uygun:
        # (E2E 2026-09) GECICI KOD — ILK GIRIS. Panel yoneticiye tek
        # seferlik kod veriyor ve "telefon + kod ile girin" diyor; ama bu
        # uc yalniz `password_hash`e bakiyordu: kod web'de (tek alan)
        # e-postayla da telefonla da 401 aliyordu. Kod tutarsa OTURUM
        # ACILMAZ; `login-phone` ile AYNI sozlesme doner (setup_token ->
        # /auth/set-password).
        kurulum = await _gecici_kod_eslesmesi(satirlar, body.password, body.tenant_slug)
        if kurulum is not None:
            await giris_basarili(redis, kimlik.deger)
            return JSONResponse(
                PhoneLoginResponse(
                    password_setup_required=True, setup_token=kurulum
                ).model_dump()
            )
        await giris_basarisiz(redis, kimlik.deger)
        # BASARISIZ GIRIS DENETIME YAZILIR.
        #
        # OLCULEN KUSUR (P205 §1, `test_audit` yakaladi): yeni akista
        # yanlis parola sessizce 401 donuyordu — `login_fail` satiri
        # HIC yazilmiyordu. Bir hesaba yapilan parola denemelerini
        # gormeden "bu hesaba saldirildi mi" sorusu YANITSIZ kalir.
        #
        # KIMLIGI COZULEN her uyelik icin yazilir (slug verilmisse
        # yalniz o): tenant COZULMEDIYSE kapsam yok, cagrilmaz.
        for r in satirlar:
            if body.tenant_slug and r["slug"] != body.tenant_slug:
                continue
            await _audit_login_fail(r["tenant_id"], method="kimlik")
        raise _INVALID_CREDS
    if len(uygun) > 1:
        # SECIM GEREKLI: jeton URETILMEZ. Rastgele birini secmek,
        # kullaniciyi bilmedigi bir tesise sokmak olurdu.
        raise APIError(409, "tesis_secimi_gerekli", "tesis_secimi_gerekli")

    hedef = uygun[0]
    async with SessionLocal() as session:
        async with session.begin():
            await set_tenant(session, hedef["tenant_id"])
            user = (
                await session.execute(
                    select(AppUser).where(AppUser.id == hedef["user_id"])
                )
            ).scalar_one_or_none()
            if user is None or not user.is_active:
                await _audit_login_fail(hedef["tenant_id"], method="kimlik", user=user)
                raise _INVALID_CREDS
            # (P128) Gorev suresi disindaki denetci token ALMAZ.
            if gorev_penceresi_disinda(user):
                await _audit_login_fail(hedef["tenant_id"], method="kimlik", user=user)
                raise _GOREV_SURESI_DISINDA
            await record_audit(
                session, action=Action.LOGIN_OK, tenant_id=hedef["tenant_id"],
                actor_user_id=user.id, actor_rol=user.role,
                resource_type="app_user", resource_id=user.id,
            )
            hedef_user = user

    await giris_basarili(redis, kimlik.deger)
    # JETON URETIMI TEK YERDE (`_issue_token_pair`): ikinci bir kopya
    # yazmak, refresh kaydini bir gun birinde unutmak demekti.
    return await _issue_token_pair(redis, hedef_user)

@router.post("/login-phone", response_model=PhoneLoginResponse)
async def login_phone(
    body: PhoneLoginRequest,
    redis: aioredis.Redis = Depends(get_redis),
) -> PhoneLoginResponse:
    """Telefonla giris: cep telefonu (global benzersiz) + (gecici kod VEYA
    kalici parola). Tenant TELEFONDAN otomatik cozulur (tenant_slug YOK).

    Telefon global benzersiz oldugundan `tenant_id_by_phone` (SECURITY DEFINER,
    RLS bootstrap) ile tenant bulunur; kullanici tenant baglaminda telefonla
    yuklenir. Mobil roller (yonetici/security/tesis_gorevlisi/resident) bu yolu
    kullanir; admin paneli e-posta ile `POST /auth/login` kullanir.

    * Kalici parola eslesirse -> normal oturum (token cifti).
    * Gecici kod eslesirse (password_set=false) -> oturum YOK; kisa omurlu
      `setup_token` doner, kullanici /auth/set-password ile parolasini belirlemek
      ZORUNDADIR (kod tek kullanimlik: parola belirlenince silinir).
    * Basarisiz her adim (numara/parola/kod) -> 401 (adim sizdirilmaz).
    """
    try:
        phone = normalize_phone(body.phone)
    except ValueError:
        raise _INVALID_PHONE_CREDS
    # (E2E 2026-09) `/auth/login` ile AYNI sayac: iki kapi tek kilit.
    await giris_kilidi_denetle(redis, phone)
    try:
        return await _login_phone_govde(body, phone, redis)
    except APIError as e:
        if e.status_code == 401:
            await giris_basarisiz(redis, phone)
        raise


async def _login_phone_govde(
    body: PhoneLoginRequest, phone: str, redis: aioredis.Redis
) -> PhoneLoginResponse:
    async with SessionLocal() as session:
        async with session.begin():
            tenant_id = (
                await session.execute(
                    text("SELECT public.tenant_id_by_phone(:p)"), {"p": phone}
                )
            ).scalar_one_or_none()
            if tenant_id is None:
                await verify_password_async(body.password, None)
                raise _INVALID_PHONE_CREDS

            await set_tenant(session, tenant_id)
            user: AppUser | None = (
                await session.execute(
                    select(AppUser).where(AppUser.telefon == phone)
                )
            ).scalar_one_or_none()
            if user is None or not user.is_active:
                await verify_password_async(body.password, None)
                await _audit_login_fail(tenant_id, method="phone", user=user)
                raise _INVALID_PHONE_CREDS
            # (P128) Gorev penceresi — e-posta girisiyle AYNI kural.
            if gorev_penceresi_disinda(user):
                await _audit_login_fail(tenant_id, method="phone", user=user)
                raise _GOREV_SURESI_DISINDA

            if user.password_set:
                if not await verify_password_async(body.password, user.password_hash):
                    await _audit_login_fail(tenant_id, method="phone", user=user)
                    raise _INVALID_PHONE_CREDS
                await record_audit(
                    session, action=Action.LOGIN_OK, tenant_id=tenant_id,
                    actor_user_id=user.id, actor_rol=user.role,
                    resource_type="app_user", resource_id=user.id,
                    meta={"method": "phone"},
                )
                # Token'lar transaction disinda uretilir (asagida).
            else:
                if not await verify_password_async(body.password, user.temp_code_hash):
                    await _audit_login_fail(tenant_id, method="phone", user=user)
                    raise _INVALID_PHONE_CREDS
                # Gecici kod dogru -> parola kurulumu zorunlu; oturum token'i
                # VERILMEZ (kod API erisimi saglamaz). Denetim: kod dogrulandi.
                await record_audit(
                    session, action=Action.LOGIN_OK, tenant_id=tenant_id,
                    actor_user_id=user.id, actor_rol=user.role,
                    resource_type="app_user", resource_id=user.id,
                    meta={"method": "phone", "setup_required": True},
                )
                return PhoneLoginResponse(
                    password_setup_required=True,
                    setup_token=create_setup_token(
                        user_id=user.id, tenant_id=user.tenant_id
                    ),
                )

    await giris_basarili(redis, phone)
    tokens = await _issue_token_pair(redis, user)
    return PhoneLoginResponse(
        password_setup_required=False, **tokens.model_dump()
    )


@router.post("/set-password", response_model=TokenPair)
async def set_password(
    body: SetPasswordRequest,
    redis: aioredis.Redis = Depends(get_redis),
) -> TokenPair:
    """Ilk giristeki zorunlu parola belirleme (setup_token ile).

    Basarida: parola kaydedilir (bcrypt), gecici kod SILINIR (tek kullanimlik),
    password_set=true olur ve tam oturum (token cifti) doner.
    """
    try:
        claims = decode_token(body.setup_token, expected_type="pwd_setup")
    except jwt.PyJWTError:
        raise APIError(401, "invalid_token", "kurulum_tokeni_gecersiz")

    async with SessionLocal() as session:
        async with session.begin():
            await set_tenant(session, claims["tenant_id"])
            user: AppUser | None = (
                await session.execute(
                    select(AppUser).where(AppUser.id == claims.get("sub"))
                )
            ).scalar_one_or_none()
            # Token gecerli olsa da durum degismis olabilir (pasif, parola
            # zaten belirlenmis => token tek kullanimliktir).
            if (
                user is None
                or not user.is_active
                or user.password_set
                or user.temp_code_hash is None
            ):
                raise APIError(401, "invalid_token", "kurulum_tokeni_kullanilmis")

            user.password_hash = hash_password(body.new_password)
            user.password_set = True
            user.temp_code_hash = None
            user.updated_at = func.now()

            await record_audit(
                session, action=Action.PASSWORD_SET, tenant_id=claims["tenant_id"],
                actor_user_id=user.id, actor_rol=user.role,
                resource_type="app_user", resource_id=user.id,
            )

    return await _issue_token_pair(redis, user)


@router.post("/logout", status_code=204, response_model=None)
async def logout(
    body: CikisIstek,
    redis: aioredis.Redis = Depends(get_redis),
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer_istege_bagli),
) -> Response:
    """(E2E 2026-09) CIKIS — bu cihazin oturumunu SUNUCUDA kapatir.

    OLCULEN KUSUR: backend'de cikis ucu yoktu; web yalniz cerezi, mobil
    yalniz yerel depoyu siliyordu ve eski refresh 30 gun gecerli kaliyordu.

    * `refresh_token` verilirse AILESI silinir (yenilenemez).
    * Bearer erisim jetonu varsa kalan omru boyunca kara listeye alinir.
    * `her_yerden=true` kullanicinin TUM jetonlarini gecersiz kilar
      (baska cihazlar dahil) — gecerli bir erisim jetonu ister.

    HER ZAMAN 204: gecersiz/eski jetonla cikis denemesi hata vermez —
    istemci her durumda yerel oturumu siler; "zaten kapaliydi" bilgisi
    kimsenin isine yaramaz.
    """
    if body.refresh_token:
        try:
            rc = decode_token(body.refresh_token, expected_type="refresh")
            await _revoke_family(redis, rc.get("fam", ""), rc.get("jti"))
        except jwt.PyJWTError:
            pass
    if creds is not None and creds.credentials:
        try:
            ac = decode_token(creds.credentials, expected_type="access")
        except jwt.PyJWTError:
            ac = None
        if ac is not None:
            # "Her yerden" yalniz HALA GECERLI bir jetonla (iptal denetimi
            # kara listeden ONCE yapilir, yoksa kendi jetonunu iptal edilmis
            # sayardi).
            gecerli = not await iptal_edilmis_mi(redis, ac)
            await erisim_jetonunu_kapat(redis, ac)
            if body.her_yerden and gecerli:
                await tum_oturumlari_kapat(redis, ac.get("sub"))
    return Response(status_code=204)


@router.post("/refresh", response_model=TokenPair)
async def refresh(
    body: RefreshRequest,
    redis: aioredis.Redis = Depends(get_redis),
) -> TokenPair:
    # 1) imza + tip + son kullanma.
    try:
        claims = decode_token(body.refresh_token, expected_type="refresh")
    except jwt.PyJWTError:
        raise APIError(401, "invalid_token", "refresh_token_gecersiz")

    jti = claims.get("jti", "")
    fam = claims.get("fam", "")
    sub = claims.get("sub")
    tenant_id = claims.get("tenant_id")

    # (E2E 2026-09) Parola sifirlama / "her yerden cik" sonrasi eski aile
    # yenilenemez (bkz. `oturum_iptal.py`).
    if await iptal_edilmis_mi(redis, claims):
        await _revoke_family(redis, fam, jti)
        raise APIError(401, "invalid_token", "oturum_sonlandirildi")

    # 2) rotation/reuse kontrolu.
    current = await redis.get(f"refresh:fam:{fam}")
    valid_fam = await redis.get(f"refresh:valid:{jti}")
    if valid_fam is None or current != jti:
        # gecersiz/zaten donmus/eski jti => reuse suphesi: tum aileyi iptal et.
        await _revoke_family(redis, fam, jti)
        raise APIError(401, "invalid_token", "refresh_token_iptal")

    # 3) kullaniciyi RLS altinda yeniden yukle (rol degismis olabilir).
    async with SessionLocal() as session:
        async with session.begin():
            await set_tenant(session, tenant_id)
            user: AppUser | None = (
                await session.execute(select(AppUser).where(AppUser.id == sub))
            ).scalar_one_or_none()
            if user is None or not user.is_active:
                await _revoke_family(redis, fam, jti)
                raise APIError(401, "invalid_token", "kullanici_bulunamadi_veya_pasif")

            # (P224) ARSIVLENMIS TESIS OTURUM YENILEYEMEZ.
            #
            # Giris yolu `tenant_uyelikleri` suzgeciyle zaten kapali ama
            # ARSIVLEMEDEN ONCE alinmis bir oturum, yenilemeyle sonsuza
            # kadar yasayabilirdi. Erisim jetonu kisa omurlu oldugu icin
            # kopus en gec o sure sonunda tamamlanir.
            arsiv = (
                await session.execute(
                    text("SELECT arsivlendi_at FROM tenant WHERE id = :t"),
                    {"t": tenant_id},
                )
            ).scalar()
            if arsiv is not None:
                await _revoke_family(redis, fam, jti)
                raise APIError(401, "invalid_token", "tesis_arsivde")

            # (P247 §2) SAKIN MODU yenilemede korunur — HALA uygunsa
            # (daire bagi kopmussa asil role doner).
            arol = claims.get("arol")
            if arol:
                from ..rol_gecisi import (
                    IKINCIL_ROL, aktif_rolu_uygula, rol_secenekleri,
                )

                if IKINCIL_ROL.get(user.role) == arol and arol in await rol_secenekleri(
                    session, user
                ):
                    aktif_rolu_uygula(user, arol)
                else:
                    arol = None
            from ..rol_gecisi import asil_rol as _asil

            access = create_access_token(
                user_id=user.id, tenant_id=user.tenant_id, role=user.role,
                asil_rol=_asil(user),
            )
            new_refresh, new_jti, _ = create_refresh_token(
                user_id=user.id, tenant_id=user.tenant_id, family_id=fam,
                arol=arol,
            )

    # 4) rotation: eski jti'yi sil, yeni jti'yi aile guncel'i yap.
    await redis.delete(f"refresh:valid:{jti}")
    await _store_refresh(redis, new_jti, fam)

    return TokenPair(
        access_token=access,
        refresh_token=new_refresh,
        token_type="Bearer",
        expires_in=access_token_ttl_seconds(),
    )

# ============================ KAYIT — ORTAK ================================ #
#
# (P155r2) P148 "SAKIN KENDI KAYDOLUR" AKISI KALDIRILDI. Ne yapiyordu:
# tesis kodu + blok/daire + telefon ile basvuru acilir, SMS ile telefon
# dogrulanir, basvuru YONETICI ONAYINA duser, onaylanunca hesap acilirdi
# (`/auth/kayit/basla`, `/auth/kayit/dogrula`, `/kayit-basvurulari`).
#
# NEDEN KALDIRILDI — iki bagimsiz sebep:
#   1. YENI SISTEMDE KARSILIGI YOK. Yeni kural (sartname KISITLAR):
#      "yalniz ONCEDEN EKLENMIS telefonla eslesen kaydolur". P148 tam
#      TERSIYDI — hesabi OLMAYAN biri basvuruyordu ve dogrulama daire
#      sahipligi degil, tesis kodunu BILMEKTI. Onay adimi da o acigi
#      kapatmak icin sonradan eklenmisti (P148.2); acik kalkinca onay
#      adiminin de sebebi kalmadi.
#   2. HIC KULLANILMIYORDU. Olculdu: ne mobil ne web bu uclari cagiriyor
#      (yalniz testler). Yani kaldirilan sey CANLI bir yol degil, olu bir
#      yoldu.
#
# VERI: `kayit_dogrulama` tablosu ve `kayit_durum` enum'u DURUYOR — tablo
# `amac='giris'`/`'oauth'` kodlari icin hâlâ kullaniliyor ve gecmis
# satirlar silinmiyor. Olcum: kaldirma aninda tabloda 0 satir vardi, yani
# kimsenin bekleyen basvurusu kaybolmadi.

#: Adimlari ayirt ETTIRMEYEN tek hata: "kod yanlis" ile "hesap yok"
#: arasindaki fark, tesisin kullanici listesini disariya sizdirirdi.
_KAYIT_GECERSIZ = APIError(422, "invalid_registration", "kayit_bilgileri_gecersiz")


# ==================== (P154) ROL SECIMLI KAYIT ============================== #
#
# BRIEF: rol -> tesis ID -> telefon -> parola. Tesis ID + telefon ONCEDEN
# TANIMLI bir kayitla eslesmiyorsa kaydolunamaz.
#
# HESAP ZATEN ACILMIS, kisi yalnizca onu SAHIPLENIYOR. Onay adimi YOKTUR
# — onay, hesabi acan yoneticinin kendisidir.
#
# (P155r2) BU ARTIK TEK ELLE-KAYIT YOLU. Karsiti olan P148 akisi (hesabi
# OLMAYAN birinin daire uzerinden basvurup onaya dusmesi) kaldirildi;
# yukaridaki "KAYIT — ORTAK" basligina bakiniz. Dolayisiyla
# `kayit_dogrulama` uzerinde `amac='kayit'` tasiyan her satirin artik
# `user_id`si DOLUDUR — eskiden NULL/DOLU ayrimi iki akisi ayiriyordu,
# simdi ayrilacak ikinci akis yok. `user_id IS NULL` kontrolu yine de
# BIRAKILDI (bkz. `rol_kayit_dogrula`): eski satirlar tabloda durabilir
# ve onlarin bu yoldan gecmemesi gerekir.
#
# Enum'a yeni bir `amac` EKLENMEDI cunku enum degeri geri alinamaz ve
# `goc-tersinirlik` kapisi downgrade sonrasi semayi karsilastiriyor —
# artik kalan bir enum degeri o kapiyi kirardi.


def _maskele(telefon: str) -> str:
    """Kullanicinin YAZDIGI numarayi maskeler (kayitli bir numarayi degil)."""
    if len(telefon) <= 6:
        return "*" * len(telefon)
    return f"{telefon[:5]}***{telefon[-3:]}"


@router.post("/kayit/rol-basla", response_model=RolKayitBaslaResponse)
async def rol_kayit_basla(
    body: RolKayitBaslaRequest,
    redis: aioredis.Redis = Depends(get_redis),
) -> RolKayitBaslaResponse:
    """Rol + tesis ID + telefon -> eslesirse SMS kodu gonderir.

    ESLESME SONUCU YANITTAN OKUNAMAZ (bkz. `RolKayitBaslaResponse`).
    """
    try:
        phone = normalize_phone(body.telefon)
    except ValueError:
        raise _KAYIT_GECERSIZ

    # HIZ SINIRI DOGRULAMADAN ONCE: sonra saymak, eslesmeyen numara icin
    # sinirsiz deneme birakip ucu bir sorgulama aracina cevirirdi.
    await kod_istegi_say(redis, phone, kapsam="rol_kayit")

    async with SessionLocal() as session:
        async with session.begin():
            tenant_id = (
                await session.execute(
                    text("SELECT public.tenant_id_by_kayit_kodu(:k)"),
                    {"k": body.tesis_kodu.strip()},
                )
            ).scalar_one_or_none()
            # TESIS KODU HATASI SOYLENIR: kod zaten kamuya aciktir ve en
            # sik yazim hatasi orada olur.
            if tenant_id is None:
                raise _KAYIT_GECERSIZ

            await set_tenant(session, tenant_id)
            tenant_ad = (
                await session.execute(select(Tenant.ad).where(Tenant.id == tenant_id))
            ).scalar_one()

            user = (
                await session.execute(
                    select(AppUser).where(AppUser.telefon == phone)
                )
            ).scalar_one_or_none()

            # BURADAN SONRASI SESSIZ: hicbir dal yaniti degistirmez, yalniz
            # SMS gonderilip gonderilmeyecegini belirler.
            uygun = (
                user is not None
                and user.is_active
                and user.role == body.rol
                # PAROLASI OLAN HESAP BU YOLDAN GECMEZ: kayit, parola
                # BELIRLENMEMIS hesabi sahiplenmektir. Aksi hâlde uc,
                # ikinci bir parola SIFIRLAMA yuzeyi olurdu; parolasini
                # unutan kullanicinin yolu `/auth/giris/kod-iste`tir.
                and not user.password_set
            )
            if uygun and body.rol == "resident":
                uygun = await _daire_eslesiyor(
                    session, user=user, daire_no=body.daire_no, blok=body.blok
                )

            if uygun and user is not None:
                await kod_uret_ve_gonder(
                    session,
                    tenant_id=tenant_id,
                    telefon=phone,
                    amac="kayit",
                    user_id=user.id,
                )

    return RolKayitBaslaResponse(
        tesis_ad=tenant_ad, telefon_maskeli=_maskele(phone)
    )


async def _daire_eslesiyor(
    session, *, user: AppUser, daire_no: str | None, blok: str | None
) -> bool:
    """Sakinin BEYAN ETTIGI daire, gercekten bagli oldugu daire mi?

    Daire eslesmesi iki bicimi de kabul eder (`unit.no` bazi tesislerde
    blok onekini icinde tasir) — P148'deki kuralin AYNISI; iki yerde iki
    farkli eslestirme, kullaniciya ayni ekranda farkli davranirdi.
    """
    aranan = (daire_no or "").strip().lower()
    b = (blok or "").strip().lower()
    birlesik = f"{b}-{aranan}" if b else aranan
    return bool(
        (
            await session.execute(
                select(Unit.id)
                .join(UnitResident, UnitResident.unit_id == Unit.id)
                .where(
                    UnitResident.user_id == user.id,
                    or_(
                        func.lower(Unit.no) == aranan,
                        func.lower(Unit.no) == birlesik,
                    ),
                )
            )
        ).first()
    )


@router.post("/kayit/rol-dogrula", response_model=RolKayitDogrulaResponse)
async def rol_kayit_dogrula(
    body: RolKayitDogrulaRequest,
) -> RolKayitDogrulaResponse:
    """Kod dogru ise PAROLA BELIRLEME jetonu doner (oturum DEGIL).

    Jeton tek kullanimliktir: `set-password` `temp_code_hash`i temizler ve
    ayni jeton ikinci kez gecmez.
    """
    try:
        phone = normalize_phone(body.telefon)
    except ValueError:
        raise _KAYIT_GECERSIZ

    async with SessionLocal() as session:
        async with session.begin():
            # `kodu_dogrula` tenant baglamini kendi kurar (goc 0042) ve
            # deneme sayacini AYRI oturumda artirir.
            kayit = await kodu_dogrula(
                session, telefon=phone, kod=body.kod, amac="kayit"
            )
            # P148 BASVURUSU BU YOLDAN TAMAMLANAMAZ: orada hesap henuz
            # yoktur ve akis yonetici onayindan gecer.
            if kayit.user_id is None:
                raise _KAYIT_GECERSIZ

            user = (
                await session.execute(
                    select(AppUser).where(AppUser.id == kayit.user_id)
                )
            ).scalar_one_or_none()
            if user is None or not user.is_active or user.password_set:
                raise _KAYIT_GECERSIZ

            # `set-password` tek kullanimliligi `temp_code_hash`ten okur;
            # dogrulanan kodun hash'ini oraya tasiyoruz ki O KAPI aynen
            # islesin ve ikinci bir tek-kullanim mekanizmasi yazilmasin.
            user.temp_code_hash = kayit.kod_hash
            kayit.durum = "onaylandi"
            kayit.karar_at = func.now()
            await session.flush()

            jeton = create_setup_token(user_id=user.id, tenant_id=user.tenant_id)

    return RolKayitDogrulaResponse(setup_token=jeton)


# ==================== (P149) PAROLASIZ GIRIS (telefon + kod) ================ #
#
# NEDEN VAR: P148 sakinleri PAROLASIZ aciyor (`password_hash=NULL`). Mevcut
# `login-phone` ya kalici parola ya gecici kod ariyordu; ikisi de olmayan
# kullanici HIC GIRIS YAPAMIYORDU — onaylanan hesap kullanilamaz kaliyordu.
#
# Kod mekanizmasi kayitla AYNI (`telefon_kodu`): guvenlik ozellikleri tek
# yerde, `amac` ayrimi giris kodunun baska bir kapiyi acmasini engelliyor.


@router.post("/giris/kod-iste", response_model=KayitDurumResponse)
async def giris_kodu_iste(
    body: TelefonIstek,
    redis: aioredis.Redis = Depends(get_redis),
) -> KayitDurumResponse:
    """Kayitli ve AKTIF numaraya giris kodu gonderir.

    NUMARA VARLIGINI SIZDIRMAZ: numara kayitli olmasa da yanit AYNIDIR.
    Aksi halde bu uc bir "hangi numaralar kayitli" sorgusuna donusurdu.
    """
    try:
        phone = normalize_phone(body.telefon)
    except ValueError:
        return KayitDurumResponse(durum="onay_bekliyor")
    # (E2E 2026-09) HIZ SINIRI YOKTU: ayni numaraya 7/7 istek 200 aldi ve
    # her biri bir SMS denemesi uretti — modul basliginin (hiz_siniri.py)
    # tam olarak bu uc icin tanimladigi para + taciz riski.
    await kod_istegi_say(redis, phone, kapsam="giris")

    async with SessionLocal() as session:
        async with session.begin():
            tenant_id = (
                await session.execute(
                    text("SELECT public.tenant_id_by_phone(:p)"), {"p": phone}
                )
            ).scalar_one_or_none()
            if tenant_id is None:
                return KayitDurumResponse(durum="onay_bekliyor")
            await set_tenant(session, tenant_id)
            user = (
                await session.execute(
                    select(AppUser).where(AppUser.telefon == phone)
                )
            ).scalar_one_or_none()
            if user is None or not user.is_active:
                return KayitDurumResponse(durum="onay_bekliyor")
            sonuc = await kod_uret_ve_gonder(
                session, tenant_id=tenant_id, telefon=phone, amac="giris"
            )
    if _gonderilemedi(sonuc):
        await kod_istegi_geri_al(redis, phone, kapsam="giris")
    return KayitDurumResponse(durum="onay_bekliyor")


def _gonderilemedi(sonuc) -> bool:
    """Saglayici kodu TESLIM EDEMEDI mi? (basarisiz gonderim kota yemez)."""
    durum = getattr(sonuc, "durum", None)
    return durum is not None and durum not in ("gonderildi", "iletildi", "kuyrukta")


@router.post("/giris/eposta-kod-iste", response_model=KayitDurumResponse)
async def eposta_giris_kodu_iste(
    body: EpostaKodIstek,
    redis: aioredis.Redis = Depends(get_redis),
) -> KayitDurumResponse:
    """(P172 §5) E-POSTAYA giris kodu gonderir.

    =======================================================================
    TELEFON YOLUYLA AYNI KURALLAR
    =======================================================================
    Sure, deneme siniri ve hiz siniri `telefon_kodu` modulunden gelir —
    ikinci bir sistem YOK. Degisen tek sey kimlik ve teslimat kanali.

    ADRES VARLIGINI SIZDIRMAZ: kayitli olmayan bir adres icin de AYNI
    yanit doner. Aksi halde bu uc "hangi e-postalar kayitli" sorgusuna
    donusurdu — telefon yolundaki kararin aynisi.

    HIZ SINIRI KIMLIGE BAGLI: anahtar `tesis:eposta`. Yalniz e-posta
    kullanmak, ayni adresi tasiyan iki tesisin sayacini birlestirirdi.
    """
    eposta = str(body.eposta).lower()
    # (P205 §1) HIZ SINIRI ARTIK KIMLIGE BAGLI, tesise degil: slug
    # opsiyonel oldugu icin "tesis:eposta" anahtari her zaman
    # kurulamaz. Adres basina saymak, ayni adresi tasiyan iki tesisin
    # sayacini birlestirir — ve DOGRUSU budur: kotuye kullanan kisi
    # ADRESI deniyor, tesisi degil.
    await kod_istegi_say(redis, eposta, kapsam="giris_eposta")

    async with SessionLocal() as session:
        # (P205 §1) SLUG YOKSA ADRESIN TUM UYELIKLERINE AYNI KOD.
        #
        # Kod ADRESE gider ve adresin sahibi TEK KISIDIR; ayni kodu iki
        # tenant satirina yazmak yeni bir yetki VERMEZ. Dogrulamada
        # eslesen tesis tek ise giris, cok ise SECIM istenir.
        satirlar = await _uyelikler(session, eposta)
    hedefler = [
        r for r in satirlar
        if r["is_active"] and (
            body.tenant_slug is None or r["slug"] == body.tenant_slug
        )
    ]
    # SIZDIRMAMA: hedef bulunamasa da AYNI yanit doner.
    # KOD BIR KEZ URETILIR ve tum hedeflere AYNISI yazilir: posta
    # kutusuna TEK bir e-posta dusuyor, kullanicidan "hangi tesisin
    # kodu" ayrimi yapmasi istenemez.
    kod = f"{secrets.randbelow(1_000_000):06d}" if hedefler else None
    sonuclar = []
    for r in hedefler:
        async with SessionLocal() as session:
            async with session.begin():
                await set_tenant(session, r["tenant_id"])
                ayar = await tenant_ayari(session, r["tenant_id"])
                sonuclar.append(await eposta_kodu_uret_ve_gonder(
                    session, tenant_id=r["tenant_id"], eposta=eposta,
                    amac="giris", ayar=ayar, sabit_kod=kod,
                ))
    # (E2E 2026-09 / P207) BASARISIZ GONDERIM KOTA YEMEZ: kodu hic almayan
    # kullanicinin "tekrar gonder" hakki yanmamali.
    if sonuclar and all(_gonderilemedi(x) for x in sonuclar):
        await kod_istegi_geri_al(redis, eposta, kapsam="giris_eposta")
    return KayitDurumResponse(durum="onay_bekliyor")


@router.post("/giris/eposta-kod-dogrula", response_model=TokenPair)
async def eposta_giris_kodu_dogrula(
    body: EpostaKodDogrulaIstek,
    redis: aioredis.Redis = Depends(get_redis),
) -> TokenPair:
    """Kod dogru ise OTURUM ACAR — parola aranmaz (telefon yolunun esi).

    (P205 §1) SLUG OPSIYONEL. Verilmezse adresin uyeliklerinden KODU
    TUTAN tesisler bulunur:
      * TEK ise dogrudan giris,
      * BIRDEN COK ise 409 `tesis_secimi_gerekli` — parola yolundaki
        davranisin AYNISI; rastgele birini secmek, kullaniciyi
        bilmedigi bir tesise sokmak olurdu.
    """
    eposta = str(body.eposta).lower()
    async with SessionLocal() as session:
        satirlar = await _uyelikler(session, eposta)
    adaylar = [
        r for r in satirlar
        if r["is_active"] and (
            body.tenant_slug is None or r["slug"] == body.tenant_slug
        )
    ]
    if not adaylar:
        raise TK_GECERSIZ

    # ================= 1. GECIS: YALNIZ YOKLA, TUKETME =================
    #
    # OLCULEN KUSUR (P205 §1): ilk yazimda dogrulama TARAMA sirasinda
    # yapiliyor ve kod O SIRADA tuketilmiyordu — `test_eposta_kanali`
    # iki seyi birden yakaladi: kod IKINCI kez de calisiyordu ve
    # `eposta_dogrulandi` bayragi ACILMIYORDU (P181 Bölüm 4 kurali).
    #
    # Dogru ayrim: TARAMA yazmaz (oturum COMMIT EDILMEZ), KAZANAN
    # tesiste tam islem yapilir. Tarama sirasinda tuketmek, iki tesisi
    # olan bir kullanicinin kodunu ilk bakista harcamak olurdu.
    tutanlar: list[dict] = []
    for r in adaylar:
        async with SessionLocal() as session:
            await set_tenant(session, r["tenant_id"])
            try:
                await eposta_kodunu_dogrula(
                    session, tenant_id=r["tenant_id"], eposta=eposta,
                    kod=body.kod, amac="giris",
                )
            except APIError:
                continue
            finally:
                # YAZMA YOK: `begin()` acilmadi, oturum commit edilmeden
                # kapaniyor.
                await session.rollback()
            tutanlar.append(r)

    if not tutanlar:
        raise TK_GECERSIZ
    if len(tutanlar) > 1:
        raise APIError(409, "tesis_secimi_gerekli", "tesis_secimi_gerekli")

    # ================= 2. GECIS: KAZANAN TESISTE TAM ISLEM =============
    hedef = tutanlar[0]
    async with SessionLocal() as session:
        async with session.begin():
            await set_tenant(session, hedef["tenant_id"])
            kayit = await eposta_kodunu_dogrula(
                session, tenant_id=hedef["tenant_id"], eposta=eposta,
                kod=body.kod, amac="giris",
            )
            user = (
                await session.execute(
                    select(AppUser).where(AppUser.id == hedef["user_id"])
                )
            ).scalar_one_or_none()
            if user is None or not user.is_active:
                raise TK_GECERSIZ
            if gorev_penceresi_disinda(user):
                raise _GOREV_SURESI_DISINDA
            # (P181 Bölüm 4) KODU GIRMEK ADRESIN KONTROLUNU KANITLAR:
            # bayrak burada acilir ki e-postali ama hic dogrulamamis
            # MEVCUT kullanici OTP ile girip otomatik dogrulansin
            # (parola sifirlama onlar icin de calissin).
            if not user.eposta_dogrulandi:
                user.eposta_dogrulandi = True
                user.updated_at = func.now()
            # KOD TUKETILIR: tekrar kullanilamaz.
            kayit.durum = "onaylandi"
            await record_audit(
                session, action=Action.LOGIN_OK, tenant_id=hedef["tenant_id"],
                actor_user_id=user.id, actor_rol=user.role,
                resource_type="app_user", resource_id=user.id,
            )
            await session.flush()
            hedef_user = user
    return await _issue_token_pair(redis, hedef_user)

@router.post("/sifre/kod-iste", response_model=KayitDurumResponse)
async def sifre_sifirlama_kodu_iste(
    body: SifreKodIstek,
    redis: aioredis.Redis = Depends(get_redis),
) -> KayitDurumResponse:
    """(P181 Bölüm 2) "Şifremi unuttum" — E-POSTAYA sıfırlama kodu gönderir.

    =======================================================================
    E-POSTA TABANLI, SMS YOK. `giris/eposta-kod-iste` ile AYNI KURALLAR.
    =======================================================================
    ADRES/HESAP VARLIGINI SIZDIRMAZ: kayıtlı olmayan, pasif ya da e-postası
    DOĞRULANMAMIŞ hesap için de AYNI yanıt döner. Aksi halde bu uç "hangi
    adresler kayıtlı/doğrulanmış" sorgusuna dönüşürdü.

    GATE `eposta_dogrulandi`: kod yalnız doğrulanmış e-postalı aktif
    kullanıcıya gider (Bölüm 1 ön koşulu) — doğrulanmamış adrese parola
    bağlantısı gönderilmez. Süre/deneme/hız sınırı `telefon_kodu`dan gelir.
    """
    kimlik = f"{body.tenant_slug}:{str(body.eposta).lower()}"
    await kod_istegi_say(redis, kimlik, kapsam="sifre_sifirla")

    async with SessionLocal() as session:
        async with session.begin():
            tenant_id = (
                await session.execute(
                    text("SELECT public.tenant_id_by_slug(:slug)"),
                    {"slug": body.tenant_slug},
                )
            ).scalar_one_or_none()
            if tenant_id is None:
                return KayitDurumResponse(durum="onay_bekliyor")
            await set_tenant(session, tenant_id)
            eposta = str(body.eposta).lower()
            user = (
                await session.execute(
                    select(AppUser).where(func.lower(AppUser.email) == eposta)
                )
            ).scalar_one_or_none()
            # Yalnız DOĞRULANMIŞ e-postalı aktif kullanıcıya kod: doğrulanmamış
            # adres reset yapamaz (Bölüm 1). Yanıt her durumda AYNI (sızıntısız).
            if user is None or not user.is_active or not user.eposta_dogrulandi:
                return KayitDurumResponse(durum="onay_bekliyor")
            ayar = await tenant_ayari(session, tenant_id)
            sonuc = await eposta_kodu_uret_ve_gonder(
                session, tenant_id=tenant_id, eposta=eposta,
                amac="sifre_sifirla", ayar=ayar,
            )
    if _gonderilemedi(sonuc):
        await kod_istegi_geri_al(redis, kimlik, kapsam="sifre_sifirla")
    return KayitDurumResponse(durum="onay_bekliyor")


@router.post("/sifre/dogrula-ve-ayarla", response_model=KayitDurumResponse)
async def sifre_sifirla(
    body: SifreSifirlaIstek,
    redis: aioredis.Redis = Depends(get_redis),
) -> KayitDurumResponse:
    """(P181 Bölüm 2) Kod doğru ise YENİ PAROLAYI kurar.

    OTURUM AÇMAZ: sıfırlama sonrası kullanıcı yeni parolasıyla taze giriş
    yapar (görev-penceresi/denetçi kuralları giriş yolunda uygulanır; ikinci
    bir parolasız token yolu açmayız). Geçersiz/süresi dolmuş kod net hata
    verir; başarı yanıtı sızıntısızdır (geçerli kod zaten yalnız adres
    sahibine gitmiştir).
    """
    async with SessionLocal() as session:
        async with session.begin():
            tenant_id = (
                await session.execute(
                    text("SELECT public.tenant_id_by_slug(:slug)"),
                    {"slug": body.tenant_slug},
                )
            ).scalar_one_or_none()
            if tenant_id is None:
                raise TK_GECERSIZ
            eposta = str(body.eposta).lower()
            kayit = await eposta_kodunu_dogrula(
                session, tenant_id=tenant_id, eposta=eposta,
                kod=body.kod, amac="sifre_sifirla",
            )
            user = (
                await session.execute(
                    select(AppUser).where(func.lower(AppUser.email) == eposta)
                )
            ).scalar_one_or_none()
            if user is None or not user.is_active or not user.eposta_dogrulandi:
                raise TK_GECERSIZ
            # Kod TUKETILIR: tekrar kullanilamaz.
            kayit.durum = "onaylandi"
            kayit.karar_at = func.now()
            user.password_hash = hash_password(body.yeni_parola)
            user.password_set = True
            user.updated_at = func.now()
            sifirlanan_id = user.id
            await record_audit(
                session, action=Action.PASSWORD_RESET, tenant_id=tenant_id,
                actor_user_id=user.id, actor_rol=user.role,
                resource_type="app_user", resource_id=user.id,
            )
    # (E2E 2026-09) Sifirlama HESAP KURTARMA yoludur: acik oturumlar (ele
    # gecirilmis olabilir) kapanir. Olculdu: eski refresh 200 donuyordu.
    await tum_oturumlari_kapat(redis, sifirlanan_id)
    return KayitDurumResponse(durum="onay_bekliyor")


@router.post("/giris/kod-dogrula", response_model=TokenPair)
async def giris_kodu_dogrula(
    body: TelefonKodIstek,
    redis: aioredis.Redis = Depends(get_redis),
) -> TokenPair:
    """Kod dogru ise OTURUM ACAR — parola aranmaz."""
    try:
        phone = normalize_phone(body.telefon)
    except ValueError:
        raise TK_GECERSIZ

    async with SessionLocal() as session:
        async with session.begin():
            kayit = await kodu_dogrula(
                session, telefon=phone, kod=body.kod, amac="giris"
            )
            await set_tenant(session, kayit.tenant_id)
            user = (
                await session.execute(
                    select(AppUser).where(AppUser.telefon == phone)
                )
            ).scalar_one_or_none()
            if user is None or not user.is_active:
                raise TK_GECERSIZ
            # (P128) Gorev suresi disindaki denetci token ALMAZ — parolali
            # yolla ayni kural; buraya da konmali, yoksa parolasiz yol
            # kapiyi delerdi.
            if gorev_penceresi_disinda(user):
                raise _GOREV_SURESI_DISINDA
            # Kod TUKETILIR: tekrar kullanilamaz.
            kayit.durum = "onaylandi"
            await session.flush()
            return await _issue_token_pair(redis, user)
