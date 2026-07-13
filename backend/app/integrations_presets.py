"""Entegrasyon PRESET'leri (C1b) — generic webhook uzerinde makul varsayilanlar.

DURUST SINIR: bunlar gercek cihaz surucusu DEGIL, sadece generic HTTP webhook
sablonlaridir (marka-bagimsiz). Panel/mobil formu bu varsayilanlarla ON-DOLDURUR;
kullanici duzenleyebilir. payload_template `{{message}}` / `{{title}}` yer
tutucularini destekler (tetikte doldurulur).
"""
from __future__ import annotations

PRESETS: dict[str, dict] = {
    "webhook-generic": {
        "channel_type": "webhook",
        "http_method": "POST",
        "headers_json": {"Content-Type": "application/json"},
        "payload_template": '{"text": "{{message}}"}',
    },
    "megaphone-generic": {
        "channel_type": "megaphone",
        "http_method": "POST",
        "headers_json": {"Content-Type": "application/json"},
        "payload_template": '{"announcement": "{{message}}"}',
    },
    "smarthome-generic": {
        "channel_type": "smarthome",
        "http_method": "POST",
        "headers_json": {"Content-Type": "application/json"},
        "payload_template": '{"event": "{{title}}", "detail": "{{message}}"}',
    },
}


def render_template(template: str, *, message: str, title: str) -> str:
    """{{message}}/{{title}} yer tutucularini doldur (basit, guvenli replace)."""
    return template.replace("{{message}}", message).replace("{{title}}", title)
