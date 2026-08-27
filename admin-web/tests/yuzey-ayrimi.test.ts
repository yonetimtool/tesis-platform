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

import { _OGELER, PROFIL_OGESI } from "@/lib/menu";
import {
  PLATFORM_ROTALARI,
  TESIS_ROTALARI,
  konakYuzeyi,
  rolYuzeyeGirebilir,
  mobilYalnizRol,
  rotaYuzeyi,
  tesisYuzeyiBekleyenRol,
} from "@/lib/yuzey";

/**
 * Menudeki tum href'ler.
 *
 * (P133.1) Eskiden `AppShell.tsx` KAYNAGINDAN regex ile okunuyordu; liste
 * `lib/menu.ts`e tasininca kirildi. Artik MODULDEN okunuyor — kaynak
 * taramasindan daha saglam: dosya yeniden duzenlense de calisir ve
 * "regex hicbir sey bulamadi, 0 href, test gecti" hâli imkânsizdir
 * (asagidaki alt sinir kontrolleri de bunu ayrica olcer).
 */
function menuHrefleri(): string[] {
  return [..._OGELER.map((o) => o.href), PROFIL_OGESI.href];
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

  it("`app` GECEN ama app.* OLMAYAN konak TESIS DEGILDIR", () => {
    // `apple.ornek` ya da `panel.app.ornek` yanlislikla tesis sayilmamali.
    // (P127) Beklenen deger DEGISTI: `app.` ile baslamayan bilinmeyen bir
    // konak artik "platform" degil TANITIM'dir — varsayilani platform
    // birakmak, markanin ana adresinde bir yonetici giris ekrani acmak
    // demekti. Olculen KURAL ayni: "icinde app gecmesi tesis yapmaz".
    expect(konakYuzeyi("apple.ornek.com")).toBe("tanitim");
    // `panel.` ONEKI kazanir — bilinen bir calisma yuzeyidir.
    expect(konakYuzeyi("panel.app.ornek.com")).toBe("platform");
    expect(konakYuzeyi("apple.ornek.com")).not.toBe("tesis");
  });
});

describe("AppShell menuyu YUZEYDEN turetiyor", () => {
  it("menu listesi ELLE suzulmuyor — `rotaYuzeyi` cagriliyor", () => {
    // Elle yazilmis bir `if` listesi, `lib/yuzey.ts` guncellenince
    // ayrisirdi. Kaynak, tek kaynaktan turetmeyi zorunlu tutuyor.
    // (P133.1) Suzgec `lib/menu.ts`e tasindi (bolumleme ile birlikte);
    // kilit de oraya tasindi — kabuk artik hazir gruplari ciziyor.
    const menuKaynak = readFileSync("lib/menu.ts", "utf8");
    expect(menuKaynak).toContain("rotaYuzeyi(o.href) === yuzey");
    expect(menuKaynak).toContain("rotaRoldeGorunur(o.href, rol)");
    const kaynak = readFileSync("components/AppShell.tsx", "utf8");
    // Kabuk KENDI suzgecini yazmaz: `menuGruplari`yi cagirir.
    expect(kaynak).toContain("menuGruplari(yuzey, rol)");
    // (P126 sonrasi) YUZEY ARTIK KABUKTA COZULMUYOR, uclu olarak geliyor:
    // sunucu ciziminde `window` yoktu ve ilk kare `app.*`ta bile PLATFORM
    // menusuyle boyaniyordu. Cozum konagi ISTEGIN BASLIGINDAN okumak —
    // yani cagri korumali DUZENDE. Kilit oraya tasindi.
    const duzen = readFileSync("app/(protected)/layout.tsx", "utf8");
    expect(duzen).toContain("konakYuzeyi(");
    expect(duzen).toContain('get("host")');
    expect(kaynak).not.toContain("window.location.host");
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

  it("(P129) TESIS yuzeyine YALNIZ yonetici + denetci (+ admin) girer", () => {
    // Kapsam P129'da DARALDI: `app.*` bir masabasi yuzeyidir. `admin`in
    // girebilmesi bilincli — bir tesisin gordugu ekrani dogrulamali.
    for (const r of ["yonetici", "denetci", "admin"]) {
      expect(rolYuzeyeGirebilir(r, "tesis"), r).toBe(true);
    }
  });

  it("(P129) MOBIL-YALNIZ roller tesis yuzeyine GIREMEZ", () => {
    // Sakin, guvenlik ve saha gorevlisi isini TELEFONDA yapar. Kapi
    // sunucu tarafinda: oturum HIC kurulmaz (menu gizlemek degil).
    for (const r of ["resident", "security", "tesis_gorevlisi"]) {
      expect(rolYuzeyeGirebilir(r, "tesis"), r).toBe(false);
      expect(mobilYalnizRol(r), r).toBe(true);
      // "Yakinda" DEMEZ: web calisma alani planlanmiyor.
      expect(tesisYuzeyiBekleyenRol(r), r).toBe(false);
    }
  });

  it("`guvenlik_amiri` HÂLÂ BEKLEYEN rol (ne web ne mobil seti var)", () => {
    expect(rolYuzeyeGirebilir("guvenlik_amiri", "tesis")).toBe(false);
    expect(tesisYuzeyiBekleyenRol("guvenlik_amiri")).toBe(true);
    // Mobil-yalniz DEGIL: onu magazaya yollamak da yanlis olurdu.
    expect(mobilYalnizRol("guvenlik_amiri")).toBe(false);
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
    // (P154/P179) Blok basligi ARTIK degisken konak: `{$APP_DOMAIN},
    // {$APP_DOMAIN_IDN} {` (kanonik `app.yonetiyor.com`). Tam basligi aramak
    // kilidi kirmasin — testin olctugu sey basligin METNI degil, `app.`
    // blogunun gercekten uygulamaya PROXY'lenmesi. Baslangic isareti guncel
    // blok basligina gore daraltildi.
    const blok = caddy.slice(caddy.indexOf("{$APP_DOMAIN}, {$APP_DOMAIN_IDN} {"));
    const govde = blok.slice(0, blok.indexOf("\n}"));
    expect(govde).toContain("reverse_proxy admin-web:3000");
    expect(govde).not.toContain("/srv/portal/app");
  });
});
