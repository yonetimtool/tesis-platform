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

/**
 * Kisiler — tahsilat/borclandirma/icra formlarindaki "Kisi" alani.
 *
 * (P206 §2) OLCULEN KUSUR: bu liste BOS geliyordu ve sebep YETKI
 * DEGILDI. `limit=500` isteniyor, uc 200 tavaninda 422 donuyor, SWR
 * hatasi sessizce yutuluyor ve `data?.items ?? []` BOS liste
 * uretiyordu: kullanici kimseyi secemiyordu, ekran ise hicbir sey
 * soylemiyordu.
 *
 * IKI DUZELTME: uc tavani 1000'e cikti (`/units` ile ayni gerekce) ve
 * bu kanca artik HATAYI GIZLEMIYOR — cagiran `hata`yi ekranda
 * gosterebiliyor.
 */
export function useKisiler() {
  const { data, error, isLoading } = useSWR<Sayfali<{ id: string; ad: string }>>(
    "/api/users?limit=500",
    jsonFetcher,
    { revalidateOnFocus: false },
  );
  return {
    kisiler: (data?.items ?? []).map((u) => ({ id: u.id, ad: u.ad })),
    hata: error ? true : false,
    yukleniyor: isLoading,
  };
}

/**
 * (P206 §2) BORCLULAR — tahsilat penceresindeki kisi seciciyi
 * ONCELIKLENDIRIR.
 *
 * Tahsilat penceresinde sorulan soru "kimden para aliyorum" degil,
 * "KIME BORCU VAR"dir: yonetici kapida duran kisiyi ararken yuzlerce
 * ad arasindan degil, BORCLU LISTESINDEN secmeli ve borcu ne kadarsa
 * onu GORMELI. Yaslandirma ucu (borclular ekraninin kaynagi) daireyle
 * birlikte borclu kisiyi ve kalan tutari zaten donuyor — ikinci bir
 * uc yazmak, ayni sayinin iki yerde ayrisma riski demekti (P192 TEK
 * KAYNAK kurali).
 */
export function useBorclular() {
  const { data, error, isLoading } = useSWR<{
    kovalar: {
      daireler: {
        unit_id: string;
        unit_no: string;
        kalan_kurus: number;
        borclu_ad: string | null;
        borclu_user_id: string | null;
      }[];
    }[];
  }>("/api/panel/yaslandirma", jsonFetcher, { revalidateOnFocus: false });

  const satirlar = (data?.kovalar ?? [])
    .flatMap((k) => k.daireler)
    // KISISI OLMAYAN daire ATLANIR: tahsilat bir KISIYE yazilir ve
    // "sahipsiz daire" secilirse kayit kime ait oldugu belirsiz olurdu.
    .filter((d) => d.borclu_user_id)
    .map((d) => ({
      userId: d.borclu_user_id as string,
      unitId: d.unit_id,
      ad: d.borclu_ad ?? "",
      unitNo: d.unit_no,
      kalanKurus: d.kalan_kurus,
    }))
    .sort((a, b) => b.kalanKurus - a.kalanKurus);

  return { borclular: satirlar, hata: !!error, yukleniyor: isLoading };
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
