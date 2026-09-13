// @vitest-environment jsdom
// (P229 §3) GOREV TAMAMLAMA BILGISI — web yuzeyi.
//
// =========================================================================
// OLCULEN IKI KUSUR
// =========================================================================
// 1. `Task` semasi tamamlama hakkinda HICBIR SEY tasimiyordu: liste
//    "tamamlandi mi" sorusunu yanitlayamiyordu. Ayrinti panelindeki
//    tamamlama tablosu vardi ama her gorev icin TEK TEK acmak gerekiyordu.
// 2. BFF rotasi `app/api/tasks/[id]/completions/route.ts` YALNIZ POST
//    export ediyordu. Sayfa GET ile okuyordu, yani istek 405 aliyordu ve
//    tablo HIC DOLMUYORDU. Arka uc dogru, sayfa dogru, ORTA HALKA eksik —
//    P189 ve P226'da olculen sinifin aynisi.
import { describe, expect, it } from "vitest";

import { tr as trSozluk } from "@/lib/i18n/sozluk/tr";

describe("(P229 §3) BFF rotasi metotlari", () => {
  it("completions rotasi GET DE export eder (yoksa tablo 405 alir)", async () => {
    const rota = await import("@/app/api/tasks/[id]/completions/route");
    expect(typeof rota.GET, "GET eksik — sayfa 405 alir").toBe("function");
    expect(typeof rota.POST).toBe("function");
  });

  it("GERI ALMA rotasi DELETE export eder", async () => {
    const rota = await import(
      "@/app/api/tasks/[id]/completions/[completionId]/route"
    );
    expect(typeof rota.DELETE).toBe("function");
  });
});

describe("(P229 §3) 7 dil paritesi", () => {
  const ANAHTARLAR = [
    "gorevTamamlamaDurumu",
    "gorevTamamlandiRozet",
    "gorevAcikRozet",
    "gorevTamamlamayiGeriAl",
    "gorevTamamlamaGeriAlOnay",
  ] as const;

  it("yeni anahtarlar YEDI DILDE de var ve Turkce KOPYASI degil", async () => {
    const diller = ["en", "de", "fr", "es", "ru", "ar"] as const;
    for (const d of diller) {
      const mod = (await import(`@/lib/i18n/sozluk/${d}`)) as Record<string, unknown>;
      const s = mod[d] as Record<string, string>;
      for (const k of ANAHTARLAR) {
        expect(s[k], `${d}.${k} eksik`).toBeTruthy();
        // Cevrilmemis anahtar sessizce Turkce kalirdi; kullanici
        // ekranda YABANCI bir dil gorurdu.
        expect(s[k], `${d}.${k} Turkce kalmis`).not.toBe(
          (trSozluk as Record<string, string>)[k],
        );
      }
    }
  });
});
