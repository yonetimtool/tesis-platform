// (P155 §8) MAGAZA BAGLANTILARI — davet web yedeginin "uygulamayi indir"
// dugmeleri.
//
// Play paketi BILINIYOR (`android/app/build.gradle.kts`), bu yuzden sabit.
// App Store numeric id'si Apple Developer/App Store Connect'ten alinir ve
// ORTAM DEGISKENINDEN gelir — bilinmeden sabit yazmak kirik bir baglanti
// birakirdi. Ayarlanmamissa iOS dugmesi CIZILMEZ (kirik yerine yok).
export const PLAY_URL =
  "https://play.google.com/store/apps/details?id=com.app.yonetiyor";

/** App Store numeric id (or. `1234567890`). `.env`de
 *  `NEXT_PUBLIC_APPLE_APP_ID` ile verilir; yoksa iOS dugmesi gizlenir. */
export const APPLE_APP_ID = process.env.NEXT_PUBLIC_APPLE_APP_ID ?? "";

export const APP_STORE_URL = APPLE_APP_ID
  ? `https://apps.apple.com/app/id${APPLE_APP_ID}`
  : "";

export type Platform = "ios" | "android" | "masaustu";

/** Kaba istemci platformu — hangi magaza dugmesi one cikacak. */
export function platformSez(ua: string): Platform {
  if (/iPhone|iPad|iPod/i.test(ua)) return "ios";
  if (/Android/i.test(ua)) return "android";
  return "masaustu";
}
