"""(P253 §D) Sikayet gizliligi — kilitler.

1. GIZLILIK: sikayet edenin kimligi HICBIR site rolune donmez (yonetici
   dahil) — her sikayet ucu x her site rolu; ne anahtar ne deger.
2. ESIK FARKLI KAYNAK DAIRE sayar: bir kisinin 5 sikayeti doldurmaz,
   farkli dairelerden gelenler doldurur; esik disi kisi sayilmaz.
3. GUNLUK SINIRLAR: ayni daireye 24 saatte 2, toplam 5 — kibar 429.
4. "ASILSIZ": gerekce zorunlu, sikayet edene bildirim, askiya alma ve
   geri alinca KENDILIGINDEN kalkma; yonetim kimin oldugunu ogrenmez.
5. RESMI KIMLIK ACMA yalniz platform (admin) — gerekceli, her goruntuleme
   denetimde; site yoneticisi 403.
"""
from __future__ import annotations

import json
import uuid

import pytest

from app.hata_metinleri import METINLER
from app.sikayet_koruma import ASKI_GUN, GUNLUK_DAIRE_SINIRI, GUNLUK_TOPLAM_SINIRI
from app.security import hash_password

PW = "GizPass1!"
SITE_ROLLERI = ("admin_a", "yonetici_a", "guard_a", "gorevli_a", "resident_a", "amir_a", "denetci_a")


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def blok(client, world, owner_conn):
    """Tek blok: 6 hedef daire + 8 kaynak daire (her birinde bir sakin)."""
    a = world["a"]
    sfx = uuid.uuid4().hex[:6]
    blok_ad = f"G{sfx}"
    with owner_conn.cursor() as cur:
        cur.execute("UPDATE tenant SET gurultu_esigi = 3 WHERE id = %s", (a,))
        cur.execute(
            "INSERT INTO building_block (tenant_id, ad, kat_sayisi) VALUES (%s,%s,1)",
            (a, blok_ad),
        )

        def daire(no):
            cur.execute(
                "INSERT INTO unit (tenant_id, no, blok, kat) VALUES (%s,%s,%s,1) RETURNING id",
                (a, f"{no}-{sfx}", blok_ad),
            )
            return str(cur.fetchone()[0])

        hedefler = [daire(f"H{i}") for i in range(6)]
        sakinler = []
        for i in range(8):
            u = daire(f"K{i}")
            email = f"giz{i}-{sfx}@acme.com"
            cur.execute(
                "INSERT INTO app_user (tenant_id, ad, email, telefon, password_hash, role, password_set) "
                "VALUES (%s,%s,%s,%s,%s,'resident'::user_role,true) RETURNING id",
                (a, f"Gizli Sakin{i} {sfx}", email, f"+90533{uuid.uuid4().int % 10**7:07d}",
                 hash_password(PW)),
            )
            uid = str(cur.fetchone()[0])
            cur.execute(
                "INSERT INTO unit_resident (tenant_id, unit_id, user_id) VALUES (%s,%s,%s)",
                (a, u, uid),
            )
            sakinler.append({"email": email, "password": PW, "id": uid, "unit": u,
                             "ad": f"Gizli Sakin{i} {sfx}"})
    return {**world, "hedefler": hedefler, "sakinler": sakinler}


def _sikayet(client, slug, sakin, hedef, kategori="gurultu"):
    return client.post(
        "/unit-complaints",
        headers=_h(client, slug, sakin),
        json={"target_unit_id": hedef, "kategori": kategori, "notlar": "olcum"},
    )


def _uyari(owner_conn, hedef) -> int:
    return owner_conn.execute(
        "SELECT count(*) FROM unit_uyari WHERE unit_id = %s", (hedef,)
    ).fetchone()[0]


def _ekle(owner_conn, tenant, hedef, sakin, *, gun_once=0, asilsiz=False, adet=1):
    for _ in range(adet):
        owner_conn.execute(
            "INSERT INTO unit_complaint (tenant_id, target_unit_id, complainant_user_id, "
            " kaynak_unit_id, kategori, durum, created_at, asilsiz_at, asilsiz_gerekce) "
            "VALUES (%s,%s,%s,%s,'gurultu','acik', now() - make_interval(days => %s), "
            " CASE WHEN %s THEN now() END, CASE WHEN %s THEN 'olcum' END)",
            (tenant, hedef, sakin["id"], sakin["unit"], gun_once, asilsiz, asilsiz),
        )


# ------------------------------- 1. gizlilik -------------------------------- #
def _sizinti(govde, sakin) -> list[str]:
    """Yanitta sikayet edene ait ANAHTAR ya da DEGER var mi."""
    metin = json.dumps(govde, ensure_ascii=False)
    bulgu = []
    if "complainant" in metin:
        bulgu.append("complainant anahtari")
    for alan in ("id", "email", "ad"):
        if sakin[alan] in metin:
            bulgu.append(f"sikayet eden {alan}")
    return bulgu


def test_KIMLIK_hicbir_site_rolune_DONMEZ(client, blok, owner_conn):
    slug = blok["slug_a"]
    s0, hedef = blok["sakinler"][0], blok["hedefler"][0]
    r = _sikayet(client, slug, s0, hedef)
    assert r.status_code == 201, r.text
    cid = r.json()["id"]
    yon = _h(client, slug, blok["yonetici_a"])
    # Yonetim eylemleri de kimlik dondurmez.
    eylemler = [
        client.post(f"/unit-complaints/{cid}/okundu", headers=yon),
        client.post(f"/unit-complaints/{cid}/asilsiz", headers=yon, json={"gerekce": "olcum gerekcesi"}),
        client.delete(f"/unit-complaints/{cid}/asilsiz", headers=yon),
        client.patch(f"/unit-complaints/{cid}", headers=yon, json={"durum": "kapali"}),
    ]
    for e in eylemler:
        assert e.status_code == 200, e.text
        assert not _sizinti(e.json(), s0), e.json()

    okumalar = [
        ("GET", "/unit-complaints", {}),
        ("GET", "/unit-complaints", {"target_unit_id": hedef}),
        ("GET", "/unit-complaints/density", {}),
        ("GET", "/unit-complaints/gorunur-sayi", {}),
        ("GET", "/unit-complaints/building-map", {}),
        ("GET", "/unit-complaints/kaynak-ozeti", {"unit_id": hedef}),
        ("GET", "/unit-complaints/mine", {}),
        ("GET", "/activity", {}),
        ("GET", "/notifications", {}),
        ("GET", f"/units/{hedef}", {}),
    ]
    acik = 0
    for rol in SITE_ROLLERI:
        h = _h(client, slug, blok[rol])
        for _, yol, prm in okumalar:
            y = client.get(yol, headers=h, params=prm)
            assert y.status_code in (200, 403, 404), (rol, yol, y.status_code, y.text)
            if y.status_code == 200:
                acik += 1
                assert not _sizinti(y.json(), s0), (rol, yol, _sizinti(y.json(), s0))
    assert acik > 10, "olcum bos: hicbir okuma 200 donmedi"


def test_DENETIM_GORUNTULEYICISI_sikayet_edeni_SIZDIRMAZ(client, blok):
    slug = blok["slug_a"]
    s0 = blok["sakinler"][0]
    cid = _sikayet(client, slug, s0, blok["hedefler"][0]).json()["id"]
    adm = _h(client, slug, blok["admin_a"])
    satirlar = client.get(
        "/audit", headers=adm,
        params={"tenant_id": str(blok["a"]), "resource_type": "unit_complaint"},
    ).json()["items"]
    dosya = [s for s in satirlar if s["resource_id"] == cid and s["action"] == "unit_complaint_file"]
    assert dosya and all(s["actor_user_id"] is None for s in dosya)


def test_SEMADA_kimlik_alani_YOK():
    from app.schemas import UnitComplaintOut

    assert not [a for a in UnitComplaintOut.model_fields if "complainant" in a]


# --------------------------------- 2. esik ---------------------------------- #
def test_ESIK_bir_kisinin_bes_sikayeti_DOLDURMAZ_farkli_daireler_DOLDURUR(client, blok, owner_conn):
    slug, a = blok["slug_a"], blok["a"]
    s, hedef = blok["sakinler"], blok["hedefler"][1]
    # Bir kisi: 1 gercek + 4 eklenmis = 5 sikayet, TEK kaynak.
    assert _sikayet(client, slug, s[0], hedef).status_code == 201
    _ekle(owner_conn, a, hedef, s[0], adet=4)
    assert _uyari(owner_conn, hedef) == 0
    # Ikinci kaynak: 2 < 3 -> uyari yok.
    assert _sikayet(client, slug, s[1], hedef).status_code == 201
    assert _uyari(owner_conn, hedef) == 0, "tek kisinin sikayetleri esigi doldurdu"
    # Ucuncu FARKLI daire -> esik.
    assert _sikayet(client, slug, s[2], hedef).status_code == 201
    assert _uyari(owner_conn, hedef) == 1


def test_ESIK_DISI_kisinin_sikayeti_SAYILMAZ(client, blok, owner_conn):
    slug, a = blok["slug_a"], blok["a"]
    s, hedef = blok["sakinler"], blok["hedefler"][2]
    x = s[7]
    # X'in 2 eski sikayeti asilsiz (baska dairelere) -> 2/3 asilsiz: ESIK DISI.
    _ekle(owner_conn, a, blok["hedefler"][4], x, gun_once=3, asilsiz=True)
    _ekle(owner_conn, a, blok["hedefler"][5], x, gun_once=4, asilsiz=True)
    assert _sikayet(client, slug, x, hedef).status_code == 201
    assert _sikayet(client, slug, s[1], hedef).status_code == 201
    assert _sikayet(client, slug, s[2], hedef).status_code == 201
    assert _uyari(owner_conn, hedef) == 0, "esik disi kisinin sikayeti sayildi"
    assert _sikayet(client, slug, s[3], hedef).status_code == 201
    assert _uyari(owner_conn, hedef) == 1


# -------------------------------- 3. sinirlar ------------------------------- #
def test_GUNLUK_SINIRLAR_kibar_429(client, blok):
    slug = blok["slug_a"]
    s0, h = blok["sakinler"][0], blok["hedefler"]
    assert GUNLUK_DAIRE_SINIRI == 2 and GUNLUK_TOPLAM_SINIRI == 5
    assert _sikayet(client, slug, s0, h[0], "gurultu").status_code == 201
    assert _sikayet(client, slug, s0, h[0], "zarar_verme").status_code == 201
    r = _sikayet(client, slug, s0, h[0], "diger")
    assert r.status_code == 429, r.text
    assert r.json()["error"]["message"] == METINLER["sikayet_daire_gunluk_sinir"]["tr"].format(sayi=2)
    for i in (1, 2, 3):
        assert _sikayet(client, slug, s0, h[i]).status_code == 201
    r = _sikayet(client, slug, s0, h[4])
    assert r.status_code == 429, r.text
    assert r.json()["error"]["message"] == METINLER["sikayet_gunluk_sinir"]["tr"].format(sayi=5)
    # Baska sakin etkilenmez.
    assert _sikayet(client, slug, blok["sakinler"][1], h[4]).status_code == 201


def test_SINIR_METINLERI_hata_gibi_DEGIL():
    for kod in ("sikayet_daire_gunluk_sinir", "sikayet_gunluk_sinir", "sikayet_askida"):
        tr = METINLER[kod]["tr"]
        assert not any(k in tr.lower() for k in ("hata", "yasak", "engellendi", "reddedildi")), tr
        assert set(METINLER[kod]) == {"tr", "en", "ar", "ru", "de", "fr", "es"}


# -------------------------------- 4. asilsiz -------------------------------- #
def test_ASILSIZ_gerekce_zorunlu_bildirim_ve_kimliksiz(client, blok, owner_conn):
    slug = blok["slug_a"]
    s0 = blok["sakinler"][0]
    cid = _sikayet(client, slug, s0, blok["hedefler"][0]).json()["id"]
    yon = _h(client, slug, blok["yonetici_a"])
    for govde in ({}, {"gerekce": ""}, {"gerekce": "   "}):
        assert client.post(f"/unit-complaints/{cid}/asilsiz", headers=yon, json=govde).status_code == 422
    r = client.post(f"/unit-complaints/{cid}/asilsiz", headers=yon, json={"gerekce": "Kamerada olay yok"})
    assert r.status_code == 200, r.text
    assert r.json()["asilsiz"] is True and r.json()["asilsiz_gerekce"] == "Kamerada olay yok"
    # Ikinci kez -> 422 (gecersiz gecis).
    assert client.post(f"/unit-complaints/{cid}/asilsiz", headers=yon,
                       json={"gerekce": "tekrar"}).status_code == 422
    # Sikayet edene bildirim (yalniz ona).
    alicilar = owner_conn.execute(
        "SELECT user_id FROM notification WHERE tip = 'sikayet_asilsiz' AND tenant_id = %s",
        (blok["a"],),
    ).fetchall()
    assert [str(x[0]) for x in alicilar] == [s0["id"]]
    # Sakin kendi kaydinda karari ve gerekceyi gorur.
    mine = client.get("/unit-complaints/mine", headers=_h(client, slug, s0)).json()["items"]
    kayit = next(i for i in mine if i["id"] == cid)
    assert kayit["asilsiz"] is True and kayit["asilsiz_gerekce"] == "Kamerada olay yok"
    # Diger roller isaretleyemez.
    for rol in ("guard_a", "gorevli_a", "resident_a", "amir_a", "denetci_a"):
        h = _h(client, slug, blok[rol])
        assert client.post(f"/unit-complaints/{cid}/asilsiz", headers=h,
                           json={"gerekce": "deneme gerekce"}).status_code == 403, rol


def test_ASILSIZ_kademesi_ASKI_ve_geri_alinca_KENDILIGINDEN_kalkar(client, blok, owner_conn):
    slug, a = blok["slug_a"], blok["a"]
    x, h = blok["sakinler"][6], blok["hedefler"]
    yon = _h(client, slug, blok["yonetici_a"])
    # 4 eski sikayet (gunluk sinira takilmasin diye gecmiste).
    for i in range(4):
        _ekle(owner_conn, a, h[i], x, gun_once=2 + i)
    idler = [str(r[0]) for r in owner_conn.execute(
        "SELECT id FROM unit_complaint WHERE complainant_user_id = %s ORDER BY created_at", (x["id"],)
    ).fetchall()]
    for cid in idler[:3]:
        assert client.post(f"/unit-complaints/{cid}/asilsiz", headers=yon,
                           json={"gerekce": "dogrulanamadi"}).status_code == 200
    # 3 asilsiz: henuz askida degil.
    assert _sikayet(client, slug, x, h[5]).status_code == 201
    sinirlama = "SELECT count(*) FROM notification WHERE tip = 'sikayet_sinirlama' AND user_id = %s"
    assert owner_conn.execute(sinirlama, (x["id"],)).fetchone()[0] == 0
    # 4. isaret -> 4/5 = %80 >= %60 ve 4 >= 4: ASKIDA + bildirim.
    assert client.post(f"/unit-complaints/{idler[3]}/asilsiz", headers=yon,
                       json={"gerekce": "dogrulanamadi"}).status_code == 200
    assert owner_conn.execute(sinirlama, (x["id"],)).fetchone()[0] == 1
    r = _sikayet(client, slug, x, h[4], "diger")
    assert r.status_code == 429, r.text
    assert r.json()["error"]["code"] == "rate_limited"
    assert METINLER["sikayet_askida"]["tr"].split("{")[0] in r.json()["error"]["message"]
    assert ASKI_GUN == 14
    # Geri al -> kisitlama KENDILIGINDEN kalkar.
    assert client.delete(f"/unit-complaints/{idler[3]}/asilsiz", headers=yon).status_code == 200
    assert _sikayet(client, slug, x, h[4], "diger").status_code == 201


def test_KAYNAK_OZETI_oruntu_etiketsiz(client, blok, owner_conn):
    slug, a = blok["slug_a"], blok["a"]
    s, hedef = blok["sakinler"], blok["hedefler"][3]
    _ekle(owner_conn, a, hedef, s[0], gun_once=1, adet=4)
    _ekle(owner_conn, a, hedef, s[1], gun_once=1)
    _ekle(owner_conn, a, hedef, s[2], gun_once=1, asilsiz=True)
    yon = _h(client, slug, blok["yonetici_a"])
    oz = client.get("/unit-complaints/kaynak-ozeti", headers=yon, params={"unit_id": hedef})
    assert oz.status_code == 200, oz.text
    assert oz.json() == {
        "gun": 30, "sikayet_sayisi": 5, "farkli_kaynak": 2,
        "tek_kaynak_yogun": True, "asilsiz_sayisi": 1,
    }
    for rol in ("guard_a", "gorevli_a", "resident_a", "amir_a", "denetci_a"):
        r = client.get("/unit-complaints/kaynak-ozeti", headers=_h(client, slug, blok[rol]),
                       params={"unit_id": hedef})
        assert r.status_code == 403, rol


# ------------------------- 5. resmi kimlik acma ----------------------------- #
def test_RESMI_KIMLIK_yalniz_platform_gerekceli_ve_HER_GORUNTULEME_denetimde(client, blok, owner_conn):
    slug = blok["slug_a"]
    s0 = blok["sakinler"][0]
    cid = _sikayet(client, slug, s0, blok["hedefler"][0]).json()["id"]
    govde = {"tenant_id": str(blok["a"]), "sikayet_id": cid,
             "gerekce": "Savcilik yazisi 2026/123 uzerine resmi talep"}
    for rol in ("yonetici_a", "guard_a", "gorevli_a", "resident_a", "amir_a", "denetci_a"):
        r = client.post("/platform/sikayet-kimlik", headers=_h(client, slug, blok[rol]), json=govde)
        assert r.status_code == 403, (rol, r.text)
    adm = _h(client, slug, blok["admin_a"])
    kisa = client.post("/platform/sikayet-kimlik", headers=adm,
                       json={**govde, "gerekce": "talep" + " " * 20})
    assert kisa.status_code == 422
    sayac = ("SELECT count(*) FROM audit_log WHERE action = 'sikayet_kimlik_acma' "
             "AND resource_id = %s")
    for n in (1, 2):
        r = client.post("/platform/sikayet-kimlik", headers=adm, json=govde)
        assert r.status_code == 200, r.text
        assert r.json()["sikayet_eden_id"] == s0["id"] and r.json()["sikayet_eden_ad"] == s0["ad"]
        assert owner_conn.execute(sayac, (cid,)).fetchone()[0] == n
    meta = owner_conn.execute(
        "SELECT meta FROM audit_log WHERE action = 'sikayet_kimlik_acma' AND resource_id = %s LIMIT 1",
        (cid,),
    ).fetchone()[0]
    assert meta["gerekce"].startswith("Savcilik")
