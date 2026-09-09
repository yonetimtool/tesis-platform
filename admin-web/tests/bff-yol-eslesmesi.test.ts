// (P163 §1) BFF YOL ESLESMESI — 405 SINIFININ KILIDI.
//
// BILDIRILEN HATA: toplu daire olusturmada "Kaydet" 405 Method Not
// Allowed doneriyordu ve sunucu log'unda traceback YOKTU.
//
// KOK NEDEN (olculdu, tahmin edilmedi):
//   panel  -> POST /api/units/bulk
//   Next   -> app/api/units/[id]/route.ts  (id = "bulk")
//   o dosyada POST TANIMLI DEGIL -> 405, istek backend'e HIC GITMEDI.
//
// Uc ve sozlesme dogruydu (`openapi.yaml: /units/bulk: post`,
// `units.py: @router.post("/bulk")`). Eksik olan TEK halka BFF'ti.
//
// AYNI TARAMA IKINCI BIR KIRIK BULDU (`kat-sil`) ve IKI "KAZAYLA CALISAN"
// yol buldu (`toplu`, `siralama`): onlarin vekili de yoktu ama `[id]`
// rotasinin `PATCH`i devraliyor ve `/units/${id}` tesadufen dogru URL'yi
// kuruyordu.
//
// BU TEST NE OLCER: panelin cagirdigi HER `/api/*` alt-yolunun, o metodu
// GERCEKTEN tanimlayan bir vekil dosyasi var mi. Yani hatanin sinifini
// kilitler, tek ornegini degil.
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

const KOK = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const API = join(KOK, "app", "api");

/** Kaynakta gecen `apiSend("<yol>", "<METOT>"` cagrilarini toplar. */
function cagrilar(): { yol: string; metot: string; dosya: string }[] {
  const cikti: { yol: string; metot: string; dosya: string }[] = [];
  const tara = (dizin: string) => {
    for (const ad of readdirSync(dizin)) {
      const tam = join(dizin, ad);
      if (statSync(tam).isDirectory()) {
        // `app/api` BFF'in KENDISI — cagiran degil.
        if (tam === API) continue;
        tara(tam);
        continue;
      }
      if (!ad.endsWith(".tsx") && !ad.endsWith(".ts")) continue;
      const kaynak = readFileSync(tam, "utf8");
      for (const m of kaynak.matchAll(
        /apiSend(?:<[^>]*>)?\(\s*[`"]([^`"$]+)[`"]\s*,\s*"(GET|POST|PATCH|PUT|DELETE)"/g,
      )) {
        cikti.push({ yol: m[1], metot: m[2], dosya: tam.slice(KOK.length + 1) });
      }
    }
  };
  tara(join(KOK, "app"));
  tara(join(KOK, "components"));
  return cikti;
}

/**
 * Bir `/api/...` yolunun hangi route dosyasina duseceğini bulur.
 *
 * Next kuralini taklit eder: DUZ SEGMENT dinamik segmenti YENER. Bu
 * ayrimi atlarsak test, `bulk` icin `[id]`yi bulur ve gercek davranisi
 * olcmez.
 */
function rotaDosyasi(yol: string): string | null {
  const parcalar = yol.replace(/^\/api\//, "").split("/").filter(Boolean);
  let dizin = API;
  for (const p of parcalar) {
    const duz = join(dizin, p);
    if (existsSync(duz) && statSync(duz).isDirectory()) {
      dizin = duz;
      continue;
    }
    const dinamik = readdirSync(dizin).find(
      (a) => a.startsWith("[") && statSync(join(dizin, a)).isDirectory(),
    );
    if (!dinamik) return null;
    dizin = join(dizin, dinamik);
  }
  const dosya = join(dizin, "route.ts");
  return existsSync(dosya) ? dosya : null;
}

/**
 * (P221) IKINCI TARAMA: `fetch("/api/...")` ve `useSWR("/api/...")`.
 *
 * `apoSend` taramasi TEK BASINA YETMIYORDU: `/api/ozellikler` vekilini
 * silip suite'i kosunca HICBIR test dusmedi — cunku o cagri `apiSend`
 * ile degil SWR anahtariyla, `lib/` altinda yapiliyor. Yani P163'te
 * kilitlenen 405 sinifi, cagri BU BICIMDE yazildiginda hala kacabiliyordu.
 *
 * `lib/` de taranir: veri cekme oradan da yapiliyor.
 */
function duzCagrilar(): { yol: string; dosya: string }[] {
  const cikti: { yol: string; dosya: string }[] = [];
  const tara = (dizin: string) => {
    for (const ad of readdirSync(dizin)) {
      const tam = join(dizin, ad);
      if (statSync(tam).isDirectory()) {
        if (tam === API) continue;
        tara(tam);
        continue;
      }
      if (!ad.endsWith(".tsx") && !ad.endsWith(".ts")) continue;
      const kaynak = readFileSync(tam, "utf8");
      for (const m of kaynak.matchAll(
        /(?:fetch|useSWR(?:<[^>]*>)?)\(\s*[`"](\/api\/[^`"$?]+)/g,
      )) {
        cikti.push({ yol: m[1], dosya: tam.slice(KOK.length + 1) });
      }
    }
  };
  tara(join(KOK, "app"));
  tara(join(KOK, "components"));
  tara(join(KOK, "lib"));
  return cikti;
}

/**
 * Yol bir `route.ts`e cozuluyor mu?
 *
 * GERI IZLEMELI: duz segment dinamigi yener AMA yalniz o dalda gercekten
 * bir `route.ts` varsa. `app/api/panel/ice-aktarim/` yalniz `[id]`
 * tasiyor, kendi `route.ts`i yok — Next o istegi kardes `[kaynak]`
 * vekiline verir. Duz dali kosulsuz secen bir cozucu, CALISAN bir yolu
 * "eksik" diye raporlardi (ilk yazimda tam bunu yapti).
 *
 * Sondaki `/` (sablon degiskeninin onu) DINAMIK segment demektir.
 */
function cozuluyorMu(yol: string): boolean {
  const parcalar = yol.replace(/^\/api\//, "").split("/");
  const acikUclu = parcalar[parcalar.length - 1] === "";
  const segmentler = parcalar.filter(Boolean);

  const dene = (dizin: string, i: number): boolean => {
    if (i === segmentler.length) {
      if (!acikUclu) return existsSync(join(dizin, "route.ts"));
      // ACIK UCLU (`/api/x/${id}/...`): degiskenden SONRASINI kaynaktan
      // bilemiyoruz. Olculebilen tek sey, dinamik bir cocugun VAR
      // olmasi — bunu olcup fazlasini iddia etmiyoruz.
      return readdirSync(dizin).some(
        (a) => a.startsWith("[") && statSync(join(dizin, a)).isDirectory(),
      );
    }
    const duz = join(dizin, segmentler[i]);
    if (existsSync(duz) && statSync(duz).isDirectory() && dene(duz, i + 1)) {
      return true;
    }
    return readdirSync(dizin).some(
      (a) =>
        a.startsWith("[") &&
        statSync(join(dizin, a)).isDirectory() &&
        dene(join(dizin, a), i + 1),
    );
  };
  return dene(API, 0);
}

const DUZ_CAGRILAR = duzCagrilar();

describe("(P221) duz fetch/SWR cagrilarinin da vekili VAR", () => {
  it("tarama gercekten cagri buluyor", () => {
    expect(DUZ_CAGRILAR.length).toBeGreaterThan(50);
  });

  it("HER `/api/...` anahtari bir route dosyasina duser", () => {
    const eksik = DUZ_CAGRILAR.filter((c) => !cozuluyorMu(c.yol)).map(
      (c) => `${c.dosya}: ${c.yol}`,
    );
    expect(eksik, `vekil dosyasi YOK:\n${eksik.join("\n")}`).toEqual([]);
  });
});

const CAGRILAR = cagrilar();

describe("(P163) her BFF cagrisinin vekili VAR ve METODU tanimli", () => {
  it("tarama gercekten cagri buluyor (sessizce bosa dusmesin)", () => {
    expect(CAGRILAR.length).toBeGreaterThan(30);
  });

  it("HER cagrilan yol bir route dosyasina duser", () => {
    const eksik = CAGRILAR.filter((c) => rotaDosyasi(c.yol) === null).map(
      (c) => `${c.dosya}: ${c.metot} ${c.yol}`,
    );
    expect(eksik, `vekil dosyasi YOK:\n${eksik.join("\n")}`).toEqual([]);
  });

  it("HER cagrilan METOT o dosyada TANIMLI (405 sinifi)", () => {
    // 405'in kendisi budur: dosya eslesir ama metot yoktur. Next o
    // durumda hicbir govdeyi calistirmadan 405 doner — bu yuzden sunucu
    // log'unda iz kalmaz ve hata "sebepsiz" gorunur.
    const eksik: string[] = [];
    for (const c of CAGRILAR) {
      const dosya = rotaDosyasi(c.yol);
      if (!dosya) continue;
      const kaynak = readFileSync(dosya, "utf8");
      if (!new RegExp(`export async function ${c.metot}\\b`).test(kaynak)) {
        eksik.push(`${c.metot} ${c.yol} -> ${dosya.slice(KOK.length + 1)}`);
      }
    }
    expect(eksik, `metot TANIMLI DEGIL (405 verir):\n${eksik.join("\n")}`).toEqual([]);
  });
});

describe("(P163) yapisal daire yollarinin KENDI vekili var", () => {
  // Bu dortlu `[id]`ye dusmemeli: ikisi 405 veriyordu, ikisi kazayla
  // calisiyordu. Kendi dosyalari olmasi, davranisin tesadufe degil
  // KARARA baglanmasi demek.
  for (const [yol, metot] of [
    ["/api/units/bulk", "POST"],
    ["/api/units/toplu", "PATCH"],
    ["/api/units/siralama", "PATCH"],
    ["/api/units/kat-sil", "POST"],
  ] as const) {
    it(`${metot} ${yol} kendi dosyasinda`, () => {
      const dosya = rotaDosyasi(yol);
      expect(dosya, `${yol} icin vekil yok`).toBeTruthy();
      expect(dosya, `${yol} hala [id]'ye dusuyor`).not.toContain("[id]");
      expect(readFileSync(dosya!, "utf8")).toContain(`export async function ${metot}`);
    });
  }

  it("`[id]` rotasi UUID DOGRULAR — yanlis eslesme sessiz kalmaz", () => {
    const kaynak = readFileSync(join(API, "units", "[id]", "route.ts"), "utf8");
    // Kimlik UUID degilse 404: yeni bir yapisal yol eklenip vekili
    // unutulursa "bulunamadi" denir, "yontem yok" degil — ve gercek
    // sebebin aranacagi yer bellidir.
    expect(kaynak).toMatch(/UUID\s*=/);
    expect(kaynak.match(/UUID\.test/g) ?? []).toHaveLength(3);
  });
});
