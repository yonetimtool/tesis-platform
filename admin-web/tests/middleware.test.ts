// Panelin oturum kapisi. Iki ayri sey test edilir:
//   1) DAVRANIS: refresh cookie yoksa /login'e yonlendir, varsa gecir.
//   2) KAPSAM: `config.matcher` app/(protected) altindaki TUM sayfalari
//      kapsiyor mu. Bu ikincisi kritik — yeni bir sayfa eklenip matcher'a
//      yazilmadiginda kapi o sayfa icin sessizce ACIK kalir (veri sizmaz,
//      cunku /api/* cagrilari 401 doner; ama oturumsuz kullanici panel
//      kabugunu gorur ve temiz yonlendirme yerine hata akisina duser).
import fs from "node:fs";
import path from "node:path";

import { NextRequest } from "next/server";
import { describe, expect, it } from "vitest";

import { ACCESS_COOKIE, REFRESH_COOKIE } from "@/lib/cookies";
import { config, middleware } from "@/middleware";

const KOK = path.resolve(__dirname, "..");

function istek(yol: string, cookie?: string): NextRequest {
  return new NextRequest(new URL(`http://panel.test${yol}`), {
    headers: cookie ? { cookie } : {},
  });
}

describe("oturum kapisi (davranis)", () => {
  it("oturum YOK: /login'e 307 yonlendirme (ayni host korunur)", () => {
    const res = middleware(istek("/dashboard"));
    const loc = new URL(res.headers.get("location") ?? "");
    expect(res.status).toBe(307);
    expect(loc.pathname).toBe("/login");
    expect(loc.host).toBe("panel.test");
  });

  it("BOS degerli refresh cookie oturum SAYILMAZ", () => {
    const res = middleware(istek("/dashboard", `${REFRESH_COOKIE}=`));
    expect(res.headers.get("location")).toContain("/login");
  });

  it("baska bir cookie oturum yerine GECMEZ (yalniz refresh cookie sayilir)", () => {
    const res = middleware(istek("/dashboard", "tesis_at=access-var"));
    expect(res.headers.get("location")).toContain("/login");
  });

  it("refresh cookie VAR: istek gecer (yonlendirme yok)", () => {
    // (P126.2) ROTA KONAKLA TUTARLI SECILIR. `istek()` `panel.test`
    // konagini kullanir, yani PLATFORM yuzeyidir; oraya bir TESIS rotasi
    // (`/dashboard`) sormak artik yuzey kapisina takilir ve 307 doner.
    // Bu testin olctugu sey OTURUM kapisidir — rota platform tarafindan
    // secilir ki iki kural birbirine karismasin.
    const res = middleware(istek("/tenants", `${REFRESH_COOKIE}=rt-123`));
    expect(res.status).toBe(200);
    expect(res.headers.get("location")).toBeNull();
  });

  it("derin yol ve sorgu dizesi korunur; yalniz pathname /login olur", () => {
    const res = middleware(istek("/reports/dues?donem=2026-07"));
    const loc = new URL(res.headers.get("location") ?? "");
    expect(loc.pathname).toBe("/login");
    expect(loc.search).toBe("?donem=2026-07");
  });

  it("token GECERLILIGI burada denetlenmez — varlik yeter (BFF 401'de yeniler)",
    () => {
      // Suresi dolmus/cop bir token bile kapiyi gecer; dogrulama BFF'te.
      // Platform konagi -> platform rotasi (bkz. yukaridaki not).
      const res = middleware(istek("/audit", `${REFRESH_COOKIE}=cop`));
      expect(res.status).toBe(200);
    });
});

/** app/(protected) altindaki sayfa rotalarini dosya sisteminden turetir. */
function korumaliRotalar(): string[] {
  const kok = path.join(KOK, "app", "(protected)");
  const out: string[] = [];
  const gez = (dir: string, onek: string): void => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      if (!e.isDirectory()) continue;
      const alt = path.join(dir, e.name);
      const yol = `${onek}/${e.name}`;
      if (fs.existsSync(path.join(alt, "page.tsx"))) out.push(yol);
      else gez(alt, yol); // orn. reports/ -> reports/dues
    }
  };
  gez(kok, "");
  return out.sort();
}

describe("matcher kapsami (yapisal)", () => {
  const rotalar = korumaliRotalar();

  it("app/(protected) altinda sayfa BULUNUR (test bosa dusmesin)", () => {
    expect(rotalar.length).toBeGreaterThan(10);
  });

  it("kok (/) korunur", () => {
    expect(config.matcher).toContain("/");
  });

  it("HER korumali sayfanin matcher girisi VAR", () => {
    // Bir giris ya tam yol ("/dashboard/:path*") ya da ust segmenti kapsar
    // ("/reports/:path*" -> /reports/dues).
    const kapsiyor = (rota: string): boolean =>
      config.matcher.some((m) => {
        const taban = m.replace("/:path*", "");
        return taban === rota || rota.startsWith(`${taban}/`);
      });

    const eksik = rotalar.filter((r) => !kapsiyor(r));
    expect(eksik, `matcher'da EKSIK korumali rotalar: ${eksik.join(", ")}`).toEqual([]);
  });

  it("matcher'da OLMAYAN bir rotaya isaret eden GEREKSIZ giris yok", () => {
    // Silinmis bir sayfanin girisi kalirsa liste yaniltici olur.
    const fazla = config.matcher
      .filter((m) => m !== "/")
      .map((m) => m.replace("/:path*", ""))
      .filter((taban) => !rotalar.some((r) => r === taban || r.startsWith(`${taban}/`)));
    expect(fazla, `matcher'da KARSILIGI OLMAYAN girisler: ${fazla.join(", ")}`)
      .toEqual([]);
  });

  it("/login ve /api/* KORUNMAZ (giris ekrani ve BFF kapinin disinda)", () => {
    for (const m of config.matcher) {
      expect(m.startsWith("/login")).toBe(false);
      expect(m.startsWith("/api")).toBe(false);
    }
  });
});

// --------------------------------------------------------------------------- #
// (P126.2) YUZEY KAPISI — menu gizlemek ERISILEMEZ yapmaz.
//
// P125 menuyu suzdu; ama adres cubuguna `/dues` yazan biri panelde o sayfayi
// yine acabiliyordu. Kerem'in sarti acikti: "enforcement is server-side, not
// hidden nav". Bu blok istegin SAYFA CIZILMEDEN kesildigini olcer.
//
// BU BIR VERI SINIRI DEGIL, YUZEY SINIRIDIR: veriyi backend RBAC korur
// (317 ucluk rol matrisi, dokunulmadi). Buradaki kural "hangi is hangi
// adreste yapilir".
function yuzeyIstegi(host: string, yol: string): NextRequest {
  return new NextRequest(new URL(`http://${host}${yol}`), {
    headers: { cookie: `${REFRESH_COOKIE}=rt-123` },
  });
}

/** Rol tasiyan istek: access cerezi (imzasiz sahte JWT) + refresh. */
function rolIstegi(host: string, yol: string, rol: string | null): NextRequest {
  const cerezler = [`${REFRESH_COOKIE}=rt-123`];
  if (rol) {
    const govde = Buffer.from(JSON.stringify({ role: rol })).toString(
      "base64url",
    );
    cerezler.push(`${ACCESS_COOKIE}=sahte.${govde}.imza`);
  }
  return new NextRequest(new URL(`http://${host}${yol}`), {
    headers: { cookie: cerezler.join("; ") },
  });
}

describe("rol kapisi (P126.7)", () => {
  const APP = "app.xn--ynetiyor-n4a.com";

  it("SAKIN yonetim sayfasini ACAMAZ — kendi baslangicina gider", () => {
    for (const yol of ["/finans", "/dues", "/users", "/shifts"]) {
      const res = middleware(rolIstegi(APP, yol, "resident"));
      expect(res.status, yol).toBe(307);
      expect(
        new URL(res.headers.get("location") ?? "").pathname,
        yol,
      ).toBe("/aidatim");
    }
  });

  it("SAKIN kendi sayfalarini ACAR", () => {
    for (const yol of ["/aidatim", "/taleplerim", "/kvkk", "/profil"]) {
      expect(middleware(rolIstegi(APP, yol, "resident")).status, yol).toBe(200);
    }
  });

  it("YONETICI arac gecislerini ACAMAZ (uc ona 403 doner)", () => {
    const res = middleware(rolIstegi(APP, "/arac-gecisleri", "yonetici"));
    expect(res.status).toBe(307);
    expect(new URL(res.headers.get("location") ?? "").pathname).toBe(
      "/dashboard",
    );
  });

  it("GUVENLIK kapi sayfalarini ACAR, finansi ACAMAZ", () => {
    expect(middleware(rolIstegi(APP, "/ziyaretciler", "security")).status).toBe(
      200,
    );
    expect(middleware(rolIstegi(APP, "/finans", "security")).status).toBe(307);
  });

  it("DERIN BAGLANTI rol kapisina TAKILMAZ", () => {
    // `/tasks/123` siniflandirmada YOKTUR; kok parcaya indirgenerek
    // degerlendirilir. Yoksa her derin baglanti "rolde yok" sayilirdi.
    expect(middleware(rolIstegi(APP, "/tasks/abc-123", "yonetici")).status).toBe(
      200,
    );
    expect(middleware(rolIstegi(APP, "/tasks/abc-123", "resident")).status).toBe(
      307,
    );
  });

  it("ACCESS CEREZI YOKSA rol kapisi UYGULANMAZ (yenileme sansi kalsin)", () => {
    // 15 dakikada access duser; refresh 30 gundur. Bu araliktaki kullaniciyi
    // disari atmak, oturumu acik birine "yetkin yok" demek olurdu.
    expect(middleware(rolIstegi(APP, "/finans", null)).status).toBe(200);
  });

  it("KOK (`/`) ROLE GORE yonlendirilir (dongu yok)", () => {
    const hedef = (rol: string) =>
      new URL(
        middleware(rolIstegi(APP, "/", rol)).headers.get("location") ?? "",
      ).pathname;
    expect(hedef("resident")).toBe("/aidatim");
    expect(hedef("security")).toBe("/ziyaretciler");
    expect(hedef("tesis_gorevlisi")).toBe("/gorevlerim");
    expect(hedef("yonetici")).toBe("/dashboard");
  });

  it("BOZUK access cerezi kapiyi TETIKLEMEZ (cokme/kilitlenme yok)", () => {
    const res = new NextRequest(new URL(`http://${APP}/finans`), {
      headers: { cookie: `${REFRESH_COOKIE}=rt; ${ACCESS_COOKIE}=bozuk` },
    });
    expect(middleware(res).status).toBe(200);
  });
});

describe("yuzey kapisi (P126.2)", () => {
  const APP = "app.xn--ynetiyor-n4a.com";
  const PANEL = "panel.xn--ynetiyor-n4a.com";

  it("PANELDE tesis rotasi ACILMAZ — platform kokune yonlendirilir", () => {
    for (const yol of ["/dues", "/finans", "/sayac-okuma", "/shifts", "/units"]) {
      const res = middleware(yuzeyIstegi(PANEL, yol));
      expect(res.status, yol).toBe(307);
      expect(new URL(res.headers.get("location") ?? "").pathname, yol).toBe(
        "/tenants",
      );
    }
  });

  it("APP'TE platform rotasi ACILMAZ — tesis kokune yonlendirilir", () => {
    for (const yol of ["/tenants", "/audit", "/support", "/integrations"]) {
      const res = middleware(yuzeyIstegi(APP, yol));
      expect(res.status, yol).toBe(307);
      expect(new URL(res.headers.get("location") ?? "").pathname, yol).toBe(
        "/dashboard",
      );
    }
  });

  it("DOGRU yuzeydeki rota GECER", () => {
    expect(middleware(yuzeyIstegi(PANEL, "/tenants")).status).toBe(200);
    expect(middleware(yuzeyIstegi(APP, "/dues")).status).toBe(200);
    expect(middleware(yuzeyIstegi(APP, "/finans")).status).toBe(200);
  });

  it("ALT YOLLAR da kapiya tabidir", () => {
    // `/tenants/abc-123` panelde gecer, app'te gecmez.
    expect(middleware(yuzeyIstegi(PANEL, "/tenants/abc-123")).status).toBe(200);
    expect(middleware(yuzeyIstegi(APP, "/tenants/abc-123")).status).toBe(307);
    // `/reports/dues` iki parcali bir TESIS rotasi.
    expect(middleware(yuzeyIstegi(APP, "/reports/dues")).status).toBe(200);
    expect(middleware(yuzeyIstegi(PANEL, "/reports/dues")).status).toBe(307);
  });

  it("KOK (`/`) yuzeyin kendi baslangicina gider", () => {
    // Panelde tesis panosu YOKTUR; app'te tesisler listesi yoktur.
    expect(
      new URL(middleware(yuzeyIstegi(PANEL, "/")).headers.get("location") ?? "")
        .pathname,
    ).toBe("/tenants");
    expect(
      new URL(middleware(yuzeyIstegi(APP, "/")).headers.get("location") ?? "")
        .pathname,
    ).toBe("/dashboard");
  });

  it("OTURUM KAPISI YUZEY KAPISINDAN ONCE gelir", () => {
    // Oturumsuz kullanici, yanlis yuzeydeki bir rotada bile `/login`e
    // gitmeli — yoksa once koke yonlendirilir, orada tekrar `/login`e
    // duser ve kullanici iki sicramali bir akis gorur.
    const res = middleware(new NextRequest(new URL(`http://${PANEL}/dues`)));
    expect(new URL(res.headers.get("location") ?? "").pathname).toBe("/login");
  });

  it("SINIFLANDIRILMAMIS rota ENGELLENMEZ", () => {
    // Bilinmeyen bir sayfayi kesmek, yeni bir sayfayi sessizce olduren bir
    // tuzak olurdu. Siniflandirmanin TAM olmasini yuzey-ayrimi testi
    // zorunlu tutuyor; kapinin isi BILINEN yanlis yerlesimi kesmek.
    expect(middleware(yuzeyIstegi(PANEL, "/henuz-yok")).status).toBe(200);
  });

  it("LEGACY panel.yonetio.site de PLATFORM yuzeyidir", () => {
    // Eski alan adi sonsuza kadar calisir; yuzeyi degismez.
    const res = middleware(yuzeyIstegi("panel.yonetio.site", "/dues"));
    expect(res.status).toBe(307);
    expect(new URL(res.headers.get("location") ?? "").pathname).toBe("/tenants");
  });
});
