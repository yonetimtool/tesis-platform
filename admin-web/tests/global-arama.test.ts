// (P162 §3) GLOBAL ARAMA — KAPSAM ve YETKI KILIDI.
//
// Brief iki sey istiyor ve ikisi de sessizce bozulabilir:
//
//   1. KAPSAM: arama on yediden fazla kaynagi taramali. Sunucu bir kaynak
//      donuyor ama istemci tablosunda yoksa, sonuca tiklayan kullanici
//      KOK ROTAYA duser — yani aradigi kaydi bulamaz. Hicbir hata da
//      alinmaz; en sinsi bozulma turu.
//
//   2. YETKI: "kullanici goremeyecegi kaydi arama sonucunda GORMEYECEK."
//      Bu kural SUNUCUDA uygulanir ve orada bir arama testi zaten var
//      (`backend/tests/test_arama.py`). BURADA olculen sey ISTEMCININ
//      kurali kendi basina TEKRAR ETMEDIGI: istemcide rol suzgeci
//      yazilsaydi ikinci bir dogruluk kaynagi olurdu ve ikisi ayrisirdi.
import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import { PALET_HEDEF, vuruslariGrupla } from "@/components/ui/komut-paleti";

const KOK = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const SUNUCU = readFileSync(
  join(KOK, "..", "backend", "app", "routers", "arama.py"),
  "utf8",
);
const BFF = readFileSync(join(KOK, "app", "api", "panel", "arama", "route.ts"), "utf8");

/** Sunucudaki `KAYNAKLAR` tablosundan kaynak adlarini okur. */
function sunucuKaynaklari(): string[] {
  const blok = SUNUCU.slice(
    SUNUCU.indexOf("KAYNAKLAR: tuple[Kaynak, ...] = ("),
    SUNUCU.indexOf("@router.get"),
  );
  return [...blok.matchAll(/Kaynak\("([a-z]+)"/g)].map((m) => m[1]);
}

describe("(P162) kapsam — istemci tablosu SUNUCUYLA ayni", () => {
  it("sunucu en az 17 kaynak tariyor", () => {
    // Brief 18 tur istedi; `dokuman` BILEREK kapsam disi (gerekce
    // `arama.py` icinde yazili: gorunurlugu ust kayda bagli, rol
    // kumesiyle degil).
    expect(sunucuKaynaklari().length).toBeGreaterThanOrEqual(17);
  });

  it("SUNUCUNUN DONDUGU HER KAYNAK istemcide bir hedefe baglanir", () => {
    const eksik = sunucuKaynaklari().filter((k) => !PALET_HEDEF[k]);
    expect(eksik, `hedefi olmayan kaynak: ${eksik.join(", ")}`).toEqual([]);
  });

  it("ISTEMCIDE FAZLADAN kaynak yok (olu satir gostermez)", () => {
    const sunucuda = new Set(sunucuKaynaklari());
    const fazla = Object.keys(PALET_HEDEF).filter((k) => !sunucuda.has(k));
    expect(fazla, `sunucuda olmayan kaynak: ${fazla.join(", ")}`).toEqual([]);
  });

  it("her hedefin rotasi ve ikonu VAR", () => {
    for (const [ad, h] of Object.entries(PALET_HEDEF)) {
      expect(h.rota.startsWith("/"), `${ad} rotasi`).toBe(true);
      expect(h.ikon.length, `${ad} ikonu`).toBeGreaterThan(10);
    }
  });
});

describe("(P162) YETKI — istemci kurali TEKRAR ETMEZ", () => {
  it("istemcide rol suzgeci YOK", () => {
    const istemci = readFileSync(
      join(KOK, "components", "ui", "komut-paleti.tsx"),
      "utf8",
    );
    // Rol adlari istemcide gecerse, biri orada bir yetki karari vermeye
    // baslamis demektir. Yetki SUNUCUDA — iki kaynak ayrisamaz.
    for (const rol of ["yonetici", "resident", "guvenlik_amiri", "denetci", "tesis_gorevlisi"]) {
      expect(istemci, `istemcide rol gecmemeli: ${rol}`).not.toContain(rol);
    }
  });

  it("BFF suzgec uygulamaz, yalnizca vekillik eder", () => {
    expect(BFF).toContain("proxyJson");
    for (const rol of ["yonetici", "resident", "denetci"]) {
      expect(BFF).not.toContain(rol);
    }
  });

  it("sunucu rol kumelerini ROUTERLARDAN okur, yeniden yazmaz", () => {
    // `_rol_kumesi(...)` disinda elle yazilmis bir `frozenset({...})`
    // varsa iki liste ayrisabilir hale gelir.
    const blok = SUNUCU.slice(
      SUNUCU.indexOf("KAYNAKLAR: tuple[Kaynak, ...] = ("),
      SUNUCU.indexOf("@router.get"),
    );
    const kaynakSatirlari = [...blok.matchAll(/Kaynak\("[a-z]+",\s*([^,]+),/g)].map(
      (m) => m[1].trim(),
    );
    expect(kaynakSatirlari.length).toBeGreaterThanOrEqual(17);
    for (const ifade of kaynakSatirlari) {
      expect(ifade, `elle yazilmis rol kumesi: ${ifade}`).toContain("_rol_kumesi(");
    }
  });

  it("TALEP kaynagi SATIR KAPSAMINI da uygular (rol kumesi yetmez)", () => {
    // Sakin talepleri gorebilir ama YALNIZ kendininkileri. Bu satir
    // dusesse komsunun talebi arama kutusundan okunurdu.
    expect(SUNUCU).toContain("_OWN_SCOPED_ROLES");
    expect(SUNUCU).toContain("Complaint.acan_user_id == user.id");
  });

  it("DOKUMAN kapsam disi ve GEREKCESI yazili", () => {
    // Sessizce atlanmis olmasin: kararin kendisi kodda durmali.
    expect(SUNUCU).toContain("DOKUMAN (`varlik_eki`) BILEREK KAPSAM DISI");
    expect(sunucuKaynaklari()).not.toContain("dokuman");
  });
});

describe("(P162) gruplama — klavye gezinmesi kirilmaz", () => {
  const v = (kaynak: string, id: string) => ({ kaynak, id, baslik: id });

  it("bitisik ayni kaynaklar TEK grup olur", () => {
    const g = vuruslariGrupla([v("kisi", "a"), v("kisi", "b"), v("daire", "c")]);
    expect(g.map((x) => x.kaynak)).toEqual(["kisi", "daire"]);
    expect(g[0].ogeler).toHaveLength(2);
  });

  it("BASLANGIC INDEKSLERI duz listeyle ayni", () => {
    const g = vuruslariGrupla([
      v("kisi", "a"),
      v("kisi", "b"),
      v("daire", "c"),
      v("gorev", "d"),
    ]);
    expect(g.map((x) => x.baslangic)).toEqual([0, 2, 3]);
    // Toplam oge sayisi korunur — hicbir vurus dusmez.
    expect(g.reduce((n, x) => n + x.ogeler.length, 0)).toBe(4);
  });

  it("SUNUCU SIRASI korunur (istemcide yeniden siralanmaz)", () => {
    const g = vuruslariGrupla([v("gorev", "a"), v("kisi", "b"), v("gorev", "c")]);
    // `gorev` iki kez geciyor: istemci onlari birlestirip sirayi
    // degistirmemeli — sunucunun oncelik karari varsa bozulurdu.
    expect(g.map((x) => x.kaynak)).toEqual(["gorev", "kisi", "gorev"]);
  });

  it("bos liste bos grup verir", () => {
    expect(vuruslariGrupla([])).toEqual([]);
  });
});
