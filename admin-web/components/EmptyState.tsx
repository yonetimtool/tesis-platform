import type { ReactNode } from "react";

// Tutarli bos-durum yuzeyi (Faz 2). Kucuk marka-renkli satir-ikon + tek satir
// metin + istege bagli eylem. Tablolarda `colSpan`'li bir <td> icinde de,
// kart-listelerinde de dogrudan kullanilabilir. Animasyon yok — sakin durur.
export function EmptyState({
  title,
  description,
  action,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 px-6 py-12 text-center">
      <span className="flex h-12 w-12 items-center justify-center rounded-2xl bg-brand-teal/10 text-brand-teal">
        <svg viewBox="0 0 24 24" className="h-6 w-6" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
          <path d="M4 8l8-4 8 4v8l-8 4-8-4z" />
          <path d="M4 8l8 4 8-4M12 12v8" />
        </svg>
      </span>
      <div className="space-y-1">
        <p className="text-sm font-medium text-ink">{title}</p>
        {description && <p className="text-sm text-muted">{description}</p>}
      </div>
      {action}
    </div>
  );
}
