// @vitest-environment jsdom
// (P217 §4) DAIRE ATAMA: DOLU DAIRELER GIZLENMEZ, ISARETLENIR.
//
// ===========================================================================
// KARAR ve GEREKCESI
// ===========================================================================
// Sikayet: "zaten baskasina atanmis daireler listede gorunuyor,
// gorunmesin". GIZLEMEK YANLIS olurdu: bir dairede BIRDEN COK sakin
// mesrudur — esler, aile, ve malik + kiraci bir arada. `unit_resident`
// tablosunda tekillik kisiti YOK ve `rol_tipi` (malik|kiraci) tam bunun
// icin var. Gizleseydik ikinci sakini eklemek IMKANSIZ olurdu.
//
// Ama sikayetin isaret ettigi sorun gercek: 200 daire arasinda BOS
// olani bulmak zor. Cozum iki parcali: bos daireler ONCE siralanir,
// dolu olanin yaninda KAC SAKIN oldugu yazar.
//
// TAKLIT HTTP KATMANINDA (P200).
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import UsersPage from "@/app/(protected)/users/page";

import { ciz } from "./yardimci";

const DAIRELER = [
  { id: "u1", no: "A-1", blok: null, aktif: true, sakin_sayisi: 2 },
  { id: "u2", no: "A-2", blok: null, aktif: true, sakin_sayisi: 0 },
  { id: "u3", no: "A-3", blok: null, aktif: true, sakin_sayisi: 1 },
  { id: "u4", no: "A-4", blok: null, aktif: true, sakin_sayisi: 0 },
];

function sunucu() {
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    const url = String(girdi);
    const govde = url.includes("/api/units")
      ? { meta: { limit: 1000, offset: 0, total: DAIRELER.length }, items: DAIRELER }
      // ROL LISTESI SUNUCUDAN gelir (P130): `acilabilir-roller`
      // donmezse form rol secenegi HIC cizmiyor ve daire alanina da
      // ulasilamiyor — ilk yazimda testi dusuren sey buydu.
      : url.includes("acilabilir-roller")
        ? { roller: ["resident", "yonetici", "security"] }
        : { meta: { limit: 20, offset: 0, total: 0 }, items: [] };
    return new Response(JSON.stringify(govde), {
      status: 200, headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

/** Kullanici ekleme modalini acar ve daire secicisini doner. */
async function daireSecici(): Promise<HTMLSelectElement> {
  const k = userEvent.setup();
  await k.click(await screen.findByRole("button", { name: /yeni kullanıcı|\+ yeni/i }));
  const modal = await screen.findByRole("dialog");
  // Rol "sakin" secilmeden daire alani cizilmiyor.
  const secimler = within(modal).getAllByRole("combobox");
  const rol = secimler.find((sc) =>
    Array.from(sc.querySelectorAll("option")).some((o) => o.value === "resident"));
  expect(rol, "rol seçimi bulunamadı").toBeTruthy();
  await k.selectOptions(rol!, "resident");
  return await waitFor(() => {
    const hepsi = within(modal).getAllByRole("combobox") as HTMLSelectElement[];
    const daire = hepsi.find((sc) =>
      Array.from(sc.querySelectorAll("option")).some((o) => o.value === "u1"));
    expect(daire, "daire seçimi bulunamadı").toBeTruthy();
    return daire!;
  });
}

describe("(P217 §4) daire atama listesi", () => {
  it("DOLU daireler LISTEDE KALIR (ikinci sakin eklenebilsin)", async () => {
    sunucu();
    ciz(UsersPage);
    const secici = await daireSecici();
    const degerler = Array.from(secici.options).map((o) => o.value);
    // Dolu olan A-1 ve A-3 de secilebilir olmali.
    expect(degerler).toContain("u1");
    expect(degerler).toContain("u3");
  });

  it("DOLU daire KAC SAKIN oldugunu YAZAR", async () => {
    sunucu();
    ciz(UsersPage);
    const secici = await daireSecici();
    const a1 = Array.from(secici.options).find((o) => o.value === "u1");
    expect(a1?.textContent).toMatch(/2 sakin/i);
    // BOS dairede isaret YOK — kalabalik yapmasin.
    const a2 = Array.from(secici.options).find((o) => o.value === "u2");
    expect(a2?.textContent ?? "").not.toMatch(/sakin/i);
  });

  it("BOS daireler ONCE siralanir", async () => {
    sunucu();
    ciz(UsersPage);
    const secici = await daireSecici();
    // Ilk secenek "daire yok" (bos deger); ondan sonrakiler sirali.
    const daireler = Array.from(secici.options)
      .filter((o) => o.value)
      .map((o) => o.value);
    const bosIndeks = daireler.findIndex((d) => d === "u2");
    const doluIndeks = daireler.findIndex((d) => d === "u1");
    expect(bosIndeks).toBeLessThan(doluIndeks);
    // Ikinci bos daire de dolulardan once.
    expect(daireler.findIndex((d) => d === "u4")).toBeLessThan(doluIndeks);
  });

  it("BOS/DOLU ayrimi disinda SIRA KORUNUR (kararli siralama)", async () => {
    sunucu();
    ciz(UsersPage);
    const secici = await daireSecici();
    const daireler = Array.from(secici.options).filter((o) => o.value).map((o) => o.value);
    // Bos olanlar kendi aralarinda gelis sirasinda: u2, u4
    expect(daireler.indexOf("u2")).toBeLessThan(daireler.indexOf("u4"));
    // Dolular da: u1, u3
    expect(daireler.indexOf("u1")).toBeLessThan(daireler.indexOf("u3"));
  });
});
