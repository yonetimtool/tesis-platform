// (P175) DERLEME VE CALISMA ANI DIS BAGIMLILIKLARI.
//
// =========================================================================
// OLCULEN OLAY
// =========================================================================
// Test sunucusunda derleme TAMAMEN kirildi:
//   request to https://fonts.googleapis.com/... failed, EAI_AGAIN
//   next/font error: Failed to fetch `Inter` from Google Fonts
//
// Bir yapi adiminin, KOD DEGISMEMISKEN disaridaki bir servisin o anki
// durumuna gore basarisiz olmasi kabul edilemez.
//
// NOT — CALISMA ANI ZATEN TEMIZDI: `next/font/google` yaziyi derleme
// aninda indirip KENDI kokenimizden servis ediyordu; kullanicinin
// tarayicisindan Google'a istek gitmiyordu. Yani degisen sey gizlilik
// degil AG BAGIMSIZLIGI. Bu test ikisini de kilitliyor.
import { describe, expect, it } from "vitest";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";

import { taranacakKaynaklar } from "./tarama";

describe("yazi tipi YEREL", () => {
  it("`next/font/google` HICBIR YERDE ithal edilmiyor", () => {
    const ihlal: string[] = [];
    for (const [dosya, kaynak] of taranacakKaynaklar(["app", "components"], [
      ".tsx",
      ".ts",
    ])) {
      // Yorumda gecmesi serbest — orada NEDEN kaldirildigi yaziyor.
      if (/from\s+["']next\/font\/google["']/.test(kaynak)) ihlal.push(dosya);
    }
    expect(
      ihlal,
      `derlemeyi aga baglar:\n${ihlal.join("\n")}`,
    ).toEqual([]);
  });

  it("woff2 dosyalari DEPODA ve yedi alt kume de var", () => {
    const gerekli = [
      "latin", "latin-ext", "vietnamese",
      "greek", "greek-ext", "cyrillic", "cyrillic-ext",
    ];
    for (const a of gerekli) {
      const yol = `public/fonts/inter-${a}.woff2`;
      expect(existsSync(yol), `eksik: ${yol}`).toBe(true);
      // Bos ya da bozuk bir dosya, testi yesil birakip ekrani bozardi.
      expect(statSync(yol).size, yol).toBeGreaterThan(5000);
    }
  });

  it("ALT KUME BOLUNMESI KORUNDU — her kuralin `unicode-range`i var", () => {
    // Bolunme kaybolursa Turkce bir kullanici 213 KB'in TAMAMINI indirir.
    // `next/font/local` bu yuzden secilmedi: `src` dizisinde per-dosya
    // `unicode-range` kabul etmiyor.
    const css = readFileSync("app/yazi-tipi.css", "utf8");
    const kurallar = css.match(/@font-face\s*\{[^}]*\}/g) ?? [];
    const altKumeler = kurallar.filter((k) => k.includes("/fonts/"));
    expect(altKumeler).toHaveLength(7);
    for (const k of altKumeler) {
      expect(k, k.slice(0, 80)).toMatch(/unicode-range:/);
    }
    // YEDEK OLCULERI: duzen kaymasini (CLS) azaltiyor; `next/font` bunu
    // kendiliginden uretiyordu, elle yazarken atlamak gorunmez bir
    // gerileme olurdu.
    expect(css).toContain("size-adjust:");
    expect(css).toContain("ascent-override:");
  });

  it("LISANS DEPODA (SIL OFL 1.1 — yeniden dagitim serbest)", () => {
    const lisans = readFileSync("public/fonts/OFL.txt", "utf8");
    expect(lisans).toContain("SIL Open Font License");
    expect(lisans).toContain("Inter Project Authors");
  });
});

describe("calisma ani dis kaynaklar", () => {
  it("derlenmis CSS'te Google Fonts referansi YOK", () => {
    // Kullanici IP'sinin ucuncu tarafa aktarilmadiginin KANITI.
    const dizin = ".next/static/css";
    if (!existsSync(dizin)) return; // derleme yoksa atla
    for (const d of readdirSync(dizin).filter((x) => x.endsWith(".css"))) {
      const css = readFileSync(`${dizin}/${d}`, "utf8");
      expect(css, d).not.toMatch(/fonts\.(googleapis|gstatic)\.com/);
    }
  });

  it("BILINEN dis kaynaklar YALNIZ bu listede", () => {
    // Yeni bir CDN/betik/varlik eklendiginde bu test kirilir ve karar
    // GOZDEN GECIRILIR — sessizce ucuncu tarafa istek acilmasin.
    // Her giris, ISTEK GERCEKTEN GIDIYOR MU sorusunu acikca yanitlar —
    // "kodda gecen adres" ile "kullanicidan cikan istek" ayni sey degil.
    const izinli = new Map<string, string>([
      [
        "tile.openstreetmap.org",
        "ISTEK GIDER (NFC/plan haritalari). Kullanicinin tarayicisindan; " +
          "IP + bakilan koordinat OSM'e ulasir. `NEXT_PUBLIC_KARO_URL` ile " +
          "kendi karo sunucumuza cevrilebilir — KVKK icin onerilen yol.",
      ],
      [
        "www.google.com",
        "ISTEK GITMIYOR: `SiteHarita` bugun HICBIR ekranda cizilmiyor " +
          "(P167'de Ozet'ten kaldirildi, bilesen bilerek korundu). " +
          "Cizildigi gun Google Maps iframe'i kullanicinin tarayicisindan " +
          "yuklenir ve IP ucuncu tarafa gider — O GUN karar gozden " +
          "gecirilmeli. Bugun ise yalniz olu bir kod yolu.",
      ],
      [
        "www.openstreetmap.org",
        "ISTEK GITMIYOR: ayni bilesenin anahtarsiz gomulu harita yolu. " +
          "Yukaridakiyle ayni kosul gecerli.",
      ],
      [
        "youtube.com",
        "ISTEK GITMIYOR: kamera adresi DOGRULAMASINDA kullanilan bir " +
          "REDDETME listesi — YouTube bir yayin akisi degil web sayfasi " +
          "oldugu icin adres GECERSIZ sayilir. Adres hicbir zaman " +
          "cagrilmaz.",
      ],
      [
        "play.google.com",
        "Magaza baglantisi. Kullanici TIKLAMADAN istek gitmez.",
      ],
      [
        "apps.apple.com",
        "Magaza baglantisi. Kullanici TIKLAMADAN istek gitmez.",
      ],
    ]);

    const desen = /https:\/\/([a-z0-9.-]+\.[a-z]{2,})/g;
    // Kendi alan adlarimiz ve ornek/yer tutucu adresler sayilmaz.
    // (P181 Böl.0) `yonetiyor` KENDI KANONIK adresimiz (tanitim/kayit —
    // yonetiyor.com/yonetici/kayit). Ucuncu taraf degil; adres politikasinda
    // kanonik alan adi. `yonetio` yalniz `.site` alt alanlarini eslestiriyordu.
    const bizim = /yonetio|yonetiyor|ynetiyor|example|ornek|localhost|w3\.org|schema\.org|github\.com|openstreetmap\.org\/copyright/;
    const bulunan = new Set<string>();
    for (const [dosya, kaynak] of taranacakKaynaklar(
      ["app", "components", "lib"],
      [".tsx", ".ts", ".css"],
    )) {
      if (dosya.includes("/tests/")) continue;
      for (const m of kaynak.matchAll(desen)) {
        const konak = m[1];
        if (bizim.test(konak)) continue;
        bulunan.add(konak);
      }
    }
    const beklenmeyen = [...bulunan].filter((k) => !izinli.has(k));
    expect(
      beklenmeyen,
      "GOZDEN GECIRILMEMIS dis kaynak — istemeden ucuncu tarafa istek " +
        `aciliyor olabilir:\n${beklenmeyen.join("\n")}`,
    ).toEqual([]);
  });
});
