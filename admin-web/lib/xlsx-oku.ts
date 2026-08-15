/**
 * (P162 §4.2) XLSX OKUYUCU — bagimliliksiz, tarayicida.
 *
 * =========================================================================
 * NEDEN VAR: "Excel ice aktarma calismiyor"
 * =========================================================================
 * Boru hattinin TAMAMI zaten vardi (sablon, kolon esleme, dogrulama,
 * onizleme, hata raporu, kismi basari, geri alma). Eksik olan tek sey
 * DOSYA OKUMAKTI: sayfa yalnizca YAPISTIRMA kabul ediyordu. Kullanici
 * elindeki `.xlsx` dosyasini surukleyip birakinca hicbir sey olmuyordu —
 * "calismiyor" sikayetinin kaynagi buydu.
 *
 * P154'teki karar ("xlsx kitapligi eklemeyelim") gerekcesiyle birlikte
 * yaziliydi: yeni bir kod yolu, yeni bir saldiri yuzeyi. O gerekce
 * DOGRU; cozum kitaplik eklemek DEGIL, gerekli olan en kucuk okuyucuyu
 * yazmak oldu.
 *
 * =========================================================================
 * NE OKUR, NE OKUMAZ
 * =========================================================================
 * XLSX bir ZIP icinde XML'dir. Burada yalnizca:
 *   * ZIP merkezi dizini okunur, girdiler `DecompressionStream` ile acilir,
 *   * `xl/sharedStrings.xml` metin tablosu,
 *   * ILK sayfanin hucre degerleri (paylasilan dize, satir-ici dize, sayi).
 *
 * OKUNMAYANLAR — bilincli ve guvenlik gerekcesi acik:
 *   * FORMUL DEGERLENDIRILMEZ. `<f>` dugumu tamamen yok sayilir; yalnizca
 *     onbelleklenmis deger (`<v>`) alinir. Formul yorumlamak, kullanicinin
 *     dosyasindan gelen bir ifadeyi calistirmak olurdu.
 *   * MAKRO, HARICI BAG, DDE yok sayilir.
 *   * XML VARLIKLARI genisletilmez (yalnizca bes standart varlik cozulur)
 *     — XXE/varlik-bombasi yolu bastan kapali.
 *
 * =========================================================================
 * DESTEK VE ACIK GERI DUSUS
 * =========================================================================
 * `DecompressionStream("deflate-raw")` gerekir (Chrome 103+, Firefox 113+,
 * Safari 16.4+). YOKSA SESSIZ KALINMAZ: `XlsxDesteklenmiyor` firlatilir ve
 * sayfa kullaniciyi YAPISTIRMA yoluna yonlendirir. Sessizce bos satir
 * dondurmek, "dosyam bos mu, uygulama mi bozuk" sorusunu cevapsiz
 * birakirdi.
 */

export class XlsxHatasi extends Error {}
export class XlsxDesteklenmiyor extends XlsxHatasi {}

/** ZIP yerel/merkezi imzalari. */
const MERKEZ_SON = 0x06054b50;
const MERKEZ_GIRDI = 0x02014b50;

interface ZipGirdisi {
  ad: string;
  sikistirma: number;
  veriBaslangici: number;
  sikistirilmisBoy: number;
}

function metinCoz(bayt: Uint8Array): string {
  return new TextDecoder().decode(bayt);
}

/**
 * ZIP merkezi dizinini okur.
 *
 * YEREL BASLIKTAN DEGIL MERKEZDEN: yerel basliklar akis halinde yazilmis
 * dosyalarda boyut alanlarini 0 birakabilir (veri tanimlayici kullanir);
 * merkezi dizin her zaman dolu ve dosyanin sonunda tek yerdedir.
 */
function zipGirdileri(gv: DataView, ham: Uint8Array): ZipGirdisi[] {
  // EOCD kaydini sondan geriye ara (yorum alani en fazla 65535 bayt).
  let eocd = -1;
  const enAz = Math.max(0, ham.length - 65557);
  for (let i = ham.length - 22; i >= enAz; i--) {
    if (gv.getUint32(i, true) === MERKEZ_SON) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) throw new XlsxHatasi("zip_eocd_yok");

  const adet = gv.getUint16(eocd + 10, true);
  let p = gv.getUint32(eocd + 16, true);
  const girdiler: ZipGirdisi[] = [];
  for (let i = 0; i < adet; i++) {
    if (gv.getUint32(p, true) !== MERKEZ_GIRDI) throw new XlsxHatasi("zip_girdi_bozuk");
    const sikistirma = gv.getUint16(p + 10, true);
    const sikistirilmisBoy = gv.getUint32(p + 20, true);
    const adBoyu = gv.getUint16(p + 28, true);
    const ekBoy = gv.getUint16(p + 30, true);
    const yorumBoy = gv.getUint16(p + 32, true);
    const yerel = gv.getUint32(p + 42, true);
    const ad = metinCoz(ham.subarray(p + 46, p + 46 + adBoyu));
    // Yerel basligin degisken alanlari girdiye gore FARKLI olabilir;
    // veri baslangici yerel baslikta yeniden okunmali.
    const yerelAdBoyu = gv.getUint16(yerel + 26, true);
    const yerelEkBoy = gv.getUint16(yerel + 28, true);
    girdiler.push({
      ad,
      sikistirma,
      veriBaslangici: yerel + 30 + yerelAdBoyu + yerelEkBoy,
      sikistirilmisBoy,
    });
    p += 46 + adBoyu + ekBoy + yorumBoy;
  }
  return girdiler;
}

async function girdiAc(ham: Uint8Array, g: ZipGirdisi): Promise<string> {
  const dilim = ham.subarray(g.veriBaslangici, g.veriBaslangici + g.sikistirilmisBoy);
  if (g.sikistirma === 0) return metinCoz(dilim);
  if (g.sikistirma !== 8) throw new XlsxHatasi("zip_yontem_desteklenmiyor");
  if (typeof DecompressionStream === "undefined") throw new XlsxDesteklenmiyor();
  const akis = new Blob([dilim]).stream().pipeThrough(
    new DecompressionStream("deflate-raw"),
  );
  return new Response(akis).text();
}

/** Yalnizca BES standart XML varligi. Ozel varlik GENISLETILMEZ (XXE yok). */
function xmlCoz(s: string): string {
  return s
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)))
    .replace(/&amp;/g, "&");
}

/** `sharedStrings.xml` -> metin tablosu. */
function paylasilanDizeler(xml: string): string[] {
  const cikti: string[] = [];
  for (const m of xml.matchAll(/<si\b[^>]*>([\s\S]*?)<\/si>/g)) {
    // Bir `<si>` birden cok `<t>` parcasi tasiyabilir (zengin metin);
    // hepsi BIRLESTIRILIR, yoksa bicimlendirilmis basliklar kirpilirdi.
    const parcalar = [...m[1].matchAll(/<t\b[^>]*>([\s\S]*?)<\/t>/g)].map((x) => x[1]);
    cikti.push(xmlCoz(parcalar.join("")));
  }
  return cikti;
}

/** `A1` / `BC12` -> sifir tabanli sutun indeksi. */
export function sutunIndeksi(ref: string): number {
  let n = 0;
  for (const ch of ref) {
    const k = ch.charCodeAt(0);
    if (k < 65 || k > 90) break;
    n = n * 26 + (k - 64);
  }
  return n - 1;
}

/** Sayfa XML'i -> satirlar. Eksik hucreler BOS DIZE ile doldurulur. */
export function sayfayiCoz(xml: string, dizeler: string[]): string[][] {
  const satirlar: string[][] = [];
  for (const r of xml.matchAll(/<row\b[^>]*>([\s\S]*?)<\/row>/g)) {
    const hucreler: string[] = [];
    for (const c of r[1].matchAll(/<c\b([^>]*)(?:\/>|>([\s\S]*?)<\/c>)/g)) {
      const oz = c[1];
      const ic = c[2] ?? "";
      const refM = /r="([A-Z]+)\d+"/.exec(oz);
      const idx = refM ? sutunIndeksi(refM[1]) : hucreler.length;
      // ATLANAN HUCRELER: XLSX bos hucreyi HIC yazmaz. Indeksle
      // hizalamazsak kolonlar kayar ve esleme sessizce yanlis olur.
      while (hucreler.length < idx) hucreler.push("");

      const tip = /t="([^"]+)"/.exec(oz)?.[1];
      let deger = "";
      if (tip === "inlineStr") {
        deger = [...ic.matchAll(/<t\b[^>]*>([\s\S]*?)<\/t>/g)].map((x) => x[1]).join("");
        deger = xmlCoz(deger);
      } else {
        // `<f>` (FORMUL) BILEREK YOK SAYILIR — yalnizca onbelleklenmis
        // deger okunur. Formul yorumlamak, kullanicinin dosyasindan gelen
        // bir ifadeyi calistirmak olurdu.
        const v = /<v\b[^>]*>([\s\S]*?)<\/v>/.exec(ic)?.[1] ?? "";
        deger = tip === "s" ? (dizeler[Number(v)] ?? "") : xmlCoz(v);
      }
      hucreler[idx] = deger;
    }
    satirlar.push(hucreler);
  }
  return satirlar;
}

/**
 * Bir `.xlsx` dosyasindan ILK sayfanin satirlarini okur.
 *
 * ILK SAYFA: sablon tek sayfalidir ve kullaniciya "hangi sayfa" diye
 * sormak, akisa bir adim daha eklerdi. Coklu sayfa gerekirse burada
 * secim acilir.
 */
export async function xlsxSatirlari(dosya: File | Blob): Promise<string[][]> {
  const ham = new Uint8Array(await dosya.arrayBuffer());
  const gv = new DataView(ham.buffer, ham.byteOffset, ham.byteLength);
  const girdiler = zipGirdileri(gv, ham);

  const paylasilan = girdiler.find((g) => g.ad === "xl/sharedStrings.xml");
  const dizeler = paylasilan ? paylasilanDizeler(await girdiAc(ham, paylasilan)) : [];

  // Sayfa dosyasi her zaman `sheet1.xml` degil; ada gore ilkini al.
  const sayfalar = girdiler
    .filter((g) => /^xl\/worksheets\/sheet\d+\.xml$/.test(g.ad))
    .sort((a, b) => a.ad.localeCompare(b.ad, undefined, { numeric: true }));
  if (sayfalar.length === 0) throw new XlsxHatasi("xlsx_sayfa_yok");

  return sayfayiCoz(await girdiAc(ham, sayfalar[0]), dizeler);
}
