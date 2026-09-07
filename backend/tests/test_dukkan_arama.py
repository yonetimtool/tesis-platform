"""(DUKKAN F3) KAMU ARAMA + SEO SAYFASI + SIRALAMA.

===========================================================================
NE KORUNUYOR
===========================================================================
1. GORUNURLUK: onaysiz/dogrulanmamis isletme aramaya SIZMAZ.
2. ESLESME: hizmet alanindan, ADRESTEN degil.
3. SEO ESIGI: sifir isletmede 404 (ince icerik alan adi genelini vurur).
4. SIRALAMA: deterministik ve ikincil anahtarli (sayfalama tutarli).
5. SIZINTI: kamu profili sahibe ozel alanlari DONDURMEZ.

Akis GERCEKTEN suruluyor: isletme acilir, onaylanir, aranir.
"""
from __future__ import annotations

import uuid

import pytest


def _tel() -> str:
    return f"+9053{uuid.uuid4().int % 10**8:08d}"


def _giris(client) -> dict:
    tel = _tel()
    kod = client.post("/dukkan/auth/telefon/kod",
                      json={"telefon": tel}).json()["dev_kod"]
    d = client.post("/dukkan/auth/telefon/dogrula",
                    json={"telefon": tel, "kod": kod}).json()
    return {"h": {"Authorization": f"Bearer {d['access_token']}"},
            "id": d["kullanici"]["id"]}


@pytest.fixture
def moderator(client, dukkan_conn):
    k = _giris(client)
    dukkan_conn.execute(
        "INSERT INTO dukkan.moderator (kullanici_id, atayan) VALUES (%s,'test') "
        "ON CONFLICT DO NOTHING", (k["id"],))
    return k


def _mahalle_idler(dukkan_conn, ilce="cekmekoy", n=3) -> list[str]:
    return [str(r[0]) for r in dukkan_conn.execute(
        "SELECT m.id FROM dukkan.mahalle m "
        "JOIN dukkan.ilce ic ON ic.id = m.ilce_id "
        "JOIN dukkan.il i ON i.id = ic.il_id "
        "WHERE i.slug='istanbul' AND ic.slug=%s ORDER BY m.slug LIMIT %s",
        (ilce, n)).fetchall()]


def _yayinla(client, dukkan_conn, moderator, *, ad, kategori="elektrikci",
             mahalle_idler=None, aciklama=None) -> str:
    """Isletmeyi ACIP ONAYLAYARAK yayina alir. Doner: slug.

    Akisin TAMAMI suruluyor — dogrudan SQL ile 'onayli' yazmak, onay
    yolundaki puan hesabini ve seviye kuralini ATLARDI.
    """
    k = _giris(client)
    r = client.post("/dukkan/isletme", headers=k["h"],
                    json={"ad": ad, "telefon": _tel(),
                          **({"aciklama": aciklama} if aciklama else {})})
    assert r.status_code == 201, r.text
    isl = r.json()["id"]
    assert client.put(f"/dukkan/isletme/{isl}/kategoriler", headers=k["h"],
                      json={"slugler": [kategori]}).status_code == 200
    assert client.put(f"/dukkan/isletme/{isl}/hizmet-alanlari", headers=k["h"],
                      json={"mahalle_idler": mahalle_idler
                            or _mahalle_idler(dukkan_conn)}).status_code == 200
    kod = client.post(f"/dukkan/isletme/{isl}/telefon/kod",
                      headers=k["h"]).json()["dev_kod"]
    assert client.post(f"/dukkan/isletme/{isl}/telefon/dogrula",
                       headers=k["h"], json={"kod": kod}).status_code == 200
    assert client.post(f"/dukkan/isletme/{isl}/basvur",
                       headers=k["h"]).status_code == 200
    assert client.post(f"/dukkan/moderasyon/isletme/{isl}/karar",
                       headers=moderator["h"],
                       json={"karar": "onayla"}).status_code == 200
    return client.get(f"/dukkan/isletme/{isl}", headers=k["h"]).json()["slug"]


# ==================================================================== #
# 1. GORUNURLUK
# ==================================================================== #

def test_ONAYSIZ_ISLETME_ARAMADA_CIKMAZ(client, dukkan_conn):
    """Seviye 0 ve `taslak` isletme aramada gorunmemeli.

    Kayit ucretsiz ve aninda; gorunur kilmak SAHTE ISLETMEYI (T3) davet
    etmek olurdu (docs/dukkan/03-guven-ve-fraud.md §3).
    """
    k = _giris(client)
    ad = f"Gizli {uuid.uuid4().hex[:6]}"
    client.post("/dukkan/isletme", headers=k["h"],
                json={"ad": ad, "telefon": _tel()})
    r = client.get("/dukkan/isletme-ara", params={"q": ad})
    assert r.status_code == 200
    assert r.json()["toplam"] == 0, "onaysiz isletme aramaya SIZDI"


def test_ASKIYA_ALINAN_ARAMADAN_DUSER(client, dukkan_conn, moderator):
    ad = f"Askı {uuid.uuid4().hex[:6]}"
    slug = _yayinla(client, dukkan_conn, moderator, ad=ad)
    assert client.get("/dukkan/isletme-ara", params={"q": ad}).json()["toplam"] == 1

    isl = dukkan_conn.execute(
        "SELECT id FROM dukkan.isletme WHERE slug=%s", (slug,)).fetchone()[0]
    client.post(f"/dukkan/moderasyon/isletme/{isl}/karar", headers=moderator["h"],
                json={"karar": "askiya_al", "gerekce": "Test"})
    assert client.get("/dukkan/isletme-ara", params={"q": ad}).json()["toplam"] == 0
    # Profil de kapanmali — ve 403 DEGIL 404: "var ama askida" bilgisi
    # kamuya acik olmamali.
    assert client.get(f"/dukkan/isletme-profil/{slug}").status_code == 404


# ==================================================================== #
# 2. ESLESME HIZMET ALANINDAN
# ==================================================================== #

def test_ESLESME_HIZMET_ALANINDAN_ADRESTEN_DEGIL(client, dukkan_conn, moderator):
    """Bir usta Cekmekoy'de oturup Kadikoy'e gidebilir.

    Isletmenin ADRESI hic girilmemis olsa bile, hizmet alani Kadikoy ise
    Kadikoy aramasinda CIKMALI.
    """
    kadikoy = _mahalle_idler(dukkan_conn, ilce="kadikoy", n=2)
    assert kadikoy, "kadikoy mahallesi bulunamadi"
    ad = f"Gezici {uuid.uuid4().hex[:6]}"
    _yayinla(client, dukkan_conn, moderator, ad=ad, mahalle_idler=kadikoy)

    r = client.get("/dukkan/isletme-ara",
                   params={"il": "istanbul", "ilce": "kadikoy", "q": ad})
    assert r.json()["toplam"] == 1, "hizmet alanindan eslesmedi"
    # Baska ilcede CIKMAMALI.
    r2 = client.get("/dukkan/isletme-ara",
                    params={"il": "istanbul", "ilce": "cekmekoy", "q": ad})
    assert r2.json()["toplam"] == 0


def test_MAHALLE_SUZGECI_IL_ILCE_ISTER(client):
    """Sessizce il/ilce'yi yok saymak, iki farkli ildeki ayni adli
    mahalleyi BIRLESTIRIRDI (Turkiye'de onlarca 'Merkez' var)."""
    r = client.get("/dukkan/isletme-ara", params={"mahalle": "catalmese"})
    assert r.status_code == 422, r.text
    r2 = client.get("/dukkan/isletme-ara", params={"ilce": "cekmekoy"})
    assert r2.status_code == 422


def test_TURKCE_HARFSIZ_ISLETME_ARAMASI(client, dukkan_conn, moderator):
    """Mahalle aramasinda olculen kusurun isletme adindaki karsiligi."""
    ad = f"Çilingir Şükrü {uuid.uuid4().hex[:5]}"
    _yayinla(client, dukkan_conn, moderator, ad=ad)
    for q in ("Çilingir Şükrü", "cilingir sukru", "CILINGIR"):
        r = client.get("/dukkan/isletme-ara", params={"q": q})
        assert r.json()["toplam"] >= 1, f"q={q!r} bulamadi"


# ==================================================================== #
# 3. SEO SAYFASI
# ==================================================================== #

def test_SEO_SAYFASI_SIFIR_ISLETMEDE_404(client):
    """Bos bir 'yakinda' sayfasi INCE ICERIKTIR ve ceza sayfa basina
    degil ALAN ADI GENELINE isler — 10 iyi sayfa da duser."""
    r = client.get("/dukkan/sayfa/istanbul/cekmekoy/catalmese/mobilya-tamiri")
    assert r.status_code == 404, r.text
    assert "isletme_yok" in r.text


def test_SEO_SAYFASI_VERI_DONDURUR(client, dukkan_conn, moderator):
    hedef = _mahalle_idler(dukkan_conn, n=1)
    ad = f"SEO {uuid.uuid4().hex[:6]}"
    _yayinla(client, dukkan_conn, moderator, ad=ad, mahalle_idler=hedef,
             aciklama="Test açıklaması")
    slug = dukkan_conn.execute(
        "SELECT slug FROM dukkan.mahalle WHERE id=%s", (hedef[0],)).fetchone()[0]

    r = client.get(f"/dukkan/sayfa/istanbul/cekmekoy/{slug}/elektrikci")
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["konum"]["ilce"] == "Çekmeköy"
    assert d["kategori"]["slug"] == "elektrikci"
    assert d["toplam"] >= 1
    assert any(x["ad"] == ad for x in d["isletmeler"])
    # Ic baglanti listeleri VAR (bos olabilir ama alan bulunmali):
    # istemci hep ayni sekilde okumali.
    assert "komsu_mahalleler" in d and "diger_kategoriler" in d


def test_SEO_SAYFASI_OLMAYAN_KATEGORI_404(client):
    r = client.get("/dukkan/sayfa/istanbul/cekmekoy/catalmese/boyle-yok")
    assert r.status_code == 404


def test_ANA_KATEGORI_SEO_SAYFASI_ACMAZ(client):
    """Ana kategori ('elektrik') sayfa acmamali: isletmeler ALT
    kategori seciyor ve ana kategori sayfasi hepsini karistirirdi."""
    r = client.get("/dukkan/sayfa/istanbul/cekmekoy/catalmese/elektrik")
    assert r.status_code == 404


# ==================================================================== #
# 4. SIRALAMA
# ==================================================================== #

def test_SIRALAMA_PUANI_ONAYDA_HESAPLANIR(client, dukkan_conn, moderator):
    """Onay `dogrulama_seviyesi` ve `onaylandi_at` degistiriyor — ikisi de
    formulun girdisi. Hesabi atlamak, yeni onaylanmis isletmenin puani 0
    kalarak listenin EN ALTINDA dogmasi demekti."""
    ad = f"Puan {uuid.uuid4().hex[:6]}"
    slug = _yayinla(client, dukkan_conn, moderator, ad=ad)
    puan = dukkan_conn.execute(
        "SELECT siralama_puani FROM dukkan.isletme WHERE slug=%s",
        (slug,)).fetchone()[0]
    assert puan > 0, f"onay sonrasi puan {puan}"


def test_SAYFALAMA_TUTARLI_ikincil_anahtar(client, dukkan_conn, moderator):
    """Esit puanlarda PostgreSQL sirayi GARANTI ETMEZ.

    ==================================================================
    ILK YAZIMDA BU TEST BOS YERE YESILDI
    ==================================================================
    Kilidi KIRARAK denedim: ikincil anahtari (`i.id`) kaldirdim ve test
    YINE GECTI. Sebep, olcumun kurulmamis olmasiydi — uretilen
    isletmelerin puanlari `yenilik` ve `profil` bilesenleri yuzunden
    BIRBIRINDEN FARKLIYDI, yani ORTADA ESITLIK YOKTU ve PostgreSQL
    zaten kararli bir sira uretiyordu.

    Test ancak esitligi KENDISI KURARSA bir sey olcer: asagida tum
    puanlar ayni degere sabitleniyor.
    """
    ortak = _mahalle_idler(dukkan_conn, n=1)
    sluglar = [
        _yayinla(client, dukkan_conn, moderator,
                 ad=f"Sıra{n}-{uuid.uuid4().hex[:5]}", mahalle_idler=ortak)
        for n in range(6)
    ]
    # ESITLIGI KURUYORUZ — olcumun on kosulu.
    dukkan_conn.execute(
        "UPDATE dukkan.isletme SET siralama_puani = 42 WHERE slug = ANY(%s)",
        (sluglar,))

    slug = dukkan_conn.execute(
        "SELECT slug FROM dukkan.mahalle WHERE id=%s", (ortak[0],)).fetchone()[0]
    ortak_p = {"il": "istanbul", "ilce": "cekmekoy", "mahalle": slug,
               "kategori": "elektrikci", "boyut": 2}

    goruldu: list[str] = []
    for sayfa in (1, 2, 3):
        r = client.get("/dukkan/isletme-ara", params=ortak_p | {"sayfa": sayfa})
        goruldu += [x["slug"] for x in r.json()["items"]]

    bizimkiler = [s for s in goruldu if s in set(sluglar)]
    assert len(bizimkiler) == len(set(bizimkiler)), (
        f"sayfalar arasinda TEKRAR var: {bizimkiler}"
    )
    # Ayni sorgu IKI KEZ ayni sirayi vermeli — kararlilik.
    ilk = [x["slug"] for x in client.get(
        "/dukkan/isletme-ara", params=ortak_p | {"sayfa": 1}).json()["items"]]
    ikinci = [x["slug"] for x in client.get(
        "/dukkan/isletme-ara", params=ortak_p | {"sayfa": 1}).json()["items"]]
    assert ilk == ikinci, "ayni sorgu FARKLI sira dondurdu"


def test_SIRALAMA_HER_SECENEKTE_BENZERSIZ_ANAHTARLA_BITER():
    """YAPISAL KILIT — ve neden davranissal olani YETMIYOR.

    ==================================================================
    OLCEMEDIGIM SEY
    ==================================================================
    Ikincil anahtari (`i.id`) kaldirip ustteki davranissal testi
    kosturdum: ESIT PUANLARLA BILE GECTI. Sebep, PostgreSQL'in bu veri
    boyutunda kararli bir plan (tek is parcacikli tarama) secmesi.

    Yani kararsizligi bir testte GUVENILIR BICIMDE ZORLAYAMIYORUM.
    Risk gercek — `ORDER BY` toplam bir siralama tanimlamadiginda sonuc
    SARTNAME GEREGI belirsizdir ve plan veri buyudukce ya da paralel
    tarama devreye girdiginde degisir — ama tetiklemesi bana bagli degil.

    Bu yuzden kilit YAPISAL: her siralama secenegi BENZERSIZ bir sutunla
    bitmeli. Davranissal test "bugun bozuk degil" der; bu test "bozulmasi
    MUMKUN degil" der.
    """
    from app.dukkan.arama import isletme_ara
    import inspect
    import textwrap

    kaynak = inspect.getsource(isletme_ara)

    # Sozluk degerlerini AST ile okuyoruz: regex tirnak kacislarinda
    # kirilgan ve bu testin kendisi bir kilit — kirilgan olmamali.
    import ast as _ast

    agac = _ast.parse(textwrap.dedent(kaynak))
    secenekler = {}
    for dugum in _ast.walk(agac):
        if isinstance(dugum, _ast.Dict) and dugum.keys and all(
            isinstance(k, _ast.Constant) for k in dugum.keys
        ):
            adaylar = {
                k.value: v.value
                for k, v in zip(dugum.keys, dugum.values)
                if isinstance(v, _ast.Constant) and isinstance(v.value, str)
            }
            if set(adaylar) == {"puan", "yeni", "ad"}:
                secenekler = adaylar
                break
    assert secenekler, "siralama secenekleri okunamadi"
    for ad, ifade in secenekler.items():
        assert ifade.rstrip().endswith("i.id"), (
            f"'{ad}' siralamasi benzersiz anahtarla BITMIYOR: {ifade!r}. "
            "Esit degerlerde PostgreSQL sirayi garanti etmez; sayfa 2'de "
            "ayni kayit tekrar cikabilir ya da biri hic gorunmeyebilir."
        )


def test_SIRALAMA_SECENEKLERI(client):
    for s in ("puan", "yeni", "ad"):
        assert client.get("/dukkan/isletme-ara",
                          params={"sirala": s}).status_code == 200
    assert client.get("/dukkan/isletme-ara",
                      params={"sirala": "rastgele"}).status_code == 422


# ==================================================================== #
# 5. KAMU PROFILI SIZDIRMAZ
# ==================================================================== #

def test_KAMU_PROFILI_SAHIBE_OZEL_ALANLARI_DONDURMEZ(
    client, dukkan_conn, moderator
):
    """Tek uc kullanip alan gizlemeye calismak, bir gun eklenen bir alani
    gizlemeyi unutmak demekti — bu yuzden kamu profili AYRI bir uc."""
    ad = f"Sızıntı {uuid.uuid4().hex[:6]}"
    slug = _yayinla(client, dukkan_conn, moderator, ad=ad)
    dukkan_conn.execute(
        "UPDATE dukkan.isletme SET vergi_no='1234567890', "
        "red_sebebi='gizli gerekce' WHERE slug=%s", (slug,))

    d = client.get(f"/dukkan/isletme-profil/{slug}").json()
    ham = str(d)
    for yasak in ("vergi_no", "1234567890", "red_sebebi", "gizli gerekce",
                  "askiya_alma_sebebi", "sahip_kullanici_id"):
        assert yasak not in ham, f"kamu profilinde '{yasak}' SIZDI"


def test_KAMU_PROFILI_BOLGELERI_ILCE_DUZEYINDE_OZETLER(
    client, dukkan_conn, moderator
):
    """40 mahalle secen bir isletmenin profilinde 40 satir sayfayi
    bogardi; uc ilce duzeyinde gruplayip SAYI veriyor."""
    onmahalle = _mahalle_idler(dukkan_conn, n=8)
    slug = _yayinla(client, dukkan_conn, moderator,
                    ad=f"Bölge {uuid.uuid4().hex[:6]}", mahalle_idler=onmahalle)
    d = client.get(f"/dukkan/isletme-profil/{slug}").json()
    assert len(d["hizmet_bolgeleri"]) == 1, d["hizmet_bolgeleri"]
    assert d["hizmet_bolgeleri"][0]["mahalle_sayisi"] == 8


# ==================================================================== #
# 6. SITEMAP
# ==================================================================== #

def _bos_mahalle(dukkan_conn, kategori_slug: str) -> tuple[str, str, str]:
    """HIC isletmesi olmayan bir mahalle bulur. Doner: (id, slug, ilce_slug).

    ==================================================================
    ILK YAZIMDA BU TEST SIRA-BAGIMLIYDI
    ==================================================================
    Sabit bir ilce ("uskudar") secmisti ve ayni takimda daha once kosan
    testler oraya isletme birakinca sayi esigi gecmis oluyordu; test
    IZOLASYONDA gecip TAM TAKIMDA DUSUYORDU.

    Cozum sabiti kaldirmak degil, ON KOSULU KURMAK: gercekten bos bir
    mahalle ARANIYOR. (Bu depoda ayni sinif bir kirilganlik
    `patrol-windows-pollution-flake` olarak kayitli.)
    """
    satir = dukkan_conn.execute(
        """
        SELECT m.id, m.slug, ic.slug
        FROM dukkan.mahalle m
        JOIN dukkan.ilce ic ON ic.id = m.ilce_id
        JOIN dukkan.il i ON i.id = ic.il_id
        WHERE i.slug = 'istanbul'
          AND NOT EXISTS (SELECT 1 FROM dukkan.isletme_hizmet_alani ha
                           WHERE ha.mahalle_id = m.id)
        ORDER BY random() LIMIT 1
        """
    ).fetchone()
    assert satir, "bos mahalle bulunamadi"
    return str(satir[0]), satir[1], satir[2]


def test_SITEMAP_ESIGI_UYGULANIR(client, dukkan_conn, moderator):
    """Esigi gecmeyen yol sitemap'e GIRMEZ — arama motoruna ince icerik
    tanitmak alan adi genelini vurur."""
    mid, slug, ilce = _bos_mahalle(dukkan_conn, "cilingir")
    _yayinla(client, dukkan_conn, moderator,
             ad=f"Tek {uuid.uuid4().hex[:6]}", mahalle_idler=[mid],
             kategori="cilingir")

    def var_mi(esik: int) -> bool:
        d = client.get("/dukkan/sitemap/sayfalar", params={"esik": esik}).json()
        return any(x["mahalle"] == slug and x["ilce"] == ilce
                   and x["kategori"] == "cilingir" for x in d["items"])

    assert var_mi(1), "esik 1'de yol yok"
    assert not var_mi(3), "TEK isletmeli yol esik 3'te sitemap'e GIRDI"
