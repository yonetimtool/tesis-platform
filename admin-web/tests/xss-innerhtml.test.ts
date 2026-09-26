import { readFileSync } from "node:fs";
import { relative, resolve } from "node:path";

import { describe, expect, it } from "vitest";

import { taranacakDosyalar } from "./tarama";

// (P248 §3c) XSS — `innerHTML` / `outerHTML` / `insertAdjacentHTML` /
// `document.write` KILIDI.
//
// `dangerouslySetInnerHTML` zaten iki kilitte (duz-metin-alanlari: izinli
// dosya listesi; guvenlik-hijyeni: degisken icermez). DOM API'siyle HTML
// yazmak ise hicbir kilitte degildi: React kacisini TAMAMEN atlar. Tek
// mesru kullanim zengin metin editoru — degeri ya kullanicinin KENDI
// yazdigi (contenteditable) ya da sunucunun `ZenginHtml` tipiyle TEMIZLEDIGI
// govde (backend/app/temizleme.py, test_temizleme.py).
const IZINLI: Record<string, string> = {
  "components/ZenginMetin.tsx":
    "contenteditable editor: deger sunucuda ZenginHtml ile temizlenmis govde ya da kullanicinin kendi yazdigi",
};

const DESEN = /\.(innerHTML|outerHTML)\s*=(?!=)|insertAdjacentHTML\(|document\.write\(/;

describe("(P248 §3c) DOM uzerinden HTML yazimi kilidi", () => {
  it("yalniz izinli dosyalar DOM'a ham HTML yazar", () => {
    const kok = resolve(__dirname, "..");
    const kullanan = taranacakDosyalar(["app", "components", "lib"], [".ts", ".tsx"])
      .filter((y) => DESEN.test(readFileSync(y, "utf8")))
      .map((y) => relative(kok, y));
    expect(kullanan.sort()).toEqual(Object.keys(IZINLI).sort());
  });

  it("POZITIF KONTROL: desen atamayi yakalar, okumayi birakir", () => {
    expect(DESEN.test("el.innerHTML = x;")).toBe(true);
    expect(DESEN.test("if (k.innerHTML !== d)")).toBe(false);
    expect(DESEN.test("el.insertAdjacentHTML('beforeend', x)")).toBe(true);
  });
});
