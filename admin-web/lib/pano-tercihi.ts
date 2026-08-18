// (P167 Asama 2) OZET SAYFASININ KULLANICI BASINA DUZENI — tek kaynak.
//
// Brief iki ayri ozellestirme istiyor ve ikisi de AYNI kayitta durur:
//   §2.1 widget seridi — hangi alti kisayol, hangi sirada
//   §2.5 bolum duzeni  — hangi bolum gorunur, hangi sirada
//
// TEK KAYIT, IKI AYRI DEGIL: ikisi de "bu kullanicinin Ozet sayfasi nasil
// gorunuyor" sorusunun cevabi. Ayri tutmak, panel duzenleme modunda iki
// ayri kaydetme yolu ve yarim kaydedilmis bir duzen ihtimali demekti.
//
// SUNUCUDA SAKLANIR (`app_user.pano_tercihi`), `localStorage`ta DEGIL:
// tarayici deposu KULLANICI basina degil TARAYICI basina calisir. Ofisteki
// bilgisayardan duzenlenen pano, evdeki dizustunde varsayilana donerdi —
// brief'in "kullanici basina kalici" sartinin tam tersi.
//
// (Kabuk menusunun acik/kapali durumu BILEREK `localStorage`ta kaliyor: o
// bir GEZINME aliskanligidir ve cihaz basina farkli olmasi dogaldir.)
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

/** Ozet sayfasindaki bolumler. Sira BURADAKI VARSAYILAN siradir. */
export type PanoBolumId =
  | "widgetlar"
  | "finans"
  | "maket"
  | "takvim"
  // (P167 §2.5) BRIEF'IN LISTESINDE OLMAYAN IKI BOLUM — BILEREK EKLENDI.
  //
  // §2.5 bolumleri "widget seridi, finansal kartlar, takvim, 3D,
  // alarmlar" diye sayiyor. Ama sayfada BUNLARDAN BASKA seyler de vardi:
  // suren/siradaki devriyeyi gosteren kahraman blok, dort KPI halkasi ve
  // kamera seridi. Brief'in listesini harfi harfine uygulamak onlari
  // SILMEK olurdu — ve GENEL KISITLAR'in ilk maddesi "Mevcut islev
  // kaybolmayacak" diyor.
  //
  // Cozum ikisini de tutuyor: islev KALDI, ama artik oteki bolumlerle
  // AYNI kurala tabi — gizlenebilir ve siralanabilir. Yani "sayfa
  // ozellestirilebilir olacak" sarti onlari da kapsiyor.
  | "devriye"
  | "kpi"
  | "kameralar"
  | "alarmlar";

export interface PanoBolumTanimi {
  id: PanoBolumId;
  anahtar: SozlukAnahtari;
  /**
   * Bolum satirin TAMAMINI mi kaplar yoksa YARISINI mi?
   *
   * Yan yana gelen iki `yarim` bolum tek satiri paylasir. Bu alan
   * sayesinde duzen TEK BOYUTLU bir liste olarak kalabiliyor —
   * surukle-birak iki eksende olsaydi hem kod hem klavye erisimi
   * kat kat karmasiklasirdi.
   *
   * (§2.4) Brief "3D site maketi SAG UST tarafa alinacak" diyor; varsayilan
   * sirada `finans` ve `maket` yan yana iki yarim bolum, yani maket
   * widget seridinin hemen altinda sag sutunda duruyor.
   */
  genislik: "tam" | "yarim";
  /**
   * Bolum KENDI basligini mi ciziyor?
   *
   * `KameraSeridi` basligini kendi cizer VE kamera yoksa HICBIR SEY
   * cizmez (P132.4b'nin kurali: "kamera yoksa bolum hic cizilmez").
   * Cerceve ona bir baslik eklerse, bos bir "Kameralar" basligi kalirdi
   * — yani kaldirilmis bir kural sessizce geri gelirdi.
   *
   * DUZENLEME MODUNDA kontrol satiri YINE cizilir: kullanici bos bir
   * bolumu de siralayip gizleyebilmeli.
   */
  kendiBasligi?: true;
}

export const PANO_BOLUMLERI: readonly PanoBolumTanimi[] = [
  { id: "widgetlar", anahtar: "panoBolumWidgetlar", genislik: "tam", kendiBasligi: true },
  { id: "finans", anahtar: "panoBolumFinans", genislik: "yarim" },
  { id: "maket", anahtar: "panoBolumMaket", genislik: "yarim" },
  // TAKVIM TAM GENISLIK: brief "buyuk" ve "sayfada belirgin yer alacak"
  // diyor. Yarim satirda gun/hafta gorunumu okunmaz olurdu.
  { id: "takvim", anahtar: "panoBolumTakvim", genislik: "tam" },
  // Devriye ve alarmlar YAN YANA: ikisi de "su an sahada ne oluyor"
  // sorusunun parcasi ve ayni bakista okunmalari dogal.
  { id: "devriye", anahtar: "panoBolumDevriye", genislik: "yarim" },
  { id: "alarmlar", anahtar: "panoBolumAlarmlar", genislik: "yarim" },
  { id: "kpi", anahtar: "panoBolumKpi", genislik: "tam" },
  { id: "kameralar", anahtar: "panoBolumKameralar", genislik: "tam", kendiBasligi: true },
];

const BOLUM_IDLERI = new Set<string>(PANO_BOLUMLERI.map((b) => b.id));

/** Sunucudaki kaydin sekli (`PanoTercihi` semasi). */
export interface PanoTercihi {
  widgetlar?: { rota: string }[];
  bolumler?: { id: string; gizli?: boolean }[];
}

/** Cizim icin cozulmus bolum satiri. */
export interface CozulmusBolum extends PanoBolumTanimi {
  gizli: boolean;
}

/** Widget seridinde en fazla kac kisayol (brief: alti). */
// (P168 §1.2) ALTI DEGIL YEDI. Serit tam genislikte ve YEDI ESIT alan
// tasiyor; sinir tek bir yerde durur ki serit, secim modali ve kayit
// govdesi ayrisamasin.
export const WIDGET_SINIRI = 7;

/**
 * Kayitli tercihi VARSAYILANLA birlestir.
 *
 * UC KURAL, ucu de bir gerileme senaryosundan:
 *
 *  1. KAYITTA OLMAYAN BOLUM SONA EKLENIR. Yeni bir bolum eklendiginde,
 *     eski kaydi olan kullanicilar onu HIC gormezdi — kayit tam liste
 *     sanilirdi.
 *  2. TANINMAYAN KIMLIK ATILIR. Kaldirilan bir bolum eski kayitlarda
 *     durur; cizmeye calismak `undefined` bir bilesen demekti.
 *  3. KAYIT BOSSA VARSAYILAN. "Tercih yok" ile "hepsini gizledim" ayri
 *     seyler; ikincisi kayitta GIZLI bayraklariyla temsil edilir.
 */
export function bolumleriCoz(tercih: PanoTercihi | undefined): CozulmusBolum[] {
  const kayit = tercih?.bolumler ?? [];
  const gizliler = new Map(kayit.map((b) => [b.id, b.gizli ?? false]));
  const sirali = kayit
    .map((b) => PANO_BOLUMLERI.find((t) => t.id === b.id))
    .filter((t): t is PanoBolumTanimi => Boolean(t));
  const eksikler = PANO_BOLUMLERI.filter(
    (t) => !sirali.some((s) => s.id === t.id),
  );
  return [...sirali, ...eksikler].map((t) => ({
    ...t,
    gizli: gizliler.get(t.id) ?? false,
  }));
}

/**
 * Widget kumesini coz — GECERSIZ ROTALAR ELENIR.
 *
 * `izinliRotalar` cagirandan gelir ve `menuGruplari(yuzey, rol)`ten
 * turetilir. Boylece "erisemeyecegi bir sekmeyi widget yapamaz" kurali
 * (brief §2.1) MENUYLE AYNI kaynaktan gelir — ikinci bir yetki listesi
 * yazsaydik, biri degistiginde oteki sessizce eskirdi.
 *
 * ROLU DEGISEN ya da SAYFASI KALKAN bir widget de burada duser: kayit
 * temizlenmeden onceki halinde kalir, cizim ise gecerli olani gosterir.
 */
export function widgetlariCoz(
  tercih: PanoTercihi | undefined,
  izinliRotalar: readonly string[],
  varsayilan: readonly string[],
): string[] {
  const izinli = new Set(izinliRotalar);
  const kayitli = (tercih?.widgetlar ?? [])
    .map((w) => w.rota)
    .filter((r) => izinli.has(r));
  // KAYIT VARSA AYNEN KULLANILIR — eksik kalani varsayilanla TAMAMLAMAYIZ.
  // Tamamlasaydik, alti kisayoldan besini silen kullanici her acilista
  // silmediklerinin yanina yenilerinin geldigini gorurdu.
  if (tercih?.widgetlar?.length) return kayitli.slice(0, WIDGET_SINIRI);
  return varsayilan.filter((r) => izinli.has(r)).slice(0, WIDGET_SINIRI);
}

/** Sunucuya yazilacak govde. */
export function tercihGovdesi(
  widgetlar: readonly string[],
  bolumler: readonly CozulmusBolum[],
): PanoTercihi {
  return {
    widgetlar: widgetlar.slice(0, WIDGET_SINIRI).map((rota) => ({ rota })),
    bolumler: bolumler.map((b) => ({ id: b.id, gizli: b.gizli })),
  };
}

/** Bilinen bir bolum kimligi mi? (Testler ve tur daraltma icin.) */
export function bolumTanimli(id: string): id is PanoBolumId {
  return BOLUM_IDLERI.has(id);
}
