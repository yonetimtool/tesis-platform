"""(P243 §5c) PANIK KATEGORILERI — metin ve ALICI KUMESI.

===========================================================================
NE OLCULUYOR
===========================================================================
Tek bir "acil durum" alarmi, alan kisiye NE YAPACAGINI soylemiyordu.
Burada olculen iki sey:
  1. her kategorinin KENDI metni gidiyor (deprem ile gaz ayni cumleyi
     kullanmiyor),
  2. alici kumesi kategoriden de tureyor: bina geneli tehlikeler TUM
     SITEYE, saglik/guvenlik tehdidi YALNIZ yonetim+guvenlige.
"""
from __future__ import annotations

import pytest


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _tetikle(client, headers, tip: str, kategori: str | None):
    govde = {"tip": tip}
    if kategori:
        govde["kategori"] = kategori
    r = client.post("/panik", headers=headers, json=govde)
    assert r.status_code == 201, r.text
    return r.json()


# ========================== METIN: HER KATEGORI AYRI ====================== #
def test_HER_KATEGORININ_KENDI_TALIMATI_VAR(client, world):
    """Deprem ile gaz kacagi AYNI cumleyi kullanamaz."""
    from app.push_metinleri import METINLER, push_govdesi

    metinler = {}
    for k in ("deprem", "yangin", "gaz", "tahliye", "saglik",
              "guvenlik_tehdidi", "diger"):
        kimlik = f"panik_kategori_{k}"
        assert kimlik in METINLER, kimlik
        metinler[k] = push_govdesi(kimlik, "tr")

    # HEPSI BIRBIRINDEN FARKLI.
    assert len(set(metinler.values())) == len(metinler), metinler

    # TALIMATLAR BIRBIRINI DISLIYOR — kanit olarak anahtar kelimeler.
    assert "asansör" in metinler["deprem"].lower()
    assert "elektrik" in metinler["gaz"].lower()
    assert "terk" in metinler["tahliye"].lower()
    # GUVENLIK TEHDIDINDE "DISARI CIK" DEMIYORUZ — yerinde kal.
    assert "kalın" in metinler["guvenlik_tehdidi"]
    assert "terk" not in metinler["guvenlik_tehdidi"].lower()


def test_KATEGORI_METINLERI_YEDI_DILDE(client, world):
    from app.push_metinleri import METINLER

    from .test_push_i18n import DILLER

    for k in ("deprem", "yangin", "gaz", "tahliye", "saglik",
              "guvenlik_tehdidi", "diger"):
        kayit = METINLER[f"panik_kategori_{k}"]
        for dil in DILLER:
            assert kayit.baslik[dil].strip(), (k, dil)
            assert kayit.govde[dil].strip(), (k, dil)


def test_KISA_TUTULDU_bildirim_ekraninda_okunur(client, world):
    """Uzun metin '...' ile kesilir ve kesilen yer TALIMATIN oldugu yer."""
    from app.push_metinleri import METINLER

    from .test_push_i18n import DILLER

    for k in ("deprem", "yangin", "gaz", "tahliye", "saglik",
              "guvenlik_tehdidi"):
        for dil in DILLER:
            govde = METINLER[f"panik_kategori_{k}"].govde[dil]
            assert len(govde) <= 110, (k, dil, len(govde))


# ====================== ALICI KUMESI KATEGORIDEN TURER ==================== #
def test_DEPREM_TUM_SITEYE_GIDER(client, world, owner_conn):
    """Bina geneli tehlike: sakin de alir — yapacagi bir sey var."""
    from app.tasks import panik_yayinla

    admin = _h(client, world["slug_a"], world["admin_a"])
    sakin = _h(client, world["slug_a"], world["resident_a"])
    tid = client.get("/me", headers=admin).json()["tenant_id"]
    alarm = _tetikle(client, admin, "guvenlik", "deprem")
    panik_yayinla(alarm["id"], tid)

    b = client.get("/notifications", headers=sakin, params={"limit": 50}).json()
    panikler = [x for x in b["items"] if x["tip"] == "panik_alarm"]
    assert panikler, "sakin DEPREM alarmini ALMALI"
    # METIN KATEGORIYE AIT.
    assert "asansör" in panikler[0]["mesaj"].lower(), panikler[0]["mesaj"]


def test_SAGLIK_SAKINE_GITMEZ(client, world):
    """Saglik durumu KISISEL VERIDIR; siteye duyurmak gereksiz ifsadir."""
    from app.tasks import panik_yayinla

    admin = _h(client, world["slug_a"], world["admin_a"])
    sakin = _h(client, world["slug_a"], world["resident_a"])
    guard = _h(client, world["slug_a"], world["guard_a"])
    tid = client.get("/me", headers=admin).json()["tenant_id"]

    onceki = len(
        [
            x for x in client.get(
                "/notifications", headers=sakin, params={"limit": 50}
            ).json()["items"] if x["tip"] == "panik_alarm"
        ]
    )
    alarm = _tetikle(client, admin, "guvenlik", "saglik")
    panik_yayinla(alarm["id"], tid)

    sonraki = len(
        [
            x for x in client.get(
                "/notifications", headers=sakin, params={"limit": 50}
            ).json()["items"] if x["tip"] == "panik_alarm"
        ]
    )
    assert sonraki == onceki, "saglik alarmi sakine GITMEMELI"
    # AMA GUVENLIK ALIR.
    g = [
        x for x in client.get(
            "/notifications", headers=guard, params={"limit": 50}
        ).json()["items"] if x["tip"] == "panik_alarm"
    ]
    assert g, "guvenlik saglik alarmini ALMALI"


def test_GUVENLIK_TEHDIDI_SAKINE_GITMEZ(client, world):
    """Saldirgan ihtimalinde sakinleri koridora cikarmak RISKI ARTIRIR."""
    from app.panik import kategori_alicilari

    assert "resident" not in kategori_alicilari("guvenlik", "guvenlik_tehdidi")
    assert "resident" in kategori_alicilari("guvenlik", "tahliye")


def test_KATEGORI_KUMEYI_DARALTMAZ_SADECE_GENISLETIR(client, world):
    """`sakin` panigi + saglik: guvenlik yine de ALIR."""
    from app.panik import ALICI_ROLLERI, kategori_alicilari

    taban = ALICI_ROLLERI["sakin"]
    assert taban <= kategori_alicilari("sakin", "saglik")
    assert taban <= kategori_alicilari("sakin", "deprem")


def test_KATEGORISIZ_ALARM_ESKI_METNI_KULLANIR(client, world):
    """P240 doneminde acilmis alarmlara uydurma talimat yazilmaz."""
    from app.panik_yayin import kategori_kimligi

    assert kategori_kimligi(None) == "panik_alarm"
    assert kategori_kimligi("deprem") == "panik_kategori_deprem"


def test_GECERSIZ_KATEGORI_REDDEDILIR(client, world):
    admin = _h(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/panik", headers=admin, json={"tip": "guvenlik", "kategori": "sel"}
    )
    assert r.status_code == 422, r.text
