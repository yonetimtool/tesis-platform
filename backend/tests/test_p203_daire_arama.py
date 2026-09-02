"""(P203 §3) DAIRE ARAMA — numara VEYA sakin adiyla.

===========================================================================
OLCULEN KUSUR
===========================================================================
Ziyaretci kaydinda daire ELLE yaziliyordu (mobil formda serbest metin).
Kapida duran gorevli cogu zaman "Ayse Hanim'a geldim" duyar, "A-12'ye
geldim" duymaz. Numarayi bilmedigi icin ya sakini arayip soruyor ya da
YANLIS daire yaziyordu — ikincisi SESSIZ bir kusurdur: kayit olusur ve
bildirim BASKA BIR SAKINE gider.

ONCE OLCULDU: guvenligin `GET /units` ve
`GET /units/by-no/{no}/residents` yetkisi ZATEN VARDI (rol matrisi).
Yani eksik olan yetki degil, ADLA ARAMAYDI.
"""
from __future__ import annotations

import uuid

import pytest


def _giris(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def daire_ve_sakin(client, world, owner_conn):
    """A tesisinde bir daire + ona bagli AKTIF sakin."""
    ek = uuid.uuid4().hex[:6]
    no = f"D{ek}"
    ad = f"Ayse Bulunabilir {ek}"
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO unit (tenant_id, no, blok) VALUES (%s,%s,'A') RETURNING id",
            (world["a"], no),
        )
        unit_id = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, password_hash, role) "
            "VALUES (%s,%s,%s,'x','resident'::user_role) RETURNING id",
            (world["a"], ad, f"sakin-{ek}@ornek.com"),
        )
        uid = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO unit_resident (tenant_id, unit_id, user_id) VALUES (%s,%s,%s)",
            (world["a"], unit_id, uid),
        )
    return {"no": no, "ad": ad, "unit_id": str(unit_id), "user_id": str(uid), "ek": ek}


def _ara(client, h, q):
    r = client.get("/units/ara", headers=h, params={"q": q})
    assert r.status_code == 200, r.text
    return r.json()


def test_GUVENLIK_DAIRE_NUMARASIYLA_bulur(client, world, daire_ve_sakin):
    h = _giris(client, world["slug_a"], world["guard_a"])
    sonuc = _ara(client, h, daire_ve_sakin["no"])
    assert any(d["no"] == daire_ve_sakin["no"] for d in sonuc), sonuc


def test_GUVENLIK_SAKIN_ADIYLA_da_bulur(client, world, daire_ve_sakin):
    """Ozelligin asil sebebi: gorevli numarayi degil ISMI biliyor."""
    h = _giris(client, world["slug_a"], world["guard_a"])
    sonuc = _ara(client, h, "Bulunabilir")
    assert any(d["no"] == daire_ve_sakin["no"] for d in sonuc), sonuc


def test_SONUC_SAKINLERI_de_TASIR(client, world, daire_ve_sakin):
    """Hedef sakin secimi ZORUNLU; ayri bir cagri her aramada ikinci bir
    bekleme daha yasatirdi."""
    h = _giris(client, world["slug_a"], world["guard_a"])
    sonuc = _ara(client, h, daire_ve_sakin["no"])
    daire = next(d for d in sonuc if d["no"] == daire_ve_sakin["no"])
    assert any(s["user_id"] == daire_ve_sakin["user_id"] for s in daire["sakinler"])
    # AMAC SINIRLI: yalniz kimlik + ad. Telefon/e-posta/borc YOK.
    assert set(daire["sakinler"][0]) == {"user_id", "ad"}


def test_BOS_ve_TEK_HARF_sorgu_BOS_DONER(client, world, daire_ve_sakin):
    """Uc bir DOKUM ARACI degil: tek istekle tum daire/sakin listesini
    veremez."""
    h = _giris(client, world["slug_a"], world["guard_a"])
    assert _ara(client, h, "") == []
    assert _ara(client, h, "a") == []


def test_BASKA_TESISIN_dairesi_GORUNMEZ(client, world, owner_conn):
    """Izolasyon: arama RLS altinda calisir."""
    ek = uuid.uuid4().hex[:6]
    no = f"B{ek}"
    with owner_conn.cursor() as cur:
        cur.execute("INSERT INTO unit (tenant_id, no) VALUES (%s,%s)", (world["b"], no))
    h = _giris(client, world["slug_a"], world["guard_a"])
    assert _ara(client, h, no) == []


def test_SAKIN_ARAMA_UCUNU_GOREMEZ(client, world):
    """RBAC `by-no/.../residents` ile AYNI: sakin baska dairelerin
    kimlerde oldugunu sorgulayamaz."""
    h = _giris(client, world["slug_a"], world["resident_a"])
    r = client.get("/units/ara", headers=h, params={"q": "ab"})
    assert r.status_code == 403, r.text


def test_PASIF_SAKIN_LISTELENMEZ(client, world, daire_ve_sakin, owner_conn):
    """Tasinmis sakine ziyaretci bildirimi gitmemeli."""
    h = _giris(client, world["slug_a"], world["guard_a"])
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE unit_resident SET bitis=now() WHERE user_id=%s",
            (daire_ve_sakin["user_id"],),
        )
    sonuc = _ara(client, h, daire_ve_sakin["no"])
    daire = next(d for d in sonuc if d["no"] == daire_ve_sakin["no"])
    assert daire["sakinler"] == []
    # Adla arama da BULMAMALI: baglanti bitti.
    assert _ara(client, h, "Bulunabilir") == [] or all(
        d["no"] != daire_ve_sakin["no"] for d in _ara(client, h, "Bulunabilir")
    )
