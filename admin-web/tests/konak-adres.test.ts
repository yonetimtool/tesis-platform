// (P191 §1) KONAK-OTESI YONLENDIRME ADRESLERI.
//
// Bu dosyanin TEK ISI su iddiayi kanitlamak: uretilen hicbir yonlendirme
// adresinde PORT YOKTUR. Prod'da olculen kusur `app.yonetiyor.com:3000`
// idi — Next'in ic dinleme portu `req.nextUrl` uzerinden sizmisti ve
// tarayici ERR_CONNECTION_TIMED_OUT aliyordu (3000 disari kapali).
import { describe, expect, it } from "vitest";

import {
  appKonagi,
  istekKonagi,
  kokAdresNormalize,
  konakOtesiAdres,
  panelKonagi,
} from "@/lib/konak-adres";

function basliklar(kv: Record<string, string>): Headers {
  return new Headers(kv);
}

describe("kokAdresNormalize", () => {
  it("port ATILIR, sondaki yol/slash atilir", () => {
    expect(kokAdresNormalize("https://app.yonetiyor.com:3000/")).toBe("https://app.yonetiyor.com");
    expect(kokAdresNormalize("https://app.yonetiyor.com/kayit")).toBe("https://app.yonetiyor.com");
    expect(kokAdresNormalize(" https://app.yonetiyor.com ")).toBe("https://app.yonetiyor.com");
  });

  it("bos / gecersiz / http disi sema -> null", () => {
    for (const d of ["", "   ", null, undefined, "app.yonetiyor.com", "ftp://a.b"]) {
      expect(kokAdresNormalize(d)).toBeNull();
    }
  });
});

describe("konak esdegerleri", () => {
  it("panel <-> app YALNIZ ilk etiket TAM eslesirse", () => {
    expect(appKonagi("panel.yonetiyor.com")).toBe("app.yonetiyor.com");
    expect(appKonagi("panel.yonetiyor.com:3000")).toBe("app.yonetiyor.com");
    expect(panelKonagi("app.yonetiyor.com")).toBe("panel.yonetiyor.com");
    // Alt-dize eslesmesi OLMAZ.
    expect(appKonagi("mypanel.example.com")).toBeNull();
    expect(panelKonagi("napp.example.com")).toBeNull();
    // Yerel gelistirme konaklarinda esdeger YOK.
    for (const h of ["localhost", "localhost:3000", "127.0.0.1", ""]) {
      expect(appKonagi(h)).toBeNull();
      expect(panelKonagi(h)).toBeNull();
    }
  });
});

describe("istekKonagi", () => {
  it("x-forwarded-host > host; port atilir; zincirde ILK deger", () => {
    expect(istekKonagi(basliklar({ host: "admin-web:3000", "x-forwarded-host": "panel.yonetiyor.com" }))).toBe(
      "panel.yonetiyor.com",
    );
    expect(istekKonagi(basliklar({ "x-forwarded-host": "panel.yonetiyor.com, kenar.example" }))).toBe(
      "panel.yonetiyor.com",
    );
    expect(istekKonagi(basliklar({ host: "panel.yonetiyor.com:8443" }))).toBe("panel.yonetiyor.com");
    expect(istekKonagi(basliklar({}))).toBeNull();
  });
});

describe("konakOtesiAdres", () => {
  const bas = basliklar({ host: "panel.yonetiyor.com", "x-forwarded-proto": "https" });

  it("ORTAM DEGISKENI kazanir ve portu tasinmaz", () => {
    const adres = konakOtesiAdres("/kayit", "?niyet=kayit", {
      ortamKok: "https://app.yonetiyor.com:3000",
      yedekKonak: "app.yonetiyor.com",
      basliklar: bas,
    });
    expect(adres).toBe("https://app.yonetiyor.com/kayit?niyet=kayit");
  });

  it("ortam degiskeni YOKSA iletilmis basliklardan turetilir (yine portsuz)", () => {
    expect(
      konakOtesiAdres("/", "", { ortamKok: null, yedekKonak: "app.yonetiyor.com", basliklar: bas }),
    ).toBe("https://app.yonetiyor.com/");
  });

  it("sema `x-forwarded-proto`dan; baslik yoksa https VARSAYILIR", () => {
    expect(
      konakOtesiAdres("/", "", {
        ortamKok: null,
        yedekKonak: "app.yonetiyor.com",
        basliklar: basliklar({ "x-forwarded-proto": "http" }),
      }),
    ).toBe("http://app.yonetiyor.com/");
    expect(
      konakOtesiAdres("/", "", { ortamKok: null, yedekKonak: "app.yonetiyor.com", basliklar: basliklar({}) }),
    ).toBe("https://app.yonetiyor.com/");
  });

  it("hedef konak yoksa null -> cagiran yonlendirme YAPMAZ", () => {
    expect(konakOtesiAdres("/", "", { ortamKok: null, yedekKonak: null, basliklar: bas })).toBeNull();
  });

  it("URETILEN ADRESTE ASLA PORT YOKTUR (kusurun kendisi)", () => {
    const girdiler = [
      { ortamKok: "https://app.yonetiyor.com:3000/", yedekKonak: "app.yonetiyor.com:3000" },
      { ortamKok: null, yedekKonak: "app.yonetiyor.com:3000" },
      { ortamKok: "https://app.yonetiyor.com", yedekKonak: null },
    ];
    for (const g of girdiler) {
      const adres = konakOtesiAdres("/kayit", "", { ...g, basliklar: bas });
      expect(adres).not.toBeNull();
      expect(new URL(adres!).port).toBe("");
      expect(adres).not.toMatch(/:\d{2,5}\//);
    }
  });
});
