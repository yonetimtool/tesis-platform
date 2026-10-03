"""(P253 acil, goc 0170) E-POSTA KUCUK HARF — sunucu tarafi kilit.

OLCULEN KUSUR (prod): 4 adres buyuk harfle basliyordu, 4 adres harf
farkiyla iki kez kayitliydi. Ekran buyuk harfi engellemiyor, sunucu
kucultmuyordu.

KURAL:
  * Sunucu buyuk harfi REDDETMEZ, KUCULTUR (SSO ve Excel buyuk harf yollar).
  * YALNIZ ASCII A-Z: Turkce kural (`I` -> `ı`) e-postayi bozar.
  * Her e-posta sutununda yazma tetigi var (yeni sutun -> goc listesine).
  * Gocte harf farki BENZERSIZLIGE takilan satir atlanir, birlestirilmez.
"""
from __future__ import annotations

import importlib.util
import uuid
from pathlib import Path

import pytest

from app.eposta import eposta_normalle


def _goc():
    for kok in ("/contracts", "../contracts", "contracts"):
        p = Path(kok) / "db/migrations/versions/0170_p253_eposta_kucuk_harf.py"
        if p.exists():
            spec = importlib.util.spec_from_file_location("goc_0170", p)
            m = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(m)
            return m
    pytest.skip("goc dosyasi bulunamadi")


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# ------------------------------- kural ------------------------------------ #
@pytest.mark.parametrize("ham, beklenen", [
    ("Ali.Veli@Ornek.COM", "ali.veli@ornek.com"),
    ("  Frknkymkc1996@gmail.com ", "frknkymkc1996@gmail.com"),
    # Turkce kural YOK: I -> i (ı DEGIL); İ/Ş gibi ASCII disi harfe dokunulmaz.
    ("ISIK@X.COM", "isik@x.com"),
    ("İŞ@x.com", "İŞ@x.com"),
    ("zaten@kucuk.com", "zaten@kucuk.com"),
])
def test_KURAL_yalniz_ascii_kucultur(ham, beklenen, owner_conn):
    assert eposta_normalle(ham) == beklenen
    # Veritabani fonksiyonu AYNI sonucu verir (tetik bunu kullanir).
    db = owner_conn.execute("SELECT public.eposta_normalle(%s)", (ham,)).fetchone()[0]
    assert db == beklenen


def test_KIMLIK_cozumu_kucultur():
    from app.kimlik import kimligi_coz

    assert kimligi_coz(" Ali@ORNEK.com ").deger == "ali@ornek.com"


# --------------------------- envanter + tetik ------------------------------ #
def test_HER_EPOSTA_SUTUNU_gocte_ve_TETIKLI(owner_conn):
    """Katalogdaki e-posta sutunlari == goc listesi; her birinde tetik var.
    Yeni bir e-posta sutunu eklenirse bu test onu goc listesine yazdirir."""
    katalog = {
        (s, t, c) for s, t, c in owner_conn.execute(
            "SELECT c.table_schema, c.table_name, c.column_name "
            "FROM information_schema.columns c "
            "JOIN information_schema.tables t USING (table_schema, table_name) "
            "WHERE t.table_type = 'BASE TABLE' "
            "  AND c.table_schema IN ('public', 'dukkan') "
            "  AND c.data_type IN ('text', 'character varying') "
            "  AND (c.column_name ILIKE '%%email%%' OR c.column_name ILIKE '%%eposta%%') "
            # Bunlar e-posta ADRESI degil (bayrak/sablon/olay kimligi).
            "  AND c.column_name NOT IN ('sikayet_eden_eposta')"
        ).fetchall()
    }
    assert katalog == set(_goc().SUTUNLAR)
    for sema, tablo, _ in _goc().SUTUNLAR:
        var = owner_conn.execute(
            "SELECT 1 FROM pg_trigger WHERE tgname = %s AND tgrelid = %s::regclass",
            (f"trg_{tablo}_eposta_kucuk", f"{sema}.{tablo}"),
        ).fetchone()
        assert var, f"{sema}.{tablo}: e-posta tetigi yok"


def test_TETIK_dogrudan_SQL_yazimini_da_kucultur(owner_conn, world):
    """API disi yol (SQL fonksiyonu, tohum, elle yazim) da kucuk yazar."""
    uid = uuid.uuid4()
    owner_conn.execute(
        "INSERT INTO app_user (id, tenant_id, ad, email, password_hash, role) "
        "VALUES (%s, %s, 'Tetik', '  Buyuk.Harf@Ornek.COM ', '!', 'security')",
        (uid, world["a"]))
    assert owner_conn.execute(
        "SELECT email FROM app_user WHERE id = %s", (uid,)).fetchone()[0] \
        == "buyuk.harf@ornek.com"
    owner_conn.execute("UPDATE app_user SET email = 'IKINCI@Ornek.com' WHERE id = %s", (uid,))
    assert owner_conn.execute(
        "SELECT email FROM app_user WHERE id = %s", (uid,)).fetchone()[0] == "ikinci@ornek.com"


# ------------------------------ goc davranisi ----------------------------- #
def test_GOC_ayni_tesiste_HARF_IKIZINI_ATLAR_birlestirmez(owner_conn):
    """Benzersizlige takilan satir DEGISTIRILMEZ; digerleri kucultulur."""
    goc = _goc()
    t = f"goc_deneme_{uuid.uuid4().hex[:8]}"
    owner_conn.execute(
        f"CREATE TABLE public.{t} (tenant_id int, email text, "
        f"UNIQUE (tenant_id, email))")
    try:
        owner_conn.execute(
            f"INSERT INTO public.{t} VALUES "
            "(1, 'ali@x.com'), (1, 'Ali@x.com'), "      # ayni tesis: IKIZ
            "(2, 'Ali@x.com'), "                        # baska tesis: kucultulur
            "(1, 'Veli@X.com')")                        # tekil: kucultulur
        owner_conn.execute(goc.kucult_sql("public", t, "email"))
        satirlar = sorted(owner_conn.execute(
            f"SELECT tenant_id, email FROM public.{t}").fetchall())
        assert satirlar == [(1, "Ali@x.com"), (1, "ali@x.com"),
                            (1, "veli@x.com"), (2, "ali@x.com")]
    finally:
        owner_conn.execute(f"DROP TABLE public.{t}")


def test_GOC_tesis_uyelik_birincil_ikizinde_EN_ESKISI_kalir(owner_conn):
    goc = _goc()
    t = f"uyelik_deneme_{uuid.uuid4().hex[:8]}"
    owner_conn.execute(
        f"CREATE TABLE public.{t} (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), "
        "eposta text, birincil bool, created_at timestamptz)")
    try:
        owner_conn.execute(
            f"INSERT INTO public.{t} (eposta, birincil, created_at) VALUES "
            "('Kaan@x.com', true, now() - interval '2 day'), "
            "('kaan@x.com', true, now() - interval '1 day'), "
            "('tek@x.com', true, now())")
        owner_conn.execute(goc.birincil_ikiz_sql(t))
        satirlar = sorted(owner_conn.execute(
            f"SELECT eposta, birincil FROM public.{t}").fetchall())
        assert satirlar == [("Kaan@x.com", True), ("kaan@x.com", False),
                            ("tek@x.com", True)]
    finally:
        owner_conn.execute(f"DROP TABLE public.{t}")


# ------------------------------- API yollari ------------------------------ #
def test_KULLANICI_EKLE_buyuk_harfi_kucultur_ve_harf_ikizi_409(client, world, owner_conn):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    yerel = f"Ali.Veli.{uuid.uuid4().hex[:8]}"
    r = client.post("/users", headers=h, json={
        "ad": "Ali", "soyad": "Veli", "email": f"  {yerel}@Ornek.COM ", "role": "security"})
    assert r.status_code == 201, r.text
    beklenen = f"{yerel.lower()}@ornek.com"
    assert owner_conn.execute(
        "SELECT email FROM app_user WHERE id = %s", (r.json()["id"],)).fetchone()[0] == beklenen
    # Ayni adres baska harfle: ayni kisi -> reddedilir (ikinci hesap ACILMAZ).
    r2 = client.post("/users", headers=h, json={
        "ad": "Ali", "soyad": "Veli", "email": beklenen.upper(), "role": "security"})
    assert r2.status_code == 409, r2.text


def test_SAKIN_EKLE_kucultur(client, world, owner_conn):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    yerel = f"Sakin.{uuid.uuid4().hex[:8]}"
    r = client.post("/residents", headers=h, json={
        "ad": "Sakin", "soyad": "Kisi", "email": f"{yerel}@Ornek.com",
        "unit_no": f"EK-{uuid.uuid4().hex[:5]}", "blok": "A",
        "telefon": f"+90555{uuid.uuid4().int % 10000000:07d}"})
    assert r.status_code in (200, 201), r.text
    assert owner_conn.execute(
        "SELECT count(*) FROM app_user WHERE email = %s",
        (f"{yerel.lower()}@ornek.com",)).fetchone()[0] == 1


def test_GIRIS_buyuk_harfle_de_calisir(client, world):
    cred = world["yonetici_a"]
    r = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"], "email": cred["email"].upper(),
        "password": cred["password"]})
    assert r.status_code == 200, r.text
