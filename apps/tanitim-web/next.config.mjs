/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Prod Docker imaji icin minimal standalone server — admin-web ile AYNI
  // desen. Ayrisma yapilmadi: iki Next uygulamasinin ayni depoda farkli
  // cikti kipiyle derlenmesi, Dockerfile'lari da ayristirirdi.
  output: "standalone",
  // Gorsel optimizasyonu KAPALI: `sharp` standalone imaja ~30 MB platform
  // binary'si ekler ve bu sitedeki tum gorseller SABIT marka varliklaridir
  // (logo + magaza rozetleri). admin-web'de de ayni karar verildi.
  images: { unoptimized: true },
};

export default nextConfig;
