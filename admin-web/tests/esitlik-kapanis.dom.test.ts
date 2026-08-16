// @vitest-environment jsdom
// (P162 §5) SON UC WEB/MOBIL FARKI — kapanis kilidi.
//
// `docs/web-mobil-esitlik.md`de olculen son uc fark:
//   1. ziyaretci kaydi duzenleme (mobilde var, webde yoktu),
//   2. dis hizmet duzenleme + silme (mobilde var, webde yoktu),
//   3. kargo TESLIM ALMA (mobilde var, webde yoktu).
//
// UCUNCU FARK OLCULURKEN TABLO DUZELDI: kaba fiil sayimi "kargo PATCH
// mobilde var" diyordu ve bunu GUVENLIK ekraninin eksigi sanmistim.
// Sunucuya bakinca `PATCH /kargo/{id}` kapisinin `_RESIDENT` oldugu
// gorundu — yani o bir SAKIN eylemi. Dogru kapanis, guvenlik ekranina
// dugme koymak degil, SAKININ o listede kendi kargosunu isaretleyebilmesi.
// (`GET /kargo` zaten rol kapsamli: sakin yalnizca kendi dairelerininkini
// gorur.)
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import DisHizmetlerPage from "@/app/(protected)/dis-hizmetler/page";
import KargolarPage from "@/app/(protected)/kargolar/page";
import ZiyaretcilerPage from "@/app/(protected)/ziyaretciler/page";

import { ciz } from "./yardimci";

interface Cagri {
  url: string;
  yontem: string;
  govde: unknown;
}

/** `harita`: url oneki -> yanit govdesi. */
function taklit(harita: Record<string, unknown>): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const yontem = init?.method ?? "GET";
    cagrilar.push({ url, yontem, govde: init?.body ? JSON.parse(String(init.body)) : null });
    if (yontem !== "GET") {
      return new Response(JSON.stringify({ id: "x" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
    const anahtar = Object.keys(harita)
      .filter((k) => url.startsWith(k))
      .sort((a, b) => b.length - a.length)[0];
    return new Response(JSON.stringify(anahtar ? harita[anahtar] : { items: [] }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

afterEach(() => vi.restoreAllMocks());

const ZIYARETCI = {
  id: "z1",
  ziyaretci_ad: "Ali Veli",
  unit_no: "A-3",
  notlar: "Kargo",
  giris_zamani: "2026-08-15T10:00:00Z",
  cikis_zamani: null,
};

const HIZMET = {
  id: "h1",
  tur: "Tesisatçı",
  ad: "Mehmet",
  soyad: "Kaya",
  telefon: "+905321112203",
  aciklama: null,
};

const KARGO_BEKLEYEN = {
  id: "k1",
  unit_no: "A-3",
  durum: "bekliyor",
  firma: "Yurtiçi",
  notlar: null,
  created_at: "2026-08-15T10:00:00Z",
};

describe("(P162) 1. ziyaretci kaydi DUZENLENEBILIR", () => {
  it("duzenle ON DOLU acilir ve PATCH eder", async () => {
    const c = taklit({ "/api/visitors": { items: [ZIYARETCI] } });
    ciz(ZiyaretcilerPage);
    await waitFor(() => expect(screen.getByText("Ali Veli")).toBeInTheDocument());

    await userEvent.click(screen.getByRole("button", { name: "Düzenle" }));
    const kutu = within(await screen.findByRole("dialog"));
    // Form ON DOLU gelmeli; bos acilsaydi "duzenleme" silip yeniden
    // yazmaya donusurdu ve kayit kimligi korunsa da veri kaybi olurdu.
    expect(kutu.getByDisplayValue("Ali Veli")).toBeInTheDocument();
    expect(kutu.getByDisplayValue("A-3")).toBeInTheDocument();

    await userEvent.click(kutu.getByRole("button", { name: "Kaydet" }));
    await waitFor(() => {
      const p = c.find((x) => x.yontem === "PATCH");
      expect(p, "PATCH atilmadi").toBeTruthy();
      expect(p!.url).toContain("/api/visitors/z1");
    });
  });

  it("DUZENLEME CIKISTAN BAGIMSIZ — cikmis kayitta da var", async () => {
    taklit({ "/api/visitors": { items: [{ ...ZIYARETCI, cikis_zamani: "2026-08-15T12:00:00Z" }] } });
    ciz(ZiyaretcilerPage);
    await waitFor(() => expect(screen.getByText("Ali Veli")).toBeInTheDocument());
    // Yanlis yazilan bir ad, ziyaretci ciktiktan SONRA da duzeltilebilmeli.
    expect(screen.getByRole("button", { name: "Düzenle" })).toBeInTheDocument();
    // Cikis dugmesi ise ARTIK YOK (ikinci kez damgalanmaz).
    expect(screen.queryByRole("button", { name: "Çıkış" })).toBeNull();
  });
});

describe("(P162) 2. dis hizmet DUZENLENEBILIR ve SILINEBILIR", () => {
  it("duzenle ON DOLU acilir ve PATCH eder", async () => {
    const c = taklit({ "/api/external-services": { items: [HIZMET] } });
    ciz(DisHizmetlerPage);
    await waitFor(() => expect(screen.getByText(/Mehmet/)).toBeInTheDocument());

    await userEvent.click(screen.getByRole("button", { name: "Düzenle" }));
    const kutu = within(await screen.findByRole("dialog"));
    expect(kutu.getByDisplayValue("Mehmet")).toBeInTheDocument();
    await userEvent.click(kutu.getByRole("button", { name: /Kaydet|Ekle/ }));

    await waitFor(() => {
      const p = c.find((x) => x.yontem === "PATCH");
      expect(p, "PATCH atilmadi").toBeTruthy();
      expect(p!.url).toContain("/api/external-services/h1");
    });
  });

  it("SILME once ONAY sorar — iptal edilirse istek ATILMAZ", async () => {
    const c = taklit({ "/api/external-services": { items: [HIZMET] } });
    ciz(DisHizmetlerPage);
    await waitFor(() => expect(screen.getByText(/Mehmet/)).toBeInTheDocument());

    await userEvent.click(screen.getByRole("button", { name: "Sil" }));
    const kutu = within(await screen.findByRole("dialog"));
    await userEvent.click(kutu.getByRole("button", { name: "İptal" }));
    expect(c.some((x) => x.yontem === "DELETE")).toBe(false);
  });
});

describe("(P162) 3. kargo TESLIM ALMA — SAKIN eylemi", () => {
  it("SAKIN bekleyen kargoyu teslim alabilir", async () => {
    const c = taklit({
      "/api/kargo": { items: [KARGO_BEKLEYEN] },
      "/api/me": { role: "resident" },
    });
    ciz(KargolarPage);
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Teslim aldım" })).toBeInTheDocument(),
    );
    await userEvent.click(screen.getByRole("button", { name: "Teslim aldım" }));

    await waitFor(() => {
      const p = c.find((x) => x.yontem === "PATCH");
      expect(p, "PATCH atilmadi").toBeTruthy();
      expect(p!.url).toContain("/api/kargo/k1");
      // Tek gecerli hedef durum; geri donus yok.
      expect(p!.govde).toEqual({ durum: "teslim_alindi" });
    });
  });

  it("GUVENLIKTE dugme YOK — o bir SAKIN eylemi", async () => {
    // Sunucu zaten 404 doner (`_RESIDENT`); dugme gostermek "yetkim var
    // sandim" demektir.
    taklit({ "/api/kargo": { items: [KARGO_BEKLEYEN] }, "/api/me": { role: "security" } });
    ciz(KargolarPage);
    await waitFor(() => expect(screen.getByText("A-3")).toBeInTheDocument());
    expect(screen.queryByRole("button", { name: "Teslim aldım" })).toBeNull();
  });

  it("TESLIM ALINMIS kargoda dugme YOK (ikinci damga olmaz)", async () => {
    taklit({
      "/api/kargo": { items: [{ ...KARGO_BEKLEYEN, durum: "teslim_alindi" }] },
      "/api/me": { role: "resident" },
    });
    ciz(KargolarPage);
    await waitFor(() => expect(screen.getByText("A-3")).toBeInTheDocument());
    expect(screen.queryByRole("button", { name: "Teslim aldım" })).toBeNull();
  });
});
