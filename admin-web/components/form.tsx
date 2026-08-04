"use client";

import type { ReactNode } from "react";
import { useT } from "@/lib/i18n/kullan";

// Ortak form/dugme token'lari (Faz 1). Teal odak halkasi + yumusak golge/hover
// kaldirmasi. Ic sayfalar bu siniflari import ederek "bedava" cilalanir.
// (P132) ORTAK ILKELLER TASARIM SISTEMINE TASINDI — 47 sayfa bunlari
// kullaniyor. Sayfa sayfa gecmek yerine BURAYI degistirmek, ayni sonucu
// tek yerde ve gerileme riski olmadan verir ("tek yer, sayfa basina CSS
// degil" — P132 sart 1).
export const inputCls =
  "w-full rounded-lg border border-slate-300 bg-yuzey-card px-3 py-2 text-sm text-metin-body outline-none transition focus:border-primary focus:ring-2 focus:ring-primary/25 disabled:opacity-60";
// Birincil dugme MAVI (mobil `HomeTokens.primary`). Beyaz metin
// #2563EB uzerinde 5.17:1 — AA (tests/tasarim-kontrast.test.ts).
// GOLGE KALDIRILDI: mobil kartlarda golge yoktur, dugmede de olmamali.
export const btnPrimary =
  "odak-ters inline-flex items-center justify-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-[#1d4fd8] active:translate-y-px disabled:opacity-60";
export const btnGhost =
  "kart-kenar rounded-lg border bg-yuzey-card px-3 py-1.5 text-sm text-metin-body transition hover:bg-yuzey-divider";
export const btnDanger =
  "rounded-lg border border-accent-red/30 bg-yuzey-card px-3 py-1.5 text-sm text-vurguInk-red transition hover:bg-accent-red/12";

// Kart yuzeyi — yumusak katmanli golge + 16px radius (dashboard vb. yeniden
// kullanir; koyu modda .dark .bg-white → slate-900).
// Kart: radius 16 + 1px cok hafif kenarlik, GOLGE YOK (mobil karari).
export const cardCls = "kart-kenar rounded-kart border bg-yuzey-card";

// Satir-ici form/panel yuzeyi (kart + ic bosluk). Overlay DEGIL — mevcut akis
// korunur; yalnizca yuzey Faz-1 sistemine gecer.
export const panelCls =
  "kart-kenar rounded-kart border bg-yuzey-card p-kart";

// Tablo kart cercevesi (dashboard tablo deseni). Icine `overflow-x-auto` sarmali
// + <table> gelir.
export const tableCardCls =
  "kart-kenar overflow-hidden rounded-kart border bg-yuzey-card";

// Panel giris hareketi — hizli fade + kucuk olcek/kayma (~250ms). motion.form /
// motion.div ile yayilir: {...panelMotion}. reducedMotion="user" global saygi.
export const panelMotion = {
  initial: { opacity: 0, y: 8, scale: 0.985 },
  animate: { opacity: 1, y: 0, scale: 1 },
  transition: { duration: 0.25, ease: [0.22, 1, 0.36, 1] as const },
};

// Sayfa basligi + istege bagli eylem satiri. Tight heading, tutarli ritim.
export function PageHeader({
  title,
  subtitle,
  action,
}: {
  title: string;
  subtitle?: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-wrap items-start justify-between gap-3">
      <div className="min-w-0 space-y-1">
        <h1 className="text-selam text-metin-heading break-words">{title}</h1>
        {subtitle && <p className="text-sm text-muted">{subtitle}</p>}
      </div>
      {action}
    </div>
  );
}

export function Field({
  label,
  children,
  hint,
}: {
  label: string;
  children: ReactNode;
  hint?: string;
}) {
  return (
    <label className="block text-sm">
      <span className="mb-1 block font-medium">{label}</span>
      {children}
      {hint ? <span className="mt-1 block text-xs text-muted">{hint}</span> : null}
    </label>
  );
}

export function ErrorBox({ message }: { message?: string | null }) {
  if (!message) return null;
  return (
    // CANLI BOLGE (tur 56): kutu ekrana SONRADAN gelir. `role="alert"`
    // olmadan ekran okuyucu yeni metni DUYURMAZ — gormeyen kullanici
    // kaydin neden gitmedigini anlamaz. `alert` zaten assertive'dir;
    // ayrica `aria-live` vermek cift duyuruya yol acar.
    <p
      role="alert"
      className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700"
    >
      {message}
    </p>
  );
}

export function Pager({
  offset,
  limit,
  total,
  onPrev,
  onNext,
}: {
  offset: number;
  limit: number;
  total: number;
  onPrev: () => void;
  onNext: () => void;
}) {
  const t = useT();
  const canPrev = offset > 0;
  const canNext = offset + limit < total;
  return (
    <div className="flex items-center justify-between text-sm">
      <span className="text-muted">
        {t("ortakSayfalayici", {
          toplam: total,
          bas: total === 0 ? 0 : offset + 1,
          son: Math.min(offset + limit, total),
        })}
      </span>
      <div className="flex gap-2">
        <button disabled={!canPrev} onClick={onPrev} className={`${btnGhost} disabled:opacity-50`}>
          {t("ortakOnceki")}
        </button>
        <button disabled={!canNext} onClick={onNext} className={`${btnGhost} disabled:opacity-50`}>
          {t("ortakSonraki")}
        </button>
      </div>
    </div>
  );
}

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
export function EksikVeriUyarisi({ mesaj }: { mesaj?: string | null }) {
  if (!mesaj) return null;
  return (
    <p
      role="status"
      className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-1.5 text-xs text-amber-800"
    >
      {mesaj}
    </p>
  );
}
