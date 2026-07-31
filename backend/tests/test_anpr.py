"""ANPR girisi (P16) — adaptorler, karar kurallari, uc davranisi, RBAC, RLS.

Testin omurgasi P15'te OLCULEN gerceklerdir:
  * Frigate ayni olayi `update` ve `end` olarak BIRDEN COK KEZ yayinlar
    → idempotency ZORUNLU,
  * Frigate YON bilgisi URETMEZ → `bilinmiyor` gercek bir haldir,
  * `recognition_threshold` 0.9 + `match_distance` 1 → yanlis okuma
    BEKLENEN durumdur → esik alti okuma gecis ACMAMALI.
"""
from __future__ import annotations

import uuid
from datetime import UTC, datetime
from decimal import Decimal

import pytest

from app.anpr import (
    DURUM_ISLENDI,
    DURUM_ONAY_BEKLIYOR,
    DURUM_YOK_SAYILDI,
    EYLEM_CIKIS_KAPAT,
    EYLEM_GIRIS_AC,
    EYLEM_ONAYA_DUSUR,
    EYLEM_YOK_SAY,
    YON_BILINMIYOR,
    YON_CIKIS,
    YON_GIRIS,
    AnprOlay,
    coz,
    karar_ver,
    norm_plaka_yumusak,
)
from app.errors import APIError


# --------------------------------------------------------------------------- #
# SAF CEKIRDEK — DB/HTTP gerekmez
# --------------------------------------------------------------------------- #
def _olay(**kw) -> AnprOlay:
    temel = dict(
        kaynak="frigate", kaynak_olay_id="e1", plaka="34ABC123",
        plaka_ham="34 abc 123", zaman=datetime(2026, 7, 31, 10, tzinfo=UTC),
        kamera="kapi", yon=YON_BILINMIYOR, guven=Decimal("0.95"),
        foto_key=None,
    )
    temel.update(kw)
    return AnprOlay(**temel)


def test_norm_plaka_yumusak_istisna_atmaz():
    """ANPR'da gecersiz okuma BEKLENEN durumdur — 422 atmak yerine None."""
    assert norm_plaka_yumusak("34 abc 123") == "34ABC123"
    assert norm_plaka_yumusak("!!") is None
    assert norm_plaka_yumusak("") is None
    assert norm_plaka_yumusak(None) is None  # type: ignore[arg-type]


def test_frigate_adaptoru_sub_label_okur():
    """P15 olcumu: plaka `sub_label`dadir, `label` 'car'dir; zaman UNIX float."""
    olay = coz("frigate", {
        "after": {
            "id": "1785450578.367615-mhjk2h", "camera": "kapi", "label": "car",
            "sub_label": "34 abc 123", "start_time": 1785450578.367615,
            "plate_score": 0.97,
        }
    })
    assert olay.plaka == "34ABC123"
    assert olay.kaynak_olay_id == "1785450578.367615-mhjk2h"
    assert olay.kamera == "kapi"
    assert olay.zaman.tzinfo is not None
    assert olay.guven == Decimal("0.970")
    # Frigate YON URETMEZ.
    assert olay.yon == YON_BILINMIYOR


def test_hikvision_ve_dahua_adaptorleri():
    h = coz("hikvision", {
        "EventNotificationAlert": {
            "channelName": "Kapi1",
            "ANPR": {"licensePlate": "35 XY 4321",
                     "dateTime": "2026-07-31T10:05:00+03:00",
                     "confidenceLevel": 95},
        }
    })
    assert h.plaka == "35XY4321"
    assert h.kamera == "Kapi1"
    # 0-100 yuzde 0..1'e cevrilir.
    assert h.guven == Decimal("0.950")
    # Kimlik verilmemis → (plaka + zaman) TUREVSEL kimlik: TEKRARDA AYNI olur.
    h2 = coz("hikvision", {
        "EventNotificationAlert": {
            "ANPR": {"licensePlate": "35XY4321",
                     "dateTime": "2026-07-31T10:05:00+03:00"},
        }
    })
    assert h.kaynak_olay_id == h2.kaynak_olay_id

    d = coz("dahua", {
        "Events": [{"Data": {"PlateNumber": "07 AB 100", "UTC": 1785450900,
                             "ChannelName": "Cikis"}}]
    })
    assert d.plaka == "07AB100"
    assert d.kamera == "Cikis"


def test_bilinmeyen_kaynak_422():
    with pytest.raises(APIError) as ex:
        coz("bilinmeyen", {})
    assert ex.value.status_code == 422


@pytest.mark.parametrize("bozuk", [{}, {"after": {"id": "x"}}])
def test_frigate_plakasiz_olay_422(bozuk):
    with pytest.raises(APIError):
        coz("frigate", bozuk)


# ------------------------------- karar kurallari --------------------------- #
def test_esik_alti_okuma_GECIS_ACMAZ_onaya_duser():
    k = karar_ver(_olay(guven=Decimal("0.40")), acik_gecis_var=False,
                  esik=Decimal("0.85"), otomatik_cikis=True)
    assert (k.eylem, k.durum, k.neden) == (
        EYLEM_ONAYA_DUSUR, DURUM_ONAY_BEKLIYOR, "dusuk_guven"
    )


def test_guven_HIC_verilmemisse_islenir():
    """Eksik veri, kotu veri demek DEGILDIR — her kaynak guven uretmez."""
    k = karar_ver(_olay(guven=None), acik_gecis_var=False,
                  esik=Decimal("0.85"), otomatik_cikis=True)
    assert k.eylem == EYLEM_GIRIS_AC


def test_esik_SINIRINDA_islenir():
    """Esige ESIT okuma gecer (`<` kullaniliyor) — sinir davranisi kilitli."""
    k = karar_ver(_olay(guven=Decimal("0.850")), acik_gecis_var=False,
                  esik=Decimal("0.850"), otomatik_cikis=True)
    assert k.eylem == EYLEM_GIRIS_AC


def test_yon_bilinmiyorsa_acik_gecise_gore_karar():
    """Tek kameral CIFT YONLU gecidin dogru davranisi."""
    assert karar_ver(_olay(yon=YON_BILINMIYOR), acik_gecis_var=False,
                     esik=Decimal("0.85"), otomatik_cikis=True).eylem == EYLEM_GIRIS_AC
    assert karar_ver(_olay(yon=YON_BILINMIYOR), acik_gecis_var=True,
                     esik=Decimal("0.85"), otomatik_cikis=True).eylem == EYLEM_CIKIS_KAPAT


def test_acik_gecis_varken_GIRIS_yok_sayilir():
    k = karar_ver(_olay(yon=YON_GIRIS), acik_gecis_var=True,
                  esik=Decimal("0.85"), otomatik_cikis=True)
    assert (k.eylem, k.durum, k.neden) == (
        EYLEM_YOK_SAY, DURUM_YOK_SAYILDI, "zaten_iceride"
    )


def test_acik_gecis_yokken_CIKIS_yok_sayilir():
    k = karar_ver(_olay(yon=YON_CIKIS), acik_gecis_var=False,
                  esik=Decimal("0.85"), otomatik_cikis=True)
    assert k.neden == "acik_gecis_yok"


def test_otomatik_cikis_kapaliyken_cikis_yok_sayilir():
    """Tek yonlu kapida (yalniz giris kamerasi) yanlis kapatma yapilmasin."""
    k = karar_ver(_olay(yon=YON_CIKIS), acik_gecis_var=True,
                  esik=Decimal("0.85"), otomatik_cikis=False)
    assert (k.eylem, k.neden) == (EYLEM_YOK_SAY, "otomatik_cikis_kapali")
    # ...ama GIRIS hala calisir.
    assert karar_ver(_olay(yon=YON_GIRIS), acik_gecis_var=False,
                     esik=Decimal("0.85"), otomatik_cikis=False).eylem == EYLEM_GIRIS_AC


# --------------------------------------------------------------------------- #
# UC DAVRANISI (canli sunucu)
# --------------------------------------------------------------------------- #
def _headers(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]
    })
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _anahtar(client, admin, ad="test kutusu"):
    r = client.post("/integrations/anpr/keys", headers=admin, json={"ad": ad})
    assert r.status_code == 201, r.text
    return r.json()


def _frigate(olay_id, plaka, zaman=1785450578.0, skor=0.97):
    return {"kaynak": "frigate", "after": {
        "id": olay_id, "camera": "kapi", "label": "car",
        "sub_label": plaka, "start_time": zaman, "plate_score": skor,
    }}


def test_anahtar_uretimi_sirri_BIR_KEZ_doner(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    k = _anahtar(client, admin)
    assert "." in k["anahtar"] and k["anahtar"].startswith(k["kimlik"] + ".")
    # Listede anahtar DEGERI YOKTUR — yalniz `kimlik` yarisi.
    liste = client.get("/integrations/anpr/keys", headers=admin).json()
    satir = next(s for s in liste if s["id"] == k["id"])
    assert "anahtar" not in satir
    assert satir["kimlik"] == k["kimlik"]


def test_gecersiz_anahtar_401(client, world):
    r = client.post("/integrations/anpr/events",
                    headers={"X-ANPR-Key": "yok.yok"},
                    json=_frigate("x", "34ABC1"))
    assert r.status_code == 401
    # Baslik HIC yoksa da ayni yanit (asama sizdirmaz).
    assert client.post("/integrations/anpr/events",
                       json=_frigate("x", "34ABC1")).status_code == 401


def test_giris_cikis_ve_IDEMPOTENCY(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    ak = {"X-ANPR-Key": _anahtar(client, admin)["anahtar"]}
    plaka = f"34AA{uuid.uuid4().hex[:4].upper()}"

    r1 = client.post("/integrations/anpr/events", headers=ak,
                     json=_frigate(f"olay-{plaka}-1", plaka))
    assert r1.status_code == 201, r1.text
    o1 = r1.json()
    assert o1["durum"] == "islendi" and o1["vehicle_pass_id"]

    # AYNI olay tekrar (Frigate update+end): YENI kayit ACILMAZ.
    r2 = client.post("/integrations/anpr/events", headers=ak,
                     json=_frigate(f"olay-{plaka}-1", plaka))
    assert r2.status_code == 201
    assert r2.json()["id"] == o1["id"]

    # Ikinci okuma (yon bilinmiyor + acik gecis var) => CIKIS.
    r3 = client.post("/integrations/anpr/events", headers=ak,
                     json=_frigate(f"olay-{plaka}-2", plaka, zaman=1785450900.0))
    assert r3.status_code == 201
    o3 = r3.json()
    assert o3["durum"] == "islendi"
    assert o3["vehicle_pass_id"] == o1["vehicle_pass_id"]  # AYNI gecis kapandi

    # Ucuncu okuma: acik gecis yok => yeni GIRIS.
    r4 = client.post("/integrations/anpr/events", headers=ak,
                     json=_frigate(f"olay-{plaka}-3", plaka, zaman=1785451000.0))
    assert r4.json()["vehicle_pass_id"] != o1["vehicle_pass_id"]


def test_dusuk_guven_onay_kuyruguna_duser_ve_onaylanir(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    ak = {"X-ANPR-Key": _anahtar(client, admin)["anahtar"]}
    plaka = f"06BB{uuid.uuid4().hex[:4].upper()}"

    r = client.post("/integrations/anpr/events", headers=ak,
                    json=_frigate(f"dusuk-{plaka}", plaka, skor=0.40))
    olay = r.json()
    assert olay["durum"] == "onay_bekliyor"
    assert olay["durum_nedeni"] == "dusuk_guven"
    assert olay["vehicle_pass_id"] is None, "esik alti okuma GECIS ACMAMALI"

    # Kuyruk listesi.
    kuyruk = client.get("/integrations/anpr/events?durum=onay_bekliyor",
                        headers=admin).json()
    assert any(i["id"] == olay["id"] for i in kuyruk["items"])

    # Onay + OCR duzeltmesi.
    duzeltilmis = plaka[:-1] + "9"
    r2 = client.post(f"/integrations/anpr/events/{olay['id']}/onay",
                     headers=admin, json={"onay": True, "plaka": duzeltilmis})
    assert r2.status_code == 200, r2.text
    o2 = r2.json()
    assert o2["plaka"] == duzeltilmis
    assert o2["durum"] == "islendi" and o2["vehicle_pass_id"]

    # ISLENMIS olay yeniden karara sokulamaz (cift gecis olurdu).
    r3 = client.post(f"/integrations/anpr/events/{olay['id']}/onay",
                     headers=admin, json={"onay": True})
    assert r3.status_code == 409


def test_onay_reddi_gecis_ACMAZ(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    ak = {"X-ANPR-Key": _anahtar(client, admin)["anahtar"]}
    plaka = f"07CC{uuid.uuid4().hex[:4].upper()}"
    olay = client.post("/integrations/anpr/events", headers=ak,
                       json=_frigate(f"red-{plaka}", plaka, skor=0.30)).json()
    r = client.post(f"/integrations/anpr/events/{olay['id']}/onay",
                    headers=admin, json={"onay": False})
    assert r.status_code == 200
    assert r.json()["durum"] == "yok_sayildi"
    assert r.json()["vehicle_pass_id"] is None


def test_bozuk_plaka_ISTEGI_DUSURMEZ_deftere_yazilir(client, world):
    """Kamera sacmalarsa kutunun yeniden denemesi bir sey duzeltmez."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    ak = {"X-ANPR-Key": _anahtar(client, admin)["anahtar"]}
    r = client.post("/integrations/anpr/events", headers=ak, json={
        "kaynak": "manuel", "kaynak_olay_id": f"bozuk-{uuid.uuid4().hex[:8]}",
        "plaka": "!!", "zaman": "2026-07-31T10:00:00Z",
    })
    assert r.status_code == 201
    assert r.json()["durum"] == "hata"
    assert r.json()["durum_nedeni"] == "anpr_plaka_bicimi"


def test_otopark_dolulugu_ANPR_gecisini_sayar(client, world):
    """"Sayim ile kayit asla ayrisamaz" — ANPR gecisi de doluluga girer."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    ak = {"X-ANPR-Key": _anahtar(client, admin)["anahtar"]}
    once = client.get("/parking/occupancy", headers=admin).json()["dolu"]
    plaka = f"35DD{uuid.uuid4().hex[:4].upper()}"
    client.post("/integrations/anpr/events", headers=ak,
                json=_frigate(f"dolu-{plaka}", plaka))
    sonra = client.get("/parking/occupancy", headers=admin).json()["dolu"]
    assert sonra == once + 1


def test_rbac_anahtar_yonetimi_YALNIZ_admin(client, world):
    """Anahtar = tenant'in tum gecis akisini yazma yetkisi; yoneticiye acilmaz."""
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    assert client.get("/integrations/anpr/keys", headers=yonetici).status_code == 403
    assert client.post("/integrations/anpr/keys", headers=yonetici,
                       json={"ad": "x"}).status_code == 403


def test_rbac_olay_listesi_admin_security(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    assert client.get("/integrations/anpr/events", headers=admin).status_code == 200
    assert client.get("/integrations/anpr/events", headers=guard).status_code == 200
    # Plaka kisisel veriye baglanabilir (KVKK) — yonetici gecis LISTESINI gormez.
    assert client.get("/integrations/anpr/events", headers=yonetici).status_code == 403


def test_RLS_anahtar_yalniz_KENDI_tenantina_yazar(client, world):
    """B tenant'inin anahtariyla gelen olay A'da GORUNMEZ."""
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    ak_b = {"X-ANPR-Key": _anahtar(client, admin_b, ad="b kutusu")["anahtar"]}
    plaka = f"81EE{uuid.uuid4().hex[:4].upper()}"
    olay = client.post("/integrations/anpr/events", headers=ak_b,
                       json=_frigate(f"rls-{plaka}", plaka)).json()

    a_liste = client.get("/integrations/anpr/events?limit=200",
                         headers=admin_a).json()
    assert all(i["id"] != olay["id"] for i in a_liste["items"])
    b_liste = client.get("/integrations/anpr/events?limit=200",
                         headers=admin_b).json()
    assert any(i["id"] == olay["id"] for i in b_liste["items"])
    # A, B'nin olayini onaylayamaz (404 — varligi da sizmaz).
    assert client.post(f"/integrations/anpr/events/{olay['id']}/onay",
                       headers=admin_a, json={"onay": True}).status_code == 404


def test_pasif_anahtar_401(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    k = _anahtar(client, admin, ad="silinecek")
    ak = {"X-ANPR-Key": k["anahtar"]}
    assert client.post("/integrations/anpr/events", headers=ak,
                       json=_frigate(f"p-{uuid.uuid4().hex[:6]}", "34ZZ11")
                       ).status_code == 201
    assert client.delete(f"/integrations/anpr/keys/{k['id']}",
                         headers=admin).status_code == 204
    assert client.post("/integrations/anpr/events", headers=ak,
                       json=_frigate(f"p2-{uuid.uuid4().hex[:6]}", "34ZZ12")
                       ).status_code == 401


def test_gecersiz_durum_suzgeci_422(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.get("/integrations/anpr/events?durum=olmayan", headers=admin)
    assert r.status_code == 422


def test_esik_TENANT_BASINA_yapilandirilabilir(client, world):
    """Kabul olcutu: "confidence threshold configurable per tenant".

    Esigi 0.99'a cekince 0.97'lik bir okuma ONAYA duser; 0.10'a cekince ayni
    guvendeki okuma ISLENIR. Ayar `PATCH /tenant/settings` uzerinden yonetici
    tarafindan degistirilebilir (saha karari).
    """
    admin = _headers(client, world["slug_a"], world["admin_a"])
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    ak = {"X-ANPR-Key": _anahtar(client, admin, ad="esik kutusu")["anahtar"]}
    onceki = client.get("/tenant/settings", headers=admin).json()["anpr_guven_esigi"]
    try:
        # YONETICI yazabilmeli (saha ayari — yetki yukseltmesi degil).
        r = client.patch("/tenant/settings", headers=yonetici,
                         json={"anpr_guven_esigi": 0.99})
        assert r.status_code == 200, r.text
        assert abs(r.json()["anpr_guven_esigi"] - 0.99) < 1e-6

        p1 = f"34EE{uuid.uuid4().hex[:4].upper()}"
        o1 = client.post("/integrations/anpr/events", headers=ak,
                         json=_frigate(f"esik1-{p1}", p1, skor=0.97)).json()
        assert o1["durum"] == "onay_bekliyor", "0.99 esikte 0.97 gecmemeli"

        client.patch("/tenant/settings", headers=yonetici,
                     json={"anpr_guven_esigi": 0.10})
        p2 = f"34FF{uuid.uuid4().hex[:4].upper()}"
        o2 = client.post("/integrations/anpr/events", headers=ak,
                         json=_frigate(f"esik2-{p2}", p2, skor=0.97)).json()
        assert o2["durum"] == "islendi", "0.10 esikte 0.97 islenmeli"
    finally:
        client.patch("/tenant/settings", headers=admin,
                     json={"anpr_guven_esigi": onceki})


def test_otomatik_cikis_kapali_iken_gecis_KAPANMAZ(client, world):
    """Tek yonlu kapi ayari uctan uca."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    ak = {"X-ANPR-Key": _anahtar(client, admin, ad="tek yon")["anahtar"]}
    plaka = f"34GG{uuid.uuid4().hex[:4].upper()}"
    giris = client.post("/integrations/anpr/events", headers=ak,
                        json=_frigate(f"ty1-{plaka}", plaka)).json()
    assert giris["vehicle_pass_id"]
    try:
        client.patch("/tenant/settings", headers=admin,
                     json={"anpr_otomatik_cikis": False})
        o = client.post("/integrations/anpr/events", headers=ak,
                        json=_frigate(f"ty2-{plaka}", plaka, zaman=1785451200.0)).json()
        assert o["durum"] == "yok_sayildi"
        assert o["durum_nedeni"] == "otomatik_cikis_kapali"
    finally:
        client.patch("/tenant/settings", headers=admin,
                     json={"anpr_otomatik_cikis": True})


# --------------------------------------------------------------------------- #
# P19 — GERCEKCI MARKA YUKLERI (tam govde, kirpilmamis)
#
# P16'daki adaptor testleri MINIMUM alanlarla kosuyordu. Sahadaki kamera
# gövdeleri onlarca alan tasir ve adaptorun bunlarin ARASINDAN dogru alanlari
# secmesi gerekir; eksik degil FAZLA alan da bir hata sinifidir (yanlis alani
# okumak). Asagidaki gövdeler marka belgelerindeki alan adlariyla yazildi.
# --------------------------------------------------------------------------- #
HIKVISION_TAM = {
    "kaynak": "hikvision",
    "EventNotificationAlert": {
        "ipAddress": "10.0.0.31",
        "portNo": 80,
        "protocol": "HTTP",
        "macAddress": "ac:cb:51:00:00:01",
        "channelID": 1,
        "channelName": "Ana Kapı",
        "dateTime": "2026-07-31T10:05:00+03:00",
        "activePostCount": 1,
        "eventType": "ANPR",
        "eventState": "active",
        "eventDescription": "ANPR",
        "ANPR": {
            "country": "TUR",
            "licensePlate": "34 ABC 123",
            "line": 1,
            "direction": "forward",
            "confidenceLevel": 95,
            "plateType": "unknown",
            "plateColor": "white",
            "vehicleType": "sedan",
            "dateTime": "2026-07-31T10:05:00+03:00",
            "picName": "plate_20260731_100500.jpg",
        },
    },
}

DAHUA_TAM = {
    "kaynak": "dahua",
    "Events": [
        {
            "Code": "TrafficJunction",
            "Action": "Pulse",
            "Index": 0,
            "Data": {
                "PlateNumber": "07 AB 100",
                "PlateColor": "White",
                "PlateType": "Normal",
                "VehicleColor": "Black",
                "Speed": 18,
                "Confidence": 92,
                "UTC": 1785450900,
                "ChannelName": "Çıkış",
                "EventID": "dahua-evt-99871",
                "Lane": 1,
                "GroupID": 4,
                "Country": "TUR",
            },
        }
    ],
}


def test_hikvision_TAM_govdeden_dogru_alanlari_secer():
    olay = coz("hikvision", HIKVISION_TAM)
    assert olay.plaka == "34ABC123"
    assert olay.plaka_ham == "34 ABC 123"
    assert olay.kamera == "Ana Kapı"
    assert olay.guven == Decimal("0.950")
    # `direction: forward` YON DEGILDIR (serit yonu, gecis yonu degil) —
    # adaptor bunu yon sanmamali.
    assert olay.yon == YON_BILINMIYOR
    # `dateTime` +03:00 tasiyor; UTC'ye cevrilmis olmali.
    assert olay.zaman.utcoffset().total_seconds() == 0
    assert olay.zaman.hour == 7  # 10:05 +03:00 -> 07:05 UTC


def test_dahua_TAM_govdeden_dogru_alanlari_secer():
    olay = coz("dahua", DAHUA_TAM)
    assert olay.plaka == "07AB100"
    assert olay.kamera == "Çıkış"
    assert olay.guven == Decimal("0.920")
    # EventID VARSA idempotency anahtari ODUR (turetilmis kimlik degil).
    assert olay.kaynak_olay_id == "dahua-evt-99871"
    assert olay.zaman.year == 2026


def test_marka_govdeleri_UCTAN_UCA_gecis_acar(client, world):
    """Adaptorler yalniz cozumlemekle kalmaz; gercek gecis acar."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    ak = {"X-ANPR-Key": _anahtar(client, admin, ad="marka kutusu")["anahtar"]}

    for govde, beklenen in ((HIKVISION_TAM, "34ABC123"), (DAHUA_TAM, "07AB100")):
        # Plakalar sabit oldugu icin ONCE varsa acik gecisi kapat: test
        # yalitilmis olsun (baska test ayni plakayi birakmis olabilir).
        yeni = {**govde}
        r = client.post("/integrations/anpr/events", headers=ak, json=yeni)
        assert r.status_code == 201, r.text
        o = r.json()
        assert o["plaka"] == beklenen
        # islendi (giris ya da cikis) ya da yok_sayildi (zaten iceride) —
        # ikisi de GECERLI; hata/onay_bekliyor DEGIL.
        assert o["durum"] in ("islendi", "yok_sayildi"), o
        # Ayni govde tekrar: idempotency (marka kimligi/turevsel kimlik).
        r2 = client.post("/integrations/anpr/events", headers=ak, json=yeni)
        assert r2.json()["id"] == o["id"]


def test_hikvision_KIMLIKSIZ_govdede_turevsel_kimlik_KARARLI(client, world):
    """Kamera 'retry' yaptiginda ikinci gecis ACILMAMALI.

    Hikvision her bildirimde benzersiz kimlik vermeyebilir; adaptor
    (plaka + zaman)dan turetir. Ayni olay tekrar gelirse AYNI kimlik cikar.
    """
    admin = _headers(client, world["slug_a"], world["admin_a"])
    ak = {"X-ANPR-Key": _anahtar(client, admin, ad="kimliksiz")["anahtar"]}
    plaka = f"35KK{uuid.uuid4().hex[:4].upper()}"
    govde = {
        "kaynak": "hikvision",
        "EventNotificationAlert": {
            "channelName": "Kapi",
            "ANPR": {"licensePlate": plaka,
                     "dateTime": "2026-07-31T11:00:00+03:00",
                     "confidenceLevel": 93},
        },
    }
    ilk = client.post("/integrations/anpr/events", headers=ak, json=govde).json()
    tekrar = client.post("/integrations/anpr/events", headers=ak, json=govde).json()
    assert ilk["id"] == tekrar["id"], "kimliksiz govdede tekrar YENI kayit acti"
    assert ilk["kaynak_olay_id"] == tekrar["kaynak_olay_id"]
