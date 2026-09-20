// (P244 §6c) KAYIT BASINA KART YIGINI — YAPISAL YASAK.
//
// ===========================================================================
// OLCULEN DESEN
// ===========================================================================
// Uc ekran (`arac-gecisleri`, `olaylar`, `ziyaretciler`) ayni seyi
// yapiyordu: liste kaydini `kayitlar.map(... => <Kart>)` ile AYRI BIR
// KART olarak alt alta diziyordu.
//
// Neden kusur: bu kayitlar TEKRARLI ve KISA ALANLI (tarih, ad, daire,
// durum). Kart dili her kayda bir baslik seviyesi ve bir kenarlik verir;
// ekrana dort kayit sigar. Tablo ayni alanda yirmi bes kayit gosterir ve
// goz sutunlari takip eder.
//
// Kart YANLIS bir bilesen degil — YANLIS YERDE kullanilmisti. Kart, her
// ogesi FARKLI yapida olan seyler icindir (blok karti, kamera karosu,
// duyuru). Tekrarli satir tablodur.
//
// ===========================================================================
// NEDEN METIN TARAMASI
// ===========================================================================
// "Ekran bos gorunuyor" gorsel bir yargidir ve jsdom onu olcemez. Ama
// DESEN yapisaldir ve kaynakta gorunur: bir listeyi `map` edip `<Kart`
// dondurmek. Tarama bugun yazilmamis bir ekrani da yarin yakalar.
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

const KOK = join(__dirname, "..");

/**
 * ISTISNA LISTESI — kart dilinin DOGRU oldugu ekranlar.
 *
 * Her satir bir GEREKCE tasir; gerekcesiz istisna, kurali sessizce
 * bosaltmanin en kolay yoludur.
 */
const ISTISNALAR: Record<string, string> = {
  // Sakinler BLOKLARA GORE gruplu: her kart bir BLOK, icindeki liste
  // sakinler. Gruplama sayfanin var olma sebebi (P220 §4).
  "residents/page.tsx": "kart = blok grubu, kayit degil",
  // Kameralar: her karo bir CANLI GORUNTU tasiyor — tekrarli metin degil.
  "kameralar/page.tsx": "kart = kamera karosu (gorsel)",
  // Bina duzenleme: her kart bir BLOK (ad + sayi + eylemler).
  "building-editor/page.tsx": "kart = blok karti",
  // Ozet sayfasi: bolumler farkli yapida, tekrarli kayit degil.
  "dashboard/page.tsx": "kart = pano bolumu",
  // Duyuru/etkinlik UZUN ICERIK tasir (`govde`, `whitespace-pre-line`) —
  // referans da bunlari zengin ICERIK KARTI olarak ciziyor. Uzun metni
  // tablo hucresine sikistirmak onu okunmaz yapardi.
  "duyurular/page.tsx": "kart = uzun icerikli duyuru",
  "etkinlikler/page.tsx": "kart = uzun icerikli etkinlik",
  // Rezervasyon YONETIMI'nde kart bir REZERVASYON degil ORTAK ALAN
  // tanimidir (ad + aktiflik + kural). Referansta da "alan kartlari".
  "rezervasyon-yonetimi/page.tsx": "kart = ortak alan tanimi",
  // Sikayet haritasinda kart bir BLOK (icinde daire izgarasi).
  "schematic/page.tsx": "kart = blok grubu",
  // Gorev panosunda kart bir SURUKLENEBILIR GOREV KARTI (kanban) —
  // tabloya cevirmek surukle-birakin kendisini oldururdu.
  "tasks/page.tsx": "kart = kanban gorev karti",
  // Tesis ayarlarinda kart bir AYAR GRUBU (icinde alanlar).
  "tesis-ayarlari/page.tsx": "kart = ayar grubu",
  // Yonetim iletisiminde kart bir KISI KARTVIZITI: ad + telefon + rol,
  // uc-dort satirlik bir kimlik bloku ve tiklanabilir `tel:` baglantisi.
  "yonetim-iletisim/page.tsx": "kart = kisi kartviziti",
};

/**
 * BORC — kural ihlali ama HENUZ duzeltilmedi.
 *
 * Istisnadan FARKI: burada kart YANLIS yerde. Listeye yazilmalarinin
 * sebebi, duzeltmenin bu turun kapsami disinda olmasi (P244 asama 8:
 * operasyon ve iletisim turlari).
 *
 * LISTE TAM ESLESIR: biri duzeltilince buradan SILINMELI (yoksa liste
 * bayatlar), yeni biri eklenince test DUSER. Yani borc ne sessizce
 * buyuyebilir ne de sessizce unutulabilir.
 */
// (P244 §8a) BORC KAPANDI: ucu de tabloya tasindi. Liste BOS birakildi,
// SILINMEDI — iddia "bugun borc yok" olarak KALIR ve yeni bir kart
// yigini eklenirse test duser.
const BORC: string[] = [];

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

/** `xxx.map((y) => ( <Kart` deseni — arada bos satir/boşluk olabilir. */
const DESEN = /\.map\(\s*\(?\s*\w+[^)]*\)?\s*=>\s*\(?\s*<Kart\b/;

describe("(P244 §6c) kayit basina kart yigini", () => {
  const liste = sayfalar();

  it("TARAMA gercekten sayfa buluyor (vakum degil)", () => {
    expect(liste.length).toBeGreaterThan(50);
    // Desen GERCEKTEN eslesiyor mu — sahte kaynakta dogrulanir.
    expect(DESEN.test("{kayitlar.map((o) => (\n  <Kart key={o.id}>")).toBe(true);
    expect(DESEN.test("{kayitlar.map((o) => (\n  <tr key={o.id}>")).toBe(false);
  });

  it("HICBIR sayfa liste kaydini KART olarak dizmiyor", () => {
    const suclular: string[] = [];
    for (const p of liste) {
      const gorece = p.slice(join(KOK, "app", "(protected)").length + 1);
      if (ISTISNALAR[gorece]) continue;
      if (DESEN.test(readFileSync(p, "utf8"))) suclular.push(gorece);
    }
    expect(
      suclular.sort(),
      `kayit basina kart dizen sayfa (borc listesi disinda):\n${suclular.join("\n")}`,
    ).toEqual([...BORC].sort());
  });

  it("ISTISNALARIN HEPSI HALA VAR (bayat liste birikmesin)", () => {
    // Silinmis bir dosya icin istisna tutmak, listeyi zamanla anlamsiz
    // bir birikime cevirir.
    for (const yol of Object.keys(ISTISNALAR)) {
      expect(() =>
        statSync(join(KOK, "app", "(protected)", yol)),
        `istisna listesinde olmayan dosya: ${yol}`,
      ).not.toThrow();
    }
  });
});
