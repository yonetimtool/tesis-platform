// (E2E 2026-09) Bakim yillik ozeti -> CSV (TESIS-14). Sayfa dosyasinda
// degil: Next.js app dizininde `page.tsx` yalniz varsayilan bileseni ve
// bilinen alanlari disari verebilir; test de bu saf fonksiyonu jsdom
// kurmadan olcer.

export interface BakimOzetVerisi {
  yil: number;
  satirlar: {
    ad: string;
    yasal: boolean;
    bakim_sayisi: number;
    toplam_kurus: number;
    son_bakim: string | null;
    sonraki_bakim: string;
  }[];
}

/** (E2E 2026-09) Yillik ozet CSV'si — denetime verilebilir cikti.
 *
 * Istemcide uretilir: veri zaten ekranda, sunucuda ayri bir rapor ucu
 * acmak ayni sorguyu ikinci kez yazmak olurdu. BOM: Excel Turkce
 * karakterleri ancak onunla dogru acar. Ayrac `;` — Turkce Excel
 * virgulu ondalik ayraci sayar. */
export function bakimOzetCsv(
  ozet: BakimOzetVerisi,
  basliklar: string[],
  yasalMetin: string,
): string {
  const kacis = (c: string) => (/[";\n]/.test(c) ? `"${c.replace(/"/g, '""')}"` : c);
  const satirlar: string[][] = [basliklar];
  for (const s of ozet.satirlar) {
    satirlar.push([
      s.ad,
      s.yasal ? yasalMetin : "",
      String(s.bakim_sayisi),
      (s.toplam_kurus / 100).toFixed(2).replace(".", ","),
      s.son_bakim ?? "",
      s.sonraki_bakim,
    ]);
  }
  return "\ufeff" + satirlar.map((r) => r.map(kacis).join(";")).join("\n");
}

