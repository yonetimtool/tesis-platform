"""(P171 duzeltme) GOCLER UYGULAMA KODUNA BAGLANAMAZ.

===========================================================================
BU KILIT NEDEN VAR — GERCEK OLAY
===========================================================================
Goc 0066 `from app.temizleme import zengin_temizle` yaziyordu; gerekce
"tek dogruluk kaynagi" idi. Gerekce YANLISTI ve test ortamini dusurdu:

  * `infra/docker-compose.yml` `contracts/` dizinini CANLI MOUNT eder,
    `backend/app/` ise IMAJA GOMULUDUR.
  * Yani goc dosyasi ile uygulama kodu FARKLI KANALLARDAN gelir ve
    FARKLI SURUMLERDE olabilir. Depo guncellenip imaj yeniden
    kurulmadiginda konteyner YENI gocu gorur ama ESKI kodu tasir.
  * `ModuleNotFoundError: app.temizleme` -> goc dustu -> sema 0064'te
    kaldi -> `api` (migrate'e `service_completed_successfully` ile bagli)
    HIC BASLAMADI -> `admin-web` ve `worker` de baslamadi. Ortam tamamen
    erisilemez oldu.

ASIL ILKE: GOCLER TARIHSEL KAYITTIR. Bir goc yazildigi andaki dunyayi
tarif eder ve yillar sonra ayni sonucu uretmelidir. Bugunun uygulama
koduna baglanan bir goc, o kod degistiginde (yeniden adlandirma, imza
degisikligi, silinme) GECMISI kirar.

===========================================================================
NEDEN STATIK OLCUM
===========================================================================
Uctan uca kapi (`infra/goc-sifirdan.sh`) gercek konteynerde kosuyor ama
GELISTIRICININ IMAJIYLA kosuyor: imaj o an tazeyse ithal BASARILI olur ve
kusur gorunmez — bu turda tam olarak boyle oldu, uc takim yesildi.

Statik olcum imajdan BAGIMSIZDIR: dosyanin kendisine bakar ve kusuru
ortam ne olursa olsun yakalar.
"""
from __future__ import annotations

import ast
import pathlib

#: Goclerin ithal etmesine izin verilen ust duzey paketler.
#:
#: `alembic` ve `sqlalchemy` goc altyapisinin KENDISIDIR. `nh3` bir veri
#: onarim gocunun ihtiyaci ve `requirements.txt` uzerinden imaja girer —
#: alembic'le AYNI kanaldan, yani goc dosyasiyla ayrisma riski YOK.
#: Standart kutuphane serbest.
IZINLI_PAKETLER = {
    "alembic", "sqlalchemy", "sa", "nh3",
    # (P213 §6b) `cryptography`: goc 0107 kamera parolasini AES-GCM ile
    # sifreler. Kuralin AMACI `app.*`i disarida tutmak — cunku o kod
    # imaja gomulu ve goclarla ayri surumlerde olabilir. Ucuncu parti bir
    # kutuphane bu riski TASIMAZ: `requirements`ta sabitlenmis, migrate
    # imajinda zaten kurulu ve goc dosyasi onu YALNIZ dondurulmus bir
    # bicimde (base64(nonce||ct+tag)) kullaniyor.
    "cryptography",
}

#: Standart kutuphaneden gocbaslarinda kullanilanlar.
IZINLI_STDLIB = {
    "__future__",
    "os", "re", "json", "uuid", "textwrap", "datetime", "pathlib",
    "typing", "collections", "itertools", "hashlib", "secrets", "enum",
    "decimal", "math", "string", "sys",
    # (P213 §6b) goc 0107: base64 (sifreli blob bicimi) + urllib
    # (adresten kimlik ayirma). Ikisi de standart kutuphane.
    "base64", "urllib",
}


def _goc_dosyalari() -> list[pathlib.Path]:
    for kok in ("/contracts/db/migrations/versions",
                "contracts/db/migrations/versions",
                "../contracts/db/migrations/versions"):
        d = pathlib.Path(kok)
        if d.is_dir():
            dosyalar = sorted(d.glob("*.py"))
            # BOS SONUC BIR ARIZADIR: yokluk iddialari bos kume uzerinde
            # her zaman dogrudur ve kilit hicbir sey olcmeden yesil kalir.
            assert dosyalar, f"goc dosyasi bulunamadi: {kok}"
            return dosyalar
    raise AssertionError("goc dizini bulunamadi — kilit olcum yapamiyor")


def _ithaller(dosya: pathlib.Path) -> set[str]:
    """Dosyadaki TUM ithallerin ust duzey paket adlari (ic ice olanlar dahil).

    Fonksiyon icindeki ithaller de sayilir: ilk kusur tam olarak oradaydi
    (`upgrade()` icinde `from app.temizleme import ...`) ve yalniz modul
    duzeyine bakan bir olcum onu KACIRIRDI.
    """
    agac = ast.parse(dosya.read_text(encoding="utf-8"))
    adlar: set[str] = set()
    for dugum in ast.walk(agac):
        if isinstance(dugum, ast.Import):
            for a in dugum.names:
                adlar.add(a.name.split(".")[0])
        elif isinstance(dugum, ast.ImportFrom):
            # `from . import x` (goreli) — modul None olur.
            if dugum.module and dugum.level == 0:
                adlar.add(dugum.module.split(".")[0])
            elif dugum.level:
                adlar.add(".")
    return adlar


def test_HICBIR_GOC_uygulama_kodunu_ITHAL_ETMEZ():
    ihlal: list[str] = []
    for f in _goc_dosyalari():
        for ad in _ithaller(f):
            if ad in IZINLI_PAKETLER or ad in IZINLI_STDLIB:
                continue
            ihlal.append(f"{f.name}: {ad}")
    assert not ihlal, (
        "Goc dosyasi izinsiz bir paket ithal ediyor. `app.*` KESINLIKLE "
        "yasak: `contracts/` canli mount, `backend/app/` imaja gomulu — "
        "ikisi farkli surumlerde olabilir ve goc, imaj yenilenmeden "
        "dagitildiginda DUSER.\n" + "\n".join(ihlal)
    )


def test_GOC_ZINCIRI_TEK_UCLU():
    """Iki uc (branch) ya da kopuk halka, `upgrade head`i belirsiz kilar.

    Bu, uctan uca kapinin da on kosulu: cok uclu bir zincirde `head`
    hangisi oldugu belli olmaz ve kapi yanlis seyi olcer.
    """
    revizyonlar: dict[str, str] = {}
    oncekiler: set[str] = set()
    for f in _goc_dosyalari():
        govde = f.read_text(encoding="utf-8")
        agac = ast.parse(govde)
        rev = onceki = None
        for dugum in agac.body:
            if not isinstance(dugum, ast.Assign):
                continue
            hedef = dugum.targets[0]
            if not isinstance(hedef, ast.Name):
                continue
            if isinstance(dugum.value, ast.Constant):
                if hedef.id == "revision":
                    rev = dugum.value.value
                elif hedef.id == "down_revision":
                    onceki = dugum.value.value
        assert rev, f"{f.name}: `revision` okunamadi"
        assert rev not in revizyonlar, (
            f"revizyon kimligi TEKRAR EDIYOR: {rev} "
            f"({f.name} ve {revizyonlar[rev]})"
        )
        revizyonlar[rev] = f.name
        if onceki:
            assert onceki not in oncekiler, (
                f"{f.name}: `{onceki}` iki gocun ONCEKI'si — zincir DALLANMIS"
            )
            oncekiler.add(onceki)

    uclar = set(revizyonlar) - oncekiler
    assert len(uclar) == 1, f"zincirde tek uc olmali, bulunan: {sorted(uclar)}"

    kayip = oncekiler - set(revizyonlar)
    assert not kayip, f"var olmayan revizyona baglanan goc: {sorted(kayip)}"
