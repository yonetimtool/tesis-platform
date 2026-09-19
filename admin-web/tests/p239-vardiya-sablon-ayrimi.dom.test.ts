// @vitest-environment jsdom
// (P239 §2) VARDIYA OLUSTURMA vs. SABLON — AYNI YAZI IKI DUGMEDE OLMAZ.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// Sayfada IKI dugme vardi ve IKISI DE `t("vardiyaYeni")` yaziyordu
// ("Yeni vardiya"). Ustteki BIRLESIK modali (takvim -> kisi -> onizleme,
// P235 §1), alttaki SABLON modalini aciyordu. Kullanici sablon modalini
// "vardiya olusturma" sanip takvim ve kisi seciciyi orada ariyordu.
//
// Istenen ozellik (olusturma aninda takvim + kisi) ZATEN VARDI; eksik
// olan, hangi dugmenin onu actigini SOYLEYEN etiketti.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import Sayfa from "@/app/(protected)/vardiya-plani/page";
import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz } from "./yardimci";

const BUGUN = new Date().toISOString().slice(0, 10);
const kanca = (ad: string) => document.querySelector(`[data-test="${ad}"]`);

let cagrilar: { url: string; metot: string }[] = [];

function taklit() {
  cagrilar = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const metot = (init?.method ?? "GET").toUpperCase();
    cagrilar.push({ url, metot });
    let govde: unknown = { ok: true };
    if (url.startsWith("/api/vardiya-plani/cizelge")) {
      govde = { baslangic: BUGUN, bitis: BUGUN, personel: [] };
    } else if (url.includes("/vardiya-plani/simdi")) {
      govde = { gorevdeki_vardiya: null, gorevdekiler: [], sonraki_vardiya: null, sonrakiler: [] };
    } else if (url === "/api/me") {
      govde = { id: "u-ben", role: "yonetici" };
    } else if (url.startsWith("/api/shifts")) {
      govde = { meta: { limit: 20, offset: 0, total: 0 }, items: [] };
    } else if (url.startsWith("/api/users")) {
      // GERCEK BIR PERSONEL: bos listede gonderim dugmesi kapali kalir
      // ve test "tazeleme" iddiasini HIC olcmeden yesil gorunurdu.
      govde = {
        meta: { limit: 200, offset: 0, total: 1 },
        items: [{ id: "u-1", ad: "Ali Guvenlik", role: "security" }],
      };
    } else if (
      metot === "POST" &&
      url === "/api/vardiya-plani/kalip-uygula"
    ) {
      // (P243 §1) UC DEGISTI: modal artik TEK yoldan gonderiyor.
      // Eski `/toplu` yolu sunucuda 422 aliyordu (olculdu) ve
      // kaldirildi.
      govde = {
        uygulandi: true,
        parti_id: "pt-1",
        eklenecek: 1,
        eklenen: 1,
        cakisan: 0,
        satirlar: [],
      };
    }
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  }) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

it("IKI DUGME AYNI YAZIYI TASIMAZ", async () => {
  // Sozluk duzeyinde de ayri: ayni anahtari iki yerde kullanmak,
  // birini degistirenin otekini de degistirmesi demekti.
  expect(tr.vardiyaSablonYeni).not.toBe(tr.vardiyaYeni);

  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-yeni")).toBeTruthy());
  expect(kanca("vardiya-sablon-yeni")).toBeTruthy();
  expect(kanca("vardiya-yeni")?.textContent).not.toBe(
    kanca("vardiya-sablon-yeni")?.textContent,
  );
});

it("SABLON BOLUMU NE OLDUGUNU ve nereden vardiya eklenecegini SOYLER", async () => {
  // Dugme adini degistirmek tek basina "peki bu ne zaman kullanilir"
  // sorusunu yanitlamazdi.
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-sablon-aciklama")).toBeTruthy());
  expect(kanca("vardiya-sablon-aciklama")?.textContent).toContain(
    tr.vardiyaYeni,
  );
});

it("USTTEKI DUGME takvim + kisi TASIYAN modali acar", async () => {
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-yeni")).toBeTruthy());
  await userEvent.click(kanca("vardiya-yeni") as HTMLElement);

  await waitFor(() => expect(kanca("vardiya-ekle-takvim")).toBeTruthy());
  // KISI SECIMI DE OLUSTURMA ANINDA: mobildeki akis (P235 §1).
  expect(kanca("vardiya-ekle-kisi")).toBeTruthy();
});

it("ATAMADAN SONRA CIZELGE YENIDEN CEKILIR", async () => {
  // Cizelge tazelenmezse kullanici ekledigi vardiyayi goremez ve
  // "kaydedilmedi mi" diye tekrar ekler.
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("vardiya-yeni")).toBeTruthy());
  await userEvent.click(kanca("vardiya-yeni") as HTMLElement);
  await waitFor(() => expect(kanca("vardiya-ekle-takvim")).toBeTruthy());

  await userEvent.click(kanca(`vardiya-ekle-gun-${BUGUN}`) as HTMLElement);
  await userEvent.selectOptions(
    kanca("vardiya-ekle-kisi") as HTMLSelectElement,
    "u-1",
  );

  const gonder = kanca("vardiya-ekle-gonder") as HTMLButtonElement;
  expect(gonder.disabled, "gun + kisi secili, gonderim ACIK olmali").toBe(
    false,
  );
  const oncekiCizelge = cagrilar.filter((c) =>
    c.url.startsWith("/api/vardiya-plani/cizelge"),
  ).length;
  await userEvent.click(gonder);

  // Once ISTEK GERCEKTEN ATILDI...
  await waitFor(() =>
    expect(
      cagrilar.some(
        (c) =>
          c.metot === "POST" &&
          c.url === "/api/vardiya-plani/kalip-uygula",
      ),
    ).toBe(true),
  );
  // ...sonra CIZELGE YENIDEN CEKILDI.
  await waitFor(() =>
    expect(
      cagrilar.filter((c) => c.url.startsWith("/api/vardiya-plani/cizelge"))
        .length,
    ).toBeGreaterThan(oncekiCizelge),
  );
});
