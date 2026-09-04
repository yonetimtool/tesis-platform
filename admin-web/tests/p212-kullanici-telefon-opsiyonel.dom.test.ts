// @vitest-environment jsdom
// (P212-ek §2) KULLANICI EKLEME: TELEFON ARTIK ZORUNLU DEGIL.
//
// ===========================================================================
// OLCULEN ENGEL
// ===========================================================================
// Ayni kisiyi IKINCI bir tesise eklemek imkansizdi: telefon PLATFORM
// GENELINDE benzersiz (`uq_app_user_telefon`) ve form onu ZORUNLU
// tutuyordu. Backend'de olculdu:
//     telefonsuz gonder -> 422 "telefon: Field required"
//     gercek numarayla  -> 409 "zaten kayitli"
// Yani ikinci uyelik ancak UYDURMA bir numarayla acilabiliyordu.
// Kimlik P197'den beri E-POSTADIR.
//
// Burada olculen sey ARAYUZUN GONDERDIGI GOVDE: telefon bos birakilinca
// form kaydetmeyi ENGELLEMEMELI ve govdede `null` gitmeli.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import Sayfa from "@/app/(protected)/users/page";
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
    let govde: unknown = { items: [], meta: { total: 0 } };
    if (url.startsWith("/api/users") && (init?.method ?? "GET") === "POST") {
      govde = { id: "u-yeni" };
    } else if (url.includes("/api/units")) {
      govde = { items: [], meta: { total: 0 } };
    }
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

afterEach(() => vi.restoreAllMocks());

async function formuAc(k: ReturnType<typeof userEvent.setup>) {
  ciz(Sayfa);
  const dugme = await screen.findByRole("button", { name: new RegExp(tr.kullaniciYeni, "i") });
  await k.click(dugme);
  await screen.findByLabelText(new RegExp(`^${tr.ortakAd}\\s*\\*?$`));
}

it("TELEFON BOS: kayit ENGELLENMEZ ve govdede `null` gider", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  await formuAc(k);

  // Dar sorgu SART: /Ad/i birden cok etiketi buluyor ("Ad", "Aranabilir"...).
  await k.type(screen.getByLabelText(new RegExp(`^${tr.ortakAd}\\s*\\*?$`)), "Coklu Kisi");
  await k.type(
    screen.getByLabelText(new RegExp(tr.kullaniciEposta, "i")),
    "coklu@ornek.com",
  );
  // TELEFON DOLDURULMUYOR — olculen sey tam olarak bu.
  await k.click(screen.getByRole("button", { name: new RegExp(tr.ortakKaydet, "i") }));

  await waitFor(() =>
    expect(
      cagrilar.some((c) => c.url === "/api/users" && c.metot === "POST"),
    ).toBe(true),
  );
  const post = cagrilar.find((c) => c.url === "/api/users" && c.metot === "POST")!;
  expect(post.govde.email).toBe("coklu@ornek.com");
  // Bos alan "gecersiz numara" degil "numara yok" demektir.
  expect(post.govde.telefon).toBeNull();
});

it("TELEFON VERILIRSE normallestirilmis gider (gerileme yok)", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  await formuAc(k);

  await k.type(screen.getByLabelText(new RegExp(`^${tr.ortakAd}\\s*\\*?$`)), "Numarali");
  await k.type(
    screen.getByLabelText(new RegExp(tr.kullaniciEposta, "i")),
    "numarali@ornek.com",
  );
  await k.type(screen.getByLabelText(new RegExp(tr.kullaniciTelefon, "i")), "05321112203");
  await k.click(screen.getByRole("button", { name: new RegExp(tr.ortakKaydet, "i") }));

  await waitFor(() =>
    expect(cagrilar.some((c) => c.url === "/api/users" && c.metot === "POST")).toBe(true),
  );
  expect(
    cagrilar.find((c) => c.url === "/api/users" && c.metot === "POST")!.govde.telefon,
  ).toBe("+905321112203");
});
