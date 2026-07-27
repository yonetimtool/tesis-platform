// Panel i18n cekirdegi (tur 17).
//
// Panel tur 17'ye kadar TEK dilliydi (`<html lang="tr">`, Turkce sabitler,
// BFF'te sabit `Accept-Language: tr`). Bu dosya yeni sozlesmenin dort
// ayagini kilitler:
//   1. sozluk BUTUNLUGU — 7 dil, ayni anahtar kumesi, kopyalanmamis ceviri,
//   2. dil COZUMLEME — cookie > tarayici > tr, RFC 9110 q siralamasi,
//   3. KAYNAK taramasi — kabuk/giris yuzeyinde Turkce sabit kalmamis,
//   4. YON (RTL) — Arapcada `dir="rtl"` ve mantiksal kenarlar.
//
// Not: sozluk tipi `tr`den turer, yani EKSIK anahtar zaten derleme
// hatasidir (`npx tsc --noEmit`). Buradaki testler derleyicinin goremedigi
// seyleri olcer: cevirinin gercekten yapilip yapilmadigi, cozumleme ve
// kaynak sizintilari.
import fs from "node:fs";
import path from "node:path";

import { describe, expect, it } from "vitest";

import {
  DILLER,
  DIL_ADLARI,
  acceptLanguageCoz,
  istekDili,
  rtlMi,
  yon,
  type Dil,
} from "@/lib/i18n/diller";
import { SOZLUKLER } from "@/lib/i18n/sozluk";
import { tr } from "@/lib/i18n/sozluk/tr";

const KOK = path.resolve(__dirname, "..");

// YALNIZ Turkcede bulunan harfler. `ç/ö/ü` KASITLI olarak disarida:
// Almanca/Fransizca metinlerde de gecerler ve yanlis alarm uretirlerdi
// (mobil `ag_hatasi_i18n_test.dart` ile ayni gerekce).
const TR_HARF = /[ğışĞİŞ]/;

describe("sozluk butunlugu", () => {
  it("7 dilin hepsi var ve anahtar kumeleri AYNI", () => {
    expect(Object.keys(SOZLUKLER).sort()).toEqual([...DILLER].sort());
    const beklenen = Object.keys(tr).sort();
    for (const dil of DILLER) {
      expect(Object.keys(SOZLUKLER[dil]).sort(), dil).toEqual(beklenen);
    }
  });

  it("hicbir metin bos degil", () => {
    for (const dil of DILLER) {
      for (const [anahtar, metin] of Object.entries(SOZLUKLER[dil])) {
        expect(metin.trim(), `${dil}/${anahtar}`).not.toBe("");
      }
    }
  });

  it("ceviri GERCEKTEN yapilmis (TR kopyasi degil)", () => {
    // Bilincli istisnalar: marka adi ve dil secici basligi her dilde ayni.
    const istisna = new Set(["dilSeciciBaslik"]);
    for (const dil of DILLER) {
      if (dil === "tr") continue;
      for (const anahtar of Object.keys(tr) as (keyof typeof tr)[]) {
        if (istisna.has(anahtar)) continue;
        const metin = SOZLUKLER[dil][anahtar];
        expect(TR_HARF.test(metin), `${dil}/${anahtar}: ${metin}`).toBe(false);
      }
    }
  });

  it("yer tutucular tum dillerde AYNI", () => {
    const alanlar = (s: string) => (s.match(/\{(\w+)\}/g) ?? []).sort().join(",");
    for (const anahtar of Object.keys(tr) as (keyof typeof tr)[]) {
      const beklenen = alanlar(tr[anahtar]);
      for (const dil of DILLER) {
        expect(alanlar(SOZLUKLER[dil][anahtar]), `${dil}/${anahtar}`).toBe(beklenen);
      }
    }
  });

  it("dil adlari KENDI dilinde kalir (secici islevini yitirmesin)", () => {
    expect(DIL_ADLARI.tr).toBe("Türkçe");
    expect(DIL_ADLARI.ar).toBe("العربية");
    expect(DIL_ADLARI.ru).toBe("Русский");
    // 7 dilin hepsinde ayni ad — ceviri sozlugunde DEGILLER.
    for (const dil of DILLER) expect(DIL_ADLARI[dil].length).toBeGreaterThan(1);
  });
});

describe("dil cozumleme", () => {
  it.each<[string | null, Dil]>([
    [null, "tr"],
    ["", "tr"],
    ["ar", "ar"],
    ["ar-SA,ar;q=0.9,en;q=0.8", "ar"],
    // q siralamasi: once yazilan degil, q'su yuksek olan kazanir.
    ["en;q=0.3,ru;q=0.9", "ru"],
    // Desteklenmeyen diller atlanir.
    ["zz,it;q=0.9,de;q=0.5", "de"],
    ["zz", "tr"],
    ["*", "tr"],
    [";;;q=", "tr"],
  ])("Accept-Language %s -> %s", (header, beklenen) => {
    expect(acceptLanguageCoz(header)).toBe(beklenen);
  });

  it("KULLANICI SECIMI tarayici dilini EZER", () => {
    expect(istekDili("de", "ar,en;q=0.9")).toBe("de");
    // Gecersiz cookie degeri yok sayilir, tarayiciya duser.
    expect(istekDili("klingon", "ar,en;q=0.9")).toBe("ar");
    expect(istekDili(undefined, "ar")).toBe("ar");
    expect(istekDili(undefined, undefined)).toBe("tr");
  });
});

describe("yon (RTL)", () => {
  it("yalniz Arapca RTL", () => {
    for (const dil of DILLER) {
      expect(rtlMi(dil), dil).toBe(dil === "ar");
      expect(yon(dil), dil).toBe(dil === "ar" ? "rtl" : "ltr");
    }
  });

  it("kabuk YONE DUYARLI siniflar kullanir (sabit sol/sag YOK)", () => {
    // `left-0`/`pl-`/`border-r` gibi siniflar Arapcada kenar cubugunu
    // yanlis tarafa koyar; mantiksal karsiliklari (`start-`, `ps-`,
    // `border-e`) iki yonde de dogrudur.
    const kabuk = fs.readFileSync(path.join(KOK, "components/AppShell.tsx"), "utf8");
    const yasakli = /(^|\s|`)(left-0|right-0|pl-64|border-r\b|text-left)/;
    for (const satir of kabuk.split("\n")) {
      if (satir.trim().startsWith("//")) continue;
      expect(yasakli.test(satir), satir.trim()).toBe(false);
    }
  });
});

describe("kaynak taramasi — kabuk/giris yuzeyi", () => {
  // Bu turda cevrilen dosyalar. Kalan sayfalar sonraki turlarda eklenecek
  // (bkz. README "Kalan is" tablosu) — liste BILEREK dar tutuldu ki
  // "bitti" dedigimiz yuzey gercekten bitmis olsun.
  const CEVRILEN = [
    // tur 17 — kabuk/giris yuzeyi
    "components/AppShell.tsx",
    "components/ThemeToggle.tsx",
    "components/DilSecici.tsx",
    "components/ReportsTabs.tsx",
    "app/login/page.tsx",
    "app/layout.tsx",
    "lib/backend.ts",
    "lib/client.ts",
    "lib/fetcher.ts",
    "lib/roles.ts",
    // tur 18 — tamamlanan sayfalar
    "app/(protected)/audit/page.tsx",
    "app/(protected)/dashboard/page.tsx",
    "app/(protected)/notifications/page.tsx",
    "app/(protected)/settings/page.tsx",
    "app/(protected)/schematic/page.tsx",
    "app/(protected)/shifts/page.tsx",
    "app/(protected)/announcements/page.tsx",
    "app/(protected)/checkpoints/page.tsx",
    "app/(protected)/transparency/page.tsx",
  ];

  // MARKA KILIDI: "Yönetio" kelime isareti cevrilmez (mobil README §15 ile
  // ayni karar) — Turkce karakter tasir ama dile gore degismez.
  const MARKA = /^Yönetio$/;

  it("cevrilen dosyalarda TURKCE sabit kalmadi", () => {
    const TR = /[çğıöşüÇĞİÖŞÜ]/;
    const sizanlar: string[] = [];
    for (const dosya of CEVRILEN) {
      const govde = fs.readFileSync(path.join(KOK, dosya), "utf8");
      govde.split("\n").forEach((satir, i) => {
        const kod = satir.split("//")[0];
        // Yalniz STRING literalleri: yorumlar Turkce olabilir.
        for (const m of kod.matchAll(/"([^"\\\n]{2,})"|'([^'\\\n]{2,})'/g)) {
          const v = m[1] ?? m[2] ?? "";
          if (TR.test(v) && !MARKA.test(v)) sizanlar.push(`${dosya}:${i + 1} ${v}`);
        }
      });
    }
    expect(sizanlar).toEqual([]);
  });
});
