"""(P241 §1) PERIYODIK BAKIM TAKIBI.

===========================================================================
ISTEGIN DOGRULAMA CUMLESI BURADA SURULUYOR
===========================================================================
"Bir asansor bakimi tanimla, periyodunu 6 ay yap, yaklasan bildirimini
gor, bakim kaydi gir, sonraki tarihin ilerledigini gor."

`test_ASANSOR_AKISI_bastan_sona` tam olarak bunu yapar — ve hatirlatma
isini GERCEKTEN kosar (taklit degil): bildirim satiri veritabanindan
okunur.
"""
from __future__ import annotations

import uuid
from datetime import date, timedelta


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _ekipman(client, admin, **over):
    body = {
        "ad": f"Asansör {uuid.uuid4().hex[:5]}",
        "tur": "asansor",
        "periyot": "alti_aylik",
        "yasal": True,
    }
    body.update(over)
    r = client.post("/bakim/ekipmanlar", headers=admin, json=body)
    assert r.status_code == 201, r.text
    return r.json()


# ======================= PERIYOT VE TARIH HESABI ========================== #
def test_SONRAKI_TARIH_HESAPLANIR_verilmezse(client, world):
    admin = _h(client, world["slug_a"], world["admin_a"])
    e = _ekipman(client, admin, son_bakim="2026-03-15")
    # 6 aylik = TAKVIM AYI, 180 gun DEGIL: gun sayisiyla carpmak yilda
    # dort kez yapilan bir bakimi ay ay kaydirirdi.
    assert e["sonraki_bakim"] == "2026-09-15"


def test_AY_SONU_TASMASI_KIRPILIR(client, world):
    # 31 Ocak + 1 ay = 28 Subat. Kirpilmasaydi tarih aritmetigi patlar
    # ve ayin 31'inde yapilan bakim 500 uretirdi.
    admin = _h(client, world["slug_a"], world["admin_a"])
    e = _ekipman(client, admin, periyot="aylik", son_bakim="2026-01-31")
    assert e["sonraki_bakim"] == "2026-02-28"


def test_SERBEST_PERIYOT_gun_ISTER(client, world):
    admin = _h(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/bakim/ekipmanlar", headers=admin,
        json={"ad": "Hidrofor", "tur": "hidrofor", "periyot": "gun"},
    )
    assert r.status_code == 422, r.text


def test_SABIT_PERIYOT_gun_KABUL_ETMEZ(client, world):
    # Celiskili satir: "aylik ama 45 gun". DB CHECK de reddeder; sema
    # kapisi 500 yerine 422 dondurmek icin var.
    admin = _h(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/bakim/ekipmanlar", headers=admin,
        json={"ad": "Kazan", "tur": "kazan", "periyot": "aylik",
              "periyot_gun": 45},
    )
    assert r.status_code == 422


def test_GUNCELLEMEDE_TEK_ALAN_gelse_de_TUTARLILIK_denetlenir(client, world):
    # Yalniz `periyot` gelirse sema `periyot_gun`u GORMEZ; birlesik
    # durum ucta denetlenmeseydi DB CHECK 500 ile patlardi.
    admin = _h(client, world["slug_a"], world["admin_a"])
    e = _ekipman(client, admin, periyot="gun", periyot_gun=90)
    r = client.patch(
        f"/bakim/ekipmanlar/{e['id']}", headers=admin, json={"periyot": "yillik"}
    )
    assert r.status_code == 422
    # Kimlik CUMLEYE cevrilerek doner (hata_metinleri); olculen sey
    # DOGRU kimligin secildigi.
    assert "serbest periyotta" in r.json()["error"]["message"]


# ============================== DURUM ===================================== #
def test_DURUM_ve_KALAN_GUN_turetilir(client, world):
    admin = _h(client, world["slug_a"], world["admin_a"])
    bugun = date.today()
    gecikmis = _ekipman(
        client, admin, ad="Geciken", sonraki_bakim=str(bugun - timedelta(days=5))
    )
    bugunku = _ekipman(client, admin, ad="Bugün", sonraki_bakim=str(bugun))
    yakin = _ekipman(
        client, admin, ad="Yakın", sonraki_bakim=str(bugun + timedelta(days=10))
    )
    uzak = _ekipman(
        client, admin, ad="Uzak", sonraki_bakim=str(bugun + timedelta(days=300))
    )
    assert gecikmis["durum"] == "gecikti" and gecikmis["kalan_gun"] == -5
    assert bugunku["durum"] == "bugun" and bugunku["kalan_gun"] == 0
    assert yakin["durum"] == "yaklasti"
    assert uzak["durum"] == "planli"


def test_EKIPMAN_ESIGI_TESIS_VARSAYILANINI_EZER(client, world):
    # Yangin tupu 30 gun onceden yeter; asansor muayenesi randevu icin
    # 60 gun ister. Tek esik ikisini ayni kefeye koyardi.
    admin = _h(client, world["slug_a"], world["admin_a"])
    bugun = date.today()
    hedef = str(bugun + timedelta(days=45))
    varsayilan = _ekipman(client, admin, ad="Tüp", sonraki_bakim=hedef)
    ozel = _ekipman(client, admin, ad="Asansör", sonraki_bakim=hedef, uyari_gun=60)
    assert varsayilan["durum"] == "planli"
    assert varsayilan["etkin_uyari_gun"] == 30
    assert ozel["durum"] == "yaklasti"
    assert ozel["etkin_uyari_gun"] == 60


def test_DURUM_SUZGECI_TUM_KAYITLARI_TARAR(client, world):
    # Sayfalamadan SONRA suzmek "gecikmis yok" yanilgisi uretirdi.
    admin = _h(client, world["slug_a"], world["admin_a"])
    bugun = date.today()
    for i in range(3):
        _ekipman(client, admin, ad=f"Planlı {i}",
                 sonraki_bakim=str(bugun + timedelta(days=200 + i)))
    gecikmis = _ekipman(client, admin, ad="Geciken",
                        sonraki_bakim=str(bugun - timedelta(days=3)))
    r = client.get(
        "/bakim/ekipmanlar", headers=admin, params={"durum": "gecikti", "limit": 2}
    )
    assert r.status_code == 200
    assert gecikmis["id"] in {x["id"] for x in r.json()["items"]}


def test_LISTE_EN_YAKIN_TARIH_USTTE(client, world):
    admin = _h(client, world["slug_a"], world["admin_a"])
    bugun = date.today()
    _ekipman(client, admin, ad="Uzak", sonraki_bakim=str(bugun + timedelta(days=300)))
    yakin = _ekipman(client, admin, ad="Yakın",
                     sonraki_bakim=str(bugun + timedelta(days=2)))
    items = client.get(
        "/bakim/ekipmanlar", headers=admin, params={"limit": 100}
    ).json()["items"]
    idler = [x["id"] for x in items]
    assert idler.index(yakin["id"]) < idler.index(
        next(x["id"] for x in items if x["ad"] == "Uzak")
    )


# ============================ BAKIM KAYDI ================================= #
def test_KAYIT_TARIHI_ILERLETIR_ve_DAMGALARI_TEMIZLER(client, world):
    admin = _h(client, world["slug_a"], world["admin_a"])
    e = _ekipman(client, admin, son_bakim="2026-01-10")
    assert e["sonraki_bakim"] == "2026-07-10"
    r = client.post(
        f"/bakim/ekipmanlar/{e['id']}/kayitlar", headers=admin,
        json={"tarih": "2026-07-12", "islem": "Yıllık kontrol", "gidere_yaz": False},
    )
    assert r.status_code == 201, r.text
    detay = next(
        x for x in client.get(
            "/bakim/ekipmanlar", headers=admin, params={"limit": 200}
        ).json()["items"] if x["id"] == e["id"]
    )
    assert detay["son_bakim"] == "2026-07-12"
    assert detay["sonraki_bakim"] == "2027-01-12"


def test_TUTAR_DEFTERE_ONAY_BEKLEYEN_GIDER_yazar(client, world):
    """P192 TEK DEFTER: para `finansal_hareket`te yasar, burada degil."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    e = _ekipman(client, admin)
    r = client.post(
        f"/bakim/ekipmanlar/{e['id']}/kayitlar", headers=admin,
        json={"tarih": str(date.today()), "tutar_kurus": 250000},
    )
    assert r.status_code == 201, r.text
    hareket_id = r.json()["hareket_id"]
    assert hareket_id, "defter satiri YAZILMALI"

    hareketler = client.get(
        "/finans/hareketler", headers=admin, params={"limit": 100}
    ).json()["items"]
    h = next(x for x in hareketler if x["id"] == hareket_id)
    # ONAY BEKLIYOR: kaydi giren kisi harcamayi ONAYLAMIS sayilmaz.
    assert h["durum"] == "onay_bekliyor"
    assert h["tip"] == "gider" and h["tutar_kurus"] == 250000


def test_GIDERE_YAZMA_KAPATILABILIR(client, world):
    # Bakim bedeli baska bir faturaya dahilse ikinci kez deftere
    # yazilmamali.
    admin = _h(client, world["slug_a"], world["admin_a"])
    e = _ekipman(client, admin)
    r = client.post(
        f"/bakim/ekipmanlar/{e['id']}/kayitlar", headers=admin,
        json={"tarih": str(date.today()), "tutar_kurus": 90000,
              "gidere_yaz": False},
    )
    assert r.status_code == 201
    assert r.json()["hareket_id"] is None
    assert r.json()["tutar_kurus"] == 90000


def test_GECMIS_KAYITLAR_EKIPMAN_BAZINDA_gorulur(client, world):
    admin = _h(client, world["slug_a"], world["admin_a"])
    a = _ekipman(client, admin, ad="A ekipmanı")
    b = _ekipman(client, admin, ad="B ekipmanı")
    for t in ("2026-01-05", "2026-04-05"):
        client.post(f"/bakim/ekipmanlar/{a['id']}/kayitlar", headers=admin,
                    json={"tarih": t, "gidere_yaz": False})
    client.post(f"/bakim/ekipmanlar/{b['id']}/kayitlar", headers=admin,
                json={"tarih": "2026-02-02", "gidere_yaz": False})
    r = client.get("/bakim/kayitlar", headers=admin,
                   params={"ekipman_id": a["id"], "limit": 50})
    assert r.status_code == 200
    tarihler = [x["tarih"] for x in r.json()["items"]]
    assert tarihler == ["2026-04-05", "2026-01-05"], tarihler


def test_BELGE_EKLENEBILIR_var_olan_EK_mekanizmasiyla(client, world):
    # Ayri bir `bakim_eki` tablosu ACILMADI: calisan mekanizma
    # yeniden kullanildi (rapor/fatura/sertifika).
    admin = _h(client, world["slug_a"], world["admin_a"])
    e = _ekipman(client, admin)
    k = client.post(
        f"/bakim/ekipmanlar/{e['id']}/kayitlar", headers=admin,
        json={"tarih": str(date.today()), "gidere_yaz": False},
    ).json()
    r = client.post(
        "/ekler", headers=admin,
        json={"varlik_tipi": "bakim_kaydi", "varlik_id": k["id"],
              "tur": "not", "metin": "Muayene raporu no 2026/114"},
    )
    assert r.status_code == 201, r.text
    ekler = client.get(
        "/ekler", headers=admin,
        params={"varlik_tipi": "bakim_kaydi", "varlik_id": k["id"]},
    ).json()["items"]
    assert any("2026/114" in (x["metin"] or "") for x in ekler)


# ============================== ROLLER ==================================== #
def test_SAHA_OKUR_YAZAMAZ(client, world):
    admin = _h(client, world["slug_a"], world["admin_a"])
    _ekipman(client, admin)
    for rol in ("guard_a", "gorevli_a"):
        h = _h(client, world["slug_a"], world[rol])
        # Kapida duran kisi "bugun asansor bakimi var" bilgisini KULLANIR.
        assert client.get("/bakim/ekipmanlar", headers=h).status_code == 200, rol
        r = client.post(
            "/bakim/ekipmanlar", headers=h,
            json={"ad": "X", "tur": "y", "periyot": "aylik"},
        )
        assert r.status_code == 403, rol


def test_SAKIN_HIC_GORMEZ(client, world):
    # Bakim bir ISLETME kaydidir; sakine gosterilecek kisisel bir hizmet
    # degil.
    sakin = _h(client, world["slug_a"], world["resident_a"])
    assert client.get("/bakim/ekipmanlar", headers=sakin).status_code == 403


# ============================== RAPOR ===================================== #
def test_YILLIK_OZET_yasal_EKSIKLERI_AYRI_gosterir(client, world):
    """Denetimin ilk sorusu: zorunlu olanlarin kaci yapildi."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    yapilan = _ekipman(client, admin, ad="Asansör 1", yasal=True)
    _ekipman(client, admin, ad="Jeneratör (ihmal)", tur="jenerator", yasal=True)
    _ekipman(client, admin, ad="Klima", tur="klima", yasal=False)
    client.post(
        f"/bakim/ekipmanlar/{yapilan['id']}/kayitlar", headers=admin,
        json={"tarih": "2026-05-05", "tutar_kurus": 120000, "gidere_yaz": False},
    )
    r = client.get("/bakim/ozet", headers=admin, params={"yil": 2026})
    assert r.status_code == 200, r.text
    ozet = r.json()
    satir = next(x for x in ozet["satirlar"] if x["ekipman_id"] == yapilan["id"])
    assert satir["bakim_sayisi"] == 1 and satir["toplam_kurus"] == 120000
    assert "Jeneratör (ihmal)" in ozet["yasal_eksik"]
    # Yasal OLMAYAN bir ekipman "eksik" sayilmaz.
    assert "Klima" not in ozet["yasal_eksik"]
    assert ozet["toplam_kurus"] >= 120000


def test_DENETCI_RAPORU_OKUR_ama_YAZAMAZ(client, world):
    admin = _h(client, world["slug_a"], world["admin_a"])
    _ekipman(client, admin)
    denetci = _h(client, world["slug_a"], world["denetci_a"])
    assert client.get(
        "/bakim/ozet", headers=denetci, params={"yil": 2026}
    ).status_code == 200
    r = client.post(
        "/bakim/ekipmanlar", headers=denetci,
        json={"ad": "X", "tur": "y", "periyot": "aylik"},
    )
    assert r.status_code == 403


# ====================== HATIRLATMA ISI (GERCEK KOSUM) ===================== #
def test_HATIRLATMA_UC_KADEME_ve_TEK_SEFER(client, world, owner_conn):
    from app.bakim_hatirlatma_isi import tum_tenantlar_icin

    admin = _h(client, world["slug_a"], world["admin_a"])
    bugun = date.today()
    yak = _ekipman(client, admin, ad="Yaklaşan", sonraki_bakim=str(bugun + timedelta(days=10)))
    bug = _ekipman(client, admin, ad="Bugünkü", sonraki_bakim=str(bugun))
    gec = _ekipman(client, admin, ad="Geciken", sonraki_bakim=str(bugun - timedelta(days=4)))

    tum_tenantlar_icin(bugun=bugun)
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT tip, mesaj_veri->>'ekipman', user_id FROM notification "
            "WHERE tenant_id = %s AND tip::text LIKE 'bakim_%%'", (world["a"],),
        )
        satirlar = cur.fetchall()
    tipler = {ad: tip for tip, ad, _ in satirlar}
    assert tipler.get("Yaklaşan") == "bakim_yaklasti"
    assert tipler.get("Bugünkü") == "bakim_bugun"
    assert tipler.get("Geciken") == "bakim_gecikti"
    # TESIS ALARMI: `user_id IS NULL` olmazsa yonetim bunu GOREMEZ
    # (`notifications._kapsam`, P240 §4'te olculdu).
    #
    # (E2E 2026-09) ISTISNA: "bugun" kademesi tesis gorevlisine KISI
    # satiriyla da yazilir (o rol NULL satiri goremiyor). Kisi satiri
    # YALNIZ bugun kademesinde olmali.
    for tip, _, uid in satirlar:
        if uid is not None:
            assert tip == "bakim_bugun", tip
    assert any(uid is None for tip, _, uid in satirlar if tip == "bakim_bugun")

    # IKINCI KOSUM SESSIZ: damgalar ayni gun tekrar gondermez.
    ikinci = tum_tenantlar_icin(bugun=bugun)
    assert ikinci["bildirim"] == 0, ikinci
    assert yak and bug and gec


def test_GECIKME_HER_GUN_DEGIL_HAFTADA_BIR(client, world, owner_conn):
    """Bildirim yorgunlugu: gunluk hatirlatma kanalin KAPATILMASINA yol acar."""
    from app.bakim_hatirlatma_isi import GECIKME_TEKRAR_GUN, tum_tenantlar_icin

    admin = _h(client, world["slug_a"], world["admin_a"])
    bugun = date.today()
    e = _ekipman(client, admin, ad="Uzun gecikme",
                 sonraki_bakim=str(bugun - timedelta(days=30)))
    tum_tenantlar_icin(bugun=bugun)

    def _sayi():
        with owner_conn.cursor() as cur:
            cur.execute(
                "SELECT count(*) FROM notification WHERE tenant_id = %s "
                "AND tip = 'bakim_gecikti' AND mesaj_veri->>'ekipman' = %s",
                (world["a"], "Uzun gecikme"),
            )
            return cur.fetchone()[0]

    assert _sayi() == 1
    # ERTESI GUN: tekrar YOK.
    tum_tenantlar_icin(bugun=bugun + timedelta(days=1))
    assert _sayi() == 1
    # DAMGA GERI ALINIR (bir hafta gecmis gibi) -> TEKRAR VAR.
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE bakim_ekipmani SET gecikme_bildirildi_at = "
            "now() - (%s || ' days')::interval WHERE id = %s",
            (GECIKME_TEKRAR_GUN + 1, e["id"]),
        )
    tum_tenantlar_icin(bugun=bugun)
    assert _sayi() == 2


def test_PASIF_EKIPMAN_BILDIRIM_URETMEZ(client, world, owner_conn):
    from app.bakim_hatirlatma_isi import tum_tenantlar_icin

    admin = _h(client, world["slug_a"], world["admin_a"])
    bugun = date.today()
    e = _ekipman(client, admin, ad="Sökülen kazan",
                 sonraki_bakim=str(bugun - timedelta(days=9)))
    client.patch(f"/bakim/ekipmanlar/{e['id']}", headers=admin,
                 json={"aktif": False})
    tum_tenantlar_icin(bugun=bugun)
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM notification WHERE tenant_id = %s "
            "AND mesaj_veri->>'ekipman' = %s", (world["a"], "Sökülen kazan"),
        )
        assert cur.fetchone()[0] == 0


# =================== ISTEGIN DOGRULAMA CUMLESI — TAM AKIS ================== #
def test_ASANSOR_AKISI_bastan_sona(client, world, owner_conn):
    """Tanimla -> yaklasan bildirimi -> bakim kaydi -> tarih ilerledi."""
    from app.bakim_hatirlatma_isi import tum_tenantlar_icin

    admin = _h(client, world["slug_a"], world["admin_a"])
    bugun = date.today()
    # 1) ASANSOR, 6 AYLIK, YASAL — bakim 10 gun sonra.
    e = _ekipman(
        client, admin, ad="A Blok asansörü", tur="asansor",
        periyot="alti_aylik", yasal=True,
        sonraki_bakim=str(bugun + timedelta(days=10)),
        sorumlu_ad="Kone Servis", sorumlu_telefon="+902120000000",
    )
    assert e["durum"] == "yaklasti" and e["kalan_gun"] == 10

    # 2) YAKLASAN BILDIRIMI GERCEKTEN GIDIYOR.
    tum_tenantlar_icin(bugun=bugun)
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT tip FROM notification WHERE tenant_id = %s "
            "AND mesaj_veri->>'ekipman' = %s", (world["a"], "A Blok asansörü"),
        )
        assert [r[0] for r in cur.fetchall()] == ["bakim_yaklasti"]

    # 3) BAKIM YAPILDI — fatura da girildi.
    #
    # (E2E 2026-09) Firma 10 gun ERKEN geldi: kayit BUGUN tarihli.
    # Once burada "bugun + 10" yaziliyordu — gelecek tarihli kayit artik
    # 422 (bkz. test_GELECEK_TARIHLI_KAYIT_REDDEDILIR).
    kayit = client.post(
        f"/bakim/ekipmanlar/{e['id']}/kayitlar", headers=admin,
        json={"tarih": str(bugun),
              "yapan_ad": "Kone Servis", "islem": "Yıllık kontrol + halat",
              "tutar_kurus": 480000},
    )
    assert kayit.status_code == 201, kayit.text

    # 4) SONRAKI TARIH ALTI AY ILERLEDI.
    detay = next(
        x for x in client.get(
            "/bakim/ekipmanlar", headers=admin, params={"limit": 200}
        ).json()["items"] if x["id"] == e["id"]
    )
    yapilan = bugun
    beklenen_ay = (yapilan.month - 1 + 6) % 12 + 1
    beklenen_yil = yapilan.year + (yapilan.month - 1 + 6) // 12
    assert detay["sonraki_bakim"].startswith(f"{beklenen_yil:04d}-{beklenen_ay:02d}")
    assert detay["durum"] == "planli"

    # 5) YILLIK OZETTE GORUNUYOR ve YASAL EKSIK DEGIL.
    ozet = client.get(
        "/bakim/ozet", headers=admin, params={"yil": yapilan.year}
    ).json()
    satir = next(x for x in ozet["satirlar"] if x["ekipman_id"] == e["id"])
    assert satir["bakim_sayisi"] == 1 and satir["toplam_kurus"] == 480000
    assert "A Blok asansörü" not in ozet["yasal_eksik"]


# ================= (E2E 2026-09) TARIH GERI/ILERI ATMAZ =================== #
def test_ESKI_TARIHLI_KAYIT_PLANI_GERI_ALMAZ(client, world):
    """TESIS-06: 20.09 bakimindan sonra unutulmus 15.08 kaydi girilince
    asansor "gecikti" oluyordu."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    e = _ekipman(client, admin, periyot="aylik")
    bugun = date.today()
    yeni = bugun - timedelta(days=3)
    eski = bugun - timedelta(days=40)
    r1 = client.post(f"/bakim/ekipmanlar/{e['id']}/kayitlar", headers=admin,
                     json={"tarih": str(yeni), "gidere_yaz": False})
    assert r1.status_code == 201, r1.text
    once = next(x for x in client.get("/bakim/ekipmanlar", headers=admin,
                                      params={"limit": 200}).json()["items"]
                if x["id"] == e["id"])
    r2 = client.post(f"/bakim/ekipmanlar/{e['id']}/kayitlar", headers=admin,
                     json={"tarih": str(eski), "gidere_yaz": False})
    assert r2.status_code == 201, r2.text
    sonra = next(x for x in client.get("/bakim/ekipmanlar", headers=admin,
                                       params={"limit": 200}).json()["items"]
                 if x["id"] == e["id"])
    assert sonra["son_bakim"] == str(yeni)
    assert sonra["sonraki_bakim"] == once["sonraki_bakim"]
    assert sonra["durum"] != "gecikti"
    # Eski kayit GECMISTE yine de gorunur.
    tarihler = [x["tarih"] for x in client.get(
        "/bakim/kayitlar", headers=admin, params={"ekipman_id": e["id"]}
    ).json()["items"]]
    assert str(eski) in tarihler


def test_GELECEK_TARIHLI_KAYIT_REDDEDILIR(client, world):
    """TESIS-06: 2030 tarihli kayit yasal muayeneyi yillarca gizliyordu."""
    from app.hata_metinleri import METINLER

    admin = _h(client, world["slug_a"], world["admin_a"])
    e = _ekipman(client, admin)
    r = client.post(f"/bakim/ekipmanlar/{e['id']}/kayitlar", headers=admin,
                    json={"tarih": "2030-01-01", "gidere_yaz": False})
    assert r.status_code == 422, r.text
    assert r.json()["error"]["message"] == METINLER["bakim_tarihi_gelecekte"]["tr"]
    # Plan degismedi.
    detay = next(x for x in client.get("/bakim/ekipmanlar", headers=admin,
                                       params={"limit": 200}).json()["items"]
                 if x["id"] == e["id"])
    assert detay["sonraki_bakim"] == e["sonraki_bakim"]
    # Bir gun tolerans: UTC ile yerel gun farki "bugun"u reddetmemeli.
    ok = client.post(f"/bakim/ekipmanlar/{e['id']}/kayitlar", headers=admin,
                     json={"tarih": str(date.today() + timedelta(days=1)),
                           "gidere_yaz": False})
    assert ok.status_code == 201, ok.text


def test_PERIYOT_DEGISINCE_SONRAKI_TARIH_YENIDEN_HESAPLANIR(client, world):
    """Diger gozlem: yillik -> aylik sonrasi tarih aynı kaliyordu."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    e = _ekipman(client, admin, periyot="yillik", son_bakim="2026-03-15")
    assert e["sonraki_bakim"] == "2027-03-15"
    r = client.patch(f"/bakim/ekipmanlar/{e['id']}", headers=admin,
                     json={"periyot": "aylik"})
    assert r.status_code == 200, r.text
    assert r.json()["sonraki_bakim"] == "2026-04-15"
    # Tarih ACIKCA verilirse ona dokunulmaz.
    r2 = client.patch(f"/bakim/ekipmanlar/{e['id']}", headers=admin,
                      json={"periyot": "uc_aylik", "sonraki_bakim": "2026-12-01"})
    assert r2.status_code == 200, r2.text
    assert r2.json()["sonraki_bakim"] == "2026-12-01"


def test_BUGUN_BILDIRIMI_TESIS_GOREVLISINE_GORUNUR(client, world):
    """TESIS-15 (bakim): gorevli NULL satiri goremedigi icin "bugun"
    bildirimini listede hic bulamiyordu."""
    from app.bakim_hatirlatma_isi import tum_tenantlar_icin

    admin = _h(client, world["slug_a"], world["admin_a"])
    ad = f"Bugün {uuid.uuid4().hex[:5]}"
    _ekipman(client, admin, ad=ad, sonraki_bakim=str(date.today()))
    tum_tenantlar_icin(bugun=date.today())
    gorevli = _h(client, world["slug_a"], world["gorevli_a"])
    items = client.get("/notifications", headers=gorevli,
                       params={"limit": 200}).json()["items"]
    assert any(x.get("tip") == "bakim_bugun" for x in items), items


def test_BAKIM_KAYDINA_PDF_BELGE_EKLENIR_ve_ACILABILIR(client, world):
    """TESIS-05: PDF presign 422 aliyordu; ek listesi yalniz ad gosteriyordu."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    e = _ekipman(client, admin)
    k = client.post(
        f"/bakim/ekipmanlar/{e['id']}/kayitlar", headers=admin,
        json={"tarih": str(date.today()), "gidere_yaz": False},
    ).json()
    bilet = client.post(
        "/uploads/presign", headers=admin,
        json={"content_type": "application/pdf", "amac": "belge",
              "dosya_adi": "muayene.pdf"},
    )
    assert bilet.status_code == 200, bilet.text
    key = bilet.json()["foto_key"]
    r = client.post(
        "/ekler", headers=admin,
        json={"varlik_tipi": "bakim_kaydi", "varlik_id": k["id"],
              "tur": "dosya", "dosya_key": key, "dosya_adi": "muayene.pdf"},
    )
    assert r.status_code == 201, r.text
    ekler = client.get(
        "/ekler", headers=admin,
        params={"varlik_tipi": "bakim_kaydi", "varlik_id": k["id"]},
    ).json()["items"]
    ek = next(x for x in ekler if x["dosya_key"] == key)
    assert ek["dosya_url"] and key in ek["dosya_url"]
    # Saha (okur) da raporu acabilir.
    gorevli = _h(client, world["slug_a"], world["gorevli_a"])
    g = client.get(
        "/ekler", headers=gorevli,
        params={"varlik_tipi": "bakim_kaydi", "varlik_id": k["id"]},
    )
    assert g.status_code == 200
    assert any(x["dosya_url"] for x in g.json()["items"])


def test_EK_URL_BASKA_TENANT_ANAHTARINI_IMZALAMAZ(client, world):
    """dosya_key istemciden gelir; yabanci onekli anahtar imzalanmamali."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    e = _ekipman(client, admin)
    k = client.post(
        f"/bakim/ekipmanlar/{e['id']}/kayitlar", headers=admin,
        json={"tarih": str(date.today()), "gidere_yaz": False},
    ).json()
    yabanci = f"{world['b']}/belge/{uuid.uuid4().hex}.pdf"
    r = client.post(
        "/ekler", headers=admin,
        json={"varlik_tipi": "bakim_kaydi", "varlik_id": k["id"],
              "tur": "dosya", "dosya_key": yabanci},
    )
    assert r.status_code == 201
    assert r.json()["dosya_url"] is None
