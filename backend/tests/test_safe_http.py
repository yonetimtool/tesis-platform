"""SSRF kapisi + webhook gonderim birim testleri (C1b). Process-ici calisir
(app.safe_http dogrudan cagrilir; httpx sahtelenir) — ag YOK.

SSRF non-negotiable: ic/ozel/metadata hedefleri REDDEDILIR; hostname'e degil
COZULEN IP'ye bakilir (DNS-rebinding korumasi).
"""
from __future__ import annotations

import socket

import httpx
import pytest

import app.safe_http as sh
from app.safe_http import (
    SSRFBlocked,
    _pin_host_to_ips,
    send_webhook,
    validate_public_url,
)

# Public IP literal — cozum gerektirmez; kapidan GECMELI.
_PUBLIC = "http://93.184.216.34/hook"


# ------------------------------- SSRF kapisi -------------------------------- #
@pytest.mark.parametrize(
    "url",
    [
        "http://127.0.0.1/x",          # loopback
        "http://localhost/x",          # hostname -> 127.0.0.1 (cozup denetlenir)
        "http://10.0.0.5/x",           # 10/8 private
        "http://172.16.0.9/x",         # 172.16/12 private
        "http://192.168.1.10/x",       # 192.168/16 private
        "http://169.254.169.254/meta", # bulut metadata (link-local)
        "http://[::1]/x",              # IPv6 loopback
        "http://[fc00::1]/x",          # IPv6 ULA
        "http://[fe80::1]/x",          # IPv6 link-local
        "http://0.0.0.0/x",            # unspecified
        "ftp://example.com/x",         # sema disi
        "file:///etc/passwd",          # sema disi
        "http:///nohost",              # host yok
    ],
)
def test_ssrf_ic_hedefler_reddedilir(url):
    with pytest.raises(SSRFBlocked):
        validate_public_url(url)


def test_public_ip_kapidan_gecer():
    ips = validate_public_url(_PUBLIC)
    assert ips == ["93.184.216.34"]


def test_ip_pin_baglantida_dogrulanmis_ipye_sabitler(monkeypatch):
    """DNS-rebinding/TOCTOU kapatma: pin devredeyken hedef host YALNIZ
    dogrulanmis IP'ye cozulur (rebind ile private donen ikinci cozum DEVREYE
    GIRMEZ); baska host'lar gercek resolver'a duser."""
    other_called = {"n": 0}

    def _fake_real(h, port, *a, **k):
        # Rebind saldirisi: hedef host artik private'a cozuluyor OLSA BILE
        # pin bunu kullanmaz. Baska host icin gercek yol izlenir.
        if h == "victim.example":
            return [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("10.9.9.9", port))]
        other_called["n"] += 1
        return [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("8.8.8.8", port))]

    monkeypatch.setattr(sh.socket, "getaddrinfo", _fake_real)
    with _pin_host_to_ips("victim.example", ["93.184.216.34"]):
        # Hedef host: pin dogrulanmis public IP'yi doner (rebind 10.9.9.9 DEGIL)
        res = sh.socket.getaddrinfo("victim.example", 443)
        assert [r[4][0] for r in res] == ["93.184.216.34"]
        # Baska host: gercek resolver'a duser
        sh.socket.getaddrinfo("other.example", 443)
        assert other_called["n"] == 1
    # Cikista gercek getaddrinfo geri yuklendi
    assert sh.socket.getaddrinfo is _fake_real


def test_dns_rebinding_private_ip_reddedilir(monkeypatch):
    """Public GORUNEN hostname private'a cozulurse REDDEDILIR (hostname'e
    guvenilmez; cozulen IP denetlenir)."""

    def _fake_getaddrinfo(host, port, *a, **k):
        return [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("10.1.2.3", port))]

    monkeypatch.setattr(sh.socket, "getaddrinfo", _fake_getaddrinfo)
    with pytest.raises(SSRFBlocked):
        validate_public_url("http://totally-public-looking.example/x")


# ------------------------------ webhook gonder ------------------------------ #
class _FakeResp:
    def __init__(self, status):
        self.status_code = status

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def iter_bytes(self):
        yield b"ok"


class _FakeClient:
    def __init__(self, *, status=None, exc=None):
        self._status = status
        self._exc = exc

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def stream(self, method, url, headers=None, content=None):
        if self._exc:
            raise self._exc
        return _FakeResp(self._status)


def test_gonderim_basari_2xx(monkeypatch):
    monkeypatch.setattr(sh.httpx, "Client", lambda **k: _FakeClient(status=204))
    res = send_webhook("POST", _PUBLIC, headers={"X": "1"}, content=b"{}")
    assert res.ok is True and res.status == 204 and res.error is None


def test_gonderim_hata_4xx_ok_false(monkeypatch):
    monkeypatch.setattr(sh.httpx, "Client", lambda **k: _FakeClient(status=500))
    res = send_webhook("POST", _PUBLIC)
    assert res.ok is False and res.status == 500


def test_gonderim_ag_hatasi_ok_false_error(monkeypatch):
    monkeypatch.setattr(
        sh.httpx,
        "Client",
        lambda **k: _FakeClient(exc=httpx.ConnectError("baglanti yok")),
    )
    res = send_webhook("POST", _PUBLIC)
    assert res.ok is False and res.status is None and res.error


def test_gonderim_ssrf_engeli_firlatir(monkeypatch):
    # Ic hedef -> httpx'e HIC ulasmadan SSRFBlocked (validate iceride).
    called = {"n": 0}
    monkeypatch.setattr(
        sh.httpx, "Client",
        lambda **k: called.__setitem__("n", called["n"] + 1) or _FakeClient(status=200),
    )
    with pytest.raises(SSRFBlocked):
        send_webhook("POST", "http://10.0.0.1/x")
    assert called["n"] == 0  # istek DENENMEDI
