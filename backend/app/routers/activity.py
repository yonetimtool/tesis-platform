"""GET /activity — birlesik "Son Hareketler" akisi (G5).

Amac: mobil ana ekran akisi ARTIK ISTEMCIDE birlestirilmiyor. Onceden her rol
3-4 ayri uca istek atip sonuclari elde siraliyordu (sayfalama yok, kronoloji
yaklasik, "hangi ucu hangi rolde cagirabilirim" bilgisi istemcide). Bu uc ayni
olaylari SUNUCUDA birlestirir, SUNUCUDA siralar ve SUNUCUDA rol/KVKK'ya gore
suzer.

Kaynaklar (yeni tablo YOK — hepsi mevcut kayitlardan turer):
  devriye_okutma | gorev_tamamlama | aidat_odeme | talep | daire_sikayeti |
  alarm | ziyaretci_giris | ziyaretci_cikis | kargo | kargo_teslim |
  arac_giris | arac_cikis | ihlal

ROL SUZGECI (sunucu tarafinda; istemci bypass EDEMEZ):
  * admin    : operasyonel + finans + talep/sikayet + arac + ihlal.
  * yonetici : admin ile ayni, arac gecisleri HARIC (plaka RBAC'i admin+security).
  * security : operasyonel (devriye, gorev, alarm, ziyaretci, kargo, arac,
               ihlal) + KENDI actigi talepler. FINANS YOK (aidat gormez).
  * resident : YALNIZ kendi dairesi/kendisi (kendine hedeflenen ziyaretci,
               dairesinin kargosu, dairesinin aidat odemesi, kendi talepleri,
               kendi actigi daire sikayetleri). Baskasinin olayi ASLA girmez.
  * tesis_gorevlisi: YALNIZ gorev tamamlamalari (mevcut KVKK kisiti korunur).

ZIYARETCI/KARGO — BILINCLI KISIT (yonetim dahil): bu iki kaynak yonetim
rollerine (admin + yonetici) burada da KAPALIDIR. Sebep: /visitors ve /kargo
uclarinda yonetim VARSAYILAN KAPALI'dir ve daire bazli TEK-SEFERLIK izinle
(unit_access_permission) acilir. Birlesik akis bu kapiyi bypass eden bir yan
kanal OLMAMALIDIR — aksi halde izin mekanizmasi anlamsizlasirdi.

SAYFALAMA — bilesik imlec (zaman, id): `ORDER BY zaman DESC, id DESC` ve
`WHERE (zaman, id) < (imlec)`. offset kullanilmaz; araya YENI kayit girse bile
sayfalar kaymaz/tekrarlamaz (offset'te olurdu). `id` kaynaklar arasi benzersiz
oldugundan ("<tur>:<uuid>") esit zamanli olaylarda da siralama KARARLIDIR.
`meta.total` YOKTUR: 13 kaynagin birlesik sayimi her istekte tam tarama
demektir ve akis ekraninda kullanilmaz.
"""
from __future__ import annotations

import base64
import binascii
from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser
from ..schemas import ActivityItemOut, ActivityResponse

router = APIRouter(prefix="/activity", tags=["activity"])

_READER = require_role(
    "admin", "yonetici", "security", "tesis_gorevlisi", "resident"
)

# --------------------------------------------------------------------------- #
# Kaynak parcalari. Her parca AYNI kolonlari uretir:
#   kaynak_id uuid | tur text | baslik text | alt_metin text |
#   zaman timestamptz | renk_ipucu text
# RLS tenant'i zaten daraltir; buradaki WHERE'ler YALNIZ rol/sahiplik icindir.
# `:uid` = oturum kullanicisi (resident/own-scope parcalarinda kullanilir).
# --------------------------------------------------------------------------- #

_DEVRIYE = """
SELECT s.id, 'devriye_okutma', 'Devriye Okutması', c.ad,
       s.okutma_zamani, 'notr'
FROM scan_event s
JOIN checkpoint c ON c.id = s.checkpoint_id
"""

_GOREV = """
SELECT tc.id, 'gorev_tamamlama', 'Görev Tamamlandı', t.ad,
       tc.tamamlanma_zamani, 'olumlu'
FROM task_completion tc
JOIN task t ON t.id = tc.task_id
"""

# Yalniz BASARILI odemeler akisa girer (bekleyen/iptal finansal olay degildir).
_AIDAT = """
SELECT p.id, 'aidat_odeme', 'Aidat Ödemesi',
       'Daire ' || u.no || ' — ₺' ||
           to_char(p.tutar_kurus / 100.0, 'FM999999990.00'),
       p.odeme_zamani, 'olumlu'
FROM dues_payment p
JOIN unit u ON u.id = p.unit_id
WHERE p.durum = 'basarili'
"""
# resident: YALNIZ AKTIF olarak oturdugu dairelerin odemeleri.
_AIDAT_OWN = _AIDAT + """
  AND EXISTS (SELECT 1 FROM unit_resident ur
              WHERE ur.unit_id = p.unit_id AND ur.user_id = :uid
                AND ur.bitis IS NULL)
"""

_TALEP = """
SELECT c.id, 'talep',
       CASE c.durum
           WHEN 'acik'       THEN 'Talep Açıldı'
           WHEN 'is_emri'    THEN 'Talep İş Emrine Dönüştü'
           WHEN 'cozuldu'    THEN 'Talep Çözüldü'
           ELSE                   'Talep Reddedildi'
       END,
       c.baslik, c.updated_at,
       CASE c.durum
           WHEN 'cozuldu' THEN 'olumlu'
           WHEN 'acik'    THEN 'uyari'
           ELSE                'notr'
       END
FROM complaint c
"""
# Acan roller (security/resident) YALNIZ kendi taleplerini gorur —
# /complaints listesindeki _own_scope ile BIRE BIR ayni kural.
_TALEP_OWN = _TALEP + " WHERE c.acan_user_id = :uid"

# Daire sikayeti TAM ANONIM: sikayet EDEN hicbir turde donmez (kaynak_id
# sikayet kaydinin id'sidir, kisi degil).
_SIKAYET = """
SELECT uc.id, 'daire_sikayeti', 'Daire Şikayeti',
       'Daire ' || u.no || ' — ' || uc.kategori::text,
       uc.created_at, 'uyari'
FROM unit_complaint uc
JOIN unit u ON u.id = uc.target_unit_id
"""
# resident: YALNIZ KENDI actigi sikayetler (/unit-complaints/mine ile ayni
# kural). Kendi dairesine gelen sikayetleri GORMEZ (yogunluk sizmasi olurdu).
_SIKAYET_OWN = _SIKAYET + " WHERE uc.complainant_user_id = :uid"

# "Acil durum" olaylari = tur alarmlari (SOS kaldirildi; dashboard/live ile
# ayni tip kumesi).
_ALARM = """
SELECT n.id, 'alarm',
       CASE n.tip
           WHEN 'kacirilan_tur'    THEN 'Kaçırılan Tur'
           WHEN 'eksik_checkpoint' THEN 'Eksik Checkpoint'
           ELSE                         'Gecikmiş Okutma'
       END,
       n.mesaj, n.created_at, 'alarm'
FROM notification n
WHERE n.tip IN ('kacirilan_tur', 'eksik_checkpoint', 'gecikmis_okutma')
"""

_ZIYARETCI_GIRIS = """
SELECT v.id, 'ziyaretci_giris', 'Ziyaretçi Girişi',
       v.ziyaretci_ad || ' — Daire ' || u.no, v.created_at, 'notr'
FROM visitor v
JOIN unit u ON u.id = v.unit_id
"""
_ZIYARETCI_CIKIS = """
SELECT v.id, 'ziyaretci_cikis', 'Ziyaretçi Çıkışı',
       v.ziyaretci_ad || ' — Daire ' || u.no, v.cikis_zamani, 'notr'
FROM visitor v
JOIN unit u ON u.id = v.unit_id
WHERE v.cikis_zamani IS NOT NULL
"""
# resident: TEK HEDEF modeli — yalniz KENDINE hedeflenen kayitlar (ayni
# dairedeki esinkini bile gormez; /visitors ile ayni kural).
_ZIYARETCI_GIRIS_OWN = _ZIYARETCI_GIRIS + " WHERE v.target_resident_user_id = :uid"
_ZIYARETCI_CIKIS_OWN = _ZIYARETCI_CIKIS + " AND v.target_resident_user_id = :uid"

_KARGO = """
SELECT k.id, 'kargo', 'Kargo Kaydedildi',
       k.firma || ' — Daire ' || u.no, k.created_at, 'notr'
FROM kargo k
JOIN unit u ON u.id = k.unit_id
"""
_KARGO_TESLIM = """
SELECT k.id, 'kargo_teslim', 'Kargo Teslim Edildi',
       k.firma || ' — Daire ' || u.no, k.teslim_zamani, 'olumlu'
FROM kargo k
JOIN unit u ON u.id = k.unit_id
WHERE k.teslim_zamani IS NOT NULL
"""
# resident: kargo DAIRE bazlidir (es de gorur) — /kargo ile ayni kural.
_OWN_UNIT_KARGO = """
  EXISTS (SELECT 1 FROM unit_resident ur
          WHERE ur.unit_id = k.unit_id AND ur.user_id = :uid
            AND ur.bitis IS NULL)
"""
_KARGO_OWN = _KARGO + " WHERE " + _OWN_UNIT_KARGO
_KARGO_TESLIM_OWN = _KARGO_TESLIM + " AND " + _OWN_UNIT_KARGO

# Arac gecisi: plaka daireye/kisiye baglanabilir (KVKK) — YALNIZ admin+security
# (uc RBAC'i ile ayni).
_ARAC_GIRIS = """
SELECT vp.id, 'arac_giris', 'Araç Girişi',
       vp.plaka || COALESCE(' — Daire ' || u.no, '')
                || COALESCE(' (' || vp.arac_tanim || ')', ''),
       vp.giris_zamani, 'notr'
FROM vehicle_pass vp
LEFT JOIN unit u ON u.id = vp.unit_id
"""
_ARAC_CIKIS = """
SELECT vp.id, 'arac_cikis', 'Araç Çıkışı',
       vp.plaka || COALESCE(' — Daire ' || u.no, ''),
       vp.cikis_zamani, 'notr'
FROM vehicle_pass vp
LEFT JOIN unit u ON u.id = vp.unit_id
WHERE vp.cikis_zamani IS NOT NULL
"""

_IHLAL = """
SELECT vi.id, 'ihlal', 'İhlal Kaydı',
       vi.baslik || COALESCE(' — ' || vi.konum, ''), vi.created_at,
       CASE vi.durum
           WHEN 'yeni'        THEN 'alarm'
           WHEN 'inceleniyor' THEN 'uyari'
           ELSE                    'notr'
       END
FROM violation vi
"""

# Rol -> kaynak parcalari. Sunucu tarafi tek dogruluk kaynagi; istemci bu
# listeyi TASIMAZ.
_ROL_KAYNAKLARI: dict[str, tuple[str, ...]] = {
    "admin": (
        _DEVRIYE, _GOREV, _AIDAT, _TALEP, _SIKAYET, _ALARM,
        _ARAC_GIRIS, _ARAC_CIKIS, _IHLAL,
    ),
    # yonetici: arac gecisi HARIC (plaka okuma yetkisi admin+security'de).
    "yonetici": (
        _DEVRIYE, _GOREV, _AIDAT, _TALEP, _SIKAYET, _ALARM, _IHLAL,
    ),
    # security: operasyonel + KENDI talepleri; FINANS (aidat) YOK.
    "security": (
        _DEVRIYE, _GOREV, _ALARM, _TALEP_OWN,
        _ZIYARETCI_GIRIS, _ZIYARETCI_CIKIS, _KARGO, _KARGO_TESLIM,
        _ARAC_GIRIS, _ARAC_CIKIS, _IHLAL,
    ),
    # tesis_gorevlisi: KVKK kisiti — yalniz gorev tamamlamalari.
    "tesis_gorevlisi": (_GOREV,),
    # resident: yalniz kendisi/kendi dairesi.
    "resident": (
        _ZIYARETCI_GIRIS_OWN, _ZIYARETCI_CIKIS_OWN,
        _KARGO_OWN, _KARGO_TESLIM_OWN, _AIDAT_OWN, _TALEP_OWN, _SIKAYET_OWN,
    ),
}

# Parca icinde ':uid' geciyorsa sorguya kullanici parametresi baglanir.
_UID_GEREKEN = ":uid"


def _encode_cursor(zaman: datetime, item_id: str) -> str:
    """Opak imlec: base64url("<iso zaman>|<id>"). Istemci ICERIGINE BAKMAZ —
    ileride siralama anahtari degisirse sozlesme kirilmaz."""
    raw = f"{zaman.isoformat()}|{item_id}".encode()
    return base64.urlsafe_b64encode(raw).decode().rstrip("=")


def _decode_cursor(cursor: str) -> tuple[datetime, str]:
    pad = "=" * (-len(cursor) % 4)
    try:
        raw = base64.urlsafe_b64decode(cursor + pad).decode()
        zaman_s, item_id = raw.split("|", 1)
        return datetime.fromisoformat(zaman_s), item_id
    except (ValueError, binascii.Error, UnicodeDecodeError):
        raise APIError(422, "validation_error", "cursor_gecersiz")


@router.get("", response_model=ActivityResponse)
async def list_activity(
    limit: int = Query(20, ge=1, le=100),
    cursor: str | None = Query(
        None, description="Onceki yanitin meta.next_cursor degeri (opak)"
    ),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> ActivityResponse:
    """Rol-farkindali, en yeniden eskiye birlesik olay akisi."""
    parcalar = _ROL_KAYNAKLARI[user.role]

    union_sql = "\nUNION ALL\n".join(f"({p.strip()})" for p in parcalar)
    params: dict[str, object] = {"lim": limit + 1}
    if any(_UID_GEREKEN in p for p in parcalar):
        params["uid"] = user.id

    kosul = ""
    if cursor is not None:
        c_zaman, c_id = _decode_cursor(cursor)
        kosul = "WHERE (f.zaman, f.id) < (:cz, :cid)"
        params["cz"] = c_zaman
        params["cid"] = c_id

    sql = text(
        f"""
        SELECT f.id, f.tur, f.baslik, f.alt_metin, f.zaman, f.renk_ipucu,
               f.kaynak_id
        FROM (
            SELECT u.tur || ':' || u.kaynak_id::text AS id,
                   u.tur, u.baslik, u.alt_metin, u.zaman, u.renk_ipucu,
                   u.kaynak_id
            FROM (
                {union_sql}
            ) AS u (kaynak_id, tur, baslik, alt_metin, zaman, renk_ipucu)
        ) AS f
        {kosul}
        ORDER BY f.zaman DESC, f.id DESC
        LIMIT :lim
        """
    )
    rows = (await db.execute(sql, params)).mappings().all()

    # limit+1 cektik: fazlalik varsa DAHA VAR demektir (ayri COUNT sorgusu yok).
    has_more = len(rows) > limit
    rows = rows[:limit]
    items = [
        ActivityItemOut(
            id=r["id"],
            tur=r["tur"],
            baslik=r["baslik"],
            alt_metin=r["alt_metin"],
            zaman=r["zaman"],
            renk_ipucu=r["renk_ipucu"],
            kaynak_id=r["kaynak_id"],
        )
        for r in rows
    ]
    next_cursor = (
        _encode_cursor(items[-1].zaman, items[-1].id) if (has_more and items) else None
    )
    return ActivityResponse(
        meta={"limit": limit, "next_cursor": next_cursor}, items=items
    )
