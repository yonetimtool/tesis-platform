"""(E2E 2026-09) GUVENLIK turu — kamera / NVR kayit kusurlari.

Uctan uca test turunun (bulgular/guvenlik.md) kamera maddeleri:

  GUVENLIK-01  ffmpeg stderr'i kamera parolasini api.log'a DUZ yaziyordu
               (LOG_PII'den bagimsiz) -> gunluk maskesi + handler filtresi.
  GUVENLIK-02  basarisiz kayit arama/oynatma denetim kaydi ROLLBACK ile
               siliniyordu -> ayri kisa transaction.
  GUVENLIK-03  bozuk sablon oynatmada 500; `kayit_saglayici` serbest metin
               -> kayit aninda 422 + Literal.
  GUVENLIK-04  kayit oynatma hatasinda "canli yayin hazir degil" metni
               -> ayri kimlik (`kamera_kayit_oynatilamadi`).
  GUVENLIK-15  duzenlemede baglanti testi KAYITLI parolayi kullanamiyordu
               -> `camera_id` (yalniz ayni konaga) + ayri kimlik alanlari.
  GUVENLIK-16  canli yayin siniri tum tesislerde TEK havuz + `KEYS`
               -> tesis basina ZSET + genel tavan (Lua, atomik).

Ag/gercek NVR gerektirmeyen her sey burada BIRIM duzeyinde olculur (taklit
alt surec / taklit HTTP istemcisi — dikis, olculen katmanin ALTINDA). Uc
davranisi (422/502, denetim satiri) canli sunucuya karsi olculur.
"""
from __future__ import annotations

import asyncio
import logging
import os
import uuid
from types import SimpleNamespace
from typing import get_args

import httpx
import pytest

from app.errors import APIError
from app.gunlukleme import (
    KimlikMaskeleFiltresi,
    maskele_url_kimligi,
    yapilandir,
)
from app.kamera_kayit import SAGLAYICILAR, SablonGecersiz, sablon_dogrula
from app.kamera_kayit.sablon import SablonSaglayici
from app.routers import cameras as kamera_modulu
from app.schemas import KayitSaglayiciAd

PAROLA = "GizliParola77"


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _kamera(client, h, **ek) -> str:
    r = client.post("/cameras", headers=h, json={
        "ad": f"G-{uuid.uuid4().hex[:8]}",
        "stream_url": "rtsp://10.9.0.5:554/s", "tur": "rtsp", **ek})
    assert r.status_code == 201, r.text
    return r.json()["id"]


class _Toplayici(logging.Handler):
    """Bicimlenmis satirlari toplar — handler filtresinin ETKISINI olcer."""

    def __init__(self) -> None:
        super().__init__()
        self.satirlar: list[str] = []
        self.setFormatter(logging.Formatter("%(message)s"))

    def emit(self, record: logging.LogRecord) -> None:
        self.satirlar.append(self.format(record))


# ======================= GUVENLIK-01: GUNLUK MASKESI ======================= #

@pytest.mark.parametrize(
    "ham,sizmamali",
    [
        ("Error opening input file rtsp://kul:GizliParola77@testcam:8554/yok.",
         "GizliParola77"),
        ("'rtsp://admin:p%40ss@10.0.0.4/Streaming'", "p%40ss"),
        ("http://op:NvrGizli!7@nvr.local/ISAPI", "NvrGizli!7"),
        # kullanici adi da maskelenir — kimlik bir CIFT
        ("rtsp://yalnizkullanici@konak/x", "yalnizkullanici"),
    ],
)
def test_URL_kimligi_MASKELENIR(ham, sizmamali):
    maskeli = maskele_url_kimligi(ham)
    assert sizmamali not in maskeli, maskeli
    assert "***@" in maskeli


def test_KIMLIKSIZ_adres_ve_ffmpeg_etiketi_DOKUNULMAZ():
    """`[rtsp @ 0x55]` ffmpeg'in kendi etiketidir, adres degil."""
    ham = "[rtsp @ 0x55d] method DESCRIBE failed: 404 rtsp://konak:554/yol"
    assert maskele_url_kimligi(ham) == ham


def test_FILTRE_mesaji_ARGUMANLARI_ve_TRACEBACKi_maskeler():
    log = logging.getLogger("test.g01.filtre")
    log.propagate = False
    toplayici = _Toplayici()
    toplayici.addFilter(KimlikMaskeleFiltresi())
    log.addHandler(toplayici)
    try:
        log.warning("dogrudan rtsp://a:%s@k/x", PAROLA)
        log.warning("arguman %r", f"rtsp://a:{PAROLA}@k/x")
        try:
            raise RuntimeError(f"baglanamadim rtsp://a:{PAROLA}@k/x")
        except RuntimeError:
            log.exception("istisna")
    finally:
        log.removeHandler(toplayici)
    metin = "\n".join(toplayici.satirlar)
    assert PAROLA not in metin, metin
    assert metin.count("***@") >= 3


def test_LOG_PII_ACIKKEN_de_parola_MASKELI(monkeypatch):
    """Parola kisisel veri degil SIRdir: gelistirme anahtari onu acmaz."""
    monkeypatch.setenv("LOG_PII", "1")
    assert PAROLA not in maskele_url_kimligi(f"rtsp://u:{PAROLA}@h/")


@pytest.fixture
def _kok_handlerlari_geri_ver():
    kok = logging.getLogger()
    onceki = list(kok.handlers)
    onceki_seviye = kok.level
    yield
    kok.handlers[:] = onceki
    kok.setLevel(onceki_seviye)


def test_yapilandir_KOK_HANDLERA_filtre_takar(_kok_handlerlari_geri_ver):
    """Filtre TEK TEK cagri yerlerine birakilmaz: yarin eklenecek bir
    `logger.info("... %s", adres)` satiri da korunmali."""
    yapilandir("INFO")
    for h in logging.getLogger().handlers:
        assert any(isinstance(f, KimlikMaskeleFiltresi) for f in h.filters), h
    yapilandir("INFO")  # ikinci cagri filtreyi IKILEMEZ
    for h in logging.getLogger().handlers:
        assert sum(isinstance(f, KimlikMaskeleFiltresi) for f in h.filters) == 1


@pytest.mark.asyncio
async def test_KARE_CEKIMI_ffmpeg_ciktisini_MASKELI_yazar(monkeypatch):
    """Olculen sizintinin birebir yolu: ffmpeg basarisiz, stderr adresi
    parolasiyla tasiyor, `_kare_cek` onu uyari olarak yaziyor."""

    class _Surec:
        async def communicate(self):
            return b"", (
                f"Error opening input file rtsp://kul:{PAROLA}@testcam:8554/yokyol."
            ).encode()

    async def sahte_exec(*a, **k):
        return _Surec()

    monkeypatch.setattr(asyncio, "create_subprocess_exec", sahte_exec)
    toplayici = _Toplayici()  # FILTRESIZ: cagri yerinin kendi maskesi olculur
    kamera_modulu.logger.addHandler(toplayici)
    try:
        veri, kimlik = await kamera_modulu._kare_cek(
            f"rtsp://kul:{PAROLA}@testcam:8554/yokyol"
        )
    finally:
        kamera_modulu.logger.removeHandler(toplayici)
    assert veri == b""
    assert kimlik  # teshis kaybolmadi
    metin = "\n".join(toplayici.satirlar)
    assert "kare alinamadi" in metin
    assert PAROLA not in metin, metin


# ================== GUVENLIK-03: SABLON + SAGLAYICI KUMESI ================= #

def test_SAGLAYICI_KUMESI_semayla_AYNI():
    """Iki kaynak ayrismasin: adaptor kumesi ile sema Literal'i."""
    assert set(get_args(KayitSaglayiciAd)) == set(SAGLAYICILAR)


@pytest.mark.parametrize(
    "sablon",
    [
        "rtsp://10.0.0.4/p?s={bas}&e={bit}",
        "rtsp://10.0.0.4/c{kanal}?t={bas_tarih}T{bas_saat}&u={bas_unix:d}",
        "rtsp://10.0.0.4/sabit",  # yer tutucusuz sabit adres de gecerli
    ],
)
def test_GECERLI_sablon_kabul(sablon):
    sablon_dogrula(sablon)


@pytest.mark.parametrize(
    "sablon,parca",
    [
        ("rtsp://10.0.0.4/{yokalan}", "{yokalan}"),
        ("rtsp://10.0.0.4/{", "{"),
        ("rtsp://10.0.0.4/{bas.__class__}", "{bas.__class__}"),
        ("rtsp://10.0.0.4/{bas[0]}", "{bas[0]}"),
        ("rtsp://10.0.0.4/{bas:{kanal}}", "{bas"),
        ("rtsp://10.0.0.4/{bas_unix:q}", ""),
    ],
)
def test_BOZUK_sablon_ADLANDIRILARAK_reddedilir(sablon, parca):
    with pytest.raises(SablonGecersiz) as hata:
        sablon_dogrula(sablon)
    assert parca in str(hata.value)


@pytest.mark.asyncio
async def test_ESKI_bozuk_sablon_oynatmada_500_DEGIL_adli_hata():
    """Dogrulama oncesi kaydedilmis sablon: KeyError yerine SablonGecersiz
    (uc bunu 422'ye cevirir)."""
    import datetime as dt

    s = SablonSaglayici("rtsp://h/{yokalan}")
    an = dt.datetime(2026, 9, 5, 14, tzinfo=dt.timezone.utc)
    with pytest.raises(SablonGecersiz):
        await s.oynatma_adresi(an, an + dt.timedelta(hours=1))


def test_GECERSIZ_saglayici_ve_sablon_KAYITTA_422(client, world):
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    kid = _kamera(client, yon)
    try:
        r = client.patch(f"/cameras/{kid}", headers=yon,
                         json={"kayit_saglayici": "foo"})
        assert r.status_code == 422, r.text

        r = client.patch(f"/cameras/{kid}", headers=yon, json={
            "kayit_saglayici": "sablon",
            "kayit_adres": "rtsp://10.9.0.5:554/{yokalan}"})
        assert r.status_code == 422, r.text
        assert "yokalan" in r.json()["error"]["message"]

        # Once gecerli sablon, sonra YALNIZ adresi boz: birlestirilerek olculur.
        r = client.patch(f"/cameras/{kid}", headers=yon, json={
            "kayit_saglayici": "sablon",
            "kayit_adres": "rtsp://10.9.0.5:554/p?s={bas}"})
        assert r.status_code == 200, r.text
        r = client.patch(f"/cameras/{kid}", headers=yon,
                         json={"kayit_adres": "rtsp://10.9.0.5:554/{"})
        assert r.status_code == 422, r.text
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)

    r = client.post("/cameras", headers=yon, json={
        "ad": "bozuk", "stream_url": "rtsp://10.9.0.5:554/s", "tur": "rtsp",
        "kayit_aktif": True, "kayit_saglayici": "sablon",
        "kayit_adres": "rtsp://10.9.0.5/{bas.__class__}"})
    assert r.status_code == 422, r.text


def test_HIKVISION_adresi_SABLON_gibi_dogrulanmaz(client, world):
    """Hikvision/Dahua'da `kayit_adres` HTTP tabanidir; `{` icermesi
    beklenmez ama sablon kurali ona uygulanmamali."""
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    kid = _kamera(client, yon)
    try:
        r = client.patch(f"/cameras/{kid}", headers=yon, json={
            "kayit_saglayici": "hikvision", "kayit_adres": "http://10.9.0.5"})
        assert r.status_code == 200, r.text
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)


# ============ GUVENLIK-02: BASARISIZ DENEME DE DENETIME YAZILIR ============ #

def _denetim_sayisi(owner_conn, kid: str, eylem: str) -> int:
    return owner_conn.execute(
        "SELECT count(*) FROM audit_log WHERE resource_id = %s AND action = %s",
        (kid, eylem),
    ).fetchone()[0]


ARALIK = {"bas": "2026-09-05T14:00:00Z", "bit": "2026-09-05T15:00:00Z"}


def test_BASARISIZ_ARAMALAR_denetimde_KALIR(client, world, owner_conn):
    """Olculen: 4 basarisiz (502) aramadan sonra sayi 1'de kaliyordu."""
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    # 127.0.0.1:1 — baglanti HEMEN reddedilir (zaman asimi beklenmez).
    kid = _kamera(client, yon, kayit_aktif=True, kayit_saglayici="hikvision",
                  kayit_adres="http://127.0.0.1:1")
    try:
        for _ in range(3):
            r = client.get(f"/cameras/{kid}/kayit/araliklar", headers=yon,
                           params=ARALIK)
            assert r.status_code == 502, r.text
        assert _denetim_sayisi(owner_conn, kid, "camera_kayit_arama") == 3
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)


def test_BASARISIZ_OYNATMA_denetimde_KALIR_ve_500_DEGIL(client, world, owner_conn):
    """Bozuk sablon (dogrulama ONCESI kaydedilmis gibi — DB'ye dogrudan
    yazilir): oynatma 422 doner ve deneme yine de iz birakir."""
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    kid = _kamera(client, yon, kayit_aktif=True, kayit_saglayici="sablon",
                  kayit_adres="rtsp://10.9.0.5/p?s={bas}")
    try:
        owner_conn.execute(
            "UPDATE camera SET kayit_adres = %s WHERE id = %s",
            ("rtsp://10.9.0.5/{yokalan}", kid),
        )
        r = client.post(f"/cameras/{kid}/kayit/oynat", headers=yon, json=ARALIK)
        if r.status_code == 503:
            pytest.skip("MediaMTX bu ortamda yapilandirilmamis (kamera_canli_kapali)")
        assert r.status_code == 422, r.text
        assert "yokalan" in r.json()["error"]["message"]
        assert _denetim_sayisi(owner_conn, kid, "camera_kayit_izleme") == 1
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)


# =============== GUVENLIK-04: KAYIT HATASI KENDI METNIYLE ================== #

class _SahteYanit:
    def __init__(self, durum: int) -> None:
        self.status_code = durum
        self.content = b""
        self.headers: dict[str, str] = {}


def _sahte_istemci(durum: int):
    class _Istemci:
        async def __aenter__(self):
            return self

        async def __aexit__(self, *a):
            return False

        async def get(self, *a, **k):
            return _SahteYanit(durum)

    return lambda **k: _Istemci()


@pytest.mark.asyncio
@pytest.mark.parametrize("dosya", ["index.m3u8", "seg1.mp4"])
async def test_KAYIT_404_canli_METNIYLE_ANLATILMAZ(monkeypatch, dosya):
    kid = uuid.uuid4()
    kamera = SimpleNamespace(id=kid, kayit_aktif=True, kayit_saglayici="sablon")

    async def sahte_getir(db, model, _id):
        return kamera

    async def kodek_yok(_yol):
        return None

    monkeypatch.setattr(kamera_modulu, "get_or_404", sahte_getir)
    monkeypatch.setattr(kamera_modulu, "_yol_kodegi", kodek_yok)
    monkeypatch.setattr(kamera_modulu.settings, "mediamtx_url", "http://gecit:8888")
    monkeypatch.setattr(httpx, "AsyncClient", _sahte_istemci(404))

    yol = f"kayit{kid.hex}{'0' * 16}"
    with pytest.raises(APIError) as hata:
        await kamera_modulu.kayit_hls(
            camera_id=kid, yol=yol, dosya=dosya, db=None, user=None
        )
    assert hata.value.mesaj == "kamera_kayit_oynatilamadi", hata.value.mesaj
    assert hata.value.code == "bad_gateway"


@pytest.mark.asyncio
async def test_KAYIT_KODEK_sorunu_AYRI_teshis(monkeypatch):
    kid = uuid.uuid4()
    kamera = SimpleNamespace(id=kid, kayit_aktif=True, kayit_saglayici="sablon")

    async def sahte_getir(db, model, _id):
        return kamera

    async def kodek_h265(_yol):
        return "H265"

    monkeypatch.setattr(kamera_modulu, "get_or_404", sahte_getir)
    monkeypatch.setattr(kamera_modulu, "_yol_kodegi", kodek_h265)
    monkeypatch.setattr(kamera_modulu.settings, "mediamtx_url", "http://gecit:8888")
    monkeypatch.setattr(httpx, "AsyncClient", _sahte_istemci(404))
    with pytest.raises(APIError) as hata:
        await kamera_modulu.kayit_hls(
            camera_id=kid, yol=f"kayit{kid.hex}{'0' * 16}", dosya="seg1.mp4",
            db=None, user=None,
        )
    assert hata.value.mesaj == "kamera_kodek_desteklenmiyor"


@pytest.mark.asyncio
async def test_KAYIT_PLAYLIST_zaman_asimi_KAYIT_metni(monkeypatch):
    async def ayakta() -> bool:
        return True

    class _Zamanasimli:
        async def __aenter__(self):
            return self

        async def __aexit__(self, *a):
            return False

        async def get(self, *a, **k):
            raise httpx.ReadTimeout("zaman asimi")

    monkeypatch.setattr(kamera_modulu, "_gecit_ayakta", ayakta)
    monkeypatch.setattr(httpx, "AsyncClient", lambda **k: _Zamanasimli())
    with pytest.raises(APIError) as hata:
        await kamera_modulu._playlist_bekle(
            "http://gecit/x.m3u8", uuid.uuid4(),
            hazir_degil="kamera_kayit_oynatilamadi",
        )
    assert hata.value.mesaj == "kamera_kayit_oynatilamadi"


# ============ GUVENLIK-15: DUZENLEMEDE KAYITLI KIMLIKLE TEST =============== #

def _sifreli(parola: str) -> str | None:
    from app.kamera_kimlik import parola_sakla

    try:
        return parola_sakla(parola)
    except Exception as exc:  # pragma: no cover — KEK yoksa
        pytest.skip(f"parola sifrelenemiyor (SDM_KEK?): {exc}")


@pytest.fixture
def kayitli_kamera(monkeypatch):
    kamera = SimpleNamespace(
        id=uuid.uuid4(),
        stream_url="rtsp://10.0.0.4:554/Streaming/101",
        alt_stream_url="rtsp://10.0.0.4:554/Streaming/102",
        stream_kullanici="admin",
        stream_parola_sifreli=_sifreli(PAROLA),
    )

    async def sahte_getir(db, model, _id):
        return kamera

    monkeypatch.setattr(kamera_modulu, "get_or_404", sahte_getir)
    return kamera


def _istek(**k):
    from app.schemas import KameraTestIstek

    return KameraTestIstek(**{"tur": "rtsp", **k})


@pytest.mark.asyncio
async def test_AYNI_KONAKTA_kayitli_kimlik_TAKILIR(kayitli_kamera):
    adres = await kamera_modulu._test_adresi(
        _istek(stream_url="rtsp://10.0.0.4:554/Streaming/101",
               camera_id=kayitli_kamera.id), None)
    assert adres == f"rtsp://admin:{PAROLA}@10.0.0.4:554/Streaming/101"
    # Alt akis konagi da ayni cihaz sayilir.
    adres = await kamera_modulu._test_adresi(
        _istek(stream_url="rtsp://10.0.0.4:554/baska/yol",
               camera_id=kayitli_kamera.id), None)
    assert PAROLA in adres


@pytest.mark.asyncio
@pytest.mark.parametrize("baska", [
    "rtsp://saldirgan.example:554/x",   # farkli konak
    "rtsp://10.0.0.4:8554/x",           # farkli port
])
async def test_BASKA_KONAGA_kayitli_parola_GITMEZ(kayitli_kamera, baska):
    """Parola yazilir-okunmaz; adresi degistirip testi baska bir sunucuya
    yonelterek parolayi disari almak mumkun olmamali."""
    adres = await kamera_modulu._test_adresi(
        _istek(stream_url=baska, camera_id=kayitli_kamera.id), None)
    assert adres == baska
    assert PAROLA not in adres


@pytest.mark.asyncio
async def test_ONCELIK_adres_sonra_ayri_alan_sonra_kayit(kayitli_kamera):
    adres = await kamera_modulu._test_adresi(
        _istek(stream_url="rtsp://yeni:Yeni1@10.0.0.4:554/s",
               camera_id=kayitli_kamera.id), None)
    assert adres == "rtsp://yeni:Yeni1@10.0.0.4:554/s"
    adres = await kamera_modulu._test_adresi(
        _istek(stream_url="rtsp://10.0.0.4:554/s", stream_kullanici="op",
               stream_parola="Ayri2", camera_id=kayitli_kamera.id), None)
    assert adres == "rtsp://op:Ayri2@10.0.0.4:554/s"


def test_TEST_ucu_BASKA_TESISIN_kamerasini_GORMEZ(client, world):
    """`camera_id` RLS altinda cozulur: B tesisinin kamerasi A'da 404."""
    hb = _h(client, world["slug_b"], world["admin_b"])
    r = client.post("/cameras", headers=hb, json={
        "ad": "B-kam", "stream_url": "rtsp://10.9.0.7:554/s", "tur": "rtsp"})
    assert r.status_code == 201, r.text
    kid_b = r.json()["id"]
    try:
        ya = _h(client, world["slug_a"], world["yonetici_a"])
        r = client.post("/cameras/test-baglanti", headers=ya, json={
            "stream_url": "rtsp://10.9.0.7:554/s", "tur": "rtsp",
            "camera_id": kid_b})
        assert r.status_code == 404, r.text
    finally:
        client.delete(f"/cameras/{kid_b}", headers=hb)


# ============== GUVENLIK-16: TESIS BASINA CANLI SINIRI ===================== #

@pytest.mark.asyncio
async def test_CANLI_SINIR_TESIS_BASINA_ve_GENEL_TAVAN():
    import redis.asyncio as aioredis

    url = os.getenv("REDIS_URL", "redis://redis:6379/0")
    r = aioredis.from_url(url, socket_connect_timeout=3)
    try:
        await r.ping()
    except Exception as exc:  # pragma: no cover
        pytest.skip(f"Redis erisilemiyor: {exc}")
    onek = f"test:g16:{uuid.uuid4().hex}"
    a, b, c = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    ayir = kamera_modulu.canli_yer_ayir
    try:
        # A tesisi kendi sinirina (2) takilir...
        assert await ayir(r, a, "k1", tesis_sinir=2, genel_sinir=5, anahtar_oneki=onek)
        assert await ayir(r, a, "k2", tesis_sinir=2, genel_sinir=5, anahtar_oneki=onek)
        assert not await ayir(r, a, "k3", tesis_sinir=2, genel_sinir=5, anahtar_oneki=onek)
        # ...zaten izlenen kamera sinira TAKILMAZ (ayni muxer)...
        assert await ayir(r, a, "k1", tesis_sinir=2, genel_sinir=5, anahtar_oneki=onek)
        # ...ve B tesisi bundan ETKILENMEZ (eski kusur: tek havuz).
        assert await ayir(r, b, "k1", tesis_sinir=2, genel_sinir=5, anahtar_oneki=onek)
        assert await ayir(r, b, "k2", tesis_sinir=2, genel_sinir=5, anahtar_oneki=onek)
        # Genel tavan (5) doldu: C tesisi 1. kamerasini alir, 2.yi alamaz.
        assert await ayir(r, c, "k1", tesis_sinir=2, genel_sinir=5, anahtar_oneki=onek)
        assert not await ayir(r, c, "k2", tesis_sinir=2, genel_sinir=5, anahtar_oneki=onek)
        # Suresi dolan uye atilir (TTL'in yerini tutan temizlik).
        await r.zadd(f"{onek}:tesis:{a}", {"k1": 1, "k2": 1})
        assert await ayir(r, a, "k3", tesis_sinir=2, genel_sinir=0, anahtar_oneki=onek)
    finally:
        await r.delete(f"{onek}:tesis:{a}", f"{onek}:tesis:{b}",
                       f"{onek}:tesis:{c}", f"{onek}:genel")
        await r.aclose()


def test_CANLI_UCU_KEYS_KULLANMAZ():
    """`KEYS` Redis'i tarama boyunca kilitler (O(N)); uretimde her
    playlist isteginde calisiyordu."""
    import inspect

    kaynak = inspect.getsource(kamera_modulu.kamera_canli)
    assert ".keys(" not in kaynak
    assert "canli_yer_ayir" in kaynak
