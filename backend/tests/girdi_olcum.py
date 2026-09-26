"""(P248 §3a) GIRDI SINIRI OLCUMU — uc guvenlik kilidi ve girdi kilidi ortak.

Bir ucun TUM metin girdileri (govde semasi — ic ice modeller, liste/sozluk
elemanlari dahil — sorgu ve form parametreleri) tek tek gezilir ve her
metin icin su sorulur: DAR bir siniri var mi?

  DAR  = `max_length <= GENEL_UST` ya da `pattern` ya da `Literal`/Enum
         ya da `EmailStr` (email-validator 254'u asani reddeder)
  ALAN SINIFI = alanin ADINA gore tavan (`girdi_siniri.SINIF_KURALLARI`):
         "email" adli alan 254'u, "ad" adli alan 200'u asamaz.

`uc-guvenlik.tsv`deki `girdi` sutunu bu olcumden HESAPLANIR:
  -     ucun metin girdisi yok
  dar   her metin girdisi dar sinirli
  <yol:neden,...>  sinirsiz / sinif tavanini asan girdiler
"""
from __future__ import annotations

import enum
import inspect
import typing
from typing import Annotated, Literal

from app.girdi_siniri import GENEL_UST, UZUN_ISTISNALAR, sinif_tavani

#: Uzunlugu SEMADA degil, UC ICINDEKI DOGRULAYICIDA olculen girdiler —
#: (sema sinifi, alan) -> gerekce. Burada olmak "sinirsiz" demek DEGIL;
#: `test_p248_girdi_siniri.py::test_DOGRULAYICIDA_SINIRLI_canli` her birini
#: canli ucta 2049+ karakterle surup 422 aldigini olcer.
DOGRULAYICIDA_SINIRLI: dict[tuple[str, str], str] = {
    **{(s, a): "kamera URL'si: router `dogrula_url_tur`/`dogrula_restream`/"
                "`dogrula_snapshot` URL_UST_SINIR (2048) ile olcer ve KATALOG "
                "metniyle (kamera_url_cok_uzun) 422 doner — pydantic siniri bu "
                "ozel metni genel metne cevirirdi (P25)"
       for s in ("CameraCreate", "CameraUpdate")
       for a in ("stream_url", "alt_stream_url", "restream_url", "snapshot_url")},
    ("KameraTestIstek", "stream_url"):
        "kamera baglanti testi: ayni router dogrulayicisi (URL_UST_SINIR)",
    ("AnprEventIn", "ham"):
        "cihazin HAM yuku (dict[str, Any]) — tiplenemez; entegrasyon sirri ile "
        "kimlikli uc, 5 MB govde siniri + 200k taban tavan",
}


def _pydantic_mi(t) -> bool:
    from pydantic import BaseModel

    return inspect.isclass(t) and issubclass(t, BaseModel)


def _metadata_siniri(meta) -> tuple[int | None, bool]:
    ml, pat = None, False
    for m in meta:
        ml = getattr(m, "max_length", None) or ml
        pat = pat or bool(getattr(m, "pattern", None))
    return ml, pat


def _metinler(tip, meta, yol, sinif, alan, cikti, gorulen):
    """`tip` icindeki her metin konumu icin (yol, sinif, alan, max_length,
    dar_mi) ekler. `meta`: bu konuma uygulanan kisitlar."""
    from pydantic import EmailStr

    kok = typing.get_origin(tip)
    if kok is Annotated:
        taban, *ek = typing.get_args(tip)
        # Annotated[str, StringConstraints(...)] ya da Field(...)
        ek_meta = []
        for e in ek:
            ek_meta.append(e)
            ek_meta.extend(getattr(e, "metadata", []) or [])
        _metinler(taban, list(meta) + ek_meta, yol, sinif, alan, cikti, gorulen)
        return
    if kok is Literal or (inspect.isclass(tip) and issubclass(tip, enum.Enum)):
        return
    if tip is EmailStr:
        cikti.append((yol, sinif, alan, 254, True))
        return
    if tip is str:
        ml, pat = _metadata_siniri(meta)
        cikti.append((yol, sinif, alan, ml, bool(ml) or pat))
        return
    if kok in (typing.Union, getattr(__import__("types"), "UnionType", None)):
        for a in typing.get_args(tip):
            # Birlesimdeki `str | None` alan duzeyi kisiti TASIR.
            _metinler(a, meta, yol, sinif, alan, cikti, gorulen)
        return
    if kok in (list, set, frozenset, tuple, typing.Sequence):
        for a in typing.get_args(tip):
            if a is not Ellipsis:
                # Eleman: alan duzeyi max_length LISTE uzunlugudur, eleman
                # siniri DEGIL — eleman kendi Annotated kisitini tasimali.
                _metinler(a, [], yol + "[]", sinif, alan, cikti, gorulen)
        return
    if kok is dict:
        args = typing.get_args(tip)
        if args:
            _metinler(args[0], [], yol + "{k}", sinif, alan, cikti, gorulen)
            _metinler(args[1], [], yol + "{v}", sinif, alan, cikti, gorulen)
        return
    if _pydantic_mi(tip):
        if tip in gorulen:
            return
        gorulen.add(tip)
        for ad, f in tip.model_fields.items():
            _metinler(f.annotation, f.metadata, f"{yol}.{ad}" if yol else ad,
                      tip.__name__, ad, cikti, gorulen)


def _parametreler(dependant, acc):
    acc += list(dependant.query_params)
    acc += [p for p in dependant.body_params
            if type(p.field_info).__name__ in ("Form", "File")]
    for d in dependant.dependencies:
        _parametreler(d, acc)
    return acc


def uc_metinleri(route) -> list[tuple[str, str, str, int | None, bool]]:
    """Ucun tum metin girdileri: (yol, sinif, alan, max_length, dar_mi)."""
    cikti: list = []
    for p in route.dependant.body_params:
        if type(p.field_info).__name__ in ("Form", "File"):
            continue
        tip = getattr(p.field_info, "annotation", None)
        _metinler(tip, p.field_info.metadata, "", "govde", p.name, cikti, set())
    for p in _parametreler(route.dependant, []):
        fi = p.field_info
        _metinler(fi.annotation, fi.metadata, "?" + p.name, "sorgu", p.name,
                  cikti, set())
    return cikti


def ihlaller(route) -> list[str]:
    """Dar olmayan / sinif tavanini asan girdiler (istisnalar haric)."""
    out = []
    for yol, sinif, alan, ml, dar in uc_metinleri(route):
        anahtar = (sinif, alan)
        if anahtar in DOGRULAYICIDA_SINIRLI:
            continue
        if not dar:
            out.append(f"{yol}:sinirsiz")
            continue
        if ml is None:
            continue  # pattern / EmailStr
        if ml > GENEL_UST and anahtar not in UZUN_ISTISNALAR:
            out.append(f"{yol}:{ml}>genel")
            continue
        tavan = sinif_tavani(alan)
        if tavan and ml > tavan[0] and anahtar not in UZUN_ISTISNALAR:
            out.append(f"{yol}:{ml}>{tavan[1]}{tavan[0]}")
    return sorted(set(out))


def girdi_sutunu(route) -> str:
    if not uc_metinleri(route):
        return "-"
    return ",".join(ihlaller(route)) or "dar"
