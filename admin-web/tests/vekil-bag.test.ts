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

describe("BFF beyaz listesi sozlesmeyle ortusur (P84)", () => {
  const yollar = sozlesmeYollari().map(kalip);

  it("sozlesme yollari okundu", () => {
    expect(yollar.length).toBeGreaterThan(100);
  });

  it.each(Object.entries(OKUMA))("OKUMA %s -> %s", (_ad, yol) => {
    expect(yollar).toContain(kalip(yol));
  });

  it.each(Object.entries(YAZMA))("YAZMA %s -> %s", (_ad, yol) => {
    expect(yollar).toContain(kalip(yol));
  });
});
