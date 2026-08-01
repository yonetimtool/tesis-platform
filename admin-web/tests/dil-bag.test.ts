// (P85) DIL LISTELERI UC YERDE AYNI OLMALI.
//
// Ayni dil kumesi UC ayri yerde tutuluyor:
//   * panel: `lib/i18n/diller.ts` (DILLER)
//   * mobil: `AppDil` enum'u (secici + supportedLocales)
//   * ARB dosyalari: `mobile/lib/l10n/app_<kod>.arb`
//
// Biri eklenip digeri unutulursa kusur SESSIZDIR ve her yerde farkli
// gorunur: panelde secilebilen bir dil mobilde YOK, ya da `AppDil`de olan
// bir dilin ARB'si yok ve `gen-l10n` o dili sessizce ingilizceye dusurur.
// Kullanici dilini secer, arayuz DEGISMEZ.
//
// SIRA da onemli: `supportedLocales` yorumu "sira = secicideki sira" der;
// iki istemcinin secici sirasinin ayrisması urun tutarsizligidir.
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

import { DILLER } from "@/lib/i18n/diller";

const KOK = join(__dirname, "..", "..");

/** `AppDil` enum'undaki dil kodlari (bildirim sirasiyla). */
function mobilDilleri(): string[] {
  const kaynak = readFileSync(
    join(KOK, "mobile", "lib", "src", "core", "i18n", "locale_controller.dart"),
    "utf8",
  );
  const blok = /enum AppDil \{([\s\S]*?)\n\n/.exec(kaynak);
  expect(blok, "AppDil enum'u bulunamadi").not.toBeNull();
  return [...(blok as RegExpExecArray)[1].matchAll(/^\s+\w+\('([a-z]{2})'/gm)].map(
    (m) => m[1],
  );
}

/** `mobile/lib/l10n/app_<kod>.arb` dosyalarindaki kodlar. */
function arbDilleri(): string[] {
  return readdirSync(join(KOK, "mobile", "lib", "l10n"))
    .map((ad) => /^app_([a-z]{2})\.arb$/.exec(ad)?.[1])
    .filter((x): x is string => Boolean(x));
}

describe("dil listeleri uc yerde ayni (P85)", () => {
  it("panel DILLER = mobil AppDil (SIRA dahil)", () => {
    // Sira da karsilastirilir: secici sirasi urun karari ve iki
    // istemcide ayni olmali.
    expect([...DILLER]).toEqual(mobilDilleri());
  });

  it("her dilin ARB dosyasi VAR (eksik ARB sessizce ingilizceye duser)", () => {
    expect([...arbDilleri()].sort()).toEqual([...DILLER].sort());
  });
});
