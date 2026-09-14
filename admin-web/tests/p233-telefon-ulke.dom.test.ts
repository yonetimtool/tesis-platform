// @vitest-environment jsdom
// (P233 §3) TELEFON ALANI — ulke kodu SECILIR, elle yazilmaz.
//
// Saf fonksiyonlar `telefon.test.ts`te olculuyor. Burada olculen sey
// ZINCIR: secicide bir ulke secilince cagiran formun tuttugu HAM DEGER
// gercekten degisiyor mu, ve o deger sunucuya gidecek E.164'u uretiyor mu.
// P226/P229 dersi: aradaki halka olculmezse iki ucu dogru olan bir zincir
// yine kopuk kalabilir.
import { cleanup, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement, useState } from "react";
import { afterEach, describe, expect, it } from "vitest";

import { TelefonAlani } from "@/components/TelefonAlani";
import { I18nProvider } from "@/lib/i18n/kullan";
import { SOZLUKLER } from "@/lib/i18n/sozluk";
import { telefonHatasi, telefonNormalle } from "@/lib/telefon";

afterEach(cleanup);

let sonDeger = "";

function Sahne({ baslangic = "" }: { baslangic?: string }) {
  const [v, setV] = useState(baslangic);
  sonDeger = v;
  return createElement(I18nProvider, {
    baslangicDili: "tr",
    baslangicSozlugu: SOZLUKLER.tr,
    children: createElement(TelefonAlani, {
      etiket: "Telefon",
      deger: v,
      onDegisti: setV,
    }),
  });
}

const ulkeKutusu = () =>
  document.querySelector<HTMLSelectElement>('[data-test="telefon-ulke"]')!;
const numaraKutusu = () =>
  document.querySelector<HTMLInputElement>('[data-test="telefon-numara"]')!;

describe("P233 §3 telefon ulke kodu", () => {
  it("ULKE KUTUSU BOS BASLAR ve numara ULKESIZ GECERSIZDIR", async () => {
    render(createElement(Sahne));
    expect(ulkeKutusu().value).toBe("");

    await userEvent.type(numaraKutusu(), "5419222388");
    // Eski davranis burada SESSIZCE `+90` ekliyordu.
    expect(telefonNormalle(sonDeger)).toBe("");
    expect(telefonHatasi(sonDeger)).toBe("ulkeYok");
  });

  it("ULKE SECILINCE KOD DOLAR ve E.164 uretilir", async () => {
    render(createElement(Sahne));
    await userEvent.type(numaraKutusu(), "5419222388");
    await userEvent.selectOptions(ulkeKutusu(), "TR");

    expect(sonDeger).toBe("(+90) 541 922 23 88");
    expect(telefonNormalle(sonDeger)).toBe("+905419222388");
    expect(telefonHatasi(sonDeger)).toBeNull();
  });

  it("MEVCUT KAYITTA ulke DEGERDEN cozulur", () => {
    render(createElement(Sahne, { baslangic: "+491711234567" }));
    expect(ulkeKutusu().value).toBe("DE");
    expect(numaraKutusu().value).toBe("171 123 4567");
  });

  it("ULKEYE GORE SINIR — fazla rakam KABUL EDILMEZ", async () => {
    render(createElement(Sahne, { baslangic: "+974" }));
    await userEvent.type(numaraKutusu(), "3312345678");
    // Katar 8 hane.
    expect(telefonNormalle(sonDeger)).toBe("+97433123456");
  });

  it("ULKE DEGISINCE fazla haneler KIRPILIR", async () => {
    render(createElement(Sahne, { baslangic: "+905419222388" }));
    await userEvent.selectOptions(ulkeKutusu(), "QA");
    // Sessizce birakmak, KAYDEDILEMEYEN bir numarayi gecerli gostermek
    // olurdu.
    expect(telefonNormalle(sonDeger)).toBe("+97454192223");
  });

  it("SECENEK LISTESI ELLE YAZMAYA IZIN VERMEZ (select, input degil)", () => {
    render(createElement(Sahne));
    expect(ulkeKutusu().tagName).toBe("SELECT");
    // TR ILK SIRADA: kullanicilarin ezici cogunlugu icin dogru secim.
    expect(ulkeKutusu().options[1].value).toBe("TR");
  });
});
