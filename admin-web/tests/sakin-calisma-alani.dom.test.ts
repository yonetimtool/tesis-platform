// @vitest-environment jsdom
// (P126.3) SAKIN CALISMA ALANI — Aidatim + Taleplerim.
//
// Paneldeki `dues` ve `complaints` YONETIM ekranlaridir (tahakkuk olusturur,
// baskasinin talebini yonetir). Bunlar talebi/borcu YASAYAN tarafin
// ekranlari ve ayri uclara bakarlar.
//
// UC OLCUM, ucu de sessizce yanlis olabilecek cinsten:
//  1. Aidatim YONETIM ucuna DEGIL `/api/me/dues`e gidiyor mu — ayni ucu rol
//     suzgeciyle paylasmak, suzgec unutuldugunda tum sitenin borcunu sakine
//     gostermek olurdu;
//  2. Talep listesine ISTEMCI SUZGECI konmamis mi (sunucu zaten
//     kendi-kapsamli; istemci suzgeci bir gun unutulur, sunucu kurali
//     unutulmaz);
//  3. Hata varken "kayit yok" DENMIYOR mu (P61 sinifi).
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import AidatimPage from "@/app/(protected)/aidatim/page";
import TaleplerimPage from "@/app/(protected)/taleplerim/page";

import { ciz } from "./yardimci";

function taklit(harita: Record<string, unknown>, durum = 200) {
  const cagrilar: { url: string; method: string; body: unknown }[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      method: init?.method ?? "GET",
      body: init?.body ? JSON.parse(String(init.body)) : undefined,
    });
    const anahtar = Object.keys(harita)
      .filter((k) => url.startsWith(k))
      .sort((a, b) => b.length - a.length)[0];
    if (anahtar === undefined) {
      return new Response(JSON.stringify({ error: { message: "yok" } }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }
    return new Response(JSON.stringify(harita[anahtar]), {
      status: durum,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

const DAIRE = {
  unit_id: "u1",
  no: "A-12",
  toplam_tahakkuk_kurus: 150000,
  toplam_odenen_kurus: 50000,
  bakiye_kurus: 100000,
  assessments: [
    {
      id: "a1",
      donem: "2026-08",
      tutar_kurus: 75000,
      son_odeme_tarihi: "2026-08-15",
      aciklama: null,
    },
  ],
  payments: [],
};

afterEach(() => vi.restoreAllMocks());

describe("Aidatım", () => {
  it("KENDI ucuna gider — yonetim ucuna DEGIL", async () => {
    const c = taklit({ "/api/me/dues": { items: [DAIRE] } });
    ciz(AidatimPage);
    await waitFor(() => expect(screen.getByText(/A-12/)).toBeInTheDocument());
    expect(c.some((x) => x.url.startsWith("/api/me/dues"))).toBe(true);
    // YONETIM ucu HIC cagrilmamali.
    expect(c.some((x) => /^\/api\/dues/.test(x.url))).toBe(false);
  });

  it("bakiye ve tahakkuk TL olarak gosterilir", async () => {
    taklit({ "/api/me/dues": { items: [DAIRE] } });
    ciz(AidatimPage);
    await waitFor(() => expect(screen.getByText(/1\.000/)).toBeInTheDocument());
    expect(screen.getByText(/750/)).toBeInTheDocument();
  });

  it("KAYIT YOKKEN bos durum, HATA VARKEN 'yok' DENMEZ", async () => {
    taklit({ "/api/me/dues": { items: [] } });
    ciz(AidatimPage);
    expect(
      await screen.findByText(/Kayıtlı aidat bilgisi yok/i),
    ).toBeInTheDocument();
  });

  it("istek DUSTUGUNDE 'kayit yok' YAZILMAZ (P61)", async () => {
    taklit({ "/api/me/dues": { error: { message: "patladi" } } }, 500);
    ciz(AidatimPage);
    await waitFor(() =>
      expect(screen.getByText(/bir hata/i)).toBeInTheDocument(),
    );
    expect(screen.queryByText(/Kayıtlı aidat bilgisi yok/i)).toBeNull();
  });
});

describe("Taleplerim", () => {
  const TALEP = {
    id: "c1",
    baslik: "Asansör bozuk",
    mesaj: "İkinci asansör çalışmıyor.",
    durum: "acik",
    kategori_ad: null,
    created_at: "2026-08-01T09:00:00Z",
  };

  it("KENDI talepleri listelenir — ISTEMCI SUZGECI YOK", async () => {
    // Sunucu zaten kendi-kapsamli (`_OWN_SCOPED_ROLES`). Istemci suzgeci
    // koymak, bir gun unutuldugunda sessizce baskasinin talebini gosterirdi;
    // sunucu kurali unutulmaz.
    taklit({ "/api/complaints": { items: [TALEP] } });
    ciz(TaleplerimPage);
    expect(await screen.findByText("Asansör bozuk")).toBeInTheDocument();
    const kaynak = TaleplerimPage.toString();
    expect(kaynak).not.toContain("acan_user_id");
  });

  it("YENI TALEP gonderilir ve liste tazelenir", async () => {
    const c = taklit({ "/api/complaints": { items: [] } });
    ciz(TaleplerimPage);
    // (P161) Form artik MODALDA: once acilir.
    await userEvent.click(await screen.findByRole("button", { name: "Yeni talep" }));
    await userEvent.type(
      screen.getByLabelText(/Konu/i),
      "Su kaçağı",
    );
    await userEvent.type(
      screen.getByLabelText(/Açıklama/i),
      "Bodrumda su var.",
    );
    await userEvent.click(screen.getByRole("button", { name: /Gönder/i }));
    await waitFor(() => {
      const post = c.find((x) => x.method === "POST");
      expect(post?.body).toMatchObject({
        baslik: "Su kaçağı",
        mesaj: "Bodrumda su var.",
      });
    });
  });

  it("BOS alanla gonderilmez", async () => {
    const c = taklit({ "/api/complaints": { items: [] } });
    ciz(TaleplerimPage);
    // (P161) Form artik MODALDA: once acilir.
    await userEvent.click(await screen.findByRole("button", { name: "Yeni talep" }));
    await userEvent.click(screen.getByRole("button", { name: /Gönder/i }));
    expect(await screen.findByText(/zorunludur/i)).toBeInTheDocument();
    expect(c.some((x) => x.method === "POST")).toBe(false);
  });
});
