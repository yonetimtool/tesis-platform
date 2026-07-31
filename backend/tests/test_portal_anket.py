"""Site web portali + anket (P38)."""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

import pytest

UTC = timezone.utc


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def p(client, world):
    from types import SimpleNamespace
    return SimpleNamespace(
        client=client, slug=world["slug_a"], world=world,
        yonetici=_h(client, world["slug_a"], world["yonetici_a"]),
        admin=_h(client, world["slug_a"], world["admin_a"]),
        sakin=_h(client, world["slug_a"], world["resident_a"]),
        guard=_h(client, world["slug_a"], world["guard_a"]),
    )


def _yayinla(p, **alanlar):
    govde = {"yayinda": True, "hero_baslik": "Huzur Sitesi",
             "hakkimizda": "2005'te kuruldu."}
    govde.update(alanlar)
    r = p.client.patch("/portal", headers=p.yonetici, json=govde)
    assert r.status_code == 200, r.text
    return r.json()


# ============================== YAYIN KAPISI ================================ #
def test_YAYINDA_DEGILKEN_public_404(p):
    """403 'bu tesis var ama kapali' bilgisini sizdirirdi; slug tahminiyle
    tesis envanteri cikarilabilirdi."""
    r = p.client.get(f"/public/{p.slug}")
    assert r.status_code == 404, r.text
    assert r.json()["error"]["code"] == "not_found"


def test_OLMAYAN_slug_de_404_ve_AYNI_kod(p):
    r = p.client.get(f"/public/olmayan-{uuid.uuid4().hex[:8]}")
    assert r.status_code == 404
    assert r.json()["error"]["code"] == "not_found"


def test_VARSAYILAN_KAPALI(p):
    """Bir tesisin adi ve adresi, yonetim ACIKCA yayinlamadan internete
    cikmamali."""
    assert p.client.get("/portal", headers=p.yonetici).json()["yayinda"] is False


def test_yayinlaninca_PUBLIC_acilir(p):
    _yayinla(p)
    r = p.client.get(f"/public/{p.slug}")
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["tesis_adi"] == "A"
    assert d["hero_baslik"] == "Huzur Sitesi"
    assert d["konum_lat"] and d["konum_lon"], "harita gomulusu icin konum"


def test_public_uc_KIMLIK_ISTEMEZ(p):
    _yayinla(p)
    # Authorization header'i HIC gonderilmiyor.
    assert p.client.get(f"/public/{p.slug}").status_code == 200


def test_yayin_DENETLENIR(p, owner_conn, world):
    _yayinla(p)
    satir = owner_conn.execute(
        "SELECT meta FROM audit_log WHERE tenant_id = %s AND action = "
        "'portal_yayin' ORDER BY ts DESC LIMIT 1", (world["a"],)).fetchone()
    assert satir and satir[0]["yayinda"] == "True"


def test_portal_YONETIMI_yalniz_yonetim(p):
    for h in (p.sakin, p.guard):
        assert p.client.get("/portal", headers=h).status_code == 403
        assert p.client.patch("/portal", headers=h,
                              json={"yayinda": True}).status_code == 403


# ============================== ICERIK ====================================== #
def test_duyuru_YALNIZ_OZET_cikar(p):
    """Tam govde site ICINE yoneliktir; tamamini internete acmak sakinlere
    yazilmis bir metni herkese yayinlamak olurdu."""
    uzun = "A" * 900
    d = p.client.post("/announcements", headers=p.yonetici, json={
        "baslik": "Uzun Duyuru", "govde": uzun})
    assert d.status_code == 201, d.text
    _yayinla(p)
    pub = p.client.get(f"/public/{p.slug}").json()
    kayit = next(x for x in pub["duyurular"] if x["baslik"] == "Uzun Duyuru")
    assert len(kayit["ozet"]) < len(uzun)
    assert "govde" not in kayit


def test_galeri_IDOR_korumasi(p, world):
    me = p.client.get("/me", headers=p.yonetici).json()
    tid = me["tenant_id"]
    ok = p.client.post("/portal/galeri", headers=p.yonetici, json={
        "obje_anahtari": f"{tid}/portal/{uuid.uuid4().hex}.jpg", "sira": 1})
    assert ok.status_code == 201, ok.text
    kotu = p.client.post("/portal/galeri", headers=p.yonetici, json={
        "obje_anahtari": f"{uuid.uuid4()}/portal/x.jpg"})
    assert kotu.status_code == 422
    assert kotu.json()["error"]["code"] == "invalid_foto_key"
    # Ayni anahtar iki kez eklenemez.
    assert p.client.post("/portal/galeri", headers=p.yonetici, json={
        "obje_anahtari": ok.json()["obje_anahtari"]}).status_code == 409
    assert p.client.delete(f"/portal/galeri/{ok.json()['id']}",
                           headers=p.yonetici).status_code == 204


# ============================== ILETISIM ==================================== #
def test_iletisim_KAYIT_ONCE(p):
    """Mesaji dogrudan e-postaya cevirmek, SMTP yapilandirilmamis bir sitede
    mesajin SESSIZCE KAYBOLMASI demekti."""
    _yayinla(p)
    r = p.client.post(f"/public/{p.slug}/iletisim", json={
        "ad": "Ali Veli", "telefon": "+905321112233",
        "mesaj": "Daire kiralamak istiyorum."})
    assert r.status_code == 201, r.text
    liste = p.client.get("/portal/iletisim", headers=p.yonetici).json()["items"]
    assert any(m["ad"] == "Ali Veli" for m in liste)


def test_iletisim_DONUS_YOLU_zorunlu(p):
    """Telefonu ve e-postasi olmayan bir mesaja yonetim cevap veremezdi."""
    _yayinla(p)
    r = p.client.post(f"/public/{p.slug}/iletisim", json={
        "ad": "Anonim", "mesaj": "Merhaba dunya"})
    assert r.status_code == 422, r.text


def test_iletisim_YAYINDA_DEGILSE_404(p):
    r = p.client.post(f"/public/{p.slug}/iletisim", json={
        "ad": "Ali", "email": "a@b.com", "mesaj": "Merhaba dunya"})
    assert r.status_code == 404


# ================================ ANKET ===================================== #
def _anket(p, **over):
    govde = {"baslik": f"Anket {uuid.uuid4().hex[:6]}",
             "secenekler": [{"metin": "Evet", "sira": 0},
                            {"metin": "Hayır", "sira": 1}]}
    govde.update(over)
    return p.client.post("/anketler", headers=p.yonetici, json=govde)


def test_anket_EN_AZ_IKI_secenek(p):
    """Tek secenekli bir anket oy toplamaz, ONAY toplar."""
    r = _anket(p, secenekler=[{"metin": "Tamam"}])
    assert r.status_code == 422, r.text


def test_TEK_OY_ve_DEGISTIRILEMEZ(p):
    """Degistirilebilir oy, kapanis anina kadar sonucun anlamsiz olmasi
    demekti."""
    a = _anket(p).json()
    sec = a["secenekler"]
    r = p.client.post(f"/anketler/{a['id']}/oy", headers=p.sakin,
                      json={"secenek_id": sec[0]["id"]})
    assert r.status_code == 201, r.text
    assert r.json()["oy_verdim"] is True

    ikinci = p.client.post(f"/anketler/{a['id']}/oy", headers=p.sakin,
                           json={"secenek_id": sec[1]["id"]})
    assert ikinci.status_code == 409, ikinci.text
    assert ikinci.json()["error"]["code"] == "conflict"


def test_ACIK_ANKETTE_sonuc_GIZLI_sakine(p):
    """Guncel dagilimi gostermek sonraki oy verenleri ETKILER (surusel
    etki) ve oylamanin kendisini bozardi."""
    a = _anket(p).json()
    p.client.post(f"/anketler/{a['id']}/oy", headers=p.sakin,
                  json={"secenek_id": a["secenekler"][0]["id"]})
    liste = p.client.get("/anketler", headers=p.sakin).json()["items"]
    benim = next(x for x in liste if x["id"] == a["id"])
    assert benim["acik"] is True
    assert benim["toplam_oy"] is None
    assert all(s["oy"] is None for s in benim["secenekler"])
    # Kendi oyunu verdigini BILIR (kendi oyunu gormek baskasininkini
    # gormek degildir).
    assert benim["oy_verdim"] is True


def test_YONETIM_sonucu_HER_ZAMAN_gorur(p):
    """Kararin sahibi yonetimdir."""
    a = _anket(p).json()
    p.client.post(f"/anketler/{a['id']}/oy", headers=p.sakin,
                  json={"secenek_id": a["secenekler"][0]["id"]})
    liste = p.client.get("/anketler", headers=p.yonetici).json()["items"]
    benim = next(x for x in liste if x["id"] == a["id"])
    assert benim["toplam_oy"] == 1
    assert sum(s["oy"] for s in benim["secenekler"]) == 1


def test_KAPANINCA_sonuc_HERKESE_acilir(p):
    a = _anket(p).json()
    p.client.post(f"/anketler/{a['id']}/oy", headers=p.sakin,
                  json={"secenek_id": a["secenekler"][0]["id"]})
    r = p.client.patch(f"/anketler/{a['id']}", headers=p.yonetici,
                       json={"aktif": False})
    assert r.status_code == 200, r.text
    liste = p.client.get("/anketler", headers=p.sakin).json()["items"]
    benim = next(x for x in liste if x["id"] == a["id"])
    assert benim["acik"] is False
    assert benim["toplam_oy"] == 1


def test_KAPANIS_TARIHI_gecince_oy_alinmaz(p):
    gecmis = (datetime.now(UTC) - timedelta(minutes=1)).isoformat()
    a = _anket(p, kapanis_at=gecmis).json()
    assert a["acik"] is False
    r = p.client.post(f"/anketler/{a['id']}/oy", headers=p.sakin,
                      json={"secenek_id": a["secenekler"][0]["id"]})
    assert r.status_code == 409, r.text


def test_BASKA_ANKETIN_secenegi_reddedilir(p):
    a1 = _anket(p).json()
    a2 = _anket(p).json()
    r = p.client.post(f"/anketler/{a1['id']}/oy", headers=p.sakin,
                      json={"secenek_id": a2["secenekler"][0]["id"]})
    assert r.status_code == 422, r.text


def test_OY_yalniz_SAKIN(p):
    """Anket sakinlerin karar aracidir; personelin oyu site kararina
    girmez."""
    a = _anket(p).json()
    sid = a["secenekler"][0]["id"]
    for h in (p.guard, p.yonetici, p.admin):
        r = p.client.post(f"/anketler/{a['id']}/oy", headers=h,
                          json={"secenek_id": sid})
        assert r.status_code == 403, r.status_code
    # Ama HERKES anketi OKUR.
    assert p.client.get("/anketler", headers=p.guard).status_code == 200


def test_SECENEKLER_degistirilemez(p):
    """Oy verilmis bir anketin seceneklerini degistirmek, verilmis oylari
    BASKA BIR SORUYA tasimak olurdu."""
    a = _anket(p).json()
    r = p.client.patch(f"/anketler/{a['id']}", headers=p.yonetici,
                       json={"secenekler": [{"metin": "Yeni"}]})
    assert r.status_code == 422, r.text


def test_public_ankette_sonuc_ve_KIMLIK_yok(p):
    a = _anket(p).json()
    p.client.post(f"/anketler/{a['id']}/oy", headers=p.sakin,
                  json={"secenek_id": a["secenekler"][0]["id"]})
    _yayinla(p)
    pub = p.client.get(f"/public/{p.slug}").json()
    benim = next(x for x in pub["anketler"] if x["id"] == a["id"])
    assert benim["oy_verdim"] is None, "public uc kimlik BILMEZ"
    assert benim["toplam_oy"] is None, "acik anketin sonucu GIZLI"


def test_tenant_izolasyonu(p, client, world):
    a = _anket(p).json()
    b = _h(client, world["slug_b"], world["yonetici_b"])
    assert a["id"] not in [
        x["id"] for x in client.get("/anketler", headers=b).json()["items"]]
    _yayinla(p)
    # B'nin portali yayinda DEGIL — A'nin yayini B'yi acmaz.
    assert client.get(f"/public/{world['slug_b']}").status_code == 404
