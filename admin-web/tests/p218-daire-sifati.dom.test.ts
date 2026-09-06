// @vitest-environment jsdom
// (P218) DAIREDEKI SIFAT — TEK ALAN, UC SECENEK, IKI ALANA YAZILIR.
//
// ===========================================================================
// NE COZULDU
// ===========================================================================
// Kullanici ekleme ekrani daire atarken rol HIC SORMUYORDU: bag ROLSUZ
// doguyor, borc hedefleme onu "belirsiz" torbasina koyuyor ve KMK md. 20
// ayrimi o kisiler icin calismiyordu (olculdu).
//
// Ayrica "malik ve oturan" hicbir yuzeyde temsil edilemiyordu.
//
// ARAYUZDE TEK ALAN, VERIDE IKI: yoneticinin kafasindaki soru tektir
// ("bu kisi buranin nesi?"); iki ayri kutu dort kombinasyon uretir ve
// biri anlamsizdir (malik degil + oturmuyor).
//
// TAKLIT HTTP KATMANINDA (P200): `fetch` sahteleniyor, gonderilen GOVDE
// okunuyor.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import UsersPage from "@/app/(protected)/users/page";

import { ciz } from "./yardimci";

const DAIRELER = [
  { id: "u1", no: "A-1", blok: null, aktif: true, sakin_sayisi: 0 },
];

/** Gonderilen yazma isteklerini toplayan sahte sunucu. */
function sunucu() {
  const yazmalar: { yol: string; govde: unknown }[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const metot = (init?.method ?? "GET").toUpperCase();
    if (metot !== "GET") {
      yazmalar.push({
        yol: url,
        govde: init?.body ? JSON.parse(String(init.body)) : null,
      });
      return new Response(JSON.stringify({ id: "yeni-kisi" }), {
        status: 201, headers: { "Content-Type": "application/json" },
      });
    }
    const govde = url.includes("/api/units")
      ? { meta: { limit: 1000, offset: 0, total: 1 }, items: DAIRELER }
      : url.includes("acilabilir-roller")
        ? { roller: ["resident", "yonetici"] }
        : { meta: { limit: 20, offset: 0, total: 0 }, items: [] };
    return new Response(JSON.stringify(govde), {
      status: 200, headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return yazmalar;
}

afterEach(() => vi.restoreAllMocks());

/** Formu doldurur; [sifat] verilirse sıfat seçilir. */
async function kullaniciEkle(sifat?: string) {
  const yazmalar = sunucu();
  ciz(UsersPage);
  const k = userEvent.setup();
  await k.click(await screen.findByRole("button", { name: /yeni kullanıcı|\+ yeni/i }));
  const modal = await screen.findByRole("dialog");
  const ic = within(modal);

  const secimler = ic.getAllByRole("combobox");
  const rol = secimler.find((sc) =>
    Array.from(sc.querySelectorAll("option")).some((o) => o.value === "resident"));
  await k.selectOptions(rol!, "resident");

  await k.type(ic.getAllByRole("textbox")[0], "Test Kişi");
  const eposta = ic.getAllByRole("textbox").find((a) => a.getAttribute("type") === "email")
    ?? ic.getAllByRole("textbox")[1];
  await k.type(eposta, "p218@ornek.com");

  const daire = await waitFor(() => {
    const hepsi = ic.getAllByRole("combobox") as HTMLSelectElement[];
    const d = hepsi.find((sc) =>
      Array.from(sc.querySelectorAll("option")).some((o) => o.value === "u1"));
    expect(d).toBeTruthy();
    return d!;
  });
  await k.selectOptions(daire, "u1");

  if (sifat) {
    const alan = await waitFor(() => {
      const a = modal.querySelector('[data-test="kullanici-daire-sifati"]');
      expect(a).not.toBeNull();
      return a as HTMLSelectElement;
    });
    await k.selectOptions(alan, sifat);
  }
  return { yazmalar, modal, k };
}

describe("(P218) dairedeki sıfat alanı", () => {
  it("DAIRE SECILINCE gorunur, secilmeden GORUNMEZ", async () => {
    const yazmalar = sunucu();
    ciz(UsersPage);
    const k = userEvent.setup();
    await k.click(await screen.findByRole("button", { name: /yeni kullanıcı|\+ yeni/i }));
    const modal = await screen.findByRole("dialog");
    const rol = within(modal).getAllByRole("combobox").find((sc) =>
      Array.from(sc.querySelectorAll("option")).some((o) => o.value === "resident"));
    await k.selectOptions(rol!, "resident");
    // Daire SECILMEDEN sifat alani YOK.
    expect(modal.querySelector('[data-test="kullanici-daire-sifati"]')).toBeNull();
    expect(yazmalar).toEqual([]);
  });

  it("UC SECENEK sunar", async () => {
    const { modal } = await kullaniciEkle();
    const alan = await waitFor(() => {
      const a = modal.querySelector('[data-test="kullanici-daire-sifati"]');
      expect(a).not.toBeNull();
      return a as HTMLSelectElement;
    });
    const degerler = Array.from(alan.options).map((o) => o.value).filter(Boolean);
    expect(degerler).toEqual(["malik", "kiraci", "malik_oturan"]);
  });

  it("VARSAYILAN SECILI DEGIL — yanlış varsayılan sessizce yanlış veri üretir", async () => {
    const { modal } = await kullaniciEkle();
    const alan = modal.querySelector('[data-test="kullanici-daire-sifati"]') as HTMLSelectElement;
    expect(alan.value).toBe("");
  });
});

describe("(P218) sıfat İKİ ALANA yazılır", () => {
  async function govdeAl(sifat: string) {
    const { yazmalar, modal, k } = await kullaniciEkle(sifat);
    await k.click(within(modal).getByRole("button", { name: /^kaydet$/i }));
    await waitFor(() =>
      expect(yazmalar.some((y) => y.yol.includes("/residents"))).toBe(true),
    );
    return yazmalar.find((y) => y.yol.includes("/residents"))!.govde as Record<string, unknown>;
  }

  it("MALIK (oturmuyor) -> rol_tipi=malik, oturuyor=false", async () => {
    expect(await govdeAl("malik")).toMatchObject({ rol_tipi: "malik", oturuyor: false });
  });

  it("KIRACI -> rol_tipi=kiraci, oturuyor=true", async () => {
    expect(await govdeAl("kiraci")).toMatchObject({ rol_tipi: "kiraci", oturuyor: true });
  });

  it("MALIK VE OTURAN -> rol_tipi=malik, oturuyor=TRUE (üçüncü durum)", async () => {
    // Eskiden temsil EDILEMEYEN durum: rol malik ama kullanan da o.
    expect(await govdeAl("malik_oturan")).toMatchObject({
      rol_tipi: "malik", oturuyor: true,
    });
  });
});
