// (P167 §5) RAPOR MODALI — KATALOG ILE ALAN SOZLUGUNUN KILIDI.
//
// =========================================================================
// KILITLENEN KUSUR SINIFI
// =========================================================================
// Katalog her rapor icin `alanlar: string[]` doner ve modal o adlari
// `ALAN_TANIMLARI` sozlugunden cozup cizer. Sunucu bir alan adi dondurup
// istemcide karsiligi olmazsa, `alanCiz` `null` doner ve o suzgec
// KULLANICIYA HIC GORUNMEZ.
//
// Bu SESSIZ bir kayiptir: ekran calisir gorunur, rapor uretilir, ama
// kullanici sunucunun kabul ettigi bir suzgeci hic goremez. Ekranda bir
// hata cikmaz, log'a bir satir dusmez.
//
// Bu test o sinifi kilitler: backend'in `KATALOG_KAYITLARI` tablosundaki
// HER alan adinin istemci sozlugunde bir karsiligi olmalidir.
//
// =========================================================================
// NEDEN BACKEND KAYNAGINI OKUYORUZ
// =========================================================================
// Alan listesini burada elle tekrarlamak, testin kendisini ucuncu bir
// kopya yapardi — ve o kopya eskidiginde test YESIL kalarak kusuru
// gizlerdi. Kaynak dosyayi okumak, tek dogru kaynagi korur.
import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import {
  ALAN_TANIMLARI,
  KATEGORI_BASLIGI,
  KATEGORI_VURGUSU,
  baslangicDurumu,
  govdeyeCevir,
} from "@/lib/rapor-alanlari";

const KOK = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const MOTOR = join(KOK, "backend", "app", "routers", "rapor_motoru.py");

/** Kaynaktan YORUM SATIRLARINI atar: katalog kayitlarinin arasindaki
 *  aciklamalar parantez ve tirnak icerebilir ve taramayi yaniltirdi. */
function yorumsuz(): string {
  return readFileSync(MOTOR, "utf8")
    .split("\n")
    .filter((satir) => !satir.trimStart().startsWith("#"))
    .join("\n");
}

/**
 * Her `KatalogKaydi(...)` kaydinin KATEGORISI ve ALAN DEMETI.
 *
 * Kayit sirasi: baslik, aciklama, KATEGORI, (ALANLAR), agir=...
 * Kategori dizesinden sonraki ilk parantez, alan demetidir.
 */
function kayitlar(): { kategori: string; alanlar: string[] }[] {
  const cikti: { kategori: string; alanlar: string[] }[] = [];
  for (const m of yorumsuz().matchAll(
    /"(listeler|ekstreler|dokumler)",\s*\(([^)]*)\)/g,
  )) {
    cikti.push({
      kategori: m[1],
      alanlar: [...m[2].matchAll(/"([a-z0-9_]+)"/g)].map((p) => p[1]),
    });
  }
  return cikti;
}

function katalogAlanlari(): string[] {
  return [...new Set(kayitlar().flatMap((k) => k.alanlar))];
}

function katalogKategorileri(): string[] {
  return [...new Set(kayitlar().map((k) => k.kategori))];
}

describe("rapor alan sozlugu", () => {
  it("katalogun DONDURDUGU her alanin ekran karsiligi VAR", () => {
    const alanlar = katalogAlanlari();
    // Tarama bir sey bulamadiysa test anlamsizdir; bunu da kilitliyoruz.
    expect(alanlar.length).toBeGreaterThan(10);
    const eksik = alanlar.filter((a) => !(a in ALAN_TANIMLARI));
    expect(eksik).toEqual([]);
  });

  it("katalogun her KATEGORISININ basligi ve rengi VAR", () => {
    const kategoriler = katalogKategorileri();
    expect(kategoriler.length).toBeGreaterThan(0);
    for (const k of kategoriler) {
      expect(KATEGORI_BASLIGI[k], k).toBeDefined();
      expect(KATEGORI_VURGUSU[k], k).toBeDefined();
    }
  });

  it("ONAY KUTULARI dogru varsayilanla baslar", () => {
    // KVKK anahtari `ismi_goster` ACIK baslar: kapali baslasaydi her
    // rapor adsiz cikardi ve kullanici her seferinde acmak zorunda kalirdi.
    const d = baslangicDurumu(["ismi_goster", "grup_goster", "iletisim_goster"]);
    expect(d.ismi_goster).toBe(true);
    expect(d.grup_goster).toBe(false);
    // (P168 §3) ILETISIM KAPALI baslar: telefon/e-posta kisisel veridir
    // ve kapiya asilacak bir listede varsayilan olarak bulunmamali.
    expect(d.iletisim_goster).toBe(false);
  });

  it("(P168 §3) TARIH VARSAYILANLARI: yilbasi -> bugun", () => {
    // Brief'in acik istegi. Bos birakmak, kullaniciyi her rapor icin iki
    // tarih doldurmaya ve zorunlu alan hatasi almaya zorlardi.
    const d = baslangicDurumu(["baslangic", "bitis", "tazminat_tarihi"]);
    const yil = new Date().getUTCFullYear();
    expect(d.baslangic).toBe(`${yil}-01-01`);
    expect(d.bitis).toBe(new Date().toISOString().slice(0, 10));
    // TAZMINAT TARIHI DOLDURULMAZ ve bu bilincli: o "hangi tarihe gore
    // gecikme hesaplansin" sorusudur. Yilbasi yapsaydik tazminati YILIN
    // BASINA gore hesaplatirdik — sessizce yanlis rakam.
    expect(d.tazminat_tarihi).toBe("");
  });

  it("BOS alan govdeye KONULMAZ", () => {
    // Bos dizgeyi tarih diye gondermek sunucuda dogrulama hatasi uretirdi.
    // (Varsayilanlar doldurulmus gelse de kullanici alani BOSALTABILIR.)
    const govde = govdeyeCevir({ baslangic: "", bitis: "2026-01-31" });
    expect("baslangic" in govde).toBe(false);
    expect(govde.bitis).toBe("2026-01-31");
  });

  it("`false` GONDERILIR — bos sayilip dusurulmez", () => {
    // `ismi_goster: false` KVKK'nin ta kendisidir. "Bos" sayilip
    // dusurulseydi, ad sutununu kaldirmak isteyen kullanici kapiya
    // asilacak listede adlari BASILI gorurdu.
    const govde = govdeyeCevir({ ismi_goster: false });
    expect(govde.ismi_goster).toBe(false);
  });

  it("TL girdisi KURUSA cevrilir", () => {
    // Sunucu her yerde kurus konusur; bir raporda istisna acmak 100 TL'yi
    // 1 TL saymak olurdu.
    expect(govdeyeCevir({ min_tutar_kurus: "1250,50" }).min_tutar_kurus).toBe(125050);
    expect(govdeyeCevir({ min_tutar_kurus: "100" }).min_tutar_kurus).toBe(10000);
  });

  it("AY ve YIL alanlari SAYI gonderilir", () => {
    // Sunucu `int` bekliyor (`ge=1, le=12`); metin gondermek dogrulama
    // hatasi uretirdi.
    const govde = govdeyeCevir({ baslangic_ay: "3", baslangic_yil: "2026" });
    expect(govde.baslangic_ay).toBe(3);
    expect(govde.baslangic_yil).toBe(2026);
  });

  it("BOS coklu secim govdeye KONULMAZ, dolusu KONULUR", () => {
    expect("gelir_gider_tanim_idler" in govdeyeCevir({ gelir_gider_tanim_idler: [] })).toBe(
      false,
    );
    expect(
      govdeyeCevir({ gelir_gider_tanim_idler: ["a", "b"] }).gelir_gider_tanim_idler,
    ).toEqual(["a", "b"]);
  });

  it("TANIMSIZ alan govdeye SIZMAZ", () => {
    // Sozlukte olmayan bir ad, sunucunun tanimadigi bir alandir; govdeye
    // koymak 422 uretirdi.
    expect(govdeyeCevir({ olmayan_alan: "x" })).toEqual({});
  });
});
