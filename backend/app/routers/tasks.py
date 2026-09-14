"""Task CRUD + tamamlama (completion) — /contracts/openapi.yaml.

RBAC (auth.md §4): GET admin/yonetici/security/tesis_gorevlisi — saha rolleri
YALNIZ KENDINE atanan gorevleri okur (kati: havuz/grup gorunurlugu YOK);
Task yazma (POST/PATCH/DELETE) admin/yonetici — yonetici yalniz
security/tesis_gorevlisi'ne atar; completion gonderme (POST)
admin/security/tesis_gorevlisi — saha rolu yalniz KENDINE atanan gorevi
tamamlar (aksi 403/404). tenant token'dan; RLS izole.
Completion idempotency scan desenini yeniden kullanir (SAVEPOINT).
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Header, Query, Response
from fastapi.responses import JSONResponse
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import coord_eq, get_or_404, is_unique_violation, nfc_eq, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import (
    AppUser,
    Checkpoint,
    Complaint,
    Task,
    TaskCategory,
    TaskCompletion,
    Unit,
    UnitResident,
)
from ..audit import Action, audit_user
from ..schemas import (
    TaskCompletionCreate,
    TaskCompletionListResponse,
    TaskCompletionOut,
    TaskCreate,
    TaskListResponse,
    TaskOut,
    TaskTamamlamaOzet,
    TaskUpdate,
    TicketSummaryOut,
)
from ..storage import presign_get
from ..sakin_bildirimi import sakin_bildirimi_yaz
from ..scheduler.notify import dispatch_external
from ..ticketing import add_history, notify_opener

router = APIRouter(prefix="/tasks", tags=["tasks"])

_WRITER = require_role("admin", "yonetici")
_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi")
# (P229 §3) YONETICI DE TAMAMLAYABILIR.
#
# OLCULEN DURUM: `_COMPLETER` admin + saha rolleriydi; YONETICI yoktu.
# Yani tesisi yoneten kisi, personelin kapatamadigi (izinli, isten
# ayrilmis) bir gorevi KAPATAMIYORDU — gorev sonsuza kadar acik
# kaliyordu. Saha kisitlamasi ASAGIDA korunuyor: saha rolu yalniz
# KENDINE atanan gorevi tamamlar; yonetici/admin icin o kisit yok
# cunku onlarin isi zaten baskasinin isini denetlemek.
_COMPLETER = require_role("admin", "yonetici", "security", "tesis_gorevlisi")

# Tamamlamayi GERI ALABILENLER — saha rolleri YOK.
#
# NEDEN: geri acma bir kaniti siler. Sahadaki kisi kendi tamamlamasini
# silebilseydi, "yaptim" deyip sonra izini temizleyebilirdi.
_REOPENER = require_role("admin", "yonetici")

# yonetici gorevleri yalniz saha rollerine atayabilir (auth.md §4).
_YONETICI_ATANABILIR = {"security", "tesis_gorevlisi"}

# Saha rolleri: 'Gorevlerim' YALNIZ KENDINE atanan gorevleri OKUR (kati — havuz
# ve grup gorunurlugu YOK). Baskasina atanmis ya da atanmamis gorevler saha'ya
# gorunmez; yalniz yonetim gorur (ve atar). Tamamlama da kisiye baglidir.
_SAHA_ROLLERI = {"security", "tesis_gorevlisi"}


def _assignee_visibility(user: AppUser):
    """Saha kullanicisi icin gorunurluk kosulu: YALNIZ kendine atanan gorev.
    Havuz (atanmamis) + grup gorunurlugu YOK. Yonetim (admin/yonetici) kisitsiz
    (None doner)."""
    if user.role in _SAHA_ROLLERI:
        return Task.atanan_user_id == user.id
    return None


async def _visible_task_or_404(db: AsyncSession, task_id: uuid.UUID, user: AppUser) -> Task:
    """Task'i atanan-gorunurluk kurali altinda yukle; saha kullanicisi YALNIZ
    kendine atanan gorevi gorur (aksi 404 — varligi da sizdirilmaz)."""
    task = await get_or_404(db, Task, task_id)
    if user.role in _SAHA_ROLLERI and task.atanan_user_id != user.id:
        raise APIError(404, "not_found", "kayit_bulunamadi")
    return task


async def _tamamlama_ozeti_doldur(
    db: AsyncSession, tasks: list[Task], outs: list[TaskOut]
) -> None:
    """(P229 §3) Her goreve SON tamamlamasini ekler.

    =======================================================================
    NEDEN LISTE UCUNDA, AYRI BIR ISTEKTE DEGIL
    =======================================================================
    `GET /tasks/{id}/completions` zaten vardi ve HICBIR ISTEMCIDEN
    cagrilmiyordu. Listede durum gostermek icin istemcinin her satir icin
    ayri istek atmasi gerekirdi — elli gorevlik bir listede elli istek.
    Bu yuzden ozet, listeyi ureten sorgunun yaninda TEK sorguda gelir.

    =======================================================================
    N+1 YOK: TEK SORGU, DISTINCT ON
    =======================================================================
    Her gorev icin ayri "son tamamlama" sorgusu N+1 olurdu. Tek sorguda
    tum gorevlerin tamamlamalari cekilip Python'da en yenisi seciliyor;
    tamamlama sayisi gorev basina kucuk oldugu icin bu, `DISTINCT ON`
    ile ayni sonucu verir ve SQL lehcesine baglanmaz.
    """
    if not tasks:
        return
    ids = [t.id for t in tasks]
    satirlar = (
        await db.execute(
            select(TaskCompletion, AppUser.ad)
            .outerjoin(AppUser, AppUser.id == TaskCompletion.tamamlayan_user_id)
            .where(TaskCompletion.task_id.in_(ids))
            .order_by(
                TaskCompletion.tamamlanma_zamani.desc(), TaskCompletion.id.desc()
            )
        )
    ).all()
    son: dict[uuid.UUID, TaskTamamlamaOzet] = {}
    for c, ad in satirlar:
        # Sorgu ZAMANA GORE AZALAN: her gorev icin ILK gorulen en yenidir.
        if c.task_id in son:
            continue
        son[c.task_id] = TaskTamamlamaOzet(
            id=c.id,
            tamamlayan_user_id=c.tamamlayan_user_id,
            tamamlayan_ad=ad,
            tamamlanma_zamani=c.tamamlanma_zamani,
            foto_var=c.foto_key is not None,
            notlar=c.notlar,
        )
    for t, out in zip(tasks, outs):
        ozet = son.get(t.id)
        if ozet is not None:
            out.tamamlandi = True
            out.son_tamamlama = ozet


def _durum_hesapla(t: Task, out: TaskOut, simdi: datetime) -> None:
    """(P230 §4) DORT DURUM — SAKLANMAZ, TURETILIR.

    =======================================================================
    SIRA ONEMLI
    =======================================================================
    `tamamlandi` HER SEYDEN ONCE gelir: son tarihi gecmis AMA tamamlanmis
    bir gorevi "gecikti" gostermek, biten isi bitmemis gibi raporlamak
    olurdu. Gecikme yalniz ACIK gorevler icin anlamlidir.

    `gecikme_gun` SON TARIH YOKSA None — sifir DEGIL. Sifir "bugun son
    gun" demektir; "olcusu yok" ile karistirilamaz.
    """
    if out.tamamlandi:
        out.durum = "tamamlandi"
    elif t.son_tarih is not None and t.son_tarih < simdi:
        out.durum = "gecikti"
    elif t.baslama_zamani is not None:
        out.durum = "baslandi"
    else:
        out.durum = "atandi"
    if t.son_tarih is not None:
        out.gecikme_gun = (simdi - t.son_tarih).days


async def _adlari_doldur(db: AsyncSession, tasks: list[Task], outs: list[TaskOut]) -> None:
    """(P230 §4) ATAYAN ve ATANAN adlari — TEK sorguda.

    Id yeterli degil: saha rolu kullanici listesini GOREMIYOR (403), yani
    "bu isi bana kim verdi" sorusunu istemci kendi cozemezdi. P229'da
    `tamamlayan_ad` icin verilen kararin aynisi.
    """
    ids = {t.atanan_user_id for t in tasks if t.atanan_user_id} | {
        t.olusturan_user_id for t in tasks if t.olusturan_user_id
    }
    if not ids:
        return
    adlar = {
        i: ad
        for i, ad in (
            await db.execute(select(AppUser.id, AppUser.ad).where(AppUser.id.in_(ids)))
        ).all()
    }
    for t, out in zip(tasks, outs):
        out.atanan_ad = adlar.get(t.atanan_user_id)
        out.olusturan_ad = adlar.get(t.olusturan_user_id)


async def _serialize_tasks(db: AsyncSession, tasks: list[Task]) -> list[TaskOut]:
    """Task -> TaskOut; talepten gelen gorevlere kompakt talep ozeti (ticket)
    ekler. Toplu (batch) sorgu ile N+1 yok. RLS: tum sorgular tenant-kapsamli."""
    outs = [TaskOut.model_validate(t) for t in tasks]
    await _tamamlama_ozeti_doldur(db, tasks, outs)
    await _adlari_doldur(db, tasks, outs)
    # ZAMAN TEK YERDEN: her gorev icin ayri `now()` cagirmak, uzun bir
    # listede satirlarin FARKLI anlara gore degerlendirilmesi demekti.
    simdi = datetime.now(timezone.utc)
    for t, out in zip(tasks, outs):
        _durum_hesapla(t, out, simdi)
    ticket_ids = {t.ticket_id for t in tasks if t.ticket_id is not None}
    if not ticket_ids:
        return outs

    complaints = (
        await db.execute(select(Complaint).where(Complaint.id.in_(ticket_ids)))
    ).scalars().all()
    cmap = {c.id: c for c in complaints}

    # kategori adlari (NULL kategori -> None => istemci "Diğer" gosterir).
    kat_ids = {c.kategori_id for c in complaints if c.kategori_id is not None}
    katmap: dict[uuid.UUID, str] = {}
    if kat_ids:
        katmap = {
            i: ad
            for i, ad in (
                await db.execute(
                    select(TaskCategory.id, TaskCategory.ad).where(
                        TaskCategory.id.in_(kat_ids)
                    )
                )
            ).all()
        }

    # unit label = talebi ACANIN aktif dairesi (varsa). Ticketing anonim degil.
    acan_ids = {c.acan_user_id for c in complaints}
    unitmap: dict[uuid.UUID, str] = {}
    if acan_ids:
        for uid, no in (
            await db.execute(
                select(UnitResident.user_id, Unit.no)
                .join(Unit, Unit.id == UnitResident.unit_id)
                .where(UnitResident.user_id.in_(acan_ids), UnitResident.bitis.is_(None))
            )
        ).all():
            unitmap.setdefault(uid, no)

    for out, task in zip(outs, tasks):
        c = cmap.get(task.ticket_id) if task.ticket_id else None
        if c is not None:
            out.ticket = TicketSummaryOut(
                id=c.id,
                kategori_ad=katmap.get(c.kategori_id) if c.kategori_id else None,
                baslik=c.baslik,
                durum=c.durum,
                unit_label=unitmap.get(c.acan_user_id),
            )
    return outs


async def _ensure_user_in_tenant(
    db: AsyncSession, user_id: uuid.UUID | None, actor: AppUser
) -> None:
    if user_id is None:
        return
    target_role = (
        await db.execute(select(AppUser.role).where(AppUser.id == user_id))
    ).scalar_one_or_none()
    if target_role is None:
        raise APIError(422, "invalid_reference", "atanan_user_bulunamadi")
    if actor.role == "yonetici" and target_role not in _YONETICI_ATANABILIR:
        raise APIError(422, "invalid_reference", "gorev_atama_rol_kisiti")


async def _ensure_kategori_in_tenant(db: AsyncSession, kategori_id: uuid.UUID | None) -> None:
    """Kategori ayni tenant'ta (RLS) ve AKTIF olmali; pasif kategoriye yeni
    gorev yazilamaz (soft-delete sozlesmesi, A6)."""
    if kategori_id is None:
        return
    aktif = (
        await db.execute(select(TaskCategory.aktif).where(TaskCategory.id == kategori_id))
    ).scalar_one_or_none()
    if aktif is None:
        raise APIError(422, "invalid_reference", "butce_kategori_bulunamadi")
    if not aktif:
        raise APIError(422, "invalid_reference", "gorev_pasif_kategoriye_yazilamaz")


async def _ensure_checkpoint_in_tenant(db: AsyncSession, checkpoint_id: uuid.UUID | None) -> None:
    if checkpoint_id is None:
        return
    found = (
        await db.execute(select(Checkpoint.id).where(Checkpoint.id == checkpoint_id))
    ).scalar_one_or_none()
    if found is None:
        raise APIError(422, "invalid_reference", "checkpoint_bulunamadi")


# -------------------------------- CRUD ------------------------------------- #
@router.get("", response_model=TaskListResponse)
async def list_tasks(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    kategori_id: str | None = Query(
        None, description="kategori UUID veya 'diger' (kategorisiz/Diğer)"
    ),
    aktif: bool | None = Query(None),
    atanan_user_id: str | None = Query(
        None, description="'me' (token kullanicisi) veya user UUID — atanan filtresi (mobil §11)"
    ),
    durum: str | None = Query(
        None,
        description="(P230 §4) atandi | baslandi | tamamlandi | gecikti",
    ),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> TaskListResponse:
    where = []
    # Saha rolu: baskasina atanmis gorevler listede HIC gorunmez; sonraki
    # atanan_user_id filtresi bu kosulla KESISIR (bypass edilemez).
    visibility = _assignee_visibility(user)
    if visibility is not None:
        where.append(visibility)
    if kategori_id is not None:
        if kategori_id == "diger":
            where.append(Task.kategori_id.is_(None))
        else:
            try:
                where.append(Task.kategori_id == uuid.UUID(kategori_id))
            except ValueError:
                raise APIError(422, "validation_error", "kategori_id_bicimi")
    if aktif is not None:
        where.append(Task.aktif == aktif)
    if atanan_user_id is not None:
        if atanan_user_id == "me":
            target = user.id
        else:
            try:
                target = uuid.UUID(atanan_user_id)
            except ValueError:
                raise APIError(422, "validation_error", "atanan_user_id_bicimi")
        where.append(Task.atanan_user_id == target)

    # (P230 §4) DURUM SUZGECI — SUNUCUDA.
    #
    # Istemcide suzmek, sayfalamayi BOZARDI: sunucu 50 satir doner,
    # istemci 7'sini gosterir ve kullanici "toplam 300" yazan bir
    # sayfalayicda bos sayfalar gezerdi. Durum turetilmis oldugu icin
    # suzgec de ayni turetmeyi SQL'de tekrarlar.
    if durum is not None:
        simdi = datetime.now(timezone.utc)
        tamamlanmis = select(TaskCompletion.task_id).where(
            TaskCompletion.task_id == Task.id
        ).exists()
        if durum == "tamamlandi":
            where.append(tamamlanmis)
        elif durum == "gecikti":
            where.append(~tamamlanmis)
            where.append(Task.son_tarih.is_not(None))
            where.append(Task.son_tarih < simdi)
        elif durum == "baslandi":
            where.append(~tamamlanmis)
            where.append(Task.baslama_zamani.is_not(None))
            # GECIKENLER "baslandi"DAN CIKARILIR: durum hesabi gecikmeyi
            # once degerlendiriyor; suzgec ayrisirsa ayni gorev iki
            # listede birden gorunurdu.
            where.append(
                or_(Task.son_tarih.is_(None), Task.son_tarih >= simdi)
            )
        elif durum == "atandi":
            where.append(~tamamlanmis)
            where.append(Task.baslama_zamani.is_(None))
            where.append(
                or_(Task.son_tarih.is_(None), Task.son_tarih >= simdi)
            )
        else:
            raise APIError(422, "validation_error", "gorev_durum_bilinmiyor")
    total = (await db.execute(select(func.count()).select_from(Task).where(*where))).scalar_one()
    rows = (
        await db.execute(
            select(Task).where(*where).order_by(Task.created_at, Task.id).limit(limit).offset(offset)
        )
    ).scalars().all()
    items = await _serialize_tasks(db, list(rows))
    return TaskListResponse(meta={"limit": limit, "offset": offset, "total": total}, items=items)


@router.get("/{task_id}", response_model=TaskOut)
async def get_task(
    task_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> TaskOut:
    task = await _visible_task_or_404(db, task_id, user)
    return (await _serialize_tasks(db, [task]))[0]


def _gorev_bildir(db, task: Task, user: AppUser) -> None:
    """(P191 §2) Goreve ATANAN kisiye push + kalici in-app bildirim.

    Push EK gonderimdir: hatasi kaydi kirmaz (`dispatch_external` kendi
    try/except'i icinde yutar). In-app satir da yazilir ki bildirimi o an
    kaciran kisi olayi listede bulsun (P147 ilkesi).
    """
    if task.atanan_user_id is None:
        return
    # `Task.ad` gorevi adlandiran alandir; push sablonunun alani `baslik`.
    veri = {"baslik": task.ad}
    dispatch_external(
        "gorev_atandi",
        tenant_id=user.tenant_id,
        target_user_ids=(task.atanan_user_id,),
        params=veri,
        data={"tip": "gorev_atandi", "task_id": str(task.id)},
    )
    sakin_bildirimi_yaz(
        db,
        tenant_id=user.tenant_id,
        tip="gorev_atandi",
        user_ids=(task.atanan_user_id,),
        veri=veri,
        task_id=task.id,
    )


async def _tamamlandi_bildir(db, task: Task, user: AppUser) -> None:
    """(P229 §3) Gorev tamamlaninca YONETIME haber ver.

    =======================================================================
    KIME: OLUSTURANA DEGIL, YONETIME
    =======================================================================
    Gorevi olusturan kisi izinli ya da isten ayrilmis olabilir; o zaman
    "is bitti" haberini KIMSE almazdi. Bu yuzden hedef, tesisin aktif
    yonetimi (admin + yonetici).

    KENDINI BILDIRME: gorevi tamamlayan kisinin kendisi yonetimdeyse
    (yonetici kendi kapattigi gorev) ona bildirim GITMEZ — yaptigi isi
    kendisine haber vermek gurultudur.
    """
    hedefler = [
        r
        for (r,) in (
            await db.execute(
                select(AppUser.id).where(
                    AppUser.role.in_(("admin", "yonetici")),
                    AppUser.is_active.is_(True),
                    AppUser.id != user.id,
                )
            )
        ).all()
    ]
    if not hedefler:
        return
    veri = {"baslik": task.ad, "kisi": user.ad or ""}
    dispatch_external(
        "gorev_tamamlandi",
        tenant_id=user.tenant_id,
        target_user_ids=tuple(hedefler),
        params=veri,
        data={"tip": "gorev_tamamlandi", "task_id": str(task.id)},
    )
    sakin_bildirimi_yaz(
        db,
        tenant_id=user.tenant_id,
        tip="gorev_tamamlandi",
        user_ids=tuple(hedefler),
        veri=veri,
        task_id=task.id,
    )


@router.post("", response_model=TaskOut, status_code=201)
async def create_task(
    body: TaskCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> TaskOut:
    await _ensure_user_in_tenant(db, body.atanan_user_id, user)
    # (P230 §4) KIM ATADI — "bu isi bana kim verdi" sorusunun yaniti.
    # Govdeden ALINMAZ, oturumdan gelir: istemcinin gonderecegi bir alan
    # olsaydi baskasinin adina gorev atanabilirdi.
    await _ensure_checkpoint_in_tenant(db, body.checkpoint_id)
    await _ensure_kategori_in_tenant(db, body.kategori_id)
    # (P230 §4) KIM ATADI — "bu isi bana kim verdi" sorusunun yaniti.
    # GOVDEDEN ALINMAZ, oturumdan gelir: istemcinin gonderebilecegi bir
    # alan olsaydi baskasinin adina gorev atanabilirdi.
    obj = Task(
        tenant_id=user.tenant_id,
        olusturan_user_id=user.id,
        **body.model_dump(exclude_unset=True),
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    # (P191 §2) ATANAN KISIYE BILDIRIM. Bu cagri BUGUNE KADAR YOKTU: gorev
    # olusturuluyor, atanan kisinin telefonuna hicbir sey dusmuyordu — "gorev
    # olusturdum, bildirim gelmedi" sikayetinin kok nedeni. Atama YOKSA
    # (havuz gorevi) bildirim de yoktur; kime gonderilecegi belli degil.
    _gorev_bildir(db, obj, user)
    await db.refresh(obj)
    return (await _serialize_tasks(db, [obj]))[0]


@router.patch("/{task_id}", response_model=TaskOut)
async def update_task(
    task_id: uuid.UUID,
    body: TaskUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> TaskOut:
    obj = await get_or_404(db, Task, task_id)
    data = body.model_dump(exclude_unset=True)
    # (P191 §2) ATAMA DEGISTIYSE yeni kisi bildirilmeli — gorevin ona
    # gectigini yalnizca listeye bakarak ogrenmesi beklenemez. Ayni kisiye
    # yeniden atama (deger degismedi) bildirim URETMEZ.
    eski_atanan = obj.atanan_user_id
    if "atanan_user_id" in data:
        await _ensure_user_in_tenant(db, data["atanan_user_id"], user)
    if "checkpoint_id" in data:
        await _ensure_checkpoint_in_tenant(db, data["checkpoint_id"])
    if "kategori_id" in data:
        await _ensure_kategori_in_tenant(db, data["kategori_id"])
    for key, value in data.items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    if obj.atanan_user_id is not None and obj.atanan_user_id != eski_atanan:
        _gorev_bildir(db, obj, user)
    await db.refresh(obj)
    return (await _serialize_tasks(db, [obj]))[0]


@router.delete("/{task_id}", status_code=204)
async def delete_task(
    task_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_WRITER),
) -> Response:
    obj = await get_or_404(db, Task, task_id)
    await db.delete(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    return Response(status_code=204)


# ----------------------------- completions --------------------------------- #
def _completion_out(obj: TaskCompletion, ad: str | None = None) -> TaskCompletionOut:
    """(P131) Foto KANITINI GORUNUR yapar.

    OLCULEN KUSUR: `TaskCompletionOut` semasinda `foto_url` ALANI VARDI ve
    iki istemci de onu okuyordu (mobil `TaskCompletion.fotoUrl`, panel
    gorev detayi) — ama HICBIR YERDE DOLDURULMUYORDU. Sonuc: fotograf
    kaniti YUKLENIYOR (`foto_key` dolu), sunucu onu saklıyor, ve iki
    istemcide de GORUNMUYOR. Belirti "web'de gorseller cikmiyor"du; sebep
    web degil, SUNUCUNUN doldurmadigi bir alandi.

    Olcum (dev yigini, 2026-08-04): duyuru/site kurali/etkinlik/talep
    uclarinin hepsi `foto_url` dolduruyordu; gorev tamamlamalari
    doldurmayan TEK uctu.
    """
    out = TaskCompletionOut.model_validate(obj)
    out.foto_url = presign_get(obj.foto_key) if obj.foto_key else None
    # (P229 §3) KIM tamamladi. Id yeterli degildi: saha rolu kullanici
    # listesini GOREMIYOR (403), yani adi kendisi cozemezdi.
    out.tamamlayan_ad = ad
    return out


@router.get("/{task_id}/completions", response_model=TaskCompletionListResponse)
async def list_completions(
    task_id: uuid.UUID,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> TaskCompletionListResponse:
    # 404: yoksa / baska tenant / baskasina atanmis (saha rolu icin).
    await _visible_task_or_404(db, task_id, user)
    base = TaskCompletion.task_id == task_id
    total = (
        await db.execute(select(func.count()).select_from(TaskCompletion).where(base))
    ).scalar_one()
    rows = (
        await db.execute(
            select(TaskCompletion, AppUser.ad)
            .outerjoin(AppUser, AppUser.id == TaskCompletion.tamamlayan_user_id)
            .where(base)
            .order_by(TaskCompletion.tamamlanma_zamani.desc(), TaskCompletion.id.desc())
            .limit(limit)
            .offset(offset)
        )
    ).all()
    return TaskCompletionListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_completion_out(r, ad) for r, ad in rows],
    )


def _same_completion(existing: TaskCompletion, **v) -> bool:
    return (
        existing.task_id == v["task_id"]
        and existing.tamamlayan_user_id == v["tamamlayan_user_id"]
        and existing.tamamlanma_zamani == v["tamamlanma_zamani"]
        and existing.nfc_tag_uid == v["nfc_tag_uid"]
        and coord_eq(existing.gps_lat, v["gps_lat"])
        and coord_eq(existing.gps_lng, v["gps_lng"])
        and existing.foto_key == v["foto_key"]
        and existing.notlar == v["notlar"]
    )


@router.post("/{task_id}/completions")
async def create_completion(
    task_id: uuid.UUID,
    body: TaskCompletionCreate,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_COMPLETER),
) -> JSONResponse:
    if not idempotency_key or not idempotency_key.strip():
        raise APIError(400, "bad_request", "idempotency_key_zorunlu")

    # Gorunurluk: grup disi / baska tenant -> 404 (varlik sizdirilmaz).
    task = await _visible_task_or_404(db, task_id, user)

    # Tamamlama BYPASS-PROOF: saha kullanicisi YALNIZ KENDINE atanan gorevi
    # tamamlar. (_visible_task_or_404 zaten kendine-ait olmayani 404'ler; bu
    # ek kontrol savunmacidir.)
    if user.role in _SAHA_ROLLERI and task.atanan_user_id != user.id:
        raise APIError(403, "forbidden", "gorev_yalniz_atanan_tamamlar")

    # Foto kaniti: gorev foto_zorunlu ise foto_key olmadan tamamlanamaz (mobil §11 #2).
    if task.foto_zorunlu and body.foto_key is None:
        raise APIError(422, "validation_error", "gorev_foto_kaniti_zorunlu")

    # NFC kaniti: task'in checkpoint'i varsa ve nfc gonderildiyse eslesmeli
    # (normalize karsilastirma — mobil §11 #3).
    if body.nfc_tag_uid is not None and task.checkpoint_id is not None:
        cp = (
            await db.execute(select(Checkpoint).where(Checkpoint.id == task.checkpoint_id))
        ).scalar_one_or_none()
        if cp is None or not nfc_eq(cp.nfc_tag_uid, body.nfc_tag_uid):
            raise APIError(422, "invalid_reference", "gorev_nfc_eslesmiyor")

    zaman = body.tamamlanma_zamani
    if zaman.tzinfo is None:
        zaman = zaman.replace(tzinfo=timezone.utc)

    fields = dict(
        task_id=task_id,
        tamamlayan_user_id=user.id,
        tamamlanma_zamani=zaman,
        nfc_tag_uid=body.nfc_tag_uid,
        gps_lat=body.gps_lat,
        gps_lng=body.gps_lng,
        foto_key=body.foto_key,
        notlar=body.notlar,
    )
    obj = TaskCompletion(tenant_id=user.tenant_id, idempotency_key=idempotency_key, **fields)

    created = True
    try:
        async with db.begin_nested():
            db.add(obj)
            await db.flush()
    except IntegrityError as exc:
        if not is_unique_violation(exc):
            raise translate_integrity(exc)
        created = False
        try:
            db.expunge(obj)
        except Exception:
            pass

    if created:
        # Periyodik gorev (peyzaj dahil) tamamlaninca bir sonraki planlanan tarihi ilerlet.
        if task.periyot_dakika and task.sonraki_planlanan is not None:
            task.sonraki_planlanan = task.sonraki_planlanan + timedelta(
                minutes=task.periyot_dakika
            )
            await db.flush()
        # Ticket-linked gorev tamamlaninca bagli talebi oto-coz (YALNIZ taze
        # insert'te — idempotent replay'de degil; aksi halde yonetici tekrar
        # actigi talebi ezip mukerrer history/push uretebilir).
        if task.ticket_id is not None:
            complaint = (
                await db.execute(
                    select(Complaint).where(Complaint.id == task.ticket_id)
                )
            ).scalars().first()
            if complaint is not None and complaint.durum == "is_emri":
                complaint.durum = "cozuldu"
                complaint.updated_at = func.now()
                add_history(
                    db, complaint=complaint, durum="cozuldu",
                    actor_role=user.role, sebep=None,
                )
                await db.flush()
                notify_opener(
                    complaint=complaint,
                    tenant_id=user.tenant_id,
                    tip="talep_cozuldu",
                )
        # (P229 §3) YONETIME BILDIRIM — "is bitti".
        await _tamamlandi_bildir(db, task, user)

        # (P229 §3) DENETIM KAYDI — tamamlama bir IS KANITIDIR.
        #
        # YALNIZ TAZE INSERT'TE: idempotent tekrar (ag koptu, istemci
        # yeniden gonderdi) ayni isi IKI KEZ yapilmis gibi gostermemeli.
        await audit_user(
            db, user, Action.TASK_COMPLETE,
            resource_type="task", resource_id=task_id,
            meta={"completion_id": str(obj.id), "foto": obj.foto_key is not None},
        )
        await db.refresh(obj)
        return JSONResponse(
            # (P131) `_completion_out`: yeni kaydin fotografi ANINDA
            # gorunur olsun — istemci ikinci bir istek atmak zorunda kalmasin.
            status_code=201,
            content=_completion_out(obj, user.ad).model_dump(mode="json"),
        )

    existing = (
        await db.execute(
            select(TaskCompletion).where(TaskCompletion.idempotency_key == idempotency_key)
        )
    ).scalar_one()
    if _same_completion(existing, **fields):
        return JSONResponse(
            status_code=200, content=_completion_out(existing).model_dump(mode="json")
        )
    raise APIError(409, "conflict", "idempotency_key_govde_farkli")


@router.delete("/{task_id}/completions/{completion_id}", status_code=204)
async def delete_completion(
    task_id: uuid.UUID,
    completion_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_REOPENER),
) -> Response:
    """(P229 §3) TAMAMLAMAYI GERI AL — gorevi yeniden ac.

    =======================================================================
    KIM: YALNIZ YONETIM (admin + yonetici)
    =======================================================================
    Saha rolleri DISARIDA. Geri acma bir KANITI siler; sahadaki kisi kendi
    tamamlamasini silebilseydi "yaptim" deyip izini temizleyebilirdi.

    =======================================================================
    NEDEN SILME, "iptal" BAYRAGI DEGIL
    =======================================================================
    Tamamlama kaydinin kendisi olaya dair bir OLCUMDUR (zaman, foto, NFC,
    GPS). "Iptal edildi" isaretli bir kayit birakmak, listedeki
    "son tamamlama" hesabini ve rapor toplamlarini her yerde bu bayragi
    kontrol etmeye zorlardi — bir yerde unutulmasi, geri alinmis bir isin
    raporda YAPILMIS gorunmesi demekti. Iz DENETIM KAYDINDA duruyor:
    `task_complete` ve `task_reopen` satirlari kimin ne zaman ne yaptigini
    tasiyor.
    """
    task = await _visible_task_or_404(db, task_id, user)
    obj = (
        await db.execute(
            select(TaskCompletion).where(
                TaskCompletion.id == completion_id,
                TaskCompletion.task_id == task.id,
            )
        )
    ).scalar_one_or_none()
    if obj is None:
        raise APIError(404, "not_found", "kayit_bulunamadi")

    # Denetim kaydi SILMEDEN ONCE: silinen kaydin alanlarini tasimali.
    await audit_user(
        db, user, Action.TASK_REOPEN,
        resource_type="task", resource_id=task_id,
        meta={
            "completion_id": str(obj.id),
            "tamamlayan_user_id": str(obj.tamamlayan_user_id),
            "tamamlanma_zamani": obj.tamamlanma_zamani.isoformat(),
        },
    )
    await db.delete(obj)
    await db.flush()
    return Response(status_code=204)


@router.post("/{task_id}/basla", response_model=TaskOut)
async def start_task(
    task_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_COMPLETER),
) -> TaskOut:
    """(P230 §4) GOREVE BASLANDI — personel isi aldigini isaretler.

    =======================================================================
    NEDEN AYRI BIR DURUM GEREKLI
    =======================================================================
    Onceden yalniz iki hal vardi: atanmis ve tamamlanmis. Arada gecen
    surede yonetici, isin ELE ALINDIGINI mi yoksa OYLECE DURDUGUNU mu
    bilmiyordu. "Gecikti" uyarisinin degeri de buna bagli: baslanmis ama
    uzayan bir is ile hic dokunulmamis bir is ayni sey degil.

    =======================================================================
    KIM: TAMAMLAYABILEN HERKES
    =======================================================================
    `_COMPLETER` (admin + yonetici + saha). Saha kisiti asagida korunuyor:
    saha rolu YALNIZ kendine atanan gorevi baslatabilir — tamamlama ile
    AYNI kural. Farkli olsaydi, baskasinin gorevini "baslatip"
    tamamlayamayan bir kullanici ortaya cikardi.

    =======================================================================
    IDEMPOTENT
    =======================================================================
    Ikinci cagri zamani EZMEZ. Ezseydi, yanlislikla iki kez dokunan
    kullanici gercek baslama anini kaybederdi — ve "ne zaman baslandi"
    takip ekraninin tasidigi bilgiydi.
    """
    task = await _visible_task_or_404(db, task_id, user)
    if user.role in _SAHA_ROLLERI and task.atanan_user_id != user.id:
        raise APIError(403, "forbidden", "gorev_yalniz_atanan_tamamlar")

    if task.baslama_zamani is None:
        task.baslama_zamani = datetime.now(timezone.utc)
        task.updated_at = func.now()
        await audit_user(
            db, user, Action.TASK_START,
            resource_type="task", resource_id=task_id,
        )
        await db.flush()
        # TAZELEME SART: `func.now()` bir SQL IFADESIDIR; flush sonrasi
        # onu OKUMAK veritabanina gitmeyi gerektirir ve seri hale
        # getirme sirasinda `MissingGreenlet` ile 500 uretiyordu
        # (olculdu). Tazeleme, degeri istemciye donmeden once cozer.
        await db.refresh(task)
    return (await _serialize_tasks(db, [task]))[0]
