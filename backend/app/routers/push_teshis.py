"""(P191 §2) PUSH TESHISI — "bildirim gelmedi" sorusunun tek adresi.

===========================================================================
NEDEN BU UC VAR
===========================================================================
Push altyapisi P181/P183'te yazildi ama UCTAN UCA HIC CALISTIGI GORULMEDI.
Bildirim gelmedigi zaman zincirin ALTI HALKASI vardi ve hicbiri disaridan
gorunmuyordu:

  a) uygulama FCM jetonu aliyor mu,
  b) jeton backend'e kaydediliyor mu (`user_device`),
  c) olay push GOREVINI tetikliyor mu,
  d) saglayici FCM'e gercekten istek atiyor mu, yaniti ne,
  e) `bildirim_mobil` tercihi acik mi,
  f) FCM servis hesabi yapilandirilmis mi.

Bu uc altisini TEK YANITTA gosterir. `GET /push/teshis` "durum tablosu",
`POST /push/test` ise KENDI cihazina gercek bir gonderim yapar — yonetici
"calisiyor mu?" sorusunu tahminle degil DENEYEREK cevaplar.

SIZINTI: uc yalniz yonetime acik (`admin`, `yonetici`) ve tenant-kapsamli.
Tam FCM jetonu HICBIR yanitta donmez (yalniz son 6 karakter).
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from .. import push
from ..audit import Action, audit_user
from ..deps import get_current_user, get_tenant_db, require_role
from ..models import AppUser, PushGonderim, UserDevice
from ..schemas import (
    PushDenemeOut,
    PushTemizlikResponse,
    PushTeshisResponse,
    PushTestResponse,
)

router = APIRouter(prefix="/push", tags=["push"])

_YONETIM = require_role("admin", "yonetici")


#: Tek cagrida dogrulanacak EN COK jeton (bkz. `cihaz_temizle`).
_TEMIZLIK_UST_SINIR = 200


async def _jetonlari_buda(db: AsyncSession, tokenlar: list[str]) -> int:
    """(P191-ek §1) FCM'in KALICI gecersiz dedigi jetonlari pasiflestirir.

    OLCULEN KUSUR: `dispatch_external` yolu budama yapiyordu ama `POST
    /push/test` YAPMIYORDU. Yonetici "kendime test gonder" dedikce 7/7
    `UNREGISTERED` aliyor, olu jetonlar tabloda KALIYOR ve her gonderimde
    yeniden deneniyordu. FCM bu cevabi verdiginde jeton bir daha
    KULLANILMAMALIDIR.

    SILME DEGIL PASIFLESTIRME: `/devices` kaydinin gecmisi korunur ve ayni
    jeton yeniden kaydedilirse upsert onu geri acar.
    """
    if not tokenlar:
        return 0
    sonuc = await db.execute(
        update(UserDevice)
        .where(UserDevice.fcm_token.in_(tokenlar), UserDevice.aktif.is_(True))
        .values(aktif=False, updated_at=func.now())
    )
    await db.flush()
    return int(sonuc.rowcount or 0)


@router.get("/teshis", response_model=PushTeshisResponse)
async def teshis(
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> PushTeshisResponse:
    """Push zincirinin durum tablosu + son denemeler."""
    saglayici = push.get_push_provider()
    # (f) Saglayici GERCEKTEN gonderebilir mi? `noop` icin soru anlamsizdir;
    # `fcm` icin kimlik + proje kimligi ARANIR (dosya okunur, ICERIK
    # loglanmaz/donmez).
    yapilandirildi = True
    if saglayici.name == "fcm":
        sa = push._load_service_account()
        proje = push.settings.fcm_project_id or (sa or {}).get("project_id")
        yapilandirildi = bool(sa and proje)

    # (b) Kayitli cihazlar.
    cihaz_aktif = (
        await db.execute(
            select(func.count()).select_from(UserDevice).where(UserDevice.aktif.is_(True))
        )
    ).scalar_one()
    cihaz_kullanici = (
        await db.execute(
            select(func.count(func.distinct(UserDevice.user_id))).where(
                UserDevice.aktif.is_(True)
            )
        )
    ).scalar_one()
    # (e) Tercihi KAPALI olanlar — bunlara hicbir push gitmez.
    bildirim_kapali = (
        await db.execute(
            select(func.count())
            .select_from(AppUser)
            .where(AppUser.is_active.is_(True), AppUser.bildirim_mobil.is_(False))
        )
    ).scalar_one()

    # (d) Son 24 saatin sonuc dagilimi — "ne kadari gitti".
    since = datetime.now(timezone.utc) - timedelta(hours=24)
    ozet_rows = (
        await db.execute(
            select(PushGonderim.durum, func.count())
            .where(PushGonderim.created_at >= since)
            .group_by(PushGonderim.durum)
        )
    ).all()

    satirlar = (
        await db.execute(
            select(PushGonderim, AppUser.ad, AppUser.role)
            .join(AppUser, AppUser.id == PushGonderim.user_id, isouter=True)
            # KARARLI SIRALAMA (depo kuralı): aynı milisaniyede yazılan iki
            # deneme sayfadan sayfaya yer değiştirmesin.
            .order_by(PushGonderim.created_at.desc(), PushGonderim.id)
            .limit(limit)
        )
    ).all()
    return PushTeshisResponse(
        saglayici=saglayici.name,
        yapilandirildi=yapilandirildi,
        cihaz_aktif=cihaz_aktif,
        cihaz_kullanici=cihaz_kullanici,
        bildirim_kapali=bildirim_kapali,
        ozet_24s={d: c for d, c in ozet_rows},
        denemeler=[
            PushDenemeOut(
                id=r[0].id,
                kimlik=r[0].kimlik,
                user_id=r[0].user_id,
                ad=r[1],
                rol=r[2],
                token_son6=r[0].token_son6,
                platform=r[0].platform,
                saglayici=r[0].saglayici,
                durum=r[0].durum,
                hata_kodu=r[0].hata_kodu,
                created_at=r[0].created_at,
            )
            for r in satirlar
        ],
    )


@router.post("/test", response_model=PushTestResponse)
async def test_gonder(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> PushTestResponse:
    """KENDI cihazlarina bir test bildirimi gonderir.

    BASKASINA GONDERILMEZ ve bu bilincli: "test" adi altinda tum tesise
    bildirim atabilen bir dugme, ilk yanlis tiklamada gercek bir olay
    gibi gorunen bir gurultu uretirdi.

    Yanit zincirin NEREDE koptugunu soyler: cihaz yoksa `cihaz=0`,
    saglayici noop ise `durum='noop'`, FCM reddettiyse hata kodu.
    """
    cihazlar = (
        await db.execute(
            select(UserDevice).where(
                UserDevice.user_id == user.id, UserDevice.aktif.is_(True)
            )
        )
    ).scalars().all()
    saglayici = push.get_push_provider()
    if not cihazlar:
        # (P191 §2) TESHIS SATIRI YAZILIR: "denedim, cihaz yoktu" da bir
        # sonuctur ve panelde gorunmelidir.
        await db.execute(
            text(
                "INSERT INTO push_gonderim (tenant_id, kimlik, user_id, saglayici, "
                "durum, hata_kodu) VALUES (:t, 'test', :u, :s, 'hedef_yok', "
                "CASE WHEN :bm THEN 'cihaz_yok' ELSE 'tercih_kapali' END)"
            ),
            {
                "t": str(user.tenant_id),
                "u": str(user.id),
                "s": saglayici.name,
                "bm": bool(user.bildirim_mobil),
            },
        )
        return PushTestResponse(
            saglayici=saglayici.name, cihaz=0, gonderildi=0, durum="hedef_yok"
        )

    from ..push_metinleri import dil_normalize, push_basligi, push_govdesi

    gonderildi = 0
    durumlar: list[str] = []
    hata: str | None = None
    gecersizler: list[str] = []
    for cihaz in cihazlar:
        dil = dil_normalize(cihaz.dil)
        sonuc = saglayici.send(
            [cihaz.fcm_token],
            title=push_basligi("test", dil),
            body=push_govdesi("test", dil, {}),
            data={"tip": "test"},
        )
        gonderildi += sonuc.sent
        durum, kod = (sonuc.token_sonuc or {}).get(
            cihaz.fcm_token, ("basarisiz", None)
        )
        durumlar.append(durum)
        hata = hata or kod
        # (P191-ek §1) FCM "bu jeton kayitli degil" dediyse jeton OLUDUR.
        gecersizler.extend(getattr(sonuc, "gecersiz", None) or [])
        await db.execute(
            text(
                "INSERT INTO push_gonderim (tenant_id, kimlik, user_id, token_son6, "
                "platform, saglayici, durum, hata_kodu) "
                "VALUES (:t, 'test', :u, :k, :p, :s, :d, :h)"
            ),
            {
                "t": str(user.tenant_id),
                "u": str(user.id),
                "k": cihaz.fcm_token[-6:],
                "p": cihaz.platform,
                "s": saglayici.name,
                "d": durum,
                "h": kod,
            },
        )
    budanan = await _jetonlari_buda(db, gecersizler)
    return PushTestResponse(
        saglayici=saglayici.name,
        cihaz=len(cihazlar),
        gonderildi=gonderildi,
        budanan=budanan,
        # Karisik sonucta EN KOTUSU raporlanir: "kismen gitti" bir basari degil.
        durum=next(
            (d for d in ("yapilandirilmadi", "gecersiz_token", "basarisiz", "noop") if d in durumlar),
            "gonderildi",
        ),
        hata_kodu=hata,
    )


@router.post("/cihaz-temizle", response_model=PushTemizlikResponse)
async def cihaz_temizle(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> PushTemizlikResponse:
    """(P191-ek §1) Gecersiz jetonlari TOPLU temizler — bildirim GONDERMEDEN.

    FCM `validate_only=true` ile her aktif jeton dogrulanir; `UNREGISTERED`
    / `INVALID_ARGUMENT` donenler pasiflestirilir.

    NEDEN GERCEK GONDERIM DEGIL: bu bir BAKIM aracidir. Her tiklamada
    tesisteki herkesin telefonunun calmasi kabul edilemez.

    SAGLAYICI DOGRULAYAMIYORSA (noop / kimlik yok) HICBIR SEY BUDANMAZ ve
    yanit bunu ACIKCA soyler: "bakamadim" ile "hepsi saglam" ayni sey
    degildir; ikisini karistirmak, olu jetonlari saglam ilan etmekti.
    """
    saglayici = push.get_push_provider()
    # (P191-ek §1) TEK COZUMDE UST SINIR: dogrulama jeton BASINA bir HTTP
    # istegidir. 500 cihazli bir tesiste tek tiklama 500 istek demekti ve
    # istek zaman asimina ugrardi — kullanicinin gordugu sey "dugme calismadi"
    # olurdu. En ESKI guncellenen jetonlar once bakilir (bayat olma olasiligi
    # en yuksek olanlar) ve tekrar tiklamak kaldigi yerden surdurur.
    cihazlar = (
        await db.execute(
            select(UserDevice)
            .where(UserDevice.aktif.is_(True))
            .order_by(UserDevice.updated_at.asc(), UserDevice.id)
            .limit(_TEMIZLIK_UST_SINIR)
        )
    ).scalars().all()
    if not cihazlar:
        return PushTemizlikResponse(
            saglayici=saglayici.name, denenen=0, budanan=0, desteklenmiyor=False
        )
    sonuc = saglayici.dogrula([c.fcm_token for c in cihazlar])
    if sonuc.desteklenmiyor:
        return PushTemizlikResponse(
            saglayici=saglayici.name,
            denenen=len(cihazlar),
            budanan=0,
            desteklenmiyor=True,
        )
    budanan = await _jetonlari_buda(db, list(sonuc.gecersiz))
    # Budama TESHISE de yazilir: "jetonlar neden azaldi" sorusu panelde
    # cevaplanabilmeli.
    for cihaz in cihazlar:
        if cihaz.fcm_token in set(sonuc.gecersiz):
            await db.execute(
                text(
                    "INSERT INTO push_gonderim (tenant_id, kimlik, user_id, "
                    "token_son6, platform, saglayici, durum, hata_kodu) "
                    "VALUES (:t, 'temizlik', :u, :k, :p, :s, 'gecersiz_token', "
                    "'UNREGISTERED')"
                ),
                {
                    "t": str(user.tenant_id),
                    "u": str(cihaz.user_id),
                    "k": cihaz.fcm_token[-6:],
                    "p": cihaz.platform,
                    "s": saglayici.name,
                },
            )
    await audit_user(
        db, user, Action.USER_UPDATE, resource_type="user_device",
        meta={"islem": "jeton_temizlik", "denenen": len(cihazlar), "budanan": budanan},
    )
    return PushTemizlikResponse(
        saglayici=saglayici.name,
        denenen=len(cihazlar),
        budanan=budanan,
        desteklenmiyor=False,
        belirsiz=sonuc.belirsiz,
    )


# `get_current_user` dogrudan kullanilmiyor; rol kapisi onu zaten cagiriyor.
_ = get_current_user
