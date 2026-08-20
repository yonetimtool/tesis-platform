// @vitest-environment jsdom
// (P174) JETON SURESI DOLMUSKEN SAYFA ACILISI — KULLANICI HATA GORMEZ.
//
// =========================================================================
// OLCULEN OLAY
// =========================================================================
// Sayfa acilisinda dort istek paralel gidiyor ve erisim jetonu dolmus:
//   /tenant/settings 401 · /me/profile 401 · /kurulum 401 ·
//   /notifications 401 · POST /auth/refresh 200 · ...hepsi 200
//
// Asil kusur VEKILDEYDI (`lib/backend.ts`, `tests/backend.test.ts`te
// kilitli): yenileme cozuldukten SONRA 401 alan istek, DONDURULMUS eski
// jetonla ikinci bir yenileme baslatiyor, backend "reuse" sayip
// reddediyor ve vekil 401 dondurup OTURUM CEREZLERINI SILIYORDU.
//
// Burada olculen sey EKRANIN TARAFI: vekil dogru davrandiginda kullanici
// hicbir hata gormemeli, VE gecici bir hata olsa bile ekran veri gelince
// KENDINI TOPARLAMALI.
//
// =========================================================================
// NEDEN AYRICA BU TEST
// =========================================================================
// "Toparlaniyor mu" sorusu VARSAYIMLA yanitlanmamali. Bir ekran SWR
// hatasini YEREL DURUMA kopyalasaydi kendiliginden temizlenmezdi —
// depoda taranip boyle bir yer OLMADIGI gorildi, ama iddia burada
// olculuyor. Kurulum sihirbazi temsilci olarak secildi (bildirilen ekran).
import { screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import KurulumPage from "@/app/(protected)/kurulum/page";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  usePathname: () => "/kurulum",
  useRouter: () => ({ replace: vi.fn(), refresh: vi.fn(), push: vi.fn() }),
  useSearchParams: () => new URLSearchParams(),
}));

afterEach(() => vi.unstubAllGlobals());

const DURUM = {
  gecilen: 2,
  toplam: 5,
  adimlar: [] as unknown[],
};

const HATA_METNI = /Kurulum durumu alınamadı/i;

describe("kurulum sihirbazi — jeton yenilendikten sonra", () => {
  it("VEKIL DOGRU CALISINCA hicbir hata gorunmez", async () => {
    // Vekil 401'i kendi icinde yenileyip tekrarladigi icin tarayici
    // YALNIZ 200 gorur — kullanicinin gormesi gereken sey budur.
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: true,
        status: 200,
        json: async () => DURUM,
      } as unknown as Response),
    );

    ciz(KurulumPage);

    await waitFor(() => expect(screen.queryByText(/2 \/ 5|2\/5/)).not.toBeNull());
    expect(screen.queryByText(HATA_METNI)).toBeNull();
  });

  it("GECICI HATADAN SONRA veri gelince hata TEMIZLENIR", async () => {
    // Ekran hatayi YEREL DURUMA kopyalasaydi burada takili kalirdi.
    const cagri = vi
      .fn()
      .mockResolvedValueOnce({
        ok: false,
        status: 500,
        json: async () => ({ error: { code: "server_error", message: "gecici" } }),
      } as unknown as Response)
      .mockResolvedValue({
        ok: true,
        status: 200,
        json: async () => DURUM,
      } as unknown as Response);
    vi.stubGlobal("fetch", cagri);

    ciz(KurulumPage);

    // Once hata gorunur.
    await waitFor(() => expect(screen.queryByText(HATA_METNI)).not.toBeNull());

    // SWR HATADA KENDILIGINDEN YENIDEN DENER (varsayilan
    // `errorRetryInterval` ~5 sn). Elle bir tetikleyici KULLANILMIYOR:
    // olculmek istenen sey tam olarak "kullanici hicbir sey yapmadan
    // toparlaniyor mu". `rerender` denendi ve YANLISTI — saglayicilarin
    // disina cikip `useI18n`i patlatiyor (olculdu).
    await waitFor(
      () => expect(screen.queryByText(HATA_METNI)).toBeNull(),
      { timeout: 12000 },
    );
    expect(screen.queryByText(/2 \/ 5|2\/5/)).not.toBeNull();
  }, 20000);
});
