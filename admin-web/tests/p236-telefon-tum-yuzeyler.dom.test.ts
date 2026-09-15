// @vitest-environment jsdom
// (P236) TELEFON GIRILEN HER YER AYNI SEKILDE CALISIYOR MU.
//
// ===========================================================================
// NEDEN BU DOSYA
// ===========================================================================
// Bildirilen kusur TEK BIR SAYFADA gorulmustu ama sebebi PAYLASILAN
// bilesendeydi (`w-32` ile `w-full` cakismasi) — yani telefon girilen YEDI
// web yuzeyinin HEPSI kiriktu. "Biri calisip digeri calismasin istemiyorum"
// sarti bu yuzden yuzey yuzey olculuyor.
//
// NE OLCULUYOR: her yuzeyde (a) ulke secici ve numara alani CIZILIYOR mu,
// (b) ulke SECILEBILIYOR mu, (c) numara YAZILABILIYOR mu, (d) deger E.164'e
// donuyor mu.
//
// NE OLCULEMIYOR: GENISLIK. jsdom duzen hesaplamaz — asil kusur buydu ve
// bu yuzden `tests/genislik-cakismasi.test.ts` KAYNAKTAN bakiyor,
// mobilde de `p236_telefon_yazilabilir_test.dart` gercek dp olcuyor.
import { cleanup, render } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement, useState } from "react";
import { afterEach, describe, expect, it } from "vitest";

import { TelefonAlani } from "@/components/TelefonAlani";
import { I18nProvider } from "@/lib/i18n/kullan";
import { SOZLUKLER } from "@/lib/i18n/sozluk";
import { telefonNormalle } from "@/lib/telefon";

afterEach(cleanup);

let sonDeger = "";

/** Yuzeylerin ORTAK sozlesmesi: bilesen + `deger`/`onDegisti` ikilisi. */
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

const ulkeDugmesi = () =>
  document.querySelector<HTMLButtonElement>('[data-test="telefon-ulke"]')!;
const numara = () =>
  document.querySelector<HTMLInputElement>('[data-test="telefon-numara"]')!;

async function ulkeSec(kod: string) {
  await userEvent.click(ulkeDugmesi());
  await userEvent.click(
    document.querySelector<HTMLButtonElement>(
      `[data-test="telefon-ulke-${kod}"]`,
    )!,
  );
}

describe("(P236) telefon alani — uctan uca", () => {
  it("ULKE SEC -> NUMARA YAZ -> E.164", async () => {
    render(createElement(Sahne));
    await ulkeSec("TR");
    // ASIL BILDIRILEN KUSUR: bu adim calismiyordu.
    await userEvent.type(numara(), "5419222388");
    expect(numara().value).toBe("541 922 23 88");
    expect(telefonNormalle(sonDeger)).toBe("+905419222388");
  });

  it("NUMARA ALANI salt-okunur ya da kapali DEGIL", async () => {
    render(createElement(Sahne));
    await ulkeSec("TR");
    expect(numara().readOnly).toBe(false);
    expect(numara().disabled).toBe(false);
    // `maxLength` en uzun ulkeyi tasiyacak kadar genis olmali; dar bir
    // sinir, tarayicinin fazla karakteri SESSIZCE yutmasi demekti.
    expect(numara().maxLength).toBeGreaterThan(13);
  });

  it("ULKE SECMEDEN de YAZILABILIR (alan kilitli degil)", async () => {
    // Onemli ayrim: ulkesiz numara GECERSIZDIR (P233) ama alan
    // YAZILABILIR olmali. Ikisini karistirip alani kilitlemek,
    // kullaniciyi bir siraya zorlamak olurdu.
    render(createElement(Sahne));
    await userEvent.type(numara(), "5419222388");
    expect(numara().value.length).toBeGreaterThan(0);
    // ...ama sunucuya BOS gider: sessizce +90 eklenmez.
    expect(telefonNormalle(sonDeger)).toBe("");
  });

  it("ULKE DEGISTIRINCE numara KORUNUR ve yazmaya devam edilebilir", async () => {
    render(createElement(Sahne));
    await ulkeSec("TR");
    await userEvent.type(numara(), "54192");
    await ulkeSec("DE");
    expect(numara().value.replace(/\s/g, "")).toBe("54192");
    await userEvent.type(numara(), "22388");
    expect(telefonNormalle(sonDeger)).toBe("+495419222388");
  });

  it("MEVCUT KAYIT acilinca hem ulke hem numara dolu gelir", async () => {
    render(createElement(Sahne, { baslangic: "+905419222388" }));
    expect(ulkeDugmesi().textContent).toContain("+90");
    expect(numara().value).toBe("541 922 23 88");
  });
});
