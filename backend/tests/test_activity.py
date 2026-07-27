"""GET /activity — birlesik akis (G5): rol suzgeci + imlec sayfalamasi + RLS.

Bu uc istemci tarafi birlestirmeyi (rol basina 3-4 istek) tek, SUNUCUDA
siralanmis ve SUNUCUDA suzulmus akisla degistirir. Testler kritik ozelligi
dogrular: bir rolun GORMEMESI gereken olay akista ASLA gorunmez — istemci
hangi ucu cagirdigina bakilmaksizin.
"""
from __future__ import annotations

import uuid

import pytest


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _feed(client, headers, limit=100, cursor=None):
    url = f"/activity?limit={limit}" + (f"&cursor={cursor}" if cursor else "")
    r = client.get(url, headers=headers)
    assert r.status_code == 200, r.text
    return r.json()


def _turler(client, headers) -> set[str]:
    return {i["tur"] for i in _feed(client, headers)["items"]}


def _mk_resident(owner_conn, tenant_id, email, pw):
    from app.security import hash_password

    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, password_hash, password_set, "
            "role) VALUES (%s,%s,%s,%s,true,'resident'::user_role) RETURNING id",
            (tenant_id, f"Sakin {email.split('@')[0]}", email, hash_password(pw)),
        )
        return cur.fetchone()[0]


@pytest.fixture
def aworld(client, world, owner_conn):
    """A tenant'inda her kaynaktan en az bir olay uretir.

    Olaylar DOGRUDAN owner baglantisiyla yazilir (RLS bypass): amac akisin
    SUZME/SIRALAMA davranisini olcmek, uretim uclarini yeniden test etmek
    degil. Daire ve sakin baglantilari gercek (resident kapsami olculebilsin).
    """
    a, b = world["a"], world["b"]
    sfx = uuid.uuid4().hex[:6]
    pw = "ActivityPass1!"

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND role='resident'", (a,)
        )
        resident_id = cur.fetchone()[0]
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND role='security'", (a,)
        )
        guard_id = cur.fetchone()[0]
        cur.execute("SELECT id FROM app_user WHERE tenant_id=%s AND role='admin'", (a,))
        admin_id = cur.fetchone()[0]

        # Daireler: unit_mine sakinimizin (aktif), unit_other baskasinin.
        cur.execute(
            "INSERT INTO unit (tenant_id, no) VALUES (%s,%s),(%s,%s) RETURNING id",
            (a, f"ACT-1-{sfx}", a, f"ACT-2-{sfx}"),
        )
        unit_mine = cur.fetchone()[0]
        cur.execute(
            "SELECT id FROM unit WHERE tenant_id=%s AND no=%s", (a, f"ACT-2-{sfx}")
        )
        unit_other = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO unit_resident (tenant_id, unit_id, user_id) VALUES (%s,%s,%s)",
            (a, unit_mine, resident_id),
        )
        other_resident = _mk_resident(owner_conn, a, f"act-other-{sfx}@acme.com", pw)
        cur.execute(
            "INSERT INTO unit_resident (tenant_id, unit_id, user_id) VALUES (%s,%s,%s)",
            (a, unit_other, other_resident),
        )

        # aidat_odeme — sakinin dairesi + BASKA daire (kapsam testi).
        for unit, key in ((unit_mine, f"mine-{sfx}"), (unit_other, f"other-{sfx}")):
            cur.execute(
                "INSERT INTO dues_payment (tenant_id, unit_id, tutar_kurus, yontem, "
                "durum, kaydeden_user_id, idempotency_key) "
                "VALUES (%s,%s,75000,'havale','basarili',%s,%s)",
                (a, unit, admin_id, key),
            )
        # talep — sakinin ACTIGI + baskasinin (admin'in) actigi.
        cur.execute(
            "INSERT INTO complaint (tenant_id, acan_user_id, baslik, mesaj) "
            "VALUES (%s,%s,%s,'m'),(%s,%s,%s,'m')",
            (a, resident_id, f"Talebim {sfx}", a, admin_id, f"Baskasinin talebi {sfx}"),
        )
        # daire_sikayeti — sakinin actigi + baskasinin actigi.
        cur.execute(
            "INSERT INTO unit_complaint (tenant_id, target_unit_id, "
            "complainant_user_id, kategori) VALUES (%s,%s,%s,'gurultu'),(%s,%s,%s,'diger')",
            (a, unit_other, resident_id, a, unit_mine, other_resident),
        )
        # ziyaretci — sakine HEDEFLI (biri cikisli) + baskasina hedefli.
        cur.execute(
            "INSERT INTO visitor (tenant_id, unit_id, ziyaretci_ad, kaydeden_user_id, "
            "target_resident_user_id, cikis_zamani) "
            "VALUES (%s,%s,%s,%s,%s,now()),(%s,%s,%s,%s,%s,NULL)",
            (a, unit_mine, f"Z1-{sfx}", guard_id, resident_id,
             a, unit_other, f"Z2-{sfx}", guard_id, other_resident),
        )
        # kargo — sakinin dairesi (teslim edilmis) + baska daire.
        cur.execute(
            "INSERT INTO kargo (tenant_id, unit_id, firma, kaydeden_user_id, durum, "
            "teslim_alan_user_id, teslim_zamani) "
            "VALUES (%s,%s,%s,%s,'teslim_alindi',%s,now()),(%s,%s,%s,%s,'bekliyor',NULL,NULL)",
            (a, unit_mine, f"K1-{sfx}", guard_id, resident_id,
             a, unit_other, f"K2-{sfx}", guard_id),
        )
        # arac gecisi — biri acik biri kapali.
        cur.execute(
            "INSERT INTO vehicle_pass (tenant_id, plaka, kaydeden_user_id, cikis_zamani) "
            "VALUES (%s,%s,%s,now()),(%s,%s,%s,NULL)",
            (a, f"ACT{sfx.upper()}", guard_id, a, f"ACTB{sfx.upper()}", guard_id),
        )
        # ihlal
        cur.execute(
            "INSERT INTO violation (tenant_id, baslik, olusturan_user_id) VALUES (%s,%s,%s)",
            (a, f"Ihlal {sfx}", guard_id),
        )
        # alarm (notification) — dedup_key benzersiz.
        cur.execute(
            "INSERT INTO notification (tenant_id, tip, mesaj, dedup_key) "
            "VALUES (%s,'kacirilan_tur',%s,%s)",
            (a, f"Tur kacirildi {sfx}", f"act-{sfx}"),
        )
        # B tenant'ta AYIRT EDICI bir ihlal: A'nin akisina sizmamali.
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND role='admin'", (b,)
        )
        admin_b = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO violation (tenant_id, baslik, olusturan_user_id) VALUES (%s,%s,%s)",
            (b, f"B-IHLAL-{sfx}", admin_b),
        )

    return {**world, "sfx": sfx, "other": {"email": f"act-other-{sfx}@acme.com",
                                           "password": pw}}


# ----------------------------- rol suzgeci --------------------------------- #
def test_admin_operasyonel_ve_finansi_gorur(client, aworld):
    turler = _turler(client, _headers(client, aworld["slug_a"], aworld["admin_a"]))
    assert {"aidat_odeme", "talep", "daire_sikayeti", "alarm", "ihlal",
            "arac_giris", "arac_cikis"} <= turler


def test_admin_ziyaretci_kargo_GORMEZ(client, aworld):
    """KVKK: /visitors ve /kargo yonetime VARSAYILAN KAPALI (tek-seferlik
    izinle acilir). Birlesik akis bu kapiyi bypass eden yan kanal OLMAMALI."""
    turler = _turler(client, _headers(client, aworld["slug_a"], aworld["admin_a"]))
    assert not (turler & {"ziyaretci_giris", "ziyaretci_cikis", "kargo", "kargo_teslim"})


def test_yonetici_arac_gecisi_GORMEZ(client, aworld):
    """Plaka okuma RBAC'i admin+security; akis uc RBAC'i ile tutarli kalir."""
    turler = _turler(client, _headers(client, aworld["slug_a"], aworld["yonetici_a"]))
    assert not (turler & {"arac_giris", "arac_cikis"})
    assert {"aidat_odeme", "ihlal"} <= turler


def test_security_finans_GORMEZ(client, aworld):
    h = _headers(client, aworld["slug_a"], aworld["guard_a"])
    turler = _turler(client, h)
    assert "aidat_odeme" not in turler
    assert "daire_sikayeti" not in turler
    assert {"ziyaretci_giris", "ziyaretci_cikis", "kargo", "kargo_teslim",
            "arac_giris", "ihlal", "alarm"} <= turler


def test_security_yalniz_kendi_taleplerini_gorur(client, aworld):
    """/complaints _own_scope kurali akista da gecerli."""
    h = _headers(client, aworld["slug_a"], aworld["guard_a"])
    metinler = {i["alt_metin"] for i in _feed(client, h)["items"]}
    assert f"Baskasinin talebi {aworld['sfx']}" not in metinler


def test_tesis_gorevlisi_yalniz_gorev_tamamlama(client, aworld):
    """KVKK kisiti: saha gorevlisi baska hicbir olay turunu GORMEZ."""
    h = _headers(client, aworld["slug_a"], aworld["gorevli_a"])
    assert _turler(client, h) <= {"gorev_tamamlama"}


def test_resident_yalniz_kendi_olaylari(client, aworld):
    h = _headers(client, aworld["slug_a"], aworld["resident_a"])
    items = _feed(client, h)["items"]
    turler = {i["tur"] for i in items}
    metinler = {i["alt_metin"] for i in items}
    sfx = aworld["sfx"]

    # Operasyonel/yonetim olaylari sakine KAPALI.
    assert not (turler & {"devriye_okutma", "alarm", "ihlal", "arac_giris",
                          "arac_cikis", "gorev_tamamlama"})
    # Kendi dairesi/kendisi ICERIDE.
    assert f"Z1-{sfx} — Daire ACT-1-{sfx}" in metinler       # kendine hedefli
    assert f"K1-{sfx} — Daire ACT-1-{sfx}" in metinler       # kendi dairesi
    assert f"Talebim {sfx}" in metinler                       # kendi talebi
    # Baskasinin olaylari DISARIDA.
    assert f"Z2-{sfx} — Daire ACT-2-{sfx}" not in metinler
    assert f"K2-{sfx} — Daire ACT-2-{sfx}" not in metinler
    assert f"Baskasinin talebi {sfx}" not in metinler
    # Aidat: yalniz KENDI dairesinin odemesi (tutar ayni, daire farkli).
    assert f"Daire ACT-2-{sfx} — ₺750.00" not in metinler
    assert f"Daire ACT-1-{sfx} — ₺750.00" in metinler


def test_resident_kendi_dairesine_gelen_sikayeti_gormez(client, aworld):
    """Anonimlik: sakin KENDI actigi sikayetleri gorur, dairesine GELENI
    gormez (yogunluk sizmasi olurdu)."""
    h = _headers(client, aworld["slug_a"], aworld["resident_a"])
    metinler = {i["alt_metin"] for i in _feed(client, h)["items"]}
    sfx = aworld["sfx"]
    assert f"Daire ACT-2-{sfx} — gurultu" in metinler       # kendi actigi
    assert f"Daire ACT-1-{sfx} — diger" not in metinler     # dairesine gelen


# ------------------------- KIMLIK sozlesmesi (tur 15) ----------------------- #
# Akis satirlari artik SUNUCUDA metin URETMEZ: `baslik_kimlik` + `veri` gider,
# cumleyi istemci kendi dilinde kurar. `baslik`/`alt_metin` DEPRECATED olarak
# ayni degerleri uretmeye devam eder (guncellenmemis istemciler icin).
def test_kimlik_ve_veri_gonderilir(client, aworld):
    h = _headers(client, aworld["slug_a"], aworld["admin_a"])
    items = _feed(client, h)["items"]
    assert items

    for i in items:
        # Kimlik HER satirda var ve makine-okunabilir (kucuk harf + alt cizgi).
        assert i["baslik_kimlik"], i
        assert i["baslik_kimlik"] == i["baslik_kimlik"].lower()
        assert " " not in i["baslik_kimlik"]
        assert isinstance(i["veri"], dict)

    kimlikler = {i["baslik_kimlik"] for i in items}
    # Bir TUR birden cok kimlik verebilir: talep durumu kimlige girer.
    assert kimlikler & {
        "talep_acik", "talep_is_emri", "talep_cozuldu", "talep_reddedildi"
    }
    assert "alarm" not in kimlikler  # alarm tipi de kimlige girer
    assert kimlikler & {
        "alarm_kacirilan_tur", "alarm_eksik_checkpoint", "alarm_gecikmis_okutma"
    }


def test_veri_yapisaldir_metin_degil(client, aworld):
    """Degisken alanlar AYRI AYRI gider: istemci cumleyi kendisi kurar."""
    h = _headers(client, aworld["slug_a"], aworld["admin_a"])
    items = _feed(client, h)["items"]
    sfx = aworld["sfx"]

    aidat = next(i for i in items if i["tur"] == "aidat_odeme")
    # PARA: kurus TAM SAYI — sunucu "₺750.00" bicimlemez (bicim dile baglidir).
    assert aidat["veri"]["tutar_kurus"] == 75000
    assert aidat["veri"]["daire"].startswith("ACT-")

    sikayet = next(i for i in items if i["tur"] == "daire_sikayeti")
    # KATEGORI: sozlesme kimligi (gorunen ad DEGIL) — istemci cevirir.
    assert sikayet["veri"]["kategori"] in {
        "gurultu", "kapi_onu_ayakkabi", "zarar_verme", "diger"
    }

    ihlal = next(i for i in items if i["tur"] == "ihlal")
    assert ihlal["veri"]["baslik"] == f"Ihlal {sfx}"


def test_opsiyonel_alan_YOKSA_gonderilmez(client, aworld):
    """`jsonb_strip_nulls`: bos alan null olarak degil, HIC gonderilmez —
    istemci bicimi alanin VARLIGINA gore secer (SQL COALESCE'unun yerine)."""
    h = _headers(client, aworld["slug_a"], aworld["admin_a"])
    items = _feed(client, h)["items"]
    for i in items:
        assert None not in i["veri"].values(), i


def test_eski_alanlar_ayni_metni_uretmeye_devam_eder(client, aworld):
    """DEPRECATED `baslik`/`alt_metin`: eski istemci REGRESYON gormez."""
    h = _headers(client, aworld["slug_a"], aworld["admin_a"])
    items = _feed(client, h)["items"]
    aidat = next(i for i in items if i["tur"] == "aidat_odeme")
    assert aidat["baslik"] == "Aidat Ödemesi"
    assert aidat["alt_metin"] == f"Daire {aidat['veri']['daire']} — ₺750.00"


# --------------------------- siralama / imlec ------------------------------- #
def test_yeniden_eskiye_siralanir(client, aworld):
    h = _headers(client, aworld["slug_a"], aworld["admin_a"])
    zamanlar = [i["zaman"] for i in _feed(client, h)["items"]]
    assert zamanlar == sorted(zamanlar, reverse=True)


def test_id_kaynaklar_arasi_benzersiz(client, aworld):
    h = _headers(client, aworld["slug_a"], aworld["admin_a"])
    ids = [i["id"] for i in _feed(client, h)["items"]]
    assert len(ids) == len(set(ids))
    # "<tur>:<uuid>" — kaynak_id ham kayit id'sidir.
    for item in _feed(client, h)["items"]:
        assert item["id"] == f"{item['tur']}:{item['kaynak_id']}"


def test_imlec_sayfalamasi_tekrarsiz_ve_eksiksiz(client, aworld):
    """Kucuk sayfalarla tam akisi gez: tekrar YOK, kayip YOK, sira korunur."""
    h = _headers(client, aworld["slug_a"], aworld["admin_a"])
    tam = [i["id"] for i in _feed(client, h, limit=100)["items"]]
    assert len(tam) > 3

    toplanan: list[str] = []
    cursor = None
    for _ in range(50):  # sonsuz dongu emniyeti
        sayfa = _feed(client, h, limit=2, cursor=cursor)
        toplanan += [i["id"] for i in sayfa["items"]]
        cursor = sayfa["meta"]["next_cursor"]
        if cursor is None:
            break
    assert cursor is None                      # akis gercekten bitti
    assert toplanan == tam[:len(toplanan)]     # ayni sira
    assert len(toplanan) == len(set(toplanan))  # tekrar yok
    assert set(tam[:len(toplanan)]) == set(toplanan)


def test_imlec_araya_yeni_kayit_girse_de_kaymaz(client, aworld, owner_conn):
    """offset olsaydi araya giren kayit sayfayi kaydirir ve bir olay
    TEKRARLARDI; bilesik imlecte sayfa-2 degismez."""
    h = _headers(client, aworld["slug_a"], aworld["admin_a"])
    sayfa1 = _feed(client, h, limit=2)
    beklenen = _feed(client, h, limit=2, cursor=sayfa1["meta"]["next_cursor"])

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND role='security'",
            (aworld["a"],),
        )
        guard_id = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO violation (tenant_id, baslik, olusturan_user_id) "
            "VALUES (%s,%s,%s)",
            (aworld["a"], f"Araya giren {uuid.uuid4().hex[:6]}", guard_id),
        )

    sonra = _feed(client, h, limit=2, cursor=sayfa1["meta"]["next_cursor"])
    assert [i["id"] for i in sonra["items"]] == [i["id"] for i in beklenen["items"]]


def test_son_sayfada_next_cursor_null(client, aworld):
    h = _headers(client, aworld["slug_a"], aworld["gorevli_a"])
    # tesis_gorevlisi akisi kucuktur; tek sayfada biter.
    assert _feed(client, h, limit=100)["meta"]["next_cursor"] is None


def test_gecersiz_cursor_422(client, aworld):
    h = _headers(client, aworld["slug_a"], aworld["admin_a"])
    r = client.get("/activity?cursor=bu-gecerli-degil", headers=h)
    assert r.status_code == 422, r.text


def test_meta_total_yok(client, aworld):
    h = _headers(client, aworld["slug_a"], aworld["admin_a"])
    assert "total" not in _feed(client, h)["meta"]


# ------------------------------ izolasyon ---------------------------------- #
def test_tenant_izolasyonu(client, aworld):
    """B tenant'in ihlali A'nin akisinda GORUNMEZ (RLS)."""
    ha = _headers(client, aworld["slug_a"], aworld["admin_a"])
    metinler = {i["alt_metin"] for i in _feed(client, ha)["items"]}
    assert f"B-IHLAL-{aworld['sfx']}" not in metinler

    hb = _headers(client, aworld["slug_b"], aworld["admin_b"])
    b_metinler = {i["alt_metin"] for i in _feed(client, hb)["items"]}
    assert f"B-IHLAL-{aworld['sfx']}" in b_metinler
    assert f"Ihlal {aworld['sfx']}" not in b_metinler


def test_anonim_401(client):
    assert client.get("/activity").status_code == 401
