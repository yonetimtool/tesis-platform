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
  String devriyeNoktaSayaci(Object beklenen, Object okutulan) {
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
  String sureSaatDakika(Object dakika, Object saat) {
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
  String devriyeNoktaOkutuldu(Object beklenen, Object okutulan) {
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
}
