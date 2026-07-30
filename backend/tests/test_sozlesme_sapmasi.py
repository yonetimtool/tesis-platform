"""TUR 68 — SOZLESME SAPMASI: uygulama ile `contracts/openapi.yaml` ortusuyor mu?

Dorduncu envanterin ilk maddesi. `contracts/openapi.yaml` bu projede
SOZLESMEDIR: mobil domain testleri onu kaynak gosteriyor ("bkz.
contracts/openapi.yaml"), panel tipleri ona gore yazildi. Ama **uygulamanin
sozlesmeye uydugunu kontrol eden hicbir sey yoktu**.

Olcum yapildi ve sonuc: FastAPI **133** yol sunuyor, sozlesme **119** yol
tanimliyor; parametre ADLARI normalize edilince **14 yol belgelenmemis**
cikti — arasinda TUM MODULLER var (`/support` x3, `/transparency` x3, `/me`
x3, `/audit`, `/admin/overview`, avatar, vardiya atamasi, `/health`).
Ters yonde (belgede olup uygulamada olmayan) sapma YOK.

Bu test iki yonu de kilitler:
  * uygulamada olup belgede olmayan yol → sapma (yeni uc eklenince belge de
    guncellenmeli),
  * belgede olup uygulamada olmayan yol → OLU BELGE (uc kaldirilmis ama
    sozlesme guncellenmemis).

GENISLETME (P9): ilk surum yalniz YOL karsilastiriyordu. Ayni yol uzerinde
uygulamanin ekstra bir METODU olabilir (orn. belgede yalniz `GET /x/{id}`
varken kodda `DELETE /x/{id}` de bulunur) ve yol-duzeyinde karsilastirma
bunu GORMEZ — kapsam gercekte olcuyor gorunup olcmez. Artik
(METOT, yol) ciftleri karsilastiriliyor: olcum anında 201 operasyonun
201'i iki yonde de ortusuyor.

IZIN LISTESI: `/docs`, `/openapi.json` gibi FastAPI'nin kendi ekledigi
yollar sozlesmeye girmez. `/health` bilincli olarak belgelendi (altyapi
kontrolu, istemci sozlesmesi degil ama izleme icin sozlesmede olmasi
yararli).
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest

from app.main import app

#: FastAPI'nin OTOMATIK ekledigi yollar — sozlesmeye girmezler.
OTOMATIK = {"/openapi.json", "/docs", "/docs/oauth2-redirect", "/redoc"}

#: OpenAPI operasyon anahtarlari (`parameters`, `summary` gibi kardesleri
#: ayiklamak icin).
METOTLAR = {"get", "post", "patch", "put", "delete", "head", "options", "trace"}


def _normalize(yol: str) -> str:
    """Parametre ADINI sil: `/assets/{asset_id}` ve `/assets/{id}` AYNIDIR.

    Ilk olcumde bu normalizasyon yoktu ve 63 "sapma" gorunuyordu; gercek
    sapma 14'tu. Parametre adi bir SOZLESME farki degil, adlandirma tercihi.
    """
    return re.sub(r"\{[^}]+\}", "{}", yol)


def _sozlesme_dosyasi() -> Path:
    """Sozlesme dosyasinin yolu.

    Iki yerde olabilir: depo kokunde (host'ta kosarken) ya da `/contracts`
    altinda (konteynerde — imaj yalniz `backend/`i kopyaladigi icin compose
    salt-okunur baglar). Ikisi de yoksa test ATLANIR, cunku "dosya yok"
    sapma DEGILDIR ve sessizce gecmek de dogru olmaz.
    """
    for aday in (
        Path(__file__).resolve().parents[2] / "contracts" / "openapi.yaml",
        Path("/contracts/openapi.yaml"),
    ):
        if aday.exists():
            return aday
    pytest.skip("contracts/openapi.yaml bulunamadi (compose mount eksik)")


def _sozlesme_yollari() -> set[str]:
    """`contracts/openapi.yaml` icindeki `paths:` bloguna ait yollar.

    YAML ayristirici kullanilmaz (ek bagimlilik istemez): `paths:` blogunda
    iki bosluk girintili `/...:` satirlari yollardir.
    """
    metin = _sozlesme_dosyasi().read_text(encoding="utf-8")
    yollar: set[str] = set()
    icinde = False
    for satir in metin.splitlines():
        if satir.startswith("paths:"):
            icinde = True
            continue
        if icinde and satir and not satir.startswith(" "):
            break  # sonraki ust duzey anahtar
        if icinde and re.match(r"^  /\S*:", satir):
            yollar.add(satir.strip().rstrip(":"))
    return yollar


def _sozlesme_operasyonlari() -> set[tuple[str, str]]:
    """(METOT, normalize yol) ciftleri.

    Ayristirici yine YAML kutuphanesi ISTEMEZ: `paths:` blogunda iki bosluk
    girintili `/...:` satirlari yol, dort bosluk girintili `get:`/`post:`...
    satirlari operasyondur. `parameters:` gibi metot OLMAYAN anahtarlar
    listeye girmez (METOTLAR kumesi ile suzuluyor).
    """
    metin = _sozlesme_dosyasi().read_text(encoding="utf-8")
    ciftler: set[tuple[str, str]] = set()
    icinde = False
    yol: str | None = None
    for satir in metin.splitlines():
        if satir.startswith("paths:"):
            icinde = True
            continue
        if not icinde:
            continue
        if satir and not satir.startswith(" "):
            break
        if re.match(r"^  /\S*:", satir):
            yol = _normalize(satir.strip().rstrip(":"))
            continue
        m = re.match(r"^    (\w+):", satir)
        if yol and m and m.group(1) in METOTLAR:
            ciftler.add((m.group(1).upper(), yol))
    return ciftler


def _uygulama_operasyonlari() -> set[tuple[str, str]]:
    sema = app.openapi()["paths"]
    return {
        (yontem.upper(), _normalize(yol))
        for yol, ops in sema.items()
        if yol not in OTOMATIK
        for yontem in ops
        if yontem in METOTLAR
    }


def test_sozlesme_yollari_okunabiliyor():
    """DEDEKTOR SINAMASI: ayristirici gercekten yol buluyor mu?

    Bos bir kume donseydi asagidaki iki test SESSIZCE gecerdi.
    """
    yollar = _sozlesme_yollari()
    assert len(yollar) > 100, f"sozlesmede yalniz {len(yollar)} yol goruldu"
    assert "/tasks" in yollar
    assert all(y.startswith("/") for y in yollar)


def test_uygulamadaki_her_yol_sozlesmede_var():
    """Belgelenmemis uc KALMAMALI."""
    uygulama = {
        _normalize(y) for y in app.openapi()["paths"] if y not in OTOMATIK
    }
    sozlesme = {_normalize(y) for y in _sozlesme_yollari()}
    eksik = sorted(uygulama - sozlesme)
    assert not eksik, (
        "Bu yollar UYGULAMADA var ama contracts/openapi.yaml'da YOK "
        f"({len(eksik)}):\n  " + "\n  ".join(eksik)
    )


def test_sozlesmedeki_her_yol_uygulamada_var():
    """OLU BELGE kalmamali (uc kaldirilmis, sozlesme guncellenmemis)."""
    uygulama = {_normalize(y) for y in app.openapi()["paths"]}
    sozlesme = {_normalize(y) for y in _sozlesme_yollari()}
    olu = sorted(sozlesme - uygulama)
    assert not olu, (
        "Bu yollar SOZLESMEDE var ama uygulamada YOK "
        f"({len(olu)}):\n  " + "\n  ".join(olu)
    )


def test_operasyon_ayristirici_calisiyor():
    """DEDEKTOR SINAMASI: (METOT, yol) ayristiricisi gercekten is goruyor mu?

    Bos/eksik bir kume donseydi asagidaki iki test SESSIZCE gecerdi — tam da
    yol-duzeyi olcumunun metotlari kacirmasi gibi.
    """
    ops = _sozlesme_operasyonlari()
    assert len(ops) > 150, f"sozlesmede yalniz {len(ops)} operasyon goruldu"
    assert ("GET", "/tasks") in ops
    assert ("DELETE", "/tasks/{}") in ops
    assert len(_uygulama_operasyonlari()) > 150


def test_uygulamadaki_her_OPERASYON_sozlesmede_var():
    """Yol belgeli olsa bile METOT belgesiz kalmis olabilir."""
    eksik = sorted(_uygulama_operasyonlari() - _sozlesme_operasyonlari())
    assert not eksik, (
        "Bu OPERASYONLAR uygulamada var ama sozlesmede YOK "
        f"({len(eksik)}):\n  "
        + "\n  ".join(f"{y} {p}" for y, p in eksik)
    )


def test_sozlesmedeki_her_OPERASYON_uygulamada_var():
    """Olu belge: metot kaldirilmis ama sozlesmede duruyor."""
    olu = sorted(_sozlesme_operasyonlari() - _uygulama_operasyonlari())
    assert not olu, (
        "Bu OPERASYONLAR sozlesmede var ama uygulamada YOK "
        f"({len(olu)}):\n  " + "\n  ".join(f"{y} {p}" for y, p in olu)
    )
