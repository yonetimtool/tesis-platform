# /admin-web — Yonetim Paneli (Next.js)

Multi-tenant tesis operasyon SaaS yonetim paneli. **Next.js 14 (App Router) + TypeScript +
Tailwind**. Backend'e (FastAPI, `/contracts/openapi.yaml`) **BFF** deseniyle baglanir:
token'lar **httpOnly cookie**'de tutulur, istemci JS'i ASLA gormez.

> **Panel yalnizca `admin` (platform admini) icindir** (`contracts/auth.md` §4).
> Login'de BFF, access token'daki `role` claim'ine bakar; `admin` degilse
> **403** doner ve oturum cookie'si set edilmez — `yonetici` (site yoneticisi)
> dahil diger tum roller mobil uygulamayi kullanir. Bu UX kapisidir; gercek
> yetki her istekte backend RBAC'ta zorlanir.

## Kurulum

```bash
cd admin-web
cp .env.example .env.local      # gerekirse API adresini degistir
npm install
npm run dev                     # http://localhost:3000
# uretim derlemesi:
npm run build && npm run start
```

## Ortam degiskenleri

| Degisken | Aciklama | Varsayilan |
|----------|----------|------------|
| `NEXT_PUBLIC_API_BASE_URL` | Backend API koku (`/v0` ONEKI YOK) | `http://localhost:8000` |

- **Dev:** backend `http://localhost:8000` (asagidaki "Backend'i calistirma").
- **Prod:** `https://api.example.com` gibi gercek domain; panel ayni origin veya CORS'suz
  cunku istemci backend'e **dogrudan gitmez** — hep same-origin `/api/*` (BFF) cagrilir.

## Backend'i calistirma (panel bagimliligi)

Panel calisan bir backend ister. Repo kokunden:
```bash
cd infra && docker compose up -d --build
docker compose exec api python -m scripts.seed
```
Backend `http://localhost:8000`'de ayaga kalkar (194 test gecer). `/health` 200 doner.

## Test giris bilgisi (seed)

| Alan | Deger |
|------|-------|
| Tesis (slug) | `acme-plaza` |
| E-posta | `admin@acme.com` |
| Parola | `Admin123!` |

> Seed'deki diger hesaplar (`yonetici@acme.com`, `guard@acme.com`,
> `cleaner@acme.com`, `resident@acme.com`) panele GIREMEZ (403) — rol modeli
> geregi mobil hesaplaridir.

> Login formu `tenant_slug + email + password` alir (`/contracts` `LoginRequest`'e birebir).

## Mimari

```
app/
  login/page.tsx              giris formu (-> /api/auth/login)
  page.tsx                    "/" -> /dashboard
  (protected)/
    layout.tsx                Nav + duzen (oturum middleware'de korunur)
    dashboard/page.tsx        GET /dashboard/live (SWR, 15 sn polling)
    notifications/page.tsx    GET /notifications (filtre + sayfalama + okundu)
    announcements/page.tsx    duyurular (olustur/duzenle/sil; tum cihazlara push)
  api/                        BFF route handler'lari (backend'e proxy)
    auth/login, auth/logout
    dashboard/live
    notifications, notifications/[id]
lib/
  backend.ts                  proxyJson: access cookie + 401'de single-flight refresh + cookie rotasyonu
  cookies.ts                  httpOnly cookie isim/secenekleri
  fetcher.ts                  istemci SWR fetcher (401 -> /login)
  types.ts                    /contracts sema TS karsiliklari
middleware.ts                 korumali route'lar: oturum yoksa /login
components/Nav.tsx            ust menu + cikis
```

### Token guvenligi (neden httpOnly cookie + BFF)
- access/refresh **httpOnly + SameSite=Lax + (prod) Secure** cookie'de; XSS ile calinamaz.
- Istemci backend'i **dogrudan cagirmaz**; same-origin `/api/*` route handler'lari proxy'ler
  ve cookie'deki token'i Authorization header'ina koyar.
- **401 -> refresh:** `proxyJson` access 401 alinca `POST /auth/refresh` ile yeniler ve yeni
  cookie cifti yazar. Backend refresh **rotation** yaptigi icin es zamanli istekler
  **single-flight** ile tek yenilemeye indirgenir (reuse-revoke onlenir).
- refresh de olunce cookie'ler temizlenir, 401 doner; istemci/middleware `/login`'e yonlendirir.
- Korumali sayfalar: `middleware.ts` oturum (refresh cookie) yoksa `/login`'e ceker.

## Sayfalar

- **Canli Panel** (`/dashboard`): bugunku turlar (bekliyor/tamamlandi/kacirildi rozetli) +
  okutulan/beklenen sayilari + son alarmlar (acil durum kirmizi ve en ustte — backend siralar).
  15 sn'de bir otomatik yenilenir.
- **Bildirimler** (`/notifications`): liste, okundu/okunmamis filtresi, sayfalama (limit/offset),
  `PATCH /notifications/{id}` ile okundu isaretleme.

## Notlar
- Backend ve sozlesme **degistirilmedi** (yalniz `/admin-web`).
- `npm run build` TypeScript + ESLint (`next/core-web-vitals`) kontrolunu calistirir.

## Güvenlik notu (bağımlılıklar)

- Next.js `14.2.5` → **`14.2.35`** yükseltildi (kritik güvenlik yamaları; App Router uyumlu, build sorunsuz).
- `npm audit` kalan uyarıları (Next/glob/minimatch/postcss) yalnızca **Next 16 / eslint-config-next 16 major** yükseltmesiyle kapanıyor (`npm audit fix --force`) — bu kırıcı bir değişiklik olduğundan **şimdilik uygulanmadı.**
- Kalan uyarıların çoğu ya **dev-only** araçlarda (eslint/glob/minimatch — production bundle'a girmez) ya da **kullanılmayan Next özelliklerinde** (next/image Optimizer, Pages Router i18n, beforeInteractive — panel bunları kullanmıyor; App Router + BFF deseni).
- Production öncesi plan: Next 15/16'ya kontrollü major geçiş ayrı bir görev olarak ele alınacak.
