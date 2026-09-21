// (P244 §10e) MAKET PALETI TOKEN KATMANIYLA AYNI AILEDEN.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// `site-palet.ts`in dosya basi "durum renkleri `--yz-*-edge` ailesinin
// sayisal karsiligidir" diyordu. DEGILDI: degerler elle secilmis,
// doygunlugu dusurulmus tonlardi (#6586a4, #ad7930...). Iddia ile kod
// AYRISMISTI — ve boyle bir ayrisma, yorumun yanlis yone guven vermesi
// demektir.
//
// Ayrica maket kendi gri ailesini tasiyordu (#151b22, #e8edf2, #d8e0e9)
// ve P244'ten sonra ana sayfadaki TEK uyumsuz oge oydu.
//
// ===========================================================================
// NE OLCULUYOR — ve neden "esit" DEGIL
// ===========================================================================
// WebGL `var(--yz-*)` anlamaz; renk GPU'ya SAYI olarak gider. Yani
// palet token'i kopyalamak zorunda. Ama BIREBIR ESITLIK de dogru sart
// degil: durum renkleri duvara karsi 3.0 esigini tutmak icin ISIKLIGI
// kaydirilmis tonlardir (P244 asama 1'in `-ink`/`-edge` yontemi).
//
// Bu yuzden olculen sey TON (hue) AYNILIGI:
//   normal -> accent, borclu -> warning, alarm -> danger,
//   pasif -> text-2, secim/hover -> success
//
// Yuzeyler ise BIREBIR esit olmali — onlarin kontrast sarti yok, rolu
// var: bina = kart yuzeyi, tabla = cokuk yuzey, tuval = sayfa zemini.
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

import { durumRenkleri, hoverRengi, sahnePaleti, secimRengi } from "@/components/3d/site-palet";

const KOK = join(__dirname, "..");
const SISTEM = readFileSync(join(KOK, "app", "tasarim-sistemi.css"), "utf8");

function token(ad: string, koyu = false): string {
  const hepsi = [...SISTEM.matchAll(new RegExp(`--${ad}:\\s*(#[0-9a-fA-F]{6})`, "g"))];
  if (hepsi.length === 0) throw new Error(`Token yok: --${ad}`);
  return (koyu ? hepsi[hepsi.length - 1] : hepsi[0])[1].toLowerCase();
}

/** HSL tonu (0-360). Isiklik ve doygunluk YOK SAYILIR. */
function ton(hex: string): number {
  const n = parseInt(hex.slice(1), 16);
  const r = ((n >> 16) & 255) / 255;
  const g = ((n >> 8) & 255) / 255;
  const b = (n & 255) / 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  if (max === min) return -1; // notr (gri) — tonu yok
  const d = max - min;
  let h: number;
  if (max === r) h = ((g - b) / d) % 6;
  else if (max === g) h = (b - r) / d + 2;
  else h = (r - g) / d + 4;
  h *= 60;
  return h < 0 ? h + 360 : h;
}

/** Iki ton arasindaki EN KISA aci farki. */
function tonFarki(a: string, b: string): number {
  const x = ton(a);
  const y = ton(b);
  if (x < 0 || y < 0) return Math.abs(x - y) < 1 ? 0 : 999;
  const d = Math.abs(x - y);
  return Math.min(d, 360 - d);
}

// Isiklik kaydirmasi tonu birkac derece oynatabilir; pay birakiliyor.
const TON_PAYI = 8;

describe("(P244 §10e) durum renkleri token AILESINDEN", () => {
  const ESLESME: [string, string][] = [
    ["normal", "yz-accent"],
    ["borclu", "yz-warning"],
    ["alarm", "yz-danger"],
    ["pasif", "yz-text-2"],
  ];

  for (const koyu of [false, true]) {
    const ad = koyu ? "koyu" : "acik";
    for (const [durum, tk] of ESLESME) {
      it(`${ad}: ${durum} tonu --${tk} ile ayni`, () => {
        const sahne = durumRenkleri(koyu)[durum as "normal"];
        expect(tonFarki(sahne, token(tk, koyu)), `${sahne} vs ${token(tk, koyu)}`).toBeLessThanOrEqual(
          TON_PAYI,
        );
      });
    }
    it(`${ad}: secim ve hover --yz-success ailesinden`, () => {
      const y = token("yz-success", koyu);
      expect(tonFarki(secimRengi(koyu), y)).toBeLessThanOrEqual(TON_PAYI);
      expect(tonFarki(hoverRengi(koyu), y)).toBeLessThanOrEqual(TON_PAYI);
    });
  }
});

describe("(P244 §10e) sahne YUZEYLERI token ile BIREBIR", () => {
  const ESLESME: [keyof ReturnType<typeof sahnePaleti>, string][] = [
    ["arkaPlan", "yz-bg-app"],
    ["platform", "yz-surface-sunken"],
    ["platformKenar", "yz-border"],
    ["kutle", "yz-surface-1"],
    ["katCizgisi", "yz-border"],
    ["cati", "yz-surface-2"],
  ];
  for (const koyu of [false, true]) {
    const ad = koyu ? "koyu" : "acik";
    for (const [alan, tk] of ESLESME) {
      it(`${ad}: ${String(alan)} = --${tk}`, () => {
        expect(String(sahnePaleti(koyu)[alan]).toLowerCase()).toBe(token(tk, koyu));
      });
    }
  }

  it("DOGA OGELERI token'a ZORLANMADI (cim/havuz/agac)", () => {
    // Cimin, havuzun, agacin semantik bir token karsiligi YOKTUR.
    // Onlari da `--yz-*`a zorlamak, olmayan bir anlam uydurmak olurdu.
    // Bu iddia o karari GORUNUR tutar: biri "tutarlilik" adina cimi
    // gri yaparsa test duser.
    const p = sahnePaleti(false);
    expect(p.cim).not.toBe(token("yz-surface-1"));
    expect(p.havuz).not.toBe(token("yz-surface-1"));
  });
});
