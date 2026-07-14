"""Ortak alan rezervasyonu: alan CRUD + ANINDA rezerve + zamanlama kurallari +
iptal + CAKISMA ENGELI + RBAC + izolasyon.

ONAY AKISI KALDIRILDI: sakin bos slotu rezerve edince kayit dogrudan
durum='onaylandi' olur. Zamanlama (slot baslangicina gore, tenant tz):
  * 24s penceresi: slota <24s kala rezerve edilir (erken -> 422; gecmis -> 422).
  * gunde bir: sakin slot-gunune denk 1 aktif rezervasyon tutar (2. -> 409).
  * son dakika: <10 dk kala BOS slot gunluk kotayi baypas eder.
Iptal (durum='iptal') slotu bosaltir. CAKISMA: DB partial EXCLUDE
(WHERE durum='onaylandi') — cakisan ikinci talep 409 (INSERT aninda, yaris-safe).

Testler CANLI sunucuya (httpx) gider; sunucu GERCEK saati kullanir. Bu yuzden
slot saatleri "simdi"ye gore (Europe/Istanbul) uretilir — sabit tarih yerine
now+ofset. Ayni gun ikinci rezervasyon gunluk kotaya takilir; bu yuzden ayni
gun coklu-slot testleri FARKLI sakinler kullanir (kota kisi-bazli).
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

import pytest

_IST = ZoneInfo("Europe/Istanbul")


def _now():
    return datetime.now(_IST)


def _hslot(hours_ahead, dur_h=1):
    """Saat-hizali slot: simdi+hours_ahead (tarih, "HH:MM", "HH:MM")."""
    start = (_now() + timedelta(hours=hours_ahead)).replace(
        minute=0, second=0, microsecond=0
    )
    end = start + timedelta(hours=dur_h)
    return start.date().isoformat(), start.strftime("%H:%M"), end.strftime("%H:%M")


def _mslot(minutes_ahead, dur_min=20):
    """Dakika-hassas slot (son-dakika istisnasi testi icin)."""
    start = _now() + timedelta(minutes=minutes_ahead)
    end = start + timedelta(minutes=dur_min)
    return start.date().isoformat(), start.strftime("%H:%M"), end.strftime("%H:%M")


def _iki_bitisik_slot_ayni_gun():
    """AYNI takvim gunune denk, 24s penceresi icinde, cakismayan iki BITISIK
    saat slotu -> ((tarih,s,e), (tarih,s,e)). Kural her gun bagimsiz 1 oldugundan
    MUMKUNSE gelecek bir gun (yarin) secilir; gece yarisina yakin saatlerde (0-1)
    bugune duser — iki durumda da 2. slot ayni gune denk gelir (kota testi)."""
    now = _now()
    if now.hour >= 2:  # yarin: (simdi-2s) ve (simdi-1s) saatleri hala <24s icinde
        day = (now + timedelta(days=1)).date()
        h1 = now.hour - 2
    else:  # gece yarisi kenar durumu: bugun ileri iki saat
        day = now.date()
        h1 = now.hour + 1
    d = day.isoformat()
    return (
        (d, f"{h1:02d}:00", f"{h1 + 1:02d}:00"),
        (d, f"{h1 + 1:02d}:00", f"{h1 + 2:02d}:00"),
    )


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _mk_area(client, headers, **over):
    body = {"ad": f"Alan {uuid.uuid4().hex[:6]}"}
    body.update(over)
    r = client.post("/common-areas", headers=headers, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def _post(client, headers, alan_id, slot, *, expect=201, **over):
    """slot = (tarih, baslangic, bitis). kisi_sayisi=2 varsayilan."""
    tarih, bas, bit = slot
    body = {"alan_id": alan_id, "tarih": tarih, "baslangic": bas,
            "bitis": bit, "kisi_sayisi": 2}
    body.update(over)
    r = client.post("/reservations", headers=headers, json=body)
    assert r.status_code == expect, r.text
    return r.json()


def _cancel(client, headers, rez_id, expect=200):
    r = client.post(f"/reservations/{rez_id}/cancel", headers=headers)
    assert r.status_code == expect, r.text
    return r.json()


def _mk_resident(owner_conn, tenant_id, email, pw):
    from app.security import hash_password

    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, password_hash, role) "
            "VALUES (%s,%s,%s,%s,'resident'::user_role) RETURNING id",
            (tenant_id, f"Sakin {email.split('@')[0]}", email, hash_password(pw)),
        )
        return cur.fetchone()[0]


@pytest.fixture
def rworld(client, world, owner_conn):
    """world + daireler/sakinler + iki ortak alan (yonetici API ile):

    * unit1 (R-101): resident_a + es (ayni dairede iki sakin).
    * unit2 (R-202): resident_diger.
    * alan1, alan2 — tenant A. Uc ayri sakin (resident_a, es, diger).
    """
    a = world["a"]
    suffix = uuid.uuid4().hex[:6]
    pw = "RezPass1!"
    es_email = f"res-{suffix}@acme.com"
    diger_email = f"rdiger-{suffix}@acme.com"

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND email=%s AND role='resident'",
            (a, world["resident_a"]["email"]),
        )
        resident_a_id = cur.fetchone()[0]
    es_id = _mk_resident(owner_conn, a, es_email, pw)
    diger_id = _mk_resident(owner_conn, a, diger_email, pw)

    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO unit (tenant_id, no) VALUES (%s,%s) RETURNING id",
            (a, f"R-101-{suffix}"),
        )
        unit1 = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO unit (tenant_id, no) VALUES (%s,%s) RETURNING id",
            (a, f"R-202-{suffix}"),
        )
        unit2 = cur.fetchone()[0]
        for uid, unit in ((resident_a_id, unit1), (es_id, unit1), (diger_id, unit2)):
            cur.execute(
                "INSERT INTO unit_resident (tenant_id, unit_id, user_id) "
                "VALUES (%s,%s,%s)",
                (a, unit, uid),
            )

    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    alan1 = _mk_area(client, yonetici, ad=f"Havuz-{suffix}")
    alan2 = _mk_area(client, yonetici, ad=f"Toplanti-{suffix}")

    return {
        **world,
        "unit1": str(unit1),
        "unit1_no": f"R-101-{suffix}",
        "unit2": str(unit2),
        "resident_a_id": str(resident_a_id),
        "es": {"email": es_email, "password": pw},
        "diger": {"email": diger_email, "password": pw},
        "alan1": alan1["id"],
        "alan2": alan2["id"],
    }


# ------------------------------ ortak alan ---------------------------------- #
def test_alan_crud_ve_rbac(client, rworld):
    yonetici = _headers(client, rworld["slug_a"], rworld["yonetici_a"])
    admin = _headers(client, rworld["slug_a"], rworld["admin_a"])
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    guard = _headers(client, rworld["slug_a"], rworld["guard_a"])

    alan = _mk_area(client, yonetici, ad=f"Teras-{uuid.uuid4().hex[:6]}",
                    aciklama="Cati terasi")
    assert alan["aktif"] is True and alan["aciklama"] == "Cati terasi"
    # ayni adla ikinci alan 409
    assert client.post(
        "/common-areas", headers=admin, json={"ad": alan["ad"]}
    ).status_code == 409
    # sakin/saha alan ACAMAZ
    for h in (resident, guard):
        assert client.post(
            "/common-areas", headers=h, json={"ad": "X"}
        ).status_code == 403
    # sakin/saha aktif alanlari OKUR
    for h in (resident, guard):
        ids = [it["id"] for it in client.get(
            "/common-areas", headers=h, params={"limit": 200}
        ).json()["items"]]
        assert alan["id"] in ids

    # pasiflestir (soft-delete): yonetim gorur, sakin GORMEZ
    p = client.patch(
        f"/common-areas/{alan['id']}", headers=yonetici, json={"aktif": False}
    )
    assert p.status_code == 200 and p.json()["aktif"] is False
    r_ids = [it["id"] for it in client.get(
        "/common-areas", headers=resident, params={"limit": 200}
    ).json()["items"]]
    assert alan["id"] not in r_ids
    # sakin pasif alana rezerve edemez (422 — timing'den once alan kontrolu)
    _post(client, resident, alan["id"], _hslot(2), expect=422)
    # bos govde PATCH 422
    assert client.patch(
        f"/common-areas/{alan['id']}", headers=yonetici, json={}
    ).status_code == 422


# ----------------------- rezerve et (aninda onaylandi) ---------------------- #
def test_sakin_rezerve_eder_aninda_onaylandi(client, rworld):
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    slot = _hslot(2)
    r = _post(client, resident, rworld["alan1"], slot, kisi_sayisi=4,
              notlar="Aile yuzme saati")
    # ONAY YOK: dogrudan onaylandi
    assert r["durum"] == "onaylandi"
    assert r["unit_id"] == rworld["unit1"]  # daire kimlikten turedi
    assert r["unit_no"] == rworld["unit1_no"]
    assert r["baslangic"] == slot[1] and r["bitis"] == slot[2]
    assert r["kisi_sayisi"] == 4 and r["notlar"] == "Aile yuzme saati"
    assert r["talep_eden_ad"] == "Resident A"
    # iptal edilmedi -> iptal alanlari bos
    assert r["iptal_eden_user_id"] is None and r["iptal_zamani"] is None


def test_talep_dogrulama(client, rworld):
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    # bitis <= baslangic -> 422 (sema; timing'den once)
    _post(client, resident, rworld["alan1"], ("2026-07-14", "12:00", "12:00"),
          expect=422)
    _post(client, resident, rworld["alan1"], ("2026-07-14", "14:00", "13:00"),
          expect=422)
    # kisi_sayisi 0 -> 422
    _post(client, resident, rworld["alan1"], _hslot(2), kisi_sayisi=0, expect=422)
    # olmayan alan -> 422
    _post(client, resident, str(uuid.uuid4()), _hslot(2), expect=422)
    # baskasinin dairesi unit_id olarak verilemez -> 422
    _post(client, resident, rworld["alan1"], _hslot(2),
          unit_id=rworld["unit2"], expect=422)


def test_rezerve_rbac_yalniz_sakin(client, rworld):
    tarih, bas, bit = _hslot(2)
    for role in ("admin_a", "yonetici_a", "guard_a", "gorevli_a"):
        h = _headers(client, rworld["slug_a"], rworld[role])
        assert client.post(
            "/reservations", headers=h,
            json={"alan_id": rworld["alan1"], "tarih": tarih,
                  "baslangic": bas, "bitis": bit, "kisi_sayisi": 2},
        ).status_code == 403, role


# --------------------------- ZAMANLAMA KURALLARI ---------------------------- #
def test_24_saat_penceresi(client, rworld):
    """Slota <24s kala rezerve edilir; >=24s erken 422; gecmis slot 422."""
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    # simdi+2s (delta ~2s) -> OK
    _post(client, resident, rworld["alan1"], _hslot(2), expect=201)
    # simdi+25s (>= 24s) -> cok erken 422 (mesajda 24 saat vurgusu)
    r = _post(client, resident, rworld["alan1"], _hslot(25), expect=422)
    assert "24 saat" in r["error"]["message"]
    # gecmis slot (simdi-2s) -> 422
    _post(client, resident, rworld["alan1"], _hslot(-2), expect=422)


def test_yarin_ama_24s_icinde_ok(client, rworld):
    """Yarina sarkan ama simdiden <24s icinde slot rezerve edilir."""
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    _post(client, resident, rworld["alan1"], _hslot(23), expect=201)


def test_gunde_bir_rezervasyon(client, rworld):
    """Gunluk kota SLOT-GUNUNE gore: ayni gun 2. slot 409; FARKLI gun serbest.

    (Regresyon: bir gunun slotunu almak baska GUNU bloke ETMEMELI — kota
    rezervasyon/bugun gunune degil, SLOTUN takvim gunune baglidir.)"""
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    diger = _headers(client, rworld["slug_a"], rworld["diger"])
    # ilk rezervasyon (bugun +2s) OK
    _post(client, resident, rworld["alan1"], _hslot(2))
    # ayni sakin AYNI gun IKINCI (cakismayan) slot -> 409 gunluk kota
    r = _post(client, resident, rworld["alan1"], _hslot(4), expect=409)
    assert "bu gun" in r["error"]["message"].lower()
    # ayni sakin FARKLI gun (yarin, 24s icinde) rezerve EDEBILIR — kota slot-gunu
    # bazli; bugunku rezervasyon yarini bloke ETMEZ.
    _post(client, resident, rworld["alan1"], _hslot(23))
    # BASKA sakin ayni gun de rezerve edebilir (kota kisi-bazli)
    _post(client, diger, rworld["alan1"], _hslot(4))


def test_gunde_bir_her_gun_bagimsiz(client, rworld):
    """Gunluk kota HER takvim gunu icin BAGIMSIZ 1'dir — yalniz "bugun" degil.

    Regresyon: gelecek bir gunun (yarin) ilk slotu alininca AYNI yarin gunune
    ikinci (cakismayan/bitisik) slot da 409 gunluk kotaya takilmali; kota
    slot-gunune baglidir, bugune ozel degildir. Baska sakin ayni gune rezerve
    edebilir (kota kisi-bazli)."""
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    diger = _headers(client, rworld["slug_a"], rworld["diger"])
    s1, s2 = _iki_bitisik_slot_ayni_gun()
    assert s1[0] == s2[0]  # iki slot da ayni takvim gunu
    # ilk slot (o gunun ilk rezervasyonu) OK
    _post(client, resident, rworld["alan1"], s1)
    # AYNI gun IKINCI (bitisik -> cakisma DEGIL) slot -> 409 gunluk kota
    r = _post(client, resident, rworld["alan1"], s2, expect=409)
    assert "bu gun" in r["error"]["message"].lower()
    # BASKA sakin ayni gune rezerve edebilir (kota kisi-bazli, cakisma yok)
    _post(client, diger, rworld["alan1"], s2)


def test_son_dakika_istisnasi(client, rworld):
    """<10 dk kala BOS slot gunluk kotayi baypas eder; >10dk edilmez."""
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    # kota doldur: simdi+2s OK
    _post(client, resident, rworld["alan1"], _hslot(2))
    # kota dolu + slot 4s sonra (>10dk) -> 409 gunluk
    _post(client, resident, rworld["alan1"], _hslot(4), expect=409)
    # kota dolu AMA bos slot <10dk kala (simdi+5dk) -> baypas -> 201
    _post(client, resident, rworld["alan1"], _mslot(5), expect=201)


# ------------------------------ CAKISMA ENGELI ------------------------------ #
def test_cakisan_ikinci_rezervasyon_409(client, rworld):
    """Ilk talep aninda onaylanir; onayliyla kesisen ikinci talep 409
    (INSERT anindaki DB EXCLUDE — yaris-safe). Farkli sakinler (kota degil)."""
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    diger = _headers(client, rworld["slug_a"], rworld["diger"])
    es = _headers(client, rworld["slug_a"], rworld["es"])

    # simdi+2s'ten 3 saatlik blok
    _post(client, resident, rworld["alan1"], _hslot(2, dur_h=3))
    # kesisen (simdi+3s, blok icinde) -> 409
    _post(client, diger, rworld["alan1"], _hslot(3), expect=409)
    # yine kesisen (simdi+4s) baska sakin -> 409 (kota degil, cakisma)
    _post(client, es, rworld["alan1"], _hslot(4), expect=409)


def test_cakismayan_bitisik_farkli_alan_serbest(client, rworld):
    """Bitisik slot (bitis == baslangic) ve farkli alan cakisma DEGILDIR."""
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    diger = _headers(client, rworld["slug_a"], rworld["diger"])
    es = _headers(client, rworld["slug_a"], rworld["es"])

    # bitisik: +2s..+3s ve +3s..+4s (farkli sakinler; ayni alan) -> ikisi de OK
    _post(client, resident, rworld["alan1"], _hslot(2))
    _post(client, diger, rworld["alan1"], _hslot(3))
    # farkli alan ayni saat -> OK
    _post(client, es, rworld["alan2"], _hslot(2))


# --------------------------------- iptal ------------------------------------ #
def test_iptal_slotu_bosaltir_ve_damgalanir(client, rworld):
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    diger = _headers(client, rworld["slug_a"], rworld["diger"])
    slot = _hslot(2)

    r = _post(client, resident, rworld["alan1"], slot)
    # sakin KENDI rezervasyonunu iptal eder
    body = _cancel(client, resident, r["id"])
    assert body["durum"] == "iptal"
    assert body["iptal_eden_ad"] == "Resident A"
    assert body["iptal_zamani"] is not None
    # iptal slotu bosaltti: baska sakin ayni araligi rezerve edebilir
    _post(client, diger, rworld["alan1"], slot)
    # zaten iptal -> ikinci iptal 409
    _cancel(client, resident, r["id"], expect=409)


def test_iptal_rbac(client, rworld):
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    diger = _headers(client, rworld["slug_a"], rworld["diger"])

    r = _post(client, resident, rworld["alan1"], _hslot(2))
    # saha rolleri VE YONETIM iptal edemez (403) — yonetim yalniz izler
    for role in ("guard_a", "gorevli_a", "yonetici_a", "admin_a"):
        h = _headers(client, rworld["slug_a"], rworld[role])
        assert client.post(
            f"/reservations/{r['id']}/cancel", headers=h
        ).status_code == 403, role
    # BASKA sakin baskasinin rezervasyonunu iptal edemez (404 — varlik sizmaz)
    assert client.post(
        f"/reservations/{r['id']}/cancel", headers=diger
    ).status_code == 404
    # rezerve eden sakin KENDI rezervasyonunu iptal eder (>=10 dk kala)
    assert client.post(
        f"/reservations/{r['id']}/cancel", headers=resident
    ).status_code == 200


def test_iptal_10_dakika_kurali(client, rworld):
    """Slot baslangicina <10 dk kala (son-dakika rezervasyonu) iptal edilemez."""
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    # simdi+5 dk bos slot (son-dakika; kota bos oldugundan zaten rezerve edilir)
    r = _post(client, resident, rworld["alan1"], _mslot(5))
    resp = client.post(f"/reservations/{r['id']}/cancel", headers=resident)
    assert resp.status_code == 422, resp.text
    assert "10 dakika" in resp.json()["error"]["message"]
    # kayit hala onayli (iptal edilmedi)
    assert client.get(
        f"/reservations/{r['id']}", headers=resident
    ).json()["durum"] == "onaylandi"


# ------------------------------- okuma -------------------------------------- #
def test_sakin_yalniz_kendi_dairesinin_rezervasyonlarini_gorur(client, rworld):
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    es = _headers(client, rworld["slug_a"], rworld["es"])
    diger = _headers(client, rworld["slug_a"], rworld["diger"])
    yonetici = _headers(client, rworld["slug_a"], rworld["yonetici_a"])

    mine = _post(client, resident, rworld["alan1"], _hslot(2))
    theirs = _post(client, diger, rworld["alan1"], _hslot(3))

    ids = [it["id"] for it in client.get(
        "/reservations", headers=resident, params={"limit": 200}
    ).json()["items"]]
    assert mine["id"] in ids and theirs["id"] not in ids
    # es AYNI dairenin rezervasyonunu gorur (daire bazli kapsam)
    es_ids = [it["id"] for it in client.get(
        "/reservations", headers=es, params={"limit": 200}
    ).json()["items"]]
    assert mine["id"] in es_ids
    # detay: baska dairenin kaydi 404 (varlik sizdirilmaz)
    assert client.get(f"/reservations/{theirs['id']}", headers=resident).status_code == 404
    # yonetim ikisini de gorur
    y_ids = [it["id"] for it in client.get(
        "/reservations", headers=yonetici, params={"limit": 200}
    ).json()["items"]]
    assert mine["id"] in y_ids and theirs["id"] in y_ids


def test_okuma_rbac_saha_403(client, rworld):
    for role in ("guard_a", "gorevli_a"):
        h = _headers(client, rworld["slug_a"], rworld[role])
        assert client.get("/reservations", headers=h).status_code == 403, role


def test_liste_filtreleri(client, rworld):
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    diger = _headers(client, rworld["slug_a"], rworld["diger"])
    yonetici = _headers(client, rworld["slug_a"], rworld["yonetici_a"])
    slot = _hslot(2)
    tarih = slot[0]
    # farkli sakinler (ayni gun kota) — a onayli kalir, b iptal edilir
    a = _post(client, resident, rworld["alan1"], slot)
    b = _post(client, diger, rworld["alan2"], slot)
    _cancel(client, diger, b["id"])

    # durum filtresi: onaylandi -> a var, b yok
    onayli = client.get(
        "/reservations", headers=yonetici,
        params={"durum": "onaylandi", "limit": 200},
    ).json()["items"]
    assert any(it["id"] == a["id"] for it in onayli)
    assert not any(it["id"] == b["id"] for it in onayli)
    # durum=iptal -> b var
    iptal = client.get(
        "/reservations", headers=yonetici,
        params={"durum": "iptal", "limit": 200},
    ).json()["items"]
    assert any(it["id"] == b["id"] for it in iptal)
    # alan + tarih filtresi (gun gorunumu)
    gun = client.get(
        "/reservations", headers=yonetici,
        params={"alan_id": rworld["alan2"], "tarih": tarih, "limit": 200},
    ).json()["items"]
    assert [it["id"] for it in gun] == [b["id"]]
    # gecersiz durum 422
    assert client.get(
        "/reservations", headers=yonetici, params={"durum": "olmayan"}
    ).status_code == 422


# ----------------------------- tenant izolasyonu ---------------------------- #
def test_tenant_izolasyonu(client, rworld):
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    r = _post(client, resident, rworld["alan1"], _hslot(2))

    yonetici_b = _headers(client, rworld["slug_b"], rworld["yonetici_b"])
    # B yonetimi A'nin rezervasyonunu goremez (RLS -> 404)
    b_ids = [it["id"] for it in client.get(
        "/reservations", headers=yonetici_b, params={"limit": 200}
    ).json()["items"]]
    assert r["id"] not in b_ids
    assert client.get(f"/reservations/{r['id']}", headers=yonetici_b).status_code == 404
    # Iptal zaten YALNIZ sakin (yonetim rolu 403) — B yonetimi de A'nin kaydini
    # iptal edemez (rol kapisi; ayrica RLS/ownership).
    assert client.post(
        f"/reservations/{r['id']}/cancel", headers=yonetici_b
    ).status_code == 403
    # B yonetimi A'nin alanini da goremez
    b_alan_ids = [it["id"] for it in client.get(
        "/common-areas", headers=yonetici_b, params={"limit": 200}
    ).json()["items"]]
    assert rworld["alan1"] not in b_alan_ids


# ------------------------------ musaitlik / slotlar ------------------------- #
def test_alan_musaitlik_create_ve_okuma(client, rworld):
    yonetici = _headers(client, rworld["slug_a"], rworld["yonetici_a"])
    alan = _mk_area(client, yonetici, ad=f"Salon-{uuid.uuid4().hex[:6]}",
                    acilis="10:00", kapanis="14:00", slot_dakika=60)
    assert alan["acilis"] == "10:00" and alan["kapanis"] == "14:00"
    assert alan["slot_dakika"] == 60
    # kapanis <= acilis -> 422
    assert client.post(
        "/common-areas", headers=yonetici,
        json={"ad": f"X-{uuid.uuid4().hex[:6]}", "acilis": "14:00", "kapanis": "10:00"},
    ).status_code == 422
    # saat verilmezse tum-gun varsayilan (00:00, 60 dk)
    d = _mk_area(client, yonetici, ad=f"Def-{uuid.uuid4().hex[:6]}")
    assert d["acilis"] == "00:00" and d["slot_dakika"] == 60
    # kismi guncelleme: yalniz slot_dakika
    p = client.patch(f"/common-areas/{alan['id']}", headers=yonetici,
                     json={"slot_dakika": 30})
    assert p.status_code == 200 and p.json()["slot_dakika"] == 30


def test_slots_dolu_bos_ve_gorunurluk_kademesi(client, rworld):
    """Slot izgarasi + ROL-FARKINDA gorunurluk: resident dolu slotta yalniz
    'dolu' (kimlik/kisi GIZLI); yonetim dolu slotta rezerve eden daire + kisi."""
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    diger = _headers(client, rworld["slug_a"], rworld["diger"])
    yonetici = _headers(client, rworld["slug_a"], rworld["yonetici_a"])
    # Pencere simdiye gore: [+1s, +5s] — 4 gelecek slot, hepsi <24s icinde.
    start = (_now() + timedelta(hours=1)).replace(minute=0, second=0, microsecond=0)
    h = start.hour
    tarih = start.date().isoformat()
    alan = _mk_area(client, yonetici, ad=f"Slot-{uuid.uuid4().hex[:6]}",
                    acilis=f"{h:02d}:00", kapanis=f"{h + 4:02d}:00", slot_dakika=60)
    s2 = (tarih, f"{h + 1:02d}:00", f"{h + 2:02d}:00")  # ikinci slot
    bos_bas = f"{h:02d}:00"

    def _slots(headers):
        r = client.get(f"/common-areas/{alan['id']}/slots", headers=headers,
                       params={"date": tarih})
        assert r.status_code == 200, r.text
        return {it["baslangic"]: it for it in r.json()["items"]}

    # baslangicta hepsi BOS + sakin rezerve edebilir (<24s icinde)
    s0 = _slots(diger)
    assert len(s0) == 4 and all(it["dolu"] is False for it in s0.values())
    assert all(it["rezerve_edilebilir"] and it["sebep"] is None for it in s0.values())

    # resident kisi_sayisi=3 ile ikinci slotu rezerve eder -> o slot dolu
    _post(client, resident, alan["id"], s2, kisi_sayisi=3)
    dolu_bas = s2[1]

    # RESIDENT (diger) gorunumu: BASKASININ dolu slotu ANONIM — kimlik/kisi
    # GIZLI (None) VE benim=False (kimlik SIZMAZ).
    s1 = _slots(diger)
    assert s1[dolu_bas]["dolu"] is True
    assert s1[dolu_bas]["rezerve_edilebilir"] is False and s1[dolu_bas]["sebep"] == "dolu"
    for it in s1.values():
        assert set(it.keys()) == {"baslangic", "bitis", "dolu",
                                  "rezerve_edilebilir", "sebep",
                                  "unit_no", "kisi_sayisi", "benim"}
        assert it["unit_no"] is None and it["kisi_sayisi"] is None
    # diger baskasinin (resident_a) slotunu KENDI slotu SANMAZ
    assert s1[dolu_bas]["benim"] is False

    # YONETIM gorunumu: dolu slotta rezerve eden DAIRE + kisi sayisi (benim yok)
    s_y = _slots(yonetici)
    assert s_y[dolu_bas]["unit_no"] == rworld["unit1_no"]
    assert s_y[dolu_bas]["kisi_sayisi"] == 3
    assert s_y[dolu_bas]["benim"] is False
    # bos slotta yonetimde de unit/kisi None
    assert s_y[bos_bas]["unit_no"] is None and s_y[bos_bas]["kisi_sayisi"] is None
    # yonetim rezerve_edilemez (rezerve etmez)
    assert all(it["rezerve_edilebilir"] is False for it in s_y.values())

    # KOTA yansir: rezerve eden sakin icin bos slotlar 'gunluk' (edilemez)
    s_res = _slots(resident)
    assert s_res[bos_bas]["rezerve_edilebilir"] is False
    assert s_res[bos_bas]["sebep"] == "gunluk"
    assert s_res[bos_bas]["unit_no"] is None  # kendi gorununde de kimlik yok
    # KENDI dolu slotu: benim=True (yesil/kirmizi rengi buradan) — ama kimlik
    # alani yine None (renk karari baslangic/bitis+simdi ile).
    assert s_res[dolu_bas]["benim"] is True
    assert s_res[dolu_bas]["unit_no"] is None and s_res[dolu_bas]["kisi_sayisi"] is None

    # TUM roller slotlari okuyabilir
    for role in ("resident_a", "guard_a", "gorevli_a", "yonetici_a", "admin_a"):
        _slots(_headers(client, rworld["slug_a"], rworld[role]))


def test_slots_pasif_alan_sakine_404(client, rworld):
    yonetici = _headers(client, rworld["slug_a"], rworld["yonetici_a"])
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    tarih = _hslot(2)[0]
    alan = _mk_area(client, yonetici, ad=f"Pasif-{uuid.uuid4().hex[:6]}")
    client.patch(f"/common-areas/{alan['id']}", headers=yonetici,
                 json={"aktif": False})
    # pasif alan sakine gorunmez (rezerve edilemez -> varlik sizdirilmaz)
    assert client.get(f"/common-areas/{alan['id']}/slots", headers=resident,
                      params={"date": tarih}).status_code == 404
    # yonetim pasif alanin slotlarini gorur (duzenleme baglami)
    assert client.get(f"/common-areas/{alan['id']}/slots", headers=yonetici,
                      params={"date": tarih}).status_code == 200


def test_rezerve_musaitlik_penceresi_disi_422(client, rworld):
    yonetici = _headers(client, rworld["slug_a"], rworld["yonetici_a"])
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    # Pencere [+2s, +4s]: ici slotlar gelecekte + <24s icinde.
    start = (_now() + timedelta(hours=2)).replace(minute=0, second=0, microsecond=0)
    h = start.hour
    tarih = start.date().isoformat()
    alan = _mk_area(client, yonetici, ad=f"Pencere-{uuid.uuid4().hex[:6]}",
                    acilis=f"{h:02d}:00", kapanis=f"{h + 2:02d}:00", slot_dakika=60)
    # acilis oncesi (+1s) -> 422 musaitlik disi
    _post(client, resident, alan["id"],
          (tarih, f"{h - 1:02d}:00", f"{h:02d}:00"), expect=422)
    # kapanis sonrasi -> 422
    _post(client, resident, alan["id"],
          (tarih, f"{h + 2:02d}:00", f"{h + 3:02d}:00"), expect=422)
    # pencere ici -> 201
    _post(client, resident, alan["id"],
          (tarih, f"{h:02d}:00", f"{h + 1:02d}:00"), expect=201)
