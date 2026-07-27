"""Ceviri isi (worker) — GERCEK DB + SAHTE saglayici.

Kapsam: yazim/yeniden-ceviri kararlarinin DB'ye yansimasi, ELLE DUZELTME
kuralinin ucu uca davranisi, BASARISIZLIK ILKESI (saglayici cokerse icerik
durur) ve yeni ceviri tablolarinda RLS izolasyonu.

Saglayici her testte sahtelenir (ag yok) — sonuclar deterministiktir.
"""
from __future__ import annotations

import json
import uuid

import pytest

from app import ceviri
from app.ceviri_service import entity_cevir
from app.config import settings
from app.translate import TranslationError, TranslationProvider


# ------------------------------ sahte saglayici ----------------------------- #
class _Sahte(TranslationProvider):
    """Cagri sayan sahte saglayici.

    `hata`: TranslationError atar (saglayici tamamen cokmus).
    `atlanan`: bu dilleri sonuca EKLEMEZ (kismi basari).
    """

    def __init__(self, *, hata: str | None = None, atlanan: tuple[str, ...] = ()):
        self.cagri = 0
        self.hata = hata
        self.atlanan = atlanan

    def translate(self, text, source_lang, target_langs):
        self.cagri += 1
        if self.hata:
            raise TranslationError(self.hata)
        return {
            d: f"<{d}>{text}" for d in target_langs if d not in self.atlanan
        }


class _HazirDegil(TranslationProvider):
    hazir = False

    def translate(self, text, source_lang, target_langs):  # pragma: no cover
        raise AssertionError("hazir olmayan saglayici cagrilmamali")


# --------------------------------- yardimci --------------------------------- #
def _duyuru(owner_conn, tenant_id, baslik="Su kesintisi", govde="Yarin 10:00."):
    return owner_conn.execute(
        """
        INSERT INTO announcement (tenant_id, baslik, govde, olusturan_user_id)
        SELECT %s, %s, %s, u.id FROM app_user u
         WHERE u.tenant_id = %s ORDER BY u.email LIMIT 1
        RETURNING id
        """,
        (tenant_id, baslik, govde, tenant_id),
    ).fetchone()[0]


def _ceviriler(owner_conn, entity_id) -> dict[str, dict]:
    satirlar = owner_conn.execute(
        "SELECT dil, alanlar, durum::text, cevirildi_mi, elle_duzeltildi, "
        "kaynak_hash, hata_mesaji FROM announcement_ceviri "
        "WHERE announcement_id = %s",
        (entity_id,),
    ).fetchall()
    return {
        r[0]: {
            "alanlar": r[1],
            "durum": r[2],
            "cevirildi_mi": r[3],
            "elle_duzeltildi": r[4],
            "kaynak_hash": r[5],
            "hata_mesaji": r[6],
        }
        for r in satirlar
    }


def _elle_duzelt(owner_conn, tenant_id, entity_id, dil, metin, kaynak_hash_):
    """Yoneticinin bir dildeki ceviriyi ELLE duzeltmesini taklit eder."""
    owner_conn.execute(
        """
        INSERT INTO announcement_ceviri
            (tenant_id, announcement_id, dil, alanlar, durum, cevirildi_mi,
             elle_duzeltildi, kaynak_hash)
        VALUES (%s, %s, %s, %s::jsonb, 'hazir', false, true, %s)
        ON CONFLICT (tenant_id, announcement_id, dil) DO UPDATE
           SET alanlar = EXCLUDED.alanlar, durum = 'hazir', cevirildi_mi = false,
               elle_duzeltildi = true, kaynak_hash = EXCLUDED.kaynak_hash
        """,
        (tenant_id, entity_id, dil, json.dumps(metin, ensure_ascii=False),
         kaynak_hash_),
    )


# --------------------------------- testler ---------------------------------- #
def test_alti_hedef_dil_hazir_yazilir(owner_conn, world):
    """Kaynak tr; kalan 6 dil cevrilir ve `hazir` olur."""
    aid = _duyuru(owner_conn, world["a"])
    p = _Sahte()

    ozet = entity_cevir("duyuru", aid, world["a"], provider=p)

    assert sorted(ozet["cevrilen"]) == sorted(ceviri.hedef_diller("tr"))
    assert ozet["hata"] == []
    satirlar = _ceviriler(owner_conn, aid)
    assert set(satirlar) == set(ceviri.hedef_diller("tr"))
    assert "tr" not in satirlar  # kaynak dil icin satir ACILMAZ
    for dil, s in satirlar.items():
        assert s["durum"] == "hazir"
        assert s["cevirildi_mi"] is True and s["elle_duzeltildi"] is False
        assert s["alanlar"] == {
            "baslik": f"<{dil}>Su kesintisi",
            "govde": f"<{dil}>Yarin 10:00.",
        }
    # Alan basina TEK cagri (2 alan) — dil basina ayri cagri yapilmaz.
    assert p.cagri == 2


def test_yeniden_kosum_IDEMPOTENT_bosa_ceviri_yapmaz(owner_conn, world):
    aid = _duyuru(owner_conn, world["a"])
    entity_cevir("duyuru", aid, world["a"], provider=_Sahte())

    ikinci = _Sahte()
    ozet = entity_cevir("duyuru", aid, world["a"], provider=ikinci)

    assert ozet["cevrilen"] == [] and ikinci.cagri == 0


def test_kaynak_metin_degisince_yeniden_cevrilir(owner_conn, world):
    aid = _duyuru(owner_conn, world["a"])
    entity_cevir("duyuru", aid, world["a"], provider=_Sahte())
    onceki = _ceviriler(owner_conn, aid)["ru"]["kaynak_hash"]

    owner_conn.execute(
        "UPDATE announcement SET govde = %s WHERE id = %s",
        ("Yarin 14:00 (guncellendi).", aid),
    )
    ozet = entity_cevir("duyuru", aid, world["a"], provider=_Sahte())

    assert sorted(ozet["cevrilen"]) == sorted(ceviri.hedef_diller("tr"))
    yeni = _ceviriler(owner_conn, aid)["ru"]
    assert yeni["kaynak_hash"] != onceki
    assert yeni["alanlar"]["govde"] == "<ru>Yarin 14:00 (guncellendi)."


def test_ELLE_DUZELTME_kaynak_AYNIYSA_korunur(owner_conn, world):
    """Ilgisiz alan (foto/tarih) degisip is yeniden kossa bile duzeltme kalir."""
    aid = _duyuru(owner_conn, world["a"])
    entity_cevir("duyuru", aid, world["a"], provider=_Sahte())
    h = ceviri.kaynak_hash({"baslik": "Su kesintisi", "govde": "Yarin 10:00."})
    _elle_duzelt(
        owner_conn, world["a"], aid, "ru",
        {"baslik": "Отключение воды", "govde": "Завтра в 10:00."}, h,
    )

    # Kaynak metne DOKUNMADAN is yeniden kosuyor.
    p = _Sahte()
    ozet = entity_cevir("duyuru", aid, world["a"], provider=p)

    assert "ru" not in ozet["cevrilen"] and ozet["korunan"] == 1
    assert p.cagri == 0
    ru = _ceviriler(owner_conn, aid)["ru"]
    assert ru["alanlar"]["baslik"] == "Отключение воды"   # KORUNDU
    assert ru["elle_duzeltildi"] is True and ru["cevirildi_mi"] is False


def test_ELLE_DUZELTME_kaynak_DEGISINCE_gecersiz(owner_conn, world):
    """Kaynak metin degistiyse duzeltme eski metnin duzeltmesidir -> yenilenir."""
    aid = _duyuru(owner_conn, world["a"])
    entity_cevir("duyuru", aid, world["a"], provider=_Sahte())
    h = ceviri.kaynak_hash({"baslik": "Su kesintisi", "govde": "Yarin 10:00."})
    _elle_duzelt(
        owner_conn, world["a"], aid, "ru",
        {"baslik": "Отключение воды", "govde": "Завтра в 10:00."}, h,
    )

    owner_conn.execute(
        "UPDATE announcement SET govde = %s WHERE id = %s",
        ("Su kesintisi IPTAL edildi.", aid),
    )
    ozet = entity_cevir("duyuru", aid, world["a"], provider=_Sahte())

    assert "ru" in ozet["cevrilen"] and ozet["korunan"] == 0
    ru = _ceviriler(owner_conn, aid)["ru"]
    assert ru["alanlar"]["govde"] == "<ru>Su kesintisi IPTAL edildi."
    assert ru["elle_duzeltildi"] is False  # duzeltme gecersiz kildi


def test_BASARISIZLIK_ILKESI_saglayici_cokerse_icerik_durur(owner_conn, world):
    """Saglayici down: diller `hata`, ICERIK ve ORIJINAL metin YERINDE."""
    aid = _duyuru(owner_conn, world["a"])

    ozet = entity_cevir(
        "duyuru", aid, world["a"], provider=_Sahte(hata="baglanti reddedildi")
    )

    assert ozet["cevrilen"] == []
    assert sorted(ozet["hata"]) == sorted(ceviri.hedef_diller("tr"))
    satirlar = _ceviriler(owner_conn, aid)
    for s in satirlar.values():
        assert s["durum"] == "hata"
        assert "baglanti reddedildi" in s["hata_mesaji"]
        assert s["alanlar"] == {}  # yarim/uydurma ceviri YOK
    # Icerik kaydi bozulmadi: orijinal metin okunabilir.
    assert owner_conn.execute(
        "SELECT baslik, govde FROM announcement WHERE id = %s", (aid,)
    ).fetchone() == ("Su kesintisi", "Yarin 10:00.")


def test_saglayici_hazir_degilse_hata_yazilir_cokme_yok(owner_conn, world):
    aid = _duyuru(owner_conn, world["a"])
    ozet = entity_cevir("duyuru", aid, world["a"], provider=_HazirDegil())
    assert sorted(ozet["hata"]) == sorted(ceviri.hedef_diller("tr"))
    assert all(s["durum"] == "hata" for s in _ceviriler(owner_conn, aid).values())


def test_KISMI_basari_yalniz_eksik_dil_hata_olur(owner_conn, world):
    """Bir dil cevrilemezse digerleri `hazir` kalir (hepsi cope gitmez)."""
    aid = _duyuru(owner_conn, world["a"])

    ozet = entity_cevir(
        "duyuru", aid, world["a"], provider=_Sahte(atlanan=("ar",))
    )

    assert ozet["hata"] == ["ar"]
    satirlar = _ceviriler(owner_conn, aid)
    assert satirlar["ar"]["durum"] == "hata"
    assert "eksik alan" in satirlar["ar"]["hata_mesaji"]
    assert satirlar["ru"]["durum"] == "hazir"


def test_hata_sonrasi_yeniden_deneme_hazir_yapar(owner_conn, world):
    aid = _duyuru(owner_conn, world["a"])
    entity_cevir("duyuru", aid, world["a"], provider=_Sahte(hata="down"))

    ozet = entity_cevir("duyuru", aid, world["a"], provider=_Sahte())

    assert sorted(ozet["cevrilen"]) == sorted(ceviri.hedef_diller("tr"))
    satirlar = _ceviriler(owner_conn, aid)
    assert all(s["durum"] == "hazir" for s in satirlar.values())
    assert all(s["hata_mesaji"] is None for s in satirlar.values())


def test_icerik_silinince_ceviriler_CASCADE_gider(owner_conn, world):
    """Silinmis duyurunun metni ceviri tablosunda YASAMAZ (yetim satir yok)."""
    aid = _duyuru(owner_conn, world["a"])
    entity_cevir("duyuru", aid, world["a"], provider=_Sahte())
    assert len(_ceviriler(owner_conn, aid)) == 6

    owner_conn.execute("DELETE FROM announcement WHERE id = %s", (aid,))

    assert _ceviriler(owner_conn, aid) == {}


def test_silinmis_icerik_icin_is_cokmez(owner_conn, world):
    aid = _duyuru(owner_conn, world["a"])
    owner_conn.execute("DELETE FROM announcement WHERE id = %s", (aid,))
    ozet = entity_cevir("duyuru", aid, world["a"], provider=_Sahte())
    assert ozet["cevrilen"] == [] and ozet.get("not") == "icerik yok"


@pytest.mark.parametrize(
    "tip_ad,tablo,alan",
    [("site_kurali", "site_kurali", "icerik"), ("etkinlik", "etkinlik", "aciklama")],
)
def test_kural_ve_etkinlik_de_cevrilir(owner_conn, world, tip_ad, tablo, alan):
    """Uc entity AYNI yoldan gecer (registry ile parametrik)."""
    uid = owner_conn.execute(
        "SELECT id FROM app_user WHERE tenant_id = %s ORDER BY email LIMIT 1",
        (world["a"],),
    ).fetchone()[0]
    if tablo == "site_kurali":
        eid = owner_conn.execute(
            "INSERT INTO site_kurali (tenant_id, baslik, icerik, olusturan_user_id) "
            "VALUES (%s,'Havuz','Havuz 08:00-22:00.',%s) RETURNING id",
            (world["a"], uid),
        ).fetchone()[0]
    else:
        eid = owner_conn.execute(
            "INSERT INTO etkinlik (tenant_id, baslik, aciklama, tarih, "
            "olusturan_user_id) VALUES (%s,'Senlik','Bahcede muzik.',now(),%s) "
            "RETURNING id",
            (world["a"], uid),
        ).fetchone()[0]

    ozet = entity_cevir(tip_ad, eid, world["a"], provider=_Sahte())

    assert sorted(ozet["cevrilen"]) == sorted(ceviri.hedef_diller("tr"))
    t = ceviri.tip(tip_ad)
    satir = owner_conn.execute(
        f"SELECT alanlar FROM {t.ceviri_tablo} WHERE {t.fk_kolon} = %s AND dil='ru'",
        (eid,),
    ).fetchone()[0]
    assert satir["baslik"].startswith("<ru>")
    assert satir[alan].startswith("<ru>")


# ----------------------------------- RLS ------------------------------------ #
def test_RLS_ceviri_satirlari_tenant_disina_SIZMAZ(owner_conn, app_conn, world):
    """app_rw yalniz kendi tenant baglamindaki ceviri satirlarini gorur."""
    aid = _duyuru(owner_conn, world["a"])
    entity_cevir("duyuru", aid, world["a"], provider=_Sahte())

    with app_conn.transaction():
        # Dogru baglam: satirlar GORUNUR.
        app_conn.execute(
            "SELECT set_config('app.current_tenant_id', %s, true)", (str(world["a"]),)
        )
        assert app_conn.execute(
            "SELECT count(*) FROM announcement_ceviri WHERE announcement_id = %s",
            (aid,),
        ).fetchone()[0] == 6

    with app_conn.transaction():
        # BASKA tenant baglami: HICBIR satir gorunmez.
        app_conn.execute(
            "SELECT set_config('app.current_tenant_id', %s, true)", (str(world["b"]),)
        )
        assert app_conn.execute(
            "SELECT count(*) FROM announcement_ceviri WHERE announcement_id = %s",
            (aid,),
        ).fetchone()[0] == 0


@pytest.mark.parametrize(
    "tablo",
    ["announcement_ceviri", "site_kurali_ceviri", "etkinlik_ceviri"],
)
def test_RLS_baglam_YOKKEN_hicbir_ceviri_gorunmez(
    owner_conn, app_conn, world, tablo
):
    """Guvenli varsayilan (kurulu desen: test_rls_isolation).

    Ceviri tablosu eklenip RLS listesine yazilmayi UNUTMAK sessiz bir
    cross-tenant sizintisidir; bu test onu yakalar. `app_conn` bu testte HIC
    baglam almaz (temiz oturum).
    """
    aid = _duyuru(owner_conn, world["a"])
    entity_cevir("duyuru", aid, world["a"], provider=_Sahte())
    assert app_conn.execute(f"SELECT tenant_id FROM {tablo}").fetchall() == []


def test_RLS_baska_tenant_adina_ceviri_YAZILAMAZ(owner_conn, app_conn, world):
    """WITH CHECK: A baglaminda B'nin tenant_id'siyle satir yazilamaz."""
    aid = _duyuru(owner_conn, world["a"])
    import psycopg

    with pytest.raises(psycopg.errors.Error):
        with app_conn.transaction():
            app_conn.execute(
                "SELECT set_config('app.current_tenant_id', %s, true)",
                (str(world["a"]),),
            )
            app_conn.execute(
                "INSERT INTO announcement_ceviri (tenant_id, announcement_id, dil, "
                "alanlar, durum, kaynak_hash) "
                "VALUES (%s, %s, 'ru', '{}'::jsonb, 'hazir', 'h')",
                (world["b"], aid),
            )


def test_cevrilebilir_tip_dsn_varsayilani_app_rw(owner_conn, world):
    """Ceviri isi OWNER ile degil app_rw ile yazar (RLS'e tabi)."""
    assert "app_rw" in settings.app_dsn
    aid = _duyuru(owner_conn, world["a"])
    entity_cevir("duyuru", aid, world["a"], provider=_Sahte())
    assert len(_ceviriler(owner_conn, aid)) == 6


def test_desteklenmeyen_dil_DB_kisitina_takilir(owner_conn, world):
    """ck_*_dil: kume genisletmek MIGRATION ister (sessizce veri girmez)."""
    aid = _duyuru(owner_conn, world["a"])
    import psycopg

    with pytest.raises(psycopg.errors.CheckViolation):
        owner_conn.execute(
            "INSERT INTO announcement_ceviri (tenant_id, announcement_id, dil, "
            "alanlar, durum, kaynak_hash) "
            "VALUES (%s, %s, 'ja', '{}'::jsonb, 'hazir', 'h')",
            (world["a"], aid),
        )


def test_ayni_dil_icin_IKINCI_satir_acilamaz(owner_conn, world):
    aid = _duyuru(owner_conn, world["a"])
    entity_cevir("duyuru", aid, world["a"], provider=_Sahte())
    import psycopg

    with pytest.raises(psycopg.errors.UniqueViolation):
        owner_conn.execute(
            "INSERT INTO announcement_ceviri (tenant_id, announcement_id, dil, "
            "alanlar, durum, kaynak_hash) "
            "VALUES (%s, %s, 'ru', '{}'::jsonb, 'hazir', 'h')",
            (world["a"], aid),
        )


def test_cross_tenant_FK_reddedilir(owner_conn, world):
    """Composite FK: B'nin tenant'inda A'nin duyurusuna ceviri baglanamaz."""
    aid = _duyuru(owner_conn, world["a"])
    import psycopg

    with pytest.raises(psycopg.errors.ForeignKeyViolation):
        owner_conn.execute(
            "INSERT INTO announcement_ceviri (tenant_id, announcement_id, dil, "
            "alanlar, durum, kaynak_hash) "
            "VALUES (%s, %s, 'ru', '{}'::jsonb, 'hazir', 'h')",
            (world["b"], aid),
        )


def test_bilinmeyen_tip_ValueError(world):
    with pytest.raises(ValueError):
        entity_cevir("yok", uuid.uuid4(), world["a"], provider=_Sahte())
