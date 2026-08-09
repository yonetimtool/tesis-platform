// (P127) TANITIM YUZEYI — kok alan adi artik bir SITE.
//
// UC SEY OLCULUR:
//   1. Konak -> yuzey esleme (kok/www = tanitim; panel/app degismedi),
//   2. middleware tanitim yuzeyinde OTURUM KAPISINI CALISTIRMAZ — yoksa
//      markanin ana adresine giren her ziyaretci `/login`e duserdi,
//   3. icerik 7 dilde TAM ve dil dil AYRI (kopya/eksik yok).
import { readFileSync } from "node:fs";

import { NextRequest } from "next/server";
import { describe, expect, it } from "vitest";

import { middleware } from "@/middleware";
import { DILLER } from "@/lib/i18n/diller";
import { TANITIM_KOKEN } from "@/lib/tanitim/adres";
import { TANITIM } from "@/lib/tanitim/icerik";
import { konakYuzeyi, kokRota } from "@/lib/yuzey";

const KOK = "xn--ynetiyor-n4a.com";
const WWW = `www.${KOK}`;
const APP = `app.${KOK}`;
const PANEL = `panel.${KOK}`;

function istek(konak: string, yol: string, cerez = "") {
  return new NextRequest(new URL(`http://${konak}${yol}`), {
    headers: cerez ? { cookie: cerez } : undefined,
  });
}

describe("(P127) konak -> yuzey", () => {
  it("kok ve www TANITIM", () => {
    expect(konakYuzeyi(KOK)).toBe("tanitim");
    expect(konakYuzeyi(WWW)).toBe("tanitim");
    // Eski alan adi da tanitimdir (Caddy ikisini de sunuyor).
    expect(konakYuzeyi("yonetio.site")).toBe("tanitim");
    expect(konakYuzeyi("www.yonetio.site")).toBe("tanitim");
  });

  it("(P154) TIRELI alt alanlar da dogru yuzeye duser", () => {
    // Test sunucusu Cloudflare Tunnel arkasinda ve ucretsiz sertifika
    // IKI SEVIYELI alt alani kapsamadigi icin adlar tek seviyeye indi.
    // Eski `startsWith("app.")` kurali tireyle eslesmiyordu ve ikisi de
    // "tanitim" sayiliyordu — middleware o yuzeyde `/` disindaki HER yolu
    // koke geri attigi icin panel ve uygulama KULLANILAMAZ haldeydi.
    expect(konakYuzeyi("app-test.yonetio.site")).toBe("tesis");
    expect(konakYuzeyi("panel-test.yonetio.site")).toBe("platform");
    // Nokta bicimi AYNEN calismaya devam eder.
    expect(konakYuzeyi("app.yonetiyor.com")).toBe("tesis");
    expect(konakYuzeyi("panel.yonetiyor.com")).toBe("platform");
  });

  it("(P154) ETIKET SINIRI: gevsek eslesme YOK", () => {
    // `includes("app")` gibi bir kural bunlari da tesis sayardi.
    expect(konakYuzeyi("napp.example.com")).toBe("tanitim");
    expect(konakYuzeyi("apps.example.com")).toBe("tanitim");
    expect(konakYuzeyi("panelx.example.com")).toBe("tanitim");
    // `test.yonetio.site` TANITIM kalmali — tire kurali onu kapmamali.
    expect(konakYuzeyi("test.yonetio.site")).toBe("tanitim");
  });

  it("app./panel. DEGISMEDI (gerileme kapisi)", () => {
    expect(konakYuzeyi(APP)).toBe("tesis");
    expect(konakYuzeyi(PANEL)).toBe("platform");
  });

  it("YEREL gelistirme PLATFORM kalir", () => {
    // `npm run dev` diyen gelistirici panele bakar; onu tanitim sayfasina
    // dusurmek her gun bir tiklama fazlasi olurdu.
    for (const h of ["localhost", "localhost:3000", "127.0.0.1", ""]) {
      expect(konakYuzeyi(h), h).toBe("platform");
    }
  });

  it("kok rotasi yuzeye gore", () => {
    expect(kokRota("tanitim")).toBe("/");
    expect(kokRota("platform")).toBe("/tenants");
    expect(kokRota("tesis")).toBe("/dashboard");
  });
});

describe("(P127) middleware — tanitim PUBLIC", () => {
  it("OTURUMSUZ ziyaretci koku GORUR (login'e DUSMEZ)", () => {
    const res = middleware(istek(KOK, "/"));
    expect(res.status).toBe(200);
  });

  it("www da ayni", () => {
    expect(middleware(istek(WWW, "/")).status).toBe(200);
  });

  it("kok alan adinda KORUMALI adres KOKE doner (login'e degil)", () => {
    // Giris o alan adinin isi degildir: panel.* ve app.* vardir. Orada
    // bir giris formu gostermek yuzey ayrimini bozardi.
    const res = middleware(istek(KOK, "/dues"));
    expect(res.status).toBe(307);
    expect(new URL(res.headers.get("location") ?? "").pathname).toBe("/");
  });

  it("PANEL/APP yuzeyinde oturum kapisi DEGISMEDI", () => {
    // Gerileme kapisi: tanitim dali eklenirken oturum kapisi kirilmamali.
    for (const konak of [PANEL, APP]) {
      const res = middleware(istek(konak, "/dashboard"));
      expect(res.status, konak).toBe(307);
      expect(new URL(res.headers.get("location") ?? "").pathname).toBe("/login");
    }
  });
});

describe("(P127) icerik — 7 dil TAM", () => {
  it("her dilde tum alanlar dolu", () => {
    for (const dil of DILLER) {
      const i = TANITIM[dil];
      expect(i, dil).toBeTruthy();
      for (const [alan, deger] of Object.entries(i)) {
        if (Array.isArray(deger)) {
          expect(deger.length, `${dil}/${alan}`).toBeGreaterThan(0);
        } else {
          expect(String(deger).trim().length, `${dil}/${alan}`).toBeGreaterThan(0);
        }
      }
      // Ozellik sayisi TUM dillerde ayni olmali: bir dilde eksik madde,
      // o dildeki ziyaretciye urunun daha az sey yaptigini soylerdi.
      expect(i.ozellikler.length, dil).toBe(TANITIM.tr.ozellikler.length);
      expect(i.hakkimizdaParagraflar.length, dil).toBe(
        TANITIM.tr.hakkimizdaParagraflar.length,
      );
    }
  });

  it("TR metni baska dile KOPYALANMAMIS", () => {
    // P126.7'nin dersi: ceviri yerine kopya yapistirmak sessiz bir
    // hatadir. E-posta adresi haric (kasitli olarak ayni).
    for (const dil of DILLER) {
      if (dil === "tr") continue;
      const i = TANITIM[dil];
      expect(i.metaBaslik, dil).not.toBe(TANITIM.tr.metaBaslik);
      expect(i.yoneticiBaslik, dil).not.toBe(TANITIM.tr.yoneticiBaslik);
      expect(i.sakinAlt, dil).not.toBe(TANITIM.tr.sakinAlt);
      expect(i.iletisimEposta, dil).toBe(TANITIM.tr.iletisimEposta);
    }
  });
});

describe("(P127) SEO plumbing", () => {
  it("robots CALISMA ALANINI indekslemez, tanitimi indeksler", () => {
    const kaynak = readFileSync("app/robots.ts", "utf8");
    expect(kaynak).toContain('konakYuzeyi');
    expect(kaynak).toContain("disallow");
    expect(kaynak).toContain("sitemap");
  });

  it("sitemap YALNIZ public adresleri sayar", () => {
    const kaynak = readFileSync("app/sitemap.ts", "utf8");
    expect(kaynak).toContain("/gizlilik");
    expect(kaynak).toContain("/kosullar");
    // Calisma alani rotalari haritada OLMAMALI (302 zinciri + indeks
    // butcesi israfi).
    expect(kaynak).not.toContain("/dashboard");
    expect(kaynak).not.toContain("/dues");
  });

  it("hreflang 7 dili de bildiriyor", () => {
    const kaynak = readFileSync("app/page.tsx", "utf8");
    expect(kaynak).toContain("languages");
    expect(kaynak).toContain("alternates");
    expect(kaynak).toContain("DILLER");
  });

  it("kanonik adres PUNYCODE ve TEK yerde", () => {
    // Unicode konak (`yönetiyor.com`) yazmak ayni sayfayi IKI KOKEN gibi
    // gosterebilirdi; `infra/alan-adi-denetimi.py` da yapilandirmada
    // unicode birakmayi reddediyor — kod ayni dili konussun.
    expect(TANITIM_KOKEN).toBe("https://xn--ynetiyor-n4a.com");
    for (const yol of ["app/page.tsx", "app/sitemap.ts", "app/robots.ts"]) {
      const kaynak = readFileSync(yol, "utf8");
      expect(kaynak, yol).toContain("TANITIM_KOKEN");
      expect(kaynak, yol).not.toMatch(/https:\/\/y[^\s"']*netiyor\.com/);
    }
  });
});
