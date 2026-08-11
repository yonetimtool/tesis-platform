// (P84) BFF BEYAZ LISTESI SOZLESMEDE GERCEKTEN VAR MI?
//
// `lib/panel-vekil.ts` panelin sunucuya acilan tek kapisidir: her giris
// bir backend YOLUNA esler. Yol yanlis yazilir ya da sunucudan
// kaldirilirsa panel tarafinda HICBIR SEY derlenmez/patlamaz — istek
// gider, **404** doner ve kullanici sayfada "yuklenemedi" gorur. Yani
// bir yazim hatasinin bedeli, calisma zamaninda kaybolan bir ozelliktir.
//
// Kaynak `contracts/openapi.yaml`: bu depoda SOZLESME odur ve
// `backend/tests/test_sozlesme_sapmasi.py` onun uygulamayla iki yonde
// ortustugunu zaten kilitliyor. Yani buradaki bag dolayli olarak
// UYGULAMAYA baglanmis olur — openapi'yi kaynak almak, ikinci bir
// dogruluk kaynagi UYDURMAK degil, var olan zincire eklemektir.
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

import { OKUMA, YAZMA } from "@/lib/panel-vekil";

/** `openapi.yaml` icindeki yol anahtarlari (`  /x/y:` satirlari). */
function sozlesmeYollari(): string[] {
  const kaynak = readFileSync(
    join(__dirname, "..", "..", "contracts", "openapi.yaml"),
    "utf8",
  );
  return [...kaynak.matchAll(/^ {2}(\/[^\s:]*):/gm)].map((m) => m[1]);
}

/** `/x/{id}` gibi parametreli yollari `/x/*` kalibina indirger. */
function kalip(yol: string): string {
  return yol.replace(/\{[^}]+\}/g, "*");
}

/**
 * (P154 / Asama 8) Vekil girisi DUZ, sozlesme yolu PARAMETRELI olabilir.
 *
 * Ice aktarim catisi sozlesmede TEK operasyondur (`/ice-aktarim/{tur}`,
 * `tur` bir enum) ama vekil beyaz listesi DORT DUZ giris tasir — cunku
 * beyaz listenin isi istemcinin yol uydurmasini engellemek ve bunun icin
 * hedefin duz olmasi gerekir.
 *
 * TIPO KORUMASI KAYBOLMUYOR: yanlis yazilmis bir tur (`/ice-aktarim/dare`)
 * sunucuda 404 DEGIL **422** alir — router kendi `TURLER` kaydini
 * dogruluyor (`test_ice_aktarim.py::test_BILINMEYEN_tur_422`). Yani
 * sessiz bir kayip degil, gurultulu bir hata olur.
 */
function sozlesmedeVarMi(yollar: string[], hedef: string): boolean {
  const h = kalip(hedef);
  if (yollar.includes(h)) return true;
  return yollar.some((y) => {
    if (!y.includes("*")) return false;
    const re = new RegExp(`^${y.split("*").map(escapeRe).join("[^/]+")}$`);
    return re.test(h);
  });
}

function escapeRe(x: string): string {
  return x.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

describe("BFF beyaz listesi sozlesmeyle ortusur (P84)", () => {
  const yollar = sozlesmeYollari().map(kalip);

  it("sozlesme yollari okundu", () => {
    expect(yollar.length).toBeGreaterThan(100);
  });

  it.each(Object.entries(OKUMA))("OKUMA %s -> %s", (_ad, yol) => {
    expect(sozlesmedeVarMi(yollar, yol), yol).toBe(true);
  });

  it.each(Object.entries(YAZMA))("YAZMA %s -> %s", (_ad, yol) => {
    expect(sozlesmedeVarMi(yollar, yol), yol).toBe(true);
  });

  it("olcum BOSA DUSMUYOR — uydurma bir yol REDDEDILIR", () => {
    // Joker eslesme eklendi; kural gevsemedigi buradan gorulur.
    expect(sozlesmedeVarMi(yollar, "/boyle-bir-uc-yok")).toBe(false);
    expect(sozlesmedeVarMi(yollar, "/ice-aktarim/daire/fazladan")).toBe(false);
  });
});
