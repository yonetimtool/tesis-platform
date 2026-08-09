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
from datetime import datetime, timedelta, timezone

import jwt
import redis.asyncio as aioredis
from fastapi import APIRouter, Depends
from sqlalchemy import func, or_, select, text, update

from ..audit import Action, record_audit
from ..config import settings
from ..db import SessionLocal, set_tenant
from ..deps import get_redis, gorev_penceresi_disinda
from ..errors import APIError
from ..mesajlasma import sms_saglayicisi
from ..telefon_kodu import GECERSIZ as TK_GECERSIZ
from ..hiz_siniri import kod_istegi_say
from ..telefon_kodu import (
    kod_uret_ve_gonder,
    kodu_dogrula,
    tenant_baglamini_kur,
)
from ..models import (
    AppUser,
    KayitDogrulama,
    Tenant,
    Unit,
    UnitResident,
)
from ..schemas import (
    TelefonIstek,
    TelefonKodIstek,
    KayitBaslaRequest,
    KayitBaslaResponse,
    KayitDogrulaRequest,
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
    verify_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])

_INVALID_CREDS = APIError(401, "invalid_credentials", "giris_bilgileri_hatali_email")
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


@router.post("/login", response_model=TokenPair)
async def login(
    body: LoginRequest,
    redis: aioredis.Redis = Depends(get_redis),
) -> TokenPair:
    async with SessionLocal() as session:
        async with session.begin():
            # 1) slug -> tenant_id (RLS bootstrap: SECURITY DEFINER fonksiyon).
            tenant_id = (
                await session.execute(
                    text("SELECT public.tenant_id_by_slug(:slug)"),
                    {"slug": body.tenant_slug},
                )
            ).scalar_one_or_none()
            if tenant_id is None:
                raise _INVALID_CREDS

            # 2) tenant baglami + kullaniciyi RLS altinda yukle.
            await set_tenant(session, tenant_id)
            # email tenant-ici benzersiz (lower(email)); case-insensitive tam eslesme.
            user: AppUser | None = (
                await session.execute(
                    select(AppUser).where(
                        func.lower(AppUser.email) == body.email.lower()
                    )
                )
            ).scalar_one_or_none()

            # 3) dogrulama — basarisiz adimlari ayirt ettirmeden 401.
            if user is None or not verify_password(body.password, user.password_hash):
                await _audit_login_fail(tenant_id, method="email", user=user)
                raise _INVALID_CREDS
            if not user.is_active:
                await _audit_login_fail(tenant_id, method="email", user=user)
                raise _INVALID_CREDS
            # (P128) Gorev suresi disindaki denetci token ALMAZ. Kapiyi
            # yalniz `get_current_user`a birakmak, kullaniciya "giris
            # basarili" deyip ardindan her ekranda 403 gostermek olurdu.
            if gorev_penceresi_disinda(user):
                await _audit_login_fail(tenant_id, method="email", user=user)
                raise _GOREV_SURESI_DISINDA

            await record_audit(
                session, action=Action.LOGIN_OK, tenant_id=tenant_id,
                actor_user_id=user.id, actor_rol=user.role,
                resource_type="app_user", resource_id=user.id,
            )
            access = create_access_token(
                user_id=user.id, tenant_id=user.tenant_id, role=user.role
            )
            refresh, jti, fam = create_refresh_token(
                user_id=user.id, tenant_id=user.tenant_id
            )

    await _store_refresh(redis, jti, fam)
    return TokenPair(
        access_token=access,
        refresh_token=refresh,
        token_type="Bearer",
        expires_in=access_token_ttl_seconds(),
    )


async def _issue_token_pair(redis: aioredis.Redis, user: AppUser) -> TokenPair:
    """Dogrulanmis kullanici icin access+refresh cifti uret ve refresh'i kaydet."""
    access = create_access_token(
        user_id=user.id, tenant_id=user.tenant_id, role=user.role
    )
    refresh_token, jti, fam = create_refresh_token(
        user_id=user.id, tenant_id=user.tenant_id
    )
    await _store_refresh(redis, jti, fam)
    return TokenPair(
        access_token=access,
        refresh_token=refresh_token,
        token_type="Bearer",
        expires_in=access_token_ttl_seconds(),
    )


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

    async with SessionLocal() as session:
        async with session.begin():
            tenant_id = (
                await session.execute(
                    text("SELECT public.tenant_id_by_phone(:p)"), {"p": phone}
                )
            ).scalar_one_or_none()
            if tenant_id is None:
                raise _INVALID_PHONE_CREDS

            await set_tenant(session, tenant_id)
            user: AppUser | None = (
                await session.execute(
                    select(AppUser).where(AppUser.telefon == phone)
                )
            ).scalar_one_or_none()
            if user is None or not user.is_active:
                await _audit_login_fail(tenant_id, method="phone", user=user)
                raise _INVALID_PHONE_CREDS
            # (P128) Gorev penceresi — e-posta girisiyle AYNI kural.
            if gorev_penceresi_disinda(user):
                await _audit_login_fail(tenant_id, method="phone", user=user)
                raise _GOREV_SURESI_DISINDA

            if user.password_set:
                if not verify_password(body.password, user.password_hash):
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
                if not verify_password(body.password, user.temp_code_hash):
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

            access = create_access_token(
                user_id=user.id, tenant_id=user.tenant_id, role=user.role
            )
            new_refresh, new_jti, _ = create_refresh_token(
                user_id=user.id, tenant_id=user.tenant_id, family_id=fam
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

# ======================= (P148) SAKIN KENDI KAYDOLUR ======================= #
#
# GUVEN SINIRI — ACIKCA KAYDEDILDI: bu akista daire sahipligi
# DOGRULANMIYOR. Tesis kodunu ogrenen herkes herhangi bir daireye
# kaydolabilir ve o dairenin verisini gorur. Kerem bu riski secenekler
# gosterildikten SONRA acikca kabul etti (bkz. MASTER-PLAN P148). Kodun
# kendisi bu yuzden bir SIR gibi ele alinmali; sizarsa tesis kodu
# DEGISTIRILEBILIR olmali.
#
# PAROLA YOK: kullanici satiri `password_hash=NULL`, `password_set=False`
# ile acilir. Kimlik = DOGRULANMIS TELEFON. Yeni bir sema alani
# eklenmedi — var olanlar bu durumu zaten ifade ediyor.

_KAYIT_KOD_OMRU_DK = 10
_KAYIT_MAX_DENEME = 5
#: Adimlari ayirt ETTIRMEYEN tek hata: "kod yanlis" ile "daire yok"
#: arasindaki fark, tesisin daire listesini disariya sizdirirdi.
_KAYIT_GECERSIZ = APIError(422, "invalid_registration", "kayit_bilgileri_gecersiz")


def _telefon_maskele(t: str) -> str:
    return t[:-6] + "***" + t[-3:] if len(t) > 8 else "***"


@router.post("/kayit/basla", response_model=KayitBaslaResponse)
async def kayit_basla(
    body: KayitBaslaRequest,
    redis: aioredis.Redis = Depends(get_redis),
) -> KayitBaslaResponse:
    """Tesis kodu + blok/daire + telefon -> SMS kodu gonderir."""
    try:
        phone = normalize_phone(body.telefon)
    except ValueError:
        raise _KAYIT_GECERSIZ

    async with SessionLocal() as session:
        async with session.begin():
            tenant_id = (
                await session.execute(
                    text("SELECT public.tenant_id_by_kayit_kodu(:k)"),
                    {"k": body.tesis_kodu.strip()},
                )
            ).scalar_one_or_none()
            if tenant_id is None:
                raise _KAYIT_GECERSIZ

            await set_tenant(session, tenant_id)
            tenant_ad = (
                await session.execute(select(Tenant.ad).where(Tenant.id == tenant_id))
            ).scalar_one()

            # DAIRE ESLESMESI IKI BICIMI DE KABUL EDER ve bu KEYFI DEGIL:
            # olcum gosterdi ki `unit.no` bazi tesislerde blok onekini
            # ZATEN icinde tasiyor ("A-1"), bazilarinda tasimiyor ("1").
            # Kullanicidan hangi bicimde yazdigini bilmesini beklemek
            # yanlis olurdu; ikisi de denenir.
            aranan = body.daire_no.strip().lower()
            blok = (body.blok or "").strip().lower()
            birlesik = f"{blok}-{aranan}" if blok else aranan
            unit = (
                await session.execute(
                    select(Unit).where(
                        or_(
                            func.lower(Unit.no) == aranan,
                            func.lower(Unit.no) == birlesik,
                        )
                    )
                )
            ).scalars().first()
            if unit is None:
                raise _KAYIT_GECERSIZ

            # Telefon BASKA bir kullaniciya aitse kayit acilmaz: telefon
            # global benzersiz ve kimligin ta kendisi.
            varolan = (
                await session.execute(
                    text("SELECT public.tenant_id_by_phone(:p)"), {"p": phone}
                )
            ).scalar_one_or_none()
            if varolan is not None:
                raise _KAYIT_GECERSIZ

            kod = f"{secrets.randbelow(1_000_000):06d}"
            # (P154) TENANT SINIRINI GECER — bu yuzden duz DELETE degil,
            # SECURITY DEFINER fonksiyon. `kayit_dogrulama` artik RLS
            # altinda (goc 0042) ve buradaki temizlik BASKA BIR TESISIN
            # satirina dokunmak zorunda: `uq_kayit_acik_basvuru` KISMI ve
            # GLOBAL bir benzersizlik indeksidir (bir telefon TUM
            # PLATFORMDA tek acik basvuru). Kisi A sitesinde kayda baslayip
            # B sitesinde baslarsa, RLS'e tabi bir DELETE A'nin satirini
            # goremez ve INSERT benzersizlik ihlaliyle 500 verirdi —
            # test_kayit_dogrulama_rls.py bunu OLCUYOR.
            #
            # `acik_temizle` DEGIL `telefon_sifirla`: buradaki eski DELETE
            # `amac` ve `durum` suzgeci TASIMIYORDU (kisi onay bekleyen
            # basvurusunu iptal edip bastan baslayabilsin diye). Davranis
            # bit bit korundu.
            await session.execute(
                text("SELECT public.kayit_dogrulama_telefon_sifirla(:p)"),
                {"p": phone},
            )
            session.add(
                KayitDogrulama(
                    tenant_id=tenant_id,
                    unit_id=unit.id,
                    telefon=phone,
                    kod_hash=hash_password(kod),
                    son_gecerlilik=datetime.now(timezone.utc)
                    + timedelta(minutes=_KAYIT_KOD_OMRU_DK),
                )
            )
            # SMS saglayici bugun LOG saglayicisidir: kod GONDERILMEZ,
            # gunluge yazilir. Gercek gecit baglanmasi YAPILANDIRMA isidir
            # (bkz. mesajlasma.MesajSaglayici) — bu uc degismez.
            sms_saglayicisi().gonder(
                phone, None,
                f"Yönetio kayıt kodunuz: {kod} "
                f"({_KAYIT_KOD_OMRU_DK} dakika geçerli)",
            )

    return KayitBaslaResponse(
        tesis_ad=tenant_ad,
        # `no` blok onekini zaten tasiyorsa TEKRAR eklenmez ("A-A-1" olurdu).
        daire=unit.no,
        telefon_maskeli=_telefon_maskele(phone),
    )


@router.post("/kayit/dogrula", response_model=KayitDurumResponse)
async def kayit_dogrula(body: KayitDogrulaRequest) -> KayitDurumResponse:
    """(P148.2) Kod dogru ise basvuru ONAYA dusuer — HESAP ACILMAZ.

    Onceki surumde burasi kullaniciyi acip token donuyordu. Kerem onay
    adimini actigi icin (bkz. MASTER-PLAN P148.2) hesap ancak yonetici
    onayindan SONRA acilir; bu uc artik oturum DONDURMEZ. Boylece tahmin
    edilebilir tesis kodu tek basina veriye erisim saglamaz.
    """
    try:
        phone = normalize_phone(body.telefon)
    except ValueError:
        raise _KAYIT_GECERSIZ

    async with SessionLocal() as session:
        async with session.begin():
            # (P154) `kayit_dogrulama` RLS altinda (goc 0042) ve burada
            # kullanicinin HENUZ OTURUMU YOK. Baglami yalniz tenant
            # kimligi donduren SECURITY DEFINER cozucu kurar.
            if (
                await tenant_baglamini_kur(session, telefon=phone, amac="kayit")
                is None
            ):
                raise _KAYIT_GECERSIZ
            kayit = (
                await session.execute(
                    select(KayitDogrulama).where(
                        KayitDogrulama.telefon == phone,
                        # (P154) `amac` SUZGECI EKLENDI. Onceden yoktu ve
                        # `uq_kayit_acik_basvuru` (telefon, amac) uzerinde
                        # oldugu icin ayni telefon farkli amaclarla BIRDEN
                        # FAZLA acik satir tasiyabilirdi — o durumda
                        # `scalar_one_or_none()` MultipleResultsFound ile
                        # 500 verirdi. Ayrica bir GIRIS kodunun kayit
                        # dogrulamasini tamamlamasi da engellenmis olur.
                        KayitDogrulama.amac == "kayit",
                        KayitDogrulama.durum == "telefon_bekliyor",
                    )
                )
            ).scalar_one_or_none()
            if kayit is None:
                raise _KAYIT_GECERSIZ
            if kayit.son_gecerlilik < datetime.now(timezone.utc):
                raise _KAYIT_GECERSIZ
            if kayit.deneme >= _KAYIT_MAX_DENEME:
                raise _KAYIT_GECERSIZ
            if not verify_password(body.kod, kayit.kod_hash):
                # SAYAC AYRI OTURUMDA: bu istek 422 ile bitecek ve
                # `session.begin()` blogu artisi GERI SARARDI (olculdu —
                # ilk yazimda koruma hic calismiyordu).
                async with SessionLocal() as s2:
                    async with s2.begin():
                        await set_tenant(s2, kayit.tenant_id)
                        await s2.execute(
                            update(KayitDogrulama)
                            .where(KayitDogrulama.id == kayit.id)
                            .values(deneme=KayitDogrulama.deneme + 1)
                        )
                raise _KAYIT_GECERSIZ

            kayit.ad = body.ad.strip()
            kayit.durum = "onay_bekliyor"
            await session.flush()

    return KayitDurumResponse(durum="onay_bekliyor")


# ==================== (P154) ROL SECIMLI KAYIT ============================== #
#
# BRIEF: rol -> tesis ID -> telefon -> parola. Tesis ID + telefon ONCEDEN
# TANIMLI bir kayitla eslesmiyorsa kaydolunamaz.
#
# P148'DEN FARKI (ve neden ayri bir yol): P148 `kayit/basla`, HENUZ HESABI
# OLMAYAN bir sakinin daire uzerinden basvurmasidir ve yonetici onayina
# duser. Burasi TERSI: hesap yonetici tarafindan ZATEN ACILMIS, kisi
# yalnizca onu SAHIPLENIYOR. Onay adimi YOKTUR — onay, hesabi acan
# yoneticinin kendisidir.
#
# AYNI TABLOYU (`kayit_dogrulama`) ve AYNI `amac='kayit'` degerini
# kullaniyoruz; ikisi `user_id` ile ayrilir:
#     user_id IS NULL      -> P148 basvurusu (hesap HENUZ YOK)
#     user_id IS NOT NULL  -> P154 rol kaydi (hesap VAR, sahipleniliyor)
# Enum'a yeni bir `amac` EKLENMEDI cunku enum degeri geri alinamaz ve
# `goc-tersinirlik` kapisi downgrade sonrasi semayi karsilastiriyor —
# artik kalan bir enum degeri o kapiyi kirardi.
#
# CAKISMA YOK: P148 zaten telefonu bir kullaniciya ait olan basvuruyu
# reddediyor (`tenant_id_by_phone`), bu yol ise TAM TERSINI ariyor. Bir
# telefon ayni anda iki akista olamaz.


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
async def giris_kodu_iste(body: TelefonIstek) -> KayitDurumResponse:
    """Kayitli ve AKTIF numaraya giris kodu gonderir.

    NUMARA VARLIGINI SIZDIRMAZ: numara kayitli olmasa da yanit AYNIDIR.
    Aksi halde bu uc bir "hangi numaralar kayitli" sorgusuna donusurdu.
    """
    try:
        phone = normalize_phone(body.telefon)
    except ValueError:
        return KayitDurumResponse(durum="onay_bekliyor")

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
            await kod_uret_ve_gonder(
                session, tenant_id=tenant_id, telefon=phone, amac="giris"
            )
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
