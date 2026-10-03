"""Telefon numarasini MASKELER — tek yer (P253 acil, davet 500).

Uc kopya vardi (`davet`, `auth`, `oauth`); davettekine VERITABANINDAKI
telefon geciyordu ve telefonsuz davetlide `len(None)` -> 500 aliyordu:
kisi kaydini tamamlayamiyor, parola atanmiyor, "beni tanimiyor" saniyordu.

BOS / None -> "" (bos dize, None DEGIL): yayindaki eski mobil surumler
alani zorunlu `String` olarak okuyor; None onlari cokertirdi. Istemci bos
degeri gorunce satiri hic cizmez.
"""
from __future__ import annotations


def telefon_maskele(telefon: str | None) -> str:
    t = (telefon or "").strip()
    if not t:
        return ""
    if len(t) <= 6:
        return "*" * len(t)
    return f"{t[:5]}***{t[-3:]}"
