// @vitest-environment jsdom
// (P43) Yonetisim sayfasi — SITE AKTARIMININ istemci tarafi.
//
// Sunucu XLSX ayristirmaz (saldiri yuzeyi); satirlari PANEL cozer. Bu
// donusum yanlis olursa sunucu dogru calissa bile kurulum bozulur — ve
// hicbir backend testi bunu gormez.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import YonetisimPage from "@/app/(protected)/yonetisim/page";

import { cagrilanUrller, ciz, fetchSahtele } from "./yardimci";

const BOS = { meta: { limit: 50, offset: 0, total: 0 }, items: [] };

function sahtele(): void {
  fetchSahtele({
    "/api/panel/karar-defteri": BOS,
    "/api/panel/dokumanlar": BOS,
    "/api/panel/kvkk-metinler": [],
    "/api/panel/unit-uyarilari": BOS,
    "/api/panel/site-aktar": {
      blok_olusan: 1, daire_olusan: 2, kisi_olusan: 0, hatalar: [],
    },
  });
}

afterEach(() => vi.restoreAllMocks());

describe("Site aktarimi (istemci ayristirmasi)", () => {
  it("KURU CALISMA varsayilan ACIK ve govdede yalniz_dogrula=true gider", async () => {
    sahtele();
    ciz(YonetisimPage);
    await waitFor(() => expect(screen.getByText("Karar defteri")).toBeInTheDocument());

    const kutu = screen.getByRole("checkbox", { name: /Önce yalnızca doğrula/ });
    expect(kutu).toBeChecked();
    expect(screen.getByRole("button", { name: "Doğrula" })).toBeInTheDocument();
  });

  it("`;` VE TAB ayiricilarinin IKISI de calisir", async () => {
    // Excel'den kopyalama TAB uretir, elle yazan `;` kullanir; birini
    // desteklemek digerini sessizce BOS SATIRA cevirirdi.
    sahtele();
    const govdeler: unknown[] = [];
    const oncekiFetch = globalThis.fetch;
    globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
      if (String(girdi).includes("site-aktar") && init?.body) {
        govdeler.push(JSON.parse(String(init.body)));
      }
      return oncekiFetch(girdi, init);
    }) as typeof fetch;

    ciz(YonetisimPage);
    await waitFor(() => expect(screen.getByText("Excel ile site aktarımı")).toBeInTheDocument());

    const alan = screen.getByRole("textbox", { name: "" }) as HTMLTextAreaElement;
    void alan;
    const metinKutulari = screen.getAllByRole("textbox");
    const aktarKutusu = metinKutulari[metinKutulari.length - 1];
    await userEvent.click(aktarKutusu);
    await userEvent.paste("A;A-1;Ali Veli;+905321112233;malik\nB\tB-2");
    await userEvent.click(screen.getByRole("button", { name: "Doğrula" }));

    await waitFor(() => expect(govdeler.length).toBe(1));
    const g = govdeler[0] as { yalniz_dogrula: boolean; satirlar: Record<string, unknown>[] };
    expect(g.yalniz_dogrula).toBe(true);
    expect(g.satirlar).toHaveLength(2);
    // SATIR NUMARASI 2'DEN BASLAR: kullanicinin dosyasinda 1. satir
    // basliktir ve hata raporundaki numara Excel'deki satirla ORTUSMELI.
    expect(g.satirlar[0].satir_no).toBe(2);
    expect(g.satirlar[1].satir_no).toBe(3);
    expect(g.satirlar[0]).toMatchObject({
      blok: "A", daire_no: "A-1", ad: "Ali Veli", rol_tipi: "malik",
    });
    // TAB ile ayrilan satir da COZULDU.
    expect(g.satirlar[1]).toMatchObject({ blok: "B", daire_no: "B-2" });
    // Eksik alanlar null — bos dizge gondermek sunucuda "bos ad" 422'si
    // uretirdi.
    expect(g.satirlar[1].ad).toBeNull();
  });

  it("BOS metinle aktarim istegi ATILMAZ", async () => {
    sahtele();
    ciz(YonetisimPage);
    await waitFor(() => expect(screen.getByText("Excel ile site aktarımı")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: "Doğrula" }));
    await waitFor(() =>
      expect(screen.getByText("Aktarılacak satır yok.")).toBeInTheDocument(),
    );
    expect(cagrilanUrller().some((u) => u.includes("site-aktar"))).toBe(false);
  });
});
