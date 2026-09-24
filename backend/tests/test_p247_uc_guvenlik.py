"""(P247 §6) UC GUVENLIK KILIDI — her uc, her guvenlik sutunu BEYANLI.

===========================================================================
NEDEN
===========================================================================
E2E 2026-09 turu gosterdi ki "dogrulandi" denen kurallar gercek akista
kaciyordu: anonim anket oyu kisiye baglanabiliyordu, arama amire sakin
telefonunu aciyordu, giris ucu kaba kuvvete aciktu. Hepsinin ortak yani:
kural BIR YERDE yazili, yeni/degisen uc onu hic sormuyordu.

Bu dosya her ucu (FastAPI rotalari, sozlesmeden degil — sozlesmeye
yazilmamis bir uc da yakalanir) `tests/yetki/uc-guvenlik.tsv` ile
karsilastirir. Sutunlar:

  kimlik    zorunlu | kamu                         (KODDAN hesaplanir)
  kapsam    tesis | platform                       (KODDAN: get_tenant_db)
  sahiplik  - | kendi | atama | rol | hedef        (BEYAN — IDOR karari)
  hiz       var | -                                (KODDAN: sinir bagimliligi/cagrisi)
  denetim   ozel | genel | haric | -               (KODDAN: audit cagrisi / genel_denetim)
  hassas    yanitta kisisel/gizli alanlar          (KODDAN: yanit semasi)
  tavan     yalniz varsayilan tavana dayanan girdi alanlari (KODDAN)
  not       gerekce (kamu uc, haric denetim, sinirsiz hassas uc icin ZORUNLU)

KODDAN hesaplanan bir sutun beyanla uyusmazsa test KIRMIZI: ornegin bir
yanit semasina `telefon` eklenirse `hassas` degisir ve bu degisiklik
BILINCLI bir kilit guncellemesiyle (inceleme) gecer. Yeni uc `?` ile
eklenir ve beyan doldurulmadan test gecmez.

GUNCELLEME (hesaplanan sutunlari yeniden yazar, BEYANLARI KORUR):
    docker compose exec -T -e UC_GUVENLIK_GUNCELLE=1 api \\
        pytest -q tests/test_p247_uc_guvenlik.py
    docker compose cp api:/app/tests/yetki/uc-guvenlik.tsv \\
        ../backend/tests/yetki/uc-guvenlik.tsv
"""
from __future__ import annotations

import inspect
import os
import re
import sys
import typing
from pathlib import Path

import pytest

KILIT = Path(__file__).resolve().parent / "yetki" / "uc-guvenlik.tsv"
GUNCELLE = os.getenv("UC_GUVENLIK_GUNCELLE") == "1"

SUTUNLAR = ("metot", "yol", "kimlik", "kapsam", "sahiplik", "hiz", "denetim",
            "hassas", "tavan", "not")
HESAPLANAN = ("kimlik", "kapsam", "hiz", "denetim", "hassas", "tavan")
SAHIPLIK_DEGERLERI = {"-", "kendi", "atama", "rol", "hedef"}

#: Yanitta HASSAS sayilan alan adlari (kisisel veri / gizli bilgi).
HASSAS = re.compile(
    r"(^|_)(telefon|phone|email|eposta|adres|iban|tc|kimlik_no|dogum|parola|"
    r"password|token|sifre|anahtar|secret|plaka|kullanici)($|_)"
)
#: Yalniz BAYRAK/maske/sayim olan (degeri tasimayan) hassas adli alanlar.
BAYRAK = re.compile(r"(_set|_var|_hazir|_maskeli|_yok|_son6|_dogrulandi|_kaynak|_required|_type)$")

#: Hiz siniri ZORUNLU olan uc siniflari (desen, metot).
HIZ_ZORUNLU = (
    (re.compile(r"/(login|login-phone|tesislerim)$"), "POST"),
    (re.compile(r"kod-iste$|^/auth/.*/basla$|/basvuru$"), "POST"),
    (re.compile(r"(^/arama$|/ara$)"), "GET"),
    (re.compile(r"(/indir$|/pdf$|/disa-aktar$|/makbuz/)"), "GET"),
    (re.compile(r"^/raporlar/\{kod\}"), "POST"),
)


# --------------------------------------------------------------------------- #
# Olcum
# --------------------------------------------------------------------------- #
def _bagimliliklar(dependant, acc):
    for d in dependant.dependencies:
        acc.append(d.call)
        _bagimliliklar(d, acc)
    return acc


def _alanlar(tip, seen=None, onek=""):
    from pydantic import BaseModel

    seen = seen if seen is not None else set()
    out = []
    if tip is None:
        return out
    for a in typing.get_args(tip):
        out += _alanlar(a, seen, onek)
    if inspect.isclass(tip) and issubclass(tip, BaseModel) and tip not in seen:
        seen.add(tip)
        for ad, f in tip.model_fields.items():
            out.append(onek + ad)
            out += _alanlar(f.annotation, seen, onek + ad + ".")
    return out


def _tavana_dayanan(tip, seen=None, onek=""):
    """Girdi semasinda ACIK `max_length`/`pattern`i olmayan str alanlari."""
    from pydantic import BaseModel

    seen = seen if seen is not None else set()
    out = []
    if not (inspect.isclass(tip) and issubclass(tip, BaseModel)) or tip in seen:
        return out
    seen.add(tip)
    for ad, f in tip.model_fields.items():
        args = typing.get_args(f.annotation) or (f.annotation,)
        duz = [b for a in args for b in (typing.get_args(a) or (a,))]
        if str in duz and not any(
            getattr(m, "max_length", None) or getattr(m, "pattern", None)
            for m in f.metadata
        ):
            out.append(onek + ad)
        for b in duz:
            out += _tavana_dayanan(b, seen, onek + ad + ".")
    return out


def _kaynak(endpoint) -> str:
    """Uc govdesi + govdenin cagirdigi AYNI modul fonksiyonlari (bir kademe)."""
    try:
        metin = inspect.getsource(endpoint)
    except (OSError, TypeError):
        return ""
    modul = sys.modules.get(endpoint.__module__)
    for ad in set(re.findall(r"\b(_?[a-z][a-z0-9_]*)\(", metin)):
        f = getattr(modul, ad, None)
        if inspect.isfunction(f) and f is not endpoint:
            try:
                metin += inspect.getsource(f)
            except (OSError, TypeError):
                pass
    return metin


def olcum() -> dict[tuple[str, str], dict[str, str]]:
    from fastapi.routing import APIRoute

    from app.genel_denetim import denetlenir_mi
    from app.main import app

    sonuc: dict[tuple[str, str], dict[str, str]] = {}
    for r in app.routes:
        if not isinstance(r, APIRoute):
            continue
        cagrilar = _bagimliliklar(r.dependant, [])
        adlar = {getattr(c, "__name__", "") for c in cagrilar}
        kimlik = "zorunlu" if adlar & {"get_current_user", "get_access_claims"} else "kamu"
        kapsam = "tesis" if "get_tenant_db" in adlar else "platform"
        kaynak = _kaynak(r.endpoint)
        hiz = "var" if (
            any(hasattr(c, "hiz_siniri_kapsami") for c in cagrilar)
            or re.search(r"\b(kod_istegi_say|giris_kilidi_denetle|DENEME_SINIRI)\b", kaynak)
        ) else "-"
        govde = None
        for p in r.dependant.body_params:
            govde = getattr(p, "type_", None) or getattr(p.field_info, "annotation", None)
        tavan = sorted(_tavana_dayanan(govde)) if govde else []
        hassas = sorted({
            a.split(".")[-1] for a in _alanlar(r.response_model)
            if HASSAS.search(a.split(".")[-1]) and not BAYRAK.search(a.split(".")[-1])
        })
        for m in r.methods:
            if m in ("HEAD", "OPTIONS"):
                continue
            if m == "GET":
                denetim = "ozel" if re.search(r"\b(audit_user|record_audit)\b", kaynak) else "-"
            elif re.search(r"\b(audit_user|record_audit)\b", kaynak):
                denetim = "ozel"
            elif kimlik == "zorunlu" and denetlenir_mi(m, r.path):
                denetim = "genel"
            else:
                denetim = "haric"
            sonuc[(m, r.path)] = {
                "kimlik": kimlik, "kapsam": kapsam, "hiz": hiz, "denetim": denetim,
                "hassas": ",".join(hassas) or "-", "tavan": ",".join(tavan) or "-",
            }
    return sonuc


def _oku() -> dict[tuple[str, str], dict[str, str]]:
    if not KILIT.exists():
        return {}
    out = {}
    for satir in KILIT.read_text(encoding="utf-8").splitlines():
        if not satir.strip() or satir.startswith("#") or satir.startswith("metot\t"):
            continue
        parca = satir.split("\t")
        parca += [""] * (len(SUTUNLAR) - len(parca))
        k = dict(zip(SUTUNLAR, parca))
        out[(k["metot"], k["yol"])] = k
    return out


def _yaz(olculen, eski) -> None:
    satirlar = ["\t".join(SUTUNLAR)]
    for (m, y) in sorted(olculen, key=lambda t: (t[1], t[0])):
        o = olculen[(m, y)]
        e = eski.get((m, y), {})
        satirlar.append("\t".join([
            m, y, o["kimlik"], o["kapsam"], e.get("sahiplik") or "?", o["hiz"],
            o["denetim"], o["hassas"], o["tavan"], e.get("not") or "",
        ]))
    KILIT.write_text(
        "# (P247 §6) UC GUVENLIK KILIDI — bkz. tests/test_p247_uc_guvenlik.py\n"
        + "\n".join(satirlar) + "\n",
        encoding="utf-8",
    )


# --------------------------------------------------------------------------- #
# Testler
# --------------------------------------------------------------------------- #
@pytest.fixture(scope="module")
def olculen():
    return olcum()


def test_KILIT_GUNCEL(olculen):
    eski = _oku()
    if GUNCELLE:
        _yaz(olculen, eski)
        pytest.skip(f"kilit guncellendi: {KILIT}")
    eksik = sorted(set(olculen) - set(eski))
    fazla = sorted(set(eski) - set(olculen))
    assert not eksik, (
        f"KILITTE OLMAYAN UC(lar): {eksik[:10]} — yeni uc beyansiz gecemez "
        "(dosya basligindaki GUNCELLEME komutu + beyan)"
    )
    assert not fazla, f"Artik olmayan uc(lar) kilitte: {fazla[:10]}"
    farklar = []
    for k, o in olculen.items():
        for s in HESAPLANAN:
            if eski[k][s] != o[s]:
                farklar.append(f"{k[0]} {k[1]} [{s}] kilit={eski[k][s]!r} olculen={o[s]!r}")
    assert not farklar, "GUVENLIK OZELLIGI DEGISTI:\n" + "\n".join(farklar[:40])


def test_BEYANLAR_DOLU():
    bos = [f"{m} {y}" for (m, y), k in _oku().items()
           if k["sahiplik"] not in SAHIPLIK_DEGERLERI]
    assert not bos, f"sahiplik beyani eksik/gecersiz ({len(bos)}): {bos[:15]}"


def test_KAMU_UC_GEREKCELI():
    """Kimliksiz her uc BILINCLI olmali — gerekce `not` sutununda."""
    bos = [f"{m} {y}" for (m, y), k in _oku().items()
           if k["kimlik"] == "kamu" and not k["not"].strip()]
    assert not bos, f"gerekcesiz kamu uc(lar): {bos}"


def test_DENETIMSIZ_YAZMA_GEREKCELI():
    bos = [f"{m} {y}" for (m, y), k in _oku().items()
           if k["kimlik"] == "zorunlu" and k["denetim"] == "haric"
           and not k["not"].strip()]
    assert not bos, f"denetimsiz kimlikli yazma, gerekcesiz: {bos}"


def test_HASSAS_UCLARDA_HIZ_SINIRI():
    """Giris, kod gonderme, arama ve disa aktarim uclari SINIRLI olmali."""
    eksik = []
    for (m, y), k in _oku().items():
        for desen, metot in HIZ_ZORUNLU:
            if m == metot and desen.search(y) and k["hiz"] != "var" \
                    and not y.startswith("/dukkan/"):
                eksik.append(f"{m} {y}")
    assert not eksik, f"hiz siniri gereken uc(lar) sinirsiz: {eksik}"


def test_KIMLIGE_BAGLI_ID_UCLARI_SAHIPLIK_BEYANLI():
    """Path'te kimlik tasiyan ve saha/sakin rollerine acik uclar IDOR
    icin beyan edilmeli ('-' kabul edilmez)."""
    from app.main import app
    from fastapi.routing import APIRoute

    acik = {}
    for r in app.routes:
        if not isinstance(r, APIRoute) or "{" not in r.path:
            continue
        roller = None
        for c in _bagimliliklar(r.dependant, []):
            if hasattr(c, "izinli_roller"):
                roller = set(c.izinli_roller)
        if roller is None or roller & {"resident", "security", "tesis_gorevlisi",
                                       "guvenlik_amiri"}:
            for m in r.methods:
                acik[(m, r.path)] = True
    kilit = _oku()
    eksik = [f"{m} {y}" for (m, y) in acik
             if (m, y) in kilit and kilit[(m, y)]["kimlik"] == "zorunlu"
             and kilit[(m, y)]["sahiplik"] == "-" and not y.startswith("/dukkan/")]
    assert not eksik, f"sahiplik beyani gereken uclar: {sorted(eksik)[:20]}"
