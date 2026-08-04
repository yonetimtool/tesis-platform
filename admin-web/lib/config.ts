// Backend base URL. YALNIZ BFF (Next sunucu tarafi) kullanir; /v0 oneki YOK.
// Oncelik: API_BASE_URL (calisma-zamani, sunucu-ozel; prod'da ic ag:
// http://api:8000) > NEXT_PUBLIC_API_BASE_URL (dev/derleme-zamani) > localhost.
// API_BASE hicbir istemci ("use client") modulune girmez; bu yuzden public-olmayan
// bir env var calisma zamaninda okunabilir ve imaj yeniden derlenmeden degistirilir.
export const API_BASE =
  process.env.API_BASE_URL ??
  process.env.NEXT_PUBLIC_API_BASE_URL ??
  "http://localhost:8000";

// (P129) MAGAZA BAGLANTILARI — YAPILANDIRMADAN, UYDURMADAN.
//
// `app.*` yalniz yonetici + denetci yuzeyidir; sakin ve saha personeli
// mobil uygulamaya yonlendirilir. Yonlendirirken bir BAGLANTI vermek
// dogru olur — ama uygulama HENUZ YAYINDA DEGIL (P118 Mac derlemesinde
// bekliyor). Play adresini `applicationId`den turetip yazmak (bugun
// 404 veren bir baglanti) ya da App Store icin sayisal kimlik UYDURMAK,
// kullaniciya bozuk bir soz vermek olurdu.
//
// Bu yuzden: baglantilar ORTAM DEGISKENINDEN gelir ve YALNIZ tanimliysa
// gosterilir. Yayina cikildiginda tek yapilacak sey bu ikisini
// tanimlamaktir — kod degisikligi YOK.
//
// `API_BASE` gibi calisma-zamani (public olmayan) degisken KULLANILAMAZ:
// bu degerler istemciye cizilen bir bilesende gerekiyor.
export const MAGAZA_ANDROID = process.env.NEXT_PUBLIC_PLAY_URL ?? null;
export const MAGAZA_IOS = process.env.NEXT_PUBLIC_APPSTORE_URL ?? null;
