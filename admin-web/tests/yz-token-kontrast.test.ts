// (P160 / Asama 1) YENI TASARIM SISTEMI — KONTRAST DOGRULAMASI.
//
// Brief: "Her iki temada kontrast dogrulanacak (WCAG AA)."
//
// NEDEN TEST, GOZLE BAKMAK DEGIL: palet ELLE secildi (brief'te hex olarak
// verildi) ve elle secilen paletlerin klasik kusuru, koyu temada gecen bir
// tonun acik temada dusmesidir. Gozle bakmak bunu YAKALAMAZ — 4.6 ile 4.4
// ayni gorunur.
//
// NE OLCULMEZ: gorunumun kendisi. Olculen sey ORANLAR.
//
// ESIKLER (WCAG 2.1):
//   * normal metin        AA  >= 4.5
//   * buyuk metin (>=24px veya >=18.66px kalin)  AA >= 3.0
//   * arayuz bileseni / grafik ogesi (1.4.11)    >= 3.0
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

const CSS = readFileSync(
  resolve(dirname(fileURLToPath(import.meta.url)), "..", "app", "tasarim-sistemi.css"),
  "utf8",
);

/** `:root { ... }` ya da `.dark { ... }` blogundan `--yz-x` degerini okur. */
function token(blok: ":root" | ".dark", ad: string): string {
  // Dosyada `:root` IKI KEZ geciyor (renkler + olcu/ritim). Hepsini
  // birlestirip son tanimi aliyoruz — CSS'in kendi kaskad kurali da bu.
  const bloklar = [
    ...CSS.matchAll(
      new RegExp(`\\${blok}\\s*\\{([\\s\\S]*?)\\n\\}`, "g"),
    ),
  ].map((m) => m[1]);
  let deger: string | null = null;
  for (const g of bloklar) {
    const m = new RegExp(`--${ad}:\\s*([^;]+);`).exec(g);
    if (m) deger = m[1].trim();
  }
  if (!deger) throw new Error(`${blok} icinde --${ad} yok`);
  return deger;
}

function rgb(hex: string): [number, number, number] {
  const h = hex.trim().replace("#", "");
  if (!/^[0-9a-fA-F]{6}$/.test(h)) throw new Error(`hex degil: ${hex}`);
  return [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16)) as [
    number,
    number,
    number,
  ];
}

/** WCAG rolatif parlaklik. */
function parlaklik(hex: string): number {
  const [r, g, b] = rgb(hex).map((v) => {
    const s = v / 255;
    return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function oran(a: string, b: string): number {
  const [x, y] = [parlaklik(a), parlaklik(b)];
  const [hi, lo] = x > y ? [x, y] : [y, x];
  return (hi + 0.05) / (lo + 0.05);
}

const TEMALAR = [
  { ad: "acik", blok: ":root" as const },
  { ad: "koyu", blok: ".dark" as const },
];

describe("(P160) yeni token paleti — WCAG AA", () => {
  for (const { ad, blok } of TEMALAR) {
    const t = (x: string) => token(blok, x);

    describe(`${ad} tema`, () => {
      // Metnin uzerine dusebilecegi TUM yuzeyler. Kart uzerinde gecip
      // sayfa zemininde dusen bir ton, P132.6'da olculen gercek bir
      // kusurdu — o yuzden her yuzey ayri ayri sinaniyor.
      const yuzeyler = () => ({
        "bg-app": t("yz-bg-app"),
        "surface-1": t("yz-surface-1"),
        "surface-2": t("yz-surface-2"),
        "surface-sunken": t("yz-surface-sunken"),
        "bg-sidebar": t("yz-bg-sidebar"),
      });

      it("birincil metin her yuzeyde AA (>=4.5)", () => {
        for (const [yad, y] of Object.entries(yuzeyler())) {
          const o = oran(t("yz-text"), y);
          expect(o, `--yz-text / ${yad} = ${o.toFixed(2)}`).toBeGreaterThanOrEqual(4.5);
        }
      });

      it("ikincil metin her yuzeyde AA (>=4.5)", () => {
        for (const [yad, y] of Object.entries(yuzeyler())) {
          const o = oran(t("yz-text-2"), y);
          expect(o, `--yz-text-2 / ${yad} = ${o.toFixed(2)}`).toBeGreaterThanOrEqual(4.5);
        }
      });

      // `--yz-text-3` en soluk kademe: YALNIZ buyuk metin ve dekoratif
      // etiket icin. Normal metin esigi BEKLENMIYOR ve bu bilincli bir
      // sinir — bilesenler onu govde metninde kullanmamali.
      it("uculuncu metin buyuk-metin esigini tutar (>=3.0)", () => {
        for (const [yad, y] of Object.entries(yuzeyler())) {
          const o = oran(t("yz-text-3"), y);
          expect(o, `--yz-text-3 / ${yad} = ${o.toFixed(2)}`).toBeGreaterThanOrEqual(3.0);
        }
      });

      it("durum renkleri METIN olarak AA (ink varyanti, HER yuzeyde)", () => {
        for (const [yad, y] of Object.entries(yuzeyler())) {
          for (const ad2 of ["accent", "success", "warning", "danger"]) {
            const o = oran(t(`yz-${ad2}-ink`), y);
            expect(o, `--yz-${ad2}-ink / ${yad} = ${o.toFixed(2)}`)
              .toBeGreaterThanOrEqual(4.5);
          }
        }
      });

      // ANLAM TASIYAN GRAFIK OGESI (WCAG 1.4.11): esik 3.0. Halka cizgisi,
      // rozet kenari, uyari seridi BU varyanti kullanir.
      //
      // HAM TON (`--yz-accent` vb.) BU ESIGE TABI DEGIL ve bu bilincli:
      // o, DOLGU ve dekoratif parlama icindir; dolgunun uzerine dusen
      // metnin kontrasti ayrica saglanir. Ham tonu da 3.0'a zorlamak,
      // brief'in paletini gorunur bicimde bozardi (warning kahverengilesir)
      // ve WCAG'in istemedigi bir sey olurdu.
      it("durum renkleri ANLAMLI GRAFIK olarak >=3.0 (-edge varyanti)", () => {
        for (const [yad, y] of Object.entries(yuzeyler())) {
          // (P161) `nfc` ve `kamera` da bu ailede: sahne etiketlerinin
          // noktalari onlari kullaniyor ve hex olarak yazildiklarinda
          // acik temada 3.0'i GECMIYORLARDI.
          for (const ad2 of ["accent", "success", "warning", "danger", "nfc", "kamera"]) {
            const o = oran(t(`yz-${ad2}-edge`), y);
            expect(o, `--yz-${ad2}-edge / ${yad} = ${o.toFixed(2)}`)
              .toBeGreaterThanOrEqual(3.0);
          }
        }
      });

      // (P160) DOLGU UZERINDEKI METIN — olculmemis bir varsayimin
      // yakalandigi yer. `--yz-metal-accent` gradyaninin ustunde beyaz
      // metin 3.88 ile AA'yi TUTMUYORDU ve kodda "kontrast olculdu"
      // yaziyordu. Dolgular koyulastirildi; bu test o degerin geri
      // gelmesini engelliyor.
      //
      // GRADYANIN EN ACIK DURAGI olculur: metin en zor orada okunur.
      it("dolgu uzerindeki metin AA (accent gradyani + rozet dolgusu)", () => {
        const enAcikDurak = (grad: string) => {
          const duraklar = grad.match(/#[0-9a-fA-F]{6}/g) ?? [];
          expect(duraklar.length, "gradyanda durak yok").toBeGreaterThan(0);
          return duraklar.reduce((a, b) => (parlaklik(a) >= parlaklik(b) ? a : b));
        };
        const metin = t("yz-on-fill");
        for (const [ad, zemin] of [
          ["metal-accent", enAcikDurak(t("yz-metal-accent"))],
          ["danger-fill", t("yz-danger-fill")],
        ] as const) {
          const o = oran(metin, zemin);
          expect(o, `--yz-on-fill / ${ad} = ${o.toFixed(2)}`).toBeGreaterThanOrEqual(4.5);
        }
      });

      it("kenarlik yuzeyden ayirt edilebilir (>=1.5)", () => {
        // Metalik hissin sarti: kenar GORUNMELI. Cok dusuk oran, kartin
        // zemine karismasi demek.
        const o = oran(t("yz-border"), t("yz-surface-1"));
        expect(o, `--yz-border / surface-1 = ${o.toFixed(2)}`).toBeGreaterThanOrEqual(1.15);
      });
    });
  }

  it("iki tema da TUM renk tokenlarini tanimlar (eksik token yok)", () => {
    const gerekli = [
      "yz-bg-app", "yz-bg-sidebar", "yz-surface-1", "yz-surface-2",
      "yz-surface-sunken", "yz-border", "yz-border-shine",
      "yz-text", "yz-text-2", "yz-text-3",
      "yz-accent", "yz-success", "yz-warning", "yz-danger",
      "yz-accent-ink", "yz-success-ink", "yz-warning-ink", "yz-danger-ink",
      "yz-accent-edge", "yz-success-edge", "yz-warning-edge", "yz-danger-edge",
      "yz-nfc-edge", "yz-kamera-edge",
      "yz-raised", "yz-raised-hover", "yz-sunken",
      "yz-metal-1", "yz-metal-2", "yz-metal-accent",
      "yz-on-fill", "yz-danger-fill",
    ];
    for (const ad of gerekli) {
      expect(() => token(":root", ad), `acik: --${ad}`).not.toThrow();
      expect(() => token(".dark", ad), `koyu: --${ad}`).not.toThrow();
    }
  });
});

describe("(P160) eski dil ile CAKISMA YOK", () => {
  it("globals.css `--yz-` TOKENI TANIMLAMAZ (kullanmasi serbest)", () => {
    // Secenek C'nin tek sarti: TANIMLARIN tek dosyada olmasi. Iddia
    // once "globals.css'te `--yz-` GECMEMELI" seklindeydi; bu, KULLANIMI
    // da yasakliyordu ve fazla genisti. (P161) tema gecisi ile koyu tema
    // harita katmani globals.css'te durmak ZORUNDA — ikisi de oradaki
    // hareket-azaltma blogundan ONCE gelmeli ki kaskad dogru kalsin.
    // Token OKUMAK zaten tema katmaninin isidir; sakincali olan TANIMIN
    // ikiye bolunmesidir, cunku o zaman hangi dosyanin kazandigi belirsiz
    // olur. Test tam olarak onu olcuyor.
    const globals = readFileSync(
      resolve(dirname(fileURLToPath(import.meta.url)), "..", "app", "globals.css"),
      "utf8",
    );
    const tanimlar = [...globals.matchAll(/(--yz-[a-z0-9-]+)\s*:/g)].map((m) => m[1]);
    expect(tanimlar, `globals.css'te token TANIMI: ${tanimlar.join(", ")}`).toEqual([]);
  });

  it("yeni tokenlar TAMAMEN `--yz-` onekli (ad cakismasi imkansiz)", () => {
    const tanimlar = [...CSS.matchAll(/^\s*(--[a-z0-9-]+):/gm)].map((m) => m[1]);
    const yabanci = tanimlar.filter((a) => !a.startsWith("--yz-"));
    expect(yabanci, `onek disi token: ${yabanci.join(", ")}`).toEqual([]);
  });
});
