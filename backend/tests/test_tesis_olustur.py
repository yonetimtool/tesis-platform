"""(P155r2 / §3) YONETICI SELF-SIGNUP — tesis uygulamadan acilir.

Sartname: "Tesis adini giriniz" alani. Ileri denince arka planda tesis
kodu uretilir (ilk 4 harf + YYAAGG) ve TESIS OLUSUR. Ayri bir admin
paneli adimi YOK.

BU DOSYANIN OLCTUGU DORT SEY:
  1. Tesis GERCEKTEN aciliyor, kod KURALA UYGUN ve oturum aciliyor.
  2. Kod uretimi kenar durumlari: Turkce harf, 4 harften kisa ad,
     rakamla baslayan ad, AYNI GUN AYNI AD cakismasi.
  3. Telefon normalizasyonu: 0532 / 532 / +90532 AYNI numaraya coker.
  4. Kotuye kullanim: ayni numara ikinci tesis acamaz, hiz siniri var.
"""
from __future__ import annotations

import re
import uuid


def _sso_jeton(eposta: str) -> str:
    """(P197) SSO baglama jetonu — callback'in urettiginin AYNISI.

    NEDEN GEREKLI: bu dosya `/auth/kayit/tesis-olustur`u PAROLA yoluyla
    suruyordu. P197'de e-posta ZORUNLU oldu (`app_user.email` NOT NULL,
    goc 0089) ve bu ucun e-posta kaynagi SAGLAYICIDIR — parola yolunda
    hicbir adres yok, dolayisiyla uc 422 `eposta_gerekli` doner.

    OLCULEN DAVRANISLAR DEGISMEDI (kod uretimi, Turkce harf, telefon
    normalizasyonu, hiz siniri, ayni numara ikinci tesis acamaz); yalnizca
    KIMLIK YONTEMI, urunde gercekten kullanilan yola cevrildi: web'in
    kayit sayfasi bu ucu YALNIZ sosyal yolda cagiriyor (parola yolu
    `yonetici-basvuru` -> `yonetici-dogrula` -> `yonetici-tesis`),
    mobilde ise hicbir ekran cagirmiyor.
    """
    from app.routers.oauth import _baglama_jetonu

    return _baglama_jetonu({
        "saglayici": "google",
        "subject": f"sub-{uuid.uuid4().hex}",
        "eposta": eposta,
        "email_verified": True,
        "ad": "SSO Yonetici",
    })


def _eposta() -> str:
    return f"p197-tesis-{uuid.uuid4().hex[:10]}@ornek.com"


def _tel() -> str:
    return "+9059" + str(uuid.uuid4().int)[:8]


def _ad(onek: str = "Sinama") -> str:
    """Her testte BENZERSIZ tesis adi — cakisma testleri HARIC.

    Ayni adin ayni gun ikinci kez kullanilmasi kod cakismasi uretir ve
    o davranis AYRICA olculuyor; oteki testlerin ona takilmamasi icin
    ad benzersizlestiriliyor.
    """
    return f"{onek} {uuid.uuid4().hex[:6]}"


def _olustur(client, **ek):
    govde = {
        "tesis_ad": _ad(),
        "ad": "Ayse Yonetici",
        "telefon": _tel(),
        # (P197) PAROLA yerine SSO: bkz. `_sso_jeton`.
        "baglama_jetonu": _sso_jeton(_eposta()),
    }
    govde.update(ek)
    return client.post("/auth/kayit/tesis-olustur", json=govde)


def test_P187_telefon_OPSIYONEL_tesis_acilir(client):
    """(P187) TELEFON OPSIYONEL: SSO 'yeni tesis' yolunda telefon toplanmaz;
    sema zorunlu birakilinca kayit 422 ile kilitleniyordu. Telefonsuz istek
    artik tesisi acar (201)."""
    r = client.post("/auth/kayit/tesis-olustur", json={
        "tesis_ad": _ad(), "ad": "Telefonsuz Yonetici",
        "baglama_jetonu": _sso_jeton(_eposta()),
    })
    assert r.status_code == 201, r.text


# ===================== 1) MUTLU YOL — UCTAN UCA ============================ #


def test_tesis_ACILIR_kod_uretilir_ve_OTURUM_acilir(client, owner_conn):
    """Tek istekte: tesis + yonetici + oturum. Admin adimi YOK."""
    tel = _tel()
    r = client.post("/auth/kayit/tesis-olustur", json={
        "tesis_ad": "Oltu Sitesi Sinama",
        "ad": "Ayse Yonetici",
        "telefon": tel,
        "baglama_jetonu": _sso_jeton(_eposta()),
    })
    assert r.status_code == 201, r.text
    veri = r.json()

    # Kod BICIMI: 4 harf + '-' + YYAAGG (+ cakismada '-NN').
    assert re.fullmatch(r"[A-Z]{4}-\d{6}(-[A-Za-z0-9]+)?", veri["tesis_kodu"]), (
        veri["tesis_kodu"]
    )
    assert veri["tesis_kodu"].startswith("OLTU-")
    assert veri["tesis_ad"] == "Oltu Sitesi Sinama"

    # OTURUM GERCEK: donen jetonla korumali bir uca girilebiliyor.
    jeton = veri["jetonlar"]["access_token"]
    me = client.get("/me", headers={"Authorization": f"Bearer {jeton}"})
    assert me.status_code == 200, me.text
    assert me.json()["role"] == "yonetici"

    # Ve kullanici BIRINCIL yonetici olarak yazilmis.
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT u.role::text, u.birincil, u.password_set, t.kurulum_tamamlandi "
            "FROM app_user u JOIN tenant t ON t.id = u.tenant_id "
            "WHERE u.telefon = %s", (tel,)
        )
        rol, birincil, parola_var, kurulum = cur.fetchone()
    # (P197) `password_set` artik FALSE: bu uc SOSYAL yoldur ve sosyal
    # yolda parola HIC YOKTUR — kimlik saglayicidadir. Eskiden test
    # parola yolunu suruyordu (bkz. `_sso_jeton` notu).
    assert (rol, birincil, parola_var) == ("yonetici", True, False)
    # Ad BU ISTEKTE verildi; kullaniciyi tekrar adlandirma ekranina
    # dusurmek sartname ADIM 4'e ("Ana ekran") aykiri olurdu.
    assert kurulum is True, "kurulum_tamamlandi=false — adlandirma ekrani tekrar cikar"


def test_SOSYAL_acilan_yoneticinin_PAROLASI_YOKTUR(client):
    """Kayittan sonra kullanici KAYDOLDUGU yontemle girer (sartname §3).

    (P197) TEST YENIDEN YAZILDI. Eskiden bu dosya ucu PAROLA yoluyla
    suruyordu ve "ayni parolayla giris" olculuyordu. O yol artik yok:
    ucun e-posta kaynagi saglayicidir (bkz. `_sso_jeton`). Kural
    degismedi, YONTEM degisti — sosyal yolla acilan yonetici parolasiz
    olur ve telefon+parola ile GIREMEZ; SSO ile girer.
    """
    tel = _tel()
    r = _olustur(client, telefon=tel)
    assert r.status_code == 201, r.text

    g = client.post("/auth/login-phone",
                    json={"phone": tel, "password": "CokGizliParola1"})
    assert g.status_code == 401, g.text


# ============ 2) KOD URETIMI — KENAR DURUMLAR (sartname §2) ================ #


def test_TURKCE_harfler_ASCII_koda_donusur(client):
    """Kod telefonda ELLE yazilir; klavyede `ş`/`ğ` aratmamali."""
    r = _olustur(client, tesis_ad=f"Şişli Güneş {uuid.uuid4().hex[:6]}")
    assert r.status_code == 201, r.text
    assert r.json()["tesis_kodu"].startswith("SISL-"), r.json()["tesis_kodu"]


def test_i_harfi_YEREL_BAGIMSIZ_donusur(client):
    """`upper('i')` Turkce ctype'ta `İ` dondurur ve suzgec onu ATARDI.

    Goc 0041 bunu `upper` SONRASI ikinci bir `translate` ile kapatti;
    burasi o kilidin yerinde durdugunu olcer.
    """
    r = _olustur(client, tesis_ad=f"istanbul konaklari {uuid.uuid4().hex[:6]}")
    assert r.status_code == 201, r.text
    assert r.json()["tesis_kodu"].startswith("ISTA-"), r.json()["tesis_kodu"]


def test_DORT_HARFTEN_KISA_ad_bicimi_BOZMAZ(client):
    """"As" -> `ASXX`: kod hep 4 harf + tarih olmali, kisa ad onu bozmamali."""
    r = _olustur(client, tesis_ad="As")
    assert r.status_code == 201, r.text
    kod = r.json()["tesis_kodu"]
    assert re.fullmatch(r"[A-Z]{4}-\d{6}(-[A-Za-z0-9]+)?", kod), kod
    assert kod.startswith("ASXX-"), kod


def test_RAKAMLA_BASLAYAN_ve_NOKTALAMALI_ad_bicimi_BOZMAZ(client):
    """Harf olmayan her sey ATILIR; geriye 4 harf kalmazsa `X` ile doldurulur."""
    r = _olustur(client, tesis_ad="34. Cadde Sitesi")
    assert r.status_code == 201, r.text
    kod = r.json()["tesis_kodu"]
    assert re.fullmatch(r"[A-Z]{4}-\d{6}(-[A-Za-z0-9]+)?", kod), kod
    # "34. Cadde Sitesi" -> rakam/noktalama atilir -> "CADD"
    assert kod.startswith("CADD-"), kod


def test_HIC_HARF_YOKSA_kod_yine_de_uretilir(client):
    """Tamamen rakamdan olusan ad: `XXXX` + tarih. 500 DEGIL."""
    r = _olustur(client, tesis_ad="1234 5678")
    assert r.status_code == 201, r.text
    assert r.json()["tesis_kodu"].startswith("XXXX-"), r.json()["tesis_kodu"]


def test_AYNI_GUN_AYNI_AD_cakismasi_RASTGELE_ek_alir(client):
    """Iki tesis ayni tabani uretir; ikincisi ek almali ve kod BENZERSIZ olmali."""
    ad = f"Cakisma {uuid.uuid4().hex[:6]}"
    a = _olustur(client, tesis_ad=ad)
    b = _olustur(client, tesis_ad=ad)
    assert a.status_code == 201 and b.status_code == 201, (a.text, b.text)

    ka, kb = a.json()["tesis_kodu"], b.json()["tesis_kodu"]
    assert ka != kb, "ayni gun ayni ad AYNI kodu uretti — benzersizlik yok"
    # Ikisi de ayni tabani paylasir; ikincisi ek tasir.
    taban = ka.split("-")[0]
    assert kb.startswith(taban + "-")
    assert len(kb.split("-")) == 3, f"ikinci kod ek TASIMIYOR: {kb}"


def test_ad_DEGISSE_BILE_kod_SABIT_kalir(client, owner_conn):
    """Kod bir KIMLIKTIR; ad duzeltilince degisirse dagitilmis kod olurdu."""
    r = _olustur(client, tesis_ad=f"Ilk Ad {uuid.uuid4().hex[:6]}")
    assert r.status_code == 201, r.text
    kod = r.json()["tesis_kodu"]

    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE tenant SET ad = %s WHERE kayit_kodu = %s RETURNING kayit_kodu",
            (f"Bambaska Ad {uuid.uuid4().hex[:6]}", kod),
        )
        sonraki = cur.fetchone()[0]
    assert sonraki == kod, "ad degisince kod da degisti — dagitilmis kodlar olurdu"


# ================= 3) TELEFON NORMALIZASYONU (sartname §2) ================= #


def test_0532_532_ve_90532_AYNI_numaraya_coker(client):
    """Kullanici hangi bicimde yazarsa yazsin ayni hesaba dusmeli.

    Olcum: birinci bicimle tesis acilir; oteki bicimler "zaten kayitli"
    der. Ayri hesap acilsaydi 201 donerlerdi.

    UC ISTEK — DAHA FAZLASI DEGIL: hiz siniri telefon basina 3'tur
    (`KOD_ISTEK_SINIRI`) ve dorduncu istek 429 alirdi. 429 aslinda
    normalizasyonun CALISTIGINI gosterir (sayac anahtari normalize
    numaradir, yani tum bicimler AYNI sayaci tuketmis olur) ama bu
    DOLAYLI bir kanittir; test dogrudan olcecek kadar istek yapiyor.
    Sartnamenin saydigi uc bicim (0532 / 532 / +90532) tam olarak
    bu ucudur.
    """
    govde = str(uuid.uuid4().int)[:9]  # 9 hane: 5XXXXXXXX
    yerel = "5" + govde[:8]
    ilk = client.post("/auth/kayit/tesis-olustur", json={
        "tesis_ad": _ad(), "ad": "Ayse", "telefon": f"+90{yerel}",
        "baglama_jetonu": _sso_jeton(_eposta()),
    })
    assert ilk.status_code == 201, ilk.text

    for bicim in (f"0{yerel}", yerel):
        r = client.post("/auth/kayit/tesis-olustur", json={
            "tesis_ad": _ad(), "ad": "Ayse", "telefon": bicim,
            "baglama_jetonu": _sso_jeton(_eposta()),
        })
        assert r.status_code == 409, (
            f"{bicim!r} AYRI bir hesap acti ({r.status_code}) — "
            f"normalizasyon calismiyor: {r.text}"
        )


def test_0090_oneki_de_AYNI_numaraya_coker(client):
    """`00` uluslararasi oneki de `+` ile ayni yere dusmeli.

    AYRI TEST: onceki testin hiz siniri butcesi (telefon basina 3) doldu;
    dorduncu bicimi oraya sikistirmak testi 429'a carpardi.
    """
    govde = str(uuid.uuid4().int)[:9]
    yerel = "5" + govde[:8]
    ilk = client.post("/auth/kayit/tesis-olustur", json={
        "tesis_ad": _ad(), "ad": "Ayse", "telefon": f"+90{yerel}",
        "baglama_jetonu": _sso_jeton(_eposta()),
    })
    assert ilk.status_code == 201, ilk.text

    r = client.post("/auth/kayit/tesis-olustur", json={
        "tesis_ad": _ad(), "ad": "Ayse", "telefon": f"0090{yerel}",
        "baglama_jetonu": _sso_jeton(_eposta()),
    })
    assert r.status_code == 409, r.text


def test_GECERSIZ_telefon_422(client):
    r = _olustur(client, telefon="abc")
    assert r.status_code == 422, r.text


# ===================== 4) KOTUYE KULLANIM =================================== #


def test_AYNI_NUMARA_ikinci_tesis_acamaz(client):
    """Telefon GLOBAL benzersiz — ikinci tesis 409."""
    tel = _tel()
    assert _olustur(client, telefon=tel).status_code == 201
    ikinci = _olustur(client, telefon=tel)
    assert ikinci.status_code == 409, ikinci.text
    assert ikinci.json()["error"]["code"] == "conflict"


def test_PAROLA_VE_SOSYAL_ikisi_birden_verilemez(client):
    """Sema kurali: yontem TEK olmali.

    (P197) IKISI DE ACIKCA VERILIYOR: `_olustur` artik varsayilan olarak
    SSO jetonu koyuyor, yani "parola ekle" demek yetmiyordu — istegin
    IKI yontemi birden tasidigini gostermek icin ikisi de yaziliyor.
    """
    r = _olustur(client, parola="CokGizliParola1",
                 baglama_jetonu=_sso_jeton(_eposta()))
    assert r.status_code == 422, r.text


def test_YONTEMSIZ_istek_reddedilir(client):
    r = client.post("/auth/kayit/tesis-olustur", json={
        "tesis_ad": _ad(), "ad": "Ayse", "telefon": _tel(),
    })
    assert r.status_code == 422, r.text


def test_HIZ_SINIRI_uygulanir(client):
    """Tesis acmak kotuye kullanilabilir bir yuzey — sinir SART.

    Sinir TELEFON basina; bu yuzden ayni numarayla art arda denenir.
    Ilk istek 201, sonrakiler 409 (numara dolu) ve sinir asilinca 429.
    """
    from app.hiz_siniri import KOD_ISTEK_SINIRI

    tel = _tel()
    kodlar = []
    for _ in range(KOD_ISTEK_SINIRI + 2):
        kodlar.append(_olustur(client, telefon=tel).status_code)

    assert kodlar[0] == 201, kodlar
    assert 429 in kodlar, f"hiz siniri HIC devreye girmedi: {kodlar}"
