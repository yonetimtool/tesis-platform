// @vitest-environment jsdom
// (P253 acil) E-POSTA BUYUK HARF — EKRANDA REDDEDILIR, GONDERILMEZ.
//
// OLCULEN KUSUR (prod): 4 adres buyuk harfle basliyordu; 4 adres harf
// farkiyla iki kez kayitliydi. Ekran buyuk harfi kabul ediyordu.
//
// KARAR: buyuk harf yazilinca alan HEMEN "E-posta adresi kucuk harfle
// yazilmalidir." der ve form gonderilmez. Sunucu ayrica kucultur (SSO,
// Excel) — burada olculen EKRAN.
//
// P250 sizintisi olculdu: ad/soyad bicimleyicisi (`adBicimle`,
// `soyadBicimle`) e-posta alanina UYGULANMIYOR — asagidaki kaynak kilidi
// bunu kalici kilar.
import { readFileSync } from "node:fs";

import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import Sayfa from "@/components/kisiler/kullanici-listesi";
import { tr } from "@/lib/i18n/sozluk/tr";

import { taranacakDosyalar } from "./tarama";
import { ciz } from "./yardimci";

type Cagri = { url: string; metot: string; govde: Record<string, unknown> };

function taklit(): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      metot: (init?.method ?? "GET").toUpperCase(),
      govde: init?.body ? JSON.parse(String(init.body)) : {},
    });
    const govde =
      url.startsWith("/api/users") && init?.method === "POST"
        ? { id: "u-yeni" }
        : { items: [], meta: { total: 0 } };
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

afterEach(() => vi.restoreAllMocks());

async function doldur(k: ReturnType<typeof userEvent.setup>, eposta: string) {
  ciz(Sayfa);
  await k.click(
    await screen.findByRole("button", { name: new RegExp(tr.kullaniciYeni, "i") }),
  );
  await k.type(
    await screen.findByLabelText(new RegExp(`^${tr.ortakAd}\\s*\\*?$`)),
    "Furkan",
  );
  await k.type(screen.getByLabelText(new RegExp(`^${tr.kisiSoyad}\\s*\\*?$`)), "Kaymakci");
  await k.type(screen.getByLabelText(new RegExp(tr.kullaniciEposta, "i")), eposta);
}

it("BUYUK HARF: alan ANINDA hata verir ve form GONDERILMEZ", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  await doldur(k, "Frknkymkc1996@gmail.com");

  // Alandan cikilmadan (blur yok) hata gorunur.
  expect(screen.getAllByText(tr.epostaHataBuyukHarf).length).toBeGreaterThan(0);

  await k.click(screen.getByRole("button", { name: new RegExp(tr.ortakKaydet, "i") }));
  await new Promise((r) => setTimeout(r, 50));
  expect(cagrilar.some((c) => c.url === "/api/users" && c.metot === "POST")).toBe(false);
});

it("KUCUK HARF: gonderilir, adres DEGISMEDEN gider (ad bicimi sizmaz)", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  await doldur(k, "frknkymkc1996@gmail.com");
  expect(screen.queryByText(tr.epostaHataBuyukHarf)).toBeNull();
  await k.click(screen.getByRole("button", { name: new RegExp(tr.ortakKaydet, "i") }));
  await waitFor(() =>
    expect(cagrilar.some((c) => c.url === "/api/users" && c.metot === "POST")).toBe(true),
  );
  const post = cagrilar.find((c) => c.url === "/api/users" && c.metot === "POST")!;
  expect(post.govde.email).toBe("frknkymkc1996@gmail.com");
});

it("KAYNAK KILIDI: e-posta alani olan her form gonderimde buyuk harfi denetler", () => {
  // `<EpostaAlani` kullanan dosya `epostaGonderilemez` (ya da kurali iceren
  // `epostaHataMetni`) cagirmali; aksi halde alan hata gosterir ama form
  // yine gonderilir.
  const eksik: string[] = [];
  for (const yol of taranacakDosyalar(["app", "components"])) {
    if (yol.endsWith("components/EpostaAlani.tsx")) continue;
    const s = readFileSync(yol, "utf8");
    if (!/<EpostaAlani\b/.test(s)) continue;
    if (!/epostaGonderilemez\(|epostaHataMetni\(/.test(s)) eksik.push(yol);
  }
  expect(eksik).toEqual([]);
});

it("KAYNAK KILIDI: ad/soyad bicimleyicisi e-posta degerine UYGULANMAZ (P250)", () => {
  const ihlal: string[] = [];
  for (const yol of taranacakDosyalar(["app", "components"])) {
    const satirlar = readFileSync(yol, "utf8").split("\n");
    satirlar.forEach((l, i) => {
      if (/(adBicimle|soyadBicimle)\([^)]*(eposta|email)/i.test(l)) {
        ihlal.push(`${yol}:${i + 1}`);
      }
    });
  }
  expect(ihlal).toEqual([]);
});
