// (P245) DOLGU UZERINDE METIN — `-edge` GRAFIK ESIGIDIR, METIN DEGIL.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// Uc yerde ayni hata vardi ve hepsi GERCEK TARAYICIDA goruldu:
//
//   * `/rezervasyon-yonetimi` — zemin `--yz-success-edge` (#159946),
//     metin `--yz-success-ink` (#107736): yesil uzerine yesil, 1.53.
//     Etiket okunmuyordu.
//   * `pano/widget-seridi` — beyaz metin `--yz-danger-edge` (#ef4444)
//     uzerinde 3.76; esik 4.5 ve metin KUCUK.
//
// Tasarim sisteminin kurali P244 asama 1'de yazilmisti ama hicbir yerde
// ZORLANMIYORDU:
//   `-edge` -> ANLAMLI GRAFIK (halka, kenar, isaret) esigi 3.0
//   `-ink`  -> METIN esigi 4.5, ACIK yuzey uzerinde
//   `-fill` -> DOLGU yuzeyi; uzerine `--yz-on-fill` gelir
//
// ===========================================================================
// NEDEN KAYNAK TARAMASI
// ===========================================================================
// jsdom RENK COZMEZ (P226 dersi): bir DOM testi bu ekrani sorunsuz
// bulur. Olculebilecek en yakin YAPISAL sey, ayni stil blogunda
// `background`in `-edge` ve `color`in `-ink` olmasi.
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

const KOK = join(__dirname, "..");

function kaynaklar(): [string, string][] {
  const cikti: [string, string][] = [];
  const tara = (dizin: string) => {
    for (const ad of readdirSync(dizin)) {
      const tam = join(dizin, ad);
      if (statSync(tam).isDirectory()) {
        if (ad === "node_modules" || ad === ".next") continue;
        tara(tam);
        continue;
      }
      if (ad.endsWith(".tsx")) cikti.push([tam, readFileSync(tam, "utf8")]);
    }
  };
  tara(join(KOK, "app"));
  tara(join(KOK, "components"));
  return cikti;
}

/**
 * Ayni `style` blogunda `background: ...-edge` ve `color: ...-ink`.
 *
 * Iki ozellik arasinda en fazla birkac satir olabilir; blok siniri
 * `}` ile kabaca kesilir ki komsu bloklar birbirine karismasin.
 */
const EDGE_ZEMIN_INK_METIN =
  /background:\s*"var\(--yz-(\w+)-edge\)"[^}]{0,200}?color:\s*"var\(--yz-\1-ink\)"/;

/** `-edge` zemin uzerinde HAM beyaz metin. */
const EDGE_ZEMIN_BEYAZ = /background:\s*"var\(--yz-\w+-edge\)"[^}]{0,200}?color:\s*"#f{3,6}"/i;

describe("(P245) dolgu uzerinde metin", () => {
  const DOSYALAR = kaynaklar();

  it("TARAMA gercekten calisiyor (vakum degil)", () => {
    expect(DOSYALAR.length).toBeGreaterThan(100);
    expect(
      EDGE_ZEMIN_INK_METIN.test(
        'style={{ background: "var(--yz-success-edge)", color: "var(--yz-success-ink)" }}',
      ),
    ).toBe(true);
    // Ayni ailenin DISINDA kalan esleme suclu SAYILMAZ (ornegin
    // kirmizi zemin uzerinde notr metin ayri bir karardir).
    expect(
      EDGE_ZEMIN_INK_METIN.test(
        'style={{ background: "var(--yz-success-edge)", color: "var(--yz-danger-ink)" }}',
      ),
    ).toBe(false);
  });

  it("AYNI AILENIN `-edge` ZEMINI + `-ink` METNI YOK", () => {
    const suclular = DOSYALAR.filter(([, k]) => EDGE_ZEMIN_INK_METIN.test(k)).map(([y]) =>
      y.slice(KOK.length + 1),
    );
    expect(
      suclular.sort(),
      `ayni tonun edge zemini + ink metni:\n${suclular.join("\n")}`,
    ).toEqual([]);
  });

  it("`-edge` ZEMIN uzerinde HAM BEYAZ metin YOK", () => {
    // Beyaz bazi `-edge` tonlarinda AA'yi tutar (accent 5.17), bazisinda
    // tutmaz (danger 3.76). Ham `#fff` yerine `--yz-on-fill` ve dolgu
    // icin `-fill` tonu kullanilir; boylece karar TEK YERDE olculur.
    const suclular = DOSYALAR.filter(([, k]) => EDGE_ZEMIN_BEYAZ.test(k)).map(([y]) =>
      y.slice(KOK.length + 1),
    );
    expect(suclular.sort(), `edge zemin + ham beyaz:\n${suclular.join("\n")}`).toEqual([]);
  });
});
