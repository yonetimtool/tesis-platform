// @vitest-environment jsdom
// (P170 §1) "BENI HATIRLA" — WEB TARAFI.
//
// =========================================================================
// EN PAHALI SONUC: PAROLANIN UYGULAMA DEPOSUNDA DUZ METIN DURMASI
// =========================================================================
// `localStorage` ayni kokende calisan her betige aciktir; tek bir XSS,
// o an ekranda olan kullanicinin degil TUM kayitli parolalarin sizmasina
// donerdi. Bu test parolanin oraya HIC yazilmadigini dogruluyor.
//
// OLCULEN OTEKI SEYLER:
//   * isaretli -> tanimlayicilar saklanir ve ON-DOLDURULUR,
//   * isaretsiz -> hicbir sey saklanmaz VE onceden saklanan SILINIR,
//   * cikis -> saklanan temizlenir + tarayicinin SESSIZ oturum acmasi kapanir,
//   * form isaretlemesi -> tarayicinin parola yoneticisinin okudugu
//     oznitelikler (`name`, `autocomplete`, gercek `<form>`) yerinde.
import { describe, expect, it, beforeEach, vi } from "vitest";

import {
  kimligiSakla,
  kimligiUnut,
  tanimlayiciOku,
  tanimlayiciSil,
  tanimlayiciYaz,
} from "@/lib/kimlik-deposu";

const PAROLA = "CokGizliParola123";

beforeEach(() => {
  localStorage.clear();
});

describe("kimlik deposu", () => {
  it("isaretli: tanimlayicilar saklanir ve geri okunur", () => {
    tanimlayiciYaz({ telefon: "+905551112233" });
    expect(tanimlayiciOku(true)).toEqual({ telefon: "+905551112233" });

    tanimlayiciYaz({ tenantSlug: "demo", email: "a@b.com" });
    expect(tanimlayiciOku(false)).toEqual({
      tenantSlug: "demo",
      email: "a@b.com",
    });
  });

  it("PAROLA HICBIR ANAHTARA YAZILMAZ", async () => {
    tanimlayiciYaz({ telefon: "+905551112233" });
    // `PasswordCredential` yoksa sessizce doner (Firefox/Safari yolu).
    await kimligiSakla("+905551112233", PAROLA);

    const hepsi = Object.keys(localStorage).map((k) => localStorage.getItem(k));
    expect(hepsi.join("|")).not.toContain(PAROLA);
    // Depoda parola ADINI tasiyan bir anahtar da olmamali.
    expect(Object.keys(localStorage).join("|").toLowerCase()).not.toContain(
      "parola",
    );
    expect(Object.keys(localStorage).join("|").toLowerCase()).not.toContain(
      "password",
    );
  });

  it("isaretsiz: onceden saklanan SILINIR", () => {
    tanimlayiciYaz({ telefon: "+905551112233" });
    tanimlayiciSil();
    expect(tanimlayiciOku(true)).toBeNull();
  });

  it("EKSIK CIFT tam sayilmaz: yalniz tesis kodu varsa on-doldurma YOK", () => {
    // E-posta yolunda ikisi birlikte anlamli; yalniz biri, formu yarim
    // doldurup kullaniciyi "kaydedilmis ama calismiyor" halinde birakirdi.
    tanimlayiciYaz({ tenantSlug: "demo" });
    expect(tanimlayiciOku(false)).toBeNull();
  });

  it("CIKIS: saklanan silinir ve SESSIZ oturum acma kapatilir", async () => {
    tanimlayiciYaz({ telefon: "+905551112233" });
    const engelle = vi.fn().mockResolvedValue(undefined);
    vi.stubGlobal("navigator", {
      credentials: { preventSilentAccess: engelle },
    });

    await kimligiUnut();

    expect(tanimlayiciOku(true)).toBeNull();
    // Ortak bir bilgisayarda "cikis yaptim", bir sonraki kisinin tek
    // tikla GIREMEMESI demektir.
    expect(engelle).toHaveBeenCalled();
    vi.unstubAllGlobals();
  });

  it("KIMLIK DEPOSU VARSA parola ORAYA verilir (uygulama deposuna DEGIL)", async () => {
    const sakla = vi.fn().mockResolvedValue(undefined);
    class SahteKimlik {
      id: string;
      password: string;
      constructor(d: { id: string; password: string }) {
        this.id = d.id;
        this.password = d.password;
      }
    }
    vi.stubGlobal("PasswordCredential", SahteKimlik);
    vi.stubGlobal("navigator", { credentials: { store: sakla } });

    await kimligiSakla("+905551112233", PAROLA);

    expect(sakla).toHaveBeenCalledTimes(1);
    const gecen = sakla.mock.calls[0][0] as SahteKimlik;
    expect(gecen.id).toBe("+905551112233");
    expect(gecen.password).toBe(PAROLA);
    // Ve yine uygulama deposunda IZ YOK.
    expect(Object.values(localStorage).join("|")).not.toContain(PAROLA);
    vi.unstubAllGlobals();
  });

  it("kimlik deposu HATA VERIRSE giris bozulmaz", async () => {
    class SahteKimlik {
      constructor(_d: { id: string; password: string }) {}
    }
    vi.stubGlobal("PasswordCredential", SahteKimlik);
    vi.stubGlobal("navigator", {
      credentials: {
        store: vi.fn().mockRejectedValue(new Error("reddedildi")),
      },
    });

    // FIRLATMAMALI: kimlik deposuna yazamamak GIRISI bozmaz. Kullanici
    // iceri girdi; "parolan kaydedilemedi" hatasi, basarili bir islemi
    // basarisiz gibi okuturdu.
    await expect(kimligiSakla("x", PAROLA)).resolves.toBeUndefined();
    vi.unstubAllGlobals();
  });
});

describe("giris formu isaretlemesi (parola yoneticisi icin)", () => {
  it("gercek <form>, name + autocomplete oznitelikleri yerinde", async () => {
    const kaynak = await import("node:fs").then((fs) =>
      fs.readFileSync("components/GirisFormu.tsx", "utf8"),
    );

    // GERCEK FORM: `onSubmit` bir `<form>` uzerinde olmali. Tarayicinin
    // parola yoneticisi "gonderim" olayini arar; `div` + `onClick`
    // kaydetmeyi HIC teklif ettirmezdi.
    expect(kaynak).toContain("motion.form");
    expect(kaynak).toContain("onSubmit={onSubmit}");

    // KULLANICI ADI ALANLARI: `autocomplete` tek basina yetmiyor —
    // tarayicilar kararli bir `name` de arar.
    expect(kaynak).toContain('name="telefon"');
    expect(kaynak).toContain('name="email"');
    expect(kaynak).toMatch(/autoComplete="username"/);

    // PAROLA ALANI.
    expect(kaynak).toContain('name="password"');
    expect(kaynak).toContain('autoComplete="current-password"');

    // PAROLA ARTIK `localStorage`A YAZILMIYOR: eski surumde bir
    // `localStorage.setItem` yigini vardi; hepsi `lib/kimlik-deposu.ts`e
    // tasindi ve orada parola HIC gecmiyor.
    expect(kaynak).not.toContain("localStorage.setItem");
  });
});
