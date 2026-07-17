"use client";

import type { ReactNode } from "react";

// Ortak form/dugme token'lari (Faz 1). Teal odak halkasi + yumusak golge/hover
// kaldirmasi. Ic sayfalar bu siniflari import ederek "bedava" cilalanir.
export const inputCls =
  "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-ink outline-none transition focus:border-brand-teal focus:ring-2 focus:ring-brand-teal/25 disabled:opacity-60";
export const btnPrimary =
  "inline-flex items-center justify-center gap-2 rounded-lg bg-brand-teal px-4 py-2 text-sm font-medium text-white shadow-soft transition-all hover:bg-[#0c8382] hover:shadow-lift active:translate-y-px disabled:opacity-60 disabled:shadow-none";
export const btnGhost =
  "rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm text-slate-700 transition hover:border-slate-400 hover:bg-slate-100";
export const btnDanger =
  "rounded-lg border border-red-300 bg-white px-3 py-1.5 text-sm text-red-700 transition hover:bg-red-50";

// Kart yuzeyi — yumusak katmanli golge + 16px radius (dashboard vb. yeniden
// kullanir; koyu modda .dark .bg-white → slate-900).
export const cardCls =
  "rounded-2xl border border-slate-200 bg-white shadow-card";

// Satir-ici form/panel yuzeyi (kart + ic bosluk). Overlay DEGIL — mevcut akis
// korunur; yalnizca yuzey Faz-1 sistemine gecer.
export const panelCls =
  "rounded-2xl border border-slate-200 bg-white p-5 shadow-card";

// Tablo kart cercevesi (dashboard tablo deseni). Icine `overflow-x-auto` sarmali
// + <table> gelir.
export const tableCardCls =
  "overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-card";

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
      <div className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
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
    <p className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
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
  const canPrev = offset > 0;
  const canNext = offset + limit < total;
  return (
    <div className="flex items-center justify-between text-sm">
      <span className="text-muted">
        Toplam {total} · {total === 0 ? 0 : offset + 1}-{Math.min(offset + limit, total)}
      </span>
      <div className="flex gap-2">
        <button disabled={!canPrev} onClick={onPrev} className={`${btnGhost} disabled:opacity-50`}>
          Önceki
        </button>
        <button disabled={!canNext} onClick={onNext} className={`${btnGhost} disabled:opacity-50`}>
          Sonraki
        </button>
      </div>
    </div>
  );
}
