"""(P247 §5) BILDIRIM GORUNUMU — gruplama, kaynak, aciliyet, kilit, rozet.

Kabul olcutu 10: "gruplu/gonderenli/onizlemeli bildirim; acil olanlar
yuksek oncelikli". Govde FCM'e giden JSON'un KENDISI uzerinden olculur
(`_http_post_json` taklit edilir) — cihazdaki gorunum burada OLCULEMEZ,
`docs/P247-kararlar.md` §5 "olculemeyenler".
"""
from __future__ import annotations

import ast
import pathlib
import uuid

import pytest

from app import push, push_gorunum
from app.push_gorunum import ACIL_TIPLER, gorunum_kur, grup, hedef_rol
from app.scheduler import notify


def _fcm(monkeypatch):
    giden: list[dict] = []
    monkeypatch.setattr(push, "_load_service_account", lambda: {"project_id": "p"})
    monkeypatch.setattr(push, "_fetch_access_token", lambda sa: "t")
    monkeypatch.setattr(push, "_http_post_json", lambda u, h, b: giden.append(b) or {})
    return giden


def test_PANIK_ACIL_SES_KAPALI_OLSA_BILE_YUKSEK_ONCELIK(monkeypatch):
    giden = _fcm(monkeypatch)
    tid = uuid.uuid4()
    g = gorunum_kur("panik_alarm", tenant_id=tid, data={"panik_id": "p1"},
                    kaynak="Güneş Sitesi", rozet={"tok": 3})
    # Sessiz kanal (kullanici sesi kapatmis): ses YOK ama teslim GECIKMEZ.
    push.FcmProvider().send(["tok"], title="PANİK", body="A Blok 3",
                            kanal="yonetio_sessiz_v2", ses=None, gorunum=g)
    m = giden[0]["message"]
    an = m["android"]["notification"]
    assert m["android"]["priority"] == "high"
    assert an["notification_priority"] == "PRIORITY_MAX"
    assert an["visibility"] == "PUBLIC"
    assert an["tag"] == "acil:p1"
    assert an["notification_count"] == 3
    assert an["title"] == "PANİK · Güneş Sitesi"
    aps = m["apns"]["payload"]["aps"]
    assert aps["thread-id"] == f"{tid}:acil"
    assert aps["interruption-level"] == "time-sensitive"
    assert aps["badge"] == 3
    assert aps["alert"] == {"title": "PANİK", "body": "A Blok 3", "subtitle": "Güneş Sitesi"}
    assert "sound" not in aps  # sessiz tercih korunur
    assert m["apns"]["headers"]["apns-priority"] == "10"
    assert m["apns"]["headers"]["apns-collapse-id"] == "acil:p1"


def test_SIRADAN_BILDIRIM_KILITTE_OZEL_ve_ETKIN(monkeypatch):
    giden = _fcm(monkeypatch)
    g = gorunum_kur("kargo", tenant_id=uuid.uuid4(), data={"kargo_id": "k1"},
                    kaynak="Site", rozet={})
    push.FcmProvider().send(["tok"], title="Kargo", body="Aras", kanal="yonetio_genel_v2",
                            ses="default", gorunum=g)
    m = giden[0]["message"]
    assert m["android"]["priority"] == "high"   # sesli -> eski kural
    assert m["android"]["notification"]["visibility"] == "PRIVATE"
    assert "notification_priority" not in m["android"]["notification"]
    assert m["apns"]["payload"]["aps"]["interruption-level"] == "active"
    assert m["apns"]["payload"]["aps"]["sound"] == "default"
    assert "badge" not in m["apns"]["payload"]["aps"]


def test_GURULTU_ESKALASYONU_ACIL():
    for k in ("gurultu_eskalasyon_guvenlik", "gurultu_eskalasyon_yonetim",
              "panik_kategori_yangin", "akilli_ev_yangin"):
        assert push_gorunum.acil_mi(k), k
    assert not push_gorunum.acil_mi("gurultu_uyari_sakin")
    assert not push_gorunum.acil_mi("panik_kapandi")


def test_HER_BILDIRIM_KIMLIGININ_BIR_GRUBU_VAR():
    """Yeni bir push kimligi eklenip gruba baglanmazsa "genel" yiginina
    duser — bu kilit onu yakalar."""
    kaynak = pathlib.Path(push.__file__).with_name("push_metinleri.py").read_text()
    kimlikler: set[str] = set()
    for n in ast.walk(ast.parse(kaynak)):
        hedef = getattr(n, "target", None) or (getattr(n, "targets", None) or [None])[0]
        if getattr(hedef, "id", "") == "METINLER" and isinstance(n.value, ast.Dict):
            kimlikler = {k.value for k in n.value.keys if isinstance(k, ast.Constant)}
    assert kimlikler, "METINLER okunamadi"
    genelde = {k for k in kimlikler if grup(k) == "genel"} - {"test", "portal_iletisim"}
    assert not genelde, f"gruba baglanmamis push kimlikleri: {sorted(genelde)}"
    assert ACIL_TIPLER <= kimlikler | {"akilli_ev_yangin"}


def test_HEDEF_ROL_IKI_ROLLU_KISIDE_SAKIN_BILDIRIMI_SAKIN_MODUNDA():
    assert hedef_rol("kargo", "yonetici", kisi_hedefli=True) == "resident"
    assert hedef_rol("aidat_borc", "yonetici", kisi_hedefli=True) == "resident"
    # Rol yayini: yonetici olarak aldi.
    assert hedef_rol("yeni_talep", "yonetici", kisi_hedefli=False) == "yonetici"
    assert hedef_rol("kargo", "yonetici", kisi_hedefli=False) == "yonetici"
    # Yonetim bildirimi kisi hedefli de olsa yonetici modunda.
    assert hedef_rol("gider_onay", "yonetici", kisi_hedefli=True) == "yonetici"
    assert hedef_rol("kargo", "resident", kisi_hedefli=True) == "resident"


def test_DISPATCH_GORUNUM_ve_HEDEF_ROL_TASIR(monkeypatch):
    """Uctan uca dagitici: hedef rol `data`da, rozet ve kaynak gorunumde."""
    y, s = uuid.uuid4(), uuid.uuid4()
    monkeypatch.setattr(notify, "_fetch_device_tokens_for_users", lambda t, ids: [
        notify.Cihaz("TOK-Y", "tr", y, "ios", True, rol="yonetici", kisi_hedefli=True),
        notify.Cihaz("TOK-S", "tr", s, "android", True, rol="resident", kisi_hedefli=True),
    ])
    monkeypatch.setattr(notify, "_gorunum_bilgisi", lambda t, ids: ("Güneş", {y: 4}))
    kayit = []

    class Kaydedici:
        name = "kaydedici"

        def send(self, tokens, *, title, body, data=None, kanal=None, ses=None, gorunum=None):
            kayit.append((list(tokens), dict(data or {}), gorunum))

    monkeypatch.setattr(notify.push, "get_push_provider", lambda: Kaydedici())
    notify.dispatch_external("kargo", tenant_id=uuid.uuid4(), target_user_ids=(y, s),
                             params={"firma": "Aras", "daire": "3"},
                             data={"tip": "kargo", "kargo_id": "k9"})
    # Iki kisi de sakin modunda acar -> ayni grup, tek gonderim.
    assert len(kayit) == 1
    tokens, data, g = kayit[0]
    assert sorted(tokens) == ["TOK-S", "TOK-Y"]
    assert data["hedef_rol"] == "resident"
    assert g.kaynak == "Güneş" and g.etiket == "kargo:k9"
    # Rozet: okunmamis + bu bildirim.
    assert g.rozet == {"TOK-Y": 5, "TOK-S": 1}


# ------------------------- ROZET = UYGULAMADAKI SAYI ------------------------ #
def _giris(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.mark.parametrize("kim", ["resident_a", "guard_a", "yonetici_a"])
def test_ROZET_SAYISI_UYGULAMADAKI_OKUNMAMIS_SAYISIYLA_AYNI(client, world, owner_conn, app_conn, kim):
    tid = world["a"]
    h = _giris(client, world["slug_a"], world[kim])
    me = client.get("/me", headers=h).json()
    uid = uuid.UUID(me["id"])
    # Uc tur satir: kisinin kendi satiri, ortak yonetim alarmi, guvenligin
    # GORMEDIGI ortak bakim satiri.
    eklenen = []
    with owner_conn.cursor() as cur:
        for tip, sahip in (("kargo", uid), ("kacirilan_tur", None), ("bakim_bugun", None)):
            nid = uuid.uuid4()
            cur.execute(
                "INSERT INTO notification (id, tenant_id, tip, user_id, mesaj) "
                "VALUES (%s, %s, %s, %s, 'p247')", (nid, tid, tip, sahip))
            eklenen.append(nid)
    try:
        beklenen = client.get("/notifications?okundu=false&limit=1", headers=h).json()["meta"]["total"]
        with app_conn.cursor() as cur:
            cur.execute("SELECT set_config('app.current_tenant_id', %s, true)", (str(tid),))
            sayi = notify.okunmamis_sayilari(cur, [uid]).get(uid, 0)
        assert sayi == beklenen, (kim, sayi, beklenen)
        assert beklenen >= 1
    finally:
        with owner_conn.cursor() as cur:
            cur.execute("DELETE FROM notification WHERE id = ANY(%s)", (eklenen,))
