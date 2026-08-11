"""(P154 / Asama 4) SOSYAL GIRIS UCLARI — Google / Microsoft / Apple.

===========================================================================
BRIEF'IN KRITIK KURALI VE BUNUN UCLARA YANSIMASI
===========================================================================
"Saglayici telefon vermiyor ama eslesme modelimiz tesis ID + telefon.
Sosyal hesapla kaydolan da tesis ID ve telefon girecek; sosyal hesap
kimlik dogrulama YONTEMI, eslesme anahtari degil."

Bu yuzden burada ASLA KULLANICI YARATILMAZ. Sosyal giris iki sonuctan
birini verir:
  * kimlik ZATEN BAGLI  -> oturum acilir,
  * kimlik BAGLI DEGIL  -> "baglama gerekli" denir ve kullanici tesis
    kodu + telefonunu girer, SMS ile dogrular, ancak O ZAMAN baglanir.

===========================================================================
ILK BAGLAMADA SMS NEDEN ZORUNLU
===========================================================================
Saglayici "bu Google hesabinin sahibisin" der; "bu telefonun sahibisin"
DEMEZ. SMS olmasaydi, birinin tesis kodunu ve telefon numarasini bilen
herhangi biri kendi Google hesabini o kisinin hesabina baglayip iceri
girerdi. Tesis kodu KAMUYA ACIK, telefon numarasi ise sir degil — yani
ikisi birlikte bir kimlik kaniti DEGILDIR.

Bu yeni bir kapi ACMAZ, mevcut kapiyla AYNI GUCTEDIR: uruncte SMS zaten
tek basina oturum aciyor (`/auth/giris/kod-dogrula`, P149). Dolayisiyla
SMS ile korunan bir baglama, en zayif mevcut kapidan daha zayif degildir.

PAROLASI OLAN HESAP DA BAGLAYABILIR — `kayit` akisindaki
`password_set=false` sarti BURAYA KONMADI. Konsaydi "parolan var, o hâlde
Google'i hic kullanamazsin" demis olurduk; oysa kullanici SMS ile telefon
sahipligini kanitliyor ve bu, parolayi bilmekle ayni sinifta bir kanit
(yukaridaki gerekce).

===========================================================================
GERI DONUS ADRESI ISTEKTEN ALINMAZ
===========================================================================
Callback'ten sonra tarayici NEREYE gonderilecekse, o adres AYARLARDAN
gelir (`oauth_web_donus` / `oauth_mobil_donus`). Istekten almak klasik
acik-yonlendirme (open redirect) acigi olurdu: saldirgan kendi adresini
verir, kullanici saglayicidan donerken oraya dusurulur.

Ayni sebeple saglayiciya bildirilen `redirect_uri` HER ZAMAN bizim
callback ucumuzdur. Bunun ikinci bir faydasi var: her saglayicida
KAYDEDILECEK TEK BIR ADRES olur (mobil icin ayri bir kayit gerekmez).

===========================================================================
YOL SEKLI: `/baslat/{saglayici}` — `/{saglayici}/baslat` DEGIL
===========================================================================
Degisken segment BASA konsaydi `/baglan/basla` istegi `/{saglayici}/basla`
kalibina duserdi (`saglayici="baglan"`) ve govde BASKA bir semayla
dogrulanip 422 verirdi — OLCULDU. FastAPI yollari TANIM SIRASINA gore
eslestirdigi icin "literal rotalari once yaz" ile de cozulebilirdi, ama o
cozum DISIPLINE bagli: siralamayi bozan biri sessiz bir 422 uretirdi.
Degisken segmenti SONA almak ayni hatayi YAPISAL OLARAK imkansiz kilar.

===========================================================================
JETON URL'DE TASINMAZ
===========================================================================
Callback, sonucu Redis'e tek kullanimlik bir kimlikle yazar ve tarayiciyi
`...?oauth=<id>` ile geri gonderir. Uygulama o kimligi `POST /sonuc` ile
jetona cevirir. Erisim jetonunu adres cubuguna koymak, onu tarayici
gecmisine, `Referer` basligina ve sunucu gunluklerine yazmak olurdu.
"""
from __future__ import annotations

import json
import secrets
from datetime import datetime, timedelta, timezone

import jwt
import redis.asyncio as aioredis
from fastapi import APIRouter, Depends, Form, Request, Response
from fastapi.responses import RedirectResponse
from sqlalchemy import func, select, text

from ..audit import Action, record_audit
from ..config import settings
from ..db import SessionLocal, set_tenant
from ..deps import get_current_user, get_redis, gorev_penceresi_disinda
from ..errors import APIError
from ..hiz_siniri import kod_istegi_say
from ..models import AppUser, OauthKimlik, Tenant
from ..oauth import (
    KIMLIK_GECERSIZ,
    SAGLAYICI_KAPALI,
    Kimlik,
    acik_saglayicilar,
    kimlik_dogrula,
    kod_degistir,
    pkce_uret,
    saglayici_al,
)
from ..schemas import (
    OauthBaglaBaslaRequest,
    OauthBaglaDogrulaRequest,
    OauthBaglantiListesi,
    OauthBaglantiOut,
    OauthBaslaRequest,
    OauthBaslaResponse,
    OauthKayitBaslaResponse,
    OauthSaglayiciListesi,
    OauthSonucIstek,
    OauthSonucResponse,
    TokenPair,
)
from ..security import normalize_phone
from ..telefon_kodu import GECERSIZ as TK_GECERSIZ
from ..telefon_kodu import kod_uret_ve_gonder, kodu_dogrula
from .auth import _issue_token_pair

router = APIRouter(prefix="/auth/oauth", tags=["auth"])

_OTURUM_GECERSIZ = APIError(400, "bad_request", "oauth_oturum_gecersiz")
_BAGLAMA_GECERSIZ = APIError(400, "bad_request", "oauth_baglama_gecersiz")
_BASKASINA_BAGLI = APIError(409, "conflict", "oauth_baska_hesaba_bagli")
_BAGLANTI_YOK = APIError(404, "not_found", "oauth_baglanti_yok")
_SON_YONTEM = APIError(409, "conflict", "oauth_son_giris_yontemi")
_GOREV_SURESI_DISINDA = APIError(403, "forbidden", "gorev_suresi_disinda")

#: Baglama jetonunun JWT `type` iddiasi — `access` ile karistirilamaz.
_BAGLAMA_TIPI = "oauth_link"

#: SMS kodunun amaci. 'kayit' YENIDEN KULLANILMADI: `amac` ayriminin tum
#: varlik sebebi "bir amac icin uretilen kod baska bir kapiyi acamaz"
#: (goc 0039) ve iki yolun onkosullari FARKLI ('kayit' parolasiz hesap
#: ister, baglama istemez).
_KOD_AMACI = "oauth"

_YUZEYLER = ("web", "mobil")


def _donus_adresi(yuzey: str) -> str:
    """Callback sonrasi tarayicinin gonderilecegi adres — AYARLARDAN.

    Istekten alinmaz (bkz. modul basligi: acik yonlendirme).

    BOSSA SAGLAYICI KAPALI SAYILIR ve bu `basla`da (kullanici siteden
    AYRILMADAN) kontrol edilir. Aksi hâlde yanlis yapilandirma SESSIZ
    kalirdi: kullanici Google'a gider, doner ve 404 bulur — hata mesaji
    saglayicinin sayfasinda degil bizim tarafimizda olmali.
    """
    if yuzey == "mobil":
        return settings.oauth_mobil_donus
    return settings.oauth_web_donus


def _callback_adresi(istek: Request, saglayici: str) -> str:
    """Saglayiciya bildirilen `redirect_uri`.

    `oauth_callback_taban` VERILMISSE O KULLANILIR ve bu NORMAL DURUMDUR:
    saglayicilar adresi TAM ESLESME ile dogrular, dolayisiyla ters vekil
    arkasindaki bir kurulumda istekten turetilen adres (ic konak adi,
    http, farkli port) kayitli adresle tutmaz ve giris "redirect_uri
    mismatch" ile patlardi.
    """
    taban = settings.oauth_callback_taban.rstrip("/")
    if not taban:
        taban = str(istek.base_url).rstrip("/")
    return f"{taban}/auth/oauth/callback/{saglayici}"


@router.get("/saglayicilar", response_model=OauthSaglayiciListesi)
async def saglayici_listesi() -> OauthSaglayiciListesi:
    """Yapilandirilmis saglayicilar — arayuz hangi dugmeyi gosterecegini
    buradan ogrenir.

    KIMLIK GEREKTIRMEZ: giris ekraninda, oturum acilmadan cagrilir.
    Sizdirdigi tek bilgi hangi saglayicilarin acik oldugu — bu zaten
    giris ekranindaki dugmelerden gorunur.
    """
    return OauthSaglayiciListesi(saglayicilar=acik_saglayicilar())


@router.post("/baslat/{saglayici}", response_model=OauthBaslaResponse)
async def basla(
    saglayici: str,
    body: OauthBaslaRequest,
    istek: Request,
    redis: aioredis.Redis = Depends(get_redis),
) -> OauthBaslaResponse:
    """Saglayiciya gidilecek adresi uretir ve oturumu (state) saklar."""
    sag = saglayici_al(saglayici)
    yuzey = body.yuzey if body.yuzey in _YUZEYLER else "web"
    if not _donus_adresi(yuzey):
        raise SAGLAYICI_KAPALI

    state = secrets.token_urlsafe(32)
    nonce = secrets.token_urlsafe(16)
    dogrulayici, meydan = pkce_uret()
    redirect_uri = _callback_adresi(istek, sag.kod)

    await redis.set(
        f"oauth:state:{state}",
        json.dumps(
            {
                "saglayici": sag.kod,
                "nonce": nonce,
                "dogrulayici": dogrulayici,
                "yuzey": yuzey,
                "redirect_uri": redirect_uri,
            }
        ),
        ex=settings.oauth_state_ttl_seconds,
    )

    from ..oauth import yetki_adresi

    adres = yetki_adresi(
        sag, redirect_uri=redirect_uri, state=state, nonce=nonce, meydan=meydan
    )
    return OauthBaslaResponse(adres=adres, state=state)


async def _oturum_al(redis: aioredis.Redis, state: str) -> dict:
    """State'i TUKETEREK okur.

    `getdel`: bir `state` YALNIZ BIR KEZ kullanilabilir. Birakmak, ayni
    yetkilendirme kodunun yeniden oynatilmasina (replay) kapi acardi.
    """
    ham = await redis.getdel(f"oauth:state:{state}")
    if not ham:
        raise _OTURUM_GECERSIZ
    return json.loads(ham)


async def _sonucu_yaz(redis: aioredis.Redis, veri: dict) -> str:
    sonuc_id = secrets.token_urlsafe(32)
    await redis.set(
        f"oauth:sonuc:{sonuc_id}",
        json.dumps(veri),
        ex=settings.oauth_baglama_ttl_seconds,
    )
    return sonuc_id


async def _kimligi_coz(kimlik: Kimlik) -> dict:
    """Kimlik bagli mi? Bagliysa hangi kullaniciya?

    RLS BOOTSTRAP: kullanicinin oturumu yok, tesisi bilinmiyor. `tenant_id
    _by_oauth` (goc 0048, SECURITY DEFINER) donguyu kirar — `tenant_id_by
    _phone` ile ayni sinif.
    """
    async with SessionLocal() as session:
        async with session.begin():
            tenant_id = (
                await session.execute(
                    text("SELECT public.tenant_id_by_oauth(:s, :sub)"),
                    {"s": kimlik.saglayici, "sub": kimlik.subject},
                )
            ).scalar_one_or_none()
            if tenant_id is None:
                return {"tur": "baglama"}

            await set_tenant(session, tenant_id)
            satir = (
                await session.execute(
                    select(OauthKimlik).where(
                        OauthKimlik.saglayici == kimlik.saglayici,
                        OauthKimlik.subject == kimlik.subject,
                    )
                )
            ).scalar_one_or_none()
            if satir is None:
                return {"tur": "baglama"}
            return {
                "tur": "giris",
                "tenant_id": str(tenant_id),
                "user_id": str(satir.user_id),
            }


async def _callback_isle(
    istek: Request,
    saglayici: str,
    code: str | None,
    state: str | None,
    redis: aioredis.Redis,
) -> RedirectResponse:
    if not code or not state:
        raise _OTURUM_GECERSIZ
    oturum = await _oturum_al(redis, state)
    if oturum.get("saglayici") != saglayici:
        raise _OTURUM_GECERSIZ

    sag = saglayici_al(saglayici)
    id_token = await kod_degistir(
        sag,
        code=code,
        redirect_uri=oturum["redirect_uri"],
        dogrulayici=oturum["dogrulayici"],
    )
    kimlik = await kimlik_dogrula(saglayici, id_token, nonce=oturum["nonce"])

    veri = await _kimligi_coz(kimlik)
    veri.update(
        saglayici=kimlik.saglayici,
        subject=kimlik.subject,
        eposta=kimlik.eposta,
        relay=kimlik.relay,
    )
    sonuc_id = await _sonucu_yaz(redis, veri)

    ayirac = "&" if "?" in _donus_adresi(oturum["yuzey"]) else "?"
    return RedirectResponse(
        f"{_donus_adresi(oturum['yuzey'])}{ayirac}oauth={sonuc_id}", status_code=303
    )


@router.get("/callback/{saglayici}")
async def callback_get(
    saglayici: str,
    istek: Request,
    code: str | None = None,
    state: str | None = None,
    redis: aioredis.Redis = Depends(get_redis),
) -> RedirectResponse:
    """Google/Microsoft geri donusu (GET)."""
    return await _callback_isle(istek, saglayici, code, state, redis)


@router.post("/callback/{saglayici}")
async def callback_post(
    saglayici: str,
    istek: Request,
    code: str | None = Form(default=None),
    state: str | None = Form(default=None),
    redis: aioredis.Redis = Depends(get_redis),
) -> RedirectResponse:
    """Apple geri donusu.

    APPLE `form_post` KULLANIR: `name`/`email` kapsamlari istendiginde
    sonuc GET sorgu dizesiyle degil, POST govdesiyle gelir. Ayni uc iki
    metotla acilmazsa Apple girisi callback'te 405 alirdi.
    """
    return await _callback_isle(istek, saglayici, code, state, redis)


def _baglama_jetonu(kimlik: dict) -> str:
    simdi = datetime.now(timezone.utc)
    return jwt.encode(
        {
            "type": _BAGLAMA_TIPI,
            "saglayici": kimlik["saglayici"],
            "subject": kimlik["subject"],
            "eposta": kimlik.get("eposta"),
            "iat": int(simdi.timestamp()),
            "exp": int(
                (
                    simdi + timedelta(seconds=settings.oauth_baglama_ttl_seconds)
                ).timestamp()
            ),
        },
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )


def _baglama_coz(jeton: str) -> dict:
    try:
        iddialar = jwt.decode(
            jeton, settings.jwt_secret, algorithms=[settings.jwt_algorithm]
        )
    except jwt.PyJWTError:
        raise _BAGLAMA_GECERSIZ
    if iddialar.get("type") != _BAGLAMA_TIPI:
        raise _BAGLAMA_GECERSIZ
    return iddialar


@router.post("/sonuc", response_model=OauthSonucResponse)
async def sonuc(
    body: OauthSonucIstek,
    redis: aioredis.Redis = Depends(get_redis),
) -> OauthSonucResponse:
    """Callback'in biraktigi tek kullanimlik sonucu jetona cevirir.

    IKI OLASI SONUC:
      * `giris`   — kimlik zaten bagli, oturum acilir,
      * `baglama` — kimlik dogrulandi ama bir hesaba bagli degil; cagiran
        tesis kodu + telefon ile devam eder.
    """
    ham = await redis.getdel(f"oauth:sonuc:{body.sonuc_id}")
    if not ham:
        raise _OTURUM_GECERSIZ
    veri = json.loads(ham)

    if veri.get("tur") != "giris":
        return OauthSonucResponse(
            durum="baglama_gerekli",
            saglayici=veri["saglayici"],
            eposta=veri.get("eposta"),
            relay=bool(veri.get("relay")),
            baglama_jetonu=_baglama_jetonu(veri),
        )

    async with SessionLocal() as session:
        async with session.begin():
            await set_tenant(session, veri["tenant_id"])
            user = (
                await session.execute(
                    select(AppUser).where(AppUser.id == veri["user_id"])
                )
            ).scalar_one_or_none()
            if user is None or not user.is_active:
                raise KIMLIK_GECERSIZ
            # (P128) Gorev suresi disindaki denetci token ALMAZ — parolali
            # ve kodlu yollarda oldugu gibi. Buraya konmasaydi sosyal
            # giris o kapiyi delerdi.
            if gorev_penceresi_disinda(user):
                raise _GOREV_SURESI_DISINDA
            await session.execute(
                OauthKimlik.__table__.update()
                .where(
                    OauthKimlik.saglayici == veri["saglayici"],
                    OauthKimlik.subject == veri["subject"],
                )
                .values(son_giris_at=func.now())
            )
            await record_audit(
                session,
                action=Action.LOGIN_OK,
                tenant_id=user.tenant_id,
                actor_user_id=user.id,
                actor_rol=user.role,
                resource_type="app_user",
                resource_id=user.id,
                meta={"method": f"oauth:{veri['saglayici']}"},
            )
            cift = await _issue_token_pair(redis, user)

    return OauthSonucResponse(durum="giris", jetonlar=cift)


@router.post("/baglan/basla", response_model=OauthKayitBaslaResponse)
async def baglan_basla(
    body: OauthBaglaBaslaRequest,
    redis: aioredis.Redis = Depends(get_redis),
) -> OauthKayitBaslaResponse:
    """Tesis kodu + telefon eslesirse SMS kodu gonderir.

    ESLESME SONUCU YANITTAN OKUNAMAZ — `auth.rol_kayit_basla` ile AYNI
    ilke: yanit her durumda tesis adini ve maskeli numarayi doner, SMS
    gonderilip gonderilmedigi disaridan anlasilmaz. Aksi hâlde uc bir
    "bu numara bu sitede kayitli mi" sorgusuna donusurdu.
    """
    kimlik = _baglama_coz(body.baglama_jetonu)
    try:
        phone = normalize_phone(body.telefon)
    except ValueError:
        raise _BAGLAMA_GECERSIZ

    # HIZ SINIRI DOGRULAMADAN ONCE — `rol_kayit_basla` ile ayni sira.
    # Sonra saymak, eslesmeyen numara icin sinirsiz deneme birakirdi.
    await kod_istegi_say(redis, phone, kapsam="oauth_baglama")

    async with SessionLocal() as session:
        async with session.begin():
            tenant_id = (
                await session.execute(
                    text("SELECT public.tenant_id_by_kayit_kodu(:k)"),
                    {"k": body.tesis_kodu.strip()},
                )
            ).scalar_one_or_none()
            # TESIS KODU HATASI SOYLENIR: kod kamuya aciktir ve en sik
            # yazim hatasi orada olur (`rol_kayit_basla` ile ayni karar).
            if tenant_id is None:
                raise _BAGLAMA_GECERSIZ

            await set_tenant(session, tenant_id)
            tenant_ad = (
                await session.execute(select(Tenant.ad).where(Tenant.id == tenant_id))
            ).scalar_one()

            user = (
                await session.execute(select(AppUser).where(AppUser.telefon == phone))
            ).scalar_one_or_none()

            # BURADAN SONRASI SESSIZ: hicbir dal yaniti degistirmez.
            if user is not None and user.is_active:
                await kod_uret_ve_gonder(
                    session,
                    tenant_id=tenant_id,
                    telefon=phone,
                    amac=_KOD_AMACI,
                    user_id=user.id,
                )

    return OauthKayitBaslaResponse(
        tesis_ad=tenant_ad, telefon_maskeli=_telefon_maskele(phone)
    )


def _telefon_maskele(t: str) -> str:
    if len(t) <= 6:
        return "*" * len(t)
    return f"{t[:5]}***{t[-3:]}"


async def _kimligi_bagla(
    session, *, user: AppUser, saglayici: str, subject: str, eposta: str | None
) -> None:
    """Kimligi kullaniciya baglar. AYNI SAGLAYICIDAN eskisi VARSA DEGISIR.

    Neden degistirme: `uq_oauth_kimlik_user_saglayici` bir kullaniciya
    saglayici basina tek kimlik birakir (goc 0048). Ikinci bir Google
    hesabini "hata" saymak yerine YENISIYLE DEGISTIRMEK, kullanicinin
    hesap degistirdigi (is -> kisisel) en yaygin durumu dogrudan
    karsilar; onceki satiri birakmak ise "yontemi kaldir" ekranini iki
    ayirt edilemez satirla doldururdu.

    BASKA BIR KULLANICIYA BAGLI KIMLIK DEVRALINMAZ: `_BASKASINA_BAGLI`.
    Devralmak, bir Google hesabinin iki kisiyi acmasi demekti.
    """
    baskasi = (
        await session.execute(
            text(
                "SELECT public.tenant_id_by_oauth(:s, :sub)"
            ),
            {"s": saglayici, "sub": subject},
        )
    ).scalar_one_or_none()
    if baskasi is not None:
        mevcut = (
            await session.execute(
                select(OauthKimlik).where(
                    OauthKimlik.saglayici == saglayici,
                    OauthKimlik.subject == subject,
                )
            )
        ).scalar_one_or_none()
        # `mevcut is None` = satir BASKA bir tenant'ta (RLS gizliyor).
        if mevcut is None or mevcut.user_id != user.id:
            raise _BASKASINA_BAGLI
        mevcut.eposta = eposta
        mevcut.son_giris_at = func.now()
        return

    await session.execute(
        OauthKimlik.__table__.delete().where(
            OauthKimlik.user_id == user.id,
            OauthKimlik.saglayici == saglayici,
        )
    )
    session.add(
        OauthKimlik(
            tenant_id=user.tenant_id,
            user_id=user.id,
            saglayici=saglayici,
            subject=subject,
            eposta=eposta,
        )
    )
    await session.flush()


@router.post("/baglan/dogrula", response_model=TokenPair)
async def baglan_dogrula(
    body: OauthBaglaDogrulaRequest,
    redis: aioredis.Redis = Depends(get_redis),
) -> TokenPair:
    """SMS kodu dogruysa kimligi baglar VE oturum acar."""
    kimlik = _baglama_coz(body.baglama_jetonu)
    try:
        phone = normalize_phone(body.telefon)
    except ValueError:
        raise TK_GECERSIZ

    async with SessionLocal() as session:
        async with session.begin():
            kayit = await kodu_dogrula(
                session, telefon=phone, kod=body.kod, amac=_KOD_AMACI
            )
            await set_tenant(session, kayit.tenant_id)
            user = (
                await session.execute(select(AppUser).where(AppUser.telefon == phone))
            ).scalar_one_or_none()
            if user is None or not user.is_active:
                raise TK_GECERSIZ
            if gorev_penceresi_disinda(user):
                raise _GOREV_SURESI_DISINDA

            await _kimligi_bagla(
                session,
                user=user,
                saglayici=kimlik["saglayici"],
                subject=kimlik["subject"],
                eposta=kimlik.get("eposta"),
            )
            # Kod TUKETILIR: tekrar kullanilamaz.
            kayit.durum = "onaylandi"
            await record_audit(
                session,
                action=Action.LOGIN_OK,
                tenant_id=user.tenant_id,
                actor_user_id=user.id,
                actor_rol=user.role,
                resource_type="app_user",
                resource_id=user.id,
                meta={"method": f"oauth_baglama:{kimlik['saglayici']}"},
            )
            await session.flush()
            return await _issue_token_pair(redis, user)


# ===================== OTURUM ACIKKEN YONTEM YONETIMI ====================== #
#
# Brief: "kullanicinin sonradan yontem ekleyip cikarabilmesi".
#
# BURADA SMS ARANMAZ ve bu bilinclidir: cagiran zaten gecerli bir oturum
# tasiyor, yani kimligini KANITLAMIS durumda. Bir kez daha SMS istemek
# guvenlik eklemez, yalnizca surtunme ekler.

_YONTEM_KAPISI = Depends(get_current_user)


@router.get("/baglantilarim", response_model=OauthBaglantiListesi)
async def baglantilarim(user: AppUser = _YONTEM_KAPISI) -> OauthBaglantiListesi:
    """HER ROL KENDI baglantilarini gorur — rol kapisi YOK, bilincli.

    Kayit kullanicinin KENDI hesabina aittir; bir rolun kendi giris
    yontemlerini gorememesi icin sebep yok. Baskasinin baglantilarini
    dondurecek bir parametre de yok.
    """
    async with SessionLocal() as session:
        async with session.begin():
            await set_tenant(session, user.tenant_id)
            satirlar = (
                (
                    await session.execute(
                        select(OauthKimlik)
                        .where(OauthKimlik.user_id == user.id)
                        .order_by(OauthKimlik.saglayici)
                    )
                )
                .scalars()
                .all()
            )
            return OauthBaglantiListesi(
                items=[
                    OauthBaglantiOut(
                        saglayici=s.saglayici,
                        eposta=s.eposta,
                        son_giris_at=s.son_giris_at,
                        created_at=s.created_at,
                    )
                    for s in satirlar
                ]
            )


@router.post("/baglantilarim", response_model=OauthBaglantiListesi)
async def baglanti_ekle(
    body: OauthSonucIstek,
    user: AppUser = _YONTEM_KAPISI,
    redis: aioredis.Redis = Depends(get_redis),
) -> OauthBaglantiListesi:
    """Oturum acikken yeni bir yontem ekler.

    AYNI TARAYICI AKISI KULLANILIR (`/basla` -> callback -> `sonuc_id`);
    ikinci bir akis yazmak, ayni isi iki kez yapmak olurdu. Fark, sonucun
    burada TUKETILMESI: `POST /sonuc` cagrilmaz.
    """
    ham = await redis.getdel(f"oauth:sonuc:{body.sonuc_id}")
    if not ham:
        raise _OTURUM_GECERSIZ
    veri = json.loads(ham)

    async with SessionLocal() as session:
        async with session.begin():
            await set_tenant(session, user.tenant_id)
            db_user = (
                await session.execute(select(AppUser).where(AppUser.id == user.id))
            ).scalar_one()
            await _kimligi_bagla(
                session,
                user=db_user,
                saglayici=veri["saglayici"],
                subject=veri["subject"],
                eposta=veri.get("eposta"),
            )
    return await baglantilarim(user)


@router.delete("/baglantilarim/{saglayici}", status_code=204)
async def baglanti_sil(saglayici: str, user: AppUser = _YONTEM_KAPISI) -> Response:
    """Yontemi kaldirir — SON GIRIS YOLUNU kaldirmaya IZIN VERMEZ.

    Kullanicinin elinde en az bir yol kalmali; yoksa kendi hesabina bir
    daha giremez ve kurtarma yolu yalniz yoneticiden gecer. Kabul edilen
    yollar: parola, BASKA bir sosyal kimlik, ya da telefon (SMS ile giris
    P149'dan beri tek basina oturum aciyor).
    """
    async with SessionLocal() as session:
        async with session.begin():
            await set_tenant(session, user.tenant_id)
            satirlar = (
                (
                    await session.execute(
                        select(OauthKimlik).where(OauthKimlik.user_id == user.id)
                    )
                )
                .scalars()
                .all()
            )
            hedef = next((s for s in satirlar if s.saglayici == saglayici), None)
            if hedef is None:
                raise _BAGLANTI_YOK

            db_user = (
                await session.execute(select(AppUser).where(AppUser.id == user.id))
            ).scalar_one()
            kalan_sosyal = [s for s in satirlar if s.id != hedef.id]
            if not (db_user.password_set or db_user.telefon or kalan_sosyal):
                raise _SON_YONTEM

            await session.delete(hedef)

    return Response(status_code=204)
