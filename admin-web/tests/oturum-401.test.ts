// (P101) 401 HER YERDE AYNI SEYI YAPAR.
//
// `apiSend`, `jsonFetcher` ve `fetchAllPaged` 401'de giris ekranina
// yonlendirir. Ama uc cagri yeri ham `fetch` kullaniyor (FormData ve
// ikili govde gerektirdikleri icin) ve 401'i SIRADAN bir hata gibi
// isliyordu: kullaniciya "Yanit kaydedilemedi (401)" gibi bir KOD
// gosteriliyor, oturumun bittigi soylenmiyor ve sayfa olu kaliyordu.
//
// Ayni gercek dort yerde, ucu farkli davraniyordu — oturumun tekrar
// eden sinifi ("tek gercek, iki yer"), bu kez OTURUM YONETIMINDE.
import { afterEach, describe, expect, it, vi } from "vitest";

import { oturumDustu } from "@/lib/client";

function sahteKonum() {
  const konum = { href: "" };
  vi.stubGlobal("window", { location: konum });
  return konum;
}

afterEach(() => vi.unstubAllGlobals());

describe("oturumDustu (P101)", () => {
  it("401'de giris ekranina YONLENDIRIR ve true doner", () => {
    const konum = sahteKonum();
    expect(oturumDustu(new Response(null, { status: 401 }))).toBe(true);
    expect(konum.href).toBe("/login");
  });

  it("401 DISI durumlarda hicbir sey yapmaz", () => {
    const konum = sahteKonum();
    for (const durum of [200, 204, 403, 404, 409, 422, 500]) {
      expect(oturumDustu(new Response(null, { status: durum })), String(durum))
        .toBe(false);
    }
    // YONLENDIRME YOK: 403 "yetkin yok" demektir, "oturumun bitti" DEGIL.
    // Ikisini karistirmak, yetkisiz bir sayfaya bakan kullaniciyi
    // sebepsizce giris ekranina atardi.
    expect(konum.href).toBe("");
  });
});
