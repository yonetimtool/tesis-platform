// @vitest-environment jsdom
// (P203 §4) VARDIYA PLANI EKRANI — haftalik izgara, bos slot, atama.
//
// Olculen sey EKRANIN DAVRANISI + GIDEN GOVDE. Kurallarin kendisi
// sunucuda kilitli (backend test_p203_vardiya_*); burada olculen,
// arayuzun dogru ucu dogru govdeyle cagirdigi ve BOS VARDIYAYI
// GORUNUR kildigi (istegin acik sarti).
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import Sayfa from "@/app/(protected)/vardiya-plani/page";
import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz } from "./yardimci";

type Cagri = { url: string; metot: string; govde: Record<string, unknown> };

const GUNDUZ = {
  shift_id: "s-1",
  shift_ad: "Gunduz",
  baslangic_saat: "08:00:00",
  bitis_saat: "16:00:00",
  kisiler: [{ plan_id: "p-1", user_id: "u-1", ad: "Ali Guvenlik", rol: "security" }],
  bos: false,
};
const GECE_BOS = {
  shift_id: "s-2",
  shift_ad: "Gece",
  baslangic_saat: "20:00:00",
  bitis_saat: "08:00:00",
  kisiler: [],
  bos: true,
};

function taklit(opts: { atamaUyari?: string[] } = {}): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const metot = (init?.method ?? "GET").toUpperCase();
    cagrilar.push({
      url,
      metot,
      govde: init?.body ? JSON.parse(String(init.body)) : {},
    });
    let govde: unknown = { ok: true };
    if (url.startsWith("/api/vardiya-plani?")) {
      govde = {
        baslangic: "2026-08-31",
        bitis: "2026-09-06",
        gunler: [
          { tarih: "2026-08-31", slotlar: [GUNDUZ, GECE_BOS] },
          { tarih: "2026-09-01", slotlar: [GECE_BOS] },
        ],
      };
    } else if (url.includes("/vardiya-plani/simdi")) {
      govde = {
        zaman: "2026-09-02T10:00:00",
        gorevdeki_vardiya: GUNDUZ,
        gorevdekiler: GUNDUZ.kisiler,
        sonraki_vardiya: GECE_BOS,
        sonrakiler: [{ plan_id: "p-9", user_id: "u-9", ad: "Veli Gece", rol: "security" }],
        sonraki_baslangic: "2026-09-02T20:00:00",
      };
    } else if (url.startsWith("/api/users")) {
      govde = {
        items: [
          { id: "u-2", ad: "Yeni Personel", role: "security" },
          { id: "u-3", ad: "Sakin Kisi", role: "resident" },
        ],
      };
    } else if (metot === "POST" && url === "/api/vardiya-plani") {
      govde = { id: "p-2", uyarilar: opts.atamaUyari ?? [] };
    }
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

const kanca = (ad: string) =>
  document.querySelector(`[data-test="${ad}"]`) as HTMLElement | null;

afterEach(() => vi.restoreAllMocks());

it("HAFTALIK IZGARA cizilir ve BOS VARDIYA acikca isaretlenir", async () => {
  // Istegin acik sarti. Bos slot LISTEDE HIC GORUNMEYEN seydir; tablo
  // olmadan yonetici onu goz taramasiyla bulamazdi.
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-slot-2026-08-31-s-1")).toBeTruthy());
  expect(kanca("vardiya-slot-2026-08-31-s-2")).toBeTruthy();
  expect(kanca("vardiya-slot-2026-08-31-s-1")!.textContent).toContain("Ali Guvenlik");
  expect(kanca("vardiya-slot-2026-08-31-s-2")!.textContent).toContain(tr.vardiyaBos);
  // Bos sayisi ROZETTE toplanir: yonetici tabloyu taramadan once
  // "eksik var mi" sorusunu yanitlayabilmeli.
  expect(screen.getByText("2 vardiya boş")).toBeTruthy();
});

it("ANLIK DURUM: su an gorevde + siradaki", async () => {
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-simdi-gorevde")).toBeTruthy());
  expect(kanca("vardiya-simdi-gorevde")!.textContent).toContain("Ali Guvenlik");
  expect(kanca("vardiya-simdi-sonraki")!.textContent).toContain("Veli Gece");
});

it("SLOTA TIKLAYINCA kim atanmis gorunur", async () => {
  const k = userEvent.setup();
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-slot-2026-08-31-s-1")).toBeTruthy());
  await k.click(kanca("vardiya-slot-2026-08-31-s-1")!);
  await waitFor(() => expect(kanca("vardiya-slot-kisiler")).toBeTruthy());
  expect(kanca("vardiya-slot-kisiler")!.textContent).toContain("Ali Guvenlik");
});

it("ATAMA dogru uca, DOGRU GOVDEYLE gider", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-slot-2026-08-31-s-2")).toBeTruthy());
  await k.click(kanca("vardiya-slot-2026-08-31-s-2")!);
  await waitFor(() => expect(kanca("vardiya-kisi-sec")).toBeTruthy());
  await k.selectOptions(kanca("vardiya-kisi-sec")!, "u-2");

  await waitFor(() =>
    expect(cagrilar.some((c) => c.metot === "POST" && c.url === "/api/vardiya-plani"))
      .toBe(true),
  );
  const post = cagrilar.find((c) => c.metot === "POST" && c.url === "/api/vardiya-plani")!;
  expect(post.govde).toEqual({
    shift_id: "s-2",
    tarih: "2026-08-31",
    user_id: "u-2",
  });
});

it("SAKIN atanabilir listede YOK", async () => {
  // Vardiya personele atanir; sakini listelemek yoneticiye anlamsiz
  // bir secenek sunup yanlislikla secmesine zemin hazirlardi.
  const k = userEvent.setup();
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-slot-2026-08-31-s-2")).toBeTruthy());
  await k.click(kanca("vardiya-slot-2026-08-31-s-2")!);
  await waitFor(() => expect(kanca("vardiya-kisi-sec")).toBeTruthy());
  const secim = kanca("vardiya-kisi-sec") as HTMLSelectElement;
  const adlar = Array.from(secim.options).map((o) => o.textContent);
  expect(adlar).toContain("Yeni Personel");
  expect(adlar).not.toContain("Sakin Kisi");
});

it("HAFTALIK SINIR UYARISI kullaniciya GOSTERILIR", async () => {
  // Uyari sessiz gecerse ozellik anlamsizlasir: 45 saat asimi bir
  // MALIYETTIR (§5 onu gidere yaziyor) ve yonetici atamayi YAPARKEN
  // gormeli.
  const k = userEvent.setup();
  taklit({ atamaUyari: ["haftalik_normal_asildi"] });
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-slot-2026-08-31-s-2")).toBeTruthy());
  await k.click(kanca("vardiya-slot-2026-08-31-s-2")!);
  await waitFor(() => expect(kanca("vardiya-kisi-sec")).toBeTruthy());
  await k.selectOptions(kanca("vardiya-kisi-sec")!, "u-2");
  expect(await screen.findByText(tr.vardiyaUyariHaftalik)).toBeTruthy();
});

it("HAFTA GEZINME sunucudan YENI ARALIK ister", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-hafta-araligi")).toBeTruthy());
  const ilk = kanca("vardiya-hafta-araligi")!.textContent;
  await k.click(kanca("vardiya-sonraki-hafta")!);
  await waitFor(() =>
    expect(kanca("vardiya-hafta-araligi")!.textContent).not.toBe(ilk),
  );
  // Yeni aralik icin YENI istek atildi (istemcide dilimlenmedi).
  const araliklar = new Set(
    cagrilar.filter((c) => c.url.startsWith("/api/vardiya-plani?")).map((c) => c.url),
  );
  expect(araliklar.size).toBeGreaterThan(1);
});
