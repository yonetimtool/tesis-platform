"""(P155r2) COMPOSE, `settings`teki her OAUTH degiskenini GECIRIYOR MU?

===========================================================================
OLCULEN KUSUR
===========================================================================
OAuth konsollarda yapilandirildi, `.env.prod`a yazildi ve
`/auth/oauth/saglayicilar` yine BOS LISTE dondu.

Sebep: compose'da `env_file` YOK; `environment:` bloklari ACIK BEYAZ
LISTEDIR. Adi orada gecmeyen bir degisken konteynere ULASMAZ. `.env`e
yazmak tek basina hicbir sey yapmiyordu.

===========================================================================
NEDEN TUM TEST TAKIMI YESILKEN BU KACTI
===========================================================================
`tests/test_oauth.py` saglayicilari `monkeypatch.setattr(settings, ...)`
ile kuruyor — yani KONTEYNER ORTAMINA HIC BAKMIYOR. Dogru karar (agsiz,
hizli, gercek dogrulama kod yolunu suruyor) ama bir kor nokta birakiyor:
"uygulama dogru calisiyor" ile "uygulamaya deger ULASIYOR" ayri sorular.
Bu dosya IKINCISINI olcer.

===========================================================================
NEDEN YAML OKUNUYOR, `docker compose config` KOSULMUYOR
===========================================================================
`docker compose config` degiskenleri COZER ve testin Docker'a bagimli
olmasini gerektirir; CI'da ve bu konteynerin icinde Docker yoktur. Ham
YAML'i okumak yeterli: aranan sey DEGERLER degil, ANAHTARIN ORADA
OLMASI. Kusur zaten "anahtar hic yazilmamis" kusuruydu.

===========================================================================
!! TEK-DOSYA BIND MOUNT TUZAGI — OLCULDU
===========================================================================
Compose dosyalari konteynere TEK DOSYA olarak baglaniyor. `sed -i`,
`mv` ve cogu editorun "kaydet"i dosyayi YERINDE DEGISTIRMEZ; yeni bir
inode yazip eskisinin uzerine tasir. Bind mount ESKI INODE'a bagli
kaldigi icin konteyner DEGISIKLIGI GORMEZ ve bu test ESKI icerikle
YESIL doner.

Yani: compose'u duzenledikten sonra
    docker compose up -d --force-recreate api
kosulmadan bu testin yesili BIR SEY KANITLAMAZ.

Bu, depoda ZATEN gecerli olan kuralla ayni sinifta: imajlar kodu BAKE
ediyor, dolayisiyla `backend/` duzenlendikten sonra da `build` +
`up -d` gerekiyor. Yeni bir disiplin degil, var olanin ayni tuzagi.
"""
from __future__ import annotations

import pathlib
import re

import pytest
import yaml

#: IKI ARAMA YOLU — `main.py::_goc_head` ile ayni desen:
#:   * `/infra/...`      → konteynerde (dev compose iki dosyayi SALT
#:                          OKUNUR baglar; klasorun tamami DEGIL, cunku
#:                          orada `.env` ve `secrets/` var),
#:   * `<depo>/infra/...` → gelistirici makinesinde / CI'da.
#: Ikisi de yoksa test ATLANIR; ama normal kosumda BULUNUR ve gercekten
#: olcer. Hep atlayan bir test hicbir sey korumaz.
_ADAYLAR = (
    pathlib.Path("/infra"),
    pathlib.Path(__file__).resolve().parents[2] / "infra",
)


def _compose_dizini() -> pathlib.Path | None:
    for d in _ADAYLAR:
        if (d / "docker-compose.yml").is_file():
            return d
    return None


_DIZIN = _compose_dizini()

COMPOSE_ADLARI = ("docker-compose.yml", "docker-compose.prod.yml")
COMPOSE_DOSYALARI = tuple(
    (_DIZIN / ad) if _DIZIN else pathlib.Path(ad) for ad in COMPOSE_ADLARI
)

#: OAuth'un ZAMANLAMA/omur ayarlari: kodda makul varsayilanlari var ve
#: konsol kurulumunun parcasi DEGILLER. Compose'a tasimamak bilincli —
#: her ayari gecirmek, gercekten gerekenleri gurultuye gomerdi.
GECIRILMESI_GEREKMEYEN = {
    "oauth_state_ttl_seconds",
    "oauth_baglama_ttl_seconds",
}


def _oauth_ayarlari() -> set[str]:
    """`config.Settings`teki `oauth_*` alanlarinin ORTAM DEGISKENI adlari.

    Kaynak KODDUR, elle tutulan bir liste degil: yeni bir `oauth_*`
    ayari eklendiginde bu test onu KENDILIGINDEN arar ve compose'a
    eklenmediyse kirmiziya doner. Elle liste tutmak, kusuru bir kez daha
    yasamak demekti.
    """
    from app.config import Settings

    return {
        ad.upper()
        for ad in Settings.model_fields
        if ad.startswith("oauth_") and ad not in GECIRILMESI_GEREKMEYEN
    }


def _api_ortami(dosya: pathlib.Path) -> dict[str, str]:
    veri = yaml.safe_load(dosya.read_text(encoding="utf-8"))
    return dict(veri["services"]["api"]["environment"])


@pytest.mark.parametrize("dosya", COMPOSE_DOSYALARI, ids=lambda p: p.name)
def test_compose_TUM_oauth_degiskenlerini_gecirir(dosya: pathlib.Path):
    """Her `oauth_*` ayari `api` servisinin `environment` blogunda OLMALI."""
    if not dosya.exists():
        pytest.skip(f"{dosya} yok (konteyner icinde `infra/` bagli degil)")

    ortam = _api_ortami(dosya)
    eksik = sorted(_oauth_ayarlari() - set(ortam))
    assert not eksik, (
        f"{dosya.name}: `api` servisine GECIRILMEYEN OAuth degiskenleri: "
        f"{eksik}\n"
        "compose'da `env_file` YOK — `environment` blogunda adi gecmeyen "
        "degisken konteynere ULASMAZ. `.env`e yazmak YETMEZ ve hata "
        "SESSIZDIR: `/auth/oauth/saglayicilar` bos liste doner."
    )


@pytest.mark.parametrize("dosya", COMPOSE_DOSYALARI, ids=lambda p: p.name)
def test_oauth_degiskenleri_OPSIYONEL(dosya: pathlib.Path):
    """Hicbiri `:?` (zorunlu) OLMAMALI.

    Sosyal giris bir EK yoldur: yapilandirmayan bir kurulum ACILABILMELI.
    `:?` koymak, OAuth'suz her ortamda compose'u kirardi.
    """
    if not dosya.exists():
        pytest.skip(f"{dosya} yok")

    ortam = _api_ortami(dosya)
    zorunlu = sorted(
        ad
        for ad in _oauth_ayarlari()
        if isinstance(ortam.get(ad), str) and ":?" in ortam[ad]
    )
    assert not zorunlu, (
        f"{dosya.name}: zorunlu (`:?`) isaretlenmis OAuth degiskenleri: "
        f"{zorunlu} — sosyal girisi yapilandirmayan kurulum ACILAMAZ."
    )


@pytest.mark.parametrize("dosya", COMPOSE_DOSYALARI, ids=lambda p: p.name)
def test_oauth_degiskenleri_AYNI_ADLI_env_anahtarindan_okur(dosya: pathlib.Path):
    """`OAUTH_X: ${OAUTH_X:-...}` — ad esitligi.

    Yanlis anahtardan okumak (`OAUTH_GOOGLE_AUD: ${GOOGLE_AUD:-}`) tam
    olarak duzeltilen kusurla AYNI sinifta bir sessiz kusurdur: `.env`e
    dogru adi yazan kisi hicbir sey olmadigini gorur.
    """
    if not dosya.exists():
        pytest.skip(f"{dosya} yok")

    ortam = _api_ortami(dosya)
    hatali: list[str] = []
    for ad in sorted(_oauth_ayarlari()):
        deger = ortam.get(ad)
        if not isinstance(deger, str):
            continue
        m = re.match(r"^\$\{([A-Z0-9_]+)(:-.*)?\}$", deger, re.S)
        if m is None or m.group(1) != ad:
            hatali.append(f"{ad} -> {deger!r}")
    assert not hatali, f"{dosya.name}: ad uyusmazligi: {hatali}"


def test_iki_compose_dosyasi_AYNI_oauth_kumesini_tasir():
    """Dev ve prod AYRISMAMALI.

    Ayrisirlarsa dev'de calisan bir yapilandirma prod'da SESSIZCE
    calismaz — ve bu, kusurun ilk kez fark edildigi durumun ta kendisi.
    """
    varolan = [d for d in COMPOSE_DOSYALARI if d.exists()]
    if len(varolan) < 2:
        pytest.skip("iki compose dosyasi da gerekli")

    kumeler = {d.name: {a for a in _api_ortami(d) if a.startswith("OAUTH_")}
               for d in varolan}
    adlar = list(kumeler)
    fark = kumeler[adlar[0]] ^ kumeler[adlar[1]]
    assert not fark, f"dev/prod OAuth kumeleri ayrismis; fark: {sorted(fark)}"
