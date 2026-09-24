// (P247 §2) PROFILDEN ROL GECISI — YONETICI <-> SAKIN (web).
//
// Olculen dort katman:
//   1. JETON -> WEB ROLU: `resident` + `asil_rol:yonetici` = SAKIN_MODU;
//      saf sakin HALA mobil-yalniz (P129).
//   2. ARA KATMAN: sakin modu yalniz sakin rotalarina girer; yonetim
//      rotasi sakin ana sayfasina (Aidatim) yonlenir.
//   3. MENU: sakin modunda tek bolum, tek yonetim ogesi yok.
//   4. PROFIL MENUSU: yalniz `roller.length == 2` iken iki secenek; secim
//      BFF'e dogru govdeyle gider. BFF refresh cerezini govdeye koyar ve
//      yeni jetonu yuzey kapisindan gecirir.
//   5. BILDIRIM: hedef aktif modda yoksa diger modda aranir (otomatik gecis).
import { readFileSync } from "node:fs";

import { NextRequest } from "next/server";
import { describe, expect, it } from "vitest";

import { ACCESS_COOKIE, REFRESH_COOKIE } from "@/lib/cookies";
import { menuGruplari } from "@/lib/menu";
import {
  SAKIN_KIMLIKLERI,
  bildirimHedefi,
  digerRol,
  gecisMenusuVar,
  webRolu,
} from "@/lib/rol-gecisi";
import { tokenRolu } from "@/lib/rol-token";
import {
  SAKIN_MODU,
  TESIS_ROTALARI,
  kokRotaRol,
  rolYuzeyeGirebilir,
  rotaRoldeGorunur,
} from "@/lib/yuzey";
import { middleware } from "@/middleware";

function jeton(govde: Record<string, unknown>): string {
  const b64 = (o: unknown) =>
    Buffer.from(JSON.stringify(o)).toString("base64url");
  return `${b64({ alg: "HS256" })}.${b64(govde)}.imza`;
}

const SAKIN_JETONU = jeton({ sub: "u1", role: "resident", asil_rol: "yonetici" });
const YONETICI_JETONU = jeton({ sub: "u1", role: "yonetici" });
const APP = "app.xn--ynetiyor-n4a.com";

function istek(yol: string, access: string): NextRequest {
  return new NextRequest(new URL(`http://${APP}${yol}`), {
    headers: { cookie: `${REFRESH_COOKIE}=rt; ${ACCESS_COOKIE}=${access}` },
  });
}

function hedef(res: Response): string | null {
  const loc = res.headers.get("location");
  return loc ? new URL(loc).pathname : null;
}

describe("1. jeton -> web rolu", () => {
  it("resident + asil_rol:yonetici = SAKIN_MODU", () => {
    expect(tokenRolu(SAKIN_JETONU)).toBe(SAKIN_MODU);
  });
  it("saf sakin HALA resident ve app.*a GIREMEZ (P129 korunuyor)", () => {
    const saf = jeton({ role: "resident" });
    expect(tokenRolu(saf)).toBe("resident");
    expect(rolYuzeyeGirebilir("resident", "tesis")).toBe(false);
    expect(rolYuzeyeGirebilir(SAKIN_MODU, "tesis")).toBe(true);
    // Guvenlik gibi baska bir rol asil_rol iddiasiyla sakin moduna DONMEZ.
    expect(tokenRolu(jeton({ role: "resident", asil_rol: "security" }))).toBe("resident");
  });
  it("/me yaniti: roller 2 ise menu, 1 ise yok", () => {
    const cift = { role: "resident", roller: ["yonetici", "resident"] };
    expect(webRolu(cift)).toBe(SAKIN_MODU);
    expect(gecisMenusuVar(cift)).toBe(true);
    expect(digerRol(cift)).toBe("yonetici");
    expect(gecisMenusuVar({ role: "yonetici", roller: ["yonetici"] })).toBe(false);
    expect(gecisMenusuVar({ role: "security", roller: ["security"] })).toBe(false);
    expect(webRolu({ role: "resident", roller: ["resident"] })).toBe("resident");
  });
});

describe("2. ara katman (middleware)", () => {
  it("sakin modu: kok -> Aidatim, sakin rotalari ACIK", () => {
    expect(hedef(middleware(istek("/", SAKIN_JETONU)))).toBe("/aidatim");
    for (const yol of ["/aidatim", "/taleplerim", "/duyurular", "/rezervasyonlarim", "/profil", "/notifications"]) {
      expect(middleware(istek(yol, SAKIN_JETONU)).status, yol).toBe(200);
    }
  });
  it("sakin modu: HER yonetim rotasi sakin ana sayfasina yonlenir", () => {
    const yonetim = TESIS_ROTALARI.filter(
      (r) => rotaRoldeGorunur(r, "yonetici") && !rotaRoldeGorunur(r, SAKIN_MODU),
    );
    expect(yonetim.length).toBeGreaterThan(30);
    for (const yol of yonetim) {
      const res = middleware(istek(yol, SAKIN_JETONU));
      expect(res.status, yol).toBe(307);
      expect(hedef(res), yol).toBe("/aidatim");
    }
    // Derin baglanti da (alt yol) kesilir.
    expect(hedef(middleware(istek("/users/123", SAKIN_JETONU)))).toBe("/aidatim");
  });
  it("yonetici modu: sakin sayfalari KAPALI, kok Ozet", () => {
    expect(hedef(middleware(istek("/aidatim", YONETICI_JETONU)))).toBe("/dashboard");
    expect(middleware(istek("/users", YONETICI_JETONU)).status).toBe(200);
    expect(kokRotaRol("tesis", "yonetici")).toBe("/dashboard");
  });
});

describe("3. sakin modu menusu", () => {
  it("TEK basliksiz bolum; ogeler yalniz sakin sayfalari; ikonlar benzersiz", () => {
    const g = menuGruplari("tesis", SAKIN_MODU);
    expect(g.map((x) => x.id)).toEqual(["sakin"]);
    expect(g[0].bagimsiz).toBe(true);
    const hrefler = g[0].ogeler.map((o) => o.href);
    expect(hrefler).toEqual([
      "/aidatim", "/duyurular", "/taleplerim", "/rezervasyonlarim",
      "/etkinlikler", "/kurallar", "/notifications", "/yonetim-iletisim",
    ]);
    const ikonlar = g[0].ogeler.map((o) => o.icon);
    expect(new Set(ikonlar).size).toBe(ikonlar.length);
    for (const h of hrefler) expect(rotaRoldeGorunur(h, "yonetici") && h !== "/notifications", h).toBe(false);
  });
  it("sakin modunda gorunen HER rota menude ya da profil menusunde (kayip sayfa yok)", () => {
    const menude = new Set(menuGruplari("tesis", SAKIN_MODU).flatMap((g) => g.ogeler.map((o) => o.href)));
    const gorunen = TESIS_ROTALARI.filter((r) => rotaRoldeGorunur(r, SAKIN_MODU));
    const disarida = gorunen.filter((r) => !menude.has(r));
    // Profil ve KVKK sag ust kullanici menusundedir (P167 §1.7).
    expect(disarida.sort()).toEqual(["/kvkk", "/profil"]);
  });
});

describe("5. bildirim -> otomatik mod gecisi", () => {
  const cift = (role: string) => ({ role, roller: ["yonetici", "resident"] });

  it("sakin modunda yonetim bildirimi -> yoneticiye gecip hedefe", () => {
    expect(bildirimHedefi("panik_alarm", SAKIN_MODU, cift("resident"))).toEqual({
      rota: "/panik",
      gecis: "yonetici",
    });
    expect(bildirimHedefi("bakim_gecikti", SAKIN_MODU, cift("resident"))).toEqual({
      rota: "/bakim",
      gecis: "yonetici",
    });
  });
  it("yonetici modunda sakinin kendi bildirimi -> sakine gecip hedefe", () => {
    expect(bildirimHedefi("aidat_borc", "yonetici", cift("yonetici"))).toEqual({
      rota: "/aidatim",
      gecis: "resident",
    });
  });
  it("aktif modda erisilebilen hedefe GECIS YOK", () => {
    expect(bildirimHedefi("talep_cozuldu", SAKIN_MODU, cift("resident"))).toEqual({
      rota: "/taleplerim",
      gecis: null,
    });
    expect(bildirimHedefi("panik_alarm", "yonetici", cift("yonetici"))).toEqual({
      rota: "/panik",
      gecis: null,
    });
  });
  it("tek rollu kiside gecis ONERILMEZ", () => {
    const tek = { role: "yonetici", roller: ["yonetici"] };
    expect(bildirimHedefi("aidat_borc", "yonetici", tek)).toBeNull();
    expect(bildirimHedefi("aidat_borc", "yonetici", null)).toBeNull();
  });
});

describe("4b. BFF rotasi", () => {
  it("BFF: refresh cerezi GOVDEYE konur, yeni jeton yuzey kapisindan gecer", () => {
    const k = readFileSync("app/api/me/rol-gecis/route.ts", "utf8");
    expect(k).toContain("req.cookies.get(REFRESH_COOKIE)");
    expect(k).toContain("refresh_token: refresh");
    expect(k).toContain("oturumAc(req, veri.access_token, veri.refresh_token)");
    expect(k).toContain('proxyJson("/me", "GET")');
  });
});

describe("5b. SAKINE yazilmis bildirim (backend SAKIN_KIMLIKLERI ile ayni kume)", () => {
  const cift = (role: string) => ({ role, roller: ["yonetici", "resident"] });

  it("kume backend'deki kumeyle BIREBIR ayni (ayrisirsa duser)", () => {
    const kaynak = readFileSync("../backend/app/push_gorunum.py", "utf8");
    const blok = kaynak.slice(kaynak.indexOf("SAKIN_KIMLIKLERI"));
    const govde = blok.slice(blok.indexOf("{"), blok.indexOf("})"));
    const backend = [...govde.matchAll(/"([a-z_]+)"/g)].map((m) => m[1]).sort();
    expect([...SAKIN_KIMLIKLERI].sort()).toEqual(backend);
  });

  it("yonetici modunda talep_cozuldu -> sakine gecip Taleplerim (yonetim Talepler DEGIL)", () => {
    expect(bildirimHedefi("talep_cozuldu", "yonetici", cift("yonetici"))).toEqual({
      rota: "/taleplerim",
      gecis: "resident",
    });
  });

  it("tek rollu yoneticide talep_cozuldu yonetim ekranina gider (gecis yok)", () => {
    expect(
      bildirimHedefi("talep_cozuldu", "yonetici", { role: "yonetici", roller: ["yonetici"] }),
    ).toEqual({ rota: "/complaints", gecis: null });
  });
});
