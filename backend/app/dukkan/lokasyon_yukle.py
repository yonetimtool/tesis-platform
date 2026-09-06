"""Lokasyon agacini (il/ilce/mahalle) DIS KAYNAKTAN yukler. Bir kez calisir.

Kullanim (api konteynerinde):
    python -m app.dukkan.lokasyon_yukle /yol/tr-lokasyon.json

===========================================================================
NEDEN VERI ICERIDE YASIYOR, CALISMA ANINDA API'YE SORULMUYOR
===========================================================================
`/istanbul/cekmekoy/catalmese/elektrikci` SEO sayfasi varligini `mahalle`
satirina borcludur. O satir bir dis API'den gelseydi, API'nin kesintisi
BINLERCE SEO sayfasinin 500 vermesi demek olurdu — arama motoruna
verilebilecek en kotu sinyal. Veri bir kez yuklenir, elle guncellenir.

===========================================================================
HAM VERI KULLANILAMAZ HALDEYDI — OLCULDU
===========================================================================
Secilen kaynak (MIT lisansli) su kusurlari tasiyor:
  * 74.402 Turkce adda 'ı' harfi SIFIR kez geciyor. Turkcede 'ı' cok
    yaygindir ("Balıkesir", "Diyarbakır", "Çınarlı"); sifir olmasi
    istatistiksel olarak imkansiz.
  * Adlarin %83,6'si U+0307 BIRLESEN NOKTA tasiyor: "Mahallesi̇".
  * Il adlari bile bozuk: "Balikesi̇r", "Di̇yarbakir", "Afyonkarahi̇sar".

TESHIS: kaynak metin BUYUK HARFTI ve Turkce OLMAYAN bir yerel ayarla
kucultuldu. Python'da bu donusum sudur:
    'İ'.lower() -> 'i' + U+0307     (noktali i, ustunde fazladan nokta)
    'I'.lower() -> 'i'              (DOGRUSU 'ı' olmaliydi)

Bozulma BIRE BIR ve bilgi kaybetmeden geri dondurulebiliyor cunku iki
durum birbirinden AYIRT EDILEBILIR: biri birlesen nokta tasiyor, oteki
tasimiyor. `_onar` bunu yapiyor.

DOGRULAMA (tahmin degil, olcum):
  * 81/81 il adi bilinen dogru adla eslesti,
  * 39/39 Istanbul ilcesi eslesti,
  * brief'in ornek yolu "Çatalmeşe" dogru bicimde bulundu.
Bir kaynak degistirilirse bu dogrulamalar TEKRAR calistirilmali
(`tests/test_dukkan_lokasyon.py`).

===========================================================================
NELER YUKLENMIYOR
===========================================================================
Kaynak 74.402 kayit iceriyor ama hepsi hizmet alani DEGIL:
    Mahallesi  32.355   -> yuklenir ('mahalle')
    Köyü       12.364   -> yuklenir ('koy')
    Mevkii     22.912   -> YUKLENMEZ
    Mezrası     5.337   -> YUKLENMEZ
"Mevki" ve "mezra" kirsal konum adlaridir; bir usta hizmet alani olarak
"mevki" secmez. Bunlari yuklemek mahalle secicisini kullanilmaz
kilardi (45.000 yerine 74.000 secenek) ve hicbir isletme onlari
secmeyecegi icin o sayfalar KALICI olarak esik altinda kalirdi.
Gerekirse sonradan eklenebilir: `tip` sutunu genisletilir.
"""
from __future__ import annotations

import asyncio
import hashlib
import json
import pathlib
import re
import sys
from datetime import date

from sqlalchemy import text

from .veritabani import SessionLocal, engine

KAYNAK_URL = (
    "https://raw.githubusercontent.com/ferhat-mousavi/"
    "turkiye-il-ilce-mahalle-koy/master/turkiye-il-ilce-mahalle-koy.json"
)
LISANS = "MIT"

# Yuklenecek son ekler -> `mahalle.tip`
EK_TIP = {"Mahallesi": "mahalle", "Köyü": "koy"}

_SLUG_HARITA = str.maketrans({
    "ı": "i", "İ": "i", "ş": "s", "Ş": "s", "ğ": "g", "Ğ": "g",
    "ü": "u", "Ü": "u", "ö": "o", "Ö": "o", "ç": "c", "Ç": "c",
    "â": "a", "î": "i", "û": "u",
})


def _onar(s: str) -> str:
    """Turkce olmayan yerel ayarla bozulmus metni geri cevirir.

    Doner: onarilmis metin.

    'i' + U+0307  -> 'i'   (kaynakta 'İ' idi)
    'i'           -> 'ı'   (kaynakta 'I' idi)
    """
    cikti: list[str] = []
    i = 0
    while i < len(s):
        c = s[i]
        nokta = i + 1 < len(s) and s[i + 1] == "̇"
        if c == "i" and nokta:
            cikti.append("i")
            i += 2
        elif c == "i":
            cikti.append("ı")
            i += 1
        elif c == "İ" and nokta:
            cikti.append("İ")
            i += 2
        else:
            cikti.append(c)
            i += 1
    return "".join(cikti)


def slugla(ad: str) -> str:
    """SEO yolu icin kalici slug uretir. Doner: [a-z0-9-] dizgesi.

    Slug URL'in parcasi ve KALICIDIR: bir kez uretilip saklanir, her
    okumada YENIDEN TURETILMEZ. Idari bir ad degisikliginde slug'in
    kendiliginden degismesi, calisan baglantiyi sessizce oldururdu.
    """
    s = ad.translate(_SLUG_HARITA).lower()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-")


def _mahalle_ayikla(ham: str) -> tuple[str, str] | None:
    """Ham mahalle metnini (ad, tip) ikilisine cevirir.

    Doner: (ad, tip) yuklenecekse; `None` yuklenmeyecekse (mevki/mezra,
    bos kayit veya taninmayan bicim).
    """
    ad = _onar(ham).strip()
    if not ad:
        return None
    parcalar = ad.split()
    tip = EK_TIP.get(parcalar[-1])
    if tip is None:
        return None
    govde = " ".join(parcalar[:-1]).strip()
    # "Yeni  Mahallesi" gibi cift bosluklu kayitlar var; sadelestir.
    govde = re.sub(r"\s+", " ", govde)
    return (govde, tip) if govde else None


async def yukle(yol: pathlib.Path) -> dict[str, int]:
    ham = yol.read_bytes()
    ozet = hashlib.sha256(ham).hexdigest()
    veri = json.loads(ham)

    sayac = {"il": 0, "ilce": 0, "mahalle": 0, "atlanan": 0, "slug_cakisma": 0}

    async with SessionLocal() as s:
        async with s.begin():
            ulke_id = (
                await s.execute(
                    text(
                        "INSERT INTO ulke (kod, ad) VALUES ('TR', 'Türkiye') "
                        "ON CONFLICT (kod) DO UPDATE SET ad = EXCLUDED.ad "
                        "RETURNING id"
                    )
                )
            ).scalar_one()

            for ham_il, ilceler in veri.items():
                il_ad = _onar(ham_il).strip()
                il_id = (
                    await s.execute(
                        text(
                            "INSERT INTO il (ulke_id, ad, slug) "
                            "VALUES (:u, :a, :s) "
                            "ON CONFLICT (ulke_id, slug) DO UPDATE SET ad = EXCLUDED.ad "
                            "RETURNING id"
                        ),
                        {"u": ulke_id, "a": il_ad, "s": slugla(il_ad)},
                    )
                ).scalar_one()
                sayac["il"] += 1

                for ham_ilce, mahalleler in ilceler.items():
                    ilce_ad = _onar(ham_ilce).strip()
                    ilce_id = (
                        await s.execute(
                            text(
                                "INSERT INTO ilce (il_id, ad, slug) "
                                "VALUES (:i, :a, :s) "
                                "ON CONFLICT (il_id, slug) DO UPDATE "
                                "SET ad = EXCLUDED.ad RETURNING id"
                            ),
                            {"i": il_id, "a": ilce_ad, "s": slugla(ilce_ad)},
                        )
                    ).scalar_one()
                    sayac["ilce"] += 1

                    gorulen: set[str] = set()
                    for ham_m in mahalleler:
                        cozum = _mahalle_ayikla(ham_m)
                        if cozum is None:
                            sayac["atlanan"] += 1
                            continue
                        ad, tip = cozum
                        slug = slugla(ad)
                        if not slug:
                            sayac["atlanan"] += 1
                            continue
                        # Ayni ilcede ayni slug: "Yeni Mahallesi" ve "Yeni
                        # Köyü" cakisir. Ikincisine tip eki veriyoruz —
                        # SESSIZCE DUSURMEK bir mahalleyi haritadan silerdi.
                        if slug in gorulen:
                            slug = f"{slug}-{tip}"
                            if slug in gorulen:
                                sayac["slug_cakisma"] += 1
                                continue
                        gorulen.add(slug)
                        await s.execute(
                            text(
                                "INSERT INTO mahalle (ilce_id, ad, slug, tip) "
                                "VALUES (:i, :a, :s, :t) "
                                "ON CONFLICT (ilce_id, slug) DO UPDATE "
                                "SET ad = EXCLUDED.ad, tip = EXCLUDED.tip"
                            ),
                            {"i": ilce_id, "a": ad, "s": slug, "t": tip},
                        )
                        sayac["mahalle"] += 1

            await s.execute(
                text(
                    "INSERT INTO veri_kaynagi "
                    "(tur, kaynak_url, lisans, sha256, indirme_tarihi, "
                    " kayit_sayisi, onarim_notu, not_metni) "
                    "VALUES ('lokasyon', :u, :l, :h, :t, CAST(:k AS jsonb), :o, :n) "
                    "ON CONFLICT (tur, sha256) DO UPDATE "
                    "SET kayit_sayisi = EXCLUDED.kayit_sayisi"
                ),
                {
                    "u": KAYNAK_URL,
                    "l": LISANS,
                    "h": ozet,
                    "t": date.today(),
                    "k": json.dumps(sayac),
                    "o": (
                        "Kaynakta Turkce kucultme bozuktu: 'ı' harfi 74.402 adda "
                        "SIFIR kez geciyordu, adlarin %83,6'si U+0307 birlesen "
                        "nokta tasiyordu. Deterministik olarak onarildi "
                        "(i+U+0307 -> i, yalin i -> ı). Dogrulama: 81/81 il ve "
                        "39/39 Istanbul ilcesi bilinen dogru adla eslesti."
                    ),
                    "n": (
                        "Yalniz 'Mahallesi' ve 'Köyü' yuklendi. 'Mevkii' ve "
                        "'Mezrası' kayitlari hizmet alani olarak anlamsiz "
                        "oldugu icin disarida birakildi."
                    ),
                },
            )
    await engine.dispose()
    return sayac


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    sayac = asyncio.run(yukle(pathlib.Path(sys.argv[1])))
    print(f"[lokasyon] yuklendi: {sayac}")
    # SIFIR KAYIT SESSIZ GECMEZ (P217 dersi: "Kaydedildi" deyip hicbir sey
    # yapmamak, bu depoda olculmus bir kusur sinifi).
    if sayac["mahalle"] == 0:
        print("[lokasyon] HATA: hicbir mahalle yuklenmedi.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
