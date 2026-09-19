// (P241 §2e) BILDIRIM YONLENDIRME — IKI YUZEYIN HARITASI AYNI OLMALI.
//
// ===========================================================================
// NEDEN BOYLE BIR KILIT
// ===========================================================================
// P240'ta uc yeni bildirim ailesi eklendi ve mobil yonlendirme beyaz
// listesi GUNCELLENMEDI: panik push'una dokunan kullanici alarm ekranina
// gitmiyordu. Kaynak testleri goremedi cunku "bilinmeyen tipe `null`
// donmek" tasarimin kendisidir — yani kusur, calisan koddan ayirt
// EDILEMEZ.
//
// Bu kilit, kusuru YAPISAL olarak yakalar: sunucunun bildigi her tip
// (`enum-adlari`) ya IKI yuzeyde de bir hedefe baglanir ya da IKISINDE
// DE baglanmaz. Biri eklenip oteki unutulursa test duser.
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { expect, it } from "vitest";

import { BILDIRIM_ROTALARI } from "@/lib/bildirim-rotasi";
import { BILDIRIM_TIP } from "@/lib/enum-adlari";

/** Mobil haritadan tip adlarini oku — tek kaynak dosyanin KENDISI. */
function mobilTipler(): Set<string> {
  const yol = join(
    process.cwd(),
    "..",
    "mobile",
    "lib",
    "src",
    "features",
    "notifications",
    "presentation",
    "bildirim_rotasi.dart",
  );
  const kaynak = readFileSync(yol, "utf8");
  // `switch (b.tip)` govdesindeki tirnakli degerler.
  const govde = kaynak.slice(
    kaynak.indexOf("switch (b.tip)"),
    kaynak.indexOf("_ => null,"),
  );
  return new Set([...govde.matchAll(/'([a-z_]+)'/g)].map((m) => m[1]));
}

it("BOSA GECME MUHAFIZI: iki harita da dolu okundu", () => {
  expect(Object.keys(BILDIRIM_ROTALARI).length).toBeGreaterThan(10);
  expect(mobilTipler().size).toBeGreaterThan(10);
});

it("WEB ve MOBIL yonlendirme haritalari AYNI tipleri tasir", () => {
  const web = new Set(Object.keys(BILDIRIM_ROTALARI));
  const mobil = mobilTipler();
  const webFazlasi = [...web].filter((t) => !mobil.has(t)).sort();
  const mobilFazlasi = [...mobil].filter((t) => !web.has(t)).sort();
  expect(
    { webFazlasi, mobilFazlasi },
    "bir yuzeye eklenen tip otekine de eklenmeli",
  ).toEqual({ webFazlasi: [], mobilFazlasi: [] });
});

it("HARITADAKI HER TIP sunucunun bildigi bir tiptir", () => {
  // Olmayan bir tipe hedef yazmak, hic calismayacak bir satir birakmak
  // ve haritaya bakan bir sonraki kisiyi yaniltmak olurdu.
  const bilinen = new Set(Object.keys(BILDIRIM_TIP));
  const tanimsiz = Object.keys(BILDIRIM_ROTALARI)
    .filter((t) => !bilinen.has(t))
    .sort();
  expect(tanimsiz, "sunucuda olmayan bildirim tipi").toEqual([]);
});

it("(P241 §2e) VARDIYA YAYINI ve BAKIM haritada", () => {
  expect(BILDIRIM_ROTALARI.vardiya_yayinlandi).toBe("/vardiya-plani");
  expect(BILDIRIM_ROTALARI.bakim_gecikti).toBe("/bakim");
});
