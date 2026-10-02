// @vitest-environment jsdom
// (P251 §3) SIKAYET HARITASI — daire ayrintisi ACILIR PENCEREDE; Esc ve
// disari tiklama kapatir; acik ve suresi dolmus sikayetler AYRI.
import { fireEvent, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import SchematicPage from "@/app/(protected)/schematic/page";
import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz } from "./yardimci";

afterEach(() => vi.restoreAllMocks());

const HARITA = {
  bloklar: [{ blok: "A", katlar: [{ kat: 3, units: [
    { unit_id: "u1", unit_no: "A-7", blok: "A", kat: 3, sira: 1, color: "sari", complaint_count: 1 },
  ] }] }],
  unplaced: [],
};
const SIKAYETLER = { meta: { limit: 50, offset: 0, total: 2 }, items: [
  { id: "c1", target_unit_id: "u1", kategori: "gurultu", notlar: "Gece müzik", durum: "acik",
    created_at: "2026-10-01T22:00:00Z", suresi_doldu: false },
  { id: "c2", target_unit_id: "u1", kategori: "gurultu", notlar: "Eski şikayet", durum: "acik",
    created_at: "2026-09-01T22:00:00Z", suresi_doldu: true },
] };

function taklit() {
  globalThis.fetch = (async (g: RequestInfo | URL) => {
    const u = String(g);
    const govde = u.includes("/api/unit-complaints") ? SIKAYETLER : HARITA;
    return new Response(JSON.stringify(govde), { status: 200, headers: { "Content-Type": "application/json" } });
  }) as typeof fetch;
}

it("daireye tiklayinca ACILIR PENCERE: blok/kat, acik ve suresi dolmus ayri", async () => {
  taklit();
  const k = userEvent.setup();
  ciz(SchematicPage);
  await k.click(await screen.findByRole("button", { name: /A-7/ }));
  const pencere = await screen.findByRole("dialog");
  expect(pencere.textContent).toContain("A-7");
  await waitFor(() => expect(document.querySelector('[data-test="harita-acik-sikayetler"]')).toBeTruthy());
  expect(document.querySelector('[data-test="harita-acik-sikayetler"]')!.textContent).toContain("Gece müzik");
  const dolmus = document.querySelector('[data-test="harita-suresi-dolmus"]')!;
  expect(dolmus.textContent).toContain(tr.haritaSuresiDolmus);
  expect(dolmus.textContent).toContain("Eski şikayet");
  expect(document.querySelector('[data-test="harita-acik-sikayetler"]')!.textContent).not.toContain("Eski şikayet");
});

it("Esc pencereyi kapatir", async () => {
  taklit();
  const k = userEvent.setup();
  ciz(SchematicPage);
  await k.click(await screen.findByRole("button", { name: /A-7/ }));
  await screen.findByRole("dialog");
  fireEvent.keyDown(document, { key: "Escape" });
  await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull());
});
