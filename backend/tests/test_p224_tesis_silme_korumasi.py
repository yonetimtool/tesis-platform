"""(P224) TESIS SILME KORUMASI — bugunku prod kazasinin kilidi.

===========================================================================
OLCULEN KAZA
===========================================================================
Prod'da "Yönetio Platform" tesisi silindi. Platform admin hesabi o tesise
bagliydi ve ON DELETE CASCADE ile gitti:

    SELECT ... FROM app_user WHERE role='admin'  ->  0 satir

Panele girilemez hale gelindi. Sistem HICBIR NOKTADA DIRENMEDI:
  * son admin korumasi yoktu,
  * adminin tesisini silme engeli yoktu,
  * onizleme yoktu (icinde ne oldugu gosterilmiyordu),
  * onay kelimesi HER TESISTE AYNI idi ("SİL") — yani yanlis tesisi
    silmeye karsi hicbir sey yapmiyordu, sadece kas hafizasi uretiyordu.

===========================================================================
KORUMA GENIS DEGIL, DAR OLMALI
===========================================================================
Bu dosyanin yarisi "engellendi mi" diye bakar, yarisi "MESRU SILME HALA
CALISIYOR MU" diye. Ikincisi olmadan koruma, her silmeyi engelleyerek de
"gecebilirdi" ve bunu fark etmek aylar surerdi.
"""
from __future__ import annotations

import uuid

import pytest
from sqlalchemy import create_engine, text


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def admin(client, world):
    return _h(client, world["slug_a"], world["admin_a"])


def _yeni_tesis(client, admin) -> tuple[str, str]:
    ek = uuid.uuid4().hex[:6]
    ad = f"P224 {ek}"
    r = client.post("/tenants", headers=admin, json={
        "ad": ad,
        "yoneticiler": [{
            "ad": "Yonetici Test",
            "phone": "+9053" + str(abs(hash(ek)) % 10**7).rjust(7, "0"),
            "email": f"p224-{ek}@ornek.com",
        }],
    })
    assert r.status_code == 201, r.text
    return r.json()["tenant_id"], ad


# ==================================================================== #
# 1. MESRU SILMELER CALISMAYA DEVAM EDIYOR  (koruma FAZLA GENIS DEGIL)
# ==================================================================== #

def test_ADMIN_OLMAYAN_GECMISSIZ_TESIS_SILINEBILIR(client, admin):
    """Koruma her silmeyi engelleseydi bu test duserdi."""
    tid, ad = _yeni_tesis(client, admin)
    r = client.delete(f"/tenants/{tid}", headers=admin, params={"onay": ad})
    assert r.status_code == 204, r.text


def test_IKI_ADMIN_VARKEN_BIRI_SILINEBILIR(client, world, admin, owner_conn):
    """Koruma "her admin dokunulmaz" degil "platform adminsiz kalmasin".

    Ikinci admin OWNER baglantisiyla acilir: uc katmani yoneticinin kendi
    kumesi disini olusturmasina izin vermez ve bu testin olctugu sey o
    degil, TRIGGER'in dar olup olmadigidir.
    """
    ek = uuid.uuid4().hex[:6]
    eposta = f"p224-ikinci-{ek}@ornek.com"
    owner_conn.execute(
        "INSERT INTO app_user (tenant_id, ad, email, password_hash, "
        "password_set, role, is_active) SELECT tenant_id, 'Ikinci Admin', %s, "
        "password_hash, true, 'admin', true FROM app_user "
        "WHERE role='admin' LIMIT 1", (eposta,))
    # Silme BASARILI olmali: geride hala en az bir admin var.
    owner_conn.execute("DELETE FROM app_user WHERE email = %s", (eposta,))
    kalan = owner_conn.execute(
        "SELECT count(*) FROM app_user WHERE email = %s", (eposta,)).fetchone()[0]
    assert kalan == 0, "iki admin varken biri SILINEMEDI — koruma fazla genis"


# ==================================================================== #
# 2. TRIGGER — UYGULAMA KATMANI ATLANSA BILE
# ==================================================================== #

def test_SON_PLATFORM_ADMINI_PSQL_DEN_BILE_SILINEMEZ(owner_conn):
    """Asil koruma budur: uc atlanabilir, veritabani atlanamaz."""
    import psycopg
    with pytest.raises(psycopg.errors.RestrictViolation) as hata:
        owner_conn.execute("DELETE FROM app_user WHERE role = 'admin'")
    assert "SON PLATFORM ADMINI SILINEMEZ" in str(hata.value)
    owner_conn.rollback()


def test_ADMININ_TESISI_PSQL_DEN_BILE_SILINEMEZ(owner_conn):
    """BUGUNKU KAZANIN TA KENDISI: kimse admini silmedi, TESISI sildi.

    Bu trigger olmasaydi, "son admin silinemez" tek basina ayni kazayi
    tekrar yasatirdi — cascade sirasinda hata gelir ama mesaj "son admin
    silinemez" olurdu ve yonetici NEYI yanlis yaptigini anlamazdi.
    """
    import psycopg
    with pytest.raises(psycopg.errors.RestrictViolation) as hata:
        owner_conn.execute(
            "DELETE FROM tenant WHERE id = "
            "(SELECT tenant_id FROM app_user WHERE role='admin' LIMIT 1)")
    assert "PLATFORM ADMININ BAGLI OLDUGU TESIS SILINEMEZ" in str(hata.value)
    owner_conn.rollback()


# ==================================================================== #
# 3. UC KATMANI — ANLASILIR MESAJ
# ==================================================================== #

def test_ADMININ_TESISI_UCTAN_SILINEMEZ_ve_SEBEBI_ACIK(client, admin):
    """Trigger reddederdi ama mesaji ham olurdu; uc NET konusur.

    ONAY DOGRU VERILIR (ozetten okunur): yanlis adla denemek yalnizca onay
    kapisini olcerdi ve asil korumayi HIC surmezdi — ilk yazimda tam bunu
    yaptim ve test "onay tutmadi" mesajina takildi.
    """
    me = client.get("/me", headers=admin).json()
    tid = me["tenant_id"]
    ozet = client.get(f"/tenants/{tid}/silme-ozeti", headers=admin).json()
    assert ozet["platform_admini_var"] is True
    assert ozet["dogrudan_silinebilir"] is False

    r = client.delete(f"/tenants/{tid}", headers=admin,
                      params={"onay": ozet["onay_metni"]})
    assert r.status_code == 409, r.text
    assert "platform yöneticisi" in r.json()["error"]["message"].lower()


def test_KENDI_TESISINI_ARSIVLEYEMEZ(client, admin):
    me = client.get("/me", headers=admin).json()
    r = client.post(f"/tenants/{me['tenant_id']}/arsivle", headers=admin)
    assert r.status_code == 409, r.text


# ==================================================================== #
# 4. ONAY = TESISIN ADI
# ==================================================================== #

def test_SABIT_KELIME_ONAYI_REDDEDILIR(client, admin):
    """"SİL" her tesiste ayniydi: kas hafizasi uretiyor, yanlis tesiste
    de ayni refleksle yaziliyordu."""
    tid, ad = _yeni_tesis(client, admin)
    r = client.delete(f"/tenants/{tid}", headers=admin, params={"onay": "SİL"})
    assert r.status_code == 409, r.text
    assert "tam adını" in r.json()["error"]["message"]
    # TESIS DURUYOR.
    assert client.get(f"/tenants/{tid}/silme-ozeti", headers=admin).status_code == 200


def test_ONAY_SUNUCUDA_DOGRULANIR_PANELDE_DEGIL(client, admin):
    """Paneli atlayan her cagri (betik, curl, ileride baska istemci) de
    ayni kapidan gecer."""
    tid, ad = _yeni_tesis(client, admin)
    for yanlis in ("", " ", ad.lower(), ad[:-1], ad + "x"):
        r = client.delete(f"/tenants/{tid}", headers=admin, params={"onay": yanlis})
        assert r.status_code == 409, (yanlis, r.status_code)
    # BASTAKI/SONDAKI BOSLUK KIRPILIR ve bu BILINCLI: kopyala-yapistirda
    # eklenen bir bosluk yuzunden "adini dogru yazdim ama kabul etmiyor"
    # demek, korumayi guclendirmez sadece sinir bozar. Kirpma DISINDA
    # hicbir tolerans yok (buyuk/kucuk harf bile tutmuyor — ustteki
    # `ad.lower()` bunu olcer).
    r = client.delete(f"/tenants/{tid}", headers=admin, params={"onay": " " + ad + " "})
    assert r.status_code == 204, r.text


# ==================================================================== #
# 5. ONIZLEME
# ==================================================================== #

def test_SILME_OZETI_ICERIGI_SAYAR(client, admin):
    tid, ad = _yeni_tesis(client, admin)
    d = client.get(f"/tenants/{tid}/silme-ozeti", headers=admin).json()
    assert d["ad"] == ad
    assert d["onay_metni"] == ad, "onay metni SUNUCUDAN gelmeli"
    assert d["kullanici"] >= 1, "tesis olusturulurken yonetici acildi"
    for alan in ("daire", "finansal_hareket", "sikayet", "belge", "denetim_kaydi"):
        assert isinstance(d[alan], int), alan
    assert d["dogrudan_silinebilir"] is True
    assert d["platform_admini_var"] is False


# ==================================================================== #
# 6. AKILLI SILME — GECMISI OLAN TESIS ONCE ARSIVLENIR
# ==================================================================== #

def test_GECMISI_OLAN_TESIS_DOGRUDAN_SILINEMEZ(client, admin, owner_conn):
    """P189'un (kullanici silme) tesis karsiligi: geriye donuk
    sorulabilen kayit varsa yikici islem TEK ADIMDA yapilmaz."""
    tid, ad = _yeni_tesis(client, admin)
    owner_conn.execute(
        "INSERT INTO complaint (tenant_id, acan_user_id, baslik, mesaj, durum) "
        "SELECT %s, id, 'P224', 'gecmis', 'acik' FROM app_user "
        "WHERE tenant_id = %s LIMIT 1", (tid, tid))

    d = client.get(f"/tenants/{tid}/silme-ozeti", headers=admin).json()
    assert d["sikayet"] >= 1
    assert d["dogrudan_silinebilir"] is False

    r = client.delete(f"/tenants/{tid}", headers=admin, params={"onay": ad})
    assert r.status_code == 409, r.text
    assert "arşivle" in r.json()["error"]["message"].lower()


def test_ARSIVLENDIKTEN_SONRA_GECMISLI_TESIS_SILINEBILIR(
        client, admin, owner_conn):
    """Arsiv bir CIKMAZ SOKAK degil: ikinci ve ACIK adim silmedir."""
    tid, ad = _yeni_tesis(client, admin)
    owner_conn.execute(
        "INSERT INTO complaint (tenant_id, acan_user_id, baslik, mesaj, durum) "
        "SELECT %s, id, 'P224', 'gecmis', 'acik' FROM app_user "
        "WHERE tenant_id = %s LIMIT 1", (tid, tid))
    assert client.post(f"/tenants/{tid}/arsivle", headers=admin).status_code == 200
    r = client.delete(f"/tenants/{tid}", headers=admin, params={"onay": ad})
    assert r.status_code == 204, r.text


# ==================================================================== #
# 7. ARSIV GORUNURLUGU VE GERI GETIRME
# ==================================================================== #

def test_ARSIVLI_TESIS_NORMAL_LISTEDE_GORUNMEZ_ARSIVDE_GORUNUR(client, admin):
    tid, ad = _yeni_tesis(client, admin)
    assert client.post(f"/tenants/{tid}/arsivle", headers=admin).status_code == 200

    normal = client.get("/tenants", headers=admin).json()["items"]
    assert not any(i["id"] == tid for i in normal), "arsivli tesis NORMAL listede"

    arsiv = client.get("/tenants?arsivli=true", headers=admin).json()["items"]
    assert any(i["id"] == tid for i in arsiv), "arsivli tesis ARSIVDE yok"


def test_ARSIVDEN_GERI_GETIRILEBILIR(client, admin):
    tid, ad = _yeni_tesis(client, admin)
    client.post(f"/tenants/{tid}/arsivle", headers=admin)
    r = client.post(f"/tenants/{tid}/geri-al", headers=admin)
    assert r.status_code == 200, r.text
    assert r.json()["arsivlendi_at"] is None
    assert any(i["id"] == tid
               for i in client.get("/tenants", headers=admin).json()["items"])


def test_ARSIVLI_TESISE_GIRIS_YAPILAMAZ(client, admin, owner_conn):
    """Gorunurluk KIMLIK SINIRINDA kesiliyor: arsivli tesise ait TOKEN
    URETILEMEZ, yani veri katmanina hic gelinmez."""
    tid, ad = _yeni_tesis(client, admin)
    ek = uuid.uuid4().hex[:6]
    eposta = f"p224-giris-{ek}@ornek.com"
    owner_conn.execute(
        "INSERT INTO app_user (tenant_id, ad, email, password_hash, "
        "password_set, role, is_active) SELECT %s, 'Giris Test', %s, "
        "password_hash, true, 'yonetici', true FROM app_user "
        "WHERE role='admin' LIMIT 1", (tid, eposta))
    slug = owner_conn.execute(
        "SELECT slug FROM tenant WHERE id = %s", (tid,)).fetchone()[0]

    uyelik_once = owner_conn.execute(
        "SELECT count(*) FROM public.tenant_uyelikleri(%s)", (eposta,)
    ).fetchone()[0]
    assert uyelik_once >= 1, "hazirlik: kullanici giris yolunda gorunmuyor"

    client.post(f"/tenants/{tid}/arsivle", headers=admin)

    uyelik_sonra = owner_conn.execute(
        "SELECT count(*) FROM public.tenant_uyelikleri(%s)", (eposta,)
    ).fetchone()[0]
    assert uyelik_sonra == 0, (
        "ARSIVLI TESIS GIRIS YOLUNDA HALA GORUNUYOR — token uretilebilir")


# ==================================================================== #
# 8. DENETIM KAYDI
# ==================================================================== #

def test_ARSIVLEME_ve_SILME_DENETIME_YAZILIR(client, admin, owner_conn):
    """Prod'da bir tesis silindi ve geriye "kim, ne zaman, neyi sildi"
    sorusunu yanitlayan TEK BIR SATIR bile kalmadi."""
    tid, ad = _yeni_tesis(client, admin)
    client.post(f"/tenants/{tid}/arsivle", headers=admin)
    client.delete(f"/tenants/{tid}", headers=admin, params={"onay": ad})

    satirlar = owner_conn.execute(
        "SELECT action, meta FROM audit_log WHERE resource_id = %s "
        "AND action IN ('tenant_archive','tenant_delete') ORDER BY ts",
        (tid,)).fetchall()
    eylemler = [r[0] for r in satirlar]
    assert "tenant_archive" in eylemler and "tenant_delete" in eylemler, eylemler
    # SILME KAYDI ICERIGI DE TASIR: "neyi kaybettim" sorusu sonradan da
    # yanitlanabilsin.
    silme = [r for r in satirlar if r[0] == "tenant_delete"][0]
    assert silme[1].get("ad") == ad, silme[1]
