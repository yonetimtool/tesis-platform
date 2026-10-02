// @vitest-environment jsdom
// (P250 §2) ODEME KODLARI PENCERESI — kopyala, sec, tek/toplu e-posta, durum.
//
// Olculen: sunucuya GIDEN govde (P200 dersi) ve listede gorunen teslim
// durumu. Sira sunucudan gelir (yeni eklenen ustte); pencere sirayi BOZMAZ.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement } from "react";
import { afterEach, expect, it, vi } from "vitest";

import { OdemeKodlariPenceresi } from "@/components/OdemeKodlariPenceresi";
import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz } from "./yardimci";

const LISTE = {
  uretilen: 0,
  items: [
    { user_id: "u-yeni", ad: "Işıl ÖZTÜRK", daire_no: "A-3", odeme_kodu: "TS-YENI22",
      email: "isil@ornek.com", eposta_durumu: null, eposta_engeli: null },
    { user_id: "u-2", ad: "Ali VELİ", daire_no: "A-1", odeme_kodu: "TS-ABC234",
      email: "ali@ornek.com", eposta_durumu: "geri_dondu", eposta_engeli: null },
    { user_id: "u-3", ad: "Adressiz Kisi", daire_no: "B-2", odeme_kodu: "TS-XYZ789",
      email: null, eposta_durumu: null, eposta_engeli: "eposta_yok" },
  ],
};

type Cagri = { url: string; govde: Record<string, unknown> };

function taklit(): Cagri[] {
  const c: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    c.push({ url, govde: init?.body ? JSON.parse(String(init.body)) : {} });
    const govde = url.endsWith("/eposta")
      ? { gonderilen: 1, kuyruga_alinan: 0, atlananlar: [] }
      : LISTE;
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return c;
}

afterEach(() => vi.restoreAllMocks());

async function ac() {
  ciz(() => createElement(OdemeKodlariPenceresi, { acik: true, onKapat: () => {} }));
  await screen.findByText("TS-YENI22");
}

it("sira sunucudaki gibi, her kodda KOPYALA, durum rozetleri", async () => {
  taklit();
  await ac();
  const satirlar = document.querySelectorAll('[data-test="odeme-kodu-satiri"]');
  expect(satirlar[0].textContent).toContain("TS-YENI22");
  expect(satirlar).toHaveLength(3);
  for (const s of satirlar) {
    expect(within(s as HTMLElement).getByRole("button", { name: /kopyala/i })).toBeTruthy();
  }
  expect(within(satirlar[1] as HTMLElement).getByText(tr.odemeKoduDurumgeri_dondu)).toBeTruthy();
  expect(within(satirlar[2] as HTMLElement).getByText(tr.odemeKoduEngeleposta_yok)).toBeTruthy();
});

it("TUMUNU SEC yalniz gonderilebilirleri secer; toplu govde", async () => {
  const k = userEvent.setup();
  const c = taklit();
  await ac();
  await k.click(screen.getByLabelText(tr.odemeKoduTumunuSec));
  const toplu = document.querySelector('[data-test="odeme-kodu-toplu-gonder"]') as HTMLButtonElement;
  expect(toplu.textContent).toContain("(2)");
  await k.click(toplu);
  await waitFor(() => expect(c.some((x) => x.url.endsWith("/eposta"))).toBe(true));
  expect(c.find((x) => x.url.endsWith("/eposta"))!.govde).toEqual({
    user_ids: ["u-yeni", "u-2"],
  });
});

it("tek kisiye gonder: yalniz o kisi; adressiz kisinin dugmesi kapali", async () => {
  const k = userEvent.setup();
  const c = taklit();
  await ac();
  const dugmeler = document.querySelectorAll<HTMLButtonElement>('[data-test="odeme-kodu-gonder"]');
  expect(dugmeler[2].disabled).toBe(true);
  await k.click(dugmeler[1]);
  await waitFor(() => expect(c.some((x) => x.url.endsWith("/eposta"))).toBe(true));
  expect(c.find((x) => x.url.endsWith("/eposta"))!.govde).toEqual({ user_ids: ["u-2"] });
});
