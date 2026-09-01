"""Kullanici yonetimi: liste/detay/olustur/guncelle + RBAC + tenant izolasyon + login."""
from __future__ import annotations

import uuid



def _p197_mail() -> str:
    """(P197) Kullanici/sakin olusturmada e-posta ZORUNLU oldu.

    `app_user.email` NOT NULL (goc 0089): davet, dogrulama kodu ve parola
    sifirlama YALNIZ e-postadan gidiyor, yani e-postasiz acilan hesap
    sahiplenilemez. Test govdelerine BENZERSIZ adres verilir —
    `uq_app_user_tenant_email` ayni tesiste tekrari reddeder.
    """
    return f"p197-{uuid.uuid4().hex[:12]}@ornek.com"

def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _login_status(client, slug, email, password):
    return client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": email, "password": password},
    ).status_code


def _uphone() -> str:
    """Benzersiz gecerli (E.164) test telefonu — telefon artik global benzersiz
    zorunlu login anahtaridir; world/seed numaralariyla cakismaz."""
    return "+90" + str(uuid.uuid4().int)[:10]


# -------------------------------- liste ------------------------------------ #
def test_list_users_no_password_hash_and_filters(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.get("/users", headers=admin)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["meta"]["total"] >= 4  # admin/guard/cleaner/resident (seed/world)
    for u in body["items"]:
        assert "password_hash" not in u  # ASLA donmez
        assert {"id", "ad", "email", "role", "is_active", "created_at"} <= set(u)

    # role filtresi
    sec = client.get("/users", headers=admin, params={"role": "security"}).json()["items"]
    assert all(u["role"] == "security" for u in sec)
    # is_active filtresi
    act = client.get("/users", headers=admin, params={"is_active": True}).json()["items"]
    assert all(u["is_active"] is True for u in act)


def test_list_users_rbac_and_isolation(client, world):
    guard = _headers(client, world["slug_a"], world["guard_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])
    for h in (guard, gorevli, resident):
        assert client.get("/users", headers=h).status_code == 403

    # tenant izolasyonu: A admin'i B kullanicisini goremez
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    a_emails = {u["email"] for u in client.get("/users", headers=admin_a).json()["items"]}
    b_ids = [u["id"] for u in client.get("/users", headers=admin_b).json()["items"]]
    # A'nin gordukleri B'nin id'leriyle kesismez
    a_ids = {u["id"] for u in client.get("/users", headers=admin_a).json()["items"]}
    assert a_ids.isdisjoint(set(b_ids))
    assert "guard@example.com" in a_emails


# ------------------------------ olustur ------------------------------------ #
def test_create_user_credentialless_and_email_conflict(client, world):
    """(P186) Yonetici PAROLA ATAMAZ: olusturulan hesap PAROLASIZDIR, dogrudan
    GIREMEZ (sahiplenme davet/Tesis ID yoluyladir). Ayni e-posta tekrar -> 409."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    email = f"yeni-{uuid.uuid4().hex[:8]}@acme.com"

    r = client.post(
        "/users",
        headers=admin,
        json={"ad": "Yeni Personel", "email": email, "telefon": _uphone(), "role": "security"},
    )
    assert r.status_code == 201, r.text
    assert r.json()["role"] == "security" and r.json()["is_active"] is True
    assert "password_hash" not in r.json()
    assert "temp_code" not in r.json()  # (P186) gecici kod da URETILMEZ

    # PAROLASIZ hesap DOGRUDAN GIREMEZ (herhangi bir parola -> 401)
    assert _login_status(client, world["slug_a"], email, "HerhangiParola1!") == 401

    # ayni email tekrar -> 409
    dup = client.post(
        "/users",
        headers=admin,
        json={"ad": "x", "email": email, "telefon": _uphone(), "role": "tesis_gorevlisi"},
    )
    assert dup.status_code == 409 and dup.json()["error"]["code"] == "conflict"


def test_create_user_rbac(client, world):
    guard = _headers(client, world["slug_a"], world["guard_a"])
    r = client.post(
        "/users",
        headers=guard,
        json={"ad": "x", "email": f"x-{uuid.uuid4().hex[:6]}@a.com", "telefon": _uphone(), "role": "resident", "password": "Parola123!"},
    )
    assert r.status_code == 403


# ------------------- yonetici saha personeli acar (Ozellik 3) -------------- #
def test_yonetici_creates_field_staff(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    # (P186) parola/gecici kod YOK: hesap parolasiz acilir, DAVET gonderilir.
    r = client.post(
        "/users",
        headers=yon,
        json={"ad": "Yeni Guard", "email": f"guard-{uuid.uuid4().hex[:8]}@acme.com", "telefon": _uphone(), "role": "security"},
    )
    assert r.status_code == 201, r.text
    assert "temp_code" not in r.json()
    assert r.json()["davet"] is not None  # davet ozeti doner
    # tesis_gorevlisi de acilabilir
    r2 = client.post(
        "/users",
        headers=yon,
        json={"ad": "Yeni Temizlik", "email": f"temizlik-{uuid.uuid4().hex[:8]}@acme.com", "telefon": _uphone(), "role": "tesis_gorevlisi"},
    )
    assert r2.status_code == 201, r2.text


# (P185) email artik ZORUNLU — eksik email -> 422 (login degil, dogrulama kanali).
def test_create_user_email_required(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/users",
        headers=admin,
        # E-POSTA BILEREK YOK: bu testin OLCTUGU sey tam olarak reddedilmesi.
        json={"ad": "Epostasiz", "telefon": _uphone(), "role": "security",
              "password": "Parola123!"},
    )
    assert r.status_code == 422, r.text


# (P185) yonetici artik BASKA bir yonetici acabilir (es-yonetici ekleme).
def test_yonetici_creates_co_manager(client, world):
    from app.roller import yonetilebilir

    assert "yonetici" in yonetilebilir("yonetici")
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post(
        "/users",
        headers=yon,
        json={
            "ad": "Es Yonetici",
            "email": f"esyon-{uuid.uuid4().hex[:8]}@acme.com",
            "telefon": _uphone(),
            "role": "yonetici",
            "password": "Parola123!",
        },
    )
    assert r.status_code == 201, r.text
    assert r.json()["role"] == "yonetici"


# (P185) bir yonetici bir daireye ATANABILIR (yonetici ayni zamanda malik/sakin
# olabilir). Onceden yalniz `resident` atanabiliyordu.
def test_yonetici_can_be_assigned_to_unit(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    yon_h = _headers(client, world["slug_a"], world["yonetici_a"])
    yon_id = client.get("/me", headers=yon_h).json()["id"]

    unit = client.post(
        "/units", headers=admin, json={"no": f"Y-{uuid.uuid4().hex[:6]}", "blok": "A"}
    )
    assert unit.status_code == 201, unit.text
    uid = unit.json()["id"]

    asg = client.post(
        f"/units/{uid}/residents",
        headers=admin,
        json={"user_id": yon_id, "rol_tipi": "malik"},
    )
    assert asg.status_code == 201, asg.text


def test_yonetici_cannot_create_yetki_yukseltmesi(client, world):
    """(Duzeltme turu) `resident` BU LISTEDEN CIKTI; (P185) `yonetici` DE CIKTI.

    Yonetici kendi tesisinin sakinini YONETIR (acar/duzenler/pasiflestirir) ve
    (P185) es-yonetici EKLER. Yasak kalan kume yetki YUKSELTMESI olanlardir:
    platform admini ve dis sirket amiri.

    Liste ELLE tutulmaz — kaynak `app/roller.py`. Boylece tablo degisince
    bu test de kendiliginde dogru kalir (matrisin TAMAMI ayrica
    `test_rol_olusturma_matrisi.py`de olculur).
    """
    from app.roller import yonetilebilir

    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    yasak = sorted(set(("admin", "guvenlik_amiri")) - yonetilebilir("yonetici"))
    assert yasak, "yasak kume bosaldi — kural gevsemis olabilir"
    for role in yasak:
        r = client.post(
            "/users",
            headers=yon,
            json={"ad": "x", "email": f"y-{uuid.uuid4().hex[:8]}@acme.com", "telefon": _uphone(), "role": role, "password": "Parola123!"},
        )
        assert r.status_code == 403, (role, r.text)
        assert r.json()["error"]["code"] == "forbidden"


# ------------------------------ guncelle ----------------------------------- #
def test_update_user_role_active_password(client, world, owner_conn):
    """(P186) Yonetici PAROLA ATAYAMAZ — PATCH `password` YOKSAYILIR. Bu test
    yalnizca rol + is_active guncellemesini olculur. Login'in gercekten parolaya
    ve is_active'e baglandigini dogrulamak icin parola DB'ye dogrudan yazilir
    (world fixture'inin yaptigi gibi), cunku olusturma/patch parolasizdir."""
    from app.security import hash_password

    admin = _headers(client, world["slug_a"], world["admin_a"])
    email = f"upd-{uuid.uuid4().hex[:8]}@acme.com"
    created = client.post(
        "/users",
        headers=admin,
        json={"ad": "Guncellenecek", "email": email, "telefon": _uphone(), "role": "tesis_gorevlisi"},
    ).json()
    uid = created["id"]

    # rol + pasiflestir
    pr = client.patch(f"/users/{uid}", headers=admin, json={"role": "security", "is_active": False})
    assert pr.status_code == 200
    assert pr.json()["role"] == "security" and pr.json()["is_active"] is False

    # parola DB'ye dogrudan yazilir (yonetici arayuzunden atanamaz)
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE app_user SET password_hash=%s, password_set=true WHERE id=%s",
            (hash_password("YeniParola9!"), uid),
        )

    # is_active False iken login reddedilir; True yapinca parola ile login olur
    assert _login_status(client, world["slug_a"], email, "YeniParola9!") == 401
    client.patch(f"/users/{uid}", headers=admin, json={"is_active": True})
    assert _login_status(client, world["slug_a"], email, "YeniParola9!") == 200
    assert _login_status(client, world["slug_a"], email, "YanlisParola1!") == 401


def test_update_user_email_and_conflict(client, world):
    """(P186 §2.2/§2.4) TAMAMLANMAMIS hesapta e-posta guncellenir; BASKA
    kullanicinin e-postasina cakisma JENERIK 409 doner (hangi alan/hesap
    sizmaz). Tamamlanmis hesabin e-postasi ayri testte bloklanir
    (test_p186_email_change_after_completion_blocked)."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    eski = f"mail-eski-{uuid.uuid4().hex[:8]}@acme.com"
    # parola YOK -> tamamlanmamis (davet akisi); e-posta SERBEST degisir
    uid = client.post(
        "/users",
        headers=admin,
        json={"ad": "Mail Sahibi", "email": eski, "telefon": _uphone(), "role": "security"},
    ).json()["id"]

    # email guncelle -> 200, yanit yeni email'i tasir
    yeni = f"mail-yeni-{uuid.uuid4().hex[:8]}@acme.com"
    r = client.patch(f"/users/{uid}", headers=admin, json={"email": yeni})
    assert r.status_code == 200, r.text
    assert r.json()["email"] == yeni

    # baska kullanicinin email'ine guncelleme -> 409 conflict (anlasilir hata)
    digeri = f"mail-diger-{uuid.uuid4().hex[:8]}@acme.com"
    client.post(
        "/users",
        headers=admin,
        json={"ad": "Diger", "email": digeri, "telefon": _uphone(), "role": "tesis_gorevlisi"},
    )
    dup = client.patch(f"/users/{uid}", headers=admin, json={"email": digeri})
    assert dup.status_code == 409 and dup.json()["error"]["code"] == "conflict"


def test_update_user_tenant_isolation(client, world):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    # A'da kullanici olustur
    uid = client.post(
        "/users",
        headers=admin_a,
        json={"ad": "A user", "email": f"a-{uuid.uuid4().hex[:8]}@acme.com", "telefon": _uphone(), "role": "resident", "password": "Parola123!"},
    ).json()["id"]
    # B admin goremez / degistiremez -> 404 (RLS)
    assert client.get(f"/users/{uid}", headers=admin_b).status_code == 404
    assert client.patch(f"/users/{uid}", headers=admin_b, json={"ad": "x"}).status_code == 404


# ------------ yonetici saha personeli yonetimi (Parca C) -------------------- #
def _me_id(client, h):
    return client.get("/me", headers=h).json()["id"]


def test_yonetici_updates_field_staff(client, world, owner_conn):
    """(P186) Parola sifirlama ucu KALDIRILDI — yonetici saha personelinin
    yalnizca ad/telefon/rol/is_active bilgilerini duzenler. Login'in is_active'e
    baglandigi, parola DB'ye dogrudan yazilarak dogrulanir."""
    from app.security import hash_password

    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    phone = _uphone()
    created = client.post(
        "/users", headers=yon,
        json={"ad": "Saha X", "email": f"sahax-{uuid.uuid4().hex[:8]}@acme.com", "telefon": phone, "role": "security"},
    ).json()
    uid = created["id"]

    # yonetici ad/telefon/rol duzenler (saha ici)
    newphone = _uphone()
    pr = client.patch(
        f"/users/{uid}", headers=yon,
        json={"ad": "Saha Y", "telefon": newphone, "role": "tesis_gorevlisi"},
    )
    assert pr.status_code == 200, pr.text
    assert pr.json()["ad"] == "Saha Y" and pr.json()["role"] == "tesis_gorevlisi"

    # rolu `admin`e cekemez -> 403 (yetki yukseltme yok). (P185: `yonetici`ye
    # cekmek ARTIK serbest — es-yonetici; `admin` hâlâ kapali.)
    assert client.patch(
        f"/users/{uid}", headers=yon, json={"role": "admin"}
    ).status_code == 403

    # parola DB'ye yazilir (yonetici atayamaz); telefon + parola ile login olur
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE app_user SET password_hash=%s, password_set=true WHERE id=%s",
            (hash_password("SahaParola1!"), uid),
        )
    lp = client.post(
        "/auth/login-phone", json={"phone": newphone, "password": "SahaParola1!"}
    )
    assert lp.status_code == 200, lp.text

    # pasiflestir -> login reddedilir (is_active False)
    client.patch(f"/users/{uid}", headers=yon, json={"is_active": False})
    lp2 = client.post(
        "/auth/login-phone", json={"phone": newphone, "password": "SahaParola1!"}
    )
    assert lp2.status_code == 401


def test_yonetici_cannot_manage_yonetilemeyen_rolleri(client, world):
    """(Duzeltme turu) `resident_a` BU LISTEDEN CIKTI — artik yonetilebilir.
    (P185) `yonetici_a` DA CIKTI — es-yonetici yonetimi acildi.

    Kalan gercekten disaridadir: platform admini. Ona dokunmak yetki
    yukseltmesi olurdu.
    """
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    for cred in ("admin_a",):
        h = _headers(client, world["slug_a"], world[cred])
        uid = _me_id(client, h)
        assert client.patch(
            f"/users/{uid}", headers=yon, json={"ad": "X"}
        ).status_code == 403, cred


# ============================ P186 — duzenleme ============================== #
def _tel186() -> str:
    return "+90" + str(uuid.uuid4().int)[:10]


def test_p186_email_change_before_completion_ok(client, world):
    """(P186 §2.2) TAMAMLANMAMIS hesapta e-posta degisimi SERBEST; davet yeniden
    gonderilir (yan etki). Burada 200 + e-posta guncellendigi + kayit_tamamlandi
    False dogrulanir."""
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    eski = f"once-{uuid.uuid4().hex[:8]}@acme.com"
    # parola YOK -> password_set False (davet akisi)
    created = client.post(
        "/users", headers=yon,
        json={"ad": "Davetli", "email": eski, "telefon": _tel186(), "role": "security"},
    ).json()
    uid = created["id"]
    detay = client.get(f"/users/{uid}", headers=yon).json()
    assert detay["kayit_tamamlandi"] is False

    yeni = f"sonra-{uuid.uuid4().hex[:8]}@acme.com"
    r = client.patch(f"/users/{uid}", headers=yon, json={"email": yeni})
    assert r.status_code == 200, r.text
    assert r.json()["email"] == yeni


def test_p186_email_change_after_completion_blocked(client, world):
    """(P186 §2.2) TAMAMLANMIS hesabin e-postasini yonetici DEGISTIREMEZ (409).
    (P186: POST /users artik parola almadigindan tamamlanmis hesap uretmez;
    seed'deki `guard_a` password_set=true'dur ve yonetici onu yonetir.)"""
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    uid = client.get("/me", headers=guard).json()["id"]
    assert client.get(f"/users/{uid}", headers=yon).json()["kayit_tamamlandi"] is True

    yeni = f"yeni-{uuid.uuid4().hex[:8]}@acme.com"
    r = client.patch(f"/users/{uid}", headers=yon, json={"email": yeni})
    assert r.status_code == 409, r.text
    # AYNI e-postayi (degisiklik yok) gondermek reddedilmez:
    mevcut = world["guard_a"]["email"]
    assert client.patch(
        f"/users/{uid}", headers=yon, json={"email": mevcut, "aranabilir": True}
    ).status_code == 200


def test_p186_role_change_clears_unit_binding(client, world):
    """(P186 §2.3) Rol daire-tutan kumeden CIKINCA (resident->security) aktif
    daire bagi kaldirilir; detayda daire_id null olur."""
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    created = client.post(
        "/residents", headers=yon,
        json={"telefon": _tel186(), "unit_no": f"P186-{uuid.uuid4().hex[:4]}", "email": _p197_mail()},
    ).json()
    uid = created["user_id"]
    detay = client.get(f"/users/{uid}", headers=yon).json()
    assert detay["role"] == "resident"
    assert detay["daire_id"] == created["unit_id"]

    r = client.patch(f"/users/{uid}", headers=yon, json={"role": "security"})
    assert r.status_code == 200, r.text
    son = client.get(f"/users/{uid}", headers=yon).json()
    assert son["role"] == "security"
    assert son["daire_id"] is None  # bag kaldirildi

    # resident <-> yonetici gecisinde bag KORUNUR (ayri senaryo, ayni kume)


def test_p186_other_tenant_manager_cannot_edit(client, world):
    """(P186 §2.6) Baska tesisin yoneticisi/admini bu kullaniciyi duzenleyemez —
    RLS satiri hic gormez -> 404 (sunucu tarafi)."""
    yon_a = _headers(client, world["slug_a"], world["yonetici_a"])
    created = client.post(
        "/users", headers=yon_a,
        json={"ad": "A-Kisi", "email": f"a-{uuid.uuid4().hex[:8]}@acme.com",
              "telefon": _tel186(), "role": "security"},
    ).json()
    uid = created["id"]
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    assert client.patch(
        f"/users/{uid}", headers=admin_b, json={"ad": "Sizma"}
    ).status_code == 404
