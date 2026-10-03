"""(P253 A2) Toplu tahakkuk geri alma (§C-4) + "rapor hazir" bildirimi.

* Toplu tahakkuk parti kimligi doner; parti tek istekte TERS KAYITLA geri
  alinir. Sebep zorunlu; odeme almis satir atlanir (`odenmis`); ikinci
  geri alma hicbir seyi tekrar ters kayitlamaz.
* Kuyruktaki rapor bitince ISTEYEN kisiye `rapor_hazir` bildirimi yazilir
  (baskasina degil).
"""
from __future__ import annotations

import asyncio
import time
import uuid

import pytest

from app.hata_metinleri import METINLER


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def ortam(client, world):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    blok = f"P{uuid.uuid4().hex[:5]}"
    daireler = []
    for i in range(3):
        r = client.post("/units", headers=h, json={"no": f"{blok}-{i}", "blok": blok})
        assert r.status_code == 201, r.text
        daireler.append(r.json()["id"])
    tanim = client.post("/gelir-gider-tanimlari", headers=h, json={
        "ad": f"Aidat {blok}", "tip": "gider"})
    assert tanim.status_code == 201, tanim.text
    return h, blok, daireler, tanim.json()["id"]


def _toplu(client, h, blok, tanim, donem="2031-07"):
    r = client.post("/borclandirma/toplu", headers=h, json={
        "donem": donem, "gelir_gider_tanim_id": tanim, "tutar_kurus": 10000,
        "suzgec": {"blok": blok}})
    assert r.status_code == 201, r.text
    return r.json()


def test_TOPLU_parti_GERI_AL_sebep_zorunlu_odenmis_atlanir(client, world, ortam):
    h, blok, daireler, tanim = ortam
    sonuc = _toplu(client, h, blok, tanim)
    assert sonuc["olusan"] == 3 and sonuc["parti_id"]
    parti = sonuc["parti_id"]
    # Bir daireye odeme: o kalem geri alinamaz.
    kalem = client.get(f"/units/{daireler[0]}/dues", headers=h).json()
    a_id = next(k["id"] for k in kalem["assessments"] if k["donem"] == "2031-07")
    o = client.post("/dues/payments", headers={**h, "Idempotency-Key": str(uuid.uuid4())}, json={
        "unit_id": daireler[0], "assessment_id": a_id, "tutar_kurus": 5000, "yontem": "elden"})
    assert o.status_code in (200, 201), o.text

    for govde in ({}, {"aciklama": "  "}):
        r = client.post(f"/borclandirma/parti/{parti}/geri-al", headers=h, json=govde)
        assert r.status_code == 422
        assert r.json()["error"]["message"] == METINLER["sebep_zorunlu"]["tr"]

    r = client.post(f"/borclandirma/parti/{parti}/geri-al", headers=h,
                    json={"aciklama": "Yanlis donem secildi"})
    assert r.status_code == 200, r.text
    assert r.json()["geri_alinan"] == 2
    assert [a["neden"] for a in r.json()["atlananlar"]] == ["odenmis"]
    # Ikinci kez: yeni ters kayit YOK.
    r2 = client.post(f"/borclandirma/parti/{parti}/geri-al", headers=h,
                     json={"aciklama": "Tekrar"})
    assert r2.json()["geri_alinan"] == 0


def test_PARTI_yoksa_404_ve_yetkisiz_403(client, world, ortam):
    h, *_ = ortam
    assert client.post(f"/borclandirma/parti/{uuid.uuid4()}/geri-al", headers=h,
                       json={"aciklama": "deneme"}).status_code == 404
    for rol in ("guard_a", "gorevli_a", "resident_a", "denetci_a"):
        r = client.post(f"/borclandirma/parti/{uuid.uuid4()}/geri-al",
                        headers=_h(client, world["slug_a"], world[rol]), json={"aciklama": "deneme"})
        assert r.status_code == 403, rol


def test_RAPOR_HAZIR_bildirimi_yalniz_isteyene(client, world, owner_conn):
    from app.rapor_kuyruk import isi_uret

    yon = _h(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/raporlar/borc_alacak/kuyruk?bicim=excel", headers=yon, json={
        "baslangic": "2026-01-01", "bitis": "2026-12-31"})
    assert r.status_code == 202, r.text
    is_id = uuid.UUID(r.json()["id"])
    # Isci (Celery) isi alabilir; almazsa testte uretilir. Iki yol da AYNI
    # isleve gider ve hazir bir isi ikinci kez uretmez.
    for _ in range(40):
        durum = owner_conn.execute("SELECT durum FROM rapor_isi WHERE id = %s", (str(is_id),)).fetchone()[0]
        if durum in ("hazir", "hata"):
            break
        time.sleep(0.5)
    else:
        asyncio.run(isi_uret(is_id))
    assert owner_conn.execute("SELECT durum FROM rapor_isi WHERE id = %s",
                              (str(is_id),)).fetchone()[0] == "hazir"
    satirlar = owner_conn.execute(
        "SELECT n.user_id, n.mesaj_veri->>'rapor', a.email FROM notification n "
        "JOIN app_user a ON a.id = n.user_id WHERE n.tip = 'rapor_hazir' "
        "AND n.mesaj_veri->>'is_id' = %s", (str(is_id),),
    ).fetchall()
    assert len(satirlar) == 1 and satirlar[0][2] == world["yonetici_a"]["email"]
    assert satirlar[0][1]
