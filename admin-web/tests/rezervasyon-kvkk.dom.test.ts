// @vitest-environment jsdom
// (P126.3 son dilim) REZERVASYON + KVKK TERCIHLERI.
//
// Iki sayfa da YAZMA yapar ve ikisinde de sessizce yanlis olabilecek bir
// kural var:
//  * Rezervasyon: zamanlama kurallari (24 sa / gunde bir / 10 dk) SUNUCUDA
//    olculur. Istemciye kopyalanirsa iki kopya zamanla ayrisir ve kullanici
//    "ekran izin verdi, sunucu reddetti" celiskisini yasar — bu test sunucu
//    hatasinin AYNEN gosterildigini olcer.
//  * KVKK: UC BAGIMSIZ KANAL. Tek bayraga indirgemek, kisiyi istemedigi
//    kanaldan mesaj almak ile hic almamak arasinda secmeye zorlardi.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import KvkkPage from "@/app/(protected)/kvkk/page";
import RezervasyonlarimPage from "@/app/(protected)/rezervasyonlarim/page";

import { ciz } from "./yardimci";

function taklit(harita: Record<string, unknown>, durumlar: Record<string, number> = {}) {
  const cagrilar: { url: string; method: string; body: unknown }[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      method: init?.method ?? "GET",
      body: init?.body ? JSON.parse(String(init.body)) : undefined,
    });
    const anahtar = Object.keys(harita)
      .filter((k) => url.startsWith(k))
      .sort((a, b) => b.length - a.length)[0];
    if (anahtar === undefined) {
      return new Response(JSON.stringify({ error: { message: "yok" } }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }
    return new Response(JSON.stringify(harita[anahtar]), {
      status: durumlar[anahtar] ?? 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

const ALAN = { id: "a1", ad: "Toplantı salonu", aktif: true };
const REZ = {
  id: "r1",
  alan_ad: "Toplantı salonu",
  tarih: "2026-09-01",
  baslangic: "10:00",
  bitis: "12:00",
  kisi_sayisi: 4,
  durum: "onaylandi",
};

afterEach(() => vi.restoreAllMocks());

describe("Rezervasyonlarım", () => {
  it("KENDI rezervasyonlari listelenir, PASIF alan secenege GIRMEZ", async () => {
    taklit({
      "/api/reservations": { items: [REZ] },
      "/api/common-areas": {
        items: [ALAN, { id: "a2", ad: "Kapalı havuz", aktif: false }],
      },
    });
    ciz(RezervasyonlarimPage);
    // Ad HEM kartta HEM secenekte gecer; sorgu ROLE ile daraltilir yoksa
    // "birden cok eleman" hatasi verir (ilk yazimda tam bu oldu).
    expect(
      await screen.findByRole("heading", { name: "Toplantı salonu" }),
    ).toBeInTheDocument();
    await waitFor(() =>
      expect(screen.getByRole("option", { name: "Toplantı salonu" })).toBeInTheDocument(),
    );
    // Pasif alan rezerve EDILEMEZ; secenekte gostermek bos yere denettirirdi.
    expect(screen.queryByRole("option", { name: "Kapalı havuz" })).toBeNull();
  });

  it("EKSIK alanla istek GONDERILMEZ", async () => {
    const c = taklit({
      "/api/reservations": { items: [] },
      "/api/common-areas": { items: [ALAN] },
    });
    ciz(RezervasyonlarimPage);
    await userEvent.click(
      await screen.findByRole("button", { name: /Rezervasyon yap/i }),
    );
    expect(await screen.findByText(/zorunludur/i)).toBeInTheDocument();
    expect(c.some((x) => x.method === "POST")).toBe(false);
  });

  it("SUNUCU zamanlama hatasi AYNEN gosterilir", async () => {
    // Kurallar istemciye KOPYALANMADI: sunucunun cumlesi en dogru
    // aciklamadir ve iki kopya zamanla ayrisirdi.
    const c = taklit(
      {
        "/api/reservations": { items: [] },
        "/api/common-areas": { items: [ALAN] },
      },
      {},
    );
    ciz(RezervasyonlarimPage);
    await screen.findByRole("option", { name: "Toplantı salonu" });
    await userEvent.selectOptions(screen.getByLabelText(/Alan/i), "a1");
    await userEvent.type(screen.getByLabelText(/Tarih/i), "2026-09-01");
    await userEvent.type(screen.getByLabelText(/Başlangıç/i), "10:00");
    await userEvent.type(screen.getByLabelText(/Bitiş/i), "12:00");
    // POST'u hataya cevir.
    const eski = globalThis.fetch;
    globalThis.fetch = (async (g: RequestInfo | URL, i?: RequestInit) => {
      if ((i?.method ?? "GET") === "POST") {
        return new Response(
          JSON.stringify({ error: { message: "En az 24 saat önceden." } }),
          { status: 422, headers: { "Content-Type": "application/json" } },
        );
      }
      return eski(g, i);
    }) as typeof fetch;
    await userEvent.click(
      screen.getByRole("button", { name: /Rezervasyon yap/i }),
    );
    expect(await screen.findByText(/24 saat önceden/i)).toBeInTheDocument();
    expect(c.length).toBeGreaterThan(0);
  });
});

describe("KVKK tercihleri", () => {
  it("UC KANAL AYRI AYRI gosterilir ve sunucudan gelen deger yuklenir", async () => {
    taklit({ "/api/me/pazarlama": { eposta: true, sms: false, arama: false } });
    ciz(KvkkPage);
    // CIRCIR DUZELTMESI (P129 kapilarinda yakalandi, kod kusuru DEGIL):
    // `findAllByRole` kutularin VAR OLMASINI bekler, `checked` degerinin
    // sunucudan gelen yanitla GUNCELLENMESINI beklemez. Kutular ilk
    // cizimde (varsayilan `false`) zaten vardir; yanit hizli geldiginde
    // test geciyor, yavas geldiginde `false` okuyup dusuyordu — tam
    // koşumda bir kez dustu, tek basina ve ikinci tam kosumda gecti.
    // Beklenen DEGERIN kendisi beklenir.
    const kutular = await screen.findAllByRole("checkbox");
    expect(kutular).toHaveLength(3);
    await waitFor(() =>
      expect((kutular[0] as HTMLInputElement).checked).toBe(true),
    );
    expect((kutular[1] as HTMLInputElement).checked).toBe(false);
  });

  it("BIR KANALI kapatmak otekileri ETKILEMEZ", async () => {
    const c = taklit({
      "/api/me/pazarlama": { eposta: true, sms: true, arama: false },
    });
    ciz(KvkkPage);
    const kutular = await screen.findAllByRole("checkbox");
    await userEvent.click(kutular[1]); // SMS kapat
    await userEvent.click(screen.getByRole("button", { name: /Kaydet/i }));
    await waitFor(() => {
      const patch = c.find((x) => x.method === "PATCH");
      expect(patch?.body).toMatchObject({
        eposta: true,
        sms: false,
        arama: false,
      });
    });
  });

  it("YASAL BELGE baglantilari var", async () => {
    taklit({ "/api/me/pazarlama": { eposta: false, sms: false, arama: false } });
    ciz(KvkkPage);
    expect(
      await screen.findByRole("link", { name: /Gizlilik/i }),
    ).toHaveAttribute("href", "/gizlilik");
    expect(screen.getByRole("link", { name: /Koşulları/i })).toHaveAttribute(
      "href",
      "/kosullar",
    );
  });
});
