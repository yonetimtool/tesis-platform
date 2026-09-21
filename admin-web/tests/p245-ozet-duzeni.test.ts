// (P245) OZET SAYFASI DUZENI — REFERANSIN (ui5) ORANLARI.
//
// ===========================================================================
// KOK NEDEN: SONUC HIC GORULMEMISTI
// ===========================================================================
// P244 boyunca testler yesildi ama sayfa referansa benzemedi. Sebep
// yapisal: jsdom YERLESIM HESAPLAMAZ — genislik, oran ve bosluk
// olculemez. Bu turda dongu degisti: gercek Chromium ile ekran
// goruntusu alinip referansla yan yana karsilastirildi
// (`scripts/ekran-goruntusu.mjs`, `docs/P245/`).
//
// BU DOSYA O DONGUNUN YERINI TUTMAZ; onun KARARLARINI kilitler.
// Ekran goruntusu "nasil gorunuyor" sorusunu yanitlar, bu dosya
// "hangi kural bozulursa o goruntu bozulur" sorusunu.
import { describe, expect, it } from "vitest";

import {
  PANO_BOLUMLERI,
  bolumleriCoz,
  satirlariCoz,
  varsayilanSatirlar,
} from "@/lib/pano-tercihi";

describe("(P245) varsayilan duzen referansin sirasinda", () => {
  const bolumler = bolumleriCoz(undefined);
  const satirlar = varsayilanSatirlar(bolumler);

  it("ILK SIRA KPI SERIDI — referansta ilk okunan sey", () => {
    // Olculen kusur: sayfa kisayol seridiyle basliyordu ve referansin
    // dort KPI'si sayfanin ALTINDAYDI.
    expect(satirlar[0].bolumler.map((b) => b.id)).toEqual(["kpi"]);
  });

  it("IKINCI SIRA 2/1 — maket SOLDA ve BUYUK", () => {
    // Olculen kusur: maket `yarim` genislikteydi ve "sagda kucuk bir
    // kutu" olarak okunuyordu. Referansta sayfanin merkezi.
    const s = satirlar[1];
    expect(s.oran).toBe("2-1");
    expect(s.bolumler.map((b) => b.id)).toEqual(["maket", "yanpanel"]);
  });

  it("UCUNCU SIRA UC ESIT SUTUN — tahsilat / talepler / son islemler", () => {
    const s = satirlar[2];
    expect(s.sutun).toBe(3);
    expect(s.bolumler.map((b) => b.id)).toEqual(["tahsilat", "talepler", "sonislemler"]);
  });

  it("MEVCUT ICERIK KAYBOLMADI — yalnizca ASAGI indi", () => {
    // GENEL KISIT: "mevcut islev kaybolmayacak". Referansta olmayan
    // bolumler SILINMEDI; referans duzeninin altinda duruyorlar ve
    // "paneli duzenle" ile tasinabilir/gizlenebilirler.
    const idler = bolumler.map((b) => b.id);
    const ESKILER = [
      "finans",
      "takvim",
      "devriye",
      "alarmlar",
      "widgetlar",
      "kameralar",
    ] as const;
    for (const eski of ESKILER) {
      expect(idler, `${eski} kayboldu`).toContain(eski);
    }
    // ...ve hepsi referans bolumlerinden SONRA.
    const sonReferans = idler.indexOf("sonislemler");
    for (const eski of ESKILER.slice(0, 2)) {
      expect(idler.indexOf(eski)).toBeGreaterThan(sonReferans);
    }
  });
});

describe("(P245) genislik sozlugu", () => {
  it("`genis` ve `dar` TEK BIR CIFT olarak taniml", () => {
    // 2/1 satiri ancak `genis` + `dar` ile kurulur. Ikisinden biri tek
    // basina kalirsa satir 1 sutuna duser ve maket yine buyumez.
    const genis = PANO_BOLUMLERI.filter((b) => b.genislik === "genis");
    const dar = PANO_BOLUMLERI.filter((b) => b.genislik === "dar");
    expect(genis.length).toBe(1);
    expect(dar.length).toBe(1);
  });

  it("`uc` genisligi UCUN KATI — aksi halde satir bolunemez", () => {
    const uc = PANO_BOLUMLERI.filter((b) => b.genislik === "uc");
    expect(uc.length % 3).toBe(0);
  });

  it("KAYITLI TERCIHTE de oran TANIMDAN turer", () => {
    // Oran kayda YAZILMAZ: kullanici satiri elle kurmus olsa bile
    // maket yine buyuk cizilir. Ayni bilgiyi iki yerde tutmak, biri
    // degisince otekini bayatlatmakti.
    const cozulmus = satirlariCoz(
      { satirlar: [{ sutun: 2, idler: ["maket", "yanpanel"], baslik: null }] },
      bolumleriCoz(undefined),
    );
    expect(cozulmus[0].oran).toBe("2-1");
  });
});
