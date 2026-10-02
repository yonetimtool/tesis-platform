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
  GRUP_IKONU,
  PROFIL_OGESI,
  TANIM_SEKMELERI,
  _OGELER,
  kurulumGorunur,
  menuGruplari,
  ogeAktif,
  ogeBaglantisi,
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

  it("ayni BAGLANTI IKI kez listelenmemis", () => {
    // (P154 / Asama 7.1) OGE KIMLIGI ARTIK (rota + sorgu). Brief FINANS
    // bolumunde yedi satir istiyor ve altisi `/finans`in `tip` suzgeci —
    // yalniz `href`e bakan eski kural bunlari "kopya" sayardi.
    //
    // Tekillik SART: `key` ve aktiflik bu degerden okunuyor; iki ayni
    // baglanti, menude ayirt edilemeyen iki satir demekti.
    const baglantilar = _OGELER.map(ogeBaglantisi);
    expect(baglantilar.length).toBe(new Set(baglantilar).size);
  });

  it("SORGULU oge, rotasi ROL LISTESINDE olan bir sayfaya isaret eder", () => {
    // Sorgu `href`e gomulseydi (`"/finans?tip=gelir"`) rol/yuzey aramasi
    // TAM ESLESME yaptigi icin bosa duser ve oge HICBIR ROLDE gorunmezdi.
    for (const o of _OGELER.filter((x) => x.sorgu)) {
      expect(rotaYuzeyi(o.href), `${ogeBaglantisi(o)} yuzeysiz`).not.toBeNull();
    }
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

  it("(P166 §1) HICBIR BOLUM 'katli' DEGIL — alan kaldirildi", () => {
    // "Daha fazla"nin ardinda duran bir bolum kavrami kalkti. Bu testin
    // isi, alanin bir gun sessizce geri gelmemesi: `katli: true` tasiyan
    // bir grup, gizli menuyu yeniden acardi.
    for (const g of menuGruplari("tesis", "yonetici")) {
      expect(g, g.id).not.toHaveProperty("katli");
    }
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
    // (P167 §1.3) `/dashboard` artik GUVENLIK'in altinda degil, bagimsiz
    // "Ozet" sekmesi. Bolum kimligi olarak `ozet` doner ama kabuk onu
    // basliksiz cizer — kullanici acisindan bir bolum DEGIL, tek satir.
    expect(rotaninGrubu("/dashboard")).toBe("ozet");
    expect(rotaninGrubu("/dues")).toBe("finans");
    // (P251 §8) Kisiler kendi grubunda; eski `/users` yonlenir.
    expect(rotaninGrubu("/kisiler")).toBe("kisiler");
    expect(rotaninGrubu("/announcements")).toBe("iletisim");
    expect(rotaninGrubu("/units")).toBe("tesis");
  });

  it("ALT ROTA da ust ogenin bolumune duser", () => {
    // `/tenants/abc` menude yoktur ama `/tenants`in bolumu acilmali;
    // yoksa detay sayfasinda menu kullaniciyi bulundugu yerden koparirdi.
    expect(rotaninGrubu("/tenants/9f2a")).toBe("platform");
    expect(rotaninGrubu("/finans/maas-kartlari")).toBe("finans");
  });

  it("BILINMEYEN rota null doner (kabuk ilk bolume duser)", () => {
    expect(rotaninGrubu("/boyle-bir-sayfa-yok")).toBeNull();
    // Profil BILEREK bolum disidir: kullanicinin kendi kaydi, yonetim isi
    // degil — alt bolumde, cikisin yaninda durur.
    expect(rotaninGrubu("/profil")).toBeNull();
  });
});

describe("(P166 §1) TAM LISTE — gizli menu katmani yok", () => {
  // ESKI HEDEF: "acilista en cok 12 gorunur satir" (P133.1). O butce,
  // dort bolumu "Daha fazla"nin ardina saklayarak tutuluyordu.
  //
  // Kerem'in olcumu o cozumu curuttu: kullanici o satirin bir MENU
  // oldugunu anlamiyor, arkasindaki 30+ sayfayi HIC gormuyor. Yeni kural
  // bunun TERSI ve testi de tersine cevriliyor: hicbir sayfa gizlenmez,
  // liste uzarsa KAYDIRILIR.
  function acilistaGorunen(yuzey: "tesis" | "platform", rol: string): string[] {
    // Kabuk artik TUM bolumleri acik cizer; bu fonksiyon o kurali
    // veri duzeyinde tekrar eder.
    return menuGruplari(yuzey, rol).flatMap((g) => g.ogeler.map(ogeBaglantisi));
  }

  it("YONETICI: role gorunen HER sayfa acilista listede", () => {
    const gorunen = acilistaGorunen("tesis", "yonetici");
    const tumu = menuGruplari("tesis", "yonetici").flatMap((g) =>
      g.ogeler.map(ogeBaglantisi),
    );
    expect(gorunen.sort()).toEqual(tumu.sort());
    // Eskiden katli olan bolumlerin ogeleri de ICINDE (bu testin asil
    // amaci): kullanicilar, tanimlar, duyurular, finans hareketleri.
    expect(gorunen).toContain("/kisiler");
    // (P251 §7) Tanimlar TEK satir; sekmeler sayfanin icinde.
    expect(gorunen).toContain("/tanimlar");
    expect(gorunen).toContain("/announcements");
    // (P167 Asama 4) SORGU SUZGECLERI GERCEK SAYFA OLDU: `/finans?tip=gelir`
    // yerine `/finans/gelirler`. Sebep brief §4 — her birinin kendi
    // formu ve sutunlari var.
    expect(gorunen).toContain("/finans/gelirler");
    // (P167 §1.4) Icra artik FINANS bolumunun altinda ama listede.
    expect(gorunen).toContain("/icra");
    // (P167 §1.3) Ozet bagimsiz sekme olarak EN USTTE. `gorunen` yukarida
    // `sort()` ile YERINDE siralandigi icin sira ayri bir cagridan
    // okunuyor — yoksa test kendi mutasyonunu olcerdi.
    expect(acilistaGorunen("tesis", "yonetici")[0]).toBe("/dashboard");
  });

  it("DENETCI ve ADMIN icin de tam liste", () => {
    for (const [yuzey, rol] of [
      ["tesis", "denetci"],
      ["platform", "admin"],
    ] as const) {
      const gruplar = menuGruplari(yuzey, rol);
      const beklenen = gruplar.reduce((n, g) => n + g.ogeler.length, 0);
      expect(acilistaGorunen(yuzey, rol).length, `${yuzey}/${rol}`).toBe(beklenen);
    }
  });
});

describe("(P167 §1) MENU MIMARISI", () => {
  const yonetici = () => menuGruplari("tesis", "yonetici");
  const baglantilar = () =>
    yonetici().flatMap((g) => g.ogeler.map(ogeBaglantisi));

  it("§1.3 OZET bagimsiz sekmedir: en ustte, BASLIKSIZ, tek satir", () => {
    const ilk = yonetici()[0];
    expect(ilk.id).toBe("ozet");
    expect(ilk.bagimsiz).toBe(true);
    expect(ilk.ogeler.map((o) => o.href)).toEqual(["/dashboard"]);
    // Baska hicbir bolum basliksiz DEGIL — "bagimsiz" bir kacis kapisi
    // olmamali, yoksa menu yeniden duz bir listeye doner.
    for (const g of yonetici().slice(1)) expect(g.bagimsiz, g.id).toBe(false);
  });

  it("§1.4 ICRA DOSYALARI finansin ALTINDA (bagimsiz sekme DEGIL)", () => {
    expect(rotaninGrubu("/icra")).toBe("finans");
    expect(yonetici().map((g) => g.id)).not.toContain("icra");
  });

  it("§1.4 FINANS HAREKETLERI ayri bolum DEGIL, finansin altinda", () => {
    expect(yonetici().map((g) => g.id)).not.toContain("finansHareket");
    expect(rotaninGrubu("/finans")).toBe("finans");
  });

  it("§1.5 ILETISIM UCLUSU TEK SATIR — ayni rota iki kez listelenmiyor", () => {
    const mesaj = baglantilar().filter((h) => h.startsWith("/mesajlar"));
    expect(mesaj).toEqual(["/mesajlar"]);
  });

  it("(P251 §7) TANIMLAR bolumu: Bloklar + Ice aktarim + TEK 'Tanimlar' satiri", () => {
    // P167 §1.6 sayfanin on iki sekmesini menuye ayri satir olarak
    // koymustu; kullanici bunlari ayri SAYFA saniyordu. Sekme seridi
    // sayfanin icinde — menu yalniz sayfayi gosterir.
    const tanimlar = yonetici().find((g) => g.id === "tanimlar");
    expect((tanimlar?.ogeler ?? []).map(ogeBaglantisi)).toEqual([
      "/building-editor",
      "/ice-aktarim",
      "/tanimlar",
    ]);
    expect(baglantilar().filter((h) => h.startsWith("/tanimlar"))).toEqual(["/tanimlar"]);
  });

  it("(P251 §7) sekmeler ARAMA icin ayri listede, sayfanin sirasiyla", () => {
    expect(TANIM_SEKMELERI.map((o) => o.sorgu)).toEqual([
      "defter=kasalar",
      "defter=gelir-gider-gruplari",
      "defter=gelir-gider-tanimlari",
      "defter=firmalar",
      "defter=gorev-kategorileri",
      // (P251 §8) personel-kayitlari -> Finans › Maas kartlari.
      "defter=arac-kayitlari",
      "defter=sayaclar-ana",
      "defter=sayaclar-bolum",
      "defter=unit-tipleri",
      "defter=unit-gruplari",
      "defter=ayarlar",
    ]);
    for (const o of TANIM_SEKMELERI) expect(o.href).toBe("/tanimlar");
  });

  it("(P251 §7) herhangi bir sekmedeyken menude 'Tanimlar' satiri AKTIF", () => {
    const oge = yonetici().flatMap((g) => g.ogeler).find((o) => o.href === "/tanimlar")!;
    expect(ogeAktif(oge, "/tanimlar", new URLSearchParams("defter=kasalar"))).toBe(true);
    expect(ogeAktif(oge, "/tanimlar", null)).toBe(true);
  });

  it("(P251 §8) KURULUM SIHIRBAZI Yonetim grubunda (alt cubuktan tasindi)", () => {
    // P167 §1.8 onu alt cubuga almisti; P251 menu paritesi (mobilde de
    // Yonetim) "ayni is, ayni grup" ilkesiyle gruba aldi.
    expect(baglantilar()).toContain("/kurulum");
    expect(rotaninGrubu("/kurulum")).toBe("yonetim");
    // Ama hâlâ bir SAYFA: rol kapisi ve gorunurluk sorulabilir olmali.
    expect(kurulumGorunur("tesis", "yonetici")).toBe(true);
    expect(kurulumGorunur("tesis", "denetci")).toBe(false);
  });

  it("§1.7 PROFIL bolum ogesi DEGIL (sag ust menude)", () => {
    expect(baglantilar()).not.toContain("/profil");
    expect(profilGorunur("tesis", "yonetici")).toBe(true);
  });

  it("§1.1 HER BOLUMUN BIR IKONU VAR (ana baslik ikonlu cizilir)", () => {
    for (const g of yonetici()) {
      expect(GRUP_IKONU[g.id], g.id).toBeTruthy();
    }
    expect(GRUP_IKONU.platform).toBeTruthy();
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
