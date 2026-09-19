// @vitest-environment jsdom
// (P243 §4) WEB GORUNUM MODU — STANDART / BUYUK.
//
// ===========================================================================
// NE OLCULUYOR
// ===========================================================================
//  * secim KOK SINIFINI degistiriyor (tum arayuz oradan olcekleniyor),
//  * cerez yaziliyor (SSR ilk karede basabilsin — titreme yok),
//  * hesaba da yaziliyor (baska tarayicida ayni gorunum),
//  * tokenlar GERCEKTEN buyuyor ve KONTRAST tokenlarina DOKUNULMUYOR.
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import { GorunumSecici } from "@/components/GorunumSecici";

import { ciz } from "./yardimci";

type Cagri = { url: string; metot: string; govde: Record<string, unknown> };

function taklit(uiGorunum = "standart"): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      metot: (init?.method ?? "GET").toUpperCase(),
      govde: init?.body ? JSON.parse(String(init.body)) : {},
    });
    const govde = url.startsWith("/api/me")
      ? { id: "u-1", ui_gorunum: uiGorunum }
      : { ok: true };
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

const kanca = (ad: string) =>
  document.querySelector(`[data-test="${ad}"]`) as HTMLElement | null;

afterEach(() => {
  vi.restoreAllMocks();
  document.documentElement.classList.remove("yz-buyuk");
  document.cookie = "gorunum=; max-age=0; path=/";
});

it("BUYUK secimi KOK SINIFINI acar ve CEREZE yazar", async () => {
  const k = userEvent.setup();
  taklit();
  ciz(GorunumSecici);
  await waitFor(() => expect(kanca("gorunum-buyuk")).toBeTruthy());
  expect(document.documentElement.classList.contains("yz-buyuk")).toBe(false);

  await k.click(kanca("gorunum-buyuk")!);
  expect(document.documentElement.classList.contains("yz-buyuk")).toBe(true);
  // CEREZ: SSR ilk karede sinifi basabilsin — yoksa sayfa once KUCUK
  // cizilir ve tam da bu ayara ihtiyac duyan kisi bir kare okuyamaz.
  expect(document.cookie).toContain("gorunum=buyuk");
});

it("SECIM HESABA DA yazilir (baska tarayicida ayni gorunum)", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  ciz(GorunumSecici);
  await waitFor(() => expect(kanca("gorunum-buyuk")).toBeTruthy());
  await k.click(kanca("gorunum-buyuk")!);
  await waitFor(() => {
    const p = cagrilar.find(
      (c) => c.metot === "PATCH" && c.url === "/api/me/gorunum",
    );
    expect(p).toBeTruthy();
    expect(p!.govde.gorunum).toBe("buyuk");
  });
});

it("HESAPTAKI TERCIH acilista uygulanir", async () => {
  taklit("buyuk");
  ciz(GorunumSecici);
  await waitFor(() =>
    expect(document.documentElement.classList.contains("yz-buyuk")).toBe(true),
  );
});

it("STANDARDA DONUS sinifi KALDIRIR", async () => {
  const k = userEvent.setup();
  taklit();
  ciz(GorunumSecici);
  await waitFor(() => expect(kanca("gorunum-buyuk")).toBeTruthy());
  await k.click(kanca("gorunum-buyuk")!);
  await k.click(kanca("gorunum-standart")!);
  expect(document.documentElement.classList.contains("yz-buyuk")).toBe(false);
  expect(document.cookie).toContain("gorunum=standart");
});

// ===========================================================================
// TOKENLAR — CSS'in KENDISI OLCULUYOR
// ===========================================================================
// jsdom CSS degiskenlerini hesaplamaz; bu yuzden tasarim dosyasi
// KAYNAK OLARAK okunuyor. Olculen sey "sinif var mi" degil, sinifin
// GERCEKTEN daha buyuk degerler tanimladigi.
function tokenlar(blok: string): Record<string, number> {
  const kaynak = readFileSync(
    join(process.cwd(), "app", "tasarim-sistemi.css"),
    "utf8",
  );
  // BLOK, ICINDEKI TOKENLA BULUNUR: `:root {` dosyada birden cok kez
  // geciyor (renk, olcu, boslik ayri bloklarda) ve ilkini almak yanlis
  // blogu olcmekti — ilk yazimda tam bunu yaptim ve test "tabanda yok"
  // dedi.
  const imza = `--yz-fs-display`;
  let i = -1;
  let ara = 0;
  while ((ara = kaynak.indexOf(blok, ara)) !== -1) {
    const son = kaynak.indexOf("}", ara);
    if (kaynak.slice(ara, son).includes(imza)) {
      i = ara;
      break;
    }
    ara = son;
  }
  expect(i, `blok bulunamadi: ${blok}`).toBeGreaterThan(-1);
  const govde = kaynak.slice(i, kaynak.indexOf("}", i));
  const cikti: Record<string, number> = {};
  for (const m of govde.matchAll(/--(yz-fs-[a-z0-9]+):\s*(\d+)px/g)) {
    cikti[m[1]] = Number(m[2]);
  }
  return cikti;
}

it("BUYUK MOD tokenlari GERCEKTEN buyutur", () => {
  const taban = tokenlar(":root {");
  const buyuk = tokenlar(":root.yz-buyuk {");
  expect(Object.keys(buyuk).length).toBeGreaterThan(5);
  for (const [ad, deger] of Object.entries(buyuk)) {
    expect(taban[ad], `tabanda yok: ${ad}`).toBeTruthy();
    expect(deger, ad).toBeGreaterThan(taban[ad]);
  }
  // MENU, TABLO, FORM ETIKETI ve DUGME hep bu tokenlardan ciziliyor;
  // ayri ayri buyutmek, yeni bir bilesende unutulacak bir adim
  // birakirdi.
  expect(buyuk["yz-fs-body"]).toBeGreaterThanOrEqual(16);
});

it("BUYUK MOD RENK tokenlarina DOKUNMAZ (kontrast korunur)", () => {
  const kaynak = readFileSync(
    join(process.cwd(), "app", "tasarim-sistemi.css"),
    "utf8",
  );
  const i = kaynak.indexOf(":root.yz-buyuk {");
  const govde = kaynak.slice(i, kaynak.indexOf("}", i));
  // Renk degiskeni TANIMLANMAMALI: buyuk mod yalniz OLCU degistirir,
  // kontrast oranlari P160'ta olculmus haliyle kalir.
  expect(govde).not.toMatch(/--yz-(text|bg|surface|accent|danger)[a-z0-9-]*:/);
});
