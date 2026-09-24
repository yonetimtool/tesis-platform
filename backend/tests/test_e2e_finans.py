"""(E2E 2026-09) FINANS turu regresyon kilitleri.

Uctan uca test turu finans modulunde FINANS-01..21 + YETKI-06 + BILDIRIM-14
+ TESIS-01/08 + ARAYUZ-4/5/8 bulgularini raporladi. Her test bir bulguyu
KAYNAKTA kilitler; test adinin basindaki etiket bulgu numarasidir.

Testler CANLI sunucuya vurur (bkz. conftest); para her yerde KURUS.
"""
from __future__ import annotations

import io
import uuid
from datetime import date, timedelta

import pytest

from tests.test_p203_mesai_uc import _ozet, mesai_duzeni  # noqa: F401 (fixture)


# ------------------------------- yardimcilar -------------------------------- #
def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _sfx() -> str:
    return uuid.uuid4().hex[:6]


@pytest.fixture
def adm(client, world):
    return _h(client, world["slug_a"], world["admin_a"])


@pytest.fixture
def yon(client, world):
    return _h(client, world["slug_a"], world["yonetici_a"])


@pytest.fixture
def kasa(client, adm):
    r = client.post("/kasalar", headers=adm, json={
        "kod": f"EF{_sfx()}", "ad": "E2E Finans Kasa"})
    assert r.status_code == 201, r.text
    return r.json()


def _daire(client, h):
    r = client.post("/units", headers=h, json={"no": f"EF-{_sfx()}", "blok": "E"})
    assert r.status_code == 201, r.text
    return r.json()


def _borc(client, h, unit_id, donem, tutar, gun_once=None, **ek):
    govde = {"unit_id": unit_id, "donem": donem, "tutar_kurus": tutar, **ek}
    if gun_once is not None:
        govde["son_odeme_tarihi"] = (date.today() - timedelta(days=gun_once)).isoformat()
    r = client.post("/dues/assessments", headers=h, json=govde)
    assert r.status_code == 201, r.text
    return r.json()["created"][0]


def _sakin(client, h, owner_conn, ad="E2E Sakin"):
    """Giris yapabilen sakin: (user_id, basliklar)."""
    from app.security import hash_password

    eposta = f"e2ef-{uuid.uuid4().hex[:10]}@ornek.com"
    r = client.post("/users", headers=h, json={
        "ad": ad, "email": eposta, "role": "resident", "password": "Parola123!"})
    assert r.status_code == 201, r.text
    uid = r.json()["id"]
    owner_conn.execute(
        "UPDATE app_user SET password_hash = %s WHERE id = %s",
        (hash_password("SakinPass1"), uid),
    )
    return uid, eposta


def _bagla(client, h, unit_id, user_id, rol, **ek):
    r = client.post(f"/units/{unit_id}/residents", headers=h,
                    json={"user_id": user_id, "rol_tipi": rol, **ek})
    assert r.status_code in (200, 201), r.text


def _tanim(client, h, kural):
    r = client.post("/gelir-gider-tanimlari", headers=h, json={
        "ad": f"E2E {kural} {_sfx()}", "tip": "gider", "hedef_kurali": kural})
    assert r.status_code in (200, 201), r.text
    return r.json()["id"]


def _bakiye(client, h, kasa_id) -> int:
    liste = client.get("/finans/kasa-bakiyeleri", headers=h).json()["items"]
    return next(k for k in liste if k["kasa_id"] == kasa_id)["bakiye_kurus"]


def _daire_bakiye(client, h, unit_id) -> int:
    return client.get(f"/units/{unit_id}/dues", headers=h).json()["bakiye_kurus"]


def _tahsilat(client, h, kasa_id, tutar, **ek):
    r = client.post("/finans/tahsilat", headers={**h, "Idempotency-Key": uuid.uuid4().hex},
                    json={"kasa_id": kasa_id, "tutar_kurus": tutar, **ek})
    return r


# ============== FINANS-01: daire secilmeden alinan tahsilat ================= #
def test_FINANS01_dairesiz_tahsilat_kisinin_TEK_dairesine_baglanir(
        client, adm, kasa, owner_conn):
    d = _daire(client, adm)
    uid, _ = _sakin(client, adm, owner_conn)
    _bagla(client, adm, d["id"], uid, "malik", oturuyor=True)
    _borc(client, adm, d["id"], "2041-01", 215000)

    r = _tahsilat(client, adm, kasa["id"], 215000, user_id=uid)
    assert r.status_code == 201, r.text
    assert r.json()["unit_id"] == d["id"], "tahsilat daireye baglanmadi"
    assert _daire_bakiye(client, adm, d["id"]) == 0, "para kasada, borc acik"


def test_FINANS01_cok_daireli_kiside_daire_SECIMI_zorunlu(
        client, adm, kasa, owner_conn):
    d1, d2 = _daire(client, adm), _daire(client, adm)
    uid, _ = _sakin(client, adm, owner_conn)
    _bagla(client, adm, d1["id"], uid, "malik")
    _bagla(client, adm, d2["id"], uid, "malik")
    r = _tahsilat(client, adm, kasa["id"], 1000, user_id=uid)
    assert r.status_code == 422, r.text
    assert "daire" in r.json()["error"]["message"].lower()


# ============== FINANS-02: vezne tahsilatinda makbuz + bildirim ============ #
def test_FINANS02_vezne_ve_aidat_ucu_MAKBUZ_ve_BILDIRIM_uretir(
        client, adm, kasa, owner_conn):
    d = _daire(client, adm)
    uid, _ = _sakin(client, adm, owner_conn)
    _bagla(client, adm, d["id"], uid, "malik", oturuyor=True)
    _borc(client, adm, d["id"], "2041-02", 5000)

    r = _tahsilat(client, adm, kasa["id"], 3000, unit_id=d["id"], user_id=uid)
    assert r.status_code == 201, r.text
    belge = r.json()["belge_no"]
    r2 = client.post("/dues/payments", headers={**adm, "Idempotency-Key": uuid.uuid4().hex},
                     json={"unit_id": d["id"], "tutar_kurus": 2000, "yontem": "elden"})
    assert r2.status_code == 201, r2.text

    makbuzlar = owner_conn.execute(
        "SELECT belge_no, user_id FROM receipt WHERE unit_id = %s", (d["id"],)
    ).fetchall()
    assert len(makbuzlar) == 2, makbuzlar
    assert belge in {m[0] for m in makbuzlar}
    assert all(str(m[1]) == uid for m in makbuzlar), "makbuz odeyene baglanmadi"
    bildirim = owner_conn.execute(
        "SELECT count(*) FROM notification WHERE user_id = %s AND tip = 'aidat_odendi'",
        (uid,),
    ).fetchone()[0]
    assert bildirim == 2, "sakine 'odemeniz alindi' gitmedi"


# ============ FINANS-03: gerceklesmemis gider iptal edilemez =============== #
def test_FINANS03_onay_bekleyen_ve_reddedilen_gider_IPTAL_EDILEMEZ(client, adm, kasa):
    once = _bakiye(client, adm, kasa["id"])
    satirlar = client.post("/finans/hareketler", headers=adm, json={"satirlar": [
        {"tip": "gider", "tutar_kurus": 90000, "kasa_id": kasa["id"],
         "durum": "onay_bekliyor"},
        {"tip": "gider", "tutar_kurus": 350000, "kasa_id": kasa["id"],
         "durum": "onay_bekliyor"},
    ]}).json()["items"]
    bekleyen, reddedilecek = satirlar
    r = client.post(f"/finans/hareketler/{bekleyen['id']}/iptal", headers=adm, json={})
    assert r.status_code == 409, r.text
    client.post(f"/finans/hareketler/{reddedilecek['id']}/reddet", headers=adm, json={})
    r = client.post(f"/finans/hareketler/{reddedilecek['id']}/iptal", headers=adm, json={})
    assert r.status_code == 409, r.text
    assert _bakiye(client, adm, kasa["id"]) == once, "kasaya hayali para girdi"


# ====== FINANS-04: daire duzeyinde odenmis borc "odenmemis" sayilmaz ======= #
def test_FINANS04_kalemsiz_tahsilat_FAIZ_ve_YASLANDIRMA_disinda(client, adm, kasa):
    client.patch("/borclandirma/gecikme-ayari", headers=adm, json={
        "gecikme_aylik_yuzde": 5, "gecikme_uygula": True})
    d = _daire(client, adm)
    b = _borc(client, adm, d["id"], "2041-03", 100000, gun_once=70)
    # Web'in yaptigi gibi KALEMSIZ tahsilat.
    assert _tahsilat(client, adm, kasa["id"], 100000, unit_id=d["id"]).status_code == 201

    oniz = client.get("/borclandirma/gecikme-faizi/onizleme", headers=adm).json()
    assert b["id"] not in {s["assessment_id"] for s in oniz["items"]}, \
        "odenmis borca faiz hesaplaniyor"
    yas = client.get("/finans/yaslandirma", headers=adm).json()
    assert not any(x["unit_id"] == d["id"] for k in yas["kovalar"] for x in k["daireler"])


def test_FINANS04_kalemsiz_tahsilat_EN_ESKI_kalemi_kapatir(client, adm, kasa):
    d = _daire(client, adm)
    eski = _borc(client, adm, d["id"], "2041-04", 1000, gun_once=40)
    yeni = _borc(client, adm, d["id"], "2041-05", 1000, gun_once=5)
    assert _tahsilat(client, adm, kasa["id"], 1500, unit_id=d["id"]).status_code == 201
    yas = client.get("/finans/yaslandirma", headers=adm).json()
    bizim = [x for k in yas["kovalar"] for x in k["daireler"] if x["unit_id"] == d["id"]]
    # Eski kalem tamamen kapandi; yeni kalemin 500'u kaldi ve kovasi 0-30.
    assert len(bizim) == 1 and bizim[0]["kalan_kurus"] == 500
    assert bizim[0]["kova"] == "0-30"
    _ = (eski, yeni)


# ============== FINANS-06: acik borc tek tanim ============================= #
def test_FINANS06_daireye_baglanmamis_tahsilat_ACIK_BORCU_dusurmez(client, adm, kasa):
    d = _daire(client, adm)
    _borc(client, adm, d["id"], "2041-06", 7000)
    once = client.get("/finans/ozet", headers=adm).json()["acik_borc_kurus"]
    # Kisi de daire de yok: hicbir borcu kapatmaz.
    assert _tahsilat(client, adm, kasa["id"], 7000).status_code == 201
    ara = client.get("/finans/ozet", headers=adm).json()["acik_borc_kurus"]
    assert ara == once
    assert _tahsilat(client, adm, kasa["id"], 7000, unit_id=d["id"]).status_code == 201
    sonra = client.get("/finans/ozet", headers=adm).json()["acik_borc_kurus"]
    assert sonra == once - 7000


# ============== FINANS-07: tahsilat orani donemsiz tahsilati sayar ========= #
def test_FINANS07_kalemsiz_tahsilat_TAHSILAT_ORANINA_girer(client, adm, kasa):
    donem = "2042-07"
    d = _daire(client, adm)
    _borc(client, adm, d["id"], donem, 40000)
    assert _tahsilat(client, adm, kasa["id"], 10000, unit_id=d["id"]).status_code == 201
    g = client.get("/finans/tahsilat-gostergesi", headers=adm,
                   params={"donem": donem}).json()
    board = client.get(f"/transparency/{donem}", headers=adm).json()["aidat"]
    rapor = client.get("/reports/financial-summary", headers=adm,
                       params={"donem": donem}).json()["tahsilat"]
    assert g["tahsilat_kurus"] == board["tahsilat_kurus"] == rapor["tahsilat_kurus"] == 10000
    assert g["oran_yuzde"] == 25


def test_FINANS07_kalemsiz_tahsilat_DONEMSIZ_yazilmaz(client, adm, kasa):
    d = _daire(client, adm)
    _borc(client, adm, d["id"], "2042-08", 5000)
    r = _tahsilat(client, adm, kasa["id"], 5000, unit_id=d["id"])
    liste = client.get("/dues/payments", headers=adm,
                       params={"unit_id": d["id"]}).json()["items"]
    assert next(p for p in liste if p["id"] == r.json()["id"])["donem"] == "2042-08"


# ============== FINANS-08: mesai gideri kasali ve tekil ==================== #
def test_FINANS08_mesai_gideri_KASALI_ve_ikinci_yazma_409(
        client, world, mesai_duzeni, owner_conn):  # noqa: F811
    h = _h(client, world["slug_a"], world["yonetici_a"])
    govde = {"yil": 2026, "ay": 9, "satirlar": [{"user_id": mesai_duzeni["user_id"]}]}
    r = client.post("/mesai/gidere-yaz", headers=h, json=govde)
    assert r.status_code == 201, r.text
    kasa_id = owner_conn.execute(
        "SELECT kasa_id FROM finansal_hareket WHERE id = %s", (r.json()[0],)
    ).fetchone()[0]
    assert kasa_id is not None, "mesai gideri kasasiz yazildi"
    ikinci = client.post("/mesai/gidere-yaz", headers=h, json=govde)
    assert ikinci.status_code == 409, ikinci.text
    # Reddedilen gider "yazilmis" sayilmaz; yeniden yazilabilir.
    client.post(f"/finans/hareketler/{r.json()[0]}/reddet", headers=h, json={})
    k = next(k for k in _ozet(client, h)["kisiler"]
             if k["user_id"] == mesai_duzeni["user_id"])
    assert k["gidere_yazildi"] is False
    assert client.post("/mesai/gidere-yaz", headers=h, json=govde).status_code == 201


# ============== FINANS-09: iade + iptal birlikte uygulanamaz =============== #
def test_FINANS09_iadeli_tahsilat_IPTAL_edilemez_iptalli_IADE_edilemez(
        client, adm, kasa):
    d = _daire(client, adm)
    t1 = _tahsilat(client, adm, kasa["id"], 80000, unit_id=d["id"]).json()
    assert client.post("/finans/iade", headers=adm, json={
        "hareket_id": t1["id"], "tutar_kurus": 30000}).status_code == 201
    r = client.post(f"/finans/hareketler/{t1['id']}/iptal", headers=adm, json={})
    assert r.status_code == 409, r.text

    t2 = _tahsilat(client, adm, kasa["id"], 5000, unit_id=d["id"]).json()
    assert client.post(f"/finans/hareketler/{t2['id']}/iptal", headers=adm,
                       json={}).status_code == 201
    r = client.post("/finans/iade", headers=adm, json={"hareket_id": t2["id"]})
    assert r.status_code == 409, r.text


def test_FINANS09_virman_bacagi_IADE_edilemez_IPTAL_iki_bacagi_birden_geri_alir(
        client, adm, kasa):
    hedef = client.post("/kasalar", headers=adm, json={
        "kod": f"EV{_sfx()}", "ad": "Virman Hedef"}).json()
    k_once, h_once = _bakiye(client, adm, kasa["id"]), _bakiye(client, adm, hedef["id"])
    bacaklar = client.post("/finans/virman", headers=adm, json={
        "kaynak_kasa_id": kasa["id"], "hedef_kasa_id": hedef["id"],
        "tutar_kurus": 2500}).json()["items"]
    r = client.post("/finans/iade", headers=adm, json={"hareket_id": bacaklar[0]["id"]})
    assert r.status_code == 422, r.text
    r = client.post(f"/finans/hareketler/{bacaklar[0]['id']}/iptal", headers=adm, json={})
    assert r.status_code == 201, r.text
    assert _bakiye(client, adm, kasa["id"]) == k_once
    assert _bakiye(client, adm, hedef["id"]) == h_once
    # Karsi bacak da iptal edilmis sayilir.
    r = client.post(f"/finans/hareketler/{bacaklar[1]['id']}/iptal", headers=adm, json={})
    assert r.status_code == 409, r.text


# ============== FINANS-10: ayni ayin aidati ikinci kez yazilmaz ============ #
def test_FINANS10_tanimli_aidat_varken_TANIMSIZ_toplu_ayni_ayi_ATLAR(client, adm):
    d = _daire(client, adm)
    aidat = client.post("/gelir-gider-tanimlari", headers=adm, json={
        "ad": f"Aidat {_sfx()}", "tip": "gider"}).json()
    _borc(client, adm, d["id"], "2043-09", 175000, gelir_gider_tanim_id=aidat["id"])
    r = client.post("/dues/assessments", headers=adm, json={
        "unit_ids": [d["id"]], "donem": "2043-09", "tutar_kurus": 175000})
    assert r.status_code == 201, r.text
    assert r.json()["olusan"] == 0 and r.json()["atlanan"] == 1
    assert r.json()["atlananlar"][0]["neden"] == "donem_zaten_borclandirildi"
    assert _daire_bakiye(client, adm, d["id"]) == 175000


# ============== FINANS-11/12: gider toplami ve kirilim ===================== #
def test_FINANS11_12_gider_KIRILIMI_toplami_TUTAR_ve_liste_neti_AYRINTIYLA_ayni(
        client, adm, kasa):
    ay = "2044-02"
    satirlar = client.post("/finans/hareketler", headers=adm, json={"satirlar": [
        {"tip": "gider", "tutar_kurus": 70000, "kasa_id": kasa["id"], "tarih": f"{ay}-03"},
        {"tip": "gider", "tutar_kurus": 20000, "kasa_id": kasa["id"], "tarih": f"{ay}-04"},
        {"tip": "gelir", "tutar_kurus": 50000, "kasa_id": kasa["id"], "tarih": f"{ay}-05"},
    ]}).json()["items"]
    # Bir gider SONRAKI ay iptal ediliyor (FINANS-11'in olculen durumu).
    client.post(f"/finans/hareketler/{satirlar[1]['id']}/iptal", headers=adm,
                json={"tarih": "2044-03-02"})
    for m in (ay, "2044-03"):
        b = client.get(f"/transparency/{m}", headers=adm).json()
        assert sum(k["toplam_kurus"] for k in b["gider_dagilimi"]) == b["toplam_gider_kurus"], m
        liste = client.get("/transparency", headers=adm).json()["items"]
        satir = next((x for x in liste if x["ay"] == m), None)
        if satir is not None:
            assert satir["net_kurus"] == b["net_kurus"], m


# ============== FINANS-13 / BILDIRIM-14: hatirlatma metni ================== #
def test_FINANS13_hatirlatma_VADE_TARIH_ve_TUTAR_turkce(client, adm, owner_conn):
    d = _daire(client, adm)
    uid, _ = _sakin(client, adm, owner_conn)
    _bagla(client, adm, d["id"], uid, "malik", oturuyor=True)
    b = _borc(client, adm, d["id"], "2044-05", 150000, gun_once=22)
    r = client.post("/finans/borclulara/hatirlat", headers=adm,
                    json={"unit_ids": [d["id"]]})
    assert r.status_code == 200 and r.json()["gonderilen"] == 1, r.text
    veri = owner_conn.execute(
        "SELECT mesaj_veri, mesaj FROM notification WHERE user_id = %s "
        "AND tip = 'aidat_hatirlatma' ORDER BY created_at DESC LIMIT 1", (uid,)
    ).fetchone()
    vade = date.fromisoformat(b["son_odeme_tarihi"]).strftime("%d.%m.%Y")
    assert veri[0]["vade"] == vade, veri
    assert veri[0]["tutar"] == "1.500,00 ₺", veri
    assert "(son ödeme: 22)" not in veri[1]


# ============== FINANS-14: kasa ekstresi kasa suzgeci ====================== #
def test_FINANS14_kasa_ekstresi_YALNIZ_o_kasa(client, adm, kasa):
    diger = client.post("/kasalar", headers=adm, json={
        "kod": f"EX{_sfx()}", "ad": "Diger"}).json()
    _tahsilat(client, adm, kasa["id"], 1111)
    _tahsilat(client, adm, diger["id"], 2222)
    r = client.post("/raporlar/kasa_ekstresi?bicim=tablo", headers=adm,
                    json={"kasa_id": kasa["id"]})
    assert r.status_code == 200, r.text
    kasalar = {s["kasa"] for s in r.json()["satirlar"]}
    assert kasalar == {"E2E Finans Kasa"}, kasalar
    assert r.json()["toplamlar"]["tutar_kurus"] == _bakiye(client, adm, kasa["id"])


# ============== FINANS-15 / ARAYUZ-4/5: sinir dogrulamalari ================= #
@pytest.mark.parametrize("acilis", [10**20, -100])
def test_FINANS15_kasa_acilisi_SINIRLI_500_degil(client, adm, acilis):
    r = client.post("/kasalar", headers=adm, json={
        "kod": f"EB{_sfx()}", "ad": "Sinir", "acilis_bakiye_kurus": acilis})
    assert r.status_code == 422, r.text


@pytest.mark.parametrize("donem", ["2026-13", "abc", "1900-01", "0000-00"])
def test_FINANS15_gecersiz_DONEM_422(client, adm, donem):
    d = _daire(client, adm)
    r = client.post("/dues/assessments", headers=adm, json={
        "unit_id": d["id"], "donem": donem, "tutar_kurus": 100})
    assert r.status_code == 422, r.text


def test_ARAYUZ5_tahakkuk_1900_son_odeme_422(client, adm):
    d = _daire(client, adm)
    r = client.post("/dues/assessments", headers=adm, json={
        "unit_id": d["id"], "donem": "2045-01", "tutar_kurus": 100,
        "son_odeme_tarihi": "1900-01-01"})
    assert r.status_code == 422, r.text


def test_FINANS15_ileri_tarihli_tahsilat_422(client, adm, kasa):
    r = _tahsilat(client, adm, kasa["id"], 100, tarih="2099-12-31")
    assert r.status_code == 422, r.text


def test_ARAYUZ4_tahakkuk_2_uzeri_31_kurus_500_VERMEZ(client, adm):
    d = _daire(client, adm)
    r = client.post("/dues/assessments", headers=adm, json={
        "unit_id": d["id"], "donem": "2045-02", "tutar_kurus": 2**31})
    assert r.status_code == 201, r.text


# ============== FINANS-21: listede iptal isareti + daire =================== #
def test_FINANS21_hareket_listesi_IPTAL_ISARETI_ve_DAIRE(client, adm, kasa):
    d = _daire(client, adm)
    t = _tahsilat(client, adm, kasa["id"], 4321, unit_id=d["id"]).json()
    client.post(f"/finans/hareketler/{t['id']}/iptal", headers=adm, json={})
    liste = client.get("/finans/hareketler", headers=adm, params={
        "kasa_id": kasa["id"], "limit": 50}).json()["items"]
    satir = next(x for x in liste if x["id"] == t["id"])
    assert satir["iptal_edildi"] is True
    assert satir["unit_no"] == d["no"]


# ============== YETKI-06 / FINANS-19: sakinin gordugu borc ================== #
def test_YETKI06_kiraci_malik_kalemini_GORMEZ_iki_uc_AYNI_borcu_soyler(
        client, world, adm, owner_conn):
    d = _daire(client, adm)
    malik, _ = _sakin(client, adm, owner_conn, "Zeynep Malik")
    kiraci, k_eposta = _sakin(client, adm, owner_conn, "Can Kiraci")
    _bagla(client, adm, d["id"], malik, "malik", oturuyor=False)
    _bagla(client, adm, d["id"], kiraci, "kiraci")
    _borc(client, adm, d["id"], "2046-01", 33300,
          gelir_gider_tanim_id=_tanim(client, adm, "malik"))
    _borc(client, adm, d["id"], "2046-01", 44400,
          gelir_gider_tanim_id=_tanim(client, adm, "kiraci_oncelikli"))
    _borc(client, adm, d["id"], "2046-02", 1000)  # tursuz, daireye yazili

    kh = _h(client, world["slug_a"], {"email": k_eposta, "password": "SakinPass1"})
    dues = client.get("/me/dues", headers=kh).json()["items"]
    bizim = next(i for i in dues if i["unit_id"] == d["id"])
    tutarlar = sorted(a["tutar_kurus"] for a in bizim["assessments"])
    assert tutarlar == [1000, 44400], tutarlar
    assert bizim["bakiye_kurus"] == 45400
    # Kalemde hedef gorunur (FINANS-19).
    hedefli = next(a for a in bizim["assessments"] if a["tutar_kurus"] == 44400)
    assert hedefli["hedef_ad"] == "Can Kiraci"
    odeme = client.get("/me/odeme-bilgileri", headers=kh).json()["borc_kurus"]
    assert odeme == sum(i["bakiye_kurus"] for i in dues), "iki ekran farkli borc"


# ============== TESIS-08: ayrilan sakinin borcu ============================= #
def test_TESIS08_ayrilan_sakinin_borcu_KENDISINDE_kalir_yeni_sakine_GECMEZ(
        client, world, adm, owner_conn):
    d = _daire(client, adm)
    eski, e_eposta = _sakin(client, adm, owner_conn, "Elif Eski")
    _bagla(client, adm, d["id"], eski, "malik", oturuyor=True)
    _borc(client, adm, d["id"], "2046-03", 710000,
          gelir_gider_tanim_id=_tanim(client, adm, "kiraci_oncelikli"))
    assert client.delete(f"/units/{d['id']}/residents/{eski}",
                         headers=adm).status_code in (200, 204)
    yeni, y_eposta = _sakin(client, adm, owner_conn, "Ozgur Yeni")
    _bagla(client, adm, d["id"], yeni, "kiraci")

    yh = _h(client, world["slug_a"], {"email": y_eposta, "password": "SakinPass1"})
    assert client.get("/me/odeme-bilgileri", headers=yh).json()["borc_kurus"] == 0
    eh = _h(client, world["slug_a"], {"email": e_eposta, "password": "SakinPass1"})
    eski_dues = client.get("/me/dues", headers=eh).json()["items"]
    assert sum(i["bakiye_kurus"] for i in eski_dues) == 710000

    # Borcu olan sakin SERT silinmez: borcun sahibi bosalmaz.
    r = client.delete(f"/residents/{eski}", headers=adm)
    assert r.status_code == 200, r.text
    assert r.json()["deleted"] is False
    hedef = owner_conn.execute(
        "SELECT hedef_user_id FROM dues_assessment WHERE unit_id = %s", (d["id"],)
    ).fetchone()[0]
    assert str(hedef) == eski


# ============== TESIS-01: sayac OKUMA -> tuketim sunucuda ================== #
def test_TESIS01_sayac_OKUMA_gonderilince_tuketim_FARK_ve_onceki_okuma_ilerler(
        client, adm):
    gider = client.post("/gelir-gider-tanimlari", headers=adm, json={
        "ad": f"Su {_sfx()}", "tip": "gider"}).json()
    ana = client.post("/sayaclar/ana", headers=adm, json={
        "ad": f"Ana-{_sfx()}", "tip": "su", "ortak_alan_yuzde": 0}).json()
    d = _daire(client, adm)
    s = client.post("/sayaclar/bolum", headers=adm, json={
        "unit_id": d["id"], "ana_sayac_id": ana["id"], "ilk_okuma": 1450}).json()

    govde = {"donem": "2046-05", "gelir_gider_tanim_id": gider["id"],
             "ana_sayac_id": ana["id"], "ana_tuketim": 12,
             "birim_fiyat_kurus": 3550, "bolum_okumalari": {s["id"]: 1462}}
    r = client.post("/borclandirma/sayac", headers=adm, json=govde)
    assert r.status_code == 201, r.text
    # 12 m3 x 35,50 TL = 426 TL (1462 m3 DEGIL).
    assert _daire_bakiye(client, adm, d["id"]) == 12 * 3550

    geri = client.post("/borclandirma/sayac", headers=adm, json={
        **govde, "donem": "2046-06", "bolum_okumalari": {s["id"]: 1455}})
    assert geri.status_code == 422, "onceki okuma ilerlemedi ya da geri sayim kabul edildi"


# ============== ARAYUZ-8 / FINANS-16: rapor ciktisi (saf) =================== #
def test_ARAYUZ8_pdf_glifsiz_karakter_YER_TUTUCU_ve_bos_rapor_cumlesi():
    pytest.importorskip("pypdf")
    from pypdf import PdfReader

    from app import rapor_ciktilari as rc
    from app.raporlar import RaporSonuc, Sutun

    s = RaporSonuc("site_sakinleri", "Site Sakinleri",
                   [Sutun("ad", "Ad Soyad", genislik=3)],
                   [{"ad": "Ayşe 🌸 O'Brien 中文"}])
    metin = "".join(p.extract_text() for p in PdfReader(io.BytesIO(
        rc.pdf_uret(s, "Site", None, None))).pages)
    assert "Ayşe ? O'Brien ??" in metin, metin

    bos = RaporSonuc("x", "Bos", [Sutun("a", "A")], [], {"a": 0})
    metin = "".join(p.extract_text() for p in PdfReader(io.BytesIO(
        rc.pdf_uret(bos, "Site", None, None))).pages)
    assert rc.VERI_YOK in metin
    assert "UTC" not in rc._damga()


def test_FINANS16_excel_grafik_verisi_TABLOYU_kopyalamaz():
    import openpyxl

    from app import rapor_ciktilari as rc
    from app.raporlar import tahsilat_performansi
    from app.routers.rapor_motoru import KATALOG_KAYITLARI

    tp = tahsilat_performansi(
        [{"donem": "2026-08", "borclandirilan": 1000, "tahsil": 500}],
        [{"kova": "0-30 gün", "tutar_kurus": 10}])
    grafik = KATALOG_KAYITLARI["tahsilat_performansi"].grafik
    wb = openpyxl.load_workbook(io.BytesIO(rc.excel_uret(tp, "S", None, None, grafik=grafik)))
    ana = wb.worksheets[0]
    assert ana.max_column == len(tp.sutunlar), "tablo saga ikinci kez yazildi"
    assert wb["grafik_verisi"].sheet_state == "hidden"


def test_BILDIRIM14_tl_ve_tarih_bicimi():
    from app.finans import tarih_metni, tl_metni

    assert tl_metni(150000) == "1.500,00 ₺"
    assert tl_metni(123456789) == "1.234.567,89 ₺"
    assert tarih_metni(date(2026, 9, 1)) == "01.09.2026"
