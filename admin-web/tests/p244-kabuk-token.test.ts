// (P244 §2) KENAR CUBUGU ICERIK TOKENLARINI KULLANAMAZ.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// Asama 1'de kenar cubugu acik maviden (#d8e4f5) LACIVERDE (#14263a)
// tasindi ama cizim kodu hâlâ ICERIK yuzeylerinin metin tokenlarini
// kullaniyordu (`--yz-text`, `--yz-text-2`, `--yz-text-3`). Olculdu:
// `--yz-text` (#172033) lacivert uzerinde **1.06** — yani menu okunmuyordu.
//
// Asama 2 bunu duzeltti. Bu kilit GERI GELMESINI engelliyor.
//
// ===========================================================================
// NEDEN METIN TARAMASI
// ===========================================================================
// jsdom RENK COZMEZ: `getComputedStyle` CSS degiskenlerini hesaplamaz, bir
// DOM testi menuyu "gorunur" bulur ve GECER (P226'da ayni tuzaga
// dusulmustu — kusur prod'a o yuzden cikti). Olculebilecek tek sey,
// kenar cubugu agacinda HANGI TOKEN'IN yazildigidir.
//
// ===========================================================================
// KAPSAM
// ===========================================================================
// Yalniz kenar cubugu agaci: `SidebarBody` ve altindaki `MenuSatiri` /
// `Bolum` ile site karti. `AppShell`in geri kalani (ust cubuk, icerik,
// altbilgi) ACIK yuzeydir ve icerik tokenlarini KULLANMALIDIR.
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

const KOK = join(__dirname, "..");
const SHELL = readFileSync(join(KOK, "components", "AppShell.tsx"), "utf8");
const KART = readFileSync(join(KOK, "components", "TesisKarti.tsx"), "utf8");

/** Lacivert zeminde OKUNMAYAN icerik tokenlari. */
const YASAK = ["--yz-text", "--yz-text-2", "--yz-text-3", "--yz-metal-1", "--yz-metal-2"];

/**
 * `SidebarBody` ile `MenuSatiri`/`Bolum`un kaynagi.
 *
 * `MenuSatiri` dosyada `SidebarBody`den ONCE tanimli, bu yuzden dilim
 * bastan alinir ve `AppShell` fonksiyonunda biter — yani kenar cubugunu
 * cizen her sey iceride, ust cubuk ve icerik disarida kalir.
 */
function kenarCubuguKaynagi(): string {
  const bas = SHELL.indexOf("function MenuSatiri(");
  const son = SHELL.indexOf("export function AppShell(");
  if (bas < 0 || son < 0 || son <= bas) throw new Error("dilim sinirlari bulunamadi");
  return SHELL.slice(bas, son);
}

describe("(P244 §2) kenar cubugu token disiplini", () => {
  const kaynak = kenarCubuguKaynagi();

  it("DILIM GERCEKTEN kenar cubugunu kapsiyor (vakum degil)", () => {
    expect(kaynak).toContain("--yz-sidebar-active");
    expect(kaynak).toContain("MenuSatiri");
    expect(kaynak.length).toBeGreaterThan(2000);
    // Ust cubuk BU DILIMDE OLMAMALI — yoksa tarama yanlis yeri olcer.
    expect(kaynak).not.toContain("<GlobalArama");
  });

  it("KENAR CUBUGU icerik metin/yuzey tokenlarini KULLANMAZ", () => {
    const ihlal: string[] = [];
    for (const tok of YASAK) {
      // `--yz-text-2` ararken `--yz-text`in de eslesmemesi icin tam sinir.
      const desen = new RegExp(`var\\(${tok}\\)`, "g");
      for (const e of kaynak.matchAll(desen)) {
        const satir = kaynak.slice(0, e.index).split("\n").length;
        ihlal.push(`${tok} (dilim satiri ${satir})`);
      }
    }
    expect(
      ihlal,
      `lacivert zeminde okunmayan token: ${ihlal.join(" · ")}`,
    ).toEqual([]);
  });

  it("SITE KARTI da yalniz kabuk tokenlarini kullanir (acilir menu haric)", () => {
    // Acilir menu BEYAZ bir yuzeydir ve icerik tokenlarini kullanmasi
    // DOGRUDUR; olculen sey karttaki (lacivert zeminli) kisim.
    const kart = KART.slice(0, KART.indexOf("const ortakSinif"));
    for (const tok of YASAK) {
      expect(kart, `site kartinda ${tok}`).not.toContain(`var(${tok})`);
    }
  });

  it("AKTIF OGE renk DISINDA da bir ipucu tasir", () => {
    // Olculdu: aktif dolgu lacivert uzerinde 2.97 — arayuz bileseni esigi
    // 3.0'in ALTINDA. Renk tek tasiyici olamaz.
    expect(kaynak).toContain("--yz-sidebar-marker");
    expect(kaynak).toContain('aria-current={aktif ? "page" : undefined}');
  });
});
