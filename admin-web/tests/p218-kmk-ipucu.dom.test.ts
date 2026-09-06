// @vitest-environment jsdom
// (P218) "BORÇ KİME YAZILIR" — SEÇİM ve KMK İPUCU.
//
// ===========================================================================
// NE OLCULUYOR
// ===========================================================================
// Alan ve motor P28'den beri VARDI ama hicbir ekranda duzenlenemiyordu:
// her tanim varsayilanla doguyor, yonetici "bu bakim gideri malige
// yazilsin" diyemiyordu.
//
// IPUCU ZORLAYICI DEGIL: kanunun ne dedigini soyler, secimi
// DEGISTIRMEZ. Tur adindan tahmin etmek REDDEDILDI — ad serbest metin
// ve 7 dil, ustelik ayni kelime iki tarafa da dusebiliyor (asansor
// ISLETME kullananin, YENILEME malikin). Yanlis oneri, onerisizlikten
// kotudur.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import TanimlarPage from "@/app/(protected)/tanimlar/page";

import { ciz } from "./yardimci";

// (P218) Sayfa aktif defteri ADRESTEN okuyor (`?defter=`); sahte
// olmadan `useSearchParams` tanimsiz doner ve sayfa hic cizilmez.
// Dogrudan gelir/gider turleri defterini aciyoruz — testin konusu o.
vi.mock("next/navigation", () => ({
  useSearchParams: () => new URLSearchParams("defter=gelir-gider-tanimlari"),
  useRouter: () => ({ push: () => {}, replace: () => {}, refresh: () => {} }),
  usePathname: () => "/tanimlar",
}));

function sunucu() {
  const yazmalar: { yol: string; govde: unknown }[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    if ((init?.method ?? "GET") !== "GET") {
      yazmalar.push({ yol: url, govde: init?.body ? JSON.parse(String(init.body)) : null });
      return new Response(JSON.stringify({ id: "yeni" }), {
        status: 201, headers: { "Content-Type": "application/json" },
      });
    }
    return new Response(
      JSON.stringify({ meta: { limit: 20, offset: 0, total: 0 }, items: [] }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  }) as typeof fetch;
  return yazmalar;
}

afterEach(() => vi.restoreAllMocks());

/** Gelir/gider türü formunu açar. */
async function formuAc() {
  const yazmalar = sunucu();
  ciz(TanimlarPage);
  const k = userEvent.setup();
  // Ekleme dugmesinin adi defterden defterine degisiyor; TUM dugmeleri
  // yazdirmak yerine "yeni" gecen ilkini seciyoruz.
  const dugmeler = await screen.findAllByRole("button");
  const ekle = dugmeler.find((d) => /yeni|ekle/i.test(d.textContent ?? ""));
  expect(ekle, `ekleme düğmesi yok: ${dugmeler.map((d) => d.textContent).join(" | ")}`)
    .toBeTruthy();
  await k.click(ekle!);
  const modal = await screen.findByRole("dialog");
  return { yazmalar, modal, k };
}

describe("(P218) borç hedefi seçimi", () => {
  it("ALAN VAR ve İKİ seçenek sunuyor", async () => {
    const { modal } = await formuAc();
    const secim = await waitFor(() => {
      const hepsi = within(modal).getAllByRole("combobox") as HTMLSelectElement[];
      const s = hepsi.find((x) =>
        Array.from(x.querySelectorAll("option")).some((o) => o.value === "kiraci_oncelikli"));
      expect(s, `hedef kuralı alanı yok. Modal alanları: ${
        (within(modal).queryAllByRole("combobox") as HTMLSelectElement[])
          .map((x) => Array.from(x.options).map((o) => o.value).join("/"))
          .join(" || ")
      } | başlık: ${modal.textContent?.slice(0, 80)}`).toBeTruthy();
      return s!;
    });
    const degerler = Array.from(secim.options).map((o) => o.value).filter(Boolean);
    expect(degerler).toEqual(["kiraci_oncelikli", "malik"]);
  });

  it("SEÇENEKLER ÇEVRİLMİŞ metinle çizilir (ham enum DEĞİL)", async () => {
    // `kiraci_oncelikli` bir enum degeri, cumle degil; kullaniciya ham
    // gostermek teknik adi ekrana koymakti.
    const { modal } = await formuAc();
    const secim = await waitFor(() => {
      const hepsi = within(modal).getAllByRole("combobox") as HTMLSelectElement[];
      const s = hepsi.find((x) =>
        Array.from(x.querySelectorAll("option")).some((o) => o.value === "kiraci_oncelikli"));
      expect(s).toBeTruthy();
      return s!;
    });
    const etiketler = Array.from(secim.options).map((o) => o.textContent ?? "");
    expect(etiketler.join(" ")).toMatch(/kullanan öder/i);
    expect(etiketler.join(" ")).toMatch(/malik öder/i);
    expect(etiketler.join(" ")).not.toMatch(/kiraci_oncelikli/);
  });

  it("KMK İPUCU görünür ve ZORLAYICI DEĞİL", async () => {
    const { modal } = await formuAc();
    await waitFor(() =>
      expect(within(modal).getByText(/KMK md\. 20/i)).toBeInTheDocument(),
    );
    const ipucu = within(modal).getByText(/KMK md\. 20/i);
    // Kanunun IKI tarafini da soylemeli — tek tarafi yazmak yonlendirme
    // olurdu.
    //
    // NOT: `/malik/i` KULLANILMIYOR. Metinde "MALİKE" gecıyor ve
    // JavaScript'in `i` bayragi Turkce noktali I ile (U+0130) noktasiz
    // i'yi ESLESTIRMEZ — testi ilk yazimda tam bu yuzden dustu.
    expect(ipucu.textContent).toMatch(/kullanan/i);
    expect(ipucu.textContent).toMatch(/MALİK|malik/);
    // Ve KARARIN YONETICIDE oldugunu soylemeli.
    expect(ipucu.textContent).toMatch(/sözleşme|karar sizindir/i);
  });

  it("SEÇİM ÖNCEDEN DOLU DEĞİL — sunucu tesis varsayılanını uygular", async () => {
    // Formda bir deger secili gelseydi, tesis varsayilani SESSIZCE
    // ezilirdi: kullanici dokunmasa bile o deger gonderilirdi.
    const { modal } = await formuAc();
    const secim = await waitFor(() => {
      const hepsi = within(modal).getAllByRole("combobox") as HTMLSelectElement[];
      const s = hepsi.find((x) =>
        Array.from(x.querySelectorAll("option")).some((o) => o.value === "kiraci_oncelikli"));
      expect(s).toBeTruthy();
      return s!;
    });
    expect(secim.value).toBe("");
  });
});
