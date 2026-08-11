"""Yonetisim modulleri (P33) — karar defteri, dokuman.

(P154 / Asama 8) Site aktarim buradan cikti: `test_ice_aktarim.py`.
"""
from __future__ import annotations

import uuid

import pytest


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _sfx() -> str:
    return uuid.uuid4().hex[:6]


@pytest.fixture
def adm(client, world):
    return _headers(client, world["slug_a"], world["admin_a"])


# ============================== KARAR DEFTERI =============================== #
def test_karar_crud_ve_UYELER_ayri_tabloda(client, adm):
    """Uyeleri tek metin sutununa virgulle yazmak, "bu karara kim katildi"
    sorgusunu metin aramasina cevirirdi."""
    no = f"2026/{_sfx()}"
    r = client.post("/karar-defteri", headers=adm, json={
        "karar_no": no, "konu": "Asansör bakımı",
        "metin": "Asansör bakım sözleşmesi yenilenmesine karar verilmiştir.",
        "baskan_ad": "Ali Başkan",
        "uyeler": [{"ad": "Ayşe Üye", "gorev": "Muhasip"},
                   {"ad": "Mehmet Üye"}],
    })
    assert r.status_code == 201, r.text
    assert len(r.json()["uyeler"]) == 2
    assert {u["ad"] for u in r.json()["uyeler"]} == {"Ayşe Üye", "Mehmet Üye"}

    kid = r.json()["id"]
    liste = client.get("/karar-defteri", headers=adm).json()["items"]
    kayit = next(k for k in liste if k["id"] == kid)
    assert len(kayit["uyeler"]) == 2


def test_uye_listesi_TAMAMEN_degistirilir(client, adm):
    """Kismi ekleme/cikarma, "uyeyi cikardim mi ekledim mi" belirsizligini
    istemciye birakirdi."""
    kid = client.post("/karar-defteri", headers=adm, json={
        "karar_no": f"2026/{_sfx()}", "konu": "K", "metin": "M",
        "uyeler": [{"ad": "A"}, {"ad": "B"}, {"ad": "C"}],
    }).json()["id"]
    r = client.patch(f"/karar-defteri/{kid}", headers=adm,
                     json={"uyeler": [{"ad": "D"}]})
    assert r.status_code == 200
    assert [u["ad"] for u in r.json()["uyeler"]] == ["D"]
    # Uyeler GONDERILMEZSE dokunulmaz.
    r2 = client.patch(f"/karar-defteri/{kid}", headers=adm, json={"konu": "Yeni"})
    assert [u["ad"] for u in r2.json()["uyeler"]] == ["D"]


def test_karar_no_TEK(client, adm):
    no = f"2026/{_sfx()}"
    assert client.post("/karar-defteri", headers=adm, json={
        "karar_no": no, "konu": "K", "metin": "M"}).status_code == 201
    assert client.post("/karar-defteri", headers=adm, json={
        "karar_no": no, "konu": "K2", "metin": "M2"}).status_code == 409


def test_karar_PDF_METIN_sablonuyla(client, adm):
    """Karar bir YAZIDIR: tablo sablonuna sikistirmak metni hucrelere
    bolerdi."""
    kid = client.post("/karar-defteri", headers=adm, json={
        "karar_no": f"2026/{_sfx()}", "konu": "Genel Kurul",
        "metin": "Karar metni burada.", "baskan_ad": "Başkan",
        "uyeler": [{"ad": "Üye Bir", "gorev": "Kâtip"}],
    }).json()["id"]
    r = client.get(f"/karar-defteri/{kid}/pdf", headers=adm)
    assert r.status_code == 200
    assert r.content[:5] == b"%PDF-"
    assert "attachment" in r.headers["content-disposition"]


def test_karar_silinince_UYELER_de_gider(client, adm, owner_conn):
    kid = client.post("/karar-defteri", headers=adm, json={
        "karar_no": f"2026/{_sfx()}", "konu": "K", "metin": "M",
        "uyeler": [{"ad": "X"}]}).json()["id"]
    assert client.delete(f"/karar-defteri/{kid}", headers=adm).status_code == 204
    with owner_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM karar_uyesi WHERE karar_id = %s", (kid,))
        assert cur.fetchone()[0] == 0


# ============================== DOKUMAN ===================================== #
def test_dokuman_kaydi_ve_liste(client, adm):
    anahtar = f"t/dokuman/{_sfx()}.pdf"
    r = client.post("/dokumanlar", headers=adm, json={
        "ad": "Yönetim Planı", "obje_anahtari": anahtar,
        "icerik_tipi": "application/pdf", "boyut_bayt": 120000})
    assert r.status_code == 201, r.text
    assert r.json()["yukleyen_ad"]

    liste = client.get("/dokumanlar", headers=adm).json()["items"]
    assert anahtar in [d["obje_anahtari"] for d in liste]
    assert client.delete(f"/dokumanlar/{r.json()['id']}",
                         headers=adm).status_code == 204


def test_dokuman_BOYUT_SINIRI_25MB(client, adm):
    """Daha buyugu presign akisinda zaman asimina ve mobilde bellek
    baskisina yol acar."""
    assert client.post("/dokumanlar", headers=adm, json={
        "ad": "Buyuk", "obje_anahtari": f"t/{_sfx()}",
        "boyut_bayt": 26_214_401}).status_code == 422
    assert client.post("/dokumanlar", headers=adm, json={
        "ad": "Sinirda", "obje_anahtari": f"t/{_sfx()}",
        "boyut_bayt": 26_214_400}).status_code == 201


def test_ayni_obje_anahtari_409(client, adm):
    anahtar = f"t/{_sfx()}"
    assert client.post("/dokumanlar", headers=adm, json={
        "ad": "A", "obje_anahtari": anahtar}).status_code == 201
    assert client.post("/dokumanlar", headers=adm, json={
        "ad": "B", "obje_anahtari": anahtar}).status_code == 409


# ============================== SITE AKTAR ================================== #
# (P154 / Asama 8) Bu bolumun testleri `test_ice_aktarim.py`ye TASINDI —
# uc ICE AKTARIM CATISINA devredildi. Olculen garantiler kaybolmadi:
# onizleme yazmaz, satir bazli hata raporu tum islemi dusurmez, sablon
# alanlari bildirilir. Cati ustune GERI ALMA ve iki tur daha (acilis
# bakiyesi, arac) eklendi.


# ============================ IS TAKIBI GENISLETMESI ======================== #
def test_talep_UNIT_ONCELIK_PERSONEL_alanlari(client, adm, world):
    """Denetim omurganin ZATEN VAR OLDUGUNU gosterdi: birlestirme degil
    GENISLETME yapildi — `complaint` uc alan kazandi."""
    u = client.post("/units", headers=adm,
                    json={"no": f"IT-{_sfx()}", "blok": "A"}).json()
    personel = client.post("/personel-kayitlari", headers=adm,
                           json={"ad": "Tesisatçı Hasan", "gorev": "Teknik"})
    assert personel.status_code == 201, personel.text
    personel = personel.json()

    sakin = _headers(client, world["slug_a"], world["resident_a"])
    t = client.post("/complaints", headers=sakin,
                    json={"baslik": "Musluk akıtıyor",
                          "mesaj": "Mutfak musluğu damlıyor",
                          "unit_id": u["id"]})
    assert t.status_code == 201, t.text
    assert t.json()["unit_id"] == u["id"]
    assert t.json()["oncelik"] == "normal", "varsayilan oncelik"
    tid = t.json()["id"]

    r = client.patch(f"/complaints/{tid}", headers=adm, json={
        "oncelik": "acil", "atanan_personel_id": personel["id"]})
    assert r.status_code == 200, r.text
    assert r.json()["oncelik"] == "acil"
    assert r.json()["atanan_personel_id"] == personel["id"]
    # Adlar LISTEDE de dolu gelir (istemci daire basina istek atmasin).
    assert r.json()["atanan_personel_ad"] == "Tesisatçı Hasan"
    assert r.json()["unit_no"] == u["no"]
    # DURUM DEGISMEDI: is takibi alanlari yasam dongusune dokunmaz.
    assert r.json()["durum"] == "acik"


def test_oncelik_ve_daire_SUZGECI(client, adm, world):
    u = client.post("/units", headers=adm,
                    json={"no": f"SZ-{_sfx()}", "blok": "A"}).json()
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    tid = client.post("/complaints", headers=sakin, json={
        "baslik": "Süzgeç", "mesaj": "m", "unit_id": u["id"]}).json()["id"]
    client.patch(f"/complaints/{tid}", headers=adm, json={"oncelik": "yuksek"})

    idler = [c["id"] for c in client.get(
        "/complaints", headers=adm, params={"oncelik": "yuksek"}).json()["items"]]
    assert tid in idler
    idler = [c["id"] for c in client.get(
        "/complaints", headers=adm, params={"unit_id": u["id"]}).json()["items"]]
    assert idler == [tid]
    idler = [c["id"] for c in client.get(
        "/complaints", headers=adm, params={"oncelik": "dusuk"}).json()["items"]]
    assert tid not in idler


def test_talep_guncelleme_YALNIZ_YONETIM(client, adm, world):
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    tid = client.post("/complaints", headers=sakin,
                      json={"baslik": "R", "mesaj": "m"}).json()["id"]
    assert client.patch(f"/complaints/{tid}", headers=sakin,
                        json={"oncelik": "acil"}).status_code == 403


def test_talep_guncelleme_DOGRULAMALARI(client, adm, world):
    """Var olmayan daire/personel SESSIZCE yazilsaydi, is emri hicbir zaman
    ulasmayacagi bir kisiye atanmis gorunurdu."""
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    tid = client.post("/complaints", headers=sakin,
                      json={"baslik": "D", "mesaj": "m"}).json()["id"]
    yok = str(uuid.uuid4())
    assert client.patch(f"/complaints/{tid}", headers=adm,
                        json={"unit_id": yok}).status_code == 422
    assert client.patch(f"/complaints/{tid}", headers=adm,
                        json={"atanan_personel_id": yok}).status_code == 422
    assert client.patch(f"/complaints/{tid}", headers=adm,
                        json={}).status_code == 422
    assert client.patch(f"/complaints/{tid}", headers=adm,
                        json={"oncelik": "cok_acil"}).status_code == 422


def test_rbac(client, world):
    for rol, izin in [("admin_a", True), ("yonetici_a", True),
                      ("guard_a", False), ("resident_a", False)]:
        h = _headers(client, world["slug_a"], world[rol])
        r = client.get("/karar-defteri", headers=h)
        assert (r.status_code == 200) is izin, (rol, r.status_code)
        d = client.get("/dokumanlar", headers=h)
        assert (d.status_code == 200) is izin, (rol, d.status_code)


def test_tenant_izolasyonu(client, world):
    a = _headers(client, world["slug_a"], world["admin_a"])
    b = _headers(client, world["slug_b"], world["admin_b"])
    no = f"2026/{_sfx()}"
    k = client.post("/karar-defteri", headers=a,
                    json={"karar_no": no, "konu": "K", "metin": "M"}).json()
    b_liste = client.get("/karar-defteri", headers=b).json()["items"]
    assert k["id"] not in [i["id"] for i in b_liste]
    assert client.get(f"/karar-defteri/{k['id']}/pdf",
                      headers=b).status_code == 404
    # Ayni karar NO B'de serbest (benzersizlik tenant icidir).
    assert client.post("/karar-defteri", headers=b,
                       json={"karar_no": no, "konu": "K",
                             "metin": "M"}).status_code == 201
