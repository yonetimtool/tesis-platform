// (P244 §9b/§9c) SUZGEC, LISTENIN HATASINA BAGLI OLAMAZ.
//
// ===========================================================================
// OLCULEN KUSUR — BES EKRANDA AYNI SEY
// ===========================================================================
// `VeriTablosu`nun `araclar` yuvasi tablonun UST SERIDIDIR ve tablo
// hata alinca govdesi "tekrar dene" ile degisir. Suzgecler o yuvaya
// konuldugunda liste dustugu anda EKRANDAN SILINIYORDU.
//
// Bu tam olarak yanlis anda kaybolmaktir: kullanicinin liste
// dustugunde yaptigi ilk sey suzgeci degistirip TEKRAR DENEMEKTIR.
// Tabloyu hata durumuna sokan sey cogu zaman suzgecin kendisidir
// (cok genis aralik, gecersiz donem, zaman asimi).
//
// `/users`, `/audit`, `/dues`, `/icra`, `/tenants` — besinde de vardi.
//
// ===========================================================================
// KURAL: SUZGEC DISARIDA, LISTE EYLEMI ICERIDE
// ===========================================================================
// Ayrim keyfi degil:
//   * SUZGEC listeyi YENIDEN SORAR — hata halinde CALISIR ve gereklidir.
//   * LISTE EYLEMI (disa aktar, toplu islem) gorunen listeyi kullanir —
//     liste yoksa anlamsizdir ve onunla birlikte kaybolmasi DOGRUDUR.
//
// Bu yuzden tarama `<Secim`/`<AramaAlani` arar; `<Dugme` aramaz.
//
// ===========================================================================
// NEDEN KAYNAK TARAMASI
// ===========================================================================
// DOM testi bunu ekran ekran olcerdi ve yeni bir sayfa eklendiginde
// SESSIZ kalirdi. Kural yapisaldir: "suzgec denetimi `araclar` yuvasina
// yazilmaz".
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

const KOK = join(__dirname, "..");

function sayfalar(): string[] {
  const cikti: string[] = [];
  const tara = (dizin: string) => {
    for (const ad of readdirSync(dizin)) {
      const tam = join(dizin, ad);
      if (statSync(tam).isDirectory()) tara(tam);
      else if (ad === "page.tsx") cikti.push(tam);
    }
  };
  tara(join(KOK, "app", "(protected)"));
  return cikti;
}

/** `araclar={...}` yuvasinin icerigini dengeli parantezle cikarir. */
function araclarIcerigi(kaynak: string): string[] {
  const bloklar: string[] = [];
  let i = kaynak.indexOf("araclar={");
  while (i >= 0) {
    let d = 0;
    let j = i + "araclar=".length;
    for (let k = j; k < kaynak.length; k += 1) {
      if (kaynak[k] === "{") d += 1;
      else if (kaynak[k] === "}") {
        d -= 1;
        if (d === 0) {
          j = k + 1;
          break;
        }
      }
    }
    bloklar.push(kaynak.slice(i, j));
    i = kaynak.indexOf("araclar={", j);
  }
  return bloklar;
}

/** Suzgec denetimleri — listeyi YENIDEN SORAN kontroller. */
const SUZGEC_DESENI = /<(Secim|AramaAlani)\b/;

describe("(P244 §9b/§9c) suzgec listenin hatasina bagli olamaz", () => {
  const liste = sayfalar();

  it("TARAMA gercekten sayfa buluyor (vakum degil)", () => {
    expect(liste.length).toBeGreaterThan(50);
    // Cikarici GERCEKTEN calisiyor mu — sahte kaynakta dogrulanir.
    const sahte = 'araclar={<div><Secim value={x} /></div>}\n';
    expect(araclarIcerigi(sahte).length).toBe(1);
    expect(SUZGEC_DESENI.test(araclarIcerigi(sahte)[0])).toBe(true);
    // Dugme suclu DEGIL: liste eylemi listeyle birlikte kaybolabilir.
    expect(SUZGEC_DESENI.test('araclar={<Dugme>Dışa aktar</Dugme>}')).toBe(false);
  });

  it("HICBIR sayfa suzgec denetimini `araclar` yuvasina koymuyor", () => {
    const suclular: string[] = [];
    for (const p of liste) {
      const kaynak = readFileSync(p, "utf8");
      if (!kaynak.includes("araclar={")) continue;
      for (const blok of araclarIcerigi(kaynak)) {
        if (SUZGEC_DESENI.test(blok)) {
          suclular.push(p.slice(join(KOK, "app", "(protected)").length + 1));
        }
      }
    }
    expect(
      [...new Set(suclular)].sort(),
      `suzgeci tablonun icine koyan sayfa:\n${suclular.join("\n")}`,
    ).toEqual([]);
  });
});
