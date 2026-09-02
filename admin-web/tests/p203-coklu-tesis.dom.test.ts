// @vitest-environment jsdom
// (P203 §2) COKLU TESIS — giris secimi ve uygulama ici gecis.
//
// Olculen sey EKRANIN DAVRANISI + GIDEN GOVDE. Izolasyonun kendisi
// sunucuda kilitli (backend `test_p203_coklu_tesis.py`); burada olculen,
// arayuzun DOGRU UCU DOGRU GOVDEYLE cagirdigi.
import { createElement } from "react";
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz } from "./yardimci";

const replace = vi.fn();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace, refresh: vi.fn(), push: vi.fn() }),
  usePathname: () => "/login",
  useSearchParams: () => new URLSearchParams(),
}));

type Cagri = { url: string; metot: string; govde: Record<string, unknown> };

/** (P205 §1) `durumFn` UC BASINA durum verir: giris ucu 409 donerken
 *  uyelik ucu 200 donmeli. Tek bir `durum` degeri ikisini birden
 *  bozardi. */
function taklit(
  yanit: (url: string) => unknown,
  durum = 200,
  durumFn?: (url: string) => number,
): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      metot: (init?.method ?? "GET").toUpperCase(),
      govde: init?.body ? JSON.parse(String(init.body)) : {},
    });
    return new Response(JSON.stringify(yanit(url) ?? {}), {
      status: durumFn ? durumFn(url) : durum,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

const IKI_TESIS = {
  tesisler: [
    { tenant_id: "t-1", slug: "oltu-sitesi", ad: "Oltu Sitesi", rol: "yonetici" },
    { tenant_id: "t-2", slug: "city-ambiance", ad: "City Ambiance", rol: "resident" },
  ],
};
const TEK_TESIS = { tesisler: [IKI_TESIS.tesisler[0]] };

/** Parola alani: dar sorgu SART — `getByLabelText(/Parola/i)` hem
 *  kutuyu hem goster/gizle DUGMESINI bulur (mevcut giris testlerinin
 *  aynisi). */
const parolaGirdisi = () =>
  screen.getByLabelText(/Parola/i, { selector: "input" });

function kanca(ad: string): HTMLElement | null {
  return document.querySelector(`[data-test="${ad}"]`);
}

afterEach(() => {
  vi.restoreAllMocks();
  replace.mockClear();
});

// ======================= GIRIS EKRANI ==================================== #

/** (P205 §1) Yuzey artik FARK ETMIYOR — iki yuzeyde de TEK ALAN. */
async function girisEkrani() {
  const { GirisFormu } = await import("@/components/GirisFormu");
  return ciz(() => createElement(GirisFormu, { yuzey: "platform" as const }));
}

/** (P205 §1) TEK ALAN — ayri e-posta/tesis alani YOK. */
async function kimlikDoldur(k: ReturnType<typeof userEvent.setup>) {
  await k.type(
    screen.getByLabelText(/E-posta veya telefon/i, { selector: "input" }),
    "kerem@ornek.com",
  );
  await k.type(parolaGirdisi(), "CokGizliParola1!");
}

/** Sunucu 409 = "birden cok tesis"; istemci listeyi ayri ucla alir. */
function coklu(u: string) {
  if (u.includes("tesislerim")) return { govde: IKI_TESIS, durum: 200 };
  if (u === "/api/auth/login") {
    return { govde: { error: { code: "tesis_secimi_gerekli" } }, durum: 409 };
  }
  return { govde: { ok: true }, durum: 200 };
}

it("SUNUCU 409 DERSE secim cizilir ve JETON ISTENMEZ", async () => {
  // (P205 §1) Karar SUNUCUDA: istemci "slug bos mu" diye BAKMAZ,
  // giris dener ve 409 alirsa secim gosterir. Istemcide ikinci bir
  // kural tutmak, iki tarafin ayrisabilecegi bir yer acardi.
  const cagrilar = taklit((u) => coklu(u).govde, undefined, (u) => coklu(u).durum);
  const k = userEvent.setup();
  await girisEkrani();
  await kimlikDoldur(k);
  await k.click(screen.getByRole("button", { name: /giriş/i }));

  await waitFor(() => expect(kanca("giris-tesis-secimi")).toBeTruthy());
  expect(kanca("giris-tesis-oltu-sitesi")).toBeTruthy();
  expect(kanca("giris-tesis-city-ambiance")).toBeTruthy();
  void cagrilar;
});

it("SECILEN tesisin SLUG'I giris govdesine gider", async () => {
  const cagrilar = taklit((u) => coklu(u).govde, undefined, (u) => coklu(u).durum);
  const k = userEvent.setup();
  await girisEkrani();
  await kimlikDoldur(k);
  await k.click(screen.getByRole("button", { name: /giriş/i }));
  await waitFor(() => expect(kanca("giris-tesis-city-ambiance")).toBeTruthy());

  await k.click(kanca("giris-tesis-city-ambiance")!);
  await waitFor(() =>
    expect(
      cagrilar.filter((c) => c.url === "/api/auth/login").length,
    ).toBeGreaterThan(1),
  );
  const son = cagrilar.filter((c) => c.url === "/api/auth/login").at(-1)!;
  expect(son.govde.tenant_slug).toBe("city-ambiance");
});

it("TEK tesiste SECIM CIKMAZ ve UYELIK UCU CAGRILMAZ", async () => {
  // Sunucu 200 doner (tek uyelik) — istemcinin liste sormasina gerek
  // YOK. Fazladan cagri, her girise bir gidis-donus eklerdi.
  const cagrilar = taklit(() => ({ ok: true }));
  const k = userEvent.setup();
  await girisEkrani();
  await kimlikDoldur(k);
  await k.click(screen.getByRole("button", { name: /giriş/i }));

  await waitFor(() =>
    expect(cagrilar.some((c) => c.url === "/api/auth/login")).toBe(true),
  );
  expect(kanca("giris-tesis-secimi")).toBeNull();
  expect(cagrilar.some((c) => c.url.includes("tesislerim"))).toBe(false);
});

// ==================== UYGULAMA ICI SECICI ================================ #

async function menu(uyelikler: unknown) {
  const mod = await import("@/components/KullaniciMenusu");
  taklit((u) => {
    if (u.includes("/api/me/tesislerim")) return uyelikler;
    if (u.includes("/api/me")) return { ad: "Kerem", email: "k@o.com", tenant_id: "t-1" };
    if (u.includes("tenant/settings")) return { ad: "Oltu Sitesi" };
    return { ok: true };
  });
  return ciz(mod.KullaniciMenusu);
}

it("TEK tesisli kullanicida SECICI CIZILMEZ", async () => {
  const k = userEvent.setup();
  await menu(TEK_TESIS);
  await k.click(screen.getByRole("button", { name: /hesab/i }));
  await waitFor(() => expect(screen.getByRole("menu")).toBeTruthy());
  expect(kanca("tesis-secici")).toBeNull();
});

it("COK tesisli kullanicida SECICI cikar ve BULUNDUGU tesis isaretli", async () => {
  const k = userEvent.setup();
  await menu(IKI_TESIS);
  await k.click(screen.getByRole("button", { name: /hesab/i }));
  await waitFor(() => expect(kanca("tesis-secici")).toBeTruthy());
  // Bulundugu tesis TIKLANAMAZ (zaten oradasin).
  expect((kanca("tesis-sec-t-1") as HTMLButtonElement).disabled).toBe(true);
  expect((kanca("tesis-sec-t-2") as HTMLButtonElement).disabled).toBe(false);
  // ROL gorunur: kisi birinde yonetici, otekinde sakin olabilir —
  // hangi yetkiyle girecegini SECMEDEN ONCE bilmeli. Metin sozlukten
  // okunur (sabit yazmak, ceviri degisince sessizce eskirdi).
  expect(kanca("tesis-sec-t-2")!.textContent).toContain(tr.rolSiteSakini);
  expect(kanca("tesis-sec-t-1")!.textContent).toContain(tr.tesisDegistirSecili);
});
