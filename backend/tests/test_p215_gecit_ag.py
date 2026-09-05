"""(P215) CANLI YAYIN GECIDI — AG ve PORT YAPILANDIRMASI.

===========================================================================
OLCULEN KUSUR (prod'da, dagitimdan SONRA)
===========================================================================
    mediamtx -> yonetio-prod_default
    api      -> yonetio-prod_tesisnet
Iki ag arasinda DNS yok; `api` konteynerinde `mediamtx` adi cozulmedi
(socket.gaierror "Name or service not known") ve HER canli yayin istegi
502 dondu.

Kok neden: `docker-compose.prod.yml`de 14 servisin 13'u `networks:
[tesisnet]` tasiyor, mediamtx'te bu satir UNUTULMUS — Docker onu
varsayilan aga koydu.

===========================================================================
BU KUSUR NEDEN TESTLERDE GORUNMEDI (ve bu dosya onu nasil kapatiyor)
===========================================================================
P213 §2'de bulunan kusur GERCEKTI (MediaMTX API 401) ve DEV'de olculup
cozuldu. Ama olculen sey ZINCIRIN KENDISIYDI, ZINCIRIN PRODDAKI
TOPOLOJISI DEGIL:

  * `docker-compose.yml` (dev) HICBIR servise ag yazmaz — hepsi ayni
    varsayilan aga duser ve isim cozumu her zaman calisir. Yani bu
    kusurun dev'de ORTAYA CIKMASI MUMKUN DEGILDI.
  * Hicbir test `docker-compose.prod.yml` dosyasini OKUMUYORDU. Prod
    topolojisi, dagitimdan once hicbir yerde dogrulanmiyordu.
  * Testler `api` konteynerinin ICINDEN kosuyor ve orada mediamtx
    erisilebilir; "gecit calisiyor" sonucu DEV topolojisi icin
    dogruydu, prod icin hicbir sey soylemiyordu.

Bu dosya iki seviyede olcer:
  A. YAPISAL — prod compose dosyasini okur (dagitim oncesi, makineden
     bagimsiz). Yeni bir servis eklenip agi unutulursa duser.
  B. CALISMA ZAMANI — `api` konteynerinden mediamtx API'sine GERCEK
     istek atar. Ag/port/yetki zincirini uctan uca olcer.
"""
from __future__ import annotations

import os
import pathlib
import re

import httpx
import pytest

KOK_ADAYLARI = ("/infra", "infra", "../infra")


def _infra() -> pathlib.Path:
    for k in KOK_ADAYLARI:
        d = pathlib.Path(k)
        if (d / "docker-compose.prod.yml").exists():
            return d
    pytest.skip("infra/ bu kosumda yok (konteyner) — yapisal kilit ATLANDI")


def _servis_bloklari(metin: str) -> dict[str, str]:
    """`services:` altindaki her servisin ham blogu."""
    govde = metin.split("\nservices:", 1)[1].split("\nnetworks:", 1)[0]
    parcalar = re.split(r"\n  (?=[a-z][a-z0-9_-]*:\n)", govde)
    bloklar: dict[str, str] = {}
    for p in parcalar:
        m = re.match(r"\s*([a-z][a-z0-9_-]*):", p)
        if m:
            bloklar[m.group(1)] = p
    return bloklar


# ==================== A. YAPISAL (prod compose) ========================== #

def test_PROD_her_servis_TESISNET_agina_bagli():
    """Kok nedenin birebir kilidi.

    Prod'da ag ACIKCA yazilir; yazilmayan servis SESSIZCE varsayilan aga
    duser ve digerleriyle konusamaz. Hata mesaji da yaniltici olur —
    "servis calismiyor olabilir" der, oysa servis CALISIYOR, sadece
    baska bir agda.
    """
    metin = (_infra() / "docker-compose.prod.yml").read_text(encoding="utf-8")
    bloklar = _servis_bloklari(metin)
    assert len(bloklar) > 10, f"olcum bosa dustu: {len(bloklar)} servis"
    agsiz = [ad for ad, b in bloklar.items() if "networks:" not in b]
    assert agsiz == [], (
        "Prod'da AGI YAZILMAMIS servis(ler): " + ", ".join(agsiz) +
        " — Docker bunlari varsayilan aga koyar ve `tesisnet`teki "
        "servislerle isim cozumu CALISMAZ."
    )


def test_PROD_mediamtx_API_ile_AYNI_agda():
    """Ozel olarak bu ikisi: canli yayin zinciri tam buradan geciyor."""
    metin = (_infra() / "docker-compose.prod.yml").read_text(encoding="utf-8")
    bloklar = _servis_bloklari(metin)
    for ad in ("mediamtx", "api"):
        assert ad in bloklar, f"{ad} servisi prod compose'da YOK"
        assert "tesisnet" in bloklar[ad], f"{ad} `tesisnet` aginda DEGIL"


# ==================== A2. PORT TEK KAYNAK ================================ #

def _mediamtx_portu(infra: pathlib.Path, anahtar: str) -> str:
    m = re.search(rf"^{anahtar}:\s*:(\d+)\s*$",
                  (infra / "mediamtx.yml").read_text(encoding="utf-8"), re.M)
    assert m, f"{anahtar} `mediamtx.yml`de bulunamadi"
    return m.group(1)


def test_API_ADRESI_ile_GECIT_PORTU_ayni():
    """`api`nin aradigi port ile gecidin dinledigi port AYNI olmali.

    Ikisi ayri dosyada yazili; ayrismalari SESSIZDIR — servis ayakta,
    ag dogru, ama baglanti reddedilir ve mesaj yine "gecide
    ulasilamiyor" olur. Sahada tam olarak boyle bir supheye dusuldu
    ("logda :999 goruyorum, api 9997 ariyor").
    """
    infra = _infra()
    api_portu = _mediamtx_portu(infra, "apiAddress")
    hls_portu = _mediamtx_portu(infra, "hlsAddress")
    for dosya in ("docker-compose.prod.yml", "docker-compose.yml"):
        metin = (infra / dosya).read_text(encoding="utf-8")
        # `MEDIAMTX_API_URL` varsayilanindaki port
        m = re.search(r"MEDIAMTX_API_URL:.*?mediamtx:(\d+)", metin)
        if m:
            assert m.group(1) == api_portu, (
                f"{dosya}: api {m.group(1)} ariyor, gecit {api_portu} dinliyor"
            )
        m = re.search(r"MEDIAMTX_URL:.*?mediamtx:(\d+)", metin)
        if m:
            assert m.group(1) == hls_portu, (
                f"{dosya}: HLS {m.group(1)} ariyor, gecit {hls_portu} dinliyor"
            )


def test_MTX_ortam_degiskeni_YINELEMESI_yok():
    """Ayni ayar iki yerde tanimliysa hangisinin gecerli oldugu OKUNARAK
    anlasilamaz (env, mount edilen dosyayi ezer). Tek kaynak
    `mediamtx.yml`; compose'da `MTX_*` yinelemesi kalmamali."""
    infra = _infra()
    for dosya in ("docker-compose.prod.yml", "docker-compose.yml"):
        metin = (infra / dosya).read_text(encoding="utf-8")
        kod = "\n".join(s for s in metin.splitlines()
                        if not s.strip().startswith("#"))
        yineleme = re.findall(r"^\s*(MTX_[A-Z]+):", kod, re.M)
        assert yineleme == [], f"{dosya}: `mediamtx.yml`i ezen {yineleme}"


# ==================== B. CALISMA ZAMANI ================================== #

_API_URL = os.environ.get("MEDIAMTX_API_URL", "")


@pytest.mark.skipif(not _API_URL, reason="MEDIAMTX_API_URL yok — gecit kapali")
def test_API_KONTEYNERINDEN_gecide_ULASILIYOR():
    """UCTAN UCA: ag + port + yetki. Uc ayri sekilde kirilabilir ve UCU
    de ayni belirtiyi (502) uretir; bu test hangisinin kirildigini
    SOYLER.

    * DNS cozulmuyorsa      -> ag yanlis (P215 kok nedeni)
    * baglanti reddediliyor -> port yanlis
    * 401/403               -> `authInternalUsers` (P213 §2 kok nedeni)
    """
    try:
        yanit = httpx.get(f"{_API_URL.rstrip('/')}/v3/config/global/get",
                          timeout=5)
    except httpx.ConnectError as exc:
        metin = str(exc).lower()
        if "name or service not known" in metin or "nodename" in metin:
            pytest.fail(
                f"AG YANLIS: `{_API_URL}` adindaki konak cozulemiyor. "
                "mediamtx ile api AYNI docker aginda mi? (prod: tesisnet)"
            )
        pytest.fail(
            f"PORT/SERVIS: `{_API_URL}` baglanti reddetti ({exc}). "
            "mediamtx.yml `apiAddress` ile bu adresteki port ayni mi?"
        )
    assert yanit.status_code not in (401, 403), (
        "GECIT YETKISI: API izni bu IP'ye verilmemis — infra/mediamtx.yml "
        "`authInternalUsers` (P213 §2'nin kok nedeni buydu)."
    )
    assert yanit.status_code == 200, f"beklenmeyen durum: {yanit.status_code}"
