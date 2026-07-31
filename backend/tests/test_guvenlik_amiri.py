"""Guvenlik amiri + ikili guvenlik mimarisi (P35).

Olculen sey SAHIPLIK DEVRIDIR: `dis_sirket` modunda tur/vardiya planlamasi
yoneticiden AMIRE gecer; `yonetim_ici`de tersi. Devrin GERCEKTEN oldugunu
gostermek icin iki yon de test edilir — yalniz "amir yapabiliyor" demek,
yoneticinin hala yapabildigi bir dunyada da gecerdi.
"""
from __future__ import annotations

import uuid
from datetime import time

import pytest


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def roller(client, world):
    return {
        "admin": _h(client, world["slug_a"], world["admin_a"]),
        "yonetici": _h(client, world["slug_a"], world["yonetici_a"]),
        "amir": _h(client, world["slug_a"], world["amir_a"]),
        "guard": _h(client, world["slug_a"], world["guard_a"]),
    }


def _mod(client, roller, deger):
    r = client.patch("/tenant/settings", headers=roller["admin"],
                     json={"guvenlik_modu": deger})
    assert r.status_code == 200, r.text
    return r.json()


def _plan_govdesi():
    return {"ad": f"Plan {uuid.uuid4().hex[:6]}",
            "baslangic_saat": "00:00", "bitis_saat": "06:00",
            "periyot_dakika": 60}


# ============================== VARSAYILAN ================================== #
def test_varsayilan_mod_BUGUNKU_DAVRANIS(client, roller):
    """Mevcut tesislerin hicbiri etkilenmemeli: varsayilan yonetim_ici."""
    assert client.get("/tenant/settings", headers=roller["yonetici"]).json()[
        "guvenlik_modu"] == "yonetim_ici"


# ============================ SAHIPLIK DEVRI ================================ #
def test_YONETIM_ICI_yonetici_planlar_amir_PLANLAYAMAZ(client, roller):
    _mod(client, roller, "yonetim_ici")
    assert client.post("/patrol-plans", headers=roller["yonetici"],
                       json=_plan_govdesi()).status_code == 201
    r = client.post("/patrol-plans", headers=roller["amir"], json=_plan_govdesi())
    assert r.status_code == 403, r.text
    # Mesaj MODU soyler — "yetkiniz yok" ayarin ne oldugunu anlatmazdi.
    assert r.json()["error"]["code"] == "forbidden"


def test_DIS_SIRKET_amir_planlar_yonetici_PLANLAYAMAZ(client, roller):
    """Sahipligin GERCEKTEN devrolduğunu gosteren asil olcum."""
    _mod(client, roller, "dis_sirket")
    try:
        assert client.post("/patrol-plans", headers=roller["amir"],
                           json=_plan_govdesi()).status_code == 201
        assert client.post("/patrol-plans", headers=roller["yonetici"],
                           json=_plan_govdesi()).status_code == 403
    finally:
        _mod(client, roller, "yonetim_ici")


def test_ADMIN_HER_IKI_MODDA_yazar(client, roller):
    """Mod yanlis ayarlandiginda tesis KILITLI kalmamali."""
    for mod in ("yonetim_ici", "dis_sirket"):
        _mod(client, roller, mod)
        assert client.post("/patrol-plans", headers=roller["admin"],
                           json=_plan_govdesi()).status_code == 201
    _mod(client, roller, "yonetim_ici")


def test_devir_CHECKPOINT_ve_VARDIYAYI_da_kapsar(client, roller):
    """Plan kurup nokta ekleyemeyen ya da vardiya kuramayan bir sahiplik
    yarim sahipliktir."""
    _mod(client, roller, "dis_sirket")
    try:
        cp = client.post("/checkpoints", headers=roller["amir"], json={
            "ad": "CP", "nfc_tag_uid": f"NFC-{uuid.uuid4().hex[:10]}"})
        assert cp.status_code == 201, cp.text
        assert client.post("/checkpoints", headers=roller["yonetici"], json={
            "ad": "CP2", "nfc_tag_uid": f"NFC-{uuid.uuid4().hex[:10]}"
        }).status_code == 403

        v = client.post("/shifts", headers=roller["amir"], json={
            "ad": "Gece", "baslangic_saat": "00:00", "bitis_saat": "08:00"})
        assert v.status_code == 201, v.text
        assert client.put(
            f"/shifts/{v.json()['id']}/assignments", headers=roller["yonetici"],
            json={"user_ids": []}).status_code == 403
    finally:
        _mod(client, roller, "yonetim_ici")


def test_DEVIR_OKUMAYI_DEVRETMEZ(client, roller):
    """Dis sirkete devretmek DENETIMI devretmek degildir: yonetici planlari,
    turleri ve vardiyalari GORMEYE devam eder."""
    _mod(client, roller, "dis_sirket")
    try:
        for yol in ("/patrol-plans", "/shifts", "/checkpoints", "/scans"):
            r = client.get(yol, headers=roller["yonetici"])
            assert r.status_code == 200, (yol, r.status_code)
    finally:
        _mod(client, roller, "yonetim_ici")


# =========================== MOD AYARININ KENDISI =========================== #
def test_MODU_YALNIZ_ADMIN_degistirir(client, roller):
    """Yoneticinin kendi yetkisini kendine geri verebilmesi, dis sirkete
    devri anlamsizlastirirdi."""
    assert client.patch("/tenant/settings", headers=roller["yonetici"],
                        json={"guvenlik_modu": "dis_sirket"}).status_code == 403
    assert client.patch("/tenant/settings", headers=roller["amir"],
                        json={"guvenlik_modu": "yonetim_ici"}).status_code == 403


def test_mod_degisimi_DENETLENIR(client, roller, owner_conn, world):
    """Sahipligi devreden bir ayarin izsiz degismesi, "turleri kim
    planliyordu" sorusunu sonradan yanitlanamaz kilardi."""
    _mod(client, roller, "dis_sirket")
    _mod(client, roller, "yonetim_ici")
    satirlar = owner_conn.execute(
        "SELECT meta FROM audit_log WHERE tenant_id = %s AND action = "
        "'guvenlik_modu' ORDER BY ts", (world["a"],)).fetchall()
    assert len(satirlar) >= 2
    assert satirlar[-1][0]["eski"] == "dis_sirket"
    assert satirlar[-1][0]["yeni"] == "yonetim_ici"


def test_AYNI_deger_denetim_satiri_URETMEZ(client, roller, owner_conn, world):
    """Gurultu denetim kaydini okunamaz hale getirirdi."""
    _mod(client, roller, "yonetim_ici")
    once = owner_conn.execute(
        "SELECT count(*) FROM audit_log WHERE tenant_id = %s AND action = "
        "'guvenlik_modu'", (world["a"],)).fetchone()[0]
    _mod(client, roller, "yonetim_ici")
    sonra = owner_conn.execute(
        "SELECT count(*) FROM audit_log WHERE tenant_id = %s AND action = "
        "'guvenlik_modu'", (world["a"],)).fetchone()[0]
    assert sonra == once


# ============================= AMIRIN EKIBI ================================= #
def test_amir_YALNIZ_GUVENLIK_personeli_acar(client, roller, world):
    tel = world["bos_telefonlar"]
    r = client.post("/users", headers=roller["amir"], json={
        "ad": "Yeni Guvenlik", "role": "security", "telefon": tel[0]})
    assert r.status_code == 201, r.text
    # tesis_gorevlisi SITE isidir, dis guvenlik sirketinin personeli degil.
    assert client.post("/users", headers=roller["amir"], json={
        "ad": "Tesisci", "role": "tesis_gorevlisi",
        "telefon": tel[1]}).status_code == 403
    # Kendi rolunu cogaltamaz (yetki cogaltma yok).
    assert client.post("/users", headers=roller["amir"], json={
        "ad": "Ikinci Amir", "role": "guvenlik_amiri",
        "telefon": tel[2]}).status_code == 403


def test_amir_YETKI_YUKSELTEMEZ(client, roller, world):
    """Bu kontrol olmasaydi amir kendi rolunu yukseltebilir veya yoneticinin
    parolasini degistirebilirdi."""
    kendisi = client.get("/me", headers=roller["amir"]).json()
    r = client.patch(f"/users/{kendisi['id']}", headers=roller["amir"],
                     json={"role": "admin"})
    assert r.status_code == 403, r.text

    yonetici_id = client.get("/me", headers=roller["yonetici"]).json()["id"]
    assert client.patch(f"/users/{yonetici_id}", headers=roller["amir"],
                        json={"ad": "Ele Gecirildi"}).status_code == 403
    assert client.post(f"/users/{yonetici_id}/reset-password",
                       headers=roller["amir"]).status_code == 403


def test_amir_kendi_ekibini_duzenler(client, roller, world):
    tel = world["bos_telefonlar"]
    yeni = client.post("/users", headers=roller["amir"], json={
        "ad": "Ekip Uyesi", "role": "security", "telefon": tel[3]})
    assert yeni.status_code == 201, yeni.text
    uid = yeni.json()["id"]
    assert client.patch(f"/users/{uid}", headers=roller["amir"],
                        json={"ad": "Ekip Uyesi 2"}).status_code == 200
    assert client.post(f"/users/{uid}/reset-password",
                       headers=roller["amir"]).status_code == 200


# ============================== KAPALI ALANLAR ============================== #
def test_amire_SAKIN_ve_FINANS_alanlari_KAPALI(client, roller):
    """Dis sirket = EN AZ YETKI: guvenlik hizmeti sakin/finans verisi
    gerektirmez ve KVKK acisindan acilmasi savunulamaz."""
    for yol in ("/residents", "/dues/assessments", "/kargo", "/finans/hareketler"):
        r = client.get(yol, headers=roller["amir"])
        assert r.status_code == 403, (yol, r.status_code)


def test_amir_GUVENLIK_alanini_gorur(client, roller):
    for yol in ("/cameras", "/dashboard/live", "/notifications", "/scans"):
        r = client.get(yol, headers=roller["amir"])
        assert r.status_code == 200, (yol, r.status_code, r.text[:120])


def test_amir_TENANT_izolasyonu(client, world):
    """Amir B tenant'ina giremez (kimlik A'da)."""
    r = client.post("/auth/login", json={
        "tenant_slug": world["slug_b"], "email": world["amir_a"]["email"],
        "password": world["amir_a"]["password"]})
    assert r.status_code in (401, 404), r.text
