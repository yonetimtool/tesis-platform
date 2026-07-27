"""Ceviri saglayici soyutlamasi — LibreTranslate varsayilan.

Sozlesme: `translate(text, source_lang, target_langs) -> dict[dil, metin]`.
Donen sozlukte BULUNMAYAN dil "o dil cevrilemedi" demektir (kismi basari
mesrudur); TAMAMEN basarisiz cagri [TranslationError] atar. Cagiran (worker)
eksik dilleri `durum='hata'` olarak isaretler — icerik kaydi ETKILENMEZ.

AG NOTU (SSRF): hedef URL OPERATOR yapilandirmasidir (env), kullanici girdisi
DEGIL; bu yuzden `safe_http` KULLANILMAZ — o kapi kullanici-URL'li istekler
icindir ve ic aga (http://libretranslate:5000) cikmayi bilincli olarak
engeller. Burada ic ag hedefi TAM OLARAK istenen davranistir.
"""
from __future__ import annotations

import logging
from abc import ABC, abstractmethod

import httpx

from .config import settings

logger = logging.getLogger("translate")

# Saglayici cagrisinda tek metin icin ust sinir — cok uzun govde ceviri
# saglayicisini kilitlemesin (LibreTranslate'te istek basina makul sinir).
MAX_METIN = 20_000


class TranslationError(Exception):
    """Saglayici cagrisi TAMAMEN basarisiz (ag/HTTP/bicim hatasi)."""


class TranslationProvider(ABC):
    """Ceviri saglayicisi arayuzu."""

    #: Yapilandirma eksikse False — cagiran ceviriyi hic denemez.
    hazir: bool = True

    @abstractmethod
    def translate(
        self, text: str, source_lang: str, target_langs: list[str]
    ) -> dict[str, str]:
        """`text`i her hedef dile cevirir; dil -> cevrilmis metin dondurur.

        Cevrilemeyen dil sonuca EKLENMEZ (kismi basari). Hicbiri olmazsa
        [TranslationError].
        """


class NoopProvider(TranslationProvider):
    """Ceviri KAPALI — hicbir dil dondurmez (durum 'hata' olur, icerik durur)."""

    hazir = False

    def translate(
        self, text: str, source_lang: str, target_langs: list[str]
    ) -> dict[str, str]:
        return {}


class EchoProvider(TranslationProvider):
    """DETERMINISTIK sahte saglayici — dev/test icin (model indirmesi yok).

    Ciktisi `[<dil>] <metin>`: gercek ceviri degil ama akisin (kuyruk, durum,
    Accept-Language eslesmesi) ucu uca dogrulanmasini saglar ve testleri
    saglayici kalitesinden BAGIMSIZ kilar.
    """

    def translate(
        self, text: str, source_lang: str, target_langs: list[str]
    ) -> dict[str, str]:
        return {dil: f"[{dil}] {text}" for dil in target_langs}


class LibreTranslateProvider(TranslationProvider):
    """LibreTranslate (kendi kendine barindirilan) — VARSAYILAN saglayici.

    LibreTranslate istek basina TEK hedef dil cevirir; hedefler sirayla
    denenir ve BIRININ hatasi digerlerini dusurmez (kismi basari).
    """

    def __init__(
        self,
        base_url: str | None = None,
        api_key: str | None = None,
        timeout: float | None = None,
    ) -> None:
        # None = "ayardan al"; "" = ACIKCA bos (yapilandirilmamis) — `or`
        # kullanilsa acik bos deger sessizce ayara duserdi.
        ham = settings.translate_url if base_url is None else base_url
        self._base = (ham or "").rstrip("/")
        self._api_key = api_key if api_key is not None else settings.translate_api_key
        self._timeout = timeout or settings.translate_timeout_seconds

    @property
    def hazir(self) -> bool:  # type: ignore[override]
        return bool(self._base)

    def translate(
        self, text: str, source_lang: str, target_langs: list[str]
    ) -> dict[str, str]:
        if not self.hazir:
            raise TranslationError("TRANSLATE_URL tanimsiz")
        if not text.strip():
            # Bos metin: ceviri gerekmez, hedeflerin hepsi bos metinle "cevrildi".
            return {dil: text for dil in target_langs}
        if len(text) > MAX_METIN:
            raise TranslationError(f"metin cok uzun ({len(text)} > {MAX_METIN})")

        sonuc: dict[str, str] = {}
        hatalar: list[str] = []
        with httpx.Client(timeout=self._timeout) as client:
            for dil in target_langs:
                try:
                    sonuc[dil] = self._tek(client, text, source_lang, dil)
                except Exception as exc:  # tek dilin hatasi digerlerini dusurmez
                    hatalar.append(f"{dil}: {exc}")
                    logger.warning("ceviri basarisiz (%s->%s): %s", source_lang, dil, exc)

        if not sonuc and hatalar:
            raise TranslationError("; ".join(hatalar[:3]))
        return sonuc

    def _tek(
        self, client: httpx.Client, text: str, source: str, target: str
    ) -> str:
        govde: dict[str, str] = {
            "q": text,
            "source": source,
            "target": target,
            "format": "text",
        }
        if self._api_key:
            govde["api_key"] = self._api_key
        yanit = client.post(f"{self._base}/translate", json=govde)
        yanit.raise_for_status()
        veri = yanit.json()
        cevrilmis = veri.get("translatedText")
        if not isinstance(cevrilmis, str):
            raise TranslationError(f"beklenmeyen yanit bicimi: {veri!r}")
        return cevrilmis


# --------------------------------------------------------------------------- #
# Fabrika
# --------------------------------------------------------------------------- #
_SAGLAYICILAR: dict[str, type[TranslationProvider]] = {
    "libretranslate": LibreTranslateProvider,
    "echo": EchoProvider,
    "noop": NoopProvider,
}

_onbellek: TranslationProvider | None = None


def get_translation_provider() -> TranslationProvider:
    """Yapilandirilmis saglayici (surec basina onbelleklenir).

    Bilinmeyen TRANSLATE_PROVIDER degeri cokme URETMEZ: noop'a duser + log —
    yanlis yapilandirma icerik yazmayi engellememeli.
    """
    global _onbellek
    if _onbellek is None:
        ad = (settings.translate_provider or "noop").strip().lower()
        sinif = _SAGLAYICILAR.get(ad)
        if sinif is None:
            logger.error("bilinmeyen TRANSLATE_PROVIDER=%r -> noop", ad)
            sinif = NoopProvider
        _onbellek = sinif()
    return _onbellek


def reset_translation_provider() -> None:
    """Onbellegi temizle (testler ayarlari degistirdiginde)."""
    global _onbellek
    _onbellek = None
