// (P250 §4) Egitim videolari BFF ortak yardimcisi — yalniz `set` sorgusu
// tasinir (beyaz liste): bilinmeyen parametre backend'e sizmaz.
import type { NextRequest } from "next/server";

export function setSorgusu(req: NextRequest): string {
  const set = req.nextUrl.searchParams.get("set");
  return set && /^[a-z_]{1,30}$/.test(set) ? `?set=${set}` : "";
}
