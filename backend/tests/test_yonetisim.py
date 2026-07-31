"""Yonetisim modulleri (P33) — karar defteri, dokuman, site aktarim."""
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
def test_sablon_basliklari(client, adm):
    r = client.get("/site-aktar/sablon", headers=adm).json()
    assert r["basliklar"] == ["blok", "daire_no", "ad", "telefon", "rol_tipi"]
    assert len(r["ornek"]) == len(r["basliklar"])
    assert r["aciklama"]


def test_YALNIZ_DOGRULA_hicbir_sey_yazmaz(client, adm):
    """Kurulum tek seferlik ve GERI ALMASI ZOR: onizleme olmadan yapilmasi
    yanlis bir dosyayi 300 satir boyunca uygulamak olurdu."""
    blok = f"Z{_sfx()[:3].upper()}"
    daire = f"{blok}-1"
    r = client.post("/site-aktar", headers=adm, json={
        "yalniz_dogrula": True,
        "satirlar": [{"satir_no": 2, "blok": blok, "daire_no": daire}],
    })
    assert r.status_code == 201, r.text
    assert r.json()["daire_olusan"] == 1

    liste = client.get("/units", headers=adm,
                       params={"limit": 200}).json()["items"]
    assert daire not in [u["no"] for u in liste], "dogrulama YAZDI!"


def test_aktarim_blok_daire_kisi_olusturur(client, adm):
    blok = f"Y{_sfx()[:3].upper()}"
    tel = f"+9053{uuid.uuid4().int % 10**8:08d}"
    r = client.post("/site-aktar", headers=adm, json={"satirlar": [
        {"satir_no": 2, "blok": blok, "daire_no": f"{blok}-1",
         "ad": "Aktarim Sakin", "telefon": tel, "rol_tipi": "malik"},
        {"satir_no": 3, "blok": blok, "daire_no": f"{blok}-2"},
    ]})
    assert r.status_code == 201, r.text
    s = r.json()
    assert s["blok_olusan"] == 1 and s["daire_olusan"] == 2
    assert s["kisi_olusan"] == 1 and s["hatalar"] == []

    daireler = [u["no"] for u in client.get(
        "/units", headers=adm, params={"limit": 200}).json()["items"]]
    assert f"{blok}-1" in daireler and f"{blok}-2" in daireler


def test_SATIR_BAZLI_hata_raporu_TUM_ISLEMI_DUSURMEZ(client, adm):
    """300 satirlik bir dosyada 4 hatali satir yuzunden 296 dogru satiri
    reddetmek, kullaniciyi dosyayi elle ayiklamaya zorlardi."""
    blok = f"X{_sfx()[:3].upper()}"
    r = client.post("/site-aktar", headers=adm, json={"satirlar": [
        {"satir_no": 2, "blok": blok, "daire_no": f"{blok}-1"},
        {"satir_no": 3, "blok": "", "daire_no": "OLMAZ"},
        {"satir_no": 4, "blok": blok, "daire_no": f"{blok}-2",
         "ad": "Kotu Telefon", "telefon": "abc"},
        {"satir_no": 5, "blok": blok, "daire_no": f"{blok}-3",
         "ad": "Kotu Rol", "telefon": f"+9053{uuid.uuid4().int % 10**8:08d}",
         "rol_tipi": "sahibi"},
    ]}).json()
    assert r["daire_olusan"] >= 1
    numaralar = {h["satir_no"] for h in r["hatalar"]}
    assert numaralar == {3, 4, 5}, r["hatalar"]
    # Hata ALANI da doner (kullanici hangi hucreyi duzeltecegini bilsin).
    assert {h["alan"] for h in r["hatalar"]} == {"blok", "telefon", "rol_tipi"}


def test_aktarim_IDEMPOTENT(client, adm):
    """Var olan blok/daire/kisi ATLANIR — dosya yeniden yuklenebilir."""
    blok = f"W{_sfx()[:3].upper()}"
    govde = {"satirlar": [
        {"satir_no": 2, "blok": blok, "daire_no": f"{blok}-1"}]}
    ilk = client.post("/site-aktar", headers=adm, json=govde).json()
    ikinci = client.post("/site-aktar", headers=adm, json=govde).json()
    assert ilk["daire_olusan"] == 1
    assert ikinci["daire_olusan"] == 0 and ikinci["blok_olusan"] == 0


def test_KISI_SATIRI_OPSIYONEL(client, adm):
    """Yalniz daire kurmak gecerli bir kullanim (once yapi, sonra sakinler)."""
    blok = f"V{_sfx()[:3].upper()}"
    r = client.post("/site-aktar", headers=adm, json={"satirlar": [
        {"satir_no": 2, "blok": blok, "daire_no": f"{blok}-1"}]}).json()
    assert r["kisi_olusan"] == 0 and r["hatalar"] == []


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
