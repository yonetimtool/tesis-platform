import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

/**
 * (P154 / Asama 3) WEB KAYIT SAYFASI YALNIZ IKI ROL SUNAR.
 *
 * Brief: web'de **Yonetici** ve **Denetci**; sakin / guvenlik / tesis
 * gorevlisi MOBILDE. Rol listesi bir GUVENLIK siniri degil (gercek kapi
 * "tesis ID + telefon onceden tanimli kayitla eslesiyor mu"), ama bir
 * URUN karari — ve urun kararlari da sessizce kaymamali.
 *
 * NEDEN KAYNAK TARAMASI: liste bir `useState` icinde degil, cizim
 * bloguna gomulu. Jsdom kurup dugmeleri saymak da olurdu; kaynak
 * taramasi ayni kurali saniyeler icinde ve kirilgan secici olmadan
 * olcuyor.
 */
const KAYNAK = readFileSync(
  new URL("../app/kayit/page.tsx", import.meta.url),
  "utf8",
);

describe("(P154) web kayit rolleri", () => {
  it("Rol tipi YALNIZ yonetici ve denetci", () => {
    const m = KAYNAK.match(/type Rol = ([^;]+);/);
    expect(m, "`type Rol` bulunamadi").not.toBeNull();
    const roller = m![1]
      .split("|")
      .map((s) => s.trim().replace(/"/g, ""))
      .sort();
    expect(roller).toEqual(["denetci", "yonetici"]);
  });

  it("MOBIL rolleri web'e sizmamis", () => {
    for (const mobil of ["resident", "security", "tesis_gorevlisi"]) {
      expect(KAYNAK, `${mobil} web kayit sayfasinda`).not.toContain(`"${mobil}"`);
    }
  });

  it("parola YALNIZ set-password ucuna gider", () => {
    // Parolayi kayit uclarindan birine gondermek, onu kod dogrulamadan
    // ONCE sunucuya tasimak olurdu.
    const baslaBlok = KAYNAK.slice(
      KAYNAK.indexOf("UC_BASLA, {"),
      KAYNAK.indexOf("})) as { tesis_ad"),
    );
    expect(baslaBlok).not.toContain("parola");
  });
});

/**
 * (P154 duzeltme turu) KIMLIK DOGRULAMA YONTEMI — brief §3.
 *
 * "Kimlik dogrulama yontemi, KULLANICININ SECIMI: (a) parola olustur
 * (b) Google (c) Microsoft (d) Apple." Onceki surumde secim YOKTU: akis
 * kimlik adimindan dogrudan paroladan devam ediyordu ve sosyal hesapla
 * kaydolmak yalnizca GIRIS ekranindan mumkundu.
 */
describe("(P154) kayit akisinda yontem secimi", () => {
  it("yontem AYRI bir adim ve sira brief'inki", () => {
    const m = KAYNAK.match(/type Adim = ([^;]+);/);
    expect(m, "`type Adim` bulunamadi").not.toBeNull();
    const adimlar = m![1].split("|").map((s) => s.trim().replace(/"/g, ""));
    // Tesis ID + telefon ("kimlik") YONTEMDEN ONCE gelir.
    expect(adimlar).toEqual(["rol", "kimlik", "yontem", "kod", "parola"]);
  });

  it("dort secenek de sunuluyor (parola + saglayici dugmeleri)", () => {
    const blok = KAYNAK.slice(
      KAYNAK.indexOf('{adim === "yontem" &&'),
      KAYNAK.indexOf('{adim === "kod" &&'),
    );
    expect(blok, "yontem adimi cizilmiyor").not.toBe("");
    // (a) parola
    expect(blok).toContain("kayitYontemParola");
    // (b/c/d) — saglayici dugmeleri TEK bilesenden gelir; listeyi
    // sunucu verir, bu yuzden burada bilesen aranir, marka adlari degil.
    expect(blok).toContain("<SosyalGiris");
  });

  it("SMS'i baslatan cagri yontem seciminden SONRA yapilir", () => {
    // Kimlik adimi `UC_BASLA`yi cagirsaydi, "Google" secen kullaniciya
    // once gereksiz bir kayit SMS'i giderdi (iki kod, tek telefon).
    const kimlik = KAYNAK.slice(
      KAYNAK.indexOf("function kimlikGonder"),
      KAYNAK.indexOf("async function parolaYolu"),
    );
    expect(kimlik).not.toContain("UC_BASLA");
    expect(kimlik).toContain('setAdim("yontem")');
  });

  it("sosyal dala girilen tesis ID + telefon TASINIR", () => {
    // Web'de saglayiciya tam yonlendirme var; donuste `/giris/oauth`
    // yeni bir agactir. Tasinmasaydi kullanici ayni iki alani ikinci
    // kez yazardi.
    const blok = KAYNAK.slice(
      KAYNAK.indexOf('{adim === "yontem" &&'),
      KAYNAK.indexOf('{adim === "kod" &&'),
    );
    expect(blok).toContain("kayitBilgisi=");
  });
});
