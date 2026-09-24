"""(E2E 2026-09) TESIS-11 + TESIS-15 — saha cihazi hedef kapisi ve kopus izlemesi.

TESIS-11 OLCUMU: diyafon/kopru "baglanti testi" platformun kendi agini
tariyordu — `redis:6379`, `db:5432`, `minio:9000`, `api:8000` -> ok:true,
`localhost:1` -> ulasilamiyor. Tesis yoneticisinin elinde port tarayicisi.

TESIS-15 OLCUMU: beat isi yalniz `integration` tablosunu tariyordu;
diyafon ve akilli ev koprusunun kopusu hic bildirilmiyordu.
"""
from __future__ import annotations

import socket
import uuid

import pytest

from app.safe_http import saha_hedefi_engelli


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# ============================ KAPININ KENDISI ============================= #
@pytest.mark.parametrize(
    "host",
    ["redis", "db", "api", "minio", "localhost", "LOCALHOST.", "host.docker.internal",
     "metadata.google.internal", "169.254.169.254", "0.0.0.0", "[::1]",
     "2852039166", "::ffff:169.254.169.254", ""],
)
def test_IC_HEDEFLER_ENGELLI(host, monkeypatch):
    # Dev konteynerinde `SAHA_LOOPBACK_SERBEST=1` (sahte SIP/HA testleri
    # icin); bu birim testi PROD davranisini olcer.
    monkeypatch.setenv("SAHA_LOOPBACK_SERBEST", "0")
    assert saha_hedefi_engelli(host) is True, host


@pytest.mark.parametrize("host", ["192.168.1.50", "10.20.30.40", "172.16.5.5"])
def test_SITE_LAN_ADRESI_SERBEST(host):
    # Diyafon paneli ve HA kutusu sitenin yerel agindadir; RFC1918'i
    # kapatmak ozelligi oldururdu (P213 K3.2 ile ayni karar). NOT:
    # sunucunun KENDI bagli agina dusen bir adres (asagidaki test)
    # bu kuralin istisnasidir.
    from app.safe_http import _bagli_aglar
    import ipaddress

    if any(ipaddress.ip_address(host) in a for a in _bagli_aglar()):
        pytest.skip("bu ortamda adres sunucunun kendi agina dusuyor")
    assert saha_hedefi_engelli(host) is False


def test_SUNUCUNUN_KENDI_KONTEYNER_AGI_ENGELLI():
    """db/redis/minio'nun IP'leri konteynerin bagli aginda."""
    kendi = socket.gethostbyname(socket.gethostname())
    if kendi.startswith("127."):
        pytest.skip("konak adi loopback'e cozuluyor")
    assert saha_hedefi_engelli(kendi) is True


def test_LOOPBACK_YALNIZ_DEV_BAYRAGIYLA(monkeypatch):
    monkeypatch.delenv("SAHA_LOOPBACK_SERBEST", raising=False)
    assert saha_hedefi_engelli("127.0.0.1") is True
    monkeypatch.setenv("SAHA_LOOPBACK_SERBEST", "1")
    assert saha_hedefi_engelli("127.0.0.1") is False
    # Bayrak SERVIS ADLARINI acmaz — E2E'deki `localhost:8000` dev'de de red.
    assert saha_hedefi_engelli("localhost") is True
    assert saha_hedefi_engelli("redis") is True


# ============================ API: AYIRT EDILEMEZ ========================= #
def _diyafon(client, admin, **over):
    body = {"ad": f"D {uuid.uuid4().hex[:6]}", "yontem": "kuru_kontak",
            "host": "127.0.0.1", "port": 1, "zil_yolu": "/r1", "kapi_yolu": "/r2"}
    body.update(over)
    r = client.post("/diyafon", headers=admin, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def test_DIYAFON_IC_SERVISLERE_ULASAMAZ_ve_KAPALI_PORTTAN_AYIRT_EDILEMEZ(client, world):
    admin = _h(client, world["slug_a"], world["admin_a"])
    kapali = _diyafon(client, admin)  # 127.0.0.1:1 — kimse dinlemiyor
    referans = client.post(f"/diyafon/{kapali['id']}/saglik", headers=admin).json()
    assert referans["ok"] is False and referans["kod"] == "diyafon_ulasilamiyor"
    for host, port in (("redis", 6379), ("db", 5432), ("minio", 9000),
                       ("api", 8000), ("localhost", 8000)):
        d = _diyafon(client, admin, host=host, port=port)
        r = client.post(f"/diyafon/{d['id']}/saglik", headers=admin)
        assert r.status_code == 200, r.text
        assert r.json() == referans, (host, r.json())
        # Keyfi yollu GET de ic servise GITMEZ.
        z = client.post(f"/diyafon/{d['id']}/zil", headers=admin)
        assert z.json()["ok"] is False
        assert z.json()["kod"] == "diyafon_ulasilamiyor", (host, z.json())


def test_KOPRU_IC_SERVISE_ULASAMAZ(client, world):
    admin = _h(client, world["slug_a"], world["admin_a"])
    r = client.post("/akilli-ev/koprular", headers=admin, json={
        "ad": f"Hub {uuid.uuid4().hex[:6]}", "tur": "home_assistant",
        "host": "api", "port": 8000, "token": "x",
    })
    assert r.status_code == 201, r.text
    s = client.post(f"/akilli-ev/koprular/{r.json()['id']}/saglik", headers=admin)
    assert s.status_code == 200
    assert s.json()["ok"] is False
    assert s.json()["kod"] == "akilli_ev_ulasilamiyor"


# ======================== TESIS-15: KOPUS IZLEMESI ======================== #
def test_DIYAFON_KOPUSU_BEAT_ISINDE_BIR_KEZ_BILDIRILIR(client, world):
    from app.entegrasyon_kontrol_isi import tum_tenantlar_icin

    admin = _h(client, world["slug_a"], world["admin_a"])
    ad = f"Kopuk diyafon {uuid.uuid4().hex[:6]}"
    d = _diyafon(client, admin, ad=ad)

    def _sayi() -> int:
        items = client.get("/notifications", headers=admin,
                           params={"limit": 200}).json()["items"]
        return sum(
            1 for x in items
            if x.get("tip") == "entegrasyon_koptu"
            and ((x.get("mesaj_veri") or {}).get("ad") == ad
                 or ad in (x.get("mesaj") or ""))
        )

    once = _sayi()
    tum_tenantlar_icin()
    detay = client.get(f"/diyafon/{d['id']}", headers=admin).json()
    assert detay["saglik"] == "hata"
    assert detay["son_kontrol_at"] is not None
    assert _sayi() == once + 1, "diyafon kopusu bildirilmedi"
    tum_tenantlar_icin()
    assert _sayi() == once + 1, "ayni kopus IKINCI kez bildirilmemeli"


def test_PASIF_DIYAFON_IZLENMEZ(client, world):
    from app.entegrasyon_kontrol_isi import tum_tenantlar_icin

    admin = _h(client, world["slug_a"], world["admin_a"])
    d = _diyafon(client, admin, aktif=False)
    tum_tenantlar_icin()
    detay = client.get(f"/diyafon/{d['id']}", headers=admin).json()
    assert detay["saglik"] == "bilinmiyor"


def test_KOPRU_BAGLIYSA_SAGLIK_bagli_YAZILIR(client, world):
    from app.entegrasyon_kontrol_isi import tum_tenantlar_icin
    from tests.test_p240_akilli_ev import SahteHA

    ha = SahteHA(200)
    try:
        admin = _h(client, world["slug_a"], world["admin_a"])
        r = client.post("/akilli-ev/koprular", headers=admin, json={
            "ad": f"Hub {uuid.uuid4().hex[:6]}", "tur": "home_assistant",
            "host": "127.0.0.1", "port": ha.port, "token": "gizli",
        })
        assert r.status_code == 201, r.text
        tum_tenantlar_icin()
        koprular = client.get("/akilli-ev/koprular", headers=admin).json()
        k = next(x for x in koprular["items"] if x["id"] == r.json()["id"])
        assert k["saglik"] == "bagli"
        # SAGLIK CIHAZ CALISTIRMAZ: yalniz `GET /api/`.
        assert all(m == "GET" and y == "/api/" for m, y, _ in ha.istekler), ha.istekler
    finally:
        ha.kapat()
