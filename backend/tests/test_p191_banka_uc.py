"""(P191 §4) BANKA ENTEGRASYONU — UÇTAN UCA.

Motor testleri (`test_p191_banka_motor.py`) kararın DOĞRU olduğunu ölçer;
bu dosya kararın ürüne DOĞRU İŞLENDİĞİNİ ölçer:

  * borç gerçekten kapanıyor mu (`/dues` bakiyesi),
  * defter satırı yazılıyor mu (`finansal_hareket`),
  * makbuz üretiliyor mu,
  * aynı ekstre iki kez yüklenince ikinci kez hiçbir şey olmuyor mu,
  * yanlış eşleşme geri alınınca borç YENİDEN AÇILIYOR mu,
  * yönetim dışı roller bu uçları göremiyor mu.
"""
from __future__ import annotations

import uuid
from datetime import date

import pytest


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def banka_dunya(client, world, owner_conn):
    """Bir daire + o daireye bağlı sakin + iki açık aidat borcu.

    Sakinin `odeme_kodu`su DOĞRUDAN veritabanına yazılır: kodun nasıl
    üretildiği (P30) bu testin konusu değil, eşleştirmede KULLANILDIĞI
    konusu.
    """
    admin = _headers(client, world["slug_a"], world["admin_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])
    resident_id = client.get("/me", headers=resident).json()["id"]

    u = client.post(
        "/units", headers=admin, json={"no": f"BNK-{uuid.uuid4().hex[:6]}", "blok": "A"}
    )
    assert u.status_code == 201, u.text
    unit = u.json()
    assert client.post(
        f"/units/{unit['id']}/residents",
        headers=admin,
        json={"user_id": resident_id, "rol_tipi": "malik"},
    ).status_code == 201

    kod = f"TS-{uuid.uuid4().hex[:6].upper().translate(str.maketrans('01IO', 'ABCD'))}"
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE app_user SET odeme_kodu = %s WHERE id = %s", (kod, resident_id)
        )
    owner_conn.commit()

    donemler = []
    for ay, tutar in (("2035-01", 50000), ("2035-02", 50000)):
        r = client.post(
            "/dues/assessments",
            headers=admin,
            json={"unit_id": unit["id"], "donem": ay, "tutar_kurus": tutar},
        )
        assert r.status_code == 201, r.text
        donemler.append(ay)
    return {
        "admin": admin,
        "resident": resident,
        "resident_id": resident_id,
        "unit": unit,
        "odeme_kodu": kod,
        "donemler": donemler,
    }


def _bakiye(client, headers, unit_id) -> int:
    r = client.get(f"/units/{unit_id}/dues", headers=headers)
    assert r.status_code == 200, r.text
    return r.json()["bakiye_kurus"]


def _ice_aktar(client, headers, satirlar):
    return client.post(
        "/banka/ice-aktar", headers=headers, json={"kaynak": "ekstre", "satirlar": satirlar}
    )


def _satir(tutar, aciklama, **kw):
    govde = {
        "tarih": date.today().isoformat(),
        "tutar": tutar,
        "aciklama": aciklama,
    }
    govde.update(kw)
    return govde


# ============================== İÇE AKTARMA ================================= #
def test_AYNI_EKSTRE_IKI_KEZ_yuklenince_MUKERRER_YOK(client, banka_dunya):
    admin = banka_dunya["admin"]
    satirlar = [_satir(50000, f"HAVALE {uuid.uuid4().hex[:8]}")]
    ilk = _ice_aktar(client, admin, satirlar)
    assert ilk.status_code == 201, ilk.text
    assert ilk.json()["eklenen"] == 1 and ilk.json()["yinelenen"] == 0
    ikinci = _ice_aktar(client, admin, satirlar)
    assert ikinci.status_code == 201
    # Sessiz başarı DEĞİL: kullanıcı "zaten yüklüydü"yü görmeli.
    assert ikinci.json()["eklenen"] == 0 and ikinci.json()["yinelenen"] == 1


def test_AYNI_GUN_AYNI_TUTAR_IKI_GERCEK_HAVALE_ayri_kalir(client, banka_dunya):
    """Mükerrer koruması gerçek bir ödemeyi YUTMAMALI: iki ayrı satır
    (sıra numarası kimliğe girer) iki hareket üretir."""
    admin = banka_dunya["admin"]
    etiket = uuid.uuid4().hex[:8]
    r = _ice_aktar(client, admin, [_satir(50000, f"AIDAT {etiket}"), _satir(50000, f"AIDAT {etiket}")])
    assert r.json()["eklenen"] == 2, r.text


def test_ekstre_BOS_ise_422(client, banka_dunya):
    r = _ice_aktar(client, banka_dunya["admin"], [])
    assert r.status_code == 422


def test_MT940_metni_sunucuda_ayristirilir(client, banka_dunya):
    mt = (
        ":20:STARTUMS\n"
        ":25:TR330006100519786457841326\n"
        ":60F:C260830TRY0,00\n"
        f":61:2608300830C500,00NTRFREF{uuid.uuid4().hex[:8]}\n"
        f":86:HAVALE {banka_dunya['odeme_kodu']} AIDAT\n"
        ":62F:C260830TRY500,00\n"
    )
    r = client.post(
        "/banka/ice-aktar", headers=banka_dunya["admin"], json={"kaynak": "ekstre", "mt940": mt}
    )
    assert r.status_code == 201, r.text
    assert r.json()["eklenen"] == 1


def test_MT940_BOZUK_metin_422(client, banka_dunya):
    r = client.post(
        "/banka/ice-aktar", headers=banka_dunya["admin"], json={"kaynak": "ekstre", "mt940": "merhaba"}
    )
    assert r.status_code == 422


# ============================== EŞLEŞTİRME ================================== #
def test_REFERANSLI_odeme_BORCU_KAPATIR_DEFTERE_YAZILIR_MAKBUZ_URETIR(
    client, banka_dunya, owner_conn
):
    admin = banka_dunya["admin"]
    unit_id = banka_dunya["unit"]["id"]
    assert _bakiye(client, admin, unit_id) == 100000

    _ice_aktar(client, admin, [_satir(50000, f"AIDAT {banka_dunya['odeme_kodu']}")])
    r = client.post("/banka/eslestir", headers=admin)
    assert r.status_code == 200, r.text
    assert r.json()["otomatik"] >= 1, r.json()

    # 1) BORÇ KAPANDI (en eski dönemden).
    assert _bakiye(client, admin, unit_id) == 50000

    # 2) DEFTER SATIRI — tek satır, tutarın TAMAMI.
    with owner_conn.cursor() as cur:
        cur.execute(
            # psycopg'de `%` bir yer tutucudur: LIKE yerine `starts_with`.
            "SELECT count(*), coalesce(sum(tutar_kurus),0) FROM finansal_hareket "
            "WHERE starts_with(idempotency_key, 'banka:') AND tip='tahsilat' "
            "AND unit_id=%s",
            (unit_id,),
        )
        adet, toplam = cur.fetchone()
    assert adet == 1 and toplam == 50000

    # 3) MAKBUZ.
    hareketler = client.get(
        "/banka/hareketler", headers=admin, params={"durum": "eslesti"}
    ).json()["items"]
    eslesen = [h for h in hareketler if h["eslesmeler"]]
    assert eslesen, hareketler
    makbuz_id = eslesen[0]["eslesmeler"][0]["receipt_id"]
    assert makbuz_id
    m = client.get(f"/banka/makbuz/{makbuz_id}", headers=admin)
    assert m.status_code == 200, m.text
    assert m.json()["tutar_kurus"] == 50000
    assert m.json()["belge_no"]
    # PDF GERÇEKTEN ÜRETİLDİ VE DEPOYA YAZILDI. Makbuzu "kayıt var" diye
    # doğru saymak, sakinin indiremediği bir belgeyi başarı saymak olurdu.
    assert m.json()["pdf_url"], m.json()


def test_TEK_TRANSFER_IKI_AYI_KAPATIR_FIFO(client, banka_dunya):
    admin = banka_dunya["admin"]
    unit_id = banka_dunya["unit"]["id"]
    _ice_aktar(client, admin, [_satir(100000, f"AIDAT {banka_dunya['odeme_kodu']}")])
    client.post("/banka/eslestir", headers=admin)
    assert _bakiye(client, admin, unit_id) == 0


def test_FAZLA_ODEME_daire_ALACAGINDA_bekler(client, banka_dunya):
    admin = banka_dunya["admin"]
    unit_id = banka_dunya["unit"]["id"]
    _ice_aktar(client, admin, [_satir(150000, f"AIDAT {banka_dunya['odeme_kodu']}")])
    client.post("/banka/eslestir", headers=admin)
    # 100.000 borç, 150.000 ödeme -> 50.000 ALACAK (negatif bakiye).
    assert _bakiye(client, admin, unit_id) == -50000


def test_ESLESMEYEN_hareket_MANUEL_INCELEMEYE_duser(client, banka_dunya):
    admin = banka_dunya["admin"]
    _ice_aktar(client, admin, [_satir(77777, f"BILINMEYEN {uuid.uuid4().hex[:6]}")])
    r = client.post("/banka/eslestir", headers=admin)
    assert r.json()["manuel"] >= 1
    liste = client.get(
        "/banka/hareketler", headers=admin, params={"durum": "manuel_inceleme"}
    ).json()
    assert liste["meta"]["total"] >= 1


def test_CIKIS_HAREKETI_otomatik_gider_YAZMAZ(client, banka_dunya, owner_conn):
    """Banka masrafı yönetici onayına düşer (kullanıcının açık kuralı)."""
    admin = banka_dunya["admin"]
    _ice_aktar(
        client, admin,
        [_satir(-1500, f"BANKA MASRAFI {uuid.uuid4().hex[:6]}", yon="cikis")],
    )
    client.post("/banka/eslestir", headers=admin)
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM finansal_hareket WHERE tip='gider' "
            "AND starts_with(idempotency_key, 'banka:')"
        )
        assert cur.fetchone()[0] == 0


def test_IBAN_MASKELI_doner_TAM_IBAN_SIZMAZ(client, banka_dunya):
    admin = banka_dunya["admin"]
    iban = "TR330006100519786457841326"
    _ice_aktar(client, admin, [_satir(4242, f"IBANLI {uuid.uuid4().hex[:6]}", karsi_iban=iban)])
    metin = client.get("/banka/hareketler", headers=admin).text
    assert iban not in metin
    assert "1326" in metin  # son 4 hane gorunur


# =========================== MANUEL EŞLEŞTİRME ============================== #
def test_MANUEL_ESLESTIRME_borcu_kapatir(client, banka_dunya):
    admin = banka_dunya["admin"]
    unit_id = banka_dunya["unit"]["id"]
    _ice_aktar(client, admin, [_satir(50000, f"ISIMSIZ {uuid.uuid4().hex[:6]}")])
    client.post("/banka/eslestir", headers=admin)
    manuel = client.get(
        "/banka/hareketler", headers=admin, params={"durum": "manuel_inceleme"}
    ).json()["items"]
    hedef = manuel[0]
    r = client.post(
        f"/banka/hareketler/{hedef['id']}/manuel-eslestir",
        headers=admin,
        json={"user_id": banka_dunya["resident_id"], "unit_id": unit_id},
    )
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "eslesti"
    assert r.json()["eslesmeler"][0]["match_type"] == "manuel"
    assert _bakiye(client, admin, unit_id) == 50000


def test_ESLESMIS_hareket_TEKRAR_eslestirilemez(client, banka_dunya):
    admin = banka_dunya["admin"]
    _ice_aktar(client, admin, [_satir(50000, f"AIDAT {banka_dunya['odeme_kodu']}")])
    client.post("/banka/eslestir", headers=admin)
    eslesen = client.get(
        "/banka/hareketler", headers=admin, params={"durum": "eslesti"}
    ).json()["items"][0]
    r = client.post(
        f"/banka/hareketler/{eslesen['id']}/manuel-eslestir",
        headers=admin,
        json={"user_id": banka_dunya["resident_id"]},
    )
    assert r.status_code == 409


# ============================== GERİ ALMA =================================== #
def test_YANLIS_ESLESMEYI_GERI_ALMA_borcu_YENIDEN_ACAR(client, banka_dunya, owner_conn):
    admin = banka_dunya["admin"]
    unit_id = banka_dunya["unit"]["id"]
    _ice_aktar(client, admin, [_satir(50000, f"AIDAT {banka_dunya['odeme_kodu']}")])
    client.post("/banka/eslestir", headers=admin)
    assert _bakiye(client, admin, unit_id) == 50000

    eslesen = client.get(
        "/banka/hareketler", headers=admin, params={"durum": "eslesti"}
    ).json()["items"][0]
    r = client.post(
        f"/banka/hareketler/{eslesen['id']}/geri-al",
        headers=admin,
        json={"not_metni": "yanlis kisi"},
    )
    assert r.status_code == 200, r.text
    # BORÇ YENİDEN AÇILDI.
    assert _bakiye(client, admin, unit_id) == 100000
    # SİLME YOK — TERS KAYIT VAR.
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM finansal_hareket WHERE tip='iptal' "
            "AND starts_with(idempotency_key, 'banka-iptal:')"
        )
        assert cur.fetchone()[0] >= 1
        cur.execute("SELECT count(*) FROM payment_match WHERE durum='geri_alindi'")
        assert cur.fetchone()[0] >= 1


def test_GERI_ALINAN_hareket_YENIDEN_eslestirilebilir(client, banka_dunya):
    admin = banka_dunya["admin"]
    unit_id = banka_dunya["unit"]["id"]
    _ice_aktar(client, admin, [_satir(50000, f"AIDAT {banka_dunya['odeme_kodu']}")])
    client.post("/banka/eslestir", headers=admin)
    eslesen = client.get(
        "/banka/hareketler", headers=admin, params={"durum": "eslesti"}
    ).json()["items"][0]
    client.post(
        f"/banka/hareketler/{eslesen['id']}/geri-al", headers=admin, json={"not_metni": "x"}
    )
    r = client.post(
        f"/banka/hareketler/{eslesen['id']}/manuel-eslestir",
        headers=admin,
        json={"user_id": banka_dunya["resident_id"], "unit_id": unit_id},
    )
    assert r.status_code == 200, r.text
    assert _bakiye(client, admin, unit_id) == 50000


def test_ESLESMESIZ_harekette_geri_al_409(client, banka_dunya):
    admin = banka_dunya["admin"]
    _ice_aktar(client, admin, [_satir(999, f"YALNIZ {uuid.uuid4().hex[:6]}")])
    h = client.get("/banka/hareketler", headers=admin).json()["items"][0]
    r = client.post(f"/banka/hareketler/{h['id']}/geri-al", headers=admin, json={})
    assert r.status_code == 409


# ============================ İŞARETLEME ==================================== #
def test_ILGISIZ_GELIR_isaretlenir(client, banka_dunya):
    admin = banka_dunya["admin"]
    _ice_aktar(client, admin, [_satir(12345, f"KIRA GELIRI {uuid.uuid4().hex[:6]}")])
    h = client.get("/banka/hareketler", headers=admin, params={"durum": "yeni"}).json()["items"][0]
    r = client.post(
        f"/banka/hareketler/{h['id']}/isaretle",
        headers=admin,
        json={"durum": "ilgisiz_gelir", "not_metni": "dukkan kirasi"},
    )
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "ilgisiz_gelir"


def test_BANKA_MASRAFI_isaretlemesi_GIDER_YAZMAZ(client, banka_dunya, owner_conn):
    admin = banka_dunya["admin"]
    _ice_aktar(client, admin, [_satir(-2500, f"KOMISYON {uuid.uuid4().hex[:6]}", yon="cikis")])
    h = client.get("/banka/hareketler", headers=admin, params={"durum": "yeni"}).json()["items"][0]
    r = client.post(
        f"/banka/hareketler/{h['id']}/isaretle",
        headers=admin,
        json={"durum": "masraf", "not_metni": "eft komisyonu"},
    )
    assert r.status_code == 200
    with owner_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM finansal_hareket WHERE tip='gider' AND aciklama='eft komisyonu'")
        assert cur.fetchone()[0] == 0


def test_GECERSIZ_isaret_422(client, banka_dunya):
    admin = banka_dunya["admin"]
    _ice_aktar(client, admin, [_satir(500, f"X {uuid.uuid4().hex[:6]}")])
    h = client.get("/banka/hareketler", headers=admin, params={"durum": "yeni"}).json()["items"][0]
    r = client.post(
        f"/banka/hareketler/{h['id']}/isaretle", headers=admin, json={"durum": "eslesti"}
    )
    assert r.status_code == 422


# =============================== YETKİ ====================================== #
@pytest.mark.parametrize("kim", ["resident_a", "guard_a", "gorevli_a"])
def test_YONETIM_DISI_ROLLER_403(client, world, kim):
    h = _headers(client, world["slug_a"], world[kim])
    assert client.get("/banka/hareketler", headers=h).status_code == 403
    assert client.post("/banka/eslestir", headers=h).status_code == 403
    assert client.post(
        "/banka/ice-aktar", headers=h, json={"kaynak": "ekstre", "satirlar": []}
    ).status_code == 403


def test_KIMLIKSIZ_401(client):
    assert client.get("/banka/hareketler").status_code == 401


def test_TESIS_IZOLASYONU(client, world, banka_dunya):
    """B tesisi A'nın banka hareketlerini GÖRMEZ (RLS)."""
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    _ice_aktar(client, banka_dunya["admin"], [_satir(31337, f"IZOLE {uuid.uuid4().hex[:6]}")])
    metin = client.get("/banka/hareketler", headers=admin_b).text
    assert "31337" not in metin
