// P40 — BFF vekilinin BEYAZ LISTESI.
//
// Olculen sey iki yonlu: (1) panelin kullandigi her kaynak listede VAR mi,
// (2) listeye YANLISLIKLA tehlikeli bir sey girmis mi. Ikincisi kritik:
// "onek eslesmesi" gibi gevsek bir kural `finans/../users` turu girdilerle
// asilir; tam eslesen sozluk o sinifi tumden ortadan kaldirir — ama ancak
// sozlugun kendisi denetlenirse.
import { describe, expect, it } from "vitest";

import { OKUMA, SUZGECLER, YAZMA, okumaYolu, yazmaYolu } from "@/lib/panel-vekil";

describe("panel vekili — beyaz liste", () => {
  it("her yol MUTLAK ve gezinme parcasi ICERMEZ", () => {
    for (const [ad, yol] of Object.entries({ ...OKUMA, ...YAZMA })) {
      expect(yol.startsWith("/"), `${ad}: mutlak olmali`).toBe(true);
      expect(yol.includes(".."), `${ad}: gezinme parcasi`).toBe(false);
      expect(yol.includes("?"), `${ad}: sorgu yolda olmamali`).toBe(false);
      expect(yol.includes("//"), `${ad}: cift bolu`).toBe(false);
    }
  });

  it("bilinmeyen kaynak null doner (uydurulan yol backend'e GITMEZ)", () => {
    for (const kotu of ["users", "../users", "finans/../users", "", "PORTAL"]) {
      expect(okumaYolu(kotu), kotu).toBeNull();
      expect(yazmaYolu(kotu), kotu).toBeNull();
    }
  });

  it("YAZMA listesi HASSAS uclari ACMAZ", () => {
    // Kullanici/rol/tenant yonetimi panelde KENDI sayfalarindadir ve kendi
    // vekillerinden gecer; genel vekile girmesi, tek bir beyaz-liste
    // hatasinin yetki yuzeyini acmasi demekti.
    for (const yol of Object.values(YAZMA)) {
      expect(yol.startsWith("/users"), yol).toBe(false);
      expect(yol.startsWith("/tenants"), yol).toBe(false);
      expect(yol.startsWith("/auth"), yol).toBe(false);
    }
  });

  it("suzgec adlari YALNIZ bilinen kaynaklar icin tanimli", () => {
    for (const kaynak of Object.keys(SUZGECLER)) {
      expect(OKUMA[kaynak], `${kaynak} okuma listesinde yok`).toBeTruthy();
    }
  });

  it("okuma ve yazma AYRI: yazmaya acilan her ad bilincli secilmis", () => {
    // Okuma listesindeki bazi kaynaklar (orn. rapor katalogu, sablon)
    // YAZMAYA KAPALIDIR; ikisini tek sozluge indirmek, okumaya acmak
    // isterken yazmaya da acmak olurdu.
    expect(YAZMA["rapor-katalog"]).toBeUndefined();
    expect(YAZMA["site-aktar-sablon"]).toBeUndefined();
    expect(YAZMA["kasa-bakiyeleri"]).toBeUndefined();
    expect(YAZMA["portal-iletisim"]).toBeUndefined();
  });
});
