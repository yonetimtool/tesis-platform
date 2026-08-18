// (P168 §4.1) SMS SAYACI — TURKCE TUZAGININ KILIDI.
//
// Bu testin olctugu sey bir formul degil, BIR FATURA: `ı ğ ş İ Ğ Ş`
// GSM-7'de YOKTUR ve mesaji UCS-2'ye dusurur; sinir 160'tan 70'e iner.
// "Biraz uzun" bir mesaj birden UC SMS olur.
//
// `ç ö ü` ise GSM-7'DE VARDIR — bu ayrim testin can alici noktasi:
// "Turkce karakter varsa 70" diye kabaca yazilmis bir sayac, `ç` iceren
// 150 karakterlik bir mesaji UC SMS gosterip kullaniciyi gereksiz yere
// metni kisaltmaya iterdi.
import { describe, expect, it } from "vitest";

import { COK_UCS2, TEK_GSM7, TEK_UCS2, smsOlc } from "@/lib/sms-olcu";

describe("SMS olcumu", () => {
  it("BOS metin SIFIR parca", () => {
    // "1 SMS" demek, hicbir sey yazmamis kullaniciya maliyet gostermekti.
    const o = smsOlc("");
    expect(o.parca).toBe(0);
    expect(o.karakter).toBe(0);
  });

  it("duz Latin metin GSM-7 — sinir 160", () => {
    const o = smsOlc("Sayin Ali Bey, bakiyeniz 100 TL.");
    expect(o.unicodeMi).toBe(false);
    expect(o.parca).toBe(1);
    expect(o.kalan).toBe(TEK_GSM7 - o.karakter);
  });

  it("`ö ü` GSM-7'DE VARDIR — UCS-2'ye DUSURMEZ", () => {
    // Kabaca "Turkce harf varsa 70" yazan bir sayac burada YANILIRDI:
    // `ö` ve `ü` GSM-7 temel kumesindedir ve maliyeti ARTIRMAZ.
    const o = smsOlc("Gunaydin, ücret ödendi. Bilginize.");
    expect(o.unicodeMi).toBe(false);
    expect(o.zorlayan).toEqual([]);
  });

  it("BUYUK `Ç` VAR ama KUCUK `ç` YOK — ve bu tuzak olculur", () => {
    // GSM 03.38 temel kumesinde `Ç` (buyuk) vardir, `ç` (kucuk) YOKTUR.
    // Yani "Çok" ucuz, "çok" pahalidir. Bu ayrimi bilmeyen bir sayac
    // ya gereksiz uyarir ya da faturayi gizler.
    expect(smsOlc("ÇÇÇ").unicodeMi).toBe(false);
    const kucuk = smsOlc("çok");
    expect(kucuk.unicodeMi).toBe(true);
    expect(kucuk.zorlayan).toEqual(["ç"]);
  });

  it("`ı ğ ş` UCS-2'ye DUSURUR — sinir 70", () => {
    const o = smsOlc("Sayın Ali Bey");
    expect(o.unicodeMi).toBe(true);
    expect(o.zorlayan).toContain("ı");
    expect(o.kalan).toBe(TEK_UCS2 - o.karakter);
  });

  it("ZORLAYAN karakterler TEKRARSIZ listelenir", () => {
    // "neden 3 SMS oldu" sorusunu kullanicinin metne bakip tahmin
    // etmesine birakmak, sayaci yarim gostermek olurdu.
    const o = smsOlc("ışık ışık ğğ");
    expect(o.zorlayan.sort()).toEqual(["ı", "ş", "ğ"].sort());
  });

  it("70'i ASAN Turkce metin COK PARCAYA boluner (67'lik)", () => {
    const metin = "ı".repeat(100);
    const o = smsOlc(metin);
    expect(o.unicodeMi).toBe(true);
    expect(o.parca).toBe(Math.ceil(100 / COK_UCS2));
    expect(o.kalan).toBe(o.parca * COK_UCS2 - 100);
  });

  it("160'i ASAN Latin metin 153'luk parcalara boluner", () => {
    const o = smsOlc("a".repeat(200));
    expect(o.unicodeMi).toBe(false);
    expect(o.parca).toBe(2);
  });

  it("genisletilmis isaretler IKI karakter sayilir", () => {
    // `€` ve `{}` GSM-7'de iki birim yer kaplar; tek sayan bir sayac
    // sinira yakin mesajlarda parca sayisini YANLIS gosterirdi.
    expect(smsOlc("€").karakter).toBe(2);
    expect(smsOlc("{}").karakter).toBe(4);
    expect(smsOlc("€").unicodeMi).toBe(false);
  });
});
