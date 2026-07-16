"""Onboarding Model A — admin cross-tenant tesis olusturma/listeleme +
yonetici ilk-giris adlandirma (POST/GET /tenants, POST /tenant/setup).

Admin tenant (opsiyonel ad; kurulum_tamamlandi=false) + N yonetici acar;
listedeki ILK yonetici BIRINCIL'dir ve ilk giriste tesisi adlandirir/onaylar
(kurulum_tamamlandi=true). Mobil self-signup KALDIRILDI.
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


def test_admin_creates_tenant_yonetici_then_first_login_setup(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    phone = _uphone()

    # 1) admin: tenant (isimsiz) + yonetici (parolasiz -> gecici kod)
    r = client.post(
        "/tenants",
        headers=admin,
        json={"yoneticiler": [{"ad": "Yeni Yonetici", "phone": phone}]},
    )
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["tenant_id"] and len(body["yoneticiler"]) == 1
    assert body["yoneticiler"][0]["birincil"] is True  # tek yonetici = birincil
    temp = body["yoneticiler"][0]["temp_code"]
    assert temp  # parola verilmedi -> gecici kod

    # 2) yonetici telefonla ilk giris -> parola kurulumu gerekir
    lp = client.post("/auth/login-phone", json={"phone": phone, "password": temp})
    assert lp.status_code == 200 and lp.json()["password_setup_required"] is True
    sp = client.post(
        "/auth/set-password",
        json={"setup_token": lp.json()["setup_token"], "new_password": "YeniYonetici1!"},
    )
    assert sp.status_code == 200, sp.text
    yon = {"Authorization": f"Bearer {sp.json()['access_token']}"}

    # 3) tenant henuz kurulmamis (kurulum_tamamlandi=false)
    ts = client.get("/tenant/settings", headers=yon)
    assert ts.status_code == 200 and ts.json()["kurulum_tamamlandi"] is False

    # 4) yonetici tesisi adlandirir -> kurulum tamamlanir
    su = client.post("/tenant/setup", headers=yon, json={"ad": "Benim Sitem"})
    assert su.status_code == 200, su.text
    assert su.json()["ad"] == "Benim Sitem" and su.json()["kurulum_tamamlandi"] is True

    # 5) ikinci setup -> 409 (zaten kuruldu)
    assert client.post("/tenant/setup", headers=yon, json={"ad": "XY"}).status_code == 409


def test_admin_creates_tenant_with_password_skips_temp_code(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    phone = _uphone()
    r = client.post(
        "/tenants",
        headers=admin,
        json={
            "yoneticiler": [
                {"ad": "Parolali", "phone": phone, "password": "YonParola1!"}
            ]
        },
    )
    assert r.status_code == 201, r.text
    assert r.json()["yoneticiler"][0]["temp_code"] is None
    lp = client.post("/auth/login-phone", json={"phone": phone, "password": "YonParola1!"})
    assert lp.status_code == 200 and lp.json()["password_setup_required"] is False


def test_admin_lists_all_tenants(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.get("/tenants", headers=admin)
    assert r.status_code == 200, r.text
    ids = {i["id"] for i in r.json()["items"]}
    # world A ve B tenant'lari listede (cross-tenant admin gorunumu)
    assert str(world["a"]) in ids and str(world["b"]) in ids
    for i in r.json()["items"]:
        assert {"id", "ad", "kurulum_tamamlandi", "created_at"} <= set(i)


def test_tenants_admin_only(client, world):
    for role in ("yonetici_a", "guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.get("/tenants", headers=h).status_code == 403, role
        assert client.post(
            "/tenants",
            headers=h,
            json={"yoneticiler": [{"ad": "xy", "phone": _uphone()}]},
        ).status_code == 403, role


def test_tenant_setup_rbac_and_already_done(client, world, owner_conn):
    # BIRINCIL yonetici + tenant HAZIR (kurulum_tamamlandi default true) -> 409.
    # NOT: birincil kapisi kurulum kapisindan ONCE gelir; birincil isaretlenmezse
    # 403 donerdi (bkz. test_tenant_ad.test_birincil_olmayan_yonetici_setup_403).
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE app_user SET birincil = true WHERE tenant_id = %s AND ad = %s",
            (world["a"], "Yonetici A"),
        )
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    assert client.post("/tenant/setup", headers=yon, json={"ad": "XY"}).status_code == 409
    # yonetici disi roller -> 403
    for role in ("admin_a", "guard_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.post("/tenant/setup", headers=h, json={"ad": "XY"}).status_code == 403, role


# --------------------------------------------------------------------------- #
# Tesis detay & yonetici konfigurasyonu (admin cross-tenant)
# --------------------------------------------------------------------------- #

def _admin(client, world):
    return _headers(client, world["slug_a"], world["admin_a"])


def _create_tenant(client, admin, password=None, ad=None, yonetim_email=None):
    """Tek yoneticili tenant (o yonetici BIRINCIL olur). Geriye donuk yardimci:
    donen sozluge duz `temp_code`/`yonetici_user_id` eklenir ki mevcut testler
    coklu-yonetici yanitini elle acmasin."""
    phone = _uphone()
    yon = {"ad": "Detay Yon", "phone": phone}
    if password:
        yon["password"] = password
    body: dict = {"yoneticiler": [yon]}
    if ad:
        body["ad"] = ad
    if yonetim_email:
        body["yonetim_email"] = yonetim_email
    r = client.post("/tenants", headers=admin, json=body)
    assert r.status_code == 201, r.text
    out = r.json()
    birincil = out["yoneticiler"][0]
    out["temp_code"] = birincil["temp_code"]
    out["yonetici_user_id"] = birincil["user_id"]
    return out, phone


def _login_phone(client, phone, pw):
    return client.post("/auth/login-phone", json={"phone": phone, "password": pw})


def _setup_yonetici(client, phone, temp):
    """Gecici kod ile ilk giris + kalici parola -> yonetici auth header."""
    lp = _login_phone(client, phone, temp)
    assert lp.status_code == 200 and lp.json()["password_setup_required"] is True
    sp = client.post(
        "/auth/set-password",
        json={"setup_token": lp.json()["setup_token"], "new_password": "DetayYon1!"},
    )
    assert sp.status_code == 200, sp.text
    return {"Authorization": f"Bearer {sp.json()['access_token']}"}


def test_get_tenant_detail(client, world):
    admin = _admin(client, world)
    created, phone = _create_tenant(client, admin)
    tid = created["tenant_id"]
    r = client.get(f"/tenants/{tid}", headers=admin)
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["tenant_id"] == tid and d["kurulum_tamamlandi"] is False
    assert d["yonetici"]["id"] == created["yonetici_user_id"]
    assert d["yonetici"]["telefon"] == phone
    assert d["yonetici"]["password_set"] is False and d["yonetici"]["is_active"] is True


def test_get_tenant_detail_404(client, world):
    admin = _admin(client, world)
    assert client.get(f"/tenants/{uuid.uuid4()}", headers=admin).status_code == 404


def test_admin_renames_tenant(client, world):
    """PATCH /tenants/{id} tesis adini degistirir + kurulum_tamamlandi=true;
    bilinmeyen tesis 404, cok kisa ad 422."""
    admin = _admin(client, world)
    created, _phone = _create_tenant(client, admin)
    tid = created["tenant_id"]
    # baslangicta isimsiz (kurulum bekliyor)
    assert client.get(f"/tenants/{tid}", headers=admin).json()["kurulum_tamamlandi"] is False

    r = client.patch(f"/tenants/{tid}", headers=admin, json={"ad": "Yeni Tesis Adi"})
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["ad"] == "Yeni Tesis Adi"
    assert d["kurulum_tamamlandi"] is True
    # kalici
    assert client.get(f"/tenants/{tid}", headers=admin).json()["ad"] == "Yeni Tesis Adi"

    # bilinmeyen tesis -> 404
    assert (
        client.patch(f"/tenants/{uuid.uuid4()}", headers=admin, json={"ad": "XY"}).status_code
        == 404
    )
    # cok kisa ad (min_length=2) -> 422
    assert client.patch(f"/tenants/{tid}", headers=admin, json={"ad": "X"}).status_code == 422


def test_rename_tenant_admin_only(client, world):
    """Yonetici/saha/resident tesis adini degistiremez (403)."""
    admin = _admin(client, world)
    created, _ = _create_tenant(client, admin)
    tid = created["tenant_id"]
    for role in ("yonetici_a", "guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert (
            client.patch(f"/tenants/{tid}", headers=h, json={"ad": "Hack"}).status_code == 403
        ), role


def test_update_yonetici_and_phone_conflict(client, world):
    admin = _admin(client, world)
    created, _phone = _create_tenant(client, admin)
    tid = created["tenant_id"]
    newphone = _uphone()
    r = client.patch(
        f"/tenants/{tid}/yonetici",
        headers=admin,
        json={"ad": "Yeni Ad", "phone": newphone, "is_active": True},
    )
    assert r.status_code == 200, r.text
    assert r.json()["yonetici"]["ad"] == "Yeni Ad"
    assert r.json()["yonetici"]["telefon"] == newphone
    # cakisma: baska tenant'in yoneticisinin telefonuna cekmek -> 409
    _other, ophone = _create_tenant(client, admin)
    c = client.patch(f"/tenants/{tid}/yonetici", headers=admin, json={"phone": ophone})
    assert c.status_code == 409, c.text


def test_reset_credential_relogin(client, world):
    admin = _admin(client, world)
    created, phone = _create_tenant(client, admin, password="IlkParola1!")
    tid = created["tenant_id"]
    assert _login_phone(client, phone, "IlkParola1!").json()["password_setup_required"] is False
    rr = client.post(f"/tenants/{tid}/yonetici/reset-credential", headers=admin)
    assert rr.status_code == 200, rr.text
    temp = rr.json()["temp_code"]
    assert temp
    # eski parola artik gecmez; yeni gecici kod ilk-giris (parola belirleme) verir
    assert _login_phone(client, phone, "IlkParola1!").status_code == 401
    lp = _login_phone(client, phone, temp)
    assert lp.status_code == 200 and lp.json()["password_setup_required"] is True


def test_deactivate_blocks_login(client, world):
    admin = _admin(client, world)
    created, phone = _create_tenant(client, admin, password="AktifParola1!")
    tid = created["tenant_id"]
    assert _login_phone(client, phone, "AktifParola1!").status_code == 200
    client.patch(f"/tenants/{tid}/yonetici", headers=admin, json={"is_active": False})
    assert _login_phone(client, phone, "AktifParola1!").status_code == 401


def test_delete_tenant_cascade(client, world):
    admin = _admin(client, world)
    created, phone = _create_tenant(client, admin)
    tid = created["tenant_id"]
    yon = _setup_yonetici(client, phone, created["temp_code"])
    # RESTRICT-referans veren veri: yonetici duyuru olusturur (announcement->app_user)
    a = client.post("/announcements", headers=yon, json={"baslik": "Test", "govde": "Govde"})
    assert a.status_code in (200, 201), a.text
    # tesisi sil -> 204 (RESTRICT'e takilmadan cascade)
    d = client.delete(f"/tenants/{tid}", headers=admin)
    assert d.status_code == 204, d.text
    assert client.get(f"/tenants/{tid}", headers=admin).status_code == 404
    ids = {i["id"] for i in client.get("/tenants", headers=admin).json()["items"]}
    assert tid not in ids


def test_delete_tenant_404(client, world):
    admin = _admin(client, world)
    assert client.delete(f"/tenants/{uuid.uuid4()}", headers=admin).status_code == 404


def test_tenant_detail_rbac(client, world):
    created, _ = _create_tenant(client, _admin(client, world))
    tid = created["tenant_id"]
    for role in ("yonetici_a", "guard_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.get(f"/tenants/{tid}", headers=h).status_code == 403, role
        assert client.patch(
            f"/tenants/{tid}/yonetici", headers=h, json={"ad": "X2"}
        ).status_code == 403, role
        assert client.post(
            f"/tenants/{tid}/yonetici/reset-credential", headers=h
        ).status_code == 403, role
        assert client.delete(f"/tenants/{tid}", headers=h).status_code == 403, role


# --------------------------------------------------------------------------- #
# Coklu yonetici + yonetim maili + opsiyonel tesis adi
# --------------------------------------------------------------------------- #

def _tenant_sil(owner_conn, tid):
    with owner_conn.cursor() as cur:
        cur.execute("DELETE FROM tenant WHERE id = %s", (tid,))


def test_coklu_yonetici_olusturma_birincil_isaretlenir(client, world, owner_conn):
    admin = _admin(client, world)
    p1, p2, p3 = _uphone(), _uphone(), _uphone()
    r = client.post(
        "/tenants",
        headers=admin,
        json={
            "ad": "Coklu Sitesi",
            "yonetim_email": "yonetim@coklu.com",
            "yoneticiler": [
                {"ad": "Birinci Yonetici", "phone": p1},
                {"ad": "Ikinci Yonetici", "phone": p2, "password": "Yonetici123!"},
                {"ad": "Ucuncu Yonetici", "phone": p3},
            ],
        },
    )
    assert r.status_code == 201, r.text
    body = r.json()
    tid = body["tenant_id"]
    try:
        assert len(body["yoneticiler"]) == 3

        birinciler = [y for y in body["yoneticiler"] if y["birincil"]]
        assert len(birinciler) == 1
        assert birinciler[0]["ad"] == "Birinci Yonetici", "ILK giren birincil olmali"

        # Parolasiz olanlar gecici kod alir; parolali olan almaz. Eslemenin
        # dogrulugu kritik: yanlis kisiye kod gitmemeli.
        by_ad = {y["ad"]: y for y in body["yoneticiler"]}
        assert by_ad["Birinci Yonetici"]["temp_code"]
        assert by_ad["Ikinci Yonetici"]["temp_code"] is None
        assert by_ad["Ucuncu Yonetici"]["temp_code"]

        with owner_conn.cursor() as cur:
            cur.execute(
                "SELECT ad, birincil, aranabilir, role, telefon FROM app_user "
                "WHERE tenant_id = %s ORDER BY birincil DESC, ad",
                (tid,),
            )
            rows = cur.fetchall()
        assert len(rows) == 3
        assert all(r[3] == "yonetici" for r in rows)
        # Hepsi aranabilir=true: iletisim karti + /call-target tutarliligi.
        assert all(r[2] is True for r in rows)
        assert [r[1] for r in rows] == [True, False, False]

        # Gecici kodun DOGRU kisiye gittigi: birincil'in telefonu p1 olmali.
        assert rows[0][4] == p1

        with owner_conn.cursor() as cur:
            cur.execute(
                "SELECT ad, yonetim_email, kurulum_tamamlandi FROM tenant WHERE id = %s",
                (tid,),
            )
            t = cur.fetchone()
        assert t[0] == "Coklu Sitesi"
        assert t[1] == "yonetim@coklu.com"
        # ad verildi ama birincil yine ONAYLAR.
        assert t[2] is False
    finally:
        _tenant_sil(owner_conn, tid)


def test_ad_verilmezse_placeholder(client, world, owner_conn):
    admin = _admin(client, world)
    r = client.post(
        "/tenants",
        headers=admin,
        json={"yoneticiler": [{"ad": "Tek Yonetici", "phone": _uphone()}]},
    )
    assert r.status_code == 201, r.text
    tid = r.json()["tenant_id"]
    try:
        with owner_conn.cursor() as cur:
            cur.execute(
                "SELECT ad, kurulum_tamamlandi FROM tenant WHERE id = %s", (tid,)
            )
            t = cur.fetchone()
        assert t[0] == "(Kurulum bekliyor)"
        assert t[1] is False
    finally:
        _tenant_sil(owner_conn, tid)


def test_yonetim_email_opsiyonel(client, world, owner_conn):
    admin = _admin(client, world)
    r = client.post(
        "/tenants",
        headers=admin,
        json={"yoneticiler": [{"ad": "Mailsiz Yon", "phone": _uphone()}]},
    )
    assert r.status_code == 201, r.text
    tid = r.json()["tenant_id"]
    try:
        with owner_conn.cursor() as cur:
            cur.execute("SELECT yonetim_email FROM tenant WHERE id = %s", (tid,))
            assert cur.fetchone()[0] is None
    finally:
        _tenant_sil(owner_conn, tid)


def test_payload_ici_telefon_tekrari_422(client, world):
    admin = _admin(client, world)
    p = _uphone()
    r = client.post(
        "/tenants",
        headers=admin,
        json={"yoneticiler": [{"ad": "Aaa", "phone": p}, {"ad": "Bbb", "phone": p}]},
    )
    assert r.status_code == 422, r.text


def test_bos_yonetici_listesi_422(client, world):
    admin = _admin(client, world)
    assert client.post("/tenants", headers=admin, json={"yoneticiler": []}).status_code == 422


def test_yoneticiler_alani_zorunlu_422(client, world):
    admin = _admin(client, world)
    assert client.post("/tenants", headers=admin, json={"ad": "Yonetsiz"}).status_code == 422


def test_mevcut_telefon_409_ve_tenant_olusmaz(client, world, owner_conn):
    """Cakisma tek transaction'da geri alinir -> yarim tenant kalmaz."""
    admin = _admin(client, world)
    with owner_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM tenant")
        once = cur.fetchone()[0]

    r = client.post(
        "/tenants",
        headers=admin,
        json={
            "ad": "Catisan Tesis",
            "yoneticiler": [{"ad": "Catisan", "phone": world["yonetici_a"]["phone"]}],
        },
    )
    assert r.status_code == 409, r.text

    with owner_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM tenant")
        assert cur.fetchone()[0] == once, "409'dan sonra tenant OLUSMAMALI"


def test_ikinci_yonetici_telefon_cakismasi_409_tenant_olusmaz(client, world, owner_conn):
    """Cakisma LISTENIN ORTASINDA olsa da tenant olusmamali."""
    admin = _admin(client, world)
    with owner_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM tenant")
        once = cur.fetchone()[0]

    r = client.post(
        "/tenants",
        headers=admin,
        json={
            "yoneticiler": [
                {"ad": "Saglam Yon", "phone": _uphone()},
                {"ad": "Catisan Yon", "phone": world["guard_a"]["phone"]},
            ]
        },
    )
    assert r.status_code == 409, r.text
    with owner_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM tenant")
        assert cur.fetchone()[0] == once
