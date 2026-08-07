"""(P151) `create_tenant_with_yoneticis` — GERCEK veritabanina karsi.

NEDEN VAR: bu akis hic test edilmemisti ve PROD'DA ILK DENEMEDE kirildi
(`relation "tenant" does not exist`). Mock'la yazilsaydi kusuru YAKALAMAZDI:
hata SQL cozumleme katmanindaydi — bos `search_path` altinda tetikleyicinin
nitelenmemis `FROM tenant` satiri. Yalnizca gercek motor gorur.
"""
import json
import uuid

import pytest


def _cagir(owner_conn, slug, telefon, yoneticiler=None):
    y = yoneticiler or [{
        "ad": "Yonetici Bir", "telefon": telefon,
        "password_hash": None, "temp_code_hash": "x", "password_set": False,
    }]
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT * FROM public.create_tenant_with_yoneticis("
            "%s, %s, 'Europe/Istanbul', false, %s, %s::jsonb)",
            (f"Sinama {slug}", slug, "a@b.c", json.dumps(y)),
        )
        return cur.fetchall()


def test_tenant_olusur_ve_birincil_yonetici_doner(owner_conn):
    """Regresyon: bos search_path'li SECURITY DEFINER icinden tetikleyici
    calisabilmeli. Once burada patliyordu."""
    slug = f"t-{uuid.uuid4().hex[:8]}"
    tel = "+9059" + str(uuid.uuid4().int)[:8]
    satirlar = _cagir(owner_conn, slug, tel)
    assert len(satirlar) == 1
    tenant_id, user_id, telefon, birincil = satirlar[0]
    assert telefon == tel and birincil is True

    with owner_conn.cursor() as cur:
        # TETIKLEYICI CALISTI MI: kayit kodu uretilmis olmali (P148.1).
        cur.execute("SELECT kayit_kodu FROM tenant WHERE id = %s", (str(tenant_id),))
        kod = cur.fetchone()[0]
        assert kod and "-" in kod, f"kayit kodu uretilmedi: {kod!r}"
        # RLS ACIKKEN yazildi: FORCE RLS var ama owner superuser -> bypass.
        cur.execute(
            "SELECT relforcerowsecurity FROM pg_class WHERE relname = 'tenant'")
        assert cur.fetchone()[0] is True, "test FORCE RLS acikken anlamli"
        cur.execute("SELECT role, birincil FROM app_user WHERE id = %s",
                    (str(user_id),))
        assert cur.fetchone() == ("yonetici", True)


def test_cok_yonetici_ILKI_birincil(owner_conn):
    slug = f"t-{uuid.uuid4().hex[:8]}"
    t1 = "+9059" + str(uuid.uuid4().int)[:8]
    t2 = "+9059" + str(uuid.uuid4().int)[:8]
    y = [
        {"ad": "Ilk", "telefon": t1, "password_hash": None,
         "temp_code_hash": "x", "password_set": False},
        {"ad": "Ikinci", "telefon": t2, "password_hash": None,
         "temp_code_hash": "y", "password_set": False},
    ]
    satirlar = _cagir(owner_conn, slug, t1, y)
    esleme = {r[2]: r[3] for r in satirlar}
    assert esleme[t1] is True and esleme[t2] is False


def test_ayni_slug_IKINCI_kez_reddedilir(owner_conn):
    """Benzersizlik ihlali fonksiyondan raise olur; API 409'a cevirir."""
    slug = f"t-{uuid.uuid4().hex[:8]}"
    _cagir(owner_conn, slug, "+9059" + str(uuid.uuid4().int)[:8])
    with pytest.raises(Exception):
        _cagir(owner_conn, slug, "+9059" + str(uuid.uuid4().int)[:8])


def test_TETIKLEYICI_bos_search_path_altinda_kirilmaz(owner_conn):
    """KUSURUN TA KENDISI: oturumun search_path'i BOSKEN de calismali.

    Prod'daki cagiran (`search_path=''` tasiyan SECURITY DEFINER) bu kosulu
    yaratiyordu. Tetikleyicinin kendi `SET search_path=''`i oldugu icin
    artik cagirandan BAGIMSIZ.
    """
    with owner_conn.cursor() as cur:
        cur.execute("SET search_path = ''")
    try:
        satirlar = _cagir(
            owner_conn, f"t-{uuid.uuid4().hex[:8]}",
            "+9059" + str(uuid.uuid4().int)[:8])
        assert len(satirlar) == 1
    finally:
        with owner_conn.cursor() as cur:
            cur.execute("SET search_path = public")
