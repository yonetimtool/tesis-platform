"""GET /notifications + PATCH /notifications/{id} — /contracts/openapi.yaml.

RBAC (auth.md §4): admin + security. tenant token'dan; RLS izole.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Header, Query
from sqlalchemy import and_, case, func, or_, select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..errors import APIError
from ..deps import get_tenant_db, require_role
from ..hata_metinleri import istek_dili
from ..models import AppUser, Notification, NotificationKisiDurumu
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
    "admin", "yonetici", "security", "guvenlik_amiri", "resident",
    # (P241 §2e) `tesis_gorevlisi` EKLENDI — OLCULEN KUSUR.
    #
    # Uc ona 403 doniyordu, yani kendisine ATANAN GOREVIN bildirimini
    # (P191 §2'de eklenen `gorev_atandi`) hicbir zaman goremiyordu:
    # satir yaziliyordu, push gidiyordu, ama in-app liste kapaliydi.
    # Push'u kaciran kisi olayi listede bulamiyordu.
    "tesis_gorevlisi",
)

# Yonetim alarmlarini goren roller. Sakin BURADA YOK.
_YONETIM_GOZU = ("admin", "yonetici", "security", "guvenlik_amiri")
#: Guvenlik rolleri: paylasilan satirlarin bir kismini gormez (asagida).
_GUVENLIK_GOZU = ("security", "guvenlik_amiri")
_GUVENLIK_DISI_TIPLER = ("bakim_yaklasti", "bakim_bugun", "bakim_gecikti")


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
        # (P241 §2e) KENDI SATIRI DA GORUNUR — OLCULEN KUSUR.
        #
        # Once yalniz `user_id IS NULL` donuyordu ve bunun bedeli sessizdi:
        # `security` ya da `guvenlik_amiri` bir GOREVE ATANDIGINDA
        # (`gorev_atandi`, P191 §2) satir yaziliyor ama LISTEDE HIC
        # GORUNMUYORDU. Olculdu: kendi bildirimi yazilmis bir guvenlik
        # gorevlisinin listesi BOS donuyordu.
        #
        # GIZLILIK BOZULMAZ: eklenen sey "KENDI satirim", "baskasinin
        # satiri" degil. `test_yonetim_KISISEL_akisi_gormez` (sakinin
        # akisi yonetime kapali) AYNEN gecerli — o satirin `user_id`si
        # baskasinin.
        ortak = Notification.user_id.is_(None)
        if user.role in _GUVENLIK_GOZU:
            # (E2E 2026-09) Tesis BAKIM alarmlari guvenlik ekibinin isi
            # degildir (asansor/jenerator periyodik bakimi): paylasilan
            # satirlardan disarida kalir. Guvenlige ait olanlar (kacirilan
            # tur, panik, gurultu eskalasyonu...) aynen gorunur.
            ortak = ortak & Notification.tip.not_in(_GUVENLIK_DISI_TIPLER)
        return or_(ortak, Notification.user_id == user.id)
    return Notification.user_id == user.id


# =========================================================================== #
# (E2E 2026-09, goc 0149) PAYLASILAN SATIRDA DURUM KISIYE AIT
# =========================================================================== #
# `user_id IS NULL` yonetim alarmlari herkesin ORTAK satiridir; okundu ve
# silindi `notification_kisi_durumu`nda KISI basina tutulur. Onceden bir
# gorevlinin okumasi/silmesi yoneticinin listesini de degistiriyordu.
_D = NotificationKisiDurumu


def _durum_kosulu(user: AppUser):
    return and_(_D.notification_id == Notification.id, _D.user_id == user.id)


def _etkin_okundu():
    """Kullanicinin GORDUGU okundu degeri (outer join `_D` gerektirir)."""
    return case(
        (Notification.user_id.is_(None), _D.okundu_at.is_not(None)),
        else_=Notification.okundu,
    )


#: (P181 Bölüm 6.5) YUMUŞAK silinen satır listede/işlemde YOK sayılır.
def _canli():
    """Satir hic silinmemis VE (paylasilansa) BU KISI icin silinmemis.

    `_D` outer join'i gerektirir.
    """
    return and_(
        Notification.silindi_at.is_(None),
        or_(Notification.user_id.is_not(None), _D.silindi_at.is_(None)),
    )


def _secim(user: AppUser, *ek):
    """Kapsam + kisiye ait durum join'i hazir `select(Notification, okundu)`."""
    return (
        select(Notification, _etkin_okundu().label("etkin_okundu"))
        .outerjoin(_D, _durum_kosulu(user))
        .where(_kapsam(user), _canli(), *ek)
    )


async def _durum_yaz(
    db: AsyncSession, user: AppUser, ids: list[uuid.UUID], *, okundu: bool | None = None,
    sil: bool = False,
) -> None:
    """Paylasilan satirlar icin KISININ durumunu yaz (upsert)."""
    if not ids:
        return
    degerler = {}
    if okundu is not None:
        degerler["okundu_at"] = func.now() if okundu else None
    if sil:
        degerler["silindi_at"] = func.now()
    stmt = pg_insert(_D).values([
        {"tenant_id": user.tenant_id, "notification_id": i, "user_id": user.id,
         **{k: (None if v is None else v) for k, v in degerler.items()}}
        for i in ids
    ])
    stmt = stmt.on_conflict_do_update(
        index_elements=[_D.notification_id, _D.user_id],
        set_={k: getattr(stmt.excluded, k) for k in degerler},
    )
    await db.execute(stmt)


async def _ayir(
    db: AsyncSession, user: AppUser, ids: list[uuid.UUID]
) -> tuple[list[uuid.UUID], list[uuid.UUID]]:
    """Kapsamdaki canli id'leri (kendi satirlarim, paylasilanlar) diye ayir."""
    satirlar = (
        await db.execute(
            select(Notification.id, Notification.user_id)
            .outerjoin(_D, _durum_kosulu(user))
            .where(Notification.id.in_(ids), _kapsam(user), _canli())
        )
    ).all()
    kendi = [i for i, uid in satirlar if uid is not None]
    ortak = [i for i, uid in satirlar if uid is None]
    return kendi, ortak


def _out(row: Notification, dil: str, okundu: bool | None = None) -> NotificationOut:
    """Kayit -> yanit; metin ISTEGIN dilinde uretilir.

    Kimlik yoksa (tur 16 oncesi satir) kayittaki `mesaj` aynen doner —
    geri uyumluluk; o metin donmus Turkce'dir ve cevrilemez.

    (P192 §4.2) `mesaj_veri.metin` DOLUYSA O KULLANILIR ve CEVRILMEZ:
    yoneticinin kendi yazdigi hatirlatma cumlesidir ve push'ta da aynen
    gonderilmistir. Ikisinin ayrismasi, sakinin telefonunda bir cumle,
    uygulamada baska bir cumle gormesi olurdu.
    """
    out = NotificationOut.model_validate(row)
    if okundu is not None:
        out.okundu = bool(okundu)
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
    ek = []
    if okundu is not None:
        ek.append(_etkin_okundu() == okundu)

    dil = istek_dili(accept_language)
    aranan = _kucult((q or "").strip())

    if len(aranan) < ARAMA_ASGARI:
        # ARAMASIZ YOL DEGISMEDI: sayfalama SQL'de kaliyor ve buyuk
        # listelerde tek satir bile fazladan uretilmiyor.
        total = (
            await db.execute(
                select(func.count())
                .select_from(Notification)
                .outerjoin(_D, _durum_kosulu(user))
                .where(_kapsam(user), _canli(), *ek)
            )
        ).scalar_one()
        rows = (
            await db.execute(
                _secim(user, *ek)
                .order_by(Notification.created_at.desc(), Notification.id.desc())
                .limit(limit)
                .offset(offset)
            )
        ).all()
        return NotificationListResponse(
            meta={"limit": limit, "offset": offset, "total": total},
            items=[_out(r, dil, ok) for r, ok in rows],
        )

    # ---------------------------- ARAMALI YOL ---------------------------- #
    ham = (
        await db.execute(
            _secim(user, *ek)
            .order_by(Notification.created_at.desc(), Notification.id.desc())
            .limit(ARAMA_TAVANI)
        )
    ).all()
    eslesenler = [
        out
        for out in (_out(r, dil, ok) for r, ok in ham)
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
            select(Notification)
            .outerjoin(_D, _durum_kosulu(user))
            .where(Notification.id == notification_id, _kapsam(user), _canli())
        )
    ).scalar_one_or_none()
    if obj is None:
        raise APIError(404, "not_found", "kayit_bulunamadi")
    if obj.user_id is None:
        # PAYLASILAN satir DEGISMEZ; yalniz bu kisinin durumu.
        await _durum_yaz(db, user, [obj.id], okundu=body.okundu)
    else:
        obj.okundu = body.okundu
    await db.flush()
    await db.refresh(obj)
    return _out(obj, istek_dili(accept_language), body.okundu)


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
    kendi, ortak = await _ayir(db, user, list(body.ids))
    if kendi:
        await db.execute(
            update(Notification)
            .where(Notification.id.in_(kendi))
            .values(okundu=body.okundu)
        )
    await _durum_yaz(db, user, ortak, okundu=body.okundu)
    return NotificationTopluSonuc(etkilenen=len(kendi) + len(ortak))


@router.post("/tumunu-okundu", response_model=NotificationTopluSonuc)
async def tumunu_okundu(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_VIEWER),
) -> NotificationTopluSonuc:
    """Kapsamdaki TÜM okunmamışları okundu işaretle."""
    okunmamis = (
        await db.execute(
            select(Notification.id, Notification.user_id)
            .outerjoin(_D, _durum_kosulu(user))
            .where(_kapsam(user), _canli(), _etkin_okundu().is_(False))
        )
    ).all()
    kendi = [i for i, uid in okunmamis if uid is not None]
    ortak = [i for i, uid in okunmamis if uid is None]
    if kendi:
        await db.execute(
            update(Notification).where(Notification.id.in_(kendi)).values(okundu=True)
        )
    await _durum_yaz(db, user, ortak, okundu=True)
    return NotificationTopluSonuc(etkilenen=len(okunmamis))


@router.post("/toplu-sil", response_model=NotificationTopluSonuc)
async def toplu_sil(
    body: NotificationTopluSil,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_VIEWER),
) -> NotificationTopluSonuc:
    """Seçili bildirimleri YUMUŞAK sil (silindi_at=now) + denetim kaydı."""
    kendi, ortak = await _ayir(db, user, list(body.ids))
    if kendi:
        await db.execute(
            update(Notification)
            .where(Notification.id.in_(kendi))
            .values(silindi_at=func.now())
        )
    await _durum_yaz(db, user, ortak, sil=True)
    etkilenen = len(kendi) + len(ortak)
    if etkilenen:
        # "Bu bildirim neden kayboldu" sorusunun kanıtı — adet + aktör yeter.
        await audit_user(
            db, user, Action.NOTIFICATION_DELETE,
            resource_type="notification", meta={"adet": etkilenen},
        )
    return NotificationTopluSonuc(etkilenen=etkilenen)
