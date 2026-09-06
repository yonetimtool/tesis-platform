"""Dukkan kategori agacini yukler (iki seviye: ana > hizmet). Idempotent.

Kullanim:  python -m app.dukkan.kategori_yukle

===========================================================================
NEDEN IKI SEVIYE
===========================================================================
Ucuncu seviye hem URL'i hem kullaniciyi uzatir. Daraltma V2'de kategoriye
bagli SORU SETI ile yapilacak ("kac oda?", "esya dahil mi?") — derin bir
agacla degil. Bir kullanici "Tadilat > Boya Badana"yi bulur; "Tadilat >
Ic Mekan > Duvar > Boya Badana"da kaybolur.

===========================================================================
KATEGORI SECIMI NEREDEN GELDI
===========================================================================
Liste, Yonetiyor'un dogal komsulugundan turedi: bir site yoneticisinin
ve bir daire sakininin gercekten aradigi hizmetler. `dis_hizmet`
tablosunda yoneticilerin elle girdigi turler de (cilingir, elektrik,
tesisat) bu listede karsilik buluyor — ama iki yapi AYRI kaliyor
(docs/dukkan/00-mimari.md §4).

`slug` KALICIDIR: SEO yolunun son parcasi (/istanbul/cekmekoy/catalmese/
elektrikci). Bir kategorinin adi degisse bile slug degismez; degismesi
gerekiyorsa 301 ile eski slug yasatilir.
"""
from __future__ import annotations

import asyncio
import sys

from sqlalchemy import text

from .veritabani import SessionLocal, engine

# (ana ad, ana slug, ikon, [(alt ad, alt slug), ...])
AGAC: list[tuple[str, str, str, list[tuple[str, str]]]] = [
    ("Temizlik", "temizlik", "sparkles", [
        ("Ev Temizliği", "ev-temizligi"),
        ("Ofis Temizliği", "ofis-temizligi"),
        ("İnşaat Sonrası Temizlik", "insaat-sonrasi-temizlik"),
        ("Koltuk Yıkama", "koltuk-yikama"),
        ("Halı Yıkama", "hali-yikama"),
        ("Cam Temizliği", "cam-temizligi"),
    ]),
    ("Tadilat ve Tamirat", "tadilat", "hammer", [
        ("Boya Badana", "boya-badana"),
        ("Alçıpan ve Asma Tavan", "alcipan"),
        ("Fayans ve Seramik", "fayans-seramik"),
        ("Parke ve Laminat", "parke"),
        ("Duvar Kağıdı", "duvar-kagidi"),
        ("Genel Tadilat", "genel-tadilat"),
    ]),
    ("Tesisat", "tesisat", "wrench", [
        ("Su Tesisatı", "su-tesisati"),
        ("Tıkanıklık Açma", "tikaniklik-acma"),
        ("Kombi Servisi", "kombi-servisi"),
        ("Petek Temizliği", "petek-temizligi"),
        ("Doğalgaz Tesisatı", "dogalgaz-tesisati"),
    ]),
    ("Elektrik", "elektrik", "zap", [
        ("Elektrikçi", "elektrikci"),
        ("Elektrik Tesisatı", "elektrik-tesisati"),
        ("Avize ve Aydınlatma Montajı", "avize-montaji"),
        ("Jeneratör Servisi", "jenerator-servisi"),
    ]),
    ("Nakliyat", "nakliyat", "truck", [
        ("Evden Eve Nakliyat", "evden-eve-nakliyat"),
        ("Ofis Taşıma", "ofis-tasima"),
        ("Asansörlü Taşıma", "asansorlu-tasima"),
        ("Eşya Depolama", "esya-depolama"),
    ]),
    ("Beyaz Eşya ve Klima", "beyaz-esya-klima", "wind", [
        ("Klima Montajı", "klima-montaji"),
        ("Klima Bakımı", "klima-bakimi"),
        ("Buzdolabı Tamiri", "buzdolabi-tamiri"),
        ("Çamaşır Makinesi Tamiri", "camasir-makinesi-tamiri"),
        ("Bulaşık Makinesi Tamiri", "bulasik-makinesi-tamiri"),
    ]),
    ("Mobilya", "mobilya", "sofa", [
        ("Mobilya Montajı", "mobilya-montaji"),
        ("Mobilya Tamiri", "mobilya-tamiri"),
        ("Perde Montajı", "perde-montaji"),
    ]),
    ("Bahçe ve Peyzaj", "bahce-peyzaj", "leaf", [
        ("Bahçe Bakımı", "bahce-bakimi"),
        ("Çim Ekimi", "cim-ekimi"),
        ("Ağaç Budama", "agac-budama"),
        ("Sulama Sistemi", "sulama-sistemi"),
    ]),
    ("Güvenlik ve Anahtar", "guvenlik-anahtar", "shield", [
        ("Çilingir", "cilingir"),
        ("Kamera Sistemi", "kamera-sistemi"),
        ("Alarm Sistemi", "alarm-sistemi"),
        ("Çelik Kapı Servisi", "celik-kapi-servisi"),
    ]),
    ("Bina ve Dış Cephe", "bina-dis-cephe", "building", [
        ("Asansör Bakımı", "asansor-bakimi"),
        ("Çatı Tamiri", "cati-tamiri"),
        ("Su Yalıtımı", "su-yalitimi"),
        ("Dış Cephe Boyama", "dis-cephe-boyama"),
        ("Isı Yalıtımı ve Mantolama", "mantolama"),
    ]),
    ("İlaçlama", "ilaclama", "bug", [
        ("Böcek İlaçlama", "bocek-ilaclama"),
        ("Kemirgen Kontrolü", "kemirgen-kontrolu"),
    ]),
    ("Cam ve Doğrama", "cam-dograma", "frame", [
        ("PVC Doğrama", "pvc-dograma"),
        ("Cam Balkon", "cam-balkon"),
        ("Panjur ve Kepenk", "panjur-kepenk"),
    ]),
]


async def yukle() -> dict[str, int]:
    sayac = {"ana": 0, "alt": 0}
    async with SessionLocal() as s:
        async with s.begin():
            for sira, (ad, slug, ikon, altlar) in enumerate(AGAC):
                ana_id = (
                    await s.execute(
                        text(
                            "INSERT INTO kategori (ad, slug, ikon, sira, ust_id) "
                            "VALUES (:a, :s, :i, :n, NULL) "
                            "ON CONFLICT (slug) WHERE ust_id IS NULL "
                            "DO UPDATE SET ad = EXCLUDED.ad, ikon = EXCLUDED.ikon, "
                            "sira = EXCLUDED.sira, updated_at = now() "
                            "RETURNING id"
                        ),
                        {"a": ad, "s": slug, "i": ikon, "n": sira},
                    )
                ).scalar_one()
                sayac["ana"] += 1

                for alt_sira, (alt_ad, alt_slug) in enumerate(altlar):
                    await s.execute(
                        text(
                            "INSERT INTO kategori (ad, slug, sira, ust_id) "
                            "VALUES (:a, :s, :n, :u) "
                            "ON CONFLICT (ust_id, slug) WHERE ust_id IS NOT NULL "
                            "DO UPDATE SET ad = EXCLUDED.ad, sira = EXCLUDED.sira, "
                            "updated_at = now()"
                        ),
                        {"a": alt_ad, "s": alt_slug, "n": alt_sira, "u": ana_id},
                    )
                    sayac["alt"] += 1
    await engine.dispose()
    return sayac


def main() -> int:
    sayac = asyncio.run(yukle())
    print(f"[kategori] yuklendi: {sayac}")
    # SESSIZ BASARISIZLIK YOK (P217 dersi).
    if sayac["alt"] == 0:
        print("[kategori] HATA: hicbir alt kategori yuklenmedi.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
