/** @type {import('next').NextConfig} */
const nextConfig = {
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
};

export default nextConfig;
