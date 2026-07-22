// Backend base URL. YALNIZ BFF (Next sunucu tarafi) kullanir; /v0 oneki YOK.
// Oncelik: API_BASE_URL (calisma-zamani, sunucu-ozel; prod'da ic ag:
// http://api:8000) > NEXT_PUBLIC_API_BASE_URL (dev/derleme-zamani) > localhost.
// API_BASE hicbir istemci ("use client") modulune girmez; bu yuzden public-olmayan
// bir env var calisma zamaninda okunabilir ve imaj yeniden derlenmeden degistirilir.
export const API_BASE =
  process.env.API_BASE_URL ??
  process.env.NEXT_PUBLIC_API_BASE_URL ??
  "http://localhost:8000";
