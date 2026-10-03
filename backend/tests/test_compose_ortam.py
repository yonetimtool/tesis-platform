"""(P253 A2) `.env.prod.example`DA TARIF EDILEN HER AYAR `api`YE ULASIYOR MU.

OLCULEN KUSUR: compose'da `env_file` YOK; `environment:` acik bir beyaz
listedir. `.env.prod.example` uc ayarin nasil acilacagini tarif ediyordu,
ama adlari prod `api` ortaminda HIC yoktu ve deger konteynere ulasmiyordu:
  * `DUKKAN_MOBIL_ACIK` — "true yap, recreate et" tarifi HICBIR SEY yapmazdi;
  * `RESEND_WEBHOOK_SIRRI` — webhook her istekte 401 donuyor, e-posta
    teslim durumlari prod'da hic guncellenmiyordu;
  * `PLAY_STORE_URL` / `APP_STORE_URL` — tarif edilen gecersiz kilma
    calismiyordu.
`test_compose_oauth` ayni sinifi yalniz `oauth_*` icin kapatmisti. Bu kilit
GENELI kapatir: ornekte (yorumlu ya da degil) adi gecen ve `Settings`te
alani olan her degisken prod compose `api` ortaminda OLMALI.
"""
from __future__ import annotations

import pathlib
import re

import pytest
import yaml

from app.config import Settings

_ADAYLAR = (pathlib.Path("/infra"), pathlib.Path(__file__).resolve().parents[2] / "infra")
_DIZIN = next((d for d in _ADAYLAR if (d / ".env.prod.example").is_file()), None)

#: Prod `api`ye GECMESI GEREKMEYEN (baska servisin ya da yalniz dev'in).
#: Her giris gerekceli; liste bos kalabilir.
_ISTISNA: dict[str, str] = {}


@pytest.mark.skipif(_DIZIN is None, reason="infra/.env.prod.example bagli degil")
def test_ORNEKTE_TARIF_EDILEN_her_ayar_prod_apiye_GECER():
    ornek = (_DIZIN / ".env.prod.example").read_text(encoding="utf-8")
    anilan = set(re.findall(r"^#?\s*([A-Z][A-Z0-9_]+)=", ornek, re.M))
    alanlar = {a.upper() for a in Settings.model_fields}
    veri = yaml.safe_load((_DIZIN / "docker-compose.prod.yml").read_text(encoding="utf-8"))
    ortam = set(dict(veri["services"]["api"]["environment"]))
    eksik = sorted((anilan & alanlar) - ortam - set(_ISTISNA))
    assert not eksik, (
        "Ornek ortamda tarif edilen ama prod `api` ortamina YAZILMAMIS ayarlar "
        "(deger konteynere ULASMAZ, hata SESSIZDIR): " + ", ".join(eksik)
    )


def test_KILIT_GERCEKTEN_OLCUYOR():
    """Hep atlayan test bir sey korumaz: normal kosumda dosya bagli olmali."""
    assert _DIZIN is not None, "infra/.env.prod.example api konteynerine baglanmali (docker-compose.yml)"
