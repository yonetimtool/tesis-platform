"""(P253 §B, plan §4.4) EYLEM PARITESI — sozlesme kilidi.

`contracts/eylem-paritesi.tsv` web <-> mobil esitliginin TEK kaynagi. Bu kilit
tablonun SOZLESMEYLE ortusmesini olcer:

  * sozlesmedeki (openapi) HER islem tabloda TAM BIR KEZ — yeni bir uc
    eklenince burasi duser: "web'de mi, mobilde mi, neden" sorusu cevapsiz
    kalamaz;
  * tabloda sozlesmede olmayan satir YOK (bayat satir);
  * `roller` yetki matrisinin IZIN kumesiyle AYNI — bir ucun yetkisi
    degisince parite karari yeniden okunur;
  * durum web/mobil isaretleriyle tutarli; `ayni` disinda gerekce zorunlu.

Web ve mobil kilitleri (`admin-web/tests/p253-eylem-paritesi.test.ts`,
`mobile/test/p253_eylem_paritesi_test.dart`) isaretlerin KAYNAKLA
ortusmesini olcer.
"""
from __future__ import annotations

import pathlib
import re

import yaml

KOK = pathlib.Path(__file__).resolve().parent
SOZLESME = pathlib.Path("/contracts")
TABLO = SOZLESME / "eylem-paritesi.tsv"
MATRIS = KOK / "yetki" / "rol-matrisi.txt"
ROLLER = "admin yonetici security tesis_gorevlisi resident guvenlik_amiri denetci".split()
DURUMLAR = {"ayni", "platform", "yalniz_mobil", "yapisal", "yalniz_web", "ic"}
_norm = lambda p: re.sub(r"\{[^}]+\}", "{}", p)  # noqa: E731
#: Uc karsiligi OLMAYAN satirlar: istemci tarafi disa aktarim (ISTEMCI) ve
#: ayni uclarla yapilan ama bir yuzeyde EKRANI eksik yetenek (YETENEK, P253
#: A2). Ikisi de web/mobil kilitlerinde KAYNAK isaretiyle olculur.
_UCSUZ = ("ISTEMCI", "YETENEK")


def _tablo() -> list[dict]:
    satirlar = []
    basliklar = None
    for ham in TABLO.read_text(encoding="utf-8").splitlines():
        if not ham.strip() or ham.startswith("#"):
            continue
        p = ham.split("\t")
        if basliklar is None:
            basliklar = p
            continue
        assert len(p) == len(basliklar), f"sutun sayisi: {ham}"
        satirlar.append(dict(zip(basliklar, p)))
    return satirlar


def _islemler() -> set[tuple[str, str]]:
    api = yaml.safe_load((SOZLESME / "openapi.yaml").read_text(encoding="utf-8"))
    return {
        (m.upper(), p)
        for p, d in api["paths"].items()
        for m in d
        if m in ("get", "post", "put", "patch", "delete")
    }


def _matris() -> dict[tuple[str, str], str]:
    out = {}
    for satir in MATRIS.read_text(encoding="utf-8").splitlines():
        if satir.startswith("#") or not satir.strip():
            continue
        p = satir.split()
        out[(p[0], _norm(p[1]))] = ",".join(r for r, i in zip(ROLLER, p[2:]) if i == "IZIN")
    return out


def test_SOZLESMEDEKI_HER_ISLEM_tabloda_TAM_BIR_KEZ():
    satirlar = [s for s in _tablo() if s["metot"] not in _UCSUZ]
    anahtarlar = [(s["metot"], s["uc"]) for s in satirlar]
    cift = sorted({a for a in anahtarlar if anahtarlar.count(a) > 1})
    assert not cift, f"tabloda iki kez: {cift}"
    islemler = _islemler()
    eksik = sorted(islemler - set(anahtarlar))
    assert not eksik, (
        "Sozlesmeye yeni uc eklendi ama EYLEM TABLOSUNDA yok. Web'de mi, mobilde "
        "mi, ikisinde mi — contracts/eylem-paritesi.tsv'ye durum ve gerekceyle "
        f"ekleyin:\n  " + "\n  ".join(f"{m} {p}" for m, p in eksik)
    )
    bayat = sorted(set(anahtarlar) - islemler)
    assert not bayat, f"tabloda olup sozlesmede olmayan (bayat) satir: {bayat}"


def test_ROLLER_yetki_matrisiyle_AYNI():
    matris = _matris()
    farkli = []
    for s in _tablo():
        if s["metot"] in _UCSUZ:
            continue
        beklenen = matris.get((s["metot"], _norm(s["uc"])))
        if beklenen is None:
            farkli.append(f"{s['metot']} {s['uc']}: matriste yok")
        elif s["roller"] != beklenen:
            farkli.append(f"{s['metot']} {s['uc']}: tablo={s['roller']} matris={beklenen}")
    assert not farkli, (
        "Bir ucun YETKISI degisti; parite karari yeniden okunmali ve `roller` "
        "guncellenmeli:\n  " + "\n  ".join(farkli[:40])
    )


def test_DURUM_ISARETLERLE_tutarli_ve_GEREKCELI():
    hatalar = []
    for s in _tablo():
        d, w, m = s["durum"], s["web"], s["mobil"]
        a = f"{s['metot']} {s['uc']}"
        asama = re.fullmatch(r"planli:([123])", d)
        if not asama and d not in DURUMLAR:
            hatalar.append(f"{a}: gecersiz durum {d}")
            continue
        if w not in "+-" or m not in "+-" or len(w) != 1 or len(m) != 1:
            hatalar.append(f"{a}: web/mobil isareti +/- olmali")
        kural = {
            "ayni": ("+", "+"),
            "yalniz_mobil": ("-", "+"),
            "yalniz_web": ("+", "-"),
            "ic": ("-", "-"),
        }.get("planli" if asama else d)
        if asama:
            kural = ("+", "-")
        if kural and (w, m) != kural:
            hatalar.append(f"{a}: durum {d} icin web/mobil {kural} olmali, tabloda ({w},{m})")
        if d != "ayni" and s["gerekce"].strip() in ("", "-"):
            hatalar.append(f"{a}: gerekce zorunlu")
    assert not hatalar, "\n  ".join(hatalar)
