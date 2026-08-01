// (P81) NUMARALANDIRMA HARITALARI SUNUCUYLA ORTUSUR — capraz bag.
//
// `lib/enum-adlari.ts` alti sunucu numaralandirmasini goruntulenen ada
// cevirir. Sunucu bir enum'a yeni deger eklerse ve harita guncellenmezse
// P53'un kurali devreye girer ve deger HAM cizilir: rozet bos kalmaz ama
// kullanici `zimmetli` yerine tanimadigi bir jeton gorur. Bu bilincli bir
// GERI DUSUS'tur, hedef degil — ve geri dususe dusuldugunu kimse fark
// etmez. Bag bunu gorunur kilar.
//
// P80'in rol bagiyla ayni desen; kaynak yine `backend/app/models.py`,
// cunku enum'un tek dogruluk kaynagi orasi.
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

import {
  BILDIRIM_TIP, DEMIRBAS_DURUM, DEMIRBAS_KATEGORI,
  ODEME_DURUM, ODEME_YONTEM, TUR_DURUM,
} from "@/lib/enum-adlari";

const MODELS = readFileSync(
  join(__dirname, "..", "..", "backend", "app", "models.py"),
  "utf8",
);

/** `X = ENUM("a", "b", name="x", ...)` blogundan degerleri ayiklar. */
function sunucuDegerleri(sabit: string): string[] {
  const blok = new RegExp(`${sabit} = ENUM\\(([\\s\\S]*?)name=`).exec(MODELS);
  if (!blok) throw new Error(`${sabit} bulunamadi`);
  return (
    blok[1]
      .split("\n")
      .filter((l) => !/^\s*#/.test(l)) // yorumlar deger degildir
      .join("\n")
      .match(/"([a-z_]+)"/g) ?? []
  ).map((x) => x.slice(1, -1));
}

/** Cevirisi BILEREK yazilmayan degerler — her biri gerekcesiyle. */
const HARIC: Record<string, { deger: string; neden: string }[]> = {
  NOTIFICATION_TIP: [
    // (P53) Peyzaj urunden KALDIRILDI (087f33f). Enum degeri eski
    // kayitlar icin semada duruyor; sozluge geri getirmek, silinmis bir
    // ozelligin sozcugunu urune geri sokmak olurdu. Ham gosterilir.
    { deger: "peyzaj_yaklasan", neden: "peyzaj urunden kaldirildi" },
    { deger: "peyzaj_kacirilan", neden: "peyzaj urunden kaldirildi" },
  ],
};

const BAGLAR: { sabit: string; harita: Record<string, string> }[] = [
  { sabit: "NOTIFICATION_TIP", harita: BILDIRIM_TIP },
  { sabit: "PATROL_WINDOW_DURUM", harita: TUR_DURUM },
  { sabit: "DUES_DURUM", harita: ODEME_DURUM },
  { sabit: "DUES_YONTEM", harita: ODEME_YONTEM },
  { sabit: "ASSET_DURUM", harita: DEMIRBAS_DURUM },
  { sabit: "ASSET_KATEGORI", harita: DEMIRBAS_KATEGORI },
];

describe("enum haritalari sunucuyla ortusur (P81)", () => {
  it.each(BAGLAR)("$sabit", ({ sabit, harita }) => {
    const haric = (HARIC[sabit] ?? []).map((x) => x.deger);
    const beklenen = sunucuDegerleri(sabit).filter((d) => !haric.includes(d));
    expect([...Object.keys(harita)].sort()).toEqual([...beklenen].sort());
  });

  it("HARIC listesindeki degerler sunucuda GERCEKTEN var", () => {
    // Aksi halde liste zamanla yalan bir gerekce koleksiyonuna doner:
    // sunucudan silinmis bir degeri "bilerek haric" diye tutmak, olmayan
    // bir seyi aciklamaktir.
    for (const [sabit, girdiler] of Object.entries(HARIC)) {
      const sunucu = sunucuDegerleri(sabit);
      for (const g of girdiler) expect(sunucu, `${sabit}/${g.deger}`).toContain(g.deger);
    }
  });
});
