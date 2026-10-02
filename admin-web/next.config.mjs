// (P250 §4) ICERIK GUVENLIK POLITIKASI (CSP).
//
// Panel bugune kadar HIC CSP tasimiyordu (yalniz Caddy'nin X-Frame-Options
// ve nosniff basliklari). Egitim videolari YouTube IFrame API'si getirdi;
// kural "yalniz gereken YouTube alanlarina izin ver, genel izin acma":
//   * script-src : kendi kaynak + Next'in satir-ici acilis betikleri +
//                  YALNIZ `https://www.youtube.com` (iframe_api ve onun
//                  yukledigi www-widgetapi). Gelistirmede `unsafe-eval`
//                  (React yenileme) eklenir; uretimde YOK.
//   * frame-src  : kendi kaynak + `https://www.youtube-nocookie.com`
//                  (oynatici) + mevcut harita gomuleri (`SiteHarita`:
//                  google.com/maps/embed ya da openstreetmap.org).
//   * worker-src : `blob:` — hls.js canli kamera akisini blob URL'li bir
//                  isciyle cozer; script-src kisitlaninca isci de ona
//                  dusuyordu.
//   * object-src 'none', base-uri 'self', frame-ancestors 'none'.
// img/connect/style/font BILEREK kisitlanmadi: MinIO imzali gorselleri,
// API ve yazi tipleri ortama gore degisen alan adlarindan gelir; onlari
// burada sabitlemek ortam basina kirilma demekti. Kilit:
// tests/p250-csp.test.ts (joker yok, YouTube yalniz iki alan adi).
const GELISTIRME = process.env.NODE_ENV !== "production";
export const ICERIK_POLITIKASI = [
  `script-src 'self' 'unsafe-inline'${GELISTIRME ? " 'unsafe-eval'" : ""} https://www.youtube.com`,
  "frame-src 'self' https://www.youtube-nocookie.com https://www.google.com https://www.openstreetmap.org",
  "worker-src 'self' blob:",
  "object-src 'none'",
  "base-uri 'self'",
  "frame-ancestors 'none'",
].join("; ");

/** @type {import('next').NextConfig} */
const nextConfig = {
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [{ key: "Content-Security-Policy", value: ICERIK_POLITIKASI }],
      },
    ];
  },
  reactStrictMode: true,
  // Prod Docker imaji icin minimal standalone server (.next/standalone).
  // Yalniz `next build` ciktisini etkiler; `next dev` degismez.
  output: "standalone",
  // Gorsel optimizasyonu BILEREK kapali (standalone'da sharp uyarisinin
  // kalici cozumu). Panelde next/image YALNIZ statik marka logosunda
  // kullanilir (YonetioLogo + login — public/yonetio-master.png, sabit
  // boyut); foto/thumbnail akisi (sikayet/duyuru) presigned MinIO URL'li
  // DUZ <img>'dir ve optimizasyondan zaten gecmez. sharp eklemek imaja
  // ~30MB platform binary'si + standalone copy karmasasi getirirdi;
  // kazanc sifira yakin oldugundan Option B secildi.
  images: { unoptimized: true },
  // (E2E 2026-09) DOGRULAMA DERLEMESI AYRI DIZINE. `npm run dogrula`
  // icindeki `next build` varsayilan `.next`e yaziyordu — ayni dizini
  // kullanan CALISAN `next dev` sunucusunun istemci dosyalari (main-app.js
  // vb.) 404 vermeye basladi ve sayfalar gunlerce hidrasyonsuz cizildi.
  // Prod imaji (Dockerfile) degiskeni vermez: yine `.next` kullanilir.
  distDir: process.env.NEXT_DIST_DIR || ".next",
};

export default nextConfig;
