// (P132) WEB TOKEN'LARI MOBIL KAYNAKLA AYNI MI?
//
// Tasarim sisteminin kaynagi `mobile/lib/src/core/theme/home_tokens.dart`.
// Web bu degerleri KOPYALAR (iki dil, iki cati) — ve kopya, kopyalandigi
// gun dogru olup ertesi gun sessizce ayrisan seydir. Kamera adres kuralinda
// (P131.1) ayni sorunu ORTAK VAKA DOSYASI ile cozmustuk; burada dosya
// formatlari cok farkli oldugu icin daha dogrudan bir yol var: Dart
// dosyasini OKU ve web temasiyla karsilastir.
//
// NE OLCULMEZ: gorunumun kendisi (ekran goruntusu karsilastirmasi bu
// depoda yok). Olculen sey DEGERLERIN esitligi — ayrisma buradan baslar.
import { readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

const KOK = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const DART = readFileSync(
  resolve(KOK, "mobile/lib/src/core/theme/home_tokens.dart"),
  "utf8",
);
const TW = readFileSync(resolve(KOK, "admin-web/tailwind.config.ts"), "utf8");
const CSS = readFileSync(resolve(KOK, "admin-web/app/globals.css"), "utf8");

/** `static const primary = Color(0xFF2563EB);` -> "#2563EB" */
function dartRenk(ad: string): string {
  const m = new RegExp(`${ad}\\s*=\\s*Color\\(0x(?:FF)?([0-9A-Fa-f]{6})\\)`).exec(DART);
  if (!m) throw new Error(`Dart'ta renk yok: ${ad}`);
  return `#${m[1].toUpperCase()}`;
}

/** `background: Color(0xFFF4F6FA),` — HomeSurface blogu icinde. */
function dartYuzey(blok: "_light" | "_dark", alan: string): string {
  const b = new RegExp(`${blok} = HomeSurface\\(([\\s\\S]*?)\\);`).exec(DART);
  if (!b) throw new Error(`Dart'ta yuzey blogu yok: ${blok}`);
  const m = new RegExp(`${alan}:\\s*Color\\(0x(?:FF)?([0-9A-Fa-f]{6})\\)`).exec(b[1]);
  if (!m) throw new Error(`Dart'ta yuzey alani yok: ${blok}.${alan}`);
  return `#${m[1].toUpperCase()}`;
}

/** `static const cardRadius = 16.0;` -> 16 */
function dartOlcu(ad: string): number {
  const m = new RegExp(`${ad}\\s*=\\s*([0-9.]+)`).exec(DART);
  if (!m) throw new Error(`Dart'ta olcu yok: ${ad}`);
  return Number(m[1]);
}

describe("(P132) vurgu paleti mobil ile AYNI", () => {
  const eslesme: [string, string][] = [
    ["primary", "primary"],
    ["green", "green"],
    ["orange", "orange"],
    ["purple", "purple"],
    ["red", "red"],
  ];
  for (const [dartAd, webAd] of eslesme) {
    it(`${dartAd}`, () => {
      const beklenen = dartRenk(dartAd);
      // Web'de `blue` adiyla durur (dart'ta `primary`); digerleri ayni ad.
      const anahtar = webAd === "primary" ? "blue" : webAd;
      const m = new RegExp(`${anahtar}:\\s*"(#[0-9A-Fa-f]{6})"`).exec(TW);
      expect(m, `tailwind.config.ts'te accent.${anahtar} yok`).not.toBeNull();
      expect(m![1].toUpperCase()).toBe(beklenen);
    });
  }

  it("primary kisayolu da ayni deger", () => {
    const m = /primary:\s*"(#[0-9A-Fa-f]{6})"/.exec(TW);
    expect(m![1].toUpperCase()).toBe(dartRenk("primary"));
  });
});

describe("(P132) yuzey/metin renkleri", () => {
  it("ACIK tema — tailwind", () => {
    const bekle: [string, string][] = [
      ["bg", dartYuzey("_light", "background")],
      ["card", dartYuzey("_light", "card")],
      ["divider", dartYuzey("_light", "divider")],
      ["placeholder", dartYuzey("_light", "placeholder")],
    ];
    for (const [ad, deger] of bekle) {
      const m = new RegExp(`${ad}:\\s*"(#[0-9A-Fa-f]{6})"`).exec(TW);
      expect(m, `yuzey.${ad} yok`).not.toBeNull();
      expect(m![1].toUpperCase(), ad).toBe(deger);
    }
    for (const [ad, alan] of [["heading", "heading"], ["body", "body"], ["muted", "muted"]]) {
      const m = new RegExp(`${ad}:\\s*"(#[0-9A-Fa-f]{6})"`).exec(TW);
      expect(m![1].toUpperCase(), ad).toBe(dartYuzey("_light", alan));
    }
  });

  it("KOYU tema — globals.css", () => {
    // Koyu tema web'de sayfa basina `dark:` varyantiyla DEGIL, tek yerde
    // (globals.css) cozulur; deger yine mobil kaynaktan gelir.
    const bekle: [string, string][] = [
      [".dark .bg-yuzey-bg", dartYuzey("_dark", "background")],
      [".dark .bg-yuzey-card", dartYuzey("_dark", "card")],
      [".dark .text-metin-heading", dartYuzey("_dark", "heading")],
      [".dark .text-metin-body", dartYuzey("_dark", "body")],
      [".dark .text-metin-muted", dartYuzey("_dark", "muted")],
    ];
    for (const [secici, deger] of bekle) {
      const m = new RegExp(
        `${secici.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\s*\\{[^}]*?(#[0-9a-fA-F]{6})`,
      ).exec(CSS);
      expect(m, `${secici} yok`).not.toBeNull();
      expect(m![1].toUpperCase(), secici).toBe(deger);
    }
  });
});

describe("(P132) olcu token'lari", () => {
  const bekle: [string, string][] = [
    ["cardRadius", "kart"],
    ["iconBoxRadius", "ikon"],
    ["chipRadius", "chip"],
  ];
  for (const [dartAd, webAd] of bekle) {
    it(`${dartAd} -> rounded-${webAd}`, () => {
      const m = new RegExp(`${webAd}:\\s*"(\\d+)px"`).exec(TW);
      expect(m, `borderRadius.${webAd} yok`).not.toBeNull();
      expect(Number(m![1])).toBe(dartOlcu(dartAd));
    });
  }

  const olculer: [string, string][] = [
    ["cardPadding", "kart"],
    ["sectionGap", "bolum"],
    ["gridGap", "izgara"],
    ["iconBox", "ikonkutu"],
    ["rowIconBox", "satirikon"],
  ];
  for (const [dartAd, webAd] of olculer) {
    it(`${dartAd} -> spacing.${webAd}`, () => {
      const m = new RegExp(`${webAd}:\\s*"(\\d+)px"`).exec(TW);
      expect(m, `spacing.${webAd} yok`).not.toBeNull();
      expect(Number(m![1])).toBe(dartOlcu(dartAd));
    });
  }
});

describe("(P132) koyu tema VURGU METNI haritasi", () => {
  // Mobilde `_koyuMetin` haritasi: 600-tonu vurgular koyu zeminde AA'yi
  // tutmaz, ayni ailenin acik tonu kullanilir. Web ayni esleme.
  it("her vurgu icin acik ton tanimli", () => {
    const cift = [...DART.matchAll(/0x(FF[0-9A-Fa-f]{6}):\s*Color\(0x(FF[0-9A-Fa-f]{6})\)/g)];
    expect(cift.length, "Dart haritasi okunamadi").toBeGreaterThanOrEqual(5);
    for (const [, , acik] of cift) {
      const hex = `#${acik.slice(2).toLowerCase()}`;
      expect(CSS.toLowerCase(), hex).toContain(hex);
    }
  });
});

describe("(P132) tint opakligi %12", () => {
  it("Dart ve web ayni opakligi kullanir", () => {
    expect(DART).toMatch(/withValues\(alpha:\s*0\.12\)/);
    const kit = readFileSync(resolve(KOK, "admin-web/components/tasarim.tsx"), "utf8");
    // Tailwind alfa sozdizimi: `/12`.
    expect(kit).toContain("bg-accent-blue/12");
  });
});

describe("(P132.8) ELDEN GECIRILEN SINIFLAR GERI GELMESIN", () => {
  // Sayfa ici tekil sinif temizligi (39 dosya + 110 `text-muted`) bir KEREYE
  // MAHSUS ise degil: yeni yazilan bir sayfa refleksle `text-slate-600`
  // yazarsa gorunum sessizce ikiye ayrilir. Bu test o temizligi KILITLER.
  //
  // NE OLCULMEZ: butun slate paletinin yasaklanmasi. Asagida SIFIRLANMIS
  // olanlar var; `bg-slate-100` (27) ve `border-slate-300` (19) BILEREK
  // durur — notrolan cip zeminleri ve girdi kenarliklaridir, tasarim
  // sisteminde karsilik gelen bir token YOK ve ikisi de `globals.css`te
  // koyu temaya devriliyor. Karsilik uretmek bu turun kapsami degildi.
  const YASAK = [
    "text-muted", // -> text-metin-muted (token kaldirildi)
    "text-slate-700",
    "text-slate-600",
    "text-slate-500",
    "text-slate-400", // -> text-metin-body / text-metin-muted
    "bg-slate-50", // -> bg-yuzey-bg
    "border-slate-200", // -> kart-kenar
    "border-slate-100", // -> border-yuzey-divider
    "rounded-2xl", // -> rounded-kart (ayni 16px, tek ad)
    "shadow-card", // mobil kartlarda GOLGE yok
  ];

  function kaynaklar(): [string, string][] {
    const cikti: [string, string][] = [];
    for (const kok of ["app", "components"]) {
      const yigin = [resolve(KOK, "admin-web", kok)];
      while (yigin.length) {
        const d = yigin.pop()!;
        for (const ad of readdirSync(d)) {
          const yol = join(d, ad);
          if (statSync(yol).isDirectory()) yigin.push(yol);
          else if (ad.endsWith(".tsx")) cikti.push([yol, readFileSync(yol, "utf8")]);
        }
      }
    }
    return cikti;
  }

  const DOSYALAR = kaynaklar();

  it("sayfa/bilesen kaynaklarinda kalmadi", () => {
    const bulunan: string[] = [];
    for (const sinif of YASAK) {
      // `dark:` onekli kullanim MESRU: koyu tema icin bilerek yazilmistir.
      const kalip = new RegExp(`(dark:)?\\b${sinif}\\b`, "g");
      for (const [yol, kaynak] of DOSYALAR) {
        for (const m of kaynak.matchAll(kalip)) {
          if (m[1]) continue;
          bulunan.push(`${sinif} (${yol.split("admin-web/")[1]})`);
        }
      }
    }
    expect(bulunan, "tasarim sistemi disi eski sinif geri gelmis").toEqual([]);
  });

  it("kaynak taramasi GERCEKTEN dosya okuyor", () => {
    // Yukaridaki test 0 dosya okusaydi da gecerdi — bu, kilidin en olasi
    // sessiz bozulma bicimidir.
    expect(DOSYALAR.length).toBeGreaterThan(40);
    expect(DOSYALAR.some(([, s]) => s.includes("text-metin-muted"))).toBe(true);
  });
});

describe("(P132) ORTAK ILKELLER tasarim sistemine bagli", () => {
  // 47 sayfa `form.tsx`teki sinif token'larini kullaniyor. Sayfalari tek
  // tek gecirmek yerine BURASI degistirildi; bu test o kazanimi kilitler —
  // biri `panelCls`i eski slate/golge hâline dondururse 47 sayfa birden
  // sessizce eski gorunume donerdi.
  const FORM = readFileSync(resolve(KOK, "admin-web/components/form.tsx"), "utf8");

  it("kart yuzeyleri token kullaniyor (slate/golge DEGIL)", () => {
    // (P138) `tableCardCls` KALDIRILDI (olu sinif, 0 kullanim); yerini
    // `components/tablo.tsx` icindeki `TabloKart` aldi ve ayni kural
    // asagida ONUN uzerinde olculuyor — kapsam kaybi yok, yer degisti.
    for (const ad of ["cardCls", "panelCls"]) {
      const m = new RegExp(`export const ${ad}[^;]*;`, "s").exec(FORM);
      expect(m, `${ad} yok`).not.toBeNull();
      const deger = m![0];
      expect(deger, ad).toContain("rounded-kart");
      expect(deger, ad).toContain("bg-yuzey-card");
      // Mobil kartlarda GOLGE YOKTUR — ayirt edici cizgi 1px kenarliktir.
      expect(deger, ad).not.toContain("shadow-card");
      expect(deger, ad).not.toContain("border-slate-200");
    }
  });

  it("TABLO KABI da token kullaniyor (slate/golge DEGIL)", () => {
    const TABLO = readFileSync(resolve(KOK, "admin-web/components/tablo.tsx"), "utf8");
    // Govde bir sonraki `export`a kadar: ilk `\n}` yikim parantezidir ve
    // JSX'ten ONCE gelir (ilk yazimda tam bu yuzden bos yakaladi).
    const m = /export function TabloKart\([\s\S]*?(?=\nexport |\n\/\/ )/.exec(TABLO);
    expect(m, "TabloKart yok").not.toBeNull();
    expect(m![0]).toContain("rounded-kart");
    expect(m![0]).toContain("bg-yuzey-card");
    // Mobil kartlarda GOLGE YOKTUR — ayirt edici cizgi 1px kenarliktir.
    expect(m![0]).not.toContain("shadow-card");
    expect(m![0]).not.toContain("border-slate-200");
  });

  it("birincil dugme MAVI (marka teali degil)", () => {
    const m = /export const btnPrimary[^;]*;/s.exec(FORM);
    expect(m![0]).toContain("bg-primary");
    expect(m![0]).not.toContain("brand-teal");
  });

  it("girdi odagi birincil renkte", () => {
    const m = /export const inputCls[^;]*;/s.exec(FORM);
    expect(m![0]).toContain("focus:border-primary");
    expect(m![0]).not.toContain("brand-teal");
  });
});

describe("(P138) TABLO ILKELI — elle iskelet geri gelmesin", () => {
  // Kendi taramasi: `kaynaklar()` baska bir describe'in ICINDE tanimli.
  function sayfalar(): [string, string][] {
    const cikti: [string, string][] = [];
    const yigin = [resolve(KOK, "admin-web/app"), resolve(KOK, "admin-web/components")];
    while (yigin.length) {
      const d = yigin.pop()!;
      for (const ad of readdirSync(d)) {
        const yol = join(d, ad);
        if (statSync(yol).isDirectory()) yigin.push(yol);
        else if (ad.endsWith(".tsx")) cikti.push([yol, readFileSync(yol, "utf8")]);
      }
    }
    return cikti;
  }

  // 22 sayfa `<table className="w-full text-sm">` iskeletini, baslik
  // hucrelerini ve satir ayiricilarini KENDI yaziyordu; ortak katman
  // (`tableCardCls`) tanimliydi ve HICBIR sayfa kullanmiyordu (0/23).
  //
  // Bedeli gorunum degil DEGISTIRILEBILIRLIK: tablo dilinde bir karar
  // degistirmek 23 dosyaya dokunmak demekti, o yuzden hicbiri
  // degistirilmiyordu. Bu kilit kaldiraci korur.
  const SAYFALAR = sayfalar();

  // ILKELLERIN KENDISI kapsam disi: `<table>`i yazan YERLER onlardir.
  //
  // (P154) `components/Liste.tsx` EKLENDI. Gerekce: bu kilidin amaci
  // "her SAYFA kendi tablosunu yazmasin"; Liste ise sayfalarin
  // KULLANDIGI ortak davranis katmani (siralama, suzgec, sayfalama) ve
  // iskeleti bir kez yazip `tablo.tsx`in hucrelerini kullaniyor.
  // Muaf tutmasaydik kilit, tam da kendisini gereksiz kilan bilesenin
  // yazilmasini engellerdi.
  //
  // (P160) `components/ui/veri-tablosu.tsx` EKLENDI — AYNI GEREKCE.
  // Yeni tasarim dilinin `VeriTablosu`u da bir ILKELDIR: siralama,
  // sayfalama, kolon gorunurlugu, satir secimi ve toplu islemi bir kez
  // yazip tum sayfalara veriyor. Muaf tutmasaydik kilit, kendisini
  // gereksiz kilan bileseni yasaklamis olurdu.
  const ILKELLER = [
    "components/tablo.tsx",
    "components/Liste.tsx",
    "components/ui/veri-tablosu.tsx",
  ];
  const ilkelMi = (y: string) => ILKELLER.some((i) => y.endsWith(i));

  // Yorum satirlari da disarida: bu kilidin GEREKCESI de `<table>` yazmak
  // zorunda ve kendi aciklamasina takilan bir kilit yazilamaz.
  const kodSatirlari = (s: string) =>
    s
      .split("\n")
      .filter((l) => !/^\s*(\/\/|\*|\{\/\*|\/\*)/.test(l))
      .join("\n");

  it("hicbir sayfa <table>/<thead> iskeletini KENDI yazmiyor", () => {
    const sizanlar = SAYFALAR.filter(
      ([y, s]) =>
        !ilkelMi(y) && /<table\b|<thead\b/.test(kodSatirlari(s)),
    ).map(([y]) => y.split("admin-web/")[1]);
    expect(sizanlar, "ortak ilkel yerine elle tablo").toEqual([]);
  });

  it("hicbir sayfa ham <th>/<td> hucresi yazmiyor", () => {
    const sizanlar = SAYFALAR.filter(
      ([y, s]) => !ilkelMi(y) && /<t[hd]\s+className=/.test(kodSatirlari(s)),
    ).map(([y]) => y.split("admin-web/")[1]);
    expect(sizanlar, "ortak ilkel yerine ham hucre").toEqual([]);
  });

  it("TARAMA gercekten dosya okuyor (vakum degil)", () => {
    // P136 dersi: yokluk iddialari bos kume uzerinde her zaman dogrudur.
    expect(SAYFALAR.length).toBeGreaterThan(40);
    expect(SAYFALAR.some(([, s]) => s.includes("TabloKart"))).toBe(true);
  });
});
