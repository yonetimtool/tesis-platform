"""(P168 §2) ICRA DOSYALARI — olusturma, duzenleme, silme, durum sozlugu.

BILDIRILEN DURUM: "P167 Asama 4.8'de istendi, yapilmamis; su an yalniz
goruntuleme var."

OLCULDU, IKI KOK NEDEN BULUNDU:
 1. YAZMA UCU `require_role("admin")` idi. Yonetici sayfayi aciyor,
    "+ Yeni" dugmesi CIZILMIYOR (basilacak ama 403 alacak bir dugme
    cizmemek dogru karardi) — yani sayfa yonetici icin SALT
    GORUNTULEMEYDI.
 2. DURUM SOZLUGU brief'inkiyle ayni degildi (`acik/takipte/
    tahsil_edildi/kapandi`), yani acilir listede istenen secenekler
    HIC YOKTU.

Bu dosya ikisini de kilitler.
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


def _kisi(client, headers):
    return client.get("/users", headers=headers, params={"limit": 5}).json()["items"][0]["id"]


def _dosya(client, headers, **kw):
    govde = {"dosya_no": f"2030/{uuid.uuid4().hex[:6]}", "user_id": _kisi(client, headers)}
    govde.update(kw)
    r = client.post("/finans/icra-dosyalari", headers=headers, json=govde)
    assert r.status_code == 201, r.text
    return r.json()


# --------------------------------------------------------------------------- #
# YETKI — asil kusur buydu
# --------------------------------------------------------------------------- #
def test_YONETICI_dosya_ACABILIR(client, world):
    """Icra dosyasi acmak TESIS YONETIMI isidir, platform yoneticiligi degil.

    Borcu takip eden, avukatla konusan ve dosyayi acan kisi yoneticidir.
    """
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    d = _dosya(client, y)
    assert d["dosya_no"]


def test_YONETICI_duzenleyip_SILEBILIR(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    d = _dosya(client, y)
    r = client.patch(f"/finans/icra-dosyalari/{d['id']}", headers=y,
                     json={"avukat": "Av. Ayse Yilmaz"})
    assert r.status_code == 200 and r.json()["avukat"] == "Av. Ayse Yilmaz"
    assert client.delete(f"/finans/icra-dosyalari/{d['id']}", headers=y).status_code == 204
    assert client.delete(f"/finans/icra-dosyalari/{d['id']}", headers=y).status_code == 404


def test_DENETCI_OKUR_ama_YAZAMAZ(client, world):
    # Karsilik olcumu: yazma yoneticiye acildi diye HERKESE acilmadi.
    d_h = _headers(client, world["slug_a"], world["denetci_a"])
    assert client.get("/finans/icra-dosyalari", headers=d_h).status_code == 200
    assert client.post("/finans/icra-dosyalari", headers=d_h, json={
        "dosya_no": "X", "user_id": str(uuid.uuid4())}).status_code == 403


def test_SAHA_ROLLERI_goremez(client, world):
    for kim in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[kim])
        assert client.get("/finans/icra-dosyalari", headers=h).status_code == 403, kim


# --------------------------------------------------------------------------- #
# DURUM SOZLUGU — brief'in BES degeri
# --------------------------------------------------------------------------- #
def test_BES_DURUM_kabul_edilir(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    for durum in ("baginiz", "beklemede", "avukatta", "mahkemede", "kapandi"):
        d = _dosya(client, y, durum=durum)
        assert d["durum"] == durum, durum


def test_ESKI_SOZLUK_ARTIK_REDDEDILIR(client, world):
    """Iki sozlugu birden kabul etmek, acilir listede karsiligi OLMAYAN
    bir durumu veritabaninda tutmak olurdu."""
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/finans/icra-dosyalari", headers=y, json={
        "dosya_no": f"2031/{uuid.uuid4().hex[:6]}",
        "user_id": _kisi(client, y), "durum": "tahsil_edildi"})
    assert r.status_code == 422, r.text


def test_VARSAYILAN_durum_BEKLEMEDE(client, world):
    # Yeni acilan dosya tanimi geregi bekliyordur; kullaniciyi her
    # seferinde ayni secimi yapmaya zorlamak gereksiz bir adim olurdu.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    assert _dosya(client, y)["durum"] == "beklemede"


# --------------------------------------------------------------------------- #
# SILME — borcu YOK ETMEZ
# --------------------------------------------------------------------------- #
def test_SILME_BORCU_yok_etmez(client, world):
    """Icra dosyasi bir SUREC KAYDIDIR, defter satiri degil.

    Dosyayi silmek hicbir finansal tutari yok etmemeli — borc
    `dues_assessment`ta durur ve dosyaya KOPYALANMAZ.
    """
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    kisi = _kisi(client, y)
    d = _dosya(client, y)

    once = client.get("/dues/assessments", headers=y, params={"limit": 200}).json()
    client.delete(f"/finans/icra-dosyalari/{d['id']}", headers=y)
    sonra = client.get("/dues/assessments", headers=y, params={"limit": 200}).json()

    assert sonra["meta"]["total"] == once["meta"]["total"]
    assert kisi  # kisi kaydi da yerinde
    assert client.get("/users", headers=y, params={"limit": 200}).json()["items"]
