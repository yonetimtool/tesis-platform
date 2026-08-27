// (P182 §4) Yerlesim yeniden siralama — saf donusum testleri.
// Surukle-birak ve klavye tasima mantigi bilesenin disinda saf fonksiyon
// oldugu icin jsdom'da surukle olayi uretmeden davranis kilitlenebilir.
import { describe, expect, it } from "vitest";
import {
  bolumSurukleBirak,
  bolumOkTasi,
  type CozulmusSatir,
} from "@/lib/pano-tercihi";

// Kucuk kurucu: id listesinden satir. gizli/anahtar vs. tasima icin onemsiz.
function satir(sutun: number, ...idler: string[]): CozulmusSatir {
  return {
    sutun,
    bolumler: idler.map((id) => ({
      id: id as CozulmusSatir["bolumler"][number]["id"],
      anahtar: id,
      gizli: false,
    })) as CozulmusSatir["bolumler"],
  };
}

// Satirlari "a,b | c" biciminde okunur kilar (karsilastirma kolay olsun).
function goster(satirlar: CozulmusSatir[]): string {
  return satirlar.map((s) => s.bolumler.map((b) => b.id).join(",")).join(" | ");
}

describe("(P182 §4) bolumSurukleBirak — surukle-birak", () => {
  it("SATIR ICINDE bir bolumu baskasinin ONUNE tasir", () => {
    const s = [satir(3, "a", "b", "c")];
    // c'yi a'nin onune birak -> c,a,b
    expect(goster(bolumSurukleBirak(s, "c", { tip: "once", id: "a" }))).toBe("c,a,b");
  });

  it("BASKA SATIRA (bolum onune) tasir", () => {
    const s = [satir(2, "a", "b"), satir(1, "c")];
    // a'yi c'nin onune birak -> ikinci satir "a,c", ilk satir "b"
    expect(goster(bolumSurukleBirak(s, "a", { tip: "once", id: "c" }))).toBe("b | a,c");
  });

  it("KAYNAK==HEDEF ise degismez", () => {
    const s = [satir(2, "a", "b")];
    expect(goster(bolumSurukleBirak(s, "a", { tip: "once", id: "a" }))).toBe("a,b");
  });

  it("SATIR SONUNA birakma (bos satira tasima)", () => {
    const s = [satir(2, "a", "b"), satir(1)]; // ikinci satir BOS
    // a'yi 1. dizinli (bos) satirin sonuna -> ilk "b", ikinci "a"
    expect(goster(bolumSurukleBirak(s, "a", { tip: "satirSonu", si: 1 }))).toBe("b | a");
  });

  it("bosalan satir SILINIR (tek bolum baska satira gidince)", () => {
    const s = [satir(1, "a"), satir(2, "b", "c")];
    // a'yi b'nin onune -> ilk satir bosalir ve dusulur
    expect(goster(bolumSurukleBirak(s, "a", { tip: "once", id: "b" }))).toBe("a,b,c");
  });

  it("bilinmeyen kaynak kimligi degisiklik yapmaz", () => {
    const s = [satir(2, "a", "b")];
    expect(goster(bolumSurukleBirak(s, "yok", { tip: "once", id: "a" }))).toBe("a,b");
  });

  it("girdi dizisini MUTASYONA UGRATMAZ", () => {
    const s = [satir(2, "a", "b")];
    bolumSurukleBirak(s, "b", { tip: "once", id: "a" });
    expect(goster(s)).toBe("a,b");
  });
});

describe("(P182 §4) bolumOkTasi — klavye", () => {
  it("SOL: satir icinde bir sola", () => {
    const s = [satir(3, "a", "b", "c")];
    expect(goster(bolumOkTasi(s, 0, 2, "sol"))).toBe("a,c,b");
  });

  it("SAG: satir icinde bir saga", () => {
    const s = [satir(3, "a", "b", "c")];
    expect(goster(bolumOkTasi(s, 0, 0, "sag"))).toBe("b,a,c");
  });

  it("SOL sinirda (ilk bolum) degismez", () => {
    const s = [satir(2, "a", "b")];
    expect(goster(bolumOkTasi(s, 0, 0, "sol"))).toBe("a,b");
  });

  it("SAG sinirda (son bolum) degismez", () => {
    const s = [satir(2, "a", "b")];
    expect(goster(bolumOkTasi(s, 0, 1, "sag"))).toBe("a,b");
  });

  it("ASAGI: sonraki satirin sonuna tasir", () => {
    const s = [satir(2, "a", "b"), satir(1, "c")];
    expect(goster(bolumOkTasi(s, 0, 0, "asagi"))).toBe("b | c,a");
  });

  it("YUKARI: onceki satirin sonuna tasir", () => {
    const s = [satir(1, "a"), satir(2, "b", "c")];
    // b'yi yukari -> ilk satir "a,b", ikinci "c"
    expect(goster(bolumOkTasi(s, 1, 0, "yukari"))).toBe("a,b | c");
  });

  it("ASAGI son satirdan sinirda degismez", () => {
    const s = [satir(1, "a"), satir(1, "b")];
    expect(goster(bolumOkTasi(s, 1, 0, "asagi"))).toBe("a | b");
  });

  it("tek bolumlu satirdan ASAGI tasiyinca bosalan satir silinir", () => {
    const s = [satir(1, "a"), satir(1, "b")];
    expect(goster(bolumOkTasi(s, 0, 0, "asagi"))).toBe("b,a");
  });

  it("girdi dizisini MUTASYONA UGRATMAZ", () => {
    const s = [satir(2, "a", "b")];
    bolumOkTasi(s, 0, 0, "sag");
    expect(goster(s)).toBe("a,b");
  });
});
