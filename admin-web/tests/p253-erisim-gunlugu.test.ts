// (P253 A1) ERISIM GUNLUGU MASKESI — infra/Caddyfile `erisim_gunlugu`.
//
// Gunluge yalniz ROTA ve SAYI girer. Bu kilit Caddy'nin `multi_regexp`
// kurallarini OKUR ve ayni sirayla uygular:
//   * sorgu dizesi hic yazilmaz (`?q=Ahmet` — arama kutusunda kisi adi);
//   * herkese acik her DINAMIK sayfanin (`/davet/[jeton]`) kendi maskesi var
//     — yeni bir jetonlu sayfa eklenip maske unutulursa duser;
//   * hicbir gercek sayfa yolu maskeye TAKILMAZ (uzun-parca kurali 24
//     karakter; `/rezervasyon-yonetimi` 20 karakter — esik daralirsa duser).
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

const KOK = join(__dirname, "..");
const CADDY = readFileSync(join(KOK, "..", "infra", "Caddyfile"), "utf8");

function kurallar(): [RegExp, string][] {
  const blok = CADDY.match(/request>uri multi_regexp \{([\s\S]*?)\n\s*\}/);
  if (!blok) throw new Error("Caddyfile: request>uri multi_regexp bulunamadi");
  return [...blok[1].matchAll(/regexp "((?:[^"\\]|\\.)*)" "((?:[^"\\]|\\.)*)"/g)].map(
    ([, d, y]) => [new RegExp(d.replace(/\\\\/g, "\\"), "g"), y.replace(/\$(\d)/g, "$$$1")],
  );
}

function maskele(uri: string): string {
  return kurallar().reduce((y, [d, r]) => y.replace(d, r), uri);
}

/** app/ altindaki sayfa yollari (grup klasorleri atlanir). */
function sayfalar(): { yol: string; acik: boolean }[] {
  const out: { yol: string; acik: boolean }[] = [];
  const gez = (d: string, parcalar: string[], korumali: boolean) => {
    for (const ad of readdirSync(join(KOK, d))) {
      const g = `${d}/${ad}`;
      if (ad === "api" && d === "app") continue;
      if (statSync(join(KOK, g)).isDirectory()) {
        const grup = /^\(.*\)$/.test(ad);
        gez(g, grup ? parcalar : [...parcalar, ad], korumali || ad === "(protected)");
      } else if (ad === "page.tsx") {
        out.push({ yol: `/${parcalar.join("/")}`, acik: !korumali });
      }
    }
  };
  gez("app", [], false);
  return out;
}

describe("(P253 A1) erisim gunlugu maskesi", () => {
  it("sorgu dizesi gunluge YAZILMAZ", () => {
    expect(maskele("/kisiler?q=Ahmet%20Yilmaz")).toBe("/kisiler");
    expect(maskele("/giris/oauth?code=GIZLI")).toBe("/giris/oauth");
  });

  it("kimlik ve jeton parcalari maskelenir", () => {
    expect(maskele("/davet/kisa")).toBe("/davet/:jeton");
    expect(maskele("/tenants/3bdf2a8a-7278-491f-a5fb-e689c54061cb")).toBe("/tenants/:id");
    expect(maskele("/x/12345/y")).toBe("/x/:id/y");
    expect(maskele("/x/abcDEF1234567890_xyzQWERTYuiop")).toBe("/x/:jeton");
    // Gercek davet jetonu bicimi (token_urlsafe: harf, rakam, "-" ve "_") —
    // prod diskinde /davet/:jeton olarak dogrulandi; kilit de kapsasin.
    expect(maskele("/davet/aB1-cD2_eF3-gH4_iJ5-kL6_mN7-oP8_qR9")).toBe("/davet/:jeton");
    expect(maskele("/davet/Ab3_dE-f9xYz")).toBe("/davet/:jeton");
    expect(maskele("/davet/-_-_")).toBe("/davet/:jeton");
  });

  it("dosya uzantilari Caddy ve olcum betiginde AYNI (sayfa olarak sayilmaz)", () => {
    const caddy = CADDY.match(/@erisimDosya path_regexp erisimDosya \\\.\(\?:([^)]+)\)\$/);
    const betik = readFileSync(join(KOK, "..", "docs", "P253-kullanim-olcumu.sh"), "utf8")
      .match(/DOSYA = re\.compile\(r"\\\.\(\?:([^)]+)\)\$"/);
    expect(caddy, "Caddyfile @erisimDosya bulunamadi").not.toBeNull();
    expect(betik, "olcum betigi DOSYA bulunamadi").not.toBeNull();
    expect(betik![1]).toBe(caddy![1]);
    const dosya = new RegExp(`\\.(?:${caddy![1]})$`, "i");
    for (const y of ["/fonts/inter.woff2", "/yonetio-logo.png", "/robots.txt", "/favicon.ico"]) {
      expect(dosya.test(y), y).toBe(true);
    }
    // Hicbir gercek SAYFA yolu dosya sanilmaz.
    expect(sayfalar().filter((s) => dosya.test(s.yol)).map((s) => s.yol)).toEqual([]);
  });

  it("herkese acik her DINAMIK sayfanin Caddy maskesi var", () => {
    const eksik = sayfalar()
      .filter((s) => s.acik && s.yol.includes("["))
      .filter((s) => {
        const ornek = s.yol.replace(/\[[^\]]+\]/g, "kisa");
        return maskele(ornek).includes("kisa");
      })
      .map((s) => s.yol);
    expect(eksik, "jetonlu sayfa var ama Caddyfile'da maskesi yok").toEqual([]);
  });

  it("hicbir gercek sayfa yolu maskeye takilmaz", () => {
    const bozulan = sayfalar()
      .filter((s) => !s.yol.includes("["))
      .filter((s) => maskele(s.yol) !== s.yol)
      .map((s) => s.yol);
    expect(bozulan).toEqual([]);
  });
});
