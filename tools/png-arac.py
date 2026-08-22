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


def _parca(tip: bytes, veri: bytes) -> bytes:
    """PNG parcasi: uzunluk + tip + veri + CRC32."""
    return (
        struct.pack(">I", len(veri))
        + tip
        + veri
        + struct.pack(">I", zlib.crc32(tip + veri) & 0xFFFFFFFF)
    )


def yaz(yol: str, en: int, boy: int, piksel: bytearray):
    """Her zaman RGBA + filtre 0 yazar (basit ve kayipsiz)."""
    satirlar = bytearray()
    for y in range(boy):
        satirlar.append(0)
        satirlar += piksel[y * en * 4 : (y + 1) * en * 4]
    parca = _parca
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


def kutu_kirp(en, boy, piksel, sol, ust, sag, alt):
    """ACIK kirpma kutusu — `sag`/`alt` DISLAYICI (Python dilim mantigi).

    `kirp()`ten AYRI ve bilincli: o, saydam paylari OLCEREK atar; bu ise
    kutuyu CAGIRANDAN alir. Ikon uretiminde kutu bir KARARDIR (bkz.
    docs/P177-kararlar.md) ve olcumle yeniden turetilmemelidir — logo
    dosyasi bir gun degisirse kutu da bilincli olarak yeniden secilmeli,
    sessizce kaymamali.
    """
    if not (0 <= sol < sag <= en and 0 <= ust < alt <= boy):
        raise SystemExit(f"gecersiz kirpma kutusu: {(sol, ust, sag, alt)} / {en}x{boy}")
    yeniEn, yeniBoy = sag - sol, alt - ust
    cikti = bytearray(yeniEn * yeniBoy * 4)
    for y in range(yeniBoy):
        k = ((ust + y) * en + sol) * 4
        cikti[y * yeniEn * 4 : (y + 1) * yeniEn * 4] = piksel[k : k + yeniEn * 4]
    return yeniEn, yeniBoy, cikti


def buyut(en, boy, piksel, hedefEn, hedefBoy):
    """Iki dogrusal (bilinear) BUYUTME — alfa ile ON CARPILMIS.

    `olcekle()` KUTU ORTALAMASIDIR ve yalniz KUCULTMEDE dogru sonuc verir:
    buyutmede kutu tek piksele duser, yani en-yakin-komsuya cokup blok
    blok kenar birakir. Ikonlarin cogu BUYUTMEDIR (466 px'lik kirpma ->
    1024 px'lik tuval), bu yuzden ayri bir yol gerekiyor.

    ON CARPIM ZORUNLU: saydam pikselin RGB'si tanimsizdir (bu dosyada 0,
    yani SIYAH). Ham RGB'yi harmanlamak, isaretin cevresine siyah bir
    hale birakirdi — kenar yumusatmasinin klasik hatasi.
    """
    cikti = bytearray(hedefEn * hedefBoy * 4)
    # Kenar hizalamasi: kaynak ve hedefin PIKSEL MERKEZLERI eslesir.
    olcX = en / hedefEn
    olcY = boy / hedefBoy
    for hy in range(hedefBoy):
        fy = (hy + 0.5) * olcY - 0.5
        y0 = int(fy) if fy >= 0 else -1
        wy = fy - y0
        y0 = min(max(y0, 0), boy - 1)
        y1 = min(y0 + 1, boy - 1)
        for hx in range(hedefEn):
            fx = (hx + 0.5) * olcX - 0.5
            x0 = int(fx) if fx >= 0 else -1
            wx = fx - x0
            x0 = min(max(x0, 0), en - 1)
            x1 = min(x0 + 1, en - 1)
            tr = tg = tb = ta = 0.0
            for (xx, yy, w) in (
                (x0, y0, (1 - wx) * (1 - wy)),
                (x1, y0, wx * (1 - wy)),
                (x0, y1, (1 - wx) * wy),
                (x1, y1, wx * wy),
            ):
                if w <= 0:
                    continue
                k = (yy * en + xx) * 4
                a = piksel[k + 3]
                tr += piksel[k] * a * w
                tg += piksel[k + 1] * a * w
                tb += piksel[k + 2] * a * w
                ta += a * w
            k = (hy * hedefEn + hx) * 4
            if ta > 0:
                cikti[k] = min(255, int(tr / ta + 0.5))
                cikti[k + 1] = min(255, int(tg / ta + 0.5))
                cikti[k + 2] = min(255, int(tb / ta + 0.5))
            cikti[k + 3] = min(255, int(ta + 0.5))
    return cikti


def yeniden_boyutla(en, boy, piksel, hedefEn, hedefBoy):
    """Yonu KENDI secer: kucultmede kutu ortalamasi, buyutmede bilinear.

    Cagiranin hangi yonde oldugunu hatirlamasi gerekmesin diye tek kapi.
    """
    if hedefEn <= en and hedefBoy <= boy:
        return olcekle(en, boy, piksel, hedefEn, hedefBoy)
    return buyut(en, boy, piksel, hedefEn, hedefBoy)


def bos_tuval(kenar, renk=None):
    """`kenar` x `kenar` RGBA tuval. `renk=None` => TAMAMEN SAYDAM."""
    if renk is None:
        return bytearray(kenar * kenar * 4)
    r, g, b = renk
    return bytearray(bytes((r, g, b, 255)) * (kenar * kenar))


def uzerine_ciz(tuvalKenar, tuval, en, boy, piksel, ox, oy):
    """Kaynagi tuvale (ox, oy) noktasindan ALFA HARMANIYLA cizer.

    KOPYALAMA DEGIL HARMAN: kopyalamak, isaretin saydam kenar
    pikselleriyle birlikte zemini de silerdi (beyaz zeminli ikonlarda
    isaretin cevresinde saydam bir hale).
    """
    for y in range(boy):
        ty = oy + y
        if not (0 <= ty < tuvalKenar):
            continue
        for x in range(en):
            tx = ox + x
            if not (0 <= tx < tuvalKenar):
                continue
            k = (y * en + x) * 4
            a = piksel[k + 3]
            if a == 0:
                continue
            h = (ty * tuvalKenar + tx) * 4
            if a == 255:
                tuval[h : h + 4] = piksel[k : k + 4]
                continue
            ta = tuval[h + 3]
            # Standart "source-over", ON CARPILMAMIS hedef uzerinde.
            ya = a + ta * (255 - a) // 255
            for c in range(3):
                tuval[h + c] = (
                    (piksel[k + c] * a + tuval[h + c] * ta * (255 - a) // 255) // ya
                    if ya
                    else 0
                )
            tuval[h + 3] = ya
    return tuval


def beyaza_boya(en, boy, piksel):
    """Tek renk (BEYAZ) siluet — alfa AYNEN korunur.

    Android 13+ "temali ikon" katmani bir ALFA MASKESIDIR: sistem onu
    kullanicinin temasindan gelen renkle boyar ve RGB'yi yok sayar. Yine
    de beyaz yaziyoruz — maskelemeyen bir onizleyicide (ya da yanlislikla
    duz PNG olarak acildiginda) isaret gorunur kalsin diye.
    """
    for i in range(en * boy):
        if piksel[i * 4 + 3]:
            piksel[i * 4] = piksel[i * 4 + 1] = piksel[i * 4 + 2] = 255
    return piksel


def yaz_opak(yol: str, en: int, boy: int, piksel: bytearray, zemin=(255, 255, 255)):
    """ALFA KANALI OLMAYAN PNG yazar (renk tipi 2 — truecolor).

    "Saydamligi 255'e cekmek" YETMEZ: dosya yine 4 kanalli olur ve
    App Store yuklemesi (ITMS-90717) ALFA KANALININ VARLIGINA bakar,
    degerlerine degil. Bu yuzden kanal GERCEKTEN dusurulur.

    `tRNS` parcasi da YAZILMAZ — o, alfasiz bir PNG'ye saydamligi geri
    getiren kacamak yoldur ve ayni denetimden gecmez.
    """
    duz = bytearray(en * boy * 3)
    zr, zg, zb = zemin
    for i in range(en * boy):
        a = piksel[i * 4 + 3]
        if a == 255:
            duz[i * 3 : i * 3 + 3] = piksel[i * 4 : i * 4 + 3]
        else:
            for c in range(3):
                duz[i * 3 + c] = (piksel[i * 4 + c] * a + (zr, zg, zb)[c] * (255 - a)) // 255
    satirlar = bytearray()
    for y in range(boy):
        satirlar.append(0)
        satirlar += duz[y * en * 3 : (y + 1) * en * 3]
    ihdr = struct.pack(">IIBBBBB", en, boy, 8, 2, 0, 0, 0)
    with open(yol, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(_parca(b"IHDR", ihdr))
        f.write(_parca(b"IDAT", zlib.compress(bytes(satirlar), 9)))
        f.write(_parca(b"IEND", b""))


def alfa_var_mi(yol: str) -> bool:
    """Dosyada ALFA KANALI VAR MI — degerlere DEGIL, IHDR'ye bakar.

    Renk tipi 4 (gri+alfa) ve 6 (RGBA) alfa TASIR. `tRNS` parcasi ise
    alfasiz bir tipe saydamlik ekler; o da alfa sayilir.
    """
    ham = open(yol, "rb").read()
    for tip, veri in _parcalar(ham):
        if tip == b"IHDR":
            renk = veri[9]
            if renk in (4, 6):
                return True
        elif tip == b"tRNS":
            return True
    return False


def ico_yaz(yol: str, katmanlar):
    """Cok boyutlu `.ico` — her katman GOMULU PNG olarak yazilir.

    `katmanlar`: [(kenar, rgba_bytearray), ...]

    PNG GOMME (BMP degil): Vista'dan beri desteklenir, kod BMP'nin ters
    cevrilmis satir duzeni ve AND maskesi olmadan yazilir. 16/32/48 gibi
    kucuk boyutlarda boyut farki onemsiz, hata payi cok daha dusuk.
    """
    import io as _io

    govdeler = []
    for kenar, px in katmanlar:
        tampon = _io.BytesIO()
        satirlar = bytearray()
        for y in range(kenar):
            satirlar.append(0)
            satirlar += px[y * kenar * 4 : (y + 1) * kenar * 4]
        tampon.write(b"\x89PNG\r\n\x1a\n")
        tampon.write(_parca(b"IHDR", struct.pack(">IIBBBBB", kenar, kenar, 8, 6, 0, 0, 0)))
        tampon.write(_parca(b"IDAT", zlib.compress(bytes(satirlar), 9)))
        tampon.write(_parca(b"IEND", b""))
        govdeler.append((kenar, tampon.getvalue()))

    basliklar = bytearray(struct.pack("<HHH", 0, 1, len(govdeler)))
    ofset = 6 + 16 * len(govdeler)
    for kenar, govde in govdeler:
        # 256 px `.ico` dizininde 0 ile kodlanir; bizim boyutlarimiz kucuk
        # ama kural yine de uygulanir ki arac ileride 256 uretebilsin.
        basliklar += struct.pack(
            "<BBBBHHII",
            kenar if kenar < 256 else 0,
            kenar if kenar < 256 else 0,
            0, 0, 1, 32, len(govde), ofset,
        )
        ofset += len(govde)
    with open(yol, "wb") as f:
        f.write(basliklar)
        for _, govde in govdeler:
            f.write(govde)


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
