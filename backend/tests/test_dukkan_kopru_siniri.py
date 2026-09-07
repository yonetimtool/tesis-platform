"""(DUKKAN F1) KOPRU SINIRI — Dukkan, Yonetiyor'u yalniz `kopru.py`den gorur.

===========================================================================
NE ZORLANIYOR
===========================================================================
Kullanicinin S3 sartlari birebir:
  * Kopru fonksiyonlari TEK BIR DOSYADA toplansin, sinir gorunur olsun
  * Yalniz OKUMA yapsin, yazma fonksiyonu hic bulunmasin
  * Her fonksiyon ne dondurdugunu acikca belgelesin
  * Dukkan kodu Yonetiyor modellerini DOGRUDAN ithal etmesin
  * "Bu sinirI olcen bir test yaz: Dukkan modullerinde Yonetiyor modeli
    import'u varsa test dussun"

===========================================================================
NEDEN AST, NEDEN `grep` DEGIL
===========================================================================
Metin aramasi yorum satirindaki bir ornegi de yakalar ve yanlis alarm
uretir; yanlis alarm ureten kilit, bir sure sonra kapatilan kilittir.
AST yalnizca GERCEK `import` dugumlerine bakiyor.

Ayni yaklasim `test_goc_bagimsizligi.py`de de kullaniliyor (gocler
`app.*` ithal edemez) ve orada ise yaradigi olculdu: goc 0107
`app.kamera_kimlik` ithal edip TUM zinciri dusurmustu.
"""
from __future__ import annotations

import ast
import pathlib

import pytest

DUKKAN_DIZINI = pathlib.Path(__file__).resolve().parents[1] / "app" / "dukkan"

# Yonetiyor'un ic yapisi. Dukkan bunlari ithal ederse sinir delinmis olur.
YASAK_MODULLER = {
    "models",      # Yonetiyor tablolari
    "db",          # app_rw engine'i
    "routers",     # Yonetiyor uclari
    "deps",        # Yonetiyor bagimliliklari
    "crud_helpers",
    "borclandirma",
    "defter",
    "finans",
}

# TEK ISTISNA. Sinirin gorunur olmasinin bedeli bu: tek bir dosya, tek bir
# istisna. Ikinci bir istisna eklenmek istenirse bu testi degistirmek
# gerekir — yani karar BILINCLI olmak zorunda kalir.
ISTISNA = "kopru.py"


def _dukkan_dosyalari() -> list[pathlib.Path]:
    return sorted(DUKKAN_DIZINI.rglob("*.py"))


def test_dukkan_dizini_VAR():
    """Kalan testler dosya bulamazsa BOS YERE yesil yanar."""
    assert DUKKAN_DIZINI.is_dir(), f"{DUKKAN_DIZINI} yok"
    assert _dukkan_dosyalari(), "dukkan paketinde hic .py dosyasi yok"


def _ithal_edilen_yonetiyor_modulleri(kaynak: str) -> set[str]:
    """Dosyadaki `app.<X>` / `..<X>` ithallerinden YASAK olanlari doner."""
    agac = ast.parse(kaynak)
    bulunan: set[str] = set()
    for dugum in ast.walk(agac):
        if isinstance(dugum, ast.ImportFrom):
            # `from ..models import X`  -> level=2, module='models'
            # `from app.models import X` -> level=0, module='app.models'
            modul = dugum.module or ""
            if dugum.level >= 2:
                kok = modul.split(".")[0]
            elif modul.startswith("app."):
                kok = modul.split(".")[1]
            else:
                continue
            if kok in YASAK_MODULLER:
                bulunan.add(kok)
        elif isinstance(dugum, ast.Import):
            for ad in dugum.names:
                if ad.name.startswith("app."):
                    kok = ad.name.split(".")[1]
                    if kok in YASAK_MODULLER:
                        bulunan.add(kok)
    return bulunan


@pytest.mark.parametrize(
    "dosya", _dukkan_dosyalari(), ids=lambda p: p.name
)
def test_dukkan_modulu_YONETIYORU_ITHAL_ETMEZ(dosya: pathlib.Path):
    """ASIL KILIT. `kopru.py` disinda hicbir Dukkan modulu Yonetiyor'un
    ic yapisina uzanamaz."""
    bulunan = _ithal_edilen_yonetiyor_modulleri(dosya.read_text())
    if dosya.name == ISTISNA:
        # Kopru ithal EDEBILIR; etmiyorsa da bir sey soylemiyoruz.
        return
    assert not bulunan, (
        f"{dosya.name} Yonetiyor modullerini DOGRUDAN ithal ediyor: "
        f"{sorted(bulunan)}. Sinir `kopru.py`den gecmeli — orasi tek kapi "
        "ve orada ne alindigi belgeli. Dogrudan ithal, o gorunurlugu yok eder."
    )


def test_KOPRU_yalniz_OKUMA_yapar():
    """Kullanicinin sarti: 'yazma fonksiyonu hic bulunmasin'.

    Kopruye bir gun yazma eklenirse, Dukkan Yonetiyor verisini DEGISTIRIR
    hale gelir — kisitin en acik ihlali. Bu test onu yakalar.
    """
    kaynak = (DUKKAN_DIZINI / ISTISNA).read_text()
    agac = ast.parse(kaynak)

    # SQLAlchemy yazma cagrilari: insert()/update()/delete() ve
    # session.add/add_all/merge/delete/flush/commit.
    YASAK_CAGRI = {"insert", "update", "delete", "add", "add_all", "merge",
                   "flush", "commit", "execute_many"}
    ihlaller: list[str] = []
    for dugum in ast.walk(agac):
        if isinstance(dugum, ast.Call):
            f = dugum.func
            ad = f.attr if isinstance(f, ast.Attribute) else (
                f.id if isinstance(f, ast.Name) else None)
            if ad in YASAK_CAGRI:
                ihlaller.append(f"{ad}() satir {dugum.lineno}")

    assert not ihlaller, (
        f"kopru.py YAZMA yapiyor: {ihlaller}. Kopru SALT OKUNUR olmali."
    )

    # Ham SQL ile yazma da kapali olsun.
    buyuk = kaynak.upper()
    for anahtar in ("INSERT INTO", "UPDATE ", "DELETE FROM"):
        # Yalnizca metin degismezleri icinde arıyoruz; aciklamalarda
        # gecen kelimeler yanlis alarm uretmesin diye AST'ten string
        # sabitlerini topluyoruz.
        sabitler = [
            d.value.upper()
            for d in ast.walk(agac)
            if isinstance(d, ast.Constant) and isinstance(d.value, str)
        ]
        # Docstring'ler de sabit; onlari disla (fonksiyon/modul govdesi).
        dokumanlar = set()
        for d in ast.walk(agac):
            if isinstance(d, (ast.Module, ast.FunctionDef, ast.AsyncFunctionDef,
                              ast.ClassDef)):
                dok = ast.get_docstring(d)
                if dok:
                    dokumanlar.add(dok.upper())
        for s in sabitler:
            if s in dokumanlar:
                continue
            assert anahtar not in s, f"kopru.py'de ham yazma SQL'i: {anahtar}"


def test_KOPRU_fonksiyonlari_BELGELI():
    """Kullanicinin sarti: 'her fonksiyon ne dondurdugunu acikca belgelesin'."""
    agac = ast.parse((DUKKAN_DIZINI / ISTISNA).read_text())
    eksik: list[str] = []
    for dugum in agac.body:
        if isinstance(dugum, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if dugum.name.startswith("_"):
                continue
            dok = ast.get_docstring(dugum)
            if not dok or "Doner" not in dok:
                eksik.append(dugum.name)
    assert not eksik, (
        f"Kopru fonksiyonlarinda 'Doner:' aciklamasi yok: {eksik}. "
        "Kopru dar bir arayuz; ne dondurdugu okunarak anlasilmali."
    )


def test_KOPRU_DAR_kalsin():
    """Fonksiyon sayisi sinirli. Kopru genisledikce sinir bulaniklasir.

    Sinir 5: bugun 2 fonksiyon var. Ucuncuyu eklemek serbest; besinciyi
    asmak bu testi degistirmeyi gerektirir — yani "kopru buyuyor" karari
    bilincli verilir.
    """
    agac = ast.parse((DUKKAN_DIZINI / ISTISNA).read_text())
    fonksiyonlar = [
        d.name for d in agac.body
        if isinstance(d, (ast.FunctionDef, ast.AsyncFunctionDef))
        and not d.name.startswith("_")
    ]
    assert len(fonksiyonlar) <= 5, (
        f"Koprude {len(fonksiyonlar)} fonksiyon var: {fonksiyonlar}. "
        "Her yeni fonksiyon icin once sunu sor: Dukkan bunu gercekten "
        "Yonetiyor'dan mi almali, yoksa kendi kaydinda mi tutmali?"
    )


# ===================================================================== #
# KOPRU RLS'E TABI — atlamaz
# ===================================================================== #

def test_KOPRU_RLS_BAGLAMI_KURUYOR():
    """Kopru `set_tenant` cagirmali.

    ==================================================================
    BU TEST NEDEN VAR — OLCULEN KUSUR
    ==================================================================
    Ilk yazimda `set_tenant` YOKTU ve `/dukkan/auth/yonetiyor` 500
    veriyordu:  `invalid input syntax for type uuid: ""`.
    `app_user` ve `tenant` FORCE RLS altinda; politika
    `current_setting('app.current_tenant_id')::uuid` okuyor ve deger
    kurulmadiginda bos dizge cast'i patliyor.

    Duzeltme bir GUVENLIK KAZANCIYDI, sadece bir hata giderme degil:
    kopru artik RLS'i ATLAMIYOR, ONA TABI. Yani yalnizca KENDISINE
    VERILEN tesisin satirlarini gorebiliyor. Owner baglantisiyla ya da
    RLS'i atlayarak okusaydi, jetondaki `tenant_id` ile oynayan biri
    baska bir tesisin kullanicisini okuyabilirdi.

    Bu kilit, birinin ileride "sorgu zaten tenant_id ile filtreliyor,
    set_tenant gereksiz" diye satiri silmesini engelliyor: filtre
    UYGULAMA katmanindadir ve bir gun unutulabilir; RLS veritabanindadir.
    """
    import ast

    kaynak = (DUKKAN_DIZINI / ISTISNA).read_text()
    agac = ast.parse(kaynak)

    for dugum in agac.body:
        if not isinstance(dugum, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        if dugum.name.startswith("_") or dugum.name == "yonetiyor_oturumu":
            continue
        cagrilar = {
            d.func.id if isinstance(d.func, ast.Name) else
            (d.func.attr if isinstance(d.func, ast.Attribute) else None)
            for d in ast.walk(dugum) if isinstance(d, ast.Call)
        }
        assert "set_tenant" in cagrilar, (
            f"kopru fonksiyonu `{dugum.name}` RLS baglamini KURMUYOR. "
            "Tenant-kapsamli tablo okuyan her kopru fonksiyonu "
            "`set_tenant` cagirmali — aksi halde ya 500 verir ya da "
            "(RLS bir gun gevsetilirse) BASKA TESISIN verisini okur."
        )
