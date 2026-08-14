"use client";

/**
 * (P160 / Asama 3) ROZET — durum sinyali.
 *
 * Brief'in ana kurali: "renk YALNIZCA durum sinyali olarak (halka rengi,
 * ROZET, uyari seridi) kalacak" — yani P133'un renkli DOLGU bloklari
 * terk edildi. Bu yuzden rozet DOLU DEGIL: notr metal yuzey + renkli
 * kenar + renkli metin.
 *
 * NEDEN DOLGU YOK: dolu rozet, listede yan yana dizildiginde sayfayi bir
 * renk cumbusune cevirir ve tam da "hazir sablon" hissini uretir. Kenar
 * + metin ayni bilgiyi tasir, gorsel gurultunun onda biriyle.
 *
 * KONTRAST: metin `-ink` (>=4.5), kenar `-edge` (>=3.0) varyantini
 * kullanir — ikisi de `tasarim-sistemi.css`te olculdu ve kilitlendi.
 * Ham ton BURADA KULLANILMAZ.
 *
 * RENK TEK BASINA ANLAM TASIMAZ (WCAG 1.4.1): rozetin METNI zaten
 * durumu soyler ("Aktif", "Pasif"). Yalniz renkle ayrilan bir rozet,
 * renk korlugu olan kullanici icin ayirt edilemezdi.
 */
import type { ReactNode } from "react";

export type RozetDurumu = "notr" | "bilgi" | "olumlu" | "uyari" | "kritik";

const RENK: Record<RozetDurumu, { kenar: string; metin: string }> = {
  notr: { kenar: "var(--yz-border)", metin: "var(--yz-text-2)" },
  bilgi: { kenar: "var(--yz-accent-edge)", metin: "var(--yz-accent-ink)" },
  olumlu: { kenar: "var(--yz-success-edge)", metin: "var(--yz-success-ink)" },
  uyari: { kenar: "var(--yz-warning-edge)", metin: "var(--yz-warning-ink)" },
  kritik: { kenar: "var(--yz-danger-edge)", metin: "var(--yz-danger-ink)" },
};

export function Rozet({
  children,
  durum = "notr",
  /** Metnin basinda kucuk renkli nokta — referans gorseldeki etiket dili. */
  nokta = false,
}: {
  children: ReactNode;
  durum?: RozetDurumu;
  nokta?: boolean;
}) {
  const r = RENK[durum];
  return (
    <span
      className="inline-flex items-center gap-1.5 whitespace-nowrap border px-2 py-0.5"
      style={{
        borderRadius: "var(--yz-radius-chip)",
        borderColor: r.kenar,
        borderWidth: "var(--yz-border-w)",
        color: r.metin,
        background: "var(--yz-surface-1)",
        fontSize: "var(--yz-fs-xs)",
      }}
    >
      {nokta && (
        <span
          aria-hidden="true"
          className="h-1.5 w-1.5 shrink-0 rounded-full"
          style={{ background: r.kenar }}
        />
      )}
      {children}
    </span>
  );
}
