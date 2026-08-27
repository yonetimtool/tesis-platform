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

/** (P181 7.1/7.2) Kayitli yerlesim satiri. */
export interface PanoSatirKaydi {
  sutun: number;
  idler: string[];
  baslik?: string | null;
}

/** Sunucudaki kaydin sekli (`PanoTercihi` semasi). */
export interface PanoTercihi {
  widgetlar?: { rota: string }[];
  bolumler?: { id: string; gizli?: boolean }[];
  // (P181 7.1/7.2) Satir bazli yerlesim; yoksa tam/yarim eslesme.
  satirlar?: PanoSatirKaydi[];
}

/** Cizim icin cozulmus bolum satiri. */
export interface CozulmusBolum extends PanoBolumTanimi {
  gizli: boolean;
}

/** (P181 7.1/7.2) Cizim icin cozulmus YERLESIM SATIRI: 1-4 sutun + banner. */
export interface CozulmusSatir {
  sutun: number;
  baslik?: string | null;
  bolumler: CozulmusBolum[];
}

/** Widget seridinde en fazla kac kisayol. Sinir TEK YERDE durur ki serit,
 *  secim modali ve kayit govdesi ayrisamasin. */
// (P182 §2) YEDI DEGIL ALTI. Sunucu semasi (`PanoTercihi.widgetlar
// max_length=6`) hep 6'ydi; istemci 7'ye izin verip metinde "7" yaziyordu,
// 7. widget eklenince sunucu 422 veriyor ve tutarsizlik "kaydedilmiyor" gibi
// gorunuyordu. Karar: HER YERDE 6 (metin bu sabitten uretilir).
export const WIDGET_SINIRI = 6;

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

const SUTUN_ENAZ = 1;
const SUTUN_ENCOK = 4;

function sutunKis(n: number): number {
  return Math.min(SUTUN_ENCOK, Math.max(SUTUN_ENAZ, Math.round(n) || 1));
}

/**
 * (P181 7.1) VARSAYILAN SATIRLAR — mevcut tam/yarim eslesmeyi satira cevirir.
 *
 * Ardisik iki `yarim` bolum 2 sutunlu bir satir; `tam` bolum 1 sutunlu. Boylece
 * hic tercihi olmayan kullanici bugunku duzenle acilir (derli toplu varsayilan).
 */
export function varsayilanSatirlar(bolumler: readonly CozulmusBolum[]): CozulmusSatir[] {
  const satirlar: CozulmusSatir[] = [];
  for (let i = 0; i < bolumler.length; i++) {
    const b = bolumler[i];
    const sonraki = bolumler[i + 1];
    if (b.genislik === "yarim" && sonraki?.genislik === "yarim") {
      satirlar.push({ sutun: 2, bolumler: [b, sonraki] });
      i++;
    } else {
      satirlar.push({ sutun: 1, bolumler: [b] });
    }
  }
  return satirlar;
}

/**
 * (P181 7.1/7.2) Kayitli `satirlar`i cizilebilir satirlara cozer.
 *
 * KAYIT VARSA ondan kurulur: her kimlik cozulmus bolume eslenir, TANINMAYAN ve
 * TEKRAR eden kimlik atilir; kayitta OLMAYAN bolum(ler) sona 1-sutunlu yeni
 * satir olarak eklenir (yeni bir bolum eklendiginde kaybolmasin diye —
 * `bolumleriCoz`teki ayni gerekce). Kayit yoksa VARSAYILAN.
 */
export function satirlariCoz(
  tercih: PanoTercihi | undefined,
  cozulmus: readonly CozulmusBolum[],
): CozulmusSatir[] {
  const kayit = tercih?.satirlar;
  if (!kayit?.length) return varsayilanSatirlar(cozulmus);
  const harita = new Map<string, CozulmusBolum>(cozulmus.map((b) => [b.id, b]));
  const kullanildi = new Set<string>();
  const satirlar: CozulmusSatir[] = [];
  for (const s of kayit) {
    const bolumler = (s.idler ?? [])
      .map((id) => harita.get(id))
      .filter((b): b is CozulmusBolum => b !== undefined && !kullanildi.has(b.id));
    bolumler.forEach((b) => kullanildi.add(b.id));
    if (bolumler.length) {
      satirlar.push({ sutun: sutunKis(s.sutun), baslik: s.baslik ?? null, bolumler });
    }
  }
  for (const b of cozulmus.filter((x) => !kullanildi.has(x.id))) {
    satirlar.push({ sutun: 1, bolumler: [b] });
  }
  return satirlar.length ? satirlar : varsayilanSatirlar(cozulmus);
}

/** Cizilecek satirlari kayit sekline cevirir. */
export function satirGovdesi(satirlar: readonly CozulmusSatir[]): PanoSatirKaydi[] {
  return satirlar.map((s) => ({
    sutun: sutunKis(s.sutun),
    idler: s.bolumler.map((b) => b.id),
    baslik: s.baslik ?? null,
  }));
}

/** Sunucuya yazilacak govde. */
export function tercihGovdesi(
  widgetlar: readonly string[],
  bolumler: readonly CozulmusBolum[],
  satirlar?: readonly CozulmusSatir[],
): PanoTercihi {
  const govde: PanoTercihi = {
    widgetlar: widgetlar.slice(0, WIDGET_SINIRI).map((rota) => ({ rota })),
    bolumler: bolumler.map((b) => ({ id: b.id, gizli: b.gizli })),
  };
  if (satirlar) govde.satirlar = satirGovdesi(satirlar);
  return govde;
}

/** Bilinen bir bolum kimligi mi? (Testler ve tur daraltma icin.) */
export function bolumTanimli(id: string): id is PanoBolumId {
  return BOLUM_IDLERI.has(id);
}

/* ---------------------------------------------------------------------------
 * (P182 §4) YERLESIM YENIDEN SIRALAMA — SAF DONUSUMLER.
 *
 * Surukle-birak ve klavye ile bolum tasima ASIL ETKILESIM. Mantik burada saf
 * fonksiyon olarak durur (bilesenin disinda) ki jsdom'da surukle olaylari
 * uretmeden DAVRANIS test edilebilsin. Bilesen yalniz olayi bu fonksiyonlara
 * baglar; index kaymasi/bos satir temizligi tek yerde tutulur.
 * ------------------------------------------------------------------------- */

/** Satirlarin derin kopyasi (bolum dizileri de kopyalanir). */
function satirlariKopyala(satirlar: readonly CozulmusSatir[]): CozulmusSatir[] {
  return satirlar.map((s) => ({ ...s, bolumler: [...s.bolumler] }));
}

/** Bir bolumu (kimlikle) diziden cikarir; cikarilani dondurur. */
function bolumSok(satirlar: CozulmusSatir[], id: string): CozulmusBolum | null {
  for (const s of satirlar) {
    const i = s.bolumler.findIndex((b) => b.id === id);
    if (i !== -1) return s.bolumler.splice(i, 1)[0];
  }
  return null;
}

/**
 * SURUKLE-BIRAK: `kaynakId` bolumunu hedefe tasir. Hedef ya BASKA BIR BOLUMUN
 * ONUNE (`{tip:"once", id}`) ya da BIR SATIRIN SONUNA (`{tip:"satirSonu", si}`,
 * bos satira birakmak icin). Kimlikle calisir; kaynak silindikten sonra dizin
 * kaymasi olmaz cunku bos satirlar YALNIZ en sonda temizlenir. `si` orijinal
 * dizinle ayni kalir (bu ana kadar satir SILINMEZ). Kaynak==hedef ise degismez.
 */
export function bolumSurukleBirak(
  satirlar: readonly CozulmusSatir[],
  kaynakId: string,
  hedef: { tip: "once"; id: string } | { tip: "satirSonu"; si: number },
): CozulmusSatir[] {
  if (hedef.tip === "once" && hedef.id === kaynakId) return satirlariKopyala(satirlar);
  const kopya = satirlariKopyala(satirlar);
  const bolum = bolumSok(kopya, kaynakId);
  if (!bolum) return kopya;
  if (hedef.tip === "once") {
    for (const s of kopya) {
      const i = s.bolumler.findIndex((b) => b.id === hedef.id);
      if (i !== -1) {
        s.bolumler.splice(i, 0, bolum);
        break;
      }
    }
  } else {
    // Kaynak cikarilinca `si` hedef satirin dizini DEGISMEZ (henuz filtre yok).
    (kopya[hedef.si] ?? kopya[kopya.length - 1])?.bolumler.push(bolum);
  }
  return kopya.filter((s) => s.bolumler.length > 0);
}

/** Klavye ok yonu: satir icinde sol/sag, satirlar arasi yukari/asagi. */
export type BolumYon = "sol" | "sag" | "yukari" | "asagi";

/**
 * KLAVYE ile bolum tasima (surukle-birak'in erisilebilir esdegeri). Sol/sag
 * bolumu SATIR ICINDE komsusuyla degistirir; yukari/asagi bolumu ONceki/SONraki
 * satirin sonuna tasir (bosalan satir silinir). Sinirda (ilk/son) DEGISMEZ.
 */
export function bolumOkTasi(
  satirlar: readonly CozulmusSatir[],
  si: number,
  bi: number,
  yon: BolumYon,
): CozulmusSatir[] {
  const kopya = satirlariKopyala(satirlar);
  const satir = kopya[si];
  if (!satir || bi < 0 || bi >= satir.bolumler.length) return kopya;
  if (yon === "sol" || yon === "sag") {
    const bj = bi + (yon === "sol" ? -1 : 1);
    if (bj < 0 || bj >= satir.bolumler.length) return kopya;
    [satir.bolumler[bi], satir.bolumler[bj]] = [satir.bolumler[bj], satir.bolumler[bi]];
    return kopya;
  }
  const sj = si + (yon === "yukari" ? -1 : 1);
  if (sj < 0 || sj >= kopya.length) return kopya;
  const [bolum] = satir.bolumler.splice(bi, 1);
  kopya[sj].bolumler.push(bolum);
  return kopya.filter((s) => s.bolumler.length > 0);
}
