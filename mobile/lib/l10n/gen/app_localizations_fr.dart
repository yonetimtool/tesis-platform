// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get cipYeni => 'Nouveau';

  @override
  String get cipAktif => 'En cours';

  @override
  String get bolumVardiyaDurumu => 'État des services';

  @override
  String get bolumSonHareketler => 'Activité récente';

  @override
  String get bolumHizliOzet => 'Aperçu rapide';

  @override
  String get bolumDuyurular => 'Annonces';

  @override
  String get bolumSiteKurallari => 'Règlement du site';

  @override
  String get bolumEtkinlikler => 'Événements';

  @override
  String get bolumOdemeAidat => 'Paiements et charges';

  @override
  String get bolumTumModuller => 'Tous les modules';

  @override
  String get kartVardiyaDurum => 'Service';

  @override
  String get kartKargo => 'Colis';

  @override
  String get kartZiyaretci => 'Visiteurs';

  @override
  String get kartAracPlaka => 'Véhicules';

  @override
  String get kartIhlaller => 'Infractions';

  @override
  String get kartGorevlerim => 'Mes tâches';

  @override
  String get kartDemirbas => 'Matériel';

  @override
  String get kartTurlarim => 'Mes rondes';

  @override
  String get kartTalepAriza => 'Demandes';

  @override
  String get kartZiyaretciler => 'Visiteurs';

  @override
  String get kartKargolarim => 'Mes colis';

  @override
  String get kartAidatBilgileri => 'Charges';

  @override
  String get kartGurultuSikayeti => 'Plainte pour bruit';

  @override
  String get kartGeriBildirim => 'Retours';

  @override
  String get kartSikayetlerim => 'Mes plaintes';

  @override
  String get kartSiteRaporlari => 'Rapports du site';

  @override
  String get kartGorevler => 'Tâches';

  @override
  String get kartAidatDurumu => 'État des charges';

  @override
  String get kartOtoparkKullanimi => 'Utilisation du parking';

  @override
  String get kartSikayetler => 'Plaintes';

  @override
  String get kartRaporlar => 'Rapports';

  @override
  String get kartYonetici => 'Gestionnaire';

  @override
  String get kartGonderimKuyrugu => 'File d\'envoi';

  @override
  String get etiketAylikOzet => 'Résumé mensuel';

  @override
  String get etiketDevriye => 'Ronde';

  @override
  String get etiketKurallar => 'Règles';

  @override
  String get etiketIletisim => 'Contact';

  @override
  String sayacAktif(num n) {
    return '$n en cours';
  }

  @override
  String sayacIceride(num n) {
    return '$n à l\'intérieur';
  }

  @override
  String sayacGiris(num n) {
    return '$n entrées';
  }

  @override
  String sayacYeni(num n) {
    return '$n nouveaux';
  }

  @override
  String sayacAcik(num n) {
    return '$n ouverts';
  }

  @override
  String sayacZimmetli(num n) {
    return '$n en prêt';
  }

  @override
  String sayacKayit(num n) {
    return '$n enregistrements';
  }

  @override
  String sayacYaklasan(num n) {
    return '$n à venir';
  }

  @override
  String sayacDaire(num n) {
    return '$n logements';
  }

  @override
  String sayacArac(num n) {
    return '$n véhicules';
  }

  @override
  String sayacGorevli(num n) {
    return '$n agents';
  }

  @override
  String sayacBekleyen(num n) {
    return '$n en attente';
  }

  @override
  String get ozetToplamDaire => 'Total des logements';

  @override
  String get ozetToplamTahsilat => 'Total encaissé';

  @override
  String get ozetTahsilatOrani => 'Taux de recouvrement';

  @override
  String get ozetOtoparkDoluluk => 'Occupation du parking';

  @override
  String get ozetTumSite => 'Tout le site';

  @override
  String get ozetBuAy => 'Ce mois';

  @override
  String get ozetSuAn => 'Maintenant';

  @override
  String otoparkDoluKapasite(Object dolu, Object kapasite) {
    return '$dolu / $kapasite';
  }

  @override
  String yuzdeDeger(Object oran) {
    return '$oran %';
  }

  @override
  String anaSelam(Object ad) {
    return 'Bonjour, $ad';
  }

  @override
  String get anaYoneticiPaneli => 'Espace gestionnaire';

  @override
  String anaDaireAltBaslik(Object daireler, Object rol) {
    return 'Logement $daireler  •  $rol';
  }

  @override
  String get anaDun => 'Hier';

  @override
  String get anaOnline => 'En ligne';

  @override
  String get anaVardiyaAktif => 'En cours';

  @override
  String get anaVardiyaPlanlandi => 'Planifié';

  @override
  String get anaEtkinlikSuruyor => 'En cours';

  @override
  String get anaEtkinlikYaklasan => 'À venir';

  @override
  String get anaOdendi => 'Payé';

  @override
  String get anaOdenmedi => 'Non payé';

  @override
  String get anaBorcVar => 'Solde dû';

  @override
  String get anaBorcYok => 'Aucun solde';

  @override
  String get anaBuAykiAidat => 'Charges du mois';

  @override
  String anaSonOdemeTarih(Object tarih) {
    return 'Dernier paiement : $tarih';
  }

  @override
  String get anaGelecekOdeme => 'Prochain paiement';

  @override
  String get anaGecmisOdemeler => 'Historique des paiements';

  @override
  String get anaAidatKaydiYok => 'Aucun enregistrement de charges';

  @override
  String get anaBildirimlerYakinda => 'Notifications bientôt disponibles';

  @override
  String get anaBildirimlerRolYok =>
      'Les notifications ne sont pas disponibles pour ce rôle';

  @override
  String get anaRaporlarYakinda => 'Rapports bientôt disponibles';

  @override
  String get sekmeAnaSayfa => 'Accueil';

  @override
  String get sekmeBildirimler => 'Notifications';

  @override
  String get sekmeRaporlar => 'Rapports';

  @override
  String get sekmeAyarlar => 'Paramètres';

  @override
  String get kabukProfil => 'Profil';

  @override
  String get kabukCikisYap => 'Se déconnecter';

  @override
  String get fabOlayBildir => 'Signaler un incident';

  @override
  String get fabTalepBildir => 'Demande / signalement';

  @override
  String get fabTalepArizaBildir => 'Signaler une demande ou une panne';

  @override
  String get fabRezervasyonYap => 'Réserver';

  @override
  String get fabDuyuruYayinla => 'Publier une annonce';

  @override
  String get fabGorevOlustur => 'Créer une tâche';

  @override
  String get fabDestekTalebi => 'Demande de support';

  @override
  String get modulDuyurular => 'Annonces';

  @override
  String get modulTurlarim => 'Mes rondes';

  @override
  String get modulDevriyeTakibi => 'Suivi des rondes';

  @override
  String get modulGorevlerim => 'Mes tâches';

  @override
  String get modulGorevYonetimi => 'Gestion des tâches';

  @override
  String get modulDemirbas => 'Matériel';

  @override
  String get modulNfcOkutma => 'Lecture NFC';

  @override
  String get modulGonderimKuyrugu => 'File d\'envoi';

  @override
  String get modulAylikRaporlar => 'Rapports mensuels';

  @override
  String get modulButce => 'Budget';

  @override
  String get modulFinansalOzet => 'Résumé financier';

  @override
  String get modulSeffaflik => 'Transparence';

  @override
  String get modulSiteButcesi => 'Budget du site';

  @override
  String get modulAidatim => 'Mes charges';

  @override
  String get modulSikayetOneri => 'Plainte / suggestion';

  @override
  String get modulZiyaretciler => 'Visiteurs';

  @override
  String get modulKargo => 'Colis';

  @override
  String get modulGoruntulemeIzni => 'Autorisation d\'accès';

  @override
  String get modulRezervasyon => 'Réservation';

  @override
  String get modulEtkinlikler => 'Événements';

  @override
  String get modulSiteKurallari => 'Règlement du site';

  @override
  String get modulDisHizmetler => 'Services externes';

  @override
  String get modulEntegrasyonlar => 'Intégrations';

  @override
  String get modulPersonel => 'Personnel de terrain';

  @override
  String get modulSakinler => 'Résidents';

  @override
  String get modulBinaYapisi => 'Structure du bâtiment';

  @override
  String get modulSikayetHaritasi => 'Carte des plaintes';

  @override
  String get modulSikayetlerim => 'Mes plaintes';

  @override
  String get modulYoneticiIletisim => 'Contact gestionnaire';

  @override
  String get ortakKaydet => 'Enregistrer';

  @override
  String sayacBekliyor(num n) {
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
  String ortakZorunluAlan(Object alan) {
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
  String kameraUrlHataHttp(Object tur) {
    return 'L\'adresse du flux $tur doit commencer par http:// ou https://';
  }

  @override
  String get kameraUrlHataRtsp =>
      'L\'adresse du flux RTSP doit commencer par rtsp://';

  @override
  String get kameraSilBaslik => 'Supprimer la caméra';

  @override
  String kameraSilOnay(Object ad) {
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
  String kameraTurEtiket(Object tur) {
    return 'Type : $tur';
  }

  @override
  String get kameraRtspBilgi =>
      'Les flux RTSP ne sont pas lisibles dans l\'application pour le moment. L\'enregistrement reste dans le système ; la lecture sera ajoutée plus tard.';

  @override
  String get kameraSeritBaslik => 'Caméra en direct';
}
