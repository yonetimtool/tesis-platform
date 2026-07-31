"""Tur butunlugu (P34) — konum durumu, gecikme alarmi, baslangic fotografi."""
from __future__ import annotations

import uuid
from datetime import datetime, time, timedelta, timezone
from types import SimpleNamespace

import pytest

from app.scheduler import service
from app.scheduler.service import detect_gecikmis
from app.tur_alarm import alarm_gecikmeleri, gecen_dakika, vadesi_gelen_adim

UTC = timezone.utc
W_START = datetime(2029, 12, 31, 0, 0, tzinfo=UTC)
W_END = datetime(2029, 12, 31, 1, 0, tzinfo=UTC)


# ============================ SAF CEKIRDEK ================================== #
def test_araliklar_KATLANIR(): 
    """Sabit aralik dakikada bir titreyen bir cihaz uretirdi; tek bildirim ise
    telefon sessizdeyse kaybolurdu."""
    assert alarm_gecikmeleri(10, 3) == [
        timedelta(minutes=10), timedelta(minutes=30), timedelta(minutes=70)]
    assert alarm_gecikmeleri(10, 0) == [], "0 tekrar = alarm KAPALI"
    assert alarm_gecikmeleri(0, 3) == []


def test_EN_SON_vadesi_gelen_adim_doner():
    """Scheduler duraksadiysa biriken alarmlari TOPTAN gondermek, gorevliye
    ayni saniyede uc bildirim atmak olurdu."""
    k = dict(pencere_baslangic=W_START, pencere_bitis=W_START + timedelta(hours=3),
             tolerans_dk=10, tekrar=3)
    assert vadesi_gelen_adim(simdi=W_START + timedelta(minutes=9), **k) is None
    assert vadesi_gelen_adim(simdi=W_START + timedelta(minutes=10), **k) == 0
    assert vadesi_gelen_adim(simdi=W_START + timedelta(minutes=29), **k) == 0
    assert vadesi_gelen_adim(simdi=W_START + timedelta(minutes=30), **k) == 1
    # 100. dakikada bile SON adim doner (birikmis 0/1/2 degil).
    assert vadesi_gelen_adim(simdi=W_START + timedelta(minutes=100), **k) == 2


def test_pencere_bitince_alarm_YOK():
    """Bitmis pencere artik 'gecikmis' degil KACIRILMIStir; ikisini birden
    gondermek ayni olayi iki kez bildirmek olurdu."""
    assert vadesi_gelen_adim(
        pencere_baslangic=W_START, pencere_bitis=W_END,
        simdi=W_END, tolerans_dk=10, tekrar=3) is None
    assert vadesi_gelen_adim(
        pencere_baslangic=W_START, pencere_bitis=W_END,
        simdi=W_END + timedelta(hours=5), tolerans_dk=10, tekrar=3) is None


def test_gecen_dakika_asagi_yuvarlar():
    assert gecen_dakika(W_START, W_START + timedelta(seconds=119)) == 1
    assert gecen_dakika(W_START, W_START - timedelta(minutes=5)) == 0


# ============================ KONUM DURUMU ================================== #
def _headers(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _cp(client, headers) -> dict:
    r = client.post("/checkpoints", headers=headers,
                    json={"ad": "CP", "nfc_tag_uid": f"NFC-{uuid.uuid4().hex[:10]}"})
    assert r.status_code == 201, r.text
    return r.json()


def _gonder(client, guard, nfc, **extra):
    govde = {"nfc_tag_uid": nfc,
             "okutma_zamani": datetime.now(UTC).isoformat()}
    govde.update(extra)
    return client.post("/scans", json=govde,
                       headers={**guard, "Idempotency-Key": uuid.uuid4().hex})


@pytest.fixture
def saha(client, world):
    return SimpleNamespace(
        admin=_headers(client, world["slug_a"], world["admin_a"]),
        guard=_headers(client, world["slug_a"], world["guard_a"]),
    )


def test_ESKI_ISTEMCI_bilinmiyor_olur_izin_yok_DEGIL(client, saha):
    """Alan gonderilmemesini 'izin_yok' saymak, OLMAYAN bir izin reddini
    raporlamak olurdu."""
    cp = _cp(client, saha.admin)
    r = _gonder(client, saha.guard, cp["nfc_tag_uid"])
    assert r.status_code == 201, r.text
    assert r.json()["konum_durumu"] == "bilinmiyor"


def test_koordinat_varsa_var_TURETILIR(client, saha):
    cp = _cp(client, saha.admin)
    r = _gonder(client, saha.guard, cp["nfc_tag_uid"], gps_lat=41.0, gps_lng=29.0)
    assert r.json()["konum_durumu"] == "var"


def test_IZIN_YOK_kaydi_DUSURMEZ(client, saha):
    """Konum izni reddedildiginde okutmayi reddetmek, gorevlinin isini
    yapmasini engellerdi; sessizce konumsuz yazmak ise BOSLUGU GIZLERDI."""
    cp = _cp(client, saha.admin)
    r = _gonder(client, saha.guard, cp["nfc_tag_uid"], konum_durumu="izin_yok")
    assert r.status_code == 201, r.text
    assert r.json()["konum_durumu"] == "izin_yok"
    assert r.json()["gps_lat"] is None


def test_var_dendi_koordinat_yok_422(client, saha):
    cp = _cp(client, saha.admin)
    r = _gonder(client, saha.guard, cp["nfc_tag_uid"], konum_durumu="var")
    assert r.status_code == 422, r.text


def test_DOGRULUK_ayri_alan(client, saha):
    """5 m ile 2 km dogruluk ekranda AYNI gorunurdu; ikincisi kanit degeri
    tasimaz."""
    cp = _cp(client, saha.admin)
    r = _gonder(client, saha.guard, cp["nfc_tag_uid"],
                gps_lat=41.0, gps_lng=29.0, gps_dogruluk_m=1850.5)
    assert r.json()["gps_dogruluk_m"] == 1850.5


def test_konum_IDEMPOTENCY_govdesinin_parcasi(client, saha):
    """Ayni anahtarla once konumsuz sonra konumlu gondermek SESSIZCE
    yutulmamali."""
    cp = _cp(client, saha.admin)
    key = uuid.uuid4().hex
    zaman = datetime.now(UTC).isoformat()
    temel = {"nfc_tag_uid": cp["nfc_tag_uid"], "okutma_zamani": zaman}
    h = {**saha.guard, "Idempotency-Key": key}
    assert client.post("/scans", headers=h, json=temel).status_code == 201
    assert client.post("/scans", headers=h, json=temel).status_code == 200
    r = client.post("/scans", headers=h, json={
        **temel, "konum_durumu": "izin_yok"})
    assert r.status_code == 409, r.text


def test_raporda_KONUMSUZ_SAYISI_ve_suzgec(client, saha):
    """Amir 'kac okutma konumsuz' sorusunu satirlari tek tek acmadan
    yanitlayabilmeli."""
    cp = _cp(client, saha.admin)
    _gonder(client, saha.guard, cp["nfc_tag_uid"], gps_lat=41.0, gps_lng=29.0)
    _gonder(client, saha.guard, cp["nfc_tag_uid"], konum_durumu="izin_yok")
    _gonder(client, saha.guard, cp["nfc_tag_uid"])

    tam = client.get("/scans", headers=saha.admin).json()
    assert tam["konumsuz_sayisi"] >= 2
    durumlar = {i["konum_durumu"] for i in tam["items"]}
    assert {"var", "izin_yok", "bilinmiyor"} <= durumlar

    suzulmus = client.get("/scans", headers=saha.admin,
                          params={"konumsuz": True}).json()
    assert all(i["konum_durumu"] != "var" for i in suzulmus["items"])
    # SAYI SUZGECTEN BAGIMSIZ: daraltilmis listede de ayni kalir.
    assert suzulmus["konumsuz_sayisi"] == tam["konumsuz_sayisi"]


# ========================= BASLANGIC FOTOGRAFI ============================== #
def test_foto_KAPALIYKEN_hicbir_sey_degismez(client, saha):
    cp = _cp(client, saha.admin)
    assert client.get("/tenant/settings", headers=saha.admin).json()[
        "tur_baslangic_foto_zorunlu"] is False
    assert _gonder(client, saha.guard, cp["nfc_tag_uid"]).status_code == 201


def test_foto_ayari_YONETICI_tarafindan_degistirilebilir(client, world):
    """Esik degisikligini platform operatorune birakmak, her ayari destek
    talebine cevirirdi."""
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.patch("/tenant/settings", headers=y, json={
        "tur_gecikme_toleransi_dk": 25, "tur_alarm_tekrar_sayisi": 2,
        "tur_baslangic_foto_zorunlu": True})
    assert r.status_code == 200, r.text
    assert r.json()["tur_gecikme_toleransi_dk"] == 25
    # geri al (diger testler etkilenmesin)
    client.patch("/tenant/settings", headers=y, json={
        "tur_gecikme_toleransi_dk": 10, "tur_alarm_tekrar_sayisi": 3,
        "tur_baslangic_foto_zorunlu": False})


def test_ayar_SINIRLARI(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    assert client.patch("/tenant/settings", headers=y, json={
        "tur_gecikme_toleransi_dk": 0}).status_code == 422
    assert client.patch("/tenant/settings", headers=y, json={
        "tur_alarm_tekrar_sayisi": 11}).status_code == 422
    # 0 tekrar GECERLIDIR (alarm kapali).
    assert client.patch("/tenant/settings", headers=y, json={
        "tur_alarm_tekrar_sayisi": 0}).status_code == 200
    client.patch("/tenant/settings", headers=y,
                 json={"tur_alarm_tekrar_sayisi": 3})


def test_foto_KAPISI_yalniz_ILK_okutmada(client, world, owner_conn):
    """Her noktada fotograf istemek turu iki katina cikarirdi ve gorevliyi
    cezalandirirdi."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    cp = _cp(client, admin)
    me = client.get("/me", headers=admin).json()
    tid = me["tenant_id"]

    # Plan + pencere: kapi YALNIZ bir tur penceresi icinde calisir.
    pid = uuid.uuid4()
    owner_conn.execute(
        "INSERT INTO patrol_plan (id, tenant_id, ad, baslangic_saat, bitis_saat, "
        "periyot_dakika) VALUES (%s,%s,%s,%s,%s,%s)",
        (pid, tid, "Foto Plan", time(0, 0), time(23, 0), 60))
    owner_conn.execute(
        "INSERT INTO patrol_plan_checkpoint (tenant_id, patrol_plan_id, "
        "checkpoint_id, sira) VALUES (%s,%s,%s,0)", (tid, pid, cp["id"]))
    simdi = datetime.now(UTC)
    owner_conn.execute(
        "INSERT INTO patrol_window (id, tenant_id, patrol_plan_id, "
        "pencere_baslangic, pencere_bitis, durum) "
        "VALUES (%s,%s,%s,%s,%s,'bekliyor')",
        (uuid.uuid4(), tid, pid, simdi - timedelta(minutes=5),
         simdi + timedelta(hours=2)))

    client.patch("/tenant/settings", headers=y,
                 json={"tur_baslangic_foto_zorunlu": True})
    try:
        r = _gonder(client, guard, cp["nfc_tag_uid"])
        assert r.status_code == 422, r.text
        # AYRI KOD: istemci "fotograf cek ve tekrar gonder" eylemini
        # genel bir dogrulama hatasindan ayirt edebilmeli.
        assert r.json()["error"]["code"] == "foto_gerekli"

        # Fotografla gecer.
        r2 = _gonder(client, guard, cp["nfc_tag_uid"],
                     foto_key=f"{tid}/tur/{uuid.uuid4().hex}.jpg")
        assert r2.status_code == 201, r2.text

        # ILK okutma yapildi -> ayni pencerede sonraki okutmalar fotografsiz.
        assert _gonder(client, guard, cp["nfc_tag_uid"]).status_code == 201

        # Baska tenant'in objesi tur kaniti diye baglanamaz (IDOR).
        r3 = _gonder(client, guard, cp["nfc_tag_uid"],
                     foto_key=f"{uuid.uuid4()}/tur/x.jpg")
        assert r3.status_code == 422
        assert r3.json()["error"]["code"] == "invalid_foto_key"
    finally:
        client.patch("/tenant/settings", headers=y,
                     json={"tur_baslangic_foto_zorunlu": False})
        owner_conn.execute("DELETE FROM patrol_plan WHERE id = %s", (pid,))


def test_foto_kapisi_PENCERE_DISINDA_calismaz(client, world):
    """Plansiz/pencere disi okutma bir TUR BASLANGICI degildir; orada
    fotograf istemek gorevliyi anlamsizca engellerdi."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    cp = _cp(client, admin)
    client.patch("/tenant/settings", headers=y,
                 json={"tur_baslangic_foto_zorunlu": True})
    try:
        assert _gonder(client, guard, cp["nfc_tag_uid"]).status_code == 201
    finally:
        client.patch("/tenant/settings", headers=y,
                     json={"tur_baslangic_foto_zorunlu": False})


# ====================== GECIKME ALARMI (scheduler) ========================== #
def _tenant(conn, tolerans=10, tekrar=3) -> uuid.UUID:
    tid = uuid.uuid4()
    conn.execute(
        "INSERT INTO tenant (id, ad, slug, timezone, tur_gecikme_toleransi_dk, "
        "tur_alarm_tekrar_sayisi) VALUES (%s,%s,%s,%s,%s,%s)",
        (tid, "Alarm", f"alarm-{tid.hex[:10]}", "Europe/Istanbul", tolerans, tekrar),
    )
    return tid


def _guard(conn, tid) -> uuid.UUID:
    gid = uuid.uuid4()
    conn.execute(
        "INSERT INTO app_user (id, tenant_id, ad, email, password_hash, role) "
        "VALUES (%s,%s,%s,%s,%s,%s::user_role)",
        (gid, tid, "Guard", f"g-{gid.hex[:8]}@x.com", "x", "security"),
    )
    return gid


def _kurulum(conn, tid, *, shift_id=None):
    pid, cid = uuid.uuid4(), uuid.uuid4()
    conn.execute(
        "INSERT INTO patrol_plan (id, tenant_id, ad, shift_id, baslangic_saat, "
        "bitis_saat, periyot_dakika) VALUES (%s,%s,%s,%s,%s,%s,%s)",
        (pid, tid, "Gece Turu", shift_id, time(0, 0), time(6, 0), 60),
    )
    conn.execute(
        "INSERT INTO checkpoint (id, tenant_id, ad, nfc_tag_uid) VALUES (%s,%s,%s,%s)",
        (cid, tid, "CP", f"N-{cid.hex[:10]}"),
    )
    conn.execute(
        "INSERT INTO patrol_plan_checkpoint (tenant_id, patrol_plan_id, "
        "checkpoint_id, sira) VALUES (%s,%s,%s,0)", (tid, pid, cid))
    wid = uuid.uuid4()
    conn.execute(
        "INSERT INTO patrol_window (id, tenant_id, patrol_plan_id, "
        "pencere_baslangic, pencere_bitis, durum) VALUES (%s,%s,%s,%s,%s,'bekliyor')",
        (wid, tid, pid, W_START, W_END),
    )
    return SimpleNamespace(pid=pid, cid=cid, wid=wid)


@pytest.fixture
def alarm_spy(monkeypatch):
    kayit: list[dict] = []

    def _sahte(**kw):
        kayit.append(kw)
        return True

    monkeypatch.setattr(service, "notify_gecikmis_okutma", _sahte)
    return kayit


@pytest.fixture
def alarm_dunyasi(owner_conn):
    tid = _tenant(owner_conn)
    gid = _guard(owner_conn, tid)
    yield SimpleNamespace(tid=tid, gid=gid, conn=owner_conn)
    owner_conn.execute("DELETE FROM tenant WHERE id = %s", (tid,))


def test_tolerans_ICINDE_alarm_YOK(alarm_dunyasi, alarm_spy):
    _kurulum(alarm_dunyasi.conn, alarm_dunyasi.tid)
    detect_gecikmis(now=W_START + timedelta(minutes=9))
    assert alarm_spy == []


def test_tolerans_ASILINCA_alarm(alarm_dunyasi, alarm_spy):
    k = _kurulum(alarm_dunyasi.conn, alarm_dunyasi.tid)
    detect_gecikmis(now=W_START + timedelta(minutes=12))
    benim = [a for a in alarm_spy if a["window_id"] == k.wid]
    assert len(benim) == 1
    assert benim[0]["adim"] == 0
    assert benim[0]["dakika"] == 12
    assert benim[0]["plan_adi"] == "Gece Turu"


def test_ILK_OKUTMA_alarmi_DURDURUR(alarm_dunyasi, alarm_spy):
    """Alarmin amaci damgalamak degil TURU BASLATMAKTIR — baslayinca susar."""
    k = _kurulum(alarm_dunyasi.conn, alarm_dunyasi.tid)
    alarm_dunyasi.conn.execute(
        "INSERT INTO scan_event (tenant_id, guard_id, checkpoint_id, nfc_tag_uid, "
        "okutma_zamani, idempotency_key) VALUES (%s,%s,%s,%s,%s,%s)",
        (alarm_dunyasi.tid, alarm_dunyasi.gid, k.cid, "NFC",
         W_START + timedelta(minutes=5), uuid.uuid4().hex),
    )
    detect_gecikmis(now=W_START + timedelta(minutes=40))
    assert [a for a in alarm_spy if a["window_id"] == k.wid] == []


def test_PENCERE_BITINCE_alarm_YOK(alarm_dunyasi, alarm_spy):
    k = _kurulum(alarm_dunyasi.conn, alarm_dunyasi.tid)
    detect_gecikmis(now=W_END + timedelta(minutes=30))
    assert [a for a in alarm_spy if a["window_id"] == k.wid] == []


def test_TEKRAR_SIFIR_alarmi_KAPATIR(owner_conn, alarm_spy):
    tid = _tenant(owner_conn, tekrar=0)
    k = _kurulum(owner_conn, tid)
    try:
        detect_gecikmis(now=W_START + timedelta(minutes=45))
        assert [a for a in alarm_spy if a["window_id"] == k.wid] == []
    finally:
        owner_conn.execute("DELETE FROM tenant WHERE id = %s", (tid,))


def test_GERCEK_bildirim_ADIM_BASINA_TEK_ama_TEKRAR_EDER(alarm_dunyasi):
    """dedup (tip, pencere) OLSAYDI tekrar HIC olmazdi; hic olmasaydi tek
    bildirim telefon sessizdeyken kaybolurdu."""
    k = _kurulum(alarm_dunyasi.conn, alarm_dunyasi.tid)
    assert detect_gecikmis(now=W_START + timedelta(minutes=12)) >= 1
    # ayni adim: yeniden kosmak ikinci bildirim URETMEZ
    assert detect_gecikmis(now=W_START + timedelta(minutes=15)) == 0
    # sonraki adim (30. dk): YENI bildirim
    assert detect_gecikmis(now=W_START + timedelta(minutes=32)) >= 1

    satirlar = alarm_dunyasi.conn.execute(
        "SELECT dedup_key, mesaj_kimlik FROM notification "
        "WHERE patrol_window_id = %s ORDER BY dedup_key", (k.wid,)).fetchall()
    assert [r[0] for r in satirlar] == [
        f"gecikmis_okutma:{k.wid}:0", f"gecikmis_okutma:{k.wid}:1"]
    assert {r[1] for r in satirlar} == {"gecikmis_okutma"}


def test_gorevli_KISI_olarak_hedeflenir(alarm_dunyasi, monkeypatch):
    """Rol yayinina birakmak, o vardiyada olmayan tum guvenlik personelini de
    titretirdi."""
    from app.scheduler import notify as notify_mod

    sid = uuid.uuid4()
    alarm_dunyasi.conn.execute(
        "INSERT INTO shift (id, tenant_id, ad, baslangic_saat, bitis_saat) "
        "VALUES (%s,%s,%s,%s,%s)",
        (sid, alarm_dunyasi.tid, "Gece", time(0, 0), time(6, 0)))
    alarm_dunyasi.conn.execute(
        "INSERT INTO shift_assignment (id, tenant_id, shift_id, user_id) "
        "VALUES (%s,%s,%s,%s)",
        (uuid.uuid4(), alarm_dunyasi.tid, sid, alarm_dunyasi.gid))
    k = _kurulum(alarm_dunyasi.conn, alarm_dunyasi.tid, shift_id=sid)

    cagrilar: list[dict] = []
    monkeypatch.setattr(notify_mod, "dispatch_external",
                        lambda kimlik, **kw: cagrilar.append({"k": kimlik, **kw}))
    detect_gecikmis(now=W_START + timedelta(minutes=12))

    kisi = [c for c in cagrilar if c.get("target_user_ids")]
    rol = [c for c in cagrilar if c.get("target_roles")]
    assert alarm_dunyasi.gid in kisi[0]["target_user_ids"]
    # YONETIM DE haberdar: gorevli telefonu duymuyorsa turu baskasi devralsin.
    assert "yonetici" in rol[0]["target_roles"]
    assert k.wid is not None
