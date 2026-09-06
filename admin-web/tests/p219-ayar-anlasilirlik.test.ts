// (P219 §1) AYAR ETIKETLERI — SONUC ODAKLI ve BIRIMLI.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// Etiketler teknik ve deger ile anlam ayrisiyordu. En keskin ornek
// eskalasyon esigi:
//
//     ayar=1 -> ILK eskalasyon 2. uyarida     (olculdu)
//     ayar=2 -> ILK eskalasyon 3. uyarida
//
// Ekranda "1" yazan alan aslinda "2. uyarida" demekti; ipucu bunu bir
// dipnotla telafi etmeye calisiyordu. Kullanici hakli olarak "1 kez
// polis mi cagrilacak" diye okuyordu.
//
// Bu dosya, ETIKETLERIN KENDISINI olcer: her ayarin bir grubu, her sayi
// alaninin bir birimi, her ipucunun somut bir sonuc cumlesi var mi.
// Bir metnin "anlasilir" olup olmadigini test edemem — ama YAPISAL
// eksikleri (birimsiz sayi, gruba girmemis ayar, ipucusuz alan)
// edebilirim ve kusur tam olarak orada baslamisti.
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

import { AYAR_GRUPLARI, OPERASYON } from "@/lib/tesis-ayar-alanlari";

const KOK = resolve(__dirname, "..");
const DILLER = ["tr", "en", "ar", "ru", "de", "fr", "es"];

/** Bir dilin sozlugunden anahtar -> metin. */
function sozluk(dil: string): Record<string, string> {
  const ham = readFileSync(resolve(KOK, `lib/i18n/sozluk/${dil}.ts`), "utf8");
  const d: Record<string, string> = {};
  for (const m of ham.matchAll(/^ {2}([a-zA-Z0-9_]+): "((?:[^"\\]|\\.)*)",$/gm)) {
    d[m[1]] = m[2];
  }
  return d;
}

const TR = sozluk("tr");

describe("(P219 §1) her ayar bir gruba ait", () => {
  it("GRUPSUZ ayar YOK", () => {
    // Gruplama olmadan on bes ayar tek sutunda diziliyordu ve
    // yonetici aradigini bulmak icin hepsini okumak zorundaydi.
    const grupsuz = OPERASYON.filter((a) => !a.grup).map((a) => a.anahtar);
    expect(grupsuz).toEqual([]);
  });

  it("TANIMSIZ gruba ait ayar YOK", () => {
    const bilinen = new Set(AYAR_GRUPLARI.map((g) => g.id));
    const kacak = OPERASYON.filter((a) => !bilinen.has(a.grup)).map((a) => a.anahtar);
    expect(kacak).toEqual([]);
  });

  it("BOS grup YOK — her baslik en az bir ayar tasir", () => {
    const bos = AYAR_GRUPLARI.filter(
      (g) => !OPERASYON.some((a) => a.grup === g.id),
    ).map((g) => g.id);
    expect(bos).toEqual([]);
  });
});

describe("(P219 §1) etiket ve açıklama kalitesi", () => {
  it("HER ayarın etiketi 7 DİLDE var", () => {
    const eksik: string[] = [];
    for (const dil of DILLER) {
      const d = sozluk(dil);
      for (const a of OPERASYON) {
        if (!d[a.etiket]) eksik.push(`${dil}:${a.etiket}`);
        if (a.ipucu && !d[a.ipucu]) eksik.push(`${dil}:${a.ipucu}`);
      }
      for (const g of AYAR_GRUPLARI) {
        if (!d[g.baslik]) eksik.push(`${dil}:${g.baslik}`);
      }
    }
    expect(eksik).toEqual([]);
  });

  it("HER ayarın bir AÇIKLAMASI var (bool alanlar dahil)", () => {
    // Aciklamasiz bir ayar, kullaniciyi tahmine birakir.
    const ipucusuz = OPERASYON.filter((a) => !a.ipucu).map((a) => a.anahtar);
    expect(ipucusuz).toEqual([]);
  });

  it("SAYI alanlarının etiketinde BİRİM ya da SORU var", () => {
    // "Tur gecikme toleransı (dk)" -> "Tur başlamazsa kaç dakika sonra
    // uyarılsın". Ikisi de birimi soyluyor; olculen sey birimin
    // GORUNMESI, hangi bicimde yazildigi degil.
    const BIRIM = /dakika|gün|metre|ay|kaç|kaçıncı|\(dk\)|\(m\)/i;
    const birimsiz = OPERASYON.filter(
      (a) => a.tip === "sayi" && !BIRIM.test(TR[a.etiket] ?? ""),
    ).map((a) => `${a.anahtar}: "${TR[a.etiket]}"`);
    expect(birimsiz).toEqual([]);
  });

  it("AÇIKLAMALAR yeterince SOMUT (en az bir tam cümle)", () => {
    const kisa = OPERASYON.filter((a) => (TR[a.ipucu ?? ""] ?? "").length < 40)
      .map((a) => `${a.anahtar}: "${TR[a.ipucu ?? ""]}"`);
    // `gurultu_uyari_metni` istisna: "Boş bırakırsanız hazır metin
    // kullanılır." kisa AMA tam — uzatmak gurultu olurdu.
    expect(kisa.filter((x) => !x.startsWith("gurultu_uyari_metni"))).toEqual([]);
  });
});

describe("(P219 §1) eskalasyon eşiği — değer ile anlam hizalı", () => {
  it("ETIKET 'kaçıncı uyarı' diye SORUYOR", () => {
    // Eski etiket "Güvenliğe eskalasyon eşiği" idi: "eşik" kelimesi
    // sayinin neyi saydigini soylemiyordu.
    expect(TR["ayarGurultuEskalasyon"]).toMatch(/kaçıncı uyarı/i);
  });

  it("AÇIKLAMA ne olacağını SOMUT anlatıyor", () => {
    const ipucu = TR["ayarGurultuEskalasyonIpucu"] ?? "";
    expect(ipucu).toMatch(/güvenli/i);        // kime gidiyor
    expect(ipucu).toMatch(/polis/i);          // ne yapiyor
    expect(ipucu).toMatch(/2 yazarsanız/i);   // ORNEKLE anlatiyor
  });

  it("SAYIM PENCERESI ile KARISTIRILMAMASI için açıklamada uyarı var", () => {
    // Sayac penceresi (gun) ile haritada gorunme suresi FARKLI seyler;
    // ikisi de "gurultu" grubunda ve yan yana duruyor.
    expect(TR["ayarGurultuPencereIpucu"]).toMatch(/harita/i);
  });
});

describe("(P219 §2) harita süresi — GÖRÜNÜRLÜK, veri silme DEĞİL", () => {
  it("ayar VAR ve gürültü grubunda (sayım penceresiyle YAN YANA)", () => {
    const harita = OPERASYON.find((a) => a.anahtar === "sikayet_harita_saat");
    expect(harita, "harita süresi ayarı yok").toBeTruthy();
    expect(harita!.grup).toBe("gurultu");
    // Sayim penceresi de ayni grupta: yonetici ikisini bir arada gorup
    // farki anlasin.
    expect(OPERASYON.find((a) => a.anahtar === "gurultu_pencere_gun")!.grup)
      .toBe("gurultu");
  });

  it("`0` (süresiz) KABUL EDİLİYOR — kapatılabilir olmalı", () => {
    // Haftada bir sikayet gelen kucuk bir sitede 24 saatlik pencere
    // haritayi surekli bos gosterir ve harita islevini yitirir.
    const harita = OPERASYON.find((a) => a.anahtar === "sikayet_harita_saat")!;
    expect(harita.min).toBe(0);
  });

  it("AÇIKLAMADA 'sil' kelimesi GEÇMİYOR, 'silinmez' GEÇİYOR", () => {
    // Istegin acik sarti: bu bir gorunurluk filtresi, veri silme degil
    // ve arayuz bunu yanlis anlatmamali.
    const ipucu = TR["ayarHaritaSaatIpucu"] ?? "";
    expect(ipucu).toMatch(/SİLİNMEZ|silinmez/);
    // "silinir/silinecek" gibi bir ifade OLMAMALI.
    expect(ipucu).not.toMatch(/silinir|silinecek|silin(ecek|ir)/i);
  });

  it("AÇIKLAMA sayaç penceresinden AYRI olduğunu SÖYLÜYOR", () => {
    // Iki sure karistirilmasin: biri saat (gorunurluk), oteki gun
    // (esik mantigi).
    const ipucu = TR["ayarHaritaSaatIpucu"] ?? "";
    expect(ipucu).toMatch(/sayaç|sayacı/i);
    expect(ipucu).toMatch(/kaç gün geriye/i);
  });

  it("AÇIKLAMA neyin ETKİLENMEDİĞİNİ sayıyor", () => {
    const ipucu = TR["ayarHaritaSaatIpucu"] ?? "";
    for (const yer of [/liste/i, /rapor/i, /sayac|sayaç/i]) {
      expect(ipucu).toMatch(yer);
    }
  });
});
