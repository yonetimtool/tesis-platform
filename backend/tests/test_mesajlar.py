"""Mesaj sablonlari + gonderim (P32)."""
from __future__ import annotations

import uuid

import pytest

from app.mesajlasma import (
    bilinmeyen_etiketler,
    etiketleri_coz,
    kullanilan_etiketler,
    sms_olc,
)


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _sfx() -> str:
    return uuid.uuid4().hex[:6]


@pytest.fixture
def adm(client, world):
    return _headers(client, world["slug_a"], world["admin_a"])


# ============================== CEKIRDEK ==================================== #
def test_etiket_cozumu():
    assert etiketleri_coz(
        "Sayın {adi_soyadi}, bakiye {bakiye} TL.",
        {"adi_soyadi": "Ali Veli", "bakiye": "1.250,50"},
    ) == "Sayın Ali Veli, bakiye 1.250,50 TL."


def test_BILINMEYEN_etiket_METINDE_KALIR():
    """Bos birakmak yazim hatasini GIZLERDI: kullanici mesajda bos bir
    bosluk gorup sorunu fark etmezdi."""
    assert etiketleri_coz("Merhaba {bakiyee}", {"bakiye": "10"}) == \
        "Merhaba {bakiyee}"


def test_None_deger_BOS_yazilir_None_METNI_DEGIL():
    assert etiketleri_coz("X{adres}Y", {"adres": None}) == "XY"


def test_etiket_listesi_SIRALI_ve_TEKRARSIZ():
    assert kullanilan_etiketler("{a_b} {c_d} {a_b}") == ["a_b", "c_d"]


def test_bilinmeyen_etiket_tespiti():
    assert bilinmeyen_etiketler("{bakiye} {uydurma}") == ["uydurma"]


# ----------------------------- SMS sayaci ----------------------------------- #
def test_sms_GSM7_160_karakter():
    olcum = sms_olc("A" * 160)
    assert olcum.unicode_mi is False
    assert olcum.parca == 1 and olcum.kalan == 0


def test_sms_161_karakter_IKI_PARCA():
    olcum = sms_olc("A" * 161)
    assert olcum.parca == 2


def test_TURKCE_i_g_s_UNICODE_ZORLAR_sinir_70e_duser():
    """TUZAK: tek bir `ş` mesaji UCS-2'ye dusurur ve 160'lik sinir 70 olur —
    "biraz uzun" bir mesaj birden UC SMS olur."""
    duz = sms_olc("A" * 100)
    turkce = sms_olc("A" * 99 + "ş")
    assert duz.unicode_mi is False and duz.parca == 1
    assert turkce.unicode_mi is True
    assert turkce.parca == 2, "70'lik sinira gecmedi"
    assert "ş" in turkce.zorlayan


def test_GSM7_kapsamı_HARF_HARF():
    """GSM-7'nin Turkce ile iliskisi SEZGISEL DEGIL — harf harf olculur.

    Kumede olanlar: `Ç` (BUYUK), `ö`, `ü`, `Ö`, `Ü`.
    Kumede OLMAYANLAR: `ç` (KUCUK!), `ı`, `ğ`, `ş`, `İ`, `Ğ`, `Ş`.
    Yani "çöp" yazan bir mesaj UCS-2'ye duser ama "Çöp" dusmez. Sayacin
    ZORLAYAN karakterleri gostermesinin sebebi tam olarak budur.
    """
    assert sms_olc("ÇöüÖÜ").unicode_mi is False
    for harf in "çığşİĞŞ":
        olcum = sms_olc(f"A{harf}")
        assert olcum.unicode_mi is True, harf
        assert harf in olcum.zorlayan


def test_sms_BOS_metin_sifir_parca():
    assert sms_olc("").parca == 0


# ================================= UC ======================================= #
def test_sablon_crud(client, adm):
    ad = f"Test-{_sfx()}"
    r = client.post("/mesaj-sablonlari", headers=adm, json={
        "kanal": "sms", "ad": ad, "govde": "Sayın {adi_soyadi}, {bakiye} TL"})
    assert r.status_code == 201, r.text
    assert r.json()["etiketler"] == ["adi_soyadi", "bakiye"]
    assert r.json()["bilinmeyen_etiketler"] == []

    sid = r.json()["id"]
    g = client.patch(f"/mesaj-sablonlari/{sid}", headers=adm,
                     json={"govde": "Yeni {uydurma}"})
    assert g.status_code == 200
    # Bilinmeyen etiket UYARIDIR, hata degil: sablon kaydedilir ama gorunur.
    assert g.json()["bilinmeyen_etiketler"] == ["uydurma"]
    assert client.delete(f"/mesaj-sablonlari/{sid}", headers=adm).status_code == 204


def test_SMS_sablonunda_KONU_OLMAZ(client, adm):
    """Dolu konu, gonderilen metne GIRMEYEN bir alan olurdu."""
    r = client.post("/mesaj-sablonlari", headers=adm, json={
        "kanal": "sms", "ad": f"K-{_sfx()}", "konu": "Konu", "govde": "x"})
    assert r.status_code == 422
    # PATCH ile de eklenemez (birlesik kural).
    sid = client.post("/mesaj-sablonlari", headers=adm, json={
        "kanal": "sms", "ad": f"K-{_sfx()}", "govde": "x"}).json()["id"]
    assert client.patch(f"/mesaj-sablonlari/{sid}", headers=adm,
                        json={"konu": "Sonradan"}).status_code == 422


def test_ayni_kanalda_ayni_ad_409_FARKLI_kanalda_serbest(client, adm):
    ad = f"Ayni-{_sfx()}"
    assert client.post("/mesaj-sablonlari", headers=adm, json={
        "kanal": "sms", "ad": ad, "govde": "x"}).status_code == 201
    assert client.post("/mesaj-sablonlari", headers=adm, json={
        "kanal": "sms", "ad": ad, "govde": "y"}).status_code == 409
    assert client.post("/mesaj-sablonlari", headers=adm, json={
        "kanal": "eposta", "ad": ad, "govde": "y"}).status_code == 201


def test_onizleme_COZULMUS_metin_ve_SMS_sayaci(client, adm):
    r = client.post("/mesajlar/onizleme?kanal=sms", headers=adm, json={
        "govde": "Sayın {adi_soyadi}, {site_adi} bakiyeniz {bakiye} TL."})
    assert r.status_code == 200, r.text
    govde = r.json()["govde"]
    assert "{adi_soyadi}" not in govde and "{bakiye}" not in govde
    assert r.json()["sms"]["parca"] >= 1
    # Turkce karakter iceren ornek metin UCS-2'ye duser.
    assert r.json()["sms"]["unicode_mi"] is True


def test_onizleme_EPOSTADA_sms_sayaci_YOK(client, adm):
    r = client.post("/mesajlar/onizleme?kanal=eposta", headers=adm,
                    json={"govde": "Merhaba {adi_soyadi}"}).json()
    assert r["sms"] is None


def test_gonderim_GECMISE_COZULMUS_metni_yazar(client, adm, world):
    """Sablona referans YETMEZ: sablon degistirilirse gecmis "ne gonderdik"
    sorusuna YANLIS cevap verirdi."""
    sablon = client.post("/mesaj-sablonlari", headers=adm, json={
        "kanal": "eposta", "ad": f"G-{_sfx()}", "konu": "{site_adi} bildirim",
        "govde": "Sayın {adi_soyadi}, bakiye {bakiye} TL."}).json()

    kullanicilar = client.get("/users", headers=adm,
                              params={"limit": 20}).json()["items"]
    hedef = [u["id"] for u in kullanicilar][:2]
    r = client.post("/mesajlar/gonder", headers=adm, json={
        "sablon_id": sablon["id"], "user_ids": hedef})
    assert r.status_code == 201, r.text
    assert r.json()["gonderildi"] + r.json()["adres_yok"] == len(hedef)

    gecmis = client.get("/mesajlar/gecmis", headers=adm,
                        params={"kanal": "eposta", "limit": 50}).json()["items"]
    if r.json()["gonderildi"]:
        kayit = gecmis[0]
        assert "{adi_soyadi}" not in kayit["govde"], "etiket cozulmemis"
        assert kayit["durum"] in ("gonderildi", "basarisiz")
        assert kayit["saglayici"]

        # SABLONU DEGISTIR -> gecmis DEGISMEMELI.
        client.patch(f"/mesaj-sablonlari/{sablon['id']}", headers=adm,
                     json={"govde": "TAMAMEN FARKLI"})
        sonra = client.get("/mesajlar/gecmis", headers=adm,
                           params={"kanal": "eposta", "limit": 50}).json()["items"]
        assert sonra[0]["govde"] == kayit["govde"]


def test_PAZARLAMA_sablonu_RIZA_YOKSA_GONDERMEZ_ve_SAYAR(client, adm):
    """SESSIZ DUSURME YOK: "gonderdim" deyip 40 kisiyi atlamak, yonetimin
    haberi olmadan bildirimsiz kalmasi demekti."""
    sablon = client.post("/mesaj-sablonlari", headers=adm, json={
        "kanal": "sms", "ad": f"P-{_sfx()}", "govde": "Kampanya",
        "amac": "pazarlama"}).json()
    kullanicilar = client.get("/users", headers=adm,
                              params={"limit": 5}).json()["items"]
    r = client.post("/mesajlar/gonder", headers=adm, json={
        "sablon_id": sablon["id"], "user_ids": [u["id"] for u in kullanicilar]})
    assert r.status_code == 201
    assert r.json()["gonderildi"] == 0
    assert r.json()["riza_yok"] == len(kullanicilar)


def test_PASIF_sablon_gonderilemez(client, adm):
    sablon = client.post("/mesaj-sablonlari", headers=adm, json={
        "kanal": "sms", "ad": f"Pas-{_sfx()}", "govde": "x",
        "aktif": False}).json()
    r = client.post("/mesajlar/gonder", headers=adm,
                    json={"sablon_id": sablon["id"], "user_ids": []})
    assert r.status_code == 422


def test_ADRESI_OLMAYAN_alici_AYRI_sayilir(client, adm):
    """E-postasi olmayan sakine e-posta gonderilemez — sessizce dusmez."""
    sablon = client.post("/mesaj-sablonlari", headers=adm, json={
        "kanal": "eposta", "ad": f"A-{_sfx()}", "govde": "x"}).json()
    u = client.post("/units", headers=adm,
                    json={"no": f"M-{_sfx()}", "blok": "A"}).json()
    kisi = client.post("/residents", headers=adm, json={
        "ad": "Epostasiz Sakin", "unit_no": u["no"],
        "telefon": f"+9054{uuid.uuid4().int % 10**8:08d}"}).json()
    r = client.post("/mesajlar/gonder", headers=adm, json={
        "sablon_id": sablon["id"], "user_ids": [kisi["user_id"]]}).json()
    assert r["adres_yok"] == 1 and r["gonderildi"] == 0


def test_varsayilan_sablon_seti():
    """Seed seti KOD ICINDE tanimlidir (test tenant'i seed'lenmez).

    HEPSI OPERASYONEL: PAZARLAMA sablonu varsayilan olarak YOKTUR — riza
    gerektirir (P36) ve hazir gelen bir pazarlama sablonu, yonetimi farkinda
    olmadan izinsiz gonderime iterdi.
    """
    from app.mesajlasma import VARSAYILAN_SABLONLAR

    adlar = {ad for _, ad, _, _, _ in VARSAYILAN_SABLONLAR}
    assert {"Bakiye Bildirimi", "Toplantı Çağrısı", "Davetiye",
            "Borç Girişi", "Tahsilat Girişi", "Yeni Duyuru",
            "Kiracı Bakiyesi"} <= adlar
    assert all(amac == "operasyonel" for *_, amac in VARSAYILAN_SABLONLAR)
    # SMS sablonlarinda KONU OLMAMALI (sema de zorlar).
    assert all(konu is None for kanal, _, konu, _, _ in VARSAYILAN_SABLONLAR
               if kanal == "sms")
    # Her sablonun etiketleri BILINEN kumeden olmali.
    for _, ad, konu, govde, _ in VARSAYILAN_SABLONLAR:
        assert bilinmeyen_etiketler(f"{konu or ''} {govde}") == [], ad


def test_rbac(client, world):
    for rol, izin in [("admin_a", True), ("yonetici_a", True),
                      ("guard_a", False), ("resident_a", False)]:
        h = _headers(client, world["slug_a"], world[rol])
        r = client.get("/mesaj-sablonlari", headers=h)
        assert (r.status_code == 200) is izin, (rol, r.status_code)


def test_tenant_izolasyonu(client, world):
    a = _headers(client, world["slug_a"], world["admin_a"])
    b = _headers(client, world["slug_b"], world["admin_b"])
    ad = f"Izo-{_sfx()}"
    s = client.post("/mesaj-sablonlari", headers=a,
                    json={"kanal": "sms", "ad": ad, "govde": "x"}).json()
    b_liste = client.get("/mesaj-sablonlari", headers=b,
                         params={"limit": 200}).json()["items"]
    assert s["id"] not in [i["id"] for i in b_liste]
    assert client.patch(f"/mesaj-sablonlari/{s['id']}", headers=b,
                        json={"govde": "y"}).status_code == 404
