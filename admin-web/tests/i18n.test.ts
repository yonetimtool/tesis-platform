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
    // tur 19
    "app/(protected)/patrol-plans/page.tsx",
    "app/(protected)/reports/tasks/page.tsx",
    "app/(protected)/reports/dues/page.tsx",
    "app/(protected)/reports/patrols/page.tsx",
    "app/(protected)/units/page.tsx",
    "app/(protected)/dues/page.tsx",
    "app/(protected)/support/page.tsx",
    // tur 20 — panel TAMAMLANDI
    "app/(protected)/assets/page.tsx",
    "app/(protected)/users/page.tsx",
    "app/(protected)/integrations/page.tsx",
    "app/(protected)/tasks/page.tsx",
    "app/(protected)/complaints/page.tsx",
    "app/(protected)/building-editor/page.tsx",
    "app/(protected)/tenants/page.tsx",
    "app/(protected)/tenants/[id]/page.tsx",
    "components/UnitDetail.tsx",
  ];

  // MARKA KILIDI: "Yönetio" kelime isareti cevrilmez (mobil README §15 ile
  // ayni karar) — Turkce karakter tasir ama dile gore degismez.
  // MARKA KILIDI: "Yönetio" kelime isareti cevrilmez (mobil README §15 ile
  // ayni karar). Satir icinde de gecebilir (`alt="Yönetio"`, logo yazisi) —
  // bu yuzden kalip TAM ESLESME degil, "Turkce karakteri YALNIZ marka
  // kelimesinden geliyor mu" testidir.
  const markaDisi = (v: string) =>
    v.replace(/Yönetio/gi, "").replace(/yönetio/g, "");
  const MARKA = { test: (v: string) => !/[çğıöşüÇĞİÖŞÜ]/.test(markaDisi(v)) };

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

  // TUR 21 — GOZLE SURUS DERSI. Panel 7 dilde gercekten calistirilinca
  // (login + her sayfa + her dil, SUNUCUNUN URETTIGI HTML incelendi) uc
  // Turkce paragraf ciktı. Sebep: onceki taramalar yalniz STRING
  // LITERALLERINE bakiyordu; JSX icindeki COK SATIRLI DUZ METIN ne tirnak
  // icindedir ne de tek satirda `>...<` kalibina uyar — yani gorunmezdi.
  //
  // Asagidaki tarama artik onu da olcuyor ve kalan is bir CIRCIR (ratchet)
  // ile kilitlendi: sayi ARTAMAZ. Kalan satirlar README'de dosya dosya
  // listeli; her turda bu esik dusurulerek sifira inilecek.
  const KALAN_ESIK = 0;   // tur 22: SIFIRA indi

  it("cok satirli JSX metni dahil HICBIR Turkce sabit kalmadi (tur 22)", () => {
    // Tur 20'de son sayfa da cevrildi; artik dosya listesi degil TUM kaynak
    // taranir. Yeni bir sayfa Turkce sabitle eklenirse bu test kirilir.
    const TR = /[çğıöşüÇĞİÖŞÜ]/;
    const sizanlar: string[] = [];
    const tara = (dizin: string) => {
      for (const ad of fs.readdirSync(path.join(KOK, dizin))) {
        const göreli = `${dizin}/${ad}`;
        const tam = path.join(KOK, göreli);
        if (fs.statSync(tam).isDirectory()) {
          tara(göreli);
          continue;
        }
        if (!/\.(tsx?|ts)$/.test(ad)) continue;
        if (göreli.includes("i18n/sozluk")) continue; // sozlugun KENDISI
        // Dil adlari HER ZAMAN kendi dilinde ("Türkçe", "Français") —
        // bilincli istisna, bkz. DIL_ADLARI.
        if (göreli.endsWith("i18n/diller.ts")) continue;
        fs.readFileSync(tam, "utf8")
          .split("\n")
          .forEach((satir, i) => {
            const kod = satir.split("//")[0];
            for (const m of kod.matchAll(/"([^"\\\n]{2,})"|'([^'\\\n]{2,})'/g)) {
              const v = m[1] ?? m[2] ?? "";
              if (TR.test(v) && !MARKA.test(v)) {
                sizanlar.push(`${göreli}:${i + 1} ${v}`);
              }
            }
            // COK SATIRLI JSX METNI (tur 21'de gozle surus bunu buldu):
            // string literali DEGIL, dogrudan JSX icindeki duz metin. Satir
            // ne `"` ne `'` icerir; `>` ve `<` de baska satirlardadir —
            // dolayisiyla yukaridaki literal taramasi ONU HIC GORMEZ.
            const cipl = kod
              .replace(/<[^>]*>/g, " ")
              .replace(/\{[^}]*\}/g, " ")
              .trim();
            if (TR.test(cipl) && !MARKA.test(cipl)) {
              sizanlar.push(`${göreli}:${i + 1} (JSX metni) ${cipl.slice(0, 60)}`);
            }
          });
      }
    };
    ["app", "components", "lib"].forEach(tara);
    // Circir: yeni Turkce metin EKLENEMEZ; mevcutlar tur tur eritilir.
    expect(
      sizanlar.length,
      `kalan ${sizanlar.length} satir:\n${sizanlar.slice(0, 10).join("\n")}`,
    ).toBeLessThanOrEqual(KALAN_ESIK);
  });

  // (P46) BILDIRIM (toast) METINLERI — taramanin KOR NOKTASIYDI.
  //
  // Yukaridaki taramalar JSX metin dugumlerine, gorunen ozniteliklere ve
  // (tur 22) TUM kaynaktaki Turkce sabitlere bakiyor. Ama son tarama
  // TURKCE HARFE bakar: `toast.success("Assignment saved.")` gibi
  // Turkce-harfsiz bir sabit gorunmezdi. Olculdu: panelde 10 sabit
  // bildirim metni vardi (dokuzu Turkce oldugu icin tur 22 taramasinin
  // ESIGINE takiliyordu ama esik "circir" oldugundan gecmisti).
  //
  // Bu olcum DILDEN BAGIMSIZDIR: bildirim metni tirnak icinde ise
  // sizintidir, hangi dilde oldugu fark etmez. Kullanicinin gordugu SON
  // mesaj en cok fark edilen yerdir.
  it("bildirim (toast) metinleri t() uzerinden gelir (P46)", () => {
    const sizanlar: string[] = [];
    const tara = (dizin: string) => {
      for (const ad of fs.readdirSync(path.join(KOK, dizin))) {
        const göreli = `${dizin}/${ad}`;
        const tam = path.join(KOK, göreli);
        if (fs.statSync(tam).isDirectory()) {
          tara(göreli);
          continue;
        }
        if (!/\.tsx?$/.test(ad)) continue;
        fs.readFileSync(tam, "utf8")
          .split("\n")
          .forEach((satir, i) => {
            const m = /toast\.[a-z]+\(\s*["\'`]([^"\'`]{2,})/.exec(satir);
            if (m) sizanlar.push(`${göreli}:${i + 1} (toast) ${m[1].slice(0, 60)}`);
          });
      }
    };
    ["app", "components"].forEach(tara);
    expect(
      sizanlar,
      `cevrilmemis bildirim metni:\n${sizanlar.slice(0, 10).join("\n")}`,
    ).toEqual([]);
  });
  // (P54) TARAYICI DIYALOGLARI — taramanin IKINCI kor noktasi.
  //
  // `window.confirm/alert/prompt` metni JSX degildir, oznitelik degildir
  // ve P46 taramasi YALNIZ `toast.*`a bakiyordu. Olculdu: panelde
  // **sekiz** sabit Turkce onay diyalogu vardi ("... silinsin mi?") ve
  // ingilizce arayuzde bile Turkce cikiyordu. Bunlar SILME onaylaridir:
  // anlasilmayan bir metne "Tamam" demek, kullanicinin okuyamadigi bir
  // uyariyi onaylamasi demektir — sinifin en pahali ornegi.
  it("tarayici diyaloglari (confirm/alert/prompt) t() uzerinden gelir (P54)", () => {
    const sizanlar: string[] = [];
    const tara = (dizin: string) => {
      for (const ad of fs.readdirSync(path.join(KOK, dizin))) {
        const göreli = `${dizin}/${ad}`;
        const tam = path.join(KOK, göreli);
        if (fs.statSync(tam).isDirectory()) {
          tara(göreli);
          continue;
        }
        if (!/\.tsx?$/.test(ad)) continue;
        fs.readFileSync(tam, "utf8")
          .split("\n")
          .forEach((satir, i) => {
            const m = /window\.(confirm|alert|prompt)\(\s*["\'`]([^"\'`]{2,})/.exec(
              satir,
            );
            if (m) {
              sizanlar.push(`${göreli}:${i + 1} (${m[1]}) ${m[2].slice(0, 60)}`);
            }
          });
      }
    };
    ["app", "components"].forEach(tara);
    expect(
      sizanlar,
      `cevrilmemis diyalog metni:\n${sizanlar.slice(0, 10).join("\n")}`,
    ).toEqual([]);
  });
  // (P69) SABLON DIZGESI ICINDEKI METIN — taramanin UCUNCU kor noktasi.
  //
  // P68'de bulundu: bir baslik `` `Yönetici ${i + 1}` `` diye yaziliydi ve
  // UC tarama da goremedi — JSX metin dugumu degil (sablon dizgesi),
  // gorunen oznitelik degil, ve P54'un taramasi yalniz `window.*`
  // diyaloglarina bakiyor. Kullanici arayuz dilini degistirdiginde o
  // baslik Turkce kaliyordu.
  //
  // KURAL: yorumlar ve sinif dizgeleri disinda, icinde ${'$'}{...} disi
  // BOSLUKLU METIN gecen sablon dizgesi sizintidir. URL/yol kaliplari
  // (bosluk icermez) dogal olarak elenir.
  it("sablon dizgelerinde sabit metin YOK (P69)", () => {
    const harf = /[A-Za-zÇĞİÖŞÜçğıöşü]{3}/;
    const sizanlar: string[] = [];
    const tara = (dizin: string) => {
      for (const ad of fs.readdirSync(path.join(KOK, dizin))) {
        const göreli = `${dizin}/${ad}`;
        const tam = path.join(KOK, göreli);
        if (fs.statSync(tam).isDirectory()) {
          tara(göreli);
          continue;
        }
        if (!ad.endsWith(".tsx")) continue;
        // YORUMLAR SILINIR ama SATIR SAYISI KORUNUR: kilidin kendi
        // gerekcesi de bu kalibi anlatmak zorunda ve kendi aciklamasina
        // takilan bir kilit yazilamaz.
        const kaynak = fs
          .readFileSync(tam, "utf8")
          .replace(/\/\*[\s\S]*?\*\//g, (m) => m.replace(/[^\n]/g, " "));
        kaynak.split("\n").forEach((satir, i) => {
          if (/^\s*\/\//.test(satir)) return;
          if (/className|class=/.test(satir)) return;
          // COK SATIRLI SABLON: satirdaki ters tirnak sayisi TEK ise
          // dizge bu satirda bitmiyor demektir ve satir icinde eslesen
          // "cift", aslinda IKI AYRI dizgenin parcalari olur. Olculdu:
          // dar kural `/api/...?limit=${x}` gibi coksatirli URL'leri
          // sizinti sayiyordu.
          if ((satir.match(/`/g) ?? []).length % 2 !== 0) return;
          // TARAYICI ONYUKLEME BETIGI: `layout.tsx` icindeki tema betigi
          // METIN DEGIL KOD tasir (`dangerouslySetInnerHTML`); cevrilecek
          // bir sey yok.
          if (/dangerouslySetInnerHTML|localStorage\.getItem/.test(satir)) return;
          // IC ICE SABLON: `` `...${x ? `...` : ""}` `` gibi satirlarda
          // ters tirnaklar SATIR ICINDE eslesir ama dogru eslesmez —
          // tarama satir tabanlidir ve ic ice dizgeleri ayristiramaz.
          // KILIDIN SINIRI BUDUR ve gizlenmiyor: bu satirlar URL ya da
          // durum SIMGESI kurar, cevrilecek metin tasimaz.
          if (/\$\{[^}]*`/.test(satir)) return;
          for (const m of satir.matchAll(/`([^`]*)`/g)) {
            const duz = m[1].replace(/\$\{[^}]*\}/g, "").trim();
            if (!harf.test(duz)) continue;
            if (!/\s/.test(duz)) continue; // url/yol/jeton — bosluk icermez
            sizanlar.push(`${göreli}:${i + 1} ${duz.slice(0, 50)}`);
          }
        });
      }
    };
    ["app", "components"].forEach(tara);
    expect(
      sizanlar,
      `sablon dizgesinde sabit metin:\n${sizanlar.slice(0, 10).join("\n")}`,
    ).toEqual([]);
  });
});
