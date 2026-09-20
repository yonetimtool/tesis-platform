// (P244 §7) PANEL VEKIL SUZGECLERI — BACKEND'DE VAR OLANLARLA AYNI OLMALI.
//
// ===========================================================================
// OLCULEN IKI KUSUR
// ===========================================================================
// `/finans/hareketler` icin beyaz liste soyleydi:
//     ["tip", "kasa_id", "baslangic", "bitis"]
// Backend'in imzasi ise (`routers/finans.py::hareket_listesi`):
//     tip, kasa_id, user_id
//
// Yani ayni satirda IKI ters yonlu kusur vardi:
//
//  1. `user_id` EKSIKTI. `/finans/iade` ekrani "bu KISININ tahsilatlari"
//     diye soruyor (`?tip=tahsilat&user_id=...`) ve suzgec BFF'te
//     DUSUYORDU — ekran HERKESIN tahsilatini listeliyordu. Kullanici
//     yanlis bir tahsilati secip iade acabilirdi.
//
//  2. `baslangic`/`bitis` FAZLAYDI. Backend bunlari HIC tanimiyor; beyaz
//     listede durmalari olmayan bir yetenegi VARMIS gibi gosteriyordu.
//     Biri tarih suzgeci yazsa parametre sunucuya gider, FastAPI onu
//     sessizce atar ve ekran "suzdum" der ama suzmez.
//
// ===========================================================================
// NEDEN BU KILIT
// ===========================================================================
// Ikisi de SESSIZ kusur: ne hata verir ne log birakir. Tek belirti
// "listede olmamasi gereken kayitlar var" ve bunu ancak veriyi bilen biri
// fark eder. Beyaz liste ile backend imzasi arasindaki fark YAPISAL
// olarak olculebilir.
import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import { SUZGECLER } from "@/lib/panel-vekil";

const DEPO = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

/** `routers/finans.py::hareket_listesi` imzasindaki `Query` parametreleri. */
function backendSuzgecleri(): string[] {
  const kaynak = readFileSync(
    join(DEPO, "backend", "app", "routers", "finans.py"),
    "utf8",
  );
  const bas = kaynak.indexOf("async def hareket_listesi(");
  expect(bas, "hareket_listesi bulunamadi").toBeGreaterThan(-1);
  const imza = kaynak.slice(bas, kaynak.indexOf(") -> HareketListResponse", bas));
  return [...imza.matchAll(/^\s*(\w+)\s*:[^=]+=\s*Query\(/gm)]
    .map((m) => m[1])
    // Sayfalama her kaynakta ortak; vekil onu ayrica tasiyor.
    .filter((ad) => ad !== "limit" && ad !== "offset");
}

describe("(P244 §7) finans-hareketler suzgec listesi", () => {
  const backend = backendSuzgecleri();

  it("TARAMA gercekten imzayi okuyor (vakum degil)", () => {
    expect(backend).toContain("tip");
    expect(backend.length).toBeGreaterThanOrEqual(3);
  });

  it("BEYAZ LISTE backend imzasiyla BIREBIR ayni", () => {
    const vekil = [...(SUZGECLER["finans-hareketler"] ?? [])].sort();
    expect(
      vekil,
      `vekil: [${vekil.join(", ")}] · backend: [${[...backend].sort().join(", ")}]`,
    ).toEqual([...backend].sort());
  });

  it("`user_id` GECIYOR — iade ekraninin dayandigi suzgec", () => {
    // Bu iddia ayri duruyor cunku DUSMESI halinde ne oldugunu anlatmasi
    // gerekiyor: iade ekrani herkesin tahsilatini listeler.
    expect(SUZGECLER["finans-hareketler"]).toContain("user_id");
  });

  it("BACKEND'DE OLMAYAN suzgec beyaz listede DURMAZ", () => {
    for (const ad of SUZGECLER["finans-hareketler"] ?? []) {
      expect(
        backend,
        `"${ad}" beyaz listede ama backend imzasinda yok — olmayan bir yetenek vaat ediliyor`,
      ).toContain(ad);
    }
  });
});
