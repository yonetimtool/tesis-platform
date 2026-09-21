// @vitest-environment jsdom
//
// (P244 §8b) TALEP TRIYAJ EKRANI — LISTE HAFIFLEDI, EYLEM KALDI.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// Her talep listede TAM ACIK duruyordu: tam mesaj + butun fotograflar +
// butun durum gecmisi. Yirmi talep = yirmi duvar ve "hangisi acik"
// sorusu ancak kaydirarak yanitlaniyordu.
//
// ===========================================================================
// KARARIN IKI YARISI — VE IKISI DE KILITLI
// ===========================================================================
// 1. AGIR OLAN CEKMECEYE: mesaj, fotograflar, durum gecmisi listede
//    DEGIL, detay cekmecesinde.
// 2. EYLEM SATIRDA KALDI: bu ekranin isi triyaj; "Coz"u cekmecenin
//    icine koymak her karara bir acma-kapama adimi eklerdi.
//
// Ikisi birlikte olculmezse tasarim yanlis tarafa kayar: yalniz (1)
// olculse eylemler de cekmeceye tasinabilirdi; yalniz (2) olculse liste
// yine duvar kalirdi.
import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import ComplaintsPage from "@/app/(protected)/complaints/page";

import { ciz, fetchSahtele } from "./yardimci";

const MESAJ = "Mutfak musluğu damlıyor";
const SEBEP_METNI = "Yetki alanımız dışında";

function talep(over: Record<string, unknown> = {}) {
  return {
    id: "t1",
    acan_user_id: "u1",
    acan_ad: "Ali Veli",
    baslik: "Musluk akıtıyor",
    mesaj: MESAJ,
    kategori_id: null,
    kategori_ad: null,
    durum: "acik",
    fotograflar: [],
    gecmis: [
      {
        durum: "acik",
        actor_role: "resident",
        sebep: SEBEP_METNI,
        created_at: "2026-08-01T08:00:00Z",
      },
    ],
    is_emri_id: null,
    is_emri_durum: null,
    created_at: "2026-08-01T08:00:00Z",
    updated_at: "2026-08-01T08:00:00Z",
    ...over,
  };
}

function kur(over: Record<string, unknown> = {}) {
  fetchSahtele({
    "/api/complaints": { meta: { limit: 20, offset: 0, total: 1 }, items: [talep(over)] },
  });
}

afterEach(() => vi.restoreAllMocks());

describe("(P244 §8b) talep triyaj ekrani", () => {
  it("LISTE TABLO — kayitlar gercek satir/sutun iliskisinde", async () => {
    kur();
    const hucre = await (async () => {
      ciz(ComplaintsPage);
      return screen.findByRole("cell", { name: "Musluk akıtıyor" });
    })();
    expect(hucre.closest("table"), "talepler tabloda degil").not.toBeNull();
  });

  it("AGIR ICERIK LISTEDE DEGIL: mesaj ve gecmis cekmece acilmadan GORUNMEZ", async () => {
    kur();
    ciz(ComplaintsPage);
    await screen.findByRole("cell", { name: "Musluk akıtıyor" });
    // Tam mesaj ve durum gecmisi sebebi listede YOK.
    expect(screen.queryByText(MESAJ)).toBeNull();
    expect(screen.queryByText(SEBEP_METNI)).toBeNull();
    expect(screen.queryByText(/Durum geçmişi/i)).toBeNull();
  });

  it("CEKMECE ACILINCA mesaj ve durum gecmisi GORUNUR", async () => {
    kur();
    ciz(ComplaintsPage);
    await screen.findByRole("cell", { name: "Musluk akıtıyor" });
    await userEvent.click(screen.getByRole("button", { name: "Detay" }));
    const cekmece = await screen.findByRole("dialog");
    expect(within(cekmece).getByText(MESAJ)).toBeInTheDocument();
    expect(within(cekmece).getByText(/Durum geçmişi/i)).toBeInTheDocument();
    expect(within(cekmece).getByText(SEBEP_METNI)).toBeInTheDocument();
  });

  it("EYLEM SATIRDA — cekmece acmadan Coz/Reddet erisilebilir", async () => {
    kur();
    ciz(ComplaintsPage);
    const hucre = await screen.findByRole("cell", { name: "Musluk akıtıyor" });
    const satir = hucre.closest("tr")!;
    expect(within(satir).getByRole("button", { name: "Çöz" })).toBeInTheDocument();
    expect(within(satir).getByRole("button", { name: "Reddet" })).toBeInTheDocument();
  });

  it("CEKMECE KARAR VERDIRMEZ: icinde Coz/Reddet YOK (tek karar noktasi)", async () => {
    // Ayni eylemi iki yerde sunmak, "hangisi gecerli" sorusunu ureten
    // ikinci bir karar noktasi olurdu.
    kur();
    ciz(ComplaintsPage);
    await screen.findByRole("cell", { name: "Musluk akıtıyor" });
    await userEvent.click(screen.getByRole("button", { name: "Detay" }));
    const cekmece = await screen.findByRole("dialog");
    expect(within(cekmece).queryByRole("button", { name: "Çöz" })).toBeNull();
    expect(within(cekmece).queryByRole("button", { name: "Reddet" })).toBeNull();
  });

  it("KAPALI talepte satirda karar dugmesi YOK (409 aldirilmaz)", async () => {
    kur({ durum: "cozuldu" });
    ciz(ComplaintsPage);
    const hucre = await screen.findByRole("cell", { name: "Musluk akıtıyor" });
    const satir = hucre.closest("tr")!;
    expect(within(satir).queryByRole("button", { name: "Çöz" })).toBeNull();
    // Detay yine acilabilir — okumak bir karar degildir.
    expect(within(satir).getByRole("button", { name: "Detay" })).toBeInTheDocument();
  });
});
