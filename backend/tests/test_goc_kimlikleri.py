"""(P154) Goc revizyon kimlikleri — bicim kilidi.

NEDEN BU KILIT VAR: bu turda `0041_tesis_kodu_ve_coklu_yonetici` (33 karakter)
yazildi ve `alembic_version.version_num` sutunu `varchar(32)`dir. Sonuc:

    psycopg.errors.StringDataRightTruncation:
    value too long for type character varying(32)
    [SQL: UPDATE alembic_version SET version_num='0041_tesis_kodu_ve_coklu_yonetici']

HATANIN SINIFI ONEMLI: goc dosyasi kusursuz calisir, `upgrade()` govdesi
sorunsuz koser ve HER SEY BITTIKTEN SONRA surum damgasi yazilirken patlar.
Yani veritabani yari yolda kalir — semaya uygulanmis ama kayda gecmemis bir
goc. `alembic current` eski revizyonu gosterir ve bir sonraki calistirma
ayni gocu TEKRAR uygular.

Yerel gelistirmede degil, `infra/goc-uyum-dogrula.sh` kapisinda yakalandi.
Kapi olmasaydi bu, ilk uretim dagitiminda ortaya cikardi.

Bu test bir SATIRLIK okumadir ve saniyeler surer; veritabani istemez.
"""
from __future__ import annotations

import pathlib
import re

# `alembic_version.version_num` sutun genisligi (Alembic varsayilani).
VERSION_NUM_MAX = 32

VERSIONS = (
    pathlib.Path(__file__).resolve().parents[2]
    / "contracts" / "db" / "migrations" / "versions"
)

_REVISION = re.compile(r'^revision\s*=\s*["\']([^"\']+)["\']', re.M)
_DOWN = re.compile(r'^down_revision\s*=\s*["\']([^"\']+)["\']', re.M)


def _kimlikler() -> dict[str, pathlib.Path]:
    bulunan: dict[str, pathlib.Path] = {}
    for yol in sorted(VERSIONS.glob("[0-9]*.py")):
        m = _REVISION.search(yol.read_text(encoding="utf-8"))
        assert m, f"{yol.name}: `revision = ...` satiri okunamadi"
        bulunan[m.group(1)] = yol
    return bulunan


def test_revizyon_kimligi_32_KARAKTERI_ASMAZ():
    """Asan kimlik, gocun SONUNDA surum damgasi yazilirken patlar."""
    uzunlar = [
        f"{yol.name}: {rev!r} ({len(rev)} karakter)"
        for rev, yol in _kimlikler().items()
        if len(rev) > VERSION_NUM_MAX
    ]
    assert not uzunlar, (
        "alembic_version.version_num varchar(32); asagidaki kimlik(ler) "
        f"sigmaz ve goc YARIDA kalir:\n  " + "\n  ".join(uzunlar)
    )


def test_down_revision_zinciri_KOPUK_DEGIL():
    """Her `down_revision` var olan bir revizyonu gostermeli.

    Yazim hatasi (`0040_tetikleyici_searchpath` gibi) alembic'te
    "Can't locate revision" ile patlar ve mesaj hangi DOSYADA oldugunu
    soylemez; burada dosya adiyla birlikte soylenir.
    """
    kimlikler = _kimlikler()
    kopuk = []
    for yol in sorted(VERSIONS.glob("[0-9]*.py")):
        m = _DOWN.search(yol.read_text(encoding="utf-8"))
        if m and m.group(1) not in kimlikler:
            kopuk.append(f"{yol.name}: down_revision={m.group(1)!r} yok")
    assert not kopuk, "\n  ".join(kopuk)


def test_TEK_head_var():
    """Iki head, `upgrade head`i belirsiz kilar ve dagitim rastgele birini secer."""
    kimlikler = _kimlikler()
    gosterilen = set()
    for yol in kimlikler.values():
        m = _DOWN.search(yol.read_text(encoding="utf-8"))
        if m:
            gosterilen.add(m.group(1))
    headler = sorted(set(kimlikler) - gosterilen)
    assert len(headler) == 1, f"tek head bekleniyordu, bulunan: {headler}"
