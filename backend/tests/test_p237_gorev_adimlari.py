"""(P237 §2) GOREV ALT ADIMLARI — asamali ilerleme, uctan uca.

===========================================================================
BRIEF'IN DOGRULAMA ISTEGI BIREBIR SURULUR
===========================================================================
"Bir gorevi uc adima bol, ikisini fotografla tamamla, yoneticide
ilerlemeyi gor." Asagidaki ilk test tam olarak bu akistir; kalanlar
kararlarin (sira, foto mirasi, yetki, bildirim esigi) her birini ayri
ayri olcer.
"""
from __future__ import annotations

import uuid

import pytest


def _giris(client, world, kim):
    r = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"],
        "email": world[kim]["email"], "password": world[kim]["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def yon(client, world):
    return _giris(client, world, "yonetici_a")


@pytest.fixture
def guard(client, world):
    return _giris(client, world, "guard_a")


@pytest.fixture
def guard_id(client, guard):
    return client.get("/me", headers=guard).json()["id"]


def _gorev(client, yon, guard_id, **k):
    govde = {"ad": f"P237 {uuid.uuid4().hex[:6]}", "atanan_user_id": guard_id}
    govde.update(k)
    r = client.post("/tasks", headers=yon, json=govde)
    assert r.status_code == 201, r.text
    return r.json()


# =========================== BRIEF AKISI ================================== #
def test_uc_adim_ikisi_fotografla_tamamlanir_yonetici_ilerlemeyi_gorur(
    client, world, yon, guard, guard_id
):
    # 1) Yonetici gorevi UC ADIMLA olusturur.
    gorev = _gorev(
        client, yon, guard_id,
        adimlar=[
            {"ad": "A blok", "sira": 0},
            {"ad": "B blok", "sira": 1},
            {"ad": "C blok", "sira": 2},
        ],
    )
    assert gorev["adim_toplam"] == 3
    assert gorev["adim_tamam"] == 0

    # 2) Personel adimlari GORUR (ayrinti ucu).
    ayrinti = client.get(f"/tasks/{gorev['id']}", headers=guard).json()
    adlar = [a["ad"] for a in ayrinti["adimlar"]]
    assert adlar == ["A blok", "B blok", "C blok"]

    # 3) Ikisini FOTOGRAFLA tamamlar.
    for adim in ayrinti["adimlar"][:2]:
        r = client.post(
            f"/tasks/{gorev['id']}/adimlar/{adim['id']}/tamamla",
            headers=guard,
            # (E2E 2026-09) foto_key kendi tenant on ekinde olmali.
            json={"foto_key": f"{world['a']}/tasks/{uuid.uuid4().hex}.jpg",
                  "notlar": "bitti"},
        )
        assert r.status_code == 200, r.text
        assert r.json()["tamamlandi"] is True

    # 4) YONETICI ILERLEMEYI GORUR: 2/3, hangisi bitti, KIM bitirdi, ne zaman,
    #    fotografiyla.
    ayrinti = client.get(f"/tasks/{gorev['id']}", headers=yon).json()
    assert (ayrinti["adim_tamam"], ayrinti["adim_toplam"]) == (2, 3)
    a, b, c = ayrinti["adimlar"]
    assert a["tamamlandi"] and b["tamamlandi"] and not c["tamamlandi"]
    assert a["tamamlayan_user_id"] == guard_id
    assert a["tamamlayan_ad"]          # KIM — ad cozulmus
    assert a["tamamlanma_zamani"]      # NE ZAMAN
    assert a["foto_url"]               # FOTOGRAFIYLA (presigned)
    assert a["notlar"] == "bitti"
    assert c["tamamlayan_user_id"] is None

    # 5) LISTEDE de gorunur — yoneticinin ilk sorusu "hangisi ne kadar
    #    ilerledi"; bunun icin her goreve girmek gerekmemeli.
    liste = client.get("/tasks?limit=200", headers=yon).json()["items"]
    satir = next(t for t in liste if t["id"] == gorev["id"])
    assert (satir["adim_tamam"], satir["adim_toplam"]) == (2, 3)
    # Adimlarin KENDISI listede TASINMAZ (yuk).
    assert satir["adimlar"] is None


# =========================== KARARLAR ===================================== #
def test_adim_SONRADAN_eklenebilir(client, yon, guard_id):
    gorev = _gorev(client, yon, guard_id, adimlar=[{"ad": "A blok"}])
    r = client.post(
        f"/tasks/{gorev['id']}/adimlar", headers=yon, json={"ad": "D blok", "sira": 9}
    )
    assert r.status_code == 201, r.text
    ayrinti = client.get(f"/tasks/{gorev['id']}", headers=yon).json()
    assert [a["ad"] for a in ayrinti["adimlar"]] == ["A blok", "D blok"]


def test_PERSONEL_adim_EKLEYEMEZ(client, yon, guard, guard_id):
    """Adim isin TANIMIDIR: paydayi isi yapan belirleseydi ilerleme
    olcusu denetlenemez olurdu."""
    gorev = _gorev(client, yon, guard_id, adimlar=[{"ad": "A blok"}])
    r = client.post(
        f"/tasks/{gorev['id']}/adimlar", headers=guard, json={"ad": "kendi adimim"}
    )
    assert r.status_code == 403, r.text


def test_FOTO_gorevden_MIRAS_ve_GEVSETILEMEZ(client, yon, guard, guard_id):
    gorev = _gorev(
        client, yon, guard_id, foto_zorunlu=True, adimlar=[{"ad": "A blok"}]
    )
    adim = client.get(f"/tasks/{gorev['id']}", headers=yon).json()["adimlar"][0]
    # MIRAS: adim kendi bayragini vermedi, gorevinkini aldi.
    assert adim["foto_zorunlu"] is True
    # FOTOSUZ tamamlama REDDEDILIR.
    r = client.post(
        f"/tasks/{gorev['id']}/adimlar/{adim['id']}/tamamla", headers=guard, json={}
    )
    assert r.status_code == 422, r.text
    assert r.json()["error"]["code"] == "validation_error"
    # GEVSETME YASAK: gorev zorunlu tutuyorsa adim muaf olamaz.
    r = client.post(
        f"/tasks/{gorev['id']}/adimlar", headers=yon,
        json={"ad": "B blok", "foto_zorunlu": False},
    )
    assert r.status_code == 422, r.text


def test_SIRA_varsayilan_SERBEST(client, yon, guard, guard_id):
    """Sahada sira cogu zaman sabit degildir; zorunlu sira isi durdururdu."""
    gorev = _gorev(
        client, yon, guard_id,
        adimlar=[{"ad": "A", "sira": 0}, {"ad": "B", "sira": 1}],
    )
    adimlar = client.get(f"/tasks/{gorev['id']}", headers=yon).json()["adimlar"]
    # IKINCI adim once tamamlanabilir.
    r = client.post(
        f"/tasks/{gorev['id']}/adimlar/{adimlar[1]['id']}/tamamla",
        headers=guard, json={},
    )
    assert r.status_code == 200, r.text


def test_SIRALI_gorevde_atlama_ENGELLENIR(client, yon, guard, guard_id):
    gorev = _gorev(
        client, yon, guard_id, adim_sirali=True,
        adimlar=[{"ad": "Bosalt", "sira": 0}, {"ad": "Yika", "sira": 1}],
    )
    adimlar = client.get(f"/tasks/{gorev['id']}", headers=yon).json()["adimlar"]
    r = client.post(
        f"/tasks/{gorev['id']}/adimlar/{adimlar[1]['id']}/tamamla",
        headers=guard, json={},
    )
    assert r.status_code == 409, r.text
    # Once birinci -> sonra ikinci GECER.
    assert client.post(
        f"/tasks/{gorev['id']}/adimlar/{adimlar[0]['id']}/tamamla",
        headers=guard, json={},
    ).status_code == 200
    assert client.post(
        f"/tasks/{gorev['id']}/adimlar/{adimlar[1]['id']}/tamamla",
        headers=guard, json={},
    ).status_code == 200


def test_IKINCI_tamamlama_409_ve_GERI_ALMA_yalniz_yonetimde(
    client, yon, guard, guard_id
):
    gorev = _gorev(client, yon, guard_id, adimlar=[{"ad": "A blok"}])
    adim = client.get(f"/tasks/{gorev['id']}", headers=yon).json()["adimlar"][0]
    yol = f"/tasks/{gorev['id']}/adimlar/{adim['id']}"
    assert client.post(f"{yol}/tamamla", headers=guard, json={}).status_code == 200
    # Ikinci tamamlama SESSIZCE YUTULMAZ: farkli bir fotograf tasiyor olabilir.
    assert client.post(f"{yol}/tamamla", headers=guard, json={}).status_code == 409
    # Personel KENDI izini temizleyemez.
    assert client.post(f"{yol}/geri-al", headers=guard).status_code == 403
    # Yonetim geri alir.
    r = client.post(f"{yol}/geri-al", headers=yon)
    assert r.status_code == 200, r.text
    assert r.json()["tamamlandi"] is False
    assert r.json()["tamamlayan_user_id"] is None


def test_KENDINE_ATANMAYAN_gorevin_adimi_tamamlanamaz(client, yon, guard):
    """Saha kisiti gorev tamamlamayla AYNI kural.

    ATANMAMIS (havuz) gorev kullanildi: `yonetici` bir gorevi ancak
    guvenlik/tesis gorevlisine atayabiliyor (mevcut kural), yani "baska
    bir yoneticiye atanmis gorev" kurulamiyor. Havuz gorevi ayni kapiyi
    olcer: saha rolune gorunmez.
    """
    r = client.post(
        "/tasks", headers=yon,
        json={"ad": f"P237 havuz {uuid.uuid4().hex[:6]}",
              "adimlar": [{"ad": "A blok"}]},
    )
    assert r.status_code == 201, r.text
    gorev = r.json()
    adim = client.get(f"/tasks/{gorev['id']}", headers=yon).json()["adimlar"][0]
    r = client.post(
        f"/tasks/{gorev['id']}/adimlar/{adim['id']}/tamamla", headers=guard, json={}
    )
    # Gorev saha rolune HIC gorunmuyor -> 404 (gorunurluk kapisi once).
    assert r.status_code in (403, 404), r.text


def test_BILDIRIM_ESIGI_her_adimda_push_atmaz(client, yon, guard, guard_id):
    """(KARAR 4) Yirmi adimlik gorev yirmi bildirim URETMEZ.

    ILK adim bildirir; hemen ardindan gelen adimlar ESIK (30 dk) dolmadigi
    icin bildirmez. Olcum `son_adim_bildirim_at`in DEGISMEMESI uzerinden
    degil, bildirim defteri uzerinden yapilir: yoneticinin bildirim
    listesinde `gorev_adim_ilerleme` satiri KAC TANE.
    """
    def _sayim():
        r = client.get("/notifications?limit=200", headers=yon)
        assert r.status_code == 200, r.text
        return sum(
            1 for n in r.json()["items"] if n.get("tip") == "gorev_adim_ilerleme"
        )

    once = _sayim()
    gorev = _gorev(
        client, yon, guard_id,
        adimlar=[{"ad": f"blok {i}", "sira": i} for i in range(5)],
    )
    adimlar = client.get(f"/tasks/{gorev['id']}", headers=yon).json()["adimlar"]
    for a in adimlar:
        assert client.post(
            f"/tasks/{gorev['id']}/adimlar/{a['id']}/tamamla",
            headers=guard, json={},
        ).status_code == 200
    # BES adim tamamlandi, bildirim EN FAZLA BIR arttı.
    assert _sayim() - once <= 1
