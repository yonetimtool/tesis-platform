// (P171) HTML BASMAYA IZINLI YUZEYLER — TAM LISTE.
//
// =========================================================================
// KILITLENEN KUSUR SINIFI
// =========================================================================
// Sunucu artik ZENGIN METIN alanlarini yazma aninda temizliyor
// (`backend/app/temizleme.py`) ve web o alanlari HTML olarak ciziyor.
// Tehlike, korumanin KAPSAMININ SESSIZCE KAYMASIDIR:
//
//   * Birisi TEMIZLENMEYEN bir alani (duyuru govdesi, etkinlik aciklamasi,
//     karar defteri metni) HTML olarak cizerse, o alan icin sunucu tarafi
//     KORUMA YOKTUR — duz metin alanlaridir ve bilincli olarak
//     temizleyiciden GECMEZLER (HTML temizleyicisi duz metni korumaz,
//     BOZAR: "5 < 10" -> "5 &lt; 10").
//   * Yani yeni bir `dangerouslySetInnerHTML`, sunucu tarafi bir kararla
//     ESLESMEK ZORUNDA. Bu test o eslesmeyi zorunlu kilar.
//
// Liste kisa tutuldu ve KISA KALMALI: her yeni giris, backend'deki
// `ZENGIN_ALANLAR` envanterinde bir karsiligi olduğunu gostermeli.
import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";

// GEZINME ORTAK YARDIMCIDAN (`tests/tarama.ts`): depo kurali, her
// tarayicinin kendi dizin gezmesini YAZMAMASI. Gerekcesi orada yazili —
// elle yazilmis bir gezinme sessizce BOS donebilir ve yokluk iddialari
// bos kume uzerinde her zaman dogru cikar, yani kilit hicbir sey
// olcmeden yesil kalir.
import { taranacakKaynaklar } from "./tarama";

/** HTML basmasina IZIN VERILEN dosyalar ve NEDENI. */
const IZINLI: Record<string, string> = {
  "app/layout.tsx":
    "Tema sinifini ilk boyamadan once atayan SABIT betik — kullanici verisi YOK.",
  "components/profil/yasal-metinler.tsx":
    "KVKK govdesi. Sunucu yazma aninda beyaz listeyle temizliyor " +
    "(`KvkkMetinCreate.govde` -> `ZenginHtml`) ve mevcut satirlar goc 0066 " +
    "ile onarildi.",
};

describe("HTML basan yuzeyler", () => {
  it("YALNIZ izinli dosyalar `dangerouslySetInnerHTML` kullanir", () => {
    const kullananlar: string[] = [];
    for (const [yol, kaynak] of taranacakKaynaklar(["app", "components"], [
      ".tsx",
      ".ts",
    ])) {
      // Yorumda gecmesi serbest (orada NEDEN kullanildigi/kullanilmadigi
      // yaziyor); JSX ozniteligi olarak gecmesi listeye tabi.
      if (/dangerouslySetInnerHTML=\{/.test(kaynak)) kullananlar.push(yol);
    }
    expect(kullananlar.sort()).toEqual(Object.keys(IZINLI).sort());
  });

  it("her izinli giris bir GEREKCE tasir", () => {
    for (const [yol, neden] of Object.entries(IZINLI)) {
      expect(neden.length, yol).toBeGreaterThan(40);
    }
  });

  it("KVKK govdesi SUNUCUDAN geldigi gibi cizilir — istemcide ikinci temizlik YOK", () => {
    // Ikinci bir temizleyici, "asil koruma nerede" sorusunu
    // bulaniklastirir ve sunucu tarafi bir gun gevsedginde bunu GIZLERDI.
    const kaynak = readFileSync(
      "components/profil/yasal-metinler.tsx",
      "utf8",
    );
    expect(kaynak).toContain("__html: data.govde");
    expect(kaynak).not.toContain("DOMPurify");
    expect(kaynak).not.toContain("zenginMetniOku");
  });
});
