// (P125) YUZEY AYRIMI — hangi rota PLATFORM'a, hangisi TESIS'e ait?
//
// Kerem'in urun karari: `panel.yönetiyor.com` YALNIZ platform sahibinin
// yuzeyidir (tesis yonetimi, platform ayarlari, tesisler-arasi gorunumler,
// islem gecmisi). Tek bir sitenin islemleri — aidat tahsilati, sayac
// okuma, vardiya — oraya GIRMEZ; onlar `app.yönetiyor.com`a (P126) gider.
//
// NEDEN AYRI BIR MODUL: siniflandirma iki yerde birden gerekiyor — menuyu
// suzmek ve TESTLE kanitlamak. Iki kopya tutulsaydi biri guncellenir,
// oteki sessizce eskir ve "panel platform-only" iddiasi dogrulanamaz hale
// gelirdi. Tek kaynak burasi; `AppShell` de testler de bunu okur.
//
// SINIFLANDIRMANIN GEREKCESI belgede: `docs/platform-tesis-ayrimi.md`.
// Orada 317 uçluk rol matrisinden okunarak yapildi, tahminle degil.

/** Bir rotanin/konagin ait oldugu yuzey.
 *
 * (P127) UCUNCU YUZEY: `tanitim`. Kok alan adi (ve www)
 * artik bir TANITIM SITESIDIR — ziyaretcinin ilk gordugu sey kendisine
 * ait olmayan bir giris formu olmamali. Rotalari PUBLIC'tir (oturum
 * kapisi yok) ve `PLATFORM_ROTALARI`/`TESIS_ROTALARI` ile karismaz. */
export type Yuzey = "platform" | "tesis" | "tanitim";

/**
 * PLATFORM rotalari — `panel.*`ta kalir.
 *
 * Hepsi TESISLER-ARASI ya da platformun kendi isidir. `users` burada
 * DEGILDIR: o bir tesisin personel/sakin listesidir. Platformun kullanici
 * isi `tenants/[id]` icindeki "yonetici ata / kimlik sifirla" akisidir ve
 * o zaten `/tenants` altindadir.
 */
export const PLATFORM_ROTALARI = [
  "/tenants",
  "/audit",
  "/support",
  "/integrations",
  "/yetki",
  "/settings",
] as const;

/**
 * TESIS rotalari — P126'da `app.*`a tasinir.
 *
 * Bugun kod tabaninda duruyorlar ve `admin` bir yer imiyle hâlâ acabilir
 * (yetki GERI ALINMADI — bkz. belgedeki duzeltilmis karar). Degisen sey
 * PANEL MENUSUNDE GORUNMEMELERI: panelin isi platformu yonetmek.
 */
export const TESIS_ROTALARI = [
  "/dashboard",
  "/shifts",
  "/checkpoints",
  "/patrol-plans",
  "/tasks",
  "/assets",
  "/units",
  "/building-editor",
  "/schematic",
  "/tanimlar",
  "/sayac-okuma",
  "/dues",
  "/finans",
  "/reports/dues",
  "/reports/patrols",
  "/reports/tasks",
  "/raporlar",
  "/transparency",
  "/users",
  "/announcements",
  "/mesajlar",
  "/portal",
  "/complaints",
  "/notifications",
  "/yonetisim",
  // (P126.3) Tesis rollerinin KENDI kayitlari (sakin calisma alani).
  "/profil",
  "/aidatim",
  "/taleplerim",
  "/duyurular",
  "/kurallar",
  "/etkinlikler",
  "/rezervasyonlarim",
  "/kvkk",
  // (P126.4) Guvenligin kapi ekranlari.
  "/ziyaretciler",
  "/kargolar",
  "/olaylar",
  "/arac-gecisleri",
  // (P126.6) Saha rolunun kendi gorevleri.
  "/gorevlerim",
  // (P126.5) Yoneticinin eksik ekranlari.
  "/kameralar",
  "/dis-hizmetler",
  "/yonetim-iletisim",
] as const;

/**
 * Bir rotanin yuzeyi. Bilinmeyen rota `null` doner — "varsayilan olarak
 * platform" demek, yeni bir tesis sayfasinin panele SESSIZCE sizmasi
 * olurdu. Test bilinmeyen rota birakmayi reddediyor.
 */
export function rotaYuzeyi(href: string): Yuzey | null {
  if ((PLATFORM_ROTALARI as readonly string[]).includes(href)) return "platform";
  if ((TESIS_ROTALARI as readonly string[]).includes(href)) return "tesis";
  return null;
}

/**
 * Konaktan yuzey. `app.` -> TESIS, `panel.` -> PLATFORM, KOK ve `www.`
 * -> TANITIM.
 *
 * NEDEN KONAKTAN: ayni Next.js uygulamasi uc alan adindan sunuluyor
 * (bkz. infra/Caddyfile). Rolden turetmek yanlis olurdu — `admin` iki
 * calisma yuzeyine de girebilir ve hangisinde oldugunu ancak adres soyler;
 * tanitim yuzeyinde ise ziyaretcinin ROLU YOKTUR.
 *
 * (P127) VARSAYILAN DEGISTI: eskiden `app.` disindaki HER konak "platform"
 * sayiliyordu. Artik yalniz `panel.` (ve yerel gelistirme adresleri)
 * platformdur; kok/www TANITIM'dir. Varsayilani platform birakmak,
 * markanin ana adresinde bir YONETICI GIRIS EKRANI acmak demekti — P120'de
 * gecici statik sayfa tam bu yuzden konmustu.
 *
 * YEREL GELISTIRME (`localhost`, `127.0.0.1`, konaksiz istek) PLATFORM
 * kalir: gelistirici `npm run dev` deyip panele bakar; onu tanitim
 * sayfasina dusurmek her gun bir tiklama fazlasi olurdu.
 */
const _YEREL_KONAKLAR = ["localhost", "127.0.0.1", "0.0.0.0", "::1", ""];

export function konakYuzeyi(host: string | null | undefined): Yuzey {
  const h = (host ?? "").toLowerCase().split(":")[0];
  if (h.startsWith("app.")) return "tesis";
  if (h.startsWith("panel.")) return "platform";
  if (_YEREL_KONAKLAR.includes(h)) return "platform";
  // Kok ve www — tanitim. (`www.` oneki ATILIR: ayni sitedir.)
  return "tanitim";
}

/**
 * Yuzeyin KOK rotasi (logo hedefi).
 *
 * Modulde durur, cizim katmaninda bir ucluda DEGIL: `sabit-metin` taramasi
 * ucludaki satir-ici dizgeleri hakli olarak "cevrilmemis metin" adayi
 * sayiyor. Ayrica hedef, yuzey tanimiyla AYNI yerde durmali — panelde
 * tesis panosu yoktur, o bilgi buraya aittir.
 */
export function kokRota(yuzey: Yuzey): string {
  if (yuzey === "platform") return "/tenants";
  if (yuzey === "tanitim") return "/";
  return "/dashboard";
}

/**
 * Yuzeyin kok rotasi, ROLE GORE (P126.7).
 *
 * `kokRota` tesis yuzeyinde `/dashboard` verir — ama panoyu YALNIZ yonetim
 * gorur. Sakini oraya yollamak, giris yapar yapmaz goremeyecegi bir sayfaya
 * atmak demekti (ve middleware onu tekrar yonlendirirdi: dongu).
 *
 * SIRA ONEMLI ve ROLLERIN ISINE GORE kuruldu: guvenligin gunu KAPIDA
 * gecer (ziyaretci/kargo), gorev ikincil isidir — bu yuzden `/ziyaretciler`
 * `/gorevlerim`den ONCE gelir. Saha gorevlisi ziyaretci ekranini goremedigi
 * icin dogal olarak `/gorevlerim`e duser. Hicbirini goremeyen rol icin
 * `/profil` her tesis rolunde vardir.
 */
const KOK_ADAYLARI = [
  "/dashboard",
  // (P129) Denetcinin gunu raporlarda gecer; panoyu goremez.
  "/raporlar",
  // Park edilen roller (P129) buraya artik DUSMEZ — satirlar duruyor ki
  // rol geri acilirsa kok rotasi da kendiliginden dogru olsun.
  "/ziyaretciler",
  "/gorevlerim",
  "/aidatim",
  "/profil",
];

export function kokRotaRol(yuzey: Yuzey, rol: string | null): string {
  if (yuzey === "platform") return kokRota("platform");
  return KOK_ADAYLARI.find((r) => rotaRoldeGorunur(r, rol)) ?? kokRota("tesis");
}

// --------------------------------------------------------------------------- #
// ROL x YUZEY KAPISI (P126.1)
//
// `panel.*` platform sahibinindir; `app.*` tesis rollerinindir. Bu kapi bir
// UX kapisidir, GUVENLIK SINIRI DEGIL: gercek yetki her istekte backend
// RBAC'ta zorlanir (contracts/auth.md §4, 317 ucluk rol matrisi). Ama yanlis
// yuzeye giren kullaniciya isini yapamayacagi bir kabuk gostermek, "sistem
// bozuk" izlenimi uretir — kapi bunu onler.

/** Platform yuzeyine girebilen roller. */
const PLATFORM_ROLLERI = new Set(["admin"]);

/**
 * Tesis yuzeyine (`app.*`) girebilen roller.
 *
 * (P129) KAPSAM DARALDI — bu bir GERI ALMA degil, URUN KARARI. P126.3-.6
 * boyunca dort tesis rolu de `app.*`a alinmisti ve calisiyordu; Kerem'in
 * karari `app.*`i **site yoneticisi + denetci** yuzeyi yapmak yonunde.
 *
 * NEDEN: sakin ve saha personeli isini TELEFONDA yapar — kapida duran bir
 * guvenlik gorevlisinin ya da dairesinden aidatina bakan bir sakinin
 * masabasi tarayicisi yoktur. Iki yuzeyi de "tam" tutmak, her ozelligi
 * IKI KEZ yazmak ve ikisinin zamanla ayrismasi demekti.
 *
 * `denetci` (P128) BURADA: denetcinin isi tam tersine masabasi isidir —
 * rapor okur, tablo indirir, kalem kalem karsilastirir. Onun icin dogru
 * yuzey web'dir; mobil bir denetci ekrani hic tasarlanmadi.
 *
 * SAYFALAR SILINMEDI, PARK EDILDI: sakin/guvenlik/saha sayfalari kod
 * tabaninda DURUYOR (bkz. ROTA_ROLLERI'ndeki park notu). Geri acmak, rol
 * adini iki listeye yazmaktir.
 */
const TESIS_ROLLERI = new Set([
  "yonetici",
  "admin",
  // (P128/P129) Salt-okuma mali denetim — masabasi rolu.
  "denetci",
]);

/**
 * (P129) MOBIL-YALNIZ roller: `app.*`ta oturum ACILMAZ, mobil uygulamaya
 * yonlendirilir.
 *
 * "Yakinda" DEMEK YANLIS OLURDU — bu roller icin web calisma alani
 * gelecekte de planlanmiyor; onlarin urunu mobil uygulamadir. Yanlis
 * cumle, kullaniciyi haftalarca bekleyecegi bir seye baglar.
 */
const MOBIL_ROLLERI = new Set(["resident", "security", "tesis_gorevlisi"]);

/**
 * ROL x ROTA — `app.*`ta HANGI ROLE HANGI SAYFA GOSTERILIR.
 *
 * NEDEN GEREKLI: P126.1-.6 boyunca menu YALNIZ YUZEYE gore suzuluyordu.
 * Sonuc: `app.*`a giren bir SAKIN, vardiya cizelgesinden tahakkuk
 * olusturmaya kadar 39 baglantiyi goruyordu. Hicbirini acamiyordu — sunucu
 * 403 donuyor — ama "goruyorum, tiklayinca calismiyor" tam olarak
 * `yuzey.ts`in bastan beri onlemeye calistigi "sistem bozuk" izlenimidir.
 *
 * BU BIR YETKILENDIRME DEGILDIR (gorunurluk yetkilendirme olmaz): gercek
 * kapi sunucudadir ve olculmustur — `backend/tests/yetki/rol-matrisi.txt`,
 * koddan uretilen 318 satirlik kilit.
 *
 * KUME NASIL SECILDI — IKI KATMAN:
 *   1. ERISIM (olculur): rol o sayfanin BIRINCIL ucundan 403 aliyorsa
 *      sayfa menude OLAMAZ. `tests/rol-menusu.test.ts` her satiri matris
 *      kilidiyle karsilastirir; bir gun bir uc daraltilirsa test duser.
 *   2. NIYET (urun karari): erisim yeterli sart DEGIL. `GET /cameras` her
 *      role acik ama Kameralar sayfasi bir YONETIM ekranidir; sakine
 *      kamera gorunumu ayri bir urun kararidir ve bu turda ALINMADI.
 *
 * Yani asagidaki kume her zaman erisim kumesinin ALT KUMESIDIR.
 */
export const ROTA_ROLLERI: Record<string, readonly string[]> = {
  // --- YONETIM EKRANLARI: yonetici + admin -------------------------------
  "/dashboard": ["admin", "yonetici"],
  "/shifts": ["admin", "yonetici"],
  "/checkpoints": ["admin", "yonetici"],
  "/patrol-plans": ["admin", "yonetici"],
  "/tasks": ["admin", "yonetici"],
  "/assets": ["admin", "yonetici"],
  "/units": ["admin", "yonetici"],
  "/building-editor": ["admin", "yonetici"],
  "/schematic": ["admin", "yonetici"],
  "/tanimlar": ["admin", "yonetici"],
  "/sayac-okuma": ["admin", "yonetici"],
  "/dues": ["admin", "yonetici"],
  "/finans": ["admin", "yonetici"],
  "/reports/dues": ["admin", "yonetici"],
  "/reports/patrols": ["admin", "yonetici"],
  "/reports/tasks": ["admin", "yonetici"],
  // (P129) DENETCININ KUMESI DAR ve bu bilincli: `/finans` ve `/dues`
  // ona ACILMADI cunku o sayfalar tahsilat/tahakkuk FORMLARI tasir;
  // sunucu denetciyi 403 ile keser ama basilacak bir dugme gostermek
  // "yetkim var sandim" demektir. Ayni veriye denetci `/raporlar`dan
  // (gelir-gider, tahakkuk-tahsilat, kasa mutabakati) yazmasiz ULASIR.
  "/raporlar": ["admin", "yonetici", "denetci"],
  // (P129) Seffaflik panosu zaten anonim ozet; denetci OKUR.
  "/transparency": ["admin", "yonetici", "denetci"],
  "/users": ["admin", "yonetici"],
  "/announcements": ["admin", "yonetici"],
  "/mesajlar": ["admin", "yonetici"],
  "/portal": ["admin", "yonetici"],
  "/complaints": ["admin", "yonetici"],
  "/notifications": ["admin", "yonetici"],
  "/yonetisim": ["admin", "yonetici"],
  "/kameralar": ["admin", "yonetici"],
  // Olaylar: guvenlik BILDIRIR (mobilde), yonetim OKUR (burada).
  // (P129) `security` cikarildi — `app.*`ta oturumu yok; kaydi mobilden
  // olusturur.
  //
  // (P154) `yonetici` DE CIKARILDI — Kerem'in karari. KOK NEDEN OLCULDU,
  // tahmin edilmedi:
  //   * `violations.py:43` _READER = admin, yonetici, security -> yonetici
  //     listeyi OKUYABILIYOR ve sayfa aciliyordu,
  //   * `violations.py:42` _WRITER = admin, security -> yonetici YAZAMIYOR,
  //   * `olaylar/page.tsx` "Olay bildir" dugmesi POST /api/violations yapiyor.
  // Yani yonetici sayfayi aciyor, listeyi goruyor, dugmeye basiyor ve 403
  // aliyor. Bildirilen "yetki hatasi" tam olarak budur.
  //
  // ALTERNATIF (uygulanmadi, karar Kerem'in): yalniz YAZMA formunu
  // yoneticiden gizleyip salt-okuma listesini birakmak. Kusur okumada
  // degil yazmadaydi; sayfayi tumden kaldirmak calisan bir okuma
  // yetenegini de goturur. Brief acikca "yoneticiden kaldir" dedigi icin
  // yazili istek uygulandi ve takas burada kayda gecti.
  //
  // `security` bu ucu GERCEKTEN kullaniyor (mobil olay bildirimi), bu
  // yuzden uc kaldirilmadi — yalniz web rota gorunurlugu daraldi.
  "/olaylar": ["admin"],

  // --- PARK EDILDI (P129) — SAKIN / GUVENLIK / SAHA ----------------------
  // Sayfalar SILINMEDI: dosyalari duruyor, testleri kosuyor. `app.*`
  // yalniz yonetici + denetci yuzeyi oldugu icin rol listeleri BOSALDI.
  // Geri acmak = ilgili satira rol adini yazmak + TESIS_ROLLERI'ne eklemek.
  // Bos listeyi SILMEK yerine burada tutmak bilincli: "bu sayfa var ama
  // hicbir role acik degil" ile "boyle bir sayfa yok" ayri seylerdir ve
  // ikincisi, siniflandirilmamis rota olarak middleware kapisindan da
  // muaf tutulurdu (P126.2).
  "/aidatim": [],
  "/taleplerim": [],
  "/kurallar": [],
  "/etkinlikler": [],
  "/rezervasyonlarim": [],
  "/ziyaretciler": [],
  "/kargolar": [],
  "/gorevlerim": [],
  "/duyurular": [],
  "/yonetim-iletisim": [],
  // `yonetici` BU SAYFAYI GOREMEZ ve bu bir tercih degil OLCUM:
  // `GET /vehicle-passes` yoneticiye 403 doner (matris kilidi). Geriye
  // yalniz `admin` kaldi (dogrulama icin bakabilmeli).
  "/arac-gecisleri": ["admin"],

  // --- HERKESIN / PAYLASILAN --------------------------------------------
  "/profil": ["admin", "yonetici", "denetci"],
  "/kvkk": ["admin", "yonetici", "denetci"],
  // Guvenilir esnaf: sunucu "herkes gorur/arayabilir" diyor (routers/
  // external_services.py). Yonetici icin ayni sayfa YAZMA formunu da acar.
  "/dis-hizmetler": ["admin", "yonetici"],
};

/**
 * [href] rotasi [rol] icin menude gorunur mu?
 *
 * PLATFORM rotalarinda rol ayrimi YOKTUR: o yuzeye zaten yalniz `admin`
 * girebiliyor (bkz. PLATFORM_ROLLERI) ve hepsi onun isidir.
 *
 * ROL BILINMIYORSA (`null`) HICBIR SEY gorunmez. "Bilmiyorsak gosterelim"
 * demek, sakine yonetim menusunu bir an icin de olsa cizmek olurdu.
 */
export function rotaRoldeGorunur(href: string, rol: string | null): boolean {
  const yuzey = rotaYuzeyi(href);
  if (yuzey === null) return false;
  if (yuzey === "platform") return rolYuzeyeGirebilir(rol, "platform");
  if (!rol) return false;
  return (ROTA_ROLLERI[href] ?? []).includes(rol);
}

/** [rol] bu [yuzey]e girebilir mi? */
export function rolYuzeyeGirebilir(rol: string | null, yuzey: Yuzey): boolean {
  if (!rol) return false;
  return yuzey === "platform"
    ? PLATFORM_ROLLERI.has(rol)
    : TESIS_ROLLERI.has(rol);
}

/** Henuz `app.*`a alinmamis tesis rolleri (giriste "yakinda" mesaji icin).
 *
 * (P129) Bugun YALNIZ `guvenlik_amiri`: rol backend'de var (P35) ama ne web
 * ne mobil ekran seti tanimlandi. Onu mobile yollamak da yanlis olurdu —
 * orada da kendi ekranlari yok. */
export function tesisYuzeyiBekleyenRol(rol: string | null): boolean {
  return (
    !!rol && ["guvenlik_amiri"].includes(rol)
  );
}

/** (P129) Bu rol MOBIL-YALNIZ mi? Giriste magaza mesaji icin. */
export function mobilYalnizRol(rol: string | null): boolean {
  return !!rol && MOBIL_ROLLERI.has(rol);
}

/** Giris reddinde gosterilecek mesajin SOZLUK ANAHTARI + hata KODU.
 *
 * NEDEN BURADA: kural IKI giris rotasinda (e-posta + telefon) AYNI olmali
 * ve ilk yazimda ikisine de KOPYALANMISTI. Mutasyon denetimi bunu yakaladi:
 * telefon rotasindaki dali bozdugumda hicbir test dusmedi, cunku testler
 * kaynakta metin ariyordu — kopyalanan kural, tek tarafi bozulunca sessiz
 * kalan bir kuraldir. Artik tek fonksiyon, iki cagri yeri.
 *
 * KOD ile ANAHTAR ayri: kod MAKINE icindir (istemci magaza baglantisini
 * ona gore cizer), anahtar INSAN icindir (7 dil).
 */
export function girisRedKarari(
  rol: string | null,
  yuzey: Yuzey,
): { anahtar: "girisMobilUygulama" | "girisRolYakinda" | "girisPanelPlatformIcin"; kod: string } {
  if (yuzey !== "tesis") return { anahtar: "girisPanelPlatformIcin", kod: "forbidden" };
  if (mobilYalnizRol(rol)) return { anahtar: "girisMobilUygulama", kod: "mobil_uygulama" };
  if (tesisYuzeyiBekleyenRol(rol)) return { anahtar: "girisRolYakinda", kod: "forbidden" };
  return { anahtar: "girisPanelPlatformIcin", kod: "forbidden" };
}
