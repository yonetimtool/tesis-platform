/**
 * (P241 §2e) BILDIRIM -> HEDEF EKRAN.
 *
 * =========================================================================
 * NEDEN BEYAZ LISTE, NEDEN MOBILDEKININ IKIZI
 * =========================================================================
 * Mobilde ayni harita `bildirim_rotasi.dart`ta yasiyor ve P240'ta bir
 * kusur uretmisti: yeni bildirim aileleri eklenmis, harita
 * GUNCELLENMEMISTI — panik push'una dokunan kullanici alarm ekranina
 * GITMIYORDU. Kaynak testleri goremedi cunku "bilinmeyen tipe null
 * donmek" TASARIMIN KENDISI.
 *
 * Bu yuzden burada da beyaz liste var VE `test_bildirim_rotasi` her iki
 * yuzeyin haritasini AYNI kumeyle karsilastiriyor: biri eklenip oteki
 * unutulursa test duser.
 *
 * `null` DONMEK BIR HATA DEGIL: o tipin gidecegi bir ekran yok demektir
 * ve satir yalnizca okunur. Uydurma bir hedef vermek, kullaniciyi
 * alakasiz bir ekrana atmak olurdu.
 */
export const BILDIRIM_ROTALARI: Record<string, string> = {
  // Devriye alarmlari.
  kacirilan_tur: "/devriye?sekme=takip",
  eksik_checkpoint: "/devriye?sekme=takip",
  gecikmis_okutma: "/devriye?sekme=takip",
  uzak_okutma: "/devriye?sekme=takip",
  // Talep akisi.
  talep_is_emri: "/complaints",
  talep_cozuldu: "/complaints",
  talep_reddedildi: "/complaints",
  is_emri_atandi: "/tasks",
  gorev_atandi: "/tasks",
  gorev_tamamlandi: "/tasks",
  gorev_adim_ilerleme: "/tasks",
  // (P241 §2e) SAKININ KENDI OLAYLARI — mobil haritada vardi, web'de
  // YOKTU. Web'de bildirim listesi yalniz yonetimde ve yonetici de bu
  // kayitlari kendi ekranindan izliyor; hedefi olmayan bir satir
  // birakmak, ayni tipe iki yuzeyde iki farkli davranis vermekti.
  kargo: "/kargolar",
  // (P247 §3) "Kargonuz guvenlik tarafindan teslim edildi".
  kargo_teslim: "/kargolar",
  ziyaretci: "/ziyaretciler",
  rezervasyon: "/rezervasyon-yonetimi",
  sikayet_cozuldu: "/complaints",
  // (P240) Panik / akilli ev / entegrasyon.
  panik_alarm: "/panik",
  panik_yanlis_alarm: "/panik",
  panik_yardim_talebi: "/panik",
  panik_tatbikat_duyuru: "/panik",
  // (P249 §3) Onay talebi/yaniti ziyaretci kaydinda. Sesli mesajin web'de
  // ekrani YOK (dinleme mobil; parite istisnasi docs §3.6) — liste sayfasi.
  ziyaretci_onay_istegi: "/ziyaretciler",
  ziyaretci_onay_yaniti: "/ziyaretciler",
  sesli_mesaj: "/ziyaretciler",
  panik_kapandi: "/panik",
  akilli_ev_kacak: "/akilli-ev",
  akilli_ev_yangin: "/akilli-ev",
  entegrasyon_koptu: "/integrations",
  // (P241 §1) Bakim.
  bakim_yaklasti: "/bakim",
  bakim_bugun: "/bakim",
  bakim_gecikti: "/bakim",
  // (P241 §2e) Vardiya plani yayinlandi.
  vardiya_yayinlandi: "/vardiya-plani",
};

export function bildirimRotasi(tip: string): string | null {
  return BILDIRIM_ROTALARI[tip] ?? null;
}
