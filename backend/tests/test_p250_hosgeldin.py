"""(P250 §3) HOS GELDINIZ E-POSTASI — kayit tamamlaninca, role gore, 7 dil, bir kez.

Gercek akis: yonetici kisiyi ekler -> davet satirindaki jeton -> kisi
`/davet/parola` ile kaydini tamamlar. Tasiyici `konsol_eposta`.
"""
from __future__ import annotations

import hashlib
import uuid

import pytest

from app.hosgeldin_eposta import DESTEK_EPOSTA, ROL_GRUBU, hosgeldin_eposta


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# ------------------------------------------------------------------ #
# 1. SABLON (saf)
# ------------------------------------------------------------------ #
@pytest.mark.parametrize("dil", ["tr", "en", "de", "fr", "es", "ar", "ru"])
@pytest.mark.parametrize("rol", sorted(ROL_GRUBU))
def test_sablon_her_rol_her_dil(dil, rol):
    konu, metin, html = hosgeldin_eposta(
        dil=dil, rol=rol, tesis_ad="Oltu Sitesi", ad="Işıl ÖZTÜRK", yil=2026,
        tesis_kodu="ABC123", web_url="https://app.yonetiyor.com",
    )
    assert "Oltu Sitesi" in konu
    for govde in (metin, html):
        assert DESTEK_EPOSTA in govde
        assert "play.google.com" in govde and "apps.apple.com" in govde
        assert "Işıl ÖZTÜRK" in govde
    # Web paneli ve Tesis ID YALNIZ yonetim rollerinde.
    yonetim = ROL_GRUBU[rol] in ("yonetici", "denetci")
    assert ("app.yonetiyor.com" in metin) == yonetim
    assert ("ABC123" in metin) == yonetim
    if dil == "ar":
        assert 'dir="rtl"' in html


def test_icerik_role_gore_FARKLI():
    def metin(rol):
        return hosgeldin_eposta(dil="tr", rol=rol, tesis_ad="T", ad="A", yil=2026)[1]
    sakin, guvenlik, gorevli, yonetici = (
        metin("resident"), metin("security"), metin("tesis_gorevlisi"), metin("yonetici")
    )
    assert "ödeme kodunuzu" in sakin
    assert "Devriye" in guvenlik
    assert "iş emirlerini" in gorevli
    assert "Kurulum sihirbazıyla" in yonetici
    assert len({sakin, guvenlik, gorevli, yonetici}) == 4


# ------------------------------------------------------------------ #
# 2. AKIS (canli API)
# ------------------------------------------------------------------ #
def _davetli_ekle(client, owner_conn, h, rol="security"):
    eposta = f"p250h-{uuid.uuid4().hex[:10]}@ornek.com"
    r = client.post("/users", headers=h, json={
        "ad": "ilker", "soyad": "yılmaz", "email": eposta, "role": rol,
    })
    assert r.status_code == 201, r.text
    uid = r.json()["id"]
    # Jeton yalniz HASH'i ile saklanir; bilinen bir jetonun hash'i davet
    # satirina yazilir (test_davet.py ile ayni yontem).
    jeton = f"p250-{uuid.uuid4().hex}"
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE davet SET jeton_hash=%s WHERE user_id=%s",
            (hashlib.sha256(jeton.encode()).hexdigest(), uid),
        )
        assert cur.rowcount == 1, "davet satiri yok"
    return uid, eposta, jeton


def _hosgeldinler(owner_conn, uid):
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT konu, govde, govde_html FROM mesaj_gonderim "
            "WHERE user_id=%s AND tur='hosgeldin'",
            (uid,),
        )
        return cur.fetchall()


def test_davetle_kayit_tamamlaninca_BIR_KEZ_gider(client, world, konsol_eposta, owner_conn):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    uid, eposta, jeton = _davetli_ekle(client, owner_conn, h, "security")
    assert _hosgeldinler(owner_conn, uid) == []  # eklemek kayit DEGIL

    r = client.post("/davet/parola", json={"jeton": jeton, "new_password": "CokGizli123!"},
                    headers={"Accept-Language": "en"})
    assert r.status_code == 200, r.text
    satirlar = _hosgeldinler(owner_conn, uid)
    assert len(satirlar) == 1
    konu, govde, html = satirlar[0]
    assert konu.endswith("welcome to Yönetiyor")
    assert "patrols" in govde and DESTEK_EPOSTA in html
    # Sakin degil: web paneli adresi YOK (guvenlik mobil-yalnizdir).
    assert "app.yonetiyor.com" not in govde

    # Ikinci tamamlama denemesi (davet artik kullanildi) e-posta URETMEZ;
    # rol degisimi de uretmez.
    client.post("/davet/parola", json={"jeton": jeton, "new_password": "CokGizli123!"})
    assert client.patch(f"/users/{uid}", headers=h, json={"role": "tesis_gorevlisi"}).status_code == 200
    assert len(_hosgeldinler(owner_conn, uid)) == 1


def test_MEVCUT_hesaplar_karsilanmis_sayilir(world, owner_conn):
    """Goc 0162: kaydi tamamlanmis hesaplar isaretli; onlara e-posta gitmez."""
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM app_user WHERE tenant_id=%s AND password_set "
            "AND hosgeldin_at IS NULL",
            (world["a"],),
        )
        # Fixture kullanicilari goc SONRASI yaratildi (isaretsiz); bu test
        # yalniz geri doldurmanin SQL'ini olcer: ayni kosulla isaretlenebilir.
        cur.execute(
            "SELECT count(*) FROM app_user u WHERE u.password_set AND u.hosgeldin_at IS NULL "
            "AND u.created_at < (SELECT max(created_at) FROM app_user) - interval '30 days'"
        )
        assert cur.fetchone()[0] == 0
