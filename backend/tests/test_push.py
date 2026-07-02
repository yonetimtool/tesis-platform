"""FCM push: provider (noop/fcm/mock format/unconfigured) + dispatch kanca wiring +
device token secimi (RLS) + /devices CRUD (idempotent, tenant-izole, RBAC) + push
in-app bildirimi kirmiyor.

client -> CALISAN API (ayri surec): provider monkeypatch'i ancak IN-PROCESS testte
gecerli; API testleri gercek DB uzerinden calisir (server PUSH_PROVIDER=noop)."""
from __future__ import annotations

import uuid

import app.push as push
from app.scheduler import notify


# --------------------------- provider (in-process) -------------------------- #
def test_get_push_provider_selection(monkeypatch):
    monkeypatch.setattr(push.settings, "push_provider", "noop")
    assert isinstance(push.get_push_provider(), push.NoopPushProvider)
    monkeypatch.setattr(push.settings, "push_provider", "fcm")
    assert isinstance(push.get_push_provider(), push.FcmProvider)
    monkeypatch.setattr(push.settings, "push_provider", "bilinmeyen")
    assert isinstance(push.get_push_provider(), push.NoopPushProvider)  # varsayilan noop


def test_fcm_send_message_format(monkeypatch):
    monkeypatch.setattr(push.settings, "fcm_project_id", "proj-123")
    monkeypatch.setattr(push.settings, "fcm_service_account_json", '{"type":"service_account"}')
    monkeypatch.setattr(push.settings, "fcm_base_url", "https://fcm.googleapis.com")
    monkeypatch.setattr(push, "_fetch_access_token", lambda sa: "ACCESS-TOKEN")
    captured: dict = {}

    def fake_post(url, headers, body, timeout=20.0):
        captured.update(url=url, headers=headers, body=body)
        return {"name": "projects/proj-123/messages/1"}

    monkeypatch.setattr(push, "_http_post_json", fake_post)

    res = push.FcmProvider().send(["TOK1"], title="Baslik", body="Govde", data={"k": "v", "n": 1})
    assert res.status == "sent" and res.sent == 1 and res.provider == "fcm"
    assert captured["url"] == "https://fcm.googleapis.com/v1/projects/proj-123/messages:send"
    assert captured["headers"]["Authorization"] == "Bearer ACCESS-TOKEN"
    assert captured["body"] == {
        "message": {
            "token": "TOK1",
            "notification": {"title": "Baslik", "body": "Govde"},
            "data": {"k": "v", "n": "1"},  # data degerleri string'e cevrilir
        }
    }


def test_fcm_unconfigured_no_http_no_raise(monkeypatch):
    monkeypatch.setattr(push.settings, "fcm_project_id", "")
    monkeypatch.setattr(push.settings, "fcm_service_account_json", "")
    calls = []
    monkeypatch.setattr(push, "_http_post_json", lambda *a, **k: calls.append(1))
    res = push.FcmProvider().send(["T"], title="t", body="b")
    assert res.status == "push_unconfigured" and res.sent == 0 and calls == []


def test_noop_provider(monkeypatch):
    res = push.NoopPushProvider().send(["A", "B"], title="t", body="b")
    assert res.status == "noop" and res.sent == 0


# ------------------------ dispatch_external wiring -------------------------- #
def test_dispatch_calls_provider_with_tokens(monkeypatch):
    monkeypatch.setattr(notify, "_fetch_device_tokens", lambda t, r: ["TOKX", "TOKY"])
    rec = []

    class Recorder:
        def send(self, tokens, *, title, body, data=None):
            rec.append((list(tokens), title, body, data))

    monkeypatch.setattr(notify.push, "get_push_provider", lambda: Recorder())
    notify.dispatch_external(
        "mesaj", tenant_id=uuid.uuid4(), target_roles=("admin",), title="TT", data={"a": "b"}
    )
    assert rec == [(["TOKX", "TOKY"], "TT", "mesaj", {"a": "b"})]


def test_dispatch_without_target_is_noop(monkeypatch):
    calls = []
    monkeypatch.setattr(notify, "_fetch_device_tokens", lambda t, r: calls.append("fetch") or [])

    class P:
        def send(self, *a, **k):
            calls.append("send")

    monkeypatch.setattr(notify.push, "get_push_provider", lambda: P())
    notify.dispatch_external("x")  # tenant_id/roles yok -> eski no-op
    assert calls == []


def test_dispatch_push_error_does_not_raise(monkeypatch):
    monkeypatch.setattr(notify, "_fetch_device_tokens", lambda t, r: ["T"])

    class Boom:
        def send(self, *a, **k):
            raise RuntimeError("fcm down")

    monkeypatch.setattr(notify.push, "get_push_provider", lambda: Boom())
    # push cokerse dispatch_external RAISE ETMEZ (in-app akisi korunur)
    notify.dispatch_external("x", tenant_id=uuid.uuid4(), target_roles=("admin",))


# ------------------------------- API + DB ---------------------------------- #
def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _register(client, headers, token, platform="android"):
    return client.post("/devices", headers=headers, json={"fcm_token": token, "platform": platform})


def test_register_idempotent_and_platform_enum(client, world):
    guard = _headers(client, world["slug_a"], world["guard_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])
    tok = f"DUP-{uuid.uuid4().hex[:8]}"

    r1 = _register(client, guard, tok, "android")
    assert r1.status_code == 201, r1.text
    dev_id = r1.json()["id"]

    r2 = _register(client, guard, tok, "ios")  # ayni token -> idempotent upsert
    assert r2.status_code in (200, 201)
    assert r2.json()["id"] == dev_id  # tek kayit
    assert r2.json()["platform"] == "ios"  # guncellendi

    items = client.get("/devices", headers=admin).json()["items"]
    assert sum(1 for d in items if d["fcm_token"] == tok) == 1

    # gecersiz platform -> 422
    bad = client.post("/devices", headers=guard, json={"fcm_token": "X", "platform": "symbian"})
    assert bad.status_code == 422


def test_unregister_deactivates(client, world):
    guard = _headers(client, world["slug_a"], world["guard_a"])
    tok = f"BYE-{uuid.uuid4().hex[:8]}"
    _register(client, guard, tok)
    assert client.delete(f"/devices/{tok}", headers=guard).status_code == 204

    from app.scheduler.notify import _fetch_device_tokens

    assert tok not in _fetch_device_tokens(world["a"], ("admin", "security"))
    # tekrar -> 404 (pasif/yok)
    assert client.delete(f"/devices/{tok}", headers=guard).status_code == 404


def test_devices_rbac(client, world):
    resident = _headers(client, world["slug_a"], world["resident_a"])
    # resident kendi cihazini kaydedebilir
    assert _register(client, resident, f"RES-{uuid.uuid4().hex[:6]}", "web").status_code == 201
    # ama liste (debug) yalniz admin
    assert client.get("/devices", headers=resident).status_code == 403


def test_fetch_tokens_role_and_tenant_isolation(client, world):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    guard_a = _headers(client, world["slug_a"], world["guard_a"])
    cleaning_a = _headers(client, world["slug_a"], world["cleaning_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])

    ta = uuid.uuid4().hex[:6]
    _register(client, admin_a, f"ADM-A-{ta}", "android")
    _register(client, guard_a, f"GRD-A-{ta}", "ios")
    _register(client, cleaning_a, f"CLN-A-{ta}", "web")
    _register(client, admin_b, f"ADM-B-{ta}", "android")

    from app.scheduler.notify import _fetch_device_tokens

    toks = set(_fetch_device_tokens(world["a"], ("admin", "security")))
    # admin + security (guard) A -> VAR; cleaning A ve B tenant -> YOK
    assert f"ADM-A-{ta}" in toks and f"GRD-A-{ta}" in toks
    assert f"CLN-A-{ta}" not in toks
    assert f"ADM-B-{ta}" not in toks
    # B tarafi kendi token'ini gorur, A'ninkini gormez (tenant izolasyon)
    toks_b = set(_fetch_device_tokens(world["b"], ("admin", "security")))
    assert f"ADM-B-{ta}" in toks_b and f"ADM-A-{ta}" not in toks_b


def test_emergency_push_hook_does_not_break_in_app(client, world):
    """Acil durum -> push kancasi tetiklenir (server noop) AMA in-app notification yine yazilir."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    _register(client, admin, f"ADM-DEV-{uuid.uuid4().hex[:6]}", "android")

    key = uuid.uuid4().hex
    r = client.post(
        "/emergency", headers={**guard, "Idempotency-Key": key}, json={"notlar": "yangin"}
    )
    assert r.status_code == 201, r.text
    # push EK gonderim; in-app acil_durum bildirimi kirilmadan olustu
    notifs = client.get("/notifications", headers=admin).json()["items"]
    assert any(n["tip"] == "acil_durum" for n in notifs)
