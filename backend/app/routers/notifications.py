"""GET /notifications + PATCH /notifications/{id} — /contracts/openapi.yaml.

RBAC (auth.md §4): admin + security. tenant token'dan; RLS izole.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Header, Query
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..errors import APIError
from ..deps import get_tenant_db, require_role
from ..hata_metinleri import istek_dili
from ..models import AppUser, Notification
from ..push_metinleri import push_basligi, push_govdesi
from ..schemas import (
    NotificationListResponse,
    NotificationOut,
    NotificationTopluOkundu,
    NotificationTopluSil,
    NotificationTopluSonuc,
    NotificationUpdate,
)

router = APIRouter(prefix="/notifications", tags=["notifications"])

# (P35) Amir P34 alarmlarinin MUHATABIDIR: gormezse turu devralamaz.
# (P147) `resident` EKLENDI — ama AYNI SATIRLARI GORMEZ, bkz. `_kapsam`.
_VIEWER = require_role(
    "admin", "yonetici", "security", "guvenlik_amiri", "resident"
)

# Yonetim alarmlarini goren roller. Sakin BURADA YOK.
_YONETIM_GOZU = ("admin", "yonetici", "security", "guvenlik_amiri")


def _kapsam(user: AppUser):
    """(P147) KIM HANGI SATIRI GORUR — tek yerde.

    Iki ayri bildirim TURU ayni tabloda duruyor ve karistirilmamalari
    gerekiyor:
      * `user_id IS NULL` -> tesise ait YONETIM alarmi (kacirilan tur,
        eksik checkpoint...). Sakin bunlari gormemeli: baska dairelerin
        ve tesisin isleyisine dair bilgi tasirlar.
      * `user_id = <kisi>` -> o kisinin KENDI olayi (kargosu, talebi).
        Yonetim bunlari gormemeli: kisisel bildirim akisidir.

    Kural cikarimla degil ACIKCA yazili; yeni bir rol eklenirse
    `_YONETIM_GOZU`ne girmedikce KENDI satirlarini gorur.
    """
    if user.role in _YONETIM_GOZU:
        return Notification.user_id.is_(None)
    return Notification.user_id == user.id


#: (P181 Bölüm 6.5) YUMUŞAK silinen satır listede/işlemde YOK sayılır.
def _canli():
    return Notification.silindi_at.is_(None)


def _out(row: Notification, dil: str) -> NotificationOut:
    """Kayit -> yanit; metin ISTEGIN dilinde uretilir.

    Kimlik yoksa (tur 16 oncesi satir) kayittaki `mesaj` aynen doner —
    geri uyumluluk; o metin donmus Turkce'dir ve cevrilemez.

    (P192 §4.2) `mesaj_veri.metin` DOLUYSA O KULLANILIR ve CEVRILMEZ:
    yoneticinin kendi yazdigi hatirlatma cumlesidir ve push'ta da aynen
    gonderilmistir. Ikisinin ayrismasi, sakinin telefonunda bir cumle,
    uygulamada baska bir cumle gormesi olurdu.
    """
    out = NotificationOut.model_validate(row)
    veri = row.mesaj_veri or {}
    ozel = veri.get("metin") if isinstance(veri, dict) else None
    if ozel:
        out.mesaj = str(ozel)
    elif row.mesaj_kimlik:
        out.mesaj = push_govdesi(row.mesaj_kimlik, dil, veri)
    return out


#: (P220 §3) ARAMADA TARANACAK EN COK SATIR.
#:
#: Arama SQL'de YAPILAMIYOR — gerekce `_arama_eslesir` basliginda.
#: Metin uretmek satir basina bir sozluk aramasi + `format`; ucuz ama
#: SINIRSIZ degil. Tavan olmadan, on bin bildirimi olan bir tesiste tek
#: arama istegi butun listeyi belleğe alirdi.
#:
#: Tavan asilirsa yanit BUNU SOYLUYOR (`meta.arama_tarandi`,
#: `meta.arama_tavani_asildi`) — sessizce eksik sonuc dondurmek, "aradim
#: bulamadim, demek ki yok" sonucuna goturur.
ARAMA_TAVANI = 1000

#: Arama icin en az bu kadar karakter. Tek harf, tavan kadar satirin
#: neredeyse tamamiyla eslesir ve arama bir ise yaramaz.
ARAMA_ASGARI = 2


def _kucult(metin: str) -> str:
    """Turkce-guvenli kucultme.

    `str.lower()` Turkce'de bozar: `'I'.lower()` -> `'i'` (nokta kaybolur),
    `'İ'.lower()` -> `'i'` + U+0307. `casefold()` bu ikisini de kararli
    ele aliyor ve depoda `raporlar.py` ayni tercihi yapmis.
    """
    return (metin or "").casefold()


def _arama_eslesir(out: NotificationOut, baslik: str, aranan: str) -> bool:
    """Bir bildirim aramayla esletiyor mu?

    ==================================================================
    ARAMA NEYI KAPSIYOR — VE NEDEN SQL'DE YAPILAMIYOR
    ==================================================================
    Kapsam UCU DE: kullanicinin GORDUGU her metin.
      * `baslik` — `push_basligi(mesaj_kimlik, dil)`, istegin dilinde
                   URETILMIS bildirim basligi,
      * `mesaj`  — govde, yine istegin dilinde uretilmis,
      * `tip`    — ham kimlik (`gorev_atandi`). Kullanici bunu ekranda
                   gormuyor ama destek yazismasinda gecebiliyor; dar bir
                   kapsam icin disarida birakmak, "tipe gore bulayim"
                   diyen yoneticiyi bos dondururdu.

    SQL'DE YAPILAMAZ: bildirim metni KAYITTA DURMUYOR. Satir
    `mesaj_kimlik` + `mesaj_veri` tasiyor ve cumle OKUMA ANINDA, istegin
    dilinde kuruluyor (tur 16 karari). `WHERE mesaj ILIKE ...` yalniz
    ESKI (tur 16 oncesi) satirlari bulurdu — yani kullanicinin gordugu
    metinlerin neredeyse hicbirini.

    Istemcide filtrelemek de yanlis olurdu: yalniz ACIK SAYFAYI suzer.
    "kargo" arayan kullanici 3. sayfadaki kaydi bulamaz ve "yok" sanir.

    Bu yuzden: kapsam icindeki satirlar (tavana kadar) URETILIR, sonra
    uretilen metin uzerinde filtrelenir. Kullanici NE GORUYORSA onda
    arama yapiyor.
    """
    return (
        aranan in _kucult(out.mesaj)
        or aranan in _kucult(baslik)
        or aranan in _kucult(out.tip)
    )


@router.get("", response_model=NotificationListResponse)
async def list_notifications(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    okundu: bool | None = Query(None),
    q: str | None = Query(
        None, description="Metin aramasi (govde + tip). En az 2 karakter."
    ),
    accept_language: str | None = Header(None, alias="Accept-Language"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_VIEWER),
) -> NotificationListResponse:
    where = [_kapsam(user), _canli()]
    if okundu is not None:
        where.append(Notification.okundu == okundu)

    dil = istek_dili(accept_language)
    aranan = _kucult((q or "").strip())

    if len(aranan) < ARAMA_ASGARI:
        # ARAMASIZ YOL DEGISMEDI: sayfalama SQL'de kaliyor ve buyuk
        # listelerde tek satir bile fazladan uretilmiyor.
        total = (
            await db.execute(
                select(func.count()).select_from(Notification).where(*where)
            )
        ).scalar_one()
        rows = (
            await db.execute(
                select(Notification)
                .where(*where)
                .order_by(Notification.created_at.desc(), Notification.id.desc())
                .limit(limit)
                .offset(offset)
            )
        ).scalars().all()
        return NotificationListResponse(
            meta={"limit": limit, "offset": offset, "total": total},
            items=[_out(r, dil) for r in rows],
        )

    # ---------------------------- ARAMALI YOL ---------------------------- #
    ham = (
        await db.execute(
            select(Notification)
            .where(*where)
            .order_by(Notification.created_at.desc(), Notification.id.desc())
            .limit(ARAMA_TAVANI)
        )
    ).scalars().all()
    eslesenler = [
        out
        for out in (_out(r, dil) for r in ham)
        if _arama_eslesir(
            out,
            push_basligi(out.mesaj_kimlik, dil) if out.mesaj_kimlik else "",
            aranan,
        )
    ]
    return NotificationListResponse(
        meta={
            "limit": limit,
            "offset": offset,
            # `total` ESLESEN SAYISI: sayfalama onun uzerinden yurur.
            "total": len(eslesenler),
            # TARAMA SEFFAF: tavan asildiysa kullanici "hepsi bu kadar"
            # sanmasin.
            "arama_tarandi": len(ham),
            "arama_tavani_asildi": len(ham) >= ARAMA_TAVANI,
        },
        items=eslesenler[offset : offset + limit],
    )


@router.patch("/{notification_id}", response_model=NotificationOut)
async def update_notification(
    notification_id: uuid.UUID,
    body: NotificationUpdate,
    accept_language: str | None = Header(None, alias="Accept-Language"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_VIEWER),
) -> NotificationOut:
    # (P147) OKUMA KAPSAMI YAZMADA DA GECERLI. Once kapsamsiz
    # `get_or_404` vardi: sakin BASKASININ bildirimini — hatta bir yonetim
    # alarmini — okundu isaretleyebilirdi. Ayni `_kapsam` suzgeci
    # uygulaniyor; kapsam disi kayit icin 404 (varligi da sizmaz).
    obj = (
        await db.execute(
            select(Notification).where(
                Notification.id == notification_id, _kapsam(user), _canli()
            )
        )
    ).scalar_one_or_none()
    if obj is None:
        raise APIError(404, "not_found", "kayit_bulunamadi")
    obj.okundu = body.okundu
    await db.flush()
    await db.refresh(obj)
    return _out(obj, istek_dili(accept_language))


# --------------------------------------------------------------------------- #
# (P181 Bölüm 6.5) TOPLU İŞLEMLER — kapsam `_kapsam` ile zorlanır (başkasının
# ya da yönetim alarmını sakin işleyemez); yumuşak silinen satır atlanır.
# --------------------------------------------------------------------------- #
@router.post("/toplu-okundu", response_model=NotificationTopluSonuc)
async def toplu_okundu(
    body: NotificationTopluOkundu,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_VIEWER),
) -> NotificationTopluSonuc:
    """Seçili bildirimleri okundu/okunmadı işaretle (yalnız kendi kapsamı)."""
    res = await db.execute(
        update(Notification)
        .where(Notification.id.in_(body.ids), _kapsam(user), _canli())
        .values(okundu=body.okundu)
    )
    return NotificationTopluSonuc(etkilenen=res.rowcount or 0)


@router.post("/tumunu-okundu", response_model=NotificationTopluSonuc)
async def tumunu_okundu(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_VIEWER),
) -> NotificationTopluSonuc:
    """Kapsamdaki TÜM okunmamışları okundu işaretle."""
    res = await db.execute(
        update(Notification)
        .where(_kapsam(user), _canli(), Notification.okundu.is_(False))
        .values(okundu=True)
    )
    return NotificationTopluSonuc(etkilenen=res.rowcount or 0)


@router.post("/toplu-sil", response_model=NotificationTopluSonuc)
async def toplu_sil(
    body: NotificationTopluSil,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_VIEWER),
) -> NotificationTopluSonuc:
    """Seçili bildirimleri YUMUŞAK sil (silindi_at=now) + denetim kaydı."""
    res = await db.execute(
        update(Notification)
        .where(Notification.id.in_(body.ids), _kapsam(user), _canli())
        .values(silindi_at=func.now())
    )
    etkilenen = res.rowcount or 0
    if etkilenen:
        # "Bu bildirim neden kayboldu" sorusunun kanıtı — adet + aktör yeter.
        await audit_user(
            db, user, Action.NOTIFICATION_DELETE,
            resource_type="notification", meta={"adet": etkilenen},
        )
    return NotificationTopluSonuc(etkilenen=etkilenen)
