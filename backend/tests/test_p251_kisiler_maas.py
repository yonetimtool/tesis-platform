"""(P251 §8) Kisiler sekmeleri, maas karti <-> hesap bagi, kurulum adimi.

Olculen:
  * `/users?role=a&role=b` birden cok rolu TEK listede doner (Kisiler ›
    Personel sekmesi); tek rol eski cagiranlar icin aynen calisir;
  * amirin rol gorunurlugu (P231) cok rollu suzgecte de korunur;
  * bir hesaba en cok BIR maas karti baglanir (409) — fazla mesai ucreti
    bu bagdan okunur, iki kart belirsizlik demekti;
  * kurulum "personel" adimi maas kartini degil saha personeli HESABINI
    sayar (mobil sihirbaz hesap ekranina gidiyordu ve adim kapanmiyordu).
"""
from __future__ import annotations

import uuid


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


SAHA = ("security", "tesis_gorevlisi", "guvenlik_amiri")


def test_cok_rollu_suzgec_tek_listede(client, world):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    r = client.get("/users", headers=y, params=[("limit", "200"), *[("role", x) for x in SAHA]])
    assert r.status_code == 200, r.text
    roller = {u["role"] for u in r.json()["items"]}
    assert roller and roller <= set(SAHA)
    # Tek deger: eski davranis.
    tek = client.get("/users", headers=y, params={"role": "resident", "limit": 200}).json()["items"]
    assert tek and {u["role"] for u in tek} == {"resident"}


def test_amir_cok_rollu_suzgecte_de_yalniz_guvenligi_gorur(client, world):
    a = _h(client, world["slug_a"], world["amir_a"])
    r = client.get("/users", headers=a, params=[("role", "security"), ("role", "resident")])
    assert r.status_code == 200, r.text
    assert {u["role"] for u in r.json()["items"]} <= {"security"}


def test_hesaba_tek_maas_karti(client, world):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    personel = client.get("/users", headers=y, params={"role": "security", "limit": 200}).json()["items"]
    hesap = personel[0]["id"]
    # Temiz baslangic: bu hesaba bagli kart varsa bag kaldirilir.
    for k in client.get("/personel-kayitlari", headers=y, params={"limit": 200}).json()["items"]:
        if k.get("app_user_id") == hesap:
            client.patch(f"/personel-kayitlari/{k['id']}", headers=y, json={"app_user_id": None})

    ad = f"Kart {uuid.uuid4().hex[:6]}"
    r = client.post("/personel-kayitlari", headers=y, json={"ad": ad, "app_user_id": hesap})
    assert r.status_code == 201, r.text
    kart = r.json()
    assert kart["app_user_id"] == hesap

    r = client.post("/personel-kayitlari", headers=y, json={"ad": ad + "2", "app_user_id": hesap})
    assert r.status_code == 409, r.text
    assert r.json()["error"]["code"] == "conflict"

    # Ayni karti kendisiyle yeniden kaydetmek celiski DEGIL.
    r = client.patch(f"/personel-kayitlari/{kart['id']}", headers=y, json={"app_user_id": hesap})
    assert r.status_code == 200, r.text

    # Baska karti ayni hesaba baglamak 409.
    r2 = client.post("/personel-kayitlari", headers=y, json={"ad": ad + "3"})
    assert r2.status_code == 201, r2.text
    r = client.patch(f"/personel-kayitlari/{r2.json()['id']}", headers=y, json={"app_user_id": hesap})
    assert r.status_code == 409, r.text

    for kid in (kart["id"], r2.json()["id"]):
        client.delete(f"/personel-kayitlari/{kid}", headers=y)


def test_kurulum_personel_adimi_hesabi_sayar(client, world):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    adimlar = {a["kod"]: a for a in client.get("/kurulum", headers=y).json()["adimlar"]}
    hesaplar = client.get(
        "/users", headers=y, params=[("limit", "1"), *[("role", x) for x in SAHA]]
    ).json()["meta"]["total"]
    assert adimlar["personel"]["sayi"] == hesaplar
    assert hesaplar > 0 and adimlar["personel"]["tamam"] is True


def test_telefonsuz_davetli_DAVET_LISTESINI_DUSURMEZ(client, world):
    """Telefon P212'den beri opsiyonel; liste semasi zorunlu tutuyordu ve
    telefonsuz TEK davetli tum listeyi 500'e dusuruyordu (tarayicida olculdu)."""
    y = _h(client, world["slug_a"], world["yonetici_a"])
    eposta = f"telsiz-{uuid.uuid4().hex[:8]}@ornek.com"
    r = client.post("/users", headers=y, json={
        "ad": "Telsiz", "soyad": "Personel", "email": eposta, "role": "security",
    })
    assert r.status_code == 201, r.text
    r = client.get("/davet", headers=y)
    assert r.status_code == 200, r.text
    satir = next(d for d in r.json()["items"] if d["user_id"] == client.get(
        "/users", headers=y, params={"q": eposta}).json()["items"][0]["id"])
    assert satir["telefon"] is None
