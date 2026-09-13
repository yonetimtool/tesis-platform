// (P123) TELEFON — panel ile mobilin AYNI kurali uygulamasi kilidi.
//
// Asagidaki PAYLASILAN TABLO `mobile/test/telefon_bicimlendirici_test.dart`
// icindekiyle birebir aynidir. Iki yuzey ayrisirsa yonetici panelde
// kaydettigi numarayi mobilde farkli gorur.
import { describe, expect, it } from "vitest";

import {
  telefonTasti,
  TELEFON_HANE_SAYISI,
  telefonBicimle,
  telefonGiris,
  telefonHaneleri,
  telefonHatasi,
  telefonNormalle,
} from "@/lib/telefon";

/** PAYLASILAN TABLO — mobil testiyle ayni girdiler. */
const HAM_BICIMLER = [
  "+905431992904",
  "905431992904",
  "05431992904",
  "5431992904",
  "+90 543 199 29 04",
  "0543-199-29-04",
  "(0543) 199-29-04",
  "00905431992904",
];

describe("telefonHaneleri", () => {
  it("HER yazim bicimi ayni 10 haneye iner", () => {
    for (const ham of HAM_BICIMLER) {
      expect(telefonHaneleri(ham), ham).toBe("5431992904");
    }
  });

  it("`90` ile BASLAYAN GECERLI numara ulke kodu SANILMAZ", () => {
    expect(telefonHaneleri("9012345678")).toBe("9012345678");
  });

  it("TASMA kirpilir (sert sinir)", () => {
    expect(telefonHaneleri("054319929041234")).toBe("5431992904");
    expect(telefonHaneleri("5431992904")).toHaveLength(TELEFON_HANE_SAYISI);
  });

  // (P227 §3) KIRPMA SESSIZ DEGIL.
  //
  // Kirpma DAVRANISI kaldi (kutuya fazlasi yazilamaz) ama artik
  // SORULABILIYOR. Once 11. rakam yazildiginda ekranda hicbir sey
  // degismiyordu; kullanici numarayi dogru sandigi halde son hanesi
  // DUSMUS oluyordu. Yapistirmada daha sinsi: 11 haneli yanlis bir
  // numara, 10 haneli BASKA BIR numaraya donusup kaydedilebiliyordu.
  it("TASMA SORULABILIYOR — sessiz degil", () => {
    // 11 ULUSAL HANE = tasma. (`05431992904` TASMA DEGILDIR: bastaki `0`
    // ulusal haneye dahil degil — ilk yazimda bunu karistirdim ve test
    // hakli olarak dustu.)
    expect(telefonTasti("054319929041")).toBe(true);
    expect(telefonTasti("54319929041")).toBe(true);
    expect(telefonTasti("0543 199 29 04")).toBe(false);
    expect(telefonTasti("05431992904")).toBe(false);
  });

  it("ULKE KODU EKLERI TASMA SAYILMAZ", () => {
    // `+90`, `0090`, `90` ve bastaki `0` soyuluyor; kullanicinin fazladan
    // rakam yazdigi anlamina GELMEZ.
    for (const ham of HAM_BICIMLER) {
      expect(telefonTasti(ham), ham).toBe(false);
    }
  });

  it("TASMA HATA OLARAK doner ve ONCE gelir", () => {
    // Numara 10 haneye kirpildigi icin oteki denetimlerin hepsi GECERLI
    // gorunur; tasma once sorulmazsa kullanici hatayi HIC gormez.
    expect(telefonHatasi("054319929041")).toBe("tasma");
  });
});

describe("telefonBicimle / telefonGiris", () => {
  it("TAM numara gruplanir", () => {
    expect(telefonBicimle("5431992904")).toBe("0(543) 199 29 04");
  });

  it("KISMI numara da gruplanir (yazarken)", () => {
    // (P227 §3) Parantez yalniz alan kodu TAMAMLANINCA kapanir.
    expect(telefonGiris("5")).toBe("0(5");
    expect(telefonGiris("543")).toBe("0(543)");
    expect(telefonGiris("5431")).toBe("0(543) 1");
    expect(telefonGiris("543199")).toBe("0(543) 199");
    expect(telefonGiris("54319929")).toBe("0(543) 199 29");
  });

  it("YAPISTIRMA cozulur", () => {
    for (const ham of HAM_BICIMLER) {
      expect(telefonGiris(ham), ham).toBe("0(543) 199 29 04");
    }
  });

  it("RAKAM DISI karakter YUTULUR", () => {
    expect(telefonGiris("0a5b4c3d1e992904")).toBe("0(543) 199 29 04");
  });

  it("BOS -> bos", () => {
    expect(telefonGiris("")).toBe("");
  });
});

describe("telefonNormalle", () => {
  it("E.164 uretir", () => {
    expect(telefonNormalle("0543 199 29 04")).toBe("+905431992904");
  });
  it("zaten E.164 olan DEGISMEZ", () => {
    expect(telefonNormalle("+905431992904")).toBe("+905431992904");
  });
  it("BOS -> bos (istege bagli alanlar temizlenebilsin)", () => {
    expect(telefonNormalle("")).toBe("");
  });
});

describe("telefonHatasi", () => {
  it("GECERLI numara -> null", () => {
    expect(telefonHatasi("0543 199 29 04")).toBeNull();
  });
  it("EKSIK hane", () => {
    expect(telefonHatasi("0543 199")).toBe("eksik");
  });
  it("SABIT HAT ON EKI reddedilir", () => {
    // `0212…` bir cep numarasi degildir ve SMS gitmez.
    expect(telefonHatasi("0212 555 44 33")).toBe("gecersizOnEk");
    expect(telefonHatasi("0312 555 44 33")).toBe("gecersizOnEk");
  });
  it("BOS: zorunluysa hata, degilse gecerli", () => {
    expect(telefonHatasi("")).toBe("bos");
    expect(telefonHatasi("", false)).toBeNull();
  });
  it("BILINMEYEN ama 5 ile baslayan blok KABUL edilir", () => {
    // BTK yeni blok tahsis edebilir; kural "kapali liste" DEGIL.
    expect(telefonHatasi("0599 123 45 67")).toBeNull();
  });
});
