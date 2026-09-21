// (P244 §4) TEK TASARIM DILI — karma sayfa BIRAKILMAZ.
//
// ===========================================================================
// OLCULEN DURUM
// ===========================================================================
// P160'ta bilincli bir gecis karari verilmisti: eski dil (`globals.css` +
// tailwind renkleri) korunsun, yeni `--yz-*` dili YANINA konsun. Gecis
// P244 asama 1'de %75'ti — 59 sayfa yalniz yeni dil, **18 karma**, 0
// yalniz eski.
//
// Asama 4 kalan 18'i temizledi. Bu kilit GERI DONMESINI engelliyor.
//
// ===========================================================================
// NEDEN MODUL YOLU OLCULUYOR
// ===========================================================================
// "Tasarim dili" gorsel bir seydir ve jsdom RENK COZMEZ — bir DOM testi
// eski dille cizilmis bir sayfayi sorunsuz bulur (P226'da olculdu).
// Olculebilecek en yakin YAPISAL sey, sayfanin hangi katmandan ithal
// ettigi. Asama 4'te modul sinirlari tasarim dili siniriyla ayni yere
// getirildi: gorsel ilkeller `components/ui/` altinda, eski dosyalarda
// yalniz forma ait olanlar kaldi.
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

const KOK = join(__dirname, "..");

/**
 * Eski tasarim dilinin GORSEL modulleri.
 *
 * (P244 §10) DORDU DE ARTIK DOSYA OLARAK DA YOK: `tablo.tsx` ve
 * `Liste.tsx` asama 4'te, `tasarim.tsx` ve `Modal.tsx` asama 10'da
 * silindi. Liste BOSALTILMADI — iddia "bu yollardan ithal edilmiyor"
 * olarak KALIR ve biri dosyayi geri koyup kullanmaya baslarsa test
 * duser.
 */
const ESKI_MODULLER = [
  "@/components/tablo",
  "@/components/tasarim",
  "@/components/Liste",
  "@/components/Modal",
];

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

describe("(P244 §4) tek tasarim dili", () => {
  const liste = sayfalar();

  it("TARAMA gercekten sayfa buluyor (vakum degil)", () => {
    // 79 sayfa olculmustu; sayi degisebilir ama sifir olamaz.
    expect(liste.length).toBeGreaterThan(50);
  });

  it("HICBIR korumali sayfa ESKI gorsel modulden ithal etmiyor", () => {
    const suclular: string[] = [];
    for (const p of liste) {
      const kaynak = readFileSync(p, "utf8");
      for (const mod of ESKI_MODULLER) {
        if (kaynak.includes(`from "${mod}"`)) {
          suclular.push(`${p.slice(KOK.length + 1)} -> ${mod}`);
        }
      }
    }
    expect(
      suclular,
      `karma dil kullanan sayfa:\n${suclular.join("\n")}`,
    ).toEqual([]);
  });

  it("(P244 §10) ESKI GORSEL MODULLER DOSYA OLARAK DA YOK", () => {
    // Onceki surum "kimse kullanmiyor" diyordu ve dosyalar duruyordu.
    // Kullanilmayan ama DURAN bir modul, bir sonraki gelistiricinin
    // refleksle ithal edecegi seydir; asama 10'da silindiler.
    for (const ad of ["tablo.tsx", "tasarim.tsx", "Liste.tsx", "Modal.tsx"]) {
      expect(
        existsSync(join(KOK, "components", ad)),
        `${ad} geri gelmis`,
      ).toBe(false);
    }
  });

  it("(P244 §10) ESKI `components/form` KALAN KULLANICILARI — bayatlamasin", () => {
    /**
     * `form.tsx` HENUZ silinemedi: bes dosya hala sinif sabitlerini
     * (`inputCls`, `btnDanger`, `cardCls`, `Field`, `ErrorBox`)
     * kullaniyor ve bunlarin hepsi GIRIS/KAYIT yuzeyinde — korumali
     * alanin disinda, kendi duzen kurallari olan ekranlar.
     *
     * LISTE TAM ESLESIR: biri temizlenince buradan SILINMELI (yoksa
     * liste bayatlar), yeni biri eklenince test DUSER. Yani borc ne
     * sessizce buyuyebilir ne de sessizce unutulabilir.
     */
    const BEKLENEN = [
      "app/davet/[jeton]/page.tsx",
      "app/giris/oauth/page.tsx",
      "app/kayit/page.tsx",
      "components/Ekler.tsx",
      "components/GirisYontemlerim.tsx",
    ];
    const kullanan: string[] = [];
    const tara = (dizin: string) => {
      for (const ad of readdirSync(dizin)) {
        const tam = join(dizin, ad);
        if (statSync(tam).isDirectory()) {
          if (ad === "node_modules" || ad === ".next") continue;
          tara(tam);
          continue;
        }
        if (!ad.endsWith(".tsx") && !ad.endsWith(".ts")) continue;
        if (tam.endsWith("components/form.tsx")) continue;
        if (readFileSync(tam, "utf8").includes('from "@/components/form"')) {
          kullanan.push(tam.slice(KOK.length + 1));
        }
      }
    };
    tara(join(KOK, "app"));
    tara(join(KOK, "components"));
    expect(kullanan.sort()).toEqual(BEKLENEN);
  });
});
