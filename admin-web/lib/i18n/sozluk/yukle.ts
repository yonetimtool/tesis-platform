import type { Dil } from "../diller";

import type { Sozluk } from "./tipler";

// (P132.5) TEMBEL SOZLUK YUKLEYICI — AYRI MODUL OLMASI SART.
//
// Ilk denemede bu fonksiyon `sozluk/index.ts` icindeydi ve HICBIR SEY
// DEGISMEDI. Sebep: `index.ts` yedi sozlugu STATIK import eder; istemci
// oradan tek bir fonksiyon alsa bile modulun tum statik bagimliliklari
// paketle birlikte gelir. Olculdu — `Anmelden` (Almanca) dizgesi 400 KB'lik
// bir parcada duruyordu ve o parca 52 rotanin ILK YUKUNDEYDI.
//
// Bu dosyanin statik bagimliligi YOKTUR: yalniz tip importlari (derleme
// aninda silinir) ve `import()` cagrilari. Boylece her dil KENDI parcasina
// duser ve yalniz secilen dil indirilir.
export async function sozlukYukle(dil: Dil): Promise<Sozluk> {
  switch (dil) {
    case "en":
      return (await import("./en")).en;
    case "ar":
      return (await import("./ar")).ar;
    case "ru":
      return (await import("./ru")).ru;
    case "de":
      return (await import("./de")).de;
    case "fr":
      return (await import("./fr")).fr;
    case "es":
      return (await import("./es")).es;
    default:
      return (await import("./tr")).tr;
  }
}
