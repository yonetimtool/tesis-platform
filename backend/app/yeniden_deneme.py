"""ORTAK YENIDEN-DENEME POLITIKASI — katlanan geri cekilme.

===========================================================================
NEDEN AYRI MODUL (P154 / Asama 9)
===========================================================================
Bu mantik P37'de caydirici webhook kuyrugu icin yazilmisti (`gurultu.py`)
ve Asama 9'un mesaj kuyrugu TAM OLARAK ayni seye ihtiyac duyuyor:
"kacinci deneme, ne zaman tekrar, ne zaman vazgec".

Kopyalamak iki politika uretirdi: biri duzeltilir, oteki unutulurdu — ve
"neden SMS 3 kez, webhook 5 kez deneniyor" sorusunun cevabi hicbir yerde
yazili olmazdi. Brief'in kurali acikti: AYNI ISI IKI KEZ YAPMA.

MAX DENEME CAGRIYA BIRAKILDI, sabitlenmedi: webhook bir DIS SISTEME,
SMS bir SAGLAYICIYA gider ve ikisinin kalici-ariza olasiligi ayni degil.
Ortak olan sey ZAMANLAMA egrisidir, sayi degil.
"""
from __future__ import annotations

from datetime import datetime, timedelta


def gecikme(deneme: int) -> timedelta:
    """Katlanan geri cekilme: 1., 2., 3. deneme -> 1, 5, 25 dakika.

    Sabit aralik, gecici olarak dusmus bir uca dakikada bir vurmak olurdu;
    katlanan aralik hem yuku dagitir hem de kalici arizada kuyrugu hizla
    bosaltir (max denemede durur).
    """
    return timedelta(minutes=5 ** max(0, deneme))


def denenmeli(
    *,
    deneme: int,
    son_deneme_at: datetime | None,
    simdi: datetime,
    max_deneme: int,
) -> bool:
    """Bu satirin siradaki denemesinin vadesi geldi mi?

    `son_deneme_at` YOKSA (henuz hic denenmemis kayit) HEMEN denenir.
    """
    if deneme >= max_deneme:
        return False
    if son_deneme_at is None:
        return True
    return simdi >= son_deneme_at + gecikme(deneme)
