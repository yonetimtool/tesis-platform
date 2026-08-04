"""(P127.2) TANITIM ILETISIM FORMU — public gonderim, admin okuma, izolasyon.

UC SORU OLCULUR:
  1. Form GERCEKTEN TESLIM EDIYOR mu (kayit atiliyor ve admin goruyor)?
     Kabul kriteri buydu; onceki tur `mailto:` birakmisti.
  2. Kimliksiz uc BASKA ADAYLARI GOREBILIYOR mu? (gorememeli)
  3. app_rw tabloya DOGRUDAN erisebiliyor mu? (erisememeli — RLS acik,
     politika yok; erisim yalniz SECURITY DEFINER fonksiyonlarindan)

Ucuncusu bu tasarimin TEK dayanagidir: "politika yok" demek, yanlis
kurulunca "herkes her seyi gorur" demeye de donebilirdi. Bu yuzden
DAVRANISLA olculur, katalog kontroluyle degil.
"""
from __future__ import annotations

import uuid

import psycopg
import pytest


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _gonder(client, **alan):
    govde = {
        "ad": "Aday Kişi",
        "email": f"aday-{uuid.uuid4().hex[:8]}@ornek.com",
        "mesaj": "Demo talep ediyorum, 120 daireli bir sitemiz var.",
        "dil": "tr",
    }
    govde.update(alan)
    # Hiz siniri IP basinadir; her test KENDI IP'siyle gelsin ki birbirini
    # 429'a dusurmesin (sinir testi bunu BILEREK kendi IP'sinde asar).
    ip = alan.pop("_ip", None) or f"10.9.{uuid.uuid4().int % 250}.{uuid.uuid4().int % 250}"
    return client.post(
        "/public/tanitim-iletisim", json=govde, headers={"X-Forwarded-For": ip}
    )


# ----------------------------- 1. TESLIMAT --------------------------------- #
def test_form_KAYIT_atiyor_ve_admin_goruyor(client, world):
    mesaj = f"Demo talebi {uuid.uuid4().hex[:8]}"
    r = _gonder(client, mesaj=mesaj)
    assert r.status_code == 201, r.text
    assert r.json()["ok"] is True

    admin = _headers(client, world["slug_a"], world["admin_a"])
    liste = client.get("/tanitim-iletisim", headers=admin, params={"limit": 200})
    assert liste.status_code == 200, liste.text
    mesajlar = [x["mesaj"] for x in liste.json()["items"]]
    assert mesaj in mesajlar, "gonderilen mesaj admin listesinde YOK"


def test_donus_yolu_ZORUNLU(client):
    """Telefon VEYA e-posta olmadan mesaj kabul edilmez.

    Ikisi de yoksa gelen mesaja CEVAP VERILEMEZ — form 'teslim ediyor'
    sayilmazdi.
    """
    r = _gonder(client, email=None, telefon=None)
    assert r.status_code == 422, r.text


def test_COK_UZUN_DIL_KODU_semada_reddedilir(client):
    assert _gonder(client, dil="tr-TR-x-uydurma").status_code == 422


def test_BILINMEYEN_DIL_saklanmaz(client, world):
    mesaj = f"Dil testi {uuid.uuid4().hex[:8]}"
    # "tr-TR-x-uydurma" SEMA tarafindan zaten reddedilir (max_length=5) —
    # yani uzun deger 422 alir. Burada olculen sey UZUNLUK DEGIL, gecerli
    # uzunlukta ama BILINMEYEN bir dil kodunun saklanmamasi.
    assert _gonder(client, mesaj=mesaj, dil="xx").status_code == 201
    admin = _headers(client, world["slug_a"], world["admin_a"])
    kayit = next(
        x for x in client.get(
            "/tanitim-iletisim", headers=admin, params={"limit": 200}
        ).json()["items"] if x["mesaj"] == mesaj
    )
    assert kayit["dil"] is None


def test_okundu_isaretleme(client, world):
    mesaj = f"Okundu testi {uuid.uuid4().hex[:8]}"
    assert _gonder(client, mesaj=mesaj).status_code == 201
    admin = _headers(client, world["slug_a"], world["admin_a"])
    kayit = next(
        x for x in client.get(
            "/tanitim-iletisim", headers=admin, params={"limit": 200}
        ).json()["items"] if x["mesaj"] == mesaj
    )
    assert kayit["okundu"] is False
    r = client.patch(
        f"/tanitim-iletisim/{kayit['id']}", headers=admin, json={"okundu": True}
    )
    assert r.status_code == 200, r.text
    assert r.json()["okundu"] is True
    # Suzgec de calisiyor: okunmamislar arasinda ARTIK YOK.
    okunmamis = client.get(
        "/tanitim-iletisim", headers=admin, params={"okundu": False, "limit": 200}
    ).json()["items"]
    assert all(x["id"] != kayit["id"] for x in okunmamis)


# ------------------------- 2. OKUMA YALNIZ ADMIN --------------------------- #
@pytest.mark.parametrize(
    "kim", ["yonetici_a", "guard_a", "gorevli_a", "resident_a", "denetci_a", "amir_a"]
)
def test_listeyi_ADMIN_DISI_hicbir_rol_goremez(client, world, kim):
    h = _headers(client, world["slug_a"], world[kim])
    assert client.get("/tanitim-iletisim", headers=h).status_code == 403


def test_KIMLIKSIZ_istek_listeyi_goremez(client):
    """Gonderim public, OKUMA degil.

    Ayni ucun altinda olsalardi form dolduran biri butun adaylari
    okuyabilirdi — tablodaki her satir kisisel veridir.
    """
    assert client.get("/tanitim-iletisim").status_code in (401, 403)


# ---------------------- 3. app_rw TABLOYA ERISEMEZ ------------------------- #
def test_app_rolu_tabloyu_DOGRUDAN_okuyamaz(client, app_conn):
    """Tasarimin dayanagi: RLS acik + politika YOK.

    Once bir kayit atilir (fonksiyon uzerinden) — yoksa "0 satir gordum"
    sonucu tablonun BOS olmasindan da gelebilirdi ve test hicbir sey
    olcmezdi.
    """
    assert _gonder(client, mesaj=f"Izolasyon {uuid.uuid4().hex[:8]}").status_code == 201

    with app_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM tanitim_iletisim")
        assert cur.fetchone()[0] == 0, (
            "app_rw tanitim_iletisim satirlarini GORUYOR — politika yoklugu "
            "erisimi kapatmali"
        )


def test_app_rolu_tabloya_DOGRUDAN_yazamaz(app_conn):
    with app_conn.cursor() as cur:
        with pytest.raises(psycopg.errors.InsufficientPrivilege):
            cur.execute(
                "INSERT INTO tanitim_iletisim (ad, mesaj) VALUES ('x', 'y')"
            )


# ------------------------------ 4. HIZ SINIRI ------------------------------ #
def test_hiz_siniri_ayni_IPde_devreye_giriyor(client, redis_client):
    ip = f"10.77.{uuid.uuid4().int % 250}.{uuid.uuid4().int % 250}"
    redis_client.delete(f"tanitim_iletisim:{ip}")
    kodlar = [
        client.post(
            "/public/tanitim-iletisim",
            json={
                "ad": "Spam Bot",
                "email": "bot@ornek.com",
                "mesaj": "aynı mesaj tekrar tekrar",
            },
            headers={"X-Forwarded-For": ip},
        ).status_code
        for _ in range(7)
    ]
    assert kodlar[:5] == [201] * 5, kodlar
    assert kodlar[5:] == [429, 429], kodlar


def test_hiz_siniri_BASKA_IPyi_etkilemiyor(client, redis_client):
    """Sinir IP basinadir: bir ziyaretcinin doldurmasi otekini kilitlemez."""
    ip1 = f"10.78.{uuid.uuid4().int % 250}.1"
    ip2 = f"10.78.{uuid.uuid4().int % 250}.2"
    for k in (ip1, ip2):
        redis_client.delete(f"tanitim_iletisim:{k}")
    for _ in range(6):
        client.post(
            "/public/tanitim-iletisim",
            json={"ad": "Bot", "email": "b@o.com", "mesaj": "tekrar eden mesaj"},
            headers={"X-Forwarded-For": ip1},
        )
    r = client.post(
        "/public/tanitim-iletisim",
        json={"ad": "Gerçek Kişi", "email": "k@o.com", "mesaj": "Demo talebim var."},
        headers={"X-Forwarded-For": ip2},
    )
    assert r.status_code == 201, r.text
