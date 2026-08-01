// (P104) BFF ROTALARI DA CEVIRIR.
//
// `metin()` tarayici icindir: dili `document.cookie`den okur ve SUNUCUDA
// `document` YOKTUR — yani her zaman varsayilan dile duser. BFF rotalari
// kullaniciya DOGRUDAN metin dondurur (`{error:{message}}`); orada
// "her zaman Turkce" demek, ingilizce arayuzde Turkce hata gostermekti.
// P46/P54'un ayni sinifi, bu kez SUNUCUDA — ve panel i18n taramalari
// yalniz `.tsx` okudugu icin `route.ts` HIC taranmamisti.
import { describe, expect, it } from "vitest";

import { istekDili, istekMetni } from "@/lib/i18n/istek-metni";

function sahteIstek(cerez?: string, kabul?: string) {
  return {
    cookies: { get: (ad: string) => (ad === "ui.locale" && cerez ? { value: cerez } : undefined) },
    headers: { get: (ad: string) => (ad === "accept-language" ? kabul ?? null : null) },
  };
}

describe("istekDili (P104)", () => {
  it("CEREZ once gelir", () => {
    expect(istekDili(sahteIstek("de", "fr-FR,fr;q=0.9"))).toBe("de");
  });

  it("cerez yoksa Accept-Language", () => {
    expect(istekDili(sahteIstek(undefined, "fr-FR,fr;q=0.9"))).toBe("fr");
  });

  it("hicbiri yoksa VARSAYILAN", () => {
    expect(istekDili(sahteIstek())).toBe("tr");
  });

  it("TANINMAYAN cerez degeri yok sayilir (uydurma dil secilemez)", () => {
    expect(istekDili(sahteIstek("xx", "en-US"))).toBe("en");
  });
});

describe("istekMetni (P104)", () => {
  it("secilen dilde metin doner", () => {
    const tr = istekMetni(sahteIstek("tr"), "girisBasarisiz");
    const en = istekMetni(sahteIstek("en"), "girisBasarisiz");
    expect(tr).not.toBe(en);
    expect(en).toMatch(/[A-Za-z]/);
  });
});
