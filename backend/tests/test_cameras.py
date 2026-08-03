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


# --------------------------------------------------------------------------- #
# RESTREAM (0012 / P17) — RTSP kamerayi OYNATILABILIR yapar
# --------------------------------------------------------------------------- #
def test_rtsp_restreamsiz_OYNATILAMAZ(client, world):
    """Davranis DEGISMEDI: restream yoksa rtsp hala oynatilamaz."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/cameras", headers=admin, json={
        "ad": f"rtsp-yalin-{uuid.uuid4().hex[:6]}",
        "stream_url": "rtsp://10.0.0.5:554/stream1", "tur": "rtsp",
    })
    assert r.status_code == 201, r.text
    assert r.json()["oynatilabilir"] is False
    assert r.json()["restream_url"] is None


def test_restream_RTSP_kamerayi_oynatilabilir_yapar(client, world):
    """P15'te olculdu: go2rtc'nin yeniden yayini gercekten oynatilabilir."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/cameras", headers=admin, json={
        "ad": f"rtsp-gecitli-{uuid.uuid4().hex[:6]}",
        "stream_url": "rtsp://10.0.0.5:554/stream1", "tur": "rtsp",
        "restream_url": "http://frigate.local:5000/api/kapi/stream.m3u8",
    })
    assert r.status_code == 201, r.text
    govde = r.json()
    assert govde["oynatilabilir"] is True, "restream varken rtsp OYNATILABILIR"
    # Kameranin KENDI adresi KORUNUR — gecit bozulunca kaybolmasin.
    assert govde["stream_url"] == "rtsp://10.0.0.5:554/stream1"


def test_restream_SONRADAN_eklenip_kaldirilabilir(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    kid = client.post("/cameras", headers=admin, json={
        "ad": f"rtsp-sonradan-{uuid.uuid4().hex[:6]}",
        "stream_url": "rtsp://10.0.0.6:554/s", "tur": "rtsp",
    }).json()["id"]

    r = client.patch(f"/cameras/{kid}", headers=admin, json={
        "restream_url": "https://gecit.example/api/kapi/stream.m3u8"})
    assert r.status_code == 200 and r.json()["oynatilabilir"] is True

    # null gonderilince gecit KALKAR ve kamera yeniden oynatilamaz olur.
    r2 = client.patch(f"/cameras/{kid}", headers=admin,
                      json={"restream_url": None})
    assert r2.status_code == 200
    assert r2.json()["restream_url"] is None
    assert r2.json()["oynatilabilir"] is False


def test_restream_YALNIZ_http_olabilir(client, world):
    """rtsp gecit adresi "oynatilabilir isaretli ama OYNAMAYAN" kamera uretirdi."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/cameras", headers=admin, json={
        "ad": f"kotu-gecit-{uuid.uuid4().hex[:6]}",
        "stream_url": "rtsp://10.0.0.7:554/s", "tur": "rtsp",
        "restream_url": "rtsp://10.0.0.7:8554/kapi",
    })
    assert r.status_code == 422


def test_hls_kamerada_restream_davranisi_bozmaz(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/cameras", headers=admin, json={
        "ad": f"hls-{uuid.uuid4().hex[:6]}",
        "stream_url": "https://ornek/stream.m3u8", "tur": "hls",
    })
    assert r.json()["oynatilabilir"] is True
    assert r.json()["restream_url"] is None


# ---------------------- P121 / 0031: anlik kare adresi ---------------------- #
# Izgara karosu oynatici ACMADAN goruntu gosterir; kareyi bu adresten ceker.
# Uc adres UC AYRI SEYDIR: stream (kameranin kendisi), restream (gecidin
# oynatilabilir yayini), snapshot (tek kare). Testler ucunun BIRBIRINDEN
# BAGIMSIZ oldugunu olcer — birini otekinin yerine kullanmak, karonun
# sessizce bos kalmasiyla sonuclanirdi.

_SNAP = "http://frigate.local:5000/api/kapi/latest.jpg"


def test_snapshot_EKLEMELI_varsayilani_None(client, world):
    """Alan opsiyoneldir: verilmezse davranis DEGISMEZ (geriye uyum)."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    cam = _mk_cam(client, admin)
    assert cam["snapshot_url"] is None


def test_snapshot_yazilir_ve_okunur(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    cam = _mk_cam(client, admin, snapshot_url=_SNAP)
    assert cam["snapshot_url"] == _SNAP
    # Listede de gorunmeli: karo listeden cizilir, tekil GET'ten degil.
    r = client.get("/cameras", headers=admin, params={"limit": 200})
    kayit = next(x for x in r.json()["items"] if x["id"] == cam["id"])
    assert kayit["snapshot_url"] == _SNAP


def test_snapshot_SONRADAN_eklenip_kaldirilabilir(client, world):
    """Frigate (P17) alani SONRADAN dolduracak; PATCH yolu calismali."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    cam = _mk_cam(client, admin)
    r1 = client.patch(f"/cameras/{cam['id']}", headers=admin,
                      json={"snapshot_url": _SNAP})
    assert r1.status_code == 200, r1.text
    assert r1.json()["snapshot_url"] == _SNAP
    r2 = client.patch(f"/cameras/{cam['id']}", headers=admin,
                      json={"snapshot_url": None})
    assert r2.status_code == 200, r2.text
    assert r2.json()["snapshot_url"] is None


def test_snapshot_YALNIZ_http_olabilir(client, world):
    """`rtsp://` bir KARE adresi olamaz — istemci onu goruntu gibi cekemez.

    Sema burada reddedilmezse belirti "kamera calismiyor" diye gorunur ve
    teshis kamerada aranir, KAYITTA degil.
    """
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/cameras", headers=admin, json={
        "ad": f"kotu-kare-{uuid.uuid4().hex[:6]}",
        "stream_url": _HLS, "tur": "hls",
        "snapshot_url": "rtsp://10.0.0.7:554/kare.jpg",
    })
    assert r.status_code == 422, r.text
    assert r.json()["error"]["code"] == "invalid_stream_url"


def test_snapshot_PATCH_te_de_dogrulanir(client, world):
    """POST'ta reddedilip PATCH'te kabul edilen bir kural, kural degildir.

    KOD OLCULUR, YALNIZ DURUM KODU DEGIL. Router dogrulamasi kaldirildiginda
    istek YINE 422 doner — ama sema kisitindan (`ck_camera_snapshot_sema`),
    ve o yol generik `validation_error` + "Değer kısıt ihlali." uretir.
    Yani yalniz `422` beklemek router dogrulamasinin varligini HIC olcmez:
    mutasyon denemesinde bu test tam olarak boyle sessiz kaldi (olculdu).
    Kullanici acisindan fark buyuktur — hangi alanin yanlis oldugunu
    soyleyen bir cumle ile "kisit ihlali" arasindaki fark.
    """
    admin = _headers(client, world["slug_a"], world["admin_a"])
    cam = _mk_cam(client, admin)
    r = client.patch(f"/cameras/{cam['id']}", headers=admin,
                     json={"snapshot_url": "rtsp://10.0.0.7:554/k.jpg"})
    assert r.status_code == 422, r.text
    assert r.json()["error"]["code"] == "invalid_stream_url", r.text
    # Mesaj ALANI isaret etmeli (kullanici hangi kutuya bakacagini bilsin).
    assert "http" in r.json()["error"]["message"], r.text


def test_snapshot_OYNATILABILIRI_degistirmez(client, world):
    """Kare adresi VIDEO degildir: rtsp kamerayi oynatilabilir YAPMAZ.

    Aksi halde kullanici karoda goruntu gorup dokunur ve oynatici acilmaz —
    kare ile yayin birbirinin yerine gecemez.
    """
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/cameras", headers=admin, json={
        "ad": f"rtsp-kare-{uuid.uuid4().hex[:6]}",
        "stream_url": _RTSP, "tur": "rtsp", "snapshot_url": _SNAP,
    })
    assert r.status_code == 201, r.text
    assert r.json()["oynatilabilir"] is False
    assert r.json()["snapshot_url"] == _SNAP


def test_snapshot_de_SINIRLI(client, world):
    """P25a siniri bu alan icin de gecerli (listeyi sisiren yapistirma)."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/cameras", headers=admin, json={
        "ad": f"uzun-kare-{uuid.uuid4().hex[:6]}",
        "stream_url": _HLS, "snapshot_url": "https://o/" + "a" * 2049,
    })
    assert r.status_code == 422, r.text


def test_snapshot_KVKK_suzgecini_delmez(client, world):
    """Gizli kamera, kare adresi olsa bile sakine SIZMAZ."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    gizli = _mk_cam(client, admin, snapshot_url=_SNAP,
                    aktif=True, sakin_gorebilir=False)
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    r = client.get("/cameras", headers=sakin, params={"limit": 200})
    assert gizli["id"] not in [x["id"] for x in r.json()["items"]]


# ------------------------- P25a: adres UZUNLUK siniri ----------------------- #
# Sinirsiz `text` sutunu, yapistirilan bir DVR yapilandirmasinin tamamini
# kabul edip listeyi ve mobil kart cizimini sisiriyordu. Sinir UC katmanda:
# mobil form, sema dogrulayicisi (422 katalog metni) ve 0015 CHECK kisiti.
def _uzun(n: int) -> str:
    """Tam `n` karakterlik GECERLI bir https adresi."""
    onek = "https://ornek.test/"
    return onek + "a" * (n - len(onek))


def test_p25_stream_url_SINIR_KABUL_asim_RET(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    tam = _uzun(2048)
    assert len(tam) == 2048
    r = client.post("/cameras", headers=admin, json={
        "ad": f"sinir-{uuid.uuid4().hex[:6]}", "stream_url": tam, "tur": "hls",
    })
    assert r.status_code == 201, "TAM 2048 kabul edilmeli (sinir DAHIL)"

    r2 = client.post("/cameras", headers=admin, json={
        "ad": f"asim-{uuid.uuid4().hex[:6]}", "stream_url": _uzun(2049),
        "tur": "hls",
    })
    assert r2.status_code == 422
    assert r2.json()["error"]["code"] == "invalid_stream_url"


def test_p25_uzunluk_hatasi_SEMA_hatasindan_AYRI(client, world):
    """Uzunluk SEMADAN ONCE olculur: 3 KB'lik bir yapistirmada
    "https ile baslamali" demek yaniltici olurdu — adres zaten https."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/cameras", headers=admin, json={
        "ad": f"uzun-hls-{uuid.uuid4().hex[:6]}", "stream_url": _uzun(3000),
        "tur": "hls",
    })
    assert r.status_code == 422
    mesaj = r.json()["error"]["message"]
    # Katalog metni UZUNLUGU ve SINIRI soyler; sema cumlesi degildir.
    assert "2048" in mesaj and "3000" in mesaj, mesaj
    assert "https" not in mesaj.lower(), f"sema cumlesi sizmis: {mesaj}"


def test_p25_uzunluk_hatasi_YEDI_DILDE(client, world):
    """Hata METNI kimlik uzerinden cevrilir (ham cumle degil)."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    gorulen = set()
    for dil in ("tr", "en", "ar", "ru", "de", "fr", "es"):
        r = client.post(
            "/cameras",
            headers={**admin, "Accept-Language": dil},
            json={"ad": f"dil-{dil}-{uuid.uuid4().hex[:6]}",
                  "stream_url": _uzun(2100), "tur": "hls"},
        )
        assert r.status_code == 422, dil
        m = r.json()["error"]["message"]
        assert m.strip(), dil
        assert "2048" in m and "2100" in m, (dil, m)
        gorulen.add(m)
    assert len(gorulen) == 7, "diller ayni metni donduruyor (ceviri eksik)"


def test_p25_restream_de_SINIRLI(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/cameras", headers=admin, json={
        "ad": f"gecit-uzun-{uuid.uuid4().hex[:6]}",
        "stream_url": "rtsp://10.0.0.9:554/s", "tur": "rtsp",
        "restream_url": _uzun(2049),
    })
    assert r.status_code == 422
    assert "2049" in r.json()["error"]["message"]


def test_p25_PATCH_te_de_olculur(client, world):
    """Guncelleme yolu ayri bir kod yolu — sinir orada da gecerli."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    kid = client.post("/cameras", headers=admin, json={
        "ad": f"patch-{uuid.uuid4().hex[:6]}",
        "stream_url": "https://ornek/stream.m3u8", "tur": "hls",
    }).json()["id"]
    r = client.patch(f"/cameras/{kid}", headers=admin,
                     json={"stream_url": _uzun(2049)})
    assert r.status_code == 422
    # Kayit DEGISMEDI (yarim guncelleme yok). Tekil GET ucu YOK — listeden
    # okunur.
    liste = client.get("/cameras", headers=admin,
                       params={"limit": 200}).json()["items"]
    kalan = next(k for k in liste if k["id"] == kid)
    assert kalan["stream_url"] == "https://ornek/stream.m3u8"


def test_p25_veritabani_kisiti_UYGULAMAYI_ATLAYANI_da_durdurur(
    owner_conn, world
):
    """Uygulama katmani tek savunma OLMAMALI: bu sutunlara ileride bir toplu
    ice aktarma ya da bakim betigi de yazabilir (0015 CHECK)."""
    import psycopg

    with owner_conn.cursor() as cur:
        try:
            cur.execute(
                "INSERT INTO camera (tenant_id, ad, stream_url, tur) "
                "VALUES (%s, %s, %s, 'hls'::camera_tur)",
                (world["a"], f"ham-{uuid.uuid4().hex[:6]}", "x" * 2049),
            )
        except psycopg.errors.CheckViolation as exc:
            owner_conn.rollback()
            assert "uzunluk" in str(exc)
        else:
            owner_conn.rollback()
            raise AssertionError("2049 karakterlik adres CHECK'e takilmadi")
