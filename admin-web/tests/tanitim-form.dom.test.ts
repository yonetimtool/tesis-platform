// @vitest-environment jsdom
// (P127.2) TANITIM FORMU — TESLIMAT ve DURUMLAR.
//
// Onceki tur buraya `mailto:` koymus ve "kalan is" diye yazmisti: kabul
// kriteri "form TESLIM EDIYOR" diyordu. Olculen sey artik odur — istek
// gercekten gidiyor mu, gonderilen govde dogru mu, ve UC DURUMUN ucu de
// ekranda mi (gonderiliyor / gonderildi / hata).
//
// EN PAHALI SONUC: kullanicinin mesajinin gidip gitmedigini bilememesi.
// Bu yuzden "hicbir sey olmadi" hâli ayrica olculur.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import { TanitimForm } from "@/components/TanitimForm";

import { ciz } from "./yardimci";

function fetchTaklidi(yanit: { status: number; govde?: unknown }) {
  const cagrilar: { url: string; body: unknown }[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    cagrilar.push({
      url: String(girdi),
      body: init?.body ? JSON.parse(String(init.body)) : undefined,
    });
    return new Response(JSON.stringify(yanit.govde ?? { ok: true }), {
      status: yanit.status,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

async function doldurVeGonder(kullanici: ReturnType<typeof userEvent.setup>) {
  await kullanici.type(screen.getByLabelText(/Ad Soyad/i), "Aday Kişi");
  await kullanici.type(screen.getByLabelText(/E-posta/i), "aday@ornek.com");
  await kullanici.type(screen.getByLabelText(/Mesajınız/i), "Demo talep ediyorum.");
  await kullanici.click(screen.getByRole("button", { name: /Gönder/i }));
}

afterEach(() => vi.restoreAllMocks());

describe("(P127.2) tanitim formu", () => {
  it("GONDERIR ve govdeyi dogru kurar (dil dahil)", async () => {
    const cagrilar = fetchTaklidi({ status: 201 });
    ciz(TanitimForm);
    await doldurVeGonder(userEvent.setup());
    await waitFor(() => expect(cagrilar).toHaveLength(1));
    expect(cagrilar[0].url).toBe("/api/tanitim-iletisim");
    const govde = cagrilar[0].body as Record<string, unknown>;
    expect(govde.ad).toBe("Aday Kişi");
    expect(govde.email).toBe("aday@ornek.com");
    expect(govde.mesaj).toBe("Demo talep ediyorum.");
    // Sayfanin dili gonderilir: donuste ayni dilde cevap yazilabilsin.
    expect(govde.dil).toBe("tr");
    // Bos alanlar `null` gider ("" degil) — sunucu bos dizeyi deger sanardi.
    expect(govde.telefon).toBeNull();
  });

  it("BASARIDA tesekkur gosterir, form YERINI birakir", async () => {
    fetchTaklidi({ status: 201 });
    ciz(TanitimForm);
    await doldurVeGonder(userEvent.setup());
    // `role="status"` iki yerde: Toast'un canli bolgesi (kabuk) ve bu
    // mesaj. METNE bakilir — olculen sey tesekkur cumlesidir.
    expect(await screen.findByText(/ulaştı/i)).toBeInTheDocument();
    // Form kaybolur: ayni mesaji ikinci kez gondermeye davet etmez.
    expect(screen.queryByRole("button", { name: /Gönder/i })).toBeNull();
  });

  it("HATADA sunucunun cumlesini gosterir (kendi genel metnini DEGIL)", async () => {
    // Hiz siniri (429) kendi cumlesini istegin dilinde doner; yutulursa
    // kullanici NEDEN gonderemedigini ogrenemezdi.
    fetchTaklidi({
      status: 429,
      govde: { error: { code: "rate_limited", message: "Çok fazla istek gönderdiniz." } },
    });
    ciz(TanitimForm);
    await doldurVeGonder(userEvent.setup());
    expect(await screen.findByRole("alert")).toHaveTextContent("Çok fazla istek gönderdiniz.");
    // Form DURUR: kullanici yazdigini kaybetmeden tekrar deneyebilmeli.
    expect(screen.getByRole("button", { name: /Gönder/i })).toBeInTheDocument();
  });

  it("AG HATASINDA da sessiz kalmaz", async () => {
    globalThis.fetch = (async () => {
      throw new TypeError("network");
    }) as typeof fetch;
    ciz(TanitimForm);
    await doldurVeGonder(userEvent.setup());
    expect(await screen.findByRole("alert")).toBeInTheDocument();
  });

  it("DONUS YOLU kurali ekranda YAZILI", () => {
    // Sunucu telefon VEYA e-posta istiyor; kullanici bunu gondermeden
    // ONCE bilmeli (yoksa 422'yi sebepsiz yer).
    fetchTaklidi({ status: 201 });
    ciz(TanitimForm);
    expect(screen.getByText(/e-posta veya telefondan en az birini/i)).toBeInTheDocument();
  });
});
