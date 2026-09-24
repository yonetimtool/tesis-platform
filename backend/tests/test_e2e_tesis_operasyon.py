"""(E2E 2026-09) TESIS operasyonu regresyonlari — gorev, NFC, demirbas,
akilli ev kapsami, sikayet haritasi tur suzgeci.

Her test uctan uca testteki BIR bulguyu (TESIS-xx / GUVENLIK-05) canli
sunucuya karsi yeniden olcer; bulgu metni test adinda ve docstring'de.
"""
from __future__ import annotations

import uuid

import pytest

from app.hata_metinleri import METINLER


def _h(client, world, kim, slug="slug_a"):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": world[slug], "email": world[kim]["email"],
              "password": world[kim]["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _id(client, h):
    return client.get("/me", headers=h).json()["id"]


def _gorev(client, h, **k):
    govde = {"ad": f"E2E {uuid.uuid4().hex[:6]}"}
    govde.update(k)
    r = client.post("/tasks", headers=h, json=govde)
    assert r.status_code == 201, r.text
    return r.json()


def _tamamla(client, h, tid, **k):
    govde = {"tamamlanma_zamani": "2026-09-20T08:00:00Z"}
    govde.update(k)
    return client.post(
        f"/tasks/{tid}/completions",
        headers={**h, "Idempotency-Key": uuid.uuid4().hex}, json=govde,
    )


# ============================ TESIS-02 ==================================== #
def test_TESIS02_bos_foto_key_foto_zorunlulugunu_ATLATAMAZ(client, world):
    yon = _h(client, world, "yonetici_a")
    gorevli = _h(client, world, "gorevli_a")
    t = _gorev(client, yon, foto_zorunlu=True, atanan_user_id=_id(client, gorevli))

    for bos in ("", "   "):
        r = _tamamla(client, gorevli, t["id"], foto_key=bos)
        assert r.status_code == 422, r.text
        assert r.json()["error"]["message"] == METINLER["gorev_foto_kaniti_zorunlu"]["tr"]

    # Baska tenant'in on eki kanit sayilmaz (IDOR).
    r = _tamamla(client, gorevli, t["id"], foto_key=f"{world['b']}/tasks/x.jpg")
    assert r.status_code == 422, r.text

    r = _tamamla(client, gorevli, t["id"], foto_key=f"{world['a']}/tasks/x.jpg")
    assert r.status_code == 201, r.text
    ozet = client.get(f"/tasks/{t['id']}", headers=yon).json()["son_tamamlama"]
    assert ozet["foto_var"] is True


def test_TESIS02_fotosuz_gorevde_bos_anahtar_foto_var_DEMEZ(client, world):
    yon = _h(client, world, "yonetici_a")
    gorevli = _h(client, world, "gorevli_a")
    t = _gorev(client, yon, atanan_user_id=_id(client, gorevli))
    r = _tamamla(client, gorevli, t["id"], foto_key="")
    assert r.status_code == 201, r.text
    assert r.json()["foto_key"] is None
    ozet = client.get(f"/tasks/{t['id']}", headers=yon).json()["son_tamamlama"]
    assert ozet["foto_var"] is False


# ============================ TESIS-03 ==================================== #
def _adimlar(client, h, tid):
    return client.get(f"/tasks/{tid}", headers=h).json()["adimlar"]


def test_TESIS03_acik_adim_varken_gorev_KAPANMAZ(client, world):
    yon = _h(client, world, "yonetici_a")
    guard = _h(client, world, "guard_a")
    t = _gorev(
        client, yon, atanan_user_id=_id(client, guard),
        adimlar=[{"ad": "A", "sira": 0}, {"ad": "B", "sira": 1}, {"ad": "C", "sira": 2}],
    )
    # Hic adim yapilmadan (olculen: 0/2 ile "tamamlandi").
    r = _tamamla(client, guard, t["id"])
    assert r.status_code == 409, r.text
    assert r.json()["error"]["message"] == METINLER["gorev_adimlari_tamamlanmadi"]["tr"]

    # 2/3 adimla (olculen: "tamamlandi").
    for a in _adimlar(client, yon, t["id"])[:2]:
        assert client.post(
            f"/tasks/{t['id']}/adimlar/{a['id']}/tamamla", headers=guard, json={},
        ).status_code == 200
    r = _tamamla(client, guard, t["id"])
    assert r.status_code == 409, r.text
    v = client.get(f"/tasks/{t['id']}", headers=yon).json()
    assert v["durum"] != "tamamlandi"
    assert (v["adim_tamam"], v["adim_toplam"]) == (2, 3)

    # Yonetim de adimlari atlayamaz.
    assert _tamamla(client, yon, t["id"]).status_code == 409


def test_TESIS03_SON_adim_gorevi_KAPATIR_ve_bildirim_gider(client, world):
    yon = _h(client, world, "yonetici_a")
    guard = _h(client, world, "guard_a")

    def _sayim():
        r = client.get("/notifications?limit=200", headers=yon)
        assert r.status_code == 200, r.text
        return sum(1 for n in r.json()["items"] if n.get("tip") == "gorev_tamamlandi")

    once = _sayim()
    t = _gorev(
        client, yon, atanan_user_id=_id(client, guard),
        adimlar=[{"ad": "A", "sira": 0}, {"ad": "B", "sira": 1}],
    )
    for a in _adimlar(client, yon, t["id"]):
        r = client.post(
            f"/tasks/{t['id']}/adimlar/{a['id']}/tamamla", headers=guard,
            json={"notlar": "tamam"},
        )
        assert r.status_code == 200, r.text

    # Olculen: 2/2 adimla `durum=atandi`, bildirim yok.
    v = client.get(f"/tasks/{t['id']}", headers=yon).json()
    assert v["tamamlandi"] is True
    assert v["durum"] == "tamamlandi"
    assert v["son_tamamlama"]["tamamlayan_user_id"] == _id(client, guard)
    gecmis = client.get(f"/tasks/{t['id']}/completions", headers=yon).json()
    assert gecmis["meta"]["total"] == 1
    assert _sayim() - once == 1

    # Geri al + yeniden tamamla: periyodik olmayan goreve IKINCI kayit yok.
    son = _adimlar(client, yon, t["id"])[-1]
    yol = f"/tasks/{t['id']}/adimlar/{son['id']}"
    assert client.post(f"{yol}/geri-al", headers=yon).status_code == 200
    assert client.post(f"{yol}/tamamla", headers=guard, json={}).status_code == 200
    gecmis = client.get(f"/tasks/{t['id']}/completions", headers=yon).json()
    assert gecmis["meta"]["total"] == 1


# ===================== TESIS-07 + GUVENLIK-05 (NFC) ======================== #
def test_GUVENLIK05_ayni_etiketin_farkli_yazimi_409_ve_kanonik_saklanir(client, world):
    yon = _h(client, world, "yonetici_a")
    ek = uuid.uuid4().hex[:6].upper()
    r = client.post("/checkpoints", headers=yon,
                    json={"ad": "Kapi", "nfc_tag_uid": f"04:a1:b2:{ek[:2]}:{ek[2:4]}:{ek[4:]}"})
    assert r.status_code == 201, r.text
    kanonik = f"04A1B2{ek}"
    assert r.json()["nfc_tag_uid"] == kanonik

    for yazim in (kanonik, kanonik.lower(), f" 04-A1-B2-{ek[:2]}-{ek[2:4]}-{ek[4:]} "):
        r2 = client.post("/checkpoints", headers=yon, json={"ad": "Kopya", "nfc_tag_uid": yazim})
        assert r2.status_code == 409, (yazim, r2.text)

    # Sorgu da kanonige cevrilir.
    liste = client.get("/checkpoints", headers=yon,
                       params={"nfc_tag_uid": f"04:a1:b2:{ek[:2]}:{ek[2:4]}:{ek[4:]}"}).json()
    assert [c["nfc_tag_uid"] for c in liste["items"]] == [kanonik]

    # Ayraclar atilinca bos kalan UID.
    r3 = client.post("/checkpoints", headers=yon, json={"ad": "Bos", "nfc_tag_uid": ":::"})
    assert r3.status_code == 422, r3.text


def test_GUVENLIK05_eski_cift_kayitta_okutma_500_VERMEZ(client, world, owner_conn):
    """Goc 0151 cakisan eski kayitlari OLDUGU GIBI birakir; okutma yine
    tek kayit secmeli (olculen: MultipleResultsFound -> 500)."""
    guard = _h(client, world, "guard_a")
    ek = uuid.uuid4().hex[:8].upper()
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO checkpoint (tenant_id, ad, nfc_tag_uid) VALUES "
            "(%s,'Eski1',%s),(%s,'Eski2',%s) RETURNING id",
            (world["a"], f"04{ek}", world["a"], f"04:{ek[:2]}:{ek[2:4]}:{ek[4:6]}:{ek[6:]}".lower()),
        )
        kanonik_id = str(cur.fetchone()[0])
    r = client.post(
        "/scans", headers={**guard, "Idempotency-Key": uuid.uuid4().hex},
        json={"nfc_tag_uid": f"04:{ek[:2]}:{ek[2:4]}:{ek[4:6]}:{ek[6:]}",
              "okutma_zamani": "2026-09-20T08:00:00Z", "gps_lat": 41.0, "gps_lng": 29.0},
    )
    assert r.status_code == 201, r.text
    # Kanonik bicimde saklanan secilir.
    assert r.json()["checkpoint_id"] == kanonik_id


def test_TESIS07_ayracli_kayit_ayracsiz_okutmayla_eslesir_ve_NFC_zorunlu(client, world):
    yon = _h(client, world, "yonetici_a")
    gorevli = _h(client, world, "gorevli_a")
    ek = uuid.uuid4().hex[:4].upper()
    cp = client.post("/checkpoints", headers=yon,
                     json={"ad": "Pano", "nfc_tag_uid": f"04:A1:B2:C3:{ek[:2]}:{ek[2:]}"}).json()
    t = _gorev(client, yon, checkpoint_id=cp["id"], atanan_user_id=_id(client, gorevli))

    # NFC'siz saha tamamlamasi REDDEDILIR (olculen: 201).
    r = _tamamla(client, gorevli, t["id"])
    assert r.status_code == 422, r.text
    assert r.json()["error"]["message"] == METINLER["gorev_nfc_zorunlu"]["tr"]

    # Mobilin ayracsiz bicimi eslesir (olculen: 422 gorev_nfc_eslesmiyor).
    r = _tamamla(client, gorevli, t["id"], nfc_tag_uid=f"04a1b2c3{ek.lower()}")
    assert r.status_code == 201, r.text

    # Yonetim masadan kapatabilir (izinli personelin gorevi).
    t2 = _gorev(client, yon, checkpoint_id=cp["id"], atanan_user_id=_id(client, gorevli))
    assert _tamamla(client, yon, t2["id"]).status_code == 201


# ============================ TESIS-04 ==================================== #
def test_TESIS04_yonetici_demirbas_tanimlar_saha_tanimlayamaz(client, world):
    yon = _h(client, world, "yonetici_a")
    guard = _h(client, world, "guard_a")
    r = client.post("/assets", headers=yon, json={"ad": "Matkap", "kategori": "alet"})
    assert r.status_code == 201, r.text
    aid = r.json()["id"]
    assert client.patch(f"/assets/{aid}", headers=yon, json={"ad": "Matkap 2"}).status_code == 200
    assert client.post("/assets", headers=guard, json={"ad": "x"}).status_code == 403
    assert client.delete(f"/assets/{aid}", headers=yon).status_code == 204


def test_demirbas_nfc_sorgusu_ayractan_bagimsiz(client, world):
    yon = _h(client, world, "yonetici_a")
    ek = uuid.uuid4().hex[:6].upper()
    a = client.post("/assets", headers=yon,
                    json={"ad": "Jenerator", "nfc_tag_uid": f"04{ek}"}).json()
    bulunan = client.get("/assets", headers=yon, params={
        "nfc_tag_uid": f"04:{ek[:2]}:{ek[2:4]}:{ek[4:]}".lower()}).json()["items"]
    assert [x["id"] for x in bulunan] == [a["id"]]


# ===================== TESIS-04b + TESIS-13 (akilli ev) ==================== #
@pytest.fixture
def ev(client, world, owner_conn):
    """Sakin A'nin dairesi + ortak alan; bir kilit (daire) + bir vana (ortak)."""
    a = world["a"]
    ek = uuid.uuid4().hex[:6]
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND email=%s AND role='resident'",
            (a, world["resident_a"]["email"]),
        )
        sakin_id = cur.fetchone()[0]
        cur.execute("INSERT INTO unit (tenant_id, no) VALUES (%s,%s) RETURNING id",
                    (a, f"EV-{ek}"))
        daire = cur.fetchone()[0]
        cur.execute("INSERT INTO unit_resident (tenant_id, unit_id, user_id) VALUES (%s,%s,%s)",
                    (a, daire, sakin_id))
    yon = _h(client, world, "yonetici_a")
    k = client.post("/akilli-ev/koprular", headers=yon, json={
        "ad": f"Hub {ek}", "tur": "home_assistant", "host": "127.0.0.1", "port": 9,
        "token": "gizli"})
    assert k.status_code == 201, k.text
    kid = k.json()["id"]

    def _cihaz(**g):
        r = client.post("/akilli-ev/cihazlar", headers=yon, json={"kopru_id": kid, **g})
        assert r.status_code == 201, r.text
        return r.json()

    kilit = _cihaz(ad="Kapı kilidi", tip="kilit", dis_kimlik="lock.kapi", unit_id=str(daire))
    vana = _cihaz(ad="Kazan vanası", tip="vana", dis_kimlik="valve.kazan", alan="Kazan")
    return {"yon": yon, "kilit": kilit, "vana": vana}


def _bolum(client, yon, **acik):
    r = client.put("/akilli-ev/bolumler", headers=yon, json={
        "bolumler": [{"bolum": b, "acik": v} for b, v in acik.items()]})
    assert r.status_code == 200, r.text


@pytest.mark.parametrize("rol", ["guard_a", "gorevli_a", "amir_a"])
def test_TESIS04b_saha_rolu_daire_kilidini_GOREMEZ_KUMANDA_EDEMEZ(client, world, ev, rol):
    _bolum(client, ev["yon"], kapi=True, kacak=True)
    h = _h(client, world, rol)
    idler = {c["id"] for c in client.get("/akilli-ev/cihazlar", headers=h).json()["items"]}
    assert ev["kilit"]["id"] not in idler, "daire kilidi saha rolune GORUNMEMELI"
    assert ev["vana"]["id"] in idler, "ortak alan cihazi saha rolune gorunur"
    r = client.post(f"/akilli-ev/cihazlar/{ev['kilit']['id']}/komut",
                    headers=h, json={"eylem": "kilit_ac"})
    assert r.status_code == 403, r.text


def test_TESIS13_kapali_bolumun_cihazi_komut_ALMAZ(client, world, ev):
    sakin = _h(client, world, "resident_a")
    kilit = ev["kilit"]
    assert kilit["bolum"] == "kapi"
    assert kilit["daire_no"], "olusturma yaniti daire_no tasimali"

    _bolum(client, ev["yon"], kapi=False)
    assert kilit["id"] not in {
        c["id"] for c in client.get("/akilli-ev/cihazlar", headers=sakin).json()["items"]}
    r = client.post(f"/akilli-ev/cihazlar/{kilit['id']}/komut",
                    headers=sakin, json={"eylem": "kilit_ac"})
    assert r.status_code == 409, r.text
    assert r.json()["error"]["message"] == METINLER["akilli_ev_bolum_kapali"]["tr"]

    # Bolum acilinca kapi GECILIR (kopru ulasilamaz -> 200 ok:false).
    _bolum(client, ev["yon"], kapi=True)
    r = client.post(f"/akilli-ev/cihazlar/{kilit['id']}/komut",
                    headers=sakin, json={"eylem": "kilit_ac"})
    assert r.status_code == 200, r.text

    # Yonetim kapali bolumde de dener (kurulum).
    _bolum(client, ev["yon"], kapi=False)
    r = client.post(f"/akilli-ev/cihazlar/{kilit['id']}/komut",
                    headers=ev["yon"], json={"eylem": "kilit_ac"})
    assert r.status_code == 200, r.text


# ============================ TESIS-17 ==================================== #
def test_TESIS17_harita_tur_suzgeci(client, world, owner_conn):
    a = world["a"]
    yon = _h(client, world, "yonetici_a")
    ek = uuid.uuid4().hex[:6]
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND email=%s AND role='resident'",
            (a, world["resident_a"]["email"]),
        )
        sakin_id = cur.fetchone()[0]
        cur.execute("INSERT INTO unit (tenant_id, no) VALUES (%s,%s) RETURNING id",
                    (a, f"H-{ek}"))
        daire = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO unit_complaint (tenant_id, target_unit_id, complainant_user_id, "
            "kategori, durum) VALUES (%s,%s,%s,'gurultu','acik'),"
            "(%s,%s,%s,'goruntu_kirliligi','acik')",
            (a, daire, sakin_id, a, daire, sakin_id),
        )

    def _sayi(**p):
        r = client.get("/unit-complaints/density", headers=yon, params=p)
        assert r.status_code == 200, r.text
        return next(i["acik_sayisi"] for i in r.json()["items"]
                    if i["target_unit_id"] == str(daire))

    assert _sayi() == 2
    assert _sayi(kategori="gurultu") == 1
    assert _sayi(kategori="zarar_verme") == 0
    assert client.get("/unit-complaints/density", headers=yon,
                      params={"kategori": "yok"}).status_code == 422

    harita = client.get("/unit-complaints/building-map", headers=yon,
                        params={"kategori": "goruntu_kirliligi"}).json()
    hucre = next(u for u in harita["unplaced"] if u["unit_id"] == str(daire))
    assert hucre["complaint_count"] == 1
