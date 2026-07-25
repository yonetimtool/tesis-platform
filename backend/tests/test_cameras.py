"""Kamera yonetimi (WP-H) — CRUD + ROL BAZLI gorunurluk + tur/URL + RLS.

RBAC (auth.md §4): YAZMA admin+yonetici. OKUMA tum roller AMA gorunurluk
suzgeci SUNUCUDA: admin/yonetici/security TUMUNU; resident/tesis_gorevlisi
YALNIZ `aktif=true AND sakin_gorebilir=true` kameralari gorur.

Kritik iddia: sakin/gorevli yanitinda gizli kamera BULUNMAZ — durum kodu
degil, YANIT ICERIGI dogrulanir (403 yerine 200 + suzulmus liste).
"""
from __future__ import annotations

import uuid

import pytest

# hls/mp4 -> http(s); rtsp -> rtsp:// (sema tur ile tutarli olmali).
_HLS = "https://nvr.example.com/hls/1/index.m3u8"
_MP4 = "https://cdn.example.com/kayit/1.mp4"
_RTSP = "rtsp://nvr.example.com/kanal1"


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _mk_cam(client, headers, **over):
    body = {"ad": f"Kamera {uuid.uuid4().hex[:6]}", "stream_url": _HLS}
    body.update(over)
    r = client.post("/cameras", headers=headers, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def _ids(client, headers, **params):
    r = client.get("/cameras", headers=headers,
                   params={"limit": 200, **params})
    assert r.status_code == 200, r.text
    return r.json()


# ------------------------------ CRUD ---------------------------------------- #
def test_yonetici_crud_tam_alan_seti(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])

    ad = f"Ana Giriş {uuid.uuid4().hex[:6]}"
    c = _mk_cam(client, yonetici, ad=ad, konum="Ana Kapı - Giriş",
                tur="hls", sakin_gorebilir=True)
    assert c["konum"] == "Ana Kapı - Giriş"
    assert c["tur"] == "hls" and c["aktif"] is True
    assert c["sakin_gorebilir"] is True
    assert c["oynatilabilir"] is True

    # PATCH: ad + gorunurluk kapatma + pasiflestirme
    p = client.patch(f"/cameras/{c['id']}", headers=yonetici,
                     json={"ad": ad + "-2", "sakin_gorebilir": False,
                           "aktif": False, "konum": None})
    assert p.status_code == 200, p.text
    assert p.json()["ad"] == ad + "-2"
    assert p.json()["sakin_gorebilir"] is False
    assert p.json()["aktif"] is False and p.json()["konum"] is None

    assert client.delete(f"/cameras/{c['id']}", headers=yonetici).status_code == 204
    # admin de yazar
    a = _mk_cam(client, _headers(client, world["slug_a"], world["admin_a"]))
    assert client.delete(
        f"/cameras/{a['id']}",
        headers=_headers(client, world["slug_a"], world["admin_a"]),
    ).status_code == 204


def test_varsayilanlar_sakine_kapali_ve_aktif(client, world):
    """sakin_gorebilir varsayilani KAPALI (KVKK): unutulan bayrak kamerayi
    sakine ACMAZ."""
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    c = _mk_cam(client, yonetici)
    assert c["sakin_gorebilir"] is False
    assert c["aktif"] is True and c["konum"] is None


def test_ayni_ad_409(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    ad = f"Cakisan {uuid.uuid4().hex[:6]}"
    _mk_cam(client, yonetici, ad=ad)
    r = client.post("/cameras", headers=yonetici,
                    json={"ad": ad, "stream_url": _HLS})
    assert r.status_code == 409, r.text


# --------------------------- rol bazli gorunurluk --------------------------- #
@pytest.fixture
def uc_kamera(client, world):
    """Ayni tenant'ta 3 kamera: sakine acik / gizli / pasif-ama-acik."""
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    tag = uuid.uuid4().hex[:6]
    # URL'ler AYRI: "gizli kameranin URL'i yanitta yok" iddiasi ancak boyle
    # anlamlidir (ucu de ayni URL'i paylassa iddia yanlislikla patlar).
    gorunur = _mk_cam(client, yonetici, ad=f"Acik {tag}",
                      stream_url=f"https://nvr.example.com/hls/acik-{tag}.m3u8",
                      sakin_gorebilir=True, aktif=True)
    gizli = _mk_cam(client, yonetici, ad=f"Gizli {tag}",
                    stream_url=f"https://nvr.example.com/hls/gizli-{tag}.m3u8",
                    sakin_gorebilir=False, aktif=True)
    pasif = _mk_cam(client, yonetici, ad=f"Pasif {tag}",
                    stream_url=f"https://nvr.example.com/hls/pasif-{tag}.m3u8",
                    sakin_gorebilir=True, aktif=False)
    yield gorunur, gizli, pasif
    for c in (gorunur, gizli, pasif):
        client.delete(f"/cameras/{c['id']}", headers=yonetici)


@pytest.mark.parametrize("role", ["admin_a", "yonetici_a", "guard_a"])
def test_yonetim_ve_guvenlik_tum_kameralari_gorur(client, world, uc_kamera, role):
    gorunur, gizli, pasif = uc_kamera
    h = _headers(client, world["slug_a"], world[role])
    ids = [i["id"] for i in _ids(client, h)["items"]]
    for c in (gorunur, gizli, pasif):
        assert c["id"] in ids, (role, c["ad"])


@pytest.mark.parametrize("role", ["resident_a", "gorevli_a"])
def test_sakin_ve_gorevli_YALNIZ_acik_kameralari_gorur(
    client, world, uc_kamera, role
):
    """403 DEGIL 200 — ama gizli/pasif kamera yanitta HIC yok (icerik iddiasi)."""
    gorunur, gizli, pasif = uc_kamera
    h = _headers(client, world["slug_a"], world[role])
    body = _ids(client, h)
    items = body["items"]
    ids = [i["id"] for i in items]

    assert gorunur["id"] in ids
    assert gizli["id"] not in ids, "sakin_gorebilir=false kamera sizdi"
    assert pasif["id"] not in ids, "aktif=false kamera sizdi"
    # Sizinti sadece id'de degil: donen her kayit iki kosulu da saglar.
    assert all(i["aktif"] and i["sakin_gorebilir"] for i in items)
    # meta.total suzulmus kumeyi sayar (gizli kamera SAYISI bile sizmaz);
    # limit=200 oldugu icin total = donen kayit sayisi.
    assert body["meta"]["total"] == len(items)
    # Gizli kameranin yayin URL'i (asil sir) yanitin HICBIR yerinde yok.
    urller = [i["stream_url"] for i in items]
    assert gizli["stream_url"] not in urller
    assert pasif["stream_url"] not in urller
    assert gorunur["stream_url"] in urller


@pytest.mark.parametrize("role", ["resident_a", "gorevli_a"])
def test_sakin_aktif_parametresiyle_suzgeci_GENISLETEMEZ(
    client, world, uc_kamera, role
):
    """?aktif=false ile pasif/gizli kameralara ulasilamaz — suzgec sunucuda."""
    gorunur, gizli, pasif = uc_kamera
    h = _headers(client, world["slug_a"], world[role])
    for params in ({"aktif": "false"}, {"aktif": "true"}):
        items = _ids(client, h, **params)["items"]
        ids = [i["id"] for i in items]
        assert gizli["id"] not in ids and pasif["id"] not in ids
        assert all(i["aktif"] and i["sakin_gorebilir"] for i in items)


def test_yonetim_aktif_suzgeci(client, world, uc_kamera):
    gorunur, gizli, pasif = uc_kamera
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])

    aktifler = [i["id"] for i in _ids(client, yonetici, aktif="true")["items"]]
    assert gorunur["id"] in aktifler and gizli["id"] in aktifler
    assert pasif["id"] not in aktifler

    pasifler = [i["id"] for i in _ids(client, yonetici, aktif="false")["items"]]
    assert pasif["id"] in pasifler and gorunur["id"] not in pasifler


def test_yazma_rbac_saha_ve_sakin_403(client, world):
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.post("/cameras", headers=h, json={
            "ad": f"X{uuid.uuid4().hex[:4]}", "stream_url": _HLS,
        }).status_code == 403, role
        assert client.patch(f"/cameras/{uuid.uuid4()}", headers=h,
                            json={"ad": "Y"}).status_code == 403, role
        assert client.delete(f"/cameras/{uuid.uuid4()}",
                             headers=h).status_code == 403, role


# ------------------------------ tur / URL semasi ---------------------------- #
def test_rtsp_kabul_edilir_ama_oynatilabilir_false(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    c = _mk_cam(client, yonetici, tur="rtsp", stream_url=_RTSP)
    assert c["tur"] == "rtsp"
    assert c["oynatilabilir"] is False, "RTSP istemcide oynatilamaz"
    # Kayit gercekten saklanir (envanter) — listede aynen doner.
    ids = [i["id"] for i in _ids(client, yonetici)["items"]]
    assert c["id"] in ids


def test_mp4_ve_hls_oynatilabilir(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    assert _mk_cam(client, yonetici, tur="mp4",
                   stream_url=_MP4)["oynatilabilir"] is True
    assert _mk_cam(client, yonetici, tur="hls")["oynatilabilir"] is True


def test_url_semasi_tur_ile_tutarli_olmali_422(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    # hls/mp4 icin rtsp:// yasak
    for tur in ("hls", "mp4"):
        r = client.post("/cameras", headers=yonetici, json={
            "ad": f"K{uuid.uuid4().hex[:4]}", "stream_url": _RTSP, "tur": tur,
        })
        assert r.status_code == 422, (tur, r.text)
    # rtsp icin http(s) yasak
    r = client.post("/cameras", headers=yonetici, json={
        "ad": f"K{uuid.uuid4().hex[:4]}", "stream_url": _HLS, "tur": "rtsp",
    })
    assert r.status_code == 422, r.text
    # sema hic tanimli degil
    r = client.post("/cameras", headers=yonetici, json={
        "ad": f"K{uuid.uuid4().hex[:4]}", "stream_url": "ftp://nvr/x", "tur": "hls",
    })
    assert r.status_code == 422, r.text
    # gecersiz tur
    r = client.post("/cameras", headers=yonetici, json={
        "ad": f"K{uuid.uuid4().hex[:4]}", "stream_url": _HLS, "tur": "webrtc",
    })
    assert r.status_code == 422, r.text


def test_patch_tur_mevcut_url_ile_dogrulanir(client, world):
    """Yalniz `tur` degistirilse bile kayitli URL'in semasi uymak zorunda."""
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    c = _mk_cam(client, yonetici, tur="hls", stream_url=_HLS)

    r = client.patch(f"/cameras/{c['id']}", headers=yonetici, json={"tur": "rtsp"})
    assert r.status_code == 422, r.text  # http(s) URL + rtsp tur = tutarsiz

    # Ikisi birlikte gonderilirse gecerli
    r = client.patch(f"/cameras/{c['id']}", headers=yonetici,
                     json={"tur": "rtsp", "stream_url": _RTSP})
    assert r.status_code == 200, r.text
    assert r.json()["oynatilabilir"] is False


def test_patch_bos_govde_422(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    c = _mk_cam(client, yonetici)
    assert client.patch(f"/cameras/{c['id']}", headers=yonetici,
                        json={}).status_code == 422


# ----------------------------- tenant izolasyonu ---------------------------- #
def test_tenant_izolasyonu(client, world):
    yonetici_a = _headers(client, world["slug_a"], world["yonetici_a"])
    yonetici_b = _headers(client, world["slug_b"], world["yonetici_b"])
    c = _mk_cam(client, yonetici_a, ad=f"A-{uuid.uuid4().hex[:6]}",
                sakin_gorebilir=True)

    b_ids = [i["id"] for i in _ids(client, yonetici_b)["items"]]
    assert c["id"] not in b_ids
    assert client.patch(f"/cameras/{c['id']}", headers=yonetici_b,
                        json={"ad": "ele gecir"}).status_code == 404
    assert client.delete(f"/cameras/{c['id']}",
                         headers=yonetici_b).status_code == 404


# --------------------------- RLS (DB katmani) ------------------------------- #
@pytest.fixture
def iki_tenant_kamera(owner_conn):
    """2 tenant + birer kamera — RLS izolasyonu app_rw ile dogrulanir."""
    a, b = uuid.uuid4(), uuid.uuid4()
    with owner_conn.cursor() as cur:
        for tid, ad in ((a, "CAM-A"), (b, "CAM-B")):
            cur.execute(
                "INSERT INTO tenant (id, ad, slug) VALUES (%s,%s,%s)",
                (tid, ad, f"cam-{tid.hex[:8]}"),
            )
            cur.execute(
                "INSERT INTO camera (tenant_id, ad, konum, stream_url, tur, "
                "aktif, sakin_gorebilir) "
                "VALUES (%s,%s,%s,%s,'hls'::camera_tur,true,true)",
                (tid, f"{ad} kapi", "Giris", _HLS),
            )
    yield a, b
    with owner_conn.cursor() as cur:
        cur.execute("DELETE FROM tenant WHERE id IN (%s,%s)", (a, b))


def test_camera_rls_tenant_izole(app_conn, iki_tenant_kamera):
    a, b = iki_tenant_kamera
    for tenant in (a, b):
        app_conn.execute(
            "SELECT set_config('app.current_tenant_id', %s, true)", (str(tenant),)
        )
        rows = app_conn.execute(
            "SELECT tenant_id, sakin_gorebilir FROM camera"
        ).fetchall()
        assert len(rows) == 1 and rows[0][0] == tenant
        app_conn.rollback()


def test_camera_rls_baglamsiz_bos(app_conn, iki_tenant_kamera):
    # app.current_tenant_id set edilmedi => guvenli varsayilan: 0 satir.
    assert app_conn.execute("SELECT tenant_id FROM camera").fetchall() == []
