"""(P147) Sakinin bildirim akisi — KALICI satir + KAPSAM ayrimi.

En kritik olculen sey KAPSAM: ayni tabloda iki ayri bildirim turu duruyor
(yonetim alarmi vs kisisel olay) ve karisirlarsa ya sakin tesisin isleyisini
gorur ya yonetim kisisel akisi gorur. Ikisi de ayri ayri olculuyor.
"""
import uuid


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_sakin_bildirim_ucunu_GOREBILIR(client, world):
    """Once 403 aliyordu — uc yonetim rollerine kapaliydi."""
    sakin = _h(client, world["slug_a"], world["resident_a"])
    r = client.get("/notifications", headers=sakin)
    assert r.status_code == 200, r.text


def test_talep_cozulunce_sakinin_listesine_KALICI_satir_duser(client, world):
    sakin = _h(client, world["slug_a"], world["resident_a"])
    mgr = _h(client, world["slug_a"], world["admin_a"])
    once = client.get("/notifications", headers=sakin).json()["meta"]["total"]
    t = client.post(
        "/complaints", headers=sakin,
        json={"baslik": f"Talep {uuid.uuid4().hex[:6]}", "mesaj": "Detayli mesaj."},
    )
    assert t.status_code == 201, t.text
    r = client.post(
        f"/complaints/{t.json()['id']}/resolve", headers=mgr,
        json={"cozum_notu": "Yapildi"},
    )
    assert r.status_code == 200, r.text
    liste = client.get("/notifications", headers=sakin).json()
    assert liste["meta"]["total"] == once + 1
    ust = liste["items"][0]
    assert ust["tip"] == "talep_cozuldu"
    # Metin KAYDA DONDURULMEDI: istegin dilinde uretiliyor.
    en = client.get(
        "/notifications", headers={**sakin, "Accept-Language": "en"}
    ).json()["items"][0]["mesaj"]
    assert en != ust["mesaj"]


def test_sakin_YONETIM_alarmlarini_GORMEZ(client, world, owner_conn):
    """`user_id IS NULL` satirlar tesise aittir — sakine sizmamali."""
    sakin = _h(client, world["slug_a"], world["resident_a"])
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO notification (tenant_id, tip, mesaj) "
            "SELECT id, 'kacirilan_tur', 'Kacirilan tur' "
            "FROM tenant WHERE slug = %s",
            (world["slug_a"],),
        )
    tipler = [
        b["tip"] for b in client.get("/notifications", headers=sakin).json()["items"]
    ]
    assert "kacirilan_tur" not in tipler


def test_yonetim_KISISEL_akisi_gormez(client, world):
    """Simetrik kusur: yonetim sakinin kisisel bildirimlerini gormemeli."""
    sakin = _h(client, world["slug_a"], world["resident_a"])
    mgr = _h(client, world["slug_a"], world["admin_a"])
    t = client.post(
        "/complaints", headers=sakin,
        json={"baslik": f"Talep {uuid.uuid4().hex[:6]}", "mesaj": "Detayli mesaj."},
    )
    client.post(
        f"/complaints/{t.json()['id']}/resolve", headers=mgr,
        json={"cozum_notu": "Yapildi"},
    )
    tipler = [
        b["tip"] for b in client.get("/notifications", headers=mgr).json()["items"]
    ]
    assert "talep_cozuldu" not in tipler


def test_baskasinin_bildirimi_okundu_ISARETLENEMEZ(client, world):
    """Yazma kapsami okuma kapsamiyla AYNI olmali (once degildi)."""
    sakin = _h(client, world["slug_a"], world["resident_a"])
    mgr = _h(client, world["slug_a"], world["admin_a"])
    t = client.post(
        "/complaints", headers=sakin,
        json={"baslik": f"Talep {uuid.uuid4().hex[:6]}", "mesaj": "Detayli mesaj."},
    )
    client.post(
        f"/complaints/{t.json()['id']}/resolve", headers=mgr,
        json={"cozum_notu": "Yapildi"},
    )
    bid = client.get("/notifications", headers=sakin).json()["items"][0]["id"]
    r = client.patch(f"/notifications/{bid}", headers=mgr, json={"okundu": True})
    assert r.status_code == 404, r.text
