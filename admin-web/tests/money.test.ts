// Para = KURUS (integer). Bu dosyanin isi: TL<->kurus donusumunun TAM SAYI
// aritmetigiyle yapildigini ve gecersiz girdinin SESSIZCE 0'a donmedigini
// (null dondugunu) kilitlemek. Aidat tutarlari buradan geciyor; kayan nokta
// hatasi para hatasidir.
import { describe, expect, it } from "vitest";

import { kurusToTL, kurusToTLSade, tlToKurus } from "@/lib/money";

describe("tlToKurus", () => {
  it("tam lira: kurus kismi 00 ile doldurulur", () => {
    expect(tlToKurus("750")).toBe(75000);
    expect(tlToKurus("0")).toBe(0);
  });

  it("virgul VE nokta ayirici kabul edilir (klavye farki)", () => {
    expect(tlToKurus("750,50")).toBe(75050);
    expect(tlToKurus("750.50")).toBe(75050);
  });

  it("tek haneli kurus 10'luk olarak yorumlanir (750,5 = 750,50)", () => {
    expect(tlToKurus("750,5")).toBe(75050);
    expect(tlToKurus("0,5")).toBe(50);
  });

  it("bastaki/sondaki bosluk kirpilir", () => {
    expect(tlToKurus("  750,50  ")).toBe(75050);
  });

  // (P50) BINLIK AYIRICI ARTIK DESTEKLENIYOR — bilincli davranis degisikligi.
  //
  // Burada `1.000,50` GECERSIZ sayiliyordu ("belirsiz" gerekcesiyle). Ama
  // panelin kendisi ayni tutari `kurusToTL` ile `1.000,50 ₺` diye GOSTERIYOR:
  // uygulama, gosterdigi bicimi geri KABUL ETMIYORDU ve kullanici gordugu
  // sayiyi yazip "gecersiz tutar" aliyordu. Belirsizlik de gercekte yok:
  // virgul varsa nokta BINLIKTIR. Ayni kural mobilde de uygulanir (P49/P50)
  // — iki istemcinin ayni metni farkli ayristirmasi, ayni sitede farkli
  // tutar girilebilmesi demekti.
  it("BINLIK AYIRICILI bicim kabul edilir (panelin GOSTERDIGI bicim)", () => {
    expect(tlToKurus("1.000,50")).toBe(100050);
    expect(tlToKurus("1.250,00")).toBe(125000);
    expect(tlToKurus("1.234.567,89")).toBe(123456789);
    // Virgul yoksa TEK nokta + en fazla iki hane ONDALIKTIR (sayisal klavye).
    expect(tlToKurus("1250.00")).toBe(125000);
    // Aksi halde nokta BINLIKTIR.
    expect(tlToKurus("1.250")).toBe(125000);
    // Para birimi jetonu ve uc bosluklari yok sayilir.
    expect(tlToKurus(" 1.250,00 ₺ ")).toBe(125000);
  });

  it("GECERSIZ girdi null doner — 0 DEGIL (sessiz sifir tutar yazamaz)", () => {
    for (const v of [
      "",
      "   ",
      "abc",
      "750,555", // 2'den fazla kurus hanesi
      "750,",
      ",50",
      "-750", // negatif tutar girisi yok (iade ayri akis)
      "1 000",
      "7e2",
      "+750",
    ]) {
      expect(tlToKurus(v), `girdi: "${v}"`).toBeNull();
    }
  });

  it("float hatasi YOK: 0.07 gibi degerler tam sayiya oturur", () => {
    // 0.07 * 100 = 7.000000000000001 (IEEE754). Integer aritmetigi bunu elemeli.
    expect(tlToKurus("0,07")).toBe(7);
    expect(Number.isInteger(tlToKurus("1234,56"))).toBe(true);
    expect(tlToKurus("1234,56")).toBe(123456);
  });
});

describe("kurusToTL", () => {
  it("binlik ayirici tr-TR (nokta) + iki haneli kurus + simge", () => {
    expect(kurusToTL(75000)).toBe("750,00 ₺");
    expect(kurusToTL(123456)).toBe("1.234,56 ₺");
    expect(kurusToTL(100000000)).toBe("1.000.000,00 ₺");
  });

  it("kurus tek haneliyken solu sifirla doldurur", () => {
    expect(kurusToTL(7)).toBe("0,07 ₺");
    expect(kurusToTL(70)).toBe("0,70 ₺");
  });

  it("sifir ve negatif (bakiye/iade) dogru bicimlenir", () => {
    expect(kurusToTL(0)).toBe("0,00 ₺");
    expect(kurusToTL(-75050)).toBe("-750,50 ₺");
    expect(kurusToTL(-7)).toBe("-0,07 ₺");
  });
});

describe("gidis-donus (round-trip)", () => {
  it("kurus -> TL -> kurus AYNI degeri verir", () => {
    for (const kurus of [0, 1, 7, 99, 100, 75050, 123456, 999999999]) {
      const metin = kurusToTL(kurus)
        .replace(" ₺", "")
        .replace(/\./g, ""); // binlik ayiricilari at, virgul kalir
      expect(tlToKurus(metin), `kurus: ${kurus}`).toBe(kurus);
    }
  });

  // (P48) BINLIK AYIRICI — ICU'YA BAGIMLI DEGIL.
  //
  // Eski surum `toLocaleString("tr-TR")` kullaniyordu. Tam ICU'lu bir
  // calisma zamaninda `5.000` verir; KUCUK-ICU ile derlenmis bir
  // Node/tarayicida `tr-TR` desteklenmez ve `en-US`a duser: `5,000`. O
  // durumda para `5,000,00 ₺` gorunurdu — hem yanlis hem OKUNAMAZ, ve hata
  // YALNIZ BAZI ORTAMLARDA ciktigi icin gelistirmede fark edilmezdi.
  it("binlik ayirici NOKTA, ondalik VIRGUL — her ortamda", () => {
    expect(kurusToTL(500000)).toBe("5.000,00 ₺");
    expect(kurusToTL(123456789)).toBe("1.234.567,89 ₺");
    expect(kurusToTL(99)).toBe("0,99 ₺");
    expect(kurusToTL(100)).toBe("1,00 ₺");
    expect(kurusToTL(0)).toBe("0,00 ₺");
  });

  it("NEGATIF tutar isaretini KORUR", () => {
    expect(kurusToTL(-500000)).toBe("-5.000,00 ₺");
    expect(kurusToTL(-99)).toBe("-0,99 ₺");
  });

  it("gruplama SINIRLARI dogru (3, 4, 6, 7 hane)", () => {
    // Uc haneden kisa sayida ayirici OLMAMALI.
    expect(kurusToTL(99900)).toBe("999,00 ₺");
    expect(kurusToTL(100000)).toBe("1.000,00 ₺");
    expect(kurusToTL(99999900)).toBe("999.999,00 ₺");
    expect(kurusToTL(100000000)).toBe("1.000.000,00 ₺");
  });
});

// (P79) IKI ISTEMCI AYNI GRUPLAMAYI URETIR — capraz bag.
//
// Panel ve mobil AYRI yollarla bicimlendirir ve bu BILINCLIDIR:
//   * panel: gruplamayi KENDI yapar (`binlikAyir`). `toLocaleString` bir
//     CALISMA ZAMANI bagimliligidir — kucuk-ICU'lu bir Node/tarayicida
//     `tr-TR` desteklenmez ve `en-US`a duser (P48'de olculdu: `5,000,00 ₺`).
//   * mobil: `intl` paketinin `NumberFormat('#,##0.00', 'tr_TR')`i.
//     Orada risk YOKTUR cunku yerel veri PAKETIN ICINDE gelir, calisma
//     zamanindan okunmaz.
//
// Yollar farkli olduguna gore CIKTININ ayni oldugunu bir sey tutmali.
// `mobile/test/i18n_test.dart` asagidaki AYNI degerleri surer; biri
// degistirilirse digeri de degistirilmelidir.
describe("panel ve mobil AYNI gruplamayi uretir (P79)", () => {
  it("mobil `tlTutar` ile ayni govde", () => {
    // mobile/test/i18n_test.dart: tlTutar(125000) == '1.250,00'
    expect(kurusToTLSade(125000)).toBe("1.250,00");
    // mobile/test/i18n_test.dart: tlTutar(99) == '0,99'
    expect(kurusToTLSade(99)).toBe("0,99");
  });

  it("simge YERI iki istemcide FARKLIDIR ve bu bilinclidir", () => {
    // Panel: son ek (`1.250,00 ₺`). Mobil: on ek (`₺1.250,00`) ya da
    // `1.250,00 TL`. Govde ayni, yerlesim urun karari — bkz. mobil
    // README §15. Bunu "tutarsizlik" diye duzeltmek, iki uygulamanin
    // yerlesik gorunumunu tek bir turda degistirmek olurdu.
    expect(kurusToTL(125000)).toBe("1.250,00 ₺");
  });
});
