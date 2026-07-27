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
}
