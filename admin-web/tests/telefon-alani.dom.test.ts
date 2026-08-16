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

function Kutu({ zorunlu = false }: { zorunlu?: boolean }) {
  const [v, setV] = useState("");
  return createElement(TelefonAlani, {
    etiket: "Telefon",
    deger: v,
    onDegisti: setV,
    zorunlu,
  });
}

function alan(): HTMLInputElement {
  return screen.getByLabelText(/telefon/i) as HTMLInputElement;
}

describe("(P166 §9) bicimleme", () => {
  it("BOSLUKLU gosterir: 05XX XXX XX XX", () => {
    ciz(() => createElement(Kutu, {}));
    fireEvent.change(alan(), { target: { value: "5431992904" } });
    expect(alan().value).toBe("0543 199 29 04");
  });

  it("SINIRSIZ RAKAM GIRILEMEZ — 10 hanede kesilir", () => {
    // Kerem'in bildirdigi kusur tam olarak buydu.
    ciz(() => createElement(Kutu, {}));
    fireEvent.change(alan(), { target: { value: "54319929049999999999" } });
    expect(alan().value).toBe("0543 199 29 04");
  });

  it("YAPISTIRMA cozulur (+90 / 0090 / bastaki 0)", () => {
    ciz(() => createElement(Kutu, {}));
    for (const ham of ["+90 543 199 29 04", "00905431992904", "05431992904"]) {
      fireEvent.change(alan(), { target: { value: ham } });
      expect(alan().value, ham).toBe("0543 199 29 04");
    }
  });

  it("HARF YUTULUR", () => {
    ciz(() => createElement(Kutu, {}));
    fireEvent.change(alan(), { target: { value: "abc543def199" } });
    expect(alan().value).toBe("0543 199");
  });
});

describe("(P166 §9) alan bazinda hata", () => {
  it("YAZARKEN HATA GOSTERMEZ (kullaniciyi erken azarlama)", () => {
    ciz(() => createElement(Kutu, { zorunlu: true }));
    fireEvent.change(alan(), { target: { value: "543" } });
    expect(screen.queryByRole("alert")).toBeNull();
  });

  it("ALANDAN CIKINCA eksik numara icin hata verir", () => {
    ciz(() => createElement(Kutu, { zorunlu: true }));
    fireEvent.change(alan(), { target: { value: "543199" } });
    fireEvent.blur(alan());
    expect(screen.getByRole("alert").textContent).toMatch(/eksik/i);
    // Renk tek basina yetmez: alan `aria-invalid` de tasimali.
    expect(alan()).toHaveAttribute("aria-invalid", "true");
  });

  it("SABIT HAT reddedilir (0212…) — SMS gitmez", () => {
    ciz(() => createElement(Kutu, { zorunlu: true }));
    fireEvent.change(alan(), { target: { value: "2123334455" } });
    fireEvent.blur(alan());
    expect(screen.getByRole("alert").textContent).toMatch(/5 ile/i);
  });

  it("TAM ve GECERLI numarada hata YOK", () => {
    ciz(() => createElement(Kutu, { zorunlu: true }));
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
