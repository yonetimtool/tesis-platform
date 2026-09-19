"""(P243 §1/§2) VARDIYA MODALI SADELESTIRME + "ATANMAMIS" TANIMI.

===========================================================================
BU DOSYA BIR KUSURU OLCEREK DOGDU
===========================================================================
Web modali "serbest saat + tek kisi" durumunda `/vardiya-plani/toplu`
ucuna `baslangic`/`bitis` gonderiyordu; sema `baslangic_tarih` /
`bitis_tarih` istiyor. Yani web'in EN SIK yapilan islemi P235'ten beri
422 aliyordu ve DOM testi bunu goremiyordu (taklit `fetch` her govdeye
200 donuyordu).

Ders: SOZLESME UYUMU sunucuya karsi olculur. Asagidaki ilk test tam
olarak bunu yapiyor.
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


def _gun(n: int) -> date:
    return date.today() + timedelta(days=300 + n)


def _kisi(client, admin, world, anahtar="guard_a"):
    u = client.get("/users", headers=admin, params={"limit": 200}).json()["items"]
    return next(x for x in u if x["email"] == world[anahtar]["email"])


# ===================== §1 TEK UC: SERBEST SAAT DE BURADAN ================== #
def test_SERBEST_SAAT_KALIP_UCUNDAN_YAZILIR(client, world):
    """Modalin artik kullandigi TEK yol — sunucu bunu KABUL ETMELI."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    kisi = _kisi(client, admin, world)
    g = _gun(0)
    r = client.post(
        "/vardiya-plani/kalip-uygula", headers=admin,
        json={
            "gruplar": [{
                "gunler": [str(g)],
                "dilimler": [
                    {"ad": "08:00-16:00", "baslangic": "08:00", "bitis": "16:00"}
                ],
                "atamalar": {"0": [kisi["id"]]},
                "kalip_id": None,
            }],
            "rotasyon": "yok",
            "kuru": False,
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["uygulandi"] is True and r.json()["eklenen"] == 1


def test_ONIZLEME_KAC_VARDIYA_OLUSACAGINI_SOYLER(client, world):
    """(§1g) `kuru=true` HICBIR SEY yazmaz ama SAYIYI verir."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    kisi = _kisi(client, admin, world)
    gunler = [str(_gun(i)) for i in (1, 2, 3)]
    r = client.post(
        "/vardiya-plani/kalip-uygula", headers=admin,
        json={
            "gruplar": [{
                "gunler": gunler,
                "dilimler": [
                    {"ad": "08:00-16:00", "baslangic": "08:00", "bitis": "16:00"}
                ],
                "atamalar": {"0": [kisi["id"]]},
                "kalip_id": None,
            }],
            "kuru": True,
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["uygulandi"] is False
    assert r.json()["eklenecek"] == 3, r.json()
    # HICBIR SEY YAZILMADI.
    c = client.get(
        "/vardiya-plani/cizelge", headers=admin,
        params={"baslangic": gunler[0], "gun": 7},
    ).json()
    k = next(x for x in c["personel"] if x["user_id"] == kisi["id"])
    assert k["bloklar"] == []


def test_MOLA_KALIP_YOLUNDAN_DA_YAZILIR(client, world):
    """(§1) Tek yola gecince mola kaybolmamali."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    kisi = _kisi(client, admin, world)
    g = _gun(4)
    r = client.post(
        "/vardiya-plani/kalip-uygula", headers=admin,
        json={
            "gruplar": [{
                "gunler": [str(g)],
                "dilimler": [
                    {"ad": "08:00-20:00", "baslangic": "08:00", "bitis": "20:00"}
                ],
                "atamalar": {"0": [kisi["id"]]},
                "kalip_id": None,
            }],
            "molalar": [{"tur": "yasal", "dakika": 60}],
            "kuru": False,
        },
    )
    assert r.status_code == 200, r.text
    c = client.get(
        "/vardiya-plani/cizelge", headers=admin,
        params={"baslangic": str(g), "gun": 1},
    ).json()
    blok = next(
        x for x in c["personel"] if x["user_id"] == kisi["id"]
    )["bloklar"][0]
    assert blok["mola_dakika"] == 60
    assert blok["calisma_saat"] == 11.0


# ========================= §1e AYLIK ROTASYON ============================= #
def test_AYLIK_ROTASYON_TAKVIM_AYINDA_KAYAR(client, world):
    """(§1e) Dort haftalik dongu DEGIL: ayin ortasinda kaymaz."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    a = _kisi(client, admin, world, "guard_a")
    b = _kisi(client, admin, world, "amir_a")
    # Ayni ayin iki gunu + ERTESI AYIN bir gunu.
    # TARIHLER AYIRT EDICI SECILDI: 9 Mart, baslangictan TAM BIR HAFTA
    # sonra. HAFTALIK rotasyon olsaydi orada dilim DEGISIRDI; aylikta
    # degismemeli. Ilk yazimda 30 Mart secmistim (dort hafta = cift
    # kaydirma) ve test iki kurali AYIRT EDEMIYORDU — kilidi kirarak
    # olctum, gecti.
    bu_ay = date(2027, 3, 2)
    bu_ay_son = date(2027, 3, 9)
    gelecek_ay = date(2027, 4, 6)
    r = client.post(
        "/vardiya-plani/kalip-uygula", headers=admin,
        json={
            "gruplar": [{
                "gunler": [str(bu_ay), str(bu_ay_son), str(gelecek_ay)],
                "dilimler": [
                    {"ad": "Gunduz", "baslangic": "08:00", "bitis": "16:00"},
                    {"ad": "Gece", "baslangic": "20:00", "bitis": "04:00"},
                ],
                "atamalar": {"0": [a["id"]], "1": [b["id"]]},
                "kalip_id": None,
            }],
            "rotasyon": "aylik",
            "kuru": True,
        },
    )
    assert r.status_code == 200, r.text
    satirlar = r.json()["satirlar"]

    def _dilim(tarih: str, user_ad: str) -> str:
        return next(
            s["dilim"] for s in satirlar
            if s["tarih"] == tarih and s["ad"] == user_ad
        )

    # MART: A gunduz. AYIN SONUNDA DA A GUNDUZ — dongu ay icinde kaymaz.
    assert _dilim(str(bu_ay), a["ad"]) == "Gunduz"
    assert _dilim(str(bu_ay_son), a["ad"]) == "Gunduz"
    # NISAN: A GECEYE kaydi.
    assert _dilim(str(gelecek_ay), a["ad"]) == "Gece"


def test_HAFTALIK_ROTASYON_KORUNDU(client, world):
    admin = _h(client, world["slug_a"], world["admin_a"])
    a = _kisi(client, admin, world, "guard_a")
    b = _kisi(client, admin, world, "amir_a")
    ilk = date(2027, 6, 7)          # pazartesi
    sonraki_hafta = date(2027, 6, 14)
    r = client.post(
        "/vardiya-plani/kalip-uygula", headers=admin,
        json={
            "gruplar": [{
                "gunler": [str(ilk), str(sonraki_hafta)],
                "dilimler": [
                    {"ad": "Gunduz", "baslangic": "08:00", "bitis": "16:00"},
                    {"ad": "Gece", "baslangic": "20:00", "bitis": "04:00"},
                ],
                "atamalar": {"0": [a["id"]], "1": [b["id"]]},
                "kalip_id": None,
            }],
            "rotasyon": "haftalik",
            "kuru": True,
        },
    )
    satirlar = r.json()["satirlar"]
    ilk_dilim = next(
        s["dilim"] for s in satirlar if s["tarih"] == str(ilk) and s["ad"] == a["ad"]
    )
    sonraki = next(
        s["dilim"] for s in satirlar
        if s["tarih"] == str(sonraki_hafta) and s["ad"] == a["ad"]
    )
    assert ilk_dilim == "Gunduz" and sonraki == "Gece"


# ==================== §1f COKLU KALIP = GRUP YAPISI ======================= #
def test_IKI_GRUP_IKI_FARKLI_KALIP(client, world):
    """(§1f) Yeni kavram YOK: `VardiyaGunGrubu` zaten `kalip_id` tasiyor."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    kisi = _kisi(client, admin, world)
    k1 = client.post(
        "/vardiya-plani/kaliplar", headers=admin,
        json={"ad": f"Iki vardiya {uuid.uuid4().hex[:4]}", "dilimler": [
            {"ad": "Gunduz", "baslangic": "08:00", "bitis": "20:00"},
        ]},
    ).json()
    k2 = client.post(
        "/vardiya-plani/kaliplar", headers=admin,
        json={"ad": f"Hafta sonu {uuid.uuid4().hex[:4]}", "dilimler": [
            {"ad": "Tam gun", "baslangic": "09:00", "bitis": "21:00"},
        ]},
    ).json()
    r = client.post(
        "/vardiya-plani/kalip-uygula", headers=admin,
        json={
            "gruplar": [
                {"gunler": [str(_gun(10))], "kalip_id": k1["id"],
                 "atamalar": {"0": [kisi["id"]]}},
                {"gunler": [str(_gun(11))], "kalip_id": k2["id"],
                 "atamalar": {"0": [kisi["id"]]}},
            ],
            "kuru": True,
        },
    )
    assert r.status_code == 200, r.text
    dilimler = {s["tarih"]: s["dilim"] for s in r.json()["satirlar"]}
    assert dilimler[str(_gun(10))] == "Gunduz"
    assert dilimler[str(_gun(11))] == "Tam gun"


# ======================= §2 "ATANMAMIS" TANIMI ============================ #
def test_VARDIYA_DUZENINDE_OLMAYAN_KISI_ISARETLENMEZ(client, world):
    """Hic vardiyasi olmayan ve kadroda olmayan kisi 'atanmamis' DEGILDIR."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    g = _gun(20)
    c = client.get(
        "/vardiya-plani/cizelge", headers=admin,
        params={"baslangic": str(g), "gun": 7},
    ).json()
    assert c["personel"], "personel listesi bos gelmemeli"
    # Bu tesiste (yeni `world`) henuz hicbir vardiya yok -> hicbiri
    # duzende degil, yani "Atanmamis" bolumu BOS olur.
    assert all(k["vardiya_duzeninde"] is False for k in c["personel"]), [
        k["ad"] for k in c["personel"] if k["vardiya_duzeninde"]
    ]


def test_BIR_KEZ_VARDIYA_YAZILINCA_DUZENE_GIRER(client, world):
    admin = _h(client, world["slug_a"], world["admin_a"])
    kisi = _kisi(client, admin, world)
    yazilan = _gun(30)
    client.post(
        "/vardiya-plani/kalip-uygula", headers=admin,
        json={
            "gruplar": [{
                "gunler": [str(yazilan)],
                "dilimler": [
                    {"ad": "08:00-16:00", "baslangic": "08:00", "bitis": "16:00"}
                ],
                "atamalar": {"0": [kisi["id"]]},
                "kalip_id": None,
            }],
            "kuru": False,
        },
    )
    # BASKA BIR HAFTAYA bakiyoruz: o hafta blogu YOK ama duzende VAR.
    baska = _gun(60)
    c = client.get(
        "/vardiya-plani/cizelge", headers=admin,
        params={"baslangic": str(baska), "gun": 7},
    ).json()
    k = next(x for x in c["personel"] if x["user_id"] == kisi["id"])
    assert k["bloklar"] == []
    assert k["vardiya_duzeninde"] is True, "gecmis vardiya DUZENE sokar"
    # Vardiyasi HIC olmayan biri hâlâ disarida.
    digerleri = [
        x for x in c["personel"]
        if x["user_id"] != kisi["id"] and x["vardiya_duzeninde"]
    ]
    assert not digerleri, digerleri
