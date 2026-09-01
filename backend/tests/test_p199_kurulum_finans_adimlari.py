"""(P199) KURULUM SIHIRBAZI — FINANS ADIMLARI.

Olculen sey su kusurdu: sihirbaz "tamam" diyordu ama tesisin finans
modulu KULLANILAMAZ kaliyordu. Aidat turu (gelir/gider tanimi) yoksa
toplu borclandirma 422 doner; yonetici bunu ancak ilk aidati yazmaya
calisirken ogreniyordu.

Uc sey kilitlenir:
  1. `gelir_gider_tanimi` ZORUNLU ve AIDATTAN ONCE gelir,
  2. otomasyon adimi VERIDEN sayilmaz — "sorulmadi" ile "bakti, kapali
     birakti" AYRI durumlardir,
  3. P192 karari korunur: sihirbaz hicbir otomasyonu ACMAZ.
"""
from __future__ import annotations


def _giris(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _adimlar(client, basliklar):
    r = client.get("/kurulum", headers=basliklar)
    assert r.status_code == 200, r.text
    return {a["kod"]: a for a in r.json()["adimlar"]}, r.json()


def test_GELIR_GIDER_TANIMI_zorunlu_ve_AIDATTAN_ONCE(client, world):
    """Sira bir CIZIM tercihi degil, OLCULEN bir bagimlilik.

    `POST /borclandirma/toplu/onizleme` `gelir_gider_tanim_id` ister
    (P193 §6'da 422 "Field required" olarak olculdu). Sihirbaz aidati
    once sorsaydi, yonetici gidip 422 yiyecekti.
    """
    yon = _giris(client, world["slug_a"], world["yonetici_a"])
    adimlar, govde = _adimlar(client, yon)

    assert adimlar["gelir_gider_tanimi"]["zorunlu"] is True
    kodlar = [a["kod"] for a in govde["adimlar"]]
    assert kodlar.index("kasa") < kodlar.index("gelir_gider_tanimi")
    assert kodlar.index("gelir_gider_tanimi") < kodlar.index("aidat")


def test_TOPLU_BORCLANDIRMA_TANIMSIZ_reddeder(client, world):
    """Adimin ZORUNLU olmasinin GEREKCESI — iddia degil, olcum.

    Tanim kimligi olmadan istek 422 doner. Bu test kirilirsa (uc artik
    tanim istemiyorsa) adimin zorunlulugu yeniden dusunulmelidir.
    """
    # ADMIN ile cagriliyor cunku OLCTUK: toplu borclandirma ucu hâlâ
    # ADMIN'e kapali degil, YONETICI'ye kapali (yonetici 403 aliyor).
    # Bu P193 §3'te acik birakilan ayri bir madde; burada olculen sey
    # tanimsiz istegin REDDEDILDIGI, rol kapisi degil.
    yon = _giris(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/borclandirma/toplu/onizleme",
        headers=yon,
        json={"donem": "2026-01", "tutar_kurus": 50000, "dagitim": "esit"},
    )
    assert r.status_code == 422, r.text


def test_ISTEGE_BAGLI_FINANS_ADIMLARI_atlanabilir(client, world):
    """Aidatini her ay ELIYLE yazan tesis de calisan bir tesistir.

    Bu dort adim zorunlu OLMAMALI; zorunlu yapmak, calisan bir tesise
    "eksiksin" demek olurdu.
    """
    yon = _giris(client, world["slug_a"], world["yonetici_a"])
    adimlar, _ = _adimlar(client, yon)
    for kod in ("aidat_plani", "otomasyon", "butce_kategorisi", "duzenli_gider"):
        assert adimlar[kod]["zorunlu"] is False, kod
        r = client.patch("/kurulum", headers=yon, json={"kod": kod, "atla": True})
        assert r.status_code == 200, r.text
        y = {a["kod"]: a for a in r.json()["adimlar"]}
        assert y[kod]["atlandi"] is True
        client.patch("/kurulum", headers=yon, json={"kod": kod, "atla": False})


def test_OTOMASYON_adimi_SORULMADI_ile_KAPALI_BIRAKILDIyi_AYIRIR(client, world):
    """Adimin can alici noktasi.

    Otekiler "satir var mi" diye sorar. Burada dogru cevap "hicbirini
    acma" olabilir; kapali bir hatirlatma ayari, hic sorulmamisla ayni
    gorunur. Ustelik ayar satirini GET de yaratir (get-or-create), yani
    "satir var" olcut OLAMAZ.

    Bu yuzden olculen sey KARARIN KAYDEDILMESIDIR (goc 0090).
    """
    yon = _giris(client, world["slug_a"], world["yonetici_a"])

    # 1) Ayari OKUMAK adimi tamamlamaz — satiri yaratsa bile.
    r = client.get("/hatirlatma-ayari", headers=yon)
    assert r.status_code == 200, r.text
    assert r.json()["aktif"] is False, "P192: hatirlatma VARSAYILAN KAPALI"
    adimlar, _ = _adimlar(client, yon)
    assert adimlar["otomasyon"]["tamam"] is False, (
        "ekrani acmak karar degildir — GET adimi tamamlamamali"
    )

    # 2) KAPALI birakmayi KAYDETMEK gecerli bir karardir ve adimi bitirir.
    r = client.patch(
        "/hatirlatma-ayari", headers=yon, json={"aktif": False}
    )
    assert r.status_code == 200, r.text
    assert r.json()["aktif"] is False, "sihirbaz hicbir otomasyonu ACMAZ"
    adimlar, _ = _adimlar(client, yon)
    assert adimlar["otomasyon"]["tamam"] is True


def test_GECIKME_AYARINI_KAYDETMEK_de_otomasyon_kararidir(client, world):
    """Otomasyon tercihi iki ekrana yayilir (hatirlatma / gecikme faizi).
    Ikisinden HANGISI kaydedilirse kaydedilsin, yonetici SORULANI
    yanitlamis olur."""
    yon = _giris(client, world["slug_a"], world["admin_a"])
    r = client.patch(
        "/borclandirma/gecikme-ayari",
        headers=yon,
        json={"gecikme_uygula": False},
    )
    assert r.status_code == 200, r.text
    yonetici = _giris(client, world["slug_a"], world["yonetici_a"])
    adimlar, _ = _adimlar(client, yonetici)
    assert adimlar["otomasyon"]["tamam"] is True
