// (P251 §8) WEB <-> MOBIL MENU PARITESI — WEB TARAFI KILIDI.
//
// Tek kaynak `contracts/menu-paritesi.tsv`. Mobil tarafi ayni tabloyu
// `mobile/test/p251_menu_paritesi_test.dart` ile olcer. Bir yuzey grubu
// ya da adi degistirirse, tabloda olmayan bir oge eklerse ya da tablodaki
// bir ogeyi kaldirirsa KENDI kilidi duser — iki yuzey bir daha
// kendiliginden ayrisamaz. Bilincli fark tabloya GEREKCESIYLE yazilir.
//
// Ad karsilastirmasi TURKCE metinle yapilir: anahtar adi ayni olsa da
// metin farkli olabilir (kusurun kendisi buydu: "Talepler" / "Talep /
// Arıza").
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

import { tr } from "@/lib/i18n/sozluk/tr";
import { GRUP_ANAHTARI, menuGruplari } from "@/lib/menu";
import { SAKIN_MODU } from "@/lib/yuzey";

type Satir = {
  kapsam: string;
  grup: string;
  web: string;
  mobil: string;
  ad: string;
  durum: string;
  gerekce: string;
};

const GRUPLAR = ["ozet", "guvenlik", "tesis", "finans", "iletisim", "kisiler", "tanimlar", "yonetim"];
const DURUMLAR = ["ayni", "yalniz_web", "yalniz_mobil", "yapisal"];

function tablo(): Satir[] {
  const ham = readFileSync(resolve(__dirname, "../../contracts/menu-paritesi.tsv"), "utf8");
  const satirlar = ham.split("\n").filter((l) => l.trim() && !l.startsWith("#"));
  const [baslik, ...govde] = satirlar;
  expect(baslik.split("\t")).toEqual(["kapsam", "grup", "web", "mobil", "ad", "durum", "gerekce"]);
  return govde.map((l) => {
    const [kapsam, grup, web, mobil, ad, durum, gerekce] = l.split("\t");
    return { kapsam, grup, web, mobil, ad, durum, gerekce };
  });
}

const ad = (anahtar: string) => (tr as Record<string, string>)[anahtar];

describe("(P251 §8) menu paritesi tablosu", () => {
  const T = tablo();

  it("tablo okunuyor ve bos degil (olcum bosa dusmesin)", () => {
    expect(T.filter((s) => s.kapsam === "yonetici").length).toBeGreaterThan(40);
    expect(T.filter((s) => s.kapsam === "sakin").length).toBeGreaterThan(5);
  });

  it("her satir gecerli; AYNI disindaki her satirin GEREKCESI var", () => {
    const hata: string[] = [];
    for (const s of T) {
      const k = `${s.kapsam}/${s.web}/${s.mobil}`;
      if (!["yonetici", "sakin"].includes(s.kapsam)) hata.push(`${k}: kapsam`);
      if (!GRUPLAR.includes(s.grup)) hata.push(`${k}: grup ${s.grup}`);
      if (!DURUMLAR.includes(s.durum)) hata.push(`${k}: durum ${s.durum}`);
      if (s.durum === "ayni" && (s.web === "-" || s.mobil === "-")) hata.push(`${k}: ayni ama bir yuzey bos`);
      if (s.durum === "yalniz_web" && s.mobil !== "-") hata.push(`${k}: yalniz_web ama mobil dolu`);
      if (s.durum === "yalniz_mobil" && s.web !== "-") hata.push(`${k}: yalniz_mobil ama web dolu`);
      if (s.durum !== "ayni" && (!s.gerekce || s.gerekce === "-")) hata.push(`${k}: GEREKCESIZ fark`);
    }
    expect(hata).toEqual([]);
  });

  it("YONETICI: web menusu tabloyla BIREBIR (grup + Turkce ad)", () => {
    const beklenen = T.filter((s) => s.kapsam === "yonetici" && s.web !== "-");
    const menu = menuGruplari("tesis", "yonetici").flatMap((g) => g.ogeler);
    const fark: string[] = [];
    for (const o of menu) {
      const s = beklenen.find((b) => b.web === o.href);
      if (!s) {
        fark.push(`tabloda yok: ${o.href} (${ad(o.anahtar)}) — contracts/menu-paritesi.tsv'ye ekleyin`);
        continue;
      }
      if (o.grup !== s.grup) fark.push(`${o.href}: grup web=${o.grup} tablo=${s.grup}`);
      if (ad(o.anahtar) !== s.ad) fark.push(`${o.href}: ad web="${ad(o.anahtar)}" tablo="${s.ad}"`);
    }
    for (const s of beklenen) {
      if (!menu.some((o) => o.href === s.web)) fark.push(`menude yok: ${s.web} (${s.ad})`);
    }
    expect(fark).toEqual([]);
  });

  it("SAKIN MODU: web menusu tabloyla BIREBIR (Turkce ad)", () => {
    // Web sakin modu tek basliksiz bolumdur (P247); grup mobilde olculur.
    const beklenen = T.filter((s) => s.kapsam === "sakin" && s.web !== "-");
    const menu = menuGruplari("tesis", SAKIN_MODU).flatMap((g) => g.ogeler);
    const fark: string[] = [];
    for (const o of menu) {
      const s = beklenen.find((b) => b.web === o.href);
      if (!s) fark.push(`tabloda yok: ${o.href} (${ad(o.anahtar)})`);
      else if (ad(o.anahtar) !== s.ad) fark.push(`${o.href}: ad web="${ad(o.anahtar)}" tablo="${s.ad}"`);
    }
    for (const s of beklenen) {
      if (!menu.some((o) => o.href === s.web)) fark.push(`menude yok: ${s.web} (${s.ad})`);
    }
    expect(fark).toEqual([]);
  });

  it("GRUP BASLIKLARI tabloyla ayni (contracts/menu-gruplari.tsv)", () => {
    const ham = readFileSync(resolve(__dirname, "../../contracts/menu-gruplari.tsv"), "utf8");
    const satirlar = ham.split("\n").filter((l) => l.trim() && !l.startsWith("#")).slice(1);
    expect(satirlar.length).toBe(7);
    for (const l of satirlar) {
      const [grup, baslik] = l.split("\t");
      expect(ad(GRUP_ANAHTARI[grup as keyof typeof GRUP_ANAHTARI]), grup).toBe(baslik);
    }
  });

  it("ayni mobil girisi iki kapsamda AYNI grupta (mobilde grup girise baglidir)", () => {
    const grup = new Map<string, string>();
    const hata: string[] = [];
    for (const s of T.filter((x) => x.mobil !== "-")) {
      const once = grup.get(s.mobil);
      if (once && once !== s.grup) hata.push(`${s.mobil}: ${once} / ${s.grup}`);
      grup.set(s.mobil, s.grup);
    }
    expect(hata).toEqual([]);
  });
});
