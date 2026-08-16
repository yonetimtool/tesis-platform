// @vitest-environment jsdom
// (P165) KAT SILME ETKI OZETI + REZERVASYON AKTIF/GECMIS AYRIMI.
//
// Iki bagimsiz kural, ikisi de "sessizce yanlis" sinifindan:
//
//  §1 KAT SILME: kat silmek `ON DELETE CASCADE` ile o kattaki dairelerin
//     SAKINLERINI, TAHAKKUKLARINI ve TAHSILATLARINI da goturur. Kullanici
//     ne kaybedecegini SILMEDEN ONCE gormeli; mali kayit varsa tek
//     tiklamayla gitmemeli.
//
//  §3 REZERVASYON: saati gecmis bir kayit iptal EDILEMEZ. Aktif/gecmis
//     ayrimi SUNUCUDA ve tesisin saat diliminde yapilir — cihaz saatine
//     guvenilmez.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import BuildingEditorPage from "@/app/(protected)/building-editor/page";
import RezervasyonlarimPage from "@/app/(protected)/rezervasyonlarim/page";

import { ciz } from "./yardimci";

interface Cagri {
  url: string;
  yontem: string;
}

const BLOK = { id: "b1", ad: "A", kat_sayisi: 3, unit_sayisi: 6 };
const DAIRE = { id: "u1", no: "A-1", blok: "A", kat: 2, sira: 1, aktif: true };

/** `onizleme`: `/api/units/kat-onizleme` yaniti. */
function taklitBina(onizleme: Record<string, unknown>): Cagri[] {
  const c: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    c.push({ url, yontem: init?.method ?? "GET" });
    const govde = url.startsWith("/api/units/kat-onizleme")
      ? onizleme
      : url.startsWith("/api/blocks")
        ? { items: [BLOK] }
        : url.startsWith("/api/units")
          ? { items: [DAIRE], meta: { total: 1, limit: 200, offset: 0 } }
          : { items: [] };
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return c;
}

afterEach(() => vi.restoreAllMocks());

/** Kat sil modalini acar ve blok/kat secer. */
async function katSilAc() {
  await userEvent.click(await screen.findByRole("button", { name: "Katı sil" }));
  const kutu = within(await screen.findByRole("dialog"));
  await userEvent.selectOptions(kutu.getByRole("combobox", { name: /Blok/ }), "A");
  await userEvent.type(kutu.getByRole("textbox", { name: /Kat/ }), "2");
  return kutu;
}

const BOS = {
  blok: "A", kat: 2, daire: 0, sakin: 0, tahakkuk: 0,
  odeme: 0, talep: 0, rezervasyon: 0, mali_kayit: false,
};
const DOLU = {
  blok: "A", kat: 2, daire: 4, sakin: 3, tahakkuk: 0,
  odeme: 0, talep: 2, rezervasyon: 1, mali_kayit: false,
};
const MALI = {
  blok: "A", kat: 2, daire: 4, sakin: 3, tahakkuk: 9,
  odeme: 5, talep: 0, rezervasyon: 0, mali_kayit: true,
};

describe("(P165 §1) kat silme — ETKI OZETI silmeden ONCE", () => {
  it("blok+kat secilince ONIZLEME ucuna gidilir", async () => {
    const c = taklitBina(DOLU);
    ciz(BuildingEditorPage);
    await katSilAc();
    await waitFor(() =>
      expect(c.some((x) => x.url.startsWith("/api/units/kat-onizleme"))).toBe(true),
    );
  });

  it("SOMUT SAYILAR gosterilir (daire, sakin, talep)", async () => {
    taklitBina(DOLU);
    ciz(BuildingEditorPage);
    await katSilAc();
    // "12 bagli kayit" bir sey soylemez; kategoriler ayri sayilir.
    expect(await screen.findByText(/4 daire/)).toBeInTheDocument();
    expect(screen.getByText(/3 sakin/)).toBeInTheDocument();
  });

  it("BOS KAT icin 'etkilenen kayit yok' denir", async () => {
    taklitBina(BOS);
    ciz(BuildingEditorPage);
    await katSilAc();
    // Bos kat 404 DEGIL sifirlarla doner; ekran da bunu boyle soyler.
    expect(await screen.findByText(/daire yok/i)).toBeInTheDocument();
  });

  it("MALI KAYIT varsa AYRI UYARI cikar", async () => {
    taklitBina(MALI);
    ciz(BuildingEditorPage);
    await katSilAc();
    // Sakin yeniden olusturulabilir, bir tahsilat kaydi olusturulamaz.
    expect(await screen.findByText(/muhasebe izi/i)).toBeInTheDocument();
  });

  it("MALI KAYITTA Sil dugmesi KAPALI — kat numarasi yazilmadan acilmaz", async () => {
    taklitBina(MALI);
    ciz(BuildingEditorPage);
    const kutu = await katSilAc();
    await waitFor(() => expect(screen.getByText(/muhasebe izi/i)).toBeInTheDocument());
    expect(kutu.getByRole("button", { name: "Sil" })).toBeDisabled();

    // Dogru kat numarasi yazilinca ACILIR: islev kaldirilmadi, yalnizca
    // kaza ile olmasi engellendi.
    await userEvent.type(kutu.getByRole("textbox", { name: /kat numarasını yazın/i }), "2");
    await waitFor(() => expect(kutu.getByRole("button", { name: "Sil" })).toBeEnabled());
  });

  it("MALI KAYIT YOKSA Sil dugmesi ACIK (gereksiz surtunme yok)", async () => {
    taklitBina(DOLU);
    ciz(BuildingEditorPage);
    const kutu = await katSilAc();
    await waitFor(() => expect(screen.getByText(/4 daire/)).toBeInTheDocument());
    expect(kutu.getByRole("button", { name: "Sil" })).toBeEnabled();
  });
});

// ---------------------------------------------------------------------------

const AKTIF_KAYIT = {
  id: "r1", alan_ad: "Spor salonu", tarih: "2026-09-01",
  baslangic: "10:00", bitis: "11:00", kisi_sayisi: 2,
  durum: "onaylandi", gecmis: false,
};
const GECMIS_KAYIT = { ...AKTIF_KAYIT, id: "r2", gecmis: true };
const GECMIS_IPTAL = { ...AKTIF_KAYIT, id: "r3", gecmis: true, durum: "iptal" };

function taklitRezervasyon(kayit: unknown): Cagri[] {
  const c: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    c.push({ url, yontem: init?.method ?? "GET" });
    return new Response(JSON.stringify({ items: [kayit] }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return c;
}

describe("(P165 §3) rezervasyon — aktif / gecmis", () => {
  it("AYRIM SUNUCUDAN sorulur (`?gecmis=`)", async () => {
    const c = taklitRezervasyon(AKTIF_KAYIT);
    ciz(RezervasyonlarimPage);
    // Istemci kendi saatiyle suzmez: cihaz saati yanlis olabilir ve
    // `tarih + bitis` ancak TESISIN saat diliminde bir ANA donusur.
    await waitFor(() =>
      expect(c.some((x) => x.url.includes("gecmis=false"))).toBe(true),
    );
  });

  it("GECMIS sekmesi sunucuya `gecmis=true` sorar", async () => {
    const c = taklitRezervasyon(GECMIS_KAYIT);
    ciz(RezervasyonlarimPage);
    await userEvent.click(await screen.findByRole("tab", { name: "Geçmiş" }));
    await waitFor(() =>
      expect(c.some((x) => x.url.includes("gecmis=true"))).toBe(true),
    );
  });

  it("AKTIF kayitta 'İptal et' VAR", async () => {
    taklitRezervasyon(AKTIF_KAYIT);
    ciz(RezervasyonlarimPage);
    expect(await screen.findByRole("button", { name: "İptal et" })).toBeInTheDocument();
  });

  it("GECMIS kayitta 'İptal et' YOK — yerine SALT-OKUNUR durum", async () => {
    taklitRezervasyon(GECMIS_KAYIT);
    ciz(RezervasyonlarimPage);
    await waitFor(() => expect(screen.getByText("Spor salonu")).toBeInTheDocument());
    // Bildirilen kusur tam olarak buydu: gecmis kaydin altinda "Iptal et".
    expect(screen.queryByRole("button", { name: "İptal et" })).toBeNull();
    expect(screen.getByText("Tamamlandı")).toBeInTheDocument();
  });

  it("GECMIS + IPTAL kayitta 'İptal edildi' yazar", async () => {
    taklitRezervasyon(GECMIS_IPTAL);
    ciz(RezervasyonlarimPage);
    await waitFor(() => expect(screen.getByText("Spor salonu")).toBeInTheDocument());
    expect(screen.getByText("İptal edildi")).toBeInTheDocument();
  });

  it("BAYRAK SEKMEDEN BAGIMSIZ: aktif sekmede gecmise dusen kayitta dugme yok", async () => {
    // Sayfa acikken bitis saati gecebilir. Kosul sekme degil, sunucunun
    // her kayit icin dondugu `gecmis` bayragi.
    taklitRezervasyon(GECMIS_KAYIT);
    ciz(RezervasyonlarimPage);
    await waitFor(() => expect(screen.getByText("Spor salonu")).toBeInTheDocument());
    expect(screen.queryByRole("button", { name: "İptal et" })).toBeNull();
  });
});
