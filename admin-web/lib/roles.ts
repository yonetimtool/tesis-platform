// Rol modeli (contracts/auth.md §4): panel YALNIZ admin icindir; diger roller
// burada yalnizca kullanici yonetimi/atama ekranlarinda gosterim icin listelenir.
import type { UserRole } from "./types";

export const ROLE_OPTIONS: { value: UserRole; label: string }[] = [
  { value: "admin", label: "Admin (platform)" },
  { value: "yonetici", label: "Yonetici" },
  { value: "security", label: "Guvenlik" },
  { value: "tesis_gorevlisi", label: "Tesis Gorevlisi" },
  { value: "resident", label: "Site Sakini" },
];

export const ROLE_STYLE: Record<string, string> = {
  admin: "bg-violet-100 text-violet-800",
  yonetici: "bg-amber-100 text-amber-800",
  security: "bg-blue-100 text-blue-800",
  tesis_gorevlisi: "bg-teal-100 text-teal-800",
  resident: "bg-slate-100 text-slate-700",
};

export function roleLabel(v: string): string {
  return ROLE_OPTIONS.find((r) => r.value === v)?.label ?? v;
}

// Gorev atanabilir saha rolleri (yonetici gorev ALMAZ, atar; resident alamaz).
export const SAHA_ROLLERI: UserRole[] = ["security", "tesis_gorevlisi"];
