// @vitest-environment jsdom
// (P251 §6) ICE AKTARIM — 1'den baslayan satir (istek govdesinde de),
// rol icin acilir liste, yapistirilan Turkce rol metni koda cevrilir,
// telefon sutunu ortak bilesenle.
import { waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import Sayfa from "@/app/(protected)/ice-aktarim/page";
import { rolTipiNormalle } from "@/lib/ice-aktarim-alanlari";

import { ciz } from "./yardimci";

type Cagri = { url: string; metot: string; govde: Record<string, unknown> };
const TURLER = [
  {
    // Varsayilan tur "daire" (sayfa adresten okur); sutunlar testin.
    kod: "daire",
    aciklama: "Daireler ve sakinler",
    alanlar: [
      { kod: "ad", zorunlu: true, ornek: "Ali" },
      { kod: "soyad", zorunlu: true, ornek: "VELİ" },
      { kod: "eposta", zorunlu: true, ornek: "ali@ornek.com" },
      { kod: "telefon", zorunlu: false, ornek: "+905321112233" },
      { kod: "rol_tipi", zorunlu: false, ornek: "malik | kiraci | malik_oturan" },
    ],
  },
];

function taklit(): Cagri[] {
  const c: Cagri[] = [];
  globalThis.fetch = (async (g: RequestInfo | URL, init?: RequestInit) => {
    const url = String(g);
    const metot = (init?.method ?? "GET").toUpperCase();
    c.push({ url, metot, govde: init?.body ? JSON.parse(String(init.body)) : {} });
    let govde: unknown = { ok: true };
    if (url.includes("ice-aktarim-turler")) govde = TURLER;
    else if (url.includes("/api/panel/ice-aktarim?")) govde = { items: [] };
    else if (metot === "POST") {
      govde = { satir_sayisi: 1, olusan: 1, atlanan: 0, guncellenen: 0, hatali: 0, hatalar: [],
        aktarim_id: null, uygulanmadi: true, davet_gonderildi: 0, davet_basarisiz: 0, davet_hatalari: [] };
    }
    return new Response(JSON.stringify(govde), { status: 200, headers: { "Content-Type": "application/json" } });
  }) as typeof fetch;
  return c;
}
const kanca = (ad: string) => document.querySelector(`[data-test="${ad}"]`) as HTMLElement | null;
afterEach(() => vi.restoreAllMocks());

it("rol ACILIR LISTE; yapistirilan 'Kiracı' koda cevrilir; govdede satir_no 1", async () => {
  const k = userEvent.setup();
  const c = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("aktarim-hucre-0-ad")).toBeTruthy());
  const rol = kanca("aktarim-hucre-0-rol_tipi") as HTMLSelectElement;
  expect(rol.tagName).toBe("SELECT");
  expect(Array.from(rol.options).map((o) => o.textContent)).toEqual(["—", "Malik", "Kiracı", "Malik (oturuyor)"]);
  // Telefon sutunu ortak bilesenle (P248): ulke kodu ayri secilir.
  expect(kanca("aktarim-hucre-0-telefon")).toBeTruthy();

  await k.click(kanca("aktarim-hucre-0-ad")!);
  await k.paste("Ali\tVeli\tali@ornek.com");
  await k.selectOptions(rol, "kiraci");
  // Ikinci satira yapistirma: rol metni Turkce.
  await k.click(kanca("aktarim-hucre-1-ad")!);
  await k.paste("Ayşe\tKaya\tayse@ornek.com\t\tKiracı");
  expect((kanca("aktarim-hucre-1-rol_tipi") as HTMLSelectElement).value).toBe("kiraci");

  await k.click(Array.from(document.querySelectorAll("button")).find((b) => /Önizle/.test(b.textContent ?? ""))!);
  await waitFor(() => expect(c.some((x) => x.metot === "POST")).toBe(true));
  const govde = c.find((x) => x.metot === "POST")!.govde as { satirlar: { satir_no: number; degerler: Record<string, string> }[] };
  expect(govde.satirlar.map((s) => s.satir_no)).toEqual([1, 2]);
  expect(govde.satirlar[0].degerler.rol_tipi).toBe("kiraci");
  expect(govde.satirlar[1].degerler.rol_tipi).toBe("kiraci");
});

it("rol normallestirme: Turkce ve tireli yazimlar; taninmayan ham kalir", () => {
  expect(rolTipiNormalle("Kiracı")).toBe("kiraci");
  expect(rolTipiNormalle("KİRACI")).toBe("kiraci");
  expect(rolTipiNormalle("Malik-Oturan")).toBe("malik_oturan");
  expect(rolTipiNormalle("malik ve oturan")).toBe("malik_oturan");
  expect(rolTipiNormalle(" komşu ")).toBe("komşu");
});
