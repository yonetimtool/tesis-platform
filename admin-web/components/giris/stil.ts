/**
 * (P162) GIRIS EKRANI CSS DEGER KURUCULARI.
 *
 * =========================================================================
 * NEDEN AYRI DOSYA
 * =========================================================================
 * Iki gerekce, ikisi de somut:
 *
 * 1. DEPO KURALI. `tests/i18n.test.ts` (P69) `.tsx` dosyalarindaki sablon
 *    dizgelerinde bosluklu metin arar — cunku P68'de bir baslik sablon
 *    dizgesi icine gomulup ceviriden kacmisti. Kural dogru; ama bir
 *    `radial-gradient(...)` ifadesi de o kaliba uyuyor. Kurali gevsetmek
 *    yerine CSS KURMA ISINI JSX'TEN CIKARDIM: zaten cizim degil, deger
 *    hesabidir.
 *
 * 2. OKUNURLUK. Bes katmanli bir sahnede gradyan ve donusum ifadeleri
 *    JSX'in icinde satir satir dagilinca hangi katmanin ne kadar kaydigi
 *    gorunmez oluyordu. Burada hepsi yan yana.
 */
import { CYAN_YUMUSAK, NAVY_DIP, NAVY_ORTA, NAVY_YAKIN, TURKUAZ, TURKUAZ_KOYU } from "./palet";

/** Sahnenin ana zemini — uzaktan yakina deep navy. */
export const ZEMIN_GRADYANI = `radial-gradient(120% 90% at 30% 20%, ${NAVY_YAKIN} 0%, ${NAVY_ORTA} 45%, ${NAVY_DIP} 100%)`;

/**
 * ORTAM ISIKLARI (sartname §10): sol ust cyan, sag arka turkuaz, orta
 * yumusak mavi. Opaklik hex son ekiyle veriliyor (`22` = %13) — ayri bir
 * `rgba()` cevirimi yazmaktansa paletteki hex'i oldugu gibi kullanmak
 * hem kisa hem de paletle birebir ayni degeri garanti ediyor.
 */
export const AURA_GRADYANI = [
  `radial-gradient(38% 42% at 12% 14%, ${TURKUAZ}22 0%, transparent 70%)`,
  `radial-gradient(46% 46% at 78% 72%, ${TURKUAZ_KOYU}1c 0%, transparent 72%)`,
  `radial-gradient(52% 40% at 55% 42%, #153B5933 0%, transparent 75%)`,
].join(",");

/**
 * ALT VINYET: form kartinin arkasini sakinlestirir. Sartname §44 —
 * "background hicbir zaman login formundan daha baskin olmamali".
 */
export const VINYET_GRADYANI = `radial-gradient(90% 70% at 72% 50%, ${NAVY_DIP}cc 0%, transparent 68%)`;

/** Dugum halesi (§6) — neon DEGIL, cok yumusak. */
export const HALE_GRADYANI = `radial-gradient(circle, ${CYAN_YUMUSAK}8c 0%, ${TURKUAZ}1f 45%, transparent 70%)`;

/** CTA gradyani (§16) — parlak DEGIL, kurumsal. */
export const CTA_GRADYANI = `linear-gradient(135deg, ${TURKUAZ_KOYU} 0%, ${TURKUAZ} 55%, #42D8CF 100%)`;

/**
 * Paralaks donusumu: katman katsayisina gore `--giris-px/py` okur.
 *
 * `translate3d` bilincli: `translate` yerine 3B bicimi kullanmak ogeyi
 * kendi bilesim katmanina alir ve her kare yeniden boyama yerine yalnizca
 * bilesim yapilir.
 */
export function paralaks(katsayi: number): string {
  return `translate3d(calc(var(--giris-px) * ${katsayi}px), calc(var(--giris-py) * ${katsayi}px), 0)`;
}
