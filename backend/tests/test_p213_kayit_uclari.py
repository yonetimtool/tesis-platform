"""(P213 §6) GECMIS KAYIT UCLARI — yetki, denetim, dogrulama, IDOR.

===========================================================================
NE OLCULEBILIR, NE OLCULEMEZ
===========================================================================
OLCULEBILIR (ve burada olculuyor): kimin erisebildigi, kapali kameranin
reddi, aralik dogrulamasi, DENETIM KAYDININ yazildigi, yol adiyla baska
kameranin kaydina gecilemedigi.

OLCULEMEZ: gercek bir NVR'dan gercek kayit gelmesi. Elimde Hikvision ya
da Dahua cihazi YOK. Protokol katmani `test_p213_kayit_adaptorleri.py`de
istek/yanit duzeyinde olculuyor; uctan uca dogrulama SAHA denemesiyle
yapilacak (docs/P213-06-gecmis-kayit-analiz.md §5).
"""
from __future__ import annotations

import uuid


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _kamera(client, h, **ek) -> str:
    r = client.post("/cameras", headers=h, json={
        "ad": f"Kayit-{uuid.uuid4().hex[:8]}",
        "stream_url": "rtsp://10.9.0.5:554/s", "tur": "rtsp", **ek})
    assert r.status_code == 201, r.text
    return r.json()["id"]


def _oku(client, h, kid: str) -> dict:
    """Tek-kayit GET ucu YOK (matris kilidi de boyle soyluyor): kamera
    listeden okunur."""
    r = client.get("/cameras?limit=100", headers=h)
    assert r.status_code == 200, r.text
    kayit = next((k for k in r.json()["items"] if k["id"] == kid), None)
    assert kayit is not None, "kamera listede yok"
    return kayit


ARALIK = {"bas": "2026-09-05T14:00:00Z", "bit": "2026-09-05T15:00:00Z"}


# ==================== YETKI =============================================== #

def test_ROL_KAPISI_sunucuda(client, world):
    """Istegin birebir karsiligi: "Guvenlik gorevlisi (amir olmayan)
    gecmis kayda erisemesin. Yetki kontrolu SUNUCU tarafinda olsun."
    """
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    kid = _kamera(client, yon)
    try:
        for anahtar, beklenen in (
            ("yonetici_a", 422),    # yetki VAR — kamerada kayit KAPALI
            ("amir_a", 422),        # yetki VAR
            ("guard_a", 403),       # amir OLMAYAN gorevli: YASAK
            ("gorevli_a", 403),
            ("resident_a", 403),
            ("denetci_a", 403),
        ):
            h = _h(client, world["slug_a"], world[anahtar])
            r = client.get(f"/cameras/{kid}/kayit/araliklar",
                           headers=h, params=ARALIK)
            assert r.status_code == beklenen, (anahtar, r.status_code, r.text)
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)


def test_OYNATMA_ucu_de_AYNI_kapiyi_kullanir(client, world):
    """Iki uc ayri yazildi; kapinin BIRINDE unutulmasi klasik hata."""
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    kid = _kamera(client, yon)
    try:
        r = client.post(f"/cameras/{kid}/kayit/oynat",
                        headers=_h(client, world["slug_a"], world["guard_a"]),
                        json=ARALIK)
        assert r.status_code == 403, r.text
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)


# ==================== KAMERA BASINA ACIK/KAPALI =========================== #

def test_VARSAYILAN_KAPALI(client, world):
    """Gecmis kayit geriye donuk gozetimdir; hicbir tesiste kendiliginden
    acik gelmemeli."""
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    kid = _kamera(client, yon)
    try:
        assert _oku(client, yon, kid)["kayit_aktif"] is False
        r = client.get(f"/cameras/{kid}/kayit/araliklar", headers=yon, params=ARALIK)
        assert r.status_code == 422
        assert r.json()["error"]["message"]
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)


def test_ACIK_ama_SAGLAYICISIZ_kamera_AYRI_hata(client, world):
    """Iki farkli eksigi ayni mesajla anlatmak, yoneticiyi yanlis yere
    bakmaya gonderirdi."""
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    kid = _kamera(client, yon, kayit_aktif=True)
    try:
        r = client.get(f"/cameras/{kid}/kayit/araliklar", headers=yon, params=ARALIK)
        assert r.status_code == 422
        kapali = client.get("/cameras", headers=yon)  # akis bozulmadi
        assert kapali.status_code == 200
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)


# ==================== ARALIK DOGRULAMA ==================================== #

def test_TERS_ve_ASIRI_GENIS_aralik_422(client, world):
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    kid = _kamera(client, yon, kayit_aktif=True, kayit_saglayici="sablon",
                  kayit_adres="rtsp://10.9.0.5/p?s={bas}&e={bit}")
    try:
        for bas, bit in (
            ("2026-09-05T15:00:00Z", "2026-09-05T14:00:00Z"),   # ters
            ("2026-09-01T00:00:00Z", "2026-09-05T00:00:00Z"),   # 4 gun
        ):
            r = client.get(f"/cameras/{kid}/kayit/araliklar", headers=yon,
                           params={"bas": bas, "bit": bit})
            assert r.status_code == 422, (bas, bit, r.text)
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)


def test_SABLON_arama_destegi_YOK_bilgisini_DONER(client, world):
    """Kritik ayrim: "arayamiyorum" ile "kayit yok" farkli seyler."""
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    kid = _kamera(client, yon, kayit_aktif=True, kayit_saglayici="sablon",
                  kayit_adres="rtsp://10.9.0.5/p?s={bas}&e={bit}")
    try:
        r = client.get(f"/cameras/{kid}/kayit/araliklar", headers=yon, params=ARALIK)
        assert r.status_code == 200, r.text
        assert r.json() == {"arama_destekli": False, "araliklar": []}
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)


# ==================== KVKK: DENETIM KAYDI ================================= #

def test_ARAMA_DENETIME_yazilir(client, world, owner_conn):
    """Gecmis kayit izleme geriye donuk gozetimdir. Kim, hangi kamerayi,
    HANGI ARALIK icin sorguladi — sonradan uretilemez, o an yazilmali."""
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    kid = _kamera(client, yon, kayit_aktif=True, kayit_saglayici="sablon",
                  kayit_adres="rtsp://10.9.0.5/p?s={bas}&e={bit}")
    try:
        client.get(f"/cameras/{kid}/kayit/araliklar", headers=yon, params=ARALIK)
        satir = owner_conn.execute(
            "SELECT action, meta FROM audit_log WHERE resource_id = %s "
            "AND action = 'camera_kayit_arama' ORDER BY ts DESC LIMIT 1",
            (kid,),
        ).fetchone()
        assert satir, "denetim kaydi YOK"
        meta = satir[1] or {}
        assert "2026-09-05T14:00:00" in str(meta.get("bas")), meta
        assert meta.get("saglayici") == "sablon"
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)


# ==================== IDOR ================================================ #

def test_YOL_ADI_BASKA_kameraya_gecmeye_izin_VERMEZ(client, world):
    """Rol kapisi gecildikten sonra bile tesis ici bir sizinti olurdu:
    A kamerasinin ucundan B'nin kaydini cekmek."""
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    a = _kamera(client, yon, kayit_aktif=True, kayit_saglayici="sablon",
                kayit_adres="rtsp://10.9.0.5/p")
    b = _kamera(client, yon, kayit_aktif=True, kayit_saglayici="sablon",
                kayit_adres="rtsp://10.9.0.6/p")
    try:
        sahte = "kayit" + uuid.UUID(b).hex + "0" * 16
        r = client.get(f"/cameras/{a}/kayit/{sahte}/index.m3u8", headers=yon)
        assert r.status_code in (404, 503), r.text
        for kotu in ("../cam123", "kayit../../x", "kayitXYZ"):
            r = client.get(f"/cameras/{a}/kayit/{kotu}/index.m3u8", headers=yon)
            assert r.status_code in (404, 503), (kotu, r.status_code)
    finally:
        for kid in (a, b):
            client.delete(f"/cameras/{kid}", headers=yon)


def test_NVR_PAROLASI_hicbir_yanitta_gecmez(client, world):
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    kid = _kamera(client, yon, kayit_aktif=True, kayit_saglayici="dahua",
                  kayit_kullanici="op", kayit_parola="NvrGizli!7")
    try:
        for r in (client.get("/cameras?limit=100", headers=yon),):
            assert "NvrGizli!7" not in r.text
            assert "kayit_parola_sifreli" not in r.text
        assert _oku(client, yon, kid)["kayit_kullanici"] == "op"
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)
