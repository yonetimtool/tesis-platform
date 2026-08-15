"""(P160) UZAK OKUTMA ALARMI — PUSH KIME GIDER (in-process).

NEDEN AYRI DOSYA: `test_uzak_okutma_alarmi.py` CALISAN API'ye istek atar
ve push hedefini GOREMEZ (`dispatch_external` ayri sureste calisir).
Hedef secimi ancak modul in-process cagrilarak olculur —
`test_push.py`teki ayni desen.

OLCULEN KARAR: alarm hem GOREVLIYE (kisi olarak) hem YONETIME (rol
olarak) gider. Ikisi ayri cagridir cunku hedefleme farkli: gorevli
`target_user_ids`, yonetim `target_roles`. Rol yayinina birakmak, o
vardiyada olmayan tum guvenlik personelini de titretirdi.
"""
from __future__ import annotations

import uuid

import app.uzak_okutma as uzak


class _Sonuc:
    """`db.execute(...)` donusu — hem skaler hem rowcount tasiyabilir."""

    def __init__(self, skaler=None, rowcount=1):
        self._skaler = skaler
        self.rowcount = rowcount

    def scalar_one_or_none(self):
        return self._skaler


class _SahteDb:
    """Iki cagri bekler: esik SELECT'i, sonra notification INSERT'i."""

    def __init__(self, esik: int | None = 50, insert_rowcount: int = 1):
        self._sira = [_Sonuc(skaler=esik), _Sonuc(rowcount=insert_rowcount)]
        self.cagrilar = 0

    async def execute(self, *_a, **_k):
        self.cagrilar += 1
        return self._sira.pop(0)


class _Kayit:
    def __init__(self, **alanlar):
        self.__dict__.update(alanlar)


NOKTA_LAT, NOKTA_LON = 41.0, 29.0
UZAK_LAT = 41.001  # ~111 m


def _scan(**degis):
    temel = dict(
        id=uuid.uuid4(),
        tenant_id=uuid.uuid4(),
        guard_id=uuid.uuid4(),
        konum_durumu="var",
        gps_lat=UZAK_LAT,
        gps_lng=NOKTA_LON,
        gps_dogruluk_m=5,
    )
    temel.update(degis)
    return _Kayit(**temel)


def _checkpoint(**degis):
    temel = dict(id=uuid.uuid4(), ad="A blok giris", gps_lat=NOKTA_LAT, gps_lng=NOKTA_LON)
    temel.update(degis)
    return _Kayit(**temel)


def _yakala(monkeypatch) -> list[dict]:
    cagrilar: list[dict] = []

    def sahte(kimlik, **kw):
        cagrilar.append({"kimlik": kimlik, **kw})

    monkeypatch.setattr(uzak, "dispatch_external", sahte)
    return cagrilar


# ------------------------------- hedefler ---------------------------------- #
async def test_gorevliye_KISI_olarak_gider(monkeypatch):
    cagrilar = _yakala(monkeypatch)
    scan = _scan()
    assert await uzak.uzak_okutma_alarmi(_SahteDb(), scan=scan, checkpoint=_checkpoint())

    kisi = [c for c in cagrilar if c.get("target_user_ids")]
    assert len(kisi) == 1, cagrilar
    assert kisi[0]["target_user_ids"] == [scan.guard_id]


async def test_yonetime_ROL_olarak_gider(monkeypatch):
    cagrilar = _yakala(monkeypatch)
    assert await uzak.uzak_okutma_alarmi(_SahteDb(), scan=_scan(), checkpoint=_checkpoint())

    rol = [c for c in cagrilar if c.get("target_roles")]
    assert len(rol) == 1, cagrilar
    assert set(rol[0]["target_roles"]) == {"admin", "yonetici", "guvenlik_amiri"}


async def test_IKISI_AYRI_CAGRI(monkeypatch):
    """Tek cagriya sikistirmak, gorevliyi rol yayinina birakmakti."""
    cagrilar = _yakala(monkeypatch)
    assert await uzak.uzak_okutma_alarmi(_SahteDb(), scan=_scan(), checkpoint=_checkpoint())
    assert len(cagrilar) == 2, cagrilar


async def test_gorevli_YOKSA_yonetim_yine_bilgilendirilir(monkeypatch):
    """`guard_id` bos bir okutma olmamali ama olursa alarm KAYBOLMAMALI."""
    cagrilar = _yakala(monkeypatch)
    assert await uzak.uzak_okutma_alarmi(
        _SahteDb(), scan=_scan(guard_id=None), checkpoint=_checkpoint()
    )
    assert len(cagrilar) == 1
    assert cagrilar[0].get("target_roles")


async def test_metin_KIMLIK_ve_VERI_tasir(monkeypatch):
    """Cumle degil kimlik + parametre (tur 16) — gorevlinin ADI GECMEZ."""
    cagrilar = _yakala(monkeypatch)
    cp = _checkpoint()
    await uzak.uzak_okutma_alarmi(_SahteDb(esik=50), scan=_scan(), checkpoint=cp)

    for c in cagrilar:
        assert c["kimlik"] == "uzak_okutma"
        assert set(c["params"]) == {"nokta", "mesafe", "esik"}
        assert c["params"]["nokta"] == cp.ad
        assert c["params"]["esik"] == 50
        assert c["data"]["checkpoint_id"] == str(cp.id)


# --------------------------- push URETILMEYENLER --------------------------- #
async def test_esik_icinde_PUSH_YOK(monkeypatch):
    cagrilar = _yakala(monkeypatch)
    yakin = _scan(gps_lat=41.00009)  # ~10 m
    assert not await uzak.uzak_okutma_alarmi(_SahteDb(), scan=yakin, checkpoint=_checkpoint())
    assert cagrilar == []


async def test_BELIRSIZ_olcumde_PUSH_YOK(monkeypatch):
    """±500 m hatayla 50 m esigi hakkinda karar VERILEMEZ — kimse
    titretilmez."""
    cagrilar = _yakala(monkeypatch)
    scan = _scan(gps_dogruluk_m=500)
    assert not await uzak.uzak_okutma_alarmi(_SahteDb(), scan=scan, checkpoint=_checkpoint())
    assert cagrilar == []


async def test_KONUMSUZ_okutmada_PUSH_YOK(monkeypatch):
    cagrilar = _yakala(monkeypatch)
    scan = _scan(konum_durumu="izin_yok", gps_lat=None, gps_lng=None)
    assert not await uzak.uzak_okutma_alarmi(_SahteDb(), scan=scan, checkpoint=_checkpoint())
    assert cagrilar == []


async def test_NOKTA_KOORDINATSIZSA_PUSH_YOK(monkeypatch):
    cagrilar = _yakala(monkeypatch)
    cp = _checkpoint(gps_lat=None, gps_lng=None)
    assert not await uzak.uzak_okutma_alarmi(_SahteDb(), scan=_scan(), checkpoint=cp)
    assert cagrilar == []


async def test_TEKRARDA_PUSH_YOK(monkeypatch):
    """INSERT catisirsa (ayni okutma) push da atilmaz — yoksa tekrar
    gonderim ayni olayi iki kez duyurudu."""
    cagrilar = _yakala(monkeypatch)
    db = _SahteDb(insert_rowcount=0)
    assert not await uzak.uzak_okutma_alarmi(db, scan=_scan(), checkpoint=_checkpoint())
    assert cagrilar == []
