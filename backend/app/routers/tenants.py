"""POST/GET /tenants — admin (platform) cross-tenant tesis olusturma/listeleme.

Onboarding Model A: admin bir tenant + N yonetici hesabini birlikte acar;
BIRINCIL yonetici (listedeki ilk) ILK GIRISTE POST /tenant/setup ile tesisi
adlandirir/onaylar. tenant RLS FORCE oldugundan cross-tenant islem owner-sahipli
SECURITY DEFINER fonksiyonlarla yapilir (create_tenant_with_yoneticis /
list_all_tenants); YALNIZ admin'e acilir (RBAC). tenant_id GIZLI kimliktir.
"""
from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Response
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from ..db import SessionLocal
from ..deps import require_role
from ..errors import APIError
from ..models import AppUser
from ..schemas import (
    KvkkMetinCreate,
    KvkkPlatformDurum,
    KvkkPlatformMetin,
    KvkkPlatformOnayOzeti,
    TenantAdminCreate,
    TenantAdminCreatedOut,
    TenantAdminDetail,
    TenantAdminListItem,
    TenantAdminListResponse,
    TenantAdminUpdate,
    TenantYoneticiAdd,
    TenantYoneticiAddedOut,
    TenantYoneticiListItem,
    TenantYoneticiListResponse,
    TenantYoneticiOut,
    TenantYoneticiResetOut,
    TenantYoneticiUpdate,
    YoneticiCreatedOut,
)
from ..security import (
    generate_temp_code,
    hash_password,
    normalize_phone,
    slugify_tenant,
)

router = APIRouter(prefix="/tenants", tags=["tenant"])

_ADMIN = require_role("admin")

# Yonetici tesisi adlandirana kadar gorunecek yer tutucu ad.
_PLACEHOLDER_AD = "(Kurulum bekliyor)"


@router.post("", response_model=TenantAdminCreatedOut, status_code=201)
async def create_tenant(
    body: TenantAdminCreate,
    _: AppUser = Depends(_ADMIN),
) -> TenantAdminCreatedOut:
    """Admin: yeni tenant + N yonetici acar (listedeki ILK yonetici BIRINCIL).

    Yonetici basina parola verilirse dogrudan belirlenir; verilmezse tek
    seferlik gecici kod uretilir (bir kez doner). `ad` verilmezse yer tutucu +
    rastgele slug; her durumda kurulum_tamamlandi=false (birincil ONAYLAR).
    Telefon GLOBAL benzersiz -> cakisma 409 (tenant olusmaz; tek transaction).
    """
    hazir: list[dict] = []
    for y in body.yoneticiler:
        try:
            phone = normalize_phone(y.phone)
        except ValueError:
            raise APIError(422, "validation_error", "telefon_gecersiz")
        if y.password is not None:
            hazir.append({
                "ad": y.ad, "telefon": phone,
                "password_hash": hash_password(y.password),
                "temp_code_hash": None, "password_set": True, "temp_code": None,
            })
        else:
            code = generate_temp_code()
            hazir.append({
                "ad": y.ad, "telefon": phone, "password_hash": None,
                "temp_code_hash": hash_password(code), "password_set": False,
                "temp_code": code,
            })

    # Sema tekrari ham girdiye bakar; normalize SONRASI da cakisabilir
    # (orn. "0532..." ve "+90532..." ayni numaraya coker).
    phones = [h["telefon"] for h in hazir]
    if len(phones) != len(set(phones)):
        raise APIError(422, "validation_error", "telefon_birden_fazla_yoneticide")

    ad = body.ad or _PLACEHOLDER_AD
    payload = [
        {k: h[k] for k in
         ("ad", "telefon", "password_hash", "temp_code_hash", "password_set")}
        for h in hazir
    ]

    async with SessionLocal() as session:
        async with session.begin():
            try:
                rows = (
                    await session.execute(
                        text(
                            "SELECT tenant_id, user_id, telefon, birincil FROM "
                            "public.create_tenant_with_yoneticis("
                            ":ad, :slug, :tz, :kur, :yem, CAST(:yon AS jsonb))"
                        ),
                        {
                            "ad": ad,
                            "slug": slugify_tenant(ad),
                            "tz": "Europe/Istanbul",
                            "kur": False,
                            "yem": body.yonetim_email,
                            "yon": json.dumps(payload),
                        },
                    )
                ).all()
            except IntegrityError:
                raise APIError(409, "conflict", "telefon_zaten_kayitli")

    # INSERT ... RETURNING satir SIRASINI garanti etmez -> TELEFONLA esle.
    # (Yanlis esleme = yanlis kisiye gecici kod.)
    by_phone = {r.telefon: r for r in rows}

    return TenantAdminCreatedOut(
        tenant_id=rows[0].tenant_id,
        yoneticiler=[
            YoneticiCreatedOut(
                user_id=by_phone[h["telefon"]].user_id,
                ad=h["ad"],
                birincil=by_phone[h["telefon"]].birincil,
                temp_code=h["temp_code"],
            )
            for h in hazir
        ],
    )


@router.get("", response_model=TenantAdminListResponse)
async def list_tenants(
    _: AppUser = Depends(_ADMIN),
) -> TenantAdminListResponse:
    """Admin: TUM tesisler (id + ad + kurulum durumu + tarih). Baska tenant
    verisi (kullanici vb.) donmez."""
    async with SessionLocal() as session:
        async with session.begin():
            rows = (
                await session.execute(
                    text(
                        "SELECT id, ad, kayit_kodu, kurulum_tamamlandi, "
                        "created_at FROM public.list_all_tenants()"
                    )
                )
            ).all()
    return TenantAdminListResponse(
        items=[
            TenantAdminListItem(
                id=r.id,
                ad=r.ad,
                kayit_kodu=r.kayit_kodu,
                kurulum_tamamlandi=r.kurulum_tamamlandi,
                created_at=r.created_at,
            )
            for r in rows
        ]
    )


_DETAIL_SQL = text(
    "SELECT tenant_id, tenant_ad, tenant_kayit_kodu, kurulum_tamamlandi, "
    "tenant_created_at, yonetici_id, yonetici_ad, telefon, is_active, "
    "password_set FROM public.tenant_detail(:tid)"
)


def _to_detail(row) -> TenantAdminDetail:
    yonetici = None
    if row.yonetici_id is not None:
        yonetici = TenantYoneticiOut(
            id=row.yonetici_id,
            ad=row.yonetici_ad,
            telefon=row.telefon,
            is_active=row.is_active,
            password_set=row.password_set,
        )
    return TenantAdminDetail(
        tenant_id=row.tenant_id,
        ad=row.tenant_ad,
        kayit_kodu=row.tenant_kayit_kodu,
        kurulum_tamamlandi=row.kurulum_tamamlandi,
        created_at=row.tenant_created_at,
        yonetici=yonetici,
    )


async def _detail_or_404(session, tenant_id: uuid.UUID):
    """tenant_detail satirini doner; tenant yoksa 404."""
    row = (await session.execute(_DETAIL_SQL, {"tid": tenant_id})).one_or_none()
    if row is None:
        raise APIError(404, "not_found", "tenant_bulunamadi")
    return row


@router.get("/{tenant_id}", response_model=TenantAdminDetail)
async def get_tenant(
    tenant_id: uuid.UUID,
    _: AppUser = Depends(_ADMIN),
) -> TenantAdminDetail:
    """Admin: tek tesis detayi + yoneticisi (ad, telefon, durum, kurulum)."""
    async with SessionLocal() as session:
        async with session.begin():
            row = await _detail_or_404(session, tenant_id)
    return _to_detail(row)


@router.patch("/{tenant_id}", response_model=TenantAdminDetail)
async def update_tenant(
    tenant_id: uuid.UUID,
    body: TenantAdminUpdate,
    _: AppUser = Depends(_ADMIN),
) -> TenantAdminDetail:
    """Admin: tesis ADINI degistirir (rename/duzeltme). kurulum_tamamlandi=true
    olur. Bilinmeyen tesis 404."""
    async with SessionLocal() as session:
        async with session.begin():
            updated = (
                await session.execute(
                    text("SELECT public.update_tenant_ad(:tid, :ad)"),
                    {"tid": tenant_id, "ad": body.ad},
                )
            ).scalar()
            if updated is None:
                raise APIError(404, "not_found", "tenant_bulunamadi")
            row = await _detail_or_404(session, tenant_id)
    return _to_detail(row)


@router.patch("/{tenant_id}/yonetici", response_model=TenantAdminDetail)
async def update_yonetici(
    tenant_id: uuid.UUID,
    body: TenantYoneticiUpdate,
    _: AppUser = Depends(_ADMIN),
) -> TenantAdminDetail:
    """Admin: tesis yoneticisinin ad/telefon/aktifligini gunceller (kismi).
    Telefon global benzersiz -> cakisma 409. Yonetici yoksa 404."""
    phone = None
    if body.phone is not None:
        try:
            phone = normalize_phone(body.phone)
        except ValueError:
            raise APIError(422, "validation_error", "telefon_gecersiz")

    async with SessionLocal() as session:
        async with session.begin():
            row = await _detail_or_404(session, tenant_id)
            if row.yonetici_id is None:
                raise APIError(404, "not_found", "tesiste_yonetici_yok")
            try:
                updated = (
                    await session.execute(
                        text(
                            "SELECT public.update_tenant_yonetici"
                            "(:tid, :uid, :ad, :tel, :act)"
                        ),
                        {
                            "tid": tenant_id,
                            "uid": row.yonetici_id,
                            "ad": body.ad,
                            "tel": phone,
                            "act": body.is_active,
                        },
                    )
                ).scalar()
            except IntegrityError:
                raise APIError(409, "conflict", "telefon_zaten_kayitli")
            if updated is None:
                raise APIError(404, "not_found", "tesiste_yonetici_yok")
            row = await _detail_or_404(session, tenant_id)
    return _to_detail(row)


@router.post(
    "/{tenant_id}/yonetici/reset-credential",
    response_model=TenantYoneticiResetOut,
)
async def reset_yonetici_credential(
    tenant_id: uuid.UUID,
    _: AppUser = Depends(_ADMIN),
) -> TenantYoneticiResetOut:
    """Admin: yonetici parolasini sifirlar + yeni TEK SEFERLIK gecici kod uretir
    (bir kez doner; admin yoneticiye iletir). Yonetici tekrar ilk-giris akisina
    duser. Yonetici yoksa 404."""
    temp_code = generate_temp_code()
    async with SessionLocal() as session:
        async with session.begin():
            row = await _detail_or_404(session, tenant_id)
            if row.yonetici_id is None:
                raise APIError(404, "not_found", "tesiste_yonetici_yok")
            updated = (
                await session.execute(
                    text(
                        "SELECT public.reset_tenant_yonetici_credential"
                        "(:tid, :uid, :tch)"
                    ),
                    {
                        "tid": tenant_id,
                        "uid": row.yonetici_id,
                        "tch": hash_password(temp_code),
                    },
                )
            ).scalar()
            if updated is None:
                raise APIError(404, "not_found", "tesiste_yonetici_yok")
    return TenantYoneticiResetOut(temp_code=temp_code)


# ------------------- (P154) tesis basina COKLU yonetici -------------------- #
#
# NEDEN AYRI BIR YOL (`/yoneticiler`, cogul): var olan `/{tid}/yonetici`
# (tekil) BIRINCIL yoneticiyi hedefler ve kimligi govdede TASIMAZ. Ayni yola
# bir `user_id` eklemek, eski cagiranlarin sessizce baska bir kaydi
# guncellemesine yol acabilirdi. Tekil yol OLDUGU GIBI kaldi.

_YONETICILER_SQL = text(
    "SELECT yonetici_id, yonetici_ad, telefon, is_active, password_set, "
    "birincil, created_at FROM public.tenant_yoneticiler(:tid)"
)


@router.get("/{tenant_id}/yoneticiler", response_model=TenantYoneticiListResponse)
async def list_yoneticiler(
    tenant_id: uuid.UUID,
    _: AppUser = Depends(_ADMIN),
) -> TenantYoneticiListResponse:
    """Admin: tesisin TUM yoneticileri (birincil once).

    Tesis yoksa 404 — bos liste donmek "tesis var ama yoneticisi yok" ile
    "boyle bir tesis yok"u ayirt edilemez kilardi.
    """
    async with SessionLocal() as session:
        async with session.begin():
            await _detail_or_404(session, tenant_id)
            rows = (await session.execute(_YONETICILER_SQL, {"tid": tenant_id})).all()
    return TenantYoneticiListResponse(
        items=[
            TenantYoneticiListItem(
                id=r.yonetici_id,
                ad=r.yonetici_ad,
                telefon=r.telefon,
                is_active=r.is_active,
                password_set=r.password_set,
                birincil=r.birincil,
                created_at=r.created_at,
            )
            for r in rows
        ]
    )


@router.post(
    "/{tenant_id}/yoneticiler",
    response_model=TenantYoneticiAddedOut,
    status_code=201,
)
async def add_yonetici(
    tenant_id: uuid.UUID,
    body: TenantYoneticiAdd,
    _: AppUser = Depends(_ADMIN),
) -> TenantYoneticiAddedOut:
    """Admin: var olan tesise yonetici ekler; TEK SEFERLIK gecici kod doner.

    Yeni yonetici BIRINCIL DEGILDIR (bkz. goc 0041). Telefon global benzersiz
    -> cakisma 409.
    """
    try:
        phone = normalize_phone(body.phone)
    except ValueError:
        raise APIError(422, "validation_error", "telefon_gecersiz")

    temp_code = generate_temp_code()
    async with SessionLocal() as session:
        async with session.begin():
            try:
                new_id = (
                    await session.execute(
                        text(
                            "SELECT public.add_tenant_yonetici"
                            "(:tid, :ad, :tel, :tch)"
                        ),
                        {
                            "tid": tenant_id,
                            "ad": body.ad,
                            "tel": phone,
                            "tch": hash_password(temp_code),
                        },
                    )
                ).scalar()
            except IntegrityError:
                raise APIError(409, "conflict", "telefon_zaten_kayitli")
            if new_id is None:
                raise APIError(404, "not_found", "tenant_bulunamadi")
    return TenantYoneticiAddedOut(user_id=new_id, ad=body.ad, temp_code=temp_code)


@router.delete("/{tenant_id}/yoneticiler/{user_id}", status_code=204)
async def remove_yonetici(
    tenant_id: uuid.UUID,
    user_id: uuid.UUID,
    _: AppUser = Depends(_ADMIN),
) -> Response:
    """Admin: yoneticiyi tesisten CIKARIR (sert silme).

    Uc ayri 409 uretir ve UCUNUN DE anlami farklidir — tek bir "silinemedi"
    mesaji kullaniciya ne yapacagini soylemezdi:
      * `son_yonetici`         -> once baska bir yonetici ekleyin
      * `birincil_yonetici`    -> once baskasini birincil yapin
      * `yonetici_kayitlari_var`-> silinemez; pasiflestirin (PATCH is_active)
    """
    async with SessionLocal() as session:
        async with session.begin():
            try:
                sonuc = (
                    await session.execute(
                        text("SELECT public.remove_tenant_yonetici(:tid, :uid)"),
                        {"tid": tenant_id, "uid": user_id},
                    )
                ).scalar()
            except IntegrityError:
                # ON DELETE RESTRICT tasiyan kayitlari var (ornegin actigi
                # talepler). Sert silme veriyi de goturecegi icin reddedilir.
                raise APIError(409, "conflict", "yonetici_kayitlari_var")
            if sonuc is None:
                raise APIError(404, "not_found", "yonetici_bulunamadi")
            if sonuc == "son_yonetici":
                raise APIError(409, "conflict", "son_yonetici_silinemez")
            if sonuc == "birincil":
                raise APIError(409, "conflict", "birincil_yonetici_silinemez")
    return Response(status_code=204)


# =========================================================================== #
# (P170 §2) KVKK VE YASAL METINLER — YONETIM PLATFORMDA
# =========================================================================== #
# Metinlerin YONETIMI (olusturma, surumleme) tesis yuzeyinden BURAYA tasindi;
# yetki yalniz platform yoneticisinde. Okuma ve onay tesis yuzeyinde KALDI
# (bkz. `routers/kvkk.py`) — bir kullanicinin kendisi hakkindaki metni
# okuyamamasi, aydinlatmanin kendisini imkansiz kilardi.
#
# VERI TENANT'A BAGLI KALIYOR: her tesisin veri sorumlusu kendisidir.
# Capraz-tenant erisim, panelin oteki uclarindaki desenle — dar,
# `SECURITY DEFINER` SQL islevleriyle (goc 0065).

#: Gecerli metin turleri. `routers/kvkk.py` ile AYNI KUME; ikinci bir liste
#: tutmamak icin oradan ithal ediliyor.
def _tur_dogrula(tur: str) -> str:
    from .kvkk import KVKK_TURLER

    if tur not in KVKK_TURLER:
        raise APIError(422, "validation_error", "kvkk_turu_gecersiz")
    return tur


@router.get("/{tenant_id}/kvkk", response_model=KvkkPlatformDurum)
async def kvkk_durumu(
    tenant_id: uuid.UUID,
    _: AppUser = Depends(_ADMIN),
) -> KvkkPlatformDurum:
    """Bir tesisin TUM metin surumleri + tur basina onay sayisi.

    TEK CAGRI: metinleri ve onay ozetini ayri uclara bolmek, panelin her
    tesis secisinde iki gidis-donus yapmasi olurdu ve ikisi birbirsiz
    anlamsiz (kac kisi onayladi sorusu HANGI SURUM bilinmeden okunmaz).
    """
    async with SessionLocal() as session:
        async with session.begin():
            metinler = (
                await session.execute(
                    text(
                        "SELECT id, tur, surum, baslik, govde, "
                        "yeniden_onay_gerekir, created_at "
                        "FROM public.kvkk_metin_listele(:tid)"
                    ),
                    {"tid": tenant_id},
                )
            ).all()
            onaylar = (
                await session.execute(
                    text(
                        "SELECT tur, surum, onaylayan "
                        "FROM public.kvkk_onay_ozeti(:tid)"
                    ),
                    {"tid": tenant_id},
                )
            ).all()

    # YURURLUKTE TURETILIR (saklanmaz): tur basina en yuksek surum. Kolon
    # olsaydi iki metin ayni anda yururlukte olabilir ya da hicbiri
    # olmayabilirdi.
    en_yuksek: dict[str, int] = {}
    for m in metinler:
        en_yuksek[m.tur] = max(en_yuksek.get(m.tur, 0), m.surum)
    return KvkkPlatformDurum(
        metinler=[
            KvkkPlatformMetin(
                id=m.id,
                tur=m.tur,
                surum=m.surum,
                baslik=m.baslik,
                govde=m.govde,
                yeniden_onay_gerekir=m.yeniden_onay_gerekir,
                yururlukte=m.surum == en_yuksek[m.tur],
                created_at=m.created_at,
            )
            for m in metinler
        ],
        onaylar=[
            KvkkPlatformOnayOzeti(tur=o.tur, surum=o.surum, onaylayan=o.onaylayan)
            for o in onaylar
        ],
    )


@router.post("/{tenant_id}/kvkk", response_model=KvkkPlatformMetin, status_code=201)
async def kvkk_yayinla(
    tenant_id: uuid.UUID,
    body: KvkkMetinCreate,
    _: AppUser = Depends(_ADMIN),
) -> KvkkPlatformMetin:
    """Bir tesise YENI SURUM yayinlar. Yerinde duzenleme UCU YOKTUR.

    Duzenlemeye izin verilseydi, dun onay vermis bir kullanicinin onayi
    bugun BASKA BIR METNE ait gorunurdu. Surum artmasi, metnin degistigini
    kullaniciya soylemenin tek durust yoludur.

    AYNI GOVDE YENIDEN YAYINLANMAZ (409): degismemis bir metin icin herkesi
    yeniden onaya zorlamak, onayi anlamsiz bir tikla dondururdu.
    """
    tur = _tur_dogrula(body.tur)
    async with SessionLocal() as session:
        async with session.begin():
            satir = (
                await session.execute(
                    text(
                        "SELECT sonuc, id, surum FROM public.kvkk_metin_yayinla"
                        "(:tid, :tur, :baslik, :govde, :yeniden)"
                    ),
                    {
                        "tid": tenant_id,
                        "tur": tur,
                        "baslik": body.baslik,
                        "govde": body.govde,
                        "yeniden": body.yeniden_onay_gerekir,
                    },
                )
            ).first()

    # SONUC KODU ISLEVDEN GELIR. Ilk yazimda sebebi ikinci bir sorguyla
    # ("tesis var mi") ariyorduk; O SORGU RLS'E TAKILIYORDU — platform
    # baglaminda `app.current_tenant_id` bos ve `tenant` politikasi onu
    # uuid'ye cevirmeye calisip 500 uretiyordu. Ayrimi `SECURITY DEFINER`
    # islevin kendisi yapiyor: hem dogru hem tek gidis-donus.
    if satir is None or satir.sonuc == "yok":
        raise APIError(404, "not_found", "tenant_bulunamadi")
    if satir.sonuc == "degismedi":
        raise APIError(409, "conflict", "kvkk_metni_degismedi")

    return KvkkPlatformMetin(
        id=satir.id,
        tur=tur,
        surum=satir.surum,
        baslik=body.baslik,
        govde=body.govde,
        yeniden_onay_gerekir=body.yeniden_onay_gerekir,
        # YENI SURUM HER ZAMAN YURURLUKTEDIR: islev en yuksek surumu
        # uretir, yani tanim geregi.
        yururlukte=True,
        created_at=datetime.now(timezone.utc),
    )


@router.delete("/{tenant_id}", status_code=204)
async def delete_tenant_endpoint(
    tenant_id: uuid.UUID,
    _: AppUser = Depends(_ADMIN),
) -> Response:
    """Admin: tesisi ve ON DELETE CASCADE ile TUM verisini (yonetici + duyuru +
    daire + sakin...) siler. GERI ALINAMAZ. Bilinmeyen tesis 404."""
    async with SessionLocal() as session:
        async with session.begin():
            deleted = (
                await session.execute(
                    text("SELECT public.delete_tenant(:tid)"),
                    {"tid": tenant_id},
                )
            ).scalar()
            if deleted is None:
                raise APIError(404, "not_found", "tenant_bulunamadi")
    return Response(status_code=204)
