"""Icerik cevirisi — API davranisi (calisan sunucu).

Kapsam: YAZMA yolunda ceviri isinin acilmasi, OKUMA yolunda Accept-Language
eslesmesi + geri-dusme zinciri + `bekliyor` davranisi, `?dil=` ezmesi,
orijinal metnin her zaman donmesi ve tenant izolasyonu.

DETERMINIZM NOTU: dev/test ortaminda worker `echo` saglayicisiyla kosar ve
API'den olusturulan icerigi arka planda cevirebilir. Bu yuzden OKUMA testleri
icerigi DOGRUDAN DB'ye yazar (kuyruk tetiklenmez) ve ceviri satirlarini kendisi
kurar — boylece beklenen metin worker zamanlamasindan BAGIMSIZ olur. YAZMA
testleri ise yaristan etkilenmeyen olgulari dogrular (satirlarin acilmasi,
kaynak_hash, elle_duzeltildi bayragi).
"""
from __future__ import annotations

import json
import uuid

import pytest

from app import ceviri


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# --------------------------------- yardimci --------------------------------- #
def _db_duyuru(owner_conn, tenant_id, baslik, govde):
    """Duyuruyu DOGRUDAN DB'ye yazar — API'yi atlar, yani ceviri KUYRUKLANMAZ."""
    return owner_conn.execute(
        """
        INSERT INTO announcement (tenant_id, baslik, govde, olusturan_user_id)
        SELECT %s, %s, %s, u.id FROM app_user u
         WHERE u.tenant_id = %s ORDER BY u.email LIMIT 1
        RETURNING id
        """,
        (tenant_id, baslik, govde, tenant_id),
    ).fetchone()[0]


def _db_ceviri(
    owner_conn, tenant_id, aid, dil, alanlar, *, durum="hazir",
    elle_duzeltildi=False, kaynak_hash_="h",
):
    owner_conn.execute(
        """
        INSERT INTO announcement_ceviri
            (tenant_id, announcement_id, dil, alanlar, durum, cevirildi_mi,
             elle_duzeltildi, kaynak_hash)
        VALUES (%s, %s, %s, %s::jsonb, %s::ceviri_durum, %s, %s, %s)
        ON CONFLICT (tenant_id, announcement_id, dil) DO UPDATE
           SET alanlar = EXCLUDED.alanlar, durum = EXCLUDED.durum,
               cevirildi_mi = EXCLUDED.cevirildi_mi,
               elle_duzeltildi = EXCLUDED.elle_duzeltildi,
               kaynak_hash = EXCLUDED.kaynak_hash
        """,
        (tenant_id, aid, dil, json.dumps(alanlar, ensure_ascii=False), durum,
         not elle_duzeltildi, elle_duzeltildi, kaynak_hash_),
    )


def _satirlar(owner_conn, aid):
    return {
        r[0]: {"durum": r[1], "elle_duzeltildi": r[2], "kaynak_hash": r[3],
               "alanlar": r[4]}
        for r in owner_conn.execute(
            "SELECT dil, durum::text, elle_duzeltildi, kaynak_hash, alanlar "
            "FROM announcement_ceviri WHERE announcement_id = %s",
            (aid,),
        ).fetchall()
    }


# ------------------------------- YAZMA yolu --------------------------------- #
def test_olusturma_6_hedef_dil_icin_ceviri_isi_ACAR(client, world, owner_conn):
    """POST sonrasi hedef diller icin satir acilir (kaynak dil icin ACILMAZ)."""
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post(
        "/announcements",
        headers=h,
        json={"baslik": f"Su kesintisi {uuid.uuid4().hex[:6]}", "govde": "Yarin 10:00."},
    )
    assert r.status_code == 201, r.text
    aid = r.json()["id"]

    satirlar = _satirlar(owner_conn, aid)
    assert set(satirlar) == set(ceviri.hedef_diller("tr"))
    assert "tr" not in satirlar
    beklenen = ceviri.kaynak_hash(
        {"baslik": r.json()["orijinal"]["baslik"], "govde": "Yarin 10:00."}
    )
    assert all(s["kaynak_hash"] == beklenen for s in satirlar.values())
    client.delete(f"/announcements/{aid}", headers=h)


def test_olusturma_yanitinda_ceviri_alanlari_bulunur(client, world):
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post(
        "/announcements", headers=h,
        json={"baslik": "Bakim", "govde": "Asansor bakimi."},
    )
    assert r.status_code == 201
    g = r.json()
    assert g["orijinal_dil"] == "tr"
    assert g["gosterilen_dil"] == "tr"
    assert g["ceviri_durumu"] == "hazir"      # kaynak dil her zaman hazir
    assert g["cevirildi_mi"] is False         # orijinal makine ciktisi degil
    assert g["orijinal"] == {"baslik": "Bakim", "govde": "Asansor bakimi."}
    client.delete(f"/announcements/{g['id']}", headers=h)


def test_govde_duzenlemesi_ELLE_DUZELTMEYI_gecersiz_kilar(
    client, world, owner_conn
):
    """Kaynak METIN degistiyse elle duzeltme korunmaz (bayrak duser)."""
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    aid = _db_duyuru(owner_conn, world["a"], "Su kesintisi", "Yarin 10:00.")
    dogru_hash = ceviri.kaynak_hash({"baslik": "Su kesintisi", "govde": "Yarin 10:00."})
    _db_ceviri(
        owner_conn, world["a"], aid, "ru",
        {"baslik": "Отключение воды", "govde": "Завтра в 10:00."},
        elle_duzeltildi=True, kaynak_hash_=dogru_hash,
    )

    r = client.patch(
        f"/announcements/{aid}", headers=h, json={"govde": "IPTAL edildi."}
    )
    assert r.status_code == 200, r.text

    ru = _satirlar(owner_conn, aid)["ru"]
    assert ru["elle_duzeltildi"] is False        # duzeltme GECERSIZ
    assert ru["alanlar"].get("baslik") != "Отключение воды"


def test_ILGISIZ_alan_duzenlemesi_ELLE_DUZELTMEYI_korur(
    client, world, owner_conn
):
    """Yalniz foto_key degistiginde kaynak metin AYNI -> duzeltme KALIR."""
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    aid = _db_duyuru(owner_conn, world["a"], "Havuz bakimi", "Cuma kapali.")
    dogru_hash = ceviri.kaynak_hash({"baslik": "Havuz bakimi", "govde": "Cuma kapali."})
    _db_ceviri(
        owner_conn, world["a"], aid, "ru",
        {"baslik": "Обслуживание бассейна", "govde": "В пятницу закрыто."},
        elle_duzeltildi=True, kaynak_hash_=dogru_hash,
    )

    r = client.patch(
        f"/announcements/{aid}",
        headers=h,
        json={"foto_key": f"{world['a']}/duyuru-foto.jpg"},
    )
    assert r.status_code == 200, r.text

    ru = _satirlar(owner_conn, aid)["ru"]
    assert ru["elle_duzeltildi"] is True                       # KORUNDU
    assert ru["alanlar"]["baslik"] == "Обслуживание бассейна"
    assert ru["durum"] == "hazir"


def test_ayni_govde_ile_PATCH_hazir_ceviriyi_bozmaz(client, world, owner_conn):
    """Metin degismediyse (ayni deger gonderildi) ceviri `hazir` kalir."""
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    aid = _db_duyuru(owner_conn, world["a"], "Genel kurul", "Pazar 14:00.")
    dogru_hash = ceviri.kaynak_hash({"baslik": "Genel kurul", "govde": "Pazar 14:00."})
    _db_ceviri(
        owner_conn, world["a"], aid, "ru", {"baslik": "Собрание", "govde": "14:00."},
        elle_duzeltildi=True, kaynak_hash_=dogru_hash,
    )

    r = client.patch(f"/announcements/{aid}", headers=h, json={"govde": "Pazar 14:00."})
    assert r.status_code == 200

    assert _satirlar(owner_conn, aid)["ru"]["elle_duzeltildi"] is True


def test_icerik_kaydi_ceviriden_BAGIMSIZ_basarilidir(client, world, owner_conn):
    """BASARISIZLIK ILKESI (API katmani): ceviri ne olursa olsun POST 201.

    Saglayici/kuyruk durumu ne olursa olsun kayit yazilir ve orijinal metin
    okunabilir — bu testin gecmesi ceviri hattina BAGLI DEGILDIR.
    """
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post(
        "/announcements", headers=h,
        json={"baslik": "Kritik duyuru", "govde": "Elektrik kesintisi."},
    )
    assert r.status_code == 201
    aid = r.json()["id"]
    d = client.get(f"/announcements/{aid}", headers=h).json()
    assert d["baslik"] == "Kritik duyuru" and d["govde"] == "Elektrik kesintisi."
    client.delete(f"/announcements/{aid}", headers=h)


# ------------------------------- OKUMA yolu --------------------------------- #
def test_accept_language_ru_cevrilmis_metni_verir(client, world, owner_conn):
    h = _headers(client, world["slug_a"], world["resident_a"])
    aid = _db_duyuru(owner_conn, world["a"], "Su kesintisi", "Yarin 10:00.")
    _db_ceviri(
        owner_conn, world["a"], aid, "ru",
        {"baslik": "Отключение воды", "govde": "Завтра в 10:00."},
    )

    r = client.get(
        f"/announcements/{aid}", headers={**h, "Accept-Language": "ru-RU,ru;q=0.9"}
    )
    assert r.status_code == 200
    g = r.json()
    assert g["baslik"] == "Отключение воды"
    assert g["govde"] == "Завтра в 10:00."
    assert g["gosterilen_dil"] == "ru"
    assert g["ceviri_durumu"] == "hazir"
    assert g["cevirildi_mi"] is True
    # ORIJINAL her zaman erisilebilir.
    assert g["orijinal"] == {"baslik": "Su kesintisi", "govde": "Yarin 10:00."}
    assert g["orijinal_dil"] == "tr"


def test_accept_language_arapca(client, world, owner_conn):
    h = _headers(client, world["slug_a"], world["resident_a"])
    aid = _db_duyuru(owner_conn, world["a"], "Su kesintisi", "Yarin 10:00.")
    _db_ceviri(
        owner_conn, world["a"], aid, "ar",
        {"baslik": "انقطاع المياه", "govde": "غدا الساعة 10:00."},
    )

    g = client.get(
        f"/announcements/{aid}", headers={**h, "Accept-Language": "ar"}
    ).json()
    assert g["baslik"] == "انقطاع المياه"
    assert g["gosterilen_dil"] == "ar"


def test_DESTEKLENMEYEN_dil_orijinale_duser(client, world, owner_conn):
    """ja desteklenmiyor -> geri-dusme: orijinal (tr) servis edilir."""
    h = _headers(client, world["slug_a"], world["resident_a"])
    aid = _db_duyuru(owner_conn, world["a"], "Su kesintisi", "Yarin 10:00.")

    g = client.get(
        f"/announcements/{aid}", headers={**h, "Accept-Language": "ja,ko;q=0.8"}
    ).json()
    assert g["baslik"] == "Su kesintisi"
    assert g["gosterilen_dil"] == "tr"
    assert g["ceviri_durumu"] == "hazir"   # kaynak dil servis edildi


def test_q_degeri_desteklenen_ilk_dili_secer(client, world, owner_conn):
    """ja (q=0.9) desteklenmiyor -> ru (q=0.8) secilir."""
    h = _headers(client, world["slug_a"], world["resident_a"])
    aid = _db_duyuru(owner_conn, world["a"], "Su kesintisi", "Yarin 10:00.")
    _db_ceviri(owner_conn, world["a"], aid, "ru", {"baslik": "RU", "govde": "RU"})

    g = client.get(
        f"/announcements/{aid}",
        headers={**h, "Accept-Language": "ja;q=0.9,ru;q=0.8,en;q=0.7"},
    ).json()
    assert g["gosterilen_dil"] == "ru" and g["baslik"] == "RU"


def test_BEKLIYOR_orijinali_verir_durum_bekliyor(client, world, owner_conn):
    """Ceviri hazir degil: ekran BOS KALMAZ, istemci "hazirlaniyor" der."""
    h = _headers(client, world["slug_a"], world["resident_a"])
    aid = _db_duyuru(owner_conn, world["a"], "Su kesintisi", "Yarin 10:00.")
    _db_ceviri(owner_conn, world["a"], aid, "ru", {}, durum="bekliyor")

    g = client.get(
        f"/announcements/{aid}", headers={**h, "Accept-Language": "ru"}
    ).json()
    assert g["baslik"] == "Su kesintisi"        # ORIJINAL
    assert g["ceviri_durumu"] == "bekliyor"     # gercek durum
    assert g["gosterilen_dil"] == "tr"
    assert g["cevirildi_mi"] is False


def test_HATA_durumunda_da_orijinal_servis_edilir(client, world, owner_conn):
    h = _headers(client, world["slug_a"], world["resident_a"])
    aid = _db_duyuru(owner_conn, world["a"], "Su kesintisi", "Yarin 10:00.")
    _db_ceviri(owner_conn, world["a"], aid, "ru", {}, durum="hata")

    g = client.get(
        f"/announcements/{aid}", headers={**h, "Accept-Language": "ru"}
    ).json()
    assert g["baslik"] == "Su kesintisi"
    assert g["ceviri_durumu"] == "hata"


def test_ceviri_satiri_YOKKEN_bekliyor_raporlanir(client, world, owner_conn):
    h = _headers(client, world["slug_a"], world["resident_a"])
    aid = _db_duyuru(owner_conn, world["a"], "Su kesintisi", "Yarin 10:00.")

    g = client.get(
        f"/announcements/{aid}", headers={**h, "Accept-Language": "de"}
    ).json()
    assert g["baslik"] == "Su kesintisi" and g["ceviri_durumu"] == "bekliyor"


def test_dil_parametresi_accept_language_i_EZER(client, world, owner_conn):
    h = _headers(client, world["slug_a"], world["resident_a"])
    aid = _db_duyuru(owner_conn, world["a"], "Su kesintisi", "Yarin 10:00.")
    _db_ceviri(owner_conn, world["a"], aid, "de", {"baslik": "DE", "govde": "DE"})

    g = client.get(
        f"/announcements/{aid}",
        headers={**h, "Accept-Language": "ru"},
        params={"dil": "de"},
    ).json()
    assert g["gosterilen_dil"] == "de" and g["baslik"] == "DE"


def test_dil_orijinal_kaynak_metni_zorlar(client, world, owner_conn):
    h = _headers(client, world["slug_a"], world["resident_a"])
    aid = _db_duyuru(owner_conn, world["a"], "Su kesintisi", "Yarin 10:00.")
    _db_ceviri(owner_conn, world["a"], aid, "ru", {"baslik": "RU", "govde": "RU"})

    g = client.get(
        f"/announcements/{aid}",
        headers={**h, "Accept-Language": "ru"},
        params={"dil": "orijinal"},
    ).json()
    assert g["baslik"] == "Su kesintisi" and g["gosterilen_dil"] == "tr"


def test_elle_duzeltilmis_ceviri_makine_bayragi_TASIMAZ(client, world, owner_conn):
    h = _headers(client, world["slug_a"], world["resident_a"])
    aid = _db_duyuru(owner_conn, world["a"], "Su kesintisi", "Yarin 10:00.")
    _db_ceviri(
        owner_conn, world["a"], aid, "ru",
        {"baslik": "Отключение воды", "govde": "Завтра."}, elle_duzeltildi=True,
    )

    g = client.get(
        f"/announcements/{aid}", headers={**h, "Accept-Language": "ru"}
    ).json()
    assert g["baslik"] == "Отключение воды"
    assert g["ceviri_durumu"] == "hazir"
    assert g["cevirildi_mi"] is False        # insan duzeltmesi


def test_LISTE_ucu_de_yerelestirir(client, world, owner_conn):
    h = _headers(client, world["slug_a"], world["resident_a"])
    aid = _db_duyuru(
        owner_conn, world["a"], f"Liste testi {uuid.uuid4().hex[:6]}", "Govde."
    )
    _db_ceviri(
        owner_conn, world["a"], aid, "ru", {"baslik": "Список", "govde": "Тело."}
    )

    liste = client.get(
        "/announcements", headers={**h, "Accept-Language": "ru"},
        params={"limit": 200},
    ).json()
    kayit = next(it for it in liste["items"] if it["id"] == str(aid))
    assert kayit["baslik"] == "Список"
    assert kayit["gosterilen_dil"] == "ru"
    assert kayit["orijinal"]["govde"] == "Govde."


def test_TENANT_IZOLASYONU_baska_tenant_cevirisi_gorunmez(
    client, world, owner_conn
):
    """B tenant'inin kullanicisi A'nin duyurusunu/cevirisini GORMEZ."""
    aid = _db_duyuru(owner_conn, world["a"], "A duyurusu", "A govde.")
    _db_ceviri(owner_conn, world["a"], aid, "ru", {"baslik": "A-RU", "govde": "A-RU"})

    hb = _headers(client, world["slug_b"], world["yonetici_b"])
    r = client.get(
        f"/announcements/{aid}", headers={**hb, "Accept-Language": "ru"}
    )
    assert r.status_code == 404


# --------------------- site kurallari + etkinlikler -------------------------- #
def test_site_kurali_accept_language(client, world, owner_conn):
    h = _headers(client, world["slug_a"], world["resident_a"])
    uid = owner_conn.execute(
        "SELECT id FROM app_user WHERE tenant_id=%s ORDER BY email LIMIT 1",
        (world["a"],),
    ).fetchone()[0]
    rid = owner_conn.execute(
        "INSERT INTO site_kurali (tenant_id, baslik, icerik, olusturan_user_id) "
        "VALUES (%s,'Havuz Saatleri','08:00-22:00 arasi acik.',%s) RETURNING id",
        (world["a"], uid),
    ).fetchone()[0]
    owner_conn.execute(
        "INSERT INTO site_kurali_ceviri (tenant_id, site_kurali_id, dil, alanlar, "
        "durum, kaynak_hash) VALUES (%s,%s,'ru',%s::jsonb,'hazir','h')",
        (world["a"], rid,
         json.dumps({"baslik": "Часы бассейна", "icerik": "Открыто 08:00-22:00."})),
    )

    g = client.get(
        f"/site-rules/{rid}", headers={**h, "Accept-Language": "ru"}
    ).json()
    assert g["baslik"] == "Часы бассейна"
    assert g["icerik"] == "Открыто 08:00-22:00."
    assert g["gosterilen_dil"] == "ru" and g["cevirildi_mi"] is True
    assert g["orijinal"]["baslik"] == "Havuz Saatleri"


def test_etkinlik_accept_language_konum_CEVRILMEZ(client, world, owner_conn):
    """konum bir YER ADIDIR — ceviriye girmez (bilincli karar)."""
    h = _headers(client, world["slug_a"], world["resident_a"])
    uid = owner_conn.execute(
        "SELECT id FROM app_user WHERE tenant_id=%s ORDER BY email LIMIT 1",
        (world["a"],),
    ).fetchone()[0]
    eid = owner_conn.execute(
        "INSERT INTO etkinlik (tenant_id, baslik, aciklama, tarih, konum, "
        "olusturan_user_id) VALUES (%s,'Bahar senligi','Bahcede muzik.',"
        "now() + interval '3 days','Site bahçesi',%s) RETURNING id",
        (world["a"], uid),
    ).fetchone()[0]
    owner_conn.execute(
        "INSERT INTO etkinlik_ceviri (tenant_id, etkinlik_id, dil, alanlar, "
        "durum, kaynak_hash) VALUES (%s,%s,'de',%s::jsonb,'hazir','h')",
        (world["a"], eid,
         json.dumps({"baslik": "Frühlingsfest", "aciklama": "Musik im Garten."})),
    )

    g = client.get(f"/events/{eid}", headers={**h, "Accept-Language": "de"}).json()
    assert g["baslik"] == "Frühlingsfest"
    assert g["aciklama"] == "Musik im Garten."
    assert g["konum"] == "Site bahçesi"      # CEVRILMEDI
    assert g["gosterilen_dil"] == "de"


def test_etkinlik_olusturmada_ceviri_isi_acilir(client, world, owner_conn):
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post(
        "/events",
        headers=h,
        json={
            "baslik": f"Etkinlik {uuid.uuid4().hex[:6]}",
            "aciklama": "Aciklama metni.",
            "tarih": "2030-01-01T10:00:00Z",
        },
    )
    assert r.status_code == 201, r.text
    eid = r.json()["id"]
    diller = {
        row[0]
        for row in owner_conn.execute(
            "SELECT dil FROM etkinlik_ceviri WHERE etkinlik_id = %s", (eid,)
        ).fetchall()
    }
    assert diller == set(ceviri.hedef_diller("tr"))
    client.delete(f"/events/{eid}", headers=h)


def test_site_kurali_olusturmada_ceviri_isi_acilir(client, world, owner_conn):
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post(
        "/site-rules",
        headers=h,
        json={"baslik": f"Kural {uuid.uuid4().hex[:6]}", "icerik": "Kural metni."},
    )
    assert r.status_code == 201, r.text
    rid = r.json()["id"]
    diller = {
        row[0]
        for row in owner_conn.execute(
            "SELECT dil FROM site_kurali_ceviri WHERE site_kurali_id = %s", (rid,)
        ).fetchall()
    }
    assert diller == set(ceviri.hedef_diller("tr"))
    client.delete(f"/site-rules/{rid}", headers=h)


@pytest.mark.parametrize("dil", list(ceviri.DESTEKLENEN_DILLER))
def test_YEDI_dilin_HEPSI_kabul_edilir(client, world, owner_conn, dil):
    """7 dilin tamami Accept-Language olarak calisir (hicbiri 4xx uretmez)."""
    h = _headers(client, world["slug_a"], world["resident_a"])
    aid = _db_duyuru(owner_conn, world["a"], "Su kesintisi", "Yarin 10:00.")
    if dil != "tr":
        _db_ceviri(
            owner_conn, world["a"], aid, dil,
            {"baslik": f"{dil}-baslik", "govde": f"{dil}-govde"},
        )

    g = client.get(
        f"/announcements/{aid}", headers={**h, "Accept-Language": dil}
    ).json()
    assert g["gosterilen_dil"] == dil
    assert g["baslik"] == ("Su kesintisi" if dil == "tr" else f"{dil}-baslik")
