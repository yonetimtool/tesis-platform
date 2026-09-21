// @vitest-environment jsdom
//
// (P244 §8c) OPERASYON EKRANLARI — SERIT SAYILARI ve DURUM SUZGECI.
//
// ===========================================================================
// IKI IDDIA
// ===========================================================================
// 1. GOREVLERDE DURUM SUZGECI EKRANA GELDI. `durumFiltre` durumu ve
//    sorgusu KODDA VARDI ama onu kuracak hicbir kontrol YOKTU: P230
//    §4'te eklenen suzgec webden HIC kullanilamiyordu (ustelik BFF de
//    dusuruyordu — bkz. `p244-gorev-bff-suzgec`).
//
// 2. SERIT SAYILARI GORUNEN LISTEDEN TURETILMEZ. Bu, bu turun en cok
//    tekrar eden kusuru: liste hem sayfali hem suzgecli oldugu icin
//    ondan saymak, suzgec acikken sayaci da suzer ("planli" secilince
//    "0 geciken bakim" yazardi — oysa geciken bakim orada duruyor).
import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import BakimPage from "@/app/(protected)/bakim/page";
import TasksPage from "@/app/(protected)/tasks/page";

import { cagrilanUrller, ciz, fetchSahtele } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/",
  useSearchParams: () => new URLSearchParams(),
}));

afterEach(() => vi.restoreAllMocks());

function gorevKur() {
  fetchSahtele({
    "/api/tasks": { meta: { limit: 25, offset: 0, total: 0 }, items: [] },
    "/api/users": { meta: { total: 0 }, items: [] },
    "/api/tanimlar/gorev-kategorileri": { items: [] },
  });
}

describe("(P244 §8c) gorevler — durum suzgeci", () => {
  it("DURUM SUZGECI EKRANDA (kodda vardi, kontrolu YOKTU)", async () => {
    gorevKur();
    ciz(TasksPage);
    expect(
      await screen.findByRole("combobox", { name: "Görev durumu" }),
    ).toBeInTheDocument();
  });

  it("SECILEN DURUM SUNUCUYA GIDER", async () => {
    gorevKur();
    ciz(TasksPage);
    const secim = await screen.findByRole("combobox", { name: "Görev durumu" });
    await userEvent.selectOptions(secim, "gecikti");
    // Sorguda `durum=gecikti` olan BIR LISTE istegi olmali. Sayac
    // istekleri de `durum=` tasir; ayirt edici olan `limit=1` OLMAMASI.
    const liste = cagrilanUrller().filter(
      (u) => u.includes("durum=gecikti") && !u.includes("limit=1"),
    );
    expect(liste.length, "durum suzgeci listeye uygulanmadi").toBeGreaterThan(0);
  });

  it("SERIT SAYILARI AYRI SORGULARDAN (gorunen listeden degil)", async () => {
    gorevKur();
    ciz(TasksPage);
    await screen.findByRole("combobox", { name: "Görev durumu" });
    const urller = cagrilanUrller();
    expect(urller.some((u) => u.includes("durum=gecikti") && u.includes("limit=1"))).toBe(true);
    expect(urller.some((u) => u.includes("durum=tamamlandi") && u.includes("limit=1"))).toBe(true);
  });
});

describe("(P244 §8c) bakim — serit sayaclari", () => {
  it("SAYAÇLAR DURUM SUZGECINDEN BAGIMSIZ SORULUR", async () => {
    // Liste `?durum=` ile suzulebiliyor; sayaclar kendi sorgularini
    // atmazsa "planli" secili bir ekranda geciken bakim sayisi 0
    // gorunurdu — yani ekran, geciken bakim YOK derdi.
    fetchSahtele({
      "/api/bakim/ekipmanlar": { meta: { limit: 200, offset: 0, total: 0 }, items: [] },
      "/api/bakim/kayitlar": { meta: { total: 0 }, items: [] },
      "/api/bakim/ozet": { yasal_eksik: [], satirlar: [] },
    });
    ciz(BakimPage);
    // Baslik hem sayfa basliginda hem ilk sekmenin adinda geciyor;
    // sorgu ROLE daraltilir.
    await screen.findByRole("heading", { name: "Periyodik bakım", level: 1 });
    const urller = cagrilanUrller();
    for (const d of ["gecikti", "bugun", "yaklasti"]) {
      expect(
        urller.some((u) => u.includes(`durum=${d}`) && u.includes("limit=1")),
        `${d} sayaci ayri sorulmuyor`,
      ).toBe(true);
    }
  });
});
