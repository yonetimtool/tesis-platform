// @vitest-environment jsdom
// (P126 sonrasi) `?lang=xx` — PAYLASILAN BAGLANTI icin acik dil secimi.
//
// SIRA: kayitli tercih > `?lang` > tarayici (Ingilizce haric) > Turkce.
// Kullanicinin KENDI secimi bir baglantiyla EZILMEZ — birinin gonderdigi
// `?lang=ar`, dilini Turkce yapmis birinin arayuzunu degistirmemeli.
import { render, screen } from "@testing-library/react";
import { createElement } from "react";
import { afterEach, describe, expect, it } from "vitest";

import { I18nProvider, useT } from "@/lib/i18n/kullan";

function Ekran() {
  const t = useT();
  return createElement("p", null, t("girisYap"));
}

function ciz(arama: string, baslangic: "tr" | "en" | "ar" = "tr") {
  window.history.replaceState({}, "", `/login${arama}`);
  return render(
    createElement(I18nProvider, {
      baslangicDili: baslangic,
      children: createElement(Ekran),
    }),
  );
}

afterEach(() => {
  document.cookie = "ui.locale=; path=/; max-age=0";
  window.history.replaceState({}, "", "/");
});

describe("?lang", () => {
  it("gecerli dil UYGULANIR ve cereze YAZILIR (sonraki istek sunucuda dogru)", () => {
    ciz("?lang=de");
    expect(screen.getByText("Anmelden")).toBeInTheDocument();
    expect(document.cookie).toContain("ui.locale=de");
  });

  it("KAYITLI TERCIH varsa `?lang` EZEMEZ", () => {
    document.cookie = "ui.locale=tr; path=/";
    ciz("?lang=ar");
    // Turkce metin kalir; Arapca'ya gecilmez.
    expect(screen.getByText("Giriş yap")).toBeInTheDocument();
    expect(document.cookie).toContain("ui.locale=tr");
  });

  it("UYDURMA deger yok sayilir (cokme yok, dil degismez)", () => {
    ciz("?lang=xx");
    expect(screen.getByText("Giriş yap")).toBeInTheDocument();
    expect(document.cookie).not.toContain("ui.locale=xx");
  });

  it("parametre YOKSA hicbir sey degismez", () => {
    ciz("");
    expect(screen.getByText("Giriş yap")).toBeInTheDocument();
    expect(document.cookie).not.toContain("ui.locale=");
  });
});
