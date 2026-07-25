// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get ortakKaydet => 'Enregistrer';

  @override
  String sayacBekliyor(int n) {
    return '$n en attente';
  }

  @override
  String get ortakKaydediliyor => 'Enregistrement...';

  @override
  String get ortakVazgec => 'Annuler';

  @override
  String get ortakSil => 'Supprimer';

  @override
  String get ortakDuzenle => 'Modifier';

  @override
  String get ortakEkle => 'Ajouter';

  @override
  String get ortakTamam => 'OK';

  @override
  String get ortakKapat => 'Fermer';

  @override
  String get ortakTumunuGor => 'Tout voir';

  @override
  String get ortakYuklenemedi => 'Chargement impossible';

  @override
  String get ortakYenidenDene => 'Réessayer';

  @override
  String get ortakYakinda => 'Bientôt';

  @override
  String get ortakBolumYakinda => 'Cette section arrive bientôt';

  @override
  String get ortakBeklenmeyenHata =>
      'Une erreur inattendue s\'est produite. Veuillez réessayer.';

  @override
  String ortakZorunluAlan(String alan) {
    return '$alan est obligatoire';
  }

  @override
  String get ayarlarBaslik => 'Paramètres';

  @override
  String get ayarlarTesis => 'Site';

  @override
  String get ayarlarYonetim => 'Gestion';

  @override
  String get ayarlarGorunum => 'Apparence';

  @override
  String get ayarlarTema => 'Thème';

  @override
  String get ayarlarTemaSistem => 'Système';

  @override
  String get ayarlarTemaAcik => 'Clair';

  @override
  String get ayarlarTemaKoyu => 'Sombre';

  @override
  String get ayarlarTemaAciklama =>
      'Le thème sombre s\'applique à tous les écrans ; « Système » suit le réglage de l\'appareil.';

  @override
  String get ayarlarTesisAdi => 'Nom du site';

  @override
  String get ayarlarTesisAdiAciklama =>
      'Le nom affiché sur l\'écran d\'accueil et dans les rapports.';

  @override
  String get ayarlarTesisAdiGuncellendi => 'Nom du site mis à jour';

  @override
  String get ayarlarKameralar => 'Caméras';

  @override
  String get ayarlarKameralarAlt =>
      'Ajouter, modifier et supprimer des caméras';

  @override
  String get ayarlarDil => 'Langue / Language';

  @override
  String get dilSecBaslik => 'Langue de l\'application';

  @override
  String get kameraBaslik => 'Caméras';

  @override
  String get kameraEkle => 'Ajouter une caméra';

  @override
  String get kameraYeni => 'Nouvelle caméra';

  @override
  String get kameraDuzenleBaslik => 'Modifier la caméra';

  @override
  String get kameraAd => 'Nom';

  @override
  String get kameraKonum => 'Emplacement (facultatif)';

  @override
  String get kameraTur => 'Type';

  @override
  String get kameraUrl => 'URL du flux';

  @override
  String get kameraAktif => 'Active';

  @override
  String get kameraAktifAlt => 'Désactivée, elle n\'apparaît dans aucune liste';

  @override
  String get kameraSakinGorebilir => 'Visible par les résidents';

  @override
  String get kameraSakinGorebilirAlt =>
      'Désactivée, seuls la gestion et la sécurité voient la caméra';

  @override
  String get kameraRtspFormUyari =>
      'Les flux RTSP ne peuvent pas encore être lus dans l\'application. L\'enregistrement est conservé ; la lecture sera ajoutée plus tard.';

  @override
  String get kameraUrlZorunlu => 'L\'adresse du flux est obligatoire';

  @override
  String kameraUrlHataHttp(String tur) {
    return 'L\'adresse du flux $tur doit commencer par http:// ou https://';
  }

  @override
  String get kameraUrlHataRtsp =>
      'L\'adresse du flux RTSP doit commencer par rtsp://';

  @override
  String get kameraSilBaslik => 'Supprimer la caméra';

  @override
  String kameraSilOnay(String ad) {
    return 'Supprimer « $ad » ?';
  }

  @override
  String get kameraBosYonetim =>
      'Aucune caméra. Ajoutez-en une en bas à droite.';

  @override
  String get kameraBosSakin => 'Aucune caméra ne vous est accessible.';

  @override
  String get kameraListeHata => 'Impossible de charger les caméras.';

  @override
  String get kameraCanli => 'En direct';

  @override
  String get kameraOynatilamiyor => 'Lecture impossible';

  @override
  String get kameraYayinAcilamadi => 'Le flux n\'a pas pu être ouvert';

  @override
  String get kameraYayinAcilamadiAlt =>
      'La caméra est peut-être éteinte ou le réseau n\'atteint pas le flux.';

  @override
  String kameraTurEtiket(String tur) {
    return 'Type : $tur';
  }

  @override
  String get kameraRtspBilgi =>
      'Les flux RTSP ne sont pas lisibles dans l\'application pour le moment. L\'enregistrement reste dans le système ; la lecture sera ajoutée plus tard.';

  @override
  String get kameraSeritBaslik => 'Caméra en direct';
}
