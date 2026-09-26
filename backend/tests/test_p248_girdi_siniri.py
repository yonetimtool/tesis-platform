"""(P248 §3a) GIRDI UZUNLUK SINIRI KILIDI — sunucu tarafi (asil koruma).

Kullanici: "Metin alanlarina istenildigi kadar yazilabiliyor." Istemcide
`maxLength` kullanicinin fazlasini YAZAMAMASI icindir; atlatilabilir (eski
surum, API istemcisi, yapistirma betigi). Asil koruma SUNUCUDADIR.

KILITLER
  1. Her ucun her metin girdisi (govde — ic ice, liste/sozluk elemani
     dahil — sorgu, form) DAR sinirli ve adinin sinif tavanini asmiyor
     (`tests/girdi_olcum.py`, `app/girdi_siniri.py`). Yeni bir uc
     sinirsiz serbest metinle gelirse bu test ve uc guvenlik kilidindeki
     `girdi` sutunu KIRMIZI olur.
  2. Istisna listeleri bayat degil (olmayan alana gerekce yazilmaz).
  3. DB'deki `length(kolon) <= n` CHECK kisitlari ile sema sinirlari
     TUTARLI (sema DAHA GENIS olursa kullanici 500/genel hata alirdi).
  4. CANLI: sinir asimi 422 + KULLANICININ DILINDE alan+sinir soyleyen
     mesaj; dogrulayicida sinirli URL alanlari 422 (500 degil).
"""
from __future__ import annotations

import re

import pytest

from .girdi_olcum import DOGRULAYICIDA_SINIRLI, girdi_sutunu, ihlaller, uc_metinleri


def _rotalar():
    from fastapi.routing import APIRoute

    from app.main import app

    return [r for r in app.routes if isinstance(r, APIRoute)]


# ================================ STATIK ==================================== #
def test_TUM_METIN_GIRDILERI_DAR_SINIRLI():
    kotu = {
        f"{','.join(sorted(r.methods))} {r.path}": ihlaller(r)
        for r in _rotalar() if ihlaller(r)
    }
    assert not kotu, (
        "Dar siniri olmayan / sinif tavanini asan metin girdileri:\n  "
        + "\n  ".join(f"{k}: {v}" for k, v in sorted(kotu.items()))
        + "\nCozum: Field(max_length=_G.<SINIF>) (app/girdi_siniri.py). "
        "Bilincli istisna: gerekcesiyle UZUN_ISTISNALAR / DOGRULAYICIDA_SINIRLI."
    )


def test_KAPSAM_gercekten_olculuyor():
    """Olcum bos donerse kilit HICBIR SEY kilitlemez — ornek alanlar gorunmeli."""
    metinler = {(s, a) for r in _rotalar() for _, s, a, _, _ in uc_metinleri(r)}
    for beklenen in [("ShiftCreate", "ad"), ("sorgu", "q"),
                     ("IceAktarimSatir", "degerler"), ("TalepOlustur", "il_slug")]:
        assert beklenen in metinler, beklenen
    assert len(metinler) > 400


from app.schemas import BaseModel as _TabanModel  # noqa: E402


class SahteGovde(_TabanModel):
    """Modul duzeyinde: `from __future__ import annotations` altinda FastAPI
    yerel sinifi cozemez."""

    aciklama: str
    etiketler: list[str] = []


def test_OLCUM_sinirsiz_alani_yakalar():
    """Gecici ihlal: sinirsiz bir `str` alanli sahte uc KIRMIZI uretmeli."""
    from fastapi import FastAPI
    from fastapi.routing import APIRoute

    uygulama = FastAPI()

    @uygulama.post("/sahte")
    async def sahte(g: SahteGovde, q: str | None = None):  # noqa: ARG001
        return {}

    rota = next(r for r in uygulama.routes if isinstance(r, APIRoute))
    assert set(ihlaller(rota)) == {"aciklama:sinirsiz", "etiketler[]:sinirsiz",
                                   "?q:sinirsiz"}
    assert girdi_sutunu(rota) != "dar"


def test_ISTISNALAR_BAYAT_DEGIL():
    from app.girdi_siniri import UZUN_ISTISNALAR

    var = {(s, a) for r in _rotalar() for _, s, a, _, _ in uc_metinleri(r)}
    bayat = sorted((set(DOGRULAYICIDA_SINIRLI) | set(UZUN_ISTISNALAR)) - var)
    assert not bayat, f"artik olmayan alana istisna: {bayat}"


def test_UC_GUVENLIK_KILIDI_girdi_sutunu_dar():
    """`uc-guvenlik.tsv`deki `girdi` sutunu `-`/`dar` disinda deger tasiyamaz."""
    from .test_p247_uc_guvenlik import _oku

    kotu = [f"{m} {y}: {k['girdi']}" for (m, y), k in _oku().items()
            if k.get("girdi") not in ("-", "dar")]
    assert not kotu, kotu


# ============================ DB TUTARLILIGI ================================ #
_CHECK = re.compile(r"length\((?:btrim\()?\(?([a-z_]+)\)?\)?\)?\s*<=\s*(\d+)")


def _pascal(tablo: str) -> str:
    return "".join(p.capitalize() for p in tablo.split("_"))


def test_DB_CHECK_kisitlari_ile_sema_tutarli(owner_conn):
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT conrelid::regclass::text, pg_get_constraintdef(oid) "
            "FROM pg_constraint WHERE contype = 'c' "
            "AND pg_get_constraintdef(oid) ~* 'length\\(' "
            "AND connamespace = 'public'::regnamespace"
        )
        kisitlar = [(t, int(n), kol) for t, d in cur.fetchall()
                    for kol, n in _CHECK.findall(d)]
    assert kisitlar, "CHECK kisiti okunamadi — olcum bozuk"
    alanlar = [(s, a, ml) for r in _rotalar() for _, s, a, ml, _ in uc_metinleri(r)]
    tasan = []
    for tablo, n, kol in kisitlar:
        onek = _pascal(tablo)
        for s, a, ml in alanlar:
            if a == kol and s.startswith(onek) and ml and ml > n:
                tasan.append(f"{s}.{a} max_length={ml} > {tablo}.{kol} CHECK {n}")
    assert not tasan, "Sema DB kisitindan GENIS (kullanici 422 yerine hata alir):\n" \
        + "\n".join(sorted(set(tasan)))


# ================================ CANLI ===================================== #
def _headers(client, slug, cred, dil="tr"):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}",
            "Accept-Language": dil}


@pytest.mark.parametrize("dil,parca", [
    ("tr", "en fazla 100 karakter"),
    ("en", "at most 100 characters"),
    ("de", "höchstens 100 Zeichen"),
])
def test_CANLI_sinir_asimi_KULLANICI_DILINDE(client, world, dil, parca):
    h = _headers(client, world["slug_a"], world["admin_a"], dil)
    r = client.post("/shifts", headers=h, json={
        "ad": "V" * 101, "baslangic_saat": "08:00", "bitis_saat": "16:00"})
    assert r.status_code == 422, r.text
    hata = r.json()["error"]
    assert hata["code"] == "validation_error"
    assert parca in hata["message"] and "'ad'" in hata["message"], hata


def test_CANLI_sinirda_kabul(client, world):
    """Sinir DAHIL: tam 100 karakter kabul edilir (off-by-one yok)."""
    h = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/shifts", headers=h, json={
        "ad": "V" * 100, "baslangic_saat": "08:00", "bitis_saat": "16:00"})
    assert r.status_code in (200, 201), r.text


def test_CANLI_sorgu_parametresi_sinirli(client, world):
    h = _headers(client, world["slug_a"], world["admin_a"])
    r = client.get("/users", headers=h, params={"q": "x" * 101})
    assert r.status_code == 422, r.text
    assert "'q'" in r.json()["error"]["message"]


@pytest.mark.parametrize("alan", ["stream_url", "snapshot_url", "restream_url"])
def test_DOGRULAYICIDA_SINIRLI_canli(client, world, alan):
    """Semada max_length YOK ama router olcer: 422, asla 500."""
    h = _headers(client, world["slug_a"], world["admin_a"])
    govde = {"ad": "K", "stream_url": "rtsp://10.0.0.1/a", "tur": "rtsp"}
    govde[alan] = ("rtsp://10.0.0.1/" if alan == "stream_url" else "https://x.example/") \
        + "a" * 3000
    r = client.post("/cameras", headers=h, json=govde)
    assert r.status_code == 422, r.text
