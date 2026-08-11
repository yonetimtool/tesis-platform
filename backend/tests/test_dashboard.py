"""GET /dashboard/live testleri — aktif turlar + sayilar, izolasyon, RBAC, alarm e2e."""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

import pytest

from app.scheduler.service import detect_missed

UTC = timezone.utc
PAST_START = datetime(2029, 12, 31, 0, 0, tzinfo=UTC)
PAST_END = datetime(2029, 12, 31, 1, 0, tzinfo=UTC)
NOW_AFTER = datetime(2030, 1, 1, 0, 0, tzinfo=UTC)


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _checkpoint(client, headers):
    nfc = f"NFC-{uuid.uuid4().hex[:10]}"
    return client.post("/checkpoints", headers=headers, json={"ad": "CP", "nfc_tag_uid": nfc}).json()


def _plan_with_checkpoints(client, headers, cp_ids):
    plan = client.post(
        "/patrol-plans",
        headers=headers,
        json={"ad": "Devriye", "baslangic_saat": "00:00", "bitis_saat": "06:00", "periyot_dakika": 60},
    ).json()
    client.put(
        f"/patrol-plans/{plan['id']}/checkpoints",
        headers=headers,
        json={"items": [{"checkpoint_id": c} for c in cp_ids]},
    )
    return plan


def _ins_window(conn, tid, pid, start, end, durum="bekliyor"):
    wid = uuid.uuid4()
    conn.execute(
        "INSERT INTO patrol_window (id, tenant_id, patrol_plan_id, pencere_baslangic, pencere_bitis, durum) "
        "VALUES (%s,%s,%s,%s,%s,%s)",
        (wid, tid, pid, start, end, durum),
    )
    return wid


def _ins_scan(conn, tid, gid, cid, when):
    conn.execute(
        "INSERT INTO scan_event (tenant_id, guard_id, checkpoint_id, nfc_tag_uid, okutma_zamani, idempotency_key) "
        "VALUES (%s,%s,%s,%s,%s,%s)",
        (tid, gid, cid, "NFC", when, uuid.uuid4().hex),
    )


def test_dashboard_shows_today_windows_with_counts(client, world, owner_conn):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    guard_id = client.get("/me", headers=guard).json()["id"]

    cp1 = _checkpoint(client, admin)
    cp2 = _checkpoint(client, admin)
    plan = _plan_with_checkpoints(client, admin, [cp1["id"], cp2["id"]])

    now = datetime.now(tz=UTC)
    wid = _ins_window(owner_conn, world["a"], plan["id"], now, now + timedelta(hours=1))
    _ins_scan(owner_conn, world["a"], guard_id, cp1["id"], now + timedelta(seconds=1))  # 1/2 okutuldu

    r = client.get("/dashboard/live", headers=admin)
    assert r.status_code == 200, r.text
    body = r.json()
    assert {"generated_at", "aktif_turlar", "alarm_gruplari"} <= set(body)

    tur = next((t for t in body["aktif_turlar"] if t["patrol_window_id"] == str(wid)), None)
    assert tur is not None
    assert tur["patrol_plan_id"] == plan["id"]
    assert tur["patrol_plan_ad"] == "Devriye"
    assert tur["durum"] == "bekliyor"
    assert tur["beklenen_checkpoint_sayisi"] == 2
    assert tur["okutulan_checkpoint_sayisi"] == 1


def test_dashboard_tenant_isolation(client, world, owner_conn):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])

    cp = _checkpoint(client, admin_a)
    plan = _plan_with_checkpoints(client, admin_a, [cp["id"]])
    now = datetime.now(tz=UTC)
    wid = _ins_window(owner_conn, world["a"], plan["id"], now, now + timedelta(hours=1))

    # B'nin paneli A'nin penceresini gormez
    body_b = client.get("/dashboard/live", headers=admin_b).json()
    assert all(t["patrol_window_id"] != str(wid) for t in body_b["aktif_turlar"])


def test_dashboard_rbac(client, world):
    # security -> 200 (matris), resident -> 403
    sec = _headers(client, world["slug_a"], world["guard_a"])
    res = _headers(client, world["slug_a"], world["resident_a"])
    assert client.get("/dashboard/live", headers=sec).status_code == 200
    r = client.get("/dashboard/live", headers=res)
    assert r.status_code == 403 and r.json()["error"]["code"] == "forbidden"


def test_dashboard_alarm_limit_validation(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    assert client.get("/dashboard/live", headers=admin, params={"alarm_limit": 0}).status_code == 422
    assert client.get("/dashboard/live", headers=admin, params={"alarm_limit": 5}).status_code == 200


def test_e2e_missed_tour_appears_in_dashboard_alarms(client, world, owner_conn):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    cp = _checkpoint(client, admin)
    plan = _plan_with_checkpoints(client, admin, [cp["id"]])
    # gecmis pencere, scan YOK -> detect ile kacirildi
    wid = _ins_window(owner_conn, world["a"], plan["id"], PAST_START, PAST_END)

    detect_missed(now=NOW_AFTER)

    body = client.get("/dashboard/live", headers=admin).json()
    # (P133.3) Alarmlar artik GRUPLU doner; olay grubun icinde durur.
    olaylar = [o for g in body["alarm_gruplari"] for o in g["olaylar"]]
    olay = next((o for o in olaylar if o["patrol_window_id"] == str(wid)), None)
    assert olay is not None
    grup = next(g for g in body["alarm_gruplari"] if olay in g["olaylar"])
    assert grup["tip"] == "kacirilan_tur"
    assert grup["patrol_plan_id"] == plan["id"]
    assert grup["patrol_plan_ad"] == "Devriye"
    assert grup["mesaj"]


def test_dashboard_alarm_mesaji_istegin_dilinde(client, world, owner_conn):
    """TUR 62: alarm metni ISTEGIN dilinde uretilir.

    Kayit tur 16'dan beri metin degil KIMLIK tasiyor (`mesaj_kimlik` +
    `mesaj_veri`) — "ilk yazanin dili kalici olmasin" diye. `/notifications`
    bunu kullaniyordu ama `/dashboard/live` DEPRECATED `mesaj` kolonunu
    donuyordu; panonun alarm listesi alti dilde Turkce goruntuluyordu.
    """
    admin = _headers(client, world["slug_a"], world["admin_a"])
    cp = _checkpoint(client, admin)
    plan = _plan_with_checkpoints(client, admin, [cp["id"]])
    _ins_window(owner_conn, world["a"], plan["id"], PAST_START, PAST_END)
    detect_missed(now=NOW_AFTER)

    def mesajlar(dil: str) -> list[str]:
        h = dict(admin)
        h["Accept-Language"] = dil
        body = client.get("/dashboard/live", headers=h).json()
        return [g["mesaj"] for g in body["alarm_gruplari"]]

    tr, en, de = mesajlar("tr"), mesajlar("en"), mesajlar("de")
    assert tr and en and de
    # Ayni kayit, UC AYRI metin: ceviri okuma aninda uretiliyor.
    assert any("kaçırıldı" in m for m in tr), tr
    assert any("was missed" in m for m in en), en
    assert any("verpasst" in m for m in de), de
    # Ve Ingilizce yanitta TURKCE metin KALMAMALI (eski davranisin nobetcisi).
    assert not any("kaçırıldı" in m for m in en), en


# --------------------------- (P133.3) TOPLAMA ------------------------------ #
#
# SIKAYET: pano alti neredeyse AYNI satiri yan yana ciziyordu
# ("E-Devriye turunda N dakikadir okutma yok" x 6). Sebep veri modelinde:
# `notification`da (tenant, tip, pencere) TEKIL, yani bir planin alti
# penceresi alti satir uretir. Yonetici icin bunlar TEK olgudur.
#
# Asagidaki testler o durumu GERCEKTEN uretir (alti pencere + detect) ve
# gruplanip gruplanmadigini olcer — "gruplama kodu var mi" degil.


def _alti_kacirilan_pencere(client, world, owner_conn, plan_ad="E-Devriye"):
    """Ayni planin ALTI kacirilmis penceresi -> alti alarm.

    URETTIGI PENCERE KIMLIKLERINI DE DONER: cagiran "bu plandaki TUM
    alarmlar" yerine "BENIM ekledigim pencereler" uzerinden iddia
    kurabilsin diye. Gerekcesi
    `test_ayni_planin_alti_alarmi_TEK_GRUBA_dusuyor` icinde.
    """
    admin = _headers(client, world["slug_a"], world["admin_a"])
    cp = _checkpoint(client, admin)
    plan = client.post(
        "/patrol-plans",
        headers=admin,
        json={"ad": plan_ad, "baslangic_saat": "00:00", "bitis_saat": "06:00",
              "periyot_dakika": 60},
    ).json()
    client.put(
        f"/patrol-plans/{plan['id']}/checkpoints",
        headers=admin,
        json={"items": [{"checkpoint_id": cp["id"]}]},
    )
    pencereler = [
        _ins_window(
            owner_conn,
            world["a"],
            plan["id"],
            PAST_START + timedelta(hours=saat),
            PAST_START + timedelta(hours=saat, minutes=59),
        )
        for saat in range(6)
    ]
    detect_missed(now=NOW_AFTER)
    return admin, plan, pencereler


def test_ayni_planin_alti_alarmi_TEK_GRUBA_dusuyor(client, world, owner_conn):
    """Ayni planin alarmlari TEK grupta toplanir.

    IDDIA SAYIYA DEGIL KIMLIGE DAYANIR — ve bu bir gevsetme degil,
    KUSUR DUZELTMESIDIR.

    Eski hâli `sayi == 6` diyordu; bu, "bu planin TEK pencere kaynagi
    benim" varsayimiydi ve YANLISTI: beat'in `generate_patrol_windows`
    gorevi ayni plan icin 12 pencere daha uretiyor (bugun + yarin x 6) ve
    `NOW_AFTER` cok ileri bir tarih oldugu icin onlar da "kacirilmis"
    sayiliyor. Test tam takimda 6 yerine 18 gorup dustu (rapor §4.46).

    Testin ASIL iddiasi zaten sayi degildi: "alti alarm ALTI GRUP degil
    TEK grup olur". Asagidaki uc olcum onu sayidan bagimsiz kurar.

    URETICI BURADA TAKLIT EDILIYOR: yarisin kazara olusmasini beklemek
    yerine fazladan pencereler BILEREK ekleniyor. Boylece test, bagimsiz
    oldugunu HER kosumda KANITLIYOR — yaris penceresi kucuk oldugu icin
    "gecti" demek yeterli degildi.
    """
    admin, plan, pencereler = _alti_kacirilan_pencere(client, world, owner_conn)

    # Beat'in uretecegi pencerelerin taklidi (farkli zaman araligi,
    # ayni plan). Bunlar da gecmiste ve `bekliyor` oldugu icin ayni
    # `detect_missed` cagrisinda kacirilmis sayilirlar.
    for saat in range(12):
        _ins_window(
            owner_conn,
            world["a"],
            plan["id"],
            PAST_START - timedelta(hours=saat + 1),
            PAST_START - timedelta(hours=saat, minutes=1),
        )
    detect_missed(now=NOW_AFTER)

    body = client.get("/dashboard/live", headers=admin, params={"alarm_limit": 100}).json()
    gruplar = [g for g in body["alarm_gruplari"] if g["patrol_plan_id"] == plan["id"]]

    # (1) GRUPLAMA IDDIASI: 18 alarm da TEK grupta.
    assert len(gruplar) == 1, f"tek grup bekleniyordu, {len(gruplar)} geldi"
    g = gruplar[0]

    # (2) BENIM pencerelerimin HEPSI o grupta.
    gorulen = {o["patrol_window_id"] for o in g["olaylar"]}
    eksik = {str(w) for w in pencereler} - gorulen
    assert not eksik, f"eklenen pencereler grupta yok: {eksik}"

    # (3) IC TUTARLILIK: `sayi` olay sayisiyla ayni olmali.
    assert g["sayi"] == len(g["olaylar"]), (g["sayi"], len(g["olaylar"]))

    assert g["patrol_plan_ad"] == "E-Devriye"
    assert g["tip"] == "kacirilan_tur"


def test_grup_EN_SON_zamani_olaylarin_en_yenisi(client, world, owner_conn):
    admin, plan, _ = _alti_kacirilan_pencere(client, world, owner_conn, "Zaman Devriyesi")
    g = next(
        x for x in client.get(
            "/dashboard/live", headers=admin, params={"alarm_limit": 100}
        ).json()["alarm_gruplari"] if x["patrol_plan_id"] == plan["id"]
    )
    zamanlar = [o["olusma_zamani"] for o in g["olaylar"]]
    assert g["en_son"] == max(zamanlar), (g["en_son"], zamanlar)


def test_FARKLI_PLANLAR_ayri_gruplarda(client, world, owner_conn):
    """Gruplama (tip, DEVRIYE) ikilisiyle — hepsini tek yigina atmaz."""
    admin, plan1, _ = _alti_kacirilan_pencere(client, world, owner_conn, "A Devriyesi")
    _, plan2, _ = _alti_kacirilan_pencere(client, world, owner_conn, "B Devriyesi")
    gruplar = client.get(
        "/dashboard/live", headers=admin, params={"alarm_limit": 100}
    ).json()["alarm_gruplari"]
    kimlikler = [g["patrol_plan_id"] for g in gruplar]
    assert plan1["id"] in kimlikler and plan2["id"] in kimlikler
    assert kimlikler.count(plan1["id"]) == 1
    assert kimlikler.count(plan2["id"]) == 1


def test_ONEM_tipe_gore(client, world, owner_conn):
    admin, plan, _ = _alti_kacirilan_pencere(client, world, owner_conn, "Onem Devriyesi")
    g = next(
        x for x in client.get(
            "/dashboard/live", headers=admin, params={"alarm_limit": 100}
        ).json()["alarm_gruplari"] if x["patrol_plan_id"] == plan["id"]
    )
    # Tur tamamen kacirildi => sahada kimse yok => en yuksek onem.
    assert g["onem"] == "yuksek"


def test_OLAY_govdesinde_tip_ve_plan_TEKRARLANMIYOR(client, world, owner_conn):
    """Gruplamanin govde kazanci: tekrar eden alanlar olaydan CIKTI.

    Bu alanlar olay basina da donseydi gruplama gorsel bir duzenleme
    olurdu; olculen sey KUCULMENIN GERCEK oldugudur.
    """
    admin, plan, _ = _alti_kacirilan_pencere(client, world, owner_conn, "Govde Devriyesi")
    g = next(
        x for x in client.get(
            "/dashboard/live", headers=admin, params={"alarm_limit": 100}
        ).json()["alarm_gruplari"] if x["patrol_plan_id"] == plan["id"]
    )
    for o in g["olaylar"]:
        assert "tip" not in o
        assert "patrol_plan_id" not in o
        assert "patrol_plan_ad" not in o
        # `mesaj` EN BUYUK alandi ve grup icinde neredeyse ayni cumlenin
        # tekrariydi; temsili metin grupta bir kez duruyor.
        assert "mesaj" not in o
    assert g["mesaj"]


def test_TENANT_YALITIMI_gruplarda_da_gecerli(client, world, owner_conn):
    admin_a, plan, _ = _alti_kacirilan_pencere(client, world, owner_conn, "Yalitim Devriyesi")
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    gruplar_b = client.get(
        "/dashboard/live", headers=admin_b, params={"alarm_limit": 100}
    ).json()["alarm_gruplari"]
    assert all(g["patrol_plan_id"] != plan["id"] for g in gruplar_b)


def test_ALARM_LIMIT_olay_sayisina_uygulanir(client, world, owner_conn):
    """LIMIT gruplara degil OLAYLARA uygulanir.

    "Son 20 grup" ile "son 20 olay" farkli seylerdir; ikincisi secildi ki
    limit gruplama oncesi/sonrasi AYNI anlami tasisin.
    """
    admin, plan, _ = _alti_kacirilan_pencere(client, world, owner_conn, "Limit Devriyesi")
    body = client.get("/dashboard/live", headers=admin, params={"alarm_limit": 3}).json()
    toplam_olay = sum(len(g["olaylar"]) for g in body["alarm_gruplari"])
    assert toplam_olay == 3, toplam_olay
    assert sum(g["sayi"] for g in body["alarm_gruplari"]) == 3


def test_GOVDE_KUCULDU_gruplama_gorsel_duzenleme_degil(client, world, owner_conn):
    """Kisit: "toplama govdeyi KUCULTUR, buyutmez."

    Iki sayi AYNI olay kumesini olcer: yeni bicim uctan alinir, eski bicim
    ayni olaylardan `son_alarmlar` duz listesi olarak yeniden kurulur. Aksi
    hâlde "kucuk govde" iddiasi az veri dondurmekten de gelebilirdi.

    KAZANC NEREDEN: olay basina tekrar eden `tip` (~30 bayt) ve
    `patrol_window_id` (36 karakterlik UUID + alan adi) grubun ustune tek
    kez cikti.
    """
    admin, _, _ = _alti_kacirilan_pencere(client, world, owner_conn, "Olcum Devriyesi")
    yeni = client.get(
        "/dashboard/live", headers=admin, params={"alarm_limit": 100}
    ).json()

    eski_alarmlar = [
        {
            "tip": g["tip"],
            "olusma_zamani": o["olusma_zamani"],
            "mesaj": g["mesaj"],
            "patrol_window_id": o["patrol_window_id"],
            "checkpoint_id": o["checkpoint_id"],
        }
        for g in yeni["alarm_gruplari"]
        for o in g["olaylar"]
    ]
    eski = {
        "generated_at": yeni["generated_at"],
        "aktif_turlar": yeni["aktif_turlar"],
        "son_alarmlar": eski_alarmlar,
    }

    import json

    eski_bayt = len(json.dumps(eski, separators=(",", ":")).encode())
    yeni_bayt = len(json.dumps(yeni, separators=(",", ":")).encode())
    # Olcum bos kume uzerinde yapilmasin (0 == 0 ile gecerdi).
    assert len(eski_alarmlar) >= 6, len(eski_alarmlar)
    assert yeni_bayt < eski_bayt, (
        f"gruplama govdeyi BUYUTTU: eski {eski_bayt} -> yeni {yeni_bayt}"
    )
    print(
        f"\n[P133.3 GOVDE] olay={len(eski_alarmlar)} "
        f"grup={len(yeni['alarm_gruplari'])} "
        f"eski={eski_bayt}B yeni={yeni_bayt}B "
        f"fark={eski_bayt - yeni_bayt:+d}B "
        f"({100 * (eski_bayt - yeni_bayt) / eski_bayt:.1f}% kucultme)"
    )


# ------------------- (P133.2) MALI ALAN ROL KAPISI ------------------------- #
#
# `/dashboard/live` guvenlik rollerine de acik. Aidat tahsilat orani MALI
# veridir ve guvenlik gorevlisinin isi degildir. Bu blok o kapiyi IKI YONDE
# olcer — "yonetici goruyor" tek basina yetmez, asil soru "guvenlik
# gormuyor mu".


def test_TAHSILAT_ORANI_yoneticiye_gorunur(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    body = client.get("/dashboard/live", headers=admin).json()
    assert "aidat_tahsilat_orani" in body
    # Tahakkuk yoksa `null` olur; alan VARLIGI olculuyor.
    assert body["aidat_tahsilat_orani"] is None or isinstance(
        body["aidat_tahsilat_orani"], int
    )


@pytest.mark.parametrize("kim", ["guard_a", "amir_a"])
def test_TAHSILAT_ORANI_guvenlik_rollerine_NULL(client, world, kim):
    h = _headers(client, world["slug_a"], world[kim])
    r = client.get("/dashboard/live", headers=h)
    assert r.status_code == 200, r.text
    assert r.json()["aidat_tahsilat_orani"] is None, (
        "guvenlik rolu MALI veriyi goruyor"
    )


def test_MALI_GORUNURLUK_pano_ve_raporlarda_AYNI():
    """(P133.6) "Kim parayi gorur" TEK yerde tanimli.

    P133.2'de panoya mali alan eklerken kumeyi ayri bir literal olarak
    yazmistim ve yorumuna "reports.py'den alinir" diye not dusmustum —
    yorum tek kaynak vaat ediyor, kod kopyaliyordu.

    AYRISMANIN BEDELI SESSIZDIR: biri `denetci`yi bir tarafa eklerse
    denetci raporlarda tahsilati gorur ama panoda goremez; hicbir test
    dusmez. Bu test o sessizligi bozar.
    """
    from app.roller import MALI_GORUNURLUK
    from app.routers import dashboard, reports

    assert reports._YONETIM is MALI_GORUNURLUK
    # Pano da AYNI nesneyi okur (kendi kopyasini tutmaz).
    kaynak = (
        __import__("pathlib").Path(dashboard.__file__).read_text(encoding="utf8")
    )
    assert "MALI_GORUNURLUK" in kaynak
    assert "_MALI_ROLLER" not in kaynak, "pano kendi kopyasini geri koymus"
