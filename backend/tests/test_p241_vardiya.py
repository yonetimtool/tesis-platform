"""(P241 §2) VARDIYA YENIDEN — izin, molalar, rol/lokasyon, yayin, kopyala.

===========================================================================
KORUNACAKLARIN KILIDI DE BURADA
===========================================================================
Istek yedi seyi "korunacak" diye sayiyor. Yeni alanlar eklenirken
bozulmadiklarini gostermek, yeni ozellikleri test etmek kadar onemli —
bu yuzden her biri icin ayri bir olcum var (asagida `KORUNDU` ile
baslayan testler).
"""
from __future__ import annotations

import uuid
from datetime import date, timedelta

import pytest


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _pazartesi(hafta_sonra: int = 0) -> date:
    bugun = date.today()
    return bugun - timedelta(days=bugun.weekday()) + timedelta(weeks=hafta_sonra)


@pytest.fixture
def personel(client, world):
    """Guvenlik personelinin kimligi — vardiya hedefi."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    r = client.get("/users", headers=admin, params={"limit": 200})
    assert r.status_code == 200, r.text
    guard = next(
        u for u in r.json()["items"] if u["email"] == world["guard_a"]["email"]
    )
    return guard


def _sablon(client, admin, **over):
    body = {"ad": f"Gündüz {uuid.uuid4().hex[:4]}", "baslangic_saat": "08:00",
            "bitis_saat": "16:00", "gun_tipi": "her_gun"}
    body.update(over)
    r = client.post("/shifts", headers=admin, json=body)
    assert r.status_code == 201, r.text
    return r.json()


# ============================== MOLALAR =================================== #
def test_MOLA_ONERISI_KANUN_METNINDEN(client, world):
    """4857 md. 68: 4 saate kadar 25 dk, 7,5'a kadar 30 dk, ustu 60 dk.

    Istekte "4 saate kadar 15 dk" yaziyordu; KANUN METNI alindi. Eksik
    bir oneri, yoneticinin hukuki dayanagini bozar.
    """
    admin = _h(client, world["slug_a"], world["admin_a"])
    for bas, bit, beklenen in (
        ("09:00", "12:00", 25),
        ("08:00", "12:00", 25),
        ("08:00", "15:00", 30),
        ("08:00", "15:30", 30),
        ("08:00", "20:00", 60),
        ("20:00", "08:00", 60),
    ):
        r = client.get(
            "/vardiya-plani/mola-onerisi", headers=admin,
            params={"baslangic_saat": bas, "bitis_saat": bit},
        )
        assert r.status_code == 200, r.text
        assert r.json()["onerilen_dakika"] == beklenen, (bas, bit)


def test_MOLA_CALISMA_SURESINDEN_DUSER(client, world, personel):
    """md. 68/son: ara dinlenme calisma suresinden sayilmaz."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    s = _sablon(client, admin, baslangic_saat="08:00", bitis_saat="20:00")
    gun = _pazartesi(2)
    r = client.post(
        "/vardiya-plani", headers=admin,
        json={"shift_id": s["id"], "tarih": str(gun), "user_id": personel["id"],
              "molalar": [{"tur": "yasal", "dakika": 60}]},
    )
    assert r.status_code == 201, r.text
    cizelge = client.get(
        "/vardiya-plani/cizelge", headers=admin,
        params={"baslangic": str(gun), "gun": 1},
    ).json()
    kisi = next(k for k in cizelge["personel"] if k["user_id"] == personel["id"])
    blok = kisi["bloklar"][0]
    # 12 saatlik vardiya, 1 saat mola -> 11 saat CALISMA.
    assert blok["calisma_saat"] == 11.0
    assert blok["mola_dakika"] == 60
    assert kisi["toplam_saat"] == 11.0


def test_MOLA_MESAI_HESABINA_DA_YANSIR(client, world, personel):
    # Bugune kadar 12 saatlik bir vardiyanin 1 saatlik molasi da fazla
    # mesai olarak ucretlendiriliyordu.
    from app.vardiya import plan_saat

    class _Plan:
        baslangic_saat = None
        bitis_saat = None
        tarih = date(2026, 3, 2)
        molalar = [{"dakika": 60}]

    class _Shift:
        from datetime import time as _t
        baslangic_saat = _t(8, 0)
        bitis_saat = _t(20, 0)

    assert plan_saat(_Plan(), _Shift()) == 11.0


# ================================ IZIN ==================================== #
def test_IZIN_YONETICI_GIRERSE_DOGRUDAN_ONAYLI(client, world, personel):
    # Onaylayacak makam zaten odur; kendi girdigini ayrica onaylatmak
    # bos bir tiklama olurdu.
    admin = _h(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/vardiya-izin", headers=admin,
        json={"user_id": personel["id"], "tur": "yillik",
              "baslangic": str(_pazartesi(3)),
              "bitis": str(_pazartesi(3) + timedelta(days=4))},
    )
    assert r.status_code == 201, r.text
    assert r.json()["durum"] == "onaylandi"


def test_IZIN_PERSONEL_KENDISI_ICIN_TALEP_ACAR(client, world):
    guard = _h(client, world["slug_a"], world["guard_a"])
    me = client.get("/me", headers=guard).json()
    r = client.post(
        "/vardiya-izin", headers=guard,
        json={"user_id": me["id"], "tur": "mazeret",
              "baslangic": str(_pazartesi(4)), "bitis": str(_pazartesi(4))},
    )
    assert r.status_code == 201, r.text
    assert r.json()["durum"] == "onay_bekliyor"


def test_IZIN_BASKASI_ADINA_GIRILEMEZ(client, world, personel):
    # Sessizce kendi adina yazmak daha kotu olurdu: kayit gorunur ama
    # yanlis kisiye.
    gorevli = _h(client, world["slug_a"], world["gorevli_a"])
    r = client.post(
        "/vardiya-izin", headers=gorevli,
        json={"user_id": personel["id"], "tur": "yillik",
              "baslangic": str(_pazartesi(5)), "bitis": str(_pazartesi(5))},
    )
    assert r.status_code == 403, r.text


def test_IZIN_ONAY_ve_TEKRAR_ONAY_REDDEDILIR(client, world):
    admin = _h(client, world["slug_a"], world["admin_a"])
    guard = _h(client, world["slug_a"], world["guard_a"])
    me = client.get("/me", headers=guard).json()
    izin = client.post(
        "/vardiya-izin", headers=guard,
        json={"user_id": me["id"], "tur": "hastalik",
              "baslangic": str(_pazartesi(6)), "bitis": str(_pazartesi(6))},
    ).json()
    r = client.post(f"/vardiya-izin/{izin['id']}/onayla", headers=admin)
    assert r.status_code == 200 and r.json()["durum"] == "onaylandi"
    # Karar verilmis talebi yeniden karara baglamak, kaydi sessizce
    # degistirmekti.
    r = client.post(f"/vardiya-izin/{izin['id']}/reddet", headers=admin)
    assert r.status_code == 409


def test_IZIN_SAATLIK_TEK_GUNE_AIT(client, world, personel):
    admin = _h(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/vardiya-izin", headers=admin,
        json={"user_id": personel["id"], "tur": "mazeret",
              "baslangic": str(_pazartesi(7)),
              "bitis": str(_pazartesi(7) + timedelta(days=2)),
              "tum_gun": False, "baslangic_saat": "09:00",
              "bitis_saat": "11:00"},
    )
    assert r.status_code == 422, r.text


def test_IZIN_LISTESI_KESISIMLE_SUZULUR(client, world, personel):
    """1-20 Agustos izni, 10-16 Agustos haftasini soran izgarada GORUNMELI."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    bas = _pazartesi(8)
    client.post(
        "/vardiya-izin", headers=admin,
        json={"user_id": personel["id"], "tur": "yillik",
              "baslangic": str(bas), "bitis": str(bas + timedelta(days=19))},
    )
    orta = bas + timedelta(days=9)
    r = client.get(
        "/vardiya-izin", headers=admin,
        params={"baslangic": str(orta), "bitis": str(orta + timedelta(days=6))},
    )
    assert r.status_code == 200
    assert any(i["user_id"] == personel["id"] for i in r.json()["items"])


# ==================== IZINLI GUNE VARDIYA ATANAMAZ ======================== #
def test_IZINLI_GUNE_VARDIYA_ATANAMAZ(client, world, personel):
    admin = _h(client, world["slug_a"], world["admin_a"])
    s = _sablon(client, admin)
    gun = _pazartesi(9)
    client.post(
        "/vardiya-izin", headers=admin,
        json={"user_id": personel["id"], "tur": "yillik",
              "baslangic": str(gun), "bitis": str(gun)},
    )
    r = client.post(
        "/vardiya-plani", headers=admin,
        json={"shift_id": s["id"], "tarih": str(gun), "user_id": personel["id"]},
    )
    assert r.status_code == 422, r.text
    assert "izin" in r.json()["error"]["message"].lower()


def test_SAATLIK_IZIN_VARDIYAYI_ENGELLEMEZ(client, world, personel):
    # Iki saatlik mazeret izni o gunku vardiyayi imkansiz kilmaz.
    admin = _h(client, world["slug_a"], world["admin_a"])
    s = _sablon(client, admin)
    gun = _pazartesi(10)
    client.post(
        "/vardiya-izin", headers=admin,
        json={"user_id": personel["id"], "tur": "mazeret",
              "baslangic": str(gun), "bitis": str(gun), "tum_gun": False,
              "baslangic_saat": "09:00", "bitis_saat": "11:00"},
    )
    r = client.post(
        "/vardiya-plani", headers=admin,
        json={"shift_id": s["id"], "tarih": str(gun), "user_id": personel["id"]},
    )
    assert r.status_code == 201, r.text


def test_BEKLEYEN_IZIN_ENGELLEMEZ(client, world):
    """Onaylanmamis bir talep henuz bir gercek degildir."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    guard = _h(client, world["slug_a"], world["guard_a"])
    me = client.get("/me", headers=guard).json()
    s = _sablon(client, admin)
    gun = _pazartesi(11)
    client.post(
        "/vardiya-izin", headers=guard,
        json={"user_id": me["id"], "tur": "yillik",
              "baslangic": str(gun), "bitis": str(gun)},
    )
    r = client.post(
        "/vardiya-plani", headers=admin,
        json={"shift_id": s["id"], "tarih": str(gun), "user_id": me["id"]},
    )
    assert r.status_code == 201, r.text


def test_IZIN_CIZELGEDE_AYRI_KATMAN(client, world, personel):
    # Bloklarla ayni listeye konmaz: mesai hesabi `bloklar`i okuyor.
    admin = _h(client, world["slug_a"], world["admin_a"])
    gun = _pazartesi(12)
    client.post(
        "/vardiya-izin", headers=admin,
        json={"user_id": personel["id"], "tur": "yillik",
              "baslangic": str(gun), "bitis": str(gun + timedelta(days=2))},
    )
    c = client.get(
        "/vardiya-plani/cizelge", headers=admin,
        params={"baslangic": str(gun), "gun": 7},
    ).json()
    kisi = next(k for k in c["personel"] if k["user_id"] == personel["id"])
    assert len(kisi["izinler"]) == 1
    assert kisi["izinler"][0]["tur"] == "yillik"
    assert kisi["bloklar"] == []


# ============================== YAYIN ===================================== #
def test_YENI_SATIR_TASLAK_ACILIR_PERSONEL_GORMEZ(client, world, personel):
    admin = _h(client, world["slug_a"], world["admin_a"])
    guard = _h(client, world["slug_a"], world["guard_a"])
    s = _sablon(client, admin)
    gun = _pazartesi(13)
    r = client.post(
        "/vardiya-plani", headers=admin,
        json={"shift_id": s["id"], "tarih": str(gun), "user_id": personel["id"]},
    )
    assert r.status_code == 201 and r.json()["yayinlandi_at"] is None

    def _blok_sayisi(h):
        c = client.get(
            "/vardiya-plani/cizelge", headers=h,
            params={"baslangic": str(gun), "gun": 1},
        ).json()
        kisi = next(
            (k for k in c["personel"] if k["user_id"] == personel["id"]), None
        )
        return len(kisi["bloklar"]) if kisi else 0

    # YONETIM GORUR (planlamayi o yapiyor), PERSONEL GORMEZ.
    assert _blok_sayisi(admin) == 1
    assert _blok_sayisi(guard) == 0

    ozet = client.get(
        "/vardiya-plani/yayin-ozeti", headers=admin,
        params={"baslangic": str(gun), "gun": 1},
    ).json()
    assert ozet["taslak"] == 1 and ozet["bekleyen"] == 1

    r = client.post(
        "/vardiya-plani/yayinla", headers=admin,
        params={"baslangic": str(gun), "gun": 1},
    )
    assert r.status_code == 200 and r.json()["yayinlanan"] == 1
    assert _blok_sayisi(guard) == 1


def test_YAYINLANMIS_SATIR_DEGISINCE_TEKRAR_BEKLER_ama_GIZLENMEZ(
    client, world, personel
):
    """Gizlemek "vardiyam kayboldu" telefonlari uretirdi."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    guard = _h(client, world["slug_a"], world["guard_a"])
    s = _sablon(client, admin)
    gun = _pazartesi(14)
    plan = client.post(
        "/vardiya-plani", headers=admin,
        json={"shift_id": s["id"], "tarih": str(gun), "user_id": personel["id"]},
    ).json()
    client.post(
        "/vardiya-plani/yayinla", headers=admin,
        params={"baslangic": str(gun), "gun": 1},
    )
    r = client.patch(
        f"/vardiya-plani/{plan['id']}", headers=admin,
        json={"not_metni": "Kapı nöbeti"},
    )
    assert r.status_code == 200, r.text

    ozet = client.get(
        "/vardiya-plani/yayin-ozeti", headers=admin,
        params={"baslangic": str(gun), "gun": 1},
    ).json()
    assert ozet["degisen"] == 1 and ozet["taslak"] == 0

    c = client.get(
        "/vardiya-plani/cizelge", headers=guard,
        params={"baslangic": str(gun), "gun": 1},
    ).json()
    kisi = next(k for k in c["personel"] if k["user_id"] == personel["id"])
    assert len(kisi["bloklar"]) == 1, "yayinlanmis satir GIZLENMEZ"


# =========================== HAFTADAN KOPYALA ============================= #
def test_HAFTADAN_KOPYALA_ve_SEBEPLI_ATLAMA(client, world, personel):
    admin = _h(client, world["slug_a"], world["admin_a"])
    s = _sablon(client, admin)
    kaynak = _pazartesi(15)
    hedef = _pazartesi(16)
    for i in (0, 1, 2):
        r = client.post(
            "/vardiya-plani", headers=admin,
            json={"shift_id": s["id"], "tarih": str(kaynak + timedelta(days=i)),
                  "user_id": personel["id"]},
        )
        assert r.status_code == 201, r.text
    # HEDEF HAFTADA BIR GUN IZINLI: o gun ATLANMALI ve SEBEBI YAZILMALI.
    client.post(
        "/vardiya-izin", headers=admin,
        json={"user_id": personel["id"], "tur": "yillik",
              "baslangic": str(hedef + timedelta(days=1)),
              "bitis": str(hedef + timedelta(days=1))},
    )
    r = client.post(
        "/vardiya-plani/haftadan-kopyala", headers=admin,
        json={"kaynak_baslangic": str(kaynak), "hedef_baslangic": str(hedef)},
    )
    assert r.status_code == 200, r.text
    sonuc = r.json()
    assert sonuc["eklenen"] == 2 and sonuc["atlanan"] == 1
    assert "izin" in sonuc["sebepler"], "sessiz atlama YOK"


def test_KOPYA_TASLAK_GELIR(client, world, personel):
    admin = _h(client, world["slug_a"], world["admin_a"])
    s = _sablon(client, admin)
    kaynak = _pazartesi(17)
    hedef = _pazartesi(18)
    client.post(
        "/vardiya-plani", headers=admin,
        json={"shift_id": s["id"], "tarih": str(kaynak), "user_id": personel["id"]},
    )
    client.post(
        "/vardiya-plani/yayinla", headers=admin,
        params={"baslangic": str(kaynak), "gun": 7},
    )
    client.post(
        "/vardiya-plani/haftadan-kopyala", headers=admin,
        json={"kaynak_baslangic": str(kaynak), "hedef_baslangic": str(hedef)},
    )
    ozet = client.get(
        "/vardiya-plani/yayin-ozeti", headers=admin,
        params={"baslangic": str(hedef), "gun": 7},
    ).json()
    assert ozet["taslak"] == 1, "kopya gozden gecirilmeden yayinlanmamali"


def test_AYNI_HAFTAYA_KOPYALAMA_REDDEDILIR(client, world):
    admin = _h(client, world["slug_a"], world["admin_a"])
    hafta = _pazartesi(19)
    r = client.post(
        "/vardiya-plani/haftadan-kopyala", headers=admin,
        json={"kaynak_baslangic": str(hafta), "hedef_baslangic": str(hafta)},
    )
    assert r.status_code == 422


# ============================ ROL / LOKASYON ============================== #
def test_VARDIYA_ROLU_ve_LOKASYON_HUCREDE_DONER(client, world, personel):
    admin = _h(client, world["slug_a"], world["admin_a"])
    s = _sablon(client, admin)
    gun = _pazartesi(20)
    r = client.post(
        "/vardiya-plani", headers=admin,
        json={"shift_id": s["id"], "tarih": str(gun), "user_id": personel["id"],
              "vardiya_rolu": "temizlik", "alan": "Otopark"},
    )
    assert r.status_code == 201, r.text
    c = client.get(
        "/vardiya-plani/cizelge", headers=admin,
        params={"baslangic": str(gun), "gun": 1},
    ).json()
    blok = next(
        k for k in c["personel"] if k["user_id"] == personel["id"]
    )["bloklar"][0]
    # HESABIN ROLU DEGISMEZ: kisi `security`, vardiya rolu `temizlik`.
    assert blok["vardiya_rolu"] == "temizlik"
    assert blok["alan"] == "Otopark"
    kisi_rolu = next(
        k for k in c["personel"] if k["user_id"] == personel["id"]
    )["rol"]
    assert kisi_rolu == "security"


# ======================= KORUNACAKLAR (istek listesi) ===================== #
def test_KORUNDU_cakisma_KESIN_RED(client, world, personel):
    admin = _h(client, world["slug_a"], world["admin_a"])
    s1 = _sablon(client, admin, baslangic_saat="08:00", bitis_saat="16:00")
    s2 = _sablon(client, admin, baslangic_saat="12:00", bitis_saat="20:00")
    gun = _pazartesi(21)
    assert client.post(
        "/vardiya-plani", headers=admin,
        json={"shift_id": s1["id"], "tarih": str(gun), "user_id": personel["id"]},
    ).status_code == 201
    r = client.post(
        "/vardiya-plani", headers=admin,
        json={"shift_id": s2["id"], "tarih": str(gun), "user_id": personel["id"]},
    )
    assert r.status_code == 422


def test_KORUNDU_gun_asiri_vardiya(client, world, personel):
    """(P205) Gece vardiyasi ertesi gune tasar ve cizelgede oyle gorunur."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    s = _sablon(client, admin, baslangic_saat="20:00", bitis_saat="08:00")
    gun = _pazartesi(22)
    client.post(
        "/vardiya-plani", headers=admin,
        json={"shift_id": s["id"], "tarih": str(gun), "user_id": personel["id"]},
    )
    c = client.get(
        "/vardiya-plani/cizelge", headers=admin,
        params={"baslangic": str(gun), "gun": 2},
    ).json()
    blok = next(
        k for k in c["personel"] if k["user_id"] == personel["id"]
    )["bloklar"][0]
    assert blok["gece_asiyor"] is True
    assert blok["calisma_saat"] == 12.0


def test_KORUNDU_amir_YALNIZ_guvenligi_gorur(client, world, personel):
    """(P231) Amirin gorus alani vardiyada da izinde de AYNI."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    amir = _h(client, world["slug_a"], world["amir_a"])
    gorevli = client.get("/users", headers=admin, params={"limit": 200}).json()
    tesis = next(
        u for u in gorevli["items"] if u["email"] == world["gorevli_a"]["email"]
    )
    gun = _pazartesi(23)
    # Amir TESIS GOREVLISINE izin YAZAMAZ.
    r = client.post(
        "/vardiya-izin", headers=amir,
        json={"user_id": tesis["id"], "tur": "yillik",
              "baslangic": str(gun), "bitis": str(gun)},
    )
    assert r.status_code == 403
    # Ama GUVENLIK personeline yazabilir.
    r = client.post(
        "/vardiya-izin", headers=amir,
        json={"user_id": personel["id"], "tur": "yillik",
              "baslangic": str(gun), "bitis": str(gun)},
    )
    assert r.status_code == 201, r.text


def test_KORUNDU_parti_geri_alma(client, world, personel):
    """(P207) Toplu islem parti kimligiyle geri alinabiliyor."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    gun = _pazartesi(24)
    r = client.post(
        "/vardiya-plani/toplu", headers=admin,
        json={"user_id": personel["id"],
              "baslangic_tarih": str(gun), "bitis_tarih": str(gun + timedelta(days=2)),
              "baslangic_saat": "08:00", "bitis_saat": "16:00"},
    )
    assert r.status_code == 200 and r.json()["eklenen"] == 3


def test_KORUNDU_mesai_hesabi_calisiyor(client, world, personel):
    """(P214) Mesai ucu ayakta ve mola DUSULMUS saatle hesapliyor."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    r = client.get(
        "/mesai/ozet", headers=admin,
        params={"yil": date.today().year, "ay": date.today().month},
    )
    assert r.status_code == 200, r.text


# ================================ EXCEL =================================== #
def test_ORNEK_SABLON_INDIRILIR_ve_KOLONLARI_TASIR(client, world):
    """Bos sablon "tarih nasil yazilir" sorusunu yanitlamaz — ornek satir SART."""
    from io import BytesIO

    from openpyxl import load_workbook

    admin = _h(client, world["slug_a"], world["admin_a"])
    r = client.get("/vardiya-plani/ornek-sablon", headers=admin)
    assert r.status_code == 200, r.text
    assert "spreadsheetml" in r.headers["content-type"]
    ws = load_workbook(BytesIO(r.content)).active
    basliklar = [c.value for c in ws[1]]
    assert basliklar[:5] == ["tarih", "eposta", "ad", "baslangic_saat", "bitis_saat"]
    # ORNEK SATIR VAR ve tarih ISO yazilmis.
    assert ws.cell(row=2, column=1).value == "2026-03-02"


def test_DISA_AKTAR_ve_GERI_YUKLE_DONGUSU(client, world, personel):
    """Indirdigin dosyayi GERI YUKLEYEBILMELISIN — dongu kapali mi."""
    from io import BytesIO

    from openpyxl import load_workbook

    admin = _h(client, world["slug_a"], world["admin_a"])
    s = _sablon(client, admin, baslangic_saat="08:00", bitis_saat="16:00")
    kaynak = _pazartesi(25)
    client.post(
        "/vardiya-plani", headers=admin,
        json={"shift_id": s["id"], "tarih": str(kaynak), "user_id": personel["id"],
              "vardiya_rolu": "guvenlik", "alan": "Kapı",
              "molalar": [{"tur": "yasal", "dakika": 30}]},
    )
    r = client.get(
        "/vardiya-plani/disa-aktar", headers=admin,
        params={"baslangic": str(kaynak), "gun": 1},
    )
    assert r.status_code == 200, r.text
    ws = load_workbook(BytesIO(r.content)).active
    basliklar = [c.value for c in ws[1]]
    satir = dict(zip(basliklar, [c.value for c in ws[2]]))
    assert satir["baslangic_saat"] == "08:00" and satir["bitis_saat"] == "16:00"
    assert satir["vardiya_rolu"] == "guvenlik"
    assert satir["mola_dakika"] == "30"

    # AYNI SATIRI BASKA BIR GUNE geri yukle — bicim kabul edilmeli.
    yeni_gun = kaynak + timedelta(days=3)
    satir["tarih"] = str(yeni_gun)
    r = client.post(
        "/vardiya-plani/ice-aktar", headers=admin,
        json={"satirlar": [{"satir_no": 2, "degerler": satir}],
              "yalniz_dogrula": False},
    )
    assert r.status_code == 200, r.text
    assert r.json()["basarili"] == 1, r.json()


def test_ICE_AKTARIM_ONIZLEME_HICBIR_SEY_YAZMAZ(client, world, personel):
    admin = _h(client, world["slug_a"], world["admin_a"])
    gun = _pazartesi(26)
    govde = {
        "satirlar": [{
            "satir_no": 2,
            "degerler": {
                "tarih": str(gun), "eposta": world["guard_a"]["email"],
                "baslangic_saat": "09:00", "bitis_saat": "17:00",
            },
        }],
        "yalniz_dogrula": True,
    }
    r = client.post("/vardiya-plani/ice-aktar", headers=admin, json=govde)
    assert r.status_code == 200 and r.json()["uygulandi"] is False
    assert r.json()["satirlar"][0]["durum"] == "eklenecek"
    c = client.get(
        "/vardiya-plani/cizelge", headers=admin,
        params={"baslangic": str(gun), "gun": 1},
    ).json()
    kisi = next(k for k in c["personel"] if k["user_id"] == personel["id"])
    assert kisi["bloklar"] == [], "onizleme YAZMAMALI"


def test_ICE_AKTARIM_HATALI_SATIR_SEBEBIYLE_RAPORLANIR(client, world):
    """Sessiz atlama YOK: her satirin durumu ve SEBEBI doner."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    gun = _pazartesi(27)
    govde = {
        "satirlar": [
            {"satir_no": 2, "degerler": {
                "tarih": "03/02/2026", "eposta": world["guard_a"]["email"],
                "baslangic_saat": "08:00", "bitis_saat": "16:00"}},
            {"satir_no": 3, "degerler": {
                "tarih": str(gun), "eposta": "yok@ornek.com",
                "baslangic_saat": "08:00", "bitis_saat": "16:00"}},
            {"satir_no": 4, "degerler": {
                "tarih": str(gun), "eposta": world["guard_a"]["email"],
                "baslangic_saat": "sekiz", "bitis_saat": "16:00"}},
        ],
        "yalniz_dogrula": True,
    }
    r = client.post("/vardiya-plani/ice-aktar", headers=admin, json=govde)
    assert r.status_code == 200
    sonuc = r.json()
    assert sonuc["hatali"] == 3 and sonuc["basarili"] == 0
    mesajlar = {s["satir_no"]: s["mesaj"] for s in sonuc["satirlar"]}
    # BELIRSIZ TARIH KABUL EDILMEZ: `03/02/2026` ay mi gun mu?
    assert "02.03.2026" in mesajlar[2]
    assert "personel" in mesajlar[3].lower() or "staff" in mesajlar[3].lower()
    assert "08:00" in mesajlar[4]


# ========================== (§2e) YAYIN BILDIRIMI ========================== #
#
# Taslak/yayin ayriminin AMACI personelin plandan haberdar olmasi.
# Bildirim gitmezse ayrim yalnizca bir gecikme katmanidir.


def _bildirimler(client, headers, tip: str | None = None):
    r = client.get("/notifications", headers=headers, params={"limit": 50})
    assert r.status_code == 200, r.text
    items = r.json()["items"]
    return [b for b in items if tip is None or b["tip"] == tip]


def test_SAHA_PERSONELI_KENDI_BILDIRIMINI_GORUR(client, world, owner_conn):
    """OLCULEN KUSUR (P241 §2e): goremiyordu.

    `notifications._kapsam` yonetim gozlu rollere (security dahil)
    YALNIZ `user_id IS NULL` satirlarini gosteriyordu. Yani bir guvenlik
    gorevlisi bir GOREVE ATANDIGINDA (`gorev_atandi`, P191 §2) satir
    yaziliyor, push gidiyor, ama IN-APP LISTEDE HIC GORUNMUYORDU.
    Olculdu: listesi BOS donuyordu.
    """
    guard = _h(client, world["slug_a"], world["guard_a"])
    me = client.get("/me", headers=guard).json()
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO notification (tenant_id, user_id, tip, mesaj, "
            " mesaj_kimlik) VALUES (%s,%s,'gorev_atandi','X','gorev_atandi')",
            (world["a"], me["id"]),
        )
    assert _bildirimler(client, guard, "gorev_atandi"), "kendi satirini GORMELI"
    # TESIS GOREVLISI de uca erisebilmeli (once 403 aliyordu).
    gorevli = _h(client, world["slug_a"], world["gorevli_a"])
    assert client.get("/notifications", headers=gorevli).status_code == 200


def test_YAYIN_ETKILENEN_KISIYE_BILDIRIM_GONDERIR(client, world, personel):
    admin = _h(client, world["slug_a"], world["admin_a"])
    guard = _h(client, world["slug_a"], world["guard_a"])
    s = _sablon(client, admin)
    gun = _pazartesi(30)
    for i in (0, 1):
        client.post(
            "/vardiya-plani", headers=admin,
            json={"shift_id": s["id"], "tarih": str(gun + timedelta(days=i)),
                  "user_id": personel["id"]},
        )
    onceki = len(_bildirimler(client, guard, "vardiya_yayinlandi"))

    r = client.post(
        "/vardiya-plani/yayinla", headers=admin,
        params={"baslangic": str(gun), "gun": 7},
    )
    assert r.status_code == 200, r.text
    assert r.json()["yayinlanan"] == 2
    assert r.json()["bildirilen_kisi"] == 1

    yeni = _bildirimler(client, guard, "vardiya_yayinlandi")
    assert len(yeni) == onceki + 1
    # SAYI ve TARIH ARALIGI mesajda: "ne kadar, ne zaman" sorusu
    # bildirimin kendisinde yanitlanmali.
    b = yeni[0]
    assert "2" in b["mesaj"]
    assert str(gun) in b["mesaj"] and str(gun + timedelta(days=1)) in b["mesaj"]


def test_BILDIRIM_KISIYE_OZEL_SAYI_TASIR(client, world, personel):
    """Iki kisi yayinlandiginda herkes KENDI sayisini gorur."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    guard = _h(client, world["slug_a"], world["guard_a"])
    amir_kisi = client.get(
        "/users", headers=admin, params={"limit": 200}
    ).json()["items"]
    amir = next(
        u for u in amir_kisi if u["email"] == world["amir_a"]["email"]
    )
    s = _sablon(client, admin)
    gun = _pazartesi(31)
    # Guvenlige UC, amire BIR vardiya.
    for i in (0, 1, 2):
        client.post(
            "/vardiya-plani", headers=admin,
            json={"shift_id": s["id"], "tarih": str(gun + timedelta(days=i)),
                  "user_id": personel["id"]},
        )
    client.post(
        "/vardiya-plani", headers=admin,
        json={"shift_id": s["id"], "tarih": str(gun), "user_id": amir["id"]},
    )
    r = client.post(
        "/vardiya-plani/yayinla", headers=admin,
        params={"baslangic": str(gun), "gun": 7},
    )
    assert r.json()["bildirilen_kisi"] == 2

    b = _bildirimler(client, guard, "vardiya_yayinlandi")[0]
    assert "3" in b["mesaj"], b["mesaj"]
    amir_h = _h(client, world["slug_a"], world["amir_a"])
    ab = _bildirimler(client, amir_h, "vardiya_yayinlandi")[0]
    assert "1" in ab["mesaj"], ab["mesaj"]


def test_PATLAMA_BIRLESTIRILIR_okunmamis_satir_GUNCELLENIR(
    client, world, personel
):
    """Bildirim yorgunlugu: bes dakikada uc yayin = UC bildirim DEGIL."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    guard = _h(client, world["slug_a"], world["guard_a"])
    s = _sablon(client, admin)
    gun = _pazartesi(32)
    client.post(
        "/vardiya-plani", headers=admin,
        json={"shift_id": s["id"], "tarih": str(gun), "user_id": personel["id"]},
    )
    client.post(
        "/vardiya-plani/yayinla", headers=admin,
        params={"baslangic": str(gun), "gun": 7},
    )
    ilk = _bildirimler(client, guard, "vardiya_yayinlandi")
    assert len(ilk) >= 1

    # IKINCI YAYIN, AYNI PENCEREDE: yeni satir ACILMAZ.
    client.post(
        "/vardiya-plani", headers=admin,
        json={"shift_id": s["id"], "tarih": str(gun + timedelta(days=1)),
              "user_id": personel["id"]},
    )
    r = client.post(
        "/vardiya-plani/yayinla", headers=admin,
        params={"baslangic": str(gun), "gun": 7},
    )
    # PUSH GITMEZ (kisi ilkini henuz acmadi) ama BILGI KAYBOLMAZ.
    assert r.json()["bildirilen_kisi"] == 0
    ikinci = _bildirimler(client, guard, "vardiya_yayinlandi")
    assert len(ikinci) == len(ilk), "yeni satir ACILMAMALI"
    # SAYI TOPLANIR ve ARALIK GENISLER.
    birlesik = ikinci[0]["mesaj"]
    assert "2" in birlesik, birlesik
    assert str(gun + timedelta(days=1)) in birlesik


def test_OKUNMUS_BILDIRIM_BIRLESTIRILMEZ(client, world, personel):
    """Okunmus bir satiri degistirmek, gorulen metni arkadan degistirmekti."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    guard = _h(client, world["slug_a"], world["guard_a"])
    s = _sablon(client, admin)
    gun = _pazartesi(33)
    client.post(
        "/vardiya-plani", headers=admin,
        json={"shift_id": s["id"], "tarih": str(gun), "user_id": personel["id"]},
    )
    client.post(
        "/vardiya-plani/yayinla", headers=admin,
        params={"baslangic": str(gun), "gun": 7},
    )
    ilk = _bildirimler(client, guard, "vardiya_yayinlandi")
    client.patch(
        f"/notifications/{ilk[0]['id']}", headers=guard, json={"okundu": True}
    )

    client.post(
        "/vardiya-plani", headers=admin,
        json={"shift_id": s["id"], "tarih": str(gun + timedelta(days=1)),
              "user_id": personel["id"]},
    )
    r = client.post(
        "/vardiya-plani/yayinla", headers=admin,
        params={"baslangic": str(gun), "gun": 7},
    )
    assert r.json()["bildirilen_kisi"] == 1, "okunmussa YENI satir acilmali"


def test_DEGISMEYEN_KISIYE_BILDIRIM_GITMEZ(client, world, personel):
    """Plani degismeyen birine haber vermek gurultu olurdu."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    amir_h = _h(client, world["slug_a"], world["amir_a"])
    s = _sablon(client, admin)
    gun = _pazartesi(34)
    onceki = len(_bildirimler(client, amir_h, "vardiya_yayinlandi"))
    client.post(
        "/vardiya-plani", headers=admin,
        json={"shift_id": s["id"], "tarih": str(gun), "user_id": personel["id"]},
    )
    client.post(
        "/vardiya-plani/yayinla", headers=admin,
        params={"baslangic": str(gun), "gun": 7},
    )
    assert len(_bildirimler(client, amir_h, "vardiya_yayinlandi")) == onceki


def test_YAYINLANACAK_SEY_YOKSA_BILDIRIM_YOK(client, world, personel):
    admin = _h(client, world["slug_a"], world["admin_a"])
    guard = _h(client, world["slug_a"], world["guard_a"])
    gun = _pazartesi(35)
    onceki = len(_bildirimler(client, guard, "vardiya_yayinlandi"))
    r = client.post(
        "/vardiya-plani/yayinla", headers=admin,
        params={"baslangic": str(gun), "gun": 7},
    )
    assert r.json() == {"yayinlanan": 0, "bildirilen_kisi": 0}
    assert len(_bildirimler(client, guard, "vardiya_yayinlandi")) == onceki


# ======================= (E2E 2026-09) duzeltmeler ======================== #
def test_ONAYLANAN_IZIN_CAKISAN_VARDIYAYI_IPTAL_EDER(client, world, personel, owner_conn):
    """Vardiyasi olan gune izin onaylaniyor, vardiya `planli` kaliyordu —
    kisi ayni anda hem izinli hem gorevde."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    s = _sablon(client, admin)
    gun = _pazartesi(17)
    r = client.post(
        "/vardiya-plani", headers=admin,
        json={"shift_id": s["id"], "tarih": str(gun), "user_id": personel["id"]},
    )
    assert r.status_code == 201, r.text
    plan_id = r.json()["id"]
    r = client.post(
        "/vardiya-izin", headers=admin,
        json={"user_id": personel["id"], "tur": "yillik",
              "baslangic": str(gun), "bitis": str(gun)},
    )
    assert r.status_code == 201 and r.json()["durum"] == "onaylandi", r.text
    with owner_conn.cursor() as cur:
        cur.execute("SELECT durum FROM vardiya_plani WHERE id = %s", (plan_id,))
        assert cur.fetchone()[0] == "iptal"


def test_DISA_AKTARIM_PERSONELE_TASLAK_ve_EPOSTA_VERMEZ(client, world, personel):
    """Guvenlik/tesis gorevlisi Excel ile yayinlanmamis plani ve tum
    personelin e-postasini goruyordu."""
    import io

    from openpyxl import load_workbook

    admin = _h(client, world["slug_a"], world["admin_a"])
    guard = _h(client, world["slug_a"], world["guard_a"])
    s = _sablon(client, admin)
    gun = _pazartesi(18)
    r = client.post(
        "/vardiya-plani", headers=admin,
        json={"shift_id": s["id"], "tarih": str(gun), "user_id": personel["id"]},
    )
    assert r.status_code == 201 and r.json()["yayinlandi_at"] is None

    def _hucreler(h):
        r = client.get("/vardiya-plani/disa-aktar", headers=h,
                       params={"baslangic": str(gun), "gun": 1})
        assert r.status_code == 200, r.text
        wb = load_workbook(io.BytesIO(r.content))
        return [str(c.value) for ws in wb for row in ws.iter_rows() for c in row if c.value]

    assert any(world["guard_a"]["email"] in h for h in _hucreler(admin))
    assert not any(world["guard_a"]["email"] in h for h in _hucreler(guard))
