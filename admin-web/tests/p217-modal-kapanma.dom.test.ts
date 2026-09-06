// @vitest-environment jsdom
// (P217 §2) MODAL BASARIDA KAPANIR — ve UC MODAL AYNI DAVRANIR.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// Daire panelinde (`UnitDetail`) UC modal var: tahakkuk, tahsilat, sakin
// atama. UCU AYRI DAVRANIYORDU:
//   tahsilat     -> `setPOpen(false)` VAR, kapaniyordu
//   tahakkuk     -> YOK; kayit basarili, "Tahakkuk eklendi." yaziliyor,
//                   liste tazeleniyor ama MODAL ACIK KALIYORDU
//   sakin atama  -> YOK
//
// Kullanicinin gordugu: "Tahakkuk eklendi mesaji cikiyor ama modal acik
// kaliyor". En olasi tepki ayni tahakkuku BIR KEZ DAHA yazmaya calismak
// ve "zaten var" hatasi almak.
//
// TAKLIT HTTP KATMANINDA (P200): `fetch` sahteleniyor, `apiSend` ve
// yanit isleme gercekten kosuyor.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import { UnitDetail } from "@/components/UnitDetail";

import { ciz } from "./yardimci";

const DAIRE = { id: "u1", no: "A-1", blok: "A", aktif: true };

function sunucu(yazmaDurumu = 201) {
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const yazma = (init?.method ?? "GET") !== "GET";
    if (yazma) {
      return new Response(
        JSON.stringify(
          yazmaDurumu >= 400
            ? { error: { code: "conflict", message: "Bu dönem için tahakkuk zaten var." } }
            : { created: [], olusan: 1, atlanan: 0 },
        ),
        { status: yazmaDurumu, headers: { "Content-Type": "application/json" } },
      );
    }
    // `/residents` DIZI doner (sayfali zarf DEGIL) — ilk yazimda zarf
    // dondurdum ve bilesen `.filter` cagirinca patladi.
    const govde = url.includes("residents")
      ? []
      : url.includes("assessments") || url.includes("payments")
        ? { meta: { limit: 20, offset: 0, total: 0 }, items: [] }
        : { meta: { limit: 20, offset: 0, total: 0 }, items: [] };
    return new Response(JSON.stringify(govde), {
      status: 200, headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

/** Tahakkuk modalini acar ve formu doldurup kaydeder. */
async function tahakkukEkle(k: ReturnType<typeof userEvent.setup>) {
  await k.click(await screen.findByRole("button", { name: /tahakkuk (ekle|oluştur)/i }));
  const modal = await screen.findByRole("dialog");
  const alanlar = within(modal).getAllByRole("textbox");
  // DONEM ZORUNLU (`required`): bos birakilinca tarayici formu hic
  // gondermiyor ve modal "kapanmadi" gorunuyordu — ilk yazimda testi
  // dusuren sey buydu, kodun kendisi degil.
  const donem = alanlar.find((a) => a.getAttribute("placeholder") === "2026-07");
  expect(donem, "dönem alanı bulunamadı").toBeTruthy();
  await k.type(donem!, "2026-07");
  // Tutar alani: `inputmode=decimal` olan.
  const tutar = alanlar.find((a) => a.getAttribute("inputmode") === "decimal");
  expect(tutar, "tutar alanı bulunamadı").toBeTruthy();
  await k.clear(tutar!);
  await k.type(tutar!, "150,00");
  await k.click(within(modal).getByRole("button", { name: /^(kaydet|ekle)$/i }));
  return modal;
}

describe("(P217 §2) daire panelindeki modallar", () => {
  it("TAHAKKUK: basarida modal KAPANIR", async () => {
    sunucu(201);
    ciz(() => UnitDetail({ unit: DAIRE as never }));
    await tahakkukEkle(userEvent.setup());
    await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull());
  });

  it("TAHAKKUK: HATADA modal ACIK KALIR (kullanici duzeltebilsin)", async () => {
    // Kapanma kurali kor olmamali: basarisiz kayitta form kaybolursa
    // kullanici ne yazdigini da kaybeder.
    sunucu(409);
    ciz(() => UnitDetail({ unit: DAIRE as never }));
    await tahakkukEkle(userEvent.setup());
    await waitFor(() =>
      expect(screen.getByRole("dialog")).toBeInTheDocument(),
    );
  });

  it("TAHAKKUK: basari bildirimi CEVRILMIS metinle gelir", async () => {
    // Eskiden `setAOk("Tahakkuk eklendi.")` — SABIT TURKCE idi ve
    // modal kapaninca zaten gorunmez olurdu.
    sunucu(201);
    ciz(() => UnitDetail({ unit: DAIRE as never }));
    await tahakkukEkle(userEvent.setup());
    expect(await screen.findByText(/tahakkuk eklendi/i)).toBeInTheDocument();
  });

  it("UC MODAL da AYNI kurali izler (kaynak kilidi)", async () => {
    // Davranisi uc ayri akisi surerek olcmek bu testin degerinden cok
    // suresini buyuturdu; olculen sey UCUNDE DE kapatma cagrisinin
    // BULUNMASI — biri unutulursa kilit haber verir.
    const { readFileSync } = await import("node:fs");
    const { resolve } = await import("node:path");
    const kaynak = readFileSync(
      resolve(__dirname, "../components/UnitDetail.tsx"), "utf8");
    for (const kapat of ["setAOpen(false)", "setPOpen(false)", "setROpen(false)"]) {
      expect(kaynak, `${kapat} yok`).toContain(kapat);
    }
  });
});
