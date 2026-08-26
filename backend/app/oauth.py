"""(P154 / Asama 4) OAUTH / OpenID Connect cekirdegi — Google, Microsoft, Apple.

===========================================================================
BU MODULUN ISI TEK BIR SORUYU YANITLAMAK
===========================================================================
"Bu istegi yapan kisi, saglayicida gercekten SU hesabin sahibi mi?"

Yaniti `sub` (subject) ve — yalniz goruntuleme icin — `email` olarak
dondurur. KIM OLDUGUNA (hangi tesis, hangi daire, hangi rol) BURASI KARAR
VERMEZ; brief'in kritik kurali geregi onu tesis ID + telefon belirler
(`routers/oauth.py`).

===========================================================================
IKI GIRIS BICIMI, TEK DOGRULAMA
===========================================================================
WEB: yetkilendirme kodu + PKCE. Tarayici koda gider, kodu bize verir, biz
     saglayiciyla TAKAS ederiz. `client_secret` sunucuda kalir.

MOBIL: cihazdaki yerel akis DOGRUDAN `id_token` verir. Kod takasi YOKTUR
     (mobil uygulamaya `client_secret` gomulemez — paketten cikarilir).

Ikisi de AYNI `kimlik_dogrula()` fonksiyonunda bulusur. Ayri iki dogrulama
yazmak, birinde `aud`/`iss`/imza kontrolunu unutmanin en kolay yoluydu.

===========================================================================
`aud` NEDEN LISTE
===========================================================================
Ayni Google projesi web ve Android icin AYRI istemci kimlikleri uretir ve
`id_token.aud` hangi istemciyle giris yapildiysa ONU tasir. Tek bir deger
beklemek, mobili ya da webi sessizce kapatirdi.

Liste BOS BIRAKILAMAZ: `aud` dogrulamasini atlamak, BASKA bir uygulamaya
kesilmis gecerli bir Google jetonunun bizde de gecmesi demektir
(karisik-vekil / "confused deputy"). Bu yuzden saglayici yapilandirilmamis
sayilir ve uc 503 doner — sessizce kabul etmez.

===========================================================================
JETON SAKLANMAZ
===========================================================================
`access_token`/`refresh_token` ne donulur ne yazilir. Saglayici API'si
cagrilmiyor; kimlik dogrulandiktan sonra oturumu kendi JWT ciftimiz
yurutur. Gerekce goc 0048'in basliginda.
"""
from __future__ import annotations

import base64
import hashlib
import secrets
import time
from dataclasses import dataclass, field

import httpx
import jwt

from .config import settings
from .errors import APIError

#: Yapilandirilmamis saglayici. CEVRILIR (duz metin degil): arayuz kapali
#: bir saglayiciyi normalde hic gostermez, ama yapilandirma degistikten
#: sonra acik kalmis bir sayfadan buraya DUSULEBILIR — ve o an ekrandaki
#: kullanicinin diliyle konusmasi gerekir.
SAGLAYICI_KAPALI = APIError(503, "service_unavailable", "oauth_saglayici_kapali")
#: Dogrulama basarisiz. TEK MESAJ: hangi adimin patladigi (imza mi, `aud`
#: mi, suresi mi) sizdirilmaz — `_INVALID_CREDS` ile ayni ilke.
KIMLIK_GECERSIZ = APIError(401, "invalid_credentials", "oauth_dogrulanamadi")


@dataclass(frozen=True)
class Saglayici:
    """Bir OpenID Connect saglayicisinin sabitleri + yapilandirmasi."""

    kod: str
    issuer: str | tuple[str, ...]
    jwks_uri: str
    yetki_ucu: str
    jeton_ucu: str
    kapsam: str
    istemci_id: str
    istemci_sir: str
    #: `id_token.aud` icin KABUL EDILEN degerler (web + mobil istemciler).
    izinli_aud: tuple[str, ...] = ()
    #: Apple `client_secret`i bir JWT'dir, sabit bir sir degil.
    apple: bool = False
    ek_yetki_parametreleri: dict[str, str] = field(default_factory=dict)

    @property
    def hazir(self) -> bool:
        """Kod takasi + jeton dogrulamasi icin gereken her sey var mi?"""
        return bool(self.istemci_id and self.izinli_aud)


def _liste(ham: str) -> tuple[str, ...]:
    return tuple(p.strip() for p in ham.split(",") if p.strip())


def saglayicilar() -> dict[str, Saglayici]:
    """Yapilandirmadan saglayici kaydini kurar.

    HER CAGRIDA YENIDEN OKUNUR (modul seviyesinde onbelleklenmez): testler
    ortam degiskenini degistirip yeniden okuyabilsin diye. Sozluk kucuk,
    maliyeti yok.
    """
    s = settings
    google_aud = _liste(s.oauth_google_aud or s.oauth_google_client_id)
    ms_aud = _liste(s.oauth_microsoft_aud or s.oauth_microsoft_client_id)
    apple_aud = _liste(s.oauth_apple_aud or s.oauth_apple_client_id)
    return {
        "google": Saglayici(
            kod="google",
            # Google TARIHSEL OLARAK IKI `iss` kullanir; ikisi de gecerlidir
            # ve yalniz birini kabul etmek rastgele girisleri reddederdi.
            issuer=("https://accounts.google.com", "accounts.google.com"),
            jwks_uri="https://www.googleapis.com/oauth2/v3/certs",
            yetki_ucu="https://accounts.google.com/o/oauth2/v2/auth",
            jeton_ucu="https://oauth2.googleapis.com/token",
            kapsam="openid email profile",
            istemci_id=s.oauth_google_client_id,
            istemci_sir=s.oauth_google_client_secret,
            izinli_aud=google_aud,
        ),
        "microsoft": Saglayici(
            kod="microsoft",
            # `common` kiracisinda `iss` HER KIRACI ICIN FARKLIDIR
            # (`.../{tid}/v2.0`). Sabit bir dize beklemek, kisisel Microsoft
            # hesaplari disinda herkesi reddederdi; bu yuzden `iss`
            # dogrulamasi ONEK ile yapilir (`_issuer_uyuyor`).
            issuer="https://login.microsoftonline.com/",
            jwks_uri=(
                f"https://login.microsoftonline.com/{s.oauth_microsoft_tenant}"
                "/discovery/v2.0/keys"
            ),
            yetki_ucu=(
                f"https://login.microsoftonline.com/{s.oauth_microsoft_tenant}"
                "/oauth2/v2.0/authorize"
            ),
            jeton_ucu=(
                f"https://login.microsoftonline.com/{s.oauth_microsoft_tenant}"
                "/oauth2/v2.0/token"
            ),
            kapsam="openid email profile",
            istemci_id=s.oauth_microsoft_client_id,
            istemci_sir=s.oauth_microsoft_client_secret,
            izinli_aud=ms_aud,
        ),
        "apple": Saglayici(
            kod="apple",
            issuer="https://appleid.apple.com",
            jwks_uri="https://appleid.apple.com/auth/keys",
            yetki_ucu="https://appleid.apple.com/auth/authorize",
            jeton_ucu="https://appleid.apple.com/auth/token",
            kapsam="openid email name",
            istemci_id=s.oauth_apple_client_id,
            istemci_sir="",  # uretilir (bkz. `_apple_istemci_sirri`)
            izinli_aud=apple_aud,
            apple=True,
            # APPLE `form_post` ZORUNLU KILAR: `name`/`email` kapsamlari
            # istendiginde geri donus GET ile gelmez, POST edilir.
            ek_yetki_parametreleri={"response_mode": "form_post"},
        ),
    }


def saglayici_al(kod: str) -> Saglayici:
    s = saglayicilar().get(kod)
    if s is None:
        raise APIError(404, "not_found", "oauth_saglayici_gecersiz")
    if not s.hazir:
        raise SAGLAYICI_KAPALI
    return s


def acik_saglayicilar() -> list[str]:
    """Yapilandirilmis saglayicilarin kodlari — arayuz hangi dugmeyi
    gosterecegini buradan ogrenir.

    Yapilandirilmamis bir saglayiciyi dugme olarak gostermek, kullaniciyi
    kesin basarisiz bir yola sokmak olurdu.
    """
    return [k for k, v in saglayicilar().items() if v.hazir]


# ======================= JWKS: getirme ve onbellek ========================= #
#
# Onbellek SART: her giriste saglayiciya bir istek daha atmak, girisleri
# saglayicinin hiz sinirina ve agdaki her aksakliga bagimli kilardi.
#
# ANAHTAR DONDURME (rotation) ONBELLEGI DELER: bilinmeyen bir `kid` gelirse
# onbellek BIR KEZ tazelenir. Aksi halde saglayici anahtarini degistirdigi
# an, TTL dolana kadar hicbir giris calismazdi.

_JWKS: dict[str, tuple[float, dict]] = {}
_JWKS_TTL = 3600.0


def jwks_onbellegi_temizle() -> None:
    """Testler icin. Uretimde cagrilmaz."""
    _JWKS.clear()


def jwks_onbellege_koy(uri: str, jwks: dict) -> None:
    """Testlerin AG'SIZ calisabilmesi icin onbellegi disaridan doldurur.

    Boylece dogrulamanin GERCEK kod yolu (imza, `iss`, `aud`, `exp`,
    `nonce`) test edilir; sahtelenen tek sey saglayicinin anahtar
    listesidir. Dogrulamayi mock'lamak, asil riskli kodu HIC olcmemek
    olurdu.
    """
    _JWKS[uri] = (time.monotonic() + _JWKS_TTL, jwks)


async def _jwks_getir(uri: str, *, zorla: bool = False) -> dict:
    kayit = _JWKS.get(uri)
    if kayit and not zorla and kayit[0] > time.monotonic():
        return kayit[1]
    async with httpx.AsyncClient(timeout=10.0) as ist:
        yanit = await ist.get(uri)
        yanit.raise_for_status()
        jwks = yanit.json()
    _JWKS[uri] = (time.monotonic() + _JWKS_TTL, jwks)
    return jwks


async def _imza_anahtari(sag: Saglayici, jeton: str):
    try:
        basliklar = jwt.get_unverified_header(jeton)
    except jwt.PyJWTError:
        raise KIMLIK_GECERSIZ
    kid = basliklar.get("kid")
    for zorla in (False, True):
        jwks = await _jwks_getir(sag.jwks_uri, zorla=zorla)
        for anahtar in jwks.get("keys", []):
            if anahtar.get("kid") == kid:
                return jwt.PyJWK(anahtar).key
        if zorla:
            break
    raise KIMLIK_GECERSIZ


def _issuer_uyuyor(sag: Saglayici, iss: str) -> bool:
    if isinstance(sag.issuer, tuple):
        return iss in sag.issuer
    if sag.kod == "microsoft":
        # `common` kiracisinda `iss` kiraciya gore degisir; ONEK esitligi
        # + `/v2.0` sonu, "login.microsoftonline.com bir kiracisi" demenin
        # dogru yoludur. Tam esitlik istemek, kisisel hesap disinda
        # herkesi reddederdi.
        return iss.startswith(sag.issuer) and iss.endswith("/v2.0")
    return iss == sag.issuer


@dataclass(frozen=True)
class Kimlik:
    saglayici: str
    subject: str
    #: YALNIZ GORUNTULEME. Eslesmede kullanilmaz (goc 0048).
    eposta: str | None
    #: (P180 guvenlik) Saglayici e-postayi DOGRULADI mi? (`id_token.email_
    #: verified`). E-POSTA TABANLI hesap eslesmesi (kayit->mevcut_hesap) icin
    #: ZORUNLU: dogrulanmamis e-posta ile bir hesaba baglamak HESAP ELE
    #: GECIRME olurdu (saldirgan kurbanin adresini iddia eden dogrulanmamis
    #: bir hesap acar). Kimlik eslesmesi (saglayici+subject) bundan ETKILENMEZ.
    email_verified: bool = False
    #: Apple'in private relay adresi mi? Arayuz bunu kullaniciya soyler.
    relay: bool = False
    #: (P155r2 / §2) Saglayicinin bildirdigi ad soyad — KAYIT FORMUNU
    #: ON-DOLDURMAK icin. Sartname: "sağlayıcıdan gelen ad soyad ve
    #: (varsa) telefon FORMA OTOMATİK DOLAR, kullanıcı düzenleyebilir."
    #:
    #: ESLESMEDE KULLANILMAZ — `eposta` ile ayni sinifta bir goruntuleme
    #: alanidir. Kullanici duzeltebildigi icin zaten guvenilir bir kimlik
    #: tasiyicisi degil; sunucuya `ad` alaninda AYRICA gelir.
    #:
    #: TELEFON YOK ve OLMAYACAK: uc saglayicinin hicbiri OpenID Connect
    #: `id_token`inda telefon vermiyor (`phone_number` kapsami Google'da
    #: yok, Microsoft'ta ayri bir Graph izni ister, Apple'da hic yok).
    #: Sartname bunu zaten varsayiyor: "Sağlayıcı telefon vermez —
    #: telefon alanı boş gelir ve kullanıcı doldurur."
    ad: str | None = None


async def kimlik_dogrula(kod: str, id_token: str, *, nonce: str | None = None) -> Kimlik:
    """`id_token`i dogrular ve kimligi doner. TEK dogrulama yolu.

    `nonce` VERILDIYSE ESLESMEK ZORUNDADIR: web akisinda nonce, jetonun
    BIZIM baslattigimiz oturuma ait oldugunu kanitlar ve yeniden-oynatmayi
    (replay) engeller. Mobil yerel akista SDK nonce'u yonetir, biz
    uretmediysek dogrulamayiz.
    """
    sag = saglayici_al(kod)
    anahtar = await _imza_anahtari(sag, id_token)
    try:
        iddialar = jwt.decode(
            id_token,
            anahtar,
            algorithms=["RS256", "ES256"],
            audience=list(sag.izinli_aud),
            options={"require": ["exp", "iss", "sub", "aud"]},
        )
    except jwt.PyJWTError:
        raise KIMLIK_GECERSIZ

    if not _issuer_uyuyor(sag, str(iddialar.get("iss", ""))):
        raise KIMLIK_GECERSIZ
    if nonce is not None and iddialar.get("nonce") != nonce:
        raise KIMLIK_GECERSIZ

    subject = str(iddialar.get("sub") or "")
    if not subject:
        raise KIMLIK_GECERSIZ

    eposta = iddialar.get("email")
    # APPLE PRIVATE RELAY: kullanici "e-postami gizle" derse Apple
    # `...@privaterelay.appleid.com` verir. Bu adres KALICI DEGILDIR
    # (kullanici iliskisini kesince olur) ve bu yuzden hicbir yerde
    # eslesme anahtari olarak kullanilmaz; yalniz "hangi hesabi
    # bagladim" sorusunu yanitlar.
    relay = bool(eposta) and str(eposta).endswith("@privaterelay.appleid.com")

    # (P180 guvenlik) `email_verified` bool ya da "true"/"false" dizgesi gelebilir
    # (saglayiciya gore). Yalniz kesin TRUE dogrulanmis sayilir. Apple private
    # relay adresi Apple'in kontrolundedir -> dogrulanmis kabul edilir.
    ev = iddialar.get("email_verified")
    email_verified = ev is True or str(ev).lower() == "true" or relay

    # AD: Google ve Microsoft `name` iddiasini `profile` kapsamiyla verir.
    # APPLE VERMEZ — Apple adi yalniz ILK yetkilendirmede, `id_token`da
    # DEGIL, `form_post` govdesindeki `user` alaninda gonderir ve bir daha
    # asla tekrarlamaz. Onu yakalamak icin callback govdesini ayrica
    # ayikla mak gerekirdi; yapilmadi ve sebebi su: ad zaten kullanicinin
    # DUZENLEYEBILECEGI bir on-doldurmadir, Apple'da bos gelmesi akisi
    # kirmaz (kullanici yazar). Sessiz bir bos alan, yalniz ilk giriste
    # calisip sonra bozulan bir ozellikten iyidir.
    ad = iddialar.get("name")
    return Kimlik(
        saglayici=sag.kod,
        subject=subject,
        eposta=str(eposta) if eposta else None,
        email_verified=email_verified,
        relay=relay,
        ad=str(ad).strip() or None if ad else None,
    )


# ============================ PKCE + durum ================================= #


def pkce_uret() -> tuple[str, str]:
    """(`code_verifier`, `code_challenge`) — S256.

    PKCE, `client_secret` TASIYAN web akisinda bile eklenir: kodun
    yakalanip baska bir istemcide kullanilmasini engeller ve bugun her
    saglayici tarafindan destekleniyor. Bedeli bir hash.
    """
    dogrulayici = base64.urlsafe_b64encode(secrets.token_bytes(32)).rstrip(b"=").decode()
    ozet = hashlib.sha256(dogrulayici.encode("ascii")).digest()
    meydan = base64.urlsafe_b64encode(ozet).rstrip(b"=").decode()
    return dogrulayici, meydan


def _apple_istemci_sirri(sag: Saglayici) -> str:
    """Apple `client_secret`i SABIT DEGIL, ES256 ile imzalanmis bir JWT'dir.

    Her takasta yeniden uretilir: uzun omurlu bir sir uretip saklamak,
    suresi doldugunda girisin sessizce durmasi demekti (Apple azami 6 ay
    verir). Uretim maliyeti bir imza.
    """
    simdi = int(time.time())
    return jwt.encode(
        {
            "iss": settings.oauth_apple_team_id,
            "iat": simdi,
            "exp": simdi + 600,
            "aud": "https://appleid.apple.com",
            "sub": sag.istemci_id,
        },
        settings.oauth_apple_private_key.replace("\\n", "\n"),
        algorithm="ES256",
        headers={"kid": settings.oauth_apple_key_id},
    )


def yetki_adresi(
    sag: Saglayici, *, redirect_uri: str, state: str, nonce: str, meydan: str
) -> str:
    from urllib.parse import urlencode

    parametreler = {
        "client_id": sag.istemci_id,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": sag.kapsam,
        "state": state,
        "nonce": nonce,
        "code_challenge": meydan,
        "code_challenge_method": "S256",
        **sag.ek_yetki_parametreleri,
    }
    return f"{sag.yetki_ucu}?{urlencode(parametreler)}"


async def kod_degistir(
    sag: Saglayici, *, code: str, redirect_uri: str, dogrulayici: str
) -> str:
    """Yetkilendirme kodunu `id_token` ile takas eder.

    YALNIZ `id_token` DONER: `access_token` bilincli olarak atilir (bkz.
    modul basligi) — donmek, cagiranin onu saklamasini kolaylastirirdi.
    """
    if sag.apple:
        sir = _apple_istemci_sirri(sag)
    else:
        sir = sag.istemci_sir
        if not sir:
            raise SAGLAYICI_KAPALI

    veri = {
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": redirect_uri,
        "client_id": sag.istemci_id,
        "client_secret": sir,
        "code_verifier": dogrulayici,
    }
    async with httpx.AsyncClient(timeout=15.0) as ist:
        yanit = await ist.post(sag.jeton_ucu, data=veri)
    if yanit.status_code >= 400:
        raise KIMLIK_GECERSIZ
    id_token = yanit.json().get("id_token")
    if not id_token:
        raise KIMLIK_GECERSIZ
    return str(id_token)
