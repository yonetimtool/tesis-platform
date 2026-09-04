"""(P212 §3) IKINCI ESIKTE GUVENLIGE ESKALASYON.

===========================================================================
ISTENEN AKIS
===========================================================================
Birinci esik (P208, DEGISMEDI): 5 gurultu sikayeti -> sakine SESLI uyari,
sayac sifirlanir.

Ikinci esik (YENI): ayni daire icin sikayet TEKRAR 5'e ulasirsa ->
GUVENLIGE bildirim (daire + kacinci kez + "polise haber veriniz"),
yoneticiye ayri bilgi, sayac yine sifirlanir.

===========================================================================
BU DOSYANIN KILITLERI
===========================================================================
  1. BIRINCI esikte guvenlige HICBIR SEY gitmez (gerileme kapisi),
  2. IKINCI esikte guvenlige gider ve metin DAIRE + SAYI + KEZ tasir,
  3. SIKAYET EDENIN kimligi HICBIR bildirimde gecmez,
  4. Yonetici de haberdar olur,
  5. Eskalasyon bildirimi SESLI kanaldan gider,
  6. Sayac ikinci esikte de sifirlanir,
  7. GORUNTU/DIGER tipleri gurultu akisini ETKILEMEZ,
  8. Ucuncu kez: ayni eskalasyon, artan `kez`,
  9. `asama` denetim kaydina ve uyari satirina yazilir.
"""
from __future__ import annotations

import uuid

import pytest

from app.push_metinleri import METINLER

from tests.test_p208_gurultu_sakin import (  # noqa: F401 — fixture'lar
    _bildirimler,
    _calistir,
    _kullanici,
    _sakin_ekle,
    _sikayet,
    d,
    push_spy,
)


def _bes_gurultu(d):
    for _ in range(5):
        _sikayet(d, kategori="gurultu")


def _guvenlikci(d) -> uuid.UUID:
    """Tesiste AKTIF bir guvenlik gorevlisi."""
    from app.security import hash_password

    uid = uuid.uuid4()
    d.conn.execute(
        "INSERT INTO app_user (id, tenant_id, ad, email, telefon, "
        "password_hash, password_set, role) "
        "VALUES (%s,%s,%s,%s,%s,%s,true,'security'::user_role)",
        (uid, d.tenant, "Guvenlik P212", f"p212-{uid.hex[:8]}@x.com",
         f"+9054{uuid.uuid4().int % 10**8:08d}", hash_password("Parola123!")))
    d.conn.commit()
    return uid


# ==================== 1) BIRINCI ESIK DEGISMEDI ========================== #

def test_BIRINCI_esikte_GUVENLIGE_HICBIR_SEY_gitmez(d, push_spy):
    """Gerileme kapisi: eskalasyon IKINCI esige ozeldir."""
    _sakin_ekle(d, "kiraci")
    _guvenlikci(d)
    _bes_gurultu(d)

    kayit = _calistir(d)
    assert kayit is not None and kayit.asama == 1

    tipler = {p["k"] for p in push_spy}
    assert "gurultu_uyari_sakin" in tipler, "sakin uyarisi DURMALI"
    assert "gurultu_eskalasyon_guvenlik" not in tipler
    assert _bildirimler(d, "gurultu_eskalasyon_guvenlik") == []


# ==================== 2) IKINCI ESIK: ESKALASYON ========================= #

def test_IKINCI_esikte_GUVENLIGE_bildirim_gider(d, push_spy):
    _sakin_ekle(d, "kiraci")
    guvenlik = _guvenlikci(d)
    # Susma suresi kapatilir: iki esik ARDISIK olarak surulecek ve
    # susma penceresi ikincisini bastirirdi (bilincli davranis, P208).
    d.conn.execute(
        "UPDATE tenant SET gurultu_susma_gun=0 WHERE id=%s", (d.tenant,))
    d.conn.commit()

    _bes_gurultu(d)
    ilk = _calistir(d)
    assert ilk.asama == 1

    _bes_gurultu(d)
    ikinci = _calistir(d)
    assert ikinci is not None, "ikinci esik ASILMALI"
    assert ikinci.asama == 2

    esk = [p for p in push_spy if p["k"] == "gurultu_eskalasyon_guvenlik"]
    assert esk, "guvenlige bildirim GITMEDI"
    assert esk[-1]["target_roles"] == ("security", "guvenlik_amiri")
    assert esk[-1]["params"]["daire"] == d.hedef["no"]
    assert esk[-1]["params"]["kez"] == 2
    assert esk[-1]["params"]["sayi"] == 5

    # IN-APP SATIR guvenlikciye yazildi: push kapali olabilir.
    satirlar = _bildirimler(d, "gurultu_eskalasyon_guvenlik")
    assert any(str(r[0]) == str(guvenlik) for r in satirlar)


def test_ESKALASYON_METNI_daire_sayi_kez_tasir_ve_POLISI_soyler(d):
    """Guvenligin gidecegi yer ve ciddiyet metinde OLMALI."""
    m = METINLER["gurultu_eskalasyon_guvenlik"]
    assert set(m.params) == {"daire", "sayi", "kez"}
    tr = m.govde["tr"]
    assert "{daire}" in tr and "{sayi}" in tr and "{kez}" in tr
    # Sistem KIMSEYI ARAMAZ: metin gorevliye "haber veriniz" der.
    assert "polis" in tr.lower()
    # 7 DIL PARITE.
    assert set(m.govde) == {"tr", "en", "ar", "ru", "de", "fr", "es"}
    assert set(m.baslik) == set(m.govde)


def test_SIKAYETCININ_KIMLIGI_hicbir_metinde_GECMEZ(d, push_spy):
    """En sert kural: eskalasyon daireyi soyler, KISIYI degil."""
    _sakin_ekle(d, "kiraci")
    _guvenlikci(d)
    d.conn.execute(
        "UPDATE tenant SET gurultu_susma_gun=0 WHERE id=%s", (d.tenant,))
    d.conn.commit()

    _bes_gurultu(d)
    _calistir(d)
    _bes_gurultu(d)
    _calistir(d)

    for tip in ("gurultu_eskalasyon_guvenlik", "gurultu_eskalasyon_yonetim"):
        for p in [x for x in push_spy if x["k"] == tip]:
            assert "complainant" not in str(p["params"]).lower()
            assert set(p["params"]) <= {"daire", "sayi", "kez"}
        for _uid, mesaj in _bildirimler(d, tip):
            # Sikayet edenlerin adi "Sikayetci" — metne SIZMAMALI.
            assert "Sikayetci" not in (mesaj or "")


def test_YONETICI_de_haberdar_olur(d, push_spy):
    _sakin_ekle(d, "kiraci")
    _guvenlikci(d)
    d.conn.execute(
        "UPDATE tenant SET gurultu_susma_gun=0 WHERE id=%s", (d.tenant,))
    d.conn.commit()

    _bes_gurultu(d)
    _calistir(d)
    _bes_gurultu(d)
    _calistir(d)

    yon = [p for p in push_spy if p["k"] == "gurultu_eskalasyon_yonetim"]
    assert yon, "yoneticiye bilgi GITMEDI"
    assert yon[-1]["target_roles"] == ("admin", "yonetici")
    # SAHIPSIZ satir: yonetim gozu gorur, kisi basina cogaltilmaz.
    satirlar = _bildirimler(d, "gurultu_eskalasyon_yonetim")
    assert satirlar and all(r[0] is None for r in satirlar)


def test_ESKALASYON_SESLI_kanaldan_gider(d):
    """Duyulmayan bir eskalasyon, hic gonderilmemis gibidir."""
    from app.push_kanal import KANAL_KRITIK, KANAL_SESSIZ, kanal_sec, ses_adi

    for tip in ("gurultu_eskalasyon_guvenlik", "gurultu_eskalasyon_yonetim"):
        assert kanal_sec(tip, sesli=True) == KANAL_KRITIK
        assert ses_adi(tip, sesli=True) == "yonetio_bildirim.caf"
        # KULLANICI SESI KAPATTIYSA sessiz kanaldan gider — tercih
        # gormezden gelinmez (P207 karari).
        assert kanal_sec(tip, sesli=False) == KANAL_SESSIZ
        assert ses_adi(tip, sesli=False) is None


# ==================== 3) SAYAC VE DIGER TIPLER =========================== #

def test_IKINCI_esikte_de_SAYAC_SIFIRLANIR(d):
    _sakin_ekle(d, "kiraci")
    _guvenlikci(d)
    d.conn.execute(
        "UPDATE tenant SET gurultu_susma_gun=0 WHERE id=%s", (d.tenant,))
    d.conn.commit()

    _bes_gurultu(d)
    _calistir(d)
    _bes_gurultu(d)
    _calistir(d)

    acik = d.conn.execute(
        "SELECT count(*) FROM unit_complaint WHERE target_unit_id=%s "
        "AND kategori='gurultu' AND durum='acik'", (d.hedef["id"],)
    ).fetchone()[0]
    assert acik == 0, "ikinci esikten sonra da sayac sifirlanmali"


def test_GORUNTU_sikayetleri_GURULTU_akisini_ETKILEMEZ(d, push_spy):
    """(P209 korunuyor) Baska tipler ne sayaci artirir ne eskalasyon.

    Kategori adi `goruntu_kirliligi` (enum'daki gercek deger).
    """
    _sakin_ekle(d, "kiraci")
    _guvenlikci(d)
    for _ in range(5):
        cid = uuid.uuid4()
        uid = _kullanici(d)
        d.conn.execute(
            "INSERT INTO unit_complaint (id, tenant_id, target_unit_id, "
            "complainant_user_id, kategori, durum) "
            "VALUES (%s,%s,%s,%s,'goruntu_kirliligi','acik')",
            (cid, d.tenant, d.hedef["id"], uid))
    d.conn.commit()

    assert _calistir(d) is None, "goruntu sikayeti gurultu esigini ASMAMALI"
    assert push_spy == []
    # Goruntu sikayetleri ACIK kalir: bir tipin esigi otekinin
    # defterini silmez.
    acik = d.conn.execute(
        "SELECT count(*) FROM unit_complaint WHERE target_unit_id=%s "
        "AND kategori='goruntu_kirliligi' AND durum='acik'", (d.hedef["id"],)
    ).fetchone()[0]
    assert acik == 5


# ==================== 4) UCUNCU KEZ + DENETIM ============================ #

def test_UCUNCU_kez_ayni_eskalasyon_ARTAN_kez_ile(d, push_spy):
    """Sistemde daha ust bir merci YOK — polis zaten eskalasyonun
    kendisi. Yeni bir "asama 3 davranisi" uydurmak, olmayan bir yetkiyi
    varmis gibi gostermek olurdu."""
    _sakin_ekle(d, "kiraci")
    _guvenlikci(d)
    d.conn.execute(
        "UPDATE tenant SET gurultu_susma_gun=0 WHERE id=%s", (d.tenant,))
    d.conn.commit()

    asamalar = []
    for _ in range(3):
        _bes_gurultu(d)
        asamalar.append(_calistir(d).asama)
    assert asamalar == [1, 2, 3]

    esk = [p for p in push_spy if p["k"] == "gurultu_eskalasyon_guvenlik"]
    assert [p["params"]["kez"] for p in esk] == [2, 3]


def test_ASAMA_denetim_kaydina_YAZILIR(d):
    _sakin_ekle(d, "kiraci")
    _guvenlikci(d)
    d.conn.execute(
        "UPDATE tenant SET gurultu_susma_gun=0 WHERE id=%s", (d.tenant,))
    d.conn.commit()

    _bes_gurultu(d)
    _calistir(d)
    _bes_gurultu(d)
    _calistir(d)

    satirlar = d.conn.execute(
        "SELECT meta FROM audit_log WHERE tenant_id=%s AND resource_id=%s "
        "ORDER BY ts", (d.tenant, str(d.hedef["id"]))).fetchall()
    metalar = [r[0] for r in satirlar if r[0] and r[0].get("islem") == "gurultu_esik"]
    assert [m["asama"] for m in metalar] == [1, 2]
    assert [m["eskalasyon"] for m in metalar] == [False, True]
    # KIMLIK SIZMAZ: guvenlikcilerin listesi denetime yazilmaz.
    assert all("guvenlik" not in str(m).lower() or "eskalasyon" in str(m)
               for m in metalar)


@pytest.mark.parametrize("dil", ["tr", "en", "ar", "ru", "de", "fr", "es"])
def test_7_DIL_PARITE(dil):
    for tip in ("gurultu_eskalasyon_guvenlik", "gurultu_eskalasyon_yonetim"):
        m = METINLER[tip]
        assert m.baslik.get(dil), f"{tip}/{dil} baslik yok"
        assert m.govde.get(dil), f"{tip}/{dil} govde yok"
