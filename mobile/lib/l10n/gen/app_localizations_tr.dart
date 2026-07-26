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
}
