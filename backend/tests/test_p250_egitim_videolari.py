"""(P250 §4) KURULUM EGITIM VIDEOLARI — panel, liste, izlendi, surum.

`egitim_videosu` PLATFORM tablosudur (butun tesisler ayni videolari gorur);
test once tablonun icerigini saklar, sonunda AYNEN geri yazar — dev
ortamindaki gercek kayitlar bozulmasin.
"""
from __future__ import annotations

import pytest

from app.egitim_video import youtube_kimligi

V1 = "AbCdEfGhIj1"
V2 = "ZyXwVuTsRq2"


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def temiz_videolar(owner_conn):
    with owner_conn.cursor() as cur:
        cur.execute("SELECT * FROM egitim_videosu")
        kolonlar = [d.name for d in cur.description]
        yedek = cur.fetchall()
        cur.execute("DELETE FROM egitim_videosu")
    yield
    with owner_conn.cursor() as cur:
        cur.execute("DELETE FROM egitim_videosu")
        for satir in yedek:
            cur.execute(
                f"INSERT INTO egitim_videosu ({','.join(kolonlar)}) "
                f"VALUES ({','.join(['%s'] * len(kolonlar))})",
                satir,
            )


@pytest.mark.parametrize(
    "baglanti,beklenen",
    [
        ("https://www.youtube.com/watch?v=dQw4w9WgXcQ", "dQw4w9WgXcQ"),
        ("https://youtu.be/dQw4w9WgXcQ?si=abc", "dQw4w9WgXcQ"),
        ("https://www.youtube.com/shorts/dQw4w9WgXcQ", "dQw4w9WgXcQ"),
        ("https://m.youtube.com/watch?feature=share&v=dQw4w9WgXcQ&t=30", "dQw4w9WgXcQ"),
        ("dQw4w9WgXcQ", "dQw4w9WgXcQ"),
        ("https://vimeo.com/12345", None),
        ("https://kotu.com/watch?v=dQw4w9WgXcQ", None),
        ("https://www.youtube.com/watch?v=kisa", None),
        ("", None),
    ],
)
def test_baglanti_bicimleri(baglanti, beklenen):
    assert youtube_kimligi(baglanti) == beklenen


def test_panel_kayit_YALNIZ_KIMLIK_ve_anlasilir_hata(client, world, temiz_videolar):
    adm = _h(client, world["slug_a"], world["admin_a"])
    r = client.put("/egitim-videolari/yonetim/blok", headers=adm, json={
        "baglanti": "https://vimeo.com/1", "baslik": "Bloklar",
    })
    assert r.status_code == 422, r.text
    assert "YouTube" in r.json()["error"]["message"]

    r = client.put("/egitim-videolari/yonetim/blok", headers=adm, json={
        "baglanti": f"https://youtu.be/{V1}?si=izleyici", "baslik": " Bloklar ",
        "aciklama": "Blok ekleme", "sira": 10,
    })
    assert r.status_code == 200, r.text
    assert r.json()["youtube_id"] == V1 and r.json()["baslik"] == "Bloklar"
    assert r.json()["surum"] == 1

    # Baslik degisimi surumu ARTIRMAZ; video degisimi ARTIRIR.
    assert client.put("/egitim-videolari/yonetim/blok", headers=adm, json={
        "baglanti": V1, "baslik": "Bloklar 2", "sira": 10,
    }).json()["surum"] == 1
    assert client.put("/egitim-videolari/yonetim/blok", headers=adm, json={
        "baglanti": V2, "baslik": "Bloklar 2", "sira": 10,
    }).json()["surum"] == 2

    liste = client.get("/egitim-videolari/yonetim", headers=adm).json()
    assert liste["adimlar"][0] == "blok" and "daire" in liste["adimlar"]
    assert [v["adim_kodu"] for v in liste["videolar"]] == ["blok"]


def test_bilinmeyen_adim_404(client, world, temiz_videolar):
    adm = _h(client, world["slug_a"], world["admin_a"])
    r = client.put("/egitim-videolari/yonetim/boyle_adim_yok", headers=adm, json={
        "baglanti": V1, "baslik": "x",
    })
    assert r.status_code == 404, r.text


def test_liste_yakinda_izlendi_ve_VIDEO_DEGISINCE_sifirlanir(client, world, temiz_videolar):
    adm = _h(client, world["slug_a"], world["admin_a"])
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    client.put("/egitim-videolari/yonetim/daire", headers=adm, json={
        "baglanti": V1, "baslik": "Daireler", "sira": 20,
    })
    client.put("/egitim-videolari/yonetim/blok", headers=adm, json={
        "baglanti": V2, "baslik": "Bloklar", "sira": 10, "aktif": False,
    })

    d = client.get("/egitim-videolari", headers=yon).json()
    adimlar = {a["adim_kodu"]: a for a in d["adimlar"]}
    # Pasif video "yakinda" (video yok) gorunur; kirik oynatici yok.
    assert adimlar["blok"]["video"] is None
    assert adimlar["daire"]["video"]["youtube_id"] == V1
    assert d["toplam"] == 1 and d["izlenen"] == 0
    # Sihirbaz sirasi korunur (blok, daire, ...).
    assert [a["adim_kodu"] for a in d["adimlar"]][:2] == ["blok", "daire"]

    # Videosu olmayan adima "izlendi" yazilamaz.
    assert client.post("/egitim-videolari/blok/izlendi", headers=yon).status_code == 404
    assert client.post("/egitim-videolari/daire/izlendi", headers=yon).status_code == 204
    d = client.get("/egitim-videolari", headers=yon).json()
    assert d["izlenen"] == 1
    assert next(a for a in d["adimlar"] if a["adim_kodu"] == "daire")["izlendi"] is True

    # Video DEGISTI -> yeni surum -> yeniden "izlenmedi".
    client.put("/egitim-videolari/yonetim/daire", headers=adm, json={
        "baglanti": V2, "baslik": "Daireler (yeni arayuz)", "sira": 20,
    })
    d = client.get("/egitim-videolari", headers=yon).json()
    assert d["izlenen"] == 0


def test_izlendi_HESABA_aittir_baska_kisiye_sizmaz(client, world, temiz_videolar):
    adm = _h(client, world["slug_a"], world["admin_a"])
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    client.put("/egitim-videolari/yonetim/daire", headers=adm, json={
        "baglanti": V1, "baslik": "Daireler",
    })
    client.post("/egitim-videolari/daire/izlendi", headers=yon)
    assert client.get("/egitim-videolari", headers=adm).json()["izlenen"] == 0


def test_rol_kapilari(client, world, temiz_videolar):
    for cred in ("guard_a", "resident_a", "gorevli_a"):
        h = _h(client, world["slug_a"], world[cred])
        assert client.get("/egitim-videolari", headers=h).status_code == 403, cred
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    assert client.put("/egitim-videolari/yonetim/blok", headers=yon, json={
        "baglanti": V1, "baslik": "x",
    }).status_code == 403
    assert client.get("/egitim-videolari/yonetim", headers=yon).status_code == 403
