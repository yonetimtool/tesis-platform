// (P253 §B, plan §4) WEB EYLEM TARAMASI — web'in backend'de neyi
// yapabildigi, KAYNAKTAN.
//
// Web istemcisi backend'e DOGRUDAN gitmez: her istek bir BFF rotasindan
// (`app/api/**/route.ts`) gecer. Yani "web'in yapabildigi eylemler" =
// BFF rotalarinin backend'e ilettigi (metot, yol) kumesi. Tarama:
//   * her `route.ts`te disa aktarilan HTTP islevini (GET/POST/...) bulur,
//   * icindeki backend cagrisini (`proxyJson`, `proxyBinary`, `anonimVekil`,
//     `anonimGet`, `backendGiris`, `callBackend`) ve ilk argumanini cozer,
//   * genel vekilleri (`panel/[kaynak]`, `tanimlar/[kaynak]`) BEYAZ LISTE
//     modullerinden acar.
// Ayrica uc uretmeyen ISTEMCI TARAFI disa aktarimlari (`csvIndir`,
// `csvMetniIndir` cagri yerleri) `istemci:<yer>` olarak verir — `data-eylem`
// isareti YERINE (P253-kararlar §B: isaret unutulabilir, cagri yeri
// unutulamaz).
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative, sep } from "node:path";

import { OKUMA, YAZMA } from "@/lib/panel-vekil";
import { TANIM_KAYNAKLARI } from "@/lib/tanimlar";

export interface WebUcu {
  metot: string;
  /** Normallestirilmis yol: parametre `{x}`, sorgu yok. */
  yol: string;
  /** Acik yol mu (true) yoksa genel vekil acilimi mi (false). */
  acik: boolean;
  kaynak: string;
}

const KOK = join(__dirname, "..");
const METOTLAR = ["GET", "POST", "PUT", "PATCH", "DELETE"] as const;

function dosyalar(dizin: string, uzanti: RegExp): string[] {
  const out: string[] = [];
  for (const ad of readdirSync(dizin)) {
    const tam = join(dizin, ad);
    if (statSync(tam).isDirectory()) {
      if (ad === "node_modules" || ad.startsWith(".next")) continue;
      out.push(...dosyalar(tam, uzanti));
    } else if (uzanti.test(ad)) {
      out.push(tam);
    }
  }
  return out;
}

/** Yolu normallestir: `${...}` -> `{x}`, sorgu atilir, sorgu-birlestirme
 *  (`/a${qs}`) atilir, cift/son egik cizgi temizlenir. */
export function yolNormalle(ham: string): string {
  // `${...}` DENGELI parantezle: ic ice sablon (`${ek ? `?${ek}` : ""}`)
  // duz bir `[^}]*` ile yarim kalirdi.
  let y = "";
  for (let i = 0; i < ham.length; i++) {
    if (ham[i] === "$" && ham[i + 1] === "{") {
      let d = 0;
      for (i = i + 1; i < ham.length; i++) {
        if (ham[i] === "{") d++;
        else if (ham[i] === "}") { d--; if (d === 0) break; }
      }
      y += "{x}";
    } else {
      y += ham[i];
    }
  }
  y = y.split("?")[0];
  // `/akilli-ev/cihazlar{x}` -> sorgu birlestirmesi; parca sonuna yapisik.
  y = y.replace(/([^/{])\{x\}$/g, "$1");
  y = y.replace(/\/+$/, "") || "/";
  return y;
}

/** `(` sonrasi ilk ust duzey arguman ve bittigi konum. */
function ilkArguman(metin: string, acilis: number): { arg: string; son: number } {
  let derinlik = 0;
  let tirnak: string | null = null;
  for (let i = acilis + 1; i < metin.length; i++) {
    const c = metin[i];
    if (tirnak) {
      if (c === "\\") { i++; continue; }
      if (c === tirnak) tirnak = null;
      else if (tirnak === "`" && c === "$" && metin[i + 1] === "{") {
        // sablon icindeki ifade: kapanan `}` e kadar ilerle
        let d = 0;
        for (i = i + 1; i < metin.length; i++) {
          if (metin[i] === "{") d++;
          else if (metin[i] === "}") { d--; if (d === 0) break; }
        }
      }
      continue;
    }
    if (c === '"' || c === "'" || c === "`") { tirnak = c; continue; }
    if (c === "(" || c === "[" || c === "{") derinlik++;
    else if (c === ")" || c === "]" || c === "}") {
      if (derinlik === 0) return { arg: metin.slice(acilis + 1, i).trim(), son: i };
      derinlik--;
    } else if (c === "," && derinlik === 0) return { arg: metin.slice(acilis + 1, i).trim(), son: i };
  }
  return { arg: "", son: metin.length };
}

/** Ifadedeki ilk `/...` ile baslayan dize/sablon. */
function ilkYolDizesi(ifade: string): string | null {
  const m = ifade.match(/(["'`])(\/[^"'`]*)\1/) ?? ifade.match(/`(\/(?:[^`]|\$\{[^}]*\})*)`/);
  if (!m) return null;
  return m[2] ?? m[1];
}

const CAGRILAR: { ad: string; metot: string | null }[] = [
  { ad: "proxyJson", metot: null },
  { ad: "proxyBinary", metot: null },
  { ad: "callBackend", metot: null },
  { ad: "anonimVekil", metot: "POST" },
  { ad: "anonimGet", metot: "GET" },
  { ad: "backendGiris", metot: "POST" },
];

/** Bir islev govdesindeki backend cagrilari. */
function govdeCagrilari(govde: string): { arg: string; metot: string | null }[] {
  const out: { arg: string; metot: string | null }[] = [];
  for (const c of CAGRILAR) {
    const re = new RegExp(`\\b${c.ad}\\(`, "g");
    let m: RegExpExecArray | null;
    while ((m = re.exec(govde))) {
      const acilis = m.index + c.ad.length;
      const { arg, son } = ilkArguman(govde, acilis);
      let metot = c.metot;
      if (metot === null) {
        const mm = govde.slice(son, son + 60).match(/^\s*,\s*"(GET|POST|PUT|PATCH|DELETE)"/);
        metot = mm ? mm[1] : null;
      }
      out.push({ arg, metot });
    }
  }
  return out;
}

/** `route.ts`i disa aktarilan HTTP islevlerine boler. */
function islevler(metin: string): { metot: string; govde: string }[] {
  const out: { metot: string; govde: string }[] = [];
  const re = /export\s+async\s+function\s+(GET|POST|PUT|PATCH|DELETE)\s*\(/g;
  const yerler: { metot: string; i: number }[] = [];
  let m: RegExpExecArray | null;
  while ((m = re.exec(metin))) yerler.push({ metot: m[1], i: m.index });
  yerler.forEach((y, k) => {
    out.push({ metot: y.metot, govde: metin.slice(y.i, k + 1 < yerler.length ? yerler[k + 1].i : undefined) });
  });
  return out;
}

const PANEL_EYLEMLERI = ["iptal", "onayla", "reddet", "ertele", "ters-kayit"];

/** Genel vekil acilimlari (dosya yoluna gore). */
function genelAcilim(goreli: string, metot: string): string[] | null {
  const okuma = Object.values(OKUMA);
  const yazma = Object.values(YAZMA);
  const tanim = Object.values(TANIM_KAYNAKLARI);
  const hepsi = [...new Set([...okuma, ...yazma])];
  switch (goreli) {
    case "app/api/panel/[kaynak]/route.ts":
      if (metot === "GET") return okuma;
      if (metot === "POST" || metot === "PUT") return yazma;
      return hepsi; // PATCH: yazma ?? okuma
    case "app/api/panel/[kaynak]/[id]/route.ts":
      return hepsi.map((k) => `${k}/{x}`);
    case "app/api/panel/[kaynak]/[id]/[eylem]/route.ts":
      if (metot === "POST") return hepsi.flatMap((k) => PANEL_EYLEMLERI.map((e) => `${k}/{x}/${e}`));
      return okuma.map((k) => `${k}/{x}/oylar`);
    case "app/api/tanimlar/[kaynak]/route.ts":
      return tanim;
    case "app/api/tanimlar/[kaynak]/[id]/route.ts":
      return tanim.map((k) => `${k}/{x}`);
    default:
      return null;
  }
}

/** Web'in backend'e iletebildigi butun (metot, yol) ciftleri. */
export function webUclari(): WebUcu[] {
  const out: WebUcu[] = [];
  for (const f of dosyalar(join(KOK, "app", "api"), /^route\.ts$/)) {
    const goreli = relative(KOK, f).split(sep).join("/");
    const metin = readFileSync(f, "utf8");
    for (const { metot, govde } of islevler(metin)) {
      const genel = genelAcilim(goreli, metot);
      if (genel) {
        for (const y of genel) out.push({ metot, yol: yolNormalle(y), acik: false, kaynak: goreli });
        continue;
      }
      for (const c of govdeCagrilari(govde)) {
        let yol = ilkYolDizesi(c.arg);
        if (!yol && /^[A-Za-z_]\w*$/.test(c.arg)) {
          // Degisken: ayni islevdeki tanimi.
          const tanimi = govde.match(new RegExp(`(?:const|let)\\s+${c.arg}\\s*=\\s*([^;]+);`));
          if (tanimi) yol = ilkYolDizesi(tanimi[1]);
        }
        if (!yol) continue;
        out.push({ metot: c.metot ?? metot, yol: yolNormalle(yol), acik: true, kaynak: goreli });
      }
    }
  }
  return out;
}

/** Uc uretmeyen istemci tarafi disa aktarimlar: `istemci:<yer>`. */
export function istemciEylemleri(): string[] {
  const out = new Set<string>();
  for (const dizin of ["app", "components", "lib"]) {
    for (const f of dosyalar(join(KOK, dizin), /\.tsx?$/)) {
      const goreli = relative(KOK, f).split(sep).join("/");
      if (goreli === "lib/csv.ts" || goreli.startsWith("app/api/")) continue;
      if (!/\bcsv(Metni)?Indir\(/.test(readFileSync(f, "utf8"))) continue;
      const sayfa = goreli.match(/^app\/\(protected\)\/(.+)\/page\.tsx$/);
      out.add(`istemci:${sayfa ? `/${sayfa[1]}` : goreli}`);
    }
  }
  return [...out].sort();
}

export const _test = { islevler, govdeCagrilari, ilkArguman, METOTLAR };
