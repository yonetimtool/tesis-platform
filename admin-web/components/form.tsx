"use client";

import type { ReactNode } from "react";
import { useT } from "@/lib/i18n/kullan";

// =========================================================================
// (P244 §10) BU MODUL KUCULDU — SILINMEDI.
// =========================================================================
// Olu ihraclar kaldirildi: `PageHeader` (yerini `ui/SayfaBasligi` aldi),
// `Field` (yerini `ui/AlanSarmal` aldi), `panelCls` ve `panelMotion`
// (hicbir kullanicisi kalmamisti).
//
// GERIYE KALAN: bes dosyanin kullandigi SINIF SABITLERI + `ErrorBox`.
// Besi de GIRIS/KAYIT yuzeyinde (`/kayit`, `/giris/oauth`,
// `/davet/[jeton]`, `Ekler`, `GirisYontemlerim`) — korumali alanin
// disinda, kendi duzen kurallari olan ekranlar.
//
// KENAR ve TEHLIKE renkleri token'a gecti. `bg-yuzey-card` /
// `text-metin-body` BILEREK DURUYOR: o aile mobil `home_tokens.dart`
// ile PARITEDE ve hangi yone gidilecegi kullanicinin karari
// (bkz. kararlar §10b.3). Sessizce cevirmek o karari arkadan dolanmak
// olurdu.
// =========================================================================
// Ortak form/dugme token'lari (Faz 1). Teal odak halkasi + yumusak golge/hover
// kaldirmasi. Ic sayfalar bu siniflari import ederek "bedava" cilalanir.
// (P132) ORTAK ILKELLER TASARIM SISTEMINE TASINDI — 47 sayfa bunlari
// kullaniyor. Sayfa sayfa gecmek yerine BURAYI degistirmek, ayni sonucu
// tek yerde ve gerileme riski olmadan verir ("tek yer, sayfa basina CSS
// degil" — P132 sart 1).
export const inputCls =
  "w-full rounded-lg border border-[color:var(--yz-border)] bg-yuzey-card px-3 py-2 text-sm text-metin-body outline-none transition focus:border-[color:var(--yz-accent)] focus:ring-2 focus:ring-[color:var(--yz-accent)]/25 disabled:opacity-60";
// Birincil dugme MAVI (mobil `HomeTokens.primary`). Beyaz metin
// #2563EB uzerinde 5.17:1 — AA (tests/tasarim-kontrast.test.ts).
// GOLGE KALDIRILDI: mobil kartlarda golge yoktur, dugmede de olmamali.
export const btnPrimary =
  "odak-ters inline-flex items-center justify-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-[#1d4fd8] active:translate-y-px disabled:opacity-60";
export const btnGhost =
  "kart-kenar rounded-lg border bg-yuzey-card px-3 py-1.5 text-sm text-metin-body transition hover:bg-yuzey-divider";
export const btnDanger =
  "rounded-lg border border-[color:var(--yz-danger-edge)] bg-yuzey-card px-3 py-1.5 text-sm text-[color:var(--yz-danger-ink)] transition hover:brightness-95";

// Kart yuzeyi — yumusak katmanli golge + 16px radius (dashboard vb. yeniden
// kullanir; koyu modda .dark .bg-white → slate-900).
// Kart: radius 16 + 1px cok hafif kenarlik, GOLGE YOK (mobil karari).
export const cardCls = "kart-kenar rounded-kart border bg-yuzey-card";

// (P138) `tableCardCls` KALDIRILDI. Tanimliydi ama HICBIR sayfa
// kullanmiyordu (0/23) — yerini `components/tablo.tsx` icindeki
// `TabloKart` aldi ve 23 sayfa oraya tasindi. Olu bir sinif birakmak,
// bir sonraki gelistiriciye iki secenek gosterirdi.

export function ErrorBox({ message }: { message?: string | null }) {
  if (!message) return null;
  return (
    // CANLI BOLGE (tur 56): kutu ekrana SONRADAN gelir. `role="alert"`
    // olmadan ekran okuyucu yeni metni DUYURMAZ — gormeyen kullanici
    // kaydin neden gitmedigini anlamaz. `alert` zaten assertive'dir;
    // ayrica `aria-live` vermek cift duyuruya yol acar.
    <p
      role="alert"
      className="rounded-lg border px-3 py-2 text-sm"
      style={{
        background: "var(--yz-surface-sunken)",
        borderColor: "var(--yz-danger-edge)",
        color: "var(--yz-danger-ink)",
      }}
    >
      {message}
    </p>
  );
}

// (P244 §4) `Pager` BURADAN KALDIRILDI — `components/ui/tablo-ilkelleri.tsx`e
// tasindi: sayfalama bir FORM kontrolu degil, tablonun parcasidir.

/** (P58) IKINCIL YUKLEME UYARISI — hata DEGIL, EKSIKLIK bildirir.
 *
 * Sayfalarin cogu ana listenin yaninda bir ARAMA listesi ceker (vardiyalar,
 * kullanicilar, daireler, kategoriler). O istek dustugunde sayfa
 * calismaya devam eder ama sonuc YANILTICIDIR: acilir liste bos kalir ve
 * "kayit yok" gibi okunur, ya da daire numarasi yerine kimlik parcasi
 * gorunur ve VERI SANILIR.
 *
 * `ErrorBox` (kirmizi, `role="alert"`) burada dogru degil: islem
 * BASARISIZ OLMADI, eksik yuklendi. Bu yuzden ayri, sessiz bir gorunum ve
 * `role="status"` — ekran okuyucu duyurur ama araya girmez.
 */
// (P244 §4) `EksikVeriUyarisi` BURADAN KALDIRILDI — `components/ui/
// durumlar.tsx`e tasindi. Eski surum sabit `amber-*` renkleri yaziyordu
// ve token katmanini bypass ediyordu. Yeniden ihrac EDILMEDI: iki
// kaynak, "hangisi gecerli?" sorusunu ureten tekrardir.
