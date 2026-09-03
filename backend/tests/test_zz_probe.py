import uuid
from tests.test_dues import _headers, _new_unit


def test_probe(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    u = _new_unit(client, admin)
    taban = {"unit_id": u["id"], "tutar_kurus": 1000, "yontem": "elden"}
    senaryolar = {
        "temiz": taban,
        "donem_uzun": {**taban, "donem": "2026-08-01"},
        "donem_metin": {**taban, "donem": "Agustos 2026"},
        "makbuz_uzun": {**taban, "makbuz_no": "M" * 300},
        "kasa_uydurma": {**taban, "kasa_id": str(uuid.uuid4())},
        "assessment_uydurma": {**taban, "assessment_id": str(uuid.uuid4())},
        "unit_uydurma": {**taban, "unit_id": str(uuid.uuid4())},
        "yontem_bilinmeyen": {**taban, "yontem": "kripto"},
        "tutar_sifir": {**taban, "tutar_kurus": 0},
        "odeme_zamani": {**taban, "odeme_zamani": "2026-08-30T10:00:00Z"},
        "odeme_zamani_naive": {**taban, "odeme_zamani": "2026-08-30T10:00:00"},
        "tutar_devasa": {**taban, "tutar_kurus": 10**18},
    }
    for ad, govde in senaryolar.items():
        r = client.post(
            "/dues/payments",
            headers={**admin, "Idempotency-Key": uuid.uuid4().hex},
            json=govde,
        )
        print(f"{ad:22} -> {r.status_code} {r.text[:160]}")
