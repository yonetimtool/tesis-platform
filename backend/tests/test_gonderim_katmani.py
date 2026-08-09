"""(P154 / Asama 9) ORTAK GONDERIM KATMANI.

Brief: "Ortak gonderim arayuzu (kanal: sms | whatsapp | email | push),
saglayici eklentisi takilabilir olsun" + "tesis basina gunluk kota".

BU DOSYANIN ASIL ISI, SESSIZ BASARIYI REDDETMEK. Yapilandirilmamis bir
kanalin "gonderildi" demesi, panelde gonderilmemis bir mesaji
gonderilmis gibi gosterip kullaniciyi "neden ulasmadi" diye aramaya
birakirdi.
"""
from __future__ import annotations

import uuid

import pytest

from app.gonderim import (
    ETKIN_KANALLAR,
    GUNLUK_KOTA,
    KANALLAR,
    YapilandirilmamisSaglayici,
    eposta_saglayicisi,
    saglayici,
)


# ===================== 1) KANAL -> SAGLAYICI, TEK NOKTA ==================== #

def test_dort_kanalin_HEPSI_bir_saglayici_dondurur():
    """Brief'in kanal kumesi eksiksiz cozulmeli."""
    assert set(KANALLAR) == {"sms", "eposta", "whatsapp", "push"}
    for kanal in KANALLAR:
        s = saglayici(kanal)
        assert s is not None and s.ad, kanal


def test_YAPILANDIRILMAMIS_kanal_sessizce_BASARILI_DONMEZ():
    """WhatsApp saglayicisi henuz SECILMEDI (brief'in kendi notu).

    Olculen sey "hata veriyor mu" degil, `gonderildi` DEMIYOR olmasi.
    """
    s = saglayici("whatsapp")
    assert isinstance(s, YapilandirilmamisSaglayici)
    sonuc = s.gonder("+905321112203", None, "deneme")
    assert sonuc.durum == "basarisiz"
    assert sonuc.hata == "saglayici_yok"


def test_BILINMEYEN_kanal_istisna_FIRLATMAZ():
    """Cagiran genelde bir DONGU icindedir; tek bozuk satir kalan 200
    aliciyi dusurmemeli. Kusur `basarisiz` olarak GECMISE yazilir."""
    sonuc = saglayici("faks").gonder("x", None, "y")
    assert sonuc.durum == "basarisiz"


def test_ETKIN_KANALLAR_veritabani_enumuyla_AYNI(owner_conn):
    """Kod katmani dort kanal biliyor; VERI katmani bugun iki.

    Bu ayrim BILINCLI (bkz. gonderim.py modul basligi) ama SESSIZ
    OLMAMALI: enum buyudugunde ya da kucuduğunde bu test duser ve
    `ETKIN_KANALLAR` guncellenmeye zorlanir.
    """
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT e.enumlabel FROM pg_type t JOIN pg_enum e "
            "ON e.enumtypid = t.oid WHERE t.typname = 'mesaj_kanal'"
        )
        enum = {r[0] for r in cur.fetchall()}
    assert enum == set(ETKIN_KANALLAR), (
        f"mesaj_kanal={enum} ile ETKIN_KANALLAR={ETKIN_KANALLAR} ayristi"
    )


def test_eposta_secimi_ROUTERDA_DEGIL_bu_katmanda():
    """Secim tek yerde olmali; `routers/mesajlar.py` artik kendi
    SMTP kurulumunu YAPMAMALI (yoksa ikinci bir yol onu kopyalar)."""
    import inspect

    from app.routers import mesajlar, tanitim

    for modul in (mesajlar, tanitim):
        kaynak = inspect.getsource(modul)
        assert "SmtpEpostaSaglayici(" not in kaynak, (
            f"{modul.__name__} kendi SMTP saglayicisini kuruyor"
        )
    assert eposta_saglayicisi() is not None


# ===================== 2) GUNLUK KOTA ====================================== #

@pytest.mark.asyncio
async def test_kota_gonderim_BASLAMADAN_kontrol_edilir(owner_conn):
    """Kota yetmiyorsa istek TUMDEN reddedilir — yarim gonderim YERINE hic.

    Sayac `mesaj_gonderim` tablosundan okunur (Redis'ten DEGIL): Redis
    dustugunde sayac sifirlanip o gun kota SINIRSIZ olurdu ve kota bir
    FATURA kontroludur.
    """
    from app.db import SessionLocal, set_tenant
    from app.gonderim import gunluk_kalan, kota_kontrol
    from app.errors import APIError

    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO tenant (ad, slug) VALUES ('Kota Sitesi', %s) RETURNING id",
            (f"kota-{uuid.uuid4().hex[:8]}",),
        )
        tid = cur.fetchone()[0]

    async with SessionLocal() as s:
        async with s.begin():
            await set_tenant(s, tid)
            # Taze tesis: kotanin TAMAMI duruyor.
            assert await gunluk_kalan(s, tid) == GUNLUK_KOTA
            # Kotanin altinda kalan istek gecer.
            await kota_kontrol(s, tid, 1)
            # Kotayi asan istek 429.
            with pytest.raises(APIError) as e:
                await kota_kontrol(s, tid, GUNLUK_KOTA + 1)
            assert e.value.status_code == 429

    with owner_conn.cursor() as cur:
        cur.execute("DELETE FROM tenant WHERE id = %s", (tid,))


# ===================== 3) ALICI SEGMENTI — ROL BAZLI ======================= #

def test_rol_segmenti_PERSONELI_de_kapsar(client, world):
    """Brief'in dorduncu segmenti: rol bazli.

    NEDEN AYRI BIR TEST: blok/borc suzgecleri SAKIN listesinden turuyor
    (`unit_resident` join'i) ve `security` / `tesis_gorevlisi` rollerinin
    dairesi YOKTUR — o listede hic gorunmezler. Rol segmenti ayri bir
    sorgu olmasaydi "guvenlige duyuru gonder" SESSIZCE bos liste
    uretirdi ve hicbir yerde hata cikmazdi.
    """
    r = client.post(
        "/auth/login",
        json={
            "tenant_slug": world["slug_a"],
            "email": world["yonetici_a"]["email"],
            "password": world["yonetici_a"]["password"],
        },
    )
    assert r.status_code == 200, r.text
    basliklar = {"Authorization": f"Bearer {r.json()['access_token']}"}

    # Sablon TESTTE acilir: `world` fixture'i tesisi bos kuruyor ve
    # varsayilan sablon setine yaslanmak, testi seed'in icerigine bagli
    # kilardi (o degisince burasi sebepsiz duserdi).
    s = client.post(
        "/mesaj-sablonlari",
        headers=basliklar,
        json={
            "kanal": "sms",
            "ad": f"Rol Segment Denemesi {uuid.uuid4().hex[:6]}",
            "govde": "Sayın {adi_soyadi}, duyuru.",
            "amac": "operasyonel",
        },
    )
    assert s.status_code == 201, s.text

    g = client.post(
        "/mesajlar/gonder",
        headers=basliklar,
        json={"sablon_id": s.json()["id"], "rol": "security"},
    )
    assert g.status_code == 201, g.text
    # `world` fixture'i A tesisinde bir `security` hesabi aciyor; segment
    # onu BULMALI. Sifir cikarsa sorgu sakin listesine dusmus demektir.
    ozet = g.json()
    assert ozet["gonderildi"] + ozet["adres_yok"] >= 1, ozet
