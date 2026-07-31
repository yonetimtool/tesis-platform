"""Site sakini yonetimi — POST/GET/PATCH/DELETE /residents + reset-password.

Sakin KENDI kayit olamaz; yonetici ekler/listeler/duzenler/siler/parola-sifirlar.
DELETE AKILLI: gecmissiz sakin tamamen silinir; gecmisi olan pasiflestirilir;
telefon HER DURUMDA serbest kalir (yeniden kayit mumkun). Canli API'ye vurur.
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


def _uphone() -> str:
    return "+90" + str(uuid.uuid4().int)[:10]


def _add(client, yon, telefon, ad="Sakin", unit="R-1"):
    r = client.post(
        "/residents", headers=yon, json={"ad": ad, "telefon": telefon, "unit_no": unit}
    )
    assert r.status_code == 201, r.text
    return r.json()


# ------------------------------ ekle / listele ---------------------------- #
def test_add_and_list_resident(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    phone = _uphone()
    res = _add(client, yon, phone, ad="Yeni Sakin", unit="R-1")
    uid = res["user_id"]

    mine = next(
        i for i in client.get("/residents", headers=yon).json()["items"]
        if i["user_id"] == uid
    )
    assert mine["ad"] == "Yeni Sakin" and mine["unit_no"] == "R-1"
    assert mine["is_active"] is True
    assert "telefon" not in mine  # KVKK


def test_add_resident_with_password_skips_temp_code(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    phone = _uphone()
    r = client.post(
        "/residents",
        headers=yon,
        json={"ad": "Parolali", "telefon": phone, "unit_no": "P-9", "password": "Sakin1234!"},
    )
    assert r.status_code == 201, r.text
    assert r.json()["temp_code"] is None  # parola verildi -> gecici kod YOK
    # dogrudan parola ile telefon-login (kurulum gerekmez)
    lp = client.post("/auth/login-phone", json={"phone": phone, "password": "Sakin1234!"})
    assert lp.status_code == 200 and lp.json()["password_setup_required"] is False
    # zayif parola -> 422
    weak = client.post(
        "/residents",
        headers=yon,
        json={"ad": "x", "telefon": _uphone(), "unit_no": "P-7", "password": "zayifparola"},
    )
    assert weak.status_code == 422


# --------------------------------- duzenle -------------------------------- #
def test_edit_resident_and_phone_freed(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    phone_a = _uphone()
    phone_b = _uphone()
    uid = _add(client, yon, phone_a, ad="Ali")["user_id"]

    # ad + telefon guncelle
    r = client.patch(f"/residents/{uid}", headers=yon, json={"ad": "Ali Veli", "telefon": phone_b})
    assert r.status_code == 204, r.text
    mine = next(i for i in client.get("/residents", headers=yon).json()["items"] if i["user_id"] == uid)
    assert mine["ad"] == "Ali Veli"

    # eski numara serbest -> yeni sakin acilir; yeni numara dolu -> cakisma 409
    assert _add(client, yon, phone_a, unit="R-2")  # 201
    dup = client.post("/residents", headers=yon, json={"ad": "x", "telefon": phone_b, "unit_no": "R-3"})
    assert dup.status_code == 409

    # bos govde 422; olmayan sakin 404
    assert client.patch(f"/residents/{uid}", headers=yon, json={}).status_code == 422
    assert client.patch(f"/residents/{uuid.uuid4()}", headers=yon, json={"ad": "z"}).status_code == 404


# ----------------------------- parola sifirla ----------------------------- #
def test_reset_password(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    phone = _uphone()
    uid = _add(client, yon, phone)["user_id"]

    r = client.post(f"/residents/{uid}/reset-password", headers=yon)
    assert r.status_code == 200, r.text
    code = r.json()["temp_code"]

    # yeni kod ile telefon-login -> parola kurulumu gerekli
    lp = client.post("/auth/login-phone", json={"phone": phone, "password": code})
    assert lp.status_code == 200 and lp.json()["password_setup_required"] is True

    assert client.post(f"/residents/{uuid.uuid4()}/reset-password", headers=yon).status_code == 404


# ------------------------------- akilli sil ------------------------------- #
def test_smart_delete_no_history_removes_and_frees_phone(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    phone = _uphone()
    uid = _add(client, yon, phone)["user_id"]

    d = client.delete(f"/residents/{uid}", headers=yon)
    assert d.status_code == 200 and d.json()["deleted"] is True

    # tamamen silindi -> listede yok; ayni numarayla yeniden kayit 201
    assert all(i["user_id"] != uid for i in client.get("/residents", headers=yon).json()["items"])
    assert _add(client, yon, phone, unit="R-9")  # numara serbest


def test_smart_delete_with_history_deactivates_and_frees_phone(client, world, owner_conn):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    phone = _uphone()
    uid = _add(client, yon, phone, ad="Gecmisli")["user_id"]

    # RESTRICT bagimlilik: sakin bir sikayet acmis (owner ile dogrudan, RLS bypass)
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO complaint (tenant_id, acan_user_id, baslik, mesaj) VALUES (%s,%s,%s,%s)",
            (world["a"], uid, "gecmis", "kayit"),
        )

    d = client.delete(f"/residents/{uid}", headers=yon)
    assert d.status_code == 200 and d.json()["deleted"] is False  # pasiflestirildi

    # pasif + telefon serbest: listede is_active=false, ayni numarayla yeniden 201
    mine = next(i for i in client.get("/residents", headers=yon).json()["items"] if i["user_id"] == uid)
    assert mine["is_active"] is False
    assert _add(client, yon, phone, unit="R-8")  # numara serbest


# --------------------------------- RBAC ----------------------------------- #
def test_residents_rbac(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    assert client.get("/residents", headers=admin).status_code == 200

    rid = uuid.uuid4()
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.get("/residents", headers=h).status_code == 403, role
        assert client.delete(f"/residents/{rid}", headers=h).status_code == 403, role
        assert client.patch(f"/residents/{rid}", headers=h, json={"ad": "x"}).status_code == 403, role
        assert client.post(f"/residents/{rid}/reset-password", headers=h).status_code == 403, role


# --------------------------------------------------------------------------- #
# P23 — sakin yasam donusu: sonradan daire atama + TAM duzenleme + malik/kiraci
# --------------------------------------------------------------------------- #
#: Test telefonlari GLOBAL benzersizdir; sayaci sabit bir onekle ilerletiriz
#: (rastgele hex TR mobil bicimini bozuyordu — 422 "gecersiz telefon").
_TEL_SAYAC = [7000000]


def _yeni_sakin(client, yonetim, unit_no):
    _TEL_SAYAC[0] += 1
    r = client.post("/residents", headers=yonetim, json={
        "unit_no": unit_no, "ad": "P23 Sakin",
        "telefon": f"+90532{_TEL_SAYAC[0]}", "rol_tipi": "kiraci",
    })
    assert r.status_code == 201, r.text
    return r.json()


def test_p23_olustur_sonradan_ata_duzenle_E2E(client, world, owner_conn):
    """(a)+(b)+(c) tek akista: yonetici sakini acar, IKINCI daireye atar,
    sonra e-posta ve malik/kiraci tipini DEGISTIRIR."""
    yonetim = _headers(client, world["slug_a"], world["yonetici_a"])
    ek = uuid.uuid4().hex[:5]
    sakin = _yeni_sakin(client, yonetim, f"P23-{ek}")
    uid = sakin["user_id"]

    # --- (a) VAR OLAN sakine IKINCI daire ata (yonetici yapabilmeli) ---
    ikinci = client.post("/units", headers=_headers(
        client, world["slug_a"], world["admin_a"]),
        json={"no": f"P23B-{ek}", "blok": "A"}).json()
    r = client.post(f"/units/{ikinci['id']}/residents", headers=yonetim,
                    json={"user_id": uid, "rol_tipi": "malik"})
    assert r.status_code == 201, r.text
    assert r.json()["rol_tipi"] == "malik"

    # Liste iki daireyi de gostermeli (aktif baglar birlesir).
    liste = client.get("/residents", headers=yonetim).json()["items"]
    satir = next(s for s in liste if s["user_id"] == uid)
    assert f"P23-{ek}" in satir["unit_no"] and f"P23B-{ek}" in satir["unit_no"]

    # --- (b) TAM duzenleme: olusturmadaki alanlarin HEPSI degisebilmeli ---
    r = client.patch(f"/residents/{uid}", headers=yonetim, json={
        "ad": "P23 Yeni Ad", "email": f"p23-{ek}@ornek.com",
    })
    assert r.status_code == 204, r.text
    epostalar = owner_conn.execute(
        "SELECT ad, email FROM app_user WHERE id = %s", (uid,)
    ).fetchone()
    assert epostalar[0] == "P23 Yeni Ad"
    assert epostalar[1] == f"p23-{ek}@ornek.com"

    # e-posta ACIKCA null ile TEMIZLENEBILIR (sakinde opsiyonel).
    assert client.patch(f"/residents/{uid}", headers=yonetim,
                        json={"email": None}).status_code == 204
    assert owner_conn.execute(
        "SELECT email FROM app_user WHERE id = %s", (uid,)
    ).fetchone()[0] is None

    # --- (c) rol_tipi AKTIF baglarin HEPSINE uygulanir ---
    assert client.patch(f"/residents/{uid}", headers=yonetim,
                        json={"rol_tipi": "malik"}).status_code == 204
    tipler = [
        t[0] for t in owner_conn.execute(
            "SELECT rol_tipi FROM unit_resident "
            "WHERE user_id = %s AND bitis IS NULL", (uid,)
        ).fetchall()
    ]
    assert tipler and set(tipler) == {"malik"}


def test_p23_rol_tipi_daire_bagi_YOKSA_422(client, world):
    """Muhasebe hedeflemesi (P28) baga dayanir; bagsiz rol_tipi anlamsizdir."""
    yonetim = _headers(client, world["slug_a"], world["yonetici_a"])
    ek = uuid.uuid4().hex[:5]
    sakin = _yeni_sakin(client, yonetim, f"P23C-{ek}")
    uid = sakin["user_id"]
    # Tum aktif baglari kaldir.
    liste = client.get("/units", headers=_headers(
        client, world["slug_a"], world["admin_a"]), params={"limit": 200}).json()
    for u in liste["items"]:
        if u["no"] == f"P23C-{ek}":
            client.delete(f"/units/{u['id']}/residents/{uid}", headers=yonetim)
    r = client.patch(f"/residents/{uid}", headers=yonetim,
                     json={"rol_tipi": "kiraci"})
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "invalid_reference"


def test_p23_bag_uclari_YONETICIYE_acik_sakine_kapali(client, world):
    """RBAC: bag yonetimi admin+yonetici; sakin/guvenlik 403."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    yonetim = _headers(client, world["slug_a"], world["yonetici_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    birim = client.post("/units", headers=admin,
                        json={"no": f"P23R-{uuid.uuid4().hex[:5]}", "blok": "A"}).json()
    assert client.get(f"/units/{birim['id']}/residents",
                      headers=yonetim).status_code == 200
    assert client.get(f"/units/{birim['id']}/residents",
                      headers=guard).status_code == 403
