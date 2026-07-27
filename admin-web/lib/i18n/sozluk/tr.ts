// TURKCE sozluk — KAYNAK dil (tur 17).
//
// Bu dosya sozlugun TIPINI de belirler (`type Sozluk = typeof tr`): diger
// diller ondan turer, dolayisiyla eksik ya da fazla anahtar DERLEME
// HATASIDIR. Yeni metin eklerken once buraya yazilir, sonra `npx tsc` alti
// dilde de eksigi soyler.
//
// ANAHTAR ADLANDIRMA: `<alan><Ne>` (orn. `kabukAyarlar`, `girisParola`).
// Alan onekleri: ortak / kabuk / giris / panel / ayar.
//
// CEVRILMEYENLER (bilincli): marka adi "Yönetio", dil adlari (kendi
// dilinde), teknik sabitler (slug, kod), tesis/kullanici verisi.

export const tr = {
  // ------------------------------- ortak ---------------------------------
  ortakYukleniyor: "Yükleniyor...",
  ortakKaydet: "Kaydet",
  ortakKaydediliyor: "Kaydediliyor...",
  ortakIptal: "İptal",
  ortakVazgec: "Vazgeç",
  ortakSil: "Sil",
  ortakSiliniyor: "Siliniyor...",
  ortakDuzenle: "Düzenle",
  ortakEkle: "Ekle",
  ortakYenile: "Yenile",
  ortakKapat: "Kapat",
  ortakTumu: "Tümü",
  ortakAktif: "Aktif",
  ortakPasif: "Pasif",
  ortakAcik: "Açık",
  ortakKapali: "Kapalı",
  ortakEvet: "Evet",
  ortakHayir: "Hayır",
  ortakDiger: "Diğer",
  ortakBaslangic: "Başlangıç",
  ortakBitis: "Bitiş",
  ortakDonem: "Dönem",
  ortakBaslik: "Başlık",
  ortakAciklama: "Açıklama",
  ortakAciklamaOpsiyonel: "Açıklama (opsiyonel)",
  ortakAra: "Ara",
  ortakFiltre: "Filtre",
  ortakKayitYok: "Kayıt yok.",
  ortakHataOlustu: "Bir hata oluştu.",
  ortakOturumSuresiDoldu: "Oturum süresi doldu.",
  ortakSunucuyaUlasilamadi: "Sunucuya ulaşılamadı.",
  ortakGeriDon: "Geri dön",
  ortakDetay: "Detay",
  ortakToplam: "Toplam",
  ortakDurum: "Durum",
  ortakTarih: "Tarih",
  ortakSaat: "Saat",
  ortakAd: "Ad",
  ortakRol: "Rol",
  ortakDaire: "Daire",
  ortakBlok: "Blok",
  ortakTesis: "Tesis",
  ortakSecin: "Seçin",
  ortakZorunluAlan: "Bu alan zorunludur.",

  // ------------------------------- kabuk ---------------------------------
  kabukCanliPanel: "Canlı Panel",
  kabukTesisler: "Tesisler",
  kabukVardiyalar: "Vardiyalar",
  kabukNfcNoktalari: "NFC Noktaları",
  kabukDevriyePlanlari: "Devriye Planları",
  kabukGorevler: "Görevler",
  kabukDemirbas: "Demirbaş",
  kabukDaireler: "Daireler",
  kabukBinaDuzenleme: "Bina Düzenleme",
  kabukSikayetHaritasi: "Şikayet Haritası",
  kabukAidat: "Aidat",
  kabukRaporlar: "Raporlar",
  kabukSeffaflik: "Şeffaflık",
  kabukKullanicilar: "Kullanıcılar",
  kabukDuyurular: "Duyurular",
  kabukTalepler: "Talepler",
  kabukBildirimler: "Bildirimler",
  kabukEntegrasyonlar: "Entegrasyonlar",
  kabukDestek: "Destek",
  kabukDenetimKaydi: "Denetim Kaydı",
  kabukAyarlar: "Ayarlar",
  kabukMenuyuAc: "Menüyü aç",
  kabukMenuyuKapat: "Menüyü kapat",
  kabukCikisYap: "Çıkış yap",

  // ------------------------------ tema / dil ------------------------------
  temaAcik: "Açık",
  temaKoyu: "Koyu",
  temaSistem: "Sistem",
  temaSecici: "Tema",
  dilSecici: "Dil",
  dilSeciciBaslik: "Dil / Language",

  // ------------------------------- giris ---------------------------------
  girisYonetimPaneli: "Yönetim Paneli",
  girisYalnizAdmin: "Yalnızca platform admini giriş yapabilir.",
  girisTesisSlug: "Tesis (slug)",
  girisEposta: "E-posta",
  girisParola: "Parola",
  girisBeniHatirla: "Beni hatırla",
  girisYap: "Giriş yap",
  girisYapiliyor: "Giriş yapılıyor...",
  girisBasarisiz: "Giriş başarısız.",
  girisSloganBaslik: "Tesis operasyonunuz, tek panelden.",
  girisSloganAlt:
    "Devriye, görev, aidat ve sakin akışlarını tek yerden yönetin — canlı durum, net raporlar, sade bir arayüz.",
  girisAltBilgi: "Yönetio · çok kiracılı tesis operasyon platformu",

  // ------------------------- sayfa ust verisi -----------------------------
  // `<title>` ve meta aciklama da dile duyarli: tarayici sekmesi ve
  // paylasim onizlemesi kullanicinin dilinde gorunur.
  metaBaslik: "Yönetio Paneli",
  metaAciklama:
    "Yönetio — çok kiracılı tesis operasyon SaaS yönetim paneli",

  // -------------------------------- roller --------------------------------
  // Rol ADLARI: sozlesme degeri (`admin`, `yonetici`...) KIMLIKTIR; burada
  // yalniz gorunen ad cevrilir. Kontrol akisi ASLA bu metne bakmaz.
  rolPlatformAdmin: "Platform Admin",
  rolYonetici: "Yönetici",
  rolGuvenlik: "Güvenlik",
  rolTesisGorevlisi: "Tesis Görevlisi",
  rolSiteSakini: "Site Sakini",

  // ------------------------------ canli panel -----------------------------
  panelBugunkuTurlar: "Bugünkü Turlar",
  panelKacirilanYok: "kaçırılan yok",
  panelAktifAlarm: "Aktif Alarm",
  panelHerSeyYolunda: "her şey yolunda",

  // ------------------------------- ayarlar --------------------------------
  ayarTesisAdi: "Tesis adı",
  ayarSaatDilimiOrnek: "Örn: Europe/Istanbul",

  // ----------------------------- bildirimler ------------------------------
  bildirimOkunduIsaretlendi: "Bildirim okundu olarak işaretlendi.",
  bildirimOkunmamis: "Okunmamış",
  bildirimOkunmus: "Okunmuş",

  // ------------------------------- raporlar -------------------------------
  raporAidatTahsilat: "Aidat Tahsilat",
  raporTurGecmisi: "Tur Geçmişi",
  raporGorevGecmisi: "Görev Geçmişi",
} as const;
