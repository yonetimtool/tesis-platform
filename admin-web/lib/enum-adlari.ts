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
  talep_is_emri: "bildirimTipTalepIsEmri",
  talep_cozuldu: "bildirimTipTalepCozuldu",
  talep_reddedildi: "bildirimTipTalepReddedildi",
  is_emri_atandi: "bildirimTipIsEmriAtandi",
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
