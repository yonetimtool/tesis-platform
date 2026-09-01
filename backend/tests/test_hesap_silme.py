"""SELF-SERVIS HESAP SILME (P112) — App Store 5.1.1(v) + KVKK ayrimi.

Apple'in kurali kesin: hesap acilabiliyorsa **uygulama icinden**
silinebilmeli. Ama "silme" bizde tek bir sey degil, IKI moddur ve hangisinin
seciledigi hesabin GECMISINE baglidir:

  * gecmissiz hesap -> satir tamamen gider (`deleted=true`),
  * gecmisi olan hesap -> satir KALIR, kimlik alanlari temizlenir
    (`deleted=false`) cunku finans/denetim satirlari yasal olarak saklanir.

Bu dosya ikisini de, engelleri de (yeniden kimlik dogrulama, son yonetici)
ve KALICI KANIT satirini olcer.
"""
from __future__ import annotations

import uuid

import pytest



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


def _sfx() -> str:
    return uuid.uuid4().hex[:6]


@pytest.fixture
def adm(client, world):
    return _headers(client, world["slug_a"], world["admin_a"])


def _sakin_ac(client, adm, owner_conn) -> tuple[str, str, str]:
    """Yeni sakin + KALICI parola. Doner: (user_id, telefon, parola).

    (P186-ek2) POST /residents artik PAROLA ALMAZ ve yonetici parola atayamaz;
    ama bu dosyanin OLCTUGU sey hesap-SILMEDIR, hesap kurulumu degil. Testin
    parolayla giris yapabilen bir sakine ihtiyaci var, o yuzden parolayi
    DOGRUDAN DB'ye yaziyoruz (`world` fixture'i ile ayni yol).
    """
    from app.security import hash_password

    tel = f"+9053{uuid.uuid4().int % 100000000:08d}"
    parola = f"Sk{_sfx()}aA1!"
    r = client.post("/residents", headers=adm, json={
        "ad": "Silinecek Sakin",
        "unit_no": f"D-{_sfx()}",
        "telefon": tel, "email": _p197_mail()})
    assert r.status_code == 201, r.text
    user_id = r.json()["user_id"]
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE app_user SET password_hash=%s, password_set=true WHERE id=%s",
            (hash_password(parola), user_id),
        )
    return user_id, tel, parola


def _oturum(client, tel, parola) -> dict:
    r = client.post("/auth/login-phone", json={"phone": tel, "password": parola})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# =========================== TEMEL AKIS ===================================== #
def test_gecmissiz_hesap_TAMAMEN_silinir(client, adm, owner_conn):
    """Hicbir islemi olmayan hesap satirdan KALKAR (deleted=true)."""
    user_id, tel, parola = _sakin_ac(client, adm, owner_conn)
    h = _oturum(client, tel, parola)

    r = client.post("/me/hesap-sil", headers=h, json={"current_password": parola})
    assert r.status_code == 200, r.text
    assert r.json()["deleted"] is True

    # ERISIM ANINDA KESILIR: ayni access token artik gecmez.
    assert client.get("/me", headers=h).status_code == 401
    # Yonetim listesinde de yok.
    liste = client.get("/residents", headers=adm).json()["items"]
    assert user_id not in [k["user_id"] for k in liste]


def test_GECMISI_OLAN_hesap_ANONIMLESTIRILIR_defter_KALIR(client, adm, owner_conn):
    """KVKK ayriminin asil testi: kisisel veri gider, DEFTER kalir."""
    user_id, tel, parola = _sakin_ac(client, adm, owner_conn)
    h = _oturum(client, tel, parola)

    # Gecmis uret: sakinin actigi bir talep (FK RESTRICT).
    t = client.post("/complaints", headers=h, json={
        "baslik": "Musluk akiyor", "mesaj": "Mutfak muslugu damlatiyor",
    })
    assert t.status_code == 201, t.text
    talep_id = t.json()["id"]

    r = client.post("/me/hesap-sil", headers=h, json={"current_password": parola})
    assert r.status_code == 200, r.text
    # Satir KALDI ama kimlik alanlari temizlendi — bu da BASARIDIR.
    assert r.json()["deleted"] is False

    # 1) KISISEL VERI GITTI.
    # Liste KVKK geregi telefon/e-posta DONDURMEZ; adin yer tutucuya
    # donduguna ve hesabin pasiflestigine bakilir.
    liste = client.get("/residents", headers=adm).json()["items"]
    kayit = next((k for k in liste if k["user_id"] == user_id), None)
    if kayit is not None:  # pasif sakinler listede gorunuyorsa
        assert kayit["ad"] == "Silinmiş Kullanıcı"
        assert kayit["is_active"] is False

    # 2) DEFTER KALDI: talep hala okunabiliyor (tesis sorununun kaydi).
    talepler = client.get("/complaints", headers=adm).json()["items"]
    assert talep_id in [x["id"] for x in talepler]

    # 3) OTURUM GECERSIZ.
    assert client.get("/me", headers=h).status_code == 401
    # 4) Parola ile YENIDEN GIRIS de imkansiz (hash temizlendi).
    yeniden = client.post("/auth/login-phone", json={"phone": tel, "password": parola})
    assert yeniden.status_code == 401


# ========================= YENIDEN KIMLIK DOGRULAMA ========================= #
def test_YANLIS_parola_ile_silinmez(client, adm, owner_conn):
    """Odunc alinmis bir telefonla tek dokunusta hesap silinememeli."""
    user_id, tel, parola = _sakin_ac(client, adm, owner_conn)
    h = _oturum(client, tel, parola)

    r = client.post("/me/hesap-sil", headers=h, json={"current_password": "YanlisParola1!"})
    assert r.status_code == 400, r.text
    # Hesap DURUYOR.
    assert client.get("/me", headers=h).status_code == 200


def test_parola_ALANI_bos_gonderilemez(client, adm, owner_conn):
    _uid, tel, parola = _sakin_ac(client, adm, owner_conn)
    h = _oturum(client, tel, parola)
    r = client.post("/me/hesap-sil", headers=h, json={"current_password": ""})
    assert r.status_code == 422, r.text


# ============================ SON YONETICI ================================== #
def test_SON_yonetici_devretmeden_SILEMEZ(client, world):
    """Tesis sahipsiz kalmamali — 409 ve metin NE YAPILACAGINI soyler."""
    # `world` fixture'inda A tenant'inda admin + yonetici VAR; once
    # yoneticiyi pasiflestirip admin'i TEK yonetici birakiyoruz.
    adm = _headers(client, world["slug_a"], world["admin_a"])
    kullanicilar = client.get("/users", headers=adm).json()["items"]
    for k in kullanicilar:
        if k["role"] == "yonetici" and k["is_active"]:
            client.patch(f"/users/{k['id']}", headers=adm, json={"is_active": False})

    r = client.post("/me/hesap-sil", headers=adm,
                    json={"current_password": world["admin_a"]["password"]})
    assert r.status_code == 409, r.text
    # Hesap DURUYOR ve tesis yonetilebilir.
    assert client.get("/me", headers=adm).status_code == 200


def test_IKINCI_yonetici_varken_silinebilir(client, world):
    """Engel "yonetici silinemez" DEGIL, "SONUNCUSU silinemez"dir."""
    # A tenant'inda hem admin hem yonetici aktif; yonetici kendini silebilmeli.
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/me/hesap-sil", headers=yon,
                    json={"current_password": world["yonetici_a"]["password"]})
    assert r.status_code == 200, r.text
    assert client.get("/me", headers=yon).status_code == 401


# =============================== KANIT ====================================== #
def test_KALICI_kanit_satiri_yazilir_ve_TEK_olur(client, adm, owner_conn):
    """`audit_log` purge edilir; kanit satiri EDILMEZ (0029).

    Ayrica ayni hesap icin IKI kanit satiri olusmamali — sayim bozulurdu.
    """
    user_id, tel, parola = _sakin_ac(client, adm, owner_conn)
    h = _oturum(client, tel, parola)
    assert client.post("/me/hesap-sil", headers=h,
                       json={"current_password": parola}).status_code == 200

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT rol, mod, kendi_istegi FROM hesap_silme_kaydi WHERE user_id = %s",
            (user_id,),
        )
        satirlar = cur.fetchall()
    assert len(satirlar) == 1, "kanit satiri tek olmali"
    rol, mod, kendi = satirlar[0]
    assert rol == "resident"
    assert mod in ("hard_delete", "anonymize")
    # KENDI ISTEGI: 5.1.1(v) akisi oldugunu bu alan kanitlar.
    assert kendi is True


def test_YONETIM_silmesi_kanitta_KENDI_ISTEGI_DEGIL(client, adm, owner_conn):
    """Ayni cekirdek, farkli aktor: ayrim kanit satirinda gorunmeli."""
    user_id, _tel, _parola = _sakin_ac(client, adm, owner_conn)
    r = client.delete(f"/residents/{user_id}", headers=adm)
    assert r.status_code == 200, r.text

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT kendi_istegi FROM hesap_silme_kaydi WHERE user_id = %s", (user_id,)
        )
        satir = cur.fetchone()
    assert satir is not None, "yonetim silmesi de kanit birakmali"
    assert satir[0] is False


# ================ (P184) PAROLASIZ SILME — E-POSTA KODU ==================== #


def _parolasizlastir(owner_conn, user_id: str, *, eposta: str | None) -> None:
    """Kullaniciyi parolasiz yapar; verilen e-postayi DOGRULANMIS yazar.

    SSO ile kaydolan (parolasiz) kullanicinin durumunu taklit eder — silme
    yolu onda parola degil, E-POSTASINA giden kodu ister.

    (P197) `eposta=None` ARTIK "e-posta SUTUNU NULL" DEMEK DEGIL: sutun
    NOT NULL oldu (goc 0089) ve e-postasiz hesap ACILAMIYOR. Taklit
    edilen durum artik "adres var ama DOGRULANMAMIS" — silme akisinin
    gercekte baktigi sart budur (`eposta_dogrulandi`).
    """
    with owner_conn.cursor() as cur:
        if eposta is None:
            cur.execute(
                "UPDATE app_user SET password_hash=NULL, password_set=false, "
                "eposta_dogrulandi=false WHERE id=%s",
                (user_id,),
            )
        else:
            cur.execute(
                "UPDATE app_user SET password_hash=NULL, password_set=false, "
                "email=%s, eposta_dogrulandi=true WHERE id=%s",
                (eposta, user_id),
            )
    owner_conn.commit()


def test_parolasiz_EPOSTA_koduyla_silinir(client, adm, owner_conn):
    """(P184) SMS'siz: dogrulanmis e-postaya giden kodla hesap silinir."""
    from app.security import hash_password

    user_id, tel, parola = _sakin_ac(client, adm, owner_conn)
    h = _oturum(client, tel, parola)  # token parolayi NULL'lamadan ONCE alinir.
    eposta = f"sil-{uuid.uuid4().hex[:10]}@ornek.com"
    _parolasizlastir(owner_conn, user_id, eposta=eposta)

    # 1) E-POSTA kodu iste — kod satiri yazilir.
    r = client.post("/me/hesap-sil/eposta-kod-iste", headers=h)
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "gonderildi"

    # Kodu BILINEN degere cevir (dev'de SMTP yok; testin kodu ogrenmesinin
    # baska yolu yok — deponun mevcut deseni).
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE kayit_dogrulama SET kod_hash=%s "
            "WHERE eposta=%s AND amac='hesap_silme' AND durum='telefon_bekliyor'",
            (hash_password("424242"), eposta),
        )
        assert cur.rowcount == 1, "e-posta silme kodu satiri uretilmedi"
    owner_conn.commit()

    # 2) Kodla sil.
    r = client.post("/me/hesap-sil", headers=h, json={"kod": "424242"})
    assert r.status_code == 200, r.text
    # Oturum artik gecersiz — hesap gitti/anonimlesti.
    assert client.get("/me", headers=h).status_code == 401


def test_parolasiz_YANLIS_eposta_kodu_silmez(client, adm, owner_conn):
    """Yanlis kod silmez: e-posta kanali da 'sahiplik kaniti' esigini korur."""
    user_id, tel, parola = _sakin_ac(client, adm, owner_conn)
    h = _oturum(client, tel, parola)
    eposta = f"sil-{uuid.uuid4().hex[:10]}@ornek.com"
    _parolasizlastir(owner_conn, user_id, eposta=eposta)

    assert client.post("/me/hesap-sil/eposta-kod-iste", headers=h).status_code == 200
    r = client.post("/me/hesap-sil", headers=h, json={"kod": "000000"})
    assert r.status_code == 422, r.text
    assert client.get("/me", headers=h).status_code == 200  # hesap DURUYOR


def test_dogrulanmis_eposta_YOKSA_422(client, adm, owner_conn):
    """(a) Kanal yoksa akis baslamaz: DOGRULANMAMIS e-posta -> 422 no_email.

    (P197) Eskiden bu test e-posta sutununu NULL yapiyordu; sutun artik
    NOT NULL. Olculen sart degismedi: silme kodu YALNIZ dogrulanmis
    adrese gider.
    """
    user_id, tel, parola = _sakin_ac(client, adm, owner_conn)
    h = _oturum(client, tel, parola)
    _parolasizlastir(owner_conn, user_id, eposta=None)

    r = client.post("/me/hesap-sil/eposta-kod-iste", headers=h)
    assert r.status_code == 422, r.text
    assert r.json()["error"]["code"] == "no_email", r.text


def test_parolasiz_EPOSTA_koduyla_PAROLA_kurar(client, adm, owner_conn):
    """(P184) `PATCH /me/password` parolasiz yolu da E-POSTA koduyla calisir.

    Silme ile AYNI tek-kullanimlik kanal (`amac='hesap_silme'`); kod
    `/me/hesap-sil/eposta-kod-iste` ile istenir ve parola KURMAK icin de gecerli.
    """
    from app.security import hash_password

    user_id, tel, parola = _sakin_ac(client, adm, owner_conn)
    h = _oturum(client, tel, parola)
    eposta = f"pw-{uuid.uuid4().hex[:10]}@ornek.com"
    _parolasizlastir(owner_conn, user_id, eposta=eposta)

    assert client.post("/me/hesap-sil/eposta-kod-iste", headers=h).status_code == 200
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE kayit_dogrulama SET kod_hash=%s "
            "WHERE eposta=%s AND amac='hesap_silme' AND durum='telefon_bekliyor'",
            (hash_password("424242"), eposta),
        )
        assert cur.rowcount == 1
    owner_conn.commit()

    yeni = f"YeniPw{_sfx()}A1!"
    r = client.patch(
        "/me/password", headers=h, json={"kod": "424242", "new_password": yeni}
    )
    assert r.status_code == 204, r.text
    # Artik parola ile giris yapilabilir.
    assert (
        client.post("/auth/login-phone", json={"phone": tel, "password": yeni})
        .status_code
        == 200
    )
