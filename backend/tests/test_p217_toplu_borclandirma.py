"""(P217 §1) TOPLU BORCLANDIRMA — SESSIZ BASARISIZLIK ve GORUNURLUK.

===========================================================================
OLCULEN DURUM (iddia dogrulanmadi, ama IKI GERCEK KUSUR bulundu)
===========================================================================
Sikayet: "toplu borclandirma calismiyor; dairelerde borc gorunmuyor,
finansa yansimiyor".

GERCEKTEN SURULDU (admin + yonetici, hem uc hem web BFF uzerinden):
  * onizleme 15 daire "islenecek" diyor,
  * isleme 201 donuyor ve `dues_assessment`a 15 kayit YAZILIYOR,
  * borclandirmalar listesi kayitlari GOSTERIYOR,
  * finans ozeti tahakkuku SAYIYOR (`acik_borc_kurus`),
  * yonetici rolu de calisiyor (P199'daki 403 P206'da acilmis).

Yani akis calisiyordu. Buna ragmen kullanicinin gordugu sey gercek; iki
kusur olculdu ve bu dosya ikisini de kilitler:

  1. SESSIZ BASARISIZLIK: ayni donem ikinci kez borclandirilinca 15
     satirin HEPSI benzersizlik carpismasiyla atlaniyor, HICBIR TAHAKKUK
     yazilmiyor — ama yanit `created: []`, `atlanan: 15` ve web'de yine
     "Kaydedildi" cikiyordu. Sunucu KAC TANE olustugunu SOYLEMIYORDU.
  2. GORUNMEYEN BORC: `/units` yaniti borc alani TASIMIYORDU. Yonetici
     "Daireler" ekranina bakip borc goremiyordu.

TEK DEFTER (P192) NOTU: tahakkuk `finansal_hareket`e YAZILMAZ ve bu
kusur DEGIL — `hareket_tip` enum'u yalnizca PARA hareketlerini tanir
(tahsilat/gider/gelir/virman/iade/acilis/iptal). Tahakkuk bir BORC
kaydidir ve `dues_assessment`ta yasar; tekil tahakkuk yolu da ayni
sekilde davranir. Finans ozeti tahakkuku oradan okur.
"""
from __future__ import annotations

import uuid


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _gider_tanimi(client, h) -> str:
    """Gider tanimi — yoksa OLUSTURUR.

    Ilk yazimda yalnizca listeliyordu ve `world` fixture'inin tenant'inda
    tanim olmadigi icin YEDI TEST birden "olcum kurulamadi" ile dustu.
    Testin kendi on kosulunu kurmasi, baska bir turun seed'ine bagli
    kalmasindan iyidir.
    """
    r = client.get("/gelir-gider-tanimlari?limit=50", headers=h)
    assert r.status_code == 200, r.text
    gider = [x for x in r.json()["items"] if x["tip"] == "gider"]
    if gider:
        return gider[0]["id"]
    y = client.post("/gelir-gider-tanimlari", headers=h, json={
        "ad": f"P217 Gider {uuid.uuid4().hex[:6]}", "tip": "gider"})
    assert y.status_code in (200, 201), f"gider tanimi acilamadi: {y.text}"
    return y.json()["id"]


def _daire(client, h) -> dict:
    """Daire — yoksa OLUSTURUR (`world` fixture'i daire acmiyor)."""
    r = client.get("/units?limit=1", headers=h)
    assert r.status_code == 200, r.text
    if r.json()["items"]:
        return r.json()["items"][0]
    y = client.post("/units", headers=h, json={
        "no": f"P217-{uuid.uuid4().hex[:5]}", "blok": "A", "aktif": True})
    assert y.status_code in (200, 201), f"daire acilamadi: {y.text}"
    return y.json()


def _govde(tanim_id: str, donem: str) -> dict:
    return {"donem": donem, "gelir_gider_tanim_id": tanim_id,
            "tutar_kurus": 4321, "kalem_tipi": "aidat",
            "aciklama": "p217 test"}


def _temizle(owner_conn, donem: str) -> None:
    owner_conn.execute("DELETE FROM dues_assessment WHERE donem = %s", (donem,))


# ==================== 1. SESSIZ BASARISIZLIK ============================= #

def test_ILK_KOSUM_kac_tahakkuk_OLUSTUGUNU_soyler(client, world, owner_conn):
    """`olusan` alani KOK DUZELTMEDIR: istemci "oldu mu" sorusunu
    yanitlayabilmeli. Eskiden `created` bos donuyor, sayi hic
    donmuyordu ve ekranda her durumda "Kaydedildi" yaziyordu."""
    h = _h(client, world["slug_a"], world["yonetici_a"])
    _daire(client, h)  # ON KOSUL: toplu borclandirma AKTIF DAIRELERI isler
    donem = f"20{uuid.uuid4().int % 90 + 10}-01"
    _temizle(owner_conn, donem)
    try:
        r = client.post("/borclandirma/toplu", headers=h,
                        json=_govde(_gider_tanimi(client, h), donem), timeout=60)
        assert r.status_code == 201, r.text
        d = r.json()
        assert d["olusan"] > 0, "hicbir tahakkuk olusmadi — olcum bosa dustu"
        assert d["atlanan"] == 0
        # Sayi GERCEKTE yazilanla ortusmeli.
        satir = owner_conn.execute(
            "SELECT count(*) FROM dues_assessment WHERE donem = %s", (donem,)
        ).fetchone()[0]
        assert d["olusan"] == satir
    finally:
        _temizle(owner_conn, donem)


def test_IKINCI_KOSUM_hicbir_sey_yazmaz_ve_BUNU_SOYLER(client, world, owner_conn):
    """KULLANICININ GORDUGU DURUM.

    Ayni donem ikinci kez borclandirilinca hicbir tahakkuk olusmaz. Bu
    DOGRU davranistir (benzersizlik); kusur, bunun SOYLENMEMESIYDI.
    `olusan == 0` istemcinin "kaydedildi" dememesi icin gereken tek
    bilgidir.
    """
    h = _h(client, world["slug_a"], world["yonetici_a"])
    _daire(client, h)
    donem = f"20{uuid.uuid4().int % 90 + 10}-02"
    _temizle(owner_conn, donem)
    govde = _govde(_gider_tanimi(client, h), donem)
    try:
        ilk = client.post("/borclandirma/toplu", headers=h, json=govde, timeout=60)
        assert ilk.json()["olusan"] > 0
        ikinci = client.post("/borclandirma/toplu", headers=h, json=govde, timeout=60)
        assert ikinci.status_code == 201, ikinci.text
        d = ikinci.json()
        assert d["olusan"] == 0, "ikinci kosumda tahakkuk olusmamali"
        assert d["atlanan"] > 0
        # Atlananlar DOKUMLU: hangi daire, hangi neden.
        assert d["atlananlar"] and d["atlananlar"][0]["neden"]
        # Ve gercekten yeni satir YOK.
        assert owner_conn.execute(
            "SELECT count(*) FROM dues_assessment WHERE donem = %s", (donem,)
        ).fetchone()[0] == ilk.json()["olusan"]
    finally:
        _temizle(owner_conn, donem)


def test_TEKIL_tahakkuk_da_olusan_doner(client, world, owner_conn):
    """Iki yol ayni ekrandan kullaniliyor; birinin sayi verip otekinin
    vermemesi ayni belirsizligi yarim birakmakti."""
    h = _h(client, world["slug_a"], world["yonetici_a"])
    daire = _daire(client, h)
    donem = f"20{uuid.uuid4().int % 90 + 10}-03"
    _temizle(owner_conn, donem)
    try:
        r = client.post("/dues/assessments", headers=h, json={
            "unit_id": daire["id"], "donem": donem, "tutar_kurus": 1234})
        assert r.status_code in (200, 201), r.text
        assert r.json()["olusan"] == 1
    finally:
        _temizle(owner_conn, donem)


# ==================== 2. YONETICI YETKISI (P199 -> P206) ================= #

def test_YONETICI_toplu_borclandirabilir(client, world, owner_conn):
    """P199'da bu uc yoneticiye 403 donuyordu; P206'da acildi.
    Istegin sorusu "gercekten acildi mi" — uctan uca olculuyor."""
    h = _h(client, world["slug_a"], world["yonetici_a"])
    _daire(client, h)
    donem = f"20{uuid.uuid4().int % 90 + 10}-04"
    _temizle(owner_conn, donem)
    try:
        tanim = _gider_tanimi(client, h)
        o = client.post("/borclandirma/toplu/onizleme", headers=h,
                        json=_govde(tanim, donem), timeout=60)
        assert o.status_code == 200, f"onizleme yoneticiye kapali: {o.text}"
        i = client.post("/borclandirma/toplu", headers=h,
                        json=_govde(tanim, donem), timeout=60)
        assert i.status_code == 201, f"isleme yoneticiye kapali: {i.text}"
        assert i.json()["olusan"] > 0
    finally:
        _temizle(owner_conn, donem)


# ==================== 3. DAIRELERDE BORC GORUNURLUGU ==================== #

def test_DAIRE_LISTESI_acik_borcu_DONER(client, world, owner_conn):
    """KULLANICININ BAKTIGI EKRAN.

    Tahakkuk yazilmisti ama `/units` yaniti borc ALANI TASIMIYORDU;
    "Daireler" ekraninda borc gorunmuyordu ve kullanici bundan
    "borclandirma calismiyor" sonucuna varabilirdi.
    """
    h = _h(client, world["slug_a"], world["yonetici_a"])
    daire = _daire(client, h)
    donem = f"20{uuid.uuid4().int % 90 + 10}-05"
    _temizle(owner_conn, donem)
    try:
        once = client.get("/units?limit=200", headers=h).json()["items"]
        onceki = next(d["borc_kurus"] for d in once if d["id"] == daire["id"])
        assert onceki is not None, "borc alani HIC donmuyor"

        r = client.post("/dues/assessments", headers=h, json={
            "unit_id": daire["id"], "donem": donem, "tutar_kurus": 55500})
        assert r.status_code in (200, 201), r.text

        sonra = client.get("/units?limit=200", headers=h).json()["items"]
        yeni = next(d["borc_kurus"] for d in sonra if d["id"] == daire["id"])
        assert yeni == onceki + 55500, (
            f"borc yansimadi: {onceki} -> {yeni} (beklenen +55500)"
        )
    finally:
        _temizle(owner_conn, donem)


def test_BORC_tahsilati_DUSER(client, world, owner_conn):
    """Alan "tahakkuk toplami" degil ACIK BORC: tahsilat dusulmeli.
    Aksi halde odemesini yapmis daire sonsuza dek borclu gorunurdu."""
    h = _h(client, world["slug_a"], world["yonetici_a"])
    daire = _daire(client, h)
    donem = f"20{uuid.uuid4().int % 90 + 10}-06"
    _temizle(owner_conn, donem)
    try:
        a = client.post("/dues/assessments", headers=h, json={
            "unit_id": daire["id"], "donem": donem, "tutar_kurus": 30000})
        assessment_id = a.json()["created"][0]["id"]
        once = next(d["borc_kurus"] for d in
                    client.get("/units?limit=200", headers=h).json()["items"]
                    if d["id"] == daire["id"])
        # Tahsilat ucu `Idempotency-Key` ZORUNLU kilar (P64): ayni
        # odemenin iki kez yazilmasi paranin iki kez tahsil edilmis
        # gorunmesi demekti.
        t = client.post("/dues/payments",
                        headers={**h, "Idempotency-Key": uuid.uuid4().hex},
                        json={
            "unit_id": daire["id"], "assessment_id": assessment_id,
            # `nakit` DEGIL `elden`: sema `elden|havale|kart|diger` kabul
            # ediyor. Ilk yazimda `nakit` gonderip 422 aldim ve testi
            # ATLIYORDUM — atlanan bir test hicbir sey korumaz; dogru
            # olan degeri kullanmakti.
            "tutar_kurus": 10000, "yontem": "elden"})
        assert t.status_code in (200, 201), f"tahsilat yazilamadi: {t.text}"
        sonra = next(d["borc_kurus"] for d in
                     client.get("/units?limit=200", headers=h).json()["items"]
                     if d["id"] == daire["id"])
        assert sonra == once - 10000, f"tahsilat dusulmedi: {once} -> {sonra}"
    finally:
        _temizle(owner_conn, donem)


# ==================== 4. TEK DEFTER SINIRI (P192) ======================= #

def test_TAHAKKUK_deftere_YAZILMAZ_ve_bu_KUSUR_DEGIL(client, world, owner_conn):
    """Istegin kabul kriteri "tahakkuk finansal_hareket'e yazilsin"
    diyordu; TASARIM bunun tersi ve bu test o karari GORUNUR kilar.

    `hareket_tip` enum'u yalnizca PARA hareketlerini tanir
    (tahsilat/gider/gelir/virman/iade/acilis/iptal). Tahakkuk bir BORC
    kaydidir, para hareketi degil. Deftere yazmak icin once enum'a yeni
    bir tur eklemek gerekirdi — yani P192'nin "defter = para" tanimini
    degistirmek. Finans ozeti tahakkuku `dues_assessment`tan okuyor ve
    `acik_borc_kurus`u dogru veriyor (olculdu).
    """
    h = _h(client, world["slug_a"], world["yonetici_a"])
    daire = _daire(client, h)
    donem = f"20{uuid.uuid4().int % 90 + 10}-07"
    _temizle(owner_conn, donem)
    try:
        client.post("/dues/assessments", headers=h, json={
            "unit_id": daire["id"], "donem": donem, "tutar_kurus": 7700})
        defter = owner_conn.execute(
            "SELECT count(*) FROM finansal_hareket fh "
            "JOIN dues_assessment da ON da.id = fh.assessment_id "
            "WHERE da.donem = %s AND fh.tip <> 'tahsilat'", (donem,)
        ).fetchone()[0]
        assert defter == 0, "tahakkuk deftere yazilmis — P192 tanimi degismis"
        # Enum da bunu soyluyor: `tahakkuk` diye bir hareket turu YOK.
        turler = {r[0] for r in owner_conn.execute(
            "SELECT unnest(enum_range(NULL::hareket_tip))").fetchall()}
        assert "tahakkuk" not in turler
    finally:
        _temizle(owner_conn, donem)


# ==================== (P217 §4) DAIRE DOLULUK BILGISI ==================== #

def test_DAIRE_LISTESI_aktif_sakin_SAYISINI_doner(client, world, owner_conn):
    """(P217 §4) Daire atamasinda "dolu mu" sorusunun yaniti.

    SAYI donuyor, "dolu/bos" BAYRAGI degil: bir dairede BIRDEN COK sakin
    mesrudur (esler, aile; malik + kiraci) ve `unit_resident`ta tekillik
    kisiti YOK. Ikili bir bayrak "1 sakin" ile "4 sakin"i ayni gosterir;
    yonetici ikinci sakini BILEREK ekleyebilmeli.
    """
    h = _h(client, world["slug_a"], world["yonetici_a"])
    daire = _daire(client, h)
    once = next(d["sakin_sayisi"] for d in
                client.get("/units?limit=200", headers=h).json()["items"]
                if d["id"] == daire["id"])
    assert once is not None, "sakin sayisi alani HIC donmuyor"

    # Sakin ata ve sayinin arttigini gor.
    kisi = client.post("/users", headers=h, json={
        "ad": "P217 Sakin", "email": f"p217-{uuid.uuid4().hex[:8]}@ornek.com",
        "role": "resident", "password": "Parola123!"})
    assert kisi.status_code == 201, kisi.text
    uid = kisi.json()["id"]
    try:
        r = client.post(f"/units/{daire['id']}/residents", headers=h,
                        json={"user_id": uid, "rol_tipi": "kiraci"})
        assert r.status_code in (200, 201), r.text
        sonra = next(d["sakin_sayisi"] for d in
                     client.get("/units?limit=200", headers=h).json()["items"]
                     if d["id"] == daire["id"])
        assert sonra == once + 1, f"sakin sayisi yansimadi: {once} -> {sonra}"
    finally:
        client.delete(f"/units/{daire['id']}/residents/{uid}", headers=h)
        client.delete(f"/users/{uid}", headers=h)


def test_AYRILAN_sakin_SAYILMAZ(client, world, owner_conn):
    """`bitis` dolu kayit AKTIF sakin degildir: tasinmis biri yuzunden
    daire sonsuza dek "dolu" gorunemez."""
    h = _h(client, world["slug_a"], world["yonetici_a"])
    daire = _daire(client, h)
    kisi = client.post("/users", headers=h, json={
        "ad": "P217 Ayrilan", "email": f"p217-{uuid.uuid4().hex[:8]}@ornek.com",
        "role": "resident", "password": "Parola123!"})
    uid = kisi.json()["id"]
    try:
        client.post(f"/units/{daire['id']}/residents", headers=h,
                    json={"user_id": uid, "rol_tipi": "kiraci"})
        dolu = next(d["sakin_sayisi"] for d in
                    client.get("/units?limit=200", headers=h).json()["items"]
                    if d["id"] == daire["id"])
        # Cikar (bitis yazilir) ve sayinin DUSTUGUNU gor.
        client.delete(f"/units/{daire['id']}/residents/{uid}", headers=h)
        sonra = next(d["sakin_sayisi"] for d in
                     client.get("/units?limit=200", headers=h).json()["items"]
                     if d["id"] == daire["id"])
        assert sonra == dolu - 1, f"ayrilan sakin hâlâ sayiliyor: {dolu} -> {sonra}"
    finally:
        client.delete(f"/users/{uid}", headers=h)
