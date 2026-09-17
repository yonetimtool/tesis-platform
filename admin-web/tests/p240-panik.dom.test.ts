// @vitest-environment jsdom
// (P240 §1) PANIK BUTONU — WEB YUZEYI.
//
// ===========================================================================
// NE OLCULUYOR
// ===========================================================================
//   1. ROL KAPISI: her rol YALNIZ tetikleyebildigi tipleri gorur.
//   2. IPTAL PENCERESI: geri sayim gorunur, iptal istegi gider.
//   3. GERI SAYIM BITINCE ISTEMCI IKINCI ISTEK ATMAZ — yayin sunucudaki
//      gecikmeli gorevin isi. Bunu ISTEMCIYE baglamak, sekme kapaninca
//      alarmin hic gitmemesi demekti.
//   4. YASAL UYARI dugmelere BASMADAN ONCE gorunur.
//   5. TAM EKRAN ALARM: kapatma dugmesi YOK; yalniz gordum/gidiyorum.
import { waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import { PanikAlarmi } from "@/components/panik/panik-alarmi";
import { PanikDugmesi } from "@/components/panik/panik-dugmesi";

import { ciz } from "./yardimci";

const el = (ad: string) => document.querySelector(`[data-test="${ad}"]`);

let cagrilar: { url: string; metot: string; govde?: unknown }[] = [];

function taklit(opts: { aktif?: unknown[] } = {}) {
  cagrilar = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const metot = (init?.method ?? "GET").toUpperCase();
    cagrilar.push({
      url,
      metot,
      govde: init?.body ? JSON.parse(String(init.body)) : undefined,
    });
    let govde: unknown = { ok: true };
    if (url === "/api/panik" && metot === "POST") {
      govde = { id: "p1", durum: "beklemede", iptal_penceresi_sn: 5 };
    } else if (url === "/api/panik/p1/iptal") {
      govde = { id: "p1", durum: "iptal" };
    } else if (url === "/api/panik/aktif") {
      govde = opts.aktif ?? [];
    }
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  }) as typeof fetch;
}

afterEach(() => {
  // SAHTE ZAMANLAYICI SIZINTISI: geri sayim testi `useFakeTimers`
  // kullaniyor ve `finally` ile geri aliyor; yine de afterEach'te
  // ACIKCA gercek zamanlayiciya donulur. Ilk yazimda bu satir yoktu ve
  // SONRAKI ALTI TEST 5 sn'de zaman asimina ugradi — sizinti, testi
  // yazdigim yerde degil BASKA testlerde patladigi icin ilk bakista
  // "bilesen hatali" gibi gorundu.
  vi.useRealTimers();
  vi.restoreAllMocks();
});

describe("(P240 §1) panik dugmesi — rol kapisi", () => {
  it("SAKIN yalniz 'evde acil durum'u gorur", async () => {
    taklit();
    ciz(() => PanikDugmesi({ rol: "resident" }));
    await userEvent.click(el("panik-ac") as HTMLElement);
    expect(el("panik-tip-sakin")).toBeTruthy();
    // Sakin site geneline anons YAPAMAZ; dugmeyi gostermek, basinca
    // 403 alacagi bir yol sunmak olurdu.
    expect(el("panik-tip-yonetici_anons")).toBeNull();
    expect(el("panik-tip-guvenlik")).toBeNull();
  });

  it("GUVENLIK yalniz 'guvenlik acili'ni gorur", async () => {
    taklit();
    ciz(() => PanikDugmesi({ rol: "security" }));
    await userEvent.click(el("panik-ac") as HTMLElement);
    expect(el("panik-tip-guvenlik")).toBeTruthy();
    expect(el("panik-tip-sakin")).toBeNull();
  });

  it("YONETICI ikisini gorur, 'sakin panigi'ni GORMEZ", async () => {
    // Yoneticinin dairesi yoktur; onun actigi sakin panigi gidilecek
    // ADRES tasimazdi (sunucu da 403 verir).
    taklit();
    ciz(() => PanikDugmesi({ rol: "yonetici" }));
    await userEvent.click(el("panik-ac") as HTMLElement);
    expect(el("panik-tip-guvenlik")).toBeTruthy();
    expect(el("panik-tip-yonetici_anons")).toBeTruthy();
    expect(el("panik-tip-sakin")).toBeNull();
  });

  it("DENETCI dugmeyi HIC gormez", async () => {
    taklit();
    ciz(() => PanikDugmesi({ rol: "denetci" }));
    expect(el("panik-ac")).toBeNull();
  });
});

describe("(P240 §1) iptal penceresi", () => {
  it("YASAL UYARI dugmelerden ONCE gorunur", async () => {
    // "112 yerine gecmez" cumlesi alarmi BASTIKTAN SONRA gosterilseydi
    // en kritik anda okunmazdi.
    taklit();
    ciz(() => PanikDugmesi({ rol: "resident" }));
    await userEvent.click(el("panik-ac") as HTMLElement);
    const uyari = el("panik-yasal") as HTMLElement;
    expect(uyari).toBeTruthy();
    expect(uyari.textContent).toMatch(/112/);
  });

  it("TETIKLEYINCE geri sayim cizilir ve IPTAL istegi gider", async () => {
    taklit();
    ciz(() => PanikDugmesi({ rol: "resident" }));
    await userEvent.click(el("panik-ac") as HTMLElement);
    await userEvent.click(el("panik-tip-sakin") as HTMLElement);

    await waitFor(() => expect(el("panik-geri-sayim")).toBeTruthy());
    expect(cagrilar.filter((c) => c.metot === "POST")).toHaveLength(1);

    await userEvent.click(el("panik-iptal") as HTMLElement);
    await waitFor(() =>
      expect(cagrilar.some((c) => c.url === "/api/panik/p1/iptal")).toBe(true),
    );
  });

  it("GERI SAYIM BITINCE ISTEMCI IKINCI ISTEK ATMAZ", async () => {
    // Yayin, sunucudaki gecikmeli gorevin isi. Istemciye baglamak,
    // sekme kapaninca alarmin HIC gitmemesi demekti.
    //
    // SAHTE ZAMANLAYICI KULLANILMIYOR: `userEvent` gercek zamanlayici
    // bekliyor ve ikisini birlikte kurmak testi 5 sn'de zaman asimina
    // ugratti (olculdu). Bunun yerine GERI SAYIM SURESINDEN UZUN
    // gercek bir bekleme yapilir — sayim 5 sn, bekleme 5.5 sn.
    taklit();
    ciz(() => PanikDugmesi({ rol: "resident" }));
    await userEvent.click(el("panik-ac") as HTMLElement);
    await userEvent.click(el("panik-tip-sakin") as HTMLElement);
    await waitFor(() => expect(el("panik-geri-sayim")).toBeTruthy());

    await new Promise((c) => setTimeout(c, 5_500));
    // Sayim BITTI (metin "Gönderildi"ye dondu) ama ISTEMCI ikinci bir
    // istek ATMADI.
    expect(el("panik-geri-sayim")?.textContent).toContain("Gönderildi");
    expect(cagrilar.filter((c) => c.metot === "POST")).toHaveLength(1);
  }, 15_000);
});

describe("(P240 §1) gelen alarm — tam ekran", () => {
  const ALARM = {
    id: "a1",
    tip: "sakin",
    durum: "acik",
    olusturan_ad: "Ayşe Yılmaz",
    olusturan_telefon: "+905551110000",
    daire_no: "12",
    blok: "A",
    checkpoint_ad: null,
    gps_lat: null,
    gps_lng: null,
    aciklama: null,
    son_24s_yanlis_alarm: 0,
  };

  it("ALARM VARSA ekrani kaplar; KAPATMA dugmesi YOK", async () => {
    // Kapatilabilir bir uyari, yogun bir ekranda REFLEKSLE kapatilir ve
    // alarm hic okunmadan kaybolur.
    taklit({ aktif: [ALARM] });
    ciz(PanikAlarmi);
    await waitFor(() => expect(el("panik-tam-ekran")).toBeTruthy());
    expect(el("panik-alarm-kim")?.textContent).toBe("Ayşe Yılmaz");
    expect(el("panik-alarm-yer")?.textContent).toBe("A 12");
    expect(el("panik-gordum")).toBeTruthy();
    expect(el("panik-mudahale")).toBeTruthy();
    const kapat = document.querySelector('[data-test="panik-tam-ekran"] [aria-label="Kapat"]');
    expect(kapat, "kapatma dugmesi OLMAMALI").toBeNull();
  });

  it("ALARM YOKSA hicbir sey cizilmez", async () => {
    taklit({ aktif: [] });
    ciz(PanikAlarmi);
    await waitFor(() => expect(cagrilar.length).toBeGreaterThan(0));
    expect(el("panik-tam-ekran")).toBeNull();
  });

  it("GIDIYORUM istegi sunucuya gider", async () => {
    taklit({ aktif: [ALARM] });
    ciz(PanikAlarmi);
    await waitFor(() => expect(el("panik-mudahale")).toBeTruthy());
    await userEvent.click(el("panik-mudahale") as HTMLElement);
    await waitFor(() =>
      expect(cagrilar.some((c) => c.url === "/api/panik/a1/mudahale")).toBe(true),
    );
  });

  it("TELEFON DOKUNULABILIR — acil durumda numara gosterilir", async () => {
    // Gunluk iletisimdeki riza kapisindan AYRI bir karar: alici kumesi
    // zaten guvenlik+yonetim ve her gosterim denetim kaydinda.
    taklit({ aktif: [ALARM] });
    ciz(PanikAlarmi);
    await waitFor(() => expect(el("panik-alarm-telefon")).toBeTruthy());
    expect((el("panik-alarm-telefon") as HTMLAnchorElement).getAttribute("href")).toBe(
      "tel:+905551110000",
    );
  });

  it("YANLIS ALARM SAYACI baglam verir (engel DEGIL)", async () => {
    taklit({ aktif: [{ ...ALARM, son_24s_yanlis_alarm: 3 }] });
    ciz(PanikAlarmi);
    await waitFor(() => expect(el("panik-alarm-yanlis-sayaci")).toBeTruthy());
    expect(el("panik-alarm-yanlis-sayaci")?.textContent).toContain("3");
    // Sayac YUKSEK olsa da mudahale dugmeleri ACIK kalir.
    expect((el("panik-mudahale") as HTMLButtonElement).disabled).toBe(false);
  });
});
