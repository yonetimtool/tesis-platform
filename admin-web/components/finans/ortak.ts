"use client";

// (P167 Asama 4) Finans sayfalarinin ORTAK veri kancalari ve secim
// listeleri. Sekiz sayfa da ayni uc kaynagi okuyor (kasa, firma,
// gelir/gider tanimi, kisi, daire); her sayfada ayri `useSWR` yazmak
// ayni anahtari sekiz kez uretmek ve birini degistirdiginde otekilerin
// onbellegini bolmek demekti.

import useSWR from "swr";

import { jsonFetcher } from "@/lib/fetcher";

export interface Secenek {
  id: string;
  ad: string;
}

interface Sayfali<T> {
  items: T[];
}

/**
 * SECIM LISTELERI — hepsi TEK SEFER cekilir ve odaklanmada tazelenmez.
 *
 * `revalidateOnFocus: false`: kasa/firma/tanim listeleri gun icinde
 * degismez. Her sekme donusunde yeniden cekmek, modal aciken listeyi
 * altindan degistirme riski demekti (secili deger kaybolur).
 */
export function useKasalar() {
  const { data } = useSWR<Sayfali<{ id: string; ad: string; kod: string }>>(
    "/api/panel/kasalar?limit=200",
    jsonFetcher,
    { revalidateOnFocus: false },
  );
  return (data?.items ?? []).map((k) => ({ id: k.id, ad: k.ad }));
}

export function useFirmalar() {
  const { data } = useSWR<Sayfali<{ id: string; ad: string }>>(
    "/api/panel/firmalar?limit=200",
    jsonFetcher,
    { revalidateOnFocus: false },
  );
  return (data?.items ?? []).map((f) => ({ id: f.id, ad: f.ad }));
}

/** Gelir/gider kalemleri — "Borclandirma Turu" ve "Gider Turu" ayni kaynak. */
export function useGelirGiderTanimlari() {
  const { data } = useSWR<Sayfali<{ id: string; ad: string }>>(
    "/api/tanimlar/gelir-gider-tanimlari?limit=200",
    jsonFetcher,
    { revalidateOnFocus: false },
  );
  return (data?.items ?? []).map((g) => ({ id: g.id, ad: g.ad }));
}

/** Kisiler — tahsilat/borclandirma/icra formlarindaki "Kisi" alani. */
export function useKisiler() {
  const { data } = useSWR<Sayfali<{ id: string; ad: string }>>(
    "/api/users?limit=500",
    jsonFetcher,
    { revalidateOnFocus: false },
  );
  return (data?.items ?? []).map((u) => ({ id: u.id, ad: u.ad }));
}

/** Bagimsiz bolumler. */
export function useDaireler() {
  const { data } = useSWR<Sayfali<{ id: string; no: string }>>(
    "/api/units?limit=500",
    jsonFetcher,
    { revalidateOnFocus: false },
  );
  return (data?.items ?? []).map((u) => ({ id: u.id, ad: u.no }));
}

/** Bugunun tarihi — `<input type="date">` icin YEREL, UTC degil. */
export function bugun(): string {
  const d = new Date();
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}
