// (P126.7) ROL x ROTA — menudeki her baglanti o rolun GERCEKTEN acabildigi
// bir sayfa mi?
//
// Bu olcum, `ROTA_ROLLERI`ni (urun karari) `backend/tests/yetki/
// rol-matrisi.txt` (KODDAN URETILEN 318 satirlik kilit) ile karsilastirir.
// Iki yonlu bir degismez verir:
//
//   * menude gosterilen her rota, rolun BIRINCIL ucundan 403 ALMADIGI bir
//     rotadir — yoksa kullanici tiklar ve bos ekran gorur;
//   * bir uc bir gun daraltilirsa (orn. `GET /visitors` sakine kapanirsa)
//     bu test DUSER ve menu ona gore guncellenir. Elle tutulan bir liste
//     boyle bir degisikligi sessizce kacirirdi.
//
// NE OLCMEZ: "IZIN" ayni veriyi gormek DEMEK DEGILDIR — `GET /cameras`
// sakine de aciktir ama sunucu ona yalniz `sakin_gorebilir` kameralari
// verir. Bu yuzden erisim GEREK sarttir, YETER sart degil; menude ne
// olacagi ayrica bir urun kararidir (bkz. ROTA_ROLLERI docstring'i).
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import { ROTA_ROLLERI, TESIS_ROTALARI, rotaRoldeGorunur } from "@/lib/yuzey";

const KOK = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const KILIT = resolve(KOK, "backend/tests/yetki/rol-matrisi.txt");

/** Kilit dosyasindaki rol sutunlarinin SIRASI (basliktan okunur). */
function kilidiOku(): { roller: string[]; satir: Map<string, string[]> } {
  const ham = readFileSync(KILIT, "utf8").split("\n");
  const baslik = ham.find((s) => s.startsWith("#"));
  if (!baslik) throw new Error("kilit basligi yok");
  const roller = baslik.replace("#", "").trim().split(/\s+/);
  const satir = new Map<string, string[]>();
  for (const s of ham) {
    if (!s.trim() || s.startsWith("#")) continue;
    const p = s.trim().split(/\s+/);
    satir.set(`${p[0]} ${p[1]}`, p.slice(2));
  }
  return { roller, satir };
}

/**
 * Her tesis rotasinin BIRINCIL ucu — sayfa acilir acilmaz cagirdigi GET.
 *
 * ELLE DEGIL OKUNARAK dolduruldu: her sayfanin kaynagindaki `/api/...`
 * cagrilari cikarildi, BFF vekili uzerinden backend yoluna cevrildi.
 * "Birincil" olan, sayfanin ana listesini getirendir — sayfa acilinca
 * 403 aliniyorsa ekran BOSTUR, yardimci cagrilarin durumu degistirmez.
 */
const BIRINCIL_UC: Record<string, string> = {
  // (P162) Yonetim ekranlari: sakin gorunumleriyle AYNI ucu okurlar ama
  // yazma da yaparlar; rol kapisi sunucudaki `_MANAGER` ile ayni.
  "/site-kurallari": "GET /site-rules",
  "/etkinlik-yonetimi": "GET /events",
  "/dashboard": "GET /dashboard/live",
  "/shifts": "GET /shifts",
  "/checkpoints": "GET /checkpoints",
  "/patrol-plans": "GET /patrol-plans",
  "/tasks": "GET /tasks",
  "/assets": "GET /assets",
  "/units": "GET /units",
  "/building-editor": "GET /blocks",
  "/schematic": "GET /unit-complaints/building-map",
  "/tanimlar": "GET /sayaclar/ana",
  "/sayac-okuma": "GET /sayaclar/ana",
  "/dues": "GET /dues/assessments",
  "/finans": "GET /finans/ozet",
  // (P167 Asama 4) Sekiz finans sayfasi. BIRINCIL UC = sayfanin LISTESINI
  // dolduran uc; "+ Yeni" formunun yazdigi uc degil. Rol kapisi olcumu
  // sayfa ACILDIGINDA ne gorundugune bakar — bos bir ekran ile 403 ayni
  // sey degildir.
  "/finans/borclandirmalar": "GET /dues/assessments",
  "/finans/tahsilatlar": "GET /finans/hareketler",
  "/finans/giderler": "GET /finans/hareketler",
  "/finans/gelirler": "GET /finans/hareketler",
  "/finans/virman": "GET /finans/hareketler",
  "/finans/iade": "GET /finans/hareketler",
  "/finans/acilis": "GET /finans/hareketler",
  // (P192 §4) Otomasyon sayfasinin BIRINCIL ucu plan listesidir; oteki
  // uc kart ayni rol kapisinin arkasinda.
  "/finans/otomasyon": "GET /aidat-planlari",
  // (P191 §4) Banka entegrasyonu — sayfanin listesini `/banka/hareketler`
  // doldurur; ice aktarma ve eslestirme YAZMA ucudur ve sayfa acilirken
  // cagrilmaz.
  "/finans/banka": "GET /banka/hareketler",
  // (P154 / Asama 7.2) `/portal` KALDIRILDI; anket yonetimi kendi
  // sayfasina tasindi ve UCU DEGISMEDI.
  "/anketler": "GET /anketler",
  // (P154 / Asama 7.3) Kurulum sihirbazi — TEK uc sekiz adimin durumunu
  // doner (istemci sekiz ayri liste ucuna gitmez).
  "/kurulum": "GET /kurulum",
  // (P154 / Asama 8) Ice aktarim catisi — eski `/site-aktar` bunun
  // yerine gecti.
  "/ice-aktarim": "GET /ice-aktarim",
  // (P154 / Asama 7.1) Icra ayri ust bolum. Uc denetciye de OKUMA aciyor
  // (`_OKUMA = admin+yonetici+denetci`); yazma yalniz admin, o yuzden
  // sayfa yoneticiye "yeni dosya" dugmesi cizmez.
  "/icra": "GET /finans/icra-dosyalari",
  "/reports/dues": "GET /dues/payments",
  "/reports/patrols": "GET /patrol-plans",
  "/reports/tasks": "GET /tasks",
  "/raporlar": "GET /raporlar/katalog",
  "/transparency": "GET /transparency",
  "/users": "GET /users",
  "/announcements": "GET /announcements",
  "/mesajlar": "GET /mesaj-sablonlari",
  "/complaints": "GET /complaints",
  "/notifications": "GET /notifications",
  "/karar-defteri": "GET /karar-defteri",
  "/dokumanlar": "GET /dokumanlar",
  "/gurultu-uyarilari": "GET /unit-uyarilari",
  "/profil": "GET /me/profile",
  "/aidatim": "GET /me/dues",
  "/taleplerim": "GET /complaints",
  "/duyurular": "GET /announcements",
  "/kurallar": "GET /site-rules",
  "/etkinlikler": "GET /events",
  "/rezervasyonlarim": "GET /reservations",
  // (P181 Bölüm 9) Yönetim rezervasyon/alan sayfası — birincil okuma
  // `GET /reservations` (yönetim=tümü). Rolleri (admin/yönetici) o ucun
  // izinli kümesinin ALT KÜMESİ; yeni backend ucu YOK, kilit değişmez.
  "/rezervasyon-yonetimi": "GET /reservations",
  "/kvkk": "GET /me/pazarlama-tercihleri",
  "/ziyaretciler": "GET /visitors",
  "/kargolar": "GET /kargo",
  // (P155 §7) Davet gonderim durumu — yonetici/admin.
  "/davetler": "GET /davet",
  "/olaylar": "GET /violations",
  "/arac-gecisleri": "GET /vehicle-passes",
  "/gorevlerim": "GET /tasks",
  "/kameralar": "GET /cameras",
  "/dis-hizmetler": "GET /external-services",
  "/yonetim-iletisim": "GET /yonetici-iletisim",
};

const { roller: KILIT_ROLLERI, satir: KILIT_SATIRLARI } = kilidiOku();

/** [uc] icin IZIN alan roller (kilitten). */
function erisenRoller(uc: string): string[] {
  const s = KILIT_SATIRLARI.get(uc);
  if (!s) throw new Error(`kilitte yok: ${uc}`);
  return KILIT_ROLLERI.filter((_, i) => s[i] === "IZIN");
}

describe("kilit okunabiliyor (olcum bosa dusmesin)", () => {
  it("318 satirlik matris ve 6 rol", () => {
    expect(KILIT_ROLLERI).toContain("resident");
    expect(KILIT_SATIRLARI.size).toBeGreaterThan(300);
  });
});

describe("ROTA_ROLLERI eksiksiz", () => {
  it("HER tesis rotasi siniflandirilmis (sessizce gorunmez kalan yok)", () => {
    const eksik = TESIS_ROTALARI.filter((r) => !(r in ROTA_ROLLERI));
    expect(eksik, `siniflandirilmamis: ${eksik.join(", ")}`).toEqual([]);
  });

  it("HER rotanin birincil ucu bildirilmis", () => {
    const eksik = TESIS_ROTALARI.filter((r) => !(r in BIRINCIL_UC));
    expect(eksik, `ucu bildirilmemis: ${eksik.join(", ")}`).toEqual([]);
  });

  it("fazladan/olu giris yok", () => {
    const fazla = Object.keys(ROTA_ROLLERI).filter(
      (r) => !(TESIS_ROTALARI as readonly string[]).includes(r),
    );
    expect(fazla, `TESIS_ROTALARI'nda olmayan: ${fazla.join(", ")}`).toEqual([]);
  });
});

describe("MENUDEKI HER ROTA O ROLUN ACABILDIGI ROTADIR", () => {
  it("bildirilen kume, erisim kumesinin ALT KUMESI", () => {
    const ihlal: string[] = [];
    for (const [rota, roller] of Object.entries(ROTA_ROLLERI)) {
      const izinli = erisenRoller(BIRINCIL_UC[rota]);
      for (const rol of roller) {
        if (!izinli.includes(rol)) {
          ihlal.push(`${rota} -> ${rol} (uc: ${BIRINCIL_UC[rota]}, 403)`);
        }
      }
    }
    expect(ihlal, `menude AMA yetkisiz:\n${ihlal.join("\n")}`).toEqual([]);
  });

  it("`arac-gecisleri` YONETICIYE gosterilmez — uc ona 403 doner", () => {
    // Bu satir bir ORNEK degil KANIT: kural elle degil olcumle kondu.
    expect(erisenRoller("GET /vehicle-passes")).not.toContain("yonetici");
    expect(rotaRoldeGorunur("/arac-gecisleri", "yonetici")).toBe(false);
    // (P129) `security` artik `app.*`ta DEGIL; sayfa yalniz `admin`e
    // acik kaldi (dogrulama icin). Uc kurali degismedi — YUZEY degisti.
    expect(rotaRoldeGorunur("/arac-gecisleri", "security")).toBe(false);
    expect(rotaRoldeGorunur("/arac-gecisleri", "admin")).toBe(true);
  });

  it("(P129) PARK EDILEN sayfalar HICBIR role gorunmez", () => {
    // Sayfalar duruyor ama `app.*` yalniz yonetici + denetci yuzeyi.
    // Bos liste, "sayfa yok" ile karistirilmasin diye SILINMEDI.
    const park = [
      "/aidatim", "/taleplerim", "/kurallar", "/etkinlikler",
      "/rezervasyonlarim", "/ziyaretciler", "/kargolar", "/gorevlerim",
      "/duyurular", "/yonetim-iletisim",
    ];
    for (const rota of park) {
      expect(ROTA_ROLLERI[rota], rota).toEqual([]);
      for (const rol of ["resident", "security", "tesis_gorevlisi", "yonetici", "denetci", "admin"]) {
        expect(rotaRoldeGorunur(rota, rol), `${rota}/${rol}`).toBe(false);
      }
    }
  });

  it("(P129) DENETCI: raporlari gorur, para YAZAN sayfalari GORMEZ", () => {
    for (const r of ["/raporlar", "/transparency", "/profil", "/kvkk"]) {
      expect(rotaRoldeGorunur(r, "denetci"), r).toBe(true);
    }
    // `/finans` ve `/dues` YAZMA formlari tasir; denetciye gosterilmez.
    for (const r of ["/finans", "/dues", "/users", "/tasks", "/kameralar"]) {
      expect(rotaRoldeGorunur(r, "denetci"), r).toBe(false);
    }
  });
});

describe("rol calisma alanlari birbirine karismaz", () => {
  const yonetimSayfalari = ["/finans", "/dues", "/users", "/sayac-okuma", "/anketler"];
  const sakinSayfalari = ["/aidatim", "/taleplerim", "/rezervasyonlarim"];
  const kapiSayfalari = ["/ziyaretciler", "/kargolar", "/arac-gecisleri"];

  it("SAKIN hicbir sayfa GORMEZ (P129: mobil-yalniz)", () => {
    for (const r of [...yonetimSayfalari, ...kapiSayfalari, ...sakinSayfalari]) {
      expect(rotaRoldeGorunur(r, "resident"), r).toBe(false);
    }
  });

  it("YONETICI sakinin kendi kayitlarini menude GORMEZ", () => {
    for (const r of sakinSayfalari) {
      expect(rotaRoldeGorunur(r, "yonetici"), r).toBe(false);
    }
  });

  it("(P129) SAHA ROLLERI `app.*`ta HICBIR sayfa gormez", () => {
    // Mobil-yalniz roller: giriste zaten kesiliyorlar (bkz. login
    // rotalari). Menu tarafinda da bos kalmalari, kapinin delinmesi
    // hâlinde ikinci bir savunmadir.
    for (const rol of ["security", "tesis_gorevlisi", "resident"]) {
      const gorunen = TESIS_ROTALARI.filter((r) => rotaRoldeGorunur(r, rol));
      expect(gorunen, rol).toEqual([]);
    }
  });

  it("YUZEYE GIREN HER ROL en az bir sayfa gorur (bos kabuk YOK)", () => {
    for (const rol of ["yonetici", "admin", "denetci"]) {
      const n = TESIS_ROTALARI.filter((r) => rotaRoldeGorunur(r, rol)).length;
      expect(n, rol).toBeGreaterThan(3);
    }
  });

  it("PROFIL ve KVKK yuzeye giren her rolde var (kisisel veri her zaman erisilebilir)", () => {
    for (const rol of ["yonetici", "admin", "denetci"]) {
      expect(rotaRoldeGorunur("/profil", rol), rol).toBe(true);
      expect(rotaRoldeGorunur("/kvkk", rol), rol).toBe(true);
    }
  });
});

describe("bilinmeyen rol / rota", () => {
  it("ROL YOKSA hicbir sey gorunmez", () => {
    for (const r of TESIS_ROTALARI) {
      expect(rotaRoldeGorunur(r, null), r).toBe(false);
    }
  });

  it("bilinmeyen rol hicbir tesis sayfasi gormez", () => {
    expect(rotaRoldeGorunur("/profil", "guvenlik_amiri")).toBe(false);
  });

  it("PLATFORM rotasinda rol ayrimi YOK — yalniz `admin`", () => {
    expect(rotaRoldeGorunur("/tenants", "admin")).toBe(true);
    expect(rotaRoldeGorunur("/tenants", "yonetici")).toBe(false);
    expect(rotaRoldeGorunur("/audit", "resident")).toBe(false);
  });

  it("(P154) /olaylar YONETICIYE GORUNMEZ — yazma ucu ona kapali", () => {
    // KOK NEDEN, tahmin degil olcum: violations.py'de _READER yoneticiyi
    // iceriyor (liste aciliyor) ama _WRITER icermiyor; sayfanin "Olay
    // bildir" dugmesi POST yapiyor ve yonetici 403 aliyor. Kerem'in
    // karari sayfayi yoneticiden kaldirmak yonunde.
    //
    // BU KILIT NE ICIN: rol listesi bir gun "yonetim de gorsun" diye geri
    // eklenirse, ayni 403 sessizce geri gelir. Test onu yazan kisiye
    // once _WRITER'i acmasi gerektigini hatirlatir.
    expect(rotaRoldeGorunur("/olaylar", "admin")).toBe(true);
    expect(rotaRoldeGorunur("/olaylar", "yonetici")).toBe(false);
    // `security` bu ucu MOBILDEN kullanir; `app.*` yuzeyinde zaten yok.
    expect(rotaRoldeGorunur("/olaylar", "security")).toBe(false);
  });

  it("SINIFLANDIRILMAMIS rota menuye girmez", () => {
    expect(rotaRoldeGorunur("/bilinmeyen", "admin")).toBe(false);
  });

  it("ROL KUMESI OLMAYAN tesis rotasi da menuye SIZMAZ (varsayilan BOS)", () => {
    // Yukaridaki "her rota siniflandirilmis" testi bunun olmamasini
    // sagliyor; bu test EKSIK KALDIGINDA ne olacagini kilitler: varsayilan
    // "gorunur" olsaydi, yeni bir yonetim sayfasi ROTA_ROLLERI'ne
    // eklenmeyi unuttugunda SESSIZCE herkese acilirdi.
    const yedek = ROTA_ROLLERI["/finans"];
    delete ROTA_ROLLERI["/finans"];
    try {
      for (const rol of ["admin", "yonetici", "resident"]) {
        expect(rotaRoldeGorunur("/finans", rol), rol).toBe(false);
      }
    } finally {
      ROTA_ROLLERI["/finans"] = yedek;
    }
  });
});
