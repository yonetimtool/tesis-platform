"""(P168 §5) KVKK VE YASAL METINLER — bes tur, surumleme, yeniden onay.

EN PAHALI SONUCLAR:

 1. YANLIS METNE VERILMIS ONAY. Onay TUR BASINA tutulmasaydi, gizlilik
    politikasinin 1. surumunu onaylayan kullanici aydinlatma metninin
    1. surumunu de onaylamis SAYILIRDI — hukuken yanlis ve sessiz.
 2. SURUM SAYACININ ORTAK OLMASI. Gizlilik politikasi yayinlamak
    aydinlatma metninin numarasini atlatirsa, "v3'u onayladim" cumlesi
    hangi metne ait belirsiz kalir.
 3. YENIDEN ONAYIN SESSIZCE ATLANMASI. Esasa iliskin bir degisiklikte
    kimseye sorulmamasi, hukuki bir eksikligi gorunmez kilardi — bu
    yuzden bayragin VARSAYILANI "sor"dur.
"""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _yayinla(client, h, tur="aydinlatma", **kw):
    govde = {
        "tur": tur,
        "baslik": f"{tur} metni",
        "govde": f"Metin icerigi {uuid.uuid4().hex}",
    }
    govde.update(kw)
    r = client.post("/kvkk/metin", headers=h, json=govde)
    assert r.status_code == 201, r.text
    return r.json()


# --------------------------------------------------------------------------- #
# 1. BES TUR
# --------------------------------------------------------------------------- #
def test_BES_TUR_yayinlanabilir(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    for tur in ("aydinlatma", "acik_riza", "gizlilik", "kullanim_kosullari", "cerez"):
        m = _yayinla(client, y, tur)
        assert m["tur"] == tur


def test_GECERSIZ_TUR_reddedilir(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/kvkk/metin", headers=y, json={
        "tur": "uydurma", "baslik": "X", "govde": "Y"})
    assert r.status_code == 422, r.text


def test_SURUM_TUR_BASINA_ilerler(client, world):
    """Ortak sayac olsaydi "v3'u onayladim" hangi metne ait belirsiz olurdu."""
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    a1 = _yayinla(client, y, "aydinlatma")
    g1 = _yayinla(client, y, "gizlilik")
    a2 = _yayinla(client, y, "aydinlatma")
    # Gizlilik metni yayinlamak aydinlatmanin sayacini ATLATMADI.
    assert a2["surum"] == a1["surum"] + 1
    # Ve gizlilik kendi sayacindan gitti.
    assert g1["surum"] >= 1


# --------------------------------------------------------------------------- #
# 2. YURURLUK — TURETILIR, SAKLANMAZ
# --------------------------------------------------------------------------- #
def test_YURURLUKTE_olan_EN_YUKSEK_SURUM(client, world):
    """Ayri bir `yururlukte` kolonu acsaydik iki metin ayni anda
    yururlukte olabilir ya da hicbiri olmayabilirdi."""
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    _yayinla(client, y, "cerez")
    son = _yayinla(client, y, "cerez")

    liste = client.get("/kvkk/metinler?tur=cerez", headers=y).json()
    yururlukte = [m for m in liste if m["yururlukte"]]
    # TEK BIR metin yururlukte ve o EN YUKSEK surum.
    assert len(yururlukte) == 1
    assert yururlukte[0]["surum"] == son["surum"]


def test_ESKI_SURUM_SILINMEZ(client, world):
    # Onay kayitlari eski surumlere referans verir; "hangi metne onay
    # verildi" sorusu yanitlanabilir kalmali.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    ilk = _yayinla(client, y, "kullanim_kosullari")
    _yayinla(client, y, "kullanim_kosullari")
    liste = client.get("/kvkk/metinler?tur=kullanim_kosullari", headers=y).json()
    assert any(m["surum"] == ilk["surum"] for m in liste)


def test_AYNI_GOVDE_YENIDEN_yayinlanmaz(client, world):
    # Degismemis bir metin icin herkesi yeniden onaya zorlamak, onayi
    # anlamsiz bir tikla dondururdu.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    m = _yayinla(client, y, "gizlilik")
    r = client.post("/kvkk/metin", headers=y, json={
        "tur": "gizlilik", "baslik": m["baslik"], "govde": m["govde"]})
    assert r.status_code == 409, r.text


# --------------------------------------------------------------------------- #
# 3. ONAY TUR BASINA
# --------------------------------------------------------------------------- #
def test_BIR_TURUN_ONAYI_OTEKINI_ONAYLAMAZ(client, world):
    """Bu dosyanin en pahali olcumu."""
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    s = _headers(client, world["slug_a"], world["resident_a"])
    _yayinla(client, y, "aydinlatma")
    g = _yayinla(client, y, "gizlilik")

    # Yalniz GIZLILIK onaylaniyor.
    r = client.post("/kvkk/onay", headers=s, json={"tur": "gizlilik", "surum": g["surum"]})
    assert r.status_code == 201, r.text

    assert client.get("/kvkk/durum?tur=gizlilik", headers=s).json()["onay_gerekli"] is False
    # AYDINLATMA hâlâ onay BEKLIYOR.
    assert client.get("/kvkk/durum?tur=aydinlatma", headers=s).json()["onay_gerekli"] is True


def test_ESKI_SURUME_ONAY_409(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    s = _headers(client, world["slug_a"], world["resident_a"])
    ilk = _yayinla(client, y, "cerez")
    _yayinla(client, y, "cerez")  # surum ilerledi
    r = client.post("/kvkk/onay", headers=s, json={"tur": "cerez", "surum": ilk["surum"]})
    assert r.status_code == 409, r.text


# --------------------------------------------------------------------------- #
# 4. YENIDEN ONAY BAYRAGI — brief'in istegi
# --------------------------------------------------------------------------- #
def test_YENIDEN_ONAY_GEREKMEZ_ise_ESKI_ONAY_GECERLI(client, world):
    """Bir yazim hatasi duzeltmesi 200 sakini yeniden onay ekranina
    sokmamali."""
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    s = _headers(client, world["slug_a"], world["resident_a"])
    ilk = _yayinla(client, y, "acik_riza")
    client.post("/kvkk/onay", headers=s, json={"tur": "acik_riza", "surum": ilk["surum"]})

    _yayinla(client, y, "acik_riza", yeniden_onay_gerekir=False)

    d = client.get("/kvkk/durum?tur=acik_riza", headers=s).json()
    assert d["onay_gerekli"] is False, d
    # Ama GUNCEL SURUM ilerledi ve kullanicinin onayi ESKI surumde —
    # bilgi gizlenmiyor, yalnizca yeniden SORULMUYOR.
    assert d["onayladigi_surum"] < d["guncel_surum"]


def test_VARSAYILAN_YENIDEN_ONAY_ISTER(client, world):
    """Guvenli yon SORMAKTIR: bayrak gonderilmezse yeniden sorulur."""
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    s = _headers(client, world["slug_a"], world["resident_a"])
    ilk = _yayinla(client, y, "kullanim_kosullari")
    client.post("/kvkk/onay", headers=s,
                json={"tur": "kullanim_kosullari", "surum": ilk["surum"]})

    # `yeniden_onay_gerekir` GONDERILMIYOR -> varsayilan True.
    _yayinla(client, y, "kullanim_kosullari")

    d = client.get("/kvkk/durum?tur=kullanim_kosullari", headers=s).json()
    assert d["onay_gerekli"] is True, d


def test_HIC_ONAYLAMAMIS_kullanici_HER_ZAMAN_sorulur(client, world):
    # Bayrak `False` olsa bile: metni HIC GORMEMIS birine sormamak,
    # aydinlatmanin kendisini atlamak olurdu.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    s = _headers(client, world["slug_a"], world["guard_a"])
    _yayinla(client, y, "cerez", yeniden_onay_gerekir=False)
    d = client.get("/kvkk/durum?tur=cerez", headers=s).json()
    assert d["onay_gerekli"] is True


# --------------------------------------------------------------------------- #
# 5. YETKI
# --------------------------------------------------------------------------- #
def test_METIN_OKUMA_TUM_ROLLERE_ACIK(client, world):
    # Metin kullanicinin KENDI verisi hakkindadir; okuyamamak
    # aydinlatmanin kendisini imkansiz kilardi.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    _yayinla(client, y, "gizlilik")
    for kim in ("resident_a", "guard_a", "gorevli_a"):
        h = _headers(client, world["slug_a"], world[kim])
        assert client.get("/kvkk/metin?tur=gizlilik", headers=h).status_code == 200, kim


def test_YAYINLAMA_YALNIZ_YONETIM(client, world):
    for kim in ("resident_a", "guard_a", "gorevli_a"):
        h = _headers(client, world["slug_a"], world[kim])
        r = client.post("/kvkk/metin", headers=h, json={
            "tur": "cerez", "baslik": "X", "govde": "Y"})
        assert r.status_code == 403, kim
