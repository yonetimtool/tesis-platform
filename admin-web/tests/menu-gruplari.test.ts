// (P133.1) KENAR CUBUGU BOLUMLERI — KUME duzeyinde.
//
// `kabuk-rol-menusu.dom.test.ts` CIZIMI olcuyor; bu dosya VERIYI olcuyor.
// Ikisi ayri hata sinifi: gruplama dogru olup kabugun onu okumamasi da,
// kabuk dogru cizip bir sayfanin HIC bir bolume dusmemesi de mumkundur.
//
// EN PAHALI SONUC: bir sayfanin sessizce KAYBOLMASI. Gruplama bir suzgec
// degildir — 28 satiri 5 bolume dagitir — ama bir oge hicbir gruba
// yazilmazsa menuden duser ve kimse fark etmez. Ilk test tam olarak budur.
import { readFileSync, readdirSync } from "node:fs";
import { join, resolve } from "node:path";

import { describe, expect, it } from "vitest";

import {
  GRUP_ANAHTARI,
  KATLI_GRUPLAR,
  PROFIL_OGESI,
  _OGELER,
  menuGruplari,
  profilGorunur,
  rotaninGrubu,
} from "@/lib/menu";
import { rotaRoldeGorunur, rotaYuzeyi } from "@/lib/yuzey";

describe("(P133.1) hicbir sayfa KAYBOLMADI", () => {
  it("her ogenin bir grubu var ve grup tanimli", () => {
    for (const o of _OGELER) {
      expect(GRUP_ANAHTARI[o.grup], `${o.href} bilinmeyen grup: ${o.grup}`).toBeTruthy();
    }
  });

  it("ayni href IKI kez listelenmemis", () => {
    const hrefler = _OGELER.map((o) => o.href);
    expect(hrefler.length).toBe(new Set(hrefler).size);
  });

  it("gruplama ROLE GORUNEN kumeyi AYNEN tasir (eksiltmez, eklemez)", () => {
    // P133 acik sarti: "Rol kapisi bugunkuyle birebir ayni — gorunurluk
    // degismez." Bolumleme bir gorunurluk karari DEGILDIR; bu test onu
    // her rol/yuzey cifti icin dogrular.
    const ciftler = [
      ["tesis", "yonetici"],
      ["tesis", "denetci"],
      ["tesis", "admin"],
      ["tesis", "resident"],
      ["tesis", null],
      ["platform", "admin"],
      ["platform", "yonetici"],
    ] as const;

    for (const [yuzey, rol] of ciftler) {
      const beklenen = new Set(
        [..._OGELER.map((o) => o.href), PROFIL_OGESI.href].filter(
          (h) => rotaYuzeyi(h) === yuzey && rotaRoldeGorunur(h, rol),
        ),
      );
      const gelen = new Set(
        menuGruplari(yuzey, rol).flatMap((g) => g.ogeler.map((o) => o.href)),
      );
      if (profilGorunur(yuzey, rol)) gelen.add(PROFIL_OGESI.href);

      expect([...gelen].sort(), `${yuzey}/${rol}`).toEqual([...beklenen].sort());
    }
  });
});

describe("(P133.1) bolumleme", () => {
  it("BOS bolum donmez", () => {
    // Denetci dort sayfa goruyor; bes baslik altinda dort satir gostermek,
    // menuyu kisaltmak icin yapilan isi tersine cevirirdi.
    for (const rol of ["yonetici", "denetci", "admin"]) {
      for (const g of menuGruplari("tesis", rol)) {
        expect(g.ogeler.length, `${rol}/${g.id}`).toBeGreaterThan(0);
      }
    }
  });

  it("KATLI bolumler isaretli, ustteki bolumler degil", () => {
    const gruplar = menuGruplari("tesis", "yonetici");
    for (const g of gruplar) {
      expect(g.katli, g.id).toBe(KATLI_GRUPLAR.includes(g.id));
    }
    // Ve gercekten hem katli hem ustte bolum VAR (tek tarafli bir liste
    // bu testi anlamsiz kilardi).
    expect(gruplar.some((g) => g.katli)).toBe(true);
    expect(gruplar.some((g) => !g.katli)).toBe(true);
  });

  it("PANELDE tesis bolumleri, TESISTE platform bolumu YOK", () => {
    const panel = menuGruplari("platform", "admin").map((g) => g.id);
    expect(panel).not.toContain("guvenlik");
    expect(panel).not.toContain("finans");
    const tesis = menuGruplari("tesis", "yonetici").map((g) => g.id);
    expect(tesis).not.toContain("platform");
  });
});

describe("(P133.1) acilista hangi bolum acik", () => {
  it("bulunulan sayfanin bolumu", () => {
    expect(rotaninGrubu("/dashboard")).toBe("guvenlik");
    expect(rotaninGrubu("/dues")).toBe("finans");
    expect(rotaninGrubu("/users")).toBe("yonetim");
    expect(rotaninGrubu("/announcements")).toBe("iletisim");
    expect(rotaninGrubu("/units")).toBe("tesis");
  });

  it("ALT ROTA da ust ogenin bolumune duser", () => {
    // `/tenants/abc` menude yoktur ama `/tenants`in bolumu acilmali;
    // yoksa detay sayfasinda menu kullaniciyi bulundugu yerden koparirdi.
    expect(rotaninGrubu("/tenants/9f2a")).toBe("platform");
    expect(rotaninGrubu("/reports/dues")).toBe("finans");
  });

  it("BILINMEYEN rota null doner (kabuk ilk bolume duser)", () => {
    expect(rotaninGrubu("/boyle-bir-sayfa-yok")).toBeNull();
    // Profil BILEREK bolum disidir: kullanicinin kendi kaydi, yonetim isi
    // degil — alt bolumde, cikisin yaninda durur.
    expect(rotaninGrubu("/profil")).toBeNull();
  });
});

describe("(P133.1) SATIR SAYISI hedefi", () => {
  // Kerem'in olculebilir sarti: 900px yukseklikte kaydirmasiz ~10 satir.
  // Onceki hâl 28 duz satirdi (yonetici) ve kaydirma cubuguna tasiyordu.
  //
  // NE SAYILIR: acilista GORUNEN satirlar — bolum basliklari + acik olan
  // bolumun ogeleri + "Daha fazla" satiri + profil. Piksel olcmuyoruz
  // (jsdom duzen hesaplamaz); satir sayisi hedefin dogru vekilidir cunku
  // satir yuksekligi sabittir.
  function gorunenSatir(yuzey: "tesis" | "platform", rol: string, pathname: string) {
    const gruplar = menuGruplari(yuzey, rol);
    const aktif = rotaninGrubu(pathname) ?? gruplar[0]?.id ?? null;
    const ust = gruplar.filter((g) => !g.katli);
    const katli = gruplar.filter((g) => g.katli);
    const basliklar = ust.length;
    const acikOgeler = ust.filter((g) => g.id === aktif).reduce((n, g) => n + g.ogeler.length, 0);
    const dahaFazlaSatiri = katli.length > 0 ? 1 : 0;
    const profil = profilGorunur(yuzey, rol) ? 1 : 0;
    return basliklar + acikOgeler + dahaFazlaSatiri + profil;
  }

  it("YONETICI: 28 duz satir -> en cok 12 gorunur satir", () => {
    // En kotu hâl: en KALABALIK bolum acikken (Guvenlik, 10 oge).
    const enKotu = Math.max(
      gorunenSatir("tesis", "yonetici", "/dashboard"),
      gorunenSatir("tesis", "yonetici", "/dues"),
      gorunenSatir("tesis", "yonetici", "/units"),
      gorunenSatir("tesis", "yonetici", "/profil"),
    );
    expect(enKotu).toBeLessThanOrEqual(12);
    // Ve gercekten 28'den cok daha az (test "0 satir" ile de gecmesin).
    expect(enKotu).toBeGreaterThan(4);
  });

  it("DENETCI ve ADMIN de kaydirmasiz", () => {
    expect(gorunenSatir("tesis", "denetci", "/raporlar")).toBeLessThanOrEqual(10);
    expect(gorunenSatir("platform", "admin", "/tenants")).toBeLessThanOrEqual(10);
  });
});

describe("(P133.5) panel.* AYNI kenar cubugunu kullanir", () => {
  // Kerem'in acik sarti: "kenar cubugu iki bilesene CATALLANMAZ."
  //
  // Catallanma sessiz bir hatadir: iki dosya bir sure ayni durur, sonra
  // biri duzeltilir otekI unutulur ve panel eski menuyle kalir. Bu test
  // catallanmayi YAPISAL olarak imkânsiz kilmaz ama GORUNUR kilar.
  it("kenar cubugu TEK dosyada tanimli", () => {
    const kok = resolve(__dirname, "..");
    const bilesenler = readdirSync(join(kok, "components")).filter((a) =>
      a.endsWith(".tsx"),
    );
    const cubuklar = bilesenler.filter((ad) => {
      const s = readFileSync(join(kok, "components", ad), "utf8");
      // Kenar cubugunu cizen dosya `menuGruplari`yi cagirandir.
      return s.includes("menuGruplari(");
    });
    expect(cubuklar, "kenar cubugu catallanmis").toEqual(["AppShell.tsx"]);
  });

  it("PLATFORM yuzeyi de bolumlenmis (duz liste DEGIL)", () => {
    const gruplar = menuGruplari("platform", "admin");
    expect(gruplar.length).toBeGreaterThan(1);
    // Panel yogun duzenini korur ama AYNI bolumleme dilini kullanir.
    for (const g of gruplar) expect(GRUP_ANAHTARI[g.id]).toBeTruthy();
  });
});
