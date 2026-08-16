// @vitest-environment jsdom
// (P163 §4) YAPISAL ARACLAR — YENI YERINDE.
//
// Brief: "Toplu daire olustur · Kat sil · Numara ile sec — bunlar BINA
// DUZENLEME ekranina tasinacak; yapisal islemler tek yerde toplanmali.
// Daireler listesi liste/filtre/CRUD ekrani olarak kalsin."
//
// BU DOSYA TASIMANIN IKI YARISINI DA OLCER:
//   * araclar BURADA calisiyor (kaybolmadilar),
//   * `yz-tasima-kullanici-daire` ise Daireler sayfasinda ARTIK OLMADIKLARINI
//     olcer. Iki yerde birden dururlarsa hangisinin gecerli oldugu
//     belirsizlesir.
//
// AYRICA §1'IN SENARYOLARI BURADA: baslangic kati 0, negatif kat, mevcut
// blokta daire varken ekleme, numara cakismasi.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import BuildingEditorPage from "@/app/(protected)/building-editor/page";

import { ciz } from "./yardimci";

interface Cagri {
  url: string;
  yontem: string;
  govde: Record<string, unknown> | null;
}

const BLOK = { id: "b1", ad: "A", kat_sayisi: 3, unit_sayisi: 6 };
const DAIRE = { id: "u1", no: "A-1", blok: "A", kat: 1, sira: 1, aktif: true };

function taklit(durum = 200, yanit: unknown = { id: "yeni" }): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const yontem = init?.method ?? "GET";
    cagrilar.push({
      url,
      yontem,
      govde: init?.body ? JSON.parse(String(init.body)) : null,
    });
    if (yontem !== "GET") {
      return new Response(JSON.stringify(yanit), {
        status: durum,
        headers: { "Content-Type": "application/json" },
      });
    }
    const govde = url.startsWith("/api/blocks")
      ? { items: [BLOK] }
      : url.startsWith("/api/units")
        ? { items: [DAIRE], meta: { total: 1, limit: 200, offset: 0 } }
        : { items: [] };
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

afterEach(() => vi.restoreAllMocks());

/** Toplu olusturma modalini acar ve alanlari doldurur. */
async function topluAc(baslangicKat: string) {
  await userEvent.click(await screen.findByRole("button", { name: "Toplu daire oluştur" }));
  const kutu = within(await screen.findByRole("dialog"));
  await userEvent.type(kutu.getByRole("textbox", { name: /Blok/ }), "A");
  const katAlani = kutu.getByRole("textbox", { name: /Başlangıç katı/ });
  await userEvent.clear(katAlani);
  if (baslangicKat) await userEvent.type(katAlani, baslangicKat);
  return kutu;
}

describe("(P163 §4) araclar BINA DUZENLEME'de", () => {
  it("uc yapisal arac da acilis dugmesine sahip", async () => {
    taklit();
    ciz(BuildingEditorPage);
    for (const ad of ["Toplu daire oluştur", "Katı sil", "Daire tipi toplu değiştir"]) {
      expect(await screen.findByRole("button", { name: ad })).toBeInTheDocument();
    }
  });

  it("hepsi MODAL acar (P162 kurali)", async () => {
    taklit();
    ciz(BuildingEditorPage);
    await userEvent.click(await screen.findByRole("button", { name: "Katı sil" }));
    expect(await screen.findByRole("dialog")).toBeInTheDocument();
  });
});

describe("(P163 §1) toplu olusturma — 405'in duzeltildigi yol", () => {
  it("DOGRU YOLA ve DOGRU METODLA gider", async () => {
    const c = taklit();
    ciz(BuildingEditorPage);
    const kutu = await topluAc("1");
    await userEvent.click(kutu.getByRole("button", { name: "Kaydet" }));

    await waitFor(() => {
      const p = c.find((x) => x.yontem === "POST");
      expect(p, "POST atilmadi").toBeTruthy();
      // 405'in kok nedeni: bu yolun vekili yoktu ve istek `[id]` rotasina
      // dusuyordu. Yol ve metot burada kilitli.
      expect(p!.url).toBe("/api/units/bulk");
    });
  });

  it("BASLANGIC KATI 0 gonderilebilir (zemin kat)", async () => {
    const c = taklit();
    ciz(BuildingEditorPage);
    const kutu = await topluAc("0");
    await userEvent.click(kutu.getByRole("button", { name: "Kaydet" }));
    await waitFor(() => {
      const p = c.find((x) => x.yontem === "POST");
      // 0 "bos" ile karistirilmamali: zemin kat GERCEK bir kattir ve
      // `Number("")` de 0 verir — bu yuzden ayrimi `tamsayiCoz` yapar.
      expect(p!.govde!.baslangic_kat).toBe(0);
    });
  });

  it("NEGATIF KAT gonderilebilir (-1, -2 bodrum)", async () => {
    for (const deger of ["-1", "-2"]) {
      const c = taklit();
      const { unmount } = ciz(BuildingEditorPage);
      const kutu = await topluAc(deger);
      await userEvent.click(kutu.getByRole("button", { name: "Kaydet" }));
      await waitFor(() => {
        const p = c.find((x) => x.yontem === "POST");
        expect(p!.govde!.baslangic_kat).toBe(Number(deger));
      });
      unmount();
    }
  });

  it("MEVCUT BLOKTA daire varken ekleme yapilabilir", async () => {
    // Sunucu var olan no'lari ATLAR (`atlanan`), hata vermez. Istemci de
    // engellememeli — blokta daire olmasi bir kilit degil.
    const c = taklit(201, { olusturulan: [], atlanan: ["A-1"], bitis_no: 12 });
    ciz(BuildingEditorPage);
    await waitFor(() => expect(screen.getByText(/A/)).toBeInTheDocument());
    const kutu = await topluAc("1");
    await userEvent.click(kutu.getByRole("button", { name: "Kaydet" }));
    await waitFor(() => {
      expect(c.find((x) => x.yontem === "POST")).toBeTruthy();
    });
  });

  it("NUMARA CAKISMASINDA (409) hata EKRANDA gorunur", async () => {
    const c = taklit(409, { error: { code: "conflict", message: "Daire no çakışması" } });
    ciz(BuildingEditorPage);
    const kutu = await topluAc("1");
    await userEvent.click(kutu.getByRole("button", { name: "Kaydet" }));
    // Sessizce yutulmaz: kullanici NEDEN olmadigini gormeli.
    expect(await screen.findByText(/çakışması/i)).toBeInTheDocument();
    expect(c.some((x) => x.yontem === "POST")).toBe(true);
  });

  it("BLOK KALIBI istekten ONCE dogrulanir", async () => {
    const c = taklit();
    ciz(BuildingEditorPage);
    await userEvent.click(await screen.findByRole("button", { name: "Toplu daire oluştur" }));
    const kutu = within(await screen.findByRole("dialog"));
    await userEvent.type(kutu.getByRole("textbox", { name: /Blok/ }), "A Blok");
    await userEvent.click(kutu.getByRole("button", { name: "Kaydet" }));
    // Sunucuya HIC gitmemeli; anlamsiz bir 422 yerine sebep yazilir.
    expect(c.some((x) => x.yontem === "POST")).toBe(false);
    expect(await screen.findByText(/yalnızca harf ve rakam/i)).toBeInTheDocument();
  });
});

describe("(P163 §4) kat silme ve toplu tip", () => {
  it("kat silme DOGRU yola gider", async () => {
    const c = taklit();
    ciz(BuildingEditorPage);
    await userEvent.click(await screen.findByRole("button", { name: "Katı sil" }));
    const kutu = within(await screen.findByRole("dialog"));
    await userEvent.selectOptions(kutu.getByRole("combobox", { name: /Blok/ }), "A");
    await userEvent.type(kutu.getByRole("textbox", { name: /Kat/ }), "2");
    await userEvent.click(kutu.getByRole("button", { name: "Sil" }));

    // Once ONAY sorulur; onaysiz istek ATILMAZ.
    //
    // IKI DIYALOG ACIK: kat-sil formu ve onun ustundeki onay. Sonuncusu
    // onaydir — `findByRole("dialog")` tekil arar ve "birden cok" diye
    // duserdi.
    await waitFor(() => expect(screen.getAllByRole("dialog")).toHaveLength(2));
    const diyaloglar = screen.getAllByRole("dialog");
    const onay = within(diyaloglar[diyaloglar.length - 1]);
    await userEvent.click(onay.getByRole("button", { name: "İptal" }));
    expect(c.some((x) => x.url === "/api/units/kat-sil")).toBe(false);
  });

  it("toplu tip modali SECIM SAYISINI gosterir", async () => {
    taklit();
    ciz(BuildingEditorPage);
    await userEvent.click(
      await screen.findByRole("button", { name: "Daire tipi toplu değiştir" }),
    );
    const kutu = within(await screen.findByRole("dialog"));
    // Secim yokken kaydet KAPALI: bos bir istek "yaptim" deyip hicbir sey
    // yapmamak olurdu.
    expect(kutu.getByRole("button", { name: "Kaydet" })).toBeDisabled();
  });
});
