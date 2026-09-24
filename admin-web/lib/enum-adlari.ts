// (P53) TEL DEGERI -> GORUNEN AD — tek kaynak.
//
// Sunucu numaralandirmalari tel degeriyle doner (`basarili`, `zimmetli`,
// `kacirilan_tur`). Bunlari ekrana OLDUGU GIBI yazmak iki ayri hataydi:
// kullanici alt cizgili teknik jetonlar goruyordu ve dil degistirdiginde
// hicbir sey degismiyordu.
//
// HARITA BURADA, SAYFADA DEGIL: ayni numaralandirma birden cok sayfada
// gorunuyor (tur durumu hem panoda hem tur raporunda, odeme durumu hem
// aidat sayfasinda hem daire detayinda). Her sayfada ayri bir harita
// tutmak, birinin guncellenip digerinin unutulmasi demekti — nitekim
// P51'de bildirim tipi YALNIZ bildirimler sayfasinda cevrilmis, PANODAKI
// ayni rozet ham kalmisti.
//
// EKSIK DEGER HAM DONER: sunucu numaralandirmaya yeni bir deger eklerse
// (ya da urunden kaldirilmis eski bir kayit gorunurse) rozet BOS KALMAZ.
// Bos rozet, "durum yok" gibi okunur ve yanlis bilgidir.
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

export type EnumHarita = Record<string, SozlukAnahtari>;

/** `notification_tip` (bildirimler sayfasi + panodaki alarm listesi). */
export const BILDIRIM_TIP: EnumHarita = {
  kacirilan_tur: "bildirimTipKacirilanTur",
  eksik_checkpoint: "bildirimTipEksikCheckpoint",
  gecikmis_okutma: "bildirimTipGecikmisOkutma",
  uzak_okutma: "bildirimTipUzakOkutma",
  talep_is_emri: "bildirimTipTalepIsEmri",
  talep_cozuldu: "bildirimTipTalepCozuldu",
  talep_reddedildi: "bildirimTipTalepReddedildi",
  is_emri_atandi: "bildirimTipIsEmriAtandi",
  // (P147) Sakinin KENDI olaylarinin geri donusu. Bu dort deger arka uca
  // eklendiginde BURASI unutulmustu ve `enum-bag` kilidi yakaladi —
  // aynanin varlik sebebi tam olarak bu.
  kargo: "bildirimTipKargo",
  ziyaretci: "bildirimTipZiyaretci",
  rezervasyon: "bildirimTipRezervasyon",
  sikayet_cozuldu: "bildirimTipSikayetCozuldu",
  // (P181 Bölüm 10.2) Vardiya sonu özeti (batching) — "X/Y nokta okutuldu".
  vardiya_ozeti: "bildirimTipVardiyaOzeti",
  // (E2E 2026-09) Sunucu enum'unda VARDI, haritada yoktu (model de
  // eksikti; `GET /notifications` 500 veriyordu).
  vardiya_hatirlatma: "bildirimTipVardiyaHatirlatma",
  vardiya_baslamadi: "bildirimTipVardiyaBaslamadi",
  // (P191 §2, göç 0078) Görev atama ve aidat borcu — ikisinin de bildirimi
  // HIC YOKTU; "görev oluşturdum, telefona hiçbir şey gelmedi" bundandı.
  gorev_atandi: "bildirimTipGorevAtandi",
  // (P229 §3, göç 0131) Görev TAMAMLANINCA yönetime bildirim. `gorev_atandi`
  // ile ayrı tip: yönleri ters (atama yönetimden sahaya, tamamlanma sahadan
  // yönetime) ve tek tipe indirmek, bildirim tercihinde birini kapatmayı
  // ötekini de kapatmak yapardı.
  gorev_tamamlandi: "bildirimTipGorevTamamlandi",
  // (P237 §2, göç 0136) Alt adım ilerlemesi — EŞİKLİ/TOPLU gönderilir.
  // `gorev_tamamlandi`dan ayrı: biri işin SONUNU, öteki ORTASINI bildirir;
  // tek tipe indirmek "ilerlemeyi kapat, bitişi al" tercihini yok ederdi.
  gorev_adim_ilerleme: "bildirimTipGorevAdimIlerleme",
  // (P237 §3, göç 0137) Anket açılınca hedef kitleye bildirim.
  anket_acildi: "bildirimTipAnketAcildi",
  // (P240 §1) PANIK — uc ayri tip: alarm, yanlis alarm duzeltmesi, kapanis.
  panik_alarm: "bildirimTipPanikAlarm",
  panik_yanlis_alarm: "bildirimTipPanikYanlisAlarm",
  panik_kapandi: "bildirimTipPanikKapandi",
  // (P240 §4) Entegrasyon baglantisi koptu (yonetim alarmi).
  entegrasyon_koptu: "bildirimTipEntegrasyonKoptu",
  // (P240 §3) Akilli ev olaylari.
  akilli_ev_kacak: "bildirimTipAkilliEvKacak",
  akilli_ev_yangin: "bildirimTipAkilliEvYangin",
  // (P241 §1) Periyodik bakim — uc kademe.
  bakim_yaklasti: "bildirimTipBakimYaklasti",
  bakim_bugun: "bildirimTipBakimBugun",
  bakim_gecikti: "bildirimTipBakimGecikti",
  // (P241 §2) Vardiya plani yayinlandi.
  vardiya_yayinlandi: "bildirimTipVardiyaYayinlandi",
  aidat_borc: "bildirimTipAidatBorc",
  // (P191 §4) Banka eslestirmesi odemeyi isledi -> "odemeniz alindi".
  aidat_odendi: "bildirimTipAidatOdendi",
  // (P192 §4, göç 0086) OTOMASYON bildirimleri: hatırlatma (sakine),
  // tahakkuk önizlemesi / aylık özet / gider onayı (yöneticiye).
  aidat_hatirlatma: "bildirimTipAidatHatirlatma",
  aidat_onizleme: "bildirimTipAidatOnizleme",
  aylik_ozet: "bildirimTipAylikOzet",
  gider_onay: "bildirimTipGiderOnay",
  // (P208 §1, göç 0103) Gürültü eşiği: sakine uyarı + yönetime bilgi.
  // NOT (P212): bu iki değer arka uçta P208'de eklenmişti ama BURAYA
  // yazılmamıştı — `enum-bag` kilidi P212'de yakaladı (aynanın varlık
  // sebebi tam olarak bu; P147'de de aynısı olmuştu).
  gurultu_uyari_sakin: "bildirimTipGurultuUyariSakin",
  gurultu_esik_yonetim: "bildirimTipGurultuEsikYonetim",
  // (P212 §3, göç 0104) İkinci eşikte güvenliğe eskalasyon + yönetime bilgi.
  gurultu_eskalasyon_guvenlik: "bildirimTipGurultuEskalasyonGuvenlik",
  gurultu_eskalasyon_yonetim: "bildirimTipGurultuEskalasyonYonetim",
};

/** `patrol_window_durum` (pano "Bugunun turlari" + tur raporu). */
export const TUR_DURUM: EnumHarita = {
  bekliyor: "turDurumBekliyor",
  tamamlandi: "turDurumTamamlandi",
  kacirildi: "turDurumKacirildi",
};

/** `dues_durum` (aidat odemeleri + daire detayi). */
export const ODEME_DURUM: EnumHarita = {
  basarili: "odemeDurumBasarili",
  bekliyor: "odemeDurumBekliyor",
  iptal: "odemeDurumIptal",
};

/** `dues_yontem` (daire detayindaki odeme satiri). */
export const ODEME_YONTEM: EnumHarita = {
  elden: "odemeYontemElden",
  havale: "odemeYontemHavale",
  kart: "odemeYontemKart",
  diger: "odemeYontemDiger",
};

/** `asset_durum`. */
export const DEMIRBAS_DURUM: EnumHarita = {
  musait: "demirbasDurumMusait",
  zimmetli: "demirbasDurumZimmetli",
  bakimda: "demirbasDurumBakimda",
};

/** `asset_kategori`. */
export const DEMIRBAS_KATEGORI: EnumHarita = {
  ekipman: "demirbasKategoriEkipman",
  arac: "demirbasKategoriArac",
  alet: "demirbasKategoriAlet",
  diger: "demirbasKategoriDiger",
};

/** Gorunen ad; harita disindaki deger HAM doner (bkz. dosya basligi). */
export function enumAdi(
  t: (a: SozlukAnahtari) => string,
  harita: EnumHarita,
  deger: string | null | undefined,
): string {
  if (!deger) return "—";
  const anahtar = harita[deger];
  return anahtar ? t(anahtar) : deger;
}
