/**
 * (E2E 2026-09 / TESIS-16 + ANA-4) Tekil daire no onizlemesi sunucunun
 * `daire_no_kanonik` kuralinin aynasi olmali: yalniz rakam -> "{blok}-{no}".
 */
import { describe, expect, it } from "vitest";
import { daireNoOnizle } from "@/lib/daire-no";

describe("daireNoOnizle", () => {
  it("yalniz rakam blok onekini alir", () => {
    expect(daireNoOnizle("11", "A")).toBe("A-11");
    expect(daireNoOnizle(" 7 ", "B")).toBe("B-7");
  });
  it("onekli ya da harfli no aynen kalir", () => {
    expect(daireNoOnizle("A-11", "A")).toBe("A-11");
    expect(daireNoOnizle("B3", "A")).toBe("B3");
  });
  it("bloksuz dairede dokunulmaz", () => {
    expect(daireNoOnizle("12", null)).toBe("12");
    expect(daireNoOnizle("12", "")).toBe("12");
  });
});
