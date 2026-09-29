"""(P249 §1) SOS — ALICININ GORDUGU olculur, gonderenin yazdigi degil.

===========================================================================
NEDEN BU DOSYA VAR
===========================================================================
P243'te kategori testleri GONDEREN ucu (istek govdesi) ve VERITABANINI
(bildirim satiri) olctu; alarmi ALAN kisinin ekranini hic olcmedi. Mobil
modelde `kategori` alani yoktu ve bu hicbir kirmizi uretmedi. Buradaki her
test alicinin eline gecen seyi olcer: yanit govdesi (istegin dilinde
baslik + talimat), FCM govdesinin KENDISI, alici kumesinin tercihi asip
asmadigi.
"""
from __future__ import annotations

import uuid

import pytest


def _h(client, slug, cred, dil: str | None = None):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    h = {"Authorization": f"Bearer {r.json()['access_token']}"}
    if dil:
        h["Accept-Language"] = dil
    return h


def _uid(client, h):
    return client.get("/me", headers=h).json()["id"]


def _yayinla(client, admin, alarm_id):
    from app.tasks import panik_yayinla

    tid = client.get("/me", headers=admin).json()["tenant_id"]
    panik_yayinla(alarm_id, tid)


@pytest.fixture
def ortam(client, world):
    return {
        "admin": _h(client, world["slug_a"], world["admin_a"]),
        "sakin": _h(client, world["slug_a"], world["resident_a"]),
        "guard": _h(client, world["slug_a"], world["guard_a"]),
    }


@pytest.fixture
def alarm_ac(client, ortam):
    """Alarm acar, yayinlar; test bitince KAPATIR.

    KAPATMAK SART: ayni kisinin ayni tipte acik alarmi varken tekrar basmak
    YENI alarm uretmez (P240 kurali) — kapatilmazsa sonraki test baska
    kategorideki eski alarmi geri alirdi.
    """
    acilan: list[str] = []

    def ac(tip: str, kategori: str | None, kim: str = "admin"):
        govde = {"tip": tip}
        if kategori:
            govde["kategori"] = kategori
        r = client.post("/panik", headers=ortam[kim], json=govde)
        assert r.status_code == 201, r.text
        a = r.json()
        _yayinla(client, ortam["admin"], a["id"])
        acilan.append(a["id"])
        return a

    yield ac
    for aid in acilan:
        client.post(f"/panik/{aid}/kapat", headers=ortam["admin"], json={})


# ====================== METIN: KIM ve NEREDE GERI GELDI =================== #
def test_YARDIM_CAGRISI_BILDIRIMI_KIM_ve_NEREDE_SOYLER():
    """P243 kusuru: saglik bildirimi hangi dairede oldugunu SOYLEMIYORDU."""
    from app.push_metinleri import push_basligi, push_govdesi

    for k in ("saglik", "guvenlik_tehdidi", "diger"):
        g = push_govdesi(f"panik_kategori_{k}", "tr", {"ad": "Ayşe", "yer": "B-12"})
        assert "Ayşe" in g and "B-12" in g, (k, g)
    assert push_basligi("panik_kategori_deprem", "tr") == "DEPREM ALARMI"
    assert push_basligi("panik_kategori_deprem", "en") == "EARTHQUAKE ALERT"


def test_TOPLU_UYARI_BILDIRIMI_TALIMATLA_BASLAR_ve_YERI_TASIR():
    from app.push_metinleri import push_govdesi

    g = push_govdesi("panik_kategori_deprem", "tr", {"yer": "Güneş Sitesi"})
    assert g.startswith("Çök, kapan, tutun"), g
    assert g.endswith("Güneş Sitesi"), g


def test_TATBIKAT_HER_DILDE_BASLIKTA_ve_GOVDEDE():
    from app.push_metinleri import METINLER

    from .test_push_i18n import DILLER

    isaret = {"tr": "TATBİKAT", "en": "DRILL", "de": "ÜBUNG", "fr": "EXERCICE",
              "es": "SIMULACRO", "ar": "تمرين", "ru": "УЧЕНИЯ"}
    for k in ("deprem", "yangin", "gaz", "tahliye"):
        m = METINLER[f"panik_tatbikat_{k}"]
        for dil in DILLER:
            assert m.baslik[dil].startswith(isaret[dil]), (k, dil, m.baslik[dil])
    assert "tatbikat" in METINLER["panik_tatbikat_deprem"].govde["tr"].lower()


# ============================ KANAL ve FCM GOVDESI ======================== #
def test_ALARM_KENDI_KANALINDAN_ve_SESI_KAPALI_OLSA_DA_SESLI():
    from app.push_kanal import KANAL_ALARM, KANAL_SESSIZ, kanal_sec, ses_adi

    for kimlik in ("panik_alarm", "panik_kategori_deprem",
                   "panik_tatbikat_yangin", "panik_yardim_talebi"):
        assert kanal_sec(kimlik, sesli=False) == KANAL_ALARM, kimlik
        assert ses_adi(kimlik, sesli=False) is not None, kimlik
    # Sonuc bildirimleri alarm DEGIL — dongulu alarm sesiyle calmazlar.
    assert kanal_sec("panik_kapandi", sesli=False) == KANAL_SESSIZ


def _msg(g, title="DEPREM ALARMI", body="Çök — X"):
    return {
        "token": "t", "notification": {"title": title, "body": body},
        "data": {"tip": "panik_alarm", "panik_id": "p1"},
        "android": {"priority": "high", "notification": {"channel_id": "c"}},
        "apns": {"payload": {"aps": {"sound": "default"}}},
    }


def test_ANDROID_YENI_SURUM_YEREL_ALARM_ALIR_notification_YOK():
    """Sistemin cizdigi bildirim tam ekran acamaz ve 'Gordum'de susmaz."""
    from app.push import gorunumu_uygula
    from app.push_gorunum import gorunum_kur

    g = gorunum_kur("panik_kategori_deprem", tenant_id="t", kaynak="Site",
                    data={"panik_id": "p1"}, yerel_alarm=True)
    m = _msg(g)
    gorunumu_uygula(m, g, "t", title="DEPREM ALARMI")
    assert "notification" not in m
    assert "apns" not in m
    assert m["android"]["priority"] == "high"
    assert m["data"]["yerel_alarm"] == "1"
    assert m["data"]["baslik"].startswith("DEPREM ALARMI")
    assert m["data"]["govde"] == "Çök — X"
    assert m["data"]["etiket"] == "acil:p1"


def test_IOS_KRITIK_IZINLI_CIHAZA_KRITIK_SES():
    from app.push import gorunumu_uygula
    from app.push_gorunum import gorunum_kur

    g = gorunum_kur("panik_kategori_yangin", tenant_id="t", kaynak=None,
                    data={"panik_id": "p1"}, kritik=True)
    m = _msg(g)
    gorunumu_uygula(m, g, "t", title="YANGIN ALARMI")
    aps = m["apns"]["payload"]["aps"]
    assert aps["interruption-level"] == "critical"
    assert aps["sound"] == {"critical": 1, "name": "default", "volume": 1.0}
    # Izinsiz cihaz: time-sensitive (yetki dosyasinda var) — KRITIK DEGIL.
    g2 = gorunum_kur("panik_kategori_yangin", tenant_id="t", kaynak=None,
                     data={"panik_id": "p1"})
    m2 = _msg(g2)
    gorunumu_uygula(m2, g2, "t", title="YANGIN ALARMI")
    assert m2["apns"]["payload"]["aps"]["interruption-level"] == "time-sensitive"
    assert m2["apns"]["payload"]["aps"]["sound"] == "default"


def test_SURUM_ESIGI():
    from app.push_gorunum import surum_en_az

    assert surum_en_az("1.8.0") and surum_en_az("1.10.2") and surum_en_az("2.0.0+19")
    assert not surum_en_az("1.7.0") and not surum_en_az(None)
    assert not surum_en_az("bozuk")


# ================ TERCIH SOS'U SUSTURAMAZ (olculen kopukluk 1) ============ #
def test_MOBIL_BILDIRIMI_KAPALI_SAKINE_DE_DEPREM_PUSHU_DENENIR(
    client, world, ortam, alarm_ac, owner_conn
):
    sakin_id = _uid(client, ortam["sakin"])
    jeton = f"p249-{uuid.uuid4().hex}"
    r = client.post("/devices", headers=ortam["sakin"],
                    json={"fcm_token": jeton, "platform": "android",
                          "uygulama_surum": "1.8.0"})
    assert r.status_code == 201, r.text
    client.patch("/me/bildirim-tercihleri", headers=ortam["sakin"],
                 json={"bildirim_mobil": False})
    try:
        with owner_conn.cursor() as cur:
            cur.execute("SELECT bildirim_mobil FROM app_user WHERE id=%s", (sakin_id,))
            assert cur.fetchone()[0] is False, "tercih kapatilamadi"
        a = alarm_ac("yonetici_anons", "deprem")
        with owner_conn.cursor() as cur:
            cur.execute(
                "SELECT durum FROM push_gonderim WHERE user_id=%s "
                "AND token_son6=%s AND kimlik='panik_kategori_deprem'",
                (sakin_id, jeton[-6:]),
            )
            satirlar = cur.fetchall()
        assert satirlar, (
            "mobil bildirimi kapali sakine deprem push'u HIC denenmedi — "
            "tercih alarmi susturuyor"
        )
        assert a["id"]
    finally:
        client.patch("/me/bildirim-tercihleri", headers=ortam["sakin"],
                     json={"bildirim_mobil": True})
        client.delete(f"/devices/{jeton}", headers=ortam["sakin"])


# ======================= ALICI EKRANI — IKI DENEYIM ======================= #
def test_TOPLU_UYARI_ALICIYA_BASLIK_ve_ADIM_ADIM_TALIMAT(client, ortam, alarm_ac):
    a = alarm_ac("yonetici_anons", "deprem")
    d = client.get(f"/panik/{a['id']}", headers=ortam["sakin"]).json()
    assert d["kategori"] == "deprem"
    assert d["toplu"] is True
    assert d["baslik"] == "DEPREM ALARMI"
    assert len(d["talimat"]) >= 4
    assert "ÇÖK" in d["talimat"][0]
    # AYNI alarm INGILIZCE istenince INGILIZCE — tek kaynak, istegin dili.
    en = {**ortam["sakin"], "Accept-Language": "en"}
    d2 = client.get(f"/panik/{a['id']}", headers=en).json()
    assert d2["baslik"] == "EARTHQUAKE ALERT"
    assert "DROP" in d2["talimat"][0]


def test_YARDIM_CAGRISI_KISA_TALIMAT_ve_TOPLU_DEGIL(client, ortam, alarm_ac):
    a = alarm_ac("guvenlik", "saglik")
    d = client.get(f"/panik/{a['id']}", headers=ortam["guard"]).json()
    assert d["toplu"] is False
    assert d["baslik"] == "SAĞLIK ACİLİ"
    assert len(d["talimat"]) == 1 and "112" in d["talimat"][0]


def test_YANLIS_ALARM_SAYACI_SAKINDE_YOK_TOPLU_UYARIDA_YOK(client, ortam, alarm_ac):
    # Yoneticinin bugunku yanlis alarmi (gonderilmeden iptal).
    r = client.post("/panik", headers=ortam["admin"],
                    json={"tip": "yonetici_anons", "kategori": "deprem"})
    client.post(f"/panik/{r.json()['id']}/iptal", headers=ortam["admin"])

    a = alarm_ac("yonetici_anons", "deprem")
    for kim in ("sakin", "guard"):
        d = client.get(f"/panik/{a['id']}", headers=ortam[kim]).json()
        assert d["son_24s_yanlis_alarm"] == 0, (kim, "toplu uyarida sayac YOK")

    # Yardim cagrisinda GUVENLIK sayaci gorur.
    r = client.post("/panik", headers=ortam["admin"],
                    json={"tip": "guvenlik", "kategori": "saglik"})
    client.post(f"/panik/{r.json()['id']}/iptal", headers=ortam["admin"])
    b = alarm_ac("guvenlik", "saglik")
    assert client.get(f"/panik/{b['id']}", headers=ortam["guard"]).json()[
        "son_24s_yanlis_alarm"] >= 1


def test_SAKIN_OTEKI_ALICILARIN_LISTESINI_GORMEZ(client, ortam, alarm_ac):
    a = alarm_ac("yonetici_anons", "tahliye")
    d = client.get(f"/panik/{a['id']}", headers=ortam["sakin"]).json()
    assert d["alicilar"] == [], "deprem alarmi acan sakin sitedeki herkesin adini goruyordu"
    y = client.get(f"/panik/{a['id']}", headers=ortam["admin"]).json()
    assert y["alicilar"], "yonetim listeyi gormeli"


# ======================== GUVENDEYIM / YARDIM / DURUM ===================== #
def test_GUVENDEYIM_EKRANI_KAPATIR_ve_DURUMDA_GORUNUR(client, ortam, alarm_ac):
    a = alarm_ac("yonetici_anons", "deprem")
    aktif = client.get("/panik/aktif", headers=ortam["sakin"]).json()
    assert any(x["id"] == a["id"] for x in aktif)

    r = client.post(f"/panik/{a['id']}/guvendeyim", headers=ortam["sakin"])
    assert r.status_code == 200, r.text
    assert r.json()["benim_yanitim"] == "guvende"
    aktif = client.get("/panik/aktif", headers=ortam["sakin"]).json()
    assert all(x["id"] != a["id"] for x in aktif), "yanit tam ekrani KAPATMALI"

    durum = client.get(f"/panik/{a['id']}/durum", headers=ortam["admin"]).json()
    assert durum["guvende"] >= 1
    assert durum["yanitsiz"] == durum["alici"] - durum["guvende"] - durum["yardim"]
    sakin_id = _uid(client, ortam["sakin"])
    kisiler = [k for d in durum["daireler"] for k in d["kisiler"]] + durum["personel"]
    assert any(k["user_id"] == sakin_id and k["yanit"] == "guvende" for k in kisiler)


def test_YARDIM_ISTEYEN_GUVENLIGE_KENDI_BILDIRIMIYLE_GIDER(client, ortam, alarm_ac):
    a = alarm_ac("yonetici_anons", "yangin")
    r = client.post(f"/panik/{a['id']}/yardim", headers=ortam["sakin"])
    assert r.status_code == 200, r.text
    assert r.json()["benim_yanitim"] == "yardim"
    b = client.get("/notifications", headers=ortam["guard"], params={"limit": 20}).json()
    assert any(x["tip"] == "panik_yardim_talebi" for x in b["items"]), (
        "yardim isteyen sakin guvenlige DUYURULMALI"
    )
    durum = client.get(f"/panik/{a['id']}/durum", headers=ortam["admin"]).json()
    assert durum["yardim"] >= 1
    # YARDIM once gelir (yoneticinin gozu once oraya gitmeli).
    if durum["daireler"]:
        assert durum["daireler"][0]["durum"] in ("yardim", "yanitsiz", "guvende")


def test_YARDIM_CAGRISINDA_GUVENDEYIM_YOK(client, ortam, alarm_ac):
    a = alarm_ac("guvenlik", "saglik")
    r = client.post(f"/panik/{a['id']}/guvendeyim", headers=ortam["guard"])
    assert r.status_code == 409
    assert r.json()["error"]["code"] == "conflict"


def test_DURUMU_SAKIN_GOREMEZ(client, ortam, alarm_ac):
    a = alarm_ac("yonetici_anons", "gaz")
    r = client.get(f"/panik/{a['id']}/durum", headers=ortam["sakin"])
    assert r.status_code == 403


def test_ALICI_OLMAYAN_GUVENDEYIM_DIYEMEZ(client, world, alarm_ac):
    a = alarm_ac("yonetici_anons", "deprem")
    admin_id_h = _h(client, world["slug_a"], world["admin_a"])
    # Tetikleyen kendi alarminin alicisi degil.
    r = client.post(f"/panik/{a['id']}/guvendeyim", headers=admin_id_h)
    assert r.status_code == 403


# =========================== CIHAZ: KRITIK UYARI ========================== #
def test_KRITIK_UYARI_IZNI_KAYDEDILIR_ve_GONDERILMEYINCE_KORUNUR(
    client, ortam, owner_conn
):
    jeton = f"p249k-{uuid.uuid4().hex}"
    try:
        r = client.post("/devices", headers=ortam["guard"],
                        json={"fcm_token": jeton, "platform": "ios",
                              "kritik_uyari": True})
        assert r.status_code == 201, r.text
        client.post("/devices", headers=ortam["guard"],
                    json={"fcm_token": jeton, "platform": "ios"})
        with owner_conn.cursor() as cur:
            cur.execute("SELECT kritik_uyari FROM user_device WHERE fcm_token=%s",
                        (jeton,))
            assert cur.fetchone()[0] is True
    finally:
        client.delete(f"/devices/{jeton}", headers=ortam["guard"])
