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
  rolYuzeyeGirebilir,
  rotaYuzeyi,
  tesisYuzeyiBekleyenRol,
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
  // NOT: bu blogun ilk hali kapinin ICINI (`!== "admin"` sabiti) olcuyordu
  // ve P126.1 kapiyi yuzeye baglayinca DUSTU — hakli olarak. Uygulamayi
  // degil DAVRANISI olcmek gerekiyordu: "tesis rolu panele giremez".
  it("hicbir tesis rolu PLATFORM yuzeyine giremez", () => {
    for (const r of ["yonetici", "security", "tesis_gorevlisi", "resident", "guvenlik_amiri"]) {
      expect(rolYuzeyeGirebilir(r, "platform"), r).toBe(false);
    }
  });

  it("giris rotasi kapiyi UYGULUYOR ve 403 donuyor", () => {
    const kaynak = readFileSync("app/api/auth/login/route.ts", "utf8");
    expect(kaynak).toContain("rolYuzeyeGirebilir");
    expect(kaynak).toContain("403");
  });
});

describe("rol x yuzey kapisi (P126.1)", () => {
  it("PLATFORM yuzeyine yalniz `admin` girer", () => {
    expect(rolYuzeyeGirebilir("admin", "platform")).toBe(true);
    for (const r of ["yonetici", "security", "tesis_gorevlisi", "resident", "guvenlik_amiri"]) {
      expect(rolYuzeyeGirebilir(r, "platform"), r).toBe(false);
    }
  });

  it("TESIS yuzeyine `yonetici`, `resident`, `security` ve `admin` girer", () => {
    // `resident` P126.3 sonunda eklendi: gunluk isini web'den yapabilecegi
    // set tamamlandi (aidat, talep, duyuru, kural, etkinlik, rezervasyon,
    // KVKK, profil). `admin`in girebilmesi bilincli: bir tesisin gordugu
    // ekrani dogrulamak icin oraya bakabilmeli.
    for (const r of ["yonetici", "resident", "security", "admin"]) {
      expect(rolYuzeyeGirebilir(r, "tesis"), r).toBe(true);
    }
  });

  it("SAYFALARI HENUZ OLMAYAN roller tesis yuzeyine ALINMAZ", () => {
    // Girer girmez her yerde 403 goren bir ekran vermek yerine "yakinda"
    // demek daha durust. `security`/`tesis_gorevlisi` icin ziyaretci,
    // kargo, ihlal, arac gecisi ve gorevlerim sayfalari HENUZ YOK.
    for (const r of ["tesis_gorevlisi", "guvenlik_amiri"]) {
      expect(rolYuzeyeGirebilir(r, "tesis"), r).toBe(false);
      expect(tesisYuzeyiBekleyenRol(r), r).toBe(true);
    }
  });

  it("SAKIN ve GUVENLIK artik BEKLEYEN rol DEGIL", () => {
    // Ikisinin de kendi seti tamamlandi (P126.3 / P126.4).
    expect(tesisYuzeyiBekleyenRol("resident")).toBe(false);
    expect(tesisYuzeyiBekleyenRol("security")).toBe(false);
  });

  it("ROLSUZ/bilinmeyen token hicbir yuzeye giremez", () => {
    expect(rolYuzeyeGirebilir(null, "platform")).toBe(false);
    expect(rolYuzeyeGirebilir(null, "tesis")).toBe(false);
    expect(rolYuzeyeGirebilir("uydurma_rol", "tesis")).toBe(false);
  });

  it("`admin` BEKLEYEN rol sayilmaz (yanlis mesaj gitmesin)", () => {
    expect(tesisYuzeyiBekleyenRol("admin")).toBe(false);
    expect(tesisYuzeyiBekleyenRol("yonetici")).toBe(false);
  });

  it("giris rotasi kapiyi KONAKTAN turetiyor (sabit rol karsilastirmasi YOK)", () => {
    // Eski hal `!== "admin"` diye sabit bir karsilastirmaydi; app.* acilinca
    // tesis rollerini de reddederdi.
    const kaynak = readFileSync("app/api/auth/login/route.ts", "utf8");
    expect(kaynak).toContain('konakYuzeyi(req.headers.get("host"))');
    expect(kaynak).toContain("rolYuzeyeGirebilir(rol, yuzey)");
    expect(kaynak).not.toContain('!== "admin"');
  });
});

describe("Caddy — app.* artik uygulamaya proxy'leniyor", () => {
  it("app. blogu `admin-web:3000`e gider (yer tutucu DEGIL)", () => {
    const caddy = readFileSync("../infra/Caddyfile", "utf8");
    const blok = caddy.slice(caddy.indexOf("app.{$PORTAL_DOMAIN} {"));
    const govde = blok.slice(0, blok.indexOf("\n}"));
    expect(govde).toContain("reverse_proxy admin-web:3000");
    expect(govde).not.toContain("/srv/portal/app");
  });
});
