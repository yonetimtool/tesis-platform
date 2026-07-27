"""Icerik cevirisi — SAF cekirdek + saglayici soyutlamasi (DB/ag YOK).

Bu dosya ceviri kararlarini dogrudan sinar: Accept-Language ayristirma,
geri-dusme zinciri, kaynak ozeti, ELLE DUZELTME kurali ve yerelestirme.
Saglayici testlerinde ag cagrisi sahtelenir (httpx transport / stub sinif).
"""
from __future__ import annotations

import httpx
import pytest

from app import ceviri
from app.translate import (
    EchoProvider,
    LibreTranslateProvider,
    NoopProvider,
    TranslationError,
    get_translation_provider,
    reset_translation_provider,
)


# --------------------------- Accept-Language -------------------------------- #
def test_accept_language_q_sirasi_ve_bolge_dusurme():
    # Bolge eki duser (tr-TR -> tr); q'ya gore azalan siralama.
    assert ceviri.accept_language_coz("tr-TR,tr;q=0.9,en;q=0.8") == ["tr", "en"]
    assert ceviri.accept_language_coz("en;q=0.3,ru;q=0.9") == ["ru", "en"]


def test_accept_language_joker_q0_ve_bozuk_parcalar_atlanir():
    assert ceviri.accept_language_coz("*") == []
    assert ceviri.accept_language_coz("de;q=0") == []          # q=0 = istenmiyor
    assert ceviri.accept_language_coz("fr;q=abc") == []        # bozuk q -> 0
    assert ceviri.accept_language_coz(None) == []
    assert ceviri.accept_language_coz("") == []
    # Bozuk parca digerlerini DUSURMEZ.
    assert ceviri.accept_language_coz(",,es;q=0.5,") == ["es"]


def test_accept_language_ayni_dil_tekrarlanmaz():
    assert ceviri.accept_language_coz("tr-TR,tr-CY,tr") == ["tr"]


def test_dil_sec_geri_dusme_zinciri():
    # 1) Acik ?dil= her seyi ezer.
    assert ceviri.dil_sec(
        accept_language="ru", kaynak_dil="tr", istek_dil="de"
    ) == "de"
    # 2) 'orijinal' kaynak dili zorlar.
    assert ceviri.dil_sec(
        accept_language="ru", kaynak_dil="tr", istek_dil="orijinal"
    ) == "tr"
    # 3) Accept-Language'daki ilk DESTEKLENEN dil (ja desteklenmiyor -> ru).
    assert ceviri.dil_sec(
        accept_language="ja;q=0.9,ru;q=0.8", kaynak_dil="tr"
    ) == "ru"
    # 4) Hicbiri desteklenmiyorsa KAYNAK dil (icerik okunamaz kalmaz).
    assert ceviri.dil_sec(accept_language="ja,ko", kaynak_dil="tr") == "tr"
    assert ceviri.dil_sec(accept_language=None, kaynak_dil="tr") == "tr"
    # 5) Desteklenmeyen ACIK istek de 400 degil geri-dusme uretir.
    assert ceviri.dil_sec(
        accept_language="ru", kaynak_dil="tr", istek_dil="ja"
    ) == "ru"


# ------------------------------ kaynak ozeti -------------------------------- #
def test_kaynak_hash_deterministik_ve_sira_bagimsiz():
    a = ceviri.kaynak_hash({"baslik": "A", "govde": "B"})
    b = ceviri.kaynak_hash({"govde": "B", "baslik": "A"})
    assert a == b
    assert a != ceviri.kaynak_hash({"baslik": "A", "govde": "C"})


def test_kaynak_hash_alan_sinirini_karistirmaz():
    """Ayirici olmasa "ab"+"c" ile "a"+"bc" ayni ozeti verirdi."""
    assert ceviri.kaynak_hash({"baslik": "ab", "govde": "c"}) != ceviri.kaynak_hash(
        {"baslik": "a", "govde": "bc"}
    )


def test_kaynak_hash_none_bos_metin_gibi():
    assert ceviri.kaynak_hash({"baslik": None}) == ceviri.kaynak_hash({"baslik": ""})


# --------------------- ELLE DUZELTME kurali (cekirdek) ---------------------- #
def _satir(**kw):
    temel = dict(
        dil="ru",
        alanlar={"baslik": "X", "govde": "Y"},
        durum=ceviri.DURUM_HAZIR,
        cevirildi_mi=True,
        elle_duzeltildi=False,
        kaynak_hash="h1",
    )
    temel.update(kw)
    return ceviri.CeviriSatiri(**temel)


def test_elle_duzeltme_kaynak_AYNIYSA_korunur():
    s = _satir(elle_duzeltildi=True, kaynak_hash="h1")
    assert ceviri.korunur_mu(s, "h1") is True


def test_elle_duzeltme_kaynak_DEGISTIYSE_korunmaz():
    """Kaynak metin degistiyse duzeltme ARTIK YANLIS metnin duzeltmesidir."""
    s = _satir(elle_duzeltildi=True, kaynak_hash="h1")
    assert ceviri.korunur_mu(s, "h2") is False


def test_makine_cevirisi_hicbir_zaman_korunmaz():
    assert ceviri.korunur_mu(_satir(elle_duzeltildi=False), "h1") is False
    assert ceviri.korunur_mu(None, "h1") is False


def test_cevrilecek_diller_kararlari():
    hedefler = ["en", "ru", "de", "fr"]
    mevcut = {
        # elle duzeltilmis + kaynak ayni -> KORUNUR (cevrilmez)
        "en": _satir(dil="en", elle_duzeltildi=True, kaynak_hash="h1"),
        # zaten hazir + kaynak ayni -> bosa istek atmayiz
        "ru": _satir(dil="ru", durum=ceviri.DURUM_HAZIR, kaynak_hash="h1"),
        # hazir ama kaynak DEGISMIS -> yeniden cevrilir
        "de": _satir(dil="de", durum=ceviri.DURUM_HAZIR, kaynak_hash="ESKI"),
        # fr: satir YOK -> cevrilir
    }
    assert ceviri.cevrilecek_diller(
        mevcut=mevcut, yeni_hash="h1", hedefler=hedefler
    ) == ("de", "fr")


def test_cevrilecek_diller_hata_durumu_yeniden_denenir():
    mevcut = {"ru": _satir(durum=ceviri.DURUM_HATA, kaynak_hash="h1")}
    assert ceviri.cevrilecek_diller(
        mevcut=mevcut, yeni_hash="h1", hedefler=["ru"]
    ) == ("ru",)


def test_hedef_diller_kaynagi_dislar():
    assert "tr" not in ceviri.hedef_diller("tr")
    assert len(ceviri.hedef_diller("tr")) == len(ceviri.DESTEKLENEN_DILLER) - 1
    assert "en" not in ceviri.hedef_diller("en")


# ----------------------------- yerelestirme --------------------------------- #
_ORIJINAL = {"baslik": "Su kesintisi", "govde": "Yarin 10:00."}


def test_yerelestir_kaynak_dil_orijinali_verir():
    y = ceviri.yerelestir(
        orijinal=_ORIJINAL, satir=None, istenen_dil="tr", kaynak_dil="tr"
    )
    assert y.alanlar == _ORIJINAL
    assert y.dil == "tr" and y.durum == ceviri.DURUM_HAZIR
    assert y.cevirildi_mi is False  # orijinal makine ciktisi DEGIL


def test_yerelestir_hazir_ceviri_servis_edilir():
    s = _satir(dil="ru", alanlar={"baslik": "Отключение", "govde": "Завтра"})
    y = ceviri.yerelestir(
        orijinal=_ORIJINAL, satir=s, istenen_dil="ru", kaynak_dil="tr"
    )
    assert y.alanlar["baslik"] == "Отключение"
    assert y.dil == "ru" and y.durum == ceviri.DURUM_HAZIR
    assert y.cevirildi_mi is True


def test_yerelestir_elle_duzeltilmis_ceviri_makine_sayilmaz():
    s = _satir(dil="ru", elle_duzeltildi=True)
    y = ceviri.yerelestir(
        orijinal=_ORIJINAL, satir=s, istenen_dil="ru", kaynak_dil="tr"
    )
    assert y.durum == ceviri.DURUM_HAZIR
    assert y.cevirildi_mi is False  # insan duzeltmesi


@pytest.mark.parametrize("durum", [ceviri.DURUM_BEKLIYOR, ceviri.DURUM_HATA])
def test_yerelestir_hazir_degilse_ORIJINAL_servis_edilir(durum):
    """[ORIJINAL] Ekran BOS KALMAZ; durum gercegi soyler."""
    s = _satir(dil="ru", durum=durum, alanlar={})
    y = ceviri.yerelestir(
        orijinal=_ORIJINAL, satir=s, istenen_dil="ru", kaynak_dil="tr"
    )
    assert y.alanlar == _ORIJINAL
    assert y.dil == "tr"          # geri-dusme: metnin gercek dili kaynak
    assert y.durum == durum       # istemci "çeviri hazırlanıyor" diyebilir
    assert y.cevirildi_mi is False


def test_yerelestir_satir_yoksa_bekliyor():
    y = ceviri.yerelestir(
        orijinal=_ORIJINAL, satir=None, istenen_dil="ru", kaynak_dil="tr"
    )
    assert y.alanlar == _ORIJINAL and y.durum == ceviri.DURUM_BEKLIYOR


def test_yerelestir_eksik_alan_orijinalle_tamamlanir():
    """YARIM ceviri servis edilmez: eksik alan orijinaliyle doldurulur."""
    s = _satir(dil="ru", alanlar={"baslik": "Отключение"})  # govde eksik
    y = ceviri.yerelestir(
        orijinal=_ORIJINAL, satir=s, istenen_dil="ru", kaynak_dil="tr"
    )
    assert y.alanlar["baslik"] == "Отключение"
    assert y.alanlar["govde"] == _ORIJINAL["govde"]


# ------------------------------ saglayicilar -------------------------------- #
#: Ozgun sinif — monkeypatch'ten ONCE yakalanir (aksi halde lambda kendini cagirir).
_GERCEK_CLIENT = httpx.Client


def _sahte_httpx(monkeypatch, handler) -> None:
    """httpx.Client'i MockTransport'lu ozgun istemciye yonlendirir."""
    transport = httpx.MockTransport(handler)
    monkeypatch.setattr(
        httpx, "Client", lambda *a, **kw: _GERCEK_CLIENT(transport=transport)
    )


def test_echo_saglayici_her_hedef_dili_dondurur():
    sonuc = EchoProvider().translate("Merhaba", "tr", ["en", "ru"])
    assert sonuc == {"en": "[en] Merhaba", "ru": "[ru] Merhaba"}


def test_noop_saglayici_bos_doner_ve_hazir_degil():
    p = NoopProvider()
    assert p.hazir is False
    assert p.translate("x", "tr", ["en"]) == {}


def test_libretranslate_yanit_ayristirma(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
        import json as _json

        assert "/translate" in str(request.url)
        veri = _json.loads(request.read().decode())
        return httpx.Response(
            200, json={"translatedText": f"<{veri['target']}>{veri['q']}"}
        )

    _sahte_httpx(monkeypatch, handler)
    p = LibreTranslateProvider(base_url="http://libretranslate:5000")
    assert p.translate("Merhaba", "tr", ["en", "ru"]) == {
        "en": "<en>Merhaba",
        "ru": "<ru>Merhaba",
    }


def test_libretranslate_KISMI_basari_digerlerini_dusurmez(monkeypatch):
    """Bir dil 500 verirse diger diller yine cevrilir (kismi basari mesru)."""

    def handler(request: httpx.Request) -> httpx.Response:
        import json as _json

        veri = _json.loads(request.read().decode())
        if veri["target"] == "ar":
            return httpx.Response(500, json={"error": "model yok"})
        return httpx.Response(200, json={"translatedText": f"ok-{veri['target']}"})

    _sahte_httpx(monkeypatch, handler)
    p = LibreTranslateProvider(base_url="http://libretranslate:5000")
    sonuc = p.translate("Merhaba", "tr", ["en", "ar", "ru"])
    assert set(sonuc) == {"en", "ru"}          # ar EKSIK -> cagiran 'hata' isaretler
    assert "ar" not in sonuc


def test_libretranslate_TAMAMEN_basarisizsa_TranslationError(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(503, text="down")

    _sahte_httpx(monkeypatch, handler)
    p = LibreTranslateProvider(base_url="http://libretranslate:5000")
    with pytest.raises(TranslationError):
        p.translate("Merhaba", "tr", ["en", "ru"])


def test_libretranslate_url_yoksa_hazir_degil():
    """TRANSLATE_URL bossa saglayici HAZIR DEGIL (ag cagrisi denenmez)."""
    p = LibreTranslateProvider(base_url="")
    assert p.hazir is False
    with pytest.raises(TranslationError):
        p.translate("x", "tr", ["en"])


def test_libretranslate_bos_metin_ag_cagrisi_yapmaz(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:  # pragma: no cover
        raise AssertionError("bos metin icin ag cagrisi YAPILMAMALI")

    _sahte_httpx(monkeypatch, handler)
    p = LibreTranslateProvider(base_url="http://libretranslate:5000")
    assert p.translate("   ", "tr", ["en"]) == {"en": "   "}


def test_fabrika_bilinmeyen_saglayici_noop_a_duser(monkeypatch):
    """Yanlis yapilandirma icerik YAZMAYI engellememeli (cokme yok)."""
    from app import config

    monkeypatch.setattr(config.settings, "translate_provider", "yok-boyle-bir-sey")
    reset_translation_provider()
    try:
        assert isinstance(get_translation_provider(), NoopProvider)
    finally:
        reset_translation_provider()


def test_fabrika_echo_secimi(monkeypatch):
    from app import config

    monkeypatch.setattr(config.settings, "translate_provider", "echo")
    reset_translation_provider()
    try:
        assert isinstance(get_translation_provider(), EchoProvider)
    finally:
        reset_translation_provider()


def test_tip_kaydi_migration_ile_tutarli():
    """Registry, migration 0007'deki tablo/kolon adlariyla ayni olmali."""
    assert ceviri.tip("duyuru").ceviri_tablo == "announcement_ceviri"
    assert ceviri.tip("duyuru").alanlar == ("baslik", "govde")
    assert ceviri.tip("site_kurali").fk_kolon == "site_kurali_id"
    assert ceviri.tip("site_kurali").alanlar == ("baslik", "icerik")
    assert ceviri.tip("etkinlik").alanlar == ("baslik", "aciklama")
    with pytest.raises(ValueError):
        ceviri.tip("bilinmeyen")


# --------------------------- kuyruklama (commit yarisi) ---------------------- #
def test_kuyruklama_GECIKMELI_commit_yarisini_onler(monkeypatch):
    """Ceviri isi istegin transaction'i commit EDILMEDEN kuyruklanir.

    Worker hemen kossa icerigi goremez ve ceviri HIC uretilmezdi (gerçekten
    gozlemlendi: worker loglarinda `not: icerik yok`). Bu yuzden `countdown`
    ile kucuk bir gecikme verilir.
    """
    import uuid as _uuid

    from app import ceviri_service

    cagrilar = []
    monkeypatch.setattr(
        ceviri_service.celery_app,
        "send_task",
        lambda ad, **kw: cagrilar.append((ad, kw)),
    )
    assert ceviri_service.enqueue_ceviri("duyuru", _uuid.uuid4(), _uuid.uuid4()) is True
    (ad, kw), = cagrilar
    assert ad == "ceviri.translate_entity"
    assert kw["countdown"] > 0, "commit yarisi icin gecikme SART"
    assert set(kw["kwargs"]) == {"tip_ad", "entity_id", "tenant_id"}


def test_kuyruk_erisilemezse_ISTISNA_YUKSELMEZ(monkeypatch):
    """BASARISIZLIK ILKESI: broker down olsa bile icerik kaydi dusmez."""
    import uuid as _uuid

    from app import ceviri_service

    def _patlat(*a, **kw):
        raise RuntimeError("redis erisilemiyor")

    monkeypatch.setattr(ceviri_service.celery_app, "send_task", _patlat)
    # Yukselmez, yalnizca False doner.
    assert ceviri_service.enqueue_ceviri("duyuru", _uuid.uuid4(), _uuid.uuid4()) is False


def test_task_icerik_gorunmuyorsa_YENIDEN_DENER(monkeypatch):
    """Commit yarisi kaybedilirse task RETRY eder — ceviri sessizce kaybolmaz."""
    import uuid as _uuid

    import app.ceviri_service as svc
    from app import tasks

    # Task govdesi `entity_cevir`i cagri aninda import eder -> modulde sahtele.
    monkeypatch.setattr(
        svc, "entity_cevir",
        lambda *a, **kw: {"cevrilen": [], "hata": [], "korunan": 0,
                          "atlanan": 0, "not": "icerik yok"},
    )

    class _RetryIstendi(Exception):
        pass

    def _retry(countdown=None):
        raise _RetryIstendi()

    monkeypatch.setattr(tasks.translate_entity, "retry", _retry)

    with pytest.raises(_RetryIstendi):
        tasks.translate_entity.run(
            tip_ad="duyuru",
            entity_id=str(_uuid.uuid4()),
            tenant_id=str(_uuid.uuid4()),
        )


def test_task_denemeler_TUKENINCE_sessizce_biter(monkeypatch):
    """Icerik GERCEKTEN silinmisse (cevirisi de CASCADE ile gitti) is biter."""
    import uuid as _uuid

    import app.ceviri_service as svc
    from app import tasks

    monkeypatch.setattr(
        svc, "entity_cevir",
        lambda *a, **kw: {"cevrilen": [], "hata": [], "korunan": 0,
                          "atlanan": 0, "not": "icerik yok"},
    )
    # Denemeler tukendi: retries == max_retries -> retry YOK, sonuc doner.
    tasks.translate_entity.push_request(retries=tasks.translate_entity.max_retries)
    try:
        ozet = tasks.translate_entity.run(
            tip_ad="duyuru",
            entity_id=str(_uuid.uuid4()),
            tenant_id=str(_uuid.uuid4()),
        )
    finally:
        tasks.translate_entity.pop_request()
    assert ozet["not"] == "icerik yok"
