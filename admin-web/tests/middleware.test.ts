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

import { REFRESH_COOKIE } from "@/lib/cookies";
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
    const res = middleware(istek("/dashboard", `${REFRESH_COOKIE}=rt-123`));
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
      const res = middleware(istek("/units", `${REFRESH_COOKIE}=cop`));
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
