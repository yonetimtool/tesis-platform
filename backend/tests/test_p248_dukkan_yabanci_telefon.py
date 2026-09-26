"""(P248 §2) DUKKAN — YABANCI NUMARA ILE GIRIS.

===========================================================================
OLCULEN KUSUR
===========================================================================
Web ve mobil telefon alanlari artik ulke kodunu SECTIRIYOR ve E.164
gonderiyor (`+4915123456789`). Dukkan'in `telefon_normalize`u ise her
girdiye TR kurallarini uyguluyordu:
  * `+4915123456789` (13 hane)  -> 422 `telefon_bicimi_gecersiz`,
  * `+4712345678`   (NO, 10 hane) -> SESSIZCE `+904712345678`.
Yani ulke kodu secilebilse de yabanci numarayla Dukkan'a girilemiyordu.

Testler canli sunucuya HTTP ile gider (taklit yok).
"""
from __future__ import annotations

import uuid

import pytest
from fastapi import HTTPException

from app.dukkan.kimlik import telefon_normalize


@pytest.mark.parametrize(
    ("girdi", "beklenen"),
    [
        # TR — eski bicimlerin HEPSI ayni anahtara (geriye donuk).
        ("05321112233", "+905321112233"),
        ("5321112233", "+905321112233"),
        ("905321112233", "+905321112233"),
        ("+90 532 111 22 33", "+905321112233"),
        ("(+90) 532 111 22 33", "+905321112233"),
        # YABANCI — acik ulke koduyla, KENDI koduyla.
        ("+49 151 23456789", "+4915123456789"),
        ("(+44) 7911 123456", "+447911123456"),
        ("0049 151 23456789", "+4915123456789"),
        # SESSIZ DONUSUM YOK: 10 haneli Norvec numarasi TR'ye cevrilmez.
        ("+47 12345678", "+4712345678"),
    ],
)
def test_telefon_normalize_ulke_kodunu_korur(girdi, beklenen):
    assert telefon_normalize(girdi) == beklenen


@pytest.mark.parametrize("girdi", ["+12", "+49abc", "123"])
def test_telefon_normalize_gecersizi_reddeder(girdi):
    with pytest.raises(HTTPException) as h:
        telefon_normalize(girdi)
    assert h.value.status_code == 422


def test_yabanci_numara_ile_OTP_girisi_uctan_uca(client):
    """Alman numarasi: kod iste -> dogrula -> hesap E.164 ile acilir."""
    tel = f"+49151{uuid.uuid4().int % 10**8:08d}"
    r = client.post("/dukkan/auth/telefon/kod", json={"telefon": tel})
    assert r.status_code == 200, r.text
    kod = r.json()["dev_kod"]
    r = client.post(
        "/dukkan/auth/telefon/dogrula", json={"telefon": tel, "kod": kod}
    )
    assert r.status_code == 200, r.text
    assert r.json()["kullanici"]["telefon"] == tel
