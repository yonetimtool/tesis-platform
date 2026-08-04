// (P125) YUZEY AYRIMI — panel PLATFORM-ONLY, app.* TESIS.
//
// Kerem'in urun karari: panel.yönetiyor.com yalniz platform sahibinin
// yuzeyidir; tek bir sitenin islemleri (aidat tahsilati, sayac okuma,
// vardiya) oraya GIRMEZ.
//
// NEDEN TEST: "menuyu suzdum" bir kez calisir, sonra biri listeye yeni bir
// tesis sayfasi ekler ve panelde belirir — hicbir sey dusmez, kimse fark
// etmez. Kilit, siniflandirmanin TAM olmasini ve menunun ondan TURETILMESINI
// zorunlu tutar.
import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

import {
  PLATFORM_ROTALARI,
  TESIS_ROTALARI,
  konakYuzeyi,
  rotaYuzeyi,
} from "@/lib/yuzey";

/** `AppShell` icindeki menu listesinin href'leri (kaynaktan okunur). */
function menuHrefleri(): string[] {
  const kaynak = readFileSync("components/AppShell.tsx", "utf8");
  const blok = kaynak.slice(
    kaynak.indexOf("const LINKS"),
    kaynak.indexOf("function Icon"),
  );
  return [...blok.matchAll(/href:\s*"([^"]+)"/g)].map((m) => m[1]);
}

describe("rota siniflandirmasi", () => {
  it("MENUDEKI HER ROTA siniflandirilmis (bilinmeyen KALMAZ)", () => {
    // Bilinmeyen bir rota menude ne platformda ne teste gorunur — yani
    // sessizce KAYBOLUR. Bu test onu gurultulu hale getirir.
    const siniflanmamis = menuHrefleri().filter((h) => rotaYuzeyi(h) === null);
    expect(
      siniflanmamis,
      `lib/yuzey.ts'e ekleyin (platform mi tesis mi?): ${siniflanmamis.join(", ")}`,
    ).toEqual([]);
  });

  it("PLATFORM ve TESIS kumeleri KESISMEZ", () => {
    const kesisim = PLATFORM_ROTALARI.filter((r) =>
      (TESIS_ROTALARI as readonly string[]).includes(r),
    );
    expect(kesisim).toEqual([]);
  });

  it("TESIS sayfalari PLATFORM kumesinde DEGIL (urun karari)", () => {
    // Kerem'in acik sarti: panelde tek bir sitenin aidat islemleri olmasin.
    for (const r of ["/dues", "/finans", "/sayac-okuma", "/shifts", "/tasks"]) {
      expect(rotaYuzeyi(r), r).toBe("tesis");
    }
  });

  it("PLATFORM sayfalari dogru siniflanmis", () => {
    for (const r of ["/tenants", "/audit", "/support", "/integrations"]) {
      expect(rotaYuzeyi(r), r).toBe("platform");
    }
  });

  it("`users` TESIS tarafinda — bir tesisin personel listesidir", () => {
    // Platformun kullanici isi /tenants/[id] icindeki "yonetici ata"dir.
    expect(rotaYuzeyi("/users")).toBe("tesis");
  });
});

describe("konakYuzeyi", () => {
  it("app.* -> tesis", () => {
    expect(konakYuzeyi("app.xn--ynetiyor-n4a.com")).toBe("tesis");
    expect(konakYuzeyi("app.xn--ynetiyor-n4a.com:443")).toBe("tesis");
    expect(konakYuzeyi("APP.XN--YNETIYOR-N4A.COM")).toBe("tesis");
  });

  it("panel.* ve digerleri -> platform", () => {
    expect(konakYuzeyi("panel.xn--ynetiyor-n4a.com")).toBe("platform");
    expect(konakYuzeyi("panel.yonetio.site")).toBe("platform");
    expect(konakYuzeyi("localhost:3000")).toBe("platform");
    expect(konakYuzeyi(null)).toBe("platform");
  });

  it("`app` GECEN ama app.* OLMAYAN konak platformdur", () => {
    // `apple.ornek` ya da `panel.app.ornek` yanlislikla tesis sayilmamali.
    expect(konakYuzeyi("apple.ornek.com")).toBe("platform");
    expect(konakYuzeyi("panel.app.ornek.com")).toBe("platform");
  });
});

describe("AppShell menuyu YUZEYDEN turetiyor", () => {
  it("menu listesi ELLE suzulmuyor — `rotaYuzeyi` cagriliyor", () => {
    // Elle yazilmis bir `if` listesi, `lib/yuzey.ts` guncellenince
    // ayrisirdi. Kaynak, tek kaynaktan turetmeyi zorunlu tutuyor.
    const kaynak = readFileSync("components/AppShell.tsx", "utf8");
    expect(kaynak).toContain("rotaYuzeyi(l.href) === yuzey");
    expect(kaynak).toContain("konakYuzeyi(");
  });

  it("PANELDE hicbir TESIS rotasi menuye girmez", () => {
    const platformMenu = menuHrefleri().filter(
      (h) => rotaYuzeyi(h) === "platform",
    );
    for (const h of platformMenu) {
      expect(TESIS_ROTALARI as readonly string[]).not.toContain(h);
    }
    // Ve menude gercekten platform ogesi VAR (bos kume "gecti" demesin).
    expect(platformMenu.length).toBeGreaterThanOrEqual(5);
  });

  it("APP YUZEYINDE hicbir PLATFORM rotasi menuye girmez", () => {
    const tesisMenu = menuHrefleri().filter((h) => rotaYuzeyi(h) === "tesis");
    for (const h of tesisMenu) {
      expect(PLATFORM_ROTALARI as readonly string[]).not.toContain(h);
    }
    expect(tesisMenu.length).toBeGreaterThanOrEqual(15);
  });
});

describe("panel giris kapisi — TESIS ROLU PANELE GIREMEZ", () => {
  it("login rotasi `admin` disindaki rolu 403 ile reddeder", () => {
    // Sunucu tarafi zorlama: menuyu gizlemek yetkilendirme DEGILDIR, ama
    // bu kapi zaten girisin kendisini kesiyor. Davranis kilitleniyor —
    // P126 `app.*`i actiginda bu kapinin YALNIZ panel icin gecerli
    // kalmasi gerekecek ve o zaman bu test degistirilmeli.
    const kaynak = readFileSync("app/api/auth/login/route.ts", "utf8");
    expect(kaynak).toContain('tokenRole(tokens.access_token) !== "admin"');
    expect(kaynak).toContain("403");
  });
});
