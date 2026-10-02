// @vitest-environment jsdom
// (P250 §4) KURULUM VIDEOLARI — pencere, izlendi, "simdi yap", panel onizlemesi.
//
// YouTube IFrame API'si SAHTELENIR (`window.YT`): olculen sey bizim
// davranisimiz — ENDED gelince izlendi isteginin gitmesi ve dugmenin
// vurgulanmasi; oynatici hatasinda anlasilir uyari.
import { act, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement } from "react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";

import { KurulumVideolariPenceresi } from "@/components/KurulumVideolari";
import { tr } from "@/lib/i18n/sozluk/tr";
import { youtubeKimligi } from "@/lib/youtube";

import { ciz } from "./yardimci";

const push = vi.fn();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push, replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/dashboard",
  useSearchParams: () => new URLSearchParams(),
}));

type Olaylar = { onStateChange?: (e: { data: number }) => void; onError?: (e: { data: number }) => void };
let sonOynatici: { videoId: string; host?: string; vars?: Record<string, unknown>; olay: Olaylar } | null = null;

beforeEach(() => {
  push.mockClear();
  sonOynatici = null;
  window.YT = {
    PlayerState: { ENDED: 0 },
    Player: class {
      constructor(_el: HTMLElement, ayar: { videoId: string; host?: string; playerVars?: Record<string, unknown>; events?: Olaylar }) {
        sonOynatici = { videoId: ayar.videoId, host: ayar.host, vars: ayar.playerVars, olay: ayar.events ?? {} };
      }
      loadVideoById() {}
      cueVideoById(id: string) {
        if (sonOynatici) sonOynatici.videoId = id;
      }
      destroy() {}
    },
  } as unknown as Window["YT"];
});
afterEach(() => vi.restoreAllMocks());

const LISTE = {
  set_kodu: "yonetici",
  toplam: 2,
  izlenen: 1,
  kurulum_tamam: false,
  adimlar: [
    { adim_kodu: "blok", video: { youtube_id: "AbCdEfGhIj1", baslik: "Bloklar", aciklama: "Blok ekleme" }, izlendi: true },
    { adim_kodu: "daire", video: { youtube_id: "ZyXwVuTsRq2", baslik: "Daireler", aciklama: null }, izlendi: false },
    { adim_kodu: "daire_tipi", video: null, izlendi: false },
  ],
};

function taklit() {
  const c: { url: string; metot: string }[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    c.push({ url: String(girdi), metot: (init?.method ?? "GET").toUpperCase() });
    const govde = String(girdi).endsWith("/izlendi") ? {} : LISTE;
    return new Response(JSON.stringify(govde), { status: 200, headers: { "Content-Type": "application/json" } });
  }) as typeof fetch;
  return c;
}

const kanca = (ad: string) => document.querySelector(`[data-test="${ad}"]`) as HTMLElement | null;

it("ilk izlenmemis adimda acilir; oynatici nocookie + rel=0", async () => {
  taklit();
  ciz(() => createElement(KurulumVideolariPenceresi, { acik: true, onKapat: () => {} }));
  await waitFor(() => expect(sonOynatici?.videoId).toBe("ZyXwVuTsRq2"));
  expect(sonOynatici?.host).toBe("https://www.youtube-nocookie.com");
  expect(sonOynatici?.vars?.rel).toBe(0);
  // Izlenen adim onay isaretiyle, aktif adim aria-current ile.
  const adimlar = document.querySelectorAll('[data-test="egitim-adim"]');
  expect(adimlar[0].textContent).toBe("✓");
  expect(adimlar[1].getAttribute("aria-current")).toBe("step");
});

it("video BITINCE izlendi gider ve 'Simdi bu adimi yap' vurgulanir; tiklayinca sayfaya gider", async () => {
  const c = taklit();
  const onKapat = vi.fn();
  ciz(() => createElement(KurulumVideolariPenceresi, { acik: true, onKapat }));
  await waitFor(() => expect(sonOynatici?.videoId).toBe("ZyXwVuTsRq2"));
  expect(kanca("egitim-simdi-yap")?.getAttribute("data-vurgulu")).toBe("hayir");
  await act(async () => sonOynatici!.olay.onStateChange?.({ data: 0 }));
  await waitFor(() =>
    expect(c.some((x) => x.url === "/api/egitim-videolari/daire/izlendi" && x.metot === "POST")).toBe(true),
  );
  expect(kanca("egitim-simdi-yap")?.getAttribute("data-vurgulu")).toBe("evet");
  await userEvent.click(kanca("egitim-simdi-yap")!);
  expect(onKapat).toHaveBeenCalled();
  expect(push).toHaveBeenCalledWith("/building-editor");
});

it("ortada kapatilan video izlendi SAYILMAZ (istek gitmez)", async () => {
  const c = taklit();
  ciz(() => createElement(KurulumVideolariPenceresi, { acik: true, onKapat: () => {} }));
  await waitFor(() => expect(sonOynatici).not.toBeNull());
  await act(async () => sonOynatici!.olay.onStateChange?.({ data: 2 })); // duraklatildi
  expect(c.some((x) => x.url.endsWith("/izlendi"))).toBe(false);
});

it("videosuz adim 'yakinda' — kirik oynatici yok; ileri ok ile gezilir", async () => {
  taklit();
  ciz(() => createElement(KurulumVideolariPenceresi, { acik: true, onKapat: () => {}, baslangic: "daire" }));
  await waitFor(() => expect(kanca("egitim-ileri")).toBeTruthy());
  await userEvent.click(kanca("egitim-ileri")!);
  expect(kanca("egitim-yakinda")?.textContent).toBe(tr.egitimYakinda);
  expect(kanca("youtube-oynatici")).toBeNull();
});

it("gizli / yerlestirmesi kapali video: anlasilir uyari", async () => {
  taklit();
  ciz(() => createElement(KurulumVideolariPenceresi, { acik: true, onKapat: () => {} }));
  await waitFor(() => expect(sonOynatici).not.toBeNull());
  await act(async () => sonOynatici!.olay.onError?.({ data: 150 }));
  expect(kanca("youtube-hata")?.textContent).toBe(tr.egitimVideoKapali);
});

it("youtube kimligi istemci ikizi sunucuyla ayni kurallar", () => {
  expect(youtubeKimligi("https://www.youtube.com/watch?v=dQw4w9WgXcQ")).toBe("dQw4w9WgXcQ");
  expect(youtubeKimligi("youtu.be/dQw4w9WgXcQ?si=x")).toBe("dQw4w9WgXcQ");
  expect(youtubeKimligi("https://youtube.com/shorts/dQw4w9WgXcQ")).toBe("dQw4w9WgXcQ");
  expect(youtubeKimligi("https://vimeo.com/1")).toBeNull();
  expect(youtubeKimligi("https://kotu.com/watch?v=dQw4w9WgXcQ")).toBeNull();
});
