// BFF cekirdegi: backend'e (FastAPI) sunucu tarafindan proxy.
// Token'lar httpOnly cookie'de; istemci ASLA gormez. 401'de TEK-UCUS (single-flight)
// refresh: backend refresh rotation yaptigi icin es zamanli yenilemeler tek cagrida
// birlestirilir (reuse-revoke onlenir).

import { cookies } from "next/headers";
import { NextResponse } from "next/server";

import { API_KAPALI_KODU } from "./backend-kodlari";
import { API_BASE } from "./config";
import { DIL_COOKIE, istekDili, type Dil } from "./i18n/diller";
import { SOZLUKLER } from "./i18n/sozluk";
import {
  ACCESS_COOKIE,
  ACCESS_MAX_AGE,
  REFRESH_COOKIE,
  REFRESH_MAX_AGE,
  cookieOptions,
} from "./cookies";

interface TokenPair {
  access: string;
  refresh: string;
}

function setAuthCookies(res: NextResponse, access: string, refresh: string): void {
  res.cookies.set(ACCESS_COOKIE, access, cookieOptions(ACCESS_MAX_AGE));
  res.cookies.set(REFRESH_COOKIE, refresh, cookieOptions(REFRESH_MAX_AGE));
}

function clearAuthCookies(res: NextResponse): void {
  res.cookies.delete(ACCESS_COOKIE);
  res.cookies.delete(REFRESH_COOKIE);
}

/// BFF'in ileteceği dil: kullanicinin cookie secimi, yoksa tarayici dili.
/// `cookies()` yalniz istek baglaminda calisir — bu dosya zaten route
/// handler'lardan cagrilir.
async function panelDili(): Promise<Dil> {
  try {
    const c = await cookies();
    return istekDili(c.get(DIL_COOKIE)?.value);
  } catch {
    // Istek baglami yoksa (beklenmez) varsayilan dil.
    return "tr";
  }
}

async function callBackend(
  path: string,
  method: string,
  accessToken: string | undefined,
  body?: unknown,
  extraHeaders?: Record<string, string>,
): Promise<Response> {
  // Sunucu hata metinleri (tur 14) ve icerik cevirisi `Accept-Language`e
  // gore servis edilir. Panel artik 7 dilli (tur 17): baslik KULLANICININ
  // sectigi dilden gelir, sabit `tr` degil. Zincir `dil, tr;q=0.8`:
  // sunucuda cevirisi eksik bir metin Turkce'ye duser, bos kalmaz.
  const dil = await panelDili();
  const headers: Record<string, string> = {
    "Accept-Language": dil === "tr" ? "tr" : `${dil}, tr;q=0.8`,
    ...(extraHeaders ?? {}),
  };
  if (accessToken) headers["Authorization"] = `Bearer ${accessToken}`;
  if (body !== undefined) headers["Content-Type"] = "application/json";
  try {
    return await fetch(`${API_BASE}${path}`, {
      method,
      headers,
      body: body !== undefined ? JSON.stringify(body) : undefined,
      cache: "no-store",
    });
  } catch {
    // (P171 duzeltme) API'YE ULASILAMIYOR — TEK YERDE, TANIMLI BIR YANIT.
    //
    // `fetch` baglanti kurulamayinca ATAR (ECONNREFUSED/DNS). Onceden bu
    // istisna route handler'a kadar cikiyor ve Next 500 uretiyordu:
    // her sayfa kendi hatasini kendi metniyle gosteriyor, kullanici
    // "bir hata olustu" goruyordu — sunucunun KAPALI oldugunu degil.
    //
    // Burada yakalamak MERKEZILIGIN kendisidir: `proxyJson`, `proxyBinary`
    // ve tazeleme yolu HEPSI buradan geciyor, yani panelin tamami ayni
    // kodu doner ve istemci tarafi TEK bir durum ekrani cizebilir.
    //
    // 503: gecici bir hizmet yoklugu. 500 "bizde bir kusur var" der ve
    // kullaniciya tekrar denemenin ise yarayacagini SOYLEMEZ.
    return apiKapaliYaniti(dil);
  }
}

/** API'ye ulasilamadiginda uretilen SENTETIK yanit — tek bicim. */
function apiKapaliYaniti(dil: Dil): Response {
  return new Response(
    JSON.stringify({
      error: {
        code: API_KAPALI_KODU,
        message: SOZLUKLER[dil].ortakSunucuyaUlasilamadi,
      },
    }),
    { status: 503, headers: { "Content-Type": "application/json" } },
  );
}

// --- single-flight refresh ------------------------------------------------- #
const inflight = new Map<string, Promise<TokenPair | null>>();

function refreshSingleFlight(rt: string): Promise<TokenPair | null> {
  const existing = inflight.get(rt);
  if (existing) return existing;
  const p = (async (): Promise<TokenPair | null> => {
    try {
      const res = await fetch(`${API_BASE}/auth/refresh`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refresh_token: rt }),
        cache: "no-store",
      });
      if (!res.ok) return null;
      const d = (await res.json()) as { access_token: string; refresh_token: string };
      return { access: d.access_token, refresh: d.refresh_token };
    } catch {
      return null;
    } finally {
      inflight.delete(rt);
    }
  })();
  inflight.set(rt, p);
  return p;
}

/** Backend'e dogrudan login (cookie set etmeyi cagiran route handler yapar). */
export async function backendLogin(body: {
  tenant_slug: string;
  email: string;
  password: string;
}): Promise<{ ok: boolean; status: number; data: unknown }> {
  const res = await callBackend("/auth/login", "POST", undefined, body);
  const data = await res.json().catch(() => null);
  return { ok: res.ok, status: res.status, data };
}

/**
 * TELEFONLA giris (mobil ile AYNI uc: `POST /auth/login-phone`).
 *
 * Tenant kodu YOKTUR ve olmamalidir: telefon GLOBAL benzersizdir, sunucu
 * tenant'i numaradan cozer (`tenant_id_by_phone`). Web'de tesis kodu sormak,
 * mobilde sorulmayan bir bilgiyi ayni kullaniciya web'de sormak olurdu.
 */
export async function backendPhoneLogin(body: {
  phone: string;
  password: string;
}): Promise<{ ok: boolean; status: number; data: unknown }> {
  const res = await callBackend("/auth/login-phone", "POST", undefined, body);
  const data = await res.json().catch(() => null);
  return { ok: res.ok, status: res.status, data };
}

/**
 * (P154 / Asama 3) KIMLIK ONCESI vekil — oturum cerezi TASIMAZ.
 *
 * NEDEN `proxyJson` DEGIL: o, `ACCESS_COOKIE`/`REFRESH_COOKIE` okur ve
 * gerektiginde jeton yeniler. Rol secimli kayitta kullanicinin HENUZ
 * OTURUMU YOKTUR; oraya cerez mantigini sokmak, kaydolmaya calisan birinin
 * baskasinin (ayni tarayicidaki) oturumuyla islem yapmasina acilan bir
 * yol olurdu. Bu vekil yalniz govdeyi tasir.
 *
 * Yanit AYNEN gecer: sunucunun "adimlari ayirt ETTIRMEYEN" metni burada
 * yeniden yazilmamali.
 */
export async function anonimVekil(
  path: string,
  body: unknown,
): Promise<NextResponse> {
  const res = await callBackend(path, "POST", undefined, body);
  const data = await res.json().catch(() => null);
  return NextResponse.json(data, { status: res.status });
}

/**
 * (P154 / Asama 4) KIMLIK ONCESI GET — `anonimVekil`in okuma ikizi.
 *
 * `proxyJson` KULLANILMADI: o cerez okur ve gerekirse jeton yeniler.
 * Giris ekraninda cagrilan bir uc icin cerez mantigi yalniz gereksiz
 * degil, `anonimVekil`in belgeledigi sinifta bir risk (baskasinin ayni
 * tarayicidaki oturumu).
 */
export async function anonimGet(path: string): Promise<NextResponse> {
  const res = await callBackend(path, "GET", undefined);
  const data = await res.json().catch(() => null);
  return NextResponse.json(data, { status: res.status });
}

/**
 * Oturum cerezlerini yazan yanit.
 *
 * (P155r2) `ek` OPSIYONEL ve yalniz JETON OLMAYAN alanlar icindir —
 * `/auth/kayit/tesis-olustur` uretilen TESIS KODUNU dondurmek zorunda
 * (yonetici onu sakinlerine iletecek). Jetonlar HER ZAMAN cerezde kalir;
 * `ek`e jeton koymak, onlari JS'e gorunur kilmak olurdu ve bu fonksiyonun
 * varlik sebebini bozardi.
 */
export function loginResponse(
  access: string,
  refresh: string,
  ek?: Record<string, unknown>,
): NextResponse {
  const res = NextResponse.json({ ok: true, ...ek });
  setAuthCookies(res, access, refresh);
  return res;
}

/**
 * (P172 §5) KIMLIK ONCESI GIRIS CAGRISI — cerez TASIMAZ, gerekirse KURAR.
 *
 * `proxyJson` DEGIL: o, oturum cerezlerini okur ve 401'de jeton yeniler.
 * Kullanicinin henuz oturumu yokken ikisi de anlamsiz, ustelik bayat bir
 * cerez varsa yanlis kimlikle istek gonderilirdi.
 *
 * `jetonBekle` true ise basarili yanittaki jetonlar httpOnly cereze
 * yazilir ve govdeye KONMAZ — parolali giris yolunun ayni kurali.
 */
export async function backendGiris(
  yol: string,
  govde: unknown,
  jetonBekle: boolean,
): Promise<NextResponse> {
  const res = await callBackend(yol, "POST", undefined, govde);
  const data = await res.json().catch(() => null);
  if (!res.ok || !jetonBekle) {
    return NextResponse.json(data, { status: res.status });
  }
  const t = data as { access_token?: string; refresh_token?: string } | null;
  if (!t?.access_token || !t?.refresh_token) {
    // Sunucu 200 dedi ama jeton yok: sessizce "giris oldu" saymak,
    // kullaniciyi oturumsuz bir panele sokmak olurdu.
    return NextResponse.json(
      { error: { code: "error", message: SOZLUKLER[await panelDili()].girisBasarisiz } },
      { status: 502 },
    );
  }
  return loginResponse(t.access_token, t.refresh_token);
}

export function logoutResponse(): NextResponse {
  const res = NextResponse.json({ ok: true });
  clearAuthCookies(res);
  return res;
}

/**
 * Korumali bir backend cagrisini proxy'le: access cookie ile dene; 401 ise
 * refresh (single-flight) + cookie rotasyonu + bir kez tekrar. refresh olunce
 * 401 + cookie temizle (istemci login'e doner).
 */
async function passthrough(res: Response): Promise<NextResponse> {
  // 204 / bos govde (orn. DELETE) -> govdesiz yanit.
  if (res.status === 204 || res.headers.get("content-length") === "0") {
    return new NextResponse(null, { status: res.status });
  }
  const data = await res.json().catch(() => null);
  return NextResponse.json(data, { status: res.status });
}

export async function proxyJson(
  path: string,
  method: string,
  body?: unknown,
  extraHeaders?: Record<string, string>,
): Promise<NextResponse> {
  const jar = cookies();
  const access = jar.get(ACCESS_COOKIE)?.value;
  const refresh = jar.get(REFRESH_COOKIE)?.value;

  let res = await callBackend(path, method, access, body, extraHeaders);

  if (res.status === 401 && refresh) {
    const pair = await refreshSingleFlight(refresh);
    if (!pair) {
      // Bu metin BFF'in KENDI urettigi hatadir (backend'e hic gitmedi),
      // dolayisiyla tur 14'un sunucu katalogu devrede degil — panel
      // sozlugunden, kullanicinin dilinde uretilir.
      const out = NextResponse.json(
        {
          error: {
            code: "unauthorized",
            message: SOZLUKLER[await panelDili()].ortakOturumSuresiDoldu,
          },
        },
        { status: 401 },
      );
      clearAuthCookies(out);
      return out;
    }
    res = await callBackend(path, method, pair.access, body, extraHeaders);
    const out = await passthrough(res);
    setAuthCookies(out, pair.access, pair.refresh);
    return out;
  }

  return passthrough(res);
}


/**
 * (P40) IKILI (binary) vekil — Excel/PDF indirmeleri icin.
 *
 * NEDEN AYRI: `proxyJson` yaniti `res.json()` ile okur ve XLSX/PDF
 * baytlarini JSON diye ayristirmaya calisip BOZARDI. Burada govde
 * `arrayBuffer` olarak gecer ve `Content-Type` / `Content-Disposition`
 * OLDUGU GIBI aktarilir — dosya adini panelde yeniden uydurmak, sunucunun
 * urettigi addan sapmak olurdu.
 *
 * 401 yolu `proxyJson` ile AYNIDIR (tek-ucus refresh); iki ayri yenileme
 * mantigi, birinde duzeltilen bir hatanin digerinde kalmasi demekti — bu
 * yuzden ayni `refreshSingleFlight` kullanilir.
 */
export async function proxyBinary(
  path: string,
  method: string,
  body?: unknown,
): Promise<NextResponse> {
  const jar = cookies();
  const access = jar.get(ACCESS_COOKIE)?.value;
  const refresh = jar.get(REFRESH_COOKIE)?.value;

  let res = await callBackend(path, method, access, body);
  let yeniPair: TokenPair | null = null;

  if (res.status === 401 && refresh) {
    yeniPair = await refreshSingleFlight(refresh);
    if (!yeniPair) {
      const out = NextResponse.json(
        {
          error: {
            code: "unauthorized",
            message: SOZLUKLER[await panelDili()].ortakOturumSuresiDoldu,
          },
        },
        { status: 401 },
      );
      clearAuthCookies(out);
      return out;
    }
    res = await callBackend(path, method, yeniPair.access, body);
  }

  // HATA GOVDESI JSON'DUR: ikili yol yalniz BASARIDA bayt tasir; hatayi
  // bayt olarak gecirmek, panelde "bozuk dosya" gostermek olurdu.
  if (!res.ok) {
    const data = await res.json().catch(() => null);
    const out = NextResponse.json(data, { status: res.status });
    if (yeniPair) setAuthCookies(out, yeniPair.access, yeniPair.refresh);
    return out;
  }

  const buf = await res.arrayBuffer();
  const out = new NextResponse(buf, {
    status: res.status,
    headers: {
      "Content-Type": res.headers.get("content-type") ?? "application/octet-stream",
      "Content-Disposition":
        res.headers.get("content-disposition") ?? "attachment",
    },
  });
  if (yeniPair) setAuthCookies(out, yeniPair.access, yeniPair.refresh);
  return out;
}
