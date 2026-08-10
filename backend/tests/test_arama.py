"""(P154 / Asama 6.3) GLOBAL ARAMA — asil olculen sey SIZINTI YOKLUGU.

Brief: "Tenant izolasyonu ve rol yetkisi arama sonuclarinda da gecerli —
kullanici goremeyecegi bir kaydi arama sonucunda GORMEMELI."

Arama uclarinin klasik kusuru sudur: liste uclari rol kapili yazilir,
sonra arama "hepsini tarayan" tek sorgu olarak eklenir ve sessizce
herkesi her seye ulastirir. Fazladan bir satir gostermek HICBIR HATA
URETMEZ — yalnizca gormemesi gereken birine gosterir. O yuzden bu
dosyanin cogunlugu "gormemeli" testidir.
"""
from __future__ import annotations

import uuid


def _giris(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _telefonla(client, telefon, parola):
    r = client.post("/auth/login-phone", json={"phone": telefon, "password": parola})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _ara(client, basliklar, q):
    r = client.get(f"/arama?q={q}", headers=basliklar)
    assert r.status_code == 200, r.text
    return r.json()["items"]


def _kaynaklar(vuruslar):
    return {v["kaynak"] for v in vuruslar}


# =================== 1) ROL KUMELERI ROUTERLARLA AYNI ====================== #

def test_rol_kumeleri_ROUTERLARLA_AYNI():
    """Arama kendi yetki listesini TUTMAZ, routerdan OKUR.

    Iki liste tutulsaydi biri guncellenir oteki eskirdi ve ayrisma
    SESSIZ olurdu — kimse "arama fazla gosteriyor" diye hata almaz.
    """
    from app.routers.arama import KAYNAKLAR
    from app.routers.announcements import _READER as duyuru
    from app.routers.blocks import _READER as blok
    from app.routers.complaints import _READER as talep
    from app.routers.finans import _OKUMA as finans
    from app.routers.muhasebe_tanimlari import _TANIM_OKUR as firma
    from app.routers.tasks import _READER as gorev
    from app.routers.units import _LAYOUT_READER as daire
    from app.routers.users import _READER as kisi

    beklenen = {
        "kisi": kisi, "daire": daire, "blok": blok, "firma": firma,
        "gorev": gorev, "duyuru": duyuru, "talep": talep, "finans": finans,
    }
    assert {k.ad for k in KAYNAKLAR} == set(beklenen)
    for k in KAYNAKLAR:
        assert k.roller == frozenset(
            beklenen[k.ad].izinli_roller  # type: ignore[attr-defined]
        ), k.ad


# ======================= 2) TENANT IZOLASYONU ============================== #

def test_BASKA_TESISIN_kaydi_GORUNMEZ(client, world, owner_conn):
    """RLS'in isi ama arama onu ATLAYAN bir yol acmamali."""
    isaret = f"ZZ{uuid.uuid4().hex[:8]}"
    with owner_conn.cursor() as cur:
        # B tesisine, A'dakiyle ayni desende bir blok.
        cur.execute(
            "INSERT INTO building_block (tenant_id, ad) "
            "SELECT id, %s FROM tenant WHERE slug = %s",
            (isaret, world["slug_b"]),
        )

    a = _giris(client, world["slug_a"], world["yonetici_a"])
    assert _ara(client, a, isaret) == [], "baska tesisin blogu goruldu"

    b = _giris(client, world["slug_b"], world["yonetici_b"])
    assert any(v["baslik"] == isaret for v in _ara(client, b, isaret))


# ========================= 3) ROL SIZINTISI ================================ #

def test_SAKIN_kisi_ve_finans_GOREMEZ(client, world, owner_conn):
    """Sakin `kisi` ve `finans` kaynaklarini HIC gormemeli.

    Iki kaynak da yonetim bilgisi: `kisi` tesisin telefon defteri,
    `finans` kasa hareketi. Sakinin liste uclarinda ikisi de kapali.
    """
    isaret = f"AR{uuid.uuid4().hex[:8]}"
    with owner_conn.cursor() as cur:
        cur.execute("SELECT id FROM tenant WHERE slug = %s", (world["slug_a"],))
        tid = cur.fetchone()[0]
        # Aranan desene UYAN bir kisi ve bir finansal hareket.
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, password_hash, password_set, "
            "role, is_active) VALUES (%s,%s,%s,NULL,false,'yonetici'::user_role,true)",
            (tid, f"{isaret} Kisi", f"{isaret}@t.local"),
        )
        cur.execute(
            "INSERT INTO finansal_hareket (tenant_id, tip, yon, tutar_kurus, aciklama) "
            "VALUES (%s,'gelir'::hareket_tip,'giris'::hareket_yon,100,%s)",
            (tid, f"{isaret} tahsilat"),
        )
        # Duyuru: sakinin GORMESI gereken kaynak — testin bosa gecmedigini
        # kanitlar (sifir sonuc her iddiayi dogrular).
        cur.execute(
            "INSERT INTO announcement (tenant_id, baslik, govde, olusturan_user_id) "
            "SELECT %s, %s, 'govde', id FROM app_user "
            " WHERE tenant_id = %s AND role = 'yonetici' LIMIT 1",
            (tid, f"{isaret} duyuru", tid),
        )

    sakin = _giris(client, world["slug_a"], world["resident_a"])
    vuruslar = _ara(client, sakin, isaret)
    gorunen = _kaynaklar(vuruslar)

    assert "duyuru" in gorunen, "sakin duyuruyu goremiyor — test BOSA GECIYOR"
    assert "kisi" not in gorunen, "sakin KISI kaynagini gordu"
    assert "finans" not in gorunen, "sakin FINANS kaynagini gordu"


def test_GUVENLIK_finans_ve_kisi_GOREMEZ(client, world, owner_conn):
    isaret = f"GV{uuid.uuid4().hex[:8]}"
    with owner_conn.cursor() as cur:
        cur.execute("SELECT id FROM tenant WHERE slug = %s", (world["slug_a"],))
        tid = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO finansal_hareket (tenant_id, tip, yon, tutar_kurus, aciklama) "
            "VALUES (%s,'gider'::hareket_tip,'cikis'::hareket_yon,100,%s)",
            (tid, f"{isaret} gider"),
        )
        cur.execute(
            "INSERT INTO building_block (tenant_id, ad) VALUES (%s,%s)",
            (tid, f"{isaret}"),
        )

    guvenlik = _giris(client, world["slug_a"], world["guard_a"])
    gorunen = _kaynaklar(_ara(client, guvenlik, isaret))
    assert "blok" in gorunen, "guvenlik blogu goremiyor — test BOSA GECIYOR"
    assert "finans" not in gorunen, "guvenlik FINANS gordu"
    assert "kisi" not in gorunen, "guvenlik KISI gordu"


def test_SAKIN_BASKASININ_talebini_goremez(client, world, owner_conn):
    """Rol kumesi YETMEZ: sakin talepleri "gorebilir" ama YALNIZ kendini.

    Bu, `complaints._own_scope` kuralinin arama tarafindaki karsiligi.
    Tekrar edilmeseydi sakin, komsusunun talebini arama kutusundan
    okurdu — ve hicbir yerde hata cikmazdi.
    """
    isaret = f"TL{uuid.uuid4().hex[:8]}"
    with owner_conn.cursor() as cur:
        cur.execute("SELECT id FROM tenant WHERE slug = %s", (world["slug_a"],))
        tid = cur.fetchone()[0]
        # BASKA birinin (yonetici) actigi talep.
        cur.execute(
            "INSERT INTO complaint (tenant_id, acan_user_id, baslik, mesaj) "
            "SELECT %s, id, %s, 'mesaj' FROM app_user "
            " WHERE tenant_id = %s AND role = 'yonetici' LIMIT 1",
            (tid, f"{isaret} baskasinin talebi", tid),
        )
        # SAKININ KENDI talebi — gormesi gereken.
        cur.execute(
            "INSERT INTO complaint (tenant_id, acan_user_id, baslik, mesaj) "
            "SELECT %s, id, %s, 'mesaj' FROM app_user "
            " WHERE tenant_id = %s AND role = 'resident' LIMIT 1",
            (tid, f"{isaret} kendi talebim", tid),
        )

    sakin = _giris(client, world["slug_a"], world["resident_a"])
    basliklar = [v["baslik"] for v in _ara(client, sakin, isaret)]
    assert f"{isaret} kendi talebim" in basliklar, "kendi talebini goremiyor"
    assert f"{isaret} baskasinin talebi" not in basliklar, "BASKASININ talebini gordu"

    # Yonetim ikisini de gorur — kapsam kurali role bagli, keyfi degil.
    yon = _giris(client, world["slug_a"], world["yonetici_a"])
    yonetim_basliklari = [v["baslik"] for v in _ara(client, yon, isaret)]
    assert f"{isaret} baskasinin talebi" in yonetim_basliklari


# ============================ 4) SOZLESME ================================== #

def test_TEK_HARF_reddedilir(client, world):
    """Tek harf butun tesisi tarar ve kullaniciya bir sey anlatmaz."""
    yon = _giris(client, world["slug_a"], world["yonetici_a"])
    assert client.get("/arama?q=a", headers=yon).status_code == 422


def test_OTURUMSUZ_erisilemez(client):
    assert client.get("/arama?q=deneme").status_code == 401


def test_kaynak_basina_SINIR_var(client, world, owner_conn):
    """Sinirsiz birakmak tek istekte butun tesisi cekmek olurdu."""
    from app.routers.arama import _KAYNAK_SINIRI

    isaret = f"SN{uuid.uuid4().hex[:6]}"
    with owner_conn.cursor() as cur:
        cur.execute("SELECT id FROM tenant WHERE slug = %s", (world["slug_a"],))
        tid = cur.fetchone()[0]
        for i in range(_KAYNAK_SINIRI + 3):
            cur.execute(
                "INSERT INTO building_block (tenant_id, ad) VALUES (%s,%s)",
                (tid, f"{isaret}-{i}"),
            )

    yon = _giris(client, world["slug_a"], world["yonetici_a"])
    bloklar = [v for v in _ara(client, yon, isaret) if v["kaynak"] == "blok"]
    assert len(bloklar) == _KAYNAK_SINIRI
