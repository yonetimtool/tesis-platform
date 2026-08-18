/**
 * (P171 duzeltme) BFF'in URETTIGI HATA KODLARI — istemci/sunucu ORTAK.
 *
 * NEDEN AYRI DOSYA: `lib/backend.ts` `next/headers` ithal eder ve YALNIZ
 * sunucuda calisir. Kodu oradan almak, istemci paketine sunucu-yalniz bir
 * modul sokardi (Next derlemede patlar).
 *
 * Kod bir SOZLESMEDIR: metin yedi dilde degisir, kod degismez. Merkezi
 * durum ekrani metne degil buna bakar.
 */
export const API_KAPALI_KODU = "sunucuya_ulasilamiyor";
