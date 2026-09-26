// (P123) KAPSAM KILIDI (panel) — maskesiz kalan telefon girdisi BASARISIZLIKTIR.
//
// Mobil tarafin `telefon_alani_kapsam_test.dart` ikizi. Boyle bir gocun
// tipik eksik kalma bicimi: uc girdiden ikisi tasinir, ucuncusu gozden
// kacar ve hicbir test dusmez — cunku o sayfa zaten "calisiyordur".
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

/** Bir kokteki tum tsx dosyalari (`node_modules`/`.next*` haric). */
function kaynaklar(kok = "app"): string[] {
  const out: string[] = [];
  if (!existsSync(kok)) return out;
  for (const ad of readdirSync(kok)) {
    if (ad === "node_modules" || ad.startsWith(".next")) continue;
    const yol = join(kok, ad);
    if (statSync(yol).isDirectory()) out.push(...kaynaklar(yol));
    else if (yol.endsWith(".tsx")) out.push(yol);
  }
  return out;
}

/**
 * (P248 §2) TARAMA KAPSAMI GENISLEDI: yalniz `app/` degil `components/`
 * ve iki ayri site (`apps/dukkan-web`, `apps/tanitim-web`).
 *
 * OLCULEN KACAK: `components/GirisFormu.tsx` (giris), `components/
 * TanitimForm.tsx`, `components/ice-aktarim/aktarim-tablosu.tsx` (Excel
 * tablosu) ve iki sitenin dort formu ORTAK bilesen disindaydi — tarama
 * yalniz `app/`e bakiyordu ve yalniz `value={...telefon...}` ariyordu.
 */
const APPS = join("..", "apps");
function tumKaynaklar(): string[] {
  const out = [...kaynaklar("app"), ...kaynaklar("components")];
  for (const site of ["dukkan-web", "tanitim-web"]) {
    out.push(...kaynaklar(join(APPS, site, "app")));
    out.push(...kaynaklar(join(APPS, site, "components")));
  }
  return out;
}

/**
 * ORTAK BILESENIN KENDISI — kurali uygulayan yerler, ihlal sayilmaz.
 *
 *  * `components/TelefonAlani.tsx` + `components/UlkeSecici.tsx`: panelin
 *    tek telefon bileseni.
 *  * `apps/<site>/components/TelefonAlani.tsx`: iki ayri Docker yapim
 *    baglamindaki sitelerin ORTAK kopyasi — asagida bayt bayt
 *    karsilastiriliyor (mantik `lib/telefon.ts` ile ayni dosya).
 */
const ISTISNALAR = [
  "components/TelefonAlani.tsx",
  "components/UlkeSecici.tsx",
];

/** `//` yorumlarini ve JSX yorumlarini siler (ornek bulgu sayilmasin). */
const yorumsuz = (s: string) =>
  s
    .replace(/\{\/\*[\s\S]*?\*\/\}/g, "")
    // `/*` YALNIZ satir basinda/bosluktan sonra yorum baslatir:
    // `accept="image/*"` bir dizge, yorum DEGIL (olculdu: profil
    // sayfasinin yarisini yutuyordu).
    .replace(/(^|\s)\/\*[\s\S]*?\*\//g, "$1")
    .split("\n")
    .map((l) => l.replace(/(^|[^:])\/\/.*$/, "$1"))
    .join("\n");

/** Telefon sayilan adlar: telefon, phone, gsm, cep_tel ... */
const TEL_AD = String.raw`[A-Za-z_]*(?:telefon|phone|gsm|ceptel)[A-Za-z_]*`;

/**
 * Bir dosyadaki telefon girdisi ihlalleri.
 *
 * Mantik AYRI fonksiyonda: kasitli kusurlu bir ornekle sinanabilsin diye.
 * Depoda ihlal kalmadigi icin "gecen" bir tarama calistigini KANITLAMAZ.
 */
export function telefonIhlalleri(kaynak: string, yol: string): string[] {
  const normal = yol.split("\\").join("/");
  if (ISTISNALAR.some((i) => normal.endsWith(i))) return [];
  if (/apps\/[^/]+\/components\/TelefonAlani\.tsx$/.test(normal)) return [];
  const temiz = yorumsuz(kaynak);
  const bulgular: string[] = [];
  const satirNo = (i: number) => temiz.slice(0, i).split("\n").length;
  const kaydet = (i: number, neden: string) =>
    bulgular.push(`${yol}:${satirNo(i)}  ${neden}`);

  // 1) `value={...telefon...}` tasiyan her girdi (P123'ten beri).
  //
  // (P233 §3) `telefonGiris` MUAFIYETI KALDIRILDI: kendi `<input>`unu
  // kuran form bicimlendiriciyi CAGIRSA DA ulke secicisi gelmez. Artik
  // TEK kabul edilen sey `<TelefonAlani>`.
  for (const m of temiz.matchAll(
    new RegExp(String.raw`value=\{[^}]*(?:telefon|phone)[^}]*\}`, "gi"),
  )) {
    kaydet(m.index ?? 0, "telefon girdisi MASKESIZ (value)");
  }
  // 2) (P248 §2) TELEFON KLAVYESI / OTOMATIK DOLDURMA — ortak bilesen
  //    disinda `type="tel"`, `inputMode="tel"`, `autoComplete="tel..."`
  //    ancak kendi telefon alanini kuran bir ekranda olur.
  for (const m of temiz.matchAll(
    /\b(?:type|inputMode)=["'{]\s*["']?tel["']|autoComplete=["']tel/g,
  )) {
    kaydet(m.index ?? 0, "ham telefon girdisi (type/inputMode/autoComplete tel)");
  }
  // 3) (P248 §2) ADI TELEFON OLAN HAM GIRDI — `<input name="telefon">`
  //    (FormData ile okunan formlar `value` tasimaz; 1. madde gormez).
  for (const m of temiz.matchAll(/<(input|textarea|Alan)\b[^>]*?\/?>/g)) {
    const etiket = m[0];
    if (
      new RegExp(String.raw`\b(?:name|id)=["']${TEL_AD}["']`, "i").test(etiket)
    ) {
      kaydet(m.index ?? 0, "adi telefon olan ham girdi");
    }
  }
  // 4) (P248 §2) TANIM DEFTERI ALANI: `{ ad: "telefon", tip: "metin" }`
  //    — /tanimlar firma defterinde tam olarak bu kaciyordu.
  for (const m of temiz.matchAll(
    new RegExp(
      String.raw`\{[^{}]*\bad:\s*["']${TEL_AD}["'][^{}]*\btip:\s*["'](?!telefon["'])[a-z]+["']`,
      "gi",
    ),
  )) {
    kaydet(m.index ?? 0, "tanim alani telefon ama tip telefon DEGIL");
  }
  return bulgular;
}

describe("telefon girdisi kapsami", () => {
  it("DEDEKTOR: tarama KASITLI kusurlari gorur", () => {
    const k = (kod: string) => telefonIhlalleri(kod, "components/ornek.tsx");
    expect(k("<input value={form.telefon} />")).toHaveLength(1);
    // (P233 §3) Kendi `<input>`unu kuran form, bicimlendiriciyi CAGIRSA
    // DA ihlaldir: ulke kodu secicisi gelmez.
    expect(k("<input value={telefonGiris(form.telefon)} />")).toHaveLength(1);
    // (P248 §2) Yeni desenler.
    expect(k('<input type="tel" value={x} />')).toHaveLength(1);
    expect(k('<input inputMode="tel" value={x} />')).toHaveLength(1);
    expect(k('<input autoComplete="tel" />')).toHaveLength(1);
    expect(k('<input name="telefon" maxLength={40} />')).toHaveLength(1);
    expect(k('<Alan id="yetkili_telefon" />')).toHaveLength(1);
    expect(
      k('{ ad: "telefon", etiket: "x", tip: "metin", sutun: true },'),
    ).toHaveLength(1);
    // Yorum ve ORTAK BILESEN ihlal DEGIL.
    expect(k("// ornek: value={form.telefon}")).toHaveLength(0);
    expect(k('{/* <input type="tel" /> */}')).toHaveLength(0);
    expect(k('<TelefonAlani etiket="x" deger={telefon} name="telefon" />'))
      .toHaveLength(0);
    expect(k('{ ad: "telefon", etiket: "x", tip: "telefon" },')).toHaveLength(0);
    // `tel:` baglantisi (goruntuleme) girdi degil.
    expect(k("<a href={`tel:${i.telefon}`}>{i.telefon}</a>")).toHaveLength(0);
    // Istisna: ortak bilesenin kendisi.
    expect(
      telefonIhlalleri('<input inputMode="tel" />', "components/TelefonAlani.tsx"),
    ).toHaveLength(0);
  });

  it("HER telefon girdisi ORTAK bileseni kullanir (panel + iki site)", () => {
    const bulgular = tumKaynaklar().flatMap((f) =>
      telefonIhlalleri(readFileSync(f, "utf8"), f),
    );
    expect(
      bulgular,
      `Ortak bilesen disinda telefon girdisi kaldi — <TelefonAlani> kullanin:\n${bulgular.join("\n")}`,
    ).toEqual([]);
  });

  it("EN AZ ... ALAN olculuyor (bos kume 'temiz' sayilmasin)", () => {
    // Kapsam kilidinin en sinsi bozulma bicimi: desen degisir, tarama
    // hicbir sey bulamaz ve "gecti" der.
    const metin = tumKaynaklar()
      .map((f) => yorumsuz(readFileSync(f, "utf8")))
      .join("\n");
    const bilesen = metin.match(/<TelefonAlani\b/g)?.length ?? 0;
    // (P248 §2) ON ALTI: tanimlar, users, tenants, tenants/[id] (x2),
    // dis-hizmetler, profil, kayit, bakim (P233-P236) + giris, tanitim
    // formu, Excel tablosu (panel) + dukkan giris, isletme kaydi,
    // tanitim iletisim, tanitim kayit (siteler).
    expect(bilesen).toBeGreaterThanOrEqual(16);
  });

  it("sitelerin kopyalari panelle BAYT BAYT ayni", () => {
    // Iki site ayri Docker baglaminda derlendigi icin panelden import
    // EDEMEZ (bkz. `apps/*/components/TelefonAlani.tsx` bas yorumu).
    // Kopya sessizce eskirse iki yuzey FARKLI telefon kurali uygular.
    const siteler = ["dukkan-web", "tanitim-web"].filter((s) =>
      existsSync(join(APPS, s)),
    );
    for (const site of siteler) {
      for (const dosya of ["lib/telefon.ts", "lib/ulke-telefon.ts"]) {
        expect(
          readFileSync(join(APPS, site, dosya), "utf8"),
          `${site}/${dosya} panelin kopyasi degil — cp admin-web/${dosya} apps/${site}/${dosya}`,
        ).toBe(readFileSync(dosya, "utf8"));
      }
    }
    if (siteler.length === 2) {
      expect(
        readFileSync(join(APPS, "tanitim-web/components/TelefonAlani.tsx"), "utf8"),
        "iki sitenin TelefonAlani kopyasi ayrismis",
      ).toBe(
        readFileSync(join(APPS, "dukkan-web/components/TelefonAlani.tsx"), "utf8"),
      );
    }
  });
});
