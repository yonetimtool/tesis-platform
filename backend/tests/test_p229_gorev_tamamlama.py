"""(P229 §3) GOREV TAMAMLAMA BILGISI — kaydediliyordu, GOSTERILMIYORDU.

===========================================================================
OLCUM: VERI VARDI, ARAYUZ YOKTU
===========================================================================
`POST /tasks/{id}/completions` zaten kim (tamamlayan_user_id), ne zaman
(tamamlanma_zamani), fotograf (foto_key + presigned foto_url), not, NFC ve
GPS kaydediyordu. Eksik olanlar:

  1. `TaskOut` tamamlama hakkinda HICBIR SEY tasimiyordu -> liste ve
     ayrinti "tamamlandi mi" sorusunu YANITLAYAMIYORDU.
  2. `GET /tasks/{id}/completions` HICBIR ISTEMCIDEN cagrilmiyordu; mobil
     yalniz KENDI POST yanitini ciziyor, ekran kapaninca unutuyordu.
  3. `tamamlayan_ad` YOKTU: saha rolu kullanici listesini goremedigi icin
     (403) id'den adi cozemiyordu.
  4. Tamamlama DENETIME yazilmiyordu.
  5. Tamamlamayi GERI ALMA yolu yoktu.
  6. YONETICI tamamlayamiyordu (`_COMPLETER`de yoktu).
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

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


@pytest.fixture
def gorev(client, yon, guard_id):
    r = client.post("/tasks", headers=yon, json={
        "ad": f"P229 gorev {uuid.uuid4().hex[:6]}",
        "atanan_user_id": guard_id})
    assert r.status_code == 201, r.text
    return r.json()["id"]


def _tamamla(client, h, gorev, **k):
    govde = {"tamamlanma_zamani": datetime.now(timezone.utc).isoformat()}
    govde.update(k)
    return client.post(
        f"/tasks/{gorev}/completions", headers={
            **h, "Idempotency-Key": uuid.uuid4().hex}, json=govde)


# ==================================================================== #
# 1. DURUM LISTEDE VE AYRINTIDA GORUNUYOR
# ==================================================================== #

def test_TAMAMLANMAMIS_GOREV_ACIK_GORUNUR(client, yon, gorev):
    v = client.get(f"/tasks/{gorev}", headers=yon).json()
    assert v["tamamlandi"] is False
    assert v["son_tamamlama"] is None


def test_AYRINTIDA_KIM_VE_NE_ZAMAN_GORUNUR(client, yon, guard, gorev):
    r = _tamamla(client, guard, gorev, notlar="Bahce sulandi")
    assert r.status_code == 201, r.text

    v = client.get(f"/tasks/{gorev}", headers=yon).json()
    assert v["tamamlandi"] is True, v
    ozet = v["son_tamamlama"]
    assert ozet is not None
    assert ozet["tamamlayan_ad"], "KIM tamamladi bos — ad cozulmemis"
    assert ozet["tamamlanma_zamani"], "NE ZAMAN bos"
    assert ozet["notlar"] == "Bahce sulandi"
    assert ozet["foto_var"] is False


def test_LISTEDE_DE_GORUNUR_VE_N_ARTI_BIR_YOK(client, yon, guard, gorev):
    """Listede durum gostermek icin istemcinin satir basina ayri istek
    atmasi gerekseydi elli gorevlik listede elli istek olurdu."""
    assert _tamamla(client, guard, gorev).status_code == 201
    liste = client.get("/tasks?limit=200", headers=yon).json()["items"]
    bizim = next(t for t in liste if t["id"] == gorev)
    assert bizim["tamamlandi"] is True
    assert bizim["son_tamamlama"]["tamamlayan_ad"]


def test_EN_SON_TAMAMLAMA_GOSTERILIR(client, yon, guard, gorev):
    """Periyodik gorev defalarca tamamlanir; listede gosterilmesi gereken
    EN YENISIDIR — ilki degil."""
    ilk = _tamamla(client, guard, gorev, notlar="ilk",
                   tamamlanma_zamani="2026-01-01T08:00:00+00:00")
    assert ilk.status_code == 201, ilk.text
    son = _tamamla(client, guard, gorev, notlar="son",
                   tamamlanma_zamani="2026-06-01T08:00:00+00:00")
    assert son.status_code == 201, son.text
    v = client.get(f"/tasks/{gorev}", headers=yon).json()
    assert v["son_tamamlama"]["notlar"] == "son", v["son_tamamlama"]


def test_TAMAMLAMA_LISTESINDE_DE_AD_VAR(client, yon, guard, gorev):
    assert _tamamla(client, guard, gorev).status_code == 201
    v = client.get(f"/tasks/{gorev}/completions", headers=guard).json()
    assert v["items"][0]["tamamlayan_ad"], "saha rolu ADI goremiyor"


# ==================================================================== #
# 2. YETKI — SUNUCU TARAFINDA
# ==================================================================== #

def test_YONETICI_DE_TAMAMLAYABILIR(client, yon, gorev):
    """Personel izinli/isten ayrilmissa gorev sonsuza kadar acik
    kalmamali."""
    assert _tamamla(client, yon, gorev).status_code == 201


def test_SAHA_ROLU_BASKASININ_GOREVINI_TAMAMLAYAMAZ(
        client, yon, guard, world):
    """Mevcut kural (bypass-proof) KORUNDU."""
    r = client.post("/tasks", headers=yon, json={"ad": "Baskasinin gorevi"})
    gorev2 = r.json()["id"]
    assert _tamamla(client, guard, gorev2).status_code == 404


def test_SAHA_ROLU_TAMAMLAMAYI_GERI_ALAMAZ(client, yon, guard, gorev):
    """Geri acma bir KANITI siler. Sahadaki kisi kendi tamamlamasini
    silebilseydi "yaptim" deyip izini temizleyebilirdi."""
    c = _tamamla(client, guard, gorev)
    assert c.status_code == 201, c.text
    r = client.delete(
        f"/tasks/{gorev}/completions/{c.json()['id']}", headers=guard)
    assert r.status_code == 403, r.text


def test_YONETICI_GERI_ACABILIR(client, yon, guard, gorev):
    c = _tamamla(client, guard, gorev)
    assert c.status_code == 201, c.text
    r = client.delete(
        f"/tasks/{gorev}/completions/{c.json()['id']}", headers=yon)
    assert r.status_code == 204, r.text
    v = client.get(f"/tasks/{gorev}", headers=yon).json()
    assert v["tamamlandi"] is False, "geri acilan gorev HALA tamamlanmis"


# ==================================================================== #
# 3. DENETIM KAYDI
# ==================================================================== #

def test_TAMAMLAMA_DENETIME_YAZILIR(client, yon, guard, gorev, owner_conn):
    c = _tamamla(client, guard, gorev)
    assert c.status_code == 201, c.text
    satir = owner_conn.execute(
        "SELECT action FROM audit_log WHERE resource_id = %s "
        "AND action = 'task_complete'", (gorev,)).fetchone()
    assert satir is not None, "tamamlama denetime YAZILMADI"


def test_GERI_ACMA_DENETIME_YAZILIR(client, yon, guard, gorev, owner_conn):
    """SILINEN kaydin alanlari denetimde kalmali: yoksa geri alinmis bir
    isin kimin tarafindan yapildigi hicbir yerde kalmazdi."""
    c = _tamamla(client, guard, gorev)
    client.delete(f"/tasks/{gorev}/completions/{c.json()['id']}", headers=yon)
    satir = owner_conn.execute(
        "SELECT meta FROM audit_log WHERE resource_id = %s "
        "AND action = 'task_reopen'", (gorev,)).fetchone()
    assert satir is not None, "geri acma denetime YAZILMADI"
    assert "tamamlayan_user_id" in str(satir[0])


def test_IDEMPOTENT_TEKRAR_IKINCI_DENETIM_SATIRI_YAZMAZ(
        client, guard, gorev, owner_conn):
    """Ag koptu, istemci yeniden gonderdi: ayni is IKI KEZ yapilmis gibi
    gorunmemeli."""
    anahtar = uuid.uuid4().hex
    govde = {"tamamlanma_zamani": datetime.now(timezone.utc).isoformat()}
    for _ in range(2):
        r = client.post(f"/tasks/{gorev}/completions",
                        headers={**guard, "Idempotency-Key": anahtar},
                        json=govde)
        assert r.status_code in (200, 201), r.text
    n = owner_conn.execute(
        "SELECT count(*) FROM audit_log WHERE resource_id = %s "
        "AND action = 'task_complete'", (gorev,)).fetchone()[0]
    assert n == 1, f"idempotent tekrar {n} denetim satiri yazdi"


# ==================================================================== #
# 4. FOTOGRAF
# ==================================================================== #

def test_FOTO_ZORUNLU_GOREV_FOTOSUZ_TAMAMLANAMAZ(client, yon, guard_id, guard):
    """Foto zorunlulugu GOREV BAZINDA (`foto_zorunlu`), gorev TURUNE gore
    degil: ayni kategorideki iki isten biri kanit isteyebilir
    (yangin tupu kontrolu), digeri istemeyebilir (cop toplama)."""
    r = client.post("/tasks", headers=yon, json={
        "ad": "Kanit isteyen gorev", "atanan_user_id": guard_id,
        "foto_zorunlu": True})
    assert r.status_code == 201, r.text
    red = _tamamla(client, guard, r.json()["id"])
    assert red.status_code == 422, red.text


def test_FOTO_VARLIGI_OZETTE_GORUNUR(client, yon, guard, gorev):
    r = _tamamla(client, guard, gorev, foto_key="tenant/x/p229.jpg")
    assert r.status_code == 201, r.text
    v = client.get(f"/tasks/{gorev}", headers=yon).json()
    assert v["son_tamamlama"]["foto_var"] is True
    # Presigned URL OZETTE DEGIL: liste yuzlerce satir donebilir ve her
    # satirda imza hesaplamak yaniti da sunucuyu da bosuna yorardi.
    assert "foto_url" not in v["son_tamamlama"]
    ayrinti = client.get(f"/tasks/{gorev}/completions", headers=yon).json()
    assert ayrinti["items"][0]["foto_url"], "ayrintida foto URL'i YOK"


# ==================================================================== #
# 5. BILDIRIM — "is bitti" haberi yonetime
# ==================================================================== #

def test_TAMAMLANINCA_YONETIME_BILDIRIM_GIDER(
        client, yon, guard, gorev, owner_conn):
    """Gorev atanip unutulmasin: yonetici isin bittigini OGRENSIN.

    OLUSTURANA DEGIL YONETIME: olusturan kisi izinli/ayrilmis olabilir,
    o zaman haberi kimse almazdi.
    """
    assert _tamamla(client, guard, gorev).status_code == 201
    n = owner_conn.execute(
        "SELECT count(*) FROM notification WHERE tip = 'gorev_tamamlandi' "
        "AND task_id = %s", (gorev,)).fetchone()[0]
    assert n >= 1, "tamamlama bildirimi YAZILMADI"


def test_KENDI_TAMAMLADIGINI_KENDINE_BILDIRMEZ(
        client, yon, gorev, owner_conn):
    """Yonetici kendi kapattigi gorevi kendine haber vermemeli —
    yaptigi isi kendisine bildirmek gurultudur."""
    me = client.get("/me", headers=yon).json()["id"]
    assert _tamamla(client, yon, gorev).status_code == 201
    satir = owner_conn.execute(
        "SELECT count(*) FROM notification WHERE tip = 'gorev_tamamlandi' "
        "AND task_id = %s AND user_id = %s", (gorev, me)).fetchone()[0]
    assert satir == 0, "kendi tamamlamasini kendine bildirdi"
