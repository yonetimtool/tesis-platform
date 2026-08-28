import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

/**
 * (P185 §2/§3/§6) WEB KAYIT SAYFASI — E-POSTA DOGRULAMALI, SMS'SIZ.
 *
 * Brief: web'de **Yonetici** ve **Denetci**; sakin / guvenlik / tesis
 * gorevlisi MOBILDE. Rol listesi bir GUVENLIK siniri degil ama bir URUN
 * karari — ve urun kararlari sessizce kaymamali.
 *
 * P185 SMS/telefon-baglama akisini ("Baglama istegi gecersiz" kaynagi)
 * kaldirdi: her yol E-POSTA dogrulamasina dayanir. Telefon HÂLÂ bir alan
 * (arka uc yoneticiden iletisim numarasi ister) ama ARTIK bir giris
 * anahtari degil ve hicbir yerde SMS/telefon-kodu adimi YOK.
 *
 * NEDEN KAYNAK TARAMASI: akis bir `useState` icinde degil, cizim bloguna
 * gomulu. Kaynak taramasi kirilgan secici olmadan kurali olcer.
 */
const KAYNAK = readFileSync(
  new URL("../app/kayit/page.tsx", import.meta.url),
  "utf8",
);
const OAUTH = readFileSync(
  new URL("../app/giris/oauth/page.tsx", import.meta.url),
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
});

/**
 * (P185) KAYIT SIRASI — sartname §2.
 *
 * Sira: rol -> YONTEM -> bilgiler -> [yonetici: SECIM] -> role ozel -> kod.
 * Yontem, rol seciminden HEMEN SONRA gelir.
 */
describe("(P185) kayit akisinda sira ve yontem secimi", () => {
  it("Adim tipi yeni akisi tasir (secim + onay var, SMS ozel adimi yok)", () => {
    const m = KAYNAK.match(/type Adim = ([^;]+);/);
    expect(m, "`type Adim` bulunamadi").not.toBeNull();
    const adimlar = m![1].split("|").map((s) => s.trim().replace(/"/g, ""));
    // Yonetici secimi (yeni/katil) ve onay-bekliyor ekrani yeni akisin
    // parcasi; hepsi tanimli olmali.
    for (const beklenen of ["rol", "yontem", "bilgiler", "secim", "rolOzel", "kod", "onay", "sonuc"]) {
      expect(adimlar, `${beklenen} adimi eksik`).toContain(beklenen);
    }
  });

  it("yontem adimi ROL'DEN HEMEN SONRA gelir", () => {
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
    expect(blok).toContain("<SosyalGiris");
    expect(blok).toContain("kayitYontemEposta");
    expect(blok.indexOf("<SosyalGiris")).toBeLessThan(
      blok.indexOf("kayitYontemEposta"),
    );
  });

  it("sosyal dala secilen ROL tasinir", () => {
    const blok = KAYNAK.slice(
      KAYNAK.indexOf('{adim === "yontem" &&'),
      KAYNAK.indexOf('{adim === "bilgiler" &&'),
    );
    expect(blok).toContain("kayitRolu={rol}");
  });

  it("saglayicidan DONUSTE ad soyad ON-DOLDURULUR", () => {
    expect(KAYNAK).toContain("kayitSosyalSonucOku");
    expect(KAYNAK).toContain("if (s.ad) setAd(s.ad)");
  });
});

/**
 * (P185 §2/§6) SMS TAMAMEN KALDIRILDI — her yol e-posta dogrulamali.
 */
describe("(P185) SMS/telefon-baglama kaldirildi", () => {
  it("kayit sayfasi ESKI SMS uclarini KULLANMIYOR", () => {
    for (const eski of [
      "kayit/rol-basla",
      "kayit/rol-dogrula",
      "oauth/baglan/basla",
      "oauth/baglan/dogrula",
    ]) {
      expect(KAYNAK, `${eski} hâlâ kayit sayfasinda`).not.toContain(eski);
    }
  });

  it("giris/oauth SMS baglama formunu ICERMIYOR", () => {
    for (const eski of ["oauth/baglan/basla", "oauth/baglan/dogrula"]) {
      expect(OAUTH, `${eski} hâlâ giris/oauth'ta`).not.toContain(eski);
    }
    // Tesis+telefon+SMS adimlari kaldirildi.
    expect(OAUTH).not.toContain('"tesis"');
    expect(OAUTH).not.toContain("tesisGonder");
  });

  it("giris/oauth BAGLI DEGIL durumunda KAYDA yonlendirir (SMS sormaz)", () => {
    expect(OAUTH).toContain("kayit_gerekli");
    expect(OAUTH).toContain('router.replace("/kayit")');
  });
});

/**
 * (P185 §3) YONETICI ICIN EXPLICIT SECIM — yeni tesis / mevcuda katil.
 */
describe("(P185) yonetici yeni tesis / katil secimi", () => {
  it("SECIM adimi iki net secenek sunar (link degil)", () => {
    const blok = KAYNAK.slice(
      KAYNAK.indexOf('{adim === "secim" &&'),
      KAYNAK.indexOf('{adim === "rolOzel" &&'),
    );
    expect(blok).toContain("kayit-secim-yeni");
    expect(blok).toContain("kayit-secim-katil");
    expect(blok).toContain("kayitSecimYeni");
    expect(blok).toContain("kayitSecimKatil");
  });

  it('eski "Zaten bir sitem var" link deseni KALKTI', () => {
    expect(KAYNAK).not.toContain("kayit-zaten-sitem-var");
    expect(KAYNAK).not.toContain("setKatil");
  });

  it("DENETCI tesis ACAMAZ — yalniz yonetici", () => {
    const m = KAYNAK.match(/const tesisAcar = ([^;]+);/);
    expect(m, "`tesisAcar` bulunamadi").not.toBeNull();
    expect(m![1]).toContain('rol === "yonetici"');
  });
});

/**
 * (P185 §2) YENI TESIS OLUSTUR — Tesis ID sorulmaz, uretilir + gosterilir.
 */
describe("(P185) yeni tesis olusturma uclari", () => {
  it("PAROLA yolu e-posta dogrulamali 3 ucu KULLANIR", () => {
    expect(KAYNAK).toContain('"/api/auth/kayit/yonetici-basvuru"');
    expect(KAYNAK).toContain('"/api/auth/kayit/yonetici-dogrula"');
    expect(KAYNAK).toContain('"/api/auth/kayit/yonetici-tesis"');
  });

  it("SOSYAL yolu tesis-olustur ucunu KULLANIR (OTP yok)", () => {
    expect(KAYNAK).toContain('"/api/auth/kayit/tesis-olustur"');
  });

  it("uretilen TESIS KODU gosterilir ve kopyalanabilir", () => {
    expect(KAYNAK).toContain("kayit-uretilen-kod");
    expect(KAYNAK).toContain("kayitKopyala");
    expect(KAYNAK).toContain("writeText");
  });
});

/**
 * (P185 §6) MEVCUT TESISE KATIL — rol-eposta-* / oauth rol-tamamla-*.
 */
describe("(P185) mevcut tesise katilma uclari", () => {
  it("PAROLA yolu rol-eposta-* + set-password KULLANIR", () => {
    expect(KAYNAK).toContain('"/api/auth/kayit/rol-eposta-basla"');
    expect(KAYNAK).toContain('"/api/auth/kayit/rol-eposta-dogrula"');
    expect(KAYNAK).toContain('"/api/auth/set-password"');
  });

  it("SOSYAL yolu oauth rol-tamamla-* KULLANIR", () => {
    expect(KAYNAK).toContain('"/api/auth/oauth/rol-tamamla"');
    expect(KAYNAK).toContain('"/api/auth/oauth/rol-tamamla-dogrula"');
  });

  it("onay_bekliyor durumu BILGI ekranina goturur", () => {
    expect(KAYNAK).toContain("onay_bekliyor");
    expect(KAYNAK).toContain('setAdim("onay")');
    expect(KAYNAK).toContain("kayitOnayBekliyorBaslik");
  });
});

/**
 * (P185) E-POSTA ZORUNLU, TELEFON YALNIZ ILETISIM.
 */
describe("(P185) e-posta zorunlu, telefon giris anahtari degil", () => {
  it("e-posta alani var ve zorunlu", () => {
    expect(KAYNAK).toContain("kayit-eposta");
    expect(KAYNAK).toContain("kayitEposta");
  });

  it("telefon ipucu giris anahtari DEMEZ", () => {
    expect(KAYNAK).toContain("kayitTelefonIpucu");
    // Eski "giris anahtari" cagrisimi metinden temizlenmis olmali:
    // ipucu anahtari kullanilir, sabit metin degil.
    expect(KAYNAK).not.toContain("kayitKodAciklama");
  });
});
