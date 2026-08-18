// (P170 §2) KVKK YONETIMI PLATFORMA TASINDI — YUZEY VE YETKI KAPISI.
//
// =========================================================================
// EN PAHALI SONUC
// =========================================================================
// Yonetim ekraninin panele tasinmis GORUNUP tesis yuzeyinde acik kalmasi.
// O durumda tesis yoneticisi menude gormese bile adresi yazip girer ve
// yasal metin yayinlamaya devam ederdi — yani kapi yalnizca goz onunde
// kapanmis olurdu.
//
// AYRICA OLCULEN: OKUMA yuzeyinin YERINDE kaldigi. Yonetim tasindi diye
// kullanicinin kendi aydinlatma metnini okuyamamasi, aydinlatmanin
// kendisini imkansiz kilardi.
import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";

import { _OGELER, type MenuOgesi } from "@/lib/menu";
import { PLATFORM_ROTALARI, ROTA_ROLLERI, TESIS_ROTALARI } from "@/lib/yuzey";
import { PROFIL_BOLUMLERI } from "@/lib/profil-bolumleri";

const YOL = "/kvkk-metinler";

describe("yonetim yuzeyi", () => {
  it("PLATFORM rotasi oldu, TESIS rotasi olmaktan CIKTI", () => {
    expect(PLATFORM_ROTALARI as readonly string[]).toContain(YOL);
    expect(TESIS_ROTALARI as readonly string[]).not.toContain(YOL);
  });

  it("TESIS rol kapisindan CIKARILDI — `yonetici` icin giris yok", () => {
    // `ROTA_ROLLERI` tesis rotalarinin rol haritasidir. Girdi burada
    // kalsaydi, tesis menusunde yeniden gorunurdu.
    expect(Object.keys(ROTA_ROLLERI)).not.toContain(YOL);
  });

  it("MENUDE `platform` grubunda, `yonetim` grubunda DEGIL", () => {
    const oge = (_OGELER as readonly MenuOgesi[]).find((m) => m.href === YOL);
    expect(oge).toBeDefined();
    expect(oge?.grup).toBe("platform");
  });

  it("PAZARLAMA TERCIHLERI (`/kvkk`) TESISTE KALDI — karistirilmadi", () => {
    // Biri tesisin YAYINLADIGI yasal metin, oteki kullanicinin KENDI izni.
    expect(TESIS_ROTALARI as readonly string[]).toContain("/kvkk");
    expect(PLATFORM_ROTALARI as readonly string[]).not.toContain("/kvkk");
  });
});

describe("olu kod kalmadi", () => {
  const VEKIL = readFileSync("lib/panel-vekil.ts", "utf8");

  it("tesis yuzeyindeki BFF esleme girisleri KALDIRILDI", () => {
    // `kvkk-metinler` -> `/kvkk/metinler` ve `kvkk-metin` -> `/kvkk/metin`
    // uclari backend'de artik YOK; beyaz listede birakmak, 404'e giden
    // olu bir yol tutmak olurdu.
    expect(VEKIL).not.toContain("kvkk-metinler");
    expect(VEKIL).not.toContain("kvkk-metin");
  });

  it("sayfa PLATFORM ucunu cagiriyor, panel vekilini DEGIL", () => {
    const sayfa = readFileSync("app/(protected)/kvkk-metinler/page.tsx", "utf8");
    expect(sayfa).toContain("/api/tenants/${tesisId}/kvkk");
    expect(sayfa).not.toContain("/api/panel/kvkk");
    // TESIS SECICI: hedef tenant oturumdan TURETILMEZ, secilir.
    expect(sayfa).toContain("setTesisId");
  });
});

describe("okuma yuzeyi YERINDE", () => {
  it("profilde `yasal` bolumu var", () => {
    expect(PROFIL_BOLUMLERI.map((b) => b.id)).toContain("yasal");
  });

  it("okuma bileseni BES METNI ve ONAY GECMISINI gosterir", () => {
    const bilesen = readFileSync("components/profil/yasal-metinler.tsx", "utf8");
    for (const tur of [
      "aydinlatma",
      "acik_riza",
      "gizlilik",
      "kullanim_kosullari",
      "cerez",
    ]) {
      expect(bilesen).toContain(tur);
    }
    expect(bilesen).toContain("/api/kvkk/onaylarim");
    // ESKIYEN ONAY ACIKCA SOYLENIR: sessiz birakmak, kullaniciya
    // OKUMADIGI bir metni onaylamis gibi gosterirdi.
    expect(bilesen).toContain("profilOnayEskimis");
  });

  it("okuma ucleri ROL KAPISI TASIMAZ (kapi oturumun kendisi)", () => {
    const metin = readFileSync("app/api/kvkk/metin/route.ts", "utf8");
    const onay = readFileSync("app/api/kvkk/onaylarim/route.ts", "utf8");
    for (const k of [metin, onay]) {
      expect(k).toContain("proxyJson");
      expect(k).not.toContain("admin");
    }
  });
});
