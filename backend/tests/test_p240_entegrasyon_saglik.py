"""(P240 §4) ENTEGRASYON SAGLIK KONTROLU.

===========================================================================
EN ONEMLI OLCUM: SAGLIK KONTROLU TETIKLEMEZ
===========================================================================
Kanallar `megaphone` (siteye anons) ve `smarthome` (kapi acan cihaz).
Periyodik olarak TETIKLEMEK, gunde 96 kez anons yapmak demekti. Bu
dosyanin ilk testi tam olarak bunu kilitler: saglik ucu hicbir HTTP
istegi GONDERMEZ.
"""
from __future__ import annotations

import uuid

from app.entegrasyon_saglik import (
    HATA_BAGLANTI,
    HATA_DNS,
    HATA_SSRF,
    baglanti_dene,
)

#: UC TESTLERINDE HIZLI DUSEN ADRES.
#:
#: `example.com:9` (discard portu) paketleri SESSIZCE DUSURUR: TCP
#: denemesi 5 sn zaman asimina kadar bekler ve test istemcisi O SIRADA
#: okuma zaman asimina ugrar (ilk yazimda tam bu oldu). `.invalid` ise
#: RFC 2606 geregi ASLA cozulmez — DNS hatasi ANINDA doner.
#:
#: Zaman asimini kisaltmak YANLIS COZUM olurdu: 5 sn saha cihazlari
#: (mobil hat arkasindaki diyafon) icin dogru olcu.
COZULMEYEN = "http://kopuk.gecersiz-alan-testi.invalid/hook"


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _mk(client, admin, **over):
    body = {
        "ad": f"Entegrasyon {uuid.uuid4().hex[:6]}",
        "endpoint_url": "https://example.com/hook",
        "payload_template": '{"text": "{{message}}"}',
    }
    body.update(over)
    r = client.post("/integrations", headers=admin, json=body)
    assert r.status_code == 201, r.text
    return r.json()


# ===================== SAGLIK KONTROLU TETIKLEMEZ ========================= #
def test_SAGLIK_KONTROLU_HTTP_ISTEGI_GONDERMEZ(monkeypatch=None):
    """(P240 §4) `baglanti_dene` SADECE TCP acar.

    Kaynak taramasi: modulde `send_webhook`/`httpx` CAGRISI OLMAMALI.
    Bir sonraki gelistirici "test istegi de atalim" derse, megafon
    gunde 96 kez anons yapardi ve bunu hicbir akis testi gormezdi.
    """
    from pathlib import Path

    kaynak = Path(__file__).resolve().parents[1] / "app" / "entegrasyon_saglik.py"
    metin = kaynak.read_text(encoding="utf-8")
    for yasak in ("send_webhook", "httpx", "requests."):
        assert yasak not in metin, f"saglik kontrolu {yasak} KULLANMAMALI"
    # TCP baglantisi ACIKCA kullanilir.
    assert "socket.create_connection" in metin


def test_BEAT_GOREVI_DE_TETIKLEMEZ():
    from pathlib import Path

    kaynak = (
        Path(__file__).resolve().parents[1] / "app" / "entegrasyon_kontrol_isi.py"
    )
    metin = kaynak.read_text(encoding="utf-8")
    assert "send_webhook" not in metin
    assert "trigger" not in metin.lower().replace("tetikle", "")


# ============================ BAGLANTI DENEMESI =========================== #
def test_IC_AG_ADRESI_SSRF_KIMLIGIYLE_REDDEDILIR():
    # SSRF engeli bir AG hatasi degil YAPILANDIRMA hatasidir; "baglanti
    # yok" demek kullaniciyi aga bakmaya gonderirdi.
    s = baglanti_dene("http://127.0.0.1:1/x")
    assert s.bagli is False
    assert s.hata_kod == HATA_SSRF


def test_KAPALI_PORT_BAGLANTI_YOK_kimligi_doner():
    # example.com 9 numarali porttan (discard) yanit vermez; SSRF kapisi
    # gecilir ama TCP acilmaz.
    s = baglanti_dene("http://example.com:9/x", zaman_asimi=3)
    assert s.bagli is False
    assert s.hata_kod == HATA_BAGLANTI


# ============================== UC (API) ================================== #
def test_saglik_ucu_durumu_YAZAR(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    ent = _mk(client, admin, endpoint_url=COZULMEYEN)

    # YENI ENTEGRASYON `bilinmiyor` — "henuz olculmedi" ile "kopuk" AYNI
    # sey degil; yeni tanimi kirmizi gostermek olmayan bir sorun bildirmek.
    assert ent["saglik"] == "bilinmiyor"
    assert ent["son_kontrol_at"] is None

    r = client.post(f"/integrations/{ent['id']}/saglik", headers=admin)
    assert r.status_code == 200, r.text
    assert r.json()["saglik"] == "hata"
    assert r.json()["son_hata_kod"] == HATA_DNS
    assert r.json()["son_kontrol_at"] is not None

    # LISTEDE DE GORUNUR: panel tek ekrandan hepsini gorebilmeli.
    liste = client.get("/integrations", headers=admin).json()["items"]
    satir = next(x for x in liste if x["id"] == ent["id"])
    assert satir["saglik"] == "hata"
    assert satir["son_hata_kod"] == HATA_DNS


def test_HAM_AYRINTI_ISTEMCIYE_DONMEZ(client, world):
    # `son_hata_ayrinti` operatore hitap eder ve ic ayrinti (istisna tipi,
    # sunucu adi) sizdirir; arayuz KIMLIK alir ve kendi dilinde metne
    # cevirir.
    admin = _headers(client, world["slug_a"], world["admin_a"])
    ent = _mk(client, admin, endpoint_url=COZULMEYEN)
    client.post(f"/integrations/{ent['id']}/saglik", headers=admin)
    govde = client.get(f"/integrations/{ent['id']}", headers=admin).json()
    assert "son_hata_ayrinti" not in govde


def test_saglik_ucu_YALNIZ_YONETIM(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    ent = _mk(client, admin)
    for rol in ("guard_a", "resident_a", "gorevli_a"):
        h = _headers(client, world["slug_a"], world[rol])
        r = client.post(f"/integrations/{ent['id']}/saglik", headers=h)
        assert r.status_code == 403, rol


def test_GERCEK_TETIK_DE_SAGLIGI_YAZAR(client, world):
    # `son_basarili_at`i yalniz saglik kontrolu guncelleseydi, dakikalar
    # once GERCEKTEN calismis bir entegrasyon "uzun suredir iletisim yok"
    # gorunurdu.
    admin = _headers(client, world["slug_a"], world["admin_a"])
    ent = _mk(client, admin, endpoint_url="http://127.0.0.1:1/x")
    r = client.post(
        f"/integrations/{ent['id']}/trigger", headers=admin, json={"message": "x"}
    )
    assert r.status_code == 200
    assert r.json()["ok"] is False
    govde = client.get(f"/integrations/{ent['id']}", headers=admin).json()
    assert govde["saglik"] == "hata"
    assert govde["son_kontrol_at"] is not None


def test_KOPUS_BILDIRIMI_BIR_KEZ(client, world):
    """Damga olmadan 15 dakikada bir kosan gorev GUNDE 96 bildirim atardi."""
    from app.entegrasyon_kontrol_isi import tum_tenantlar_icin

    admin = _headers(client, world["slug_a"], world["admin_a"])
    _mk(client, admin, endpoint_url=COZULMEYEN)

    def _bildirim_sayisi() -> int:
        r = client.get("/notifications", headers=admin, params={"limit": 200})
        return sum(
            1 for x in r.json()["items"] if x.get("tip") == "entegrasyon_koptu"
        )

    once = _bildirim_sayisi()
    tum_tenantlar_icin()
    sonra_1 = _bildirim_sayisi()
    assert sonra_1 > once, "ilk kopusta bildirim GITMELI"

    tum_tenantlar_icin()
    assert _bildirim_sayisi() == sonra_1, "ayni kopus IKINCI kez bildirilmemeli"


def test_PASIF_ENTEGRASYON_KONTROL_EDILMEZ(client, world):
    # `aktif=false` bilincli bir karardir; "kopuk" demek kullanicinin
    # kendi kararini hata gibi gostermek olurdu.
    from app.entegrasyon_kontrol_isi import tum_tenantlar_icin

    admin = _headers(client, world["slug_a"], world["admin_a"])
    ent = _mk(client, admin, endpoint_url=COZULMEYEN, aktif=False)
    tum_tenantlar_icin()
    govde = client.get(f"/integrations/{ent['id']}", headers=admin).json()
    assert govde["saglik"] == "bilinmiyor"
