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
