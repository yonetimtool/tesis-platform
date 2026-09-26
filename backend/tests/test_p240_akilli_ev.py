"""(P240 §3) AKILLI EV — kopru, cihaz, bolum, senaryo, olay.

===========================================================================
EN KRITIK OLCUM: IDOR
===========================================================================
Istegin acik maddesi: "Sakin yalniz kendi dairesinin cihazlarini gorsun
ve kontrol etsin — bu bir guvenlik siniri, sunucuda zorla, IDOR testi
yaz." Bu dosyada UC ayri kapi olculuyor: liste, komut ve ortak alan.

GERCEK HUB YOK: testin icinde TAKLIT BIR HOME ASSISTANT sunucusu (HTTP)
acilir ve sunucumuz ona gercek istek gonderir. Iddia "HA REST API'sini
dogru konustum"; "bu hub surumunde calisiyor" DEGIL.
"""
from __future__ import annotations

import json
import socket
import threading
import uuid

import pytest


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


class SahteHA:
    """Minik Home Assistant taklidi: `/api/`, `/api/states/*`, `/api/services/*`."""

    def __init__(self, kod: int = 200) -> None:
        self.kod = kod
        self.istekler: list[tuple[str, str, str]] = []  # (metot, yol, govde)
        self.sok = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sok.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sok.bind(("127.0.0.1", 0))
        self.sok.listen(16)
        self.sok.settimeout(5)
        self.port = self.sok.getsockname()[1]
        self._calis = True
        threading.Thread(target=self._dongu, daemon=True).start()

    def _dongu(self) -> None:
        while self._calis:
            try:
                baglanti, _ = self.sok.accept()
            except socket.timeout:
                # (P248) BEKLEMEYE DEVAM: zaman asimi dongunun `_calis`
                # bayragini yoklamasi icindir, sunucuyu OLDURMEZ. Eskiden
                # `return` ediyordu: istek 5 sn'den gec gelirse (dev DB'de
                # binlerce tesisi dolasan `tum_tenantlar_icin` gibi) sahte
                # sunucu yok oluyor ve kopru "ulasilamiyor" aliyordu —
                # yuke bagli, koda bagli olmayan kirmizi.
                continue
            except OSError:
                return
            try:
                ham = baglanti.recv(8192).decode("utf-8", "replace")
                ilk = ham.split("\r\n", 1)[0]
                parcalar = ilk.split(" ")
                metot = parcalar[0] if parcalar else ""
                yol = parcalar[1] if len(parcalar) > 1 else ""
                govde = ham.split("\r\n\r\n", 1)[1] if "\r\n\r\n" in ham else ""
                self.istekler.append((metot, yol, govde))
                icerik = json.dumps({"state": "on"}).encode()
                baglanti.sendall(
                    f"HTTP/1.1 {self.kod} Test\r\n"
                    f"Content-Type: application/json\r\n"
                    f"Content-Length: {len(icerik)}\r\n\r\n".encode() + icerik
                )
            except OSError:
                pass
            finally:
                baglanti.close()

    def kapat(self) -> None:
        self._calis = False
        self.sok.close()


def _kopru(client, admin, **over):
    body = {
        "ad": f"Hub {uuid.uuid4().hex[:6]}",
        "tur": "home_assistant",
        "host": "127.0.0.1",
        "token": "gizli-jeton",
    }
    body.update(over)
    r = client.post("/akilli-ev/koprular", headers=admin, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def _cihaz(client, admin, kopru_id, **over):
    body = {
        "kopru_id": kopru_id,
        "ad": "Salon ışığı",
        "tip": "isik",
        "dis_kimlik": f"light.salon_{uuid.uuid4().hex[:6]}",
    }
    body.update(over)
    r = client.post("/akilli-ev/cihazlar", headers=admin, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def _bolum_ac(client, admin, *bolumler):
    r = client.put(
        "/akilli-ev/bolumler", headers=admin,
        json={"bolumler": [{"bolum": b, "acik": True} for b in bolumler]},
    )
    assert r.status_code == 200, r.text


@pytest.fixture
def evworld(client, world, owner_conn):
    """world + IKI daire: `daire` (resident_a bagli) ve `baska` (bos).

    `world` fixture'i daire YARATMAZ; IDOR olcumu icin sakinin GERCEKTEN
    bir daireye bagli olmasi sart — aksi halde "goremedi" sonucu bos
    listeden de gelebilirdi ve test hicbir sey kanitlamazdi.
    """
    a = world["a"]
    ek = uuid.uuid4().hex[:6]
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND email=%s "
            "AND role='resident'",
            (a, world["resident_a"]["email"]),
        )
        sakin_id = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO unit (tenant_id, no) VALUES (%s,%s),(%s,%s) "
            "RETURNING id",
            (a, f"EV1-{ek}", a, f"EV2-{ek}"),
        )
        daire, baska = (r[0] for r in cur.fetchall())
        cur.execute(
            "INSERT INTO unit_resident (tenant_id, unit_id, user_id) "
            "VALUES (%s,%s,%s)",
            (a, daire, sakin_id),
        )
    return {"daire": str(daire), "baska": str(baska)}


# ============================ KOPRU / JETON =============================== #
def test_JETON_YAZILIR_ama_ASLA_DONMEZ(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    k = _kopru(client, admin)
    assert k["token_set"] is True
    assert "token" not in k and "token_enc" not in k


def test_MQTT_SESSIZCE_HTTP_YE_DUSMEZ(client, world):
    # Sessiz dusus, MQTT sectigini sanan kullaniciya calismayan bir
    # kurulum vermek olurdu.
    admin = _headers(client, world["slug_a"], world["admin_a"])
    k = _kopru(client, admin, tur="mqtt")
    r = client.post(f"/akilli-ev/koprular/{k['id']}/saglik", headers=admin)
    assert r.status_code == 200
    assert r.json()["ok"] is False
    assert r.json()["kod"] == "akilli_ev_yapilandirma_eksik"


def test_SAGLIK_HA_API_UCUNU_CAGIRIR_cihaz_CALISTIRMAZ(client, world):
    ha = SahteHA(200)
    try:
        admin = _headers(client, world["slug_a"], world["admin_a"])
        k = _kopru(client, admin, port=ha.port)
        r = client.post(f"/akilli-ev/koprular/{k['id']}/saglik", headers=admin)
        assert r.status_code == 200 and r.json()["ok"] is True
    finally:
        ha.kapat()
    yollar = [y for _, y, _ in ha.istekler]
    assert yollar == ["/api/"], yollar
    # HICBIR SERVIS CAGRILMADI: saglik kontrolu cihaz calistirmaz.
    assert not any("/api/services/" in y for y in yollar)


def test_JETON_YALNIZ_BIR_KEZ_GORUNUR(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    k = _kopru(client, admin)
    r = client.post(f"/akilli-ev/koprular/{k['id']}/olay-jetonu", headers=admin)
    assert r.status_code == 200
    jeton = r.json()["olay_jetonu"]
    assert len(jeton) >= 32
    # Liste/detayda jeton DONMEZ (yalniz hash saklanir).
    liste = client.get("/akilli-ev/koprular", headers=admin).json()["items"]
    satir = next(x for x in liste if x["id"] == k["id"])
    assert "olay_jetonu" not in satir and "olay_jetonu_hash" not in satir


# ============================== IDOR ====================================== #
def test_IDOR_sakin_BASKA_DAIRENIN_cihazini_GOREMEZ(client, world, evworld):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    k = _kopru(client, admin)
    daire, baska = evworld["daire"], evworld["baska"]
    # (E2E 2026-09) TESIS-13: kapali bolumun cihazi sakine gorunmez —
    # isik `enerji` bolumunde; olcum IDOR icin, bolum acilir.
    _bolum_ac(client, admin, "enerji")

    benim = _cihaz(client, admin, k["id"], unit_id=daire)
    otekinin = _cihaz(client, admin, k["id"], unit_id=baska, ad="Komşu ışığı")
    ortak = _cihaz(client, admin, k["id"], ad="Bahçe", alan="Bahçe")

    gorulen = client.get("/akilli-ev/cihazlar", headers=sakin).json()["items"]
    idler = {c["id"] for c in gorulen}
    assert otekinin["id"] not in idler, "BASKA DAIRENIN cihazi GORUNMEMELI"
    # ORTAK ALAN da gorunmez: kazan dairesinin vanasi sakinin isi degil.
    assert ortak["id"] not in idler, "ORTAK ALAN cihazi sakine GORUNMEMELI"
    assert benim["id"] in idler, "KENDI dairesinin cihazi GORUNMELI"


def test_IDOR_sakin_BASKA_DAIRENIN_cihazina_KOMUT_VEREMEZ(client, world, evworld):
    """Asil IDOR kapisi: kimlik ELLE yazilsa bile burada durur.

    POZITIF KONTROL de var: ayni sakin KENDI dairesinin cihazini
    calistirabiliyor. Olmasaydi "her istege 403" veren bozuk bir uc da
    bu testi gecerdi.
    """
    ha = SahteHA(200)
    try:
        admin = _headers(client, world["slug_a"], world["admin_a"])
        sakin = _headers(client, world["slug_a"], world["resident_a"])
        k = _kopru(client, admin, port=ha.port)
        _bolum_ac(client, admin, "enerji")  # (E2E 2026-09) TESIS-13
        benim = _cihaz(client, admin, k["id"], unit_id=evworld["daire"])
        otekinin = _cihaz(
            client, admin, k["id"], unit_id=evworld["baska"], ad="Komsu",
        )

        r = client.post(
            f"/akilli-ev/cihazlar/{benim['id']}/komut",
            headers=sakin, json={"eylem": "ac"},
        )
        assert r.status_code == 200, r.text

        r = client.post(
            f"/akilli-ev/cihazlar/{otekinin['id']}/komut",
            headers=sakin, json={"eylem": "ac"},
        )
        assert r.status_code == 403, r.text
    finally:
        ha.kapat()


def test_IDOR_sakin_ORTAK_ALAN_cihazina_KOMUT_VEREMEZ(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    k = _kopru(client, admin)
    ortak = _cihaz(client, admin, k["id"], ad="Kazan vanası", tip="vana", alan="Kazan")
    r = client.post(
        f"/akilli-ev/cihazlar/{ortak['id']}/komut",
        headers=sakin, json={"eylem": "vana_kapat"},
    )
    assert r.status_code == 403, r.text


def test_CIHAZ_YAZMA_YALNIZ_YONETIM(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    k = _kopru(client, admin)
    for rol in ("guard_a", "resident_a", "gorevli_a"):
        h = _headers(client, world["slug_a"], world[rol])
        r = client.post(
            "/akilli-ev/cihazlar", headers=h,
            json={"kopru_id": k["id"], "ad": "X", "tip": "isik",
                  "dis_kimlik": "light.x"},
        )
        assert r.status_code == 403, rol


# =========================== TIP / EYLEM ================================== #
def test_SENSORE_KOMUT_VERILEMEZ(client, world):
    # Bir duman dedektorune "ac" demek anlamsizdir; hub 400 doner ve
    # kullanici NEDEN oldugunu anlamaz. Kapi BIZDE.
    admin = _headers(client, world["slug_a"], world["admin_a"])
    k = _kopru(client, admin)
    sensor = _cihaz(
        client, admin, k["id"], ad="Duman", tip="sensor_duman",
        dis_kimlik="binary_sensor.duman",
    )
    assert sensor["eylemler"] == []
    r = client.post(
        f"/akilli-ev/cihazlar/{sensor['id']}/komut",
        headers=admin, json={"eylem": "ac"},
    )
    assert r.status_code == 422


def test_EYLEM_LISTESI_YANITTA_DONER(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    k = _kopru(client, admin)
    isik = _cihaz(client, admin, k["id"])
    assert set(isik["eylemler"]) == {"ac", "kapat"}
    kilit = _cihaz(
        client, admin, k["id"], ad="Kapı", tip="kilit", dis_kimlik="lock.kapi"
    )
    assert kilit["eylemler"] == ["kilit_ac"]


def test_KOMUT_HA_SERVISINE_GIDER(client, world):
    ha = SahteHA(200)
    try:
        admin = _headers(client, world["slug_a"], world["admin_a"])
        k = _kopru(client, admin, port=ha.port)
        isik = _cihaz(client, admin, k["id"], dis_kimlik="light.salon")
        r = client.post(
            f"/akilli-ev/cihazlar/{isik['id']}/komut",
            headers=admin, json={"eylem": "ac"},
        )
        assert r.status_code == 200 and r.json()["ok"] is True
    finally:
        ha.kapat()
    metot, yol, govde = ha.istekler[-1]
    assert metot == "POST"
    assert yol == "/api/services/homeassistant/turn_on"
    assert json.loads(govde)["entity_id"] == "light.salon"


# ============================= BOLUMLER =================================== #
def test_BOLUMLER_VARSAYILAN_KAPALI_ve_TOPLU_YAZILIR(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.get("/akilli-ev/bolumler", headers=admin)
    assert r.status_code == 200
    bolumler = r.json()
    assert len(bolumler) == 9, "dokuz bolum"
    # YOKLUK = KAPALI: site yalniz sayac kullaniyorsa digerleri
    # gorunmesin.
    assert all(b["acik"] is False for b in bolumler)

    r = client.put(
        "/akilli-ev/bolumler", headers=admin,
        json={"bolumler": [{"bolum": "enerji", "acik": True},
                           {"bolum": "kacak", "acik": True}]},
    )
    assert r.status_code == 200, r.text
    acik = {b["bolum"] for b in r.json() if b["acik"]}
    assert acik == {"enerji", "kacak"}


def test_BOLUM_YAZMA_YALNIZ_YONETIM(client, world):
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    # Sakin OKUR (hangi bolumun acik oldugunu bilmeli) ama YAZAMAZ.
    assert client.get("/akilli-ev/bolumler", headers=sakin).status_code == 200
    r = client.put(
        "/akilli-ev/bolumler", headers=sakin,
        json={"bolumler": [{"bolum": "enerji", "acik": True}]},
    )
    assert r.status_code == 403


# ============================= SENARYOLAR ================================= #
def test_SENARYO_GECERSIZ_EYLEMI_KURULURKEN_REDDEDER(client, world):
    # Gecersiz bir eylem, ACIL DURUMDA sessizce calismayan bir senaryo
    # demekti — ve o an kimse hata mesaji okumuyor.
    admin = _headers(client, world["slug_a"], world["admin_a"])
    k = _kopru(client, admin)
    sensor = _cihaz(
        client, admin, k["id"], tip="sensor_su", dis_kimlik="binary_sensor.su"
    )
    r = client.post(
        "/akilli-ev/senaryolar", headers=admin,
        json={"olay": "su_kacagi", "cihaz_id": sensor["id"], "eylem": "ac"},
    )
    assert r.status_code == 422


def test_PANIK_SENARYOSU_CALISIR_ve_EYLEM_KODDA_SABIT_DEGIL(client, world):
    """Panik -> senaryo. Eylem VERIDEN gelir, koddan degil."""
    from app.tasks import panik_yayinla

    ha = SahteHA(200)
    try:
        admin = _headers(client, world["slug_a"], world["admin_a"])
        yon = _headers(client, world["slug_a"], world["yonetici_a"])
        k = _kopru(client, admin, port=ha.port)
        isik = _cihaz(client, admin, k["id"], dis_kimlik="light.ortak")
        r = client.post(
            "/akilli-ev/senaryolar", headers=admin,
            json={"olay": "panik_anons", "cihaz_id": isik["id"], "eylem": "ac"},
        )
        assert r.status_code == 201, r.text

        tid = client.get("/me", headers=admin).json()["tenant_id"]
        alarm = client.post(
            "/panik", headers=yon, json={"tip": "yonetici_anons"}
        ).json()
        panik_yayinla(alarm["id"], tid)

        servis = [y for m, y, _ in ha.istekler if m == "POST"]
        assert "/api/services/homeassistant/turn_on" in servis
    finally:
        ha.kapat()


def test_SENARYO_YOKKEN_PANIK_CALISIR(client, world):
    # Akilli ev yapilandirmasi olmayan tesiste panik AYNEN calisir.
    from app.tasks import panik_yayinla

    admin = _headers(client, world["slug_a"], world["admin_a"])
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    tid = client.get("/me", headers=admin).json()["tenant_id"]
    alarm = client.post("/panik", headers=yon, json={"tip": "guvenlik"}).json()
    sonuc = panik_yayinla(alarm["id"], tid)
    assert sonuc["durum"] == "acik" and sonuc["alici"] > 0


# =============================== OLAY ===================================== #
def test_OLAY_JETONU_GECERSIZSE_403(client, world):
    r = client.post(
        "/akilli-ev/olay",
        json={"olay_jetonu": "x" * 40, "dis_kimlik": "y", "olay": "su_kacagi"},
    )
    assert r.status_code == 403


def test_SU_KACAGI_SAKINE_ve_YONETIME_BILDIRIR_ve_SENARYO_CALISTIRIR(
    client, world, evworld
):
    ha = SahteHA(200)
    try:
        admin = _headers(client, world["slug_a"], world["admin_a"])
        sakin = _headers(client, world["slug_a"], world["resident_a"])
        k = _kopru(client, admin, port=ha.port)
        jeton = client.post(
            f"/akilli-ev/koprular/{k['id']}/olay-jetonu", headers=admin
        ).json()["olay_jetonu"]

        daire = evworld["daire"]
        sensor = _cihaz(
            client, admin, k["id"], ad="Mutfak su", tip="sensor_su",
            unit_id=daire, dis_kimlik="binary_sensor.mutfak_su",
        )
        vana = _cihaz(
            client, admin, k["id"], ad="Ana vana", tip="vana",
            unit_id=daire, dis_kimlik="switch.vana",
        )
        client.post(
            "/akilli-ev/senaryolar", headers=admin,
            json={"olay": "su_kacagi", "cihaz_id": vana["id"],
                  "eylem": "vana_kapat"},
        )

        r = client.post(
            "/akilli-ev/olay",
            json={"olay_jetonu": jeton, "dis_kimlik": "binary_sensor.mutfak_su",
                  "olay": "su_kacagi"},
        )
        assert r.status_code == 200, r.text
        assert r.json()["senaryo"] == 1, "vana senaryosu CALISMALI"
    finally:
        ha.kapat()

    # VANA GERCEKTEN KAPATILDI (HA servisine istek gitti).
    assert any(
        y == "/api/services/homeassistant/turn_off" for m, y, _ in ha.istekler
    )

    # YONETIM ALARMI YAZILDI (`user_id IS NULL`).
    bildirimler = client.get(
        "/notifications", headers=admin, params={"limit": 50}
    ).json()["items"]
    assert any(b.get("tip") == "akilli_ev_kacak" for b in bildirimler)
    # DAIRE SAKINI DE HABERDAR: kendi kisisel akisinda.
    sakin_bildirim = client.get(
        "/notifications", headers=sakin, params={"limit": 50}
    ).json()["items"]
    assert any(b.get("tip") == "akilli_ev_kacak" for b in sakin_bildirim)
