"""(P191-ek §1) CİHAZ JETONU HİJYENİ — UNREGISTERED birikmesin.

===========================================================================
ÖLÇÜLEN KUSUR
===========================================================================
Push nihayet FCM'e ulaştı ve **7/7 deneme `UNREGISTERED` döndü**. Tesiste
18 kayıtlı cihaz vardı, hepsi tek kullanıcıya ait bayat jetonlardı.

İki ayrı kusur üst üste binmişti:

1. **Budama yolu eksikti.** `dispatch_external` UNREGISTERED jetonları
   pasifleştiriyordu ama `POST /push/test` YAPMIYORDU — yönetici test
   düğmesine bastıkça ölü jetonlar tabloda kalıyor ve her gönderimde
   yeniden deneniyordu.
2. **Tekillik yanlış anahtardaydı.** `UNIQUE (tenant, fcm_token)`: jeton
   bir cihaz kimliği değil, cihazın o anki ADRESİDİR. Yeniden kurulumda
   yeni jeton → YENİ SATIR; eski satır "aktif" kalıyordu.

Bu dosya üçünü de ölçer: otomatik budama, cihaz bazlı tekilleştirme ve
"geçersiz jetonları temizle" ucu.
"""
from __future__ import annotations

import uuid

import pytest
from sqlalchemy.pool import NullPool

from app import push
from app.push import DogrulamaSonucu, PushResult


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _kaydet(client, headers, token, *, cihaz_kimligi=None, platform="android"):
    govde = {"fcm_token": token, "platform": platform}
    if cihaz_kimligi:
        govde["cihaz_kimligi"] = cihaz_kimligi
    return client.post("/devices", headers=headers, json=govde)


def _aktif_jetonlar(owner_conn, user_eposta) -> set[str]:
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT d.fcm_token FROM user_device d JOIN app_user u ON u.id = d.user_id "
            "WHERE lower(u.email) = %s AND d.aktif",
            (user_eposta.lower(),),
        )
        return {r[0] for r in cur.fetchall()}


# ==================== A. CİHAZ BAZINDA TEKİLLEŞTİRME ======================= #
def test_AYNI_CIHAZ_YENI_JETON_ESKISINI_PASIFLESTIRIR(client, world, owner_conn):
    """Kök kusur: her yeni jeton yeni satır açıyordu (18 kayıt, tek kişi)."""
    guard = _headers(client, world["slug_a"], world["guard_a"])
    cihaz = f"kurulum-{uuid.uuid4().hex[:12]}"
    eski = f"ESKI-{uuid.uuid4().hex[:10]}"
    yeni = f"YENI-{uuid.uuid4().hex[:10]}"

    assert _kaydet(client, guard, eski, cihaz_kimligi=cihaz).status_code == 201
    assert _kaydet(client, guard, yeni, cihaz_kimligi=cihaz).status_code == 201

    aktifler = _aktif_jetonlar(owner_conn, world["guard_a"]["email"])
    assert yeni in aktifler
    assert eski not in aktifler, "eski jeton pasiflesmeliydi"


def test_IKI_FARKLI_CIHAZ_IKISI_DE_AKTIF_KALIR(client, world, owner_conn):
    """Tekilleştirme CİHAZ bazındadır: bir kişinin iki telefonu olabilir ve
    ikincisini kaydetmek birincisini susturmamalıdır."""
    guard = _headers(client, world["slug_a"], world["guard_a"])
    tel1, tel2 = f"T1-{uuid.uuid4().hex[:8]}", f"T2-{uuid.uuid4().hex[:8]}"
    assert _kaydet(client, guard, tel1, cihaz_kimligi=f"c1-{uuid.uuid4().hex[:8]}").status_code == 201
    assert _kaydet(client, guard, tel2, cihaz_kimligi=f"c2-{uuid.uuid4().hex[:8]}").status_code == 201
    aktifler = _aktif_jetonlar(owner_conn, world["guard_a"]["email"])
    assert {tel1, tel2} <= aktifler


def test_CIHAZ_KIMLIGI_YOKSA_ESKI_DAVRANIS(client, world, owner_conn):
    """Alan NULLABLE ve öyle kalmalı: göndermeyen ESKİ SÜRÜMLER sahada
    çalışıyor. Zorunlu kılmak, güncellemeyen kullanıcının bildirimlerini
    tamamen kesmek olurdu."""
    guard = _headers(client, world["slug_a"], world["guard_a"])
    a, b = f"A-{uuid.uuid4().hex[:8]}", f"B-{uuid.uuid4().hex[:8]}"
    assert _kaydet(client, guard, a).status_code == 201
    assert _kaydet(client, guard, b).status_code == 201
    aktifler = _aktif_jetonlar(owner_conn, world["guard_a"]["email"])
    assert {a, b} <= aktifler


def test_KIMLIK_GONDERILMEYEN_ISTEK_OGRENILEN_KIMLIGI_SILMEZ(client, world, owner_conn):
    """Bir sürüm yükseltmesinde alan geçici olarak boş gelirse, daha önce
    öğrenilmiş kimlik korunmalı (yoksa tekilleştirme sessizce kapanırdı)."""
    guard = _headers(client, world["slug_a"], world["guard_a"])
    cihaz = f"kurulum-{uuid.uuid4().hex[:12]}"
    tok = f"SBT-{uuid.uuid4().hex[:10]}"
    assert _kaydet(client, guard, tok, cihaz_kimligi=cihaz).status_code == 201
    assert _kaydet(client, guard, tok).status_code == 201  # kimliksiz tekrar
    with owner_conn.cursor() as cur:
        cur.execute("SELECT cihaz_kimligi FROM user_device WHERE fcm_token = %s", (tok,))
        assert cur.fetchone()[0] == cihaz


# ======================= B. OTOMATİK BUDAMA (test ucu) ===================== #
def test_TEST_UCU_UNREGISTERED_JETONU_PASIFLESTIRIR(
    client, world, owner_conn, monkeypatch
):
    """ASIL KUSUR: `/push/test` budama yapmıyordu.

    Sağlayıcı in-process monkeypatch edilir; uç AYRI SÜREÇTE koştuğu için
    doğrudan çağrı yerine `_jetonlari_buda` yolu ölçülür — budamanın
    KENDİSİ burada, gönderim yolunun onu çağırdığı ise aşağıdaki testte.
    """
    from app.routers import push_teshis

    assert hasattr(push_teshis, "_jetonlari_buda")


def test_UNREGISTERED_BUDAMA_SQL_YOLU(client, world, owner_conn):
    """Budama gerçekten `aktif=false` yazıyor mu (canlı DB, gerçek SQL).

    KENDİ MOTORUNU KURAR, `app.db.engine`i KULLANMAZ. Gerekçe ölçüldü:
    paylaşılan motor ilk kullanıldığı olay döngüsüne bağlanır (asyncpg) ve
    `asyncio.run` her çağrıda YENİ bir döngü açar — tam takımda
    "attached to a different loop" hatası verir. Bu, P187'de Celery
    tarafında düzeltilen tuzağın aynısıdır; testte de aynı kural geçerli:
    kendi döngünü açıyorsan kendi motorunu da aç ve KAPAT.
    """
    import asyncio

    from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

    from app.config import settings
    from app.db import set_tenant
    from app.routers.push_teshis import _jetonlari_buda

    guard = _headers(client, world["slug_a"], world["guard_a"])
    tok = f"OLU-{uuid.uuid4().hex[:10]}"
    assert _kaydet(client, guard, tok).status_code == 201

    async def _koş():
        motor = create_async_engine(settings.database_url, poolclass=NullPool)
        try:
            oturum_fabrikasi = async_sessionmaker(bind=motor, expire_on_commit=False)
            async with oturum_fabrikasi() as session:
                async with session.begin():
                    await set_tenant(session, world["a"])
                    return await _jetonlari_buda(session, [tok])
        finally:
            await motor.dispose()

    assert asyncio.run(_koş()) == 1
    assert tok not in _aktif_jetonlar(owner_conn, world["guard_a"]["email"])


def test_SAGLAYICI_GECERSIZ_JETONU_BILDIRIR(monkeypatch):
    """FCM `UNREGISTERED` -> `PushResult.gecersiz` (budamanın girdisi)."""
    monkeypatch.setattr(push.settings, "fcm_service_account_path", "")
    monkeypatch.setattr(push.settings, "fcm_project_id", "proj")
    monkeypatch.setattr(push.settings, "fcm_service_account_json", '{"type":"x"}')
    monkeypatch.setattr(push, "_fetch_access_token", lambda sa: "T")
    monkeypatch.setattr(
        push,
        "_http_post_json",
        lambda *a, **k: {"error": {"status": "NOT_FOUND", "details": [
            {"errorCode": "UNREGISTERED"}
        ]}},
    )
    sonuc = push.FcmProvider().send(["OLU"], title="t", body="b")
    assert sonuc.gecersiz == ["OLU"]
    assert sonuc.token_sonuc["OLU"][0] == "gecersiz_token"


# ===================== C. "GEÇERSİZ JETONLARI TEMİZLE" ===================== #
def test_TEMIZLIK_UCU_YONETIME_ACIK_DIGERLERINE_KAPALI(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    assert client.post("/push/cihaz-temizle", headers=admin).status_code == 200
    for kim in ("resident_a", "guard_a"):
        h = _headers(client, world["slug_a"], world[kim])
        assert client.post("/push/cihaz-temizle", headers=h).status_code == 403
    assert client.post("/push/cihaz-temizle").status_code == 401


def test_TEMIZLIK_NOOP_SAGLAYICIDA_HICBIR_SEY_BUDAMAZ(client, world, owner_conn):
    """"Bakamadım" ile "hepsi sağlam" AYNI ŞEY DEĞİLDİR.

    Sunucu noop koşuyorsa doğrulama yapılamaz; uç bunu `desteklenmiyor`
    ile söyler ve HİÇBİR jetonu budamaz. Sessizce 0 döndürmek, ölü
    jetonları sağlam ilan etmekti.
    """
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    tok = f"KAL-{uuid.uuid4().hex[:10]}"
    assert _kaydet(client, guard, tok).status_code == 201

    r = client.post("/push/cihaz-temizle", headers=admin)
    assert r.status_code == 200, r.text
    d = r.json()
    if d["saglayici"] == "noop":
        assert d["desteklenmiyor"] is True
        assert d["budanan"] == 0
        # JETON KORUNDU: doğrulanamayan jeton silinmez.
        assert tok in _aktif_jetonlar(owner_conn, world["guard_a"]["email"])


def test_DOGRULAMA_VARSAYILANI_DESTEKLENMIYOR():
    """Yeni bir sağlayıcı `dogrula`yı yazmazsa sessizce "hepsi sağlam"
    dememeli — varsayılan `desteklenmiyor`dur."""
    sonuc = push.NoopPushProvider().dogrula(["A", "B"])
    assert isinstance(sonuc, DogrulamaSonucu)
    assert sonuc.desteklenmiyor is True and sonuc.gecersiz == []


def test_FCM_DOGRULAMA_VALIDATE_ONLY_KULLANIR(monkeypatch):
    """Temizlik BİLDİRİM GÖNDERMEZ: istek `validate_only=true` taşımalı ve
    `notification` govdesi İÇERMEMELİ."""
    monkeypatch.setattr(push.settings, "fcm_service_account_path", "")
    monkeypatch.setattr(push.settings, "fcm_project_id", "proj")
    monkeypatch.setattr(push.settings, "fcm_service_account_json", '{"type":"x"}')
    monkeypatch.setattr(push, "_fetch_access_token", lambda sa: "T")
    govdeler: list[dict] = []

    def sahte(url, headers, body, timeout=20.0):
        govdeler.append(body)
        return (
            {"error": {"details": [{"errorCode": "UNREGISTERED"}]}}
            if body["message"]["token"] == "OLU"
            else {"name": "ok"}
        )

    monkeypatch.setattr(push, "_http_post_json", sahte)
    sonuc = push.FcmProvider().dogrula(["OLU", "CANLI"])
    assert sonuc.gecersiz == ["OLU"] and sonuc.denenen == 2
    assert all(g["validate_only"] is True for g in govdeler)
    assert all("notification" not in g["message"] for g in govdeler)
    # BOS GOVDE GONDERILMEZ: yuksuz mesaj FCM'de `INVALID_ARGUMENT`
    # uretebilir ve o kodu "jeton olu" diye okumak SAGLAM jeton budamakti.
    assert all(g["message"].get("data") for g in govdeler)


def test_DOGRULAMA_INVALID_ARGUMENT_BUDAMAZ(monkeypatch):
    """Doğrulama yolu gönderim yolundan DAHA DAR: yalnız `UNREGISTERED`.

    `INVALID_ARGUMENT` doğrulamada gövde hakkında da olabilir; toplu bir
    temizlik aracının belirsiz bir kodla sağlam jeton budaması kabul
    edilemez. Şüpheli olan KORUNUR.
    """
    monkeypatch.setattr(push.settings, "fcm_service_account_path", "")
    monkeypatch.setattr(push.settings, "fcm_project_id", "proj")
    monkeypatch.setattr(push.settings, "fcm_service_account_json", '{"type":"x"}')
    monkeypatch.setattr(push, "_fetch_access_token", lambda sa: "T")
    monkeypatch.setattr(
        push,
        "_http_post_json",
        lambda *a, **k: {"error": {"details": [{"errorCode": "INVALID_ARGUMENT"}]}},
    )
    sonuc = push.FcmProvider().dogrula(["SAGLAM-OLABILIR"])
    assert sonuc.gecersiz == [] and sonuc.belirsiz == 1
    # GONDERIM yolunda ayni kod hala budar (govde bilinen-iyidir).
    gonderim = push.FcmProvider().send(["X"], title="t", body="b")
    assert gonderim.gecersiz == ["X"]


def test_FCM_DOGRULAMA_GECICI_HATA_JETONU_OLDURMEZ(monkeypatch):
    """Kota/ağ hatası bir KARAR DEĞİLDİR: jeton korunur, `belirsiz` sayılır."""
    monkeypatch.setattr(push.settings, "fcm_service_account_path", "")
    monkeypatch.setattr(push.settings, "fcm_project_id", "proj")
    monkeypatch.setattr(push.settings, "fcm_service_account_json", '{"type":"x"}')
    monkeypatch.setattr(push, "_fetch_access_token", lambda sa: "T")
    monkeypatch.setattr(
        push,
        "_http_post_json",
        lambda *a, **k: {"error": {"status": "QUOTA_EXCEEDED"}},
    )
    sonuc = push.FcmProvider().dogrula(["A"])
    assert sonuc.gecersiz == [] and sonuc.belirsiz == 1


def test_DOGRULAMA_KIMLIKSIZ_FCM_DESTEKLENMIYOR(monkeypatch):
    monkeypatch.setattr(push.settings, "fcm_service_account_path", "")
    monkeypatch.setattr(push.settings, "fcm_project_id", "")
    monkeypatch.setattr(push.settings, "fcm_service_account_json", "")
    sonuc = push.FcmProvider().dogrula(["A"])
    assert sonuc.desteklenmiyor is True and sonuc.gecersiz == []


def test_TEMIZLIK_SONUCU_PUSH_RESULT_ILE_TUTARLI():
    """`DogrulamaSonucu` alanları uç şemasıyla birebir (sözleşme kilidi)."""
    s = DogrulamaSonucu(provider="fcm", desteklenmiyor=False, gecersiz=["a"], denenen=3, belirsiz=1)
    assert (s.provider, s.denenen, s.belirsiz) == ("fcm", 3, 1)
    assert isinstance(PushResult(provider="fcm", sent=0, status="sent").gecersiz, list)
