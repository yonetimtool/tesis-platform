// @vitest-environment jsdom
// (P249 §2) TATBIKAT — web yuzeyi.
//
// Olculen: tatbikat alarmi gercek alarm katmaninda "TATBIKAT" seridiyle
// cizilir; yonetim planlar (zaman bos = hemen, saat dilimli zaman
// gonderilir); rapor penceresi PDF baglantisi tasir; yonetim olmayan
// planla dugmesini GORMEZ.
import { waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement } from "react";

import { describe, expect, it } from "vitest";

import { PanikAlarmi } from "@/components/panik/panik-alarmi";
import { TatbikatBolumu } from "@/components/panik/tatbikat-bolumu";

import { ciz } from "./yardimci";

const el = (ad: string) => document.querySelector(`[data-test="${ad}"]`);

let cagrilar: { url: string; metot: string; govde?: Record<string, unknown> }[] = [];

function taklit(yanitlar: Record<string, unknown>) {
  cagrilar = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const metot = (init?.method ?? "GET").toUpperCase();
    cagrilar.push({ url, metot, govde: init?.body ? JSON.parse(String(init.body)) : undefined });
    const govde = metot === "GET" ? (yanitlar[url] ?? { items: [] }) : { ok: true };
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  }) as typeof fetch;
}

const BITMIS = {
  id: "t1",
  kategori: "deprem",
  kapsam: "blok",
  blok: "A",
  planlanan_at: null,
  duyuru_gonderildi_at: null,
  durum: "bitti",
  basladi_at: "2026-09-29T11:00:00Z",
  bitis_nedeni: "elle",
  baslik: "Deprem tatbikatı",
  alarm_id: "a1",
};

describe("(P249 §2) tatbikat", () => {
  it("TATBIKAT ALARMI seritle cizilir", async () => {
    taklit({
      "/api/panik/aktif": [
        {
          id: "a1", tip: "yonetici_anons", durum: "acik", kategori: "deprem",
          toplu: true, tatbikat: true, baslik: "TATBİKAT — DEPREM ALARMI",
          talimat: ["ÇÖK, KAPAN, TUTUN."], benim_yanitim: null,
          olusturan_ad: null, olusturan_telefon: null, daire_no: null, blok: null,
          checkpoint_ad: null, gps_lat: null, gps_lng: null, aciklama: null,
          son_24s_yanlis_alarm: 0, gonderildi_at: null, created_at: "2026-09-29T11:00:00Z",
        },
      ],
    });
    ciz(PanikAlarmi);
    await waitFor(() => expect(el("panik-tatbikat-serit")).toBeTruthy());
    expect(el("panik-tatbikat-serit")?.textContent).toContain("TATBİKAT");
    expect(el("panik-baslik")?.textContent).toMatch(/^TATBİKAT/);
    expect(el("panik-guvendeyim")).toBeTruthy();
  });

  it("YONETIM hemen baslayan tatbikat planlar (zaman bos = planlanan_at null)", async () => {
    taklit({ "/api/tatbikat": [] });
    ciz(() => createElement(TatbikatBolumu, { yonetim: true }));
    await waitFor(() => expect(el("tatbikat-planla")).toBeTruthy());
    await userEvent.click(el("tatbikat-planla") as HTMLElement);
    await waitFor(() => expect(el("tatbikat-kaydet")).toBeTruthy());
    await userEvent.click(el("tatbikat-kaydet") as HTMLElement);
    await waitFor(() =>
      expect(cagrilar.some((c) => c.url === "/api/tatbikat" && c.metot === "POST")).toBe(true),
    );
    const post = cagrilar.find((c) => c.url === "/api/tatbikat" && c.metot === "POST");
    expect(post?.govde).toMatchObject({ kategori: "deprem", kapsam: "site", planlanan_at: null, duyuru: false });
  });

  it("YONETIM OLMAYAN planla dugmesini gormez; rapor PDF baglantisi tasir", async () => {
    taklit({ "/api/tatbikat": [BITMIS], "/api/tatbikat/t1": { tatbikat: BITMIS, push_denenen: 3, push_gonderildi: 2 },
      "/api/panik/a1/durum": { alici: 3, goruldu: 2, guvende: 2, yardim: 0, yanitsiz: 1, ortalama_yanit_sn: 40, daireler: [], personel: [] } });
    ciz(() => createElement(TatbikatBolumu, { yonetim: false }));
    await waitFor(() => expect(el("tatbikat-satir-t1")).toBeTruthy());
    expect(el("tatbikat-planla")).toBeNull();
    await userEvent.click(el("tatbikat-rapor-t1") as HTMLElement);
    await waitFor(() => expect(el("tatbikat-pdf")).toBeTruthy());
    expect(el("tatbikat-pdf")?.getAttribute("href")).toBe("/api/tatbikat/t1/rapor-pdf");
  });
});
