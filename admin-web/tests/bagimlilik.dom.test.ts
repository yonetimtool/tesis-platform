// @vitest-environment jsdom
// (P154 / Asama 7.4) BAGIMLILIK YONLENDIRMESI.
//
// Olculen dort sey:
//   1. Uyari YALNIZ eksikken cizilir (yoksa her ekranda kalici bir sitem),
//   2. Dugme ILGILI ekrana gider ve DONUS ADRESINI tasir,
//   3. Donus adresi DOGRULANIR — `?donus=https://baska-site` panelden
//      disari yonlendiren bir dugme uretebilirdi (acik yonlendirme),
//   4. Kayitli her bagimliligin rotasi GERCEK bir panel rotasidir.
import { screen } from "@testing-library/react";
import { createElement } from "react";
import { describe, expect, it, vi } from "vitest";

import { BagimlilikUyarisi } from "@/components/BagimlilikUyarisi";
import { DonusCubugu } from "@/components/DonusCubugu";
import {
  BAGIMLILIKLAR,
  DONUS_PARAM,
  gecerliDonus,
  hedefBaglantisi,
} from "@/lib/bagimliliklar";
import { ROTA_ROLLERI } from "@/lib/yuzey";

import { ciz } from "./yardimci";

let sahteSorgu = new URLSearchParams();
vi.mock("next/navigation", () => ({
  usePathname: () => "/dues",
  useSearchParams: () => sahteSorgu,
  useRouter: () => ({ replace: vi.fn(), refresh: vi.fn(), push: vi.fn() }),
}));

describe("(P154/7.4) uyari YALNIZ eksikken", () => {
  it("eksik DEGILSE hicbir sey cizilmez", () => {
    sahteSorgu = new URLSearchParams();
    const { container } = ciz(() =>
      createElement(BagimlilikUyarisi, { kod: "kasa" as const, eksik: false }),
    );
    expect(container.textContent).toBe("");
  });

  it("eksikse UYARI + EYLEM dugmesi cizilir", () => {
    sahteSorgu = new URLSearchParams();
    ciz(() => createElement(BagimlilikUyarisi, { kod: "kasa" as const, eksik: true }));
    expect(screen.getByText("Kasa tanımla")).toBeInTheDocument();
    // Bu bir HATA DEGIL, bir YONLENDIRME: `alert` olsaydi ekran okuyucu
    // kullanicinin isini keserdi.
    //
    // SORGU DARALTILDI: Toast saglayicisi da bir `role="status"` canli
    // bolge ciziyor; `getByRole` ikisini birden bulur. Aranan sey
    // UYARININ KENDISI, sayfadaki tek durum bolgesi degil.
    const mesaj = screen.getByText(/kasa tanımlamalısınız/);
    expect(mesaj.closest('[role="status"]')).not.toBeNull();
  });

  it("dugme HEDEFE gider ve DONUS adresini tasir", () => {
    sahteSorgu = new URLSearchParams();
    ciz(() => createElement(BagimlilikUyarisi, { kod: "kasa" as const, eksik: true }));
    const baglanti = screen.getByRole("link") as HTMLAnchorElement;
    expect(baglanti.getAttribute("href")).toContain("/tanimlar?defter=kasalar");
    expect(baglanti.getAttribute("href")).toContain(
      `${DONUS_PARAM}=${encodeURIComponent("/dues")}`,
    );
  });
});

describe("(P154/7.4) DONUS adresi DOGRULANIR", () => {
  it("uygulama disi adres REDDEDILIR (acik yonlendirme)", () => {
    // Ucu de tarayicida MUTLAK adrestir.
    expect(gecerliDonus("https://baska-site")).toBeNull();
    expect(gecerliDonus("//baska-site")).toBeNull();
    expect(gecerliDonus("/\\baska-site")).toBeNull();
    expect(gecerliDonus("/dues")).toBe("/dues");
  });

  it("gecersiz donus baglantiya EKLENMEZ", () => {
    const href = hedefBaglantisi(BAGIMLILIKLAR.kasa, "https://baska-site");
    expect(href).not.toContain("baska-site");
  });

  it("DONUS CUBUGU gecersiz adreste CIZILMEZ", () => {
    sahteSorgu = new URLSearchParams({ [DONUS_PARAM]: "https://baska-site" });
    const { container } = ciz(() => createElement(DonusCubugu));
    expect(container.textContent).toBe("");
  });

  it("DONUS CUBUGU gecerli adreste geri donus sunar", () => {
    sahteSorgu = new URLSearchParams({ [DONUS_PARAM]: "/dues" });
    ciz(() => createElement(DonusCubugu));
    const baglanti = screen.getByRole("link") as HTMLAnchorElement;
    expect(baglanti.getAttribute("href")).toBe("/dues");
  });
});

describe("(P154/7.4) kayitli hedefler GERCEK rotalar", () => {
  it("her bagimliligin rotasi ROTA_ROLLERI'nde tanimli", () => {
    // Yanlis yazilmis bir rota, kullaniciyi 404'e gonderen bir dugme
    // uretirdi — ve bu ancak elle tiklayinca fark edilirdi.
    for (const [kod, b] of Object.entries(BAGIMLILIKLAR)) {
      expect(ROTA_ROLLERI[b.rota], `${kod} -> ${b.rota}`).toBeTruthy();
    }
  });

  it("olcum BOSA DUSMUYOR — en az sekiz kayit var", () => {
    expect(Object.keys(BAGIMLILIKLAR).length).toBeGreaterThanOrEqual(8);
  });
});
