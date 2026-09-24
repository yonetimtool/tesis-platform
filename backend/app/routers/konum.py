"""(P233 §1) TESIS KONUMU — adresten koordinat cozumleme.

===========================================================================
OLCULEN DURUM: ALAN VARDI, DEGER YOKTU
===========================================================================
`tenant.konum_lat/konum_lon/konum_ad` ZATEN vardi (goc 0005) ve hava
durumu (`/weather`) onlari kullaniyor. Ama dev veritabanindaki TUM
tesisler AYNI degeri tasiyor:

    konum_ad='İstanbul'  konum_lat=41.008200  konum_lon=28.978400

Bu sunucu VARSAYILANI (`server_default`) — yani kimse hic ayarlamamis.
Sonucu gorunur ve yanlis: Erzurum'daki "Oltu Sitesi" ISTANBUL havasini
gosteriyor.

Alanlar `PATCH /tenant/settings` ile YAZILABILIR durumdaydi; eksik olan
sey, yoneticinin ENLEM/BOYLAM YAZMADAN konumunu verebilecegi bir yoldu.

===========================================================================
NEDEN HARITA DEGIL, ADRESTEN COZUMLEME
===========================================================================
Uc secenek olculdu:

  1. HARITADAN SECIM. Web'de Leaflet bileseni ZATEN VAR
     (`konum-haritasi.tsx`, devriye noktalari icin). Ama MOBILDE hic
     harita paketi YOK (`pubspec.yaml`de flutter_map/google_maps yok):
     yeni bir bagimlilik, karo saglayicisi ve cevrimdisi davranisi
     demek. Yalniz web'e yapmak da kalici parite kuralini bozardi.

  2. DUKKAN HIYERARSISINDEN TUREME. `dukkan.il/ilce/mahalle` 44.719
     mahalle tasiyor — ama KOORDINAT TASIMIYOR (olculdu: sutunlar
     id/ad/slug/posta_kodu/tip). Yani hiyerarsi tek basina lat/lon
     veremez.

  3. ADRESTEN COZUMLEME — SECILEN. Open-Meteo'nun cografi kodlama ucu
     ANAHTAR ISTEMIYOR ve ZATEN KULLANDIGIMIZ saglayici (hava durumu
     ayni yerden geliyor): yeni satici, yeni sozlesme, yeni sir yok.
     Dogruluk ILCE duzeyinde ve bu, istenen iki kullanim icin
     (hava durumu + bolgesel analiz) TAM YETERLI — hava, sokak
     hassasiyeti istemez.

Elle enlem/boylam yazma yolu KAPATILMADI (`PATCH /tenant/settings`
duruyor): ucra bir konum icin kacis yolu kalsin.
"""
from __future__ import annotations

import httpx
from fastapi import APIRouter, Depends, Query

from ..hiz_siniri import ARAMA_SINIRI
from ..config import settings
from ..deps import require_role
from ..errors import APIError
from ..models import AppUser
from ..schemas import KonumAdayi, KonumAramaSonucu

router = APIRouter(prefix="/konum", tags=["konum"])

# KIM ARAR: tesisin konumunu belirleyen kisi yonetimdir.
_ARAYAN = require_role("admin", "yonetici")

#: Cografi kodlama ucu. Hava durumuyla AYNI saglayici — ayri bir satici
#: eklemek, ayri bir kesinti kaynagi ve ayri bir gizlilik sozlesmesi
#: demekti.
_GEOCODE_URL = "https://geocoding-api.open-meteo.com/v1/search"


@router.get("/ara", response_model=KonumAramaSonucu, dependencies=[Depends(ARAMA_SINIRI)])
async def konum_ara(
    q: str = Query(min_length=2, max_length=120),
    dil: str = Query("tr", max_length=5),
    user: AppUser = Depends(_ARAYAN),
) -> KonumAramaSonucu:
    """Yer adindan koordinat adaylari — yonetici LISTEDEN secer.

    =======================================================================
    NEDEN ADAY LISTESI, TEK SONUC DEGIL
    =======================================================================
    "Oltu" sorgusu Erzurum'daki ilceyi de, Artvin'deki "Oltuca"yi da,
    Belarus'taki "Oltush"u da dondurur (olculdu). Sunucunun ilkini secip
    "buldum" demesi, yoneticinin HIC GORMEDIGI bir konumu tesise yazmak
    olurdu — ve yanlis hava durumu, fark edilmesi en zor kusurlardandir
    (ekran calisiyor gorunur).

    =======================================================================
    UC DUSERSE 503, SESSIZ BOS LISTE DEGIL
    =======================================================================
    Bos liste "boyle bir yer yok" demektir; servis erisilemiyorsa bu
    YANLIS bir cumledir ve kullaniciyi adresini yanlis yazdigini sanmaya
    iter.
    """
    try:
        async with httpx.AsyncClient(timeout=6.0) as http:
            r = await http.get(
                _GEOCODE_URL,
                params={"name": q.strip(), "count": 8, "language": dil},
            )
            r.raise_for_status()
            veri = r.json()
    except Exception:
        raise APIError(503, "konum_servisi_yok", "konum_servisi_yok")

    adaylar = [
        KonumAdayi(
            ad=x["name"],
            # `admin1` il, `admin2` ilce — saglayici bazen bos birakir;
            # bos parcalar ELENIR ki "Oltu, , Türkiye" gibi bir etiket
            # cikmasin.
            aciklama=", ".join(
                p for p in (x.get("admin2"), x.get("admin1"), x.get("country"))
                if p
            ),
            lat=float(x["latitude"]),
            lon=float(x["longitude"]),
        )
        for x in (veri.get("results") or [])
    ]
    return KonumAramaSonucu(q=q, items=adaylar)
