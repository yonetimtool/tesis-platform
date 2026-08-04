// @vitest-environment jsdom
// (P122) BINA TASARIMCISI — hucrede DAIRE TIPI.
//
// Tip atandiktan sonra bilgi yalniz YAN PANELDE duruyordu; izgaraya bakan
// kisi hangi dairenin ne oldugunu ancak tek tek dokunarak gorebiliyordu.
// Kat planinin isi tam olarak budur: BAKISTA OKUNMAK.
//
// Renk kilidi AYRI dosyada (`daire-tipi-rengi.test.ts`) ve mobil ikiziyle
// paylasilan tabloyu olcer; burada olculen sey HUCRENIN o bilgiyi
// GERCEKTEN cizmesi.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import BuildingEditorPage from "@/app/(protected)/building-editor/page";
import { daireTipiRengi } from "@/lib/daire-tipi-rengi";

import { ciz, fetchSahtele } from "./yardimci";

const BLOK = { id: "b1", ad: "A", kat_sayisi: 2, unit_sayisi: 2 };

function daire(over: Record<string, unknown> = {}) {
  return {
    id: "u1", no: "12", blok: "A", kat: 1, sira: 2,
    aktif: true, created_at: "2026-01-01T00:00:00Z",
    ...over,
  };
}

function kur(units: Record<string, unknown>[]) {
  fetchSahtele({
    "/api/blocks": { items: [BLOK], meta: { total: 1, limit: 50, offset: 0 } },
    "/api/units": { items: units, meta: { total: units.length, limit: 200, offset: 0 } },
  });
}

afterEach(() => vi.restoreAllMocks());

describe("Bina tasarımcısı — hücrede daire tipi", () => {
  it("TIP ATANMISSA hucrede gorunur", async () => {
    kur([daire({ unit_tip_id: "t1", unit_tip_ad: "2+1" })]);
    ciz(BuildingEditorPage);
    await userEvent.click(await screen.findByText(/Blok A/));
    await waitFor(() =>
      expect(screen.getByTestId("daire-tip-etiketi")).toHaveTextContent("2+1"),
    );
  });

  it("TIP YOKSA TIRE gosterilir (sira ipucuna tasindi)", async () => {
    // (Duzeltme turu) DAVRANIS BILINCLI DEGISTI. Eskiden tip yokken hucre
    // sessizce `#sira` gosteriyordu; kullanici "tip mi yok, sira mi?" diye
    // ayirt edemiyordu. Yeni kural: tip alani HER ZAMAN cizilir, atanmamissa
    // "—". Sira KAYBOLMADI — ipucuna (title) tasindi, asagidaki test olcuyor.
    kur([daire()]);
    ciz(BuildingEditorPage);
    await userEvent.click(await screen.findByText(/Blok A/));
    await waitFor(() =>
      expect(screen.getByTestId("daire-tip-etiketi")).toHaveTextContent("—"),
    );
  });

  it("TIP YOKKEN sira IPUCUNDA durur (bilgi kaybi yok)", async () => {
    kur([daire()]);
    ciz(BuildingEditorPage);
    await userEvent.click(await screen.findByText(/Blok A/));
    const etiket = await screen.findByTestId("daire-tip-etiketi");
    const hucre = etiket.closest("div[title]") as HTMLElement;
    expect(hucre.title).toBe("12 · #2");
  });

  it("UZUN tip adi KIRPILIR (hucre 80 px)", async () => {
    kur([daire({ unit_tip_ad: "Dubleks Bahçe Katı" })]);
    ciz(BuildingEditorPage);
    await userEvent.click(await screen.findByText(/Blok A/));
    await waitFor(() =>
      expect(screen.getByTestId("daire-tip-etiketi")).toHaveTextContent("Dublek…"),
    );
  });

  it("PASIF daire TIP ETIKETI GOSTERMEZ (durum renk gurultusunde kaybolmasin)", async () => {
    kur([daire({ aktif: false, unit_tip_ad: "2+1" })]);
    ciz(BuildingEditorPage);
    await userEvent.click(await screen.findByText(/Blok A/));
    await waitFor(() => expect(screen.getByText("12")).toBeInTheDocument());
    expect(screen.queryByTestId("daire-tip-etiketi")).toBeNull();
  });

  it("TIP RENGI hucreye UYGULANIR", async () => {
    kur([daire({ unit_tip_ad: "Villa" })]);
    ciz(BuildingEditorPage);
    await userEvent.click(await screen.findByText(/Blok A/));
    const etiket = await screen.findByTestId("daire-tip-etiketi");
    const hucre = etiket.closest("div[style]") as HTMLElement;
    // jsdom rengi `rgb(...)` diye normallestirir; hex'i cevirip karsilastir.
    const hex = daireTipiRengi("Villa");
    const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));
    expect(hucre.style.backgroundColor).toBe(`rgb(${r}, ${g}, ${b})`);
  });

  it("EKRAN OKUYUCU/ipucu TAM adi tasir (kisaltilmis DEGIL)", async () => {
    kur([daire({ unit_tip_ad: "Dubleks Bahçe Katı" })]);
    ciz(BuildingEditorPage);
    await userEvent.click(await screen.findByText(/Blok A/));
    const etiket = await screen.findByTestId("daire-tip-etiketi");
    const hucre = etiket.closest("div[title]") as HTMLElement;
    // Ipucu: no · tip · sira (sira artik burada; bkz. yukarisi).
    expect(hucre.title).toBe("12 · Dubleks Bahçe Katı · #2");
  });
});
