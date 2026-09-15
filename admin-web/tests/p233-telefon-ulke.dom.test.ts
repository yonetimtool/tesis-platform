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

/** (P236) Ulke secici artik ARANABILIR bir acilir liste (select degil). */
const ulkeKutusu = () =>
  document.querySelector<HTMLButtonElement>('[data-test="telefon-ulke"]')!;

async function ulkeSec(kod: string) {
  await userEvent.click(ulkeKutusu());
  const secenek = document.querySelector<HTMLButtonElement>(
    `[data-test="telefon-ulke-${kod}"]`,
  );
  if (!secenek) throw new Error(`ulke secenegi yok: ${kod}`);
  await userEvent.click(secenek);
}
const numaraKutusu = () =>
  document.querySelector<HTMLInputElement>('[data-test="telefon-numara"]')!;

describe("P233 §3 telefon ulke kodu", () => {
  it("ULKE KUTUSU BOS BASLAR ve numara ULKESIZ GECERSIZDIR", async () => {
    render(createElement(Sahne));
    // Secilmemisken yer tutucu yazar.
    expect(ulkeKutusu().textContent).toBe("Seçin");

    await userEvent.type(numaraKutusu(), "5419222388");
    // Eski davranis burada SESSIZCE `+90` ekliyordu.
    expect(telefonNormalle(sonDeger)).toBe("");
    expect(telefonHatasi(sonDeger)).toBe("ulkeYok");
  });

  it("ULKE SECILINCE KOD DOLAR ve E.164 uretilir", async () => {
    render(createElement(Sahne));
    await userEvent.type(numaraKutusu(), "5419222388");
    await ulkeSec("TR");

    expect(sonDeger).toBe("(+90) 541 922 23 88");
    expect(telefonNormalle(sonDeger)).toBe("+905419222388");
    expect(telefonHatasi(sonDeger)).toBeNull();
  });

  it("MEVCUT KAYITTA ulke DEGERDEN cozulur", () => {
    render(createElement(Sahne, { baslangic: "+491711234567" }));
    // (P236) Etiket BAYRAK + ARAMA KODU; ISO kodu bayragin YEDEGI
    // (bayrak cizilmezse regional indicator ciftini "DE" diye duser).
    expect(ulkeKutusu().textContent).toContain("+49");
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
    await ulkeSec("QA");
    // Sessizce birakmak, KAYDEDILEMEYEN bir numarayi gecerli gostermek
    // olurdu.
    expect(telefonNormalle(sonDeger)).toBe("+97454192223");
  });

  it("(P236) ULKE ELLE YAZILAMAZ — secim listeden", async () => {
    render(createElement(Sahne));
    // Denetim bir DUGME: serbest metin girisi YOK, yani kullanici
    // uydurma bir kod yazamaz.
    expect(ulkeKutusu().tagName).toBe("BUTTON");
    await userEvent.click(ulkeKutusu());
    const liste = document.querySelector('[data-test="telefon-ulke-liste"]')!;
    const ilk = liste.querySelector('[role="option"]')!;
    // TR ILK SIRADA: kullanicilarin ezici cogunlugu icin dogru secim.
    expect(ilk.getAttribute("data-test")).toBe("telefon-ulke-TR");
  });

  it("(P236) LISTE ARANABILIR — ISO kodu ve arama kodu ile", async () => {
    // Elli ulkede kaydirmak zor; ustelik etiket artik `🇹🇷 +90` oldugu
    // icin yerlesik `<select>`in yazarak atlamasi da ise yaramazdi.
    render(createElement(Sahne));
    await userEvent.click(ulkeKutusu());
    const ara = document.querySelector<HTMLInputElement>(
      '[data-test="telefon-ulke-ara"]',
    )!;

    await userEvent.type(ara, "QA");
    expect(document.querySelector('[data-test="telefon-ulke-QA"]')).toBeTruthy();
    expect(document.querySelector('[data-test="telefon-ulke-TR"]')).toBeNull();

    await userEvent.clear(ara);
    await userEvent.type(ara, "974");
    expect(document.querySelector('[data-test="telefon-ulke-QA"]')).toBeTruthy();

    await userEvent.clear(ara);
    await userEvent.type(ara, "zzz");
    expect(document.querySelector('[data-test="telefon-ulke-bos"]')).toBeTruthy();
  });

  it("(P236) ETIKET BAYRAK + ARAMA KODU, ISO kodu TEKRARLANMAZ", async () => {
    // Bayrak bir REGIONAL INDICATOR ciftidir; bayrak bicimi yoksa
    // HARFLERE duser ve ekranda "TR +90" yazar. Ayrica ISO yazmak, o
    // platformlarda "TR TR +90" demekti.
    render(createElement(Sahne));
    await userEvent.click(ulkeKutusu());
    const tr = document.querySelector('[data-test="telefon-ulke-TR"]')!;
    expect(tr.textContent).toBe("\u{1F1F9}\u{1F1F7} +90");
  });
});
