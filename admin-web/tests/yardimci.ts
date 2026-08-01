// (P43) Bilesen testleri icin ORTAK sarmalayici.
//
// Panelin sayfalari `useT` (I18nProvider) ve `useToast` (ToastProvider)
// olmadan RENDER EDILEMEZ — ikisi de saglayici yoksa ACIKCA hata atar.
// Her testte bu iki saglayiciyi tekrar kurmak, birinde degisen bir
// varsayilanin digerlerinde unutulmasi demekti.
//
// JSX YOK, `createElement` VAR: JSX icin gereken `@vitejs/plugin-react`
// eklentisinin tip dosyasi bu depodaki TypeScript ile ayristirilamiyor ve
// `next build`i KIRIYORDU. Test altyapisi urun derlemesini kiramaz.
import { render, type RenderResult } from "@testing-library/react";
import { createElement, type ComponentType } from "react";
import { SWRConfig } from "swr";

import { ToastProvider } from "@/components/Toast";
import { I18nProvider } from "@/lib/i18n/kullan";

/** Testler TR dilinde kosar: sozluk kaynak dildir ve bir anahtarin metni
 *  once orada belirir. Baska bir dil secmek, ceviri eksigini test
 *  basarisizligi gibi gosterirdi. */
export function ciz(Sayfa: ComponentType): RenderResult {
  return render(
    // HER RENDER ICIN TEMIZ SWR ONBELLEGI: SWR onbellegi MODUL DUZEYINDE
    // paylasilir; testler arasi tasinmasi, ikinci testin birinci testin
    // yanitini gormesi demekti (ve "uc dustu" senaryosu yanlislikla
    // GECERDI).
    createElement(
      SWRConfig,
      { value: { provider: () => new Map(), dedupingInterval: 0 } },
      // `children` prop OLARAK verilir: `createElement`in ucuncu
      // argumani, `children`i ZORUNLU ilan eden bilesenlerin tip
      // denetimini gecmiyor (Next derlemesi bunu yakaladi).
      createElement(I18nProvider, {
        baslangicDili: "tr" as const,
        children: createElement(ToastProvider, {
          children: createElement(Sayfa),
        }),
      }),
    ),
  );
}

/** `fetch`i SAHTELE: url -> yanit govdesi.
 *
 * Neden gercek `fetch` degil: sayfalar BFF'e (`/api/panel/...`) gider ve
 * testte sunucu YOKTUR. Eslesmeyen bir url'e 404 donmek, sayfanin hata
 * yolunu da olculebilir kilar (sessiz bos ekran yerine). */
export function fetchSahtele(
  harita: Record<string, unknown>,
  opts: { durum?: number } = {},
): void {
  const cagrilar: string[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    const url = String(girdi);
    cagrilar.push(url);
    // EN UZUN ONEK KAZANIR: `/api/panel/portal` ile
    // `/api/panel/portal-iletisim` ayni oneki paylasir; ekleme sirasina
    // gore eslestirmek, iletisim listesine PORTAL govdesini dondururdu.
    const anahtar = Object.keys(harita)
      .filter((k) => url.startsWith(k))
      .sort((a, b) => b.length - a.length)[0];
    if (anahtar === undefined) {
      return new Response(JSON.stringify({ error: { message: "yok" } }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }
    // UC BASINA DURUM: `opts.durum` TUM uclari birden bozar; oysa gercek
    // kusurlarin cogu "liste geldi ama YAZMA dustu" seklindedir. Govdede
    // `__durum` varsa o uca ozel HTTP durumu olur (isaretci govdeden
    // ayiklanir, sayfa gormez).
    const govde = harita[anahtar];
    let durum = opts.durum ?? 200;
    let cikti = govde;
    if (govde && typeof govde === "object" && "__durum" in govde) {
      const { __durum, ...kalan } = govde as { __durum: number };
      durum = __durum;
      cikti = kalan;
    }
    return new Response(JSON.stringify(cikti), {
      status: durum,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  (globalThis as { __cagrilar?: string[] }).__cagrilar = cagrilar;
}

export function cagrilanUrller(): string[] {
  return (globalThis as { __cagrilar?: string[] }).__cagrilar ?? [];
}
