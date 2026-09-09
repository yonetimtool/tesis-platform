import type { ResidentListItem } from "@/lib/types";

/**
 * (P220 §4) SAKINLERI BLOKLARA GORE GRUPLAR.
 *
 * =========================================================================
 * NEDEN SAYFADA DEGIL BURADA
 * =========================================================================
 * Once sayfa dosyasinda duruyordu ve Next.js derlemesi REDDETTI: bir
 * `page.tsx` yalniz belirli disa aktarimlara izin veriyor. Iyi de oldu —
 * saf bir fonksiyon olarak burada TEST EDILEBILIR.
 *
 * =========================================================================
 * SIRA KURALI
 * =========================================================================
 * Bloklar alfabetik (Turkce siralamayla: `localeCompare(_, "tr")` —
 * `Ç` ve `Ş` aksi halde yanlis yere duser), BLOKSUZLAR EN SONDA.
 *
 * BLOKSUZLAR GIZLENMIYOR: aktif daire bagi olmayan sakin, siteden
 * ayrilmis ama hesabi duran kisidir ve sakinler sayfasinin varlik sebebi
 * tam olarak onu BULUP silmek. Gizlemek onu bulunamaz yapardi.
 *
 * Mobildeki `bloklaraGore` ile AYNI kurallar (aynen ayni sira, ayni
 * bloksuz davranisi) — iki yuzeyin ayni listeyi farkli siralamasi,
 * yoneticinin hangisine bakacagini bilememesi olurdu.
 */
export type SakinBlogu = {
  blok: string | null;
  sakinler: ResidentListItem[];
};

export function bloklaraGore(liste: ResidentListItem[]): SakinBlogu[] {
  const gruplar = new Map<string | null, ResidentListItem[]>();
  for (const m of liste) {
    const anahtar = m.blok ?? null;
    const mevcut = gruplar.get(anahtar);
    if (mevcut) mevcut.push(m);
    else gruplar.set(anahtar, [m]);
  }
  const adlilar = [...gruplar.keys()]
    .filter((k): k is string => k !== null)
    .sort((a, b) => a.localeCompare(b, "tr"));
  const out: SakinBlogu[] = adlilar.map((b) => ({
    blok: b,
    sakinler: gruplar.get(b) ?? [],
  }));
  const bloksuz = gruplar.get(null);
  if (bloksuz) out.push({ blok: null, sakinler: bloksuz });
  return out;
}
