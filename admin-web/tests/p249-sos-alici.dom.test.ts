// @vitest-environment jsdom
// (P249 §1b) SOS — ALICININ GORDUGU (web gelen alarm katmani).
//
// P243'te bu katman sabit "ACIL DURUM CAGRISI" ciziyordu ve kategoriyi
// hic okumuyordu; hicbir test kirmizi olmadi cunku testler GONDEREN ucu
// olcuyordu. Burada olculen: toplu uyari ile yardim cagrisi FARKLI
// ekranlar, baslik ve talimat SUNUCUDAN, toplu uyarida karar
// "Guvendeyim / Yardima ihtiyacim var".
import { waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import { describe, expect, it } from "vitest";

import { PanikAlarmi } from "@/components/panik/panik-alarmi";

import { ciz } from "./yardimci";

const el = (ad: string) => document.querySelector(`[data-test="${ad}"]`);

let cagrilar: string[] = [];

function taklit(aktif: unknown[]) {
  cagrilar = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push(`${(init?.method ?? "GET").toUpperCase()} ${url}`);
    const govde = url === "/api/panik/aktif" ? aktif : { ok: true };
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  }) as typeof fetch;
}

const TABAN = {
  olusturan_ad: "Yönetim",
  olusturan_telefon: null,
  daire_no: null,
  blok: null,
  checkpoint_ad: null,
  gps_lat: null,
  gps_lng: null,
  aciklama: null,
  son_24s_yanlis_alarm: 0,
  benim_yanitim: null,
  gonderildi_at: "2026-09-29T11:04:00Z",
  created_at: "2026-09-29T11:04:00Z",
};

const DEPREM = {
  ...TABAN,
  id: "d1",
  tip: "yonetici_anons",
  durum: "acik",
  kategori: "deprem",
  toplu: true,
  baslik: "DEPREM ALARMI",
  talimat: ["ÇÖK, KAPAN, TUTUN.", "Pencerelerden uzak durun.", "Asansör kullanmayın."],
};

const SAGLIK = {
  ...TABAN,
  id: "s1",
  tip: "sakin",
  durum: "acik",
  kategori: "saglik",
  toplu: false,
  baslik: "SAĞLIK ACİLİ",
  talimat: ["112 arandı mı kontrol edin."],
  olusturan_ad: "Ayşe Yılmaz",
  daire_no: "A-12",
  blok: "A",
  son_24s_yanlis_alarm: 2,
};

describe("(P249 §1b) iki deneyim", () => {
  it("TOPLU UYARI: kategori basligi + adim adim talimat + GUVENDEYIM; Gidiyorum YOK", async () => {
    taklit([DEPREM]);
    ciz(PanikAlarmi);
    await waitFor(() => expect(el("panik-toplu")).toBeTruthy());
    expect(el("panik-baslik")?.textContent).toBe("DEPREM ALARMI");
    expect(el("panik-talimat-0")?.textContent).toContain("ÇÖK");
    expect(el("panik-talimat-2")).toBeTruthy();
    expect(el("panik-guvendeyim")).toBeTruthy();
    expect(el("panik-yardim")).toBeTruthy();
    expect(el("panik-mudahale"), "toplu uyarida Gidiyorum anlamsiz").toBeNull();
    expect(el("panik-alarm-yanlis-sayaci")).toBeNull();
  });

  it("GUVENDEYIM ve YARDIM istekleri kendi uclarina gider", async () => {
    taklit([DEPREM]);
    ciz(PanikAlarmi);
    await waitFor(() => expect(el("panik-guvendeyim")).toBeTruthy());
    await userEvent.click(el("panik-guvendeyim") as HTMLElement);
    await waitFor(() => expect(cagrilar).toContain("POST /api/panik/d1/guvendeyim"));
    await userEvent.click(el("panik-yardim") as HTMLElement);
    await waitFor(() => expect(cagrilar).toContain("POST /api/panik/d1/yardim"));
  });

  it("YARDIM CAGRISI: kategori basligi, kim/nerede, Gidiyorum/Gordum", async () => {
    taklit([SAGLIK]);
    ciz(PanikAlarmi);
    await waitFor(() => expect(el("panik-yardim-cagrisi")).toBeTruthy());
    expect(el("panik-baslik")?.textContent).toBe("SAĞLIK ACİLİ");
    expect(el("panik-alarm-kim")?.textContent).toBe("Ayşe Yılmaz");
    expect(el("panik-talimat-0")?.textContent).toContain("112");
    expect(el("panik-mudahale")).toBeTruthy();
    expect(el("panik-guvendeyim")).toBeNull();
    expect(el("panik-alarm-yanlis-sayaci")).toBeTruthy();
  });
});
