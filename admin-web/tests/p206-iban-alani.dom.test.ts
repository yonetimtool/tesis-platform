// @vitest-environment jsdom
// (P206 §3) TANIMLAR > KASALAR — IBAN alani ve BANKA secimi.
//
// Olculen sey EKRANIN DAVRANISI + GIDEN GOVDE:
//   * IBAN yazarken DORDERLI gruplanir (insan gozu 26 haneyi tek blokta
//     karsilastiramaz),
//   * gecersiz IBAN ISTEK ATMADAN durdurulur ve ANLASILIR hata verir,
//   * gecerli IBAN sunucuya BOSLUKSUZ (kanonik) gider,
//   * IBAN taninirsa BANKA ADI otomatik dolar,
//   * banka alani listeden secilebilir AMA serbest girise de acik.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import Sayfa from "@/app/(protected)/tanimlar/page";
import { tr } from "@/lib/i18n/sozluk/tr";

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
    return new Response(
      JSON.stringify({ items: [], meta: { total: 0, limit: 100, offset: 0 } }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  }) as typeof fetch;
  return cagrilar;
}

const kanca = (ad: string) =>
  document.querySelector(`[data-test="${ad}"]`) as HTMLInputElement | null;

async function formuAc(k: ReturnType<typeof userEvent.setup>) {
  ciz(Sayfa);
  await waitFor(() => expect(screen.getByText(tr.tanimYeniKayit)).toBeTruthy());
  await k.click(screen.getByText(tr.tanimYeniKayit));
  await waitFor(() => expect(kanca("tanim-iban-iban")).toBeTruthy());
}

/** Zorunlu alanlari doldurur (kod/ad) — IBAN disindaki dogrulamalar
 *  bu dosyanin konusu degil. */
async function temelAlanlar(k: ReturnType<typeof userEvent.setup>) {
  await k.type(screen.getByLabelText(tr.tanimAlanKod), "K1");
  await k.type(screen.getByLabelText(tr.tanimAlanAd), "Banka Kasa");
  // "Banka hesabi" onay kutusu: `AlanSarmal` iceren dallarda etiket
  // baglantisi kutuya degil sarmalayiciya gidiyor — kutuyu tipiyle
  // buluyoruz (bu dosyanin olctugu sey IBAN, etiket baglari degil).
  const kutular = document.querySelectorAll('input[type="checkbox"]');
  await k.click(kutular[0] as HTMLElement);
}

afterEach(() => vi.restoreAllMocks());

it("IBAN YAZARKEN DORDERLI gruplanir", async () => {
  const k = userEvent.setup();
  taklit();
  await formuAc(k);
  await k.type(kanca("tanim-iban-iban")!, "TR330006100519786457841326");
  expect(kanca("tanim-iban-iban")!.value).toBe("TR33 0006 1005 1978 6457 8413 26");
});

it("IBAN girilince BANKA ADI otomatik dolar", async () => {
  // Kullaniciyi bir yazim hatasindan kurtarir: yanlis banka adi tasiyan
  // bir kasa, mutabakatta saatler kaybettirir.
  const k = userEvent.setup();
  taklit();
  await formuAc(k);
  await k.type(kanca("tanim-iban-iban")!, "TR620006200000000000000000");
  await waitFor(() =>
    expect(kanca("tanim-banka-banka_adi")!.value).toBe("Garanti BBVA"),
  );
});

it("BANKA alani SERBEST GIRISE de acik (kapali liste degil)", async () => {
  // Katilim bankalari, yeni lisans alanlar ve yabanci subeler listeyi
  // her zaman geride birakir; kapali liste GERCEK bir hesabi
  // kaydedilemez yapardi.
  const k = userEvent.setup();
  taklit();
  await formuAc(k);
  await k.type(kanca("tanim-banka-banka_adi")!, "Listede Olmayan Banka");
  expect(kanca("tanim-banka-banka_adi")!.value).toBe("Listede Olmayan Banka");
  // Liste yine de SUNULUR (datalist).
  expect(document.getElementById("p206-banka-listesi")).toBeTruthy();
});

it("GECERSIZ IBAN ISTEK ATMADAN durdurulur, ANLASILIR hata verir", async () => {
  // Eski hâlde saglama toplami YOKTU: bu IBAN `^TR[0-9]{24}$` regex'inden
  // geciyor ve para yanlis hesaba gidiyordu.
  const k = userEvent.setup();
  const cagrilar = taklit();
  await formuAc(k);
  await temelAlanlar(k);
  await k.type(kanca("tanim-iban-iban")!, "TR330006100519786457841327");
  await k.click(screen.getByText(tr.ortakKaydet));

  await waitFor(() => expect(screen.getByText(tr.tanimIbanSaglama)).toBeTruthy());
  expect(cagrilar.some((c) => c.metot === "POST")).toBe(false);
});

it("GECERLI IBAN sunucuya BOSLUKSUZ gider", async () => {
  // Ayni IBAN'in iki farkli yazimla iki kayit uretmesi, ekstre
  // eslestirmesini (P191) bozardi.
  const k = userEvent.setup();
  const cagrilar = taklit();
  await formuAc(k);
  await temelAlanlar(k);
  await k.type(kanca("tanim-iban-iban")!, "TR330006100519786457841326");
  await k.click(screen.getByText(tr.ortakKaydet));

  await waitFor(() => expect(cagrilar.some((c) => c.metot === "POST")).toBe(true));
  const post = cagrilar.find((c) => c.metot === "POST")!;
  expect(post.govde.iban).toBe("TR330006100519786457841326");
});
