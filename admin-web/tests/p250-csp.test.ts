// (P250 §4) CSP KILIDI — yalniz gereken YouTube alanlari, joker yok.
import { describe, expect, it } from "vitest";

// @ts-expect-error -- .mjs yapilandirmasinin tip bildirimi yok; deger dizedir.
import { ICERIK_POLITIKASI as HAM } from "../next.config.mjs";

const ICERIK_POLITIKASI: string = HAM;

function yonerge(ad: string): string[] {
  const satir = ICERIK_POLITIKASI.split(";").map((x: string) => x.trim()).find((x: string) => x.startsWith(`${ad} `));
  return satir ? satir.split(/\s+/).slice(1) : [];
}

describe("CSP", () => {
  it("JOKER YOK (genel izin acilmadi)", () => {
    expect(ICERIK_POLITIKASI).not.toMatch(/(^|\s)\*(\s|;|$)/);
    expect(ICERIK_POLITIKASI).not.toMatch(/https:\s|https:;|\shttp:/);
  });
  it("betik: yalniz youtube.com IFrame API", () => {
    const dis = yonerge("script-src").filter((x) => x.startsWith("https://"));
    expect(dis).toEqual(["https://www.youtube.com"]);
  });
  it("cerceve: youtube-nocookie + mevcut harita gomuleri", () => {
    const dis = yonerge("frame-src").filter((x) => x.startsWith("https://"));
    expect(dis).toEqual([
      "https://www.youtube-nocookie.com",
      "https://www.google.com",
      "https://www.openstreetmap.org",
    ]);
    expect(dis).not.toContain("https://www.youtube.com");
  });
  it("koruyucu yonergeler", () => {
    expect(yonerge("object-src")).toEqual(["'none'"]);
    expect(yonerge("frame-ancestors")).toEqual(["'none'"]);
    expect(yonerge("worker-src")).toContain("blob:");
  });
});
