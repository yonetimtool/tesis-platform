"""(P247 §6) GENEL YAZMA DENETIMI — kimlikli her basarili mutasyon izi.

=========================================================================
NEDEN
=========================================================================
Uc guvenlik envanteri 92 kimlikli yazma ucunun HICBIR denetim satiri
yazmadigini gosterdi: duyuru, gorev, kontrol noktasi, devriye plani, SDM
anahtari, tesis yonetimi (yonetici ekle/sil, kimlik sifirla)... "Bu kaydi
kim, ne zaman degistirdi" sorusu bu uclarda YANITSIZDI.

Her uca elle `audit_user` eklemek dogru ama unutulur (envanter bunu
kanitliyor). Bu ara katman ALT SINIRDIR: kimlikli, basarili (2xx) her
POST/PUT/PATCH/DELETE icin `api_yazma` satiri — kim (jeton), ne (route
SABLONU + kaynak id), sonuc (durum). Ozel denetim yazan uclar zengin
satirlarini KORUR; bu satir onlarin yerine gecmez, ustune eklenir.

GOVDE YAZILMAZ: istek govdesi kisisel veri tasir (telefon, e-posta, not);
denetim "ne yapildi"yi kaydeder, "ne yazildi"yi degil (KVKK — veri
minimizasyonu). Ayrinti gereken uc ozel denetimini yazar.

YAZIM YANITTAN SONRA ve BAGIMSIZ ISLEMDE: denetim hatasi istegi
kirmamali; ayni islemde yazmak, basarisiz bir denetim yuzunden kullanicinin
kaydini geri almak olurdu.
"""
from __future__ import annotations

import logging
import re
import uuid

_log = logging.getLogger(__name__)

EYLEM = "api_yazma"

#: Genel denetimin YAZILMADIGI yol onekleri — her biri bilincli:
#:  * kendi denetimi olan ya da kimliksiz akislar (auth, davet, webhook),
#:  * yuksek frekansli ve kendisi zaten kayit olan olaylar (okutma),
#:  * kisinin KENDI arayuz tercihleri (tema, tur, pano) — bilgi degeri yok,
#:  * okundu isaretleri (gurultu; bildirim silme kendi denetimini yazar).
HARIC_ONEKLER = (
    "/auth/", "/davet/", "/webhooks/", "/dukkan/", "/public/",
    "/akilli-ev/olay", "/integrations/anpr/events",
    "/notifications", "/me/tur-goruldu", "/me/tema", "/me/gorunum",
    "/me/pano-tercihi", "/devices", "/uploads/presign", "/surum/kontrol",
)

_UUID = re.compile(r"^[0-9a-fA-F-]{36}$")


#: Onek haric tutulsa da DENETLENEN yollar: kimlik baglama/cozme bir
#: GUVENLIK olayidir (hesaba yeni bir giris kapisi acar ya da kapatir).
DAHIL_ONEKLER = ("/auth/oauth/baglantilarim",)
#: Tam eslesme ile haric: saha okutmasi yuksek frekansli ve kendisi kayittir
#: (`scan_event`). `/scans/simule` gibi alt yollar DENETLENIR.
HARIC_TAM = ("/scans",)


def denetlenir_mi(metot: str, yol_sablonu: str) -> bool:
    if metot not in ("POST", "PUT", "PATCH", "DELETE"):
        return False
    if yol_sablonu.startswith(DAHIL_ONEKLER):
        return True
    if yol_sablonu in HARIC_TAM:
        return False
    return not yol_sablonu.startswith(HARIC_ONEKLER)


class GenelDenetim:
    def __init__(self, app) -> None:
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http" or scope.get("method") not in (
            "POST", "PUT", "PATCH", "DELETE"
        ):
            await self.app(scope, receive, send)
            return
        durum = {"kod": 0}

        async def izleyen_send(mesaj):
            if mesaj["type"] == "http.response.start":
                durum["kod"] = mesaj["status"]
            await send(mesaj)

        await self.app(scope, receive, izleyen_send)
        if 200 <= durum["kod"] < 300:
            try:
                await _yaz(scope, durum["kod"])
            except Exception:  # pragma: no cover - denetim istegi kirmaz
                _log.exception("genel denetim yazilamadi")


async def _yaz(scope, kod: int) -> None:
    route = scope.get("route")
    sablon = getattr(route, "path", None)
    if not sablon or not denetlenir_mi(scope["method"], sablon):
        return
    jeton = None
    for ad, deger in scope.get("headers") or []:
        if ad == b"authorization" and deger[:7].lower() == b"bearer ":
            jeton = deger[7:].decode("latin-1")
    if not jeton:
        return
    from .security import decode_token

    try:
        claims = decode_token(jeton, expected_type="access")
    except Exception:
        return
    tenant_id = claims.get("tenant_id")
    if not tenant_id:
        return
    kaynak_id = next(
        (str(v) for v in (scope.get("path_params") or {}).values()
         if _UUID.match(str(v))),
        None,
    )
    from .audit import record_audit
    from .db import SessionLocal, set_tenant

    async with SessionLocal() as session:
        async with session.begin():
            await set_tenant(session, tenant_id)
            await record_audit(
                session, action=EYLEM, tenant_id=tenant_id,
                actor_user_id=claims.get("sub"), actor_rol=claims.get("role"),
                resource_type=sablon, resource_id=kaynak_id,
                meta={"metot": scope["method"], "durum": kod},
            )
