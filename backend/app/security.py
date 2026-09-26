"""Parola hash'leme + JWT uretimi/dogrulamasi.

/contracts/auth.md'ye uyar:
  * access claim'leri: sub (user_id), tenant_id, role, exp (+ iat, jti, type).
  * refresh claim'leri: sub, tenant_id, type=refresh, iat, exp, jti (+ fam: rotation
    ailesi — reuse tespiti/iptal icin).
  * access ~15 dk, refresh ~30 gun (config'ten).
"""
from __future__ import annotations

import re
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

import bcrypt
import jwt

from .config import settings


# --------------------------------------------------------------------------- #
# Telefon (global benzersiz login anahtari — E.164 tekbicim)
# --------------------------------------------------------------------------- #
_PHONE_RE = re.compile(r"^\+\d{8,15}$")


# Tesis adindan benzersiz slug (login telefonla oldugu icin slug ic detaydir;
# rastgele ek cakismayi pratikte imkansiz kilar).
_TR_ASCII = str.maketrans(
    {"ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u", "İ": "i",
     "Ç": "c", "Ğ": "g", "Ö": "o", "Ş": "s", "Ü": "u"}
)


def slugify_tenant(ad: str) -> str:
    base = ad.translate(_TR_ASCII).lower()
    base = re.sub(r"[^a-z0-9]+", "-", base).strip("-")[:40] or "tesis"
    return f"{base}-{secrets.token_hex(3)}"


def normalize_phone(raw: str) -> str:
    """Telefonu E.164'e normalize et (global benzersizlik icin tekbicim).

    - Bosluk/tire/parantez/nokta silinir.
    - Basta '00' -> '+'; basta tek '0' -> '+90' (TR varsayilan); '+' yoksa ve
      rakamla basliyorsa -> '+90' eklenir (ulke kodsuz TR numarasi).
    - Sonuc `+<8-15 rakam>` degilse ValueError (login'de 401, create'te 422).
    """
    s = re.sub(r"[\s\-().]", "", raw or "")
    if s.startswith("00"):
        s = "+" + s[2:]
    elif s.startswith("0"):
        s = "+90" + s[1:]
    elif not s.startswith("+"):
        s = "+90" + s
    if not _PHONE_RE.match(s):
        raise ValueError("Gecersiz telefon numarasi.")
    return s


# --------------------------------------------------------------------------- #
# Parola
# --------------------------------------------------------------------------- #
def hash_password(plain: str) -> str:
    """bcrypt ile parola hash'le (app_user.password_hash icin)."""
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, password_hash: str | None) -> bool:
    """Parolayi hash ile karsilastir (sabit-zaman, bcrypt).

    password_hash NULL olabilir (parolasini henuz belirlememis resident) —
    bu durumda her zaman False.
    """
    if not password_hash:
        return False
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), password_hash.encode("utf-8"))
    except (ValueError, TypeError):
        return False


#: (E2E 2026-09) ESLESME YOKKEN DE AYNI IS. Olculdu: var olan hesapta yanlis
#: parola ~450 ms (bcrypt), olmayan hesapta ~37 ms (bcrypt HIC kosmuyordu);
#: yanit govdesi ayni olsa da SURE hesabin varligini sizdiriyordu.
_SAHTE_HASH = bcrypt.hashpw(b"yonetiyor-sahte-parola", bcrypt.gensalt()).decode()


async def verify_password_async(plain: str, password_hash: str | None) -> bool:
    """`verify_password`in olay dongusunu KILITLEMEYEN bicimi.

    bcrypt ~0.3-0.5 sn CPU'dur; async uc govdesinde dogrudan cagrilinca tek
    worker'da TUM API bekler (olculdu: 10 paralel yanlis giriste `/health`
    30 ms -> 2.8 sn). Hash yoksa sahte hash'e karsi kosar: sure, hesabin
    var olup olmamasindan bagimsiz kalir.
    """
    from starlette.concurrency import run_in_threadpool

    if not password_hash:
        await run_in_threadpool(verify_password, plain, _SAHTE_HASH)
        return False
    return await run_in_threadpool(verify_password, plain, password_hash)


# Okunakli tek seferlik kod: karisan karakterler yok (I/L/O/0/1).
_TEMP_CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"


def generate_temp_code() -> str:
    """Sakin icin tek seferlik gecici giris kodu uret (orn. 'K7MR-2QWX').

    Kod yalnizca OLUSTURMA yanitinda bir kez duz metin doner (yonetici sakine
    iletir); DB'de bcrypt hash'i saklanir. Parola belirlenince gecersizlesir.
    """
    chars = "".join(secrets.choice(_TEMP_CODE_ALPHABET) for _ in range(8))
    return f"{chars[:4]}-{chars[4:]}"


# --------------------------------------------------------------------------- #
# JWT
# --------------------------------------------------------------------------- #
def _now() -> datetime:
    return datetime.now(tz=timezone.utc)


def _encode(claims: dict[str, Any]) -> str:
    return jwt.encode(claims, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_access_token(
    *, user_id: uuid.UUID | str, tenant_id: uuid.UUID | str, role: str,
    asil_rol: str | None = None,
    yz: str | None = None,
    fam: str | None = None,
) -> str:
    now = _now()
    claims = {
        "sub": str(user_id),
        "tenant_id": str(tenant_id),
        "role": role,
        "type": "access",
        "iat": int(now.timestamp()),
        # (E2E 2026-09) ms hassasiyetli verilis ani — oturum iptal damgasi
        # (`oturum_iptal.py`) saniye hassasiyetinde ayni saniyedeki yeni
        # girisi de eski sayardi.
        "ims": int(now.timestamp() * 1000),
        "exp": int((now + timedelta(minutes=settings.access_token_expire_minutes)).timestamp()),
        "jti": str(uuid.uuid4()),
    }
    # (P247 §2) IKINCIL modda (yonetici -> sakin) ASIL rol de tasinir: web
    # ara katmani yuzey kararini jetondan verir; "sakin" tek basina P129
    # geregi mobil-yalniz sayilirdi. YETKI VERMEZ — sunucu her istekte DB
    # rolunu ve daire bagini yeniden olcer (deps.get_current_user).
    if asil_rol and asil_rol != role:
        claims["asil_rol"] = asil_rol
    # (P248 §4) Web/platform oturumu: yuzey + aile, her istekte hareketsizlik
    # anahtarini tazelemek icin (`oturum_yuzeyi.py`).
    if yz:
        claims["yz"] = yz
        if fam:
            claims["fam"] = fam
    return _encode(claims)


def create_refresh_token(
    *,
    user_id: uuid.UUID | str,
    tenant_id: uuid.UUID | str,
    family_id: str | None = None,
    arol: str | None = None,
    yz: str | None = None,
) -> tuple[str, str, str]:
    """Refresh token uret. Donus: (token, jti, family_id).

    family_id verilmezse yeni bir aile baslatilir (login). Rotation'da ayni
    family_id tekrar kullanilir; boylece reuse tespitinde tum aile iptal edilir.
    """
    now = _now()
    jti = str(uuid.uuid4())
    fam = family_id or str(uuid.uuid4())
    claims = {
        "sub": str(user_id),
        "tenant_id": str(tenant_id),
        "type": "refresh",
        "iat": int(now.timestamp()),
        "ims": int(now.timestamp() * 1000),
        "exp": int((now + timedelta(days=settings.refresh_token_expire_days)).timestamp()),
        "jti": jti,
        "fam": fam,
    }
    # (P247 §2) Aktif IKINCIL rol (sakin modu) yenilemede korunur.
    if arol:
        claims["arol"] = arol
    # (P248 §4) Yuzey aileye aittir: yenilemede AYNEN tasinir.
    if yz:
        claims["yz"] = yz
    return _encode(claims), jti, fam


#: Gecici kodla girisin ardindan parola belirleme icin verilen kisa omurlu
#: token'in suresi (dakika). API erisimi VERMEZ; yalniz /auth/set-password'de gecer.
SETUP_TOKEN_EXPIRE_MINUTES = 10


def create_setup_token(*, user_id: uuid.UUID | str, tenant_id: uuid.UUID | str) -> str:
    """Parola-kurulum token'i (type=pwd_setup) uret.

    Gecici kod dogrulaninca doner; sakin bununla YALNIZCA parola belirleyebilir
    (access degildir, kaynak endpoint'lerinde gecmez — `type` kontrolu).
    """
    now = _now()
    claims = {
        "sub": str(user_id),
        "tenant_id": str(tenant_id),
        "type": "pwd_setup",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=SETUP_TOKEN_EXPIRE_MINUTES)).timestamp()),
        "jti": str(uuid.uuid4()),
    }
    return _encode(claims)


def create_kurulum_token(*, basvuru_id: uuid.UUID | str) -> str:
    """(P177 §5) TESIS KURULUM jetonu (type=tesis_kurulum).

    ===========================================================================
    `create_setup_token`DAN NEDEN AYRI
    ===========================================================================
    O jeton bir KULLANICIYA ve bir TESISE baglidir (`sub`, `tenant_id`) ve
    tasidigi yetki "parola belirle"dir. Burada ikisi de HENUZ YOK: ortada
    yalnizca e-postasi dogrulanmis bir BASVURU var.

    Ayni jetonu bos/sahte bir `tenant_id` ile uretmek, tip sistemini
    yalan soylemeye zorlamak olurdu — ve `pwd_setup` kabul eden ucun bir
    gun bu jetonu de kabul etme riskini dogururdu. Ayri `type`, o kapiyi
    yapisal olarak kapatir.

    OMRU AYARDAN: kullanicinin kodu girdikten sonra site adini yazacak
    kadar sure. Uzun tutmak, calinan bir jetonun penceresini bosuna
    genisletirdi.
    """
    now = _now()
    claims = {
        "sub": str(basvuru_id),
        "type": "tesis_kurulum",
        "iat": int(now.timestamp()),
        "exp": int(
            (now + timedelta(minutes=settings.kurulum_jetonu_omru_dk)).timestamp()
        ),
        "jti": str(uuid.uuid4()),
    }
    return _encode(claims)


def decode_token(token: str, *, expected_type: str) -> dict[str, Any]:
    """Token'i dogrula ve claim'leri don. Hatada jwt.PyJWTError firlatir.

    expected_type ('access'|'refresh') ile token tipi eslesmezse hata verir.
    """
    claims = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    if claims.get("type") != expected_type:
        raise jwt.InvalidTokenError(f"beklenen token tipi '{expected_type}'")
    return claims


def access_token_ttl_seconds() -> int:
    return settings.access_token_expire_minutes * 60
