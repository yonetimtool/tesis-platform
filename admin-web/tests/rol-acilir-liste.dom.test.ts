// @vitest-environment jsdom
// (P130) KULLANICI FORMUNDAKI ROL LISTESI SUNUCUDAN GELIR.
//
// OLCULEN KUSUR: liste `ROLE_OPTIONS`in tamamiydi. Bir site yoneticisi
// `app.*`ta "Platform Admin"i SECEBILIYOR, kaydediyor ve 403 aliyordu.
// Sunucu bastan beri dogru davraniyordu (olculdu: `yonetici -> admin` 403);
// yanlis olan, yapilamayacak bir seyi teklif eden arayuzdu.
//
// IKI YON OLCULUR: (1) izin verilmeyen rol listede YOK, (2) izin verilen
// roller listede VAR. Yalniz birincisi olculseydi, listeyi tamamen bosaltmak
// da testi gecerdi.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import UsersPage from "@/app/(protected)/users/page";

import { ciz } from "./yardimci";

function fetchTaklidi(roller: string[]) {
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    const url = String(girdi);
    if (url.startsWith("/api/users/acilabilir-roller")) {
      return new Response(JSON.stringify({ roller }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
    if (url.startsWith("/api/users")) {
      return new Response(
        JSON.stringify({ meta: { limit: 20, offset: 0, total: 0 }, items: [] }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }
    return new Response(JSON.stringify({ error: { message: "yok" } }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
}

/** Formu acar ve FORMDAKI rol select'inin secenek DEGERLERINI doner.
 *
 * SAYFADA IKI "Rol" SECIMI VAR: ustteki LISTE SUZGECI ve formdaki rol
 * alani. Suzgec BILEREK tum rolleri listeler — bir yonetici admin
 * hesaplarini LISTELEYEBILIR (goruyor, duzenleyemiyor); daraltilan sey
 * "hangi rolde hesap ACILIR"dir. Form her zaman SONUNCUdur (modal en
 * sonda cizilir). */
async function rolSecenekleri(): Promise<string[]> {
  const kullanici = userEvent.setup();
  const ekle = await screen.findByRole("button", { name: /Yeni|Ekle/i });
  await kullanici.click(ekle);
  await screen.findByRole("button", { name: /Kaydet/i });  // modal acildi
  const secimler = screen.getAllByRole("combobox", { name: /Rol/i });
  const form = secimler[secimler.length - 1];
  return Array.from(form.querySelectorAll("option")).map((o) => o.value);
}

afterEach(() => vi.restoreAllMocks());

describe("kullanici formu — rol acilir listesi", () => {
  it("yonetici PLATFORM ADMIN'i GORMEZ, saha rollerini gorur", async () => {
    fetchTaklidi(["security", "tesis_gorevlisi"]);
    ciz(UsersPage);
    await waitFor(() => expect(globalThis.fetch).toBeTruthy());
    const secenekler = await rolSecenekleri();
    expect(secenekler).not.toContain("admin");
    expect(secenekler).not.toContain("yonetici");
    expect(secenekler).toEqual(
      expect.arrayContaining(["security", "tesis_gorevlisi"]),
    );
  });

  it("admin TUM rolleri gorur — liste 'her zaman kisitli' degil", async () => {
    const hepsi = [
      "admin",
      "yonetici",
      "security",
      "tesis_gorevlisi",
      "resident",
      "guvenlik_amiri",
    ];
    fetchTaklidi(hepsi);
    ciz(UsersPage);
    const secenekler = await rolSecenekleri();
    for (const r of hepsi) expect(secenekler).toContain(r);
  });

  it("amir YALNIZ guvenlik acar — tek secenek", async () => {
    fetchTaklidi(["security"]);
    ciz(UsersPage);
    expect(await rolSecenekleri()).toEqual(["security"]);
  });
});
