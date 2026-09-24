// @vitest-environment jsdom
// (E2E 2026-09) ARAYUZ TURU — web bulgulari (bulgular/arayuz.md).
//
//   ARAYUZ-1   kenar cubugu logosu acik temada 1.51:1 (lacivert ustune lacivert),
//   ARAYUZ-6   `w-auto` secim kutusu uzun secenekle sayfayi tasiriyordu,
//   ARAYUZ-9   dokunma hedefleri < 24px (tablo siralama dugmesi),
//   ARAYUZ-10  kenar cubugunda odak halkasi gorunmuyordu,
//   ARAYUZ-13  /tasks 500'de ham sunucu metni + yaniltici "0" sayaclar,
//   ARAYUZ-17  ozet kartinda etiket kesiliyordu.
//
// CSS'in GERCEK etkisi (kontrast, piksel olcusu) jsdom'da olculemez; o
// maddelerde kilit YAPISALDIR (bkz. "select gradyan" notu) — kuralin
// yerinde durdugu sinanir, tarayicidaki gorunum degil.
import fs from "node:fs";
import path from "node:path";

import { render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import TasksPage from "@/app/(protected)/tasks/page";
import { YonetioLogo } from "@/components/YonetioLogo";
import { OzetKarti, Secim } from "@/components/ui";

import { ciz, fetchSahtele } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/tasks",
  useSearchParams: () => new URLSearchParams(),
}));

const KOK = path.resolve(__dirname, "..");
const oku = (g: string) => fs.readFileSync(path.join(KOK, g), "utf8");

afterEach(() => vi.restoreAllMocks());

describe("(ARAYUZ-13) gorevler ucu 500 donunce", () => {
  it("ham sunucu metni GOSTERILMEZ, sayaclar '0' degil '—'", async () => {
    fetchSahtele({
      "/api/tasks": { __durum: 500, error: { message: "x-ham-istisna" } },
      "/api/users": { items: [], meta: { total: 0 } },
      "/api/task-categories": { items: [] },
    });
    ciz(TasksPage);
    // Cevrili genel metin (durum kodu + referans) — "x" DEGIL.
    expect(await screen.findByText(/durum 500/)).toBeTruthy();
    expect(screen.queryByText("x-ham-istisna")).toBeNull();
    // Uc sayac da bilinmiyor: "—". Gercek bir "0" gibi durmamali.
    await waitFor(() => expect(screen.getAllByText("—").length).toBeGreaterThanOrEqual(3));
  });
});

describe("(ARAYUZ-1) kenar cubugu logosu", () => {
  it("`koyuZemin`: yalniz ACIK murekkepli isaret + beyaz kelime", () => {
    const { container } = render(YonetioLogo({ koyuZemin: true }));
    const gorseller = [...container.querySelectorAll("img")];
    expect(gorseller).toHaveLength(1);
    expect(gorseller[0].getAttribute("src")).toContain("yonetio-logo-acik");
    // Tek gorsel oldugu icin erisilebilir adi O tasir.
    expect(gorseller[0].getAttribute("alt")).toBe("Yönetiyor");
    const kelime = screen.getByText("yönetiyor");
    expect(kelime.className).toContain("text-white");
    expect(kelime.className).not.toContain("#0E3C91");
  });

  it("varsayilan (ust bar) davranis DEGISMEDI: temaya gore iki varyant", () => {
    const { container } = render(YonetioLogo({}));
    expect(container.querySelectorAll("img")).toHaveLength(2);
  });

  it("kenar cubugu `koyuZemin` ile ciziyor", () => {
    expect(oku("components/AppShell.tsx")).toMatch(/<YonetioLogo[^>]*koyuZemin/);
  });
});

describe("(ARAYUZ-6) secim kutusu tasmaz", () => {
  it("genislik verilse de `max-w-full` her zaman var", () => {
    const { container } = render(Secim({ className: "w-auto", children: null }));
    expect(container.querySelector("select")?.className).toContain("max-w-full");
  });
});

describe("(ARAYUZ-17) ozet karti etiketi kesilmez", () => {
  it("etiket `truncate` degil, sarar", () => {
    ciz(() => OzetKarti({ etiket: "Onay bekleyen hareketler", deger: "3" }));
    const etiket = screen.getByText("Onay bekleyen hareketler");
    expect(etiket.className).not.toContain("truncate");
  });
});

describe("(ARAYUZ-9 / ARAYUZ-10) yapisal kilitler", () => {
  it("tablo siralama dugmesi en az 24px (min-h-6)", () => {
    expect(oku("components/ui/veri-tablosu.tsx")).toMatch(
      /aria-label=\{t\("tabloSirala"[\s\S]{0,400}min-h-6/,
    );
  });

  it("onay kutularina fare isaretcisinde de 24px tiklama alani", () => {
    const css = oku("app/tasarim-sistemi.css");
    expect(css).toMatch(
      /:where\(input\[type="checkbox"\], input\[type="radio"\]\) \{\s*box-sizing: content-box;[\s\S]*?padding: 4px;/,
    );
  });

  it("kenar cubugu odak halkasi kendi isaret tonunda ve iki aside'da isaret var", () => {
    expect(oku("app/globals.css")).toMatch(
      /\[data-kabuk="kenar"\] :focus-visible \{\s*outline: 2px solid var\(--yz-sidebar-marker\);/,
    );
    const kabuk = oku("components/AppShell.tsx");
    // Oznitelik satirlari (yorumdaki anma sayilmaz).
    expect(kabuk.match(/^\s*data-kabuk="kenar"$/gm)?.length).toBe(2);
  });
});
