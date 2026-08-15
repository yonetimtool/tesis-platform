#!/usr/bin/env python3
"""(P162) KUCUK PNG ARACI — marka varliklarini hazirlar.

=====================================================================
NEDEN VAR
=====================================================================
Bu makinede goruntu araci YOK: ImageMagick, PIL, numpy, sharp — hicbiri
kurulu degil. Marka gorselleri ise ham geldi:

  * `yonetiyor_marka.png` RGB, yani ALFA KANALI YOK -> koyu lacivert
    giris ekranina koyunca BEYAZ BIR DIKDORTGEN olarak cikar.
  * ikisinin de cevresinde genis bos pay var -> logo kucuk gorunur.

Bagimlilik eklemek yerine (uretim paketine girmeyecek bir is icin uc
parti kurmak dogru degil) PNG'nin kendisi okunuyor: zlib zaten standart
kutuphanede ve PNG'nin filtre kurallari kisa.

DESTEK: 8 bit RGB / RGBA, interlace YOK. Marka varliklari boyle; baska
bicim gelirse arac ACIKCA hata verir, sessizce bozuk cikti uretmez.
"""
from __future__ import annotations

import struct
import sys
import zlib


def _parcalar(ham: bytes):
    assert ham[:8] == b"\x89PNG\r\n\x1a\n", "PNG degil"
    i = 8
    while i < len(ham):
        (boy,) = struct.unpack(">I", ham[i : i + 4])
        tip = ham[i + 4 : i + 8]
        veri = ham[i + 8 : i + 8 + boy]
        yield tip, veri
        i += 12 + boy


def oku(yol: str):
    """-> (genislik, yukseklik, kanal, bytearray)"""
    ham = open(yol, "rb").read()
    idat = b""
    en = boy = kanal = 0
    for tip, veri in _parcalar(ham):
        if tip == b"IHDR":
            en, boy, derinlik, renk, _, _, gecmeli = struct.unpack(">IIBBBBB", veri)
            if derinlik != 8 or renk not in (2, 6) or gecmeli != 0:
                raise SystemExit(f"desteklenmeyen PNG: derinlik={derinlik} renk={renk} gecmeli={gecmeli}")
            kanal = 3 if renk == 2 else 4
        elif tip == b"IDAT":
            idat += veri
    duz = zlib.decompress(idat)
    satirBayt = en * kanal
    cikti = bytearray(en * boy * kanal)
    onceki = bytearray(satirBayt)
    p = 0
    for y in range(boy):
        filtre = duz[p]
        p += 1
        satir = bytearray(duz[p : p + satirBayt])
        p += satirBayt
        if filtre == 1:
            for x in range(kanal, satirBayt):
                satir[x] = (satir[x] + satir[x - kanal]) & 255
        elif filtre == 2:
            for x in range(satirBayt):
                satir[x] = (satir[x] + onceki[x]) & 255
        elif filtre == 3:
            for x in range(satirBayt):
                sol = satir[x - kanal] if x >= kanal else 0
                satir[x] = (satir[x] + ((sol + onceki[x]) >> 1)) & 255
        elif filtre == 4:
            for x in range(satirBayt):
                a = satir[x - kanal] if x >= kanal else 0
                b = onceki[x]
                c = onceki[x - kanal] if x >= kanal else 0
                pp = a + b - c
                pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                tah = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                satir[x] = (satir[x] + tah) & 255
        elif filtre != 0:
            raise SystemExit(f"bilinmeyen filtre {filtre}")
        cikti[y * satirBayt : (y + 1) * satirBayt] = satir
        onceki = satir
    return en, boy, kanal, cikti


def yaz(yol: str, en: int, boy: int, piksel: bytearray):
    """Her zaman RGBA + filtre 0 yazar (basit ve kayipsiz)."""
    satirlar = bytearray()
    for y in range(boy):
        satirlar.append(0)
        satirlar += piksel[y * en * 4 : (y + 1) * en * 4]
    def parca(tip, veri):
        return struct.pack(">I", len(veri)) + tip + veri + struct.pack(">I", zlib.crc32(tip + veri) & 0xFFFFFFFF)
    ihdr = struct.pack(">IIBBBBB", en, boy, 8, 6, 0, 0, 0)
    with open(yol, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(parca(b"IHDR", ihdr))
        f.write(parca(b"IDAT", zlib.compress(bytes(satirlar), 9)))
        f.write(parca(b"IEND", b""))


def rgba_yap(en, boy, kanal, piksel) -> bytearray:
    if kanal == 4:
        return piksel
    cikti = bytearray(en * boy * 4)
    for i in range(en * boy):
        cikti[i * 4 : i * 4 + 3] = piksel[i * 3 : i * 3 + 3]
        cikti[i * 4 + 3] = 255
    return cikti


def beyazi_saydamlastir(en, boy, piksel, esik=225, tamBeyaz=248):
    """Beyaza yakin pikselleri saydam yapar.

    ANAHTARLAMA DEGIL YUMUSAK GECIS: sert esik, egik kenarlarda testere
    disi birakir. Piksel ne kadar beyazsa o kadar saydam olur; boylece
    logonun kenar yumusatmasi KORUNUR.

    `tamBeyaz` NEDEN 255 DEGIL: marka dosyasinin zemini TAM beyaz degil,
    251-255 arasi gurultulu (olculdu). 255'i kesim noktasi almak, koyu
    zeminde gorunen soluk bir beyaz sis birakiyordu.
    """
    for i in range(en * boy):
        enAz = min(piksel[i * 4], piksel[i * 4 + 1], piksel[i * 4 + 2])
        if enAz >= tamBeyaz:
            piksel[i * 4 + 3] = 0
        elif enAz > esik:
            piksel[i * 4 + 3] = int(255 * (tamBeyaz - enAz) / (tamBeyaz - esik))
    return piksel


def acik_murekkep(en, boy, piksel, karisim=0.72):
    """TERS (acik) LOGO VARYANTI — koyu zemin icin.

    NEDEN GEREKLI: marka murekkebi koyu lacivert (#12224a civari). Giris
    ekraninin zemini de deep navy (#061426). Olculdugunde kontrast orani
    ~1.2 cikiyor, yani marka zeminde KAYBOLUYOR.

    NE YAPAR: her pikseli beyaza dogru karistirir. Bu bir "beyaza cevir"
    DEGIL — ton korunur, yalnizca acilir. Boylece ikonun mavi gradyani
    acik mavi olarak yasar, koyu lacivert metin ise kirik beyaza doner.
    Kurumsal kimlik kilavuzlarindaki klasik "reverse" kullanimi budur.

    ALFA'YA DOKUNULMAZ: kenar yumusatmasi bozulmaz.
    """
    for i in range(en * boy):
        if piksel[i * 4 + 3] == 0:
            continue
        for c in range(3):
            d = piksel[i * 4 + c]
            piksel[i * 4 + c] = int(d + (255 - d) * karisim)
    return piksel


def kirp(en, boy, piksel, pay=0):
    """Tamamen saydam kenar paylarini atar."""
    ust, alt, sol, sag = boy, -1, en, -1
    for y in range(boy):
        for x in range(en):
            if piksel[(y * en + x) * 4 + 3] > 8:
                if y < ust: ust = y
                if y > alt: alt = y
                if x < sol: sol = x
                if x > sag: sag = x
    if alt < 0:
        raise SystemExit("gorsel tamamen saydam")
    sol = max(0, sol - pay); ust = max(0, ust - pay)
    sag = min(en - 1, sag + pay); alt = min(boy - 1, alt + pay)
    yeniEn, yeniBoy = sag - sol + 1, alt - ust + 1
    cikti = bytearray(yeniEn * yeniBoy * 4)
    for y in range(yeniBoy):
        k = ((ust + y) * en + sol) * 4
        cikti[y * yeniEn * 4 : (y + 1) * yeniEn * 4] = piksel[k : k + yeniEn * 4]
    return yeniEn, yeniBoy, cikti


def olcekle(en, boy, piksel, hedefEn, hedefBoy):
    """Kutu ortalamasiyla kucultme (alfa agirlikli).

    EN YAKIN KOMSU DEGIL: ikon 1072 pikselden 48'e inerken en-yakin
    komsu, ince cizgileri tamamen yutar ve kenarlari testere disi yapar.
    """
    cikti = bytearray(hedefEn * hedefBoy * 4)
    for hy in range(hedefBoy):
        y0, y1 = hy * boy // hedefBoy, max(hy * boy // hedefBoy + 1, (hy + 1) * boy // hedefBoy)
        for hx in range(hedefEn):
            x0, x1 = hx * en // hedefEn, max(hx * en // hedefEn + 1, (hx + 1) * en // hedefEn)
            tr = tg = tb = ta = n = 0
            for y in range(y0, y1):
                for x in range(x0, x1):
                    k = (y * en + x) * 4
                    a = piksel[k + 3]
                    tr += piksel[k] * a; tg += piksel[k + 1] * a; tb += piksel[k + 2] * a
                    ta += a; n += 1
            k = (hy * hedefEn + hx) * 4
            if ta:
                cikti[k] = min(255, tr // ta); cikti[k + 1] = min(255, tg // ta); cikti[k + 2] = min(255, tb // ta)
            cikti[k + 3] = ta // n if n else 0
    return cikti


def kareye_al(en, boy, piksel):
    """Uzun kenara gore ORTALAYARAK kare tuvale oturtur (ikon icin)."""
    k = max(en, boy)
    cikti = bytearray(k * k * 4)
    ox, oy = (k - en) // 2, (k - boy) // 2
    for y in range(boy):
        h = ((oy + y) * k + ox) * 4
        cikti[h : h + en * 4] = piksel[y * en * 4 : (y + 1) * en * 4]
    return k, cikti


if __name__ == "__main__":
    komut = sys.argv[1]
    if komut == "bilgi":
        en, boy, kanal, px = oku(sys.argv[2])
        print(f"{en}x{boy} kanal={kanal}")
    elif komut == "hazirla":
        # hazirla <girdi> <cikti> [--beyaz-sil] [--kare] [--boy N]
        girdi, cikti = sys.argv[2], sys.argv[3]
        bayrak = sys.argv[4:]
        en, boy, kanal, px = oku(girdi)
        px = rgba_yap(en, boy, kanal, px)
        if "--beyaz-sil" in bayrak:
            px = beyazi_saydamlastir(en, boy, px)
        if "--acik-murekkep" in bayrak:
            px = acik_murekkep(en, boy, px)
        en, boy, px = kirp(en, boy, px)
        if "--kare" in bayrak:
            en2, px = kareye_al(en, boy, px)
            en = boy = en2
        if "--boy" in bayrak:
            hedef = int(bayrak[bayrak.index("--boy") + 1])
            oran = hedef / max(en, boy)
            yEn, yBoy = max(1, round(en * oran)), max(1, round(boy * oran))
            px = olcekle(en, boy, px, yEn, yBoy)
            en, boy = yEn, yBoy
        yaz(cikti, en, boy, px)
        print(f"{cikti}: {en}x{boy}")
