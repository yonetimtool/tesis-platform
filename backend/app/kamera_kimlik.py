"""(P213 §6b) Kamera adresindeki KIMLIK BILGISINI adresten ayirir.

===========================================================================
OLCULEN KUSUR
===========================================================================
`camera.stream_url` bugune kadar `rtsp://kullanici:parola@10.0.0.5:554/s`
biciminde, **duz metin** saklaniyordu. Uc sonucu vardi:

  1. DB dokumu tek basina kamera parolasini aciyordu (yedek dosyasi,
     hata ayiklama dokumu, destek icin alinan kopya...).
  2. `GET /cameras` yaniti adresi **oldugu gibi donduruyordu** — yani
     parola, yetkili her istemciye (tarayici belleği, ag gunlugu,
     tarayici gecmisi) gidiyordu.
  3. Gunluklerde adres yazildiginda parola da yaziliyordu.

Gecmis kayit ozelligi NVR'in **yonetim** hesabini gerektirdigi icin bu
sorun buyuyecekti; once bu duzeltildi.

===========================================================================
KARAR
===========================================================================
Kimlik adresten AYRILIR: `stream_kullanici` (duz) + `stream_parola_sifreli`
(AES-GCM, `app/crypto.py` — entegrasyon sirlariyla ayni KEK deseni).
`stream_url` artik **kimliksiz** saklanir ve **kimliksiz** doner.

Parola YALNIZCA sunucunun kendi kullandigi anda geri takilir
(`kimligi_uygula`): ffmpeg cagrisi ve MediaMTX yol tanimi. Istemci hicbir
zaman gormez.

NEDEN URL'DE BIRAKIP "sadece yanitta maskele" DEMEDIK: maskeleme, veriyi
hâlâ duz saklamanin uzerine bir katman koymaktir; yedek/dokum/gunluk
yollari acik kalirdi. Ayrica maskeyi bir yerde unutmak sessiz bir
sizintidir — ayirmak, unutulunca **calismayan** (yani fark edilen) bir
tasarimdir.
"""
from __future__ import annotations

from urllib.parse import quote, unquote, urlsplit, urlunsplit

from .crypto import decrypt_secret, encrypt_secret


def kimligi_ayir(url: str) -> tuple[str, str | None, str | None]:
    """`url` -> (kimliksiz_url, kullanici, parola).

    Kimlik yoksa url AYNEN doner ve ikisi de None olur — cagiran tarafta
    "kimlik var mi" sorusunu bu ayrim cevaplar.
    """
    try:
        p = urlsplit(url)
    except ValueError:
        return url, None, None
    if not p.hostname or (p.username is None and p.password is None):
        return url, None, None
    konak = p.hostname
    if ":" in konak:  # IPv6 -> koseli parantez korunur
        konak = f"[{konak}]"
    if p.port:
        konak = f"{konak}:{p.port}"
    temiz = urlunsplit((p.scheme, konak, p.path, p.query, p.fragment))
    return (
        temiz,
        unquote(p.username) if p.username else None,
        unquote(p.password) if p.password else None,
    )


def kimligi_uygula(url: str, kullanici: str | None, parola: str | None) -> str:
    """Kimliksiz `url`e kimligi geri takar (SUNUCU ICI kullanim).

    Adreste ZATEN kimlik varsa dokunulmaz: eski kayitlar goc edilene dek
    ikisi bir arada yasayabilir ve adrestekini ezmek, calisan bir kamerayi
    bozmak olurdu.
    """
    if not kullanici and not parola:
        return url
    try:
        p = urlsplit(url)
    except ValueError:
        return url
    if p.username is not None or p.password is not None:
        return url
    if not p.hostname:
        return url
    konak = p.hostname
    if ":" in konak:
        konak = f"[{konak}]"
    if p.port:
        konak = f"{konak}:{p.port}"
    # Kimlikteki `@ : /` gibi karakterler adresi bozmasin diye KACISLI.
    kimlik = quote(kullanici or "", safe="")
    if parola:
        kimlik = f"{kimlik}:{quote(parola, safe='')}"
    return urlunsplit((p.scheme, f"{kimlik}@{konak}", p.path, p.query, p.fragment))


def parola_sakla(duz: str | None) -> str | None:
    """Duz parola -> sifreli blob (bos/None ise None)."""
    return encrypt_secret(duz) if duz else None


def parola_coz(blob: str | None) -> str | None:
    """Sifreli blob -> duz parola. Cozulemezse None.

    SESSIZ DUSUS BILINCLI: KEK degistiginde ya da bozuk bir blob'da
    istisna atmak, kamera listesini TAMAMEN cizilemez yapardi. Kimliksiz
    denemek en azindan acik kameralarda calisir; kapali olanda ffmpeg'in
    kendi "401 Unauthorized" teshisi gorunur (P191 teshis zinciri).
    """
    if not blob:
        return None
    try:
        return decrypt_secret(blob)
    except Exception:  # noqa: BLE001 — gerekce yukarida
        return None
