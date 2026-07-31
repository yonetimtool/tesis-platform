"""Havale aciklama KODU (P30) — uretim + metinden ayiklama.

Sakin banka havalesinde aciklamaya bu kodu yazar; yonetim ekstreyi
yukleyince (P29) kod ESLESTIRMEYI KESINLESTIRIR — ad benzerligi ve tutar
tahminine gerek kalmaz.
"""
from __future__ import annotations

import re
import secrets

#: KARISTIRILABILIR HARFLER CIKARILDI: kullanici kodu ELLE yazacak ve
#: telefonda `0/O`, `1/I/l` ayrimi okunmaz. Kalan alfabe 32 karakter,
#: 6 hanede ~1,07 milyar kombinasyon — bir site icin fazlasiyla yeter.
ALFABE = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
ONEK = "TS-"
UZUNLUK = 6

#: Metin icinde kodu bulan desen. Aciklamada baska metin de olur
#: ("AIDAT TS-A7K2M9 TESEKKURLER") — bu yuzden ARAMA yapilir, esitlik degil.
DESEN = re.compile(r"\bTS-([A-Z2-9]{6})\b")


def uret() -> str:
    """Yeni kod uret. Cakisma olasiligi dusuk ama SIFIR DEGIL — cagiran
    benzersizlik kisitina guvenip yeniden denemelidir."""
    return ONEK + "".join(secrets.choice(ALFABE) for _ in range(UZUNLUK))


def ayikla(metin: str) -> str | None:
    """Serbest metinden kodu cikar (yoksa None).

    BUYUK HARFE cevirir: banka ekstreleri bazen kucuk harf dondurur ve
    kullanici da kucuk yazabilir. Kod alfabesi zaten buyuk harftir.
    """
    if not metin:
        return None
    m = DESEN.search(metin.upper())
    return ONEK + m.group(1) if m else None
