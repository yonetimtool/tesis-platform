"""(P154 / Asama 6.4) NOT VE EK — ortak sistem.

Olculen dort sey:
  1. Ek, ANA KAYDIN yetkisini miras aliyor mu (kendi kumesini tutmuyor),
  2. Polimorfik bagin bedeli odendi mi — ust kayit dogrulaniyor mu,
  3. Icerik kurali hem sozlesmede hem veritabaninda mi,
  4. Silme kurali: sahibi VEYA ana kayda yazma yetkisi olan.
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


def _daire(owner_conn, slug) -> str:
    with owner_conn.cursor() as cur:
        no = f"E-{uuid.uuid4().hex[:5]}"
        cur.execute(
            "INSERT INTO unit (tenant_id, blok, no) "
            "SELECT id, 'A', %s FROM tenant WHERE slug = %s RETURNING id",
            (no, slug),
        )
        return str(cur.fetchone()[0])


# ============ 1) YETKI ANA KAYITTAN MIRAS — kopya kume YOK ================= #

def test_varlik_tipleri_GOCLE_AYNI(owner_conn):
    """Router'in bildigi tipler ile CHECK kisitinin kumesi AYNI olmali.

    Ayrisirsa iki yonde de sessiz kusur cikar: routerda olup CHECK'te
    olmayan tip 500 verir (IntegrityError), CHECK'te olup routerda
    olmayan tip ise HIC kullanilamaz.
    """
    from app.routers.ekler import VARLIKLAR

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT pg_get_constraintdef(oid) FROM pg_constraint "
            "WHERE conname = 'ck_varlik_eki_tipi'"
        )
        tanim = cur.fetchone()[0]
    for tip in VARLIKLAR:
        assert f"'{tip}'" in tanim, f"{tip} CHECK kisitinda yok"
    # Ters yon: CHECK'te olup routerda olmayan tip kalmasin.
    import re

    check_tipleri = set(re.findall(r"'([a-z_]+)'", tanim))
    assert check_tipleri == set(VARLIKLAR), check_tipleri ^ set(VARLIKLAR)


def test_rol_kumeleri_ROUTERLARDAN_okunuyor():
    """Ek sistemi KENDI rol listesini tutmaz.

    Tutsaydi ana kaydin yetkisi degistiginde ekinki degismezdi ve
    ayrisma SESSIZ olurdu — ek "fazladan" gorunur, hicbir hata cikmaz.
    """
    from app.routers.ekler import VARLIKLAR
    from app.routers.finans import _OKUMA as icra_okur
    from app.routers.units import _LAYOUT_READER as daire_okur

    assert VARLIKLAR["unit"].okur == frozenset(daire_okur.izinli_roller)
    assert VARLIKLAR["icra_dosyasi"].okur == frozenset(icra_okur.izinli_roller)


def test_YAZMA_KAPISI_birlesimden_TURETILIYOR():
    """Yazma uclarinin rol kapisi elle yazilmaz, `VARLIKLAR`tan turer.

    Elle yazilsaydi bir routerin yazar kumesi degistiginde burasi eskir,
    ya fazladan bir rol gecer ya da mesru bir rol kapida kalirdi.
    """
    from app.routers.ekler import VARLIKLAR, _YAZABILENLER

    assert _YAZABILENLER == frozenset().union(*(v.yazar for v in VARLIKLAR.values()))


def test_DENETCI_hicbir_ek_YAZAMAZ():
    """Denetci SALT-OKUMA (P128). Hicbir yazar kumesinde olmamali.

    Yazma ucunda rol kapisi olmasaydi denetci yonlendirme katmanini
    gecer ve yalnizca govdedeki mantik onu durdururdu.
    """
    from app.routers.ekler import _YAZABILENLER

    assert "denetci" not in _YAZABILENLER


def test_SAKIN_daireye_not_EKLEYEMEZ(client, world, owner_conn):
    """`unit` yazma kumesi admin+yonetici. Sakin daire notu yazamaz."""
    unit_id = _daire(owner_conn, world["slug_a"])
    sakin = _giris(client, world["slug_a"], world["resident_a"])
    r = client.post("/ekler", headers=sakin, json={
        "varlik_tipi": "unit", "varlik_id": unit_id, "tur": "not", "metin": "deneme"})
    assert r.status_code == 403, r.text


def test_SAKIN_ICRA_ekini_OKUYAMAZ(client, world, owner_conn):
    """Icra okuma kumesi admin+yonetici+denetci — sakin YOK.

    Ek sistemi kendi (gevsek) kumesini tutsaydi, sakin icra dosyasina
    yazilmis bir notu okuyabilirdi.
    """
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO icra_dosyasi (tenant_id, dosya_no, user_id) "
            "SELECT t.id, %s, u.id FROM tenant t "
            "JOIN app_user u ON u.tenant_id = t.id AND u.role = 'resident' "
            "WHERE t.slug = %s LIMIT 1 RETURNING id",
            (f"IC-{uuid.uuid4().hex[:5]}", world["slug_a"]),
        )
        icra_id = cur.fetchone()[0]

    sakin = _giris(client, world["slug_a"], world["resident_a"])
    r = client.get(
        f"/ekler?varlik_tipi=icra_dosyasi&varlik_id={icra_id}", headers=sakin
    )
    assert r.status_code == 403, r.text


# ============ 2) POLIMORFIK BAGIN BEDELI — ust kayit dogrulanir ============ #

def test_OLMAYAN_kayda_ek_TAKILAMAZ(client, world):
    """FK olmadigi icin bu kontrol UCTA yapilmali.

    Olmasaydi rastgele bir UUID'ye ek takilir, hicbir ekranda gorunmeyen
    kayitlar birikirdi.
    """
    yon = _giris(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/ekler", headers=yon, json={
        "varlik_tipi": "unit", "varlik_id": str(uuid.uuid4()),
        "tur": "not", "metin": "hayalet"})
    assert r.status_code == 404, r.text


def test_YETKI_KAPISI_VARLIK_SORGUSUNDAN_ONCE(client, world):
    """Yetkisiz cagiran 403/404 farkindan "bu id var mi" sorusunu
    YANITLAYAMAMALI.

    Sira ters olsaydi (once sorgu, sonra rol) sakin, olmayan bir icra
    dosyasi icin 404, VAR OLAN icin 403 alir ve varligi ogrenirdi.
    """
    sakin = _giris(client, world["slug_a"], world["resident_a"])
    r = client.get(
        f"/ekler?varlik_tipi=icra_dosyasi&varlik_id={uuid.uuid4()}", headers=sakin
    )
    # Kayit YOK ama yine de 403 — cunku rol kapisi once calisti.
    assert r.status_code == 403, r.text


def test_BILINMEYEN_varlik_tipi_422(client, world):
    yon = _giris(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/ekler", headers=yon, json={
        "varlik_tipi": "units", "varlik_id": str(uuid.uuid4()),
        "tur": "not", "metin": "x"})
    assert r.status_code == 422, r.text


# ==================== 3) ICERIK KURALI + MUTLU YOL ========================= #

def test_NOT_ve_DOSYA_ayni_zaman_cizgisinde(client, world, owner_conn):
    unit_id = _daire(owner_conn, world["slug_a"])
    yon = _giris(client, world["slug_a"], world["yonetici_a"])

    n = client.post("/ekler", headers=yon, json={
        "varlik_tipi": "unit", "varlik_id": unit_id,
        "tur": "not", "metin": "Kombi bakimi yapildi."})
    assert n.status_code == 201, n.text
    assert n.json()["olusturan_ad"], "notu kimin yazdigi donmuyor"

    d = client.post("/ekler", headers=yon, json={
        "varlik_tipi": "unit", "varlik_id": unit_id, "tur": "dosya",
        "dosya_key": "t/abc.jpg", "dosya_adi": "fatura.jpg"})
    assert d.status_code == 201, d.text

    liste = client.get(
        f"/ekler?varlik_tipi=unit&varlik_id={unit_id}", headers=yon
    ).json()["items"]
    # IKISI DE ayni listede: kullanici notlari ve dosyalari TEK zaman
    # cizgisinde gormek ister.
    assert {e["tur"] for e in liste} == {"not", "dosya"}


def test_BOS_not_reddedilir(client, world, owner_conn):
    """Sozlesme duzeyinde reddedilir: veritabani hatasi kullaniciya
    "IntegrityError" olarak donerdi, oysa NE eksik oldugu soylenmeli."""
    unit_id = _daire(owner_conn, world["slug_a"])
    yon = _giris(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/ekler", headers=yon, json={
        "varlik_tipi": "unit", "varlik_id": unit_id, "tur": "not", "metin": "   "})
    assert r.status_code == 422, r.text


def test_veritabani_da_BOS_notu_reddeder(owner_conn, world):
    """Ikinci savunma: uc atlansa bile CHECK tutar."""
    import psycopg

    with owner_conn.cursor() as cur:
        cur.execute("SELECT id FROM tenant WHERE slug = %s", (world["slug_a"],))
        tid = cur.fetchone()[0]
        cur.execute("SELECT id FROM app_user WHERE tenant_id = %s LIMIT 1", (tid,))
        uid = cur.fetchone()[0]
        try:
            cur.execute(
                "INSERT INTO varlik_eki (tenant_id, varlik_tipi, varlik_id, tur, "
                "olusturan_user_id) VALUES (%s,'unit',%s,'not'::ek_turu,%s)",
                (tid, str(uuid.uuid4()), uid),
            )
            raise AssertionError("bos not veritabanina girdi")
        except psycopg.errors.CheckViolation:
            owner_conn.rollback()


# =========================== 4) SILME KURALI =============================== #

def test_SAHIBI_kendi_notunu_silebilir(client, world, owner_conn):
    """Yalniz yoneticiye birakmak, kisinin kendi yazdigi notu
    duzeltmesini engellerdi."""
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO complaint (tenant_id, acan_user_id, baslik, mesaj) "
            "SELECT t.id, u.id, 'Ek testi', 'mesaj' FROM tenant t "
            "JOIN app_user u ON u.tenant_id = t.id AND u.role = 'resident' "
            "WHERE t.slug = %s LIMIT 1 RETURNING id",
            (world["slug_a"],),
        )
        talep_id = str(cur.fetchone()[0])

    yon = _giris(client, world["slug_a"], world["yonetici_a"])
    ek = client.post("/ekler", headers=yon, json={
        "varlik_tipi": "complaint", "varlik_id": talep_id,
        "tur": "not", "metin": "yonetim notu"})
    assert ek.status_code == 201, ek.text
    assert client.delete(
        f"/ekler/{ek.json()['id']}", headers=yon
    ).status_code == 204
