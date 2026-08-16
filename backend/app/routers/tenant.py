"""Tenant ayarlari — GET/PATCH /tenant/settings + POST /tenant/setup.

RLS sayesinde yalnizca token'daki tenant'in satiri gorunur (id = current_tenant).

RBAC:
  - okuma: TUM roller (herkes kendi tesisinin adini gorur — ana ekran basligi)
  - guncelleme: admin (ad + timezone + yonetim_email + konum) /
    yonetici (ad + konum_ad/konum_lat/konum_lon)
  - ilk-giris adlandirma (setup): YALNIZ BIRINCIL yonetici

`slug` ve tenant `id` bu uclarin HICBIRINDE degismez (yalniz `ad` yazilir);
login/slug akislari etkilenmez.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Tenant
from ..schemas import TenantSettings, TenantSettingsUpdate, TenantSetupRequest

router = APIRouter(prefix="/tenant", tags=["tenant"])

_READER = require_role(
    "admin", "yonetici", "security", "tesis_gorevlisi", "resident"
)
_YONETICI = require_role("yonetici")
_ADMIN_VEYA_YONETICI = require_role("admin", "yonetici")

# Yonetici tesis adini, hava durumu konumunu VE otopark kapasitesini
# degistirebilir (hepsi tesis isletme verisi); geri kalan yapilandirma
# (timezone, yonetim_email) admin'de kalir (yetki yukseltme yok).
#
# ANPR ayarlari da yoneticide: esik ve otomatik-cikis SAHA kararidir
# (kameranin nerede durdugunu, yanlis okumanin ne siklikta oldugunu site
# bilir) — yetki yukseltmesi degildir, isletme ayaridir.
_YONETICI_YAZABILIR = {
    "ad", "konum_ad", "konum_lat", "konum_lon", "otopark_kapasite",
    "anpr_guven_esigi", "anpr_otomatik_cikis",
    # (P34) Tur alarmi ve baslangic fotografi SAHA ISLETMESIDIR: turu
    # planlayan yonetici toleransi da ayarlayabilmeli. Platform
    # operatorune (admin) birakmak, her esik degisikligini destek
    # talebine cevirirdi.
    "tur_gecikme_toleransi_dk", "tur_alarm_tekrar_sayisi",
    "tur_baslangic_foto_zorunlu",
    # (P37) Gurultu caydiricisi SITE YONETIMININ isidir: esigi ve anons
    # metnini komsuluk iliskisini bilen kisi ayarlar.
    "gurultu_esigi", "gurultu_uyari_metni", "gurultu_integration_id",
    # (P160) Okutma mesafe esigi SAHA ISLETMESIDIR: noktalari yerlestiren
    # ve site duzenini bilen kisi ayarlamali.
    "okutma_mesafe_esigi_m",
    # (P165) Rezervasyon gecmisi saklama penceresi SITE ISLETMESIDIR:
    # ortak alan kullanimini yoneten kisi ayarlamali.
    "rezervasyon_gecmis_ay",
}


def _to_settings(t: Tenant) -> TenantSettings:
    return TenantSettings(
        tenant_id=t.id, ad=t.ad, slug=t.slug, timezone=t.timezone,
        kurulum_tamamlandi=t.kurulum_tamamlandi,
        yonetim_email=t.yonetim_email,
        konum_ad=t.konum_ad,
        konum_lat=float(t.konum_lat),
        konum_lon=float(t.konum_lon),
        otopark_kapasite=t.otopark_kapasite,
        anpr_guven_esigi=float(t.anpr_guven_esigi),
        anpr_otomatik_cikis=t.anpr_otomatik_cikis,
        # (P115) Istemci "simule okutma" dugmesini bu bayrakla cizer.
        demo_mod=t.demo_mod,
        tur_gecikme_toleransi_dk=t.tur_gecikme_toleransi_dk,
        tur_alarm_tekrar_sayisi=t.tur_alarm_tekrar_sayisi,
        tur_baslangic_foto_zorunlu=t.tur_baslangic_foto_zorunlu,
        guvenlik_modu=t.guvenlik_modu,
        gurultu_esigi=t.gurultu_esigi,
        okutma_mesafe_esigi_m=t.okutma_mesafe_esigi_m,
        # (P165) BU SATIR ILK YAZIMDA UNUTULMUSTU ve kusur SESSIZDI: PATCH
        # 200 donuyor, deger DB'ye yaziliyor, ama yanit alani tasimadigi
        # icin sema varsayilani (12) geri geliyordu. Ekran "kaydedildi"
        # der, kullanici eski degeri gorurdu. Test yakaladi
        # (`test_saklama_penceresi_SINIR_KOSULLARI`).
        rezervasyon_gecmis_ay=t.rezervasyon_gecmis_ay,
        gurultu_uyari_metni=t.gurultu_uyari_metni,
        gurultu_integration_id=t.gurultu_integration_id,
    )


async def _current_tenant(db: AsyncSession) -> Tenant:
    # RLS: yalnizca current tenant'in satiri gorunur.
    t = (await db.execute(select(Tenant))).scalar_one_or_none()
    if t is None:
        raise APIError(404, "not_found", "tenant_bulunamadi")
    return t


@router.get("/settings", response_model=TenantSettings)
async def get_settings(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> TenantSettings:
    return _to_settings(await _current_tenant(db))


@router.patch("/settings", response_model=TenantSettings)
async def update_settings(
    body: TenantSettingsUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN_VEYA_YONETICI),
) -> TenantSettings:
    """admin: ad + timezone + yonetim_email + konum + otopark_kapasite.
    yonetici: ad + konum (hava durumu icin tesis konumunu belirler) +
    otopark_kapasite (G4 — doluluk orani bundan hesaplanir); baska alan
    gonderirse 403. slug'a ASLA yazilmaz."""
    data = body.model_dump(exclude_unset=True)
    if user.role == "yonetici" and not set(data) <= _YONETICI_YAZABILIR:
        raise APIError(403, "forbidden", "yonetici_sinirli_alan_degistirir")
    t = await _current_tenant(db)
    # (P35) MOD DEGISIMI DENETLENIR: guvenlik sahipligini devreden bir
    # ayarin izsiz degismesi, "turleri kim planliyordu" sorusunu sonradan
    # yanitlanamaz kilardi.
    if "guvenlik_modu" in data and data["guvenlik_modu"] != t.guvenlik_modu:
        await audit_user(
            db, user, Action.GUVENLIK_MODU, resource_type="tenant",
            resource_id=t.id,
            meta={"eski": t.guvenlik_modu, "yeni": data["guvenlik_modu"]},
        )
    for key, value in data.items():
        setattr(t, key, value)
    await db.flush()
    await db.refresh(t)
    return _to_settings(t)


@router.post("/setup", response_model=TenantSettings)
async def setup_tenant(
    body: TenantSetupRequest,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETICI),
) -> TenantSettings:
    """BIRINCIL yonetici ILK GIRISTE tesisini adlandirir (onboarding Model A):
    admin tenant + yonetici(ler) acmisti; birincil burada adi belirler ve
    kurulum_tamamlandi=true olur.

    Birincil olmayan yonetici 403 — kapi mobilde yalniz birincile gosterilir,
    uc de eslesmelidir (aksi halde istemci tarafi bir kisit olarak kalirdi).
    Zaten kuruluysa 409."""
    if not user.birincil:
        raise APIError(403, "forbidden", "tesis_adi_yalniz_birincil_yonetici")
    t = await _current_tenant(db)
    if t.kurulum_tamamlandi:
        raise APIError(409, "conflict", "tesis_zaten_kuruldu")
    t.ad = body.ad
    t.kurulum_tamamlandi = True
    await db.flush()
    await db.refresh(t)
    return _to_settings(t)
