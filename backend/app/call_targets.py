"""Rol-bazli arama — "arama hedefi" soyutlamasi (C1a).

Amaç: sahadaki roller birbirine hizli ulassin. Bu tur YALNIZ 'phone' kanalini
(cihaz ceviricisi, tel: — ucretsiz, Twilio yok) uygular; ancak C1b'nin
(megafon / akilli-ev HTTP adaptorleri) yeniden yazim OLMADAN eklenebilmesi icin
KANAL soyutlamasi burada tanimlidir (channel + resolver deseni).

Gizlilik (KVKK — auth.md §4): numara YALNIZ (1) arayan rol o callee rolunu
arayabiliyorsa VE (2) callee.aranabilir=true iken aciklanir. Amaç-sınırlı
(yalniz arama), toplu listelenmez, rizasiz asla.
"""
from __future__ import annotations

from dataclasses import dataclass

from .models import AppUser

# Rol-bazli yon (tam dizin DEGIL): kim kimi arayabilir. C1a kapsamı.
# Genisletme C1b/ileride: yeni satir eklemek yeterli.
CALL_DIRECTIONS: dict[str, set[str]] = {
    "security": {"yonetici", "resident"},
    "resident": {"security"},
}

# C1a kanali: cihaz ceviricisi (tel:).
CHANNEL_PHONE = "phone"

# C1b entegrasyon kanallari — call/notify soyutlamasini GENISLETIR (phone'a
# dokunmadan). Bir Integration'in channel_type'i dogrudan bir kanal degeridir;
# tetikleme app.routers.integrations (SSRF-korumali) uzerinden yapilir. Boylece
# "yeni kanal" eklemek = yeni Integration tanimlamak, kod yeniden yazmak DEGIL.
CHANNEL_INTEGRATION = frozenset({"webhook", "megaphone", "smarthome"})

# Sistemin tanidigi tum kanallar (C1a phone + C1b entegrasyon kanallari).
KNOWN_CHANNELS = frozenset({CHANNEL_PHONE}) | CHANNEL_INTEGRATION


def is_integration_channel(channel: str) -> bool:
    """Kanal bir C1b entegrasyon kanali mi (Integration ile cozulur)?"""
    return channel in CHANNEL_INTEGRATION


@dataclass(frozen=True)
class CallTarget:
    """Cozulmus arama hedefi — kim + hangi kanal + adres.

    `channel` C1a'da hep 'phone'; `address` tel numarasi, `uri` cihaz
    cevirici icin `tel:`. C1b baska kanallar icin address/uri semantigini
    (orn. cihaz endpoint'i) yeniden kullanir — sema ayni kalir.
    """

    user_id: object
    ad: str
    role: str
    channel: str
    address: str
    uri: str


def caller_can_reach(caller_role: str, callee_role: str) -> bool:
    """Arayan rol, callee rolunu C1a yonlerine gore arayabilir mi?"""
    return callee_role in CALL_DIRECTIONS.get(caller_role, set())


def resolve_phone_target(callee: AppUser) -> CallTarget | None:
    """Telefon kanali cozucusu: riza + numara kapisi. Riza yoksa veya numara
    yoksa None (numara ASLA donmez). C1b baska kanallar icin ek resolver'lar
    ekleyecek; endpoint kanal secimini bu deseni izleyerek yapabilir.
    """
    if not callee.aranabilir:
        return None
    number = (callee.telefon or "").strip()
    if not number:
        return None
    return CallTarget(
        user_id=callee.id,
        ad=callee.ad,
        role=callee.role,
        channel=CHANNEL_PHONE,
        address=number,
        uri=f"tel:{number}",
    )
