// @vitest-environment jsdom
// (P200 §1) SIFREMI UNUTTUM — AKISIN TAMAMI.
//
// =========================================================================
// NEDEN BU DOSYA VAR
// =========================================================================
// 297 satirlik bu ekranin HIC DOM testi yoktu. Ustelik P196 gonderim
// yoluna dokundu. "Kaynaga baktim, dogru gorunuyor" bu turda tam olarak
// yetmeyen sey oldu (P198: kayit akisi parca parca olculuyordu, akisin
// KENDISI olculmuyordu ve prod'da kirildi).
//
// Bu yuzden burada olculen sey EKRANIN DAVRANISI degil yalnizca, ISTEMCININ
// SUNUCUYA NE GONDERDIGIdir: hangi uca, hangi govdeyle. Sunucu tarafi
// ayrica canli olculdu (bkz. docs/P200-kararlar.md §1).
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, expect, it, vi } from "vitest";

import { ciz } from "./yardimci";

const replace = vi.fn();
let arama = new URLSearchParams();

vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace, refresh: vi.fn(), push: vi.fn() }),
  usePathname: () => "/giris/sifremi-unuttum",
  useSearchParams: () => arama,
}));

type Cagri = { url: string; govde: Record<string, unknown> };

/** Cagrilari GOVDESIYLE kaydeder. Ortak `fetchSahtele` yalniz url
 *  tutuyor; burada olculmek istenen sey tam da GOVDE. */
function taklit(yanit: (url: string) => Response): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      govde: init?.body ? JSON.parse(String(init.body)) : {},
    });
    return yanit(url);
  }) as typeof fetch;
  return cagrilar;
}

const OK = () =>
  new Response(JSON.stringify({ durum: "onay_bekliyor" }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });

function hataYaniti(durum: number, mesaj: string) {
  return new Response(JSON.stringify({ error: { code: "x", message: mesaj } }), {
    status: durum,
    headers: { "Content-Type": "application/json" },
  });
}

async function ciziver() {
  const mod = await import("@/app/giris/sifremi-unuttum/page");
  return ciz(mod.default);
}

beforeEach(() => {
  arama = new URLSearchParams();
  replace.mockClear();
});

afterEach(() => {
  vi.restoreAllMocks();
});

/** Birinci adimi doldurup gonderir. */
async function kodIste(k: ReturnType<typeof userEvent.setup>) {
  await k.type(screen.getByLabelText("Tesis (slug)"), "oltu-sitesi");
  await k.type(screen.getByLabelText("E-posta"), "kerem@example.com");
  await k.click(screen.getByRole("button", { name: "Kod gönder" }));
}

it("AKISIN TAMAMI: kod iste -> kod + yeni parola -> girise don", async () => {
  const cagrilar = taklit(() => OK());
  const k = userEvent.setup();
  await ciziver();

  await kodIste(k);

  // --- 1. ISTEK: dogru uca, dogru govdeyle
  await waitFor(() => expect(cagrilar).toHaveLength(1));
  expect(cagrilar[0].url).toBe("/api/auth/sifre/kod-iste");
  expect(cagrilar[0].govde).toEqual({
    tenant_slug: "oltu-sitesi",
    eposta: "kerem@example.com",
  });

  // --- IKINCI ADIM ACILDI MI
  const kodAlani = await screen.findByLabelText("Doğrulama kodu");
  await k.type(kodAlani, "123456");
  await k.type(screen.getByLabelText("Yeni parola"), "YeniParola1!");
  await k.click(screen.getByRole("button", { name: "Parolayı güncelle" }));

  // --- 2. ISTEK: dort alanin DORDU de gitmeli.
  // Eksik bir alan (ornegin tenant_slug) sunucuda 422 olurdu ve
  // kullanici "kod gecersiz" saniyordu.
  await waitFor(() => expect(cagrilar).toHaveLength(2));
  expect(cagrilar[1].url).toBe("/api/auth/sifre/dogrula-ve-ayarla");
  expect(cagrilar[1].govde).toEqual({
    tenant_slug: "oltu-sitesi",
    eposta: "kerem@example.com",
    kod: "123456",
    yeni_parola: "YeniParola1!",
  });

  // --- BITTI EKRANI ve GIRISE DONUS
  await screen.findByText(/parolanız güncellendi/i);
  await k.click(screen.getByRole("button", { name: "Girişe dön" }));
  expect(replace).toHaveBeenCalledWith("/giris");
});

it("BICIM hatasi varken SUNUCUYA HIC GITMEZ", async () => {
  // Sizdirmama kurali: gecersiz slug/eposta sunucuya sorulmaz. Ayrica
  // hiz sinirini bos yere yemek istemeyiz.
  const cagrilar = taklit(() => OK());
  const k = userEvent.setup();
  await ciziver();

  await k.type(screen.getByLabelText("Tesis (slug)"), "Oltu Sitesi!");
  await k.type(screen.getByLabelText("E-posta"), "kerem");
  await k.click(screen.getByRole("button", { name: "Kod gönder" }));

  expect(cagrilar).toHaveLength(0);
  // Iki alan da KIRMIZI ve altlarinda sebep yaziyor.
  expect(
    screen.getByText("Tesis kodu yalnızca küçük harf, rakam ve tire içerebilir."),
  ).toBeTruthy();
  expect(screen.getByText("Geçerli bir e-posta adresi girin.")).toBeTruthy();
  // NOT: hata metni `label`in ICINE cizildigi icin etiket metni artik
  // "Tesis (slug)" + hata cumlesi; alan yer tutucusundan bulunur.
  expect(
    screen.getByPlaceholderText("yonetio").getAttribute("aria-invalid"),
  ).toBe("true");
});

it("SIZDIRMAMA: hesap olmasa da (200) ikinci adima gecilir", async () => {
  // Sunucu hesap var/yok/dogrulanmamis AYRIMI YAPMADAN ayni 200'u
  // doner. Ekran bunu "kod gonderildi" diye gostermeli; aksi hâlde
  // ekran, sunucunun sakladigi bilgiyi sizdirirdi.
  taklit(() => OK());
  const k = userEvent.setup();
  await ciziver();
  await kodIste(k);
  expect(await screen.findByLabelText("Doğrulama kodu")).toBeTruthy();
});

it("HIZ SINIRI (429) ikinci adima GECIRMEZ ve sunucunun mesajini gosterir", async () => {
  taklit(() => hataYaniti(429, "Çok fazla deneme yaptınız."));
  const k = userEvent.setup();
  await ciziver();
  await kodIste(k);

  expect(await screen.findByText("Çok fazla deneme yaptınız.")).toBeTruthy();
  expect(screen.queryByLabelText("Doğrulama kodu")).toBeNull();
});

it("YANLIS KOD: ekran ikinci adimda KALIR, sunucu mesajini gosterir", async () => {
  // Kusur olsaydi ekran "bitti" derdi ve kullanici parolasinin
  // degistigini SANARDI — sonra giremezdi.
  taklit((url) =>
    url.includes("dogrula-ve-ayarla") ? hataYaniti(422, "Kod geçersiz.") : OK(),
  );
  const k = userEvent.setup();
  await ciziver();
  await kodIste(k);

  await k.type(await screen.findByLabelText("Doğrulama kodu"), "000000");
  await k.type(screen.getByLabelText("Yeni parola"), "YeniParola1!");
  await k.click(screen.getByRole("button", { name: "Parolayı güncelle" }));

  expect(await screen.findByText("Kod geçersiz.")).toBeTruthy();
  expect(screen.getByLabelText("Doğrulama kodu")).toBeTruthy();
  expect(screen.queryByText(/parolanız güncellendi/i)).toBeNull();
});

it("BAGLANTIDAN gelen tesis/eposta ON DOLDURULUR ve AYNEN gonderilir", async () => {
  arama = new URLSearchParams({ tesis: "oltu-sitesi", eposta: "a@b.com" });
  const cagrilar = taklit(() => OK());
  const k = userEvent.setup();
  await ciziver();

  await k.click(screen.getByRole("button", { name: "Kod gönder" }));
  await waitFor(() => expect(cagrilar).toHaveLength(1));
  expect(cagrilar[0].govde).toEqual({
    tenant_slug: "oltu-sitesi",
    eposta: "a@b.com",
  });
});
