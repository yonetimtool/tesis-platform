"""(P250 §4) YouTube baglantisindan VIDEO KIMLIGI ayiklama.

Kabul edilen bicimler (kullanicinin listesi + ayni anlama gelen yaygin
varyantlar):
  * https://www.youtube.com/watch?v=KIMLIK  (m., music. alt alan adlari, ek
    sorgu parametreleri: &t=30s, &list=...)
  * https://youtu.be/KIMLIK                 (?si=... izleyici parametresiyle)
  * https://www.youtube.com/shorts/KIMLIK
  * https://www.youtube.com/embed/KIMLIK, youtube-nocookie.com/embed/KIMLIK
  * yalniz KIMLIK (11 karakter)

YALNIZ KIMLIK SAKLANIR: baglanti izleyici parametreleri (`si`, `feature`)
tasir ve oynatma yerlesik oynaticidan (`youtube-nocookie.com`) yapilir;
tam URL'yi saklamak hem gereksiz hem gizlilik acisindan kotu olurdu.
"""
from __future__ import annotations

import re
from urllib.parse import parse_qs, urlparse

_KIMLIK = re.compile(r"^[A-Za-z0-9_-]{11}$")
_YOUTUBE_ALANLARI = {
    "youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com",
    "youtube-nocookie.com", "www.youtube-nocookie.com",
}


def youtube_kimligi(baglanti: str) -> str | None:
    """Gecerli bir YouTube video kimligi ya da None."""
    ham = (baglanti or "").strip()
    if _KIMLIK.match(ham):
        return ham
    if "://" not in ham:
        ham = "https://" + ham
    try:
        u = urlparse(ham)
    except ValueError:
        return None
    alan = (u.hostname or "").lower()
    yol = [p for p in u.path.split("/") if p]
    aday: str | None = None
    if alan == "youtu.be":
        aday = yol[0] if yol else None
    elif alan in _YOUTUBE_ALANLARI:
        if u.path == "/watch":
            aday = (parse_qs(u.query).get("v") or [None])[0]
        elif len(yol) >= 2 and yol[0] in ("shorts", "embed", "live", "v"):
            aday = yol[1]
    if aday and _KIMLIK.match(aday):
        return aday
    return None
