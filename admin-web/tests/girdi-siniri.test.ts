import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import { describe, expect, it } from "vitest";

import { SINIR } from "@/lib/girdi-siniri";

// (P248 §3a) TEK KAYNAK = SUNUCU. `backend/app/girdi_siniri.py` icindeki
// `ISTEMCI_SABITLERI` sozlugu okunur, her anahtarin degeri (sabit adindan
// cozulerek) web `SINIR` ile karsilastirilir. Sunucuda bir sinir degisir de
// web'de degismezse kullanici ya fazlasini yazar (422) ya da gecerli metni
// yazamaz — ikisi de sessiz bir kopukluktur.
const PY = readFileSync(
  resolve(__dirname, "../../backend/app/girdi_siniri.py"),
  "utf8",
);

function sabitler(): Record<string, number> {
  const out: Record<string, number> = {};
  for (const m of PY.matchAll(/^([A-Z_]+)\s*=\s*([0-9_]+)\b/gm)) {
    out[m[1]] = Number(m[2].replace(/_/g, ""));
  }
  return out;
}

function istemciSabitleri(): Record<string, number> {
  const blok = PY.match(/ISTEMCI_SABITLERI\s*=\s*\{([\s\S]*?)\}/);
  if (!blok) throw new Error("ISTEMCI_SABITLERI bulunamadi");
  const s = sabitler();
  const out: Record<string, number> = {};
  for (const m of blok[1].matchAll(/"([A-Z_]+)"\s*:\s*([A-Z_0-9]+)/g)) {
    const deger = /^[0-9_]+$/.test(m[2]) ? Number(m[2].replace(/_/g, "")) : s[m[2]];
    if (deger === undefined) throw new Error(`cozulemeyen sabit: ${m[2]}`);
    out[m[1]] = deger;
  }
  return out;
}

describe("(P248 §3a) istemci sinirlari sunucuyla ESIT", () => {
  it("sunucudaki her istemci sabiti web SINIR'da AYNI degerle var", () => {
    const sunucu = istemciSabitleri();
    expect(Object.keys(sunucu).length).toBeGreaterThan(10);
    expect(SINIR).toEqual(sunucu);
  });
});
