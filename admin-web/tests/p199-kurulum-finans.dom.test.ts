// @vitest-environment jsdom
// (P199) KURULUM SIHIRBAZI — FINANS ADIMLARI ve "SONRAYA BIRAKILANLAR".
//
// =========================================================================
// OLCULEN KUSUR
// =========================================================================
// Sihirbaz bitiyordu ama finans modulu KULLANILAMAZ kaliyordu: aidat
// turu yok, plan yok, butce basligi yok. Yonetici bunlari kendi
// kesfetmek zorundaydi.
//
// Ikinci kusur: ATLANAN adim listeden sessizce dusuyordu. Sihirbazin
// sonunda "sunu sonraya biraktin, sonucu su" diyen hicbir yer yoktu.
import { screen, within } from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";

import KurulumPage from "@/app/(protected)/kurulum/page";
import { KURULUM_HEDEFLERI } from "@/lib/kurulum-adimlari";
import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz, fetchSahtele } from "./yardimci";

const FINANS = [
  "gelir_gider_tanimi",
  "aidat_plani",
  "otomasyon",
  "butce_kategorisi",
  "duzenli_gider",
] as const;

/** Sunucu yaniti — `atlanan` kodlari BILINCLI atlanmis sayilir. */
function durum(atlanan: readonly string[] = []) {
  const kodlar = Object.keys(KURULUM_HEDEFLERI);
  const zorunlu = new Set([
    "blok", "daire", "sakin", "eposta", "kasa", "gelir_gider_tanimi", "aidat",
  ]);
  const eksik = ["gelir_gider_tanimi"];
  return {
    adimlar: kodlar.map((kod) => ({
      kod,
      sayi: eksik.includes(kod) || atlanan.includes(kod) ? 0 : 1,
      tamam: !eksik.includes(kod) && !atlanan.includes(kod),
      atlandi: atlanan.includes(kod),
      zorunlu: zorunlu.has(kod),
    })),
    toplam: kodlar.length,
    gecilen: kodlar.length - eksik.length,
    zorunlu_toplam: zorunlu.size,
    eksik_zorunlular: eksik,
    calisir: false,
  };
}

function kur(yanit: Record<string, unknown> = durum()) {
  fetchSahtele({ "/api/panel/kurulum": yanit, "/api/me": { role: "yonetici" } });
}

afterEach(() => {
  vi.restoreAllMocks();
  localStorage.clear();
});

it("bes finans adiminin hepsinin ETIKET, ACIKLAMA ve ENGEL metni VAR", () => {
  // Sozlukte anahtar eksikse sihirbaz cevrilmemis bir kod cizerdi.
  for (const kod of FINANS) {
    const h = KURULUM_HEDEFLERI[kod];
    expect(h, kod).toBeTruthy();
    for (const anahtar of [h.etiket, h.aciklama, h.engel]) {
      expect(tr[anahtar], `${kod}: ${anahtar}`).toBeTruthy();
    }
  }
});

it("her finans adimi GIDILECEK bir ekrana bakar", () => {
  // `gorev_alani` dersi (P166 §8.3): adim, olculen seyin URETILDIGI
  // ekrana bakmali. Rota bos kalirsa kullanici adimi tamamlayamaz.
  for (const kod of FINANS) {
    expect(KURULUM_HEDEFLERI[kod].rota, kod).toMatch(/^\//);
  }
});

it("GELIR/GIDER TANIMI eksikken ozet NE CALISMADIGINI soyler", async () => {
  kur();
  ciz(KurulumPage);
  // Metin ADIM LISTESINDE de gecer; olculen sey OZETTE de gectigidir.
  const engel = tr[KURULUM_HEDEFLERI.gelir_gider_tanimi.engel];
  const hepsi = await screen.findAllByText(engel);
  expect(hepsi.length).toBeGreaterThan(1);
});

it("ATLANAN istege bagli adim OZETTE, NEYI ENGELLEDIGIYLE birlikte cikar", async () => {
  kur(durum(["aidat_plani", "butce_kategorisi"]));
  ciz(KurulumPage);
  await screen.findAllByText(tr[KURULUM_HEDEFLERI.gelir_gider_tanimi.engel]);
  const bolum = document.querySelector('[data-test="kurulum-atlananlar"]');
  expect(bolum, "atlananlar bolumu cizilmeli").toBeTruthy();
  const icinde = within(bolum as HTMLElement);
  expect(icinde.getByText(tr[KURULUM_HEDEFLERI.aidat_plani.engel])).toBeTruthy();
  expect(
    icinde.getByText(tr[KURULUM_HEDEFLERI.butce_kategorisi.engel]),
  ).toBeTruthy();
});

it("hicbir sey ATLANMAMISSA 'sonraya birakilanlar' bolumu CIZILMEZ", async () => {
  kur();
  ciz(KurulumPage);
  await screen.findAllByText(tr[KURULUM_HEDEFLERI.gelir_gider_tanimi.engel]);
  expect(document.querySelector('[data-test="kurulum-atlananlar"]')).toBeNull();
});

it("ATLANAN ZORUNLU adim 'sonraya birakilanlar'a DUSMEZ", async () => {
  // (P193 §2 karari) Atlamak gercegi degistirmez: kasasiz tesis,
  // adim atlandi diye tahsilat yapamaz. Zorunlu adim yukaridaki
  // EKSIKLER listesinde kalir; yumusak listeye tasinmasi onu
  // "istege bagli" gibi gosterirdi.
  kur(durum(["gelir_gider_tanimi"]));
  ciz(KurulumPage);
  await screen.findAllByText(tr[KURULUM_HEDEFLERI.gelir_gider_tanimi.engel]);
  expect(document.querySelector('[data-test="kurulum-atlananlar"]')).toBeNull();
});
