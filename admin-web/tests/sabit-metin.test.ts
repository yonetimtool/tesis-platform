// TUR 47 — SABIT (cevrilmemis) METIN TARAMASI.
//
// Onceki taramalar TURKCE'YE OZGU HARF (ğ/ı/ş/İ) ya da anahtar kelime
// ariyordu. Bu yuzden "Tahakkuklar", "Tutar (TL)", "Blok etiketi", "Kat",
// "sil", "Temizlik", "Kontrol", "CSV indir", "var"/"yok" gibi ONLARCA metin
// yillarca gorulmedi — hicbiri TR'ye ozgu harf tasimiyor. Tur 41/42/44'te
// bunlar TEK TEK, o sayfa surulunce ortaya cikti.
//
// Bu tarama KARAKTERE degil KONUMA bakar: JSX metin dugumu ve kullaniciya
// gorunen oznitelikler (`label`, `title`, `placeholder`, `hint`,
// `aria-label`, `alt`...) DIZGE SABITI olamaz; `t("anahtar")` uzerinden
// gelmelidir. Dil bilgisinden bagimsizdir, dolayisiyla Ingilizce sabitleri
// de yakalar.
import { describe, expect, it } from "vitest";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

/** Cevrilmesi GEREKMEYEN degerler: marka, teknik jeton, ornek/bicim. */
const IZINLI =
  /^(Yönetio|yonetio|NFC|CSV|TL|TRY|ID|URL|API|SMS|QR|GPS|MinIO|JSON|HTTP|app_user|HH:MM|https?:\/\/\.\.\.|—|·|✓|→|[\d.,:/+-]+|[A-Z]-\d+|.{0,1})$/;

/** Kullaniciya GORUNEN oznitelikler. */
const OZNITELIK =
  /\b(label|title|placeholder|hint|baslik|subtitle|description|aria-label|alt)="([^"]{2,80})"/g;

/** JSX metin dugumu: `>metin<` (ifade `{...}` degil). */
const METIN = />([^<>{}\n]{2,80})</g;

function dosyalar(kok: string): string[] {
  const out: string[] = [];
  for (const ad of readdirSync(kok)) {
    const yol = join(kok, ad);
    if (statSync(yol).isDirectory()) out.push(...dosyalar(yol));
    else if (yol.endsWith(".tsx")) out.push(yol);
  }
  return out;
}

function harfVar(s: string): boolean {
  return /[A-Za-zÇĞİÖŞÜçğıöşü]{2}/.test(s);
}

describe("sabit metin taramasi (tur 47)", () => {
  it("JSX metinleri ve gorunen oznitelikler t() uzerinden gelir", () => {
    const bulgular: string[] = [];
    for (const yol of [...dosyalar("app"), ...dosyalar("components")]) {
      const satirlar = readFileSync(yol, "utf8").split("\n");
      satirlar.forEach((l, i) => {
        if (l.includes("eslint")) return;
        for (const m of l.matchAll(METIN)) {
          const t = m[1].trim();
          // Cok satirli JSX ifadelerinin PARCASI (`(a.zaman`, `=== 1 && i`)
          // dizge sabiti degildir: operator/nokta iceren parcalari ele.
          if (!harfVar(t) || IZINLI.test(t)) continue;
          if (/[(){}[\]=&|!<>+*/]|\w\.\w/.test(t)) continue;
          bulgular.push(`${yol}:${i + 1}  ${t}`);
        }
        for (const m of l.matchAll(OZNITELIK)) {
          const t = m[2].trim();
          if (!harfVar(t) || IZINLI.test(t)) continue;
          bulgular.push(`${yol}:${i + 1}  ${m[1]}="${t}"`);
        }
      });
    }
    expect(
      bulgular,
      `Cevrilmemis sabit metin (t("...") kullanin):\n${bulgular.join("\n")}`,
    ).toEqual([]);
  });
});
