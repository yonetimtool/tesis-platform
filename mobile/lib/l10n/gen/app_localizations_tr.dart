// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get ortakKaydet => 'Kaydet';

  @override
  String sayacBekliyor(int n) {
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
  String ortakZorunluAlan(String alan) {
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
  String kameraUrlHataHttp(String tur) {
    return '$tur yayın adresi http:// veya https:// ile başlamalı';
  }

  @override
  String get kameraUrlHataRtsp => 'RTSP yayın adresi rtsp:// ile başlamalı';

  @override
  String get kameraSilBaslik => 'Kamerayı sil';

  @override
  String kameraSilOnay(String ad) {
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
  String kameraTurEtiket(String tur) {
    return 'Tür: $tur';
  }

  @override
  String get kameraRtspBilgi =>
      'RTSP yayınlar şu an uygulama içinde oynatılamıyor. Kayıt sistemde tutuluyor; oynatma desteği ileride eklenecek.';

  @override
  String get kameraSeritBaslik => 'Canlı Kamera';
}
