// BFF cekirdegi (lib/backend.ts): token'lar httpOnly cookie'de, istemci ASLA
// gormez. Buradaki bir kusur ya oturumu dusurur ya da — refresh rotation
// nedeniyle — kullaniciyi kalici olarak login'e kilitler:
//
//   * Backend refresh'te ROTATION yapar (eski token gecersizlesir). Es zamanli
//     iki 401 iki ayri refresh cagirirsa ikincisi "reuse" sayilip oturumu
//     komple iptal ettirir. Bu yuzden TEK-UCUS (single-flight) davranisi
//     burada acikca kilitlenir.
//   * Refresh sonrasi DONEN yeni cift cookie'ye yazilmazsa kullanici bir
//     sonraki istekte tekrar 401 alir; "rastgele atiliyorum" sikayeti budur.
//
// `next/headers` sunucuya ozgudur; taklit edilerek node ortaminda kosulur.
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { API_BASE } from "@/lib/config";
import {
  ACCESS_COOKIE,
  ACCESS_MAX_AGE,
  REFRESH_COOKIE,
  REFRESH_MAX_AGE,
} from "@/lib/cookies";

// Istek cookie kavanozu — test basina doldurulur (vi.mock hoist edildigi icin
// vi.hoisted ile paylasilir).
const { kavanoz } = vi.hoisted(() => ({
  kavanoz: { degerler: {} as Record<string, string> },
}));

vi.mock("next/headers", () => ({
  cookies: () => ({
    get: (ad: string) =>
      kavanoz.degerler[ad] === undefined
        ? undefined
        : { name: ad, value: kavanoz.degerler[ad] },
  }),
}));

const { backendLogin, loginResponse, logoutResponse, proxyJson } = await import(
  "@/lib/backend"
);

interface SahteYanit {
  status?: number;
  body?: unknown;
  headers?: Record<string, string>;
  /** json() patlasin (govde JSON degil). */
  bozukGovde?: boolean;
}

type Yonlendirici = (
  url: string,
  init: Record<string, unknown>,
) => SahteYanit | Promise<SahteYanit>;

/** URL'e gore yanit ureten `fetch` taklidi; cagri listesini dondurur. */
function stubFetch(yonlendirici: Yonlendirici): [string, Record<string, unknown>][] {
  const f = vi.fn(async (url: string, init: Record<string, unknown>) => {
    const y = await yonlendirici(url, init ?? {});
    const status = y.status ?? 200;
    const h = new Headers(y.headers ?? {});
    return {
      status,
      ok: status >= 200 && status < 300,
      headers: h,
      json: async () => {
        if (y.bozukGovde) throw new Error("govde JSON degil");
        return y.body ?? null;
      },
    };
  });
  vi.stubGlobal("fetch", f);
  return f.mock.calls as unknown as [string, Record<string, unknown>][];
}

/** Yanittaki Set-Cookie degeri (NextResponse.cookies.get semantigi). */
function cookieOf(res: Response, ad: string) {
  return (res as unknown as { cookies: { get: (n: string) => undefined | {
    value: string; httpOnly?: boolean; maxAge?: number; path?: string;
    expires?: Date;
  } } }).cookies.get(ad);
}

const OK_CIFT = { access_token: "yeni-at", refresh_token: "yeni-rt" };

beforeEach(() => {
  kavanoz.degerler = {};
  vi.unstubAllGlobals();
});
afterEach(() => vi.unstubAllGlobals());

describe("backendLogin", () => {
  it("backend /auth/login'e JSON POST atar; ok/status/data doner", async () => {
    const cagrilar = stubFetch(() => ({ status: 200, body: OK_CIFT }));
    const r = await backendLogin({
      tenant_slug: "acme-plaza",
      email: "admin@acme.com",
      password: "Admin123!",
    });

    expect(r).toEqual({ ok: true, status: 200, data: OK_CIFT });
    const [url, init] = cagrilar[0];
    expect(url).toBe(`${API_BASE}/auth/login`);
    expect(init.method).toBe("POST");
    expect((init.headers as Record<string, string>)["Content-Type"]).toBe(
      "application/json",
    );
    expect(JSON.parse(init.body as string).email).toBe("admin@acme.com");
    // Oturum verisi ONBELLEKLENEMEZ.
    expect(init.cache).toBe("no-store");
  });

  it("401: ok=false + sunucunun hata zarfi AYNEN tasinir", async () => {
    const zarf = { error: { code: "unauthorized", message: "Kimlik dogrulanamadi." } };
    stubFetch(() => ({ status: 401, body: zarf }));
    const r = await backendLogin({ tenant_slug: "a", email: "e", password: "p" });
    expect(r.ok).toBe(false);
    expect(r.status).toBe(401);
    expect(r.data).toEqual(zarf);
  });

  it("govde JSON degilse data=null (cagiran route patlamasin)", async () => {
    stubFetch(() => ({ status: 502, bozukGovde: true }));
    const r = await backendLogin({ tenant_slug: "a", email: "e", password: "p" });
    expect(r).toEqual({ ok: false, status: 502, data: null });
  });

  it("hicbir cookie OKUNMAZ (login oncesi oturum yok)", async () => {
    stubFetch(() => ({ body: OK_CIFT }));
    await backendLogin({ tenant_slug: "a", email: "e", password: "p" });
    const [, init] = (fetch as unknown as { mock: { calls: [string, Record<string, unknown>][] } })
      .mock.calls[0];
    expect((init.headers as Record<string, string>).Authorization).toBeUndefined();
  });
});

describe("loginResponse / logoutResponse", () => {
  it("login: iki cookie de httpOnly + kok yol + SOZLESME omurleriyle yazilir", () => {
    const res = loginResponse("at-1", "rt-1");
    const at = cookieOf(res, ACCESS_COOKIE);
    const rt = cookieOf(res, REFRESH_COOKIE);

    expect(at?.value).toBe("at-1");
    expect(at?.httpOnly).toBe(true);
    expect(at?.path).toBe("/");
    expect(at?.maxAge).toBe(ACCESS_MAX_AGE);

    expect(rt?.value).toBe("rt-1");
    expect(rt?.httpOnly).toBe(true);
    expect(rt?.maxAge).toBe(REFRESH_MAX_AGE);
  });

  it("logout: iki cookie de BOSALTILIR ve gecmise tarihlenir", () => {
    const res = logoutResponse();
    for (const ad of [ACCESS_COOKIE, REFRESH_COOKIE]) {
      const c = cookieOf(res, ad);
      expect(c?.value, ad).toBe("");
      expect(c?.expires?.getTime(), ad).toBe(0); // epoch = tarayici hemen siler
    }
  });
});

describe("proxyJson — normal akis", () => {
  it("access cookie'si Bearer olarak eklenir; istemci token'i gormez", async () => {
    kavanoz.degerler[ACCESS_COOKIE] = "at-1";
    const cagrilar = stubFetch(() => ({ status: 200, body: { items: [] } }));

    const res = await proxyJson("/units", "GET");
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ items: [] });

    const [url, init] = cagrilar[0];
    expect(url).toBe(`${API_BASE}/units`);
    expect((init.headers as Record<string, string>).Authorization).toBe("Bearer at-1");
    expect(init.cache).toBe("no-store");
    // Yanit cookie'ye DOKUNMAZ (rotasyon yok).
    expect(cookieOf(res, ACCESS_COOKIE)).toBeUndefined();
  });

  it("access cookie YOKKEN Authorization eklenmez (public uc / 401 beklenir)",
    async () => {
      const cagrilar = stubFetch(() => ({ status: 200, body: {} }));
      await proxyJson("/health", "GET");
      expect((cagrilar[0][1].headers as Record<string, string>).Authorization)
        .toBeUndefined();
    });

  it("govde VARSA Content-Type + JSON; YOKSA ikisi de yok", async () => {
    kavanoz.degerler[ACCESS_COOKIE] = "at";
    const cagrilar = stubFetch(() => ({ status: 201, body: { id: "u1" } }));

    await proxyJson("/units", "POST", { no: "A-12" });
    let init = cagrilar[0][1];
    expect((init.headers as Record<string, string>)["Content-Type"]).toBe(
      "application/json",
    );
    expect(JSON.parse(init.body as string)).toEqual({ no: "A-12" });

    await proxyJson("/units/u1/archive", "POST");
    init = cagrilar[1][1];
    expect((init.headers as Record<string, string>)["Content-Type"]).toBeUndefined();
    expect(init.body).toBeUndefined();
  });

  it("ek basliklar (Idempotency-Key) korunur", async () => {
    kavanoz.degerler[ACCESS_COOKIE] = "at";
    const cagrilar = stubFetch(() => ({ body: {} }));
    await proxyJson("/dues/pay", "POST", { kurus: 1 }, { "Idempotency-Key": "k-9" });
    expect((cagrilar[0][1].headers as Record<string, string>)["Idempotency-Key"])
      .toBe("k-9");
  });

  it("upstream durum kodu AYNEN gecer (201/409/500)", async () => {
    kavanoz.degerler[ACCESS_COOKIE] = "at";
    for (const s of [201, 409, 500]) {
      stubFetch(() => ({ status: s, body: { error: { message: "x" } } }));
      expect((await proxyJson("/x", "POST", {})).status, `${s}`).toBe(s);
    }
  });

  it("204: govde OKUNMAYA CALISILMAZ, govdesiz yanit doner (DELETE)", async () => {
    kavanoz.degerler[ACCESS_COOKIE] = "at";
    stubFetch(() => ({ status: 204, bozukGovde: true }));
    const res = await proxyJson("/units/u1", "DELETE");
    expect(res.status).toBe(204);
    expect(await res.text()).toBe("");
  });

  it("content-length: 0 basligi da govdesiz sayilir", async () => {
    kavanoz.degerler[ACCESS_COOKIE] = "at";
    stubFetch(() => ({ status: 200, headers: { "content-length": "0" }, bozukGovde: true }));
    const res = await proxyJson("/x", "POST");
    expect(res.status).toBe(200);
    expect(await res.text()).toBe("");
  });

  it("govde JSON degilse null gecer (panel 'bir hata olustu' gosterir)", async () => {
    kavanoz.degerler[ACCESS_COOKIE] = "at";
    stubFetch(() => ({ status: 502, bozukGovde: true }));
    const res = await proxyJson("/x", "GET");
    expect(res.status).toBe(502);
    expect(await res.json()).toBeNull();
  });
});

describe("proxyJson — 401 sonrasi refresh + cookie rotasyonu", () => {
  it("401 -> refresh -> TEKRAR dener ve YENI cifti cookie'ye yazar", async () => {
    kavanoz.degerler[ACCESS_COOKIE] = "eski-at";
    kavanoz.degerler[REFRESH_COOKIE] = "eski-rt";

    const cagrilar = stubFetch((url, init) => {
      if (url.endsWith("/auth/refresh")) {
        expect(JSON.parse(init.body as string)).toEqual({ refresh_token: "eski-rt" });
        return { status: 200, body: OK_CIFT };
      }
      const yetki = (init.headers as Record<string, string>).Authorization;
      // Eski token 401; yenilenmis token 200.
      return yetki === "Bearer eski-at"
        ? { status: 401, body: { error: { message: "expired" } } }
        : { status: 200, body: { items: [1] } };
    });

    const res = await proxyJson("/units", "GET");

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ items: [1] });
    // Sira: dene -> refresh -> tekrar dene
    expect(cagrilar.map((c) => c[0])).toEqual([
      `${API_BASE}/units`,
      `${API_BASE}/auth/refresh`,
      `${API_BASE}/units`,
    ]);
    // ROTASYON yaniti cookie'lere yazilmali; yoksa sonraki istek yine 401 olur.
    expect(cookieOf(res, ACCESS_COOKIE)?.value).toBe("yeni-at");
    expect(cookieOf(res, REFRESH_COOKIE)?.value).toBe("yeni-rt");
    expect(cookieOf(res, ACCESS_COOKIE)?.maxAge).toBe(ACCESS_MAX_AGE);
    expect(cookieOf(res, REFRESH_COOKIE)?.maxAge).toBe(REFRESH_MAX_AGE);
  });

  it("refresh BASARISIZ: 401 zarfi + cookie'ler TEMIZLENIR (istemci login'e doner)",
    async () => {
      kavanoz.degerler[ACCESS_COOKIE] = "eski-at";
      kavanoz.degerler[REFRESH_COOKIE] = "olu-rt";
      stubFetch((url) =>
        url.endsWith("/auth/refresh")
          ? { status: 401, body: { error: { message: "revoked" } } }
          : { status: 401, body: null },
      );

      const res = await proxyJson("/units", "GET");
      expect(res.status).toBe(401);
      expect(await res.json()).toEqual({
        error: { code: "unauthorized", message: "Oturum süresi doldu." },
      });
      for (const ad of [ACCESS_COOKIE, REFRESH_COOKIE]) {
        expect(cookieOf(res, ad)?.value, ad).toBe("");
      }
    });

  it("refresh AG HATASI verirse de ayni sonuc (patlamaz)", async () => {
    kavanoz.degerler[ACCESS_COOKIE] = "eski-at";
    kavanoz.degerler[REFRESH_COOKIE] = "rt";
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string) => {
        if (url.endsWith("/auth/refresh")) throw new Error("ECONNREFUSED");
        return {
          status: 401,
          ok: false,
          headers: new Headers(),
          json: async () => null,
        };
      }),
    );

    const res = await proxyJson("/units", "GET");
    expect(res.status).toBe(401);
    expect(cookieOf(res, REFRESH_COOKIE)?.value).toBe("");
  });

  it("401 ama refresh cookie YOK: refresh DENENMEZ, 401 aynen gecer", async () => {
    kavanoz.degerler[ACCESS_COOKIE] = "at";
    const zarf = { error: { code: "unauthorized", message: "Token yok." } };
    const cagrilar = stubFetch(() => ({ status: 401, body: zarf }));

    const res = await proxyJson("/units", "GET");
    expect(res.status).toBe(401);
    expect(await res.json()).toEqual(zarf);
    expect(cagrilar).toHaveLength(1);
    expect(cagrilar[0][0]).not.toContain("/auth/refresh");
    // Zaten oturum yok; ekstra cookie silme yapilmaz.
    expect(cookieOf(res, ACCESS_COOKIE)).toBeUndefined();
  });

  it("refresh OK ama tekrar da 401: 401 gecer, YENI cift yine yazilir " +
      "(eski rt tuketildi)", async () => {
    kavanoz.degerler[ACCESS_COOKIE] = "eski-at";
    kavanoz.degerler[REFRESH_COOKIE] = "eski-rt";
    stubFetch((url) =>
      url.endsWith("/auth/refresh")
        ? { status: 200, body: OK_CIFT }
        : { status: 401, body: { error: { message: "yetki yok" } } },
    );

    const res = await proxyJson("/admin/overview", "GET");
    expect(res.status).toBe(401);
    expect(cookieOf(res, ACCESS_COOKIE)?.value).toBe("yeni-at");
  });

  it("403 REFRESH TETIKLEMEZ (yetki sorunu, oturum sorunu degil)", async () => {
    kavanoz.degerler[ACCESS_COOKIE] = "at";
    kavanoz.degerler[REFRESH_COOKIE] = "rt";
    const cagrilar = stubFetch(() => ({ status: 403, body: { error: { message: "forbidden" } } }));

    const res = await proxyJson("/admin/overview", "GET");
    expect(res.status).toBe(403);
    expect(cagrilar).toHaveLength(1);
  });
});

describe("proxyJson — TEK-UCUS (single-flight) refresh", () => {
  it("ARDISIK 401'de eski jetonla IKINCI refresh DENENMEZ", async () => {
    // =====================================================================
    // OLCULEN OLAY (P174)
    // =====================================================================
    // Sayfa acilisinda dort istek paralel gidiyor ve erisim jetonu dolmus:
    //
    //   GET /tenant/settings 401 · GET /me/profile 401 · GET /kurulum 401
    //   GET /notifications 401 · POST /auth/refresh 200 · ...hepsi 200
    //
    // Istekler AYNI ANDA degil, ARDISIK olarak 401 aliyor. Mevcut
    // `refreshSingleFlight` girdisini `finally` icinde — yani yenileme
    // BITER BITMEZ — siliyordu. Yenileme cozuldukten SONRA 401 alan istek
    // haritada bir sey bulamiyor ve ESKI (artik DONDURULMUS) jetonla
    // IKINCI bir yenileme baslatiyordu.
    //
    // Backend rotation + reuse-revoke uyguluyor: o ikinci cagri REDDEDILIR
    // ve `pair` null olur -> vekil 401 dondurur VE OTURUM CEREZLERINI
    // SILER. Yani az once yenilenmis, GECERLI bir oturumu yok eder.
    //
    // Belirti tam da bildirilen sey: "bazi bilesenler ilk 401'i yukleme
    // hatasi olarak gosteriyor ve toparlanmiyor".
    kavanoz.degerler[ACCESS_COOKIE] = "eski-at";
    kavanoz.degerler[REFRESH_COOKIE] = "paylasilan-rt";

    let refreshSayisi = 0;
    const cagrilar = stubFetch(async (url, init) => {
      if (url.endsWith("/auth/refresh")) {
        refreshSayisi++;
        const govde = JSON.parse(String(init.body)) as { refresh_token: string };
        // ROTATION + REUSE-REVOKE: eski jeton bir kez kullanilir; ikinci
        // kullanim REDDEDILIR (gercek backend davranisi).
        if (govde.refresh_token !== "paylasilan-rt" || refreshSayisi > 1) {
          return { status: 401, body: { error: { code: "unauthorized" } } };
        }
        return { status: 200, body: OK_CIFT };
      }
      const yetki = (init.headers as Record<string, string>).Authorization;
      return yetki === "Bearer eski-at"
        ? { status: 401, body: null }
        : { status: 200, body: { ok: true } };
    });

    // 1) Ilk istek: 401 -> yenile -> tekrar dene -> 200.
    const r1 = await proxyJson("/tenant/settings", "GET");
    expect(r1.status).toBe(200);

    // 2) IKINCI istek yenilemeden SONRA basliyor ve hâlâ ESKI cerezi
    //    okuyor — tarayici `Set-Cookie`yi henuz almadi. Gercek sayfa
    //    acilisinda olan tam olarak budur.
    const r2 = await proxyJson("/kurulum", "GET");

    expect(r2.status, "ikinci istek 401 aldi — oturum bosuna dusuruldu").toBe(200);
    // ESKI JETONLA IKINCI YENILEME DENENMEMELI: denenseydi backend bunu
    // "reuse" sayar ve oturumun TAMAMINI iptal ederdi.
    expect(refreshSayisi, "eski jetonla ikinci refresh denendi").toBe(1);
    expect(
      cagrilar.filter((c) => c[0].endsWith("/auth/refresh")),
    ).toHaveLength(1);
    // Ve cerezler SILINMEMELI.
    expect(cookieOf(r2, ACCESS_COOKIE)?.value).not.toBe("");
  });


  it("es zamanli iki 401 icin /auth/refresh YALNIZ BIR KEZ cagrilir", async () => {
    kavanoz.degerler[ACCESS_COOKIE] = "eski-at";
    // (P174) JETON TESTE OZEL. Yenilenmis cift, ESKI jetonun anahtariyla
    // 30 sn saklaniyor (bkz. `lib/backend.ts` sonuc penceresi). Ayni
    // dizgeyi iki testte kullanmak, ikincisinin onbellekten donmesi ve
    // `fetch`e HIC gitmemesi demekti — olculdu. Gercek jetonlar zaten
    // benzersiz; ayni dizge testin sadelestirmesiydi.
    kavanoz.degerler[REFRESH_COOKIE] = "rt-eszamanli";

    let refreshSayisi = 0;
    let salivver!: () => void;
    const bekle = new Promise<void>((r) => {
      salivver = r;
    });

    const cagrilar = stubFetch(async (url, init) => {
      if (url.endsWith("/auth/refresh")) {
        refreshSayisi++;
        await bekle; // iki istek de refresh'i BEKLERKEN yakalanmali
        return { status: 200, body: OK_CIFT };
      }
      const yetki = (init.headers as Record<string, string>).Authorization;
      return yetki === "Bearer eski-at"
        ? { status: 401, body: null }
        : { status: 200, body: { ok: true } };
    });

    const p1 = proxyJson("/units", "GET");
    const p2 = proxyJson("/users", "GET");
    // Iki istek de ilk 401'i alip refresh'e ULASANA kadar bekle. Sabit bir
    // gecikme (setTimeout) yavas makinede flake olur; kosula bakiyoruz.
    for (let i = 0; refreshSayisi === 0 && i < 1000; i++) {
      await Promise.resolve();
    }
    expect(refreshSayisi, "refresh hic baslamadi").toBe(1);
    salivver();
    const [r1, r2] = await Promise.all([p1, p2]);

    // ROTATION guvenligi: iki refresh cagrisi "reuse" sayilip oturumu iptal
    // ettirirdi. Tek cagri + iki yanitin ikisi de yeni cifti tasir.
    expect(refreshSayisi).toBe(1);
    expect(cagrilar.filter((c) => c[0].endsWith("/auth/refresh"))).toHaveLength(1);
    expect(r1.status).toBe(200);
    expect(r2.status).toBe(200);
    expect(cookieOf(r1, REFRESH_COOKIE)?.value).toBe("yeni-rt");
    expect(cookieOf(r2, REFRESH_COOKIE)?.value).toBe("yeni-rt");
  });

  it("SAYFA ACILISI DESENI: dort paralel + bir gecikmis istek, HATA YOK",
    async () => {
      // Bildirilen log deseninin BIREBIR karsiligi:
      //   GET /tenant/settings 401 · GET /me/profile 401 · GET /kurulum 401
      //   GET /notifications 401 · POST /auth/refresh 200 · ...hepsi 200
      //
      // Kullanicinin gormesi gereken sey: HICBIR SEY. Tek yenileme,
      // butun istekler otomatik tekrar, hicbir hata ekrani.
      kavanoz.degerler[ACCESS_COOKIE] = "eski-at";
      kavanoz.degerler[REFRESH_COOKIE] = "rt-sayfa-acilisi";

      let refreshSayisi = 0;
      stubFetch(async (url, init) => {
        if (url.endsWith("/auth/refresh")) {
          refreshSayisi++;
          const govde = JSON.parse(String(init.body)) as { refresh_token: string };
          // Rotation + reuse-revoke: eski jeton BIR KEZ.
          if (govde.refresh_token !== "rt-sayfa-acilisi" || refreshSayisi > 1) {
            return { status: 401, body: { error: { code: "unauthorized" } } };
          }
          return { status: 200, body: OK_CIFT };
        }
        return (init.headers as Record<string, string>).Authorization === "Bearer eski-at"
          ? { status: 401, body: null }
          : { status: 200, body: { ok: true } };
      });

      const yanitlar = await Promise.all([
        proxyJson("/tenant/settings", "GET"),
        proxyJson("/me/profile", "GET"),
        proxyJson("/kurulum", "GET"),
        proxyJson("/notifications", "GET"),
      ]);
      // GECIKMIS ISTEK: demet bittikten sonra, hâlâ ESKI cerezle.
      yanitlar.push(await proxyJson("/kurulum", "GET"));

      for (const [i, r] of yanitlar.entries()) {
        expect(r.status, `${i}. istek hata dondu`).toBe(200);
      }
      expect(refreshSayisi, "birden fazla yenileme yapildi").toBe(1);
      // Hepsi YENI cifti tasir; tarayici tek bir tutarli duruma yakinsar.
      for (const r of yanitlar) {
        expect(cookieOf(r, REFRESH_COOKIE)?.value).toBe("yeni-rt");
      }
    });

  it("SONUC PENCERESI DOLUNCA yeni bir 401 YENI refresh cagirir",
    async () => {
      // =====================================================================
      // (P174) BU TESTIN YONU DEGISTI — ESKI HALI KUSURU KILITLIYORDU
      // =====================================================================
      // Eski iddia "ucus bitince ayni jetonla YENI refresh cagirilir" idi
      // ve `toBe(2)` bekliyordu. Bu, tam olarak duzeltilen kusurdur:
      // dondurulmus bir jetonla ikinci yenileme, backend'de "reuse"
      // sayilip OTURUMU IPTAL ETTIRIYORDU.
      //
      // Korunmasi gereken sey ise ayni: pencere SONSUZ OLMAMALI. Aksi
      // halde harita buyumeye devam eder ve cok eski bir jetona sonsuza
      // dek gecerli bir cift dagitilirdi. Yani iddia kaldirilmadi,
      // ZAMANA baglandi.
      vi.useFakeTimers();
      try {
        kavanoz.degerler[ACCESS_COOKIE] = "eski-at";
        kavanoz.degerler[REFRESH_COOKIE] = "rt-pencere";

        let refreshSayisi = 0;
        stubFetch((url, init) => {
          if (url.endsWith("/auth/refresh")) {
            refreshSayisi++;
            return { status: 200, body: OK_CIFT };
          }
          return (init.headers as Record<string, string>).Authorization === "Bearer eski-at"
            ? { status: 401, body: null }
            : { status: 200, body: {} };
        });

        await proxyJson("/units", "GET");
        // PENCERE ICINDE: yeni cagri YOK — yaris tam olarak burada kapaniyor.
        await proxyJson("/units", "GET");
        expect(refreshSayisi, "pencere icinde ikinci refresh denendi").toBe(1);

        // PENCERE DOLDUKTAN SONRA: yeniden denenir.
        vi.setSystemTime(Date.now() + 31_000);
        await proxyJson("/units", "GET");
        expect(refreshSayisi, "pencere dolunca yenileme yapilmadi").toBe(2);
      } finally {
        vi.useRealTimers();
      }
    });
});
