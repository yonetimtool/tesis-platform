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
  telefonParcala,
  telefonUlkeyiDegistir,
  ulkeBul,
} from "@/lib/telefon";
import { ulkeyiCoz } from "@/lib/ulke-telefon";

const TR = ulkeBul("TR")!;

/** PAYLASILAN TABLO — mobil testiyle ayni girdiler. */
const HAM_BICIMLER = [
  "+905431992904",
  "905431992904",
  "05431992904",
  "+90 543 199 29 04",
  "0543-199-29-04",
  "(0543) 199-29-04",
  "00905431992904",
  // (P233 §3) YENI bicim — eskiler de KABUL EDILMEYE DEVAM EDER.
  "(+90) 543 199 29 04",
];

describe("telefonHaneleri", () => {
  it("HER yazim bicimi ayni 10 haneye iner", () => {
    for (const ham of [...HAM_BICIMLER, "5431992904"]) {
      expect(telefonHaneleri(ham), ham).toBe("5431992904");
    }
  });

  // (P233 §3) ULKESIZ yazim AYRI TUTULUR: haneleri ayni, ama ULKE YOK.
  // Tabloya karistirmak, "kod uydurma" kuralini sessizce delerdi.
  it("ULKESIZ yazim haneleri verir ama ULKE VERMEZ", () => {
    expect(telefonParcala("5431992904").ulke).toBeNull();
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

// (P233 §3) ULKE KODU — TR sabiti kalkti. Mobil ikiziyle AYNI tablo.
describe("ulke kodu", () => {
  it("E.164 degerden ULKE cozulur", () => {
    expect(telefonParcala("+491711234567").ulke?.kod).toBe("DE");
    expect(telefonParcala("+905431992904").ulke?.kod).toBe("TR");
    expect(telefonParcala("+9647912345678").ulke?.kod).toBe("IQ");
  });

  it("EN UZUN KOD ONCE denenir (+90 ile +964 ayni 9 ile baslar)", () => {
    const p = telefonParcala("+9647912345678");
    expect(p.ulke?.arama).toBe("964");
    expect(p.haneler).toBe("7912345678");
  });

  it("ULKE SECILMEDEN numara GECERLI DEGIL", () => {
    // Eski davranis burada SESSIZCE `+90` ekliyordu; yabanci numara
    // BASKA BIR NUMARAYA donusuyordu.
    expect(telefonHatasi("5431992904")).toBe("ulkeYok");
    expect(telefonNormalle("5431992904")).toBe("");
  });

  it("`+` YOKSA DA tam eslesen ulke kodu taninir", () => {
    // `905431992904` numarayi yazmanin cok yaygin bir bicimi.
    expect(telefonParcala("905431992904").ulke?.kod).toBe("TR");
    // ...ama hane sayisi tutmuyorsa TAHMIN EDILMEZ: `5431992904` bir AR
    // numarasi (`+54`) sanilsaydi kullanicinin TR numarasi Arjantin
    // numarasina donerdi.
    expect(ulkeyiCoz("5431992904")).toBeNull();
  });

  it("UZUNLUK SINIRI ULKEYE GORE", () => {
    expect(telefonHatasi("(+49) 171 1234 5678")).toBeNull();
    expect(telefonTasti("(+49) 171 1234 5678")).toBe(false);
    expect(telefonTasti("(+49) 171 1234 567890")).toBe(true);
    expect(telefonTasti("(+974) 3312 3456")).toBe(false);
    expect(telefonTasti("(+974) 3312 345678")).toBe(true);
  });

  it("ON EK KURALI YALNIZ TR", () => {
    expect(telefonHatasi("(+90) 212 555 44 33")).toBe("gecersizOnEk");
    // Alman sabit hatti REDDEDILMEZ — bloklarini bilmiyoruz; uydurulmus
    // bir kural gercek bir numarayi reddederdi.
    expect(telefonHatasi("(+49) 30 12345678")).toBeNull();
  });

  it("ULKE DEGISINCE haneler KORUNUR, sinir asilirsa KIRPILIR", () => {
    expect(telefonUlkeyiDegistir("(+90) 541 922 23 88", "DE")).toBe(
      "(+49) 541 922 2388",
    );
    expect(telefonUlkeyiDegistir("(+90) 541 922 23 88", "QA")).toBe(
      "(+974) 541 922 23",
    );
  });
});

describe("telefonBicimle / telefonGiris", () => {
  it("TAM numara gruplanir", () => {
    expect(telefonBicimle("5419222388", TR)).toBe("(+90) 541 922 23 88");
  });

  it("KISMI numara da gruplanir (yazarken)", () => {
    expect(telefonGiris("05")).toBe("(+90) 5");
    expect(telefonGiris("0541")).toBe("(+90) 541");
    expect(telefonGiris("05419")).toBe("(+90) 541 9");
    expect(telefonGiris("0541922")).toBe("(+90) 541 922");
    expect(telefonGiris("054192223")).toBe("(+90) 541 922 23");
  });

  it("ULKE YOK -> kod YAZILMAZ (uydurulmaz)", () => {
    expect(telefonBicimle("5419222388", null)).toBe("541 922 23 88");
  });

  it("YAPISTIRMA cozulur", () => {
    for (const ham of HAM_BICIMLER) {
      expect(telefonGiris(ham), ham).toBe("(+90) 543 199 29 04");
    }
  });

  it("RAKAM DISI karakter YUTULUR", () => {
    expect(telefonGiris("0a5b4c3d1e992904")).toBe("(+90) 543 199 29 04");
  });

  it("BOS -> bos", () => {
    expect(telefonGiris("")).toBe("");
  });
});

describe("telefonNormalle", () => {
  it("E.164 uretir", () => {
    expect(telefonNormalle("(+90) 543 199 29 04")).toBe("+905431992904");
  });
  it("ESKI bicim de E.164 uretir (SAKLAMA DEGISMEDI)", () => {
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
    expect(telefonHatasi("(+90) 543 199 29 04")).toBeNull();
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
