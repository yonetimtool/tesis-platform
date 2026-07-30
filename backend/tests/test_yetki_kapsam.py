"""YETKI KAPSAMI — 201 operasyonun HEPSI, sozlesmeden turetilerek (tur 74).

NEDEN: `test_rls_kapsam.py` ile ayni hata sinifi, bir katman yukarida. Depoda
401 iddiasi iceren **26** satir, 403 iceren **180** satir var — ama hepsi
ELLE SECILMIS uc/rol ciftleri. "Yeni bir uc yazip auth bagimliligini koymayi
unutmak" sessizce PUBLIC bir uc demektir ve hicbir olcum bunu aramiyordu.

Sozlesme (`contracts/openapi.yaml`) global `security: [bearerAuth]` ilan
ediyor; bir operasyon `security: []` yazarak PUBLIC oldugunu BEYAN eder. Bu,
elle liste tutmadan iki yonlu bir degismez verir:

  * beyan edilmemis operasyon kimliksiz istekte 401/403 DONMELI,
  * beyan edilmis (public) operasyon kimliksiz istekte 401 DONMEMELI
    (yoksa sozlesme yalan soyluyor).

IKINCI OLCUM — ROL MATRISI KILIDI. Hangi rolun hangi uca erisebilecegi
sozlesmede yazili DEGIL, dolayisiyla "dogru" cevabi bilemeyiz. Ama
DEGISIKLIGI yakalayabiliriz: 5 rol x tum operasyonlar surulur ve sonuc
`tests/yetki/rol-matrisi.txt` dosyasindaki temel ile karsilastirilir. Yetki
davranisi degistiginde diff cikar; kasitliysa kilit guncellenir. (Tur 60'taki
yerlesim kilidiyle ayni desen.)

Kod SINIFLARI kaydedilir, ham kod degil:
  KIMLIK = 401 (kimlik yok/gecersiz)
  RED    = 403 (kimlik var, yetki yok)
  IZIN   = digerleri — istek EL HANDLER'A ULASTI (422 dogrulama, 404 bulunamadi,
           2xx basari). Yetki acisindan bunlarin hepsi "gecti"dir.

BU OLCUMUN OLCMEDIGI SEY (ilk kilidin gosterdigi): `IZIN` "ayni veriyi
goruyor" DEMEK DEGILDIR. 201 operasyonun 36'si bes rolun hepsine acik ve
uclerinde erisim ACIK AMA ICERIK ROLE GORE FARKLI:
  * `GET /reports/financial-summary` — tum roller agregati alir (seffaflik,
    kisi/daire verisi yok); `tahsilat` blogu YALNIZ admin+yonetici'ye eklenir.
  * `GET /budget/summary` — agregat ozet bilincli olarak tum rollere acik.
  * `GET /cameras` — sakin ve tesis gorevlisi `aktif` suzgecini kullanamaz;
    her durumda yalniz aktif+gorunur kameralari alir.
Yani kilit YETKILENDIRMEYI ERISILEBILIRLIK duzeyinde kilitler; handler ICINDE
role gore icerik daraltmayi GORMEZ. O katman icin ayri bir olcum gerekir.

KILIDI GUNCELLEME (imaj kodu BAKE ettigi icin iki adim):
    docker compose exec -T -e YETKI_KILIT_GUNCELLE=1 api \
        python -m pytest -q tests/test_yetki_kapsam.py::test_rol_matrisi_kilidi
    docker compose cp api:/app/tests/yetki/rol-matrisi.txt \
        ../backend/tests/yetki/rol-matrisi.txt
(Kilit KONTEYNER icine yazilir; depoya kopyalamayi atlamak "kilit guncellendi"
 sanip aslinda ESKI kilidi surdurmek demektir.)

YAN ETKI NOTU: surus mutasyon uclarina da BOS govde ile gider. Cogu 422 doner;
`POST /tenants` bos govdeyle "(Kurulum bekliyor)" tesisi YARATIR (tur 68'de
100 tanesi birikmisti). Bu yuzden surus sonunda `kurulum-bekliyor-%` tesisleri
ACIKCA silinir — conftest'in oturum temizligine guvenilmez.
"""
from __future__ import annotations

import os
import re
import uuid
from pathlib import Path

import pytest
import yaml

#: Sozlesmedeki operasyon sayisi bunun altina duserse olcum BOSA GECMIS demektir.
TABAN_OPERASYON = int(os.getenv("YETKI_TABAN_OP", "150"))

KILIT_DOSYASI = Path(__file__).resolve().parent / "yetki" / "rol-matrisi.txt"
KILIT_GUNCELLE = os.getenv("YETKI_KILIT_GUNCELLE") == "1"

METOTLAR = ("get", "post", "put", "patch", "delete")


def _sozlesme() -> dict:
    for aday in (
        Path(__file__).resolve().parents[2] / "contracts" / "openapi.yaml",
        Path("/contracts/openapi.yaml"),
    ):
        if aday.exists():
            return yaml.safe_load(aday.read_text(encoding="utf-8"))
    pytest.skip("contracts/openapi.yaml bulunamadi (sapma DEGIL, olcum yok)")


def _operasyonlar(spec: dict) -> list[tuple[str, str, bool]]:
    """(metot, yol, public_mu) uclusu — sozlesmeden, sirali."""
    out = []
    for yol, ops in (spec.get("paths") or {}).items():
        for metot, op in ops.items():
            if metot not in METOTLAR:
                continue
            public = isinstance(op, dict) and op.get("security") == []
            out.append((metot, yol, public))
    return sorted(out, key=lambda t: (t[1], t[0]))


def _yol_doldur(spec: dict, metot: str, yol: str) -> str:
    """Path parametrelerini tipine gore YER TUTUCU ile doldur.

    UUID parametreye 'x' yazmak 422 dondurur; bu, yetki kontrolunden ONCE mi
    SONRA mi oldugunu belirsiz kilar. O yuzden tip sozlesmeden okunur.
    """
    ops = spec["paths"][yol]
    parms = list(ops.get("parameters") or [])
    op = ops.get(metot)
    if isinstance(op, dict):
        parms += list(op.get("parameters") or [])
    tipler: dict[str, str] = {}
    for p in parms:
        if p.get("in") != "path":
            continue
        sema = p.get("schema") or {}
        if sema.get("type") == "integer":
            tipler[p["name"]] = "1"
        elif sema.get("format") == "uuid":
            tipler[p["name"]] = str(uuid.uuid4())
        else:
            tipler[p["name"]] = "x"
    out = yol
    for ad in re.findall(r"\{([^}]+)\}", yol):
        out = out.replace("{" + ad + "}", tipler.get(ad, str(uuid.uuid4())))
    return out


def _sinif(kod: int) -> str:
    if kod == 401:
        return "KIMLIK"
    if kod == 403:
        return "RED"
    return "IZIN"


def _istek(client, metot: str, url: str, token: str | None):
    kw: dict = {}
    if token:
        kw["headers"] = {"Authorization": f"Bearer {token}"}
    if metot in ("post", "put", "patch"):
        kw["json"] = {}
    return getattr(client, metot)(url, **kw)


@pytest.fixture
def spec():
    return _sozlesme()


# --------------------------------------------------------------------------- #
# 0. BOSA-GECME MUHAFIZI
# --------------------------------------------------------------------------- #
def test_sozlesme_operasyon_sayisi_makul(spec):
    ops = _operasyonlar(spec)
    assert len(ops) >= TABAN_OPERASYON, (
        f"sozlesmede yalniz {len(ops)} operasyon goruldu; beklenen en az "
        f"{TABAN_OPERASYON}. Ayristirma bozulduysa asagidaki testler BOSA GECER."
    )


# --------------------------------------------------------------------------- #
# 1. KIMLIKSIZ SUPURME — iki yonlu
# --------------------------------------------------------------------------- #
def test_beyan_edilmemis_her_operasyon_kimliksiz_reddediyor(client, spec):
    ops = _operasyonlar(spec)
    korumasiz = []
    for metot, yol, public in ops:
        if public:
            continue
        r = _istek(client, metot, _yol_doldur(spec, metot, yol), None)
        if r.status_code not in (401, 403):
            korumasiz.append(f"{metot.upper()} {yol} -> {r.status_code}")
    assert not korumasiz, (
        f"{len(korumasiz)} operasyon kimliksiz istegi REDDETMIYOR ve sozlesmede "
        f"`security: []` ile public BEYAN EDILMEMIS:\n  " + "\n  ".join(korumasiz)
    )


def test_public_beyan_edilenler_gercekten_erisilebilir(client, spec):
    ops = [o for o in _operasyonlar(spec) if o[2]]
    assert ops, "sozlesmede hic public operasyon yok — beyan mekanizmasi bozuk mu?"
    kilitli = []
    for metot, yol, _ in ops:
        r = _istek(client, metot, _yol_doldur(spec, metot, yol), None)
        if r.status_code == 401:
            kilitli.append(f"{metot.upper()} {yol} -> 401")
    assert not kilitli, (
        "sozlesme bu operasyonlari public BEYAN EDIYOR ama 401 donuyorlar "
        "(sozlesme yaniltici):\n  " + "\n  ".join(kilitli)
    )


# --------------------------------------------------------------------------- #
# 2. ROL MATRISI KILIDI
# --------------------------------------------------------------------------- #
def test_rol_matrisi_kilidi(client, spec, world, owner_conn):
    # Rol adlari `world` fixture'inin anahtarlarindan gelir; kimlik bilgileri
    # ORADAN okunur (conftest sabitlerini burada tekrarlamak, parolalar
    # degistiginde sessizce kopan bir ikinci kaynak olurdu).
    hesaplar = [
        ("admin", world["admin_a"]),
        ("yonetici", world["yonetici_a"]),
        ("security", world["guard_a"]),
        ("tesis_gorevlisi", world["gorevli_a"]),
        ("resident", world["resident_a"]),
    ]
    tokenlar: dict[str, str] = {}
    for rol, hesap in hesaplar:
        r = client.post(
            "/auth/login",
            json={
                "tenant_slug": world["slug_a"],
                "email": hesap["email"],
                "password": hesap["password"],
            },
        )
        assert r.status_code == 200, f"{rol} girisi basarisiz: {r.status_code} {r.text}"
        tokenlar[rol] = r.json()["access_token"]

    ops = _operasyonlar(spec)
    satirlar: list[str] = []
    try:
        for metot, yol, _public in ops:
            url = _yol_doldur(spec, metot, yol)
            siniflar = [
                _sinif(_istek(client, metot, url, tokenlar[rol]).status_code)
                for rol, _hesap in hesaplar
            ]
            satirlar.append(f"{metot.upper():6} {yol:52} " + " ".join(
                f"{s:6}" for s in siniflar))
    finally:
        # Bos govdeli POST /tenants "(Kurulum bekliyor)" tesisi yaratir.
        with owner_conn.cursor() as cur:
            cur.execute("DELETE FROM tenant WHERE slug LIKE 'kurulum-bekliyor-%'")

    baslik = "# " + " ".join(f"{r:6}" for r, _hesap in hesaplar)
    icerik = baslik + "\n" + "\n".join(satirlar) + "\n"

    if KILIT_GUNCELLE:
        KILIT_DOSYASI.parent.mkdir(parents=True, exist_ok=True)
        KILIT_DOSYASI.write_text(icerik, encoding="utf-8")
        pytest.skip(f"kilit guncellendi: {KILIT_DOSYASI} ({len(satirlar)} satir)")

    if not KILIT_DOSYASI.exists():
        pytest.skip(
            f"{KILIT_DOSYASI} yok — YETKI_KILIT_GUNCELLE=1 ile uretin"
        )

    beklenen = KILIT_DOSYASI.read_text(encoding="utf-8")
    if beklenen == icerik:
        return
    import difflib

    fark = "\n".join(
        difflib.unified_diff(
            beklenen.splitlines(), icerik.splitlines(),
            fromfile="kilit", tofile="olculen", lineterm="",
        )
    )
    pytest.fail(
        "YETKI DAVRANISI DEGISTI (rol matrisi kilidi):\n" + fark
        + "\n\nKasitliysa: YETKI_KILIT_GUNCELLE=1 pytest tests/test_yetki_kapsam.py"
    )
