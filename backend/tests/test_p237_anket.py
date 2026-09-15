"""(P237 §3) ANKET — hedef kitle, anonimlik, katilim orani, dokum.

===========================================================================
BRIEF'IN DOGRULAMA ISTEGI BIREBIR SURULUR
===========================================================================
"Bir anket ac, iki gruba gonder, oy ver, sonucu gor. Anonim anket ac, oy
ver, kimligin gorunmedigini VERITABANINDAN dogrula."

Son madde onemli: uctan "kimlik gelmiyor" demek YETMEZ — veri orada
duruyorsa bir sonraki sorgu, rapor ya da yedek onu acar. Bu yuzden
asagidaki test veritabanina DOGRUDAN bakar.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

import psycopg
import pytest

from .conftest import OWNER_DSN

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
        sakin=_h(client, world["slug_a"], world["resident_a"]),
        guard=_h(client, world["slug_a"], world["guard_a"]),
    )


def _anket(p, **over):
    govde = {
        "baslik": f"P237 {uuid.uuid4().hex[:6]}",
        "secenekler": [{"metin": "Evet", "sira": 0}, {"metin": "Hayır", "sira": 1}],
    }
    govde.update(over)
    r = p.client.post("/anketler", headers=p.yonetici, json=govde)
    assert r.status_code == 201, r.text
    return r.json()


# ======================== HEDEF KITLE ==================================== #
def test_HEDEF_KITLE_coklu_secilir_ve_donulur(p):
    a = _anket(p, hedef_roller=["resident", "security"])
    assert set(a["hedef_roller"]) == {"resident", "security"}
    # KATILIM ORANININ PAYDASI: kac kisiye gitti.
    assert a["hedef_kisi"] is not None and a["hedef_kisi"] >= 1


def test_HEDEF_DISINDAKI_rol_OY_VEREMEZ(p):
    """Gorunurluk kapisi DEGIL, OY kapisi: sakin anketi listede gorebilir
    (site genelinde ne konusuldugu bilgi degeridir) ama hedefte degilse
    oyu sayilmaz."""
    a = _anket(p, hedef_roller=["security"])
    r = p.client.post(f"/anketler/{a['id']}/oy", headers=p.sakin,
                      json={"secenek_id": a["secenekler"][0]["id"]})
    assert r.status_code == 403, r.text
    assert r.json()["error"]["code"] == "forbidden"


def test_HEDEF_BOS_ise_HERKES(p):
    a = _anket(p)
    assert a["hedef_roller"] == []
    r = p.client.post(f"/anketler/{a['id']}/oy", headers=p.sakin,
                      json={"secenek_id": a["secenekler"][0]["id"]})
    assert r.status_code == 201, r.text


def test_BILINMEYEN_rol_422(p):
    r = p.client.post("/anketler", headers=p.yonetici, json={
        "baslik": "x",
        "secenekler": [{"metin": "a"}, {"metin": "b"}],
        "hedef_roller": ["uydurma_rol"],
    })
    assert r.status_code == 422, r.text


# ======================== TARIH ARALIGI ================================== #
def test_BASLANGIC_GELMEDEN_oy_verilemez(p):
    ileri = (datetime.now(UTC) + timedelta(days=3)).isoformat()
    a = _anket(p, baslangic_at=ileri)
    assert a["acik"] is False
    r = p.client.post(f"/anketler/{a['id']}/oy", headers=p.sakin,
                      json={"secenek_id": a["secenekler"][0]["id"]})
    assert r.status_code == 409, r.text


def test_BITIS_BASLANGICTAN_ONCE_olamaz(p):
    simdi = datetime.now(UTC)
    r = p.client.post("/anketler", headers=p.yonetici, json={
        "baslik": "x",
        "secenekler": [{"metin": "a"}, {"metin": "b"}],
        "baslangic_at": (simdi + timedelta(days=2)).isoformat(),
        "kapanis_at": (simdi + timedelta(days=1)).isoformat(),
    })
    assert r.status_code == 422, r.text


# ======================== KIM NEYE OY VERDI ============================== #
def test_ADLI_ankette_DOKUM_gorunur(p):
    a = _anket(p)
    sec = a["secenekler"][0]
    assert p.client.post(f"/anketler/{a['id']}/oy", headers=p.sakin,
                         json={"secenek_id": sec["id"]}).status_code == 201
    r = p.client.get(f"/anketler/{a['id']}/oylar", headers=p.yonetici)
    assert r.status_code == 200, r.text
    satir = r.json()["items"][0]
    assert satir["secenek_id"] == sec["id"]
    assert satir["secenek_metin"] == sec["metin"]
    assert satir["ad"]  # KIM — adiyla


# ======================== ANONIMLIK ====================================== #
def test_ANONIM_ankette_KIMLIK_VERITABANINDA_YOK(p):
    """Brief: "veritabani duzeyinde garanti edilsin; yonetici veya platform
    admini bile goremesin". Uctan bakmak yetmez — VERIYE bakiyoruz."""
    a = _anket(p, anonim=True)
    assert a["anonim"] is True
    sec = a["secenekler"][0]
    r = p.client.post(f"/anketler/{a['id']}/oy", headers=p.sakin,
                      json={"secenek_id": sec["id"]})
    assert r.status_code == 201, r.text
    assert r.json()["oy_verdim"] is True

    # DOKUM UCU: 409 — "vermiyorum" degil, "veri YOK".
    d = p.client.get(f"/anketler/{a['id']}/oylar", headers=p.yonetici)
    assert d.status_code == 409, d.text

    # VERITABANI: oy satirinda kimlik NULL, katilim defterinde kimlik VAR
    # ama NEYE oy verildigi YOK.
    with psycopg.connect(OWNER_DSN, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT user_id, anonim FROM anket_oy WHERE anket_id = %s",
                (a["id"],),
            )
            satirlar = cur.fetchall()
            assert satirlar, "oy yazilmadi"
            for user_id, anonim in satirlar:
                assert anonim is True
                assert user_id is None, "ANONIM ANKETTE KIMLIK YAZILMIS"
            # Katilim defteri KIMI biliyor ama NEYI bilmiyor.
            cur.execute(
                "SELECT count(*) FROM anket_katilim WHERE anket_id = %s",
                (a["id"],),
            )
            assert cur.fetchone()[0] == 1
            cur.execute(
                "SELECT column_name FROM information_schema.columns "
                "WHERE table_name = 'anket_katilim'"
            )
            kolonlar = {r[0] for r in cur.fetchall()}
            assert "secenek_id" not in kolonlar, (
                "katilim defteri NEYE oy verildigini tutmamali"
            )


def test_ANONIM_ankette_KIMLIKLI_OY_YAZILAMAZ_veritabani_reddeder(p):
    """KIRMA DENEYI: uygulama katmanini ATLAYIP dogrudan SQL ile kimlikli
    bir anonim oy yazmaya calisiyoruz. CHECK kisiti REDDETMELI —
    garantinin uygulama kodunda degil VERITABANINDA oldugunun kaniti."""
    a = _anket(p, anonim=True)
    sec = a["secenekler"][0]
    with psycopg.connect(OWNER_DSN, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT tenant_id FROM anket WHERE id = %s", (a["id"],))
            tenant_id = cur.fetchone()[0]
            cur.execute("SELECT id FROM app_user WHERE tenant_id = %s LIMIT 1",
                        (tenant_id,))
            uid = cur.fetchone()[0]
            with pytest.raises(psycopg.errors.CheckViolation):
                cur.execute(
                    "INSERT INTO anket_oy "
                    "(tenant_id, anket_id, secenek_id, user_id, anonim) "
                    "VALUES (%s, %s, %s, %s, true)",
                    (tenant_id, a["id"], sec["id"], uid),
                )


def test_ANONIMLIK_SONRADAN_DEGISTIRILEMEZ(p):
    """Brief: "anonim sanip oy veren kisinin kimligi sonradan acilir; bu
    bir guven ihlalidir. Kilitle." IKI KATMAN olculur."""
    a = _anket(p, anonim=True)
    # 1) UC KATMANI: `AnketUpdate` alani TASIMIYOR (extra="forbid").
    r = p.client.patch(f"/anketler/{a['id']}", headers=p.yonetici,
                       json={"anonim": False})
    assert r.status_code == 422, r.text

    # 2) VERITABANI KATMANI: uygulamayi ATLAYIP dogrudan UPDATE.
    with psycopg.connect(OWNER_DSN, autocommit=True) as conn:
        with conn.cursor() as cur:
            with pytest.raises(psycopg.Error) as hata:
                cur.execute(
                    "UPDATE anket SET anonim = false WHERE id = %s", (a["id"],)
                )
            assert "anonim" in str(hata.value).lower()


def test_ADLI_ankette_kimlik_YAZILIR(p):
    """Karsi kontrol: kilit anonim ANKETE ozgu olmali; adli ankette kimlik
    kaydedilmeye devam etmeli (dokum ve tek-oy icin gerekli)."""
    a = _anket(p)
    assert p.client.post(
        f"/anketler/{a['id']}/oy", headers=p.sakin,
        json={"secenek_id": a["secenekler"][0]["id"]},
    ).status_code == 201
    with psycopg.connect(OWNER_DSN, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT user_id, anonim FROM anket_oy WHERE anket_id = %s",
                (a["id"],),
            )
            user_id, anonim = cur.fetchone()
            assert anonim is False
            assert user_id is not None


def test_ANONIMDE_de_TEK_OY(p):
    """Kimlik oy satirindan cikinca tek-oy kuralini `anket_katilim`
    zorluyor; kural KAYBOLMAMALI."""
    a = _anket(p, anonim=True)
    sec = a["secenekler"]
    assert p.client.post(f"/anketler/{a['id']}/oy", headers=p.sakin,
                         json={"secenek_id": sec[0]["id"]}).status_code == 201
    # IKINCI oy — baska secenege bile olsa.
    r = p.client.post(f"/anketler/{a['id']}/oy", headers=p.sakin,
                      json={"secenek_id": sec[1]["id"]})
    assert r.status_code == 409, r.text
