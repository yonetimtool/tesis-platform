// (P167 §2.1/§2.5) PANO TERCIHI — KUME duzeyinde.
//
// `pano.dom.test.ts` CIZIMI olcuyor; bu dosya cizimden ONCEKI kararlari:
// kayitli tercih varsayilanla nasil birlestiriliyor, gecersiz widget nasil
// eleniyor, sinir nerede uygulaniyor.
//
// EN PAHALI SONUCLAR:
//  1. YETKI SIZINTISI — kullanicinin erisemeyecegi bir sayfanin kisayolu.
//     Kayit ESKI kalabilir (rol degisir, sayfa kalkar); cizim gecerli
//     olani gostermek zorunda.
//  2. YENI BOLUMUN GORUNMEMESI — eski bir kayit "tam liste" sanilirsa,
//     sonradan eklenen bir bolum o kullanicilarda HIC cizilmez.
//  3. SESSIZ KAYIP — tanimadigi bir kimlik cizime girerse `undefined` bir
//     bilesen olur ve sayfa tamamen patlar.
import { describe, expect, it } from "vitest";

import {
  PANO_BOLUMLERI,
  WIDGET_SINIRI,
  bolumTanimli,
  bolumleriCoz,
  tercihGovdesi,
  widgetlariCoz,
} from "@/lib/pano-tercihi";

const IZINLI = ["/dues", "/finans", "/tasks", "/units", "/olaylar", "/kameralar"];
const VARSAYILAN = ["/dues", "/finans", "/tasks", "/units", "/olaylar", "/kameralar"];

describe("(P167 §2.5) bolum duzeni", () => {
  it("KAYIT YOKKEN varsayilan sira ve hepsi GORUNUR", () => {
    const b = bolumleriCoz(undefined);
    expect(b.map((x) => x.id)).toEqual(PANO_BOLUMLERI.map((x) => x.id));
    expect(b.every((x) => !x.gizli)).toBe(true);
  });

  it("KAYITTAKI SIRA korunur", () => {
    const b = bolumleriCoz({
      bolumler: [{ id: "takvim" }, { id: "widgetlar" }],
    });
    expect(b[0].id).toBe("takvim");
    expect(b[1].id).toBe("widgetlar");
  });

  it("KAYITTA OLMAYAN BOLUM SONA EKLENIR (yeni bolum kaybolmaz)", () => {
    // En pahali sessiz kusur: yeni bir bolum eklendiginde, eski kaydi
    // olan kullanicilar onu HIC gormez.
    const b = bolumleriCoz({ bolumler: [{ id: "takvim" }] });
    expect(b.length).toBe(PANO_BOLUMLERI.length);
    expect(b.map((x) => x.id)).toContain("finans");
  });

  it("TANINMAYAN KIMLIK ATILIR (cizim patlamaz)", () => {
    const b = bolumleriCoz({ bolumler: [{ id: "artik-yok" }, { id: "finans" }] });
    expect(b.map((x) => x.id)).not.toContain("artik-yok");
    expect(b.every((x) => bolumTanimli(x.id))).toBe(true);
  });

  it("GIZLI bayragi tasinir", () => {
    const b = bolumleriCoz({ bolumler: [{ id: "maket", gizli: true }] });
    expect(b.find((x) => x.id === "maket")?.gizli).toBe(true);
    // Kayitta olmayanlar GORUNUR gelir — "tercih yok" ile "gizledim"
    // ayri seylerdir.
    expect(b.find((x) => x.id === "finans")?.gizli).toBe(false);
  });

  it("(§2.4) VARSAYILANDA maket, finansin YANINDA ve UST SIRADA", () => {
    // Brief: "3D SITE MAKETI Sag UST tarafa alinacak." Iki YARIM bolum
    // yan yana cizildigi icin maket, widget seridinin hemen altinda sag
    // sutunda duruyor.
    const b = bolumleriCoz(undefined);
    const i = b.findIndex((x) => x.id === "finans");
    expect(b[i + 1].id).toBe("maket");
    expect(b[i].genislik).toBe("yarim");
    expect(b[i + 1].genislik).toBe("yarim");
    // Widget seridi ONLARDAN ONCE.
    expect(b.findIndex((x) => x.id === "widgetlar")).toBeLessThan(i);
  });

  it("(GENEL KISIT) mevcut islev KAYBOLMADI — devriye/KPI/kamera bolumleri VAR", () => {
    // Brief §2.5 bunlari saymiyor ama GENEL KISITLAR "mevcut islev
    // kaybolmayacak" diyor. Bolum olarak duruyorlar: gizlenebilir ve
    // siralanabilir, ama SILINMEDILER.
    const idler = bolumleriCoz(undefined).map((x) => x.id);
    expect(idler).toContain("devriye");
    expect(idler).toContain("kpi");
    expect(idler).toContain("kameralar");
  });
});

describe("(P167 §2.1) widget seridi", () => {
  it("KAYIT YOKKEN varsayilan kume (en cok ALTI)", () => {
    const w = widgetlariCoz(undefined, IZINLI, VARSAYILAN);
    expect(w.length).toBeLessThanOrEqual(WIDGET_SINIRI);
    expect(w).toEqual(VARSAYILAN.slice(0, WIDGET_SINIRI));
  });

  it("YETKISI OLMAYAN ROTA ELENIR (kayit eski kalmis olabilir)", () => {
    // En pahali sizinti: kullanicinin erisemeyecegi bir sayfanin
    // kisayolu. Kayit temizlenmeden onceki halinde kalir; cizim
    // GECERLI olani gostermek zorunda.
    const w = widgetlariCoz(
      { widgetlar: [{ rota: "/dues" }, { rota: "/yetki" }] },
      IZINLI,
      VARSAYILAN,
    );
    expect(w).toEqual(["/dues"]);
  });

  it("KAYITTAKI SIRA korunur", () => {
    const w = widgetlariCoz(
      { widgetlar: [{ rota: "/tasks" }, { rota: "/dues" }] },
      IZINLI,
      VARSAYILAN,
    );
    expect(w).toEqual(["/tasks", "/dues"]);
  });

  it("KAYIT VARSA eksik kalan VARSAYILANLA TAMAMLANMAZ", () => {
    // Tamamlasaydik, alti kisayoldan besini silen kullanici her acilista
    // silmediklerinin yanina yenilerinin geldigini gorurdu.
    const w = widgetlariCoz({ widgetlar: [{ rota: "/dues" }] }, IZINLI, VARSAYILAN);
    expect(w).toEqual(["/dues"]);
  });

  it("BOS KAYIT varsayilana duser (hepsini silmek DEGIL)", () => {
    // `widgetlar: []` "kayit yok" ile ayni ele alinir — kullanici
    // hepsini silmek isterse bolumu GIZLER.
    expect(widgetlariCoz({ widgetlar: [] }, IZINLI, VARSAYILAN).length).toBe(
      VARSAYILAN.length,
    );
  });

  it("ALTI SINIRI kayitta da uygulanir", () => {
    const cok = Array.from({ length: 10 }, (_, i) => ({ rota: IZINLI[i % IZINLI.length] }));
    expect(widgetlariCoz({ widgetlar: cok }, IZINLI, VARSAYILAN).length).toBe(
      WIDGET_SINIRI,
    );
  });
});

describe("(P167 §2.5) sunucuya yazilan govde", () => {
  it("hem widget hem bolum TEK kayitta", () => {
    const g = tercihGovdesi(["/dues"], bolumleriCoz(undefined));
    expect(g.widgetlar).toEqual([{ rota: "/dues" }]);
    expect(g.bolumler?.length).toBe(PANO_BOLUMLERI.length);
    expect(g.bolumler?.[0]).toEqual({ id: "widgetlar", gizli: false });
  });

  it("ALTI SINIRI govdede de uygulanir (sunucu 422 dondurmesin)", () => {
    const g = tercihGovdesi(
      Array.from({ length: 9 }, (_, i) => `/x${i}`),
      bolumleriCoz(undefined),
    );
    expect(g.widgetlar?.length).toBe(WIDGET_SINIRI);
  });
});
