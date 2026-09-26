// @vitest-environment jsdom
// (P248 §2) TELEFON ALANI HER YERDE AYNI — tel uzerindeki govde olculur.
//
// ===========================================================================
// NE OLCULUYOR
// ===========================================================================
// Kullanici ekleme ekranindaki ORTAK bilesen (`TelefonAlani`) artik giris
// ekraninda (kimlik kipi), Excel ice aktarim tablosunda (hucre kipi) ve
// tanitim iletisim formunda da kullaniliyor. Her birinde:
//   (a) ulke kodu SECILEBILIYOR / yapistirilan `+49` kendi ulkesini getiriyor,
//   (b) numara bicimleniyor,
//   (c) sunucuya giden deger E.164 (kullanici ekleme ekraniyla AYNI).
// Taklit `fetch`te — formun GERCEKTEN gonderdigi govde okunur (P200 dersi).
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { kimlikGonderimDegeri, kimlikTelefonMu, telefonHatasi } from "@/lib/telefon";

import { ciz } from "./yardimci";

const replace = vi.fn();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace, refresh: vi.fn(), push: vi.fn() }),
  usePathname: () => "/login",
  useSearchParams: () => new URLSearchParams(),
}));

type Cagri = { url: string; metot: string; govde: Record<string, unknown> };

function taklit(yanitla: (url: string, metot: string) => unknown = () => ({ ok: true })): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const metot = (init?.method ?? "GET").toUpperCase();
    cagrilar.push({
      url,
      metot,
      govde: init?.body ? JSON.parse(String(init.body)) : {},
    });
    return new Response(JSON.stringify(yanitla(url, metot)), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

const kanca = (ad: string) =>
  document.querySelector(`[data-test="${ad}"]`) as HTMLElement | null;

beforeEach(() => replace.mockClear());
afterEach(() => {
  vi.restoreAllMocks();
  localStorage.clear();
});

// ------------------------------------------------------------------ //
// 1. KARAR KURALI (saf fonksiyon)
// ------------------------------------------------------------------ //
describe("kimlik kipi karari", () => {
  it.each([
    ["0532", true],
    ["+49 151", true],
    ["(+90) 532", true],
    ["a@b.c", false],
    ["123ali@x.com", false],
    ["kerem", false],
    ["", false],
  ])("%s -> telefon mu: %s", (girdi, beklenen) => {
    expect(kimlikTelefonMu(girdi)).toBe(beklenen);
  });

  it("gonderim degeri: telefon E.164, e-posta oldugu gibi", () => {
    expect(kimlikGonderimDegeri("0543 199 29 04")).toBe("+905431992904");
    expect(kimlikGonderimDegeri("(+49) 151 23456789")).toBe("+4915123456789");
    expect(kimlikGonderimDegeri(" kerem@ornek.com ")).toBe("kerem@ornek.com");
  });

  it("sabit hat: firma numarasinda TR `5` on eki aranmaz", () => {
    expect(telefonHatasi("(+90) 212 555 44 33", true)).toBe("gecersizOnEk");
    expect(telefonHatasi("(+90) 212 555 44 33", true, true)).toBeNull();
  });
});

// ------------------------------------------------------------------ //
// 2. GIRIS EKRANI — tek alan, telefon kipinde ulke secici
// ------------------------------------------------------------------ //
describe("giris ekrani (P205 tek alan)", () => {
  async function form() {
    const { GirisFormu } = await import("@/components/GirisFormu");
    return ciz(() => createElement(GirisFormu, { yuzey: "tesis" as const }));
  }
  const kimlik = () =>
    screen.getByLabelText(/E-posta veya telefon/i, { selector: "input" }) as HTMLInputElement;
  const parola = () => screen.getByLabelText(/Parola/i, { selector: "input" });

  it("E-POSTA yazilirken ulke secici YOK, harf yazilinca e-postaya doner", async () => {
    const k = userEvent.setup();
    await form();
    expect(kanca("telefon-ulke")).toBeNull();
    await k.type(kimlik(), "123ali@x.com");
    // Rakamla baslayan e-posta KAYBOLMAZ: ilk harfte e-posta kipine doner.
    expect(kimlik().value).toBe("123ali@x.com");
    expect(kanca("telefon-ulke")).toBeNull();
    expect(kimlik().getAttribute("autocomplete")).toBe("username");
  });

  it("RAKAM yazilinca ulke secici belirir, numara BICIMLENIR", async () => {
    const k = userEvent.setup();
    await form();
    await k.type(kimlik(), "05431992904");
    expect(kanca("telefon-ulke")).toBeTruthy();
    expect(kanca("telefon-ulke")!.textContent).toContain("+90");
    expect(kimlik().value).toBe("543 199 29 04");
  });

  it("YABANCI numara: ulke secilir, govdede E.164 gider", async () => {
    const k = userEvent.setup();
    const c = taklit();
    await form();
    await k.type(kimlik(), "1");
    // Ulke kutusundan Almanya.
    await k.click(kanca("telefon-ulke")!);
    await k.click(kanca("telefon-ulke-DE")!);
    await k.clear(kimlik());
    await k.type(kimlik(), "15123456789");
    await k.type(parola(), "CokGizliParola1!");
    await k.click(screen.getByRole("button", { name: /giriş yap/i }));
    await waitFor(() =>
      expect(c.some((x) => x.url === "/api/auth/login")).toBe(true),
    );
    expect(c.find((x) => x.url === "/api/auth/login")!.govde.kimlik).toBe(
      "+4915123456789",
    );
  });

  it("`+49 151...` KARAKTER KARAKTER yazilinca ulke kaybolmaz", async () => {
    // Playwright olcumu: `+49` ulke kutusuna gecip numara kutusu bosalinca
    // ardindan gelen BOSLUK alani e-postaya dusuruyordu; numara `+90151...`
    // olarak gidiyor ve giris 401 aliyordu.
    const k = userEvent.setup();
    const c = taklit();
    await form();
    await k.type(kimlik(), "+49 151 23456789");
    expect(kanca("telefon-ulke")!.textContent).toContain("+49");
    await k.type(parola(), "CokGizliParola1!");
    await k.click(screen.getByRole("button", { name: /giriş yap/i }));
    await waitFor(() =>
      expect(c.some((x) => x.url === "/api/auth/login")).toBe(true),
    );
    expect(c.find((x) => x.url === "/api/auth/login")!.govde.kimlik).toBe(
      "+4915123456789",
    );
  });

  it("YAPISTIRILAN `+44` kendi ulkesini getirir", async () => {
    const k = userEvent.setup();
    const c = taklit();
    await form();
    await k.click(kimlik());
    await k.paste("+44 7911 123456");
    expect(kanca("telefon-ulke")!.textContent).toContain("+44");
    await k.type(parola(), "CokGizliParola1!");
    await k.click(screen.getByRole("button", { name: /giriş yap/i }));
    await waitFor(() =>
      expect(c.some((x) => x.url === "/api/auth/login")).toBe(true),
    );
    expect(c.find((x) => x.url === "/api/auth/login")!.govde.kimlik).toBe(
      "+447911123456",
    );
  });
});

// ------------------------------------------------------------------ //
// 3. EXCEL ICE AKTARIM TABLOSU — telefon hucresi ortak bilesende
// ------------------------------------------------------------------ //
describe("ice aktarim tablosu", () => {
  const TURLER = [
    {
      kod: "daire",
      aciklama: "Daireler",
      alanlar: [
        { kod: "blok", zorunlu: true, ornek: "A" },
        { kod: "daire_no", zorunlu: true, ornek: "A-1" },
        { kod: "sakin_telefon", zorunlu: false, ornek: "+905321112233" },
      ],
    },
  ];
  const cevap = (url: string, metot: string) => {
    if (url.includes("ice-aktarim-turler")) return TURLER;
    if (url.includes("/api/panel/ice-aktarim?")) return { items: [] };
    if (metot === "POST")
      return {
        satir_sayisi: 1, olusan: 1, atlanan: 0, guncellenen: 0, hatali: 0,
        hatalar: [], aktarim_id: null, uygulanmadi: true,
        davet_gonderildi: 0, davet_basarisiz: 0, davet_hatalari: [],
      };
    return { ok: true };
  };

  it("telefon hucresinde ulke secici var, numara bicimli, govde E.164", async () => {
    const k = userEvent.setup();
    const c = taklit(cevap);
    const { default: Sayfa } = await import("@/app/(protected)/ice-aktarim/page");
    ciz(Sayfa);
    await waitFor(() => expect(kanca("aktarim-hucre-0-sakin_telefon")).toBeTruthy());
    const tablo = kanca("aktarim-tablosu")!;
    // Hucre ORTAK bilesen: ulke kutusu hucrenin icinde.
    expect(tablo.querySelectorAll('[data-test="telefon-ulke"]').length).toBeGreaterThan(0);

    // Excel'den yapistirma HALA calisiyor (telefon sutunu dahil).
    await k.click(kanca("aktarim-hucre-0-blok")!);
    await k.paste("A\tA-1\t+49 151 23456789");
    const hucre = kanca("aktarim-hucre-0-sakin_telefon") as HTMLInputElement;
    await waitFor(() => expect(hucre.value).toBe("151 234 567 89"));

    await k.click(
      Array.from(document.querySelectorAll("button")).find((b) =>
        /Önizle/.test(b.textContent ?? ""),
      )!,
    );
    await waitFor(() => expect(c.some((x) => x.metot === "POST")).toBe(true));
    const satirlar = c.find((x) => x.metot === "POST")!.govde.satirlar as {
      degerler: Record<string, string>;
    }[];
    expect(satirlar[0].degerler.sakin_telefon).toBe("+4915123456789");
    expect(satirlar[0].degerler.blok).toBe("A");
  });
});

// ------------------------------------------------------------------ //
// 4. TANITIM ILETISIM FORMU
// ------------------------------------------------------------------ //
describe("tanitim iletisim formu", () => {
  it("ulke secilir, sabit hat kabul, govdede E.164", async () => {
    const k = userEvent.setup();
    const c = taklit();
    const { TanitimForm } = await import("@/components/TanitimForm");
    ciz(() => createElement(TanitimForm));
    await k.type(document.querySelector('input[name="ad"]')!, "Ali Veli");
    await k.click(kanca("telefon-ulke")!);
    await k.click(kanca("telefon-ulke-TR")!);
    // SABIT HAT: firma/ofis numarasi `5` ile baslamaz.
    await k.type(kanca("telefon-numara")!, "2125554433");
    expect((kanca("telefon-numara") as HTMLInputElement).value).toBe("212 555 44 33");
    await k.type(document.querySelector('textarea[name="mesaj"]')!, "Merhaba dunya");
    await k.click(document.querySelector('button[type="submit"]')!);
    await waitFor(() =>
      expect(c.some((x) => x.url === "/api/tanitim-iletisim")).toBe(true),
    );
    expect(c.find((x) => x.url === "/api/tanitim-iletisim")!.govde.telefon).toBe(
      "+902125554433",
    );
  });
});
