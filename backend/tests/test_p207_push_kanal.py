"""(P207 §2) BILDIRIM KANALI VE SESI.

===========================================================================
OLCULEN KUSUR
===========================================================================
FCM govdesi yalnizca `notification{title, body}` + `data` tasiyordu:
Android 8'den beri bildirimin SESI KANALIN ozelligidir ve kanal
belirtilmeyen bildirim, tanimli olmayan varsayilan kanala duserdi.
iOS'ta `aps.sound` HIC gonderilmiyordu. Yani sessizlik bir ayar degil,
EKSIKTI.

===========================================================================
EN KRITIK KILIT: KANAL KIMLIKLERI SUNUCU ILE MOBILDE AYNI
===========================================================================
Kimlikler ayrisirsa sunucu VAR OLMAYAN bir kanala gonderir; bildirim
GORUNUR ama SESSIZ olur — yani kusur ancak sahada, "sesli gelmesi
gereken bildirim gelmedi" diye fark edilir. Bu dosya `MainActivity.kt`i
OKUYUP karsilastirir.
"""
from __future__ import annotations

import pathlib

import pytest

from app.push_kanal import (
    KANAL_GENEL,
    KANAL_KRITIK,
    KANAL_SESSIZ,
    KRITIK_TIPLER,
    kanal_sec,
    ses_adi,
)

_MOBIL = pathlib.Path(
    "/app/tests/.."
)  # (varsayilan; asagida gercek yol aranir)


def _mobil_kaynak(ad: str) -> str | None:
    """Mobil kaynagi ara — depo ici koşumda VAR, konteynerde OLMAYABILIR.

    Konteynerde yoksa test ATLANIR ve bunu ACIKCA soyler: "kilit yok"
    ile "kilit gecti" ayni sey degil.
    """
    for kok in (
        pathlib.Path("/mobile"),
        pathlib.Path(__file__).resolve().parents[2] / "mobile",
    ):
        yol = kok / ad
        if yol.exists():
            return yol.read_text(encoding="utf-8")
    return None


# ===================== 1) KANAL SECIMI ===================================== #

def test_KRITIK_TIPLER_kritik_kanaldan_gider():
    """Istegin acik sarti: sikayet ve vardiya hatirlatmalari SESLI."""
    assert "yeni_talep" in KRITIK_TIPLER
    assert "vardiya_hatirlatma" in KRITIK_TIPLER
    assert kanal_sec("yeni_talep", sesli=True) == KANAL_KRITIK
    assert kanal_sec("vardiya_hatirlatma", sesli=True) == KANAL_KRITIK


def test_SIRADAN_bildirim_genel_kanaldan_gider():
    assert kanal_sec("duyuru", sesli=True) == KANAL_GENEL
    assert kanal_sec(None, sesli=True) == KANAL_GENEL


def test_SES_KAPALIYSA_KRITIK_bile_sessiz_kanaldan_gider():
    """Tercihi gormezden gelmek "kapattim ama caliyor" demekti — ve
    kullanici bir dahaki sefere bildirimlerin TAMAMINI kapatirdi."""
    assert kanal_sec("yeni_talep", sesli=False) == KANAL_SESSIZ
    assert kanal_sec("duyuru", sesli=False) == KANAL_SESSIZ
    assert ses_adi("yeni_talep", sesli=False) is None


def test_SES_ADI_dosya_yokken_SISTEM_sesi():
    """"Ses yok" ile "ozel ses yok" ayni sey degil: dosya gelene kadar
    sistem sesi calar."""
    assert ses_adi("yeni_talep", sesli=True) == "default"


# ============== 2) KIMLIKLER MOBILLE AYNI (EN KRITIK KILIT) ================ #

def test_KANAL_KIMLIKLERI_MOBILLE_AYNI():
    kaynak = _mobil_kaynak(
        "android/app/src/main/kotlin/com/app/yonetiyor/MainActivity.kt"
    )
    if kaynak is None:
        pytest.skip("mobil kaynak bu koşumda yok (konteyner) — kilit ATLANDI")
    for kimlik in (KANAL_KRITIK, KANAL_GENEL, KANAL_SESSIZ):
        assert f'"{kimlik}"' in kaynak, f"{kimlik} MainActivity.kt'te yok"


def test_MANIFEST_VARSAYILAN_KANALI_GENEL():
    """Sunucu `channel_id` gondermezse (eski surum, teshis ucu) bildirim
    Android'in isimsiz varsayilan kanalina duserdi ve SESSIZ olurdu."""
    kaynak = _mobil_kaynak("android/app/src/main/AndroidManifest.xml")
    if kaynak is None:
        pytest.skip("mobil kaynak bu koşumda yok (konteyner) — kilit ATLANDI")
    assert "default_notification_channel_id" in kaynak
    assert KANAL_GENEL in kaynak


# ===================== 3) FCM GOVDESI ====================================== #

def test_FCM_GOVDESI_kanal_ve_ses_tasir(monkeypatch):
    """Govdenin KENDISI olculuyor: `android.notification.channel_id` ve
    `apns.payload.aps.sound`."""
    from app import push

    gonderilenler: list[dict] = []

    def sahte_post(url, headers, body):
        gonderilenler.append(body)
        return {}

    monkeypatch.setattr(push, "_load_service_account", lambda: {"project_id": "p"})
    monkeypatch.setattr(push, "_fetch_access_token", lambda sa: "t")
    monkeypatch.setattr(push, "_http_post_json", sahte_post)

    push.FcmProvider().send(
        ["tok-1"], title="B", body="G", data={"tip": "yeni_talep"},
        kanal=KANAL_KRITIK, ses="default",
    )
    msg = gonderilenler[0]["message"]
    assert msg["android"]["notification"]["channel_id"] == KANAL_KRITIK
    # KRITIK BILDIRIMDE `high`: Android dusuk oncelikli mesajlari Doze
    # modunda TOPLAYIP geciktirir; "vardiyaniza 5 dakika" bildiriminin
    # gecikmesi onu ANLAMSIZ yapardi.
    assert msg["android"]["priority"] == "high"
    assert msg["apns"]["payload"]["aps"]["sound"] == "default"


def test_SESSIZ_GONDERIMDE_apns_sound_YOK(monkeypatch):
    from app import push

    gonderilenler: list[dict] = []
    monkeypatch.setattr(push, "_load_service_account", lambda: {"project_id": "p"})
    monkeypatch.setattr(push, "_fetch_access_token", lambda sa: "t")
    monkeypatch.setattr(
        push, "_http_post_json", lambda u, h, b: gonderilenler.append(b) or {}
    )

    push.FcmProvider().send(
        ["tok-1"], title="B", body="G", kanal=KANAL_SESSIZ, ses=None,
    )
    msg = gonderilenler[0]["message"]
    assert msg["android"]["notification"]["channel_id"] == KANAL_SESSIZ
    assert msg["android"]["priority"] == "normal"
    # `aps.sound` HIC GONDERILMEZ: "default" gondermek sessiz kanalda
    # iOS'u caldirirdi.
    assert "apns" not in msg


def test_ESKI_CAGIRAN_kanalsiz_da_calisir(monkeypatch):
    """Teshis ucu ve testler `kanal` gondermeden cagiriyor; govde
    kirilmamali (o durumda manifest varsayilani devreye girer)."""
    from app import push

    gonderilenler: list[dict] = []
    monkeypatch.setattr(push, "_load_service_account", lambda: {"project_id": "p"})
    monkeypatch.setattr(push, "_fetch_access_token", lambda sa: "t")
    monkeypatch.setattr(
        push, "_http_post_json", lambda u, h, b: gonderilenler.append(b) or {}
    )

    push.FcmProvider().send(["tok-1"], title="B", body="G")
    msg = gonderilenler[0]["message"]
    assert "android" not in msg and "apns" not in msg


# =================== 4) TERCIH UCU ========================================= #

def _headers(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_SES_TERCIHI_okunur_ve_degistirilir(client, world):
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.get("/me/bildirim-tercihleri", headers=h)
    assert r.status_code == 200, r.text
    # VARSAYILAN ACIK: bugune kadar sesli olmasi beklenen bildirimler
    # sessiz geliyordu; varsayilani kapali yapmak kusuru "ayar" diye
    # kalici hale getirmek olurdu.
    assert r.json()["bildirim_sesi"] is True

    r2 = client.patch("/me/bildirim-tercihleri", headers=h,
                      json={"bildirim_sesi": False})
    assert r2.status_code == 200, r2.text
    assert r2.json()["bildirim_sesi"] is False
    # KISMI GUNCELLEME: oteki kanallar DEGISMEDI.
    assert r2.json()["bildirim_mobil"] is r.json()["bildirim_mobil"]

    client.patch("/me/bildirim-tercihleri", headers=h,
                 json={"bildirim_sesi": True})


# ================== (P208 §2) TIPE GORE SES ================================ #

def test_GURULTU_UYARISI_KENDI_KANALINDAN_gider():
    """Istegin acik sarti: sakin, bildirimi GORMEDEN ne oldugunu
    anlayabilmeli. Android'de "ayni kanaldan farkli ses" diye bir sey
    YOK — ayirt edilebilir ses ayri kanal demek."""
    from app.push_kanal import KANAL_GURULTU, kanal_sec

    assert kanal_sec("gurultu_uyari_sakin", sesli=True) == KANAL_GURULTU
    # SES KAPALIYSA tercih kazanir (P207 kurali degismedi).
    assert kanal_sec("gurultu_uyari_sakin", sesli=False) == KANAL_SESSIZ


def test_KACAN_VARDIYA_OZEL_SES_ALMAZ_ama_KRITIK():
    """Istegin karari: "normal alarm sesi yeterli". Kritik kanaldan
    gider (sesli + high oncelik), kendi kanalini ACMAZ — her yeni kanal
    kullanicinin sistem ayarlarinda bir satir daha demek."""
    from app.push_kanal import KANAL_KRITIK, OZEL_KANALLI_TIPLER, kanal_sec

    assert kanal_sec("vardiya_baslamadi", sesli=True) == KANAL_KRITIK
    assert kanal_sec("vardiya_hatirlatma", sesli=True) == KANAL_KRITIK
    assert "vardiya_baslamadi" not in OZEL_KANALLI_TIPLER


def test_SIKAYET_ve_VARDIYA_P207_KANALINDAN_devam():
    from app.push_kanal import KANAL_KRITIK, kanal_sec

    for tip in ("yeni_talep", "talep_cozuldu", "vardiya_ozeti"):
        assert kanal_sec(tip, sesli=True) == KANAL_KRITIK, tip


def test_SES_ADI_dosya_HAZIR_OLUNCA_tipe_gore_ayrilir(monkeypatch):
    """`SES_HAZIR=True` oldugunda gurultu KENDI dosyasini, otekiler ORTAK
    dosyayi ister. Bugun ikisi de sistem sesi (`default`) — dosyalar
    gelmedi ve bunu bir "ayar" gibi gostermiyoruz."""
    from app import push_kanal

    assert push_kanal.ses_adi("gurultu_uyari_sakin", sesli=True) == "default"
    monkeypatch.setattr(push_kanal, "SES_HAZIR", True)
    assert push_kanal.ses_adi("gurultu_uyari_sakin", sesli=True) == (
        f"{push_kanal.GURULTU_SES_ADI}.caf"
    )
    assert push_kanal.ses_adi("vardiya_hatirlatma", sesli=True) == (
        f"{push_kanal.OZEL_SES_ADI}.caf"
    )


def test_GURULTU_TIPLERI_KRITIK_kumesinde():
    """Sakine giden uyari ve yoneticiye giden esik bilgisi SESLIDIR."""
    from app.push_kanal import KRITIK_TIPLER

    assert "gurultu_uyari_sakin" in KRITIK_TIPLER
    assert "gurultu_esik_yonetim" in KRITIK_TIPLER
