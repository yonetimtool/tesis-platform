"""(P239 §4) DEVRIYE PLANINDA HAFTALIK GUN SECIMI + BIR KERELIK EK TARIHLER.

===========================================================================
NE OLCULUYOR
===========================================================================
Plan artik "hangi gunler" tasiyor (goc 0139). Bu dosya IKI ayri sey
olcer ve ikisi de gerekli:

  1. UC (API): degerler kabul ediliyor, geri donuyor, gecersizler
     REDDEDILIYOR (bos dizi, aralik disi gun, 60'tan fazla ek tarih).
  2. PENCERE URETICI (saf fonksiyon): secilen gunlerde pencere URETIYOR,
     secilmeyen gunlerde URETMIYOR. Yalniz ucu olcmek, kolonu "kaydedilen
     ama hicbir seye yaramayan" bir alan olarak birakirdi — P239'un kendi
     dersi (`task.son_tarih` tam da oyleydi).
"""
from __future__ import annotations

import datetime as dt
import uuid

from app.scheduler.windows import gun_yuruyor, plan_windows


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _plan_body(**o):
    b = {
        "ad": f"Gece devriyesi {uuid.uuid4().hex[:6]}",
        "baslangic_saat": "22:00:00",
        "bitis_saat": "06:00:00",
        "periyot_dakika": 60,
    }
    b.update(o)
    return b


# ============================== UC (API) ================================== #
def test_gunler_kaydedilir_ve_siralanir(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    # TERS SIRA + TEKRAR gonderilir: sunucu normallestirmeli ki
    # "[4,1]" ile "[1,4]" ayni plan olarak gorunsun (denetim/karsilastirma).
    r = client.post("/patrol-plans", headers=yon, json=_plan_body(gunler=[4, 1, 4]))
    assert r.status_code == 201, r.text
    assert r.json()["gunler"] == [1, 4]


def test_gunler_verilmezse_NULL_yani_HER_GUN(client, world):
    # Eski kayitlarla ayni davranis: gun secilmediyse plan her gun yurur.
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/patrol-plans", headers=yon, json=_plan_body())
    assert r.status_code == 201, r.text
    assert r.json()["gunler"] is None


def test_BOS_DIZI_REDDEDILIR(client, world):
    # Bos dizi "hicbir gun" demek olurdu: plan AKTIF gorunurken hicbir
    # pencere uretmez — kullanicinin goremeyecegi sessiz bir kapali hal.
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/patrol-plans", headers=yon, json=_plan_body(gunler=[]))
    assert r.status_code == 422, r.text


def test_ARALIK_DISI_GUN_REDDEDILIR(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    for gecersiz in ([0], [8], [-1]):
        r = client.post("/patrol-plans", headers=yon, json=_plan_body(gunler=gecersiz))
        assert r.status_code == 422, f"{gecersiz}: {r.text}"


def test_PATCH_ile_HER_GUNE_DONULEBILIR(client, world):
    # `gunler: null` GONDERMEK "her gune don" demektir; alani HIC
    # gondermemek "dokunma" demektir. Ikisi ayrilmazsa bir plani
    # yeniden her gune cevirmek imkansiz olurdu.
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    pid = client.post(
        "/patrol-plans", headers=yon, json=_plan_body(gunler=[1])
    ).json()["id"]

    r = client.patch(f"/patrol-plans/{pid}", headers=yon, json={"ad": "Yeni ad"})
    assert r.status_code == 200 and r.json()["gunler"] == [1], "dokunulmamali"

    r = client.patch(f"/patrol-plans/{pid}", headers=yon, json={"gunler": None})
    assert r.status_code == 200 and r.json()["gunler"] is None


def test_EK_TARIHLER_kaydedilir_ve_sinirlanir(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    # (E2E 2026-09 / GUVENLIK-17) GORELI GELECEK TARIH: sabit "2026-08-30"
    # zamanla gecmise dustu ve gecmis ek gun artik 422 (ayri test).
    ileri = (dt.date.today() + dt.timedelta(days=30)).isoformat()
    r = client.post(
        "/patrol-plans",
        headers=yon,
        json=_plan_body(gunler=[1], ek_tarihler=[ileri, ileri]),
    )
    assert r.status_code == 201, r.text
    assert r.json()["ek_tarihler"] == [ileri], "tekrar tekillestirilmeli"

    # 61 gun -> RED. "Bir kerelik ek gun" bir takvim degildir; sinirsiz
    # birakmak plani somut tarih listesine cevirmenin arka kapisi olurdu.
    cok = [(dt.date.today() + dt.timedelta(days=i + 1)).isoformat() for i in range(61)]
    r = client.post("/patrol-plans", headers=yon, json=_plan_body(ek_tarihler=cok))
    assert r.status_code == 422, r.text


def test_saha_rolu_gun_degistiremez(client, world):
    # Yetki DEGISMEDI: yazma admin + yonetici. Yeni alan yeni bir kapi
    # acmamali.
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    pid = client.post("/patrol-plans", headers=yon, json=_plan_body()).json()["id"]
    guard = _headers(client, world["slug_a"], world["guard_a"])
    r = client.patch(f"/patrol-plans/{pid}", headers=guard, json={"gunler": [1]})
    assert r.status_code == 403, r.text


# ========================= PENCERE URETICI (SAF) ========================== #
def test_gun_yuruyor_kurali():
    pzt = dt.date(2026, 9, 14)   # pazartesi
    sali = dt.date(2026, 9, 15)
    # None = HER GUN (eski kayitlar).
    assert gun_yuruyor(pzt, None, None) and gun_yuruyor(sali, None, None)
    # Secili gun.
    assert gun_yuruyor(pzt, [1, 4], None)
    assert not gun_yuruyor(sali, [1, 4], None)
    # EK TARIH BIRLESIMDIR: haftalik secimin DISINDAKI gun de yurur.
    assert gun_yuruyor(sali, [1], [sali])


def test_secilmeyen_gunde_PENCERE_URETILMEZ():
    # Kolonu kaydedip ureticiyi degistirmemek, alani "kaydedilen ama
    # hicbir seye yaramayan" bir sey birakirdi.
    tz = "Europe/Istanbul"
    # Carsamba 12:00 UTC'den basla; 7 gunluk ufuk.
    simdi = dt.datetime(2026, 9, 16, 12, 0, tzinfo=dt.timezone.utc)
    gunduz_bas, gunduz_bit = dt.time(9, 0), dt.time(17, 0)

    hepsi = plan_windows(tz, simdi, 7, gunduz_bas, gunduz_bit, 60)
    yalniz_pzt = plan_windows(
        tz, simdi, 7, gunduz_bas, gunduz_bit, 60, gunler=[1]
    )
    assert hepsi, "taban olcum bos olmamali"
    assert yalniz_pzt, "pazartesi ufuk icinde olmali"
    assert len(yalniz_pzt) < len(hepsi)
    # Uretilen her pencere PAZARTESI baslamali (yerel gune gore).
    from zoneinfo import ZoneInfo
    for bas, _ in yalniz_pzt:
        assert bas.astimezone(ZoneInfo(tz)).date().isoweekday() == 1


def test_GECE_PLANI_BASLADIGI_GUNE_AITTIR():
    # "Her pazartesi gece devriyesi" 22:00'de pazartesi baslar, sali
    # 06:00'da biter. Sali secilmemis olmasi bu pencereyi DUSURMEMELI.
    from zoneinfo import ZoneInfo
    tz = "Europe/Istanbul"
    simdi = dt.datetime(2026, 9, 13, 12, 0, tzinfo=dt.timezone.utc)  # pazar
    pencereler = plan_windows(
        tz, simdi, 3, dt.time(22, 0), dt.time(6, 0), 60, gunler=[1]
    )
    assert pencereler, "pazartesi gece penceresi uretilmeli"
    # OLCUM DUZELTILDI: ilk yazim "her pencere pazartesi baslar" diyordu
    # ve KIRMIZI verdi — dogru olarak. Plan OLUSUMU pazartesi baslar ama
    # icindeki saatlik pencereler gece yarisini gecip SALI'ya sarkar.
    # Kurali olusum BASLANGICI tasir, tek tek pencereler degil.
    yerel = [b.astimezone(ZoneInfo(tz)) for b, _ in pencereler]
    assert min(yerel).date().isoweekday() == 1, "olusum PAZARTESI baslamali"
    assert min(yerel).hour == 22
    # Hicbir pencere SALI 06:00'dan sonraya tasmamali (yani salı gunu
    # BAGIMSIZ bir olusum uretilmemis).
    for _, bit in pencereler:
        b_yerel = bit.astimezone(ZoneInfo(tz))
        assert (b_yerel.date().isoweekday(), b_yerel.hour) <= (2, 6)


def test_EK_TARIH_secilmeyen_gunde_de_PENCERE_URETIR():
    from zoneinfo import ZoneInfo
    tz = "Europe/Istanbul"
    simdi = dt.datetime(2026, 9, 14, 6, 0, tzinfo=dt.timezone.utc)  # pazartesi
    sali = dt.date(2026, 9, 15)
    yalniz_pzt = plan_windows(tz, simdi, 3, dt.time(9, 0), dt.time(17, 0), 60, gunler=[1])
    artı_sali = plan_windows(
        tz, simdi, 3, dt.time(9, 0), dt.time(17, 0), 60, gunler=[1], ek_tarihler=[sali]
    )
    assert len(artı_sali) > len(yalniz_pzt)
    assert any(
        b.astimezone(ZoneInfo(tz)).date() == sali for b, _ in artı_sali
    )


def test_GECMIS_EK_TARIH_reddedilir_ama_ESKISI_duzenlemeyi_kilitlemez(client, world, owner_conn):
    """(E2E 2026-09 / GUVENLIK-17) `2020-01-01` 201 ile kabul ediliyordu —
    hic yurumeyecek bir gun. Artik 422 ve mesaj tarihi adlandirir.

    Ters yon: DUN gecerli olan ek gun bugun gecmistir; istemci listeyi
    butun olarak geri gonderdiginde plan duzenlenemez hale gelmemeli.
    """
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/patrol-plans", headers=yon,
                    json=_plan_body(ek_tarihler=["2020-01-01"]))
    assert r.status_code == 422, r.text
    assert "2020-01-01" in r.json()["error"]["message"]

    ileri = (dt.date.today() + dt.timedelta(days=10)).isoformat()
    r = client.post("/patrol-plans", headers=yon, json=_plan_body(ek_tarihler=[ileri]))
    assert r.status_code == 201, r.text
    pid = r.json()["id"]
    try:
        # Kaydedilmis tarihi zamanda geriye cek (gecmise dustu varsayimi).
        owner_conn.execute(
            "UPDATE patrol_plan SET ek_tarihler = ARRAY['2020-01-01'::date] WHERE id = %s",
            (pid,),
        )
        r = client.patch(f"/patrol-plans/{pid}", headers=yon,
                         json={"ek_tarihler": ["2020-01-01", ileri]})
        assert r.status_code == 200, r.text
        # YENI gecmis tarih yine reddedilir.
        r = client.patch(f"/patrol-plans/{pid}", headers=yon,
                         json={"ek_tarihler": ["2019-05-05", ileri]})
        assert r.status_code == 422, r.text
    finally:
        client.delete(f"/patrol-plans/{pid}", headers=yon)
