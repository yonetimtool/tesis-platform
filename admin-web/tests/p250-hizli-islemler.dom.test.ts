// @vitest-environment jsdom
// (P250 §6) HIZLI ISLEMLER — kullanici secer/siralar, secenekler role gore.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement } from "react";
import { afterEach, expect, it, vi } from "vitest";

import { HizliIslemlerKarti } from "@/components/HizliIslemlerKarti";
import { sirayiTasi } from "@/lib/hizli-islemler";
import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz } from "./yardimci";

afterEach(() => vi.restoreAllMocks());

function taklit(veri: { secenekler: string[]; secili: string[]; varsayilan: string[]; ozel: boolean }) {
  const c: { metot: string; govde: unknown }[] = [];
  globalThis.fetch = (async (_g: RequestInfo | URL, init?: RequestInit) => {
    const metot = (init?.method ?? "GET").toUpperCase();
    const govde = init?.body ? JSON.parse(String(init.body)) : null;
    c.push({ metot, govde });
    const yanit = metot === "PUT"
      ? { ...veri, secili: (govde as { secili: string[] | null }).secili ?? veri.varsayilan, ozel: (govde as { secili: unknown }).secili !== null }
      : veri;
    return new Response(JSON.stringify(yanit), { status: 200, headers: { "Content-Type": "application/json" } });
  }) as typeof fetch;
  return c;
}

const kanca = (ad: string) => document.querySelector(`[data-test="${ad}"]`) as HTMLElement | null;

function ac() {
  ciz(() => createElement(HizliIslemlerKarti, { baslik: "Hizli" }));
}

it("secili islemler SIRAYLA cizilir", async () => {
  taklit({ secenekler: ["aidat", "talep", "kurulum"], secili: ["kurulum", "aidat"], varsayilan: ["aidat", "talep"], ozel: true });
  ac();
  await waitFor(() => expect(kanca("hizli-kurulum")).toBeTruthy());
  const sira = [...kanca("hizli-islemler")!.querySelectorAll("a")].map((a) => a.getAttribute("href"));
  expect(sira).toEqual(["/kurulum", "/dues"]);
});

it("secenekler ROLE gore: sunucunun vermedigi islem listede YOK", async () => {
  const k = userEvent.setup();
  taklit({ secenekler: ["anket"], secili: [], varsayilan: [], ozel: false });
  ac();
  await waitFor(() => expect(screen.getByText(tr.panoHizliBos)).toBeTruthy());
  await k.click(kanca("hizli-ozellestir")!);
  const liste = within(kanca("hizli-secenekler")!);
  expect(liste.getAllByRole("checkbox")).toHaveLength(1);
  expect(liste.getByText(tr.panoHizliAnket)).toBeTruthy();
});

it("sec, sirala, kaydet: govdede SIRALI secim; varsayilana don = null", async () => {
  const k = userEvent.setup();
  const c = taklit({ secenekler: ["aidat", "talep", "duyuru", "kurulum"], secili: ["aidat", "talep"], varsayilan: ["aidat", "talep"], ozel: false });
  ac();
  await waitFor(() => expect(kanca("hizli-aidat")).toBeTruthy());
  await k.click(kanca("hizli-ozellestir")!);
  await k.click(within(kanca("hizli-secenek-kurulum")!).getByRole("checkbox"));
  await k.click(within(kanca("hizli-secenek-talep")!).getByRole("checkbox"));
  await k.click(screen.getByRole("button", { name: tr.panoHizliYukari.replace("{ad}", tr.panoHizliKurulum) }));
  await k.click(kanca("hizli-kaydet")!);
  await waitFor(() => expect(c.some((x) => x.metot === "PUT")).toBe(true));
  expect(c.find((x) => x.metot === "PUT")!.govde).toEqual({ secili: ["kurulum", "aidat"] });

  await k.click(kanca("hizli-ozellestir")!);
  await k.click(kanca("hizli-varsayilan")!);
  await waitFor(() => expect(c.filter((x) => x.metot === "PUT")).toHaveLength(2));
  expect(c.filter((x) => x.metot === "PUT")[1].govde).toEqual({ secili: null });
});

it("sirayiTasi saf", () => {
  expect(sirayiTasi(["a", "b", "c"], "c", -1)).toEqual(["a", "c", "b"]);
  expect(sirayiTasi(["a", "b"], "a", -1)).toEqual(["a", "b"]);
});
