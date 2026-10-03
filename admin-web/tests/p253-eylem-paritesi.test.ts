// (P253 §B, plan §4.2) EYLEM PARITESI — web kilidi.
//
// Web'in backend'e iletebildigi her (metot, yol) `contracts/eylem-paritesi.tsv`
// tablosunda bir satira eslenmeli ve o satir `web=+` demeli. Tersine,
// `web=+` diyen her satir taramada BULUNMALI (bayat isaret yok).
//
// Web'e yeni bir eylem (BFF rotasi ya da beyaz liste girisi) eklendiginde bu
// test duser: mobil karsiligini yaz ya da tabloya gerekceyle ekle.
// Istemci tarafi disa aktarimlar (`csvIndir`) `ISTEMCI` satirlariyla eslenir.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

import { istemciEylemleri, webUclari } from "./eylem-tarama";

interface Satir {
  metot: string;
  uc: string;
  web: string;
  mobil: string;
  durum: string;
}

const WEB_KOK = join(__dirname, "..");
const TABLO = join(WEB_KOK, "..", "contracts", "eylem-paritesi.tsv");

function kaynakDosyalari(): string[] {
  const out: string[] = [];
  const gez = (d: string) => {
    for (const ad of readdirSync(join(WEB_KOK, d))) {
      const g = `${d}/${ad}`;
      if (statSync(join(WEB_KOK, g)).isDirectory()) gez(g);
      else if (/\.tsx?$/.test(ad)) out.push(g);
    }
  };
  for (const d of ["app", "components", "lib"]) gez(d);
  return out;
}

function tablo(): Satir[] {
  const satirlar = readFileSync(TABLO, "utf8").split("\n").filter((l) => l.trim() && !l.startsWith("#"));
  const [baslik, ...govde] = satirlar;
  const ad = baslik.split("\t");
  return govde.map((l) => Object.fromEntries(l.split("\t").map((v, i) => [ad[i], v])) as unknown as Satir);
}

/** Taranan yolu tablodaki sozlesme yoluna esle. Puan: ayni sabit parca 2,
 *  degisken<->parametre 1, degisken<->sabit 0. ESIT puanda ilk satir —
 *  ama esitlik ancak gercekten belirsiz yolda olur (uretec de ayni kurali
 *  kullandi). */
export function esle(satirlar: Satir[], metot: string, yol: string): Satir | null {
  const ys = yol.replace(/^\//, "").split("/");
  let en: { puan: number; s: Satir } | null = null;
  for (const s of satirlar) {
    if (s.metot !== metot) continue;
    const os = s.uc.replace(/^\//, "").split("/");
    if (os.length !== ys.length) continue;
    let puan = 0;
    let uyar = true;
    for (let i = 0; i < ys.length; i++) {
      const parametre = /^\{.+\}$/.test(os[i]);
      if (ys[i] === os[i]) puan += 2;
      // Taranan yerde DEGISKEN ve sozlesmede PARAMETRE: sabit parcadan once
      // gelir (`/integrations/${id}` -> `{id}`, `presets` degil).
      else if (ys[i] === "{x}" && parametre) puan += 1;
      else if (ys[i] === "{x}" || parametre) continue;
      else { uyar = false; break; }
    }
    if (uyar && (!en || puan > en.puan)) en = { puan, s };
  }
  return en?.s ?? null;
}

describe("(P253) eylem paritesi — web", () => {
  const satirlar = tablo();
  const uclar = webUclari();

  it("web'in her ACIK cagrisi tabloda bir SOZLESME ucuna eslenir", () => {
    const eslesmeyen = uclar
      .filter((u) => u.acik && !esle(satirlar, u.metot, u.yol))
      .map((u) => `${u.metot} ${u.yol}  (${u.kaynak})`);
    expect(
      [...new Set(eslesmeyen)],
      "Web bu uca gidiyor ama sozlesmede/tabloda YOK (yanlis yol ya da sozlesme eksik)",
    ).toEqual([]);
  });

  it("web'in yapabildigi her eylem tabloda web=+ (yeni eylem -> mobil karari zorunlu)", () => {
    const eksik = new Set<string>();
    for (const u of uclar) {
      const s = esle(satirlar, u.metot, u.yol);
      if (s && s.web !== "+") eksik.add(`${s.metot} ${s.uc}  (${u.kaynak})`);
    }
    expect(
      [...eksik].sort(),
      "Web'e YENI bir eylem eklendi. contracts/eylem-paritesi.tsv'de web=+ yapin ve " +
        "mobil durumunu yazin (ayni / planli:N / yalniz_web + gerekce).",
    ).toEqual([]);
  });

  it("tabloda web=+ diyen her satir taramada BULUNUR (bayat isaret yok)", () => {
    const bulunan = new Set<string>();
    for (const u of uclar) {
      const s = esle(satirlar, u.metot, u.yol);
      if (s) bulunan.add(`${s.metot} ${s.uc}`);
    }
    const bayat = satirlar
      .filter((s) => s.metot !== "ISTEMCI" && s.web === "+" && !bulunan.has(`${s.metot} ${s.uc}`))
      .map((s) => `${s.metot} ${s.uc}`);
    expect(bayat, "Web artik bu uca gitmiyor; tabloda web=- yapin").toEqual([]);
  });

  it("istemci tarafi disa aktarimlar ISTEMCI satirlariyla BIREBIR", () => {
    const tablodaki = satirlar.filter((s) => s.metot === "ISTEMCI").map((s) => `istemci:${s.uc}`).sort();
    expect(istemciEylemleri()).toEqual(tablodaki);
  });

  it("elle Blob kuran yeni bir disa aktarim YOK (yardimci disinda)", () => {
    // `csvIndir` disinda dosya uretmek tarayicidan kacar; izinli iki yer:
    // yardimcinin kendisi ve xlsx OKUYUCU (dosya uretmez, okur).
    const izinli = new Set(["lib/csv.ts", "lib/xlsx-oku.ts"]);
    const yerler = kaynakDosyalari()
      .filter((f) => /new Blob\(/.test(readFileSync(join(WEB_KOK, f), "utf8")))
      .filter((f) => !izinli.has(f));
    expect(yerler, "csvIndir/csvMetniIndir kullanin (eylem tarayicisi onlari gorur)").toEqual([]);
  });
});
