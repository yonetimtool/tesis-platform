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
import { taranacakDosyalar } from "./tarama";

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

  // (P126.7) TR HARF TARAMASININ DELIGI: `TR_HARF` yalniz Turkce'ye OZGU
  // harfleri (ç/ğ/ı/ö/ş/ü) ariyor. "Kamera ekleme mobil uygulamada yapilir"
  // gibi bir cumle o harflerin hicbirini tasimayabilir ve İngilizce
  // sozluge OLDUGU GIBI kopyalanmis olarak sessizce gecerdi. Bu olcum o
  // acigi kapatir: bir deger TR ile birebir AYNI ise ya bir kisaltma/
  // simge/es-sozcuktur (asagidaki liste) ya da CEVRILMEMISTIR.
  const AYNI_KALABILIR = new Set([
    // Kisaltma ve simgeler — cevrilmezler.
    "NFC", "NFC UID", "SMS", "PDF", "HH:MM", "—", "?", "Tenant ID",
    // Dil secici basligi bilincli olarak iki dilli.
    "Dil / Language",
    // Es-sozcukler: hedef dilde de AYNI yazilir (Almanca "Kamera",
    // Fransizca "Plan", Ispanyolca "Rol"...). Cevrilmediklerinden degil,
    // cevirileri ayni oldugundan buradalar.
    "Admin", "Platform Admin", "Endpoint", "Endpoint URL", "Foto", "Kamera",
    "Kanal", "Meta", "Model", "Net", "Plan", "Rol", "Telefon", "Tema", "Test",
    // (P160) Gorev gorunum sekmesi. "Liste" Almanca ve Fransizcada da
    // AYNI yazilir (de. "Liste", fr. "Liste"); ceviri eksigi degil
    // es-sozcuk. Ingilizce "List", Ispanyolca "Lista" — onlar farkli.
    "Liste",
    // (P131) Oynaticinin SECTIGI YOL — teknik kimlik, cumle degil.
    // "HLS" bir bicim adi, "hls.js" bir kutuphane adidir; ikisi de
    // cevrilmez. Etiketin varlik sebebi destek sorusudur ("bende
    // acilmiyor"): hangi yolun secildigini soyler.
    "HLS (hls.js)",
    // (P133.1) Kenar cubugu bolum basligi. "Platform" Ingilizce, Almanca
    // ve Fransizcada da ayni yazilir (Fr. "Plateforme" secildi, o farkli);
    // ceviri eksigi degil es-sozcuktur.
    "Platform",
    // (P160) NFC noktasi kolon basligi. "GPS" bir SISTEM ADIDIR
    // (Global Positioning System) ve yedi dilin hepsinde ayni harflerle
    // yazilir — Arapcada da Latin harfleriyle. Ceviri eksigi degil.
    "GPS",
    // (P166 §9) TELEFON YER TUTUCUSU BIR BICIM MASKESIDIR, cumle degil.
    // `05XX XXX XX XX` Turk cep numarasinin YAZIM KALIBIDIR; hedef dile
    // cevirmek (orn. `05XX XXX XX XX` yerine yerel bir kalip) numarayi
    // YANLIS gosterirdi — alan yine TR numarasi bekliyor. Kalibi ceviren
    // bir "duzeltme", kullaniciya olmayan bir bicimi ogretirdi.
    "05XX XXX XX XX",
    // (P167 §5) Rapor modalinin dosya bicimi dugmesi. "Excel" bir URUN
    // ADIDIR (Microsoft Excel) ve yedi dilin hepsinde ayni yazilir —
    // Arapcada da Latin harfleriyle, cunku dosya uzantisi ve program adi
    // cevrilmez. Kardesi "PDF" zaten kisaltma oldugu icin gecmisti;
    // ikisini ayri muamele etmek tutarsiz olurdu.
    "Excel",
    // (P133.2) Ozet cumlesinin yan cumle AYIRICISI. Ceviri degil NOKTALAMA:
    // Latin alfabesi kullanan dillerin hepsinde ", " — Arapca "، " ile
    // ayrildigi icin anahtar yine de sozlukte durur.
    ", ",
    // (P168 §4) "Port" bir PROTOKOL TERIMIDIR ve SMTP ayar ekranlarinda
    // Ingilizce/Almanca/Fransizca'da da "Port" yazilir. Cevirmek,
    // sunucusunu kuran kisinin tanidigi kelimeyi degistirmek olurdu.
    "Port",
    // "{n} SMS" — icindeki tek kelime SMS bir KISALTMADIR (Short Message
    // Service) ve yedi dilde de boyle gecer. Cumle degil, birim etiketi.
    "{n} SMS",
    // (P202) MAGAZA ADLARI MARKADIR ve cevrilmez: Apple ile Google bu
    // adlari yedi dilde de Latin harfleriyle boyle yazar (Arapca
    // arayuzlerinde bile). Cevirmek, kullanicinin telefonunda GORDUGU
    // simgeyle ekrandaki adi ayirmak olurdu — tam da "hangi magazaya
    // gidecegim" sorusunu bulaniklastirir.
    "iPhone (App Store)",
    "Android (Google Play)",
  ]);

  // KALAN ACIK (durustce): ne bu olcum ne `TR_HARF`, ic/ig/is harfi
  // tasimayan VE birebir ayni olmayan bir Turkce cumleyi (orn. tek kelime
  // degistirilmis bir kopya) yakalar. Iki tarama birlikte pratikteki
  // vakalarin cogunu kapatir; geri kalani goz denetimidir.
  it("TR ile BIREBIR AYNI kalan deger ya kisaltmadir ya HATA", () => {
    const supheli: string[] = [];
    for (const dil of DILLER) {
      if (dil === "tr") continue;
      for (const anahtar of Object.keys(tr) as (keyof typeof tr)[]) {
        const metin = SOZLUKLER[dil][anahtar];
        if (metin === tr[anahtar] && !AYNI_KALABILIR.has(metin)) {
          supheli.push(`${dil}/${String(anahtar)}: ${metin}`);
        }
      }
    }
    expect(
      supheli,
      `TR kopyasi olabilir:\n${supheli.join("\n")}`,
    ).toEqual([]);
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

describe("VARSAYILAN DIL TURKCE — Ingilizce bir tercih sayilmaz", () => {
  // URUN KARARI (P126 sonrasi): Chrome/Edge kurulumlarinin cogu kullanici
  // hicbir sey secmemisken bile `en-US,en;q=0.9` gonderir. Turkiye'deki bir
  // sakinin tarayicisi da bunu gonderiyor ve app.* Ingilizce aciliyordu.
  // `en` bir TERCIH degil KURULUM VARSAYILANI sayilir; digerleri sayilmaz.
  it("SADECE Ingilizce isteyen tarayici TURKCE gorur", () => {
    expect(acceptLanguageCoz("en-US,en;q=0.9")).toBe("tr");
    expect(acceptLanguageCoz("en")).toBe("tr");
    expect(acceptLanguageCoz("en-GB,en-US;q=0.9,en;q=0.8")).toBe("tr");
  });

  it("CEREZ YOKKEN Ingilizce baslikla istek TURKCE cizilir (uctan uca)", () => {
    // `istekDili` kok duzenin (`app/layout.tsx`) kullandigi ayni islev:
    // `<html lang>`, yon ve sozluk bundan turuyor.
    expect(istekDili(undefined, "en-US,en;q=0.9")).toBe("tr");
  });

  it("DIGER bes dil ACIK bir sinyaldir ve KORUNUR", () => {
    expect(acceptLanguageCoz("ar-SA,ar;q=0.9")).toBe("ar");
    expect(acceptLanguageCoz("ru-RU,ru;q=0.9")).toBe("ru");
    expect(acceptLanguageCoz("de-DE,de;q=0.9")).toBe("de");
    expect(acceptLanguageCoz("fr-FR,fr;q=0.9")).toBe("fr");
    expect(acceptLanguageCoz("es-ES,es;q=0.9")).toBe("es");
  });

  it("Ingilizce ONDE olsa bile GERCEK tercih kazanir", () => {
    // `en-US,ar;q=0.9`: kullanici Arapca'yi EKLEMIS. Ingilizce atlanir.
    expect(acceptLanguageCoz("en-US,ar;q=0.9")).toBe("ar");
    expect(acceptLanguageCoz("en,de;q=0.5")).toBe("de");
  });

  it("KULLANICI SECIMI her seyi ezer — Ingilizce dahil", () => {
    // Ingilizce isteyen kullanici onu SECEBILIR; kural yalniz TARAYICI
    // basligini reddeder, kullaniciyi degil.
    expect(istekDili("en", "tr-TR,tr;q=0.9")).toBe("en");
  });

  it("desteklenmeyen dil TURKCE'ye duser", () => {
    expect(acceptLanguageCoz("ja-JP,ja;q=0.9")).toBe("tr");
    expect(acceptLanguageCoz("")).toBe("tr");
    expect(acceptLanguageCoz(null)).toBe("tr");
  });
});

describe("yon (RTL)", () => {
  it("yalniz Arapca RTL", () => {
    for (const dil of DILLER) {
      expect(rtlMi(dil), dil).toBe(dil === "ar");
      expect(yon(dil), dil).toBe(dil === "ar" ? "rtl" : "ltr");
    }
  });

  // (P138.2) KILIDIN KAPSAMI SAYFALARA GENISLETILDI.
  //
  // Bu kilit YALNIZ `AppShell.tsx`i okuyordu. 45 korumali sayfa
  // DENETIMSIZDI ve iclerinde yon-sabit siniflar vardi — ozellikle
  // tablolarin sayi sutunlarindaki `text-right`. Arapcada bunlarin
  // hicbiri donmez: sayi sutunu yanlis tarafa yaslanir.
  //
  // Olculdu ve duzeltildi: `text-left`/`text-right` -> `text-start`/
  // `text-end` (cogu ortak tablo ilkeline tasinirken `hizala="end"`e
  // dondu), `ml-/mr-` -> `ms-/me-`, `left-N/right-N` -> `start-N/end-N`.
  it("SAYFALAR ve BILESENLER de yone duyarli (sabit sol/sag YOK)", () => {
    const yasakli =
      /(^|\s|`|")(text-left|text-right|ml-(\d+|auto)|mr-(\d+|auto)|left-\d|right-\d|border-l\b|border-r\b|pl-\d|pr-\d)/;
    const sizanlar: string[] = [];
    for (const yol of taranacakDosyalar(["app", "components"])) {
      const kaynak = fs.readFileSync(yol, "utf8");
      kaynak.split("\n").forEach((satir, i) => {
        // Yorum satirlari kapsam disi: kilidin GEREKCESI de bu sinif
        // adlarini anlatmak zorunda.
        if (/^\s*(\/\/|\*|\{\/\*)/.test(satir.trim())) return;
        // `dark:` onekli varyant ayni yon sorununu tasimaz (renk).
        const temiz = satir.replace(/dark:[a-z-]+\d*/g, "");
        if (yasakli.test(temiz)) sizanlar.push(`${yol}:${i + 1} ${satir.trim().slice(0, 70)}`);
      });
    }
    expect(sizanlar, `RTL'de donmeyen sinif:\n${sizanlar.join("\n")}`).toEqual([]);
  });

  // (P137 dersi) POZITIF KONTROL: desen GERCEKTEN atesliyor mu.
  it("POZITIF KONTROL: yon-sabit sinif YAKALANIR, mantiksal olan birakilir", () => {
    const yasakli =
      /(^|\s|`|")(text-left|text-right|ml-(\d+|auto)|mr-(\d+|auto)|left-\d|right-\d|border-l\b|border-r\b|pl-\d|pr-\d)/;
    expect(yasakli.test('<td className="text-right">')).toBe(true);
    expect(yasakli.test('<div className="ml-2">')).toBe(true);
    // Mantiksal karsiliklari RAHAT birakilir.
    expect(yasakli.test('<td className="text-end">')).toBe(false);
    expect(yasakli.test('<div className="ms-2">')).toBe(false);
    // `rounded-lg` ve `border-red` yon TASIMAZ — ilk olcumumde bunlari
    // yanlislikla saymistim (61 sanmistim, gercek sayi 9'du).
    expect(yasakli.test('<div className="rounded-lg border-red-200">')).toBe(false);
  });

  it("KABUK yone duyarli (sabit sol/sag YOK)", () => {
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

  // MARKA KILIDI: "Yönetiyor" kelime isareti cevrilmez (mobil README §15 ile
  // ayni karar) — Turkce karakter tasir ama dile gore degismez.
  // MARKA KILIDI: "Yönetiyor" kelime isareti cevrilmez (mobil README §15 ile
  // ayni karar). Satir icinde de gecebilir (`alt="Yönetiyor"`, logo yazisi) —
  // bu yuzden kalip TAM ESLESME degil, "Turkce karakteri YALNIZ marka
  // kelimesinden geliyor mu" testidir.
  const markaDisi = (v: string) =>
    v.replace(/Yönetiyor/gi, "").replace(/yönetiyor/g, "");
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
        // (P113) HUKUKI BELGELER — sozlugun kardesi, ARAYUZ dizgesi degil.
        //
        // `lib/hukuki/*` gizlilik politikasi ve kullanim kosullarinin YEDI
        // DILDEKI TAM METNIDIR ve tipi `Record<Dil, Belge>`dir: eksik bir
        // dil DERLENMEZ. Yani bu taramanin korudugu sey (bir dilde kalmis
        // metin) burada TIP SISTEMI tarafindan zaten engelleniyor.
        // Istisna olmasaydi tarama, dogru cevrilmis Turkce paragraflari
        // "sizinti" sayardi — sozlugun kendisi icin de ayni sebeple
        // istisna var.
        if (göreli.includes("lib/hukuki/")) continue;
        // (P127) TANITIM ICERIGI — hukuki belgelerin kardesi, ARAYUZ
        // dizgesi degil. `lib/tanitim/icerik.ts` pazarlama metninin YEDI
        // DILDEKI tam halidir ve tipi `Record<Dil, TanitimIcerik>`tir:
        // eksik bir dil DERLENMEZ. Yani bu taramanin korudugu sey (bir
        // dilde kalmis metin) burada TIP SISTEMI tarafindan zaten
        // engelleniyor; istisna olmasaydi tarama, dogru cevrilmis Turkce
        // paragraflari "sizinti" sayardi.
        //
        // ICERIGIN KENDISI OLCUSUZ DEGIL: `tests/tanitim-yuzeyi.test.ts`
        // her dilde tum alanlarin dolu oldugunu ve TR metninin baska dile
        // KOPYALANMADIGINI olcer.
        if (göreli.includes("lib/tanitim/")) continue;
        // (P168 §4.1) GSM-7 KARAKTER KUMESI — ARAYUZ METNI DEGIL, BIR
        // ALFABE TANIMI. `lib/sms-olcu.ts` SMS'in hangi karakterleri
        // 7 bitle kodlayabildigini tarif eder ve o kume standardin
        // (GSM 03.38) kendisidir: `Ä Ö Ñ Ü à é ...` orada BIRER VERI
        // NOKTASIDIR, kullaniciya gosterilen bir cumle degil.
        //
        // Cevrilmesi ANLAMSIZ olurdu — daha kotusu, cevrilse SAYAC
        // BOZULURDU: kume degisirse hangi mesajin 160, hangisinin 70
        // karakter oldugu yanlis hesaplanir ve kullanici faturayi
        // gonderdikten sonra ogrenir.
        if (göreli.includes("lib/sms-olcu")) continue;
        // (P206 §3.2) BANKA ADLARI — ARAYUZ METNI DEGIL, OZEL ISIM.
        //
        // `lib/iban.ts` IBAN banka kodu -> BANKANIN TESCILLI ADI
        // eslemesini tasir. "Ziraat Bankası" bir cumle degil, bir
        // KURUMUN ADIDIR ve hicbir dilde cevrilmez: Ingilizce arayuzde
        // de dekontta yazan sey odur. Cevirmek, kullanicinin ekranda
        // gordugu adla bankanin kendi adini AYIRMAK olurdu — ve
        // mutabakatta tam olarak bu iki adin ayni olmasi gerekiyor.
        //
        // KUME OLCUSUZ DEGIL: `tests/p206-iban.test.ts` kod -> ad
        // esdegerligini ve TR disinda banka UYDURULMADIGINI olcer.
        if (göreli.includes("lib/iban")) continue;
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
  // (P104) BFF ROTALARI — taramanin DORDUNCU kor noktasi.
  //
  // Yukaridaki taramalar `.tsx` okur; BFF rota islerleri `route.ts`tir ve
  // HIC taranmamisti. Oysa onlar kullaniciya DOGRUDAN metin dondurur
  // (`{error:{message}}`) ve giris rotasinda iki sabit Turkce metin
  // bulundu. Sunucuda `metin()` calismaz (cerez `document`tan okunur);
  // dogru arac `istekMetni(req, anahtar)`dir.
  it("BFF rotalarinda sabit hata metni YOK (P104)", () => {
    const sizanlar: string[] = [];
    const tara = (dizin: string) => {
      for (const ad of fs.readdirSync(path.join(KOK, dizin))) {
        const göreli = `${dizin}/${ad}`;
        const tam = path.join(KOK, göreli);
        if (fs.statSync(tam).isDirectory()) {
          tara(göreli);
          continue;
        }
        if (!ad.endsWith(".ts")) continue;
        fs.readFileSync(tam, "utf8")
          .split("\n")
          .forEach((satir, i) => {
            if (/^\s*(\/\/|\*)/.test(satir)) return;
            const m = /message:\s*"([^"]{2,})"/.exec(satir);
            if (m) sizanlar.push(`${göreli}:${i + 1} ${m[1].slice(0, 60)}`);
          });
      }
    };
    tara("app/api");
    expect(
      sizanlar,
      `BFF rotasinda sabit metin (istekMetni kullanin):\n${sizanlar.join("\n")}`,
    ).toEqual([]);
  });
  // (P105) HATA YEDEK METNI — `catch` icindeki son care.
  //
  // `err instanceof Error ? err.message : "Kaydedilemedi."` kalibi 26
  // yerde vardi ve yedek metin SABIT TURKCE'ydi. Yalniz Error OLMAYAN
  // bir firlatmada gorunur — nadir, ama nadir olmasi CEVRILMEMESINI
  // gerektirmez; ustelik nadir oldugu icin kimse fark etmez ve dil
  // degistiren kullanici tek bir Turkce cumleyle karsilasir.
  //
  // Kalip dar tutuldu: yalniz `: "..."` yedegi olan ucluler. `String(e)`
  // dali P60'ta ayrica ele alindi.
  it("catch yedek metinleri t() uzerinden gelir (P105)", () => {
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
            const m = /instanceof Error \?\s*\w+\.message\s*:\s*"([^"]{2,})"/.exec(
              satir,
            );
            if (m) sizanlar.push(`${göreli}:${i + 1} ${m[1].slice(0, 40)}`);
          });
      }
    };
    ["app", "components"].forEach(tara);
    expect(
      sizanlar,
      `cevrilmemis hata yedegi:\n${sizanlar.slice(0, 10).join("\n")}`,
    ).toEqual([]);
  });
});
