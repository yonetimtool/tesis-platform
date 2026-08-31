// @vitest-environment jsdom
// (P131) KAMERA IZGARASI — OYNATICI, ROZET ve YONETIM.
//
// P126.5 oynatmayi BILEREK yapmamisti (hls.js bir bagimlilik karariydi) ve
// yonetimi de acmamisti (kural mobilde). P131'de ikisi de geldi; bu dosya
// UCUNU birden olcer:
//   1. oynatilabilir karoya tiklayinca OYNATICI acilir,
//   2. oynatilamaz kaynak ROZETLENIR ve tiklayinca NEDENINI soyleyen bir
//      bilgi kutusu acilir (siyah ekran DEGIL),
//   3. yonetim formu, mobil ile ORTAK kurali (lib/kamera-url.ts) uygular —
//      web sayfasi adresi istek GONDERILMEDEN kesilir.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import KameralarPage from "@/app/(protected)/kameralar/page";

import { ciz } from "./yardimci";

const OYNAR = {
  id: "k1",
  ad: "Ana Kapı",
  konum: "Giriş",
  stream_url: "https://ornek/live.m3u8",
  tur: "hls",
  aktif: true,
  sakin_gorebilir: true,
  restream_url: null,
  snapshot_url: "https://ornek/kare.jpg",
  oynatilabilir: true,
};
const OYNAMAZ = {
  ...OYNAR,
  id: "k2",
  ad: "Otopark",
  stream_url: "rtsp://ornek/1",
  tur: "rtsp",
  snapshot_url: null,
  oynatilabilir: false,
};

function fetchTaklidi(items: unknown[]) {
  const cagrilar: { url: string; method: string; body: unknown }[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      method: init?.method ?? "GET",
      body: init?.body ? JSON.parse(String(init.body)) : undefined,
    });
    if (url.startsWith("/api/cameras")) {
      return new Response(
        JSON.stringify({ meta: { limit: 50, offset: 0, total: items.length }, items }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }
    return new Response("{}", { status: 200, headers: { "Content-Type": "application/json" } });
  }) as typeof fetch;
  return cagrilar;
}

afterEach(() => vi.restoreAllMocks());

describe("(P131) izgara", () => {
  it("OYNATILAMAZ kamera ROZETLENIR, oynatilabilir olan rozetlenmez", async () => {
    fetchTaklidi([OYNAR, OYNAMAZ]);
    ciz(KameralarPage);
    await screen.findByText("Ana Kapı");
    // Rozet TEK: yalnizca rtsp kamerada.
    const rozetler = screen.getAllByText(/Tarayıcıda oynatılamaz/i);
    expect(rozetler).toHaveLength(1);
  });

  it("oynatilamaz karo NEDENINI soyler (siyah ekran degil)", async () => {
    fetchTaklidi([OYNAMAZ]);
    ciz(KameralarPage);
    const kullanici = userEvent.setup();
    await kullanici.click(await screen.findByRole("button", { name: /neden oynatılamıyor/i }));
    expect(await screen.findByText(/RTSP yayını yapıyor/i)).toBeInTheDocument();
    // Oynatici ACILMAZ.
    expect(document.querySelector("video")).toBeNull();
  });

  it("oynatilabilir karo OYNATICIYI acar", async () => {
    fetchTaklidi([OYNAR]);
    ciz(KameralarPage);
    const kullanici = userEvent.setup();
    await kullanici.click(await screen.findByRole("button", { name: /yayınını aç/i }));
    await waitFor(() => expect(document.querySelector("video")).not.toBeNull());
  });
});

describe("(P131) yonetim formu — ORTAK kural uygulanir", () => {
  async function formuAc() {
    const kullanici = userEvent.setup();
    await kullanici.click(await screen.findByRole("button", { name: /Yeni kamera/i }));
    return kullanici;
  }

  it("WEB SAYFASI adresi istek GONDERILMEDEN kesilir", async () => {
    const cagrilar = fetchTaklidi([]);
    ciz(KameralarPage);
    const kullanici = await formuAc();
    await kullanici.type(screen.getByRole("textbox", { name: "Ad" }), "Kapı");
    await kullanici.type(
      screen.getByLabelText(/Kamera adresi/i),
      "https://www.youtube.com/watch?v=abc",
    );
    await kullanici.click(screen.getByRole("button", { name: /Kaydet/i }));
    expect(await screen.findByText(/web sayfası adresi/i)).toBeInTheDocument();
    // SUNUCUYA HIC GIDILMEDI: sunucu bunu GECIRIRDI (sema dogru), yani
    // yakalayacak tek yer istemcidir.
    expect(cagrilar.filter((c) => c.method === "POST")).toHaveLength(0);
  });

  it("GECERLI adres POST edilir (kural her seyi reddetmiyor)", async () => {
    const cagrilar = fetchTaklidi([]);
    ciz(KameralarPage);
    const kullanici = await formuAc();
    await kullanici.type(screen.getByRole("textbox", { name: "Ad" }), "Kapı");
    await kullanici.type(
      screen.getByLabelText(/Kamera adresi/i),
      "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8",
    );
    await kullanici.click(screen.getByRole("button", { name: /Kaydet/i }));
    await waitFor(() =>
      expect(cagrilar.filter((c) => c.method === "POST")).toHaveLength(1),
    );
    const govde = cagrilar.find((c) => c.method === "POST")?.body as Record<string, unknown>;
    expect(govde.tur).toBe("hls");
    // Bos alanlar `null` gider ("" degil): sunucu bos dizeyi adres sanardi.
    expect(govde.restream_url).toBeNull();
    expect(govde.snapshot_url).toBeNull();
  });

  it("RTSP turunde https adresi kesilir (ters yon)", async () => {
    const cagrilar = fetchTaklidi([]);
    ciz(KameralarPage);
    const kullanici = await formuAc();
    await kullanici.type(screen.getByRole("textbox", { name: "Ad" }), "Otopark");
    // (P191-ek §3) TUR ARTIK ADRESTEN TURETILIR; elle secim GELISMIS
    // AYARLAR altindadir. Bu olcum "kullanici turu elle bozarsa yine
    // kesiliyor mu" sorusudur — yani gelismis yol da korunuyor.
    await kullanici.type(screen.getByLabelText(/Kamera adresi/i), "https://ornek/1");
    await kullanici.click(screen.getByRole("button", { name: /Gelişmiş ayarlar/i }));
    // SIRA ONEMLI: adres yazilirken tur yeniden turetilir, bu yuzden elle
    // secim EN SON yapilir (kullanicinin gercek sirasi da budur).
    await kullanici.selectOptions(screen.getByLabelText(/Yayın türü/i), "rtsp");
    await kullanici.click(screen.getByRole("button", { name: /Kaydet/i }));
    // IKI EŞLEŞME BEKLENIR: alan ipucu ("RTSP için rtsp:// ile başlamalı")
    // ve hata kutusu. Olculen sey HATA KUTUSU — `role="alert"` ile ayrilir.
    expect(await screen.findByRole("alert")).toHaveTextContent(/rtsp:\/\//i);
    expect(cagrilar.filter((c) => c.method === "POST")).toHaveLength(0);
  });

  // ======================================================================
  // (P191-ek §3) FORM SADELESTIRME — uc olculen kusurun kilidi
  // ======================================================================
  it("TEST DUGMESI YENI KAMERA FORMUNDA GORUNUR", async () => {
    // OLCULEN KUSUR: dugme `form.tur === "rtsp"` kosuluna baglanmisti ve
    // yeni kamera formunda tur varsayilani "hls" oldugu icin HIC
    // cizilmiyordu — "ekledim" denen ozellik kullaniciya gorunmuyordu.
    fetchTaklidi([]);
    ciz(KameralarPage);
    await formuAc();
    expect(
      screen.getByRole("button", { name: /Bağlantıyı test et/i }),
    ).toBeInTheDocument();
  });

  it("TUR ADRESTEN TURETILIR (kullaniciya sorulmaz)", async () => {
    const cagrilar = fetchTaklidi([]);
    ciz(KameralarPage);
    const kullanici = await formuAc();
    await kullanici.type(screen.getByRole("textbox", { name: "Ad" }), "Giriş");
    await kullanici.type(
      screen.getByLabelText(/Kamera adresi/i),
      "rtsp://kullanici:parola@10.0.0.5:554/Streaming/Channels/101",
    );
    // Tur secilmedi; sistem RTSP'yi adresten anladi.
    await kullanici.click(screen.getByRole("button", { name: /Kaydet/i }));
    await waitFor(() =>
      expect(cagrilar.filter((c) => c.method === "POST")).toHaveLength(1),
    );
    const govde = cagrilar.find((c) => c.method === "POST")?.body as Record<string, unknown>;
    expect(govde.tur).toBe("rtsp");
  });

  it("RESTREAM/ANLIK KARE alanlari VARSAYILAN GIZLI (gelismis)", async () => {
    // P190 mimarisi: izgarada ffmpeg karesi, tiklayinca MediaMTX HLS —
    // sistem ikisini de TEK RTSP adresinden uretir. Yoneticiye ucuncu bir
    // adres sormak, hangisini dolduracagini bilemedigi bir soru sormakti.
    fetchTaklidi([]);
    ciz(KameralarPage);
    const kullanici = await formuAc();
    expect(screen.queryByLabelText(/Yeniden yayın \(restream\) adresi/i)).toBeNull();
    await kullanici.click(screen.getByRole("button", { name: /Gelişmiş ayarlar/i }));
    expect(screen.getByLabelText(/Yeniden yayın \(restream\) adresi/i)).toBeInTheDocument();
  });
});
