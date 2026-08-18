// @vitest-environment jsdom
// (P160 / Asama 10) ROL BAZLI GEZINTI TARAMASI.
//
// =========================================================================
// BU TEST NE OLCER, NE OLCMEZ
// =========================================================================
// OLCER: her korumali sayfa jsdom'da CIZILEBILIYOR mu ve cizerken
// KONSOLA hata/uyari dusuyor mu. React'in en pahali sessiz hatalari tam
// olarak burada cikar — eksik `key`, gecersiz DOM ic ice gecmesi
// (`<div>` icinde `<p>`), denetimli/denetimsiz girdi gecisi, gecersiz
// oznitelik. Bunlarin hicbiri testi dusurmez ama hepsi gercek kusurdur.
//
// OLCMEZ: gorsel duzen, gercek tarayici davranisi, FPS. Onlar icin gercek
// tarayici gerekir ve rapor bunu ACIKCA yaziyor (docs/P160-asama10.md).
//
// NEDEN KALICI BIR TEST: bir sonraki tur yeni bir sayfa eklediginde ya da
// bir sayfayi bozdugunda, tarama onu ilk cizimde yakalar.
import { cleanup, render } from "@testing-library/react";
import { createElement } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { I18nProvider } from "@/lib/i18n/kullan";
import { SOZLUKLER } from "@/lib/i18n/sozluk";
import { ToastProvider } from "@/components/Toast";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn(), back: vi.fn() }),
  usePathname: () => "/dashboard",
  useSearchParams: () => new URLSearchParams(),
  useParams: () => ({ id: "t1" }),
  redirect: vi.fn(),
}));

/**
 * TEK BIR SAHTE UC. Her sayfa farkli sekil bekler; bu yuzden yanit
 * ayni anda "sayfali liste", "ozetli liste" ve "duz nesne" gibi
 * okunabilecek BIRLESIK bir govdedir. Amac veriyi dogrulamak degil,
 * sayfayi VERI VARKEN cizdirmek.
 */
function sahteUc() {
  // BAZI UCLAR DUZ DIZI DONER (`/ice-aktarim/turler` gibi). Ayni govdeyi
  // hem dizi hem nesne yapamayiz; sozlesmesi dizi olanlar ayrilir.
  // (P169) `kvkk-metinler` EKLENDI: sozlesmesi duz dizi ve yanlis sekil
  // vermek `VeriTablosu`nu YAKALANMAMIS ISTISNAYLA cokertiyordu. Vitest
  // bunu "bu, testleri yanlis GECIRIYOR olabilir" diye bildiriyordu —
  // yani tarama sessizce eksik olcuyordu.
  const DIZI_UCLARI = ["turler", "/checkpoints", "kvkk-metinler"];
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    const url = String(girdi);
    if (DIZI_UCLARI.some((u) => url.includes(u))) {
      return {
        ok: true,
        status: 200,
        headers: new Headers(),
        json: async () => [],
      } as unknown as Response;
    }
    return ({
      ok: true,
      status: 200,
      headers: new Headers(),
      json: async () => ({
        meta: { limit: 25, offset: 0, total: 0 },
        items: [],
        roller: [],
        yoneticiler: [],
        saglayicilar: [],
        note: null,
        tesis_kodu: null,
        genel_toplam_kurus: 0,
        ozet: { toplam: 0, tamamlandi: 0, kacirildi: 0, bekliyor: 0, kalemler: [] },
        role: "admin",
        slug: "demo",
        tenant_id: "00000000-0000-0000-0000-000000000000",
        ad: "Demo",
        timezone: "Europe/Istanbul",
        bloklar: [],
        unplaced: [],
      }),
      text: async () => "",
      blob: async () => new Blob(),
    }) as unknown as Response;
  }) as typeof fetch;
}

/** Korumali sayfalar — menude gorunen HER rota + park edilmis olanlar. */
const SAYFALAR: { yol: string; yukle: () => Promise<{ default: React.ComponentType }> }[] = [
  { yol: "/dashboard", yukle: () => import("@/app/(protected)/dashboard/page") },
  { yol: "/olaylar", yukle: () => import("@/app/(protected)/olaylar/page") },
  { yol: "/notifications", yukle: () => import("@/app/(protected)/notifications/page") },
  { yol: "/kameralar", yukle: () => import("@/app/(protected)/kameralar/page") },
  { yol: "/shifts", yukle: () => import("@/app/(protected)/shifts/page") },
  { yol: "/checkpoints", yukle: () => import("@/app/(protected)/checkpoints/page") },
  { yol: "/patrol-plans", yukle: () => import("@/app/(protected)/patrol-plans/page") },
  { yol: "/ziyaretciler", yukle: () => import("@/app/(protected)/ziyaretciler/page") },
  { yol: "/kargolar", yukle: () => import("@/app/(protected)/kargolar/page") },
  { yol: "/arac-gecisleri", yukle: () => import("@/app/(protected)/arac-gecisleri/page") },
  { yol: "/units", yukle: () => import("@/app/(protected)/units/page") },
  { yol: "/tasks", yukle: () => import("@/app/(protected)/tasks/page") },
  { yol: "/gorevlerim", yukle: () => import("@/app/(protected)/gorevlerim/page") },
  { yol: "/assets", yukle: () => import("@/app/(protected)/assets/page") },
  { yol: "/schematic", yukle: () => import("@/app/(protected)/schematic/page") },
  { yol: "/dis-hizmetler", yukle: () => import("@/app/(protected)/dis-hizmetler/page") },
  { yol: "/etkinlikler", yukle: () => import("@/app/(protected)/etkinlikler/page") },
  { yol: "/rezervasyonlarim", yukle: () => import("@/app/(protected)/rezervasyonlarim/page") },
  { yol: "/kurallar", yukle: () => import("@/app/(protected)/kurallar/page") },
  { yol: "/dues", yukle: () => import("@/app/(protected)/dues/page") },
  { yol: "/aidatim", yukle: () => import("@/app/(protected)/aidatim/page") },
  { yol: "/finans", yukle: () => import("@/app/(protected)/finans/page") },
  { yol: "/sayac-okuma", yukle: () => import("@/app/(protected)/sayac-okuma/page") },
  { yol: "/reports/dues", yukle: () => import("@/app/(protected)/reports/dues/page") },
  { yol: "/reports/patrols", yukle: () => import("@/app/(protected)/reports/patrols/page") },
  { yol: "/reports/tasks", yukle: () => import("@/app/(protected)/reports/tasks/page") },
  { yol: "/raporlar", yukle: () => import("@/app/(protected)/raporlar/page") },
  { yol: "/icra", yukle: () => import("@/app/(protected)/icra/page") },
  { yol: "/tenants", yukle: () => import("@/app/(protected)/tenants/page") },
  { yol: "/integrations", yukle: () => import("@/app/(protected)/integrations/page") },
  { yol: "/settings", yukle: () => import("@/app/(protected)/settings/page") },
  { yol: "/announcements", yukle: () => import("@/app/(protected)/announcements/page") },
  { yol: "/duyurular", yukle: () => import("@/app/(protected)/duyurular/page") },
  { yol: "/mesajlar", yukle: () => import("@/app/(protected)/mesajlar/page") },
  { yol: "/complaints", yukle: () => import("@/app/(protected)/complaints/page") },
  { yol: "/taleplerim", yukle: () => import("@/app/(protected)/taleplerim/page") },
  { yol: "/anketler", yukle: () => import("@/app/(protected)/anketler/page") },
  { yol: "/yonetim-iletisim", yukle: () => import("@/app/(protected)/yonetim-iletisim/page") },
  { yol: "/davetler", yukle: () => import("@/app/(protected)/davetler/page") },
  { yol: "/support", yukle: () => import("@/app/(protected)/support/page") },
  { yol: "/kurulum", yukle: () => import("@/app/(protected)/kurulum/page") },
  { yol: "/ice-aktarim", yukle: () => import("@/app/(protected)/ice-aktarim/page") },
  { yol: "/building-editor", yukle: () => import("@/app/(protected)/building-editor/page") },
  { yol: "/tanimlar", yukle: () => import("@/app/(protected)/tanimlar/page") },
  { yol: "/users", yukle: () => import("@/app/(protected)/users/page") },
  { yol: "/transparency", yukle: () => import("@/app/(protected)/transparency/page") },
  // (P167 §6.1) "/yonetisim" DORDE BOLUNDU; tarama dordunu de kapsar
  // ki "basligi kaldirdim ama bolumu unuttum" sinifi yakalansin.
  { yol: "/karar-defteri", yukle: () => import("@/app/(protected)/karar-defteri/page") },
  { yol: "/dokumanlar", yukle: () => import("@/app/(protected)/dokumanlar/page") },
  { yol: "/kvkk-metinler", yukle: () => import("@/app/(protected)/kvkk-metinler/page") },
  { yol: "/gurultu-uyarilari", yukle: () => import("@/app/(protected)/gurultu-uyarilari/page") },
  { yol: "/audit", yukle: () => import("@/app/(protected)/audit/page") },
  { yol: "/yetki", yukle: () => import("@/app/(protected)/yetki/page") },
  { yol: "/kvkk", yukle: () => import("@/app/(protected)/kvkk/page") },
  { yol: "/profil", yukle: () => import("@/app/(protected)/profil/page") },
];

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

describe("(P160 / Asama 10) her sayfa CIZILIR ve konsola hata dusurmez", () => {
  for (const sayfa of SAYFALAR) {
    it(`${sayfa.yol}`, async () => {
      sahteUc();
      const kayit: string[] = [];
      const hata = vi.spyOn(console, "error").mockImplementation((...a) => {
        kayit.push(String(a[0]));
      });
      const uyari = vi.spyOn(console, "warn").mockImplementation((...a) => {
        kayit.push(String(a[0]));
      });

      const mod = await sayfa.yukle();
      render(
        createElement(I18nProvider, {
          baslangicDili: "tr",
          baslangicSozlugu: SOZLUKLER.tr,
          children: createElement(ToastProvider, {
            children: createElement(mod.default),
          }),
        }),
      );

      hata.mockRestore();
      uyari.mockRestore();
      expect(kayit, `${sayfa.yol} konsola yazdi:\n${kayit.join("\n")}`).toEqual([]);
    });
  }
});
