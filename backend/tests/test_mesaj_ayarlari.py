"""(P168 §4.4) MESAJ AYARLARI — saglayici yapilandirmasi, sirlar, kota.

EN PAHALI SONUC VE BU DOSYANIN AGIRLIK MERKEZI:

  SAGLAYICI YOKKEN "GONDERILDI" DEMEK.

Onceki hâl tam olarak bunu yapiyordu: `LogSmsSaglayici` hicbir sey
gondermeden `"gonderildi"` donuyordu. Yonetici "Gonderim" listesinde
yesil bir satir goruyor, sakin hicbir sey almiyordu. Bir SMS'in gidip
gitmedigi HUKUKI bir sorudur (bildirim kaniti); yanlis bir "gonderildi"
kaydi, olmayan bir bildirimi ISPAT gibi gosterirdi.
"""
from __future__ import annotations


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# --------------------------------------------------------------------------- #
# 1. "YAPILANDIRILMADI" — sessiz yalanin kilidi
# --------------------------------------------------------------------------- #
def test_SAGLAYICI_YOKKEN_gonderildi_DENMEZ(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/mesaj-ayarlari/test", headers=y, json={
        "kanal": "sms", "hedef": "05001112233"})
    assert r.status_code == 200, r.text
    govde = r.json()
    # Gelistirme ortaminda saglayici yok; durum "gonderildi" OLMAMALI.
    assert govde["durum"] != "gonderildi", govde
    assert govde["durum"] == "yapilandirilmadi", govde
    # SEBEP DE DONER: kullanici NE YAPACAGINI bilmeli.
    assert govde["hata"]


def test_TEST_GONDERIMI_GECMISE_YAZILMAZ(client, world):
    """Test bir BILDIRIM degildir.

    Gonderim gecmisine dusmesi, "kime ne gonderdik" defterini kirletirdi
    ve KVKK kaniti olan o defteri okunmaz hale getirirdi.
    """
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    once = client.get("/mesajlar/gecmis", headers=y, params={"limit": 1}).json()
    client.post("/mesaj-ayarlari/test", headers=y, json={
        "kanal": "eposta", "hedef": "test@ornek.com"})
    sonra = client.get("/mesajlar/gecmis", headers=y, params={"limit": 1}).json()
    assert sonra["meta"]["total"] == once["meta"]["total"]


# --------------------------------------------------------------------------- #
# 2. SIRLAR — arayuz degeri HIC GORMEZ
# --------------------------------------------------------------------------- #
def test_PAROLA_ASLA_DONMEZ_yalnizca_VARLIGI(client, world):
    """Brief "sirlar maskeli gosterilsin" diyor.

    `****` gibi bir metin dondurmek KOLAY ama YANLIS olurdu: maskeli
    deger de bir DEGERDIR, forma girer ve "kaydet"te gercek parolanin
    uzerine `****` yazilirdi.
    """
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    client.put("/mesaj-ayarlari", headers=y, json={
        "sms_saglayici": "netgsm", "sms_kullanici": "u1",
        "sms_parola": "gizli-parola", "sms_baslik": "YONETIO"})

    govde = client.get("/mesaj-ayarlari", headers=y).json()
    duz = str(govde)
    assert "gizli-parola" not in duz, "PAROLA SIZDI"
    assert "sms_parola" not in govde
    assert govde["sms_parola_var"] is True
    assert govde["sms_kullanici"] == "u1"  # sir OLMAYAN alanlar doner


def test_BOS_BIRAKILAN_PAROLA_MEVCUDU_KORUR(client, world):
    """Arayuz parolayi hic gormedigi icin, her kaydediste yeniden yazmak
    zorunda kalmak kullaniciyi parolayi bir yere kopyalamaya iterdi."""
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    client.put("/mesaj-ayarlari", headers=y, json={
        "sms_saglayici": "netgsm", "sms_kullanici": "u1",
        "sms_parola": "p1", "sms_baslik": "BASLIK"})
    # Parola ALANI HIC GONDERILMEDEN baska bir alan guncelleniyor.
    client.put("/mesaj-ayarlari", headers=y, json={"sms_baslik": "YENI"})
    govde = client.get("/mesaj-ayarlari", headers=y).json()
    assert govde["sms_baslik"] == "YENI"
    assert govde["sms_parola_var"] is True, "parola silinmis"


def test_ACIKCA_BOS_DIZGE_PAROLAYI_TEMIZLER(client, world):
    # Silmenin de bir yolu olmali; `None` "degistirme", `""` "temizle".
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    client.put("/mesaj-ayarlari", headers=y, json={"sms_parola": "p1"})
    assert client.get("/mesaj-ayarlari", headers=y).json()["sms_parola_var"] is True
    client.put("/mesaj-ayarlari", headers=y, json={"sms_parola": ""})
    assert client.get("/mesaj-ayarlari", headers=y).json()["sms_parola_var"] is False


# --------------------------------------------------------------------------- #
# 3. HAZIRLIK BAYRAGI — arayuz ONCEDEN uyarabilsin
# --------------------------------------------------------------------------- #
def test_HAZIR_BAYRAGI_gercek_secimle_AYNI_yoldan(client, world):
    """"Ayarlar dolu mu" diye ayrica bakmak, o kontrolun bir gun gercek
    saglayici seciminden ayrismasi demekti."""
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    # Yarim yapilandirma: saglayici secili ama parola yok.
    client.put("/mesaj-ayarlari", headers=y, json={
        "sms_saglayici": "netgsm", "sms_kullanici": "u", "sms_parola": "",
        "sms_baslik": ""})
    assert client.get("/mesaj-ayarlari", headers=y).json()["sms_hazir"] is False

    client.put("/mesaj-ayarlari", headers=y, json={
        "sms_parola": "p", "sms_baslik": "B"})
    assert client.get("/mesaj-ayarlari", headers=y).json()["sms_hazir"] is True


# --------------------------------------------------------------------------- #
# 4. KOTA
# --------------------------------------------------------------------------- #
def test_KOTA_SIFIR_KABUL_ETMEZ(client, world):
    # `0` "sinirsiz" mi "kapali" mi belirsiz olurdu; NULL "sinir yok"
    # anlamini tasir ve kisit da bunu zorlar.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    assert client.put("/mesaj-ayarlari", headers=y,
                      json={"gunluk_kota": 0}).status_code == 422


def test_KOTA_kaydedilir_ve_KULLANIM_gorunur(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.put("/mesaj-ayarlari", headers=y, json={"gunluk_kota": 500})
    assert r.status_code == 200, r.text
    govde = client.get("/mesaj-ayarlari", headers=y).json()
    assert govde["gunluk_kota"] == 500
    # Kullanicinin "neden gonderilmiyor" sorusuyla bas basa kalmamasi icin
    # bugunku kullanim da doner.
    assert isinstance(govde["bugun_gonderilen"], int)


# --------------------------------------------------------------------------- #
# 5. YETKI
# --------------------------------------------------------------------------- #
def test_SAHA_ROLLERI_ayarlara_ULASAMAZ(client, world):
    # Saglayici parolasi tesisin sirridir.
    for kim in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[kim])
        assert client.get("/mesaj-ayarlari", headers=h).status_code == 403, kim
        assert client.put("/mesaj-ayarlari", headers=h,
                          json={"sms_baslik": "X"}).status_code == 403, kim


def test_DENETCI_ayarlari_DEGISTIREMEZ(client, world):
    d = _headers(client, world["slug_a"], world["denetci_a"])
    assert client.put("/mesaj-ayarlari", headers=d,
                      json={"sms_baslik": "X"}).status_code == 403
