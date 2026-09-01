"""(P155 / §7) DAVET JETONU — cozme, tamamlama (parola/sosyal), yasam dongusu.

Davet, yoneticinin ACTIGI parolasiz hesaba giden jetonlu kayit bagidir.
Jeton cozuldugunde tesis/rol/daire/telefon bellidir; kullanici yalniz
yontem secer. SMS YOK (jeton + saglayici kimligi SMS'in yerini tutar).

Jeton DUZ METIN saklanmaz (sha256). Test, `_kodu_al` desenini izler:
bilinen bir jetonun hash'ini davet satirina yazip ucu o duz jetonla
cagirir — olculen sey jeton uretimi degil, AKISIN kendisi.
"""
from __future__ import annotations

import hashlib
import uuid
from datetime import datetime, timedelta, timezone



def _p197_mail() -> str:
    """(P197) Kullanici/sakin olusturmada e-posta ZORUNLU oldu.

    `app_user.email` NOT NULL (goc 0089): davet, dogrulama kodu ve parola
    sifirlama YALNIZ e-postadan gidiyor, yani e-postasiz acilan hesap
    sahiplenilemez. Test govdelerine BENZERSIZ adres verilir —
    `uq_app_user_tenant_email` ayni tesiste tekrari reddeder.
    """
    return f"p197-{uuid.uuid4().hex[:12]}@ornek.com"

def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _tel() -> str:
    return "+9057" + str(uuid.uuid4().int)[:8]


def _hash(jeton: str) -> str:
    return hashlib.sha256(jeton.encode()).hexdigest()


def _davet_yaz(owner_conn, slug, *, rol="resident", telefon=None, daire=None,
               gecerlilik_gun=30, jeton="bilinen-davet-jetonu"):
    """Parolasiz hesap + (sakinse) daire + bilinen jetonlu davet olusturur.

    Doner: (user_id, jeton).
    """
    telefon = telefon or _tel()
    with owner_conn.cursor() as cur:
        cur.execute(
            # (P197) E-POSTA ZORUNLU: `app_user.email` NOT NULL (goc 0089).
            # Davet ZATEN e-postaya gider; adressiz davetli kaydi urunde
            # de olusamaz.
            "INSERT INTO app_user (tenant_id, ad, telefon, email, "
            "  password_hash, password_set, role, is_active) "
            "SELECT id, %s, %s, %s, NULL, false, %s::user_role, true "
            "FROM tenant WHERE slug = %s RETURNING id, tenant_id",
            (f"Davetli {rol}", telefon,
             f"p197-{uuid.uuid4().hex[:10]}@ornek.com", rol, slug),
        )
        uid, tid = cur.fetchone()
        if daire is not None:
            cur.execute(
                "INSERT INTO unit (tenant_id, blok, no) VALUES (%s, 'A', %s) "
                "RETURNING id",
                (tid, daire),
            )
            unit_id = cur.fetchone()[0]
            cur.execute(
                "INSERT INTO unit_resident (tenant_id, unit_id, user_id, rol_tipi) "
                "VALUES (%s, %s, %s, 'malik')",
                (tid, unit_id, uid),
            )
        son = datetime.now(timezone.utc) + timedelta(days=gecerlilik_gun)
        cur.execute(
            "INSERT INTO davet (tenant_id, user_id, jeton_hash, son_gecerlilik) "
            "VALUES (%s, %s, %s, %s)",
            (tid, uid, _hash(jeton), son),
        )
    return uid, jeton


# ============================ COZME ======================================= #

def test_coz_sakin_daire_getirir(client, world, owner_conn):
    _, jeton = _davet_yaz(owner_conn, world["slug_a"], rol="resident",
                          daire=f"D-{uuid.uuid4().hex[:4]}")
    r = client.post("/davet/coz", json={"jeton": jeton})
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["rol"] == "resident"
    assert d["daire_no"]           # sakinde daire dolu
    assert "***" in d["telefon_maskeli"]
    assert d["tesis_ad"]


def test_coz_yonetici_daire_YOK(client, world, owner_conn):
    _davet_yaz(owner_conn, world["slug_a"], rol="yonetici",
               jeton="yonetici-daviti")
    r = client.post("/davet/coz", json={"jeton": "yonetici-daviti"})
    assert r.status_code == 200, r.text
    assert r.json()["daire_no"] is None


def test_BILINMEYEN_jeton_404(client):
    r = client.post("/davet/coz", json={"jeton": "hic-boyle-jeton-yok-xyz"})
    assert r.status_code == 404


def test_SURESI_DOLMUS_jeton_410(client, world, owner_conn):
    _davet_yaz(owner_conn, world["slug_a"], gecerlilik_gun=-1,
               jeton="bayat-jeton")
    r = client.post("/davet/coz", json={"jeton": "bayat-jeton"})
    assert r.status_code == 410
    assert r.json()["error"]["code"] == "gone"


# ========================= PAROLA TAMAMLAMA =============================== #

def test_parola_ile_TAMAMLA_ve_gir(client, world, owner_conn):
    tel = _tel()
    _davet_yaz(owner_conn, world["slug_a"], rol="resident", telefon=tel,
               daire=f"D-{uuid.uuid4().hex[:4]}", jeton="parola-daviti")

    r = client.post("/davet/parola", json={
        "jeton": "parola-daviti", "ad": "Gerçek Ad", "new_password": "DavetParola1!"})
    assert r.status_code == 200, r.text
    assert r.json()["access_token"]

    # Artik telefon + parola ile girebiliyor.
    lp = client.post("/auth/login-phone", json={"phone": tel, "password": "DavetParola1!"})
    assert lp.status_code == 200 and lp.json()["password_setup_required"] is False


def test_TEK_KULLANIM_ikinci_parola_410(client, world, owner_conn):
    _davet_yaz(owner_conn, world["slug_a"], jeton="tek-kullanim",
               daire=f"D-{uuid.uuid4().hex[:4]}")
    ilk = client.post("/davet/parola", json={
        "jeton": "tek-kullanim", "new_password": "DavetParola1!"})
    assert ilk.status_code == 200, ilk.text
    # Ayni jeton ikinci kez GECMEZ (used_at + password_set).
    ikinci = client.post("/davet/parola", json={
        "jeton": "tek-kullanim", "new_password": "BaskaParola2!"})
    assert ikinci.status_code == 410


def test_zayif_parola_422(client, world, owner_conn):
    _davet_yaz(owner_conn, world["slug_a"], jeton="zayif-parola",
               daire=f"D-{uuid.uuid4().hex[:4]}")
    r = client.post("/davet/parola", json={"jeton": "zayif-parola", "new_password": "kisa"})
    assert r.status_code == 422


# ===================== SAKIN EKLEME -> DAVET GONDER ======================= #

def test_sakin_eklemede_DAVET_gonderilir(client, world):
    """POST /residents parolasiz hesap acar VE davet gonderir. (P188) BIRINCIL
    kanal E-POSTA; SMS kapali oldugu icin denenmez."""
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/residents", headers=yon, json={
        "telefon": _tel(), "unit_no": f"DV-{uuid.uuid4().hex[:4]}", "email": _p197_mail()})
    assert r.status_code == 201, r.text
    davet = r.json()["davet"]
    assert davet is not None
    # (P172 §7) YAPILANDIRMA YOKSA `gonderildi` FALSE'TUR.
    #
    # Eski iddia `True` idi ve o gunun kodu `sms.durum != "basarisiz"`
    # diyordu — yani "yapilandirilmadi" da BASARI sayiliyordu. P168
    # LogSms'i duzeltti (artik `yapilandirilmadi` doner) ama bu satir
    # eski gercegi sabitlemeye devam ediyordu.
    #
    # Test ortaminda ne SMS ne SMTP yapilandirilmis; hicbir yere hicbir
    # sey gitmedi. `True` demek, brief'in acikca yasakladigi sey:
    # "sessizce gonderildi DEMESIN".
    assert davet["gonderildi"] is False
    # (P188) BIRINCIL kanal E-POSTA (SMS kapali, hic denenmez).
    assert davet["kanal"] == "eposta"


def test_P188_davet_EPOSTA_birincil_SMS_kapaliyken_DENENMEZ(client, world, owner_conn):
    """(P188) PROD HATASI: davet SMS kanalindan deneniyor, SMS kapali (sms_aktif
    =false) oldugu icin basarisiz oluyor ve E-POSTAYA HIC DUSMUYORDU. Artik
    e-posta BIRINCIL; SMS hic denenmez. E-postali sakinde YALNIZ eposta gonderim
    kaydi olusur, SMS kaydi OLUSMAZ."""
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    eposta = f"davet-{uuid.uuid4().hex[:8]}@example.com"
    r = client.post("/residents", headers=yon, json={
        "telefon": _tel(), "unit_no": f"DV-{uuid.uuid4().hex[:4]}", "email": eposta})
    assert r.status_code == 201, r.text
    assert r.json()["davet"]["kanal"] == "eposta"
    user_id = r.json()["user_id"]

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT kanal FROM mesaj_gonderim WHERE tenant_id = %s AND user_id = %s",
            (world["a"], user_id),
        )
        kanallar = {k for (k,) in cur.fetchall()}
    assert "eposta" in kanallar, f"e-posta davet kaydi yok: {kanallar}"
    assert "sms" not in kanallar, "SMS kapaliyken davet SMS DENEMEMELI"


# (P186-ek2) test_parola_ILE_acilan_sakine_davet_YOK KALDIRILDI: POST /residents
# artik PAROLA ALMAZ (yonetici parola atayamaz), hesap DAIMA parolasiz acilir ve
# davet HER ZAMAN gonderilir — "parola verilirse davet yok" senaryosu kalmadi.


# ======================= YONETICI: DAVET PANELI ========================== #

def test_yonetici_davet_LISTELER_ve_yeniden_gonderir(client, world, owner_conn):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    uid, _ = _davet_yaz(owner_conn, world["slug_a"], rol="resident",
                        daire=f"D-{uuid.uuid4().hex[:4]}", jeton="panel-daviti")

    liste = client.get("/davet", headers=yon)
    assert liste.status_code == 200, liste.text
    kayitlar = liste.json()["items"]
    assert any(str(k["user_id"]) == str(uid) for k in kayitlar)

    # Yeniden gonder: taze jeton + gonderim. (P188) BIRINCIL kanal E-POSTA.
    yeniden = client.post(f"/davet/{uid}/yeniden", headers=yon)
    assert yeniden.status_code == 200, yeniden.text
    assert yeniden.json()["son_kanal"] == "eposta"


def test_davet_paneli_ROL_KAPISI(client, world, owner_conn):
    """Sakin davet panelini goremez (yalniz admin/yonetici)."""
    from app.security import hash_password

    # Once bir sakin acalim ve onunla girelim. (P186-ek2) POST /residents parola
    # ALMAZ; login-phone yapabilmesi icin parolayi DOGRUDAN DB'ye yaziyoruz.
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    tel = _tel()
    created = client.post("/residents", headers=yon, json={
        "telefon": tel, "unit_no": f"DV-{uuid.uuid4().hex[:4]}", "email": _p197_mail()})
    assert created.status_code == 201, created.text
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE app_user SET password_hash=%s, password_set=true WHERE id=%s",
            (hash_password("SakinParola1!"), created.json()["user_id"]),
        )
    sakin = client.post("/auth/login-phone", json={"phone": tel, "password": "SakinParola1!"})
    assert sakin.status_code == 200, sakin.text
    h = {"Authorization": f"Bearer {sakin.json()['access_token']}"}
    assert client.get("/davet", headers=h).status_code == 403


# ===================== P190 — List-Unsubscribe (RFC 8058) =================== #
def test_P190_davet_vazgec_jetonu_roundtrip():
    """(P190) Iptal jetonu user+tenant tasir, HMAC imzali; dogru cozulur,
    bozuk imza/bicim None doner (baskasini iptal ettirmeye kapali)."""
    from app.davet import davet_vazgec_coz, davet_vazgec_jetonu

    uid = uuid.uuid4()
    tid = uuid.uuid4()
    jet = davet_vazgec_jetonu(uid, tid)
    assert davet_vazgec_coz(jet) == (uid, tid)
    assert davet_vazgec_coz(jet + "x") is None                 # imza bozuk
    assert davet_vazgec_coz("bozuk") is None                    # bicim bozuk
    assert davet_vazgec_coz(f"{uid}.{tid}.deadbeefdeadbeef") is None  # yanlis imza


def test_P190_gecersiz_jeton_200_SIZDIRMAZ(client):
    """Gecersiz jetonda da 200 (varlik/gecerlilik sizdirmama)."""
    assert client.post("/davet/vazgec/bozuk-jeton").status_code == 200


def test_P190_list_unsubscribe_tek_tik_davet_epostasini_DURDURUR(client, world, owner_conn):
    """(P190) POST /davet/vazgec/{jeton} kisiyi davet e-postalarindan cikarir;
    yonetici YENIDEN gonderse bile e-posta ATLANIR (son_hata=davet_vazgecildi)."""
    from app.davet import davet_vazgec_jetonu

    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    created = client.post("/residents", headers=yon, json={
        "telefon": _tel(), "unit_no": f"VZ-{uuid.uuid4().hex[:4]}",
        "email": f"vz-{uuid.uuid4().hex[:8]}@example.com"}).json()
    uid = created["user_id"]

    # Tek-tik iptal (public, jeton imzali).
    assert client.post(f"/davet/vazgec/{davet_vazgec_jetonu(uid, world['a'])}").status_code == 200

    with owner_conn.cursor() as cur:
        cur.execute("SELECT davet_vazgecti FROM app_user WHERE id = %s", (str(uid),))
        assert cur.fetchone()[0] is True

    # Yeniden gonder -> e-posta ATLANIR; ozet "davet_vazgecildi" der.
    yeniden = client.post(f"/davet/{uid}/yeniden", headers=yon)
    assert yeniden.status_code == 200, yeniden.text
    assert yeniden.json()["son_hata"] == "davet_vazgecildi"
