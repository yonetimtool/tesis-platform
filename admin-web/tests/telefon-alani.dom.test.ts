// @vitest-environment jsdom
// (P166 §9) TELEFON ALANI — TEK bilesen, her formda ayni kural.
//
// EN PAHALI SONUC: gecersiz bir numaranin SESSIZCE kaydedilmesi. Kusur
// ancak SMS gitmeyince fark edilir — yani pratikte hic fark edilmez.
// `lib/telefon.ts`in kendi testi (`telefon.test.ts`) KURALI olcuyor; bu
// dosya kuralin FORMA BAGLANDIGINI olcuyor.
import { fireEvent, screen } from "@testing-library/react";
import { createElement, useState } from "react";
import { describe, expect, it } from "vitest";

import { TelefonAlani } from "@/components/TelefonAlani";

import { ciz } from "./yardimci";

function Kutu({
  zorunlu = false,
  baslangic = "",
}: {
  zorunlu?: boolean;
  baslangic?: string;
}) {
  const [v, setV] = useState(baslangic);
  return createElement(TelefonAlani, {
    etiket: "Telefon",
    deger: v,
    onDegisti: setV,
    zorunlu,
  });
}

function alan(): HTMLInputElement {
  return document.querySelector<HTMLInputElement>(
    '[data-test="telefon-numara"]',
  )!;
}

// (P233 §3) ULKE KODU AYRI KUTUDA: `<select>`. Alanin kendisi artik yalniz
// ULUSAL kismi tasiyor, bu yuzden testler ulkeyi ya baslangic degerinden
// (E.164) verir ya da seciciden secer.
/** (P236) Ulke secici artik ARANABILIR bir acilir liste (select degil):
 *  degeri `value` degil, dugmenin METNI tasiyor. */
function ulke(): HTMLButtonElement {
  return document.querySelector<HTMLButtonElement>(
    '[data-test="telefon-ulke"]',
  )!;
}

describe("(P166 §9) bicimleme", () => {
  it("(P233 §3) BICIM: ulusal kisim gruplanir", () => {
    ciz(() => createElement(Kutu, { baslangic: "+90" }));
    fireEvent.change(alan(), { target: { value: "5431992904" } });
    expect(alan().value).toBe("543 199 29 04");
    expect(ulke().textContent).toContain("+90");
  });

  it("SINIRSIZ RAKAM GIRILEMEZ — 10 hanede kesilir", () => {
    // Kerem'in bildirdigi kusur tam olarak buydu.
    ciz(() => createElement(Kutu, { baslangic: "+90" }));
    fireEvent.change(alan(), { target: { value: "54319929049999999999" } });
    expect(alan().value).toBe("543 199 29 04");
  });

  it("(P227 §3) KESME SESSIZ DEGIL — fazla hane HATA gosterir", () => {
    // Kirpma davranisi kaldi ama artik SOYLENIYOR. Once 11. rakam
    // yazildiginda ekranda hicbir sey degismiyordu; kullanici numarayi
    // dogru sandigi halde son hanesi DUSMUS oluyordu.
    ciz(() => createElement(Kutu, { baslangic: "+90" }));
    fireEvent.change(alan(), { target: { value: "54319929041" } });
    fireEvent.blur(alan());
    expect(screen.getByText(/hane sayisini astiniz|hane sayısını aştınız/i))
      .toBeInTheDocument();
  });

  it("YAPISTIRMA cozulur (+90 / 0090 / bastaki 0) ve ULKEYI SECER", () => {
    // (P233 §3) Rehberden kopyalanan numara ULKE BILGISI tasir; kullanicidan
    // ayrica listeden secmesi BEKLENMEZ.
    for (const ham of ["+90 543 199 29 04", "00905431992904", "05431992904"]) {
      ciz(() => createElement(Kutu, {}));
      fireEvent.change(alan(), { target: { value: ham } });
      expect(alan().value, ham).toBe("543 199 29 04");
      expect(ulke().textContent, ham).toContain("+90");
    }
  });

  it("(P233 §3) YABANCI numara YAPISTIRILINCA o ulke secilir", () => {
    ciz(() => createElement(Kutu, {}));
    fireEvent.change(alan(), { target: { value: "+49 171 1234567" } });
    expect(ulke().textContent).toContain("+49");
    expect(alan().value).toBe("171 123 4567");
  });

  it("HARF YUTULUR", () => {
    ciz(() => createElement(Kutu, { baslangic: "+90" }));
    fireEvent.change(alan(), { target: { value: "abc543def199" } });
    expect(alan().value).toBe("543 199");
  });
});

describe("(P166 §9) alan bazinda hata", () => {
  it("YAZARKEN HATA GOSTERMEZ (kullaniciyi erken azarlama)", () => {
    ciz(() => createElement(Kutu, { zorunlu: true }));
    fireEvent.change(alan(), { target: { value: "543" } });
    expect(screen.queryByRole("alert")).toBeNull();
  });

  it("ALANDAN CIKINCA eksik numara icin hata verir", () => {
    ciz(() => createElement(Kutu, { zorunlu: true, baslangic: "+90" }));
    fireEvent.change(alan(), { target: { value: "543199" } });
    fireEvent.blur(alan());
    expect(screen.getByRole("alert").textContent).toMatch(/eksik/i);
    // Renk tek basina yetmez: alan `aria-invalid` de tasimali.
    expect(alan()).toHaveAttribute("aria-invalid", "true");
  });

  it("SABIT HAT reddedilir (0212…) — SMS gitmez", () => {
    ciz(() => createElement(Kutu, { zorunlu: true, baslangic: "+90" }));
    fireEvent.change(alan(), { target: { value: "2123334455" } });
    fireEvent.blur(alan());
    expect(screen.getByRole("alert").textContent).toMatch(/5 ile/i);
  });

  it("TAM ve GECERLI numarada hata YOK", () => {
    ciz(() => createElement(Kutu, { zorunlu: true, baslangic: "+90" }));
    fireEvent.change(alan(), { target: { value: "5431992904" } });
    fireEvent.blur(alan());
    expect(screen.queryByRole("alert")).toBeNull();
  });

  it("OPSIYONEL alanda BOS deger gecerlidir", () => {
    // Profilde kullanici numarasini SILEBILIR; bos birakmayi hata saymak
    // silme yolunu kapatirdi.
    ciz(() => createElement(Kutu, {}));
    fireEvent.blur(alan());
    expect(screen.queryByRole("alert")).toBeNull();
  });

  it("ZORUNLU alanda BOS deger hatadir", () => {
    ciz(() => createElement(Kutu, { zorunlu: true }));
    fireEvent.blur(alan());
    expect(screen.getByRole("alert")).toBeTruthy();
  });
});

// (P233 §3) ULKE SECILMEDEN numara GECERLI SAYILMAZ.
describe("(P233 §3) ulke kodu zorunlu", () => {
  it("ULKESIZ numara ALANDAN CIKINCA hata verir", () => {
    ciz(() => createElement(Kutu, { zorunlu: true }));
    fireEvent.change(alan(), { target: { value: "5431992904" } });
    fireEvent.blur(alan());
    expect(screen.getByRole("alert").textContent).toMatch(/ülke|ulke/i);
  });
});
