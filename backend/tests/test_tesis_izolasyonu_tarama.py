"""TESİS İZOLASYONU — HER LİSTELEME UCU İÇİN KALICI KAPI.

===========================================================================
NEDEN BU DOSYA VAR
===========================================================================
Bir tesisin yöneticisinin BAŞKA tesisin verisini görmesi kişisel veri
sızıntısıdır ve KVKK ihlalidir. Ürünün savunması RLS'tir (her tenant
tablosunda `ENABLE` + `FORCE ROW LEVEL SECURITY`, politika
`tenant_id = current_setting('app.current_tenant_id')`), ama RLS'in
"açık olduğunu" bilmek yetmez: **bir ucun o bağlamı KURMADAN sorgu
çalıştırması** ya da RLS'i atlayan bir `SECURITY DEFINER` fonksiyonu
çağırması sızıntıyı geri getirir. Bu dosya iddiayı DAVRANIŞTAN ölçer.

===========================================================================
ÖLÇÜM YÖNTEMİ — "B'nin hiçbir kimliği A'nın yanıtında geçmesin"
===========================================================================
B tesisine her ana tabloda birer satır yazılır (doğrudan SQL, owner ile:
uçların yazma kuralları bu ölçümün konusu değil). Sonra A tesisinin
yöneticisi/admini her listeleme ucunu çağırır ve yanıt METNİNDE B'ye ait
hiçbir UUID ya da işaret dizesi geçmemelidir.

Kimlik araması ALAN ADINDAN BAĞIMSIZDIR ve bu bilinçli: bir uç sızıntıyı
`items[].id` yerine `meta`, `ozet` ya da iç içe bir alanda yapabilir;
alan alan bakmak, bakmayı unuttuğumuz alanı savunmasız bırakırdı.

===========================================================================
PLATFORM YÜZEYİ AYRIDIR (karıştırılmaz)
===========================================================================
`panel.*` platform sahibinindir ve `/tenants`, `/audit`, `/admin/overview`,
`/support/all` uçları TESİSLER ARASI olmak ZORUNDADIR — platform konsolu
budur. Onlar için ölçüm tersine çevrilir: **tesis rolleri (yonetici) bu
uçlara ERİŞEMEMELİDİR** (403). Böylece "platform admini her şeyi görür"
kuralı korunurken, tesis yöneticisinin o kapıdan geçemediği kilitlenir.
"""
from __future__ import annotations

import re
import uuid

import pytest

#: Tesis-kapsamlı listeleme uçları. HEPSİ A'nın yöneticisi/admini olarak
#: çağrılır ve yanıtta B'nin hiçbir kimliği geçmemelidir.
#:
#: Liste ELLE tutuluyor ama BOŞ KALAMAZ: `test_tarama_kapsami_daralmadi`
#: uygulamadaki GET uç sayısıyla karşılaştırır — yeni bir liste ucu eklenip
#: buraya yazılmazsa kapsam sessizce daralmasın.
TESIS_UCLARI: tuple[str, ...] = (
    "/users",
    "/units",
    "/residents",
    "/blocks",
    "/tasks",
    "/task-completions",
    "/task-categories",
    "/complaints",
    "/unit-complaints",
    # (P222 §1) Izgara sayaci. TESIS-KAPSAMLI: `get_tenant_db` ile RLS
    # baglami kurar ve yalniz o tesisin sikayetlerini sayar. Taramaya
    # yazilmasaydi kapsam orani sessizce duserdi — nitekim tam suite'te
    # `test_tarama_kapsami_daralmadi` bunu YAKALADI.
    "/unit-complaints/gorunur-sayi",
    "/assets",
    "/cameras",
    "/announcements",
    "/notifications",
    "/events",
    "/site-rules",
    "/anketler",
    "/checkpoints",
    "/patrol-plans",
    "/patrol-windows",
    "/scans",
    "/shifts",
    "/visitors",
    "/kargo",
    "/reservations",
    "/common-areas",
    "/dues/assessments",
    "/dues/payments",
    "/finans/hareketler",
    "/finans/icra-dosyalari",
    "/finans/kasa-bakiyeleri",
    "/finans/ozet",
    "/kasalar",
    "/firmalar",
    "/gelir-gider-tanimlari",
    "/gelir-gider-gruplari",
    "/budget/entries",
    "/budget/categories",
    "/banka/hareketler",
    "/devices",
    "/push/teshis",
    "/karar-defteri",
    "/dokumanlar",
    "/hatirlatmalar",
    "/mesajlar/gecmis",
    "/mesaj-sablonlari",
    "/personel-kayitlari",
    "/vehicle-passes",
    "/violations",
    "/arac-kayitlari",
    "/unit-access-request",
    "/external-services",
    "/integrations",
    "/activity",
    "/dashboard/live",
    "/takvim",
    "/unit-gruplari",
    "/unit-tipleri",
    "/unit-uyarilari",
    "/sayaclar/ana",
    "/sayaclar/bolum",
    "/transparency",
    "/raporlar/isler",
    "/yonetici-iletisim",
    "/support",
    # (GUVENLIK) COK KAYNAKLI ARAMA: tek uc, sekiz tabloyu tarar — bir
    # kaynagi suzgecsiz birakmak butun tesisleri aramaya acardi.
    "/arama",
    # --- (P192) FINANS TUTARLILIGI VE OTOMASYONU -------------------------- #
    #
    # Hepsi TESISE AIT okuma yollari. Yaslandirma ve hatirlatma gecmisi
    # ozellikle onemli: ikisi de KISI ADI dondurur, yani bir suzgec
    # bosluğu dogrudan kisisel veri sizintisi olurdu.
    "/aidat-planlari",
    "/duzenli-giderler",
    "/otomasyon-gunlugu",
    "/hatirlatma-ayari",
    "/finans/yaslandirma",
    "/finans/tahsilat-gostergesi",
    "/finans/hatirlatma-gecmisi",
    "/budget/hedefler",
    "/budget/karsilastirma",
    "/borclandirma/gecikme-ayari",
    "/borclandirma/gecikme-faizi/onizleme",
)

#: PLATFORM uçları — tesisler arası olmak ZORUNDA (panel konsolu).
#: Ölçüm tersine: tesis rolü bunlara ERİŞEMEZ.
PLATFORM_UCLARI: tuple[str, ...] = (
    "/tenants",
    "/audit",
    "/admin/overview",
    "/support/all",
)


#: Bazi uclar kendi sinirlarini/zorunlu parametrelerini dayatir. Ucun
#: sozlesmesini test icin GEVSETMEYIZ; test uca UYAR.
_PARAMETRELER: dict[str, dict] = {
    "/activity": {"limit": 50},
    "/raporlar/isler": {"limit": 50},
    # Takvim en fazla 120 gunluk aralik kabul eder — sinir UCUN kurali,
    # test ona uyar.
    "/takvim": {"baslangic": "2026-01-01", "bitis": "2026-03-31"},
    # Arama: B tesisine yazdigimiz kayitlarin ISARETI aranir — sizinti
    # varsa dogrudan gorunur.
    "/arama": {"q": "__IZ__"},
    # (P192 §5.4) Butce karsilastirmasi yil ZORUNLU ister.
    "/budget/karsilastirma": {"yil": 2026},
}


#: İsteğin kendisini yankılayan alanlar (sızıntı değil).
_YANKI = re.compile(r'"q"\s*:\s*"[^"]*"')


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def b_izleri(world, owner_conn) -> dict:
    """B tesisine her ana tabloda BİRER satır yazar; kimliklerini döner.

    Doğrudan SQL: uçların yazma kuralları (rol, doğrulama) bu ölçümün
    konusu DEĞİL; ölçülen tek şey OKUMA yolunun tenant sınırıdır.
    """
    b = world["b"]
    iz = uuid.uuid4().hex[:10].upper()
    idler: dict[str, str] = {}
    with owner_conn.cursor() as cur:
        cur.execute("SELECT set_config('app.current_tenant_id', %s, false)", (str(b),))
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id = %s LIMIT 1", (b,)
        )
        b_user = cur.fetchone()[0]

        cur.execute(
            "INSERT INTO unit (tenant_id, no, blok) VALUES (%s,%s,'B') RETURNING id",
            (b, f"BZ-{iz}"),
        )
        idler["unit"] = str(cur.fetchone()[0])

        cur.execute(
            "INSERT INTO task (tenant_id, ad, aktif) VALUES (%s,%s,true) RETURNING id",
            (b, f"BGOREV-{iz}"),
        )
        idler["task"] = str(cur.fetchone()[0])

        cur.execute(
            "INSERT INTO announcement (tenant_id, baslik, govde, olusturan_user_id) "
            "VALUES (%s,%s,%s,%s) RETURNING id",
            (b, f"BDUYURU-{iz}", "x", b_user),
        )
        idler["announcement"] = str(cur.fetchone()[0])

        cur.execute(
            "INSERT INTO camera (tenant_id, ad, stream_url, tur) "
            "VALUES (%s,%s,%s,'hls') RETURNING id",
            (b, f"BKAM-{iz}", "https://ornek.test/b.m3u8"),
        )
        idler["camera"] = str(cur.fetchone()[0])

        cur.execute(
            "INSERT INTO complaint (tenant_id, baslik, mesaj, acan_user_id) "
            "VALUES (%s,%s,%s,%s) RETURNING id",
            (b, f"BTALEP-{iz}", "x", b_user),
        )
        idler["complaint"] = str(cur.fetchone()[0])

        cur.execute(
            "INSERT INTO notification (tenant_id, tip, mesaj, user_id) "
            "VALUES (%s,'kargo',%s,%s) RETURNING id",
            (b, f"BBILDIRIM-{iz}", b_user),
        )
        idler["notification"] = str(cur.fetchone()[0])

        cur.execute(
            "INSERT INTO finansal_hareket (tenant_id, tip, yon, tutar_kurus, aciklama) "
            "VALUES (%s,'gelir','giris',12345,%s) RETURNING id",
            (b, f"BHAREKET-{iz}"),
        )
        idler["finansal_hareket"] = str(cur.fetchone()[0])

        cur.execute(
            "INSERT INTO bank_transaction (tenant_id, external_transaction_id, "
            "islem_tarihi, tutar_kurus, yon, aciklama) "
            "VALUES (%s,%s,CURRENT_DATE,999,'giris',%s) RETURNING id",
            (b, f"BEXT-{iz}", f"BBANKA-{iz}"),
        )
        idler["bank_transaction"] = str(cur.fetchone()[0])

        cur.execute("SELECT id FROM app_user WHERE tenant_id = %s", (b,))
        b_kullanicilar = [str(r[0]) for r in cur.fetchall()]
    owner_conn.commit()
    return {"iz": iz, "idler": idler, "kullanicilar": b_kullanicilar}


def _sizinti(metin: str, b_izleri: dict) -> list[str]:
    """Yanıt metninde B'ye ait bir kimlik/işaret var mı?

    YANKI SIZINTI DEĞİLDİR: `/arama` isteğin `q`sunu yanıtta geri verir
    (`{"q":"...","items":[]}`). İlk sürümde bu bir sızıntı sanıldı ve test
    yanlış alarm verdi — ölçüm aracının kendisi yanlış pozitif üretirse,
    gerçek bir açığı ararken sahte bir açığı kovalarız. Bu yüzden yankı
    alanları metinden ÇIKARILIR; kimlikler (UUID) zaten yankılanmaz.
    """
    temiz = _YANKI.sub("", metin)
    aranan = list(b_izleri["idler"].values()) + b_izleri["kullanicilar"]
    bulunan = [d for d in aranan if d in temiz]
    if b_izleri["iz"] in temiz:
        bulunan.append(f"iz:{b_izleri['iz']}")
    return bulunan


@pytest.mark.parametrize("yol", TESIS_UCLARI)
def test_TESIS_UCLARI_BASKA_TESISIN_VERISINI_DONDURMEZ(client, world, b_izleri, yol):
    """A'nın yöneticisi B'nin hiçbir kaydını göremez.

    403/404 da GEÇERLİ bir sonuçtur: uç o role kapalıysa sızıntı da yoktur.
    Ölçülen tek şey, 200 dönen bir yanıtın İÇİNDE B'nin verisi olmaması.
    """
    for kim in ("yonetici_a", "admin_a"):
        h = _h(client, world["slug_a"], world[kim])
        params = dict(_PARAMETRELER.get(yol, {"limit": 50}))
        if params.get("q") == "__IZ__":
            params["q"] = b_izleri["iz"]
        r = client.get(yol, headers=h, params=params)
        if r.status_code in (403, 404):
            continue
        assert r.status_code == 200, f"{yol} [{kim}] -> {r.status_code}: {r.text[:200]}"
        sizan = _sizinti(r.text, b_izleri)
        assert not sizan, f"{yol} [{kim}] BASKA TESISIN VERISINI SIZDIRDI: {sizan}"


@pytest.mark.parametrize("yol", PLATFORM_UCLARI)
def test_PLATFORM_UCLARI_TESIS_ROLUNE_KAPALI(client, world, yol):
    """Platform konsolu tesisler arasıdır; tesis rolü oraya GİREMEZ.

    Bu, "platform admini her şeyi görür" kuralının BEDELİDİR: kural
    ancak tesis rollerinin o kapıdan geçemediği kanıtlanırsa güvenlidir.
    """
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    r = client.get(yol, headers=yon)
    assert r.status_code in (403, 404), f"{yol} tesis rolune ACIK: {r.status_code}"


#: (kaynak adı, yol şablonu) — B'nin kimliğiyle DOĞRUDAN çağrılır.
#: Liste sızdırmıyor olabilir ama kimlik tahmin/ele geçirme yoluyla tekil
#: kayda erişim AYRI bir sınıftır (IDOR) ve ayrı ölçülmelidir.
#: NOT: `/cameras/{id}` ve `/notifications/{id}` BURADA YOK cunku GET
#: rotalari YOK (405) — okuma yuzeyi olmayan bir yolda IDOR da yoktur.
IDOR_YOLLARI: tuple[tuple[str, str], ...] = (
    ("unit", "/units/{id}"),
    ("task", "/tasks/{id}"),
    ("complaint", "/complaints/{id}"),

    ("announcement", "/announcements/{id}"),

    ("finansal_hareket", "/finans/hareketler/{id}"),
)


@pytest.mark.parametrize("kaynak,sablon", IDOR_YOLLARI)
def test_IDOR_BASKA_TESISIN_KAYDINA_KIMLIKLE_ERISILEMEZ(
    client, world, b_izleri, kaynak, sablon
):
    """B'nin kaydının KİMLİĞİNİ bilen A yöneticisi onu OKUYAMAZ.

    404 beklenir, 403 değil: kaydın VARLIĞI da sızmamalı — "yetkiniz yok"
    demek, o kimlikte bir kayıt olduğunu doğrulamaktır.
    """
    hedef = b_izleri["idler"][kaynak]
    for kim in ("yonetici_a", "admin_a"):
        h = _h(client, world["slug_a"], world[kim])
        r = client.get(sablon.format(id=hedef), headers=h)
        assert r.status_code in (403, 404), (
            f"{sablon} [{kim}] BASKA TESISIN KAYDINI ACTI: {r.status_code} "
            f"{r.text[:200]}"
        )
        if r.status_code == 200:  # pragma: no cover — yukarıda düşer
            assert not _sizinti(r.text, b_izleri)


def test_IDOR_KULLANICI_KAYDI(client, world, b_izleri):
    """`/users/{id}`: en hassas kayıt — B'nin kullanıcısı okunamaz."""
    for hedef in b_izleri["kullanicilar"]:
        for kim in ("yonetici_a", "admin_a"):
            h = _h(client, world["slug_a"], world[kim])
            r = client.get(f"/users/{hedef}", headers=h)
            assert r.status_code in (403, 404), (
                f"/users/{{id}} [{kim}] BASKA TESISIN KULLANICISINI ACTI: "
                f"{r.status_code} {r.text[:200]}"
            )


def test_KIMLIKSIZ_ISTEK_HICBIR_LISTEYI_ACMAZ(client):
    for yol in TESIS_UCLARI[:12] + PLATFORM_UCLARI:
        r = client.get(yol)
        assert r.status_code == 401, f"{yol} kimliksiz {r.status_code} dondu"


def test_RLS_HER_TENANT_TABLOSUNDA_ACIK_VE_ZORLANMIS(owner_conn):
    """Şema kapısı: `tenant_id` taşıyan her tabloda RLS AÇIK + FORCE.

    Uç bazlı ölçüm bir ucu unutabilir; bu kapı tabloyu unutmayı engeller.
    `FORCE` şart: onsuz tablo SAHİBİ (migration rolü) politikayı atlar ve
    sahiple bağlanan bir yol sızıntıyı geri getirir.
    """
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT c.relname, c.relrowsecurity, c.relforcerowsecurity "
            "FROM pg_class c "
            "JOIN pg_namespace n ON n.oid = c.relnamespace "
            "JOIN information_schema.columns col "
            "  ON col.table_name = c.relname AND col.table_schema = 'public' "
            "WHERE n.nspname = 'public' AND c.relkind = 'r' "
            "  AND col.column_name = 'tenant_id'"
        )
        satirlar = cur.fetchall()
    assert satirlar, "tenant_id tasiyan tablo bulunamadi (sorgu bozuk)"
    korumasiz = [ad for ad, rls, force in satirlar if not (rls and force)]
    assert not korumasiz, f"RLS acik/zorlanmis DEGIL: {sorted(set(korumasiz))}"


def test_UYGULAMA_ROLU_RLS_ATLAYAMAZ(owner_conn):
    """`app_rw` ne superuser ne de BYPASSRLS olmalı.

    Bu iki bayraktan biri açık olsaydı yukarıdaki bütün politikalar
    süs olurdu — ve bunu kimse fark etmezdi.
    """
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT rolsuper, rolbypassrls FROM pg_roles WHERE rolname = 'app_rw'"
        )
        satir = cur.fetchone()
    assert satir, "app_rw rolu yok"
    assert satir == (False, False), f"app_rw RLS'i atlayabiliyor: {satir}"


def test_tarama_kapsami_daralmadi(client, world):
    """Yeni bir liste ucu eklenip taramaya yazılmazsa KAPSAM SESSİZCE
    DARALIR. Bu ölçüm onu görünür kılar.

    Sayı kilidi DEĞİL, ORAN kilidi: parametresiz GET uçlarının en az
    yarısı taranmış olmalı. Kesin sayı, her yeni `/me/*` ucunda testi
    kırıp gerçek bir şey ölçmeden gürültü üretirdi.
    """
    r = client.get("/openapi.json")
    assert r.status_code == 200
    # `/dukkan` HARIC — ve bu bir muafiyet degil, KAVRAM FARKI.
    #
    # Bu tarama "her tesis-kapsamli listeleme ucu RLS baglamini kuruyor mu"
    # diye bakiyor. Dukkan (dukkan.yonetiyor.com) COK-KIRACILI DEGIL: bir
    # isletme Istanbul'daki 40 siteye birden hizmet verir, `tenant_id`
    # tasimaz ve `app.current_tenant_id` ile hicbir isi yoktur
    # (docs/dukkan/00-mimari.md K4). Uclari da kamuya acik (`security: []`)
    # cunku SEO sayfalarini bot ve uye olmayan ziyaretci gormeli.
    #
    # Bunlari paydaya katmak ORANI SULANDIRIRDI: Dukkan buyudukce (F2-F5)
    # her yeni uc, Yonetiyor tarafinin tarama kapsamini OLCMEDEN dusururdu
    # ve kilit sessizce anlamsizlasirdi. Nitekim daralma zaten burada
    # basladi: iki Dukkan ucu paydayi 156'dan 158'e cikarinca esik 78'den
    # 79'a kaydi ve test dustu.
    #
    # Dukkan'in KENDI izolasyon kapisi ayri ve daha dar: sinir
    # `isletme.sahip_kullanici_id` (sahiplik) ve her ozel uc icin ZORUNLU
    # bir IDOR testi var (docs/dukkan/02-kimlik-ve-yetki.md §5). O kapi
    # F2'de, isletme uclariyla birlikte kurulacak.
    # (P234 §1) `/webhooks` DISARIDA — `/auth` ve `/health` ile AYNI SINIF.
    #
    # Bu tarama "oturumun tenant'i disindaki satirlar donuyor mu" diye
    # sorar. Webhook'ta OTURUM YOK: cagiran bir kullanici degil saglayici,
    # kimlik jetonla degil IMZAYLA kuruluyor ve tenant ancak govdedeki
    # referanstan cozuluyor. Boyle bir uce "baska tesisin verisi donuyor
    # mu" diye sormak, sorunun on kosulunu tasimiyor.
    #
    # Odeme webhook'u zaten disaridaydi ama TESADUFEN: yolunda `{provider}`
    # oldugu icin ustteki `"{" not in y` suzgecine takiliyordu. Resend
    # webhook'unda parametre yok ve paydaya girdi — orani esigin altina
    # dusurdu. Yani kural ASLINDA VARDI, yalnizca yanlis sebeple
    # calisiyordu; simdi ADIYLA yaziliyor.
    yollar = [
        y for y in r.json()["paths"]
        if "{" not in y
        and not y.startswith(
            ("/auth", "/me", "/health", "/docs", "/openapi", "/dukkan",
             "/webhooks")
        )
    ]
    taranan = set(TESIS_UCLARI) | set(PLATFORM_UCLARI)
    kapsanan = [y for y in yollar if y in taranan]
    assert len(kapsanan) >= len(yollar) // 2, (
        f"tarama kapsami daraldi: {len(kapsanan)}/{len(yollar)} — "
        f"taranmayanlar: {sorted(set(yollar) - taranan)[:20]}"
    )


# ===================================================================== #
# (P228) "FARKLI KISI, AYNI AD" — KIMLIK TARAFINDAKI IZOLASYON
# ===================================================================== #
# Yukaridaki taramalarin tamami SORGU tarafina bakar: bir uc, oturumun
# tenant'i disindaki satirlari donduruyor mu? P228'de sizinti BASKA BIR
# YERDEN geldi: sorgular dogruydu, KIMIN hangi tesise ait oldugu yanlisti.
# `/me/tesislerim` dogrulanmamis bir e-posta eslesmesini uyelik saydi ve
# kullaniciyi HIC KAYDI OLMAYAN bir tesise gecirebildi. Hicbir RLS testi
# bunu goremezdi cunku gecisten SONRA baglam gercekten o tesisti.
#
# Bu yuzden tarama dosyasina kimlik tarafi da giriyor: yeni bir "tesis
# sec/gec" yolu eklendiginde kanit kurali BURADA hatirlatilir.

def test_P228_ad_benzerligi_hicbir_kod_yolunda_uyelik_kaniti_degil():
    """AD, kimlik kaniti olarak KULLANILAMAZ.

    Bu bir metin taramasi — davranis kilidi `test_p228_tesis_esleme_
    sizintisi.py`de. Buradaki amac, gelecekte "kullanici adiyla da
    eslestirelim, kullanicilar e-postasini yanlis yaziyor" diyen bir
    degisikligin GOZDEN KACMAMASI: uyelik/tesis-secim kodunda ad
    kiyaslamasi gorunurse test duser ve degisikligi yapan kisi P228'i
    okumak zorunda kalir.
    """
    import pathlib
    import re

    kok = pathlib.Path(__file__).resolve().parents[1] / "app"
    # Uyelik/tesis-secimi KARARINI veren yerler. Genis tarama yapmiyoruz:
    # "ad" kelimesi kod tabaninda her yerde gecer, gurultu kilidi
    # anlamsizlastirirdi.
    dosyalar = [kok / "routers" / "me.py", kok / "routers" / "auth.py"]
    supheli = re.compile(
        r"(u\.ad\s*=|\.ad\s*==\s*\w+\.ad|similarity\s*\(|levenshtein\s*\(|ILIKE\s*'%)",
        re.IGNORECASE,
    )
    for d in dosyalar:
        for no, satir in enumerate(d.read_text(encoding="utf-8").splitlines(), 1):
            if satir.lstrip().startswith("#"):
                continue
            assert not supheli.search(satir), (
                f"{d.name}:{no} uyelik kararinda AD/BENZERLIK eslesmesi: "
                f"{satir.strip()!r} — P228: kimlik yalniz dogrulanmis "
                f"e-posta veya (global benzersiz) telefon ile kanitlanir"
            )


# ===================================================================== #
# (P231 §5) ROL ICI GORUNURLUK — "ayni tesis, FARKLI KAPSAM"
# ===================================================================== #
# Bu dosyanin diger taramalari TESISLER ARASI sinira bakiyor: bir uc
# BASKA TESISIN satirini donduruyor mu? P231'de olculen sizinti AYNI
# TESIS ICINDEYDI: `guvenlik_amiri` kendi tesisinin TUM sakin ve
# personel listesini goruyordu (canli suruldu — yedi rolun hepsi geldi).
#
# Hicbir RLS testi bunu goremezdi: satirlar dogru tenant'taydi. Izolasyon
# yalniz tenant siniri degil, ROL KAPSAMI da demek.

def test_P231_amir_TESIS_ICINDE_de_dar_kapsamli(client, world):
    """Amir kendi tesisinde bile YALNIZ guvenlik personelini gorur."""
    r = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"],
        "email": world["amir_a"]["email"],
        "password": world["amir_a"]["password"]})
    assert r.status_code == 200, r.text
    h = {"Authorization": f"Bearer {r.json()['access_token']}"}

    liste = client.get("/users?limit=1000", headers=h)
    assert liste.status_code == 200, liste.text
    roller = {u["role"] for u in liste.json()["items"]}
    assert roller <= {"security", "guvenlik_amiri"}, (
        f"amir tesis icinde fazla rol goruyor: {roller}")


def test_P231_amir_BASKA_TESISIN_guvenligini_de_gormez(client, world):
    """IKI SINIR BIRDEN: rol kapsami daralinca tenant siniri UNUTULMAMALI.

    Amirin gorebildigi rol kumesi (`security`) B tesisinde de var; suzgec
    tenant kosulunun YERINE gecseydi, amir B'nin guvenlik ekibini
    gorurdu.
    """
    r = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"],
        "email": world["amir_a"]["email"],
        "password": world["amir_a"]["password"]})
    h = {"Authorization": f"Bearer {r.json()['access_token']}"}
    liste = client.get("/users?limit=1000", headers=h).json()["items"]
    # B tenant'inin guvenlik kullanicisi listede OLMAMALI.
    b_idler = {u["id"] for u in liste}
    assert b_idler, "liste bos — test anlamsizlasir"
    # Dogrudan kanit: her satir A tenant'inda mi (RLS) — uc tenant_id
    # dondurmuyor, bu yuzden SAYI ile olculur: A'daki guvenlik sayisi.
    yon = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"],
        "email": world["yonetici_a"]["email"],
        "password": world["yonetici_a"]["password"]})
    yh = {"Authorization": f"Bearer {yon.json()['access_token']}"}
    a_guvenlik = {
        u["id"] for u in client.get(
            "/users?limit=1000&role=security", headers=yh).json()["items"]
    }
    amir_guvenlik = {u["id"] for u in liste if u["role"] == "security"}
    assert amir_guvenlik <= a_guvenlik, "amir BASKA TESISIN guvenligini gordu"
