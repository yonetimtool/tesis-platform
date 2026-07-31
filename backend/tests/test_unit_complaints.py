"""Daire sikayeti (D1 + D-viz Rev-1) — kademeli gizlilik + own-block + kategori.

Rev-2 KURALLARI:
  * complainant (sikayet eden) kimligi ARTIK HICBIR role donmez (yonetim dahil);
    yonetim yalniz 'sikayet edildigini' + not + durum gorur, KIMIN ettigini degil.
    density + liste yine YALNIZ yonetim; resident/security/gorevli LISTEYE
    ERISEMEZ (403).
  * density + liste YALNIZ yonetim (residentlar sayilari goremez).
  * resident YALNIZ KENDI blogundaki daireyi sikayet eder (blok disi -> 403).
  * kategori: gurultu / kapi_onu_ayakkabi / zarar_verme / diger.
"""
from __future__ import annotations

import uuid

import pytest

from app.hata_metinleri import METINLER


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _mk_resident(owner_conn, tenant_id, email, pw):
    from app.security import hash_password

    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, password_hash, role, password_set) "
            "VALUES (%s,%s,%s,%s,'resident'::user_role, true) RETURNING id",
            (tenant_id, f"Sakin {email.split('@')[0]}", email, hash_password(pw)),
        )
        return cur.fetchone()[0]


def _mk_unit(owner_conn, tenant_id, no, blok=None):
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO unit (tenant_id, no, blok) VALUES (%s,%s,%s) RETURNING id",
            (tenant_id, no, blok),
        )
        return cur.fetchone()[0]


def _link(owner_conn, tenant_id, unit_id, user_id):
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO unit_resident (tenant_id, unit_id, user_id) VALUES (%s,%s,%s)",
            (tenant_id, unit_id, user_id),
        )


@pytest.fixture
def ucworld(client, world, owner_conn):
    """world + blok A (unit1, unit2) + blok B (unit_b) + 6 sakin (blok A'ya
    bagli — own-block ile A dairelerini sikayet edebilirler; B disi)."""
    a = world["a"]
    suffix = uuid.uuid4().hex[:6]
    pw = "UcPass1!"
    unit1 = _mk_unit(owner_conn, a, f"UC-1-{suffix}", blok="A")
    unit2 = _mk_unit(owner_conn, a, f"UC-2-{suffix}", blok="A")
    unit_b = _mk_unit(owner_conn, a, f"UC-B-{suffix}", blok="B")
    residents = []
    for i in range(6):
        email = f"uc{i}-{suffix}@acme.com"
        rid = _mk_resident(owner_conn, a, email, pw)
        _link(owner_conn, a, unit1, rid)  # hepsi blok A sakini
        residents.append({"email": email, "password": pw, "id": str(rid)})

    return {
        **world,
        "unit1": str(unit1),
        "unit1_no": f"UC-1-{suffix}",
        "unit2": str(unit2),
        "unit_b": str(unit_b),
        "unit_b_no": f"UC-B-{suffix}",
        "residents": residents,
    }


def _file(client, slug, resident, target_unit_id, **over):
    body = {"target_unit_id": target_unit_id, "kategori": "gurultu"}
    body.update(over)
    return client.post(
        "/unit-complaints",
        headers=_headers(client, slug, resident),
        json=body,
    )


def _density_for(client, headers, unit_id):
    d = client.get("/unit-complaints/density", headers=headers).json()["items"]
    return next((it for it in d if it["target_unit_id"] == unit_id), None)


# ------------------------------- kayit -------------------------------------- #
def test_sakin_acar_kendi_kaydini_gorur_complainant_donmez(ucworld, client):
    slug = ucworld["slug_a"]
    r0 = ucworld["residents"][0]
    r = _file(client, slug, r0, ucworld["unit1"], notlar="Gece gurultu")
    assert r.status_code == 201, r.text
    body = r.json()
    # resident kendi kaydini gorur ama complainant kimligi DONMEZ (None)
    assert body["complainant_user_id"] is None and body["complainant_ad"] is None
    assert body["target_unit_id"] == ucworld["unit1"]
    assert body["kategori"] == "gurultu" and body["durum"] == "acik"


# ------------------------------ own-block ----------------------------------- #
def test_own_block_ic_201_dis_403(ucworld, client):
    """resident YALNIZ kendi blogundaki (A) daireyi sikayet eder; baska blok
    (B) -> 403. Blok kapsami sunucuda zorlanir."""
    slug = ucworld["slug_a"]
    r0 = ucworld["residents"][0]
    # blok A daireleri (unit1, unit2) -> 201
    assert _file(client, slug, r0, ucworld["unit1"]).status_code == 201
    assert _file(client, slug, r0, ucworld["unit2"]).status_code == 201
    # blok B (unit_b) -> 403 (own-block disi)
    rb = _file(client, slug, r0, ucworld["unit_b"])
    assert rb.status_code == 403 and rb.json()["error"]["code"] == "forbidden"


def test_bloksuz_sakin_hicbir_yere_acamaz_403(ucworld, client, owner_conn):
    """Aktif dairesi olmayan sakin -> blok kumesi bos -> her hedefe 403."""
    slug = ucworld["slug_a"]
    pw = "UcPass1!"
    email = f"bagsiz-{uuid.uuid4().hex[:6]}@acme.com"
    _mk_resident(owner_conn, ucworld["a"], email, pw)  # daireye BAGLI DEGIL
    r = _file(client, slug, {"email": email, "password": pw}, ucworld["unit1"])
    assert r.status_code == 403


# ------------------- spam: HAFTALIK + KATEGORI-BAZLI (Rev-1.1) --------------- #
def test_spam_haftalik_kategori_bazli(ucworld, client):
    """Ayni daire + ayni KATEGORI 7 gunde 1 (409); FARKLI kategori serbest;
    baska daire / baska sakin serbest."""
    slug = ucworld["slug_a"]
    r0 = ucworld["residents"][0]
    # ayni daire + ayni kategori (gurultu) tekrar -> 409 (haftalik)
    assert _file(client, slug, r0, ucworld["unit1"], kategori="gurultu").status_code == 201
    dup = _file(client, slug, r0, ucworld["unit1"], kategori="gurultu")
    assert dup.status_code == 409 and dup.json()["error"]["code"] == "conflict"
    assert dup.json()["error"]["message"] == METINLER["sikayet_haftalik_limit"]["tr"]
    # ayni daire FARKLI kategori -> serbest (201)
    assert _file(client, slug, r0, ucworld["unit1"], kategori="zarar_verme").status_code == 201
    assert _file(client, slug, r0, ucworld["unit1"], kategori="kapi_onu_ayakkabi").status_code == 201
    # BASKA daire ayni kategori -> 201
    assert _file(client, slug, r0, ucworld["unit2"], kategori="gurultu").status_code == 201
    # BASKA sakin ayni daire+kategori -> 201
    assert _file(client, slug, ucworld["residents"][1], ucworld["unit1"], kategori="gurultu").status_code == 201


def test_spam_ayni_kategori_7gun_sonra_yeniden(ucworld, client, owner_conn):
    """Ayni daire+kategori kaydi 7 GUNDEN eskiyse yeniden acilabilir (sliding
    pencere); yeni kayittan sonra tekrar 7 gun kilitli."""
    slug = ucworld["slug_a"]
    r0 = ucworld["residents"][0]
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO unit_complaint "
            "(tenant_id, target_unit_id, complainant_user_id, kategori, created_at) "
            "VALUES (%s,%s,%s,'gurultu'::unit_complaint_kategori, now() - interval '8 days')",
            (ucworld["a"], ucworld["unit1"], r0["id"]),
        )
    # 8 gun onceki kayit pencere DISI -> yeni sikayet 201
    assert _file(client, slug, r0, ucworld["unit1"], kategori="gurultu").status_code == 201
    # simdi taze kayit pencerede -> tekrar 409
    assert _file(client, slug, r0, ucworld["unit1"], kategori="gurultu").status_code == 409


def test_kapatma_haftalik_limiti_sifirlamaz(ucworld, client):
    """Kapatma weekly limiti SIFIRLAMAZ (durumdan bagimsiz): kapali kayit da
    pencerede sayilir. Ayni kategori 7 gun icinde -> 409; farkli kategori 201."""
    slug = ucworld["slug_a"]
    r0 = ucworld["residents"][0]
    assert _file(client, slug, r0, ucworld["unit1"], kategori="gurultu").status_code == 201
    yon = _headers(client, slug, ucworld["yonetici_a"])
    cid = client.get(
        "/unit-complaints", headers=yon, params={"target_unit_id": ucworld["unit1"]}
    ).json()["items"][0]["id"]
    assert client.patch(
        f"/unit-complaints/{cid}", headers=yon, json={"durum": "kapali"}
    ).status_code == 200
    # kapali olsa da ayni kategori 7 gun icinde -> 409
    assert _file(client, slug, r0, ucworld["unit1"], kategori="gurultu").status_code == 409
    # farkli kategori -> 201
    assert _file(client, slug, r0, ucworld["unit1"], kategori="diger").status_code == 201


# ------------------------- sikayetlerim (GET /mine) ------------------------- #
def test_sikayetlerim_yalniz_kendi_kayitlari(ucworld, client):
    """resident /mine YALNIZ kendi actiklarini gorur (unit_no+kategori+durum+
    tarih); baska sakin YOK; yogunluk/renk YOK; complainant (kendisi) omitted.
    RBAC: yalniz resident (yonetim/saha 403)."""
    slug = ucworld["slug_a"]
    r0, r1 = ucworld["residents"][0], ucworld["residents"][1]
    assert _file(client, slug, r0, ucworld["unit1"], kategori="gurultu").status_code == 201
    assert _file(client, slug, r0, ucworld["unit2"], kategori="zarar_verme").status_code == 201
    assert _file(client, slug, r1, ucworld["unit1"], kategori="gurultu").status_code == 201  # baska sakin

    mine = client.get("/unit-complaints/mine", headers=_headers(client, slug, r0))
    assert mine.status_code == 200
    body = mine.json()
    assert body["meta"]["total"] == 2  # YALNIZ r0'nun ikisi (r1'inki YOK)
    for it in body["items"]:
        assert it["unit_no"] and it["kategori"] and it["durum"] and it["created_at"]
        # complainant (kendisi) donmez; yogunluk/renk alani da yok
        assert it["complainant_user_id"] is None and it["complainant_ad"] is None
        assert "renk" not in it and "acik_sayisi" not in it
    # RBAC: /mine yalniz resident
    for cred in (ucworld["admin_a"], ucworld["yonetici_a"], ucworld["guard_a"], ucworld["gorevli_a"]):
        assert client.get(
            "/unit-complaints/mine", headers=_headers(client, slug, cred)
        ).status_code == 403


# --------------------------- 1 dosya = 1 kayit ------------------------------ #
def test_bir_dosya_bir_kayit_sayim_tam_bir_artar(ucworld, client):
    """1 POST = 1 satir = ACIK sayim TAM 1 artar (cift sayim YOK). Yonetim ayni
    daireyi 1 (2 degil) gorur — hem /density hem building-map."""
    slug = ucworld["slug_a"]
    r0 = ucworld["residents"][0]
    admin = _headers(client, slug, ucworld["admin_a"])
    unit = ucworld["unit1"]

    before = _density_for(client, admin, unit)
    assert before["acik_sayisi"] == 0

    # TEK dosya
    assert _file(client, slug, r0, unit, kategori="gurultu").status_code == 201

    after = _density_for(client, admin, unit)
    assert after["acik_sayisi"] == 1  # +1, 2 DEGIL

    # Yonetim building-map de ayni daireyi TAM 1 gorur (cift sayim yok)
    body = client.get("/unit-complaints/building-map", headers=admin).json()
    flat = [u for b in body["bloklar"] for k in b["katlar"] for u in k["units"]]
    flat += list(body["unplaced"])
    u = next(u for u in flat if u["unit_id"] == unit)
    assert u["complaint_count"] == 1


# ------------------------------ renk esikleri ------------------------------- #
def test_renk_esikleri_ve_kapatma_feedback(ucworld, client):
    slug = ucworld["slug_a"]
    admin = _headers(client, slug, ucworld["admin_a"])
    unit = ucworld["unit1"]
    res = ucworld["residents"]

    # (P37 ETKILESIMI) Caydirici esigi VARSAYILAN 5'tir ve 5. gurultu
    # sikayetinde sayaci SIFIRLAR — yani varsayilan ayarda `mor` kademesi
    # gurultu icin ULASILAMAZ olur. Bu OLCUM renk skalasini olcuyor,
    # caydiriciyi degil: esik kaldirilir ki skala sonuna kadar gorunsun.
    # (Caydiricinin kendisi test_gurultu_caydirici.py'de olculur.)
    yonetici_h = _headers(client, slug, ucworld["yonetici_a"])
    assert client.patch("/tenant/settings", headers=yonetici_h,
                        json={"gurultu_esigi": 50}).status_code == 200

    # P24: DORT KADEME — 0 yesil · 1-2 sari · 3-4 kirmizi · 5+ mor.
    assert _density_for(client, admin, unit)["renk"] == "yesil"
    assert _file(client, slug, res[0], unit).status_code == 201
    d = _density_for(client, admin, unit)
    # TEK sikayet artik GORUNUR (eskiden 0-2 hepsi yesildi).
    assert d["acik_sayisi"] == 1 and d["renk"] == "sari"
    assert _file(client, slug, res[1], unit).status_code == 201
    assert _density_for(client, admin, unit)["renk"] == "sari"
    assert _file(client, slug, res[2], unit).status_code == 201
    assert _density_for(client, admin, unit)["renk"] == "kirmizi"
    assert _file(client, slug, res[3], unit).status_code == 201
    assert _density_for(client, admin, unit)["renk"] == "kirmizi"
    assert _file(client, slug, res[4], unit).status_code == 201
    assert _density_for(client, admin, unit)["renk"] == "mor"

    yon = yonetici_h
    cid = client.get(
        "/unit-complaints", headers=yon, params={"target_unit_id": unit}
    ).json()["items"][0]["id"]
    assert client.patch(
        f"/unit-complaints/{cid}", headers=yon, json={"durum": "kapali"}
    ).status_code == 200
    # Kapatma skalayi DUSURUR: 5 -> 4 = mor -> kirmizi.
    d2 = _density_for(client, admin, unit)
    assert d2["acik_sayisi"] == 4 and d2["renk"] == "kirmizi"


# ------------------------- kategori (Rev-1 genisleme) ----------------------- #
def test_kategori_yeni_degerler_ve_eski_ret(ucworld, client):
    slug = ucworld["slug_a"]
    res = ucworld["residents"]
    # yeni gecerli degerler
    assert _file(client, slug, res[0], ucworld["unit1"], kategori="kapi_onu_ayakkabi").status_code == 201
    assert _file(client, slug, res[1], ucworld["unit1"], kategori="zarar_verme").status_code == 201
    assert _file(client, slug, res[2], ucworld["unit1"], kategori="diger").status_code == 201
    # eski/gecersiz degerler -> 422
    for bad in ("ayakkabi", "goruntu", "yok"):
        assert _file(
            client, slug, res[3], ucworld["unit1"], kategori=bad
        ).status_code == 422, bad


# -------------------------------- RBAC -------------------------------------- #
def test_rbac_kademeli(ucworld, client):
    slug = ucworld["slug_a"]
    # ACMA yalniz sakin
    for cred in (ucworld["admin_a"], ucworld["yonetici_a"], ucworld["guard_a"], ucworld["gorevli_a"]):
        h = _headers(client, slug, cred)
        assert client.post(
            "/unit-complaints", headers=h,
            json={"target_unit_id": ucworld["unit1"], "kategori": "diger"},
        ).status_code == 403

    # density + liste YALNIZ yonetim (200); digerleri 403 (Rev-1 kademesi)
    for cred in (ucworld["admin_a"], ucworld["yonetici_a"]):
        h = _headers(client, slug, cred)
        assert client.get("/unit-complaints/density", headers=h).status_code == 200
        assert client.get("/unit-complaints", headers=h).status_code == 200
    for cred in (ucworld["guard_a"], ucworld["gorevli_a"], ucworld["residents"][0]):
        h = _headers(client, slug, cred)
        assert client.get("/unit-complaints/density", headers=h).status_code == 403
        assert client.get("/unit-complaints", headers=h).status_code == 403

    # kapatma yalniz yonetim
    r0 = ucworld["residents"][0]
    _file(client, slug, r0, ucworld["unit1"])
    yon = _headers(client, slug, ucworld["yonetici_a"])
    cid = client.get(
        "/unit-complaints", headers=yon, params={"target_unit_id": ucworld["unit1"]}
    ).json()["items"][0]["id"]
    for cred in (ucworld["guard_a"], ucworld["gorevli_a"], r0):
        h = _headers(client, slug, cred)
        assert client.patch(
            f"/unit-complaints/{cid}", headers=h, json={"durum": "kapali"}
        ).status_code == 403


# ---------- complainant: yonetime bile GORUNMEZ (gizlilik, Rev-2) ------------ #
def test_complainant_yonetime_bile_gorunmez_digerine_403(ucworld, client):
    slug = ucworld["slug_a"]
    r0 = ucworld["residents"][0]
    assert _file(client, slug, r0, ucworld["unit1"], notlar="Gizli not").status_code == 201

    # yonetim: not + durum gorur ama complainant kimligi ARTIK DONMEZ (gizlilik)
    for cred in (ucworld["admin_a"], ucworld["yonetici_a"]):
        h = _headers(client, slug, cred)
        resp = client.get(
            "/unit-complaints", headers=h, params={"target_unit_id": ucworld["unit1"]}
        )
        assert resp.status_code == 200
        item = resp.json()["items"][0]
        assert item["complainant_user_id"] is None and item["complainant_ad"] is None
        assert item["notlar"] == "Gizli not"  # not gorunur, kimlik gorunmez
        # sikayet edenin id'si yanit govdesinde HICBIR yerde sizmasin
        assert r0["id"] not in resp.text

    # digerleri LISTEYE ERISEMEZ -> 403
    for cred in (ucworld["guard_a"], ucworld["gorevli_a"], ucworld["residents"][1]):
        h = _headers(client, slug, cred)
        resp = client.get(
            "/unit-complaints", headers=h, params={"target_unit_id": ucworld["unit1"]}
        )
        assert resp.status_code == 403
        assert r0["id"] not in resp.text and "Gizli not" not in resp.text


# --------------------------- tenant izolasyonu ------------------------------ #
def test_tenant_izolasyonu(ucworld, client):
    slug = ucworld["slug_a"]
    assert _file(client, slug, ucworld["residents"][0], ucworld["unit1"]).status_code == 201

    admin_b = _headers(client, ucworld["slug_b"], ucworld["admin_b"])
    dens_b = client.get("/unit-complaints/density", headers=admin_b).json()["items"]
    assert all(it["target_unit_id"] != ucworld["unit1"] for it in dens_b)
    lst_b = client.get(
        "/unit-complaints", headers=admin_b, params={"target_unit_id": ucworld["unit1"]}
    ).json()["items"]
    assert lst_b == []


# --------------------------------------------------------------------------- #
# P24 — DORT KADEMELI renk skalasi
# --------------------------------------------------------------------------- #
def test_p24_renk_esikleri_SINIR_SINIR(client, world):
    """0/1/2/3/4/5 — her sinir tek tek kilitli.

    Eskiden uc kademeydi ve TEK sikayet almis daire, hic sikayet almamis
    daireyle AYNI renkteydi (0-2 yesil); yonetim ILK sinyali goremiyordu.
    """
    from app.routers.unit_complaints import _color

    assert _color(0) == "yesil"
    assert _color(1) == "sari", "TEK sikayet artik gorunur olmali"
    assert _color(2) == "sari"
    assert _color(3) == "kirmizi"
    assert _color(4) == "kirmizi"
    assert _color(5) == "mor"
    assert _color(99) == "mor"


def test_p24_esik_tablosu_TEK_KAYNAK(client, world):
    """Esikler tabloda; kod dallarina dagilmis olsa P37 sifirlamasi ve
    tenant-basi yapilandirma iki yerde degistirilmek zorunda kalirdi."""
    from app.routers.unit_complaints import _ESIKLER, _color

    # Tablo ARTAN sirada ve son satir YAKALAYICI (None) olmali.
    ustler = [u for u, _ in _ESIKLER]
    assert ustler[-1] is None, "son satir sinirsiz yakalayici olmali"
    sonlu = [u for u in ustler if u is not None]
    assert sonlu == sorted(sonlu), "esikler artan sirada degil"
    # Tablodaki her renk gercekten uretilebiliyor mu (olu satir yok).
    uretilen = {_color(n) for n in range(0, 20)}
    assert uretilen == {renk for _, renk in _ESIKLER}


# ------------------------- P24: okuma durumu (triyaj) ----------------------- #
# "Yeni / Okunmamis" sekmesi KISI BASINADIR: iki yonetici ayni siteye bakarken
# birinin okumasi digerinin kuyrugunu bosaltmamalidir. Rozet sayisi ayri bir uc
# degil, `?okunmamis=true&limit=1` -> meta.total'dir.
def _liste(client, headers, **q):
    r = client.get("/unit-complaints", headers=headers, params=q)
    assert r.status_code == 200, r.text
    return r.json()


def _rozet(client, headers) -> int:
    """Okunmamis rozeti — istemcinin yaptigi cagrinin AYNISI."""
    return _liste(client, headers, okunmamis="true", limit=1)["meta"]["total"]


def test_p24_yeni_sikayet_OKUNMAMIS_baslar(ucworld, client):
    """Satir YOKSA okunmamis: yeni kayit icin ek yazma gerekmemeli."""
    admin = _headers(client, ucworld["slug_a"], ucworld["admin_a"])
    once = _rozet(client, admin)
    assert _file(client, ucworld["slug_a"], ucworld["residents"][0],
                 ucworld["unit1"]).status_code == 201
    assert _rozet(client, admin) == once + 1

    yeni = _liste(client, admin, target_unit_id=ucworld["unit1"])["items"][0]
    assert yeni["okundu"] is False, "yeni sikayet OKUNMUS baslamamali"


def test_p24_okundu_isaretleme_kuyruktan_dusurur(ucworld, client):
    admin = _headers(client, ucworld["slug_a"], ucworld["admin_a"])
    r = _file(client, ucworld["slug_a"], ucworld["residents"][0], ucworld["unit1"])
    assert r.status_code == 201
    cid = r.json()["id"]
    once = _rozet(client, admin)

    m = client.post(f"/unit-complaints/{cid}/okundu", headers=admin)
    assert m.status_code == 200, m.text
    assert m.json()["okundu"] is True
    assert _rozet(client, admin) == once - 1

    # "Yeni" sekmesinde ARTIK YOK, tam listede HALA VAR (arsiv degil, sekme).
    yeni_ids = [i["id"] for i in _liste(client, admin, okunmamis="true")["items"]]
    assert cid not in yeni_ids
    tum = {i["id"]: i for i in _liste(client, admin)["items"]}
    assert cid in tum and tum[cid]["okundu"] is True
    # `okunmamis=false` tersini verir (okunmuslar sekmesi).
    okunanlar = [i["id"] for i in _liste(client, admin, okunmamis="false")["items"]]
    assert cid in okunanlar


def test_p24_okundu_IDEMPOTENT(ucworld, client):
    """Istemci listeyi tazelerken ayni satiri iki kez isaretleyebilir; ikinci
    cagri 409 vermemeli ve rozeti EKSIYE dusurmemeli."""
    admin = _headers(client, ucworld["slug_a"], ucworld["admin_a"])
    cid = _file(client, ucworld["slug_a"], ucworld["residents"][0],
                ucworld["unit1"]).json()["id"]
    assert client.post(f"/unit-complaints/{cid}/okundu", headers=admin).status_code == 200
    ara = _rozet(client, admin)
    assert client.post(f"/unit-complaints/{cid}/okundu", headers=admin).status_code == 200
    assert _rozet(client, admin) == ara


def test_p24_okuma_durumu_KISI_BASINA(ucworld, client):
    """EN KRITIK KURAL: admin'in okumasi yonetici'nin kuyrugunu BOSALTMAZ."""
    admin = _headers(client, ucworld["slug_a"], ucworld["admin_a"])
    yonetici = _headers(client, ucworld["slug_a"], ucworld["yonetici_a"])
    cid = _file(client, ucworld["slug_a"], ucworld["residents"][0],
                ucworld["unit1"]).json()["id"]
    y_once = _rozet(client, yonetici)

    client.post(f"/unit-complaints/{cid}/okundu", headers=admin)

    assert _rozet(client, yonetici) == y_once, "digerinin kuyrugu bosaldi"
    y_yeni = {i["id"]: i for i in _liste(client, yonetici, okunmamis="true")["items"]}
    assert cid in y_yeni and y_yeni[cid]["okundu"] is False


def test_p24_okunmamis_diger_suzgeclerle_BIRLIKTE_calisir(ucworld, client):
    """Sekme + kategori/durum suzgeci ayni anda kullanilir (VE mantigi)."""
    admin = _headers(client, ucworld["slug_a"], ucworld["admin_a"])
    g = _file(client, ucworld["slug_a"], ucworld["residents"][0], ucworld["unit1"],
              kategori="gurultu").json()["id"]
    z = _file(client, ucworld["slug_a"], ucworld["residents"][1], ucworld["unit1"],
              kategori="zarar_verme").json()["id"]

    ids = [i["id"] for i in _liste(
        client, admin, okunmamis="true", kategori="gurultu",
        target_unit_id=ucworld["unit1"])["items"]]
    assert g in ids and z not in ids

    client.post(f"/unit-complaints/{g}/okundu", headers=admin)
    ids = [i["id"] for i in _liste(
        client, admin, okunmamis="true", kategori="gurultu",
        target_unit_id=ucworld["unit1"])["items"]]
    assert g not in ids


def test_p24_kapatma_okuma_durumunu_KORUR(ucworld, client):
    """Kapatma yaniti okuma durumunu da doner; istemci satiri yerinde
    tazeliyor ve None donseydi okunmus satir tekrar OKUNMAMIS gorunurdu."""
    admin = _headers(client, ucworld["slug_a"], ucworld["admin_a"])
    cid = _file(client, ucworld["slug_a"], ucworld["residents"][0],
                ucworld["unit1"]).json()["id"]
    client.post(f"/unit-complaints/{cid}/okundu", headers=admin)
    r = client.patch(f"/unit-complaints/{cid}", headers=admin, json={"durum": "kapali"})
    assert r.status_code == 200, r.text
    assert r.json()["okundu"] is True


def test_p24_okundu_YONETIM_DISINA_KAPALI(ucworld, client):
    """Okuma kuyrugu bir YONETIM kavramidir: sakin/saha isaretleyemez."""
    cid = _file(client, ucworld["slug_a"], ucworld["residents"][0],
                ucworld["unit1"]).json()["id"]
    for kim in ("resident_a", "guard_a", "gorevli_a"):
        h = _headers(client, ucworld["slug_a"], ucworld[kim])
        assert client.post(
            f"/unit-complaints/{cid}/okundu", headers=h
        ).status_code == 403, kim
    # Sakin kendi kaydinda okuma durumu GORMEZ (yonetim kuyrugu sizmaz).
    sakin = _headers(client, ucworld["slug_a"], ucworld["residents"][0])
    benim = client.get("/unit-complaints/mine", headers=sakin).json()["items"]
    assert all(i["okundu"] is None for i in benim)


def test_p24_okundu_TENANT_izolasyonu(ucworld, client):
    """Baska tenant'in sikayeti isaretlenemez (404 — varligi bile sizmaz)."""
    cid = _file(client, ucworld["slug_a"], ucworld["residents"][0],
                ucworld["unit1"]).json()["id"]
    b = _headers(client, ucworld["slug_b"], ucworld["admin_b"])
    assert client.post(f"/unit-complaints/{cid}/okundu", headers=b).status_code == 404


def test_p24_olmayan_sikayet_404(ucworld, client):
    admin = _headers(client, ucworld["slug_a"], ucworld["admin_a"])
    r = client.post(f"/unit-complaints/{uuid.uuid4()}/okundu", headers=admin)
    assert r.status_code == 404
