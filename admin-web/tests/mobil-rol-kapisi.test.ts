// (P129) MOBIL-YALNIZ ROLLER `app.*`TA OTURUM ACAMAZ — SUNUCU TARAFINDA.
//
// Kerem'in sarti acikti: *"server-side rejection on app.* login with a clear
// Turkish message + store links. Block the session, don't just hide menus."*
//
// Menu gizlemek yetmez cunku menu bir GORUNURLUK katmanidir; oturum ise
// erisimin kendisidir. Bu dosya ikisini de olcer:
//   1. rol -> yuzey kapisi (`rolYuzeyeGirebilir`) mobil rolleri REDDEDIYOR,
//   2. giris rotalari bu kapiyi CAGIRIYOR, 403 donuyor ve mesaji ROLE GORE
//      seciyor (mobil / yakinda / platform).
//
// Mesaj SECIMI saf bir fonksiyonda (`girisRedKarari`) ve DAVRANISLA
// olculuyor. Ilk yazimda karar iki rotaya KOPYALANMISTI ve testler kaynakta
// metin ariyordu; mutasyon denetimi telefon rotasindaki dali olu bir dala
// cevirdiginde metin yerinde durdugu icin HICBIR TEST DUSMEDI. Kaynak
// taramasi geriye yalniz "kapi cagriliyor mu" sorusu icin kaldi.
import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

import {
  girisRedKarari,
  mobilYalnizRol,
  rolYuzeyeGirebilir,
  tesisYuzeyiBekleyenRol,
} from "@/lib/yuzey";

const GIRIS_ROTALARI = [
  "app/api/auth/login/route.ts",
  "app/api/auth/login-phone/route.ts",
];

describe("(P129) mobil-yalniz roller", () => {
  it("`app.*` yuzeyine GIREMEZ", () => {
    for (const r of ["resident", "security", "tesis_gorevlisi"]) {
      expect(rolYuzeyeGirebilir(r, "tesis"), r).toBe(false);
      expect(mobilYalnizRol(r), r).toBe(true);
    }
  });

  it("`app.*`a GIREBILEN roller: yonetici, denetci, admin", () => {
    // Iki yon sart: yalniz "reddediliyor" olculseydi HERKESI reddetmek de
    // testi gecerdi ve yuzey kullanilamaz olurdu.
    for (const r of ["yonetici", "denetci", "admin"]) {
      expect(rolYuzeyeGirebilir(r, "tesis"), r).toBe(true);
      expect(mobilYalnizRol(r), r).toBe(false);
    }
  });

  // (P213 §6) Amir artik WEB rolu: mobil-yalniz da degil, "yakinda" da
  // degil — dogrudan `app.*`a girer.
  it("`guvenlik_amiri` mobil-yalniz DEGIL ve artik BEKLEMEDE de degil", () => {
    expect(mobilYalnizRol("guvenlik_amiri")).toBe(false);
    expect(tesisYuzeyiBekleyenRol("guvenlik_amiri")).toBe(false);
  });

  it("platform yuzeyi etkilenmedi — yalniz `admin`", () => {
    expect(rolYuzeyeGirebilir("admin", "platform")).toBe(true);
    for (const r of ["yonetici", "denetci", "resident", "security"]) {
      expect(rolYuzeyeGirebilir(r, "platform"), r).toBe(false);
    }
  });
});

// KARAR FONKSIYONUNU DAVRANISLA OLC — kaynakta metin aramak YETMEZ.
// Ilk yazimda testler kaynakta "girisMobilUygulama" ariyordu; mutasyon
// denetimi telefon rotasindaki dali OLU bir dala cevirdiginde metin yine
// kaynakta duruyordu ve HICBIR TEST DUSMEDI. Kural artik tek bir saf
// fonksiyonda ve burada dogrudan cagriliyor.
describe("(P129) giris reddi KARARI", () => {
  it("mobil-yalniz rol -> magaza mesaji + `mobil_uygulama` kodu", () => {
    for (const r of ["resident", "security", "tesis_gorevlisi"]) {
      expect(girisRedKarari(r, "tesis"), r).toEqual({
        anahtar: "girisMobilUygulama",
        kod: "mobil_uygulama",
      });
    }
  });

  // (P213 §6) Amir icin ARTIK RED KARARINA HIC VARILMIYOR: `oturumAc`
  // once `rolYuzeyeGirebilir`e bakiyor ve amir gecti. Karar fonksiyonunu
  // "null doner" diye olcmek yanlis olurdu — o fonksiyon yalnizca REDDIN
  // metnini secer, reddedilip reddedilmeyecegine karar vermez.
  it("`guvenlik_amiri` kapiyi GECER — red metni secicisine hic ulasilmaz", () => {
    expect(rolYuzeyeGirebilir("guvenlik_amiri", "tesis")).toBe(true);
    // Ayni cagriyi bir de REDDEDILEN bir rolle yaparak, testin
    // "her sey null doner" gibi bir bosluga dusmedigini gosteriyoruz.
    expect(rolYuzeyeGirebilir("resident", "tesis")).toBe(false);
    expect(girisRedKarari("resident", "tesis").kod).toBe("mobil_uygulama");
  });

  it("platform yuzeyi -> panel mesaji, rol ne olursa olsun", () => {
    for (const r of ["yonetici", "resident", "denetci", null]) {
      expect(girisRedKarari(r, "platform"), String(r)).toEqual({
        anahtar: "girisPanelPlatformIcin",
        kod: "forbidden",
      });
    }
  });

  it("rolsuz/bilinmeyen -> panel mesaji (magaza DEGIL)", () => {
    // Bilinmeyen bir role "uygulamayi indirin" demek, olmayan bir hesap
    // turu icin yanlis yol tarif etmektir.
    expect(girisRedKarari(null, "tesis").kod).toBe("forbidden");
    expect(girisRedKarari("uydurma_rol", "tesis").kod).toBe("forbidden");
  });
});

// (P211 §2) KAPI ARTIK ROTALARDA DEGIL, `lib/oturum-kapisi.ts`TE.
// Iki rota kurali KOPYALIYORDU; panel -> app koprusu eklenince kopyalar
// yine geride kaldi (tam da P129'da olculen sinif). Rotalarda aranan sey
// artik "kapiyi CAGIRIYOR mu", karar metni tek dosyada olculuyor.
describe("(P129/P211) giris rotalari kapiyi UYGULUYOR", () => {
  for (const yol of GIRIS_ROTALARI) {
    it(`${yol}: kapiyi CAGIRIYOR, kendi kopyasi YOK`, () => {
      const kaynak = readFileSync(yol, "utf8");
      expect(kaynak).toContain("oturumAc(req");
      // Kural KOPYALANMAMALI: rotada kendi dallanmasi kalmamali.
      expect(kaynak).not.toContain("girisRedKarari(");
      expect(kaynak).not.toContain('? "girisMobilUygulama"');
    });
  }

  it("kapi TEK dosyada: rol -> yuzey + karar + 403", () => {
    const kaynak = readFileSync("lib/oturum-kapisi.ts", "utf8");
    expect(kaynak).toContain("rolYuzeyeGirebilir(rol, yuzey)");
    expect(kaynak).toContain("girisRedKarari(rol, yuzey)");
    expect(kaynak).toContain("403");
  });
});

describe("(P129) magaza baglantilari UYDURULMUYOR", () => {
  it("yapilandirma tanimsizken baglanti YOK", () => {
    // Uygulama henuz yayinda degil (P118). `applicationId`den Play adresi
    // turetmek bugun 404'e giden bir soz olurdu.
    const kaynak = readFileSync("lib/config.ts", "utf8");
    expect(kaynak).toContain("NEXT_PUBLIC_PLAY_URL");
    expect(kaynak).toContain("NEXT_PUBLIC_APPSTORE_URL");
    expect(kaynak).not.toMatch(/play\.google\.com|apps\.apple\.com/);
  });

  it("giris formu baglantiyi YALNIZ tanimliysa ciziyor", () => {
    const kaynak = readFileSync("components/GirisFormu.tsx", "utf8");
    expect(kaynak).toContain("MAGAZA_ANDROID || MAGAZA_IOS");
    expect(kaynak).toContain('data?.error?.code === "mobil_uygulama"');
  });
});
