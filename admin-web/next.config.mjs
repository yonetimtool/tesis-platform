/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Prod Docker imaji icin minimal standalone server (.next/standalone).
  // Yalniz `next build` ciktisini etkiler; `next dev` degismez.
  output: "standalone",
};

export default nextConfig;
