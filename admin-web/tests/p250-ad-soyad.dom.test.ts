// @vitest-environment jsdom
// (P250 §1) AD + SOYAD — Turkce harf kuraliyla bicim, web.
//
// (1) Kural: sunucudaki `kisi_adi.py` ile AYNI ornekler.
// (2) Kullanici ekleme formu: iki ayri zorunlu alan, YAZARKEN bicimlenir,
//     sunucuya giden govdede `ad` ve `soyad` ayri ve bicimli.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import Sayfa from "@/app/(protected)/users/page";
import { tr } from "@/lib/i18n/sozluk/tr";
import { adAyir, adBicimle, soyadBicimle, tamAd, trBuyuk, trKucuk } from "@/lib/kisi-adi";

import { ciz } from "./yardimci";

describe("kural (sunucu ikizi)", () => {
  it.each([
    ["mehmet ali", "Mehmet Ali"],
    ["ışıl", "Işıl"],
    ["ilker", "İlker"],
    ["çiğdem", "Çiğdem"],
    ["İLKER", "İlker"],
    ["IŞIL", "Işıl"],
    ["  ayşe   nur  ", "Ayşe Nur"],
    ["ayşe-nur", "Ayşe-Nur"],
    ["ÖMER FARUK", "Ömer Faruk"],
    ["şükrü", "Şükrü"],
  ])("ad %s -> %s", (g, b) => expect(adBicimle(g)).toBe(b));

  it.each([
    ["yılmaz", "YILMAZ"],
    ["öztürk", "ÖZTÜRK"],
    ["işçi", "İŞÇİ"],
    ["çiftçi", "ÇİFTÇİ"],
    ["  kara   kaya ", "KARA KAYA"],
  ])("soyad %s -> %s", (g, b) => expect(soyadBicimle(g)).toBe(b));

  it("varsayilan donusum YANLIS, Turkce dogru", () => {
    expect("ilker".toUpperCase()).toBe("ILKER");
    expect(trBuyuk("ilker")).toBe("İLKER");
    expect(trKucuk("I")).toBe("ı");
    expect(trKucuk("İ")).toBe("i");
  });

  it("yazarken bosluk silinmez (ikinci ad yazilabilsin)", () => {
    expect(adBicimle("mehmet ", true)).toBe("Mehmet ");
    expect(soyadBicimle("kara ", true)).toBe("KARA ");
  });

  it("tam ad ve ayirma", () => {
    expect(tamAd("Mehmet Ali", "YILMAZ")).toBe("Mehmet Ali YILMAZ");
    expect(adAyir("Mehmet Ali YILMAZ", "YILMAZ")).toEqual({ ad: "Mehmet Ali", soyad: "YILMAZ" });
    expect(adAyir("Ali Veli", null)).toEqual({ ad: "Ali", soyad: "Veli" });
    expect(adAyir("Tekad", null)).toEqual({ ad: "Tekad", soyad: "" });
  });
});

type Cagri = { url: string; metot: string; govde: Record<string, unknown> };

function taklit(): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const metot = (init?.method ?? "GET").toUpperCase();
    cagrilar.push({ url, metot, govde: init?.body ? JSON.parse(String(init.body)) : {} });
    const govde =
      url.startsWith("/api/users") && metot === "POST"
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

const adKutusu = () =>
  screen.getByLabelText(new RegExp(`^${tr.kisiAd}\\s*\\*?$`)) as HTMLInputElement;
const soyadKutusu = () =>
  screen.getByLabelText(new RegExp(`^${tr.kisiSoyad}\\s*\\*?$`)) as HTMLInputElement;

async function formuAc(k: ReturnType<typeof userEvent.setup>) {
  ciz(Sayfa);
  await k.click(await screen.findByRole("button", { name: new RegExp(tr.kullaniciYeni, "i") }));
  await screen.findByLabelText(new RegExp(`^${tr.kisiAd}\\s*\\*?$`));
}

describe("kullanici ekleme formu", () => {
  it("yazarken bicimlenir, govdede ad ve soyad ayri gider", async () => {
    const k = userEvent.setup();
    const cagrilar = taklit();
    await formuAc(k);
    await k.type(adKutusu(), "mehmet ali");
    expect(adKutusu().value).toBe("Mehmet Ali");
    await k.type(soyadKutusu(), "yılmaz");
    expect(soyadKutusu().value).toBe("YILMAZ");
    await k.type(screen.getByLabelText(new RegExp(tr.kullaniciEposta, "i")), "m@ornek.com");
    await k.click(screen.getByRole("button", { name: new RegExp(tr.ortakKaydet, "i") }));
    await waitFor(() =>
      expect(cagrilar.some((c) => c.url === "/api/users" && c.metot === "POST")).toBe(true),
    );
    const post = cagrilar.find((c) => c.url === "/api/users" && c.metot === "POST")!;
    expect(post.govde.ad).toBe("Mehmet Ali");
    expect(post.govde.soyad).toBe("YILMAZ");
  });

  it("soyad bos: kayit ENGELLENIR, istek gitmez", async () => {
    const k = userEvent.setup();
    const cagrilar = taklit();
    await formuAc(k);
    await k.type(adKutusu(), "ilker");
    expect(adKutusu().value).toBe("İlker");
    await k.type(screen.getByLabelText(new RegExp(tr.kullaniciEposta, "i")), "i@ornek.com");
    // `required` tarayici dogrulamasini atlamak icin form dogrudan gonderilir.
    soyadKutusu().removeAttribute("required");
    await k.click(screen.getByRole("button", { name: new RegExp(tr.ortakKaydet, "i") }));
    expect(await screen.findByText(tr.kisiAdZorunlu)).toBeTruthy();
    expect(cagrilar.some((c) => c.url === "/api/users" && c.metot === "POST")).toBe(false);
  });
});
