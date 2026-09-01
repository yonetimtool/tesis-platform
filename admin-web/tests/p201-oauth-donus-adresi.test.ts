// (P201) OAUTH DONUS ADRESI — YAPILANDIRMA ile KODUN SOZLESMESI.
//
// =========================================================================
// PROD'DA OLCULEN CIKMAZ
// =========================================================================
// Google ile yonetici kaydi donguye giriyordu. Prod izi:
//
//   POST /auth/oauth/baslat/google        200
//   GET  /auth/oauth/callback/google...   303
//   GET  /auth/oauth/saglayicilar         200   <- sayfa BASTAN yuklendi
//
// Arada `POST /auth/oauth/sonuc` YOK. Yani 303 kullaniciyi, sonuc
// kimligini COZEN bir sayfaya birakmiyordu.
//
// Kok neden KODDA DEGIL YAPILANDIRMADAYDI: `OAUTH_KAYIT_DONUS`
// `.../kayit` gosteriyordu (depodaki `.env.prod.example` da operatore
// bunu onermisti). `?oauth=<id>` parametresini cozen TEK sayfa
// `/giris/oauth`tur; `/kayit` onu okumaz.
//
// =========================================================================
// NEDEN ONCEKI TESTLER YAKALAMADI
// =========================================================================
// P198'in uctan uca testi `/kayit` sayfasini suruyor ama TARAYICININ
// SAGLAYICIDAN NASIL DONDUGUNU varsayiyor: sonucun `sessionStorage`da
// hazir oldugunu kabul ediyor. Yonlendirme HEDEFI ise koda degil
// ORTAM DEGISKENINE bagli — ve gelistirmede o degisken BOS (SSO kaydi
// dev'de hic calismiyor), yani dev'de olculmesi imkansizdi.
//
// Bu dosya bosluğu kapatir: donus adresi bir SOZLESMEDIR ve sozlesmenin
// iki tarafi (ornek yapilandirma + `?oauth=`i tuketen sayfalar) burada
// KARSILASTIRILIR.
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

const KOK = join(__dirname, "..", "..");

/** `?oauth=<id>` parametresini TUKETEN sayfalar (yol -> dosya). */
const TUKETEN_SAYFALAR: Record<string, string> = {
  "/giris/oauth": "admin-web/app/giris/oauth/page.tsx",
  // (P201) `/kayit` artik parametreyi DEVREDER; yanlis yapilandirilmis
  // bir kurulumda da kullanici cikmaza dusmesin diye.
  "/kayit": "admin-web/app/kayit/page.tsx",
};

function oku(gorece: string): string {
  return readFileSync(join(KOK, gorece), "utf8");
}

/** Bir metindeki `OAUTH_*_DONUS=<deger>` satirlarini toplar (yorumlu da). */
function donusDegerleri(metin: string): { anahtar: string; deger: string }[] {
  const bulunan: { anahtar: string; deger: string }[] = [];
  for (const satir of metin.split("\n")) {
    const e = /^\s*#?\s*(OAUTH_(?:WEB|KAYIT)_DONUS)=(\S+)\s*$/.exec(satir);
    if (e) bulunan.push({ anahtar: e[1], deger: e[2] });
  }
  return bulunan;
}

const KAYNAKLAR = [
  "infra/.env.example",
  "infra/.env.prod.example",
  "docs/oauth-kurulum.md",
];

describe("OAuth donus adresi", () => {
  it("her sayfa `?oauth=` parametresini GERCEKTEN okur", () => {
    // Liste bir IDDIA degil, dosyadan DOGRULANIR: sayfa parametreyi
    // okumayi birakirsa bu test duser ve asagidaki kilit bosa cikmaz.
    for (const [yol, dosya] of Object.entries(TUKETEN_SAYFALAR)) {
      const kaynak = oku(dosya);
      expect(kaynak, `${yol} -> ${dosya}`).toMatch(/["']oauth["']/);
    }
  });

  it("ORNEK YAPILANDIRMALARDAKI her donus adresi, TUKETEN bir sayfaya bakar", () => {
    let sayilan = 0;
    for (const kaynak of KAYNAKLAR) {
      for (const { anahtar, deger } of donusDegerleri(oku(kaynak))) {
        sayilan += 1;
        const yol = new URL(deger).pathname.replace(/\/$/, "");
        expect(
          Object.keys(TUKETEN_SAYFALAR),
          `${kaynak}: ${anahtar}=${deger} -> "${yol}" sonuc kimligini ` +
            "tuketen bir sayfa DEGIL; kullanici saglayicidan doner ve " +
            "kayda BASTAN baslar (prod'da olculen dongu)",
        ).toContain(yol);
      }
    }
    // Ornekler sessizce silinirse kilit bosa duserdi.
    expect(sayilan).toBeGreaterThanOrEqual(4);
  });

  it("KAYIT donusu ORNEKLERDE tanimli — eksikse SSO kaydi 503 doner", () => {
    for (const kaynak of ["infra/.env.example", "infra/.env.prod.example"]) {
      const anahtarlar = donusDegerleri(oku(kaynak)).map((d) => d.anahtar);
      expect(anahtarlar, kaynak).toContain("OAUTH_KAYIT_DONUS");
    }
  });
});
