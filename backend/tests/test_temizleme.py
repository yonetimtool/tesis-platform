"""(P171) SUNUCU TARAFI HTML TEMIZLEME — beyaz liste kilidi.

===========================================================================
EN PAHALI SONUC
===========================================================================
Temizlenmemis bir govdenin veri tabanina girmesi. Cizim artik ZENGIN
METIN (P170'teki duz-metne-cevirme kaldirildi), yani saklanan her sey
kullanicinin tarayicisinda YORUMLANIR. Tek bir `<img onerror>`, o metni
okuyan HER kullanicinin oturumunda kod calistirir.

===========================================================================
OLCULEN
===========================================================================
 1. Vektorler ATILIYOR: `<script>`, `on*`, `<iframe>`, `<svg>`, `<img>`,
    `javascript:`/`data:` semalari, `style`.
 2. MESRU BICIMLENDIRME KORUNUYOR — bu en az digeri kadar onemli:
    her seyi atan bir "temizleyici" guvenlidir ama urunu bozar ve P170'te
    tam olarak o bedel odenmisti.
 3. TEMIZLIK YAZMA ANINDA: uctan donen ve VERI TABANINDA duran deger
    temiz. Okuma anindaki temizlik, kirli veriyi saklayip her okuyanin
    dogru davranmasina guvenmek olurdu.
 4. DUZ METIN ALANLARI BU BORUDAN GECMIYOR: duyuru/etkinlik/karar defteri
    govdeleri HTML degildir; temizleyiciden gecirmek KORUMAZ, BOZAR
    ("5 < 10" -> "5 &lt; 10").
"""
from __future__ import annotations

import uuid

from app.temizleme import zengin_temizle


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# --------------------------------------------------------------------------- #
# 1. TEMIZLEYICININ KENDISI
# --------------------------------------------------------------------------- #
def test_SCRIPT_atilir():
    c = zengin_temizle("<p>Once</p><script>alert(1)</script><p>Sonra</p>")
    assert "script" not in c.lower()
    assert "alert" not in c
    assert "Once" in c and "Sonra" in c


def test_IMG_ONERROR_atilir():
    c = zengin_temizle('<img src=x onerror="alert(1)">Metin')
    assert "onerror" not in c.lower()
    assert "<img" not in c.lower()
    assert "Metin" in c


def test_SVG_ONLOAD_ve_IFRAME_atilir():
    c = zengin_temizle('<svg onload="alert(1)"></svg><iframe src="x"></iframe>Son')
    assert "onload" not in c.lower()
    assert "<svg" not in c.lower()
    assert "<iframe" not in c.lower()
    assert "Son" in c


def test_JAVASCRIPT_SEMASI_reddedilir():
    c = zengin_temizle('<a href="javascript:alert(1)">Tıkla</a>')
    # Metin kalir, HEDEF kalmaz.
    assert "javascript:" not in c.lower()
    assert "Tıkla" in c


def test_DATA_SEMASI_reddedilir():
    # `data:text/html;base64,...` de bir betik tasiyicisidir.
    c = zengin_temizle('<a href="data:text/html;base64,PHNjcmlwdD4=">X</a>')
    assert "data:" not in c.lower()


def test_STYLE_OZNITELIGI_ve_ETIKETI_atilir():
    c = zengin_temizle('<p style="position:fixed;top:0">A</p><style>body{}</style>')
    assert "style" not in c.lower()
    assert "A" in c


def test_ON_OZNITELIKLERI_toptan_atilir():
    # Beyaz liste kara liste DEGIL: adini saymadigimiz bir olay da gitmeli.
    c = zengin_temizle('<p onmouseover="alert(1)" onfocus="alert(2)">A</p>')
    assert "onmouseover" not in c.lower()
    assert "onfocus" not in c.lower()
    assert "<p>" in c


def test_MESRU_BICIMLENDIRME_KORUNUR():
    """Her seyi atan bir temizleyici guvenlidir ama urunu bozar.

    P170'te tam olarak o bedel odenmisti; bu turun sebebi de bu.
    """
    kaynak = (
        "<h2>Baslik</h2><p><strong>Kalin</strong> ve <em>italik</em></p>"
        "<ul><li>Bir</li><li>Iki</li></ul>"
        '<a href="https://ornek.test" title="Bag">Baglanti</a>'
        "<blockquote>Alinti</blockquote><hr>"
    )
    c = zengin_temizle(kaynak)
    for parca in ("<h2>", "<strong>", "<em>", "<ul>", "<li>", "<blockquote>", "<hr"):
        assert parca in c, parca
    assert 'href="https://ornek.test"' in c
    assert 'title="Bag"' in c


def test_BAGLANTIYA_REL_EKLENIR():
    # `target=_blank` ile acilan sayfa `window.opener` uzerinden bizi
    # yonlendirebilirdi (tabnabbing).
    c = zengin_temizle('<a href="https://ornek.test">X</a>')
    assert "noopener" in c


def test_TEMIZLEME_ETKISIZ_METINDE_DEGISTIRMEZ():
    # Duz metin beyaz listeden DEGISMEDEN gecmeli; aksi halde SMS
    # sablonlari sessizce bozulurdu.
    duz = "Sayin {ad}, aidat borcunuz {tutar} TL."
    assert zengin_temizle(duz) == duz


# --------------------------------------------------------------------------- #
# 2. UCLAR — YAZMA ANINDA TEMIZLENIYOR
# --------------------------------------------------------------------------- #
_ZEHIR = '<p>Yasal metin</p><img src=x onerror="alert(1)"><script>alert(2)</script>'


def test_KVKK_UCU_govdeyi_TEMIZ_saklar(client, world, owner_conn):
    a = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post(f"/tenants/{world['a']}/kvkk", headers=a, json={
        "tur": "gizlilik", "baslik": "Gizlilik", "govde": _ZEHIR})
    assert r.status_code == 201, r.text

    # 1) UCTAN DONEN temiz.
    assert "onerror" not in r.json()["govde"].lower()
    assert "<script" not in r.json()["govde"].lower()
    assert "Yasal metin" in r.json()["govde"]

    # 2) VERI TABANINDA duran da temiz — asil iddia bu. Okuma anindaki
    #    temizlik kirli veriyi saklardi ve yeni bir istemci korumasiz
    #    kalirdi.
    satir = owner_conn.execute(
        "SELECT govde FROM kvkk_metin WHERE tenant_id = %s AND tur = 'gizlilik' "
        "ORDER BY surum DESC LIMIT 1", (world["a"],)).fetchone()
    assert "onerror" not in satir[0].lower()
    assert "<script" not in satir[0].lower()


def test_KVKK_OKUMA_UCU_de_temiz_doner(client, world):
    a = _headers(client, world["slug_a"], world["admin_a"])
    client.post(f"/tenants/{world['a']}/kvkk", headers=a, json={
        "tur": "cerez", "baslik": "Cerez", "govde": _ZEHIR})

    r_ = _headers(client, world["slug_a"], world["resident_a"])
    g = client.get("/kvkk/metin?tur=cerez", headers=r_)
    assert g.status_code == 200, g.text
    assert "onerror" not in g.json()["govde"].lower()


def test_MESAJ_SABLONU_govdesi_TEMIZ_saklanir(client, world, owner_conn):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/mesaj-sablonlari", headers=y, json={
        "kanal": "eposta", "ad": f"Sablon {uuid.uuid4().hex[:6]}",
        "konu": "Konu", "govde": _ZEHIR})
    assert r.status_code == 201, r.text
    assert "onerror" not in r.json()["govde"].lower()

    satir = owner_conn.execute(
        "SELECT govde FROM mesaj_sablonu WHERE id = %s", (r.json()["id"],)
    ).fetchone()
    assert "onerror" not in satir[0].lower()


def test_MESAJ_ONIZLEME_de_temizlenir(client, world):
    """Onizleme saklanmaz AMA EKRANDA CIZILIR.

    Temizlenmemis birakmak, "kaydetmeden once dene" yoluyla acilmis bir
    enjeksiyon kapisi olurdu.
    """
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/mesajlar/onizleme", headers=y, json={
        "govde": _ZEHIR, "kanal": "eposta"})
    assert r.status_code == 200, r.text
    assert "onerror" not in r.json()["govde"].lower()


def test_UZUNLUK_SINIRI_KULLANICININ_metnine_uygulanir(client, world):
    """`AfterValidator` uzunluk dogrulamasindan SONRA calisir.

    Tersi olsaydi 4000 karakteri asan bir govde, temizlik onu kisalttigi
    icin SESSIZCE kabul edilirdi ve sinir anlamini yitirirdi.
    """
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/mesaj-sablonlari", headers=y, json={
        "kanal": "sms", "ad": "Uzun", "govde": "x" * 4001})
    assert r.status_code == 422, r.text


# --------------------------------------------------------------------------- #
# 3. SINIFLANDIRMA KILIDI — HANGI ALAN HTML, HANGISI DUZ METIN
# --------------------------------------------------------------------------- #
#: Zengin metin KABUL EDEN alanlar. Bunlar `ZenginHtml` tipiyle yazilmali;
#: yeni bir tanesi eklenip tip unutulursa asagidaki test kirilir.
ZENGIN_ALANLAR = {
    ("KvkkMetinCreate", "govde"),
    ("MesajSablonuCreate", "govde"),
    ("MesajSablonuUpdate", "govde"),
    ("MesajOnizlemeIstek", "govde"),
}

#: DUZ METIN alanlari — bilincli olarak temizleyiciden GECMEZLER.
#:
#: Hicbiri zengin metin editoruyle yazilmiyor ve hicbir istemci onlari
#: HTML olarak cizmiyor. HTML temizleyicisinden gecirmek KORUMAZ, BOZAR:
#: "5 < 10" yazan bir duyuru `5 &lt; 10` olarak saklanir ve kullaniciya
#: oyle gorunur. Korumalari cizim tarafinda ve orada kilitli
#: (`admin-web/tests/duz-metin-alanlari.test.ts`).
DUZ_METIN_ALANLARI = {
    ("AnnouncementCreate", "govde"),
    ("AnnouncementUpdate", "govde"),
    ("SiteKuraliCreate", "icerik"),
    ("SiteKuraliUpdate", "icerik"),
    ("KararDefteriCreate", "metin"),
    ("KararDefteriUpdate", "metin"),
    ("EtkinlikCreate", "aciklama"),
    ("EtkinlikUpdate", "aciklama"),
    ("ComplaintCreate", "mesaj"),
    ("SupportTicketCreate", "aciklama"),
    ("SupportTicketUpdate", "admin_cevap"),
    ("EkCreate", "metin"),
    ("AnketCreate", "aciklama"),
    ("AnketUpdate", "aciklama"),
    ("HatirlatmaBase", "aciklama"),
    ("ViolationCreate", "aciklama"),
    ("DokumanCreate", "aciklama"),
    ("IcraDosyasiCreate", "aciklama"),
}


#: Denetimde kullanilan zehir. Temizlenirse `onerror` KAYBOLUR.
_SONDA = '<p>A</p><img src=x onerror="alert(1)">'


def _alan_turu(bilgi):
    """Alanin TAM tipi: `annotation` + ayrik tutulan `metadata`.

    Pydantic ikisini AYRI saklar ve sekli alanin yazilisina gore degisir:
      * `ZenginHtml`        -> annotation=`str`, metadata=[AfterValidator]
      * `ZenginHtml | None` -> annotation=birlesim (Annotated ICINDE), metadata=[]
    Yalniz birine bakan bir denetim, iki durumdan birini KACIRIR — ilk
    yazimda ikisi de kacirildi, ters yonlerde.
    """
    from typing import Annotated

    if not bilgi.metadata:
        return bilgi.annotation
    return Annotated[tuple([bilgi.annotation, *bilgi.metadata])]


def _tur_temizliyor_mu(anot) -> bool:
    """Bir alan TIPI, zehirli bir govdeyi temizliyor mu.

    DAVRANISSAL OLCUM, USTVERI OKUMASI DEGIL — ve bu ayrim testin ilk
    yaziminda ISE YARADI: `ZenginHtml | None` alanlarinda `AfterValidator`
    alanin ustverisinde DEGIL, birlesim uyesinin icinde durur. Ustveriye
    bakan bir denetim, temizlik GERCEKTEN calisiyorken "calismiyor"
    diyordu. Tipi calistirmak bu belirsizligi tamamen ortadan kaldirir.
    """
    from pydantic import TypeAdapter

    try:
        sonuc = TypeAdapter(anot).validate_python(_SONDA)
    except Exception:
        # Tip bir dizge kabul etmiyorsa (sayi, enum, liste) zengin metin
        # alani da degildir.
        return False
    return isinstance(sonuc, str) and "onerror" not in sonuc.lower()


def _alan_temizleniyor_mu(sinif_adi: str, alan: str) -> bool:
    import app.schemas as semalar

    sinif = getattr(semalar, sinif_adi)
    return _tur_temizliyor_mu(_alan_turu(sinif.model_fields[alan]))


def test_ZENGIN_ALANLARIN_HEPSI_temizleniyor():
    eksik = [
        f"{c}.{a}" for c, a in sorted(ZENGIN_ALANLAR)
        if not _alan_temizleniyor_mu(c, a)
    ]
    assert not eksik, f"ZenginHtml tipi verilmemis: {eksik}"


def test_DUZ_METIN_ALANLARI_temizleyiciden_GECMEZ():
    """Ters yon de kilitli.

    Bir gun biri "her yeri temizleyelim" derse bu test kirilir ve kararin
    NEDENI karsisina cikar: duz metni HTML temizleyicisinden gecirmek
    korumaz, bozar.
    """
    yanlis = [
        f"{c}.{a}" for c, a in sorted(DUZ_METIN_ALANLARI)
        if _alan_temizleniyor_mu(c, a)
    ]
    assert not yanlis, (
        "Duz metin alani HTML temizleyicisinden geciriliyor "
        f"(icerigi bozar): {yanlis}"
    )


def test_ZENGIN_ALAN_ENVANTERI_EKSIKSIZ():
    """Semada `ZenginHtml` kullanan AMA envanterde olmayan alan kalmasin.

    Envanter bir GOZDEN GECIRME kapisidir: yeni bir zengin metin alani,
    kimse bakmadan semaya giremez.
    """
    import app.schemas as semalar

    bulunan = set()
    for ad in dir(semalar):
        sinif = getattr(semalar, ad)
        alanlar = getattr(sinif, "model_fields", None)
        if not isinstance(alanlar, dict):
            continue
        for alan, bilgi in alanlar.items():
            if _tur_temizliyor_mu(_alan_turu(bilgi)):
                bulunan.add((ad, alan))
    assert bulunan == ZENGIN_ALANLAR, (
        f"envanterde olmayan: {sorted(bulunan - ZENGIN_ALANLAR)}; "
        f"semada olmayan: {sorted(ZENGIN_ALANLAR - bulunan)}"
    )
