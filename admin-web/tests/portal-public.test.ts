// P38 — PUBLIC portal rotasi oturum kapisinin DISINDA kalmali.
//
// Bu olcumun nedeni: middleware kapsam kilidi (`middleware.test.ts`) yalniz
// app/(protected) agacini ZORUNLU tutar; ters yonu — public bir rotanin
// yanlislikla matcher'a girmesini — kimse kontrol etmiyordu. Girseydi site
// sayfasi oturumsuz ziyaretciyi /login'e atardi ve portal ISLEVSIZ olurdu.
import fs from "node:fs";
import path from "node:path";

import { describe, expect, it } from "vitest";

import { config, middleware } from "@/middleware";
import { NextRequest } from "next/server";

const KOK = path.resolve(__dirname, "..");

describe("public portal rotasi", () => {
  it("sayfa app/(protected) AGACINDA DEGIL", () => {
    // Korunan agaca konsaydi kapsam kilidi onu matcher'a eklemeyi
    // zorunlu kilar ve rota sessizce kapali hale gelirdi.
    expect(fs.existsSync(path.join(KOK, "app/site/[slug]/page.tsx"))).toBe(true);
    expect(
      fs.existsSync(path.join(KOK, "app/(protected)/site")),
    ).toBe(false);
  });

  it("matcher /site yolunu KAPSAMAZ", () => {
    const kapsar = config.matcher.some((m) => m.startsWith("/site"));
    expect(kapsar, "public portal oturum kapisina girmemeli").toBe(false);
  });

  it("matcher'daki her giris korunan bir yol (public yol sizmamis)", () => {
    // "/" disindaki her matcher girisi bir alt-yol deseni olmali; boylece
    // gelecekte "/*" gibi her seyi yutan bir desen eklenirse yakalanir.
    for (const m of config.matcher) {
      if (m === "/") continue;
      expect(m, `beklenmeyen matcher deseni: ${m}`).toMatch(/^\/[a-z-]+\/:path\*$/);
    }
  });

  it("kapi DAVRANISI degismedi: korunan yol hala /login'e gider", () => {
    const res = middleware(new NextRequest(new URL("http://panel.test/dashboard")));
    expect(res.status).toBe(307);
  });
});
