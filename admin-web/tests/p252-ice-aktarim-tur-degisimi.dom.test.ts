// @vitest-environment jsdom
// (P252 §4) ICE AKTARIM — `exhaustive-deps` uyarisinin OLCUMU.
//
// Sifirlama etkisi `[tur?.kod]`a bagli ve bu BILINCLI: `tur` nesnesine
// baglansaydi SWR'nin her yeniden dogrulamasi (sekme donusu) kullanicinin
// yazdigi tabloyu SILERDI. Ama tur ADRESTEN degistiginde (tarayicida geri,
// `?tur=` baglantisi) kolon ESLEMESI sifirlanmiyordu: sifirlama yalniz
// acilir listenin `onChange`indaydi. Eski turun alan kodlari yeni ture
// gonderiliyordu.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import Sayfa from "@/app/(protected)/ice-aktarim/page";

import { ciz } from "./yardimci";

const nav = vi.hoisted(() => ({ sorgu: "tur=daire" }));
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/ice-aktarim",
  useSearchParams: () => new URLSearchParams(nav.sorgu),
}));

const TURLER = [
  { kod: "daire", aciklama: "Daireler", alanlar: [
    { kod: "blok", zorunlu: true, ornek: "A" }, { kod: "no", zorunlu: true, ornek: "1" },
  ] },
  { kod: "kisi", aciklama: "Kişiler", alanlar: [
    { kod: "ad", zorunlu: true, ornek: "Ali" }, { kod: "eposta", zorunlu: true, ornek: "a@b.c" },
  ] },
];

type Cagri = { url: string; metot: string; govde: Record<string, unknown> };
function taklit(icerikDegisir = false): Cagri[] {
  const c: Cagri[] = [];
  let turCagrisi = 0;
  globalThis.fetch = (async (g: RequestInfo | URL, init?: RequestInit) => {
    const url = String(g);
    const metot = (init?.method ?? "GET").toUpperCase();
    c.push({ url, metot, govde: init?.body ? JSON.parse(String(init.body)) : {} });
    let govde: unknown = { items: [] };
    if (url.includes("ice-aktarim-turler")) {
      turCagrisi += 1;
      // Ikinci cagrida AYNI tur, DEGISMIS icerik (sunucu ornegi guncelledi).
      govde = icerikDegisir && turCagrisi > 1
        ? TURLER.map((t) => ({ ...t, aciklama: `${t.aciklama} (guncel)` }))
        : TURLER;
    }
    else if (metot === "POST") {
      govde = { satir_sayisi: 1, olusan: 0, atlanan: 0, guncellenen: 0, hatali: 0, hatalar: [],
        aktarim_id: null, uygulanmadi: true, davet_gonderildi: 0, davet_basarisiz: 0, davet_hatalari: [] };
    }
    return new Response(JSON.stringify(govde), { status: 200, headers: { "Content-Type": "application/json" } });
  }) as typeof fetch;
  return c;
}
afterEach(() => vi.restoreAllMocks());

it("tur ADRESTEN degisince eski kolon eslemesi YENI TURE gonderilmez", async () => {
  const k = userEvent.setup();
  const c = taklit();
  nav.sorgu = "tur=daire";
  ciz(Sayfa);
  await k.click(await screen.findByRole("button", { name: /Dosya/ }));
  await k.type(screen.getByLabelText(/^Veri/), "Blok;Ad;Eposta{enter}A;Ali;a@b.c");
  const kolon0 = await waitFor(() => {
    const s = document.querySelectorAll("select");
    const bulunan = Array.from(s).find((x) => Array.from(x.options).some((o) => o.value === "blok"));
    expect(bulunan).toBeTruthy();
    return bulunan as HTMLSelectElement;
  });
  await k.selectOptions(kolon0, "blok");

  // Tarayicida GERI: adres `?tur=kisi`. Yeniden cizim icin bir etkilesim.
  nav.sorgu = "tur=kisi";
  await k.click(screen.getByLabelText(/İlk satır başlık/));
  await k.click(screen.getByLabelText(/İlk satır başlık/));
  await waitFor(() =>
    expect(Array.from(document.querySelectorAll("option")).some((o) => o.value === "eposta")).toBe(true),
  );
  // Yeni turun zorunlulari 1. ve 2. kolona eslenir; 0. kolona DOKUNULMAZ.
  const secimler = Array.from(document.querySelectorAll("select")).filter((x) =>
    Array.from(x.options).some((o) => o.value === "eposta"));
  await k.selectOptions(secimler[1], "ad");
  await k.selectOptions(secimler[2], "eposta");
  await k.click(Array.from(document.querySelectorAll("button")).find((b) => /Önizle/.test(b.textContent ?? ""))!);
  await waitFor(() => expect(c.some((x) => x.metot === "POST")).toBe(true));
  const govde = c.find((x) => x.metot === "POST")!.govde as { satirlar: { degerler: Record<string, string> }[] };
  // Eski turun alani (`blok`) kisi aktarimina SIZMAZ.
  expect(govde.satirlar.every((s) => !("blok" in s.degerler))).toBe(true);
});

it("tur AYNI, ICERIGI degisti (yeniden dogrulama): yazilan tablo SILINMEZ (bagimlilik `tur?.kod`)", async () => {
  const k = userEvent.setup();
  const c = taklit(true);
  nav.sorgu = "tur=daire";
  ciz(Sayfa);
  const hucre = await waitFor(() => {
    const h = document.querySelector('[data-test="aktarim-hucre-0-blok"]') as HTMLInputElement | null;
    expect(h).toBeTruthy();
    return h!;
  });
  await k.type(hucre, "A");
  const once = c.filter((x) => x.url.includes("ice-aktarim-turler")).length;
  // Sekme donusu: SWR turleri yeniden ceker; icerik farkli -> YENI nesne,
  // ayni kod. (Icerik ayniysa SWR eski nesneyi korur.)
  window.dispatchEvent(new Event("focus"));
  document.dispatchEvent(new Event("visibilitychange"));
  await waitFor(() =>
    expect(c.filter((x) => x.url.includes("ice-aktarim-turler")).length).toBeGreaterThan(once),
  );
  expect((document.querySelector('[data-test="aktarim-hucre-0-blok"]') as HTMLInputElement).value).toBe("A");
});
