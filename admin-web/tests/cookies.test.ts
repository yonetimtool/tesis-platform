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
  cookieDomain,
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

// (P191 §1) COOKIE_DOMAIN — panel.* ve app.* AYNI OTURUMU paylasir.
//
// P190 §1 tesis rollerini panel.*'tan app.*'a tasimaya basladi; cerezler
// KONAK-OZEL oldugu icin kullanici tasinir tasinmaz oturumunu kaybediyor ve
// `/login`e dusuyordu. Degisken BOSSA davranis eskisiyle AYNI kalmali —
// yerel gelistirme ve testler bunun uzerine kurulu.
describe("cookieDomain (P191 §1)", () => {
  const eski = process.env.COOKIE_DOMAIN;
  afterEach(() => {
    if (eski === undefined) delete (process.env as Record<string, string | undefined>).COOKIE_DOMAIN;
    else (process.env as Record<string, string | undefined>).COOKIE_DOMAIN = eski;
  });

  function ayarla(v: string | undefined): void {
    // `process.env.X = undefined` degeri "undefined" DIZESINE cevirir.
    if (v === undefined) delete (process.env as Record<string, string | undefined>).COOKIE_DOMAIN;
    else (process.env as Record<string, string | undefined>).COOKIE_DOMAIN = v;
  }

  it("VARSAYILAN: alan adi YOK (konak-ozel cerez, bugunku davranis)", () => {
    ayarla(undefined);
    expect(cookieOptions(60).domain).toBeUndefined();
    ayarla("   ");
    expect(cookieOptions(60).domain).toBeUndefined();
  });

  it("verilince cerez ust alan adina yazilir", () => {
    ayarla(".yonetiyor.com");
    expect(cookieOptions(60).domain).toBe(".yonetiyor.com");
    expect(cookieDomain()).toBe(".yonetiyor.com");
  });

  it("localhost YOK SAYILIR (tarayici alan-adli localhost cerezini reddeder)", () => {
    ayarla("localhost");
    expect(cookieOptions(60).domain).toBeUndefined();
  });
});
