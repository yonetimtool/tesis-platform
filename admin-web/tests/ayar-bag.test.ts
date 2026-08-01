// (P83) AYAR ANAHTARLARI SUNUCU SEMASINDA GERCEKTEN VAR MI?
//
// `settings` sayfasi operasyon ayarlarini VERI-SURUCULU cizer: `OPERASYON`
// listesindeki her `anahtar` bir sunucu alanidir. Anahtar yanlis yazilir
// ya da sunucudan kaldirilirsa sayfa yine cizer — alan gorunur, kullanici
// doldurur, "Kaydet"e basar. Sunucu o alani TANIMAZ: istek ya 422 doner
// ya da alan sessizce yok sayilir. Iki durumda da kullanici ayari
// degistirdigini SANIR.
//
// TypeScript bunu yakalamaz mi? Kismen: `keyof TenantSettings` tipi
// `lib/types.ts`teki ELLE YAZILMIS arayuze bakar. O arayuz sunucudan
// turemez — yani iki taraf birlikte yanlis olabilir. Bu bag SUNUCU
// SEMASINI kaynak alir.
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

const KOK = join(__dirname, "..");

/** `settings/page.tsx` icindeki `anahtar: "..."` degerleri. */
function panelAnahtarlari(): string[] {
  const kaynak = readFileSync(
    join(KOK, "app", "(protected)", "settings", "page.tsx"),
    "utf8",
  );
  return [...kaynak.matchAll(/anahtar:\s*"([a-z_]+)"/g)].map((m) => m[1]);
}

/** `schemas.py` icindeki `class TenantSettings(BaseModel)` alan adlari. */
function sunucuAlanlari(): string[] {
  const kaynak = readFileSync(
    join(KOK, "..", "backend", "app", "schemas.py"),
    "utf8",
  );
  const blok = /class TenantSettings\(BaseModel\):([\s\S]*?)\nclass /.exec(kaynak);
  expect(blok, "TenantSettings sinifi bulunamadi").not.toBeNull();
  return [...(blok as RegExpExecArray)[1].matchAll(/^\s{4}([a-z_]+)\s*:/gm)].map(
    (m) => m[1],
  );
}

describe("ayar anahtarlari sunucu semasinda var (P83)", () => {
  it("panelin her OPERASYON anahtari sunucuda TANIMLI", () => {
    const panel = panelAnahtarlari();
    expect(panel.length, "OPERASYON listesi bos okundu").toBeGreaterThan(0);
    const sunucu = sunucuAlanlari();
    expect(sunucu.length, "sema alanlari bos okundu").toBeGreaterThan(0);
    expect(panel.filter((a) => !sunucu.includes(a))).toEqual([]);
  });

  it("TERS YON BILEREK ZORLANMAZ", () => {
    // Sunucuda panelin GOSTERMEDIGI alanlar var (konum, otopark
    // kapasitesi, ANPR esigi...). `OPERASYON` bir "tum ayarlar" listesi
    // DEGIL, bilincli bir alt kumedir: her yeni sunucu alanini panele
    // basmak, urun karari olmadan arayuz buyutmek olurdu. Bu testin
    // varligi o karari YAZIYA gecirir — yoksa bir sonraki tur eksikligi
    // kusur sanip "tamamlamaya" kalkardi.
    const eksik = sunucuAlanlari().filter((a) => !panelAnahtarlari().includes(a));
    expect(eksik.length).toBeGreaterThan(0);
  });
});
