// (P206 §3) IBAN — DOGRULAMA, BICIMLEME, BANKA COZUMU.
//
// ===========================================================================
// AYNI ORNEK KUMESI IKI TARAFTA DA KOSUYOR
// ===========================================================================
// Kural hem `lib/iban.ts`te hem `backend/app/iban.py`de yazili ve ikisi
// de gerekli (sunucu son sozu soyler, istemci kullaniciyi 422 beklemeden
// uyarir). Ayrisma riskine karsi ORNEKLER burada ve backend
// `test_p206_iban.py`de AYNIDIR — biri degisip oteki degismezse
// birindeki bekleyis kirmizi olur.
import { describe, expect, it } from "vitest";

import {
  bankaAdiCoz,
  bankaKodu,
  ibanBicimle,
  ibanGiris,
  ibanHatasi,
  ibanTemizle,
} from "@/lib/iban";

/** ORNEK KUME — backend testiyle AYNI. */
export const GECERLI = [
  "TR330006100519786457841326", // TR, 26 hane
  "TR33 0006 1005 1978 6457 8413 26", // bosluklu yazim
  "tr330006100519786457841326", // kucuk harf
  "DE89370400440532013000", // DE, 22 hane — ULKE SINIRI YOK
  "GB82WEST12345698765432", // harf iceren hesap bolumu
  "NO9386011117947", // 15 hane (ASGARI sinir)
];

export const GECERSIZ: [string, string][] = [
  ["", "iban_bos"],
  ["xx", "iban_bicim"],
  ["TR33000610051978645784132", "iban_uzunluk"], // TR ama 25 hane
  ["TR330006100519786457841327", "iban_saglama"], // son hane bozuk
  ["DE89370400440532013001", "iban_saglama"],
];

describe("dogrulama", () => {
  it("GECERLI ornekler kabul edilir (ULKE SINIRI YOK)", () => {
    for (const x of GECERLI) expect(ibanHatasi(x), x).toBeNull();
  });

  it("GECERSIZ ornekler DOGRU KIMLIKLE reddedilir", () => {
    // Kimlikler ayri: "uzunluk" ile "saglama" ayni sey degil ve
    // kullaniciya ne yapacagini soyleyen sey tam olarak bu ayrimdir.
    for (const [x, kod] of GECERSIZ) expect(ibanHatasi(x), x).toBe(kod);
  });

  it("MOD 97 tek hane hatasini yakalar — REGEX YAKALAYAMIYORDU", () => {
    // Eski denetim `^TR[0-9]{24}$`ti: asagidaki IBAN o regex'ten GECER
    // ve para YANLIS HESABA giderdi.
    const bozuk = "TR330006100519786457841327";
    expect(/^TR[0-9]{24}$/.test(bozuk)).toBe(true);
    expect(ibanHatasi(bozuk)).toBe("iban_saglama");
  });
});

describe("bicimleme", () => {
  it("DEPODA bosluksuz, EKRANDA dorderli", () => {
    expect(ibanTemizle("tr33 0006-1005 1978 6457 8413 26")).toBe(
      "TR330006100519786457841326",
    );
    expect(ibanBicimle("TR330006100519786457841326")).toBe(
      "TR33 0006 1005 1978 6457 8413 26",
    );
  });

  it("GIRIS azami uzunlugu SERT sinirlar", () => {
    // Sinirsiz yazdirip sonra reddetmek, kullaniciyi bosuna ugrastirmakti.
    const uzun = "TR" + "1".repeat(60);
    expect(ibanTemizle(ibanGiris(uzun)).length).toBe(34);
  });
});

describe("banka cozumu", () => {
  it("TR IBAN'inda banka kodu SON DORT hanedir", () => {
    // TR: 5 hane banka kodu alani, EFT kodu 4 hane ve SOLDAN SIFIRLA
    // doldurulur ("0062" -> "00062"). Ilk dordu almak Garanti'yi
    // "0006" diye okurdu (ilk yazimda oyleydi).
    expect(bankaKodu("TR620006200000000000000000")).toBe("0062");
    expect(bankaAdiCoz("TR620006200000000000000000")).toBe("Garanti BBVA");
    expect(bankaAdiCoz("TR100001000000000000000000")).toBe("Ziraat Bankası");
  });

  it("TR DISINDA banka UYDURULMAZ", () => {
    // Kodun yeri ulkeye gore degisir; tahmin etmek YANLIS banka adi
    // yazdirmak olurdu.
    expect(bankaKodu("DE89370400440532013000")).toBeNull();
    expect(bankaAdiCoz("DE89370400440532013000")).toBeNull();
  });

  it("TANINMAYAN kod icin null — SERBEST GIRIS icin yer birakir", () => {
    expect(bankaAdiCoz("TR330099900000000000000000")).toBeNull();
  });
});
