"""(P181 Bölüm 6.5) Bildirim TOPLU işlemler — okundu/sil, kapsam, yumuşak silme,
denetim kaydı. Yönetim alarmları (user_id NULL) admin kapsamındadır."""
import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _bildirim_ekle(owner_conn, tenant_id, n=3):
    ids = []
    for i in range(n):
        nid = uuid.uuid4()
        owner_conn.execute(
            "INSERT INTO notification (id, tenant_id, tip, user_id, mesaj, okundu) "
            "VALUES (%s,%s,'kacirilan_tur',NULL,%s,false)",
            (nid, tenant_id, f"test-{i}"),
        )
        ids.append(str(nid))
    owner_conn.commit()
    return ids


def test_toplu_okundu_secilenleri_isaretler(client, world, owner_conn):
    ids = _bildirim_ekle(owner_conn, world["a"], 3)
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/notifications/toplu-okundu",
        headers=admin, json={"ids": ids[:2], "okundu": True},
    )
    assert r.status_code == 200, r.text
    assert r.json()["etkilenen"] == 2
    okunmus = client.get(
        "/notifications", headers=admin, params={"okundu": True}
    ).json()
    assert okunmus["meta"]["total"] >= 2


def test_toplu_sil_YUMUSAK_siler_listeden_gizler_ve_DENETIM(client, world, owner_conn):
    ids = _bildirim_ekle(owner_conn, world["a"], 3)
    admin = _headers(client, world["slug_a"], world["admin_a"])
    once = client.get("/notifications", headers=admin).json()["meta"]["total"]
    r = client.post("/notifications/toplu-sil", headers=admin, json={"ids": ids[:1]})
    assert r.status_code == 200, r.text
    assert r.json()["etkilenen"] == 1
    sonra = client.get("/notifications", headers=admin).json()["meta"]["total"]
    assert sonra == once - 1  # silinen listede yok

    # (E2E 2026-09, goc 0149) Paylasilan yonetim alarminda silme KISIYE
    # aittir: satir DURUR, silindi_at kisinin durum satirina yazilir.
    row = owner_conn.execute(
        "SELECT silindi_at FROM notification_kisi_durumu WHERE notification_id=%s",
        (ids[0],),
    ).fetchone()
    assert row is not None and row[0] is not None, "yumuşak silme silindi_at yazmadı"

    denetim = owner_conn.execute(
        "SELECT count(*) FROM audit_log WHERE tenant_id=%s AND action='notification_delete'",
        (world["a"],),
    ).fetchone()
    assert denetim[0] >= 1, "silme denetim kaydı yazılmadı"


def test_toplu_sil_zaten_SILINENI_tekrar_islemez(client, world, owner_conn):
    ids = _bildirim_ekle(owner_conn, world["a"], 2)
    admin = _headers(client, world["slug_a"], world["admin_a"])
    client.post("/notifications/toplu-sil", headers=admin, json={"ids": ids})
    r = client.post("/notifications/toplu-sil", headers=admin, json={"ids": ids})
    assert r.json()["etkilenen"] == 0


def test_tumunu_okundu(client, world, owner_conn):
    _bildirim_ekle(owner_conn, world["a"], 3)
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/notifications/tumunu-okundu", headers=admin)
    assert r.status_code == 200, r.text
    assert r.json()["etkilenen"] >= 3
    okunmamis = client.get(
        "/notifications", headers=admin, params={"okundu": False}
    ).json()
    assert okunmamis["meta"]["total"] == 0


def test_KAPSAM_disi_tenant_ETKILENMEZ(client, world, owner_conn):
    ids_b = _bildirim_ekle(owner_conn, world["b"], 2)
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/notifications/toplu-okundu",
        headers=admin_a, json={"ids": ids_b, "okundu": True},
    )
    assert r.json()["etkilenen"] == 0  # RLS + kapsam: başka tenant görünmez


def test_PAYLASILAN_alarmda_OKUNDU_ve_SILME_KISIYE_AIT(client, world, owner_conn):
    """(E2E 2026-09) Bir guvenlik gorevlisinin okumasi/silmesi yoneticinin
    listesini degistiriyordu (tek satir paylasiliyordu)."""
    ids = _bildirim_ekle(owner_conn, world["a"], 2)
    guard = _headers(client, world["slug_a"], world["guard_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])

    r = client.patch(f"/notifications/{ids[0]}", headers=guard, json={"okundu": True})
    assert r.status_code == 200 and r.json()["okundu"] is True, r.text
    r = client.post("/notifications/toplu-sil", headers=guard, json={"ids": [ids[1]]})
    assert r.json()["etkilenen"] == 1

    admin_okunmamis = {
        n["id"] for n in client.get(
            "/notifications", headers=admin, params={"okundu": False, "limit": 200}
        ).json()["items"]
    }
    assert ids[0] in admin_okunmamis, "gorevlinin okumasi yoneticiye yansidi"
    assert ids[1] in admin_okunmamis, "gorevlinin silmesi yoneticiye yansidi"
    guard_hepsi = {
        n["id"] for n in client.get(
            "/notifications", headers=guard, params={"limit": 200}
        ).json()["items"]
    }
    assert ids[1] not in guard_hepsi, "silen kisi hala goruyor"
