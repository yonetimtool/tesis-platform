"use client";

import type { ReactNode } from "react";

export const inputCls =
  "w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-slate-500";
export const btnPrimary =
  "rounded-lg bg-ink px-4 py-2 text-sm font-medium text-white transition hover:bg-slate-700 disabled:opacity-60";
export const btnGhost =
  "rounded-lg border border-slate-300 px-3 py-1.5 text-sm text-slate-700 transition hover:bg-slate-100";
export const btnDanger =
  "rounded-lg border border-red-300 px-3 py-1.5 text-sm text-red-700 transition hover:bg-red-50";

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
    <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{message}</p>
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
