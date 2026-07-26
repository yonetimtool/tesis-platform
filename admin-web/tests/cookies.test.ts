// Token cookie'leri: isimler ve secenekler /contracts/auth.md ile AYNI olmali.
// Buradaki bir sapma ya oturumu erken dusurur (maxAge) ya da guvenlik
// varsayimini bozar (httpOnly/sameSite/secure). Middleware de ayni sabitleri
// okur — isim degisirse tum korumali rotalar sessizce acik kalir.
import { afterEach, describe, expect, it } from "vitest";

import {
  ACCESS_COOKIE,
  ACCESS_MAX_AGE,
  REFRESH_COOKIE,
  REFRESH_MAX_AGE,
  cookieOptions,
} from "@/lib/cookies";

describe("cookie isimleri", () => {
  it("sabit ve birbirinden farkli", () => {
    expect(ACCESS_COOKIE).toBe("tesis_at");
    expect(REFRESH_COOKIE).toBe("tesis_rt");
    expect(ACCESS_COOKIE).not.toBe(REFRESH_COOKIE);
  });
});

describe("omur sureleri (auth.md: access 15 dk, refresh 30 gun)", () => {
  it("saniye cinsinden sozlesmeyle birebir", () => {
    expect(ACCESS_MAX_AGE).toBe(15 * 60);
    expect(REFRESH_MAX_AGE).toBe(30 * 24 * 60 * 60);
  });

  it("refresh access'ten UZUN (aksi halde sessiz yenileme imkansiz)", () => {
    expect(REFRESH_MAX_AGE).toBeGreaterThan(ACCESS_MAX_AGE);
  });
});

describe("cookieOptions", () => {
  const eski = process.env.NODE_ENV;
  afterEach(() => {
    // NODE_ENV salt-okunur tiplenir; testte gecici olarak yaziyoruz.
    (process.env as Record<string, string | undefined>).NODE_ENV = eski;
  });

  it("her zaman httpOnly + sameSite=lax + kok yol", () => {
    const o = cookieOptions(ACCESS_MAX_AGE);
    expect(o.httpOnly).toBe(true); // istemci JS token'i GOREMEZ
    expect(o.sameSite).toBe("lax"); // CSRF yuzeyini daraltir
    expect(o.path).toBe("/");
    expect(o.maxAge).toBe(ACCESS_MAX_AGE);
  });

  it("secure YALNIZ production'da acilir (dev http:// uzerinde calisir)", () => {
    (process.env as Record<string, string | undefined>).NODE_ENV = "production";
    expect(cookieOptions(60).secure).toBe(true);

    (process.env as Record<string, string | undefined>).NODE_ENV = "development";
    expect(cookieOptions(60).secure).toBe(false);
  });

  it("verilen maxAge aynen tasinir (access/refresh ayni fabrikayi kullanir)", () => {
    expect(cookieOptions(REFRESH_MAX_AGE).maxAge).toBe(REFRESH_MAX_AGE);
  });
});
