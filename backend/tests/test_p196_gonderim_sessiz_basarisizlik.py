"""(P196) KOD GONDERIMI SESSIZCE BASARISIZ OLAMAZ.

===========================================================================
OLCULEN KUSUR
===========================================================================
Kullanici web profilinden e-postasini degistiriyor, ekran "doğrulama kodu
gönderildi" diyor, posta kutusuna HICBIR SEY gelmiyordu. Iki ayri hata
ust uste binmisti:

  1. `ayar` GECILMIYORDU. `/me/eposta/kod-iste` ve `/me/hesap-sil/...`
     `eposta_kodu_uret_ve_gonder`i `ayar` VERMEDEN cagiriyordu; o
     parametre verilmezse saglayici ENV'den secilir. Tesis KENDI
     SMTP'sini girmisse ve ENV bossa sonuc `LogEpostaSaglayici` olur —
     yani hicbir sey gonderilmez. AYNI dosyadaki oteki akislar
     (`auth.py` giris kodu / parola sifirlama, `davet.py`) `ayar`
     GECIYORDU ve calisiyorlardi; kullanicinin gozlemi de tam olarak
     buydu ("davet ve OTP calisiyor, profil e-postasi gitmiyor").
     Bu, P172 §1'de kapatilan kusur sinifinin aynisi.

  2. GONDERIM SONUCU ATILIYORDU. `gonder()`
     `GonderimSonucu(durum='yapilandirilmadi'...)` donuyor, cagiran
     okumadan `{"durum": "gonderildi"}` yaziyordu.

===========================================================================
BU DOSYA NE KILITLIYOR
===========================================================================
  A. Gonderim BASARISIZKEN uc 200 DONMEZ (502 doner).
  B. Denemenin IZI KALIR: `mesaj_gonderim`e satir yazilir — hata
     donse ve istek transaction'i geri alinsa BILE (kayit AYRI
     oturumda yazilir).
  C. Kod GOVDEYE yazilmaz: dogrulama kodu bir sirdir ve `kod_hash`
     olarak saklanmasinin anlami, duz metnini baska bir tabloya
     yazmamaktir.

NOT — BASARI YOLU: dev ortaminda STARTTLS konusan bir SMTP sunucusu
YOK (gonderici kosulsuz `starttls()` cagiriyor), bu yuzden "gercekten
gitti" hali CANLI olarak olculemedi. Onun yerine saglayici SUREC ICINDE
degistirilerek olculuyor (asagidaki `test_BASARIDA_*`): bu, HTTP
katmanini atlar ama olculen sozlesme tam olarak kirilan seydir —
"sonuc `gonderildi` ise satir `gonderildi` yazilir ve hata donmez".
"""
from __future__ import annotations

import uuid

import psycopg
import pytest


def _giris(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _son_gonderim(owner_conn, tenant_id):
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT durum, konu, govde, hata FROM mesaj_gonderim "
            "WHERE tenant_id = %s ORDER BY created_at DESC LIMIT 1",
            (tenant_id,),
        )
        return cur.fetchone()


# ==================== A) HTTP: BASARIDA IZ KALIR, KOD SIZMAZ ========== #
#
# NOT — NEDEN BURADA "502" OLCULMUYOR: dev/test ortami P196'da KONSOL
# tasiyicisina baglandi (`EPOSTA_SAGLAYICI=konsol`), yani gonderim burada
# BASARILI olur. Basarisizlik yolu ortamdan bagimsiz olsun diye SUREC
# ICINDE, saglayici degistirilerek olculuyor (B bolumu). Ortamin
# saglayicisina bagli bir "502 bekle" testi, yarin dev'e gercek SMTP
# girildiginde sessizce anlamsizlasirdi.

def test_HTTP_akisi_CALISIR_ve_IZ_BIRAKIR(client, world, owner_conn):
    """Uctan uca: kod iste -> 200 -> `mesaj_gonderim`de satir."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    yeni = f"p196-{uuid.uuid4().hex[:10]}@ornek.com"
    r = client.post("/me/eposta/kod-iste", headers=h, json={"eposta": yeni})
    assert r.status_code == 200, r.text

    satir = _son_gonderim(owner_conn, world["a"])
    assert satir is not None, "gonderim denemesi HIC iz birakmadi"
    durum, konu, govde, hata = satir
    assert durum == "gonderildi", f"durum {durum!r}"


def test_KOD_GOVDEYE_YAZILMAZ(client, world, owner_conn):
    """Dogrulama kodu bir SIRDIR: `kod_hash` olarak saklanmasinin anlami,
    duz metnini gecmis tablosuna yazmamaktir."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    yeni = f"p196-{uuid.uuid4().hex[:10]}@ornek.com"
    client.post("/me/eposta/kod-iste", headers=h, json={"eposta": yeni})

    durum, konu, govde, hata = _son_gonderim(owner_conn, world["a"])
    # Govde yer tutucu olmali; icinde 6 haneli bir kod GECMEMELI.
    import re
    assert re.search(r"\b\d{6}\b", govde or "") is None, (
        f"gonderim gecmisine DUZ KOD yazilmis: {govde!r}"
    )
    assert "dogrulama kodu" in (govde or "").lower()
    # TASIYICI ADI da yazili olmali: "gonderildi" diyen bir satirin
    # gercekte nereye gittigi gecmisten okunabilmeli.
    assert "tasiyici=" in (govde or "")


# ==================== B) BASARI YOLU (surec ici) ==================== #

def test_BASARIDA_satir_gonderildi_yazilir_ve_HATA_DONMEZ(world):
    """Saglayici `gonderildi` derse: satir `gonderildi`, sonuc `gonderildi`.

    SUREC ICI olcum — HTTP katmani atlanir (testler CANLI sunucuya vurur
    ve oradaki saglayiciyi buradan degistiremeyiz). Olculen sozlesme
    yine de tam olarak kirilan seydir.
    """
    import asyncio

    from app import telefon_kodu
    from app.db import SessionLocal, set_tenant
    from app.mesajlasma import GonderimSonucu, MesajSaglayici

    class _SahteSaglayici(MesajSaglayici):
        ad = "sahte"

        def gonder(self, hedef, konu, govde, html=None, headers=None):
            return GonderimSonucu("gonderildi", self.ad)

    eposta = f"p196-basari-{uuid.uuid4().hex[:8]}@ornek.com"
    asil = telefon_kodu.__dict__.get("_test_saglayici_ezmesi")
    assert asil is None  # temiz baslangic

    async def _kos():
        from app.db import engine

        # (P187 dersi) Paylasilan motor + kendi dongumuz: bastaki
        # `dispose(close=False)` olu donguye bagli havuzu birakir.
        await engine.dispose(close=False)
        try:
            import app.gonderim as gonderim_modulu

            eski = gonderim_modulu.saglayici
            gonderim_modulu.saglayici = lambda kanal, ayar=None: _SahteSaglayici()
            try:
                async with SessionLocal() as s:
                    async with s.begin():
                        await set_tenant(s, world["a"])
                        return await telefon_kodu.eposta_kodu_uret_ve_gonder(
                            s, tenant_id=world["a"], eposta=eposta,
                            amac="eposta_ekle",
                        )
            finally:
                gonderim_modulu.saglayici = eski
        finally:
            await engine.dispose()

    sonuc = asyncio.run(_kos())
    assert sonuc.durum == "gonderildi", sonuc


def test_BASARIDA_gecmis_satiri_gonderildi(world, owner_conn):
    """Ayni akis, bu kez `mesaj_gonderim` satirina bakilir."""
    import asyncio

    from app import telefon_kodu
    from app.db import SessionLocal, set_tenant
    from app.mesajlasma import GonderimSonucu, MesajSaglayici

    class _SahteSaglayici(MesajSaglayici):
        ad = "sahte"

        def gonder(self, hedef, konu, govde, html=None, headers=None):
            return GonderimSonucu("gonderildi", self.ad)

    eposta = f"p196-basari2-{uuid.uuid4().hex[:8]}@ornek.com"

    async def _kos():
        from app.db import engine

        await engine.dispose(close=False)
        try:
            import app.gonderim as gonderim_modulu

            eski = gonderim_modulu.saglayici
            gonderim_modulu.saglayici = lambda kanal, ayar=None: _SahteSaglayici()
            try:
                async with SessionLocal() as s:
                    async with s.begin():
                        await set_tenant(s, world["a"])
                        await telefon_kodu.eposta_kodu_uret_ve_gonder(
                            s, tenant_id=world["a"], eposta=eposta,
                            amac="eposta_ekle",
                        )
            finally:
                gonderim_modulu.saglayici = eski
        finally:
            await engine.dispose()

    asyncio.run(_kos())
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT durum, hata FROM mesaj_gonderim WHERE hedef = %s", (eposta,)
        )
        satir = cur.fetchone()
    assert satir is not None, "basarili gonderim de IZ BIRAKMALI"
    assert satir[0] == "gonderildi", satir


def test_BASARISIZLIKTA_satir_basarisiz_ve_HATA_METNI_var(world, owner_conn):
    """GONDERIM BASARISIZKEN: satir `basarisiz` + `hata` DOLU.

    Ortamdan BAGIMSIZ: saglayici surec icinde degistirilir. Bu testin
    olctugu sey, kullanicinin sikayetindeki ASIL durumdur — saglayici
    "gonderemedim" diyor ve bunun bir IZI kalmali.
    """
    import asyncio

    from app import telefon_kodu
    from app.db import SessionLocal, set_tenant
    from app.mesajlasma import GonderimSonucu, MesajSaglayici

    class _KirikSaglayici(MesajSaglayici):
        ad = "kirik-test"

        def gonder(self, hedef, konu, govde, html=None, headers=None):
            return GonderimSonucu(
                "yapilandirilmadi", self.ad, "smtp_yapilandirilmadi"
            )

    eposta = f"p196-kirik-{uuid.uuid4().hex[:8]}@ornek.com"

    async def _kos():
        from app.db import engine

        await engine.dispose(close=False)
        try:
            import app.gonderim as gonderim_modulu

            eski = gonderim_modulu.saglayici
            gonderim_modulu.saglayici = lambda kanal, ayar=None: _KirikSaglayici()
            try:
                async with SessionLocal() as s:
                    async with s.begin():
                        await set_tenant(s, world["a"])
                        return await telefon_kodu.eposta_kodu_uret_ve_gonder(
                            s, tenant_id=world["a"], eposta=eposta,
                            amac="eposta_ekle",
                        )
            finally:
                gonderim_modulu.saglayici = eski
        finally:
            await engine.dispose()

    sonuc = asyncio.run(_kos())
    assert sonuc.durum != "gonderildi", "kirik saglayici 'gonderildi' DEMEMELI"

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT durum, hata FROM mesaj_gonderim WHERE hedef = %s", (eposta,)
        )
        satir = cur.fetchone()
    assert satir is not None, "BASARISIZ deneme de IZ BIRAKMALI"
    assert satir[0] == "basarisiz", satir
    assert satir[1], "hata metni bos: operator NEDEN sorusunu yanitlayamaz"


def test_UC_SONUCU_OKUYOR_kaynak_kilidi():
    """Uc, gonderim sonucunu OKUYUP hata donuyor mu (kaynak uzerinden).

    Davranis testi ortamin saglayicisina baglidir (dev'de konsol tasiyici
    var, gonderim basarili olur). Bu kilit ortamdan bagimsizdir: kod
    yolunda `durum != "gonderildi"` kontrolu ve 502 DURUYOR mu?
    """
    from pathlib import Path

    kok = Path(__file__).resolve().parent.parent
    me = (kok / "app" / "routers" / "me.py").read_text(encoding="utf-8")
    assert 'sonuc.durum != "gonderildi"' in me, (
        "uc gonderim sonucunu OKUMUYOR — sessiz basarisizlik geri geldi"
    )
    assert '"kod_gonderilemedi"' in me, "hata kodu kayboldu"


# ==================== C) AYAR GECILIYOR MU (kaynak kilidi) ============ #

def test_KOD_UCLARI_TENANT_AYARINI_GECIYOR():
    """`ayar` gecmeyen bir cagri, tesisin kendi SMTP'sini GORMEZ.

    Kaynak uzerinden kilit: bu kusur calisma aninda ancak tesisin kendi
    SMTP'si varken gorunur (dev'de yok). Cagri sekli sabittir ve
    okunabilir — kilit oraya konur.
    """
    from pathlib import Path

    kok = Path(__file__).resolve().parent.parent
    me = (kok / "app" / "routers" / "me.py").read_text(encoding="utf-8")
    # Iki uc da ortak yardimciyi cagirmali; o yardimci `tenant_ayari`yi
    # okuyup `ayar=` ile gecirir.
    assert me.count("_kod_gonder_ve_dogrula(") >= 3, (
        "profil e-posta / hesap silme uclari ortak yardimciyi kullanmali"
    )
    assert "ayar = await tenant_ayari(db, tenant_id)" in me, (
        "yardimci tesis ayarini OKUMUYOR — ENV'e duser (P172 §1 kusuru)"
    )
