"""(P247 §2) PROFILDEN ROL GECISI — yonetici <-> sakin, sunucu zorlar.

Kabul olcutleri (P247):
 3/4. iki rollu kullanici `roller`de ikisini gorur; sakin modunda yonetim
      ucu yok,
 5.   sakin modunda yonetici ucu 403 — istemci atlatilarak (dogrudan API),
 6.   tek rollu kullanicida gecis yok; diger coklu rol birlesimleri red.
"""
from __future__ import annotations

import uuid

import pytest

from app.security import create_access_token


def _giris(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return r.json()


def _h(tok):
    return {"Authorization": f"Bearer {tok}"}


@pytest.fixture
def cift_rollu(client, world):
    """Yoneticiyi bir daireye SAKIN olarak baglar (POST /residents ayni e-posta)."""
    t = _giris(client, world["slug_a"], world["yonetici_a"])
    h = _h(t["access_token"])
    blok = f"R{uuid.uuid4().hex[:4].upper()}"
    assert client.post("/blocks", headers=h, json={"ad": blok}).status_code in (201, 409)
    r = client.post("/residents", headers=h, json={
        "unit_no": "1", "blok": blok, "telefon": world["yonetici_a"]["phone"],
        "email": world["yonetici_a"]["email"], "rol_tipi": "malik", "oturuyor": True})
    assert r.status_code == 201, r.text
    me = client.get("/me", headers=_h(t["access_token"])).json()
    yield {"tok": t, "unit_id": r.json()["unit_id"], "user_id": me["id"]}
    client.delete(f"/units/{r.json()['unit_id']}/residents/{me['id']}", headers=h)


def test_TEK_ROLLU_KULLANICIDA_GECIS_YOK(client, world):
    t = _giris(client, world["slug_a"], world["guard_a"])
    me = client.get("/me", headers=_h(t["access_token"])).json()
    assert me["roller"] == ["security"]
    r = client.post("/me/rol-gecis", headers=_h(t["access_token"]), json={"rol": "resident"})
    assert r.status_code in (403, 422), r.text


def test_DAIRESIZ_YONETICIDE_GECIS_YOK(client, world):
    t = _giris(client, world["slug_a"], world["yonetici_a"])
    me = client.get("/me", headers=_h(t["access_token"])).json()
    if me["roller"] == ["yonetici"]:
        r = client.post("/me/rol-gecis", headers=_h(t["access_token"]), json={"rol": "resident"})
        assert r.status_code == 403, r.text


def test_SAKIN_MODU_YONETIM_UCU_403_ve_GERI_DONUS(client, world, cift_rollu, owner_conn):
    tok = cift_rollu["tok"]
    me = client.get("/me", headers=_h(tok["access_token"])).json()
    assert me["roller"] == ["yonetici", "resident"] and me["role"] == "yonetici"

    r = client.post("/me/rol-gecis", headers=_h(tok["access_token"]),
                    json={"rol": "resident", "refresh_token": tok["refresh_token"]})
    assert r.status_code == 200, r.text
    sakin = r.json()
    # ESKI BAGLAM KAPANDI: eski erisim ve refresh gecmez.
    assert client.get("/me", headers=_h(tok["access_token"])).status_code == 401
    assert client.post("/auth/refresh",
                       json={"refresh_token": tok["refresh_token"]}).status_code == 401

    hs = _h(sakin["access_token"])
    assert client.get("/me", headers=hs).json()["role"] == "resident"
    # Yonetim uclari — istemci atlatilarak DOGRUDAN: 403.
    for yol in ("/users", "/residents", "/finans/ozet", "/audit"):
        assert client.get(yol, headers=hs).status_code == 403, yol
    # Sakin uclari calisir.
    assert client.get("/me/dues", headers=hs).status_code == 200
    # Yonetim alarmlari (paylasilan satirlar) sakin modunda GORUNMEZ.
    tid = client.get("/me", headers=hs).json()["tenant_id"]
    nid = uuid.uuid4()
    owner_conn.execute(
        "INSERT INTO notification (id, tenant_id, tip, user_id, mesaj, okundu) "
        "VALUES (%s,%s,'kacirilan_tur',NULL,'p247',false)", (nid, tid))
    ids = {n["id"] for n in client.get("/notifications", headers=hs,
                                       params={"limit": 200}).json()["items"]}
    assert str(nid) not in ids

    # YENILEME MODU KORUR.
    y = client.post("/auth/refresh", json={"refresh_token": sakin["refresh_token"]})
    assert y.status_code == 200, y.text
    assert client.get("/me", headers=_h(y.json()["access_token"])).json()["role"] == "resident"

    # Geri donus: yonetim uclari yeniden acik.
    g = client.post("/me/rol-gecis", headers=_h(y.json()["access_token"]),
                    json={"rol": "yonetici"})
    assert g.status_code == 200, g.text
    assert client.get("/users", headers=_h(g.json()["access_token"])).status_code == 200

    # DENETIM: iki gecis de yazildi.
    with owner_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM audit_log WHERE action = 'rol_gecisi' "
                    "AND actor_user_id = %s", (cift_rollu["user_id"],))
        assert cur.fetchone()[0] >= 2


def test_UYDURMA_ROL_IDDIASI_YETKI_KAZANDIRMAZ(client, world):
    """Jeton `role` iddiasi yalniz yetki DUSURUR: sakine `yonetici` diyen
    (imzali ama uygunsuz) iddia yok sayilir, DB rolu gecerli."""
    t = _giris(client, world["slug_a"], world["resident_a"])
    me = client.get("/me", headers=_h(t["access_token"])).json()
    sahte = create_access_token(user_id=me["id"], tenant_id=me["tenant_id"], role="yonetici")
    assert client.get("/users", headers=_h(sahte)).status_code == 403
    assert client.get("/me", headers=_h(sahte)).json()["role"] == "resident"


def test_BASKA_ROLDEKI_KISI_SAKIN_YAPILAMAZ(client, world):
    """Tek istisna yonetici+sakin: guvenlik gorevlisini daireye sakin olarak
    eklemek acik bir 'tek rol' hatasi verir."""
    t = _giris(client, world["slug_a"], world["yonetici_a"])
    h = _h(t["access_token"])
    blok = f"S{uuid.uuid4().hex[:4].upper()}"
    client.post("/blocks", headers=h, json={"ad": blok})
    r = client.post("/residents", headers=h, json={
        "unit_no": "1", "blok": blok, "telefon": world["guard_a"]["phone"],
        "email": world["guard_a"]["email"], "rol_tipi": "malik"})
    assert r.status_code == 409, r.text
    assert "tek rol" in r.json()["error"]["message"] or "başka bir rolde" in r.json()["error"]["message"]
