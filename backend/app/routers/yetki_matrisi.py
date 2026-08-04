"""Yetki matrisi (P41) — KODUN KENDISINDEN uretilir.

NEDEN ELLE LISTE DEGIL: matrisi bir sabit listede tutmak, ayni gercegi
IKINCI BIR YERDEN uretmek olurdu; bir uc `require_role`u degistirir ama
listeyi guncellemeyi unutursa panel YANLIS bir yetki tablosu gosterirdi ve
bu, "kim neye erisiyor" sorusunda guvenilmez bir kaynak demektir.

NASIL: `require_role` urettigi bagimliliga `izinli_roller` OZNITELIGI
isliyor (bkz. deps.py). Burasi FastAPI'nin `dependant` agacini gezip o
oznitelige sahip ilk bagimliligi bulur. Yani matris, isteklerin GERCEKTEN
gectigi kapinin kendisidir.

BU UCUN OLCMEDIGI SEY (durustce): `IZIN` "ayni veriyi goruyor" DEMEK
DEGILDIR. Bazi uclar bes role de aciktir ama ICERIK role gore daralir
(orn. `/cameras` sakine yalniz gorunur kameralari doner). Matris
ERISILEBILIRLIGI gosterir, handler icindeki daraltmayi GORMEZ — test
kilidi (`tests/yetki/rol-matrisi.txt`) de tam olarak bunu olcer ve bu uc
onunla AYNI kaynagi kullanir.
"""
from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, Request
from fastapi.dependencies.models import Dependant

from ..deps import require_role
from ..models import AppUser
from ..schemas import YetkiMatrisiResponse, YetkiSatiri

router = APIRouter(tags=["yetki"])

#: Matrisin sutun sirasi. Sozlesmedeki rol sirasiyla AYNI tutulur ki panel
#: ile test kilidi yan yana okunabilsin.
ROLLER: tuple[str, ...] = (
    "admin", "yonetici", "security", "tesis_gorevlisi", "resident",
    "guvenlik_amiri",
    # (P128) Denetci — panelin yetki tablosu da yedi sutunla cizilir.
    "denetci",
)

#: FastAPI'nin kendi ekledigi ve sozlesmede olmayan yollar.
_ATLANAN = {"/openapi.json", "/docs", "/docs/oauth2-redirect", "/redoc"}


def _rol_kumesi(dep: Dependant) -> tuple[frozenset[str] | None, bool]:
    """Bagimlilik agacinda ilk `izinli_roller` tasiyan cagriyi bul.

    Donus: (roller, moda_bagli). Roller None ise ucta ROL KAPISI YOKTUR —
    bu "herkese acik" demek DEGILDIR: kimlik dogrulamasi (`get_current_user`)
    yine gerekebilir. Ayrimi karistirmak, kimliksiz erisilebilir bir uc
    varmis gibi gostermek olurdu.
    """
    yigin = [dep]
    while yigin:
        d = yigin.pop()
        cagri: Any = d.call
        roller = getattr(cagri, "izinli_roller", None)
        if roller is not None:
            return roller, bool(getattr(cagri, "moda_bagli", False))
        yigin.extend(d.dependencies)
    return None, False


@router.get("/yetki-matrisi", response_model=YetkiMatrisiResponse)
async def yetki_matrisi(
    request: Request,
    _: AppUser = Depends(require_role("admin", "yonetici")),
) -> YetkiMatrisiResponse:
    """(METOT, yol) basina hangi rollerin gectigi.

    RBAC: admin + yonetici. Sakin/saha rollerine kapali — matris tum
    sistemin yetki haritasidir ve saha personeline hangi uclarin var
    oldugunu gostermek gereksiz bir kesif yuzeyi acardi.
    """
    satirlar: list[YetkiSatiri] = []
    for route in request.app.routes:
        yol = getattr(route, "path", None)
        metotlar = getattr(route, "methods", None)
        dep = getattr(route, "dependant", None)
        if not yol or not metotlar or dep is None or yol in _ATLANAN:
            continue
        roller, moda_bagli = _rol_kumesi(dep)
        for metot in sorted(m for m in metotlar if m != "HEAD"):
            satirlar.append(
                YetkiSatiri(
                    metot=metot,
                    yol=yol,
                    # Rol kapisi yoksa None doner (bkz. `_rol_kumesi`).
                    roller=sorted(roller) if roller is not None else None,
                    moda_bagli=moda_bagli,
                )
            )
    satirlar.sort(key=lambda x: (x.yol, x.metot))
    return YetkiMatrisiResponse(roller=list(ROLLER), items=satirlar)
