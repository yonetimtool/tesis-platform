// @vitest-environment jsdom
// (P251 §8) MENU PARITESIYLE GELEN WEB EKRANLARI — davranis kilitleri.
//
//   * Kisiler: tek giris, dort sekme; adresteki sekme acilir; Personel
//     sekmesi uc saha rolunu TEK istekte ister; eski `/users?rol=..`
//     dogru sekmeye yonlenir.
//   * (Maas karti eylemi P252'de "Calisma bilgileri" penceresine
//     donustu: `p252-calisma-bilgileri.dom.test.ts`.)
//   * Goruntuleme izni (web'e yeni): tek daire istegi `unit_id` ile gider;
//     onayli dairede kayit TEK OKUMADA (onaydan sonra) istenir.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import GoruntulemeIzniPage from "@/app/(protected)/goruntuleme-izni/page";
import MaasKartlariPage from "@/app/(protected)/finans/maas-kartlari/page";
import KisilerPage from "@/app/(protected)/kisiler/page";
import { rolunSekmesi } from "@/lib/kisiler";

import { ciz } from "./yardimci";

const nav = vi.hoisted(() => ({ sorgu: "", push: vi.fn(), replace: vi.fn() }));
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: nav.push, replace: nav.replace, refresh: vi.fn() }),
  usePathname: () => "/kisiler",
  useSearchParams: () => new URLSearchParams(nav.sorgu),
}));

type Cagri = { url: string; method: string; body: unknown };
let cagrilar: Cagri[] = [];

function sahte(harita: Record<string, unknown>) {
  cagrilar = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const method = init?.method ?? "GET";
    cagrilar.push({ url, method, body: init?.body ? JSON.parse(String(init.body)) : undefined });
    const anahtar = Object.keys(harita)
      .filter((k) => {
        const [m, yol] = k.includes(" ") ? k.split(" ") : ["GET", k];
        return m === method && url.startsWith(yol);
      })
      .sort((a, b) => b.length - a.length)[0];
    const govde = anahtar ? harita[anahtar] : { error: { message: "yok" } };
    return new Response(JSON.stringify(govde), {
      status: anahtar ? 200 : 404,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
}

const BOS_LISTE = { meta: { total: 0, limit: 50, offset: 0 }, items: [] };

beforeEach(() => {
  nav.sorgu = "";
  nav.push.mockReset();
  nav.replace.mockReset();
});
afterEach(() => vi.restoreAllMocks());

describe("(P251 §8) Kisiler", () => {
  it("dort sekme; adresteki sekme ACIK; Personel uc saha rolunu tek istekte ister", async () => {
    nav.sorgu = "sekme=personel";
    sahte({
      "/api/users/acilabilir-roller": { roller: ["security", "tesis_gorevlisi", "resident"] },
      "/api/users": BOS_LISTE,
      "/api/tanimlar/personel-kayitlari": { items: [] },
    });
    ciz(KisilerPage);
    const sekmeler = await screen.findAllByRole("tab");
    expect(sekmeler.map((s) => s.textContent)).toEqual([
      "Sakinler",
      "Personel",
      "Yöneticiler ve denetçiler",
      "Davetler",
    ]);
    expect(screen.getByRole("tab", { name: "Personel" })).toHaveAttribute("aria-selected", "true");
    await waitFor(() =>
      expect(
        cagrilar.some(
          (c) =>
            c.url.startsWith("/api/users?") &&
            c.url.includes("role=security") &&
            c.url.includes("role=tesis_gorevlisi") &&
            c.url.includes("role=guvenlik_amiri") &&
            !c.url.includes("role=resident"),
        ),
      ).toBe(true),
    );
    // Sayfada TEK ana baslik: sekme icindeki liste basligi h2.
    expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1);
  });

  it("sekme degisince ADRES de degisir (yenileme ayni sekmeyi acar)", async () => {
    sahte({ "/api/users": BOS_LISTE, "/api/users/acilabilir-roller": { roller: [] }, "/api/davet": { items: [] } });
    ciz(KisilerPage);
    await userEvent.click(await screen.findByRole("tab", { name: "Davetler" }));
    expect(nav.replace).toHaveBeenCalledWith("/kisiler?sekme=davetler", { scroll: false });
  });

  it("eski /users?rol=.. dogru sekmeye", () => {
    expect(rolunSekmesi("resident")).toBe("sakinler");
    expect(rolunSekmesi("yonetici")).toBe("yoneticiler");
    expect(rolunSekmesi("denetci")).toBe("yoneticiler");
    expect(rolunSekmesi("security")).toBe("personel");
    expect(rolunSekmesi("")).toBe("personel");
  });
});

describe("(P251 §8) Maas kartlari sayfasi (Finans)", () => {
  it("HESAP SECILINCE bos ad ve e-posta hesaptan dolar; govdede bag gider", async () => {
    sahte({
      "/api/tanimlar/personel-kayitlari": { items: [] },
      "/api/users": { items: [{ id: "u7", ad: "Veli Can", email: "veli@ornek.com", role: "tesis_gorevlisi" }] },
      "POST /api/tanimlar/personel-kayitlari": { id: "k1" },
    });
    ciz(MaasKartlariPage);
    expect(await screen.findByRole("heading", { level: 1, name: "Maaş kartları" })).toBeInTheDocument();
    await userEvent.click(await screen.findByRole("button", { name: "Yeni kayıt" }));
    const hesap = await screen.findByLabelText("Uygulama hesabı");
    await waitFor(() => expect(within(hesap).getAllByRole("option").length).toBeGreaterThan(1));
    await userEvent.selectOptions(hesap, "u7");
    expect(screen.getByLabelText("Ad")).toHaveValue("Veli Can");
    expect(screen.getByLabelText("E-posta")).toHaveValue("veli@ornek.com");
    // Hesap secenekleri YALNIZ saha rolleri (aktif) — sakin listede olmaz.
    const istek = cagrilar.find((c) => c.url.startsWith("/api/users?"))!;
    expect(istek.url).toContain("role=security");
    expect(istek.url).toContain("is_active=true");
    expect(istek.url).not.toContain("role=resident");
  });
});

describe("(P251 §8) Goruntuleme izni (web'e eklendi)", () => {
  const TALEPLER = {
    items: [
      { id: "t1", unit_id: "d1", unit_no: "A-1", yonetici_ad: "Y", resident_ad: "Sakin", durum: "onaylandi", used: false, requested_at: "2026-10-01T10:00:00Z" },
      { id: "t2", unit_id: "d2", unit_no: "A-2", yonetici_ad: "Y", resident_ad: null, durum: "bekliyor", used: false, requested_at: "2026-10-01T11:00:00Z" },
    ],
  };

  it("tek daire istegi unit_id ile gider; durumlar YAZIYLA", async () => {
    sahte({
      "/api/unit-access-request/granted-units": { items: [] },
      "/api/unit-access-request": TALEPLER,
      "/api/units": { items: [{ id: "d3", no: "3", blok: "B" }] },
      "POST /api/unit-access-request": { id: "t3" },
    });
    ciz(GoruntulemeIzniPage);
    expect(await screen.findByText("Onaylandı")).toBeInTheDocument();
    expect(screen.getByText("Onay bekliyor")).toBeInTheDocument();
    await userEvent.selectOptions(await screen.findByLabelText("Daire"), "d3");
    await userEvent.click(screen.getByRole("button", { name: "İzin iste" }));
    await waitFor(() =>
      expect(cagrilar.find((c) => c.method === "POST")?.body).toEqual({ unit_id: "d3" }),
    );
  });

  it("onayli dairede kayit ONAYDAN SONRA ve TEK istekle okunur", async () => {
    sahte({
      "/api/unit-access-request/granted-units": { items: [{ request_id: "t1", unit_id: "d1", unit_no: "A-1", decided_at: null }] },
      "/api/unit-access-request": TALEPLER,
      "/api/units": { items: [] },
      "/api/visitors": { items: [{ id: "v1", ziyaretci_ad: "Misafir Bey", notlar: null, created_at: "2026-10-01T09:00:00Z" }] },
    });
    ciz(GoruntulemeIzniPage);
    const kart = await screen.findByText("A-1", { selector: "span" });
    await userEvent.click(within(kart.closest("li")!).getByRole("button", { name: "Ziyaretçiler" }));
    // Tek seferlik uyari ONCE: onaysiz okuma yok.
    expect(cagrilar.some((c) => c.url.startsWith("/api/visitors"))).toBe(false);
    await userEvent.click(await screen.findByRole("button", { name: "Göster" }));
    expect(await screen.findByText("Misafir Bey")).toBeInTheDocument();
    expect(cagrilar.filter((c) => c.url.startsWith("/api/visitors?unit_id=d1"))).toHaveLength(1);
  });
});
