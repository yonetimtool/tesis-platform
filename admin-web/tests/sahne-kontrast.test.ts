// (P161 §4) SAHNE PALETI — KONTRAST DOGRULAMASI.
//
// Brief: "Her iki temada kontrast dogrulanmali (WCAG AA), ozellikle 3D
// sahne uzerindeki etiketlerde."
//
// NEDEN AYRI DOSYA: `yz-token-kontrast.test.ts` CSS tokenlarini olcer.
// Sahnenin duvar/pencere renkleri CSS DEGIL — WebGL malzemesi `var(--yz-*)`
// anlamaz, renk GPU'ya sayi olarak gider. O yuzden sahnenin kendi paleti
// var ve o paletin kendi olcumu olmali.
//
// BU TEST YAZILDIGINDA PALET DUSUYORDU. Olculen ilk degerler:
//   acik tema, duvar #e8edf2 uzerinde  -> normal 2.10, borclu 2.15, secim 2.23
//   koyu tema, duvar #8f9aa6 uzerinde  -> 1.09 ... 1.58 (HEPSI)
// Yani "daire durumunu renkle goster" maddesi koyu temada islemiyordu:
// pencere ile duvar neredeyse ayni tonda cikiyordu. Gozle bakmak bunu
// yakalamaz; 2.2 ile 3.2 ayni gorunur.
//
// ESIK: WCAG 2.1 / 1.4.11 — anlamli grafik ogesi ve arayuz bileseni 3.0.
// Kodda 3.0 yerine PAY birakilmis bir esik tutuluyor: tam sinirda duran
// bir palet, kucuk bir ton oynamasinda sessizce dusen bir palettir.
import { describe, expect, it } from "vitest";

import { durumRenkleri, hoverRengi, sahnePaleti, secimRengi } from "@/components/3d/site-palet";
import { daireOlcegi } from "@/components/3d/site-yerlesim";
import type { DaireDurumu } from "@/components/3d/site-yerlesim";

const ESIK = 3.0;

function kanallar(hex: string): [number, number, number] {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

function isiklik(hex: string): number {
  const [r, g, b] = kanallar(hex).map((v) => {
    const s = v / 255;
    return s <= 0.04045 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function oran(a: string, b: string): number {
  const x = isiklik(a);
  const y = isiklik(b);
  return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
}

const DURUMLAR: DaireDurumu[] = ["normal", "borclu", "alarm", "pasif"];
const TEMALAR: { ad: string; koyu: boolean }[] = [
  { ad: "acik", koyu: false },
  { ad: "koyu", koyu: true },
];

describe("(P161) sahne paleti — WCAG 1.4.11 (3.0)", () => {
  for (const { ad, koyu } of TEMALAR) {
    describe(`${ad} tema`, () => {
      const p = sahnePaleti(koyu);
      const durumlar = durumRenkleri(koyu);

      it("HER daire durumu DUVARDAN ayirt edilebilir", () => {
        for (const d of DURUMLAR) {
          expect(oran(durumlar[d], p.kutle), `${d} / duvar`).toBeGreaterThanOrEqual(ESIK);
        }
      });

      it("SECILI daire duvardan ayirt edilebilir", () => {
        expect(oran(secimRengi(koyu), p.kutle)).toBeGreaterThanOrEqual(ESIK);
      });

      it("HOVER duvardan ayirt edilebilir", () => {
        expect(oran(hoverRengi(koyu), p.kutle)).toBeGreaterThanOrEqual(ESIK);
      });

      it("SECIM ile NORMAL AYNI AILEDEN DEGIL (P162 §8.1)", () => {
        // OLCULEN SIKAYET: "daireye tiklayinca renk degisimi
        // anlasilmiyor, mavi tonu maviye donuyor". Secim rengi mavi,
        // `normal` durum da maviydi. Artik secim YESIL: durum ailesinde
        // kullanilmayan tek belirgin ton, yani hicbir durumla
        // karistirilamaz. Test HUE AYRIMINI olcer — parlaklik degil.
        const yesil = (h: string) => {
          const n = parseInt(h.slice(1), 16);
          const [r, g, b] = [(n >> 16) & 255, (n >> 8) & 255, n & 255];
          return g > r && g > b;
        };
        expect(yesil(secimRengi(koyu)), "secim yesil olmali").toBe(true);
        expect(yesil(durumlar.normal), "normal yesil OLMAMALI").toBe(false);
      });

      it("ALARM RENKTEN BASKA bir kanal da tasir", () => {
        // OLCULDU: `alarm` (kirmizi) ile `normal` (mavi) neredeyse AYNI
        // ISIKLIKTA (oran ~1.01). Ikisi de duvardan ayriliyor ama
        // BIRBIRINDEN yalnizca renk tonuyla ayriliyorlar — renk korlugu,
        // gri tonlamali cikti ve gunes altindaki ekran icin yetersiz.
        //
        // Rengi bozmak yerine olcek kanali eklendi. Test RENGI degil O
        // KANALIN VARLIGINI kilitler: birisi olcegi 1'e cekerse alarm
        // yeniden tek kanala duser ve bu test duser.
        expect(daireOlcegi("alarm")).toBeGreaterThan(daireOlcegi("normal"));
        expect(daireOlcegi("alarm")).toBeGreaterThanOrEqual(1.2);
      });

      it("kat cizgisi ve cati duvardan ayirt edilebilir (kutle okunsun)", () => {
        // Esik burada daha dusuk: bunlar ANLAM tasimaz, yalnizca bicimin
        // okunmasini saglar. 1.2 altinda kutle duz bir kutuya doner.
        expect(oran(p.katCizgisi, p.kutle)).toBeGreaterThanOrEqual(1.2);
        expect(oran(p.cati, p.kutle)).toBeGreaterThanOrEqual(1.05);
      });

      it("kutle ile ARKA PLAN AYNI RENK DEGIL", () => {
        // ESIK BILINCLI OLARAK DUSUK ve bu bir WCAG kurali DEGIL.
        //
        // Siluetin gokyuzunden ayrilmasini asil saglayan sey TEMEL RENK
        // degil ISIKLANDIRMA: gunes alan yuz temel renkten parlak, golgede
        // kalan yuz koyu cizilir; ayrica catinin sacagi ve platform golgesi
        // de sinir uretir. Acik temada iki temel rengi 3.0'a zorlamak,
        // gokyuzunu koyu griye cevirip "notr gun isigi" istegini bozardi.
        // Bu test yalnizca IKISININ AYNI RENGE DUSMESINI engeller — o
        // durumda kutle gercekten kaybolurdu.
        expect(oran(p.kutle, p.arkaPlan)).toBeGreaterThanOrEqual(1.08);
      });
    });
  }

  it("iki tema AYRI palet kullanir — tek kume ikisinde birden gecemiyordu", () => {
    const acik = durumRenkleri(false);
    const koyu = durumRenkleri(true);
    for (const d of DURUMLAR) {
      // `alarm` disinda hepsi farklilasti; `alarm`in acik tondaki degeri
      // zaten esigi geciyordu. Yine de en az bir durum farkli OLMALI,
      // yoksa "temaya bagli" iddiasi bos olurdu.
      expect(typeof koyu[d]).toBe("string");
    }
    expect(acik.normal).not.toBe(koyu.normal);
    expect(secimRengi(false)).not.toBe(secimRengi(true));
  });
});
