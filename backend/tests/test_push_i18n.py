"""Push + in-app bildirim metinleri 7 dilde (tur 16).

Tur 14 hata metinlerini, tur 15 akis satirlarini kimlige cevirdi. Geriye
bildirimler kalmisti ve onlarin sorunu FARKLIYDI: push ASENKRONDUR — gonderim
aninda istek, dolayisiyla `Accept-Language` YOKTUR. Bu yuzden:

  * dil CIHAZ kaydinda saklanir (`user_device.dil`, migration 0008) ve
    gonderim dile gore GRUPLANIR,
  * kalici `notification` satiri cumle degil `mesaj_kimlik` + `mesaj_veri`
    tasir; in-app liste metni OKUMA aninda istegin dilinde uretir (cumleyi
    kayda dondurmak, ilk yazanin dilini kalicilastirirdi).

Bu dosya dort ayagi kilitler: katalog butunlugu, dile gore gruplama,
kaynakta ham cumle kalmamasi, gercek uctan cihaz dili + in-app metin.
"""
from __future__ import annotations

import re
import uuid

import pytest

from app.push_metinleri import (
    METINLER,
    dil_normalize,
    push_basligi,
    push_govdesi,
)

DILLER = ("tr", "en", "ar", "ru", "de", "fr", "es")

# YALNIZ Turkcede bulunan harfler (`ç/ö/ü` disarida: Almanca/Fransizca da
# kullanir — bkz. test_hata_i18n.py'deki ayni gerekce).
TR_HARF = re.compile("[ğışĞİŞ]")


# --------------------------------------------------------------------------- #
# 1. Katalog
# --------------------------------------------------------------------------- #
def test_katalog_tam():
    assert METINLER
    for kimlik, kayit in METINLER.items():
        assert set(kayit.baslik) == set(DILLER), f"{kimlik}: baslik dili eksik"
        assert set(kayit.govde) == set(DILLER), f"{kimlik}: govde dili eksik"
        for dil in DILLER:
            assert kayit.baslik[dil].strip(), f"{kimlik}/{dil} baslik bos"
            assert kayit.govde[dil].strip(), f"{kimlik}/{dil} govde bos"


def _cevrilecek_sozcuk_var(sablon: str) -> bool:
    """Sablonda `{param}`lar disinda HARF var mi?

    `duyuru` govdesi saf gecistir: `"{baslik}"` — cevrilecek tek sozcuk
    icermez, dolayisiyla 7 dilde AYNI olmasi dogrudur. Bu ayrimi yapmadan
    "ceviri yapilmis mi" denetimi yanlis alarm uretir.
    """
    return bool(re.sub(r"\{\w+\}", "", sablon).strip(" .:—-·()"))


def test_ceviri_gercekten_yapilmis():
    """Kopyala-yapistir denetimi: TR metin baska dile birebir gecmemis."""
    for kimlik, kayit in METINLER.items():
        for dil in DILLER:
            if dil == "tr":
                continue
            if _cevrilecek_sozcuk_var(kayit.govde["tr"]):
                assert kayit.govde[dil] != kayit.govde["tr"], f"{kimlik}/{dil}"
            assert not TR_HARF.search(kayit.govde[dil]), f"{kimlik}/{dil}"
            assert not TR_HARF.search(kayit.baslik[dil]), f"{kimlik}/{dil}"
    # Basliklar HER ZAMAN cevrilecek sozcuk tasir (parametre almazlar).
    for kimlik, kayit in METINLER.items():
        assert kayit.baslik["en"] != kayit.baslik["tr"], f"{kimlik}/baslik"


def test_saf_gecis_sablonu_beklenen_yerde():
    """Saf gecis (yalniz `{param}`) sablonu SADECE `duyuru`da olmali.

    Yeni bir kimlik yanlislikla "{baslik}" gibi bos bir govdeyle eklenirse
    (yani metin yazilmayi unutulursa) bu test uyarir."""
    saf = {
        k for k, v in METINLER.items() if not _cevrilecek_sozcuk_var(v.govde["tr"])
    }
    assert saf == {"duyuru"}, saf


def test_parametreler_tum_dillerde_ayni():
    """Bir dilde dusen `{param}` sessizdir: metin eksik bilgiyle gosterilir."""
    alan = re.compile(r"\{(\w+)\}")
    for kimlik, kayit in METINLER.items():
        beklenen = set(kayit.params)
        for dil in DILLER:
            assert set(alan.findall(kayit.govde[dil])) == beklenen, f"{kimlik}/{dil}"


def test_metin_uretimi_daima_deger_dondurur():
    assert push_govdesi("boyle_kimlik_yok", "en") == "boyle_kimlik_yok"
    assert push_basligi("boyle_kimlik_yok", "en") == "boyle_kimlik_yok"
    # Desteklenmeyen dil -> Turkce'ye duser (bos metin YOK).
    assert push_govdesi("duyuru", "zz", {"baslik": "X"}) == METINLER[
        "duyuru"
    ].govde["tr"].format(baslik="X")
    # Parametre eksik -> ham sablon (istek/gonderim patlamaz).
    assert "{firma}" in push_govdesi("kargo", "en")


def test_dil_normalize():
    assert dil_normalize("ar") == "ar"
    assert dil_normalize(None) == "tr"
    assert dil_normalize("zz") == "tr"
    assert dil_normalize("tr-TR") == "tr"  # bolge ekli deger desteklenmez


# --------------------------------------------------------------------------- #
# 2. Gonderim dile gore GRUPLANIR
# --------------------------------------------------------------------------- #
def _cihaz(token: str, dil: str):
    """(P191 §2) `_fetch_device_tokens` artik `Cihaz` dondurur — teshis satiri
    "kime" sorusunu cevaplayabilsin diye `user_id`/`platform` de tasiniyor."""
    from app.scheduler.notify import Cihaz

    return Cihaz(token, dil, uuid.uuid4(), "android")


class _SahteSaglayici:
    """Gonderilen (token kumesi, baslik, govde) uclulerini kaydeder."""

    name = "sahte"

    def __init__(self) -> None:
        self.cagrilar: list[tuple[tuple[str, ...], str, str]] = []

    def send(self, tokens, *, title, body, data=None):
        self.cagrilar.append((tuple(tokens), title, body))
        return None


def test_farkli_dildeki_cihazlara_farkli_metin(monkeypatch):
    from app.scheduler import notify

    saglayici = _SahteSaglayici()
    monkeypatch.setattr(notify.push, "get_push_provider", lambda: saglayici)
    monkeypatch.setattr(
        notify,
        "_fetch_device_tokens",
        lambda tenant_id, roles: [
            _cihaz("tok-tr", "tr"),
            _cihaz("tok-ar", "ar"),
            _cihaz("tok2-ar", "ar"),
        ],
    )

    notify.dispatch_external(
        "kargo",
        tenant_id=uuid.uuid4(),
        target_roles=("resident",),
        params={"firma": "Aras", "daire": "A-12"},
    )

    # Iki dil -> IKI gonderim; ayni dildeki cihazlar TEK batch'te toplanir.
    assert len(saglayici.cagrilar) == 2
    dile_gore = {c[2]: c[0] for c in saglayici.cagrilar}
    tr_metin = METINLER["kargo"].govde["tr"].format(firma="Aras", daire="A-12")
    ar_metin = METINLER["kargo"].govde["ar"].format(firma="Aras", daire="A-12")
    assert dile_gore[tr_metin] == ("tok-tr",)
    assert set(dile_gore[ar_metin]) == {"tok-ar", "tok2-ar"}
    # Baslik da cihazin dilinde.
    basliklar = {c[1] for c in saglayici.cagrilar}
    assert basliklar == {METINLER["kargo"].baslik["tr"], METINLER["kargo"].baslik["ar"]}


def test_bilinmeyen_dil_turkceye_duser(monkeypatch):
    from app.scheduler import notify

    saglayici = _SahteSaglayici()
    monkeypatch.setattr(notify.push, "get_push_provider", lambda: saglayici)
    monkeypatch.setattr(
        notify, "_fetch_device_tokens", lambda tenant_id, roles: [_cihaz("t", "zz")]
    )
    notify.dispatch_external(
        "duyuru", tenant_id=uuid.uuid4(), target_roles=("resident",),
        params={"baslik": "Su kesintisi"},
    )
    assert saglayici.cagrilar[0][2] == "Su kesintisi"


def test_push_hatasi_akisi_kirmaz(monkeypatch):
    """Saglayici patlarsa cagiran etkilenmez (in-app kayit yazilmis olur)."""
    from app.scheduler import notify

    class _Patlayan:
        name = "patlayan"

        def send(self, *a, **kw):
            raise RuntimeError("fcm down")

    monkeypatch.setattr(notify.push, "get_push_provider", lambda: _Patlayan())
    monkeypatch.setattr(
        notify, "_fetch_device_tokens", lambda tenant_id, roles: [_cihaz("t", "tr")]
    )
    notify.dispatch_external(
        "duyuru", tenant_id=uuid.uuid4(), target_roles=("resident",),
        params={"baslik": "X"},
    )  # istisna SIZMAMALI


# --------------------------------------------------------------------------- #
# 3. Kaynak taramasi
# --------------------------------------------------------------------------- #
def test_kaynakta_ham_bildirim_cumlesi_kalmadi():
    """`dispatch_external`e cumle geciren bir cagri yeri EKLENMESIN.

    Ilk argument katalogda bir KIMLIK olmali (degisken geciriliyorsa —
    orn. `tip` — statik olarak dogrulanamaz; o yollar testlerle kapali).
    """
    import ast
    import pathlib

    kok = pathlib.Path(__file__).resolve().parents[1] / "app"
    sizanlar = []
    for yol in sorted(kok.rglob("*.py")):
        agac = ast.parse(yol.read_text(encoding="utf-8"))
        for d in ast.walk(agac):
            if not (
                isinstance(d, ast.Call)
                and getattr(d.func, "id", None) == "dispatch_external"
                and d.args
            ):
                continue
            ilk = d.args[0]
            if isinstance(ilk, ast.Constant) and isinstance(ilk.value, str):
                if ilk.value not in METINLER:
                    sizanlar.append(f"{yol.name}:{d.lineno} -> {ilk.value[:50]}")
            elif isinstance(ilk, ast.JoinedStr):  # f-string = cumle
                sizanlar.append(f"{yol.name}:{d.lineno} -> f-string")
    assert not sizanlar, "katalogsuz bildirim metni:\n" + "\n".join(sizanlar)


def test_notify_opener_cagrilari_kimlik_tasir():
    """`notify_opener` de METIN almaz — `tip` KIMLIKTIR.

    Tur 16'da bu fonksiyonun `mesaj=` parametresi kaldirildi ama
    `routers/tasks.py`deki DORDUNCU cagri yeri gozden kacti: uc yerine
    bakip "bitti" dedim, o yol 500 verdi (tam suite yakaladi). Tarama artik
    `dispatch_external` ile AYNI sekilde bu fonksiyonu da denetler.
    """
    import ast
    import pathlib

    kok = pathlib.Path(__file__).resolve().parents[1] / "app"
    sizanlar = []
    for yol in sorted(kok.rglob("*.py")):
        agac = ast.parse(yol.read_text(encoding="utf-8"))
        for d in ast.walk(agac):
            if not (
                isinstance(d, ast.Call)
                and getattr(d.func, "id", None) == "notify_opener"
            ):
                continue
            adlar = {kw.arg for kw in d.keywords}
            # `mesaj`/`title` gibi METIN parametreleri KALDIRILDI.
            # (P147) `db` EKLENDI: anlik push'un yaninda KALICI bildirim
            # satirini yazmak icin oturum gerekiyor. Kilidin amaci
            # DARALMADI — hala METIN parametresi sizmasini yakaliyor;
            # `db` bir metin tasiyicisi degil.
            fazla = adlar - {"complaint", "tenant_id", "tip", "db"}
            if fazla:
                sizanlar.append(f"{yol.name}:{d.lineno} fazla arguman: {sorted(fazla)}")
            tip = next((kw.value for kw in d.keywords if kw.arg == "tip"), None)
            if isinstance(tip, ast.Constant) and tip.value not in METINLER:
                sizanlar.append(f"{yol.name}:{d.lineno} katalogsuz tip: {tip.value}")
    assert not sizanlar, "\n".join(sizanlar)


def test_notification_tipleri_katalogda():
    """`data.tip` degerleri kimlik olarak da cozulebilmeli (istemci yonlendirme
    ile metin ayni anahtari kullanir)."""
    for tip in ("kacirilan_tur", "talep_is_emri", "talep_cozuldu", "talep_reddedildi"):
        assert tip in METINLER


# --------------------------------------------------------------------------- #
# 4. Gercek uctan
# --------------------------------------------------------------------------- #
def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_cihaz_dili_kaydedilir_ve_guncellenir(client, world):
    h = _headers(client, world["slug_a"], world["admin_a"])
    token = f"tok-{uuid.uuid4().hex[:10]}"

    r = client.post(
        "/devices", headers=h, json={"fcm_token": token, "platform": "android", "dil": "ar"}
    )
    assert r.status_code == 201, r.text
    assert r.json()["dil"] == "ar"

    # Dil degisince AYNI token yeniden kaydedilir (idempotent upsert).
    r2 = client.post(
        "/devices", headers=h, json={"fcm_token": token, "platform": "android", "dil": "de"}
    )
    assert r2.status_code == 201
    assert r2.json()["dil"] == "de"
    assert r2.json()["id"] == r.json()["id"], "yeni satir acilmamali"


def test_dil_gonderilmezse_turkce(client, world):
    """Eski istemciler `dil` gondermez — davranis degismez."""
    h = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/devices",
        headers=h,
        json={"fcm_token": f"tok-{uuid.uuid4().hex[:10]}", "platform": "ios"},
    )
    assert r.status_code == 201
    assert r.json()["dil"] == "tr"


def test_gecersiz_dil_422(client, world):
    h = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/devices",
        headers=h,
        json={"fcm_token": "tok-x", "platform": "android", "dil": "klingon"},
    )
    assert r.status_code == 422


@pytest.fixture
def bildirim(owner_conn, world):
    """A tenant'inda kimlik tasiyan bir bildirim kaydi."""
    import json

    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO notification (tenant_id, tip, mesaj, mesaj_kimlik, mesaj_veri, "
            "dedup_key) VALUES (%s,'kacirilan_tur',%s,%s,%s::jsonb,%s) RETURNING id",
            (
                world["a"],
                "eski turkce ozet",
                "kacirilan_tur",
                json.dumps({"plan": "Gece devriyesi", "eksik": 2}),
                f"push-i18n-{uuid.uuid4().hex[:8]}",
            ),
        )
        return cur.fetchone()[0]


def test_in_app_bildirim_istegin_dilinde(client, world, bildirim):
    """Ayni KAYIT, farkli `Accept-Language` -> farkli metin (kayit degismez)."""
    h = _headers(client, world["slug_a"], world["admin_a"])
    metinler = {}
    for dil in DILLER:
        r = client.get("/notifications?limit=200", headers={**h, "Accept-Language": dil})
        assert r.status_code == 200, r.text
        satir = next(i for i in r.json()["items"] if i["id"] == str(bildirim))
        metinler[dil] = satir["mesaj"]
        # Kimlik ve veri de doner (istemci yonlendirme/kendi metni icin).
        assert satir["mesaj_kimlik"] == "kacirilan_tur"
        assert satir["mesaj_veri"]["plan"] == "Gece devriyesi"

    assert len(set(metinler.values())) >= 6, metinler
    for dil, metin in metinler.items():
        assert "Gece devriyesi" in metin  # VERI cevrilmez
        if dil != "tr":
            assert not TR_HARF.search(metin), f"{dil}: {metin}"
    # Kayittaki DONMUS metin artik gosterilmiyor.
    assert "eski turkce ozet" not in metinler.values()


def test_kimliksiz_eski_kayit_mesaji_aynen_doner(client, world, owner_conn):
    """Tur 16 oncesi satirlarda kimlik NULL — geri uyumluluk."""
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO notification (tenant_id, tip, mesaj, dedup_key) "
            "VALUES (%s,'kacirilan_tur',%s,%s) RETURNING id",
            (world["a"], "ESKI KAYIT METNI", f"eski-{uuid.uuid4().hex[:8]}"),
        )
        nid = cur.fetchone()[0]
    h = _headers(client, world["slug_a"], world["admin_a"])
    r = client.get("/notifications?limit=200", headers={**h, "Accept-Language": "en"})
    satir = next(i for i in r.json()["items"] if i["id"] == str(nid))
    assert satir["mesaj"] == "ESKI KAYIT METNI"
    assert satir["mesaj_kimlik"] is None
