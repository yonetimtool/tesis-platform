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
 * (P155r2) KAYIT SIRASI — sartname §2.
 *
 * "Kullanıcıya önce sosyal hesapla kayıt önerilir … ROL SEÇİMİNDEN
 * SONRA." Yani yontem, tesis/telefon alanlarindan ONCE gelir. P154'te
 * sira `rol -> kimlik -> yontem` idi; sosyal hesapla kaydolmak isteyen
 * kisi once iki alan doldurmak zorundaydi.
 */
describe("(P155r2) kayit akisinda sira ve yontem secimi", () => {
  it("sira sartnamenin sirasi: rol -> yontem -> bilgiler -> role ozel", () => {
    const m = KAYNAK.match(/type Adim = ([^;]+);/);
    expect(m, "`type Adim` bulunamadi").not.toBeNull();
    const adimlar = m![1].split("|").map((s) => s.trim().replace(/"/g, ""));
    expect(adimlar).toEqual([
      "rol",
      "yontem",
      "bilgiler",
      "rolOzel",
      "kod",
      "sonuc",
    ]);
  });

  it("yontem adimi ROL'DEN HEMEN SONRA gelir", () => {
    // Rol dugmesi dogrudan yonteme goturmeli; araya bir alan girseydi
    // sartnamenin sirasi bozulurdu.
    const rolBlok = KAYNAK.slice(
      KAYNAK.indexOf('{adim === "rol" &&'),
      KAYNAK.indexOf('{adim === "yontem" &&'),
    );
    expect(rolBlok).toContain('setAdim("yontem")');
  });

  it("SOSYAL ONCE, elle kayit SONRA sunulur (sartname §2 duzeni)", () => {
    const blok = KAYNAK.slice(
      KAYNAK.indexOf('{adim === "yontem" &&'),
      KAYNAK.indexOf('{adim === "bilgiler" &&'),
    );
    expect(blok, "yontem adimi cizilmiyor").not.toBe("");
    // Saglayici dugmeleri TEK bilesenden gelir; listeyi sunucu verir, bu
    // yuzden burada bilesen aranir, marka adlari degil.
    expect(blok).toContain("<SosyalGiris");
    expect(blok).toContain("kayitYontemEposta");
    // SOSYAL ONDE: sartname once sosyali oneriyor, ayirac sonra geliyor.
    expect(blok.indexOf("<SosyalGiris")).toBeLessThan(
      blok.indexOf("kayitYontemEposta"),
    );
  });

  it("SMS'i baslatan cagri BILGILER adiminda DEGIL, 4. adimda yapilir", () => {
    // Bilgiler adimi `UC_BASLA`yi cagirsaydi, tesis kodu daha girilmeden
    // eslesme denenirdi.
    const bilgiler = KAYNAK.slice(
      KAYNAK.indexOf("function bilgileriGonder"),
      KAYNAK.indexOf("async function rolOzelGonder"),
    );
    expect(bilgiler).not.toContain("UC_BASLA");
    expect(bilgiler).toContain('setAdim("rolOzel")');
  });

  it("sosyal dala secilen ROL tasinir", () => {
    // Web'de saglayiciya tam yonlendirme var; donuste `/giris/oauth`
    // yeni bir agactir. Rol tasinmasaydi kullanici kayda bastan baslardi.
    // (Tesis/telefon ARTIK TASINMIYOR: yeni sirada saglayiciya onlar
    // girilmeden ONCE gidiliyor.)
    const blok = KAYNAK.slice(
      KAYNAK.indexOf('{adim === "yontem" &&'),
      KAYNAK.indexOf('{adim === "bilgiler" &&'),
    );
    expect(blok).toContain("kayitRolu={rol}");
  });

  it("saglayicidan DONUSTE ad soyad ON-DOLDURULUR", () => {
    // Sartname §2: "sağlayıcıdan gelen ad soyad … FORMA OTOMATİK DOLAR".
    expect(KAYNAK).toContain("kayitSosyalSonucOku");
    expect(KAYNAK).toContain("if (s.ad) setAd(s.ad)");
  });
});

/**
 * (P155r2 §3) YONETICI SELF-SIGNUP — tesis panelden acilir.
 */
describe("(P155r2) yonetici tesis acar", () => {
  it("tesis olusturma ucu KULLANILIYOR", () => {
    expect(KAYNAK).toContain('"/api/auth/kayit/tesis-olustur"');
  });

  it("DENETCI tesis ACAMAZ — yalniz yonetici", () => {
    // Denetci bir tesise ATANIR, tesis kurmaz.
    const m = KAYNAK.match(/const tesisAcar = ([^;]+);/);
    expect(m, "`tesisAcar` bulunamadi").not.toBeNull();
    expect(m![1]).toContain('rol === "yonetici"');
  });

  it('"Zaten bir sitem var" tesis kodu yoluna gecirir', () => {
    expect(KAYNAK).toContain("kayitZatenSitemVar");
    expect(KAYNAK).toContain("setKatil(true)");
  });

  it("uretilen TESIS KODU gosterilir ve kopyalanabilir", () => {
    // Sartname §4: SMS saglayicisi baglanana kadar yonetici kodu ELLE
    // iletecek; kod gorunur ve kopyalanabilir olmali.
    expect(KAYNAK).toContain("kayit-uretilen-kod");
    expect(KAYNAK).toContain("kayitKopyala");
    expect(KAYNAK).toContain("writeText");
  });

  it("PAROLA IKI KEZ SORULMAZ — ayri parola adimi YOK", () => {
    // Kod dogrulaninca `set-password` OTOMATIK cagrilir; kullaniciya az
    // once yazdigi parola tekrar sorulmaz.
    const kodGonder = KAYNAK.slice(
      KAYNAK.indexOf("async function kodGonder"),
      KAYNAK.indexOf("function geri()"),
    );
    expect(kodGonder).toContain("UC_PAROLA");
    const m = KAYNAK.match(/type Adim = ([^;]+);/);
    expect(m![1]).not.toContain("parola");
  });
});
