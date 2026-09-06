import fs from "node:fs";
import path from "node:path";

import yaml from "js-yaml";
import { describe, expect, it } from "vitest";

/**
 * ==========================================================================
 * BFF VEKIL BUTUNLUGU — 405 SINIFI HATANIN KALICI KAPISI
 * ==========================================================================
 * Bu depoda AYNI kusur iki kez olculdu (P173 ve P189):
 *
 *   Backend ucu MUKEMMEL calisir, ama BFF `route.ts` o metodu `export`
 *   etmezse web cagrisi 405 alir. Backend testleri bunu YAKALAMAZ cunku
 *   onlar backend'i olcer; kirilan sey ARADA kalan katmandir.
 *
 * Bu kapi Dukkan'da GUN 1'de kuruluyor — kusur olustuktan sonra degil.
 * `admin-web/tests/uc-sozlesme-kapisi.test.ts` ayni isi panel icin yapiyor.
 *
 * NE OLCULUYOR
 *   1. Sozlesmedeki (`contracts/openapi.yaml`) her `/dukkan/*` ucu icin
 *      bir BFF vekil rotasi VAR MI,
 *   2. o rota, ucun HER METODUNU export ediyor mu (GET var, POST yok gibi
 *      bir eksiklik tam olarak 405 uretir),
 *   3. ters yon: var olmayan bir uca vekil yazilmis mi (olu kod).
 */

const KOK = path.resolve(__dirname, "../../..");
const SOZLESME = path.join(KOK, "contracts/openapi.yaml");
const API_DIZINI = path.resolve(__dirname, "../app/api");

type Sozlesme = {
  paths: Record<string, Record<string, unknown>>;
};

const METOTLAR = ["get", "post", "put", "patch", "delete"] as const;

/** OpenAPI yolunu BFF dosya yoluna cevirir.
 *  /dukkan/lokasyon/il/{il_slug}/ilce  ->  app/api/lokasyon/il/[X]/ilce
 *  Dinamik parca adi ONEMLI DEGIL ([il] ya da [il_slug] olabilir);
 *  onemli olan AYNI KONUMDA bir dinamik parca bulunmasi. */
function beklenenParcalar(yol: string): string[] {
  return yol
    .replace(/^\/dukkan\//, "")
    .split("/")
    .filter(Boolean);
}

/** BFF dizininde, verilen parca desenine uyan route.ts'i bulur. */
function vekilBul(parcalar: string[]): string | null {
  let dizin = API_DIZINI;
  for (const parca of parcalar) {
    if (!fs.existsSync(dizin)) return null;
    const girisler = fs.readdirSync(dizin, { withFileTypes: true })
      .filter((d) => d.isDirectory())
      .map((d) => d.name);

    const dinamikMi = parca.startsWith("{") && parca.endsWith("}");
    const eslesen = dinamikMi
      ? girisler.find((g) => g.startsWith("[") && g.endsWith("]"))
      : girisler.find((g) => g === parca);
    if (!eslesen) return null;
    dizin = path.join(dizin, eslesen);
  }
  const dosya = path.join(dizin, "route.ts");
  return fs.existsSync(dosya) ? dosya : null;
}

function exportEdilenMetotlar(dosya: string): Set<string> {
  const kaynak = fs.readFileSync(dosya, "utf8");
  const bulunan = new Set<string>();
  for (const m of METOTLAR) {
    const buyuk = m.toUpperCase();
    if (new RegExp(`export\\s+(async\\s+)?function\\s+${buyuk}\\b`).test(kaynak)) {
      bulunan.add(m);
    }
  }
  return bulunan;
}

const sozlesme = yaml.load(fs.readFileSync(SOZLESME, "utf8")) as Sozlesme;
const dukkanYollari = Object.entries(sozlesme.paths).filter(([y]) =>
  y.startsWith("/dukkan"),
);

describe("BFF vekil butunlugu", () => {
  it("sozlesmede /dukkan ucu VAR (kapi bos yere yesil yanmasin)", () => {
    expect(dukkanYollari.length).toBeGreaterThan(0);
  });

  for (const [yol, islemler] of dukkanYollari) {
    const beklenen = METOTLAR.filter((m) => m in islemler);

    it(`${yol} -> vekil rotasi var ve ${beklenen.join(",").toUpperCase()} export ediyor`, () => {
      const dosya = vekilBul(beklenenParcalar(yol));
      expect(
        dosya,
        `'${yol}' icin BFF vekili YOK. Bu uc web'den cagrilinca 405 alir ` +
          `ve backend testleri bunu GORMEZ (P173/P189'da iki kez olculdu).`,
      ).not.toBeNull();

      const edilen = exportEdilenMetotlar(dosya!);
      const eksik = beklenen.filter((m) => !edilen.has(m));
      expect(
        eksik,
        `${path.relative(KOK, dosya!)} su metotlari export ETMIYOR: ` +
          `${eksik.join(", ").toUpperCase()}. Backend ucu calissa bile web ` +
          `cagrisi 405 doner.`,
      ).toEqual([]);
    });
  }
});

describe("olu vekil yok", () => {
  const vekiller: string[] = [];
  const tara = (dizin: string) => {
    if (!fs.existsSync(dizin)) return;
    for (const g of fs.readdirSync(dizin, { withFileTypes: true })) {
      const tam = path.join(dizin, g.name);
      if (g.isDirectory()) tara(tam);
      else if (g.name === "route.ts") vekiller.push(tam);
    }
  };
  tara(API_DIZINI);

  it("her BFF rotasinin sozlesmede bir karsiligi var", () => {
    const kapsanan = new Set(
      dukkanYollari
        .map(([y]) => vekilBul(beklenenParcalar(y)))
        .filter((d): d is string => d !== null),
    );
    const olu = vekiller.filter((v) => !kapsanan.has(v));
    expect(
      olu.map((v) => path.relative(KOK, v)),
      "sozlesmede karsiligi olmayan BFF rotasi (olu kod ya da sozlesmeye " +
        "eklenmemis uc)",
    ).toEqual([]);
  });
});
