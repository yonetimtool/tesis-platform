// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get cipYeni => 'Yeni';

  @override
  String get cipAktif => 'Aktif';

  @override
  String get bolumVardiyaDurumu => 'Vardiya Durumu';

  @override
  String get bolumSonHareketler => 'Son Hareketler';

  @override
  String get bolumHizliOzet => 'Hızlı Özet';

  @override
  String get bolumDuyurular => 'Duyurular';

  @override
  String get bolumSiteKurallari => 'Site Kuralları';

  @override
  String get bolumEtkinlikler => 'Etkinlikler';

  @override
  String get bolumOdemeAidat => 'Ödeme ve Aidat Durumu';

  @override
  String get bolumTumModuller => 'Tüm Modüller';

  @override
  String get kartVardiyaDurum => 'Vardiya Durum';

  @override
  String get kartKargo => 'Kargo';

  @override
  String get kartZiyaretci => 'Ziyaretçi';

  @override
  String get kartAracPlaka => 'Araç Plaka';

  @override
  String get kartIhlaller => 'İhlaller';

  @override
  String get kartGorevlerim => 'Görevlerim';

  @override
  String get kartDemirbas => 'Demirbaş';

  @override
  String get kartTurlarim => 'Turlarım';

  @override
  String get kartTalepAriza => 'Talep / Arıza';

  @override
  String get kartZiyaretciler => 'Ziyaretçiler';

  @override
  String get kartKargolarim => 'Kargolarım';

  @override
  String get kartAidatBilgileri => 'Aidat Bilgileri';

  @override
  String get kartGurultuSikayeti => 'Gürültü Şikayeti';

  @override
  String get kartGeriBildirim => 'Geri Bildirim';

  @override
  String get kartSikayetlerim => 'Şikayetlerim';

  @override
  String get kartSiteRaporlari => 'Site Raporları';

  @override
  String get kartGorevler => 'Görevler';

  @override
  String get kartAidatDurumu => 'Aidat Durumu';

  @override
  String get kartOtoparkKullanimi => 'Otopark Kullanımı';

  @override
  String get kartSikayetler => 'Şikayetler';

  @override
  String get kartRaporlar => 'Raporlar';

  @override
  String get kartYonetici => 'Yönetici';

  @override
  String get kartGonderimKuyrugu => 'Gönderim Kuyruğu';

  @override
  String get etiketAylikOzet => 'Aylık Özet';

  @override
  String get etiketDevriye => 'Devriye';

  @override
  String get etiketKurallar => 'Kurallar';

  @override
  String get etiketIletisim => 'İletişim';

  @override
  String sayacAktif(num n) {
    return '$n Aktif';
  }

  @override
  String sayacIceride(num n) {
    return '$n İçeride';
  }

  @override
  String sayacGiris(num n) {
    return '$n Giriş';
  }

  @override
  String sayacYeni(num n) {
    return '$n Yeni';
  }

  @override
  String sayacAcik(num n) {
    return '$n Açık';
  }

  @override
  String sayacZimmetli(num n) {
    return '$n Zimmetli';
  }

  @override
  String sayacKayit(num n) {
    return '$n Kayıt';
  }

  @override
  String sayacYaklasan(num n) {
    return '$n Yaklaşan';
  }

  @override
  String sayacDaire(num n) {
    return '$n Daire';
  }

  @override
  String sayacArac(num n) {
    return '$n araç';
  }

  @override
  String sayacGorevli(num n) {
    return '$n Görevli';
  }

  @override
  String sayacBekleyen(num n) {
    return '$n bekleyen';
  }

  @override
  String get ozetToplamDaire => 'Toplam Daire';

  @override
  String get ozetToplamTahsilat => 'Toplam Tahsilat';

  @override
  String get ozetTahsilatOrani => 'Aidat Tahsilat Oranı';

  @override
  String get ozetOtoparkDoluluk => 'Otopark Doluluk';

  @override
  String get ozetTumSite => 'Tüm Site';

  @override
  String get ozetBuAy => 'Bu Ay';

  @override
  String get ozetSuAn => 'Şu An';

  @override
  String otoparkDoluKapasite(Object dolu, Object kapasite) {
    return '$dolu / $kapasite';
  }

  @override
  String yuzdeDeger(Object oran) {
    return '%$oran';
  }

  @override
  String anaSelam(Object ad) {
    return 'Merhaba, $ad';
  }

  @override
  String get anaYoneticiPaneli => 'Yönetici Paneli';

  @override
  String anaDaireAltBaslik(Object daireler, Object rol) {
    return 'Daire $daireler  •  $rol';
  }

  @override
  String get anaDun => 'Dün';

  @override
  String get anaOnline => 'Online';

  @override
  String get anaVardiyaAktif => 'Aktif';

  @override
  String get anaVardiyaPlanlandi => 'Planlandı';

  @override
  String get anaEtkinlikSuruyor => 'Sürüyor';

  @override
  String get anaEtkinlikYaklasan => 'Yaklaşan';

  @override
  String get anaOdendi => 'Ödendi';

  @override
  String get anaOdenmedi => 'Ödenmedi';

  @override
  String get anaBorcVar => 'Borç Var';

  @override
  String get anaBorcYok => 'Borç Yok';

  @override
  String get anaBuAykiAidat => 'Bu Ayki Aidat';

  @override
  String anaSonOdemeTarih(Object tarih) {
    return 'Son Ödeme: $tarih';
  }

  @override
  String get anaGelecekOdeme => 'Gelecek Ödeme';

  @override
  String get anaGecmisOdemeler => 'Geçmiş Ödemeler';

  @override
  String get anaAidatKaydiYok => 'Aidat kaydı bulunamadı';

  @override
  String get anaBildirimlerYakinda => 'Bildirimler yakında';

  @override
  String get anaBildirimlerRolYok => 'Bildirimler bu rolde kullanılamıyor';

  @override
  String get anaRaporlarYakinda => 'Raporlar yakında';

  @override
  String get sekmeAnaSayfa => 'Ana Sayfa';

  @override
  String get sekmeBildirimler => 'Bildirimler';

  @override
  String get sekmeRaporlar => 'Raporlar';

  @override
  String get sekmeAyarlar => 'Ayarlar';

  @override
  String get kabukProfil => 'Profil';

  @override
  String get kabukCikisYap => 'Çıkış Yap';

  @override
  String get fabOlayBildir => 'Olay Bildir';

  @override
  String get fabTalepBildir => 'Talep / Bildir';

  @override
  String get fabTalepArizaBildir => 'Talep / Arıza Bildir';

  @override
  String get fabRezervasyonYap => 'Rezervasyon Yap';

  @override
  String get fabDuyuruYayinla => 'Duyuru Yayınla';

  @override
  String get fabGorevOlustur => 'Görev Oluştur';

  @override
  String get fabDestekTalebi => 'Destek Talebi';

  @override
  String get modulDuyurular => 'Duyurular';

  @override
  String get modulTurlarim => 'Turlarım';

  @override
  String get modulDevriyeTakibi => 'Devriye Takibi';

  @override
  String get modulGorevlerim => 'Görevlerim';

  @override
  String get modulGorevYonetimi => 'Görev Yönetimi';

  @override
  String get modulDemirbas => 'Demirbaş';

  @override
  String get modulNfcOkutma => 'NFC Okutma';

  @override
  String get modulGonderimKuyrugu => 'Gönderim Kuyruğu';

  @override
  String get modulAylikRaporlar => 'Aylık Raporlar';

  @override
  String get modulButce => 'Bütçe';

  @override
  String get modulFinansalOzet => 'Finansal Özet';

  @override
  String get modulSeffaflik => 'Şeffaflık';

  @override
  String get modulSiteButcesi => 'Site Bütçesi';

  @override
  String get modulAidatim => 'Aidatım';

  @override
  String get modulSikayetOneri => 'Şikayet / Öneri';

  @override
  String get modulZiyaretciler => 'Ziyaretçiler';

  @override
  String get modulKargo => 'Kargo';

  @override
  String get modulGoruntulemeIzni => 'Görüntüleme İzni';

  @override
  String get modulRezervasyon => 'Rezervasyon';

  @override
  String get modulEtkinlikler => 'Etkinlikler';

  @override
  String get modulSiteKurallari => 'Site Kuralları';

  @override
  String get modulDisHizmetler => 'Dış Hizmetler';

  @override
  String get modulEntegrasyonlar => 'Entegrasyonlar';

  @override
  String get modulPersonel => 'Saha Personeli';

  @override
  String get modulSakinler => 'Site Sakinleri';

  @override
  String get modulBinaYapisi => 'Bina Yapısı';

  @override
  String get modulSikayetHaritasi => 'Şikayet Haritası';

  @override
  String get modulSikayetlerim => 'Şikayetlerim';

  @override
  String get modulYoneticiIletisim => 'Yönetici İletişim';

  @override
  String get ortakKaydet => 'Kaydet';

  @override
  String sayacBekliyor(num n) {
    return '$n Bekliyor';
  }

  @override
  String get ortakKaydediliyor => 'Kaydediliyor...';

  @override
  String get ortakVazgec => 'Vazgeç';

  @override
  String get ortakSil => 'Sil';

  @override
  String get ortakDuzenle => 'Düzenle';

  @override
  String get ortakEkle => 'Ekle';

  @override
  String get ortakTamam => 'Tamam';

  @override
  String get ortakKapat => 'Kapat';

  @override
  String get ortakTumunuGor => 'Tümünü Gör';

  @override
  String get ortakYuklenemedi => 'Yüklenemedi';

  @override
  String get ortakYenidenDene => 'Yeniden dene';

  @override
  String get ortakYakinda => 'Yakında';

  @override
  String get ortakBolumYakinda => 'Bu bölüm yakında';

  @override
  String get ortakBeklenmeyenHata =>
      'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';

  @override
  String ortakZorunluAlan(Object alan) {
    return '$alan zorunludur';
  }

  @override
  String get ayarlarBaslik => 'Ayarlar';

  @override
  String get ayarlarTesis => 'Tesis';

  @override
  String get ayarlarYonetim => 'Yönetim';

  @override
  String get ayarlarGorunum => 'Görünüm';

  @override
  String get ayarlarTema => 'Tema';

  @override
  String get ayarlarTemaSistem => 'Sistem';

  @override
  String get ayarlarTemaAcik => 'Açık';

  @override
  String get ayarlarTemaKoyu => 'Koyu';

  @override
  String get ayarlarTemaAciklama =>
      'Koyu tema tüm ekranlarda uygulanır; sistem seçilirse cihaz ayarını izler.';

  @override
  String get ayarlarTesisAdi => 'Tesis adı';

  @override
  String get ayarlarTesisAdiAciklama => 'Ana ekranda ve raporlarda görünen ad.';

  @override
  String get ayarlarTesisAdiGuncellendi => 'Tesis adı güncellendi';

  @override
  String get ayarlarKameralar => 'Kameralar';

  @override
  String get ayarlarKameralarAlt => 'Kamera ekle, düzenle, sil';

  @override
  String get ayarlarDil => 'Dil / Language';

  @override
  String get dilSecBaslik => 'Uygulama dili';

  @override
  String get kameraBaslik => 'Kameralar';

  @override
  String get kameraEkle => 'Kamera Ekle';

  @override
  String get kameraYeni => 'Yeni kamera';

  @override
  String get kameraDuzenleBaslik => 'Kamerayı düzenle';

  @override
  String get kameraAd => 'Ad';

  @override
  String get kameraKonum => 'Konum (opsiyonel)';

  @override
  String get kameraTur => 'Tür';

  @override
  String get kameraUrl => 'Yayın URL\'si';

  @override
  String get kameraAktif => 'Aktif';

  @override
  String get kameraAktifAlt => 'Kapalıyken hiçbir listede görünmez';

  @override
  String get kameraSakinGorebilir => 'Site sakinleri görebilsin';

  @override
  String get kameraSakinGorebilirAlt =>
      'Kapalıyken kamerayı yalnızca yönetim ve güvenlik görür';

  @override
  String get kameraRtspFormUyari =>
      'RTSP yayınlar şu an uygulama içinde oynatılamaz. Kayıt saklanır; oynatma desteği ileride eklenecek.';

  @override
  String get kameraUrlZorunlu => 'Yayın adresi zorunludur';

  @override
  String kameraUrlHataHttp(Object tur) {
    return '$tur yayın adresi http:// veya https:// ile başlamalı';
  }

  @override
  String get kameraUrlHataRtsp => 'RTSP yayın adresi rtsp:// ile başlamalı';

  @override
  String get kameraSilBaslik => 'Kamerayı sil';

  @override
  String kameraSilOnay(Object ad) {
    return '\"$ad\" silinsin mi?';
  }

  @override
  String get kameraBosYonetim =>
      'Kamera tanımı yok. Sağ alttan ekleyebilirsiniz.';

  @override
  String get kameraBosSakin => 'Görüntülemenize açık kamera yok.';

  @override
  String get kameraListeHata => 'Kameralar yüklenemedi.';

  @override
  String get kameraCanli => 'Canlı';

  @override
  String get kameraKareYok => 'Görüntü alınamıyor';

  @override
  String get kameraUrlWebSayfasi =>
      'Bu bir web sayfası adresi. Uygulama yalnız doğrudan yayın adreslerini oynatır: .m3u8 (HLS) veya .mp4.';

  @override
  String get kameraKaynakYardim =>
      'Yalnız doğrudan medya adresleri oynatılır: HLS (.m3u8) ve MP4. Web sayfaları (YouTube, Vimeo, belediye izleyici sayfaları) oynatılamaz. RTSP kaydedilir ama oynatmak için bir HLS geçidi gerekir.';

  @override
  String get kameraSnapshot => 'Anlık görüntü adresi';

  @override
  String get kameraSnapshotAlt =>
      'İsteğe bağlı. Doldurulursa kamera listesinde canlı kare gösterilir (tek kare, JPEG).';

  @override
  String get kameraOynatilamiyor => 'Oynatılamıyor';

  @override
  String get kameraYayinAcilamadi => 'Yayın açılamadı';

  @override
  String get kameraYayinAcilamadiAlt =>
      'Kamera kapalı olabilir ya da ağ yayına ulaşamıyor.';

  @override
  String kameraTurEtiket(Object tur) {
    return 'Tür: $tur';
  }

  @override
  String get kameraRtspBilgi =>
      'RTSP yayınlar şu an uygulama içinde oynatılamıyor. Kayıt sistemde tutuluyor; oynatma desteği ileride eklenecek.';

  @override
  String get kameraSeritBaslik => 'Canlı Kamera';

  @override
  String anaKarsilama(String ad) {
    return 'Merhaba, $ad';
  }

  @override
  String get gorevKategorilerTooltip => 'Kategoriler';

  @override
  String get gorevYeni => 'Yeni görev';

  @override
  String get gorevOlusturuldu => 'Görev oluşturuldu ✓';

  @override
  String get gorevListesiYetkiYok =>
      'Görev listesi için yetkiniz yok. Bu ekran temizlik ve güvenlik rollerine açıktır.';

  @override
  String get gorevBuFiltredeYok => 'Bu filtreyle aktif görev yok.';

  @override
  String get gorevCipBanaAtanan => 'Bana atanan';

  @override
  String get gorevCipTumGorevler => 'Tüm görevler';

  @override
  String get gorevCipTumu => 'Tümü';

  @override
  String get gorevKategoriDiger => 'Diğer';

  @override
  String gorevPlanlanan(Object zaman) {
    return 'Planlanan: $zaman';
  }

  @override
  String get gorevSanaAtanmis => 'Sana atanmış';

  @override
  String get gorevFotoZorunlu => 'Foto zorunlu';

  @override
  String get gorevTamamlandiZatenKayitli => 'Tamamlandı ✓ (zaten kayıtlıydı)';

  @override
  String get gorevTamamlandiBuOturumda => 'Tamamlandı ✓ (bu oturumda)';

  @override
  String get gorevIslemleriTooltip => 'Görev işlemleri';

  @override
  String get gorevTakipGorunumu => 'Takip görünümü';

  @override
  String get gorevTakipGorunumuAlt =>
      'Tamamlama saha personeli tarafından yapılır (güvenlik / tesis görevlisi). Bu ekran izleme içindir.';

  @override
  String get gorevGonderiliyor => 'Gönderiliyor...';

  @override
  String get gorevTamamla => 'Tamamla';

  @override
  String get gorevGuncellendi => 'Görev güncellendi ✓';

  @override
  String get gorevSilinsinMi => 'Görev silinsin mi?';

  @override
  String get gorevSilindi => 'Görev silindi ✓';

  @override
  String get gorevNfcAciklama =>
      'Bu görev NFC doğrulamalı: tamamlamadan önce görev noktasındaki etiketi okutun.';

  @override
  String get gorevAdim1Etiket => '1. Etiketi okutun';

  @override
  String gorevOkundu(Object uid) {
    return 'Okundu: $uid';
  }

  @override
  String get gorevEtiketBekleniyor => 'Etiket bekleniyor...';

  @override
  String get gorevYenidenOkut => 'Yeniden okut';

  @override
  String get gorevEtiketiOkut => 'Etiketi okut';

  @override
  String get gorevAdim2Foto => '2. Foto kanıtı';

  @override
  String get gorevAdim2FotoOpsiyonel => '2. Foto kanıtı (isteğe bağlı)';

  @override
  String get gorevYukleniyorNokta => 'Yükleniyor...';

  @override
  String get gorevYuklendi => 'Yüklendi ✓';

  @override
  String get gorevKamera => 'Kamera';

  @override
  String get gorevYenidenCek => 'Yeniden çek';

  @override
  String get gorevGaleridenSec => 'Galeriden seç';

  @override
  String get gorevTekrarYukle => 'Tekrar yükle';

  @override
  String get gorevKaldir => 'Kaldır';

  @override
  String get gorevAdim3Not => '3. Not (isteğe bağlı)';

  @override
  String get gorevNotIpucu => 'Örn. çöp konteynerleri boşaltıldı';

  @override
  String get gorevZatenKayitliydi =>
      'Bu tamamlama zaten kayıtlıydı (tekrar gönderim — çift kayıt oluşmadı).';

  @override
  String get gorevTamamlandiKayit => 'Görev tamamlandı — kayıt oluşturuldu.';

  @override
  String gorevZaman(Object zaman) {
    return 'Zaman: $zaman';
  }

  @override
  String get gorevFotoKanitiVar => 'foto kanıtı var';

  @override
  String get gorevNfcDogrulandi => 'NFC doğrulandı';

  @override
  String get gorevYeniTamamlamaBaslat => 'Yeni tamamlama başlat';

  @override
  String get gorevDuzenleBaslik => 'Görev düzenle';

  @override
  String get gorevKategoriSilinmis => 'Kategori (silinmiş)';

  @override
  String get gorevAtananListedeDegil => 'Atanan kullanıcı (listede değil)';

  @override
  String get gorevTipleriYukleniyor => 'Görev tipleri yükleniyor...';

  @override
  String get gorevTipi => 'Görev tipi';

  @override
  String get gorevTipiYokUyari =>
      'Henüz görev tipi tanımlamadınız. Üstteki \"Kategoriler\" ekranından kendi tiplerinizi ekleyebilirsiniz; şimdilik \"Diğer\" kullanılır.';

  @override
  String get gorevAdi => 'Görev adı';

  @override
  String get gorevAdiZorunlu => 'Görev adı zorunludur';

  @override
  String get gorevAciklamaOpsiyonel => 'Açıklama (opsiyonel)';

  @override
  String get gorevPersonelYukleniyor => 'Personel listesi yükleniyor...';

  @override
  String get gorevAtananPersonel => 'Atanan personel';

  @override
  String get gorevAtanmamisHavuz => '— atanmamış (havuz görevi) —';

  @override
  String gorevPersonelAlinamadi(Object hata) {
    return 'Personel listesi alınamadı: $hata';
  }

  @override
  String get gorevKontrolNoktasiOpsiyonel =>
      'Kontrol noktası (NFC) — opsiyonel';

  @override
  String get gorevKontrolNoktasiYardim =>
      'Bağlanırsa görev NFC okutularak tamamlanır';

  @override
  String get gorevNfcYok => '— NFC yok —';

  @override
  String get gorevPeriyotDakika => 'Periyot dakika (opsiyonel)';

  @override
  String get gorevPeriyotYardim =>
      'Periyodik görevler için; boş = tek seferlik';

  @override
  String get gorevPozitifSayi => 'Pozitif tam sayı girin';

  @override
  String get gorevFotoKanitiZorunlu => 'Foto kanıtı zorunlu';

  @override
  String get gorevFotoKanitiZorunluAlt =>
      'Tamamlama foto olmadan kabul edilmez';

  @override
  String get gorevPasifAciklama => 'Pasif görev listede görünmez';

  @override
  String get gorevKategorileriBaslik => 'Görev kategorileri';

  @override
  String get gorevKategoriYeni => 'Yeni kategori';

  @override
  String get gorevKategoriAdi => 'Kategori adı';

  @override
  String get gorevKategoriAdiIpucu => 'örn. Havuz bakımı';

  @override
  String gorevKategoriEklendi(Object ad) {
    return '\"$ad\" eklendi';
  }

  @override
  String gorevKategoriEklenemedi(Object hata) {
    return 'Eklenemedi: $hata';
  }

  @override
  String get gorevKategoriSilinsinMi => 'Kategori silinsin mi?';

  @override
  String gorevKategoriSilOnay(Object ad) {
    return '\"$ad\" pasifleştirilir; mevcut görevlerin geçmişi korunur, yeni görevlerde seçilemez.';
  }

  @override
  String gorevKategoriSilindi(Object ad) {
    return '\"$ad\" silindi';
  }

  @override
  String gorevKategoriSilinemedi(Object hata) {
    return 'Silinemedi: $hata';
  }

  @override
  String gorevKategoriListeAlinamadi(Object hata) {
    return 'Liste alınamadı: $hata';
  }

  @override
  String get gorevKategoriYokBos =>
      'Henüz kategori yok. Görev oluştururken seçilebilmesi için \"Yeni kategori\" ile ekleyin.';

  @override
  String get gorevOncelikDusuk => 'Düşük';

  @override
  String get gorevOncelikOrta => 'Orta';

  @override
  String get gorevOncelikYuksek => 'Yüksek';

  @override
  String get gorevOncelik => 'Öncelik';

  @override
  String get gorevTaleptenGeldi => 'Talepten geldi';

  @override
  String get gorevBagliTalep => 'Bağlı talep';

  @override
  String gorevDaireEtiket(Object daire) {
    return 'Daire $daire';
  }

  @override
  String get talepDurumAcik => 'Açık';

  @override
  String get talepDurumIsEmri => 'İş Emri';

  @override
  String get talepDurumCozuldu => 'Çözüldü';

  @override
  String get talepDurumReddedildi => 'Reddedildi';

  @override
  String get gorevEtiketOkunamadi => 'Etiket okunamadı.';

  @override
  String get gorevFotoOnlineGerekli =>
      'Fotoğraf yüklemek için internet bağlantısı gerekli (yükleme adresi kısa ömürlü). Bağlantı gelince \"Tekrar yükle\" ile deneyin.';

  @override
  String gorevFotoAlinamadi(Object hata) {
    return 'Fotoğraf alınamadı: $hata';
  }

  @override
  String get gorevFotoOnlineGerekliKisa =>
      'Fotoğraf yüklemek için internet bağlantısı gerekli.';

  @override
  String get gorevFotoZorunluUyari =>
      'Bu görev için FOTO KANITI ZORUNLU. Tamamlamadan önce fotoğraf çekip yükleyin.';

  @override
  String get gorevFotoHenuzYuklenmedi =>
      'Fotoğraf henüz yüklenmedi. Yüklemenin bitmesini bekleyin, \"Tekrar yükle\"yi deneyin veya fotoyu kaldırın.';

  @override
  String get gorevTamamlamaOfflineUyari =>
      'Tamamlama gönderilemedi — internet bağlantısı gerekli. Bağlantı gelince tekrar \"Tamamla\"ya basın; aynı kayıt çift oluşmaz (Idempotency-Key sabit). Fotoğraflı tamamlama offline desteklenmez (bilinen kısıt).';

  @override
  String get rolAdmin => 'Platform Admini';

  @override
  String get rolYonetici => 'Site Yöneticisi';

  @override
  String get rolGuvenlik => 'Güvenlik';

  @override
  String get rolTesisGorevlisi => 'Tesis Görevlisi';

  @override
  String get rolSakin => 'Site Sakini';

  @override
  String get rolBilinmeyen => 'Bilinmeyen rol';

  @override
  String get ortakOlustur => 'Oluştur';

  @override
  String get ortakGuncelle => 'Güncelle';

  @override
  String get ortakYenile => 'Yenile';

  @override
  String get devriyeGonderimKuyruguTooltip => 'Gönderim kuyruğu';

  @override
  String get sekmeGecmis => 'Geçmiş';

  @override
  String get devriyeYetkiYok =>
      'Bu ekrandaki veriler için yetkiniz yok. Tur takibi güvenlik (ve yönetici) rolüne açıktır.';

  @override
  String devriyeSonGuncelleme(Object saat) {
    return 'Son güncelleme: $saat (otomatik yenileme: 60 sn)';
  }

  @override
  String get devriyeTuru => 'Devriye turu';

  @override
  String devriyeBitisEtiket(Object saat) {
    return 'bitiş $saat';
  }

  @override
  String devriyePencere(Object baslangic, Object bitis) {
    return 'Pencere: $baslangic – $bitis';
  }

  @override
  String devriyeNoktaSayaci(Object okutulan, Object beklenen) {
    return '$okutulan/$beklenen nokta';
  }

  @override
  String get devriyeTumNoktalarOkutuldu =>
      'Tüm noktalar okutuldu — tur tamamlanıyor. ✓';

  @override
  String devriyeSunucudaOkutma(num n) {
    return 'Sunucuda $n okutma kayıtlı (diğer cihazların okutmaları dahil olabilir).';
  }

  @override
  String get devriyeNoktaOkutNfc => 'Nokta okut (NFC)';

  @override
  String get devriyeBugununDigerTurlari => 'Bugünün diğer turları';

  @override
  String get devriyeBugununTurlari => 'Bugünün turları';

  @override
  String get devriyeDurumTamamlandi => 'Tamamlandı';

  @override
  String get devriyeDurumKacirildi => 'Kaçırıldı';

  @override
  String get devriyeDurumSimdiAktif => 'Şimdi aktif';

  @override
  String get devriyeDurumYaklasan => 'Yaklaşan';

  @override
  String get devriyeDurumBitti => 'Bitti';

  @override
  String get devriyeDurumBekliyor => 'Bekliyor';

  @override
  String get devriyeDurumBilinmiyor => 'Bilinmiyor';

  @override
  String get devriyeDurumSuresiGecti => 'Süresi geçti';

  @override
  String get devriyeBugunTurYok => 'Bugün için devriye turu yok.';

  @override
  String get devriyeNoktaListesiYok =>
      'Bu planın nokta listesi alınamadı veya plana nokta atanmamış.';

  @override
  String get devriyeKontrolNoktalari => 'Kontrol noktaları';

  @override
  String get devriyeNoktaDurumAciklama =>
      'Nokta durumları sunucudandır; tüm görevlilerin okutmaları ✓ görünür. \"Gönderiliyor\" satırlar bu cihazın henüz gönderilmemiş okutmalarıdır.';

  @override
  String devriyeNoktaAdiYedek(Object kisaId) {
    return 'Nokta $kisaId';
  }

  @override
  String get devriyeOkutuldu => 'Okutuldu ✓';

  @override
  String devriyeOkutulduZamanli(Object saat) {
    return 'Okutuldu ✓ · $saat';
  }

  @override
  String get devriyeOkutulduGonderiliyor =>
      'Okutuldu ✓ — gönderiliyor (kuyrukta)';

  @override
  String get devriyePencereSuresiDoldu => 'Pencere süresi doldu.';

  @override
  String devriyeKalanSure(Object sure) {
    return 'Kalan süre: $sure';
  }

  @override
  String sureSaatDakika(Object saat, Object dakika) {
    return '$saat sa $dakika dk';
  }

  @override
  String sureDakikaSaniye(Object dakika, Object saniye) {
    return '$dakika dk $saniye sn';
  }

  @override
  String sureSaniye(Object saniye) {
    return '$saniye sn';
  }

  @override
  String get devriyeGecmisYetkiYok =>
      'Tur geçmişi için yetkiniz yok. Bu liste güvenlik ve yönetici rollerine açıktır.';

  @override
  String get devriyeGecmisBos => 'Henüz tur penceresi kaydı yok.';

  @override
  String get devriyeOzetToplam => 'Toplam';

  @override
  String get devriyePlanlariBaslik => 'Devriye Planları';

  @override
  String get devriyePlanEkle => 'Plan ekle';

  @override
  String get devriyePlanlarListelenemedi => 'Planlar listelenemedi.';

  @override
  String devriyePlanAralik(Object baslangic, Object bitis, Object dakika) {
    return '$baslangic–$bitis · her $dakika dk';
  }

  @override
  String get devriyePasif => 'Pasif';

  @override
  String get devriyePlanSilinsinMi => 'Plan silinsin mi?';

  @override
  String devriyePlanSilOnay(Object ad) {
    return '\"$ad\" devriye planı silinecek.';
  }

  @override
  String get devriyePlanSilindi => 'Plan silindi ✓';

  @override
  String get devriyePlanDuzenleBaslik => 'Devriye planı düzenle';

  @override
  String get devriyePlanYeniBaslik => 'Yeni devriye planı';

  @override
  String get devriyePlanAdi => 'Plan adı';

  @override
  String get devriyePlanAdiIpucu => 'örn. Gece devriyesi';

  @override
  String get devriyeAdZorunlu => 'Ad zorunludur';

  @override
  String devriyeBaslangicSaat(Object saat) {
    return 'Başlangıç $saat';
  }

  @override
  String devriyeBitisSaat(Object saat) {
    return 'Bitiş $saat';
  }

  @override
  String get devriyeTurSikligi => 'Tur sıklığı (dakika)';

  @override
  String get devriyeTurSikligiYardim => 'örn. 60 = saatte bir tur';

  @override
  String get devriyeTurSikligiPozitif => 'Tur sıklığı (dk) pozitif olmalı.';

  @override
  String get devriyeTumunuKaldir => 'Tümünü kaldır';

  @override
  String get devriyeTumunuSec => 'Tümünü seç';

  @override
  String get devriyeAktifNoktaYok =>
      'Aktif kontrol noktası yok. Önce \"Kontrol noktaları\"ndan ekleyin.';

  @override
  String devriyeUidEtiket(Object uid) {
    return 'UID: $uid';
  }

  @override
  String get devriyeKaydedilemedi => 'Kaydedilemedi. Tekrar deneyin.';

  @override
  String get devriyePlanYokBos =>
      'Henüz devriye planı yok.\nSağ alttan ekleyin (saatler + noktalar).';

  @override
  String get devriyeTakibiBaslik => 'Devriye takibi';

  @override
  String get sekmeBugun => 'Bugün';

  @override
  String get sekmeTaramaGunlugu => 'Tarama günlüğü';

  @override
  String get devriyeTakibiYetkiYok =>
      'Devriye takibi için yetkiniz yok. Bu ekran yönetici ve güvenlik rollerine açıktır.';

  @override
  String get devriyeBugunPencereYok =>
      'Bugün için planlanmış devriye penceresi yok.';

  @override
  String devriyeNoktaOkutuldu(Object okutulan, Object beklenen) {
    return '$okutulan/$beklenen nokta okutuldu';
  }

  @override
  String get devriyeTaramaGunluguAlinamadi => 'Tarama günlüğü alınamadı.';

  @override
  String get devriyeGunOkutmaYok => 'Bu gün için okutma yok.';

  @override
  String get devriyeImzali => 'imzalı ✓';

  @override
  String devriyeOkutmaBekliyor(num n) {
    return '$n okutma gönderim bekliyor';
  }

  @override
  String get ortakIptal => 'İptal';

  @override
  String get ortakNotOpsiyonel => 'Not (opsiyonel)';

  @override
  String get binaDuzenlemeBaslik => 'Bina Düzenleme';

  @override
  String get binaBlokTile => 'Blok';

  @override
  String get binaBlokAtanmamis => 'Blok atanmamış';

  @override
  String binaBlokEtiket(Object ad) {
    return 'Blok $ad';
  }

  @override
  String get binaSaltGoruntulemeAciklama =>
      'Bina yapısı (salt görüntüleme). Blok kutucuğuna dokunup kat ve daire yerleşimini görebilirsiniz.';

  @override
  String get binaDuzenlemeAciklama =>
      'Blok ekleyin, kutucuğa dokunup içine kat ve daire yerleştirin. Her daire bir bloğa bağlanır. Şikayet Haritası bu yapıyı yansıtır.';

  @override
  String binaDaireSayisi(num n) {
    return '$n daire';
  }

  @override
  String get binaKayitsiz => 'kayıtsız';

  @override
  String get binaBloksuzDairelerSalt =>
      'Bloğa atanmamış daireler (salt görüntüleme).';

  @override
  String binaBlokYerlesimSalt(Object ad) {
    return 'Blok $ad — kat ve daire yerleşimi (salt görüntüleme).';
  }

  @override
  String get binaBloksuzUyari =>
      'Bu daireler bir bloğa atanmamış (eski kayıtlar). Görüntülenir, düzenlenip silinebilir; yeni daire için bir blok seçin/oluşturun.';

  @override
  String binaBlokYerlesimYardim(Object ad) {
    return 'Blok $ad — kat ekleyip her katın \"+\" düğmesiyle daire ekleyin. Aynı kattakiler yan yana dizilir.';
  }

  @override
  String get binaKatEkle => 'Kat ekle';

  @override
  String get binaTopluDaireEkle => 'Toplu daire ekle';

  @override
  String get binaBloktaDaireYok => 'Bu blokta henüz daire yok.';

  @override
  String get binaKatYokBos =>
      'Henüz kat yok. \"Kat ekle\" ile başlayın, sonra kattaki \"+\" ile daire ekleyin.';

  @override
  String get binaKatYok => 'Kat yok';

  @override
  String binaKatEtiket(Object kat) {
    return 'Kat $kat';
  }

  @override
  String binaBlokDuzenleBaslik(Object ad) {
    return 'Blok $ad — düzenle';
  }

  @override
  String get binaBloguSil => 'Bloğu sil';

  @override
  String binaBloguSilAlt(num n) {
    return '$n daire ile birlikte silinir (onay gerekir)';
  }

  @override
  String binaBlokSilinsinMi(Object ad) {
    return 'Blok $ad silinsin mi?';
  }

  @override
  String binaBlokVeDaireSilindi(Object ad, Object n) {
    return 'Blok $ad ve $n daire silindi.';
  }

  @override
  String binaBlokSilindi(Object ad) {
    return 'Blok $ad silindi.';
  }

  @override
  String binaBlokSilinemedi(Object hata) {
    return 'Blok silinemedi: $hata';
  }

  @override
  String get binaBlokSilinemediGenel =>
      'Blok silinemedi. Lütfen tekrar deneyin.';

  @override
  String binaKaliciSilmeUyari(Object n) {
    return 'Bu blok ve içindeki $n daire; aidat, ziyaretçi, kargo, rezervasyon ve şikayet kayıtlarıyla birlikte KALICI olarak silinecek. Bu işlem geri alınamaz.';
  }

  @override
  String get binaOnayIcinBlokAdi => 'Onaylamak için blok adını yazın';

  @override
  String binaSilNDaire(Object n) {
    return 'Sil ($n daire)';
  }

  @override
  String get binaBlokEtiketiGerekli => 'Blok etiketi gerekli (örn. A, B1).';

  @override
  String get binaBlokEtiketiZatenVar => 'Bu blok etiketi zaten kayıtlı.';

  @override
  String get binaBlokDuzenle => 'Blok düzenle';

  @override
  String get binaYeniBlok => 'Yeni blok';

  @override
  String get binaBlokEtiketi => 'Blok etiketi';

  @override
  String get binaBlokEtiketiYardim =>
      'Kısa alfanumerik (örn. A, B1) — tire yok';

  @override
  String get binaDaireNoGerekli => 'Daire no gerekli (örn. A-12, 12).';

  @override
  String get binaKatSiraTamSayi => 'Kat ve sıra tam sayı olmalı.';

  @override
  String get binaDaireNoZatenVar => 'Bu daire no zaten kayıtlı.';

  @override
  String binaDaireDuzenleBaslik(Object no) {
    return 'Daire $no — düzenle';
  }

  @override
  String binaYeniDaire(Object blok) {
    return 'Yeni daire · $blok';
  }

  @override
  String get binaDaireNo => 'Daire no';

  @override
  String get binaDaireNoYardim => 'Alfanumerik + tire (örn. A-12, B3, 12)';

  @override
  String get binaSira => 'Sıra';

  @override
  String get binaSiraYardim => 'Kattaki konum';

  @override
  String binaEnFazla500(Object n) {
    return 'En fazla 500 daire (şu an $n).';
  }

  @override
  String binaTopluOnizleme(
    Object bas,
    Object bitis,
    Object toplam,
    Object kat,
    Object adet,
  ) {
    return '$bas … $bitis  ($toplam daire, $kat kat × $adet)';
  }

  @override
  String get binaTopluAlanlarGerekli =>
      'Kat sayısı, kat başına daire ve başlangıç no gerekli.';

  @override
  String get binaTekSeferde500 => 'Tek seferde en fazla 500 daire.';

  @override
  String binaAtlananEk(Object n) {
    return ' ($n zaten vardı, atlandı)';
  }

  @override
  String binaDaireEklendi(Object n, Object ek) {
    return '$n daire eklendi ✓$ek';
  }

  @override
  String get binaEklenemedi => 'Eklenemedi. Tekrar deneyin.';

  @override
  String binaTopluBaslik(Object blok) {
    return 'Toplu daire ekle — Blok $blok';
  }

  @override
  String get binaTopluBaslikBloksuz => 'Toplu daire ekle — Bloksuz';

  @override
  String get binaTopluAciklama =>
      'Numaralar başlangıçtan itibaren ardışık, kat kat dolar. Var olanlar atlanır.';

  @override
  String get binaKatSayisi => 'Kat sayısı';

  @override
  String get binaKatBasinaDaire => 'Kat başına daire';

  @override
  String get binaBaslangicNo => 'Başlangıç no';

  @override
  String get binaBaslangicNoIpucu => 'örn. 101';

  @override
  String get binaDaireleriOlustur => 'Daireleri oluştur';

  @override
  String get binaSilinemedi => 'Silinemedi. Lütfen tekrar deneyin.';

  @override
  String get binaKaydedilemedi => 'Kaydedilemedi. Lütfen tekrar deneyin.';

  @override
  String get semaDaireYok => 'Henüz daire yok.';

  @override
  String get semaYogunluk => 'Yoğunluk:';

  @override
  String get semaYerlesimAciklama =>
      'Bina yerleşimi. Şikayet yoğunluğu yalnızca yönetime gösterilir.';

  @override
  String get semaYerlesimGirilmemis => 'Haritada yerleşimi girilmemiş';

  @override
  String semaDaireEtiket(Object no) {
    return 'Daire $no';
  }

  @override
  String semaAcikSikayet(num n) {
    return '$n açık şikayet';
  }

  @override
  String get semaBuDaireSikayetlerim => 'Bu daire için şikayetleriniz';

  @override
  String get semaYogunlukYonetim =>
      'Şikayet yoğunluğu yalnızca yönetime gösterilir.';

  @override
  String get semaBuDaireyiSikayetEt => 'Bu daireyi şikayet et';

  @override
  String get semaSikayetIletildi => 'Şikayetiniz iletildi.';

  @override
  String get semaSikayetlerYuklenemedi => 'Şikayetler yüklenemedi.';

  @override
  String get semaAcikSikayetYok => 'Bu daire için açık şikayet yok.';

  @override
  String get semaSikayetlerimYuklenemedi => 'Şikayetleriniz yüklenemedi.';

  @override
  String get semaSikayetimYok => 'Bu daireye şikayetiniz yok.';

  @override
  String get semaYonetimeIletildi => 'Yönetime iletildi';

  @override
  String get semaKapatildi => 'Kapatıldı';

  @override
  String get semaHaftalikSinir =>
      'Bu daire için bu konuda haftada en fazla 1 şikayet açabilirsiniz.';

  @override
  String get semaKendiBlok =>
      'Yalnızca kendi bloğunuzdaki daireleri şikayet edebilirsiniz.';

  @override
  String get semaGonderilemedi => 'Gönderilemedi. Lütfen tekrar deneyin.';

  @override
  String semaSikayetEtBaslik(Object no) {
    return 'Daire $no — şikayet et';
  }

  @override
  String get semaSikayetAnonimNot =>
      'Şikayetiniz yönetime iletilir; komşularınıza gösterilmez.';

  @override
  String get semaSikayetiGonder => 'Şikayeti gönder';

  @override
  String get kategoriGurultu => 'Gürültü';

  @override
  String get kategoriKapiOnuAyakkabi => 'Kapı önü / ayakkabı';

  @override
  String get kategoriZararVerme => 'Zarar verme';

  @override
  String talepSekmeAcik(Object n) {
    return 'Açık ($n)';
  }

  @override
  String talepSekmeIsEmri(Object n) {
    return 'İş Emri ($n)';
  }

  @override
  String talepSekmeCozulen(Object n) {
    return 'Çözülen ($n)';
  }

  @override
  String talepSekmeReddedilen(Object n) {
    return 'Reddedilen ($n)';
  }

  @override
  String get talepYeni => 'Yeni talep';

  @override
  String get talepAcikYokSakin =>
      'Açık talebiniz yok. \"Yeni talep\" ile talep/arızanızı iletebilirsiniz.';

  @override
  String get talepAcikYok => 'Açık talep yok.';

  @override
  String get talepIsEmriYok => 'İş emrine dönüşen talep yok.';

  @override
  String get talepCozulenYok => 'Henüz çözülen talep yok.';

  @override
  String get talepReddedilenYok => 'Reddedilen talep yok.';

  @override
  String get talepIletildi => 'Talebiniz iletildi ✓';

  @override
  String get talepDurumGecmisi => 'Durum geçmişi';

  @override
  String get talepGorselYuklenemedi => 'Görsel yüklenemedi';

  @override
  String get talepIsEmriAtandi => 'Atandı';

  @override
  String get talepIsEmriTamamlandi => 'Tamamlandı';

  @override
  String get talepIsEmriDurumBilinmiyor => 'Durum bilinmiyor';

  @override
  String get talepIsEmri => 'İş emri';

  @override
  String get talepYeniBaslik => 'Yeni talep / arıza';

  @override
  String get talepBaslikAlan => 'Başlık';

  @override
  String get talepBaslikZorunlu => 'Başlık zorunludur';

  @override
  String get talepAciklamaAlan => 'Açıklama';

  @override
  String get talepAciklamaZorunlu => 'Açıklama zorunludur';

  @override
  String get talepGonder => 'Gönder';

  @override
  String get talepKategoriOpsiyonel => 'Kategori (opsiyonel)';

  @override
  String get talepKategoriYok =>
      'Tanımlı kategori yok; talep \"Diğer\" olarak açılır.';

  @override
  String get talepGorseller => 'Görseller (opsiyonel, en fazla 3)';

  @override
  String get talepYoneticiIslemleri => 'Yönetici işlemleri';

  @override
  String get talepIsEmrineDonusturuldu => 'Talep iş emrine dönüştürüldü ✓';

  @override
  String get talepIsEmrineDonusturBuyuk => 'İş Emrine Dönüştür';

  @override
  String get talepCozuldu => 'Talep çözüldü ✓';

  @override
  String get talepCoz => 'Çöz';

  @override
  String get talepReddedildiBildirim => 'Talep reddedildi ✓';

  @override
  String get talepReddet => 'Reddet';

  @override
  String get talepReddediliyor => 'Reddediliyor...';

  @override
  String get talepPersonelAlinamadiKisa => 'Personel listesi alınamadı.';

  @override
  String get talepIsEmrineDonustur => 'İş emrine dönüştür';

  @override
  String get talepAtanabilirPersonelYok =>
      'Atanabilir aktif saha personeli yok. Dönüştürmek için önce security/tesis görevlisi ekleyin.';

  @override
  String get talepDonusturuluyor => 'Dönüştürülüyor...';

  @override
  String get talepDonustur => 'Dönüştür';

  @override
  String get talepReddetBaslik => 'Talebi reddet';

  @override
  String get talepRetSebebiNot =>
      'Ret sebebi talebi açan kişiye durum geçmişinde görünür.';

  @override
  String get talepRetSebebi => 'Ret sebebi';

  @override
  String get talepCozBaslik => 'Talebi çöz';

  @override
  String get talepCozNot =>
      'Talep iş emri açmadan doğrudan çözüldü olarak işaretlenir.';

  @override
  String get talepCozumNotu => 'Çözüm notu (opsiyonel)';

  @override
  String get talepKategorilerYuklenemedi => 'Kategoriler yüklenemedi.';

  @override
  String get talepFotoYuklenemedi => 'Fotoğraf yüklenemedi.';

  @override
  String get binaKat => 'Kat';

  @override
  String get binaKatYardim => '0 = zemin';

  @override
  String get binaBloksuz => 'Bloksuz';

  @override
  String get talepAcanSakin => 'Sakin';

  @override
  String rezSekmeRezervasyonlar(Object n) {
    return 'Rezervasyonlar ($n)';
  }

  @override
  String rezSekmeAlanlar(Object n) {
    return 'Alanlar ($n)';
  }

  @override
  String get rezYokSakin =>
      'Rezervasyonunuz yok. \"Alanlar\" sekmesinden bir alan seçip boş bir slotu ayırtın.';

  @override
  String get rezYok => 'Rezervasyon yok.';

  @override
  String get rezYeniAlan => 'Yeni alan';

  @override
  String get rezAlanEklendi => 'Ortak alan eklendi ✓';

  @override
  String get rezAlanGuncellendi => 'Alan güncellendi ✓';

  @override
  String get rezOrtakAlan => 'Ortak alan';

  @override
  String rezSatirOzet(
    Object tarih,
    Object baslangic,
    Object bitis,
    Object kisi,
  ) {
    return '$tarih · $baslangic-$bitis · $kisi kişi';
  }

  @override
  String get rezIptalEdildi => 'İptal edildi';

  @override
  String get rezIptalEdilsinMi => 'Rezervasyon iptal edilsin mi?';

  @override
  String get rezIptalUyari =>
      'Slot yeniden boşa çıkar; bu işlem geri alınamaz.';

  @override
  String get rezEvetIptalEt => 'Evet, iptal et';

  @override
  String get rezIptalEdildiBildirim => 'Rezervasyon iptal edildi';

  @override
  String get rezIptalGonderilemedi => 'İptal gönderilemedi. Tekrar deneyin.';

  @override
  String get rezIptalEt => 'İptal et';

  @override
  String rezDetayTarih(Object tarih, Object baslangic, Object bitis) {
    return 'Tarih: $tarih · $baslangic-$bitis';
  }

  @override
  String rezDetayKisi(Object n) {
    return 'Kişi sayısı: $n';
  }

  @override
  String rezDetayRezerve(Object zaman) {
    return 'Rezerve: $zaman';
  }

  @override
  String rezDetayNot(Object not) {
    return 'Not: $not';
  }

  @override
  String get rezAlanYokYonetim =>
      'Henüz ortak alan yok. \"Yeni alan\" ile ekleyin.';

  @override
  String get rezAlanYokGoruntuleme => 'Görüntülenecek ortak alan yok.';

  @override
  String get rezAlanYokSakin => 'Rezerve edilebilir alan yok.';

  @override
  String rezMusait(Object ozet) {
    return 'Müsait: $ozet';
  }

  @override
  String rezMusaitOzeti(Object acilis, Object kapanis, Object dakika) {
    return '$acilis–$kapanis · $dakika dk slot';
  }

  @override
  String get rezAcikDuzenle => 'Açık · düzenlemek için dokun';

  @override
  String get rezKapaliDuzenle => 'Kapalı · düzenlemek için dokun';

  @override
  String rezMusaitSlotlariGor(Object ozet) {
    return 'Müsait: $ozet · dokunup slotları gör';
  }

  @override
  String get rezPasifAlan => 'Pasif (rezerve edilemez)';

  @override
  String get rezKapanisSonra => 'Kapanış saati açılıştan sonra olmalı.';

  @override
  String get rezAlanEklenemedi => 'Alan eklenemedi. Tekrar deneyin.';

  @override
  String get rezAlanDuzenle => 'Alanı düzenle';

  @override
  String get rezYeniOrtakAlan => 'Yeni ortak alan';

  @override
  String get rezAlanAdi => 'Alan adı * (örn. Havuz)';

  @override
  String get rezAlanAdiGerekli => 'Alan adı gerekli';

  @override
  String get rezMusaitlikHerGun => 'Müsaitlik (her gün)';

  @override
  String rezAcilis(Object saat) {
    return 'Açılış: $saat';
  }

  @override
  String rezKapanis(Object saat) {
    return 'Kapanış: $saat';
  }

  @override
  String get rezSlotUzunlugu => 'Slot uzunluğu';

  @override
  String rezSlotDakika(Object n) {
    return '$n dakika';
  }

  @override
  String get rezAlaniEkle => 'Alanı ekle';

  @override
  String get rezSlotlarYuklenemedi => 'Slotlar yüklenemedi. Tekrar deneyin.';

  @override
  String get rezOnaylandi => 'Rezervasyonunuz onaylandı ✓';

  @override
  String rezTarihEtiket(Object tarih) {
    return 'Tarih: $tarih';
  }

  @override
  String get rezSlotKurali =>
      'Slot yalnızca başlangıcına 24 saatten az kala açılır; günde en fazla bir rezervasyon yapabilirsiniz.';

  @override
  String get rezSlotYok => 'Bu alan için tanımlı slot yok.';

  @override
  String get rezBenimAktif => 'Rezervasyonum (aktif)';

  @override
  String get rezBenimGecti => 'Rezervasyonum (geçti)';

  @override
  String get rezDoluBaskasi => 'Dolu (başkası)';

  @override
  String get rezSizinGecti => 'Rezervasyonunuz (geçti)';

  @override
  String rezKisiEki(Object n) {
    return ' · $n kişi';
  }

  @override
  String rezDoluDaire(Object daire, Object kisi) {
    return 'Dolu · Daire $daire$kisi';
  }

  @override
  String get rezBos => 'Boş';

  @override
  String get rezDolu => 'Dolu';

  @override
  String rezSlotAralik(Object baslangic, Object bitis) {
    return '$baslangic – $bitis';
  }

  @override
  String get rezSec => 'Seç';

  @override
  String get rezGonderilemedi => 'Gönderilemedi. Tekrar deneyin.';

  @override
  String rezEtBaslik(Object ad) {
    return '$ad — rezerve et';
  }

  @override
  String get rezKisiSayisiEtiket => 'Kişi sayısı:';

  @override
  String get rezEt => 'Rezerve et';

  @override
  String get rezDurumOnayli => 'Onaylı';

  @override
  String get rezSebepDolu => 'dolu';

  @override
  String get rezSebepGecti => 'geçti';

  @override
  String get rezSebepCokErken => '24s içinde açılır';

  @override
  String get rezSebepGunluk => 'günlük hakkınız dolu';

  @override
  String etkSekmeYaklasan(Object n) {
    return 'Yaklaşan ($n)';
  }

  @override
  String etkSekmeGecmis(Object n) {
    return 'Geçmiş ($n)';
  }

  @override
  String get etkYeni => 'Yeni etkinlik';

  @override
  String get etkYaklasanYokYonetim =>
      'Yaklaşan etkinlik yok. \"Yeni etkinlik\" ile duyurun.';

  @override
  String get etkYaklasanYok => 'Yaklaşan etkinlik yok.';

  @override
  String get etkGecmisYok => 'Geçmiş etkinlik yok.';

  @override
  String get etkDuyuruldu => 'Etkinlik duyuruldu — sakinlere bildirildi ✓';

  @override
  String get etkGuncellendi => 'Etkinlik güncellendi ✓';

  @override
  String etkKatiliyorSayisi(num n) {
    return '$n katılıyor';
  }

  @override
  String etkKatilmiyorSayisi(num n) {
    return '$n katılmıyor';
  }

  @override
  String etkKatiliminiz(Object durum) {
    return 'Katılımınız: $durum';
  }

  @override
  String etkBeyanKaydedildi(Object durum) {
    return 'Beyanınız kaydedildi: $durum ✓';
  }

  @override
  String get etkBeyanGonderilemedi => 'Beyan gönderilemedi. Tekrar deneyin.';

  @override
  String get etkKatiliyorum => 'Katılıyorum';

  @override
  String get etkKatilmiyorum => 'Katılmıyorum';

  @override
  String etkZaman(Object aralik) {
    return 'Zaman: $aralik';
  }

  @override
  String etkYer(Object konum) {
    return 'Yer: $konum';
  }

  @override
  String etkDuyuran(Object ad) {
    return 'Duyuran: $ad';
  }

  @override
  String get etkSilinsinMi => 'Etkinlik silinsin mi?';

  @override
  String etkSilOnay(Object baslik) {
    return '\"$baslik\" ve tüm katılım beyanları silinecek.';
  }

  @override
  String get etkSilindi => 'Etkinlik silindi ✓';

  @override
  String get etkBitisSonra => 'Bitiş, başlangıçtan sonra olmalı';

  @override
  String get etkKaydedilemedi => 'Kaydedilemedi. Tekrar deneyin.';

  @override
  String get etkDuzenleBaslik => 'Etkinliği düzenle';

  @override
  String get etkBaslikAlan => 'Başlık * (örn. Maç izleme akşamı)';

  @override
  String get etkBaslikGerekli => 'Başlık gerekli';

  @override
  String get etkAciklamaAlan => 'Açıklama *';

  @override
  String get etkAciklamaGerekli => 'Açıklama gerekli';

  @override
  String etkZamanSecim(Object zaman) {
    return 'Zaman: $zaman';
  }

  @override
  String get etkBitisEkle => 'Bitiş ekle (opsiyonel)';

  @override
  String etkBitis(Object zaman) {
    return 'Bitiş: $zaman';
  }

  @override
  String get etkBitisiKaldir => 'Bitişi kaldır';

  @override
  String get etkYerAlan => 'Yer (opsiyonel)';

  @override
  String get etkGorselAlan => 'Görsel (opsiyonel)';

  @override
  String get etkDuyurVeBildir => 'Duyur ve sakinlere bildir';

  @override
  String get izinBaslik => 'Görüntüleme izni';

  @override
  String get izinTumDairelere => 'Tüm dairelere izin iste';

  @override
  String get izinYeniIstek => 'Yeni istek';

  @override
  String get izinIstekYokYonetim =>
      'Henüz izin isteğiniz yok. \"Yeni istek\" ile bir daire, üstteki \"Tüm daireler\" ile tümü için izin isteyin.';

  @override
  String get izinIstekYokSakin => 'Dairenize gelen görüntüleme isteği yok.';

  @override
  String get izinTumDaireUyari =>
      'Sakini olan tüm daireler için görüntüleme izni isteği gönderilecek. Her daire kendi sakininin onayına bağlıdır — yalnızca onaylayan dairelerin kayıtlarını görebilirsiniz.';

  @override
  String izinAtlandiEki(Object n) {
    return ' ($n zaten açık)';
  }

  @override
  String izinTopluGonderildi(Object n, Object atlandi) {
    return '$n daire için istek gönderildi$atlandi — sakin onayları bekleniyor';
  }

  @override
  String izinGonderilemedi(Object hata) {
    return 'Gönderilemedi: $hata';
  }

  @override
  String get izinIsteBaslik => 'Görüntüleme izni iste';

  @override
  String get izinDaireNo => 'Daire no (örn. A-12)';

  @override
  String get izinIstekGonder => 'İstek gönder';

  @override
  String get izinIstekGonderildi =>
      'İstek gönderildi — sakinin onayı bekleniyor';

  @override
  String izinDaireIstegi(Object daire) {
    return 'Daire görüntüleme isteği$daire';
  }

  @override
  String izinIsteyen(Object ad) {
    return 'İsteyen: $ad';
  }

  @override
  String get izinKullanildiUyari =>
      'İzin kullanıldı (tek seferlik). Tekrar görmek için yeni istek açın.';

  @override
  String izinGoruntulenebilirDaireler(Object n) {
    return 'Görüntülenebilir daireler ($n)';
  }

  @override
  String get izinKullanildi => 'Kullanıldı';

  @override
  String get izinOnayli => 'Onaylı';

  @override
  String get izinVerildi => 'İzin verildi';

  @override
  String get izinOnayla => 'Onayla';

  @override
  String get izinKargolar => 'Kargolar';

  @override
  String izinKayitBaslik(Object baslik, Object daire) {
    return '$baslik$daire';
  }

  @override
  String izinDaireEki(Object daire) {
    return ' — $daire';
  }

  @override
  String get izinSuresiDoldu =>
      'İzin kullanıldı veya süresi doldu (tek seferlik). Tekrar görüntülemek için yeni bir izin isteği açın.';

  @override
  String get izinTekSeferlikUyari =>
      'Tek seferlik izinle görüntüleniyor — yenilemede erişim kapanır.';

  @override
  String get izinKayitYok => 'Bu dairede kayıt yok.';

  @override
  String izinHedef(Object ad) {
    return 'Hedef: $ad';
  }

  @override
  String izinKaydeden(Object ad) {
    return 'Kaydeden: $ad';
  }

  @override
  String izinDurumEtiket(Object durum) {
    return 'Durum: $durum';
  }

  @override
  String get izinDurumOnaylandi => 'Onaylandı';

  @override
  String get kargoDurumTeslimAlindi => 'Teslim alındı';

  @override
  String get rezSizin => 'Rezervasyonunuz';

  @override
  String get butBaslik => 'Bütçe';

  @override
  String get butSekmeOzet => 'Özet';

  @override
  String get butSekmeHareketler => 'Hareketler';

  @override
  String get butSekmeKategoriler => 'Kategoriler';

  @override
  String get butTumZamanlar => 'Tüm zamanlar';

  @override
  String get butDonem => 'Dönem';

  @override
  String get butGelir => 'Gelir';

  @override
  String get butGider => 'Gider';

  @override
  String get butKasa => 'Kasa';

  @override
  String get butKategoriKirilimi => 'Kategori kırılımı';

  @override
  String get butYeniHareket => 'Yeni hareket';

  @override
  String get butHareketYok => 'Henüz hareket yok.';

  @override
  String get butKategori => 'Kategori';

  @override
  String get butOtomatik => 'Otomatik';

  @override
  String get butKategoriSecin => 'Kategori seçin';

  @override
  String get butTutar => 'Tutar (TL)';

  @override
  String get butTutarIpucu => 'örn. 1.250,50';

  @override
  String get butTutarGecersiz => 'Geçerli bir tutar girin (örn. 1.250,50)';

  @override
  String butTarih(Object tarih) {
    return 'Tarih: $tarih';
  }

  @override
  String get butYeniKategori => 'Yeni kategori';

  @override
  String get butKategoriYok => 'Henüz kategori yok.';

  @override
  String get butKategoriAdi => 'Kategori adı';

  @override
  String get butKategoriAdiIpucu => 'örn. Bahçe bakımı';

  @override
  String get butAdZorunlu => 'Ad zorunludur';

  @override
  String butKategoriTip(Object ad, Object tip) {
    return '$ad ($tip)';
  }

  @override
  String get butPasifEki => ' · pasif (yeni kayıt kapalı)';

  @override
  String get butBeklenmeyenKisa =>
      'Beklenmeyen bir hata oluştu. Tekrar deneyin.';

  @override
  String get butFinansalOzet => 'Finansal özet';

  @override
  String get butAidatTahsilati => 'Aidat tahsilatı';

  @override
  String get butEnYuksekGiderler => 'En yüksek giderler';

  @override
  String butTahsilatYuzde(Object yuzde) {
    return 'Tahsilat %$yuzde';
  }

  @override
  String get butTahakkukYok => 'Bu dönem için tahakkuk kaydı yok.';

  @override
  String get butSiteBaslik => 'Site Bütçesi';

  @override
  String get butKategoriToplamlari => 'Kategori toplamları';

  @override
  String get butSeffaflikNotu =>
      'Bu ekran site yönetiminin gelir ve giderlerini şeffaflık amacıyla özet olarak gösterir. Kişi ve daire bazlı detaylar görüntülenmez; sorularınız için yönetiminize başvurun.';

  @override
  String get demBaslik => 'Demirbaş';

  @override
  String get demEtiketOkut => 'Etiket okut';

  @override
  String get demBaskaEtiketOkut => 'Başka etiket okut';

  @override
  String demUzerimdekiler(Object ek) {
    return 'Üzerimdekiler$ek';
  }

  @override
  String get demNfcAciklama =>
      'Demirbaşı alırken veya bırakırken üzerindeki NFC etiketini okutun. Uygulama demirbaşı tanır ve kimde olduğunu gösterir.';

  @override
  String get demTaniniyor => 'Demirbaş tanınıyor...';

  @override
  String get demKimsedeDegil => 'Kimsede değil — alınabilir.';

  @override
  String demSende(Object sure) {
    return 'SENDE — $sure üzerinde.';
  }

  @override
  String demBaskasinda(Object ad, Object sure) {
    return 'Başkasında: $ad — $sure üzerinde.';
  }

  @override
  String get demBaskasininUzerinde => 'Başkasının üzerinde görünüyor.';

  @override
  String get demBakimda => 'Bakımda — şu an zimmetlenemez.';

  @override
  String get demZorlaDevralmaYok =>
      'Zorla devralma yok — demirbaşı şu anki kullanıcısı bırakmalı.';

  @override
  String get demZimmetineAl => 'Zimmetine al';

  @override
  String get demBirak => 'Bırak / iade et';

  @override
  String get demBirakKisa => 'Bırak';

  @override
  String get demSonHareketler => 'Son hareketler';

  @override
  String demAldi(Object ad, Object zaman) {
    return '$ad aldı — $zaman (hala üzerinde)';
  }

  @override
  String get demListeYetkiYok => 'Demirbaş listesi için yetkiniz yok.';

  @override
  String get demUzerindeYok => 'Şu an üzerinde demirbaş görünmüyor.';

  @override
  String demAldin(Object zaman, Object sure) {
    return 'Aldın: $zaman ($sure)';
  }

  @override
  String get demSureBelirsiz => 'bir süredir';

  @override
  String get demSureAzOnce => 'az önce alındı, o zamandan beri';

  @override
  String demSureDakika(num n) {
    return '$n dakikadır';
  }

  @override
  String demSureSaat(num n) {
    return '$n saattir';
  }

  @override
  String demSureGun(num n) {
    return '$n gündür';
  }

  @override
  String get demOfflineUyari =>
      'İnternet bağlantısı gerekli. Zimmet kimde-olduğu ANLIK bir kayıttır; offline işlem yapılmaz (kuyruklamak yanıltıcı olurdu).';

  @override
  String demEtiketEslesmiyor(Object uid) {
    return 'Bu etiket ($uid) kayıtlı bir demirbaşla eşleşmiyor. Etiket panelden bir demirbaşa tanımlanmalı.';
  }

  @override
  String get demZatenZimmetinde =>
      'Zaten zimmetindeydi ✓ (tekrar gönderim — çift kayıt yok)';

  @override
  String get demZimmetineAlindi => 'Zimmetine alındı ✓';

  @override
  String get demBirakildi => 'Bırakıldı ✓ — zimmet kapatıldı.';

  @override
  String demIslemYapilamadi(Object hata) {
    return 'İşlem yapılamadı: $hata Durum güncellendi — karta tekrar bakın.';
  }

  @override
  String demHataSatiri(Object ad, Object hata) {
    return '$ad: $hata';
  }

  @override
  String get karBaslik => 'Kargo';

  @override
  String karSekmeBekleyen(Object n) {
    return 'Bekleyen ($n)';
  }

  @override
  String karSekmeTeslim(Object n) {
    return 'Teslim alınan ($n)';
  }

  @override
  String get karYeni => 'Yeni kargo';

  @override
  String get karBekleyenYokSakin => 'Teslim bekleyen kargonuz yok.';

  @override
  String get karBekleyenYok => 'Teslim bekleyen kargo yok.';

  @override
  String get karTeslimYok => 'Henüz teslim alınan kargo kaydı yok.';

  @override
  String get karKaydedildi =>
      'Kargo kaydedildi — daire sakinlerine bildirildi ✓';

  @override
  String karDaireTarih(Object daire, Object zaman) {
    return 'Daire: $daire · $zaman';
  }

  @override
  String karDaire(Object daire) {
    return 'Daire: $daire';
  }

  @override
  String karKayit(Object zaman) {
    return 'Kayıt: $zaman';
  }

  @override
  String karNot(Object not) {
    return 'Not: $not';
  }

  @override
  String get karTeslimAlindiBildirim => 'Kargo teslim alındı ✓';

  @override
  String get karIsaretlenemedi => 'İşaretlenemedi. Tekrar deneyin.';

  @override
  String get karTeslimAldim => 'Teslim aldım';

  @override
  String get karGonderilemedi => 'Kayıt gönderilemedi. Tekrar deneyin.';

  @override
  String get karDaireNo => 'Daire no * (örn. A-12)';

  @override
  String get karDaireNoGerekli => 'Daire no gerekli';

  @override
  String get karFirma => 'Kargo firması *';

  @override
  String get karFirmaGerekli => 'Kargo firması gerekli';

  @override
  String get karPaketFotografi => 'Paket fotoğrafı (opsiyonel)';

  @override
  String get karKaydetVeBildir => 'Kaydet ve sakinlere bildir';

  @override
  String get ortakTekrarDene => 'Tekrar dene';

  @override
  String get butTahakkuk => 'Tahakkuk';

  @override
  String get butTahsilat => 'Tahsilat';

  @override
  String get butGeciken => 'Geciken';

  @override
  String demAldiBirakti(Object ad, Object alma, Object birakma) {
    return '$ad · $alma → $birakma';
  }

  @override
  String karAdEki(Object ad) {
    return ' — $ad';
  }

  @override
  String karZamanEki(Object zaman) {
    return ' · $zaman';
  }

  @override
  String get kuralBaslik => 'Site Kuralları';

  @override
  String get kuralYeni => 'Yeni kural';

  @override
  String get kuralAramaIpucu => 'Başlıkta ara (örn. havuz)';

  @override
  String get kuralEklendi => 'Kural eklendi ✓';

  @override
  String get kuralGuncellendi => 'Kural güncellendi ✓';

  @override
  String get kuralAramaBos => 'Aramayla eşleşen kural yok.';

  @override
  String get kuralYokYonetim => 'Henüz kural yok. \"Yeni kural\" ile ekleyin.';

  @override
  String get kuralYokSakin => 'Henüz kural yayınlanmamış.';

  @override
  String get kuralSilOnayBaslik => 'Kural silinsin mi?';

  @override
  String kuralSilOnayGovde(Object baslik) {
    return '\"$baslik\" kalıcı olarak silinecek.';
  }

  @override
  String get kuralSilindi => 'Kural silindi ✓';

  @override
  String get kuralDuzenleBaslik => 'Kuralı düzenle';

  @override
  String get kuralBaslikAlan => 'Başlık * (örn. Havuz Saatleri)';

  @override
  String get kuralBaslikGerekli => 'Başlık gerekli';

  @override
  String get kuralMetni => 'Kural metni *';

  @override
  String get kuralMetniGerekli => 'Kural metni gerekli';

  @override
  String get kuralSira => 'Sıra (küçük önce)';

  @override
  String get kuralSiraGecersiz => 'Sıra 0 veya pozitif tam sayı olmalı';

  @override
  String get kuralMevcutGorsel => 'Mevcut görsel korunuyor';

  @override
  String get kuralEkleButon => 'Kuralı ekle';

  @override
  String get ortakFotoOnlineTekrarDene =>
      'Fotoğraf yüklemek için internet bağlantısı gerekli. Bağlantı gelince tekrar deneyin.';

  @override
  String get ortakFotoBekleyinVeyaKaldir =>
      'Fotoğraf henüz yüklenmedi. Yüklemenin bitmesini bekleyin veya fotoyu kaldırın.';

  @override
  String get duyuruYeni => 'Yeni duyuru';

  @override
  String get duyuruYayinlandi => 'Duyuru yayınlandı ✓';

  @override
  String get duyuruGuncellendi => 'Duyuru güncellendi ✓';

  @override
  String get duyuruYok => 'Henüz duyuru yok.';

  @override
  String get duyuruYonetim => 'Yönetim';

  @override
  String duyuruMeta(Object ad, Object zaman, Object duzenlendi) {
    return '$ad · $zaman$duzenlendi';
  }

  @override
  String get duyuruDuzenlendiEki => ' · düzenlendi';

  @override
  String get duyuruSilOnay => 'Duyuru silinsin mi?';

  @override
  String get duyuruSilindi => 'Duyuru silindi ✓';

  @override
  String get duyuruDuzenleBaslik => 'Duyuru düzenle';

  @override
  String get duyuruBaslikZorunlu => 'Başlık zorunludur';

  @override
  String get duyuruMetniAlan => 'Duyuru metni';

  @override
  String get duyuruMetniZorunlu => 'Duyuru metni zorunludur';

  @override
  String get duyuruYayinla => 'Yayınla';

  @override
  String get ortakIslemler => 'İşlemler';

  @override
  String get sakinBaslik => 'Site Sakinleri';

  @override
  String get sakinEkle => 'Sakin ekle';

  @override
  String get sakinListelenemedi => 'Sakinler listelenemedi.';

  @override
  String get sakinDaireYok => 'Daire atanmamış';

  @override
  String get sakinIslemleri => 'Sakin işlemleri';

  @override
  String get sakinParolaSifirla => 'Parola sıfırla';

  @override
  String get sakinParolaSifirlaOnay => 'Parola sıfırlansın mı?';

  @override
  String sakinParolaSifirlaGovde(Object ad) {
    return '\"$ad\" için yeni geçici kod üretilir; eski parolası geçersiz olur. Kullanıcı telefon + yeni kod ile girip parolasını belirler.';
  }

  @override
  String get sakinSifirla => 'Sıfırla';

  @override
  String sakinYeniKodMesaji(Object ad) {
    return '\"$ad\" için yeni geçici kod. Sakine iletin; telefon + bu kod ile girip parolasını belirler.';
  }

  @override
  String get sakinSilOnay => 'Sakini sil?';

  @override
  String sakinSilGovde(Object ad) {
    return '\"$ad\" silinir. Geçmiş kaydı yoksa tamamen silinir; varsa pasifleşir. Her durumda telefon numarası serbest kalır (aynı numarayla yeniden kayıt yapılabilir).';
  }

  @override
  String sakinSilindi(Object ad) {
    return '\"$ad\" silindi (numara serbest)';
  }

  @override
  String sakinPasiflestirildi(Object ad) {
    return '\"$ad\" pasifleştirildi — geçmişi var (numara serbest)';
  }

  @override
  String get sakinDuzenleBaslik => 'Sakini düzenle';

  @override
  String get sakinYeniTelefon => 'Yeni cep telefonu';

  @override
  String get sakinBosBirakDegismez => 'Boş bırakırsanız değişmez';

  @override
  String get sakinGuncellendi => 'Güncellendi ✓';

  @override
  String get ortakAdSoyad => 'Ad Soyad';

  @override
  String get telefonHataEksik =>
      'Numara eksik — 10 hane girin (örn. 0543 199 29 04).';

  @override
  String get telefonHataOnEk =>
      'Cep telefonu 5 ile başlamalı (örn. 0543…). Sabit hat kabul edilmez.';

  @override
  String get ortakCepTelefonu => 'Cep telefonu';

  @override
  String get ortakTelefonIpucu => 'örn. 0532 111 22 03';

  @override
  String get ortakTelefonZorunlu => 'Telefon zorunludur';

  @override
  String get sakinGirisAnahtari => 'Giriş anahtarı (global benzersiz).';

  @override
  String get ortakDaireNoIpucu => 'örn. A-12';

  @override
  String get sakinDaireNoZorunlu => 'Daire no zorunludur';

  @override
  String get sakinParolaOpsiyonel => 'Parola (opsiyonel)';

  @override
  String get sakinBosBirakKod => 'Boş bırakırsanız geçici kod üretilir';

  @override
  String get sakinEklendiKod =>
      'Sakin eklendi. Bu kodu sakine iletin; telefon + bu kod ile girip parolasını belirler.';

  @override
  String get sakinEklendi => 'Sakin eklendi ✓';

  @override
  String get sakinYok => 'Henüz site sakini yok.\nSağ alttan ekleyebilirsiniz.';

  @override
  String get ortakGeciciKodBaslik => 'Geçici giriş kodu';

  @override
  String get ortakKopyala => 'Kopyala';

  @override
  String get ortakKopyalandi => 'Kopyalandı';

  @override
  String get girisParolaVeyaKod => 'Parola veya geçici kod';

  @override
  String get girisIlkKodIpucu =>
      'İlk girişte yönetimden aldığınız geçici kodu yazın.';

  @override
  String get girisBeniHatirla => 'Beni hatırla';

  @override
  String get girisYap => 'Giriş yap';

  @override
  String get girisOturumSonaErdi =>
      'Oturumunuz sona erdi. Lütfen tekrar giriş yapın.';

  @override
  String get parolaBelirleBaslik => 'Parolanızı belirleyin';

  @override
  String get parolaBelirleAciklama =>
      'Geçici kodla ilk girişinizi yaptınız. Devam etmek için kendi kalıcı parolanızı oluşturun; sonraki girişlerde daire no + bu parolayı kullanacaksınız.';

  @override
  String get parolaBelirleButon => 'Parolayı belirle';

  @override
  String get parolaGiriseDon => 'Girişe dön';

  @override
  String get ortakParolaZorunlu => 'Parola zorunludur';

  @override
  String get ortakYeniParola => 'Yeni parola';

  @override
  String get ortakYeniParolaTekrar => 'Yeni parola (tekrar)';

  @override
  String get ortakYeniParolaZorunlu => 'Yeni parola zorunludur';

  @override
  String get ortakParolalarEslesmiyor => 'Parolalar eşleşmiyor';

  @override
  String get parolaKuraliKisa => 'En az 8 karakter olmalı';

  @override
  String get parolaKuraliBuyukHarf => 'En az bir büyük harf içermeli';

  @override
  String get parolaKuraliRakam => 'En az bir rakam içermeli';

  @override
  String get parolaKuraliSembol => 'En az bir sembol içermeli (! ? @ # . -)';

  @override
  String get profilYuklenemedi => 'Profil yüklenemedi.';

  @override
  String get profilNumaraYok => 'Numara girilmemiş';

  @override
  String get profilFotoBaslik => 'Profil fotoğrafı';

  @override
  String get profilFotoSec => 'Fotoğraf seç';

  @override
  String get profilFotoGuncellendi => 'Profil fotoğrafı güncellendi ✓';

  @override
  String get profilFotoKaldirildi => 'Profil fotoğrafı kaldırıldı';

  @override
  String get ortakGaleri => 'Galeri';

  @override
  String get profilParolaDegistir => 'Parola değiştir';

  @override
  String get profilMevcutParola => 'Mevcut parola';

  @override
  String get profilMevcutParolaZorunlu => 'Mevcut parola zorunludur';

  @override
  String get profilParolaGuncelle => 'Parolayı güncelle';

  @override
  String get profilParolaGuncellendi => 'Parola güncellendi ✓';

  @override
  String get profilTelefon => 'Telefon';

  @override
  String get profilTelefonIpucu => 'örn. +905551112233';

  @override
  String get profilAranabilir => 'Aranabilir';

  @override
  String get profilAranabilirAlt =>
      'Yetkili roller (rıza gerektiren arama) numaranıza ulaşabilir';

  @override
  String get profilIletisimKaydet => 'İletişimi kaydet';

  @override
  String get profilIletisimGuncellendi => 'İletişim bilgileri güncellendi ✓';

  @override
  String get personelEkle => 'Personel ekle';

  @override
  String get personelDuzenle => 'Personel düzenle';

  @override
  String get personelListelenemedi => 'Personel listelenemedi.';

  @override
  String get personelPasiflestir => 'Pasifleştir';

  @override
  String get personelAktiflestir => 'Aktifleştir';

  @override
  String get personelPasiflestirildi => 'Pasifleştirildi ✓';

  @override
  String get personelAktiflestirildi => 'Aktifleştirildi ✓';

  @override
  String personelSifirlaGovde(Object ad) {
    return '$ad için yeni geçici kod üretilecek; eski parola geçersiz olur.';
  }

  @override
  String get personelYeniKodMesaji =>
      'Yeni geçici kod. Personele iletin; telefon + bu kod ile girip parolasını belirler.';

  @override
  String get personelGuncellendi => 'Personel güncellendi ✓';

  @override
  String get personelEklendi => 'Personel eklendi ✓';

  @override
  String get personelEklendiKod =>
      'Personel eklendi. Bu kodu personele iletin; telefon + bu kod ile girip parolasını belirler.';

  @override
  String get personelFoto => 'Fotoğraf';

  @override
  String get personelTelefonOpsiyonel => 'Cep telefonu (opsiyonel)';

  @override
  String get personelBosBirakDegismezNokta => 'Boş bırakırsanız değişmez.';

  @override
  String get personelYok =>
      'Henüz saha personeli yok.\nSağ alttan ekleyebilirsiniz.';

  @override
  String get disKisiEkle => 'Kişi ekle';

  @override
  String get disListeAlinamadi => 'Liste alınamadı.';

  @override
  String get disKayitYokYonetim =>
      'Henüz kayıt yok. Sağ alttan güvendiğiniz esnafı ekleyin.';

  @override
  String get disKayitYok => 'Henüz dış hizmet kaydı yok.';

  @override
  String get disNotEkleyin => 'Not ekleyin (yalnızca yönetici düzenler).';

  @override
  String get disNotuDuzenle => 'Notu düzenle';

  @override
  String get disBolumNotu => 'Bölüm notu';

  @override
  String get disNotIpucu =>
      'örn. Yıllardır güvendiğimiz esnaflar; site güvenliği için yabancı kişileri içeri almayın.';

  @override
  String get disNotGuncellendi => 'Not güncellendi ✓';

  @override
  String get disAra => 'Ara';

  @override
  String get disSilOnay => 'Kayıt silinsin mi?';

  @override
  String disSilGovde(Object ad) {
    return '\"$ad\" silinecek.';
  }

  @override
  String get disSilindi => 'Silindi ✓';

  @override
  String get disYeniKisi => 'Yeni dış hizmet kişisi';

  @override
  String get disKisiDuzenle => 'Kişi düzenle';

  @override
  String get disTur => 'Hizmet türü';

  @override
  String get disTurIpucu => 'örn. Çilingir, Elektrik, Tesisat';

  @override
  String get disTurZorunlu => 'Tür zorunludur';

  @override
  String get disAd => 'Ad';

  @override
  String get disSoyad => 'Soyad';

  @override
  String get disAdGerekli => 'Ad gerekli';

  @override
  String get disSoyadGerekli => 'Soyad gerekli';

  @override
  String get nfcBaslik => 'NFC etiket okuma';

  @override
  String get nfcHazir => 'Okumaya hazır. Başlat\'a dokunun.';

  @override
  String get nfcYaklastirBekliyor =>
      'Etiketi telefonun arkasına yaklaştırın...';

  @override
  String get nfcOkundu => 'Etiket okundu.';

  @override
  String get nfcOkumayaBasla => 'Okumayı başlat';

  @override
  String get nfcTekrarOku => 'Tekrar oku';

  @override
  String nfcKuyrukBekleyen(num n) {
    return '$n okutma gönderim bekliyor';
  }

  @override
  String get nfcKuyruk => 'Gönderim kuyruğu';

  @override
  String get nfcKaydedildiBekliyor =>
      'Kaydedildi ✓ — bağlantı gelince otomatik gönderilecek.';

  @override
  String get nfcKaydedildiGonderiliyor => 'Kaydedildi ✓ — gönderiliyor...';

  @override
  String get nfcGonderildiZatenVar =>
      'Gönderildi ✓ — bu okutma zaten kayıtlıydı.';

  @override
  String get nfcGonderildi => 'Gönderildi ✓ — okutma kaydedildi.';

  @override
  String get nfcEslesmeYok => 'Bu etiket hiçbir checkpoint ile eşleşmiyor.';

  @override
  String get nfcSdmBaslik => 'SDM (ham, doğrulanmamış)';

  @override
  String get nfcTipEtiket => 'Tip';

  @override
  String nfcNoktalarAlinamadi(Object hata) {
    return 'Noktalar alınamadı: $hata';
  }

  @override
  String get nfcTestBaslik => 'TEST: hangi noktayı okutalım?';

  @override
  String get nfcTestAlt => 'Fiziksel etiket olmadan okutmayı simüle eder.';

  @override
  String get nfcAktifNoktaYok => 'Aktif kontrol noktası yok.';

  @override
  String get nfcAktifNoktaYokAlt => 'Önce \"Kontrol noktaları\"ndan ekleyin.';

  @override
  String get nfcManuelOkut => 'Manuel okut (test)';

  @override
  String get nfcTestGorunur => 'Yalnızca test derlemesinde görünür.';

  @override
  String nfcUidSatir(Object uid) {
    return 'UID: $uid';
  }

  @override
  String get nfcHataKapali =>
      'NFC kapalı. Lütfen cihaz ayarlarından NFC\'yi açın.';

  @override
  String get nfcHataDesteklenmiyor => 'Bu cihaz NFC desteklemiyor.';

  @override
  String get nfcHataUidOkunamadi => 'Etiket UID okunamadı.';

  @override
  String nfcHataCozumlenemedi(Object detay) {
    return 'Etiket çözümlenemedi: $detay';
  }

  @override
  String nfcHataOturum(Object detay) {
    return 'NFC oturumu başlatılamadı: $detay';
  }

  @override
  String nfcHataOkumaIptal(Object detay) {
    return 'Okuma iptal edildi: $detay';
  }

  @override
  String nfcHataYapilandirma(Object detay) {
    return 'NFC bu yapımda kullanılamıyor: $detay. Uygulamanın güncellenmesi gerekiyor; tekrar denemek sonucu değiştirmez.';
  }

  @override
  String get nfcHataBilinmeyen => 'Bilinmeyen bir hata oluştu.';

  @override
  String get nfcIosYaklastir => 'Etiketi telefonun arkasına yaklaştırın.';

  @override
  String get nfcIosOkundu => 'Okundu';

  @override
  String get nfcIosIptal => 'İptal edildi';

  @override
  String get nfcIosOkunamadi => 'Okunamadı';

  @override
  String get seffafYuklenemedi => 'Yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get seffafAyYayinlandi => 'Ay yayınlandı.';

  @override
  String get seffafYayinGeriAlindi => 'Yayın geri alındı.';

  @override
  String get seffafVeriYokYonetim =>
      'Henüz finansal veri yok. Gelir/gider veya aidat girildiğinde aylar burada listelenir.';

  @override
  String get seffafVeriYok => 'Yönetim henüz özet yayınlamadı.';

  @override
  String get seffafTaslakEki => ' • taslak';

  @override
  String get seffafYayinla => 'Bu ayı yayınla';

  @override
  String get seffafYayindaAlt => 'Sakinler bu özeti görüyor.';

  @override
  String get seffafOnizlemeAlt => 'Yalnızca yönetim görüyor (önizleme).';

  @override
  String get seffafOnizlemeUyari => 'Önizleme — henüz yayınlanmadı.';

  @override
  String seffafOzetBaslik(Object ay) {
    return '$ay — Özet';
  }

  @override
  String get seffafToplamGelir => 'Toplam gelir';

  @override
  String get seffafToplamGider => 'Toplam gider';

  @override
  String get seffafNet => 'Net';

  @override
  String seffafOncekiAyNet(Object tutar) {
    return 'Önceki ay net: $tutar';
  }

  @override
  String get seffafGiderDagilimi => 'Gider dağılımı';

  @override
  String get seffafGiderYok => 'Bu ay gider kaydı yok.';

  @override
  String get seffafAidatToplama => 'Aidat toplama';

  @override
  String get seffafTahakkukYok => 'Bu ay için tahakkuk yok.';

  @override
  String seffafOdeyenDaire(Object odeyen, Object toplam) {
    return 'Ödeyen daire: $odeyen/$toplam';
  }

  @override
  String seffafTahsilatSatir(Object tahsilat, Object tahakkuk, Object yuzde) {
    return 'Tahsilat: $tahsilat / $tahakkuk  (tutar: %$yuzde)';
  }

  @override
  String seffafGecikmede(num n) {
    return 'Gecikmede $n daire';
  }

  @override
  String ortakYuzde(Object yuzde) {
    return '%$yuzde';
  }

  @override
  String get entegYeni => 'Yeni';

  @override
  String get entegYokMesaj =>
      'Entegrasyon yok. \"Yeni\" ile bir dış sistem (megafon/akıllı ev/webhook) ekleyin.';

  @override
  String get entegSilOnay => 'Silinsin mi?';

  @override
  String entegSilGovde(Object ad) {
    return '\"$ad\" entegrasyonu silinecek.';
  }

  @override
  String entegSilinemedi(Object hata) {
    return 'Silinemedi: $hata';
  }

  @override
  String get entegAktifKisa => 'aktif';

  @override
  String get entegPasifKisa => 'pasif';

  @override
  String entegKimlikSatir(Object tip, Object kilit) {
    return 'Kimlik: $tip$kilit';
  }

  @override
  String get entegTest => 'Test';

  @override
  String entegTestBasarili(Object durum) {
    return '✓ Başarılı ($durum)';
  }

  @override
  String entegTestBasarisiz(Object hata, Object durum) {
    return '✗ $hata$durum';
  }

  @override
  String get entegBasarisiz => 'Başarısız';

  @override
  String get entegDuzenleBaslik => 'Entegrasyon düzenle';

  @override
  String get entegYeniBaslik => 'Yeni entegrasyon';

  @override
  String get entegPreset => 'Hazır şablon (preset)';

  @override
  String get entegKanalTipi => 'Kanal tipi';

  @override
  String get entegUrl => 'Endpoint URL (http/https)';

  @override
  String get entegUrlHelper => 'İç/özel adresler tetikte engellenir';

  @override
  String get entegUrlHata => 'http(s) ile başlamalı';

  @override
  String get entegHttpMetodu => 'HTTP metodu';

  @override
  String get entegKimlikDogrulama => 'Kimlik doğrulama';

  @override
  String get entegSir => 'Sır (bearer token / API key)';

  @override
  String get entegSirKayitli => 'Kayıtlı — değiştirmek için yeni değer girin';

  @override
  String get entegSirYazmaOzel => 'Yazma-özel; sunucudan asla dönmez';

  @override
  String get entegPayload => 'Payload şablonu';

  @override
  String entegPayloadHelper(Object sablonlar) {
    return '$sablonlar yer tutucuları';
  }

  @override
  String get entegTestMesaji => 'Test mesajı';

  @override
  String get ortakAdGerekli => 'Ad gerekli';

  @override
  String get ziyaretYeni => 'Yeni ziyaretçi';

  @override
  String get ziyaretKaydedildi =>
      'Ziyaretçi kaydedildi — daire sakinine bildirildi ✓';

  @override
  String get ziyaretYokGuvenlik => 'Henüz ziyaretçi kaydı yok.';

  @override
  String get ziyaretYokSakin => 'Size iletilen ziyaretçi kaydı yok.';

  @override
  String ziyaretBildirilenSakin(Object ad) {
    return 'Bildirilen sakin: $ad';
  }

  @override
  String get ziyaretSakiniAra => 'Sakini ara';

  @override
  String get ziyaretGuvenligiAra => 'Güvenliği ara';

  @override
  String get ziyaretBilgileriDuzenle => 'Bilgileri düzenle';

  @override
  String get ziyaretGuncellendi => 'Ziyaretçi bilgileri güncellendi ✓';

  @override
  String get ziyaretOnceDaireNo => 'Önce daire no girin';

  @override
  String get ziyaretSakiniSecin => 'Bildirilecek sakini seçin';

  @override
  String get ziyaretDuzenleBaslik => 'Ziyaretçi düzenle';

  @override
  String get ziyaretDuzenleAlt =>
      'Ad, daire, bildirilen sakin ve notu güncelleyebilirsiniz.';

  @override
  String get ziyaretYeniAlt =>
      'Sakine yalnızca bilgilendirme gider (onay istenmez).';

  @override
  String get ziyaretAdAlan => 'Ziyaretçi adı *';

  @override
  String get ziyaretAdGerekli => 'Ziyaretçi adı gerekli';

  @override
  String get ziyaretSakinleriGetir => 'Sakinleri getir';

  @override
  String get ziyaretBildirilecekSakin => 'Bildirilecek sakin *';

  @override
  String get ziyaretKaydetVeBildir => 'Kaydet ve sakine bildir';

  @override
  String get raporBaslik => 'Aylık raporlar';

  @override
  String get raporOncekiAy => 'Önceki ay';

  @override
  String get raporSonrakiAy => 'Sonraki ay';

  @override
  String raporAyBaslik(Object ay, Object yil) {
    return '$ay $yil';
  }

  @override
  String get raporYetkiYok =>
      'Aylık raporlar için yetkiniz yok. Bu ekran yönetici rolüne açıktır.';

  @override
  String get raporGorevTamamlama => 'Görev tamamlama';

  @override
  String get raporAidat => 'Aidat';

  @override
  String get raporSonTamamlamalar => 'Son tamamlamalar (ilk 10)';

  @override
  String get raporPlanlananPencere => 'Planlanan pencere';

  @override
  String raporTamamlanmaYuzde(Object yuzde) {
    return 'Tamamlanma %$yuzde';
  }

  @override
  String get raporPencereYok => 'Bu ay planlanmış devriye penceresi yok.';

  @override
  String get raporGorevYok => 'Bu ay görev tamamlaması yok.';

  @override
  String get raporToplamTamamlama => 'Toplam tamamlama';

  @override
  String get raporAidatKayitYok => 'Bu dönem için tahakkuk/ödeme kaydı yok.';

  @override
  String raporTahakkukDaire(num n) {
    return 'Tahakkuk ($n daire)';
  }

  @override
  String raporTahsilatOdeme(num n) {
    return 'Tahsilat ($n ödeme)';
  }

  @override
  String get raporKalanBakiye => 'Kalan bakiye';

  @override
  String get aidatBaslik => 'Aidatım';

  @override
  String get aidatYetkiYok =>
      'Aidat bilgisi yalnızca site sakini hesabına açıktır.';

  @override
  String get aidatDaireYok =>
      'Üzerinize kayıtlı daire bulunamadı. Yönetiminizle iletişime geçin.';

  @override
  String get aidatToplamBakiye => 'Toplam bakiye (tüm daireler)';

  @override
  String get aidatBorcVar => 'Borç var';

  @override
  String get aidatBorcYok => 'Borç yok';

  @override
  String get aidatToplamTahakkuk => 'Toplam tahakkuk';

  @override
  String get aidatToplamOdenen => 'Toplam ödenen';

  @override
  String get aidatBakiye => 'Bakiye';

  @override
  String aidatHesapSatiri(Object tahakkuk, Object odenen, Object bakiye) {
    return 'Tahakkuk $tahakkuk - ödenen $odenen = $bakiye';
  }

  @override
  String aidatTahakkuklar(num n) {
    return 'Tahakkuklar ($n)';
  }

  @override
  String aidatOdemeler(num n) {
    return 'Ödemeler ($n)';
  }

  @override
  String aidatSonOdeme(Object tarih) {
    return 'Son ödeme: $tarih';
  }

  @override
  String aidatMakbuz(Object no) {
    return 'Makbuz: $no';
  }

  @override
  String get aidatOdemeDurumuNotu =>
      'Ödeme durumu yalnızca ödeme sağlayıcısından gelen onayla güncellenir; sorularınız için yönetiminize başvurun.';

  @override
  String get aidatYontemElden => 'Elden';

  @override
  String get aidatYontemHavale => 'Havale/EFT';

  @override
  String get aidatYontemKart => 'Kart';

  @override
  String get aidatYontemDiger => 'Diğer';

  @override
  String get aidatDurumBasarili => 'Başarılı';

  @override
  String get aidatDurumIptal => 'İptal';

  @override
  String get noktaBaslik => 'Kontrol Noktaları';

  @override
  String get noktaEkle => 'Nokta ekle';

  @override
  String get noktaListelenemedi => 'Noktalar listelenemedi.';

  @override
  String get noktaSilOnay => 'Nokta silinsin mi?';

  @override
  String noktaSilGovde(Object ad) {
    return '\"$ad\" kontrol noktası silinecek.';
  }

  @override
  String get noktaSilindi => 'Nokta silindi ✓';

  @override
  String get noktaUidZatenVar => 'Bu NFC etiketi zaten kayıtlı.';

  @override
  String get noktaDuzenleBaslik => 'Nokta düzenle';

  @override
  String get noktaYeniBaslik => 'Yeni kontrol noktası';

  @override
  String get noktaAdIpucu => 'örn. Giriş Kapısı';

  @override
  String get noktaUidAlan => 'NFC etiket UID';

  @override
  String get noktaUidIpucu => 'örn. 04A2B3C4D5';

  @override
  String get noktaUidHelper => 'Etiketin benzersiz kimliği (hex).';

  @override
  String get noktaEnlem => 'Enlem (ops.)';

  @override
  String get noktaKonumGecersiz => 'Konum geçersiz. Örnek: 41,0082';

  @override
  String get ortakSecenekYuklenemedi =>
      'Bazı seçenekler yüklenemedi — liste eksik olabilir.';

  @override
  String get noktaBoylam => 'Boylam (ops.)';

  @override
  String get noktaPasifAlt => 'Pasif nokta okutmada eşleşmez';

  @override
  String get noktaYok =>
      'Henüz kontrol noktası yok.\nSağ alttan NFC noktası ekleyin.';

  @override
  String get kuyrukHatalariTemizle => 'Kalıcı hataları temizle';

  @override
  String get kuyrukBos => 'Kuyruk boş.';

  @override
  String kuyrukOzet(Object bekleyen, Object hatali) {
    return '$bekleyen bekliyor · $hatali kalıcı hata';
  }

  @override
  String get kuyrukSenkronla => 'Şimdi senkronla';

  @override
  String get kuyrukBekliyor => 'Bekliyor';

  @override
  String kuyrukBekliyorDeneme(Object n) {
    return 'Bekliyor (deneme: $n)';
  }

  @override
  String get kuyrukGonderiliyor => 'Gönderiliyor...';

  @override
  String get kuyrukGonderildiZatenVar => 'Gönderildi (zaten kayıtlıydı)';

  @override
  String get kuyrukGonderildiYeni => 'Gönderildi (yeni kayıt)';

  @override
  String kuyrukKaliciHata(Object hata) {
    return 'Kalıcı hata: $hata';
  }

  @override
  String get kuyrukEtiketEslesmedi => 'etiket eşleşmedi';

  @override
  String get okutmaImzaGecersiz =>
      'Etiket imzası doğrulanamadı — sahte veya yanlış etiket olabilir.';

  @override
  String get okutmaTekrarEdilmis => 'Bu okutma daha önce işlendi.';

  @override
  String okutmaBeklenmeyenHata(Object detay) {
    return 'Beklenmeyen hata: $detay';
  }

  @override
  String get noktaUidZorunlu => 'NFC UID zorunludur';

  @override
  String get hataZamanAsimi => 'Sunucuya bağlanırken zaman aşımı oluştu.';

  @override
  String get hataSunucuyaUlasilamadi =>
      'Sunucuya ulaşılamadı. Ağ bağlantınızı ve sunucu adresini kontrol edin.';

  @override
  String get destekBaslik => 'Destek';

  @override
  String get destekYeniTalep => 'Yeni Talep';

  @override
  String get destekTalepYok => 'Henüz destek talebiniz yok';

  @override
  String destekYuklenemedi(Object hata) {
    return 'Talepler yüklenemedi.\n$hata';
  }

  @override
  String destekGonderilemedi(Object hata) {
    return 'Talep gönderilemedi: $hata';
  }

  @override
  String get destekYeniTalepBaslik => 'Yeni Destek Talebi';

  @override
  String get destekKonu => 'Konu';

  @override
  String get destekGorselEkle => 'Görsel ekle';

  @override
  String get destekGorseliDegistir => 'Görseli değiştir';

  @override
  String get destekEkip => 'Yönetio Ekibi';

  @override
  String get tesisKurulumBaslik => 'Tesisinizi tanımlayın';

  @override
  String get tesisKurulumAciklama =>
      'Yönetici olarak ilk girişinizi yaptınız. Devam etmek için sitenizin/tesisinizin adını girin. Bu adı daha sonra ayarlardan değiştirebilirsiniz.';

  @override
  String get tesisAdiIpucu => 'Örn. Örnek Sitesi';

  @override
  String get tesisAdiKisa => 'Tesis adı en az 2 karakter olmalı';

  @override
  String get tesisOlustur => 'Tesisi oluştur';

  @override
  String get tesisAdiGuncellendi => 'Tesis adı güncellendi';

  @override
  String get tesisAdiAciklama =>
      'Ana ekranın başlığında görünür; tüm kullanıcılar bu adı görür.';

  @override
  String get sikayetYokSakin =>
      'Henüz şikayet açmadınız.\nŞikayet Haritası’ndan bir daire seçip şikayet edebilirsiniz.';

  @override
  String sikayetSatirBaslik(Object daire, Object kategori) {
    return 'Daire $daire · $kategori';
  }

  @override
  String get sikayetDurumKapandi => 'Kapandı';

  @override
  String get vardiyaBaslik => 'Vardiyalar';

  @override
  String get vardiyaYuklenemedi => 'Vardiyalar yüklenemedi.';

  @override
  String get vardiyaTanimYok => 'Vardiya tanımı yok';

  @override
  String vardiyaSaatAraligi(Object baslangic, Object bitis, Object gunTipi) {
    return '$baslangic - $bitis • $gunTipi';
  }

  @override
  String get vardiyaPersonelAta => 'Personel Ata';

  @override
  String vardiyaPersonelBaslik(Object ad) {
    return '$ad — Personel';
  }

  @override
  String get vardiyaPersonelGuncellendi => 'Vardiya personeli güncellendi ✓';

  @override
  String get vardiyaPersonelYuklenemedi => 'Personel yüklenemedi.';

  @override
  String get vardiyaAtanabilirYok => 'Atanabilir personel yok';

  @override
  String get gunTipiHaftaIci => 'Hafta içi';

  @override
  String get gunTipiHaftaSonu => 'Hafta sonu';

  @override
  String get gunTipiResmiTatil => 'Resmî tatil';

  @override
  String get gunTipiHerGun => 'Her gün';

  @override
  String get yonIletisimBaslik => 'Yönetici İletişim';

  @override
  String get yonIletisimAlinamadi => 'Yönetici bilgileri alınamadı.';

  @override
  String get yonIletisimTanimliDegil =>
      'Yönetici iletişim bilgisi tanımlı değil.';

  @override
  String get yonIletisimMail => 'Yönetim maili';

  @override
  String get yonIletisimAra => 'Yöneticiyi Ara';

  @override
  String get aramaBaslatilamadi => 'Arama başlatılamadı';

  @override
  String get aramaYapilamiyor => 'Aranamıyor';

  @override
  String get bildirimYok => 'Bildirim yok';

  @override
  String bildirimYuklenemedi(Object hata) {
    return 'Bildirimler yüklenemedi.\n$hata';
  }

  @override
  String get bildirimYeniPush => 'Yeni bildirim';

  @override
  String get akisDevriyeOkutma => 'Devriye Okutması';

  @override
  String get akisGorevTamamlandi => 'Görev Tamamlandı';

  @override
  String get akisAidatOdemesi => 'Aidat Ödemesi';

  @override
  String get akisTalepAcildi => 'Talep Açıldı';

  @override
  String get akisTalepIsEmri => 'Talep İş Emrine Dönüştü';

  @override
  String get akisTalepCozuldu => 'Talep Çözüldü';

  @override
  String get akisTalepReddedildi => 'Talep Reddedildi';

  @override
  String get akisDaireSikayeti => 'Daire Şikayeti';

  @override
  String get akisAlarmKacirilanTur => 'Kaçırılan Tur';

  @override
  String get akisAlarmEksikCheckpoint => 'Eksik Kontrol Noktası';

  @override
  String get akisAlarmGecikmisOkutma => 'Gecikmiş Okutma';

  @override
  String get akisZiyaretciGirisi => 'Ziyaretçi Girişi';

  @override
  String get akisZiyaretciCikisi => 'Ziyaretçi Çıkışı';

  @override
  String get akisKargoKaydedildi => 'Kargo Kaydedildi';

  @override
  String get akisKargoTeslimEdildi => 'Kargo Teslim Edildi';

  @override
  String get akisAracGirisi => 'Araç Girişi';

  @override
  String get akisAracCikisi => 'Araç Çıkışı';

  @override
  String get akisIhlalKaydi => 'İhlal Kaydı';

  @override
  String akisAltDaireTutar(Object daire, Object tutar) {
    return 'Daire $daire — $tutar';
  }

  @override
  String akisAltDaireKategori(Object daire, Object kategori) {
    return 'Daire $daire — $kategori';
  }

  @override
  String akisAltAdDaire(Object ad, Object daire) {
    return '$ad — Daire $daire';
  }

  @override
  String akisAltPlakaDaire(Object plaka, Object daire) {
    return '$plaka — Daire $daire';
  }

  @override
  String akisAltPlakaTanim(Object plaka, Object tanim) {
    return '$plaka ($tanim)';
  }

  @override
  String akisAltPlakaDaireTanim(Object plaka, Object daire, Object tanim) {
    return '$plaka — Daire $daire ($tanim)';
  }

  @override
  String akisAltMetinKonum(Object metin, Object konum) {
    return '$metin — $konum';
  }

  @override
  String akisAltPlanAralik(Object plan, Object aralik) {
    return '$plan · $aralik';
  }

  @override
  String get ortakParolayiGoster => 'Parolayı göster';

  @override
  String get ortakParolayiGizle => 'Parolayı gizle';

  @override
  String get ortakFotograf => 'Fotoğraf';

  @override
  String get ortakFotografiBuyut => 'Fotoğrafı büyüt';

  @override
  String get ortakGoster => 'Göster';

  @override
  String get talepRedBaslik => 'Talebi reddet';

  @override
  String get ziyaretciDaireSakinYok => 'Bu dairede aktif sakin yok';

  @override
  String get ceviriOtomatik => 'Bu içerik otomatik çevrilmiştir';

  @override
  String get ceviriOtomatikKisa => 'Otomatik çeviri';

  @override
  String get ceviriOrijinaliGor => 'Orijinali gör';

  @override
  String get ceviriCeviriyiGor => 'Çeviriyi gör';

  @override
  String get ceviriHazirlaniyor =>
      'Çeviri hazırlanıyor — orijinal gösteriliyor';

  @override
  String get ceviriHazirlaniyorKisa => 'Çeviri hazırlanıyor';

  @override
  String get ceviriYapilamadi => 'Çeviri yapılamadı — orijinal gösteriliyor';

  @override
  String get ceviriYapilamadiKisa => 'Çeviri yapılamadı';

  @override
  String get modulAracGecis => 'Araç Geçişleri';

  @override
  String get modulOtopark => 'Otopark';

  @override
  String get modulIhlaller => 'İhlaller';

  @override
  String get aracSuzgecTumu => 'Tümü';

  @override
  String get aracSuzgecIceride => 'İçeride';

  @override
  String get aracSuzgecCikmis => 'Çıkmış';

  @override
  String get aracPlakaAra => 'Plaka ara';

  @override
  String get aracListeBos => 'Kayıtlı araç geçişi yok';

  @override
  String get aracAramaBos => 'Bu plakayla eşleşen geçiş yok';

  @override
  String get aracRozetIceride => 'İçeride';

  @override
  String get aracRozetCikti => 'Çıktı';

  @override
  String get aracRozetZiyaretci => 'Ziyaretçi';

  @override
  String aracGirisZamani(Object zaman) {
    return 'Giriş: $zaman';
  }

  @override
  String aracCikisZamani(Object zaman) {
    return 'Çıkış: $zaman';
  }

  @override
  String aracDaire(Object no) {
    return 'Daire $no';
  }

  @override
  String get aracCikisVer => 'Çıkış ver';

  @override
  String get aracCikisOnayBaslik => 'Çıkış verilsin mi?';

  @override
  String get aracCikisVerildi => 'Çıkış kaydedildi';

  @override
  String get aracZatenKapali => 'Bu geçiş zaten kapatılmış';

  @override
  String get aracYeniGiris => 'Yeni giriş';

  @override
  String get aracGirisKaydedildi => 'Araç girişi kaydedildi';

  @override
  String get aracPlaka => 'Plaka';

  @override
  String get aracPlakaZorunlu => 'Plaka zorunlu';

  @override
  String get aracTanimAlani => 'Araç tanımı (isteğe bağlı)';

  @override
  String get aracDaireAlani => 'Daire no (isteğe bağlı)';

  @override
  String get aracZiyaretciMi => 'Ziyaretçi aracı';

  @override
  String get aracZatenIceride =>
      'Bu plakanın açık geçişi zaten var (araç içeride)';

  @override
  String get aracErisimYok =>
      'Araç geçiş listesi yalnız yönetim ve güvenlik içindir';

  @override
  String aracKaydeden(Object ad) {
    return 'Kaydeden: $ad';
  }

  @override
  String get otoparkDoluEtiket => 'Dolu';

  @override
  String get otoparkBosEtiket => 'Boş';

  @override
  String get otoparkKapasiteEtiket => 'Kapasite';

  @override
  String get otoparkKapasiteTanimsiz =>
      'Kapasite tanımlı değil — yalnız içerideki araç sayısı gösterilir';

  @override
  String get otoparkAracListesi => 'Araç geçişlerini aç';

  @override
  String get ihlalDurumYeni => 'Yeni';

  @override
  String get ihlalDurumInceleniyor => 'İnceleniyor';

  @override
  String get ihlalDurumKapatildi => 'Kapatıldı';

  @override
  String get ihlalKaynakKamera => 'Kamera';

  @override
  String get ihlalKaynakManuel => 'Manuel';

  @override
  String get ihlalKaynakDevriye => 'Devriye';

  @override
  String get ihlalListeBos => 'İhlal kaydı yok';

  @override
  String get ihlalYeni => 'Yeni ihlal';

  @override
  String get ihlalAcildi => 'İhlal kaydı açıldı';

  @override
  String get ihlalBaslikAlani => 'Başlık';

  @override
  String get ihlalBaslikZorunlu => 'Başlık zorunlu';

  @override
  String get ihlalAciklamaAlani => 'Açıklama (isteğe bağlı)';

  @override
  String get ihlalKonumAlani => 'Konum (isteğe bağlı)';

  @override
  String get ihlalKaynakAlani => 'Tespit kaynağı';

  @override
  String get ihlalIncelemeyeAl => 'İncelemeye al';

  @override
  String get ihlalKapat => 'Kaydı kapat';

  @override
  String get ihlalDurumGuncellendi => 'İhlal durumu güncellendi';

  @override
  String get ihlalKapatmaOnay =>
      'Kayıt kapatılsın mı? Kapatılan ihlal yeniden açılamaz.';

  @override
  String get ihlalKapaliDegistirilemez => 'Kapatılmış ihlal yeniden açılamaz';

  @override
  String get ihlalErisimYok =>
      'İhlal kayıtları yalnız yönetim ve güvenlik içindir';

  @override
  String ihlalKaydeden(Object ad) {
    return 'Açan: $ad';
  }

  @override
  String get kameraRestream => 'Restream adresi (isteğe bağlı)';

  @override
  String get kameraRestreamAlt =>
      'RTSP kamerayı oynatılabilir yapar. Frigate/go2rtc geçidinin HLS adresi.';

  @override
  String get kameraRestreamHata =>
      'Restream adresi http:// veya https:// ile başlamalı';

  @override
  String get kameraRestreamRozet => 'Geçit üzerinden';

  @override
  String get modulPlakaOlaylari => 'Plaka Okumaları';

  @override
  String get anprDurumIslendi => 'İşlendi';

  @override
  String get anprDurumOnayBekliyor => 'Onay bekliyor';

  @override
  String get anprDurumYokSayildi => 'Yok sayıldı';

  @override
  String get anprDurumHata => 'Hata';

  @override
  String get anprYonGiris => 'Giriş';

  @override
  String get anprYonCikis => 'Çıkış';

  @override
  String get anprYonBilinmiyor => 'Yön bilinmiyor';

  @override
  String get anprListeBos => 'Plaka okuma kaydı yok';

  @override
  String get anprErisimYok =>
      'Plaka okumaları yalnız yönetim ve güvenlik içindir';

  @override
  String anprGuven(Object oran) {
    return 'Güven %$oran';
  }

  @override
  String get anprOnayla => 'Onayla';

  @override
  String get anprReddet => 'Reddet';

  @override
  String get anprOnayBaslik => 'Okumayı onayla';

  @override
  String get anprOnayAciklama =>
      'Plaka yanlış okunduysa düzeltebilirsiniz. Onaylarsanız araç geçişi açılır/kapanır.';

  @override
  String get anprKararUygulandi => 'Karar uygulandı';

  @override
  String get anprOnayBeklemiyor => 'Bu okuma artık onay beklemiyor';

  @override
  String get anprNedenDusukGuven => 'Düşük güven';

  @override
  String get anprNedenZatenIceride => 'Araç zaten içeride';

  @override
  String get anprNedenAcikGecisYok => 'Açık geçiş yok';

  @override
  String get anprNedenOtomatikCikisKapali => 'Otomatik çıkış kapalı';

  @override
  String get anprNedenElleReddedildi => 'Elle reddedildi';

  @override
  String get anprNedenPlakaBicimi => 'Plaka okunamadı';

  @override
  String get aracPlakaOkumalari => 'Plaka okumaları';

  @override
  String get kategoriGoruntuKirliligi => 'Görüntü kirliliği';

  @override
  String get fabSikayetBildir => 'Komşu şikayeti bildir';

  @override
  String get sakinRolTipi => 'İlişki tipi';

  @override
  String get sakinRolMalik => 'Kat maliki';

  @override
  String get sakinRolKiraci => 'Kiracı';

  @override
  String get sakinRolDegisme => 'Değiştirme';

  @override
  String get sakinRolAlt =>
      'Aidat kiracıya, yatırım gideri malike borçlandırılır.';

  @override
  String get sakinEposta => 'E-posta';

  @override
  String get sakinEpostaTemizle => 'E-postayı kaldır';

  @override
  String get sakinRolBagYok =>
      'İlişki tipi için sakinin bir daireye bağlı olması gerekir';

  @override
  String get sikayetKuyruguBaslik => 'Şikayet Kuyruğu';

  @override
  String get sikayetSekmeYeni => 'Yeni';

  @override
  String get sikayetSekmeTumu => 'Tümü';

  @override
  String get sikayetOkunmamisYok => 'Okunmamış şikayet yok.';

  @override
  String get sikayetYokYonetim => 'Henüz şikayet yok.';

  @override
  String get sikayetOkunduIsaretle => 'Okundu işaretle';

  @override
  String sikayetOkunmamisRozet(int sayi) {
    return '$sayi okunmamış şikayet';
  }

  @override
  String get kameraHataAdresBozuk =>
      'Yayın adresi geçersiz. Adreste boşluk ya da satır sonu kalmış olabilir.';

  @override
  String get kameraHataSemaDesteklenmiyor =>
      'Bu adres türü doğrudan oynatılamaz. Kamera için bir yeniden yayın (restream) adresi tanımlayın.';

  @override
  String get kameraHataSifrelenmemis =>
      'Şifrelenmemiş (http) yayın cihaz tarafından engellendi. Kurumsal profil ya da VPN buna izin vermiyor olabilir.';

  @override
  String kameraUrlCokUzun(int sinir) {
    return 'Yayın adresi çok uzun (en fazla $sinir karakter).';
  }

  @override
  String get kameraUrlSifrelenmemisUyari =>
      'Bu adres şifrelenmemiş (http). Mümkünse https kullanın.';

  @override
  String get modulDaireTanimlari => 'Bağımsız Bölüm Tanımları';

  @override
  String get daireTanimSekmeTipler => 'Tipler';

  @override
  String get daireTanimSekmeGruplar => 'Gruplar';

  @override
  String get daireTanimAd => 'Ad';

  @override
  String get daireTanimAdIpucu => 'Örn. 2+1, dubleks, Villa';

  @override
  String get daireTanimVarsayilanAidat => 'Varsayılan aidat';

  @override
  String get daireTanimAidatBos => 'Tanımsız';

  @override
  String get daireTanimAidatAlt =>
      'Boş bırakılırsa tanımsız kalır; 0 yazmak “muaf” demektir.';

  @override
  String daireTanimDaireSayisi(int sayi) {
    return '$sayi daire';
  }

  @override
  String daireTanimSilOnay(int sayi) {
    return 'Bu tanım silinsin mi? Bağlı $sayi daire SİLİNMEZ, yalnız sınıflandırması boşalır.';
  }

  @override
  String daireTanimSilindiEtki(int sayi) {
    return 'Silindi. $sayi dairenin sınıflandırması boşaldı.';
  }

  @override
  String get daireTanimYok => 'Henüz tanım yok.';

  @override
  String get daireTanimYeni => 'Yeni tanım';

  @override
  String get daireTipiSecici => 'Bağımsız bölüm tipi';

  @override
  String get daireGrubuSecici => 'Bağımsız bölüm grubu';

  @override
  String get daireTanimSecilmedi => 'Seçilmedi';

  @override
  String get odeBaslik => 'Öde';

  @override
  String get odeBorcunuz => 'Ödenmemiş tutar';

  @override
  String get odeHavaleBaslik => 'Banka havalesi';

  @override
  String get odeHavaleAdim =>
      'IBAN’a havale yapın ve açıklamaya aşağıdaki kodu yazın. Kod olmadan ödemeniz eşleşmeyebilir.';

  @override
  String get odeKodBaslik => 'Açıklama kodunuz';

  @override
  String get odeKopyala => 'Kopyala';

  @override
  String get odeKopyalandi => 'Kopyalandı';

  @override
  String get odeKartBaslik => 'Kartla öde';

  @override
  String get odeKartKapali =>
      'Kart ödemesi henüz açık değil. Şimdilik banka havalesi kullanabilirsiniz.';

  @override
  String get odeHavaleKapali =>
      'Site henüz banka hesabı tanımlamamış. Yönetime başvurun.';

  @override
  String get odeBorcYok => 'Ödenmemiş borcunuz yok.';

  @override
  String get odeBasarili => 'Ödemeniz alındı.';

  @override
  String get nfcFotoGerekli => 'Tura başlamak için fotoğraf gerekli.';

  @override
  String get nfcFotoCek => 'Fotoğraf çek ve gönder';

  @override
  String get nfcFotoYukleniyor => 'Fotoğraf yükleniyor...';

  @override
  String nfcFotoYuklenemedi(String hata) {
    return 'Fotoğraf yüklenemedi: $hata';
  }

  @override
  String get nfcKonumYok => 'Konum alınamadı — okutma konumsuz kaydedildi.';

  @override
  String get nfcKonumIzinYok =>
      'Konum izni verilmedi — okutma konumsuz kaydedildi.';

  @override
  String get nfcKonumServisKapali =>
      'Konum servisi kapalı — okutma konumsuz kaydedildi.';

  @override
  String get rolGuvenlikAmiri => 'Güvenlik Amiri';

  @override
  String get rolDenetci => 'Denetçi';

  @override
  String get kvkkBaslik => 'Aydınlatma Metni';

  @override
  String get kvkkSonaKaydir => 'Onaylamak için metnin sonuna kadar okuyun.';

  @override
  String get kvkkOnayliyorum => 'Okudum, onaylıyorum';

  @override
  String get kvkkYuklenemedi => 'Aydınlatma metni yüklenemedi.';

  @override
  String get kvkkTekrarDene => 'Tekrar dene';

  @override
  String get kvkkSurumDegisti => 'Metin güncellendi; lütfen yeni metni okuyun.';

  @override
  String get kvkkIzinBaslik => 'Bana özel kampanya ve teklifler';

  @override
  String get kvkkIzinAciklama =>
      'Tamamen isteğe bağlıdır; onaylamadan devam edebilirsiniz. İstediğiniz zaman Ayarlar\'dan değiştirebilirsiniz.';

  @override
  String get kvkkIzinEposta => 'E-posta almak istiyorum';

  @override
  String get kvkkIzinSms => 'SMS almak istiyorum';

  @override
  String get kvkkIzinArama => 'Aranmak istiyorum';

  @override
  String get kvkkIzinKaydedilemedi => 'Tercih kaydedilemedi.';

  @override
  String get kvkkAyarlarBaslik => 'İzinler ve Aydınlatma Metni';

  @override
  String get kvkkMetniGoruntule => 'Aydınlatma metnini görüntüle';

  @override
  String get anketBaslik => 'Anketler';

  @override
  String get anketYok => 'Şu an açık anket yok.';

  @override
  String get anketKapali => 'Kapandı';

  @override
  String get anketOyVerdiniz => 'Oyunuz alındı';

  @override
  String get anketOyVer => 'Oy ver';

  @override
  String anketToplamOy(int sayi) {
    return '$sayi oy';
  }

  @override
  String anketOyHatasi(String hata) {
    return 'Oy gönderilemedi: $hata';
  }

  @override
  String get anketSonucKapali => 'Sonuçlar anket kapanınca görünür.';

  @override
  String get modulAnketler => 'Anketler';

  @override
  String get hesapSilBolum => 'Hesap';

  @override
  String get hesapSilBaslik => 'Hesabımı sil';

  @override
  String get hesapSilAlt =>
      'Hesabınızı ve kişisel verilerinizi kalıcı olarak silin';

  @override
  String get hesapSilOnayBaslik => 'Hesabınızı silmek istiyor musunuz?';

  @override
  String get hesapSilOnayGovde =>
      'Adınız, telefonunuz, e-postanız ve cihaz kayıtlarınız silinir; hesabınıza bir daha giriş yapamazsınız. Aidat ve ödeme kayıtları yasal saklama yükümlülüğü nedeniyle silinemez; bu kayıtlar adınızla değil, anonim olarak saklanmaya devam eder.';

  @override
  String get hesapSilParolaEtiket => 'Parolanız';

  @override
  String get hesapSilParolaAciklama =>
      'Güvenlik için parolanızı yeniden girin.';

  @override
  String get hesapSilOnayla => 'Hesabımı kalıcı olarak sil';

  @override
  String get hesapSilSonucSilindi => 'Hesabınız silindi.';

  @override
  String get hesapSilSonucAnonim =>
      'Hesabınız silindi. Yasal olarak saklanması gereken kayıtlar anonim hâle getirildi.';

  @override
  String get hesapSilParolaGerekli => 'Devam etmek için parolanızı girin.';

  @override
  String get hesapSilSiliniyor => 'Siliniyor...';

  @override
  String get ayarlarHukuki => 'Yasal';

  @override
  String get ayarlarGizlilik => 'Gizlilik Politikası';

  @override
  String get ayarlarKosullar => 'Kullanım Koşulları';

  @override
  String get ayarlarBelgeAcilamadi =>
      'Sayfa açılamadı. İnternet bağlantınızı kontrol edin.';

  @override
  String get demoSimuleOkutma => 'Simüle okutma';

  @override
  String demoSimuleOkutmaBasarili(String nokta) {
    return 'Simüle okutma kaydedildi: $nokta';
  }

  @override
  String get demoSimuleOkutmaHata => 'Simüle okutma yapılamadı.';

  @override
  String get denetciWebBaslik => 'Denetim ekranları web\'de';

  @override
  String denetciWebGovde(String adres) {
    return 'Denetim raporları ve mali gözetim masaüstü için tasarlandı. Bilgisayarınızdan $adres adresine girin.';
  }

  @override
  String get denetciWebKopyala => 'Adresi kopyala';

  @override
  String get modulVardiyalar => 'Vardiyalar';

  @override
  String get izgaraDuzenleBaslik => 'Ana ekranı düzenle';

  @override
  String izgaraDuzenleAciklama(int enCok) {
    return 'Sık kullandığınız $enCok bölümü seçin.';
  }

  @override
  String get izgaraSifirla => 'Varsayılana dön';

  @override
  String get izgaraKaydet => 'Kaydet';

  @override
  String izgaraSecim(int secili, int enCok) {
    return '$secili/$enCok seçili';
  }

  @override
  String izgaraTavanUyarisi(int enCok) {
    return 'Tavana ulaştınız. Yeni bir bölüm eklemek için önce birini çıkarın ($enCok karo).';
  }

  @override
  String get dilSeciciBaslik => 'Dil';

  @override
  String get talepGeriAl => 'Geri Al';

  @override
  String get talepGeriAlOnay =>
      'Bu talebi geri almak istiyor musunuz? Geri alınan talep yönetime iletilmez ve bu işlem geri alınamaz.';

  @override
  String get talepGeriAlindi => 'Talep geri alındı';

  @override
  String get talepDurumGeriAlindi => 'Geri Alındı';

  @override
  String get sikayetGeriAl => 'Şikayeti geri al';

  @override
  String get sikayetGeriAlindi => 'Şikayet geri alındı';

  @override
  String get izinDevam => 'Devam';

  @override
  String get izinKonumBaslik => 'Konum izni neden gerekli?';

  @override
  String get izinKonumGovde =>
      'Devriye noktasını okuttuğunuzda, turun gerçekten sahada yapıldığını doğrulamak için o anki konumunuz kaydedilir. Konumunuz YALNIZCA okutma anında alınır; uygulama sizi arka planda takip etmez.';

  @override
  String get izinKameraBaslik => 'Kamera izni neden gerekli?';

  @override
  String get izinKameraGovde =>
      'Talep veya arıza bildirirken fotoğraf ekleyebilmeniz için kamera kullanılır. Fotoğraf yalnızca siz çektiğinizde alınır ve tesis yönetimine iletilir.';

  @override
  String get girisKodlaBaslik => 'Parolam yok, kodla giriş yap';

  @override
  String get girisKodlaAciklama =>
      'Telefonunuza altı haneli bir doğrulama kodu göndereceğiz.';

  @override
  String get girisKoduGonder => 'Kod gönder';

  @override
  String get girisKodAlani => 'Doğrulama kodu';
}
