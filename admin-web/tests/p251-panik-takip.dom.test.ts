// @vitest-environment jsdom
// (P251 §1) ACIL DURUM TAKIP EKRANI — sayilar sunucudan, durumlar enum'dan,
// basliklar dolu, tatbikat suzgeci.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import PanikPage from "@/app/(protected)/panik/page";
import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz } from "./yardimci";

vi.mock("@/lib/rol-kullan", () => ({ useRol: () => "yonetici" }));
afterEach(() => vi.restoreAllMocks());

const ALARM = (id: string, durum: string, ek: Record<string, unknown> = {}) => ({
  id, tip: "guvenlik", durum, olusturan_ad: "Acme Guard", daire_no: null, blok: null,
  checkpoint_ad: null, aciklama: null, created_at: "2026-10-02T05:17:00Z",
  kapandi_at: durum === "kapandi" ? "2026-10-02T05:18:00Z" : null,
  kapanis_notu: null, mudahale_suresi_sn: null, alicilar: [],
  baslik: "ACİL DURUM", toplu: false, tatbikat: false, ...ek,
});
const DURUMLAR = ["beklemede", "acik", "mudahale", "kapandi", "iptal", "yanlis_alarm"];

function taklit(ozet: Record<string, number>) {
  const c: string[] = [];
  globalThis.fetch = (async (g: RequestInfo | URL) => {
    const url = String(g);
    c.push(url);
    let govde: unknown = [];
    if (url.startsWith("/api/panik?")) {
      govde = {
        meta: { limit: 50, offset: 0, total: 2 },
        items: url.includes("tatbikat=true")
          ? [ALARM("t1", "acik", { tatbikat: true })]
          : [ALARM("a1", "yanlis_alarm"), ALARM("a2", "kapandi")],
        durumlar: DURUMLAR,
        ozet,
      };
    }
    return new Response(JSON.stringify(govde), { status: 200, headers: { "Content-Type": "application/json" } });
  }) as typeof fetch;
  return c;
}

it("acik sayisi SUNUCUDAN — yanlis alarm/iptal acik sayilmaz, kapanan ayrintili", async () => {
  taklit({ acik: 0, bugun: 2, kapanan: 2, yanlis_alarm: 1, iptal: 0, tatbikat: 0 });
  ciz(PanikPage);
  await waitFor(() => expect(document.querySelector('[data-test="panik-satir-a1"]')).toBeTruthy());
  const acik = screen.getByText(tr.panikOzetAcik).closest("div")!.parentElement!;
  expect(acik.textContent).toContain("0");
  expect(screen.getByText("1 yanlış alarm · 0 iptal")).toBeTruthy();
});

it("durum suzgeci SUNUCUNUN enum'undan — 'Yanlış alarm' var", async () => {
  taklit({ acik: 0, bugun: 0, kapanan: 0, yanlis_alarm: 0, iptal: 0, tatbikat: 0 });
  ciz(PanikPage);
  const secim = await screen.findByLabelText(tr.panikDurumSuzgec);
  await waitFor(() =>
    expect(within(secim).getAllByRole("option").map((o) => o.textContent)).toContain(tr.panikDurumYanlisAlarm),
  );
  expect(within(secim).getAllByRole("option")).toHaveLength(DURUMLAR.length + 1);
});

it("basliklar DOLU: '/ gördü' yok, eylem sutununun adi var", async () => {
  taklit({ acik: 0, bugun: 0, kapanan: 0, yanlis_alarm: 0, iptal: 0, tatbikat: 0 });
  ciz(PanikPage);
  await waitFor(() => expect(document.querySelector('[data-test="panik-satir-a1"]')).toBeTruthy());
  const basliklar = Array.from(document.querySelectorAll("thead th")).map((th) => th.textContent?.trim());
  expect(basliklar.every((b) => b && b.length > 0)).toBe(true);
  expect(basliklar).toContain(tr.panikGorenBasligi);
  expect(basliklar).toContain(tr.ortakIslemSutunu);
  expect(basliklar.some((b) => b!.startsWith("/"))).toBe(false);
});

it("tatbikat suzgeci: varsayilan gercek; tatbikat secilince rozetli satir", async () => {
  const c = taklit({ acik: 0, bugun: 0, kapanan: 0, yanlis_alarm: 0, iptal: 0, tatbikat: 1 });
  const k = userEvent.setup();
  ciz(PanikPage);
  await waitFor(() => expect(c.some((u) => u.includes("tatbikat=false"))).toBe(true));
  await k.selectOptions(screen.getByLabelText(tr.panikKaynakSuzgec), "tatbikat");
  await waitFor(() => expect(document.querySelector('[data-test="panik-tatbikat-t1"]')).toBeTruthy());
  expect(c.some((u) => u.includes("tatbikat=true"))).toBe(true);
});
