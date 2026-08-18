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


def _yayinla(client, h, tur="aydinlatma", tenant=None, **kw):
    """(P170 §2) YAYIN ARTIK PLATFORM YOLUNDAN.

    Tesis yuzeyindeki `POST /kvkk/metin` KALDIRILDI; metinleri platform
    yonetiyor ve hedef tenant YOLDA tasiniyor. `h` bir PLATFORM ADMIN
    basligi olmali — yonetici artik yayinlayamaz (kendi testi var).
    """
    govde = {
        "tur": tur,
        "baslik": f"{tur} metni",
        "govde": f"Metin icerigi {uuid.uuid4().hex}",
    }
    govde.update(kw)
    r = client.post(f"/tenants/{tenant}/kvkk", headers=h, json=govde)
    assert r.status_code == 201, r.text
    return r.json()


# --------------------------------------------------------------------------- #
# 1. BES TUR
# --------------------------------------------------------------------------- #
def test_BES_TUR_yayinlanabilir(client, world):
    y = _headers(client, world["slug_a"], world["admin_a"])
    for tur in ("aydinlatma", "acik_riza", "gizlilik", "kullanim_kosullari", "cerez"):
        m = _yayinla(client, y, tur, tenant=world["a"])
        assert m["tur"] == tur


def test_GECERSIZ_TUR_reddedilir(client, world):
    y = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post(f"/tenants/{world['a']}/kvkk", headers=y, json={
        "tur": "uydurma", "baslik": "X", "govde": "Y"})
    assert r.status_code == 422, r.text


def test_SURUM_TUR_BASINA_ilerler(client, world):
    """Ortak sayac olsaydi "v3'u onayladim" hangi metne ait belirsiz olurdu."""
    y = _headers(client, world["slug_a"], world["admin_a"])
    a1 = _yayinla(client, y, "aydinlatma", tenant=world["a"])
    g1 = _yayinla(client, y, "gizlilik", tenant=world["a"])
    a2 = _yayinla(client, y, "aydinlatma", tenant=world["a"])
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
    y = _headers(client, world["slug_a"], world["admin_a"])
    _yayinla(client, y, "cerez", tenant=world["a"])
    son = _yayinla(client, y, "cerez", tenant=world["a"])

    # (P170 §2) SURUM LISTESI ARTIK PLATFORM UCUNDAN.
    liste = [
        m for m in client.get(f"/tenants/{world['a']}/kvkk", headers=y).json()["metinler"]
        if m["tur"] == "cerez"
    ]
    yururlukte = [m for m in liste if m["yururlukte"]]
    # TEK BIR metin yururlukte ve o EN YUKSEK surum.
    assert len(yururlukte) == 1
    assert yururlukte[0]["surum"] == son["surum"]


def test_ESKI_SURUM_SILINMEZ(client, world):
    # Onay kayitlari eski surumlere referans verir; "hangi metne onay
    # verildi" sorusu yanitlanabilir kalmali.
    y = _headers(client, world["slug_a"], world["admin_a"])
    ilk = _yayinla(client, y, "kullanim_kosullari", tenant=world["a"])
    _yayinla(client, y, "kullanim_kosullari", tenant=world["a"])
    liste = [
        m for m in client.get(f"/tenants/{world['a']}/kvkk", headers=y).json()["metinler"]
        if m["tur"] == "kullanim_kosullari"
    ]
    assert any(m["surum"] == ilk["surum"] for m in liste)


def test_AYNI_GOVDE_YENIDEN_yayinlanmaz(client, world):
    # Degismemis bir metin icin herkesi yeniden onaya zorlamak, onayi
    # anlamsiz bir tikla dondururdu.
    y = _headers(client, world["slug_a"], world["admin_a"])
    m = _yayinla(client, y, "gizlilik", tenant=world["a"])
    r = client.post(f"/tenants/{world['a']}/kvkk", headers=y, json={
        "tur": "gizlilik", "baslik": m["baslik"], "govde": m["govde"]})
    assert r.status_code == 409, r.text


# --------------------------------------------------------------------------- #
# 3. ONAY TUR BASINA
# --------------------------------------------------------------------------- #
def test_BIR_TURUN_ONAYI_OTEKINI_ONAYLAMAZ(client, world):
    """Bu dosyanin en pahali olcumu."""
    y = _headers(client, world["slug_a"], world["admin_a"])
    s = _headers(client, world["slug_a"], world["resident_a"])
    _yayinla(client, y, "aydinlatma", tenant=world["a"])
    g = _yayinla(client, y, "gizlilik", tenant=world["a"])

    # Yalniz GIZLILIK onaylaniyor.
    r = client.post("/kvkk/onay", headers=s, json={"tur": "gizlilik", "surum": g["surum"]})
    assert r.status_code == 201, r.text

    assert client.get("/kvkk/durum?tur=gizlilik", headers=s).json()["onay_gerekli"] is False
    # AYDINLATMA hâlâ onay BEKLIYOR.
    assert client.get("/kvkk/durum?tur=aydinlatma", headers=s).json()["onay_gerekli"] is True


def test_ESKI_SURUME_ONAY_409(client, world):
    y = _headers(client, world["slug_a"], world["admin_a"])
    s = _headers(client, world["slug_a"], world["resident_a"])
    ilk = _yayinla(client, y, "cerez", tenant=world["a"])
    _yayinla(client, y, "cerez", tenant=world["a"])  # surum ilerledi
    r = client.post("/kvkk/onay", headers=s, json={"tur": "cerez", "surum": ilk["surum"]})
    assert r.status_code == 409, r.text


# --------------------------------------------------------------------------- #
# 4. YENIDEN ONAY BAYRAGI — brief'in istegi
# --------------------------------------------------------------------------- #
def test_YENIDEN_ONAY_GEREKMEZ_ise_ESKI_ONAY_GECERLI(client, world):
    """Bir yazim hatasi duzeltmesi 200 sakini yeniden onay ekranina
    sokmamali."""
    y = _headers(client, world["slug_a"], world["admin_a"])
    s = _headers(client, world["slug_a"], world["resident_a"])
    ilk = _yayinla(client, y, "acik_riza", tenant=world["a"])
    client.post("/kvkk/onay", headers=s, json={"tur": "acik_riza", "surum": ilk["surum"]})

    _yayinla(client, y, "acik_riza", tenant=world["a"], yeniden_onay_gerekir=False)

    d = client.get("/kvkk/durum?tur=acik_riza", headers=s).json()
    assert d["onay_gerekli"] is False, d
    # Ama GUNCEL SURUM ilerledi ve kullanicinin onayi ESKI surumde —
    # bilgi gizlenmiyor, yalnizca yeniden SORULMUYOR.
    assert d["onayladigi_surum"] < d["guncel_surum"]


def test_VARSAYILAN_YENIDEN_ONAY_ISTER(client, world):
    """Guvenli yon SORMAKTIR: bayrak gonderilmezse yeniden sorulur."""
    y = _headers(client, world["slug_a"], world["admin_a"])
    s = _headers(client, world["slug_a"], world["resident_a"])
    ilk = _yayinla(client, y, "kullanim_kosullari", tenant=world["a"])
    client.post("/kvkk/onay", headers=s,
                json={"tur": "kullanim_kosullari", "surum": ilk["surum"]})

    # `yeniden_onay_gerekir` GONDERILMIYOR -> varsayilan True.
    _yayinla(client, y, "kullanim_kosullari", tenant=world["a"])

    d = client.get("/kvkk/durum?tur=kullanim_kosullari", headers=s).json()
    assert d["onay_gerekli"] is True, d


def test_HIC_ONAYLAMAMIS_kullanici_HER_ZAMAN_sorulur(client, world):
    # Bayrak `False` olsa bile: metni HIC GORMEMIS birine sormamak,
    # aydinlatmanin kendisini atlamak olurdu.
    y = _headers(client, world["slug_a"], world["admin_a"])
    s = _headers(client, world["slug_a"], world["guard_a"])
    _yayinla(client, y, "cerez", tenant=world["a"], yeniden_onay_gerekir=False)
    d = client.get("/kvkk/durum?tur=cerez", headers=s).json()
    assert d["onay_gerekli"] is True


# --------------------------------------------------------------------------- #
# 5. YETKI
# --------------------------------------------------------------------------- #
def test_METIN_OKUMA_TUM_ROLLERE_ACIK(client, world):
    # Metin kullanicinin KENDI verisi hakkindadir; okuyamamak
    # aydinlatmanin kendisini imkansiz kilardi.
    y = _headers(client, world["slug_a"], world["admin_a"])
    _yayinla(client, y, "gizlilik", tenant=world["a"])
    for kim in ("resident_a", "guard_a", "gorevli_a"):
        h = _headers(client, world["slug_a"], world[kim])
        assert client.get("/kvkk/metin?tur=gizlilik", headers=h).status_code == 200, kim


# --------------------------------------------------------------------------- #
# (P170 §2) YONETIM PLATFORMA GECTI — KAPI VE OKUMA
# --------------------------------------------------------------------------- #
def test_YAYINLAMA_YALNIZ_PLATFORM_ADMIN(client, world):
    """Tesis rollerinin HICBIRI yayin yapamaz — YONETICI DE DAHIL.

    Bu turun asil degisikligi: `yonetici` eskiden yayinlayabiliyordu.
    Metinleri platform yonetir; tesis yoneticisinin kendi aydinlatma
    metnini yazmasi, hukuki sorumlulugu yazma yetkisiyle karistirmakti.
    """
    for kim in ("yonetici_a", "resident_a", "guard_a", "gorevli_a", "denetci_a"):
        h = _headers(client, world["slug_a"], world[kim])
        r = client.post(f"/tenants/{world['a']}/kvkk", headers=h, json={
            "tur": "cerez", "baslik": "X", "govde": "Y"})
        assert r.status_code == 403, kim


def test_ESKI_TESIS_YOLU_KALDIRILDI(client, world):
    """`POST /kvkk/metin` ve `GET /kvkk/metinler` ARTIK YOK.

    Uc yasasaydi, panelden kaldirilmis olmasina ragmen dogrudan cagriyla
    tesis yoneticisi metin yayinlamaya devam edebilirdi — yani kapi
    yalnizca ekranda kapanmis olurdu.
    """
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    assert client.post("/kvkk/metin", headers=y, json={
        "tur": "cerez", "baslik": "X", "govde": "Y"}).status_code == 405
    assert client.get("/kvkk/metinler", headers=y).status_code == 404


def test_PLATFORM_DURUMU_YALNIZ_ADMIN(client, world):
    for kim in ("yonetici_a", "resident_a", "denetci_a"):
        h = _headers(client, world["slug_a"], world[kim])
        r = client.get(f"/tenants/{world['a']}/kvkk", headers=h)
        assert r.status_code == 403, kim


def test_PLATFORM_DURUMU_METINLERI_VE_ONAY_SAYISINI_DONER(client, world):
    a = _headers(client, world["slug_a"], world["admin_a"])
    m = _yayinla(client, a, "gizlilik", tenant=world["a"])

    # Bir sakin onaylasin.
    r_ = _headers(client, world["slug_a"], world["resident_a"])
    assert client.post(
        "/kvkk/onay", headers=r_, json={"tur": "gizlilik", "surum": m["surum"]},
    ).status_code == 201

    d = client.get(f"/tenants/{world['a']}/kvkk", headers=a)
    assert d.status_code == 200, d.text
    govde = d.json()
    gizlilik = [x for x in govde["metinler"] if x["tur"] == "gizlilik"]
    assert gizlilik and gizlilik[0]["yururlukte"] is True
    ozet = [o for o in govde["onaylar"] if o["tur"] == "gizlilik"]
    assert ozet and ozet[0]["onaylayan"] == 1
    # KISI LISTESI DONMEZ: yonetim isi icin gereksiz bir kisisel veri akisi.
    assert "kullanicilar" not in str(govde)


def test_BILINMEYEN_TESISE_YAYIN_404(client, world):
    a = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post(f"/tenants/{uuid.uuid4()}/kvkk", headers=a, json={
        "tur": "cerez", "baslik": "X", "govde": "Y"})
    assert r.status_code == 404, r.text


def test_ONAY_GECMISIM_TUM_ROLLERE_ACIK_VE_KENDIYLE_SINIRLI(client, world):
    """Okuma yuzeyi YERINDE KALDI ve her rol icin calisir.

    Ayrica: gecmis KULLANICININ KENDISIYLE sinirlidir. Yonetici bile
    buradan baskasinin onayini goremez.
    """
    a = _headers(client, world["slug_a"], world["admin_a"])
    m = _yayinla(client, a, "kullanim_kosullari", tenant=world["a"])

    r_ = _headers(client, world["slug_a"], world["resident_a"])
    assert client.post(
        "/kvkk/onay", headers=r_,
        json={"tur": "kullanim_kosullari", "surum": m["surum"]},
    ).status_code == 201

    # Sakin KENDI onayini gorur.
    g = client.get("/kvkk/onaylarim", headers=r_)
    assert g.status_code == 200, g.text
    satir = [x for x in g.json() if x["tur"] == "kullanim_kosullari"]
    assert satir and satir[0]["surum"] == m["surum"]
    assert satir[0]["guncel_mi"] is True

    # Her rol kendi gecmisini OKUYABILIR (bos olsa bile 200).
    for kim in ("yonetici_a", "guard_a", "gorevli_a", "denetci_a"):
        h = _headers(client, world["slug_a"], world[kim])
        r = client.get("/kvkk/onaylarim", headers=h)
        assert r.status_code == 200, kim
        # BASKASININ ONAYI GORUNMEZ: sakinin onayi bu listede olmamali.
        assert not [
            x for x in r.json() if x["tur"] == "kullanim_kosullari"
        ], kim


def test_ESKIYEN_ONAY_GECMISTE_ISARETLENIR(client, world):
    """Yeni surum cikinca eski onay `guncel_mi=False` olur.

    Sessiz birakmak, kullaniciya OKUMADIGI bir metni onaylamis gibi
    gosterirdi.
    """
    a = _headers(client, world["slug_a"], world["admin_a"])
    ilk = _yayinla(client, a, "cerez", tenant=world["a"])
    r_ = _headers(client, world["slug_a"], world["resident_a"])
    client.post("/kvkk/onay", headers=r_,
                json={"tur": "cerez", "surum": ilk["surum"]})

    _yayinla(client, a, "cerez", tenant=world["a"])  # surum ilerledi

    satir = [
        x for x in client.get("/kvkk/onaylarim", headers=r_).json()
        if x["tur"] == "cerez"
    ]
    assert satir and satir[0]["guncel_mi"] is False
