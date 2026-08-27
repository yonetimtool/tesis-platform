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
  String get sekmeSeffaflik => 'Transparence';

  @override
  String get sekmeGorevlerim => 'Mes tâches';

  @override
  String get sekmeAyarlar => 'Paramètres';

  @override
  String get kabukGrupGuvenlik => 'Sécurité';

  @override
  String get kabukGrupTesis => 'Installation';

  @override
  String get kabukGrupFinans => 'Finances';

  @override
  String get kabukGrupIletisim => 'Communication';

  @override
  String get kabukGrupTanimlar => 'Définitions';

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
  String get kameraKareYok => 'Image indisponible';

  @override
  String get kameraUrlWebSayfasi =>
      'Il s’agit d’une adresse de page web. L’application ne lit que les URL de flux directes : .m3u8 (HLS) ou .mp4.';

  @override
  String get kameraKaynakYardim =>
      'Seules les URL média directes sont lues : HLS (.m3u8) et MP4. Les pages web (YouTube, Vimeo, pages de visualisation municipales) ne peuvent pas être lues. Le RTSP est enregistré mais nécessite une passerelle HLS pour être lu.';

  @override
  String get kameraSnapshot => 'Adresse de l’instantané';

  @override
  String get kameraSnapshotAlt =>
      'Facultatif. Si renseigné, la liste des caméras affiche une image fixe en direct (une image JPEG).';

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

  @override
  String anaKarsilama(String ad) {
    return 'Bonjour, $ad';
  }

  @override
  String get gorevKategorilerTooltip => 'Catégories';

  @override
  String get gorevYeni => 'Nouvelle tâche';

  @override
  String get gorevOlusturuldu => 'Tâche créée ✓';

  @override
  String get gorevListesiYetkiYok =>
      'Vous n\'êtes pas autorisé à voir la liste des tâches. Cet écran est ouvert aux rôles nettoyage et sécurité.';

  @override
  String get gorevBuFiltredeYok => 'Aucune tâche active avec ce filtre.';

  @override
  String get gorevCipBanaAtanan => 'Qui m\'est attribué';

  @override
  String get gorevCipTumGorevler => 'Toutes les tâches';

  @override
  String get gorevCipTumu => 'Tous';

  @override
  String get gorevKategoriDiger => 'Autre';

  @override
  String gorevPlanlanan(Object zaman) {
    return 'Prévu : $zaman';
  }

  @override
  String get gorevSanaAtanmis => 'Attribué à vous';

  @override
  String get gorevFotoZorunlu => 'Photo obligatoire';

  @override
  String get gorevTamamlandiZatenKayitli => 'Terminé ✓ (déjà enregistré)';

  @override
  String get gorevTamamlandiBuOturumda => 'Terminé ✓ (dans cette session)';

  @override
  String get gorevIslemleriTooltip => 'Actions sur la tâche';

  @override
  String get gorevTakipGorunumu => 'Vue de suivi';

  @override
  String get gorevTakipGorunumuAlt =>
      'L\'achèvement est effectué par le personnel de terrain (sécurité / agent technique). Cet écran sert au suivi.';

  @override
  String get gorevGonderiliyor => 'Envoi en cours...';

  @override
  String get gorevTamamla => 'Terminer';

  @override
  String get gorevGuncellendi => 'Tâche mise à jour ✓';

  @override
  String get gorevSilinsinMi => 'Supprimer la tâche ?';

  @override
  String get gorevSilindi => 'Tâche supprimée ✓';

  @override
  String get gorevNfcAciklama =>
      'Cette tâche est vérifiée par NFC : scannez le tag au point de la tâche avant de terminer.';

  @override
  String get gorevAdim1Etiket => '1. Scannez le tag';

  @override
  String gorevOkundu(Object uid) {
    return 'Lu : $uid';
  }

  @override
  String get gorevEtiketBekleniyor => 'En attente du tag...';

  @override
  String get gorevYenidenOkut => 'Scanner à nouveau';

  @override
  String get gorevEtiketiOkut => 'Scanner le tag';

  @override
  String get gorevAdim2Foto => '2. Preuve photo';

  @override
  String get gorevAdim2FotoOpsiyonel => '2. Preuve photo (facultatif)';

  @override
  String get gorevYukleniyorNokta => 'Téléversement...';

  @override
  String get gorevYuklendi => 'Téléversé ✓';

  @override
  String get gorevKamera => 'Appareil photo';

  @override
  String get gorevYenidenCek => 'Reprendre';

  @override
  String get gorevGaleridenSec => 'Choisir dans la galerie';

  @override
  String get gorevTekrarYukle => 'Téléverser à nouveau';

  @override
  String get gorevKaldir => 'Retirer';

  @override
  String get gorevAdim3Not => '3. Note (facultatif)';

  @override
  String get gorevNotIpucu => 'Ex. conteneurs à déchets vidés';

  @override
  String get gorevZatenKayitliydi =>
      'Cet achèvement était déjà enregistré (renvoi — aucun doublon créé).';

  @override
  String get gorevTamamlandiKayit => 'Tâche terminée — enregistrement créé.';

  @override
  String gorevZaman(Object zaman) {
    return 'Heure : $zaman';
  }

  @override
  String get gorevFotoKanitiVar => 'preuve photo jointe';

  @override
  String get gorevNfcDogrulandi => 'NFC vérifié';

  @override
  String get gorevYeniTamamlamaBaslat => 'Démarrer un nouvel achèvement';

  @override
  String get gorevDuzenleBaslik => 'Modifier la tâche';

  @override
  String get gorevKategoriSilinmis => 'Catégorie (supprimée)';

  @override
  String get gorevAtananListedeDegil =>
      'Utilisateur assigné (absent de la liste)';

  @override
  String get gorevTipleriYukleniyor => 'Chargement des types de tâches...';

  @override
  String get gorevTipi => 'Type de tâche';

  @override
  String get gorevTipiYokUyari =>
      'Vous n\'avez pas encore défini de type de tâche. Vous pouvez ajouter les vôtres depuis l\'écran \"Catégories\" ci-dessus ; \"Autre\" est utilisé pour l\'instant.';

  @override
  String get gorevAdi => 'Nom de la tâche';

  @override
  String get gorevAdiZorunlu => 'Le nom de la tâche est obligatoire';

  @override
  String get gorevAciklamaOpsiyonel => 'Description (facultatif)';

  @override
  String get gorevPersonelYukleniyor =>
      'Chargement de la liste du personnel...';

  @override
  String get gorevAtananPersonel => 'Personnel assigné';

  @override
  String get gorevAtanmamisHavuz => '— non attribué (tâche commune) —';

  @override
  String gorevPersonelAlinamadi(Object hata) {
    return 'Impossible de charger la liste du personnel : $hata';
  }

  @override
  String get gorevKontrolNoktasiOpsiyonel =>
      'Point de contrôle (NFC) — facultatif';

  @override
  String get gorevKontrolNoktasiYardim =>
      'Si lié, la tâche se termine en scannant le NFC';

  @override
  String get gorevNfcYok => '— sans NFC —';

  @override
  String get gorevPeriyotDakika => 'Période en minutes (facultatif)';

  @override
  String get gorevPeriyotYardim =>
      'Pour les tâches récurrentes ; vide = ponctuel';

  @override
  String get gorevPozitifSayi => 'Saisissez un entier positif';

  @override
  String get gorevFotoKanitiZorunlu => 'Preuve photo obligatoire';

  @override
  String get gorevFotoKanitiZorunluAlt =>
      'L\'achèvement n\'est pas accepté sans photo';

  @override
  String get gorevPasifAciklama =>
      'Une tâche inactive n\'apparaît pas dans la liste';

  @override
  String get gorevKategorileriBaslik => 'Catégories de tâches';

  @override
  String get gorevKategoriYeni => 'Nouvelle catégorie';

  @override
  String get gorevKategoriAdi => 'Nom de la catégorie';

  @override
  String get gorevKategoriAdiIpucu => 'ex. Entretien de la piscine';

  @override
  String gorevKategoriEklendi(Object ad) {
    return '\"$ad\" ajoutée';
  }

  @override
  String gorevKategoriEklenemedi(Object hata) {
    return 'Ajout impossible : $hata';
  }

  @override
  String get gorevKategoriSilinsinMi => 'Supprimer la catégorie ?';

  @override
  String gorevKategoriSilOnay(Object ad) {
    return '\"$ad\" sera désactivée ; l\'historique des tâches existantes est conservé, mais elle ne pourra plus être choisie pour de nouvelles tâches.';
  }

  @override
  String gorevKategoriSilindi(Object ad) {
    return '\"$ad\" supprimée';
  }

  @override
  String gorevKategoriSilinemedi(Object hata) {
    return 'Suppression impossible : $hata';
  }

  @override
  String gorevKategoriListeAlinamadi(Object hata) {
    return 'Impossible de charger la liste : $hata';
  }

  @override
  String get gorevKategoriYokBos =>
      'Aucune catégorie pour l\'instant. Ajoutez-en une avec \"Nouvelle catégorie\" afin de pouvoir la choisir lors de la création d\'une tâche.';

  @override
  String get gorevOncelikDusuk => 'Faible';

  @override
  String get gorevOncelikOrta => 'Moyenne';

  @override
  String get gorevOncelikYuksek => 'Élevée';

  @override
  String get gorevOncelik => 'Priorité';

  @override
  String get gorevTaleptenGeldi => 'Issu d\'une demande';

  @override
  String get gorevBagliTalep => 'Demande liée';

  @override
  String gorevDaireEtiket(Object daire) {
    return 'Logement $daire';
  }

  @override
  String get talepDurumAcik => 'Ouvert';

  @override
  String get talepDurumIsEmri => 'Ordre de travail';

  @override
  String get talepDurumCozuldu => 'Résolu';

  @override
  String get talepDurumReddedildi => 'Rejeté';

  @override
  String get gorevEtiketOkunamadi => 'Impossible de lire le tag.';

  @override
  String get gorevFotoOnlineGerekli =>
      'Une connexion Internet est nécessaire pour téléverser une photo (l\'adresse de téléversement est éphémère). Dès le retour du réseau, utilisez \"Téléverser à nouveau\".';

  @override
  String gorevFotoAlinamadi(Object hata) {
    return 'Impossible d\'obtenir la photo : $hata';
  }

  @override
  String get gorevFotoOnlineGerekliKisa =>
      'Une connexion Internet est nécessaire pour téléverser une photo.';

  @override
  String get gorevFotoZorunluUyari =>
      'UNE PREUVE PHOTO EST OBLIGATOIRE pour cette tâche. Prenez et téléversez une photo avant de terminer.';

  @override
  String get gorevFotoHenuzYuklenmedi =>
      'La photo n\'est pas encore téléversée. Attendez la fin du téléversement, essayez \"Téléverser à nouveau\" ou retirez la photo.';

  @override
  String get gorevTamamlamaOfflineUyari =>
      'L\'achèvement n\'a pas pu être envoyé — une connexion Internet est nécessaire. Dès le retour du réseau, appuyez de nouveau sur \"Terminer\" ; le même enregistrement ne sera pas dupliqué (la clé Idempotency-Key est fixe). L\'achèvement avec photo n\'est pas pris en charge hors ligne (limitation connue).';

  @override
  String get rolAdmin => 'Administrateur de la plateforme';

  @override
  String get rolYonetici => 'Gestionnaire du site';

  @override
  String get rolGuvenlik => 'Sécurité';

  @override
  String get rolTesisGorevlisi => 'Agent technique';

  @override
  String get rolSakin => 'Résident';

  @override
  String get rolBilinmeyen => 'Rôle inconnu';

  @override
  String get ortakOlustur => 'Créer';

  @override
  String get ortakGuncelle => 'Mettre à jour';

  @override
  String get ortakYenile => 'Rafraîchir';

  @override
  String get devriyeGonderimKuyruguTooltip => 'File d\'envoi';

  @override
  String get sekmeGecmis => 'Historique';

  @override
  String get devriyeYetkiYok =>
      'Vous n\'êtes pas autorisé pour les données de cet écran. Le suivi des rondes est ouvert au rôle sécurité (et gestionnaire).';

  @override
  String devriyeSonGuncelleme(Object saat) {
    return 'Dernière mise à jour : $saat (actualisation auto : 60 s)';
  }

  @override
  String get devriyeTuru => 'Ronde de patrouille';

  @override
  String devriyeBitisEtiket(Object saat) {
    return 'fin $saat';
  }

  @override
  String devriyePencere(Object baslangic, Object bitis) {
    return 'Créneau : $baslangic – $bitis';
  }

  @override
  String devriyeNoktaSayaci(Object okutulan, Object beklenen) {
    return '$okutulan/$beklenen points';
  }

  @override
  String get devriyeTumNoktalarOkutuldu =>
      'Tous les points scannés — la ronde s\'achève. ✓';

  @override
  String devriyeSunucudaOkutma(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          '$n scans sont enregistrés sur le serveur (des scans d\'autres appareils peuvent être inclus).',
      one:
          '$n scan est enregistré sur le serveur (des scans d\'autres appareils peuvent être inclus).',
    );
    return '$_temp0';
  }

  @override
  String get devriyeNoktaOkutNfc => 'Scanner un point (NFC)';

  @override
  String get devriyeBugununDigerTurlari => 'Les autres rondes du jour';

  @override
  String get devriyeBugununTurlari => 'Les rondes du jour';

  @override
  String get devriyeDurumTamamlandi => 'Terminée';

  @override
  String get devriyeDurumKacirildi => 'Manquée';

  @override
  String get devriyeDurumSimdiAktif => 'Active maintenant';

  @override
  String get devriyeDurumYaklasan => 'À venir';

  @override
  String get devriyeDurumBitti => 'Terminée';

  @override
  String get devriyeDurumBekliyor => 'En attente';

  @override
  String get devriyeDurumBilinmiyor => 'Inconnu';

  @override
  String get devriyeDurumSuresiGecti => 'Délai dépassé';

  @override
  String get devriyeBugunTurYok => 'Aucune ronde prévue aujourd\'hui.';

  @override
  String get devriyeNoktaListesiYok =>
      'La liste des points de ce plan n\'a pas pu être chargée ou aucun point n\'est affecté au plan.';

  @override
  String get devriyeKontrolNoktalari => 'Points de contrôle';

  @override
  String get devriyeNoktaDurumAciklama =>
      'Les statuts des points viennent du serveur ; les scans de tous les agents apparaissent avec ✓. Les lignes « En cours d\'envoi » sont des scans de cet appareil non encore envoyés.';

  @override
  String devriyeNoktaAdiYedek(Object kisaId) {
    return 'Point $kisaId';
  }

  @override
  String get devriyeOkutuldu => 'Scanné ✓';

  @override
  String devriyeOkutulduZamanli(Object saat) {
    return 'Scanné ✓ · $saat';
  }

  @override
  String get devriyeOkutulduGonderiliyor =>
      'Scanné ✓ — en cours d\'envoi (en file)';

  @override
  String get devriyePencereSuresiDoldu => 'Le créneau est expiré.';

  @override
  String devriyeKalanSure(Object sure) {
    return 'Temps restant : $sure';
  }

  @override
  String sureSaatDakika(Object saat, Object dakika) {
    return '$saat h $dakika min';
  }

  @override
  String sureDakikaSaniye(Object dakika, Object saniye) {
    return '$dakika min $saniye s';
  }

  @override
  String sureSaniye(Object saniye) {
    return '$saniye s';
  }

  @override
  String get devriyeGecmisYetkiYok =>
      'Vous n\'êtes pas autorisé pour l\'historique des rondes. Cette liste est ouverte aux rôles sécurité et gestionnaire.';

  @override
  String get devriyeGecmisBos =>
      'Aucun créneau de ronde enregistré pour l\'instant.';

  @override
  String get devriyeOzetToplam => 'Total';

  @override
  String get devriyePlanlariBaslik => 'Plans de patrouille';

  @override
  String get devriyePlanEkle => 'Ajouter un plan';

  @override
  String get devriyePlanlarListelenemedi => 'Impossible de lister les plans.';

  @override
  String devriyePlanAralik(Object baslangic, Object bitis, Object dakika) {
    return '$baslangic–$bitis · toutes les $dakika min';
  }

  @override
  String get devriyePasif => 'Inactif';

  @override
  String get devriyePlanSilinsinMi => 'Supprimer le plan ?';

  @override
  String devriyePlanSilOnay(Object ad) {
    return 'Le plan de patrouille \"$ad\" sera supprimé.';
  }

  @override
  String get devriyePlanSilindi => 'Plan supprimé ✓';

  @override
  String get devriyePlanDuzenleBaslik => 'Modifier le plan de patrouille';

  @override
  String get devriyePlanYeniBaslik => 'Nouveau plan de patrouille';

  @override
  String get devriyePlanAdi => 'Nom du plan';

  @override
  String get devriyePlanAdiIpucu => 'ex. Patrouille de nuit';

  @override
  String get devriyeAdZorunlu => 'Le nom est obligatoire';

  @override
  String devriyeBaslangicSaat(Object saat) {
    return 'Début $saat';
  }

  @override
  String devriyeBitisSaat(Object saat) {
    return 'Fin $saat';
  }

  @override
  String get devriyeTurSikligi => 'Fréquence des rondes (minutes)';

  @override
  String get devriyeTurSikligiYardim => 'ex. 60 = une ronde par heure';

  @override
  String get devriyeTurSikligiPozitif =>
      'La fréquence des rondes (min) doit être positive.';

  @override
  String get devriyeTumunuKaldir => 'Tout retirer';

  @override
  String get devriyeTumunuSec => 'Tout sélectionner';

  @override
  String get devriyeAktifNoktaYok =>
      'Aucun point de contrôle actif. Ajoutez-en d\'abord depuis « Points de contrôle ».';

  @override
  String devriyeUidEtiket(Object uid) {
    return 'UID : $uid';
  }

  @override
  String get devriyeKaydedilemedi => 'Échec de l\'enregistrement. Réessayez.';

  @override
  String get devriyePlanYokBos =>
      'Aucun plan de patrouille pour l\'instant.\nAjoutez-en un en bas à droite (heures + points).';

  @override
  String get devriyeTakibiBaslik => 'Suivi des patrouilles';

  @override
  String get sekmeBugun => 'Aujourd\'hui';

  @override
  String get sekmeTaramaGunlugu => 'Journal des scans';

  @override
  String get devriyeTakibiYetkiYok =>
      'Vous n\'êtes pas autorisé pour le suivi des patrouilles. Cet écran est ouvert aux rôles gestionnaire et sécurité.';

  @override
  String get devriyeBugunPencereYok =>
      'Aucun créneau de patrouille prévu aujourd\'hui.';

  @override
  String devriyeNoktaOkutuldu(Object okutulan, Object beklenen) {
    return '$okutulan/$beklenen points scannés';
  }

  @override
  String get devriyeTaramaGunluguAlinamadi =>
      'Impossible de charger le journal des scans.';

  @override
  String get devriyeGunOkutmaYok => 'Aucun scan pour ce jour.';

  @override
  String get devriyeImzali => 'signé ✓';

  @override
  String devriyeOkutmaBekliyor(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n scans en attente d\'envoi',
      one: '$n scan en attente d\'envoi',
    );
    return '$_temp0';
  }

  @override
  String get ortakIptal => 'Annuler';

  @override
  String get ortakNotOpsiyonel => 'Note (facultatif)';

  @override
  String get binaDuzenlemeBaslik => 'Structure du bâtiment';

  @override
  String get binaBlokTile => 'Bloc';

  @override
  String get binaBlokAtanmamis => 'Aucun bloc attribué';

  @override
  String binaBlokEtiket(Object ad) {
    return 'Bloc $ad';
  }

  @override
  String get binaSaltGoruntulemeAciklama =>
      'Structure du bâtiment (lecture seule). Touchez une tuile de bloc pour voir la répartition des étages et des logements.';

  @override
  String get binaDuzenlemeAciklama =>
      'Ajoutez un bloc, touchez la tuile et placez-y étages et logements. Chaque logement appartient à un bloc. La carte des plaintes reflète cette structure.';

  @override
  String binaDaireSayisi(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n logements',
      one: '$n logement',
    );
    return '$_temp0';
  }

  @override
  String get binaKayitsiz => 'non enregistré';

  @override
  String get binaBloksuzDairelerSalt =>
      'Logements non affectés à un bloc (lecture seule).';

  @override
  String binaBlokYerlesimSalt(Object ad) {
    return 'Bloc $ad — répartition des étages et logements (lecture seule).';
  }

  @override
  String get binaBloksuzUyari =>
      'Ces logements ne sont affectés à aucun bloc (anciens enregistrements). Ils sont affichés et peuvent être modifiés ou supprimés ; pour un nouveau logement, choisissez ou créez un bloc.';

  @override
  String binaBlokYerlesimYardim(Object ad) {
    return 'Bloc $ad — ajoutez des étages, puis des logements avec le bouton \"+\" de chaque étage. Les logements d\'un même étage sont alignés.';
  }

  @override
  String get binaKatEkle => 'Ajouter un étage';

  @override
  String get binaTopluDaireEkle => 'Ajout groupé de logements';

  @override
  String get binaBloktaDaireYok =>
      'Aucun logement dans ce bloc pour l\'instant.';

  @override
  String get binaKatYokBos =>
      'Aucun étage pour l\'instant. Commencez par « Ajouter un étage », puis ajoutez des logements avec le « + » de l\'étage.';

  @override
  String get binaKatYok => 'Sans étage';

  @override
  String binaKatEtiket(Object kat) {
    return 'Étage $kat';
  }

  @override
  String binaBlokDuzenleBaslik(Object ad) {
    return 'Bloc $ad — modifier';
  }

  @override
  String get binaBloguSil => 'Supprimer le bloc';

  @override
  String binaBloguSilAlt(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Supprimé avec $n logements (confirmation requise)',
      one: 'Supprimé avec $n logement (confirmation requise)',
    );
    return '$_temp0';
  }

  @override
  String binaBlokSilinsinMi(Object ad) {
    return 'Supprimer le bloc $ad ?';
  }

  @override
  String binaBlokVeDaireSilindi(Object ad, Object n) {
    return 'Bloc $ad et $n logements supprimés.';
  }

  @override
  String binaBlokSilindi(Object ad) {
    return 'Bloc $ad supprimé.';
  }

  @override
  String binaBlokSilinemedi(Object hata) {
    return 'Impossible de supprimer le bloc : $hata';
  }

  @override
  String get binaBlokSilinemediGenel =>
      'Impossible de supprimer le bloc. Veuillez réessayer.';

  @override
  String binaKaliciSilmeUyari(Object n) {
    return 'Ce bloc et ses $n logements seront supprimés DÉFINITIVEMENT avec leurs enregistrements de charges, visiteurs, colis, réservations et plaintes. Cette action est irréversible.';
  }

  @override
  String get binaOnayIcinBlokAdi => 'Saisissez le nom du bloc pour confirmer';

  @override
  String binaSilNDaire(Object n) {
    return 'Supprimer ($n logements)';
  }

  @override
  String get binaBlokEtiketiGerekli =>
      'Un libellé de bloc est requis (ex. A, B1).';

  @override
  String get binaBlokEtiketiZatenVar => 'Ce libellé de bloc existe déjà.';

  @override
  String get binaBlokDuzenle => 'Modifier le bloc';

  @override
  String get binaYeniBlok => 'Nouveau bloc';

  @override
  String get binaBlokEtiketi => 'Libellé du bloc';

  @override
  String get binaBlokEtiketiYardim =>
      'Alphanumérique court (ex. A, B1) — sans tiret';

  @override
  String get binaDaireNoGerekli =>
      'Un numéro de logement est requis (ex. A-12, 12).';

  @override
  String get binaKatSiraTamSayi =>
      'L\'étage et la position doivent être des entiers.';

  @override
  String get binaDaireNoZatenVar => 'Ce numéro de logement existe déjà.';

  @override
  String binaDaireDuzenleBaslik(Object no) {
    return 'Logement $no — modifier';
  }

  @override
  String binaYeniDaire(Object blok) {
    return 'Nouveau logement · $blok';
  }

  @override
  String get binaDaireNo => 'Numéro de logement';

  @override
  String get binaDaireNoYardim => 'Alphanumérique + tiret (ex. A-12, B3, 12)';

  @override
  String get binaSira => 'Position';

  @override
  String get binaSiraYardim => 'Position sur l\'étage';

  @override
  String binaEnFazla500(Object n) {
    return '500 logements au maximum (actuellement $n).';
  }

  @override
  String binaTopluOnizleme(
    Object bas,
    Object bitis,
    Object toplam,
    Object kat,
    Object adet,
  ) {
    return '$bas … $bitis  ($toplam logements, $kat étages × $adet)';
  }

  @override
  String get binaTopluAlanlarGerekli =>
      'Le nombre d\'étages, de logements par étage et le numéro de départ sont requis.';

  @override
  String get binaTekSeferde500 => '500 logements au maximum à la fois.';

  @override
  String binaAtlananEk(Object n) {
    return ' ($n déjà existants, ignorés)';
  }

  @override
  String binaDaireEklendi(Object n, Object ek) {
    return '$n logements ajoutés ✓$ek';
  }

  @override
  String get binaEklenemedi => 'Ajout impossible. Réessayez.';

  @override
  String binaTopluBaslik(Object blok) {
    return 'Ajout groupé — Bloc $blok';
  }

  @override
  String get binaTopluBaslikBloksuz => 'Ajout groupé — sans bloc';

  @override
  String get binaTopluAciklama =>
      'Les numéros se suivent à partir du départ, étage par étage. Les existants sont ignorés.';

  @override
  String get binaKatSayisi => 'Nombre d\'étages';

  @override
  String get binaKatBasinaDaire => 'Logements par étage';

  @override
  String get binaBaslangicNo => 'Numéro de départ';

  @override
  String get binaBaslangicNoIpucu => 'ex. 101';

  @override
  String get binaDaireleriOlustur => 'Créer les logements';

  @override
  String get binaSilinemedi => 'Suppression impossible. Veuillez réessayer.';

  @override
  String get binaKaydedilemedi =>
      'Enregistrement impossible. Veuillez réessayer.';

  @override
  String get semaDaireYok => 'Aucun logement pour l\'instant.';

  @override
  String get semaYogunluk => 'Densité :';

  @override
  String get semaYerlesimAciklama =>
      'Répartition du bâtiment. La densité des plaintes n\'est montrée qu\'à la gestion.';

  @override
  String get semaYerlesimGirilmemis => 'Emplacement non saisi sur la carte';

  @override
  String semaDaireEtiket(Object no) {
    return 'Logement $no';
  }

  @override
  String semaAcikSikayet(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n plaintes ouvertes',
      one: '$n plainte ouverte',
    );
    return '$_temp0';
  }

  @override
  String get semaBuDaireSikayetlerim => 'Vos plaintes pour ce logement';

  @override
  String get semaYogunlukYonetim =>
      'La densité des plaintes n\'est montrée qu\'à la gestion.';

  @override
  String get semaBuDaireyiSikayetEt => 'Signaler ce logement';

  @override
  String get semaSikayetIletildi => 'Votre plainte a été transmise.';

  @override
  String get semaSikayetlerYuklenemedi => 'Impossible de charger les plaintes.';

  @override
  String get semaAcikSikayetYok => 'Aucune plainte ouverte pour ce logement.';

  @override
  String get semaSikayetlerimYuklenemedi =>
      'Impossible de charger vos plaintes.';

  @override
  String get semaSikayetimYok =>
      'Vous n\'avez aucune plainte pour ce logement.';

  @override
  String get semaYonetimeIletildi => 'Transmis à la gestion';

  @override
  String get semaKapatildi => 'Clôturé';

  @override
  String get semaHaftalikSinir =>
      'Vous pouvez ouvrir au maximum 1 plainte par semaine sur ce sujet pour ce logement.';

  @override
  String get semaKendiBlok =>
      'Vous ne pouvez signaler que des logements de votre propre bloc.';

  @override
  String get semaGonderilemedi => 'Envoi impossible. Veuillez réessayer.';

  @override
  String semaSikayetEtBaslik(Object no) {
    return 'Logement $no — signaler';
  }

  @override
  String get semaSikayetAnonimNot =>
      'Votre plainte est transmise à la gestion ; elle n\'est pas montrée à vos voisins.';

  @override
  String get semaSikayetiGonder => 'Envoyer la plainte';

  @override
  String get kategoriGurultu => 'Bruit';

  @override
  String get kategoriKapiOnuAyakkabi => 'Devant la porte / chaussures';

  @override
  String get kategoriZararVerme => 'Dégradation';

  @override
  String talepSekmeAcik(Object n) {
    return 'Ouverts ($n)';
  }

  @override
  String talepSekmeIsEmri(Object n) {
    return 'Ordre de travail ($n)';
  }

  @override
  String talepSekmeCozulen(Object n) {
    return 'Résolus ($n)';
  }

  @override
  String talepSekmeReddedilen(Object n) {
    return 'Rejetés ($n)';
  }

  @override
  String get talepYeni => 'Nouvelle demande';

  @override
  String get talepAcikYokSakin =>
      'Vous n\'avez aucune demande ouverte. Utilisez « Nouvelle demande » pour signaler une demande ou une panne.';

  @override
  String get talepAcikYok => 'Aucune demande ouverte.';

  @override
  String get talepIsEmriYok => 'Aucune demande convertie en ordre de travail.';

  @override
  String get talepCozulenYok => 'Aucune demande résolue pour l\'instant.';

  @override
  String get talepReddedilenYok => 'Aucune demande rejetée.';

  @override
  String get talepIletildi => 'Votre demande a été transmise ✓';

  @override
  String get talepDurumGecmisi => 'Historique des statuts';

  @override
  String get talepGorselYuklenemedi => 'Impossible de charger l\'image';

  @override
  String get talepIsEmriAtandi => 'Attribué';

  @override
  String get talepIsEmriTamamlandi => 'Terminé';

  @override
  String get talepIsEmriDurumBilinmiyor => 'Statut inconnu';

  @override
  String get talepIsEmri => 'Ordre de travail';

  @override
  String get talepYeniBaslik => 'Nouvelle demande / panne';

  @override
  String get talepBaslikAlan => 'Titre';

  @override
  String get talepBaslikZorunlu => 'Le titre est obligatoire';

  @override
  String get talepAciklamaAlan => 'Description';

  @override
  String get talepAciklamaZorunlu => 'La description est obligatoire';

  @override
  String get talepGonder => 'Envoyer';

  @override
  String get talepKategoriOpsiyonel => 'Catégorie (facultatif)';

  @override
  String get talepKategoriYok =>
      'Aucune catégorie définie ; la demande sera ouverte en « Autre ».';

  @override
  String get talepGorseller => 'Images (facultatif, 3 max)';

  @override
  String get talepYoneticiIslemleri => 'Actions du gestionnaire';

  @override
  String get talepIsEmrineDonusturuldu =>
      'Demande convertie en ordre de travail ✓';

  @override
  String get talepIsEmrineDonusturBuyuk => 'Convertir en ordre de travail';

  @override
  String get talepCozuldu => 'Demande résolue ✓';

  @override
  String get talepCoz => 'Résoudre';

  @override
  String get talepReddedildiBildirim => 'Demande rejetée ✓';

  @override
  String get talepReddet => 'Rejeter';

  @override
  String get talepReddediliyor => 'Rejet en cours...';

  @override
  String get talepPersonelAlinamadiKisa =>
      'Impossible de charger la liste du personnel.';

  @override
  String get talepIsEmrineDonustur => 'Convertir en ordre de travail';

  @override
  String get talepAtanabilirPersonelYok =>
      'Aucun personnel de terrain actif à attribuer. Ajoutez d\'abord un agent de sécurité ou technique pour convertir.';

  @override
  String get talepDonusturuluyor => 'Conversion en cours...';

  @override
  String get talepDonustur => 'Convertir';

  @override
  String get talepReddetBaslik => 'Rejeter la demande';

  @override
  String get talepRetSebebiNot =>
      'Le motif du rejet est visible par le demandeur dans l\'historique des statuts.';

  @override
  String get talepRetSebebi => 'Motif du rejet';

  @override
  String get talepCozBaslik => 'Résoudre la demande';

  @override
  String get talepCozNot =>
      'La demande est marquée résolue directement, sans ordre de travail.';

  @override
  String get talepCozumNotu => 'Note de résolution (facultatif)';

  @override
  String get talepKategorilerYuklenemedi =>
      'Impossible de charger les catégories.';

  @override
  String get talepFotoYuklenemedi => 'Impossible de téléverser la photo.';

  @override
  String get binaKat => 'Étage';

  @override
  String get binaKatYardim => '0 = rez-de-chaussée';

  @override
  String get binaBloksuz => 'Sans bloc';

  @override
  String get talepAcanSakin => 'Résident';

  @override
  String rezSekmeRezervasyonlar(Object n) {
    return 'Réservations ($n)';
  }

  @override
  String rezSekmeAlanlar(Object n) {
    return 'Espaces ($n)';
  }

  @override
  String get rezYokSakin =>
      'Vous n\'avez aucune réservation. Choisissez un espace dans l\'onglet « Espaces » et réservez un créneau libre.';

  @override
  String get rezYok => 'Aucune réservation.';

  @override
  String get rezYeniAlan => 'Nouvel espace';

  @override
  String get rezAlanEklendi => 'Espace commun ajouté ✓';

  @override
  String get rezAlanGuncellendi => 'Espace mis à jour ✓';

  @override
  String get rezOrtakAlan => 'Espace commun';

  @override
  String rezSatirOzet(
    Object tarih,
    Object baslangic,
    Object bitis,
    Object kisi,
  ) {
    return '$tarih · $baslangic-$bitis · $kisi pers.';
  }

  @override
  String get rezIptalEdildi => 'Annulée';

  @override
  String get rezIptalEdilsinMi => 'Annuler la réservation ?';

  @override
  String get rezIptalUyari =>
      'Le créneau redevient libre ; cette action est irréversible.';

  @override
  String get rezEvetIptalEt => 'Oui, annuler';

  @override
  String get rezIptalEdildiBildirim => 'Réservation annulée';

  @override
  String get rezIptalGonderilemedi =>
      'Impossible d\'envoyer l\'annulation. Réessayez.';

  @override
  String get rezIptalEt => 'Annuler';

  @override
  String rezDetayTarih(Object tarih, Object baslangic, Object bitis) {
    return 'Date : $tarih · $baslangic-$bitis';
  }

  @override
  String rezDetayKisi(Object n) {
    return 'Nombre de personnes : $n';
  }

  @override
  String rezDetayRezerve(Object zaman) {
    return 'Réservé : $zaman';
  }

  @override
  String rezDetayNot(Object not) {
    return 'Note : $not';
  }

  @override
  String get rezAlanYokYonetim =>
      'Aucun espace commun pour l\'instant. Ajoutez-en un avec « Nouvel espace ».';

  @override
  String get rezAlanYokGoruntuleme => 'Aucun espace commun à afficher.';

  @override
  String get rezAlanYokSakin => 'Aucun espace réservable.';

  @override
  String rezMusait(Object ozet) {
    return 'Disponible : $ozet';
  }

  @override
  String rezMusaitOzeti(Object acilis, Object kapanis, Object dakika) {
    return '$acilis–$kapanis · créneaux de $dakika min';
  }

  @override
  String get rezAcikDuzenle => 'Ouvert · touchez pour modifier';

  @override
  String get rezKapaliDuzenle => 'Fermé · touchez pour modifier';

  @override
  String rezMusaitSlotlariGor(Object ozet) {
    return 'Disponible : $ozet · touchez pour voir les créneaux';
  }

  @override
  String get rezPasifAlan => 'Inactif (non réservable)';

  @override
  String get rezKapanisSonra =>
      'L\'heure de fermeture doit être après l\'heure d\'ouverture.';

  @override
  String get rezAlanEklenemedi => 'Impossible d\'ajouter l\'espace. Réessayez.';

  @override
  String get rezAlanDuzenle => 'Modifier l\'espace';

  @override
  String get rezYeniOrtakAlan => 'Nouvel espace commun';

  @override
  String get rezAlanAdi => 'Nom de l\'espace * (ex. Piscine)';

  @override
  String get rezAlanAdiGerekli => 'Le nom de l\'espace est obligatoire';

  @override
  String get rezMusaitlikHerGun => 'Disponibilité (chaque jour)';

  @override
  String rezAcilis(Object saat) {
    return 'Ouverture : $saat';
  }

  @override
  String rezKapanis(Object saat) {
    return 'Fermeture : $saat';
  }

  @override
  String get rezSlotUzunlugu => 'Durée du créneau';

  @override
  String rezSlotDakika(Object n) {
    return '$n minutes';
  }

  @override
  String get rezAlaniEkle => 'Ajouter l\'espace';

  @override
  String get rezSlotlarYuklenemedi =>
      'Impossible de charger les créneaux. Réessayez.';

  @override
  String get rezOnaylandi => 'Votre réservation est confirmée ✓';

  @override
  String rezTarihEtiket(Object tarih) {
    return 'Date : $tarih';
  }

  @override
  String get rezSlotKurali =>
      'Un créneau n\'ouvre que moins de 24 heures avant son début ; une seule réservation par jour au maximum.';

  @override
  String get rezSlotYok => 'Aucun créneau défini pour cet espace.';

  @override
  String get rezBenimAktif => 'Ma réservation (active)';

  @override
  String get rezBenimGecti => 'Ma réservation (passée)';

  @override
  String get rezDoluBaskasi => 'Occupé (autre)';

  @override
  String get rezSizinGecti => 'Votre réservation (passée)';

  @override
  String rezKisiEki(Object n) {
    return ' · $n pers.';
  }

  @override
  String rezDoluDaire(Object daire, Object kisi) {
    return 'Occupé · Logement $daire$kisi';
  }

  @override
  String get rezBos => 'Libre';

  @override
  String get rezDolu => 'Occupé';

  @override
  String rezSlotAralik(Object baslangic, Object bitis) {
    return '$baslangic – $bitis';
  }

  @override
  String get rezSec => 'Choisir';

  @override
  String get rezGonderilemedi => 'Envoi impossible. Réessayez.';

  @override
  String rezEtBaslik(Object ad) {
    return '$ad — réserver';
  }

  @override
  String get rezKisiSayisiEtiket => 'Nombre de personnes :';

  @override
  String get rezEt => 'Réserver';

  @override
  String get rezDurumOnayli => 'Confirmée';

  @override
  String get rezSebepDolu => 'occupé';

  @override
  String get rezSebepGecti => 'passé';

  @override
  String get rezSebepCokErken => 'ouvre sous 24 h';

  @override
  String get rezSebepGunluk => 'quota journalier atteint';

  @override
  String etkSekmeYaklasan(Object n) {
    return 'À venir ($n)';
  }

  @override
  String etkSekmeGecmis(Object n) {
    return 'Passés ($n)';
  }

  @override
  String get etkYeni => 'Nouvel événement';

  @override
  String get etkYaklasanYokYonetim =>
      'Aucun événement à venir. Annoncez-en un avec « Nouvel événement ».';

  @override
  String get etkYaklasanYok => 'Aucun événement à venir.';

  @override
  String get etkGecmisYok => 'Aucun événement passé.';

  @override
  String get etkDuyuruldu => 'Événement annoncé — résidents notifiés ✓';

  @override
  String get etkGuncellendi => 'Événement mis à jour ✓';

  @override
  String etkKatiliyorSayisi(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n participent',
      one: '$n participe',
    );
    return '$_temp0';
  }

  @override
  String etkKatilmiyorSayisi(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ne participent pas',
      one: '$n ne participe pas',
    );
    return '$_temp0';
  }

  @override
  String etkKatiliminiz(Object durum) {
    return 'Votre réponse : $durum';
  }

  @override
  String etkBeyanKaydedildi(Object durum) {
    return 'Votre réponse est enregistrée : $durum ✓';
  }

  @override
  String get etkBeyanGonderilemedi =>
      'Impossible d\'envoyer la réponse. Réessayez.';

  @override
  String get etkKatiliyorum => 'Je participe';

  @override
  String get etkKatilmiyorum => 'Je ne participe pas';

  @override
  String etkZaman(Object aralik) {
    return 'Heure : $aralik';
  }

  @override
  String etkYer(Object konum) {
    return 'Lieu : $konum';
  }

  @override
  String etkDuyuran(Object ad) {
    return 'Annoncé par : $ad';
  }

  @override
  String get etkSilinsinMi => 'Supprimer l\'événement ?';

  @override
  String etkSilOnay(Object baslik) {
    return '\"$baslik\" et toutes les réponses seront supprimés.';
  }

  @override
  String get etkSilindi => 'Événement supprimé ✓';

  @override
  String get etkBitisSonra => 'La fin doit être après le début';

  @override
  String get etkKaydedilemedi => 'Enregistrement impossible. Réessayez.';

  @override
  String get etkDuzenleBaslik => 'Modifier l\'événement';

  @override
  String get etkBaslikAlan => 'Titre * (ex. Soirée match)';

  @override
  String get etkBaslikGerekli => 'Le titre est obligatoire';

  @override
  String get etkAciklamaAlan => 'Description *';

  @override
  String get etkAciklamaGerekli => 'La description est obligatoire';

  @override
  String etkZamanSecim(Object zaman) {
    return 'Heure : $zaman';
  }

  @override
  String get etkBitisEkle => 'Ajouter une fin (facultatif)';

  @override
  String etkBitis(Object zaman) {
    return 'Fin : $zaman';
  }

  @override
  String get etkBitisiKaldir => 'Retirer la fin';

  @override
  String get etkYerAlan => 'Lieu (facultatif)';

  @override
  String get etkGorselAlan => 'Image (facultatif)';

  @override
  String get etkDuyurVeBildir => 'Annoncer et notifier les résidents';

  @override
  String get izinBaslik => 'Autorisation de consultation';

  @override
  String get izinTumDairelere =>
      'Demander l\'autorisation pour tous les logements';

  @override
  String get izinYeniIstek => 'Nouvelle demande';

  @override
  String get izinIstekYokYonetim =>
      'Vous n\'avez aucune demande d\'autorisation. Utilisez « Nouvelle demande » pour un logement, ou « Tous les logements » ci-dessus pour tous.';

  @override
  String get izinIstekYokSakin =>
      'Aucune demande de consultation pour votre logement.';

  @override
  String get izinTumDaireUyari =>
      'Une demande de consultation sera envoyée pour chaque logement occupé. Chaque logement dépend de l\'accord de son résident — vous ne verrez que les données des logements ayant accepté.';

  @override
  String izinAtlandiEki(Object n) {
    return ' ($n déjà ouverts)';
  }

  @override
  String izinTopluGonderildi(Object n, Object atlandi) {
    return 'Demandes envoyées pour $n logements$atlandi — en attente des accords des résidents';
  }

  @override
  String izinGonderilemedi(Object hata) {
    return 'Envoi impossible : $hata';
  }

  @override
  String get izinIsteBaslik => 'Demander l\'autorisation de consultation';

  @override
  String get izinDaireNo => 'Numéro de logement (ex. A-12)';

  @override
  String get izinIstekGonder => 'Envoyer la demande';

  @override
  String get izinIstekGonderildi =>
      'Demande envoyée — en attente de l\'accord du résident';

  @override
  String izinDaireIstegi(Object daire) {
    return 'Demande de consultation de logement$daire';
  }

  @override
  String izinIsteyen(Object ad) {
    return 'Demandé par : $ad';
  }

  @override
  String get izinKullanildiUyari =>
      'L\'autorisation a été utilisée (usage unique). Ouvrez une nouvelle demande pour consulter à nouveau.';

  @override
  String izinGoruntulenebilirDaireler(Object n) {
    return 'Logements consultables ($n)';
  }

  @override
  String get izinKullanildi => 'Utilisée';

  @override
  String get izinOnayli => 'Approuvée';

  @override
  String get izinVerildi => 'Autorisation accordée';

  @override
  String get izinOnayla => 'Approuver';

  @override
  String get izinKargolar => 'Colis';

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
      'L\'autorisation a été utilisée ou a expiré (usage unique). Ouvrez une nouvelle demande pour consulter à nouveau.';

  @override
  String get izinTekSeferlikUyari =>
      'Consultation avec une autorisation à usage unique — l\'accès se ferme au rafraîchissement.';

  @override
  String get izinKayitYok => 'Aucun enregistrement pour ce logement.';

  @override
  String izinHedef(Object ad) {
    return 'Destinataire : $ad';
  }

  @override
  String izinKaydeden(Object ad) {
    return 'Enregistré par : $ad';
  }

  @override
  String izinDurumEtiket(Object durum) {
    return 'Statut : $durum';
  }

  @override
  String get izinDurumOnaylandi => 'Approuvée';

  @override
  String get kargoDurumTeslimAlindi => 'Remis';

  @override
  String get rezSizin => 'Votre réservation';

  @override
  String get butBaslik => 'Budget';

  @override
  String get butSekmeOzet => 'Résumé';

  @override
  String get butSekmeHareketler => 'Écritures';

  @override
  String get butSekmeKategoriler => 'Catégories';

  @override
  String get butTumZamanlar => 'Toutes périodes';

  @override
  String get butDonem => 'Période';

  @override
  String get butGelir => 'Recettes';

  @override
  String get butGider => 'Dépenses';

  @override
  String get butKasa => 'Solde';

  @override
  String get butKategoriKirilimi => 'Répartition par catégorie';

  @override
  String get butYeniHareket => 'Nouvelle écriture';

  @override
  String get butHareketYok => 'Aucune écriture pour l\'instant.';

  @override
  String get butKategori => 'Catégorie';

  @override
  String get butOtomatik => 'Automatique';

  @override
  String get butKategoriSecin => 'Choisissez une catégorie';

  @override
  String get butTutar => 'Montant (TL)';

  @override
  String get butTutarIpucu => 'ex. 1.250,50';

  @override
  String get butTutarGecersiz => 'Saisissez un montant valide (ex. 1.250,50)';

  @override
  String butTarih(Object tarih) {
    return 'Date : $tarih';
  }

  @override
  String get butYeniKategori => 'Nouvelle catégorie';

  @override
  String get butKategoriYok => 'Aucune catégorie pour l\'instant.';

  @override
  String get butKategoriAdi => 'Nom de la catégorie';

  @override
  String get butKategoriAdiIpucu => 'ex. Entretien du jardin';

  @override
  String get butAdZorunlu => 'Le nom est obligatoire';

  @override
  String butKategoriTip(Object ad, Object tip) {
    return '$ad ($tip)';
  }

  @override
  String get butPasifEki => ' · inactive (aucune nouvelle écriture)';

  @override
  String get butBeklenmeyenKisa =>
      'Une erreur inattendue s\'est produite. Réessayez.';

  @override
  String get butFinansalOzet => 'Résumé financier';

  @override
  String get butAidatTahsilati => 'Recouvrement des charges';

  @override
  String get butEnYuksekGiderler => 'Dépenses les plus élevées';

  @override
  String butTahsilatYuzde(Object yuzde) {
    return 'Recouvrement $yuzde %';
  }

  @override
  String get butTahakkukYok =>
      'Aucune imputation enregistrée pour cette période.';

  @override
  String get butSiteBaslik => 'Budget du site';

  @override
  String get butKategoriToplamlari => 'Totaux par catégorie';

  @override
  String get butSeffaflikNotu =>
      'Cet écran présente les recettes et dépenses de la gestion du site sous forme de résumé, par transparence. Les détails par personne et par logement ne sont pas affichés ; adressez vos questions à la gestion.';

  @override
  String get demBaslik => 'Inventaire';

  @override
  String get demEtiketOkut => 'Scanner le tag';

  @override
  String get demBaskaEtiketOkut => 'Scanner un autre tag';

  @override
  String demUzerimdekiler(Object ek) {
    return 'En ma possession$ek';
  }

  @override
  String get demNfcAciklama =>
      'Scannez le tag NFC sur le matériel lors de la prise ou du retour. L\'application l\'identifie et indique qui le détient.';

  @override
  String get demTaniniyor => 'Identification du matériel...';

  @override
  String get demKimsedeDegil => 'Détenu par personne — disponible.';

  @override
  String demSende(Object sure) {
    return 'CHEZ VOUS — $sure.';
  }

  @override
  String demBaskasinda(Object ad, Object sure) {
    return 'Détenu par $ad — $sure.';
  }

  @override
  String get demBaskasininUzerinde => 'Semble détenu par quelqu\'un d\'autre.';

  @override
  String get demBakimda => 'En maintenance — non attribuable pour l\'instant.';

  @override
  String get demZorlaDevralmaYok =>
      'Pas de reprise forcée — le détenteur actuel doit rendre le matériel.';

  @override
  String get demZimmetineAl => 'Prendre en charge';

  @override
  String get demBirak => 'Rendre';

  @override
  String get demBirakKisa => 'Rendre';

  @override
  String get demSonHareketler => 'Dernières opérations';

  @override
  String demAldi(Object ad, Object zaman) {
    return '$ad l\'a pris — $zaman (toujours détenu)';
  }

  @override
  String get demListeYetkiYok =>
      'Vous n\'êtes pas autorisé pour la liste d\'inventaire.';

  @override
  String get demUzerindeYok => 'Vous ne détenez actuellement aucun matériel.';

  @override
  String demAldin(Object zaman, Object sure) {
    return 'Pris : $zaman ($sure)';
  }

  @override
  String get demSureBelirsiz => 'depuis un moment';

  @override
  String get demSureAzOnce => 'à l\'instant';

  @override
  String demSureDakika(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'depuis $n minutes',
      one: 'depuis $n minute',
    );
    return '$_temp0';
  }

  @override
  String demSureSaat(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'depuis $n heures',
      one: 'depuis $n heure',
    );
    return '$_temp0';
  }

  @override
  String demSureGun(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'depuis $n jours',
      one: 'depuis $n jour',
    );
    return '$_temp0';
  }

  @override
  String get demOfflineUyari =>
      'Une connexion Internet est nécessaire. La détention est un enregistrement en temps réel ; pas de traitement hors ligne (la mise en file serait trompeuse).';

  @override
  String demEtiketEslesmiyor(Object uid) {
    return 'Ce tag ($uid) ne correspond à aucun matériel enregistré. Le tag doit être affecté à un matériel depuis le panneau.';
  }

  @override
  String get demZatenZimmetinde =>
      'Il vous était déjà attribué ✓ (renvoi — aucun doublon)';

  @override
  String get demZimmetineAlindi => 'Pris en charge ✓';

  @override
  String get demBirakildi => 'Rendu ✓ — la prise en charge est clôturée.';

  @override
  String demIslemYapilamadi(Object hata) {
    return 'Action impossible : $hata Le statut a été actualisé — regardez à nouveau la carte.';
  }

  @override
  String demHataSatiri(Object ad, Object hata) {
    return '$ad: $hata';
  }

  @override
  String get karBaslik => 'Colis';

  @override
  String karSekmeBekleyen(Object n) {
    return 'En attente ($n)';
  }

  @override
  String karSekmeTeslim(Object n) {
    return 'Récupérés ($n)';
  }

  @override
  String get karYeni => 'Nouveau colis';

  @override
  String get karBekleyenYokSakin =>
      'Vous n\'avez aucun colis en attente de retrait.';

  @override
  String get karBekleyenYok => 'Aucun colis en attente de retrait.';

  @override
  String get karTeslimYok => 'Aucun colis récupéré enregistré pour l\'instant.';

  @override
  String get karKaydedildi =>
      'Colis enregistré — les résidents du logement ont été notifiés ✓';

  @override
  String karDaireTarih(Object daire, Object zaman) {
    return 'Logement : $daire · $zaman';
  }

  @override
  String karDaire(Object daire) {
    return 'Logement : $daire';
  }

  @override
  String karKayit(Object zaman) {
    return 'Enregistré : $zaman';
  }

  @override
  String karNot(Object not) {
    return 'Note : $not';
  }

  @override
  String get karTeslimAlindiBildirim => 'Colis marqué comme récupéré ✓';

  @override
  String get karIsaretlenemedi => 'Impossible de marquer. Réessayez.';

  @override
  String get karTeslimAldim => 'Je l\'ai récupéré';

  @override
  String get karGonderilemedi =>
      'Impossible d\'envoyer l\'enregistrement. Réessayez.';

  @override
  String get karDaireNo => 'Numéro de logement * (ex. A-12)';

  @override
  String get karDaireNoGerekli => 'Le numéro de logement est obligatoire';

  @override
  String get karFirma => 'Transporteur *';

  @override
  String get karFirmaGerekli => 'Le transporteur est obligatoire';

  @override
  String get karPaketFotografi => 'Photo du colis (facultatif)';

  @override
  String get karKaydetVeBildir => 'Enregistrer et notifier les résidents';

  @override
  String get ortakTekrarDene => 'Réessayer';

  @override
  String get butTahakkuk => 'Imputé';

  @override
  String get butTahsilat => 'Encaissé';

  @override
  String get butGeciken => 'En retard';

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
  String get kuralBaslik => 'Règlement du site';

  @override
  String get kuralYeni => 'Nouvelle règle';

  @override
  String get kuralAramaIpucu => 'Rechercher dans les titres (ex. piscine)';

  @override
  String get kuralEklendi => 'Règle ajoutée ✓';

  @override
  String get kuralGuncellendi => 'Règle mise à jour ✓';

  @override
  String get kuralAramaBos => 'Aucune règle ne correspond à la recherche.';

  @override
  String get kuralYokYonetim =>
      'Aucune règle pour l’instant. Ajoutez-en une via \"Nouvelle règle\".';

  @override
  String get kuralYokSakin => 'Aucune règle publiée pour l’instant.';

  @override
  String get kuralSilOnayBaslik => 'Supprimer cette règle ?';

  @override
  String kuralSilOnayGovde(Object baslik) {
    return '\"$baslik\" sera définitivement supprimé.';
  }

  @override
  String get kuralSilindi => 'Règle supprimée ✓';

  @override
  String get kuralDuzenleBaslik => 'Modifier la règle';

  @override
  String get kuralBaslikAlan => 'Titre * (ex. Horaires piscine)';

  @override
  String get kuralBaslikGerekli => 'Le titre est obligatoire';

  @override
  String get kuralMetni => 'Texte de la règle *';

  @override
  String get kuralMetniGerekli => 'Le texte de la règle est obligatoire';

  @override
  String get kuralSira => 'Ordre (le plus petit d’abord)';

  @override
  String get kuralSiraGecersiz => 'L’ordre doit être 0 ou un entier positif';

  @override
  String get kuralMevcutGorsel => 'Image actuelle conservée';

  @override
  String get kuralEkleButon => 'Ajouter la règle';

  @override
  String get ortakFotoOnlineTekrarDene =>
      'Une connexion Internet est nécessaire pour envoyer une photo. Réessayez dès que vous êtes en ligne.';

  @override
  String get ortakFotoBekleyinVeyaKaldir =>
      'La photo n’est pas encore envoyée. Attendez la fin de l’envoi ou retirez la photo.';

  @override
  String get duyuruYeni => 'Nouvelle annonce';

  @override
  String get duyuruYayinlandi => 'Annonce publiée ✓';

  @override
  String get duyuruGuncellendi => 'Annonce mise à jour ✓';

  @override
  String get duyuruYok => 'Aucune annonce pour l’instant.';

  @override
  String get duyuruYonetim => 'Gestion';

  @override
  String duyuruMeta(Object ad, Object zaman, Object duzenlendi) {
    return '$ad · $zaman$duzenlendi';
  }

  @override
  String get duyuruDuzenlendiEki => ' · modifiée';

  @override
  String get duyuruSilOnay => 'Supprimer cette annonce ?';

  @override
  String get duyuruSilindi => 'Annonce supprimée ✓';

  @override
  String get duyuruDuzenleBaslik => 'Modifier l’annonce';

  @override
  String get duyuruBaslikZorunlu => 'Le titre est obligatoire';

  @override
  String get duyuruMetniAlan => 'Texte de l’annonce';

  @override
  String get duyuruMetniZorunlu => 'Le texte de l’annonce est obligatoire';

  @override
  String get duyuruYayinla => 'Publier';

  @override
  String get ortakIslemler => 'Actions';

  @override
  String get sakinBaslik => 'Résidents du site';

  @override
  String get sakinEkle => 'Ajouter un résident';

  @override
  String get sakinListelenemedi => 'Impossible de lister les résidents.';

  @override
  String get sakinDaireYok => 'Aucun logement attribué';

  @override
  String get sakinIslemleri => 'Actions du résident';

  @override
  String get sakinParolaSifirla => 'Réinitialiser le mot de passe';

  @override
  String get sakinParolaSifirlaOnay => 'Réinitialiser le mot de passe ?';

  @override
  String sakinParolaSifirlaGovde(Object ad) {
    return 'Un nouveau code temporaire est généré pour \"$ad\" ; l’ancien mot de passe devient invalide. L’utilisateur se connecte avec le téléphone + le nouveau code puis définit un mot de passe.';
  }

  @override
  String get sakinSifirla => 'Réinitialiser';

  @override
  String sakinYeniKodMesaji(Object ad) {
    return 'Nouveau code temporaire pour \"$ad\". Transmettez-le au résident : il se connecte avec le téléphone + ce code puis définit un mot de passe.';
  }

  @override
  String get sakinSilOnay => 'Supprimer le résident ?';

  @override
  String sakinSilGovde(Object ad) {
    return '\"$ad\" sera supprimé. Sans historique, l’enregistrement est supprimé ; sinon il devient inactif. Dans tous les cas le numéro de téléphone est libéré (il peut être réenregistré).';
  }

  @override
  String sakinSilindi(Object ad) {
    return '\"$ad\" supprimé (numéro libéré)';
  }

  @override
  String sakinPasiflestirildi(Object ad) {
    return '\"$ad\" désactivé — possède un historique (numéro libéré)';
  }

  @override
  String get sakinDuzenleBaslik => 'Modifier le résident';

  @override
  String get sakinYeniTelefon => 'Nouveau numéro de mobile';

  @override
  String get sakinBosBirakDegismez => 'Laissez vide pour ne rien changer';

  @override
  String get sakinGuncellendi => 'Mis à jour ✓';

  @override
  String get ortakAdSoyad => 'Nom complet';

  @override
  String get telefonHataEksik =>
      'Numéro incomplet — saisissez 10 chiffres (ex. 0543 199 29 04).';

  @override
  String get telefonHataOnEk =>
      'Un numéro de mobile doit commencer par 5 (ex. 0543…). Les fixes ne sont pas acceptés.';

  @override
  String get ortakCepTelefonu => 'Numéro de mobile';

  @override
  String get ortakTelefonIpucu => 'ex. 0532 111 22 03';

  @override
  String get ortakTelefonZorunlu => 'Le téléphone est obligatoire';

  @override
  String get sakinGirisAnahtari => 'Clé de connexion (unique globalement).';

  @override
  String get ortakDaireNoIpucu => 'ex. A-12';

  @override
  String get sakinDaireNoZorunlu => 'Le numéro de logement est obligatoire';

  @override
  String get sakinParolaOpsiyonel => 'Mot de passe (facultatif)';

  @override
  String get sakinBosBirakKod => 'Laissez vide pour générer un code temporaire';

  @override
  String get sakinEklendiKod =>
      'Résident ajouté. Transmettez-lui ce code : il se connecte avec le téléphone + ce code puis définit un mot de passe.';

  @override
  String get sakinEklendi => 'Résident ajouté ✓';

  @override
  String get sakinYok =>
      'Aucun résident pour l’instant.\nAjoutez-en depuis le bas à droite.';

  @override
  String get ortakGeciciKodBaslik => 'Code de connexion temporaire';

  @override
  String get ortakKopyala => 'Copier';

  @override
  String get ortakKopyalandi => 'Copié';

  @override
  String get girisParolaVeyaKod => 'Mot de passe ou code temporaire';

  @override
  String get girisIlkKodIpucu =>
      'À la première connexion, saisissez le code temporaire reçu de la gestion.';

  @override
  String get girisBeniHatirla => 'Se souvenir de moi';

  @override
  String get girisYap => 'Se connecter';

  @override
  String get girisOturumSonaErdi =>
      'Votre session a expiré. Veuillez vous reconnecter.';

  @override
  String get parolaBelirleBaslik => 'Définissez votre mot de passe';

  @override
  String get parolaBelirleAciklama =>
      'Vous vous êtes connecté pour la première fois avec un code temporaire. Pour continuer, créez votre propre mot de passe permanent ; vous vous connecterez ensuite avec votre numéro de logement + ce mot de passe.';

  @override
  String get parolaBelirleButon => 'Définir le mot de passe';

  @override
  String get parolaGiriseDon => 'Retour à la connexion';

  @override
  String get ortakParolaZorunlu => 'Le mot de passe est obligatoire';

  @override
  String get ortakYeniParola => 'Nouveau mot de passe';

  @override
  String get ortakYeniParolaTekrar => 'Nouveau mot de passe (à nouveau)';

  @override
  String get ortakYeniParolaZorunlu =>
      'Le nouveau mot de passe est obligatoire';

  @override
  String get ortakParolalarEslesmiyor =>
      'Les mots de passe ne correspondent pas';

  @override
  String get parolaKuraliKisa => 'Doit contenir au moins 8 caractères';

  @override
  String get parolaKuraliBuyukHarf => 'Doit contenir au moins une majuscule';

  @override
  String get parolaKuraliRakam => 'Doit contenir au moins un chiffre';

  @override
  String get parolaKuraliSembol =>
      'Doit contenir au moins un symbole (! ? @ # . -)';

  @override
  String get profilYuklenemedi => 'Impossible de charger le profil.';

  @override
  String get profilNumaraYok => 'Aucun numéro saisi';

  @override
  String get profilFotoBaslik => 'Photo de profil';

  @override
  String get profilFotoSec => 'Choisir une photo';

  @override
  String get profilFotoGuncellendi => 'Photo de profil mise à jour ✓';

  @override
  String get profilFotoKaldirildi => 'Photo de profil supprimée';

  @override
  String get ortakGaleri => 'Galerie';

  @override
  String get profilParolaDegistir => 'Changer le mot de passe';

  @override
  String get profilMevcutParola => 'Mot de passe actuel';

  @override
  String get profilMevcutParolaZorunlu =>
      'Le mot de passe actuel est obligatoire';

  @override
  String get profilParolaGuncelle => 'Mettre à jour le mot de passe';

  @override
  String get profilParolaGuncellendi => 'Mot de passe mis à jour ✓';

  @override
  String get profilTelefon => 'Téléphone';

  @override
  String get profilTelefonIpucu => 'ex. +905551112233';

  @override
  String get profilAranabilir => 'Joignable par téléphone';

  @override
  String get profilAranabilirAlt =>
      'Les rôles autorisés (appel avec consentement) peuvent joindre votre numéro';

  @override
  String get profilIletisimKaydet => 'Enregistrer le contact';

  @override
  String get profilIletisimGuncellendi => 'Coordonnées mises à jour ✓';

  @override
  String get personelEkle => 'Ajouter un employé';

  @override
  String get personelDuzenle => 'Modifier l\'employé';

  @override
  String get personelListelenemedi => 'Impossible de lister le personnel.';

  @override
  String get personelPasiflestir => 'Désactiver';

  @override
  String get personelAktiflestir => 'Activer';

  @override
  String get personelPasiflestirildi => 'Désactivé ✓';

  @override
  String get personelAktiflestirildi => 'Activé ✓';

  @override
  String personelSifirlaGovde(Object ad) {
    return 'Un nouveau code temporaire sera généré pour $ad ; l\'ancien mot de passe devient invalide.';
  }

  @override
  String get personelYeniKodMesaji =>
      'Nouveau code temporaire. Transmettez-le à l\'employé : il se connecte avec le téléphone + ce code puis définit un mot de passe.';

  @override
  String get personelGuncellendi => 'Employé mis à jour ✓';

  @override
  String get personelEklendi => 'Employé ajouté ✓';

  @override
  String get personelEklendiKod =>
      'Employé ajouté. Transmettez-lui ce code : il se connecte avec le téléphone + ce code puis définit un mot de passe.';

  @override
  String get personelFoto => 'Photo';

  @override
  String get personelTelefonOpsiyonel => 'Numéro de mobile (facultatif)';

  @override
  String get personelBosBirakDegismezNokta =>
      'Laissez vide pour ne rien changer.';

  @override
  String get personelYok =>
      'Aucun personnel de terrain.\nAjoutez-en depuis le bas à droite.';

  @override
  String get disKisiEkle => 'Ajouter un contact';

  @override
  String get disListeAlinamadi => 'Impossible de charger la liste.';

  @override
  String get disKayitYokYonetim =>
      'Aucune entrée. Ajoutez un artisan de confiance depuis le bas à droite.';

  @override
  String get disKayitYok => 'Aucun prestataire externe enregistré.';

  @override
  String get disNotEkleyin =>
      'Ajoutez une note (seule la gestion peut modifier).';

  @override
  String get disNotuDuzenle => 'Modifier la note';

  @override
  String get disBolumNotu => 'Note de la section';

  @override
  String get disNotIpucu =>
      'ex. Des artisans de confiance depuis des années ; pour la sécurité du site, ne laissez pas entrer d\'inconnus.';

  @override
  String get disNotGuncellendi => 'Note mise à jour ✓';

  @override
  String get disAra => 'Appeler';

  @override
  String get disSilOnay => 'Supprimer cette entrée ?';

  @override
  String disSilGovde(Object ad) {
    return '\"$ad\" sera supprimé.';
  }

  @override
  String get disSilindi => 'Supprimé ✓';

  @override
  String get disYeniKisi => 'Nouveau contact externe';

  @override
  String get disKisiDuzenle => 'Modifier le contact';

  @override
  String get disTur => 'Type de service';

  @override
  String get disTurIpucu => 'ex. Serrurier, Électricité, Plomberie';

  @override
  String get disTurZorunlu => 'Le type est obligatoire';

  @override
  String get disAd => 'Prénom';

  @override
  String get disSoyad => 'Nom';

  @override
  String get disAdGerekli => 'Le prénom est obligatoire';

  @override
  String get disSoyadGerekli => 'Le nom est obligatoire';

  @override
  String get nfcBaslik => 'Lecture de tag NFC';

  @override
  String get nfcHazir => 'Prêt à lire. Appuyez sur Démarrer.';

  @override
  String get nfcYaklastirBekliyor =>
      'Approchez le tag de l\'arrière du téléphone...';

  @override
  String get nfcOkundu => 'Tag lu.';

  @override
  String get nfcOkumayaBasla => 'Démarrer la lecture';

  @override
  String get nfcTekrarOku => 'Lire à nouveau';

  @override
  String nfcKuyrukBekleyen(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n scans en attente d\'envoi',
      one: '$n scan en attente d\'envoi',
    );
    return '$_temp0';
  }

  @override
  String get nfcKuyruk => 'File d\'envoi';

  @override
  String get nfcKaydedildiBekliyor =>
      'Enregistré ✓ — sera envoyé automatiquement dès le retour du réseau.';

  @override
  String get nfcKaydedildiGonderiliyor => 'Enregistré ✓ — envoi...';

  @override
  String get nfcGonderildiZatenVar =>
      'Envoyé ✓ — ce scan était déjà enregistré.';

  @override
  String get nfcGonderildi => 'Envoyé ✓ — scan enregistré.';

  @override
  String get nfcEslesmeYok => 'Ce tag ne correspond à aucun point de contrôle.';

  @override
  String get nfcSdmBaslik => 'SDM (brut, non vérifié)';

  @override
  String get nfcTipEtiket => 'Type';

  @override
  String nfcNoktalarAlinamadi(Object hata) {
    return 'Impossible de charger les points : $hata';
  }

  @override
  String get nfcTestBaslik => 'TEST : quel point scanner ?';

  @override
  String get nfcTestAlt => 'Simule un scan sans tag physique.';

  @override
  String get nfcAktifNoktaYok => 'Aucun point de contrôle actif.';

  @override
  String get nfcAktifNoktaYokAlt =>
      'Ajoutez-en d\'abord depuis « Points de contrôle ».';

  @override
  String get nfcManuelOkut => 'Scan manuel (test)';

  @override
  String get nfcTestGorunur => 'Visible uniquement dans les builds de test.';

  @override
  String nfcUidSatir(Object uid) {
    return 'UID: $uid';
  }

  @override
  String get nfcHataKapali =>
      'Le NFC est désactivé. Activez-le dans les réglages de l\'appareil.';

  @override
  String get nfcHataDesteklenmiyor =>
      'Cet appareil ne prend pas en charge le NFC.';

  @override
  String get nfcHataUidOkunamadi => 'Impossible de lire l\'UID du tag.';

  @override
  String nfcHataCozumlenemedi(Object detay) {
    return 'Le tag n\'a pas pu être analysé : $detay';
  }

  @override
  String nfcHataOturum(Object detay) {
    return 'Impossible de démarrer la session NFC : $detay';
  }

  @override
  String nfcHataOkumaIptal(Object detay) {
    return 'Lecture annulée : $detay';
  }

  @override
  String nfcHataYapilandirma(Object detay) {
    return 'NFC est indisponible dans cette version : $detay. L\'application doit être mise à jour ; réessayer ne changera rien.';
  }

  @override
  String get nfcHataBilinmeyen => 'Une erreur inconnue s\'est produite.';

  @override
  String get nfcIosYaklastir => 'Approchez le tag de l\'arrière du téléphone.';

  @override
  String get nfcIosOkundu => 'Lu';

  @override
  String get nfcIosIptal => 'Annulé';

  @override
  String get nfcIosOkunamadi => 'Lecture impossible';

  @override
  String get seffafYuklenemedi => 'Chargement impossible. Veuillez réessayer.';

  @override
  String get seffafAyYayinlandi => 'Le mois est publié.';

  @override
  String get seffafYayinGeriAlindi => 'Publication retirée.';

  @override
  String get seffafVeriYokYonetim =>
      'Aucune donnée financière. Les mois apparaîtront après la saisie des recettes/dépenses ou des charges.';

  @override
  String get seffafVeriYok => 'La gestion n\'a pas encore publié de résumé.';

  @override
  String get seffafTaslakEki => ' • brouillon';

  @override
  String get seffafYayinla => 'Publier ce mois';

  @override
  String get seffafYayindaAlt => 'Les résidents voient ce résumé.';

  @override
  String get seffafOnizlemeAlt => 'Seule la gestion le voit (aperçu).';

  @override
  String get seffafOnizlemeUyari => 'Aperçu — pas encore publié.';

  @override
  String seffafOzetBaslik(Object ay) {
    return '$ay — Résumé';
  }

  @override
  String get seffafToplamGelir => 'Recettes totales';

  @override
  String get seffafToplamGider => 'Dépenses totales';

  @override
  String get seffafNet => 'Net';

  @override
  String seffafOncekiAyNet(Object tutar) {
    return 'Net du mois précédent : $tutar';
  }

  @override
  String get seffafGiderDagilimi => 'Répartition des dépenses';

  @override
  String get seffafGiderYok => 'Aucune dépense enregistrée ce mois.';

  @override
  String get seffafAidatToplama => 'Recouvrement des charges';

  @override
  String get seffafTahakkukYok => 'Aucune imputation pour ce mois.';

  @override
  String seffafOdeyenDaire(Object odeyen, Object toplam) {
    return 'Logements payés : $odeyen/$toplam';
  }

  @override
  String seffafTahsilatSatir(Object tahsilat, Object tahakkuk, Object yuzde) {
    return 'Encaissé : $tahsilat / $tahakkuk  (montant : $yuzde %)';
  }

  @override
  String seffafGecikmede(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n logements en retard',
      one: '$n logement en retard',
    );
    return '$_temp0';
  }

  @override
  String ortakYuzde(Object yuzde) {
    return '$yuzde %';
  }

  @override
  String get entegYeni => 'Nouveau';

  @override
  String get entegYokMesaj =>
      'Aucune intégration. Ajoutez un système externe (sonorisation/domotique/webhook) via « Nouveau ».';

  @override
  String get entegSilOnay => 'Supprimer ?';

  @override
  String entegSilGovde(Object ad) {
    return 'L\'intégration \"$ad\" sera supprimée.';
  }

  @override
  String entegSilinemedi(Object hata) {
    return 'Suppression impossible : $hata';
  }

  @override
  String get entegAktifKisa => 'active';

  @override
  String get entegPasifKisa => 'inactive';

  @override
  String entegKimlikSatir(Object tip, Object kilit) {
    return 'Auth : $tip$kilit';
  }

  @override
  String get entegTest => 'Test';

  @override
  String entegTestBasarili(Object durum) {
    return '✓ Réussi ($durum)';
  }

  @override
  String entegTestBasarisiz(Object hata, Object durum) {
    return '✗ $hata$durum';
  }

  @override
  String get entegBasarisiz => 'Échec';

  @override
  String get entegDuzenleBaslik => 'Modifier l\'intégration';

  @override
  String get entegYeniBaslik => 'Nouvelle intégration';

  @override
  String get entegPreset => 'Modèle prêt (preset)';

  @override
  String get entegKanalTipi => 'Type de canal';

  @override
  String get entegUrl => 'URL du endpoint (http/https)';

  @override
  String get entegUrlHelper =>
      'Les adresses internes/privées sont bloquées au déclenchement';

  @override
  String get entegUrlHata => 'Doit commencer par http(s)';

  @override
  String get entegHttpMetodu => 'Méthode HTTP';

  @override
  String get entegKimlikDogrulama => 'Authentification';

  @override
  String get entegSir => 'Secret (bearer token / clé API)';

  @override
  String get entegSirKayitli =>
      'Enregistré — saisissez une nouvelle valeur pour le changer';

  @override
  String get entegSirYazmaOzel =>
      'En écriture seule ; jamais renvoyé par le serveur';

  @override
  String get entegPayload => 'Modèle de payload';

  @override
  String entegPayloadHelper(Object sablonlar) {
    return 'Espaces réservés $sablonlar';
  }

  @override
  String get entegTestMesaji => 'Message de test';

  @override
  String get ortakAdGerekli => 'Le nom est obligatoire';

  @override
  String get ziyaretYeni => 'Nouveau visiteur';

  @override
  String get ziyaretKaydedildi =>
      'Visiteur enregistré — le résident a été notifié ✓';

  @override
  String get ziyaretYokGuvenlik => 'Aucun enregistrement de visiteur.';

  @override
  String get ziyaretYokSakin =>
      'Aucun enregistrement de visiteur ne vous a été transmis.';

  @override
  String ziyaretBildirilenSakin(Object ad) {
    return 'Résident notifié : $ad';
  }

  @override
  String get ziyaretSakiniAra => 'Appeler le résident';

  @override
  String get ziyaretGuvenligiAra => 'Appeler la sécurité';

  @override
  String get ziyaretBilgileriDuzenle => 'Modifier les informations';

  @override
  String get ziyaretGuncellendi => 'Informations du visiteur mises à jour ✓';

  @override
  String get ziyaretOnceDaireNo => 'Saisissez d\'abord le numéro de logement';

  @override
  String get ziyaretSakiniSecin => 'Sélectionnez le résident à notifier';

  @override
  String get ziyaretDuzenleBaslik => 'Modifier le visiteur';

  @override
  String get ziyaretDuzenleAlt =>
      'Vous pouvez modifier le nom, le logement, le résident notifié et la note.';

  @override
  String get ziyaretYeniAlt =>
      'Le résident reçoit seulement une notification (aucune approbation demandée).';

  @override
  String get ziyaretAdAlan => 'Nom du visiteur *';

  @override
  String get ziyaretAdGerekli => 'Le nom du visiteur est obligatoire';

  @override
  String get ziyaretSakinleriGetir => 'Charger les résidents';

  @override
  String get ziyaretBildirilecekSakin => 'Résident à notifier *';

  @override
  String get ziyaretKaydetVeBildir => 'Enregistrer et notifier le résident';

  @override
  String get raporBaslik => 'Rapports mensuels';

  @override
  String get raporOncekiAy => 'Mois précédent';

  @override
  String get raporSonrakiAy => 'Mois suivant';

  @override
  String raporAyBaslik(Object ay, Object yil) {
    return '$ay $yil';
  }

  @override
  String get raporYetkiYok =>
      'Vous n\'êtes pas autorisé pour les rapports mensuels. Cet écran est réservé au rôle gestionnaire du site.';

  @override
  String get raporGorevTamamlama => 'Achèvement des tâches';

  @override
  String get raporAidat => 'Charges';

  @override
  String get raporSonTamamlamalar => 'Derniers achèvements (10 premiers)';

  @override
  String get raporPlanlananPencere => 'Fenêtres planifiées';

  @override
  String raporTamamlanmaYuzde(Object yuzde) {
    return 'Achèvement $yuzde %';
  }

  @override
  String get raporPencereYok => 'Aucune fenêtre de ronde planifiée ce mois.';

  @override
  String get raporGorevYok => 'Aucune tâche achevée ce mois.';

  @override
  String get raporToplamTamamlama => 'Total des achèvements';

  @override
  String get raporAidatKayitYok =>
      'Aucune imputation/paiement pour cette période.';

  @override
  String raporTahakkukDaire(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Imputé ($n logements)',
      one: 'Imputé ($n logement)',
    );
    return '$_temp0';
  }

  @override
  String raporTahsilatOdeme(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Encaissé ($n paiements)',
      one: 'Encaissé ($n paiement)',
    );
    return '$_temp0';
  }

  @override
  String get raporKalanBakiye => 'Solde restant';

  @override
  String get aidatBaslik => 'Mes charges';

  @override
  String get aidatYetkiYok =>
      'Les informations de charges sont réservées aux comptes résidents.';

  @override
  String get aidatDaireYok =>
      'Aucun logement n\'est enregistré à votre nom. Contactez la gestion.';

  @override
  String get aidatToplamBakiye => 'Solde total (tous les logements)';

  @override
  String get aidatBorcVar => 'Solde dû';

  @override
  String get aidatBorcYok => 'Aucun solde dû';

  @override
  String get aidatToplamTahakkuk => 'Total imputé';

  @override
  String get aidatToplamOdenen => 'Total payé';

  @override
  String get aidatBakiye => 'Solde';

  @override
  String aidatHesapSatiri(Object tahakkuk, Object odenen, Object bakiye) {
    return 'Imputé $tahakkuk - payé $odenen = $bakiye';
  }

  @override
  String aidatTahakkuklar(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Imputations ($n)',
      one: 'Imputation ($n)',
    );
    return '$_temp0';
  }

  @override
  String aidatOdemeler(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Paiements ($n)',
      one: 'Paiement ($n)',
    );
    return '$_temp0';
  }

  @override
  String aidatSonOdeme(Object tarih) {
    return 'Échéance : $tarih';
  }

  @override
  String aidatMakbuz(Object no) {
    return 'Reçu : $no';
  }

  @override
  String get aidatOdemeDurumuNotu =>
      'Le statut du paiement n\'est mis à jour que par la confirmation du prestataire de paiement ; adressez vos questions à la gestion.';

  @override
  String get aidatYontemElden => 'Espèces';

  @override
  String get aidatYontemHavale => 'Virement bancaire';

  @override
  String get aidatYontemKart => 'Carte';

  @override
  String get aidatYontemDiger => 'Autre';

  @override
  String get aidatDurumBasarili => 'Réussi';

  @override
  String get aidatDurumIptal => 'Annulé';

  @override
  String get noktaBaslik => 'Points de contrôle';

  @override
  String get noktaEkle => 'Ajouter un point';

  @override
  String get noktaListelenemedi => 'Impossible de lister les points.';

  @override
  String get noktaSilOnay => 'Supprimer ce point de contrôle ?';

  @override
  String noktaSilGovde(Object ad) {
    return 'Le point de contrôle \"$ad\" sera supprimé.';
  }

  @override
  String get noktaSilindi => 'Point de contrôle supprimé ✓';

  @override
  String get noktaUidZatenVar => 'Ce tag NFC est déjà enregistré.';

  @override
  String get noktaDuzenleBaslik => 'Modifier le point';

  @override
  String get noktaYeniBaslik => 'Nouveau point de contrôle';

  @override
  String get noktaAdIpucu => 'ex. Entrée principale';

  @override
  String get noktaUidAlan => 'UID du tag NFC';

  @override
  String get noktaUidIpucu => 'ex. 04A2B3C4D5';

  @override
  String get noktaUidHelper => 'Identifiant unique du tag (hex).';

  @override
  String get noktaEnlem => 'Latitude (opt.)';

  @override
  String get noktaKonumGecersiz => 'Position invalide. Exemple : 41,0082';

  @override
  String get ortakSecenekYuklenemedi =>
      'Certaines options n\'ont pas pu être chargées — la liste peut être incomplète.';

  @override
  String get noktaBoylam => 'Longitude (opt.)';

  @override
  String get noktaPasifAlt => 'Un point inactif ne correspond à aucun scan';

  @override
  String get noktaYok => 'Aucun point de contrôle pour l\'instant.';

  @override
  String get kuyrukHatalariTemizle => 'Effacer les échecs définitifs';

  @override
  String get kuyrukBos => 'La file est vide.';

  @override
  String kuyrukOzet(Object bekleyen, Object hatali) {
    return '$bekleyen en attente · $hatali échecs définitifs';
  }

  @override
  String get kuyrukSenkronla => 'Synchroniser';

  @override
  String get kuyrukBekliyor => 'En attente';

  @override
  String kuyrukBekliyorDeneme(Object n) {
    return 'En attente (tentative : $n)';
  }

  @override
  String get kuyrukGonderiliyor => 'Envoi...';

  @override
  String get kuyrukGonderildiZatenVar => 'Envoyé (déjà enregistré)';

  @override
  String get kuyrukGonderildiYeni => 'Envoyé (nouvel enregistrement)';

  @override
  String kuyrukKaliciHata(Object hata) {
    return 'Échec définitif : $hata';
  }

  @override
  String get kuyrukEtiketEslesmedi => 'le tag ne correspond pas';

  @override
  String get okutmaImzaGecersiz =>
      'La signature du tag n\'a pas pu être vérifiée — tag falsifié ou incorrect.';

  @override
  String get okutmaTekrarEdilmis => 'Ce scan a déjà été traité.';

  @override
  String okutmaBeklenmeyenHata(Object detay) {
    return 'Erreur inattendue : $detay';
  }

  @override
  String get noktaUidZorunlu => 'L\'UID NFC est obligatoire';

  @override
  String get hataZamanAsimi => 'Délai dépassé lors de la connexion au serveur.';

  @override
  String get hataSunucuyaUlasilamadi =>
      'Le serveur est inaccessible. Vérifiez votre connexion réseau et l\'adresse du serveur.';

  @override
  String get destekBaslik => 'Assistance';

  @override
  String get destekYeniTalep => 'Nouvelle demande';

  @override
  String get destekTalepYok => 'Vous n\'avez aucune demande d\'assistance';

  @override
  String destekYuklenemedi(Object hata) {
    return 'Impossible de charger les demandes.\n$hata';
  }

  @override
  String destekGonderilemedi(Object hata) {
    return 'Impossible d\'envoyer la demande : $hata';
  }

  @override
  String get destekYeniTalepBaslik => 'Nouvelle demande d\'assistance';

  @override
  String get destekKonu => 'Objet';

  @override
  String get destekGorselEkle => 'Ajouter une image';

  @override
  String get destekGorseliDegistir => 'Changer l\'image';

  @override
  String get destekEkip => 'L\'équipe Yönetiyor';

  @override
  String get tesisKurulumBaslik => 'Configurez votre site';

  @override
  String get tesisKurulumAciklama =>
      'Vous vous êtes connecté comme gestionnaire pour la première fois. Pour continuer, saisissez le nom de votre site ; vous pourrez le modifier plus tard dans les réglages.';

  @override
  String get tesisAdiIpucu => 'ex. Résidence Exemple';

  @override
  String get tesisAdiKisa =>
      'Le nom du site doit comporter au moins 2 caractères';

  @override
  String get tesisOlustur => 'Créer le site';

  @override
  String get tesisAdiGuncellendi => 'Nom du site mis à jour';

  @override
  String get tesisAdiAciklama =>
      'Affiché dans le titre de l\'écran d\'accueil ; tous les utilisateurs voient ce nom.';

  @override
  String get sikayetYokSakin =>
      'Vous n\'avez pas encore ouvert de plainte.\nChoisissez un logement sur la carte des plaintes.';

  @override
  String sikayetSatirBaslik(Object daire, Object kategori) {
    return 'Logement $daire · $kategori';
  }

  @override
  String get sikayetDurumKapandi => 'Clôturée';

  @override
  String get vardiyaBaslik => 'Services';

  @override
  String get vardiyaYuklenemedi => 'Impossible de charger les services.';

  @override
  String get vardiyaTanimYok => 'Aucun service défini';

  @override
  String vardiyaSaatAraligi(Object baslangic, Object bitis, Object gunTipi) {
    return '$baslangic - $bitis • $gunTipi';
  }

  @override
  String get vardiyaPersonelAta => 'Affecter du personnel';

  @override
  String vardiyaPersonelBaslik(Object ad) {
    return '$ad — Personnel';
  }

  @override
  String get vardiyaPersonelGuncellendi => 'Personnel du service mis à jour ✓';

  @override
  String get vardiyaPersonelYuklenemedi =>
      'Impossible de charger le personnel.';

  @override
  String get vardiyaAtanabilirYok => 'Aucun personnel affectable';

  @override
  String get gunTipiHaftaIci => 'En semaine';

  @override
  String get gunTipiHaftaSonu => 'Le week-end';

  @override
  String get gunTipiResmiTatil => 'Jours fériés';

  @override
  String get gunTipiHerGun => 'Tous les jours';

  @override
  String get yonIletisimBaslik => 'Contacts de la gestion';

  @override
  String get yonIletisimAlinamadi =>
      'Impossible de charger les informations de gestion.';

  @override
  String get yonIletisimTanimliDegil =>
      'Aucune coordonnée de gestion n\'est définie.';

  @override
  String get yonIletisimMail => 'E-mail de la gestion';

  @override
  String get yonIletisimAra => 'Appeler le gestionnaire';

  @override
  String get aramaBaslatilamadi => 'Impossible de lancer l\'appel';

  @override
  String get aramaYapilamiyor => 'Non joignable';

  @override
  String get bildirimYok => 'Aucune notification';

  @override
  String bildirimYuklenemedi(Object hata) {
    return 'Impossible de charger les notifications.\n$hata';
  }

  @override
  String get bildirimYeniPush => 'Nouvelle notification';

  @override
  String get akisDevriyeOkutma => 'Scan de ronde';

  @override
  String get akisGorevTamamlandi => 'Tâche terminée';

  @override
  String get akisAidatOdemesi => 'Paiement des charges';

  @override
  String get akisTalepAcildi => 'Demande ouverte';

  @override
  String get akisTalepIsEmri => 'Demande convertie en ordre de travail';

  @override
  String get akisTalepCozuldu => 'Demande résolue';

  @override
  String get akisTalepReddedildi => 'Demande rejetée';

  @override
  String get akisDaireSikayeti => 'Signalement de logement';

  @override
  String get akisAlarmKacirilanTur => 'Ronde manquée';

  @override
  String get akisAlarmEksikCheckpoint => 'Point de contrôle manquant';

  @override
  String get akisAlarmGecikmisOkutma => 'Scan en retard';

  @override
  String get akisZiyaretciGirisi => 'Entrée d\'un visiteur';

  @override
  String get akisZiyaretciCikisi => 'Sortie d\'un visiteur';

  @override
  String get akisKargoKaydedildi => 'Colis enregistré';

  @override
  String get akisKargoTeslimEdildi => 'Colis remis';

  @override
  String get akisAracGirisi => 'Entrée de véhicule';

  @override
  String get akisAracCikisi => 'Sortie de véhicule';

  @override
  String get akisIhlalKaydi => 'Enregistrement d\'infraction';

  @override
  String akisAltDaireTutar(Object daire, Object tutar) {
    return 'Logement $daire — $tutar';
  }

  @override
  String akisAltDaireKategori(Object daire, Object kategori) {
    return 'Logement $daire — $kategori';
  }

  @override
  String akisAltAdDaire(Object ad, Object daire) {
    return '$ad — logement $daire';
  }

  @override
  String akisAltPlakaDaire(Object plaka, Object daire) {
    return '$plaka — logement $daire';
  }

  @override
  String akisAltPlakaTanim(Object plaka, Object tanim) {
    return '$plaka ($tanim)';
  }

  @override
  String akisAltPlakaDaireTanim(Object plaka, Object daire, Object tanim) {
    return '$plaka — logement $daire ($tanim)';
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
  String get ortakParolayiGoster => 'Afficher le mot de passe';

  @override
  String get ortakParolayiGizle => 'Masquer le mot de passe';

  @override
  String get ortakFotograf => 'Photo';

  @override
  String get ortakFotografiBuyut => 'Agrandir la photo';

  @override
  String get ortakGoster => 'Afficher';

  @override
  String get talepRedBaslik => 'Rejeter la demande';

  @override
  String get ziyaretciDaireSakinYok => 'Aucun résident actif dans ce logement';

  @override
  String get ceviriOtomatik => 'Ce contenu a été traduit automatiquement';

  @override
  String get ceviriOtomatikKisa => 'Traduction automatique';

  @override
  String get ceviriOrijinaliGor => 'Voir l’original';

  @override
  String get ceviriCeviriyiGor => 'Voir la traduction';

  @override
  String get ceviriHazirlaniyor =>
      'Traduction en cours — l’original est affiché';

  @override
  String get ceviriHazirlaniyorKisa => 'Traduction en cours';

  @override
  String get ceviriYapilamadi =>
      'Échec de la traduction — l’original est affiché';

  @override
  String get ceviriYapilamadiKisa => 'Échec de la traduction';

  @override
  String get modulAracGecis => 'Passages de véhicules';

  @override
  String get modulOtopark => 'Parking';

  @override
  String get modulIhlaller => 'Infractions';

  @override
  String get aracSuzgecTumu => 'Tous';

  @override
  String get aracSuzgecIceride => 'À l’intérieur';

  @override
  String get aracSuzgecCikmis => 'Sortis';

  @override
  String get aracPlakaAra => 'Rechercher une plaque';

  @override
  String get aracListeBos => 'Aucun passage de véhicule enregistré';

  @override
  String get aracAramaBos => 'Aucun passage pour cette plaque';

  @override
  String get aracRozetIceride => 'À l’intérieur';

  @override
  String get aracRozetCikti => 'Sorti';

  @override
  String get aracRozetZiyaretci => 'Visiteur';

  @override
  String aracGirisZamani(Object zaman) {
    return 'Entrée : $zaman';
  }

  @override
  String aracCikisZamani(Object zaman) {
    return 'Sortie : $zaman';
  }

  @override
  String aracDaire(Object no) {
    return 'Logement $no';
  }

  @override
  String get aracCikisVer => 'Enregistrer la sortie';

  @override
  String get aracCikisOnayBaslik => 'Enregistrer la sortie ?';

  @override
  String get aracCikisVerildi => 'Sortie enregistrée';

  @override
  String get aracZatenKapali => 'Ce passage est déjà clôturé';

  @override
  String get aracYeniGiris => 'Nouvelle entrée';

  @override
  String get aracGirisKaydedildi => 'Entrée du véhicule enregistrée';

  @override
  String get aracPlaka => 'Plaque';

  @override
  String get aracPlakaZorunlu => 'La plaque est obligatoire';

  @override
  String get aracTanimAlani => 'Description du véhicule (facultatif)';

  @override
  String get aracDaireAlani => 'N° de logement (facultatif)';

  @override
  String get aracZiyaretciMi => 'Véhicule de visiteur';

  @override
  String get aracZatenIceride =>
      'Cette plaque a déjà un passage ouvert (véhicule à l’intérieur)';

  @override
  String get aracErisimYok =>
      'La liste des passages est réservée à la gestion et à la sécurité';

  @override
  String aracKaydeden(Object ad) {
    return 'Enregistré par : $ad';
  }

  @override
  String get otoparkDoluEtiket => 'Occupées';

  @override
  String get otoparkBosEtiket => 'Libres';

  @override
  String get otoparkKapasiteEtiket => 'Capacité';

  @override
  String get otoparkKapasiteTanimsiz =>
      'Capacité non définie — seul le nombre de véhicules présents est affiché';

  @override
  String get otoparkAracListesi => 'Ouvrir les passages de véhicules';

  @override
  String get ihlalDurumYeni => 'Nouveau';

  @override
  String get ihlalDurumInceleniyor => 'En cours d’examen';

  @override
  String get ihlalDurumKapatildi => 'Clôturé';

  @override
  String get ihlalKaynakKamera => 'Caméra';

  @override
  String get ihlalKaynakManuel => 'Manuel';

  @override
  String get ihlalKaynakDevriye => 'Ronde';

  @override
  String get ihlalListeBos => 'Aucune infraction enregistrée';

  @override
  String get ihlalYeni => 'Nouvelle infraction';

  @override
  String get ihlalAcildi => 'Infraction enregistrée';

  @override
  String get ihlalBaslikAlani => 'Titre';

  @override
  String get ihlalBaslikZorunlu => 'Le titre est obligatoire';

  @override
  String get ihlalAciklamaAlani => 'Description (facultatif)';

  @override
  String get ihlalKonumAlani => 'Lieu (facultatif)';

  @override
  String get ihlalKaynakAlani => 'Source de détection';

  @override
  String get ihlalIncelemeyeAl => 'Lancer l’examen';

  @override
  String get ihlalKapat => 'Clôturer';

  @override
  String get ihlalDurumGuncellendi => 'Statut de l’infraction mis à jour';

  @override
  String get ihlalKapatmaOnay =>
      'Clôturer cet enregistrement ? Une infraction clôturée ne peut pas être rouverte.';

  @override
  String get ihlalKapaliDegistirilemez =>
      'Une infraction clôturée ne peut pas être rouverte';

  @override
  String get ihlalErisimYok =>
      'Les infractions sont réservées à la gestion et à la sécurité';

  @override
  String ihlalKaydeden(Object ad) {
    return 'Ouverte par : $ad';
  }

  @override
  String get kameraRestream => 'URL de rediffusion (facultatif)';

  @override
  String get kameraRestreamAlt =>
      'Rend une caméra RTSP lisible. L’adresse HLS de la passerelle Frigate/go2rtc.';

  @override
  String get kameraRestreamHata =>
      'L’adresse de rediffusion doit commencer par http:// ou https://';

  @override
  String get kameraRestreamRozet => 'Via la passerelle';

  @override
  String get modulPlakaOlaylari => 'Lectures de plaques';

  @override
  String get anprDurumIslendi => 'Traité';

  @override
  String get anprDurumOnayBekliyor => 'En attente d’approbation';

  @override
  String get anprDurumYokSayildi => 'Ignorée';

  @override
  String get anprDurumHata => 'Erreur';

  @override
  String get anprYonGiris => 'Entrée';

  @override
  String get anprYonCikis => 'Sortie';

  @override
  String get anprYonBilinmiyor => 'Direction inconnue';

  @override
  String get anprListeBos => 'Aucune lecture de plaque';

  @override
  String get anprErisimYok =>
      'Les lectures de plaques sont réservées à la gestion et à la sécurité';

  @override
  String anprGuven(Object oran) {
    return 'Confiance $oran %';
  }

  @override
  String get anprOnayla => 'Approuver';

  @override
  String get anprReddet => 'Rejeter';

  @override
  String get anprOnayBaslik => 'Approuver la lecture';

  @override
  String get anprOnayAciklama =>
      'Vous pouvez corriger la plaque si elle a été mal lue. L’approbation ouvre ou clôt le passage.';

  @override
  String get anprKararUygulandi => 'Décision appliquée';

  @override
  String get anprOnayBeklemiyor =>
      'Cette lecture n’est plus en attente d’approbation';

  @override
  String get anprNedenDusukGuven => 'Faible confiance';

  @override
  String get anprNedenZatenIceride => 'Véhicule déjà à l’intérieur';

  @override
  String get anprNedenAcikGecisYok => 'Aucun passage ouvert';

  @override
  String get anprNedenOtomatikCikisKapali => 'Sortie automatique désactivée';

  @override
  String get anprNedenElleReddedildi => 'Rejetée manuellement';

  @override
  String get anprNedenPlakaBicimi => 'Plaque illisible';

  @override
  String get aracPlakaOkumalari => 'Lectures de plaques';

  @override
  String get kategoriGoruntuKirliligi => 'Pollution visuelle';

  @override
  String get fabSikayetBildir => 'Signaler une plainte de voisinage';

  @override
  String get sakinRolTipi => 'Type de relation';

  @override
  String get sakinRolMalik => 'Propriétaire';

  @override
  String get sakinRolKiraci => 'Locataire';

  @override
  String get sakinRolDegisme => 'Ne pas modifier';

  @override
  String get sakinRolAlt =>
      'Les charges sont imputées au locataire, les investissements au propriétaire.';

  @override
  String get sakinEposta => 'E-mail';

  @override
  String get sakinEpostaTemizle => 'Supprimer l’e-mail';

  @override
  String get sakinRolBagYok =>
      'Le résident doit être rattaché à un logement pour définir le type de relation';

  @override
  String get sikayetKuyruguBaslik => 'File des plaintes';

  @override
  String get sikayetSekmeYeni => 'Nouvelles';

  @override
  String get sikayetSekmeTumu => 'Toutes';

  @override
  String get sikayetOkunmamisYok => 'Aucune plainte non lue.';

  @override
  String get sikayetYokYonetim => 'Aucune plainte pour l\'instant.';

  @override
  String get sikayetOkunduIsaretle => 'Marquer comme lu';

  @override
  String sikayetOkunmamisRozet(int sayi) {
    return '$sayi plaintes non lues';
  }

  @override
  String get kameraHataAdresBozuk =>
      'L\'adresse du flux est invalide. Elle contient peut-être un espace ou un saut de ligne.';

  @override
  String get kameraHataSemaDesteklenmiyor =>
      'Ce type d\'adresse ne peut pas être lu directement. Définissez une adresse de rediffusion pour la caméra.';

  @override
  String get kameraHataSifrelenmemis =>
      'Le flux non chiffré (http) a été bloqué par l\'appareil. Un profil professionnel ou un VPN peut l\'interdire.';

  @override
  String kameraUrlCokUzun(int sinir) {
    return 'L\'adresse du flux est trop longue (maximum $sinir caractères).';
  }

  @override
  String get kameraUrlSifrelenmemisUyari =>
      'Cette adresse n\'est pas chiffrée (http). Utilisez https si possible.';

  @override
  String get modulDaireTanimlari => 'Types de logement';

  @override
  String get daireTanimSekmeTipler => 'Types';

  @override
  String get daireTanimSekmeGruplar => 'Groupes';

  @override
  String get daireTanimAd => 'Nom';

  @override
  String get daireTanimAdIpucu => 'p. ex. 2+1, duplex, Villa';

  @override
  String get daireTanimVarsayilanAidat => 'Charges par défaut';

  @override
  String get daireTanimAidatBos => 'Non défini';

  @override
  String get daireTanimAidatAlt =>
      'Vide signifie non défini ; 0 signifie exonéré.';

  @override
  String daireTanimDaireSayisi(int sayi) {
    return '$sayi lots';
  }

  @override
  String daireTanimSilOnay(int sayi) {
    return 'Supprimer cette définition ? Les $sayi lots liés ne sont PAS supprimés ; seule leur classification est effacée.';
  }

  @override
  String daireTanimSilindiEtki(int sayi) {
    return 'Supprimé. $sayi lots ont perdu leur classification.';
  }

  @override
  String get daireTanimYok => 'Aucune définition.';

  @override
  String get daireTanimYeni => 'Nouvelle définition';

  @override
  String get daireTipiSecici => 'Type de lot';

  @override
  String get daireGrubuSecici => 'Groupe de lots';

  @override
  String get daireTanimSecilmedi => 'Non sélectionné';

  @override
  String get odeBaslik => 'Payer';

  @override
  String get odeBorcunuz => 'Montant impayé';

  @override
  String get odeHavaleBaslik => 'Virement bancaire';

  @override
  String get odeHavaleAdim =>
      'Virez sur l\'IBAN et indiquez le code ci-dessous en libellé. Sans ce code, votre paiement risque de ne pas être rapproché.';

  @override
  String get odeKodBaslik => 'Votre code de référence';

  @override
  String get odeKopyala => 'Copier';

  @override
  String get odeKopyalandi => 'Copié';

  @override
  String get odeKartBaslik => 'Payer par carte';

  @override
  String get odeKartKapali =>
      'Le paiement par carte n\'est pas encore activé. Utilisez un virement pour l\'instant.';

  @override
  String get odeHavaleKapali =>
      'Aucun compte bancaire n\'a encore été défini pour la résidence. Contactez la gestion.';

  @override
  String get odeBorcYok => 'Vous n\'avez aucune dette en cours.';

  @override
  String get odeBasarili => 'Votre paiement a été reçu.';

  @override
  String get nfcFotoGerekli => 'Une photo est requise pour démarrer la ronde.';

  @override
  String get nfcFotoCek => 'Prendre une photo et envoyer';

  @override
  String get nfcFotoYukleniyor => 'Envoi de la photo...';

  @override
  String nfcFotoYuklenemedi(String hata) {
    return 'Échec de l\'envoi de la photo : $hata';
  }

  @override
  String get nfcKonumYok =>
      'Position indisponible — le scan a été enregistré sans elle.';

  @override
  String get nfcKonumIzinYok =>
      'Autorisation de localisation refusée — scan enregistré sans position.';

  @override
  String get nfcKonumServisKapali =>
      'Services de localisation désactivés — scan enregistré sans position.';

  @override
  String get rolGuvenlikAmiri => 'Chef de la sécurité';

  @override
  String get rolDenetci => 'Auditeur';

  @override
  String get kvkkBaslik => 'Notice d\'information';

  @override
  String get kvkkSonaKaydir =>
      'Faites défiler jusqu\'à la fin du texte pour approuver.';

  @override
  String get kvkkOnayliyorum => 'J\'ai lu et j\'approuve';

  @override
  String get kvkkYuklenemedi => 'Impossible de charger la notice.';

  @override
  String get kvkkTekrarDene => 'Réessayer';

  @override
  String get kvkkSurumDegisti =>
      'Le texte a été mis à jour ; veuillez lire la nouvelle version.';

  @override
  String get kvkkIzinBaslik => 'Campagnes et offres pour moi';

  @override
  String get kvkkIzinAciklama =>
      'Entièrement facultatif ; vous pouvez continuer sans approuver. Modifiable à tout moment dans les Réglages.';

  @override
  String get kvkkIzinEposta => 'Je souhaite recevoir des e-mails';

  @override
  String get kvkkIzinSms => 'Je souhaite recevoir des SMS';

  @override
  String get kvkkIzinArama => 'Je souhaite être appelé(e)';

  @override
  String get kvkkIzinKaydedilemedi =>
      'Impossible d\'enregistrer la préférence.';

  @override
  String get kvkkAyarlarBaslik => 'Autorisations et notice d\'information';

  @override
  String get kvkkMetniGoruntule => 'Consulter la notice d\'information';

  @override
  String get anketBaslik => 'Sondages';

  @override
  String get anketYok => 'Aucun sondage ouvert pour le moment.';

  @override
  String get anketKapali => 'Clos';

  @override
  String get anketOyVerdiniz => 'Votre vote a été enregistré';

  @override
  String get anketOyVer => 'Voter';

  @override
  String anketToplamOy(int sayi) {
    return '$sayi votes';
  }

  @override
  String anketOyHatasi(String hata) {
    return 'Le vote n\'a pas pu être envoyé : $hata';
  }

  @override
  String get anketSonucKapali => 'Les résultats s\'affichent à la clôture.';

  @override
  String get modulAnketler => 'Sondages';

  @override
  String get hesapSilBolum => 'Compte';

  @override
  String get hesapSilBaslik => 'Supprimer mon compte';

  @override
  String get hesapSilAlt =>
      'Supprimer définitivement votre compte et vos données personnelles';

  @override
  String get hesapSilOnayBaslik => 'Supprimer votre compte ?';

  @override
  String get hesapSilOnayGovde =>
      'Votre nom, votre numéro de téléphone, votre adresse e-mail et vos enregistrements d\'appareils seront supprimés et vous ne pourrez plus vous connecter. Les enregistrements de charges et de paiements ne peuvent pas être supprimés car la loi nous oblige à les conserver ; ils resteront stockés de manière anonyme et ne seront plus liés à votre nom.';

  @override
  String get hesapSilParolaEtiket => 'Votre mot de passe';

  @override
  String get hesapSilParolaAciklama =>
      'Saisissez à nouveau votre mot de passe par sécurité.';

  @override
  String get hesapSilOnayla => 'Supprimer définitivement mon compte';

  @override
  String get hesapSilSonucSilindi => 'Votre compte a été supprimé.';

  @override
  String get hesapSilSonucAnonim =>
      'Votre compte a été supprimé. Les enregistrements que la loi nous oblige à conserver ont été anonymisés.';

  @override
  String get hesapSilParolaGerekli =>
      'Saisissez votre mot de passe pour continuer.';

  @override
  String get hesapSilSiliniyor => 'Suppression...';

  @override
  String get ayarlarHukuki => 'Mentions légales';

  @override
  String get ayarlarGizlilik => 'Politique de confidentialité';

  @override
  String get ayarlarKosullar => 'Conditions d\'utilisation';

  @override
  String get ayarlarBelgeAcilamadi =>
      'La page n\'a pas pu être ouverte. Vérifiez votre connexion Internet.';

  @override
  String get demoSimuleOkutma => 'Scan simulé';

  @override
  String demoSimuleOkutmaBasarili(String nokta) {
    return 'Scan simulé enregistré : $nokta';
  }

  @override
  String get demoSimuleOkutmaHata =>
      'Le scan simulé n\'a pas pu être enregistré.';

  @override
  String get denetciWebBaslik => 'Les écrans d\'audit sont sur le web';

  @override
  String denetciWebGovde(String adres) {
    return 'Les rapports d\'audit et la supervision financière sont conçus pour le bureau. Ouvrez $adres sur votre ordinateur.';
  }

  @override
  String get denetciWebKopyala => 'Copier l\'adresse';

  @override
  String get modulVardiyalar => 'Services';

  @override
  String get izgaraDuzenleBaslik => 'Modifier l\'écran d\'accueil';

  @override
  String izgaraDuzenleAciklama(int enCok) {
    return 'Choisissez jusqu\'à $enCok sections que vous utilisez le plus.';
  }

  @override
  String get izgaraSifirla => 'Rétablir les valeurs par défaut';

  @override
  String get izgaraKaydet => 'Enregistrer';

  @override
  String izgaraSecim(int secili, int enCok) {
    return '$secili/$enCok sélectionnés';
  }

  @override
  String izgaraTavanUyarisi(int enCok) {
    return 'Limite atteinte. Retirez-en un pour en ajouter un autre ($enCok tuiles).';
  }

  @override
  String get dilSeciciBaslik => 'Langue';

  @override
  String get talepGeriAl => 'Retirer';

  @override
  String get talepGeriAlOnay =>
      'Retirer cette demande ? Une demande retirée n\'est pas transmise à la gestion et cette action est irréversible.';

  @override
  String get talepGeriAlindi => 'Demande retirée';

  @override
  String get talepDurumGeriAlindi => 'Retirée';

  @override
  String get sikayetGeriAl => 'Retirer la plainte';

  @override
  String get sikayetGeriAlindi => 'Plainte retirée';

  @override
  String get izinDevam => 'Continuer';

  @override
  String get izinKonumBaslik =>
      'Pourquoi la localisation est-elle nécessaire ?';

  @override
  String get izinKonumGovde =>
      'Lorsque vous scannez un point de contrôle, votre position à cet instant est enregistrée pour confirmer que la ronde a bien été effectuée sur place. La position est relevée UNIQUEMENT au moment du scan ; l\'application ne vous suit pas en arrière-plan.';

  @override
  String get izinKameraBaslik =>
      'Pourquoi l\'appareil photo est-il nécessaire ?';

  @override
  String get izinKameraGovde =>
      'L\'appareil photo permet de joindre une photo lors du signalement d\'une demande ou d\'une panne. Une photo n\'est prise que par vous et elle est envoyée à la gestion.';

  @override
  String get girisKodlaBaslik =>
      'Pas de mot de passe – se connecter avec un code';

  @override
  String get girisKodlaAciklama =>
      'Nous enverrons un code de vérification à six chiffres sur votre téléphone.';

  @override
  String get girisKoduGonder => 'Envoyer le code';

  @override
  String get girisKodAlani => 'Code de vérification';

  @override
  String get hesapSilKodlaOnayla =>
      'Pas de mot de passe – confirmer avec un code';

  @override
  String get hesapSilKodAciklama =>
      'Nous enverrons un code à six chiffres sur votre téléphone pour confirmer la suppression.';

  @override
  String get hesapSilKodGerekli => 'Saisissez le code de confirmation';

  @override
  String get kayitBaslik => 'S\'inscrire';

  @override
  String get kayitAltBaslik => 'Choisissez ce qui vous correspond';

  @override
  String get kayitRolYonetici => 'Gestionnaire';

  @override
  String get kayitRolSakin => 'Résident';

  @override
  String get kayitRolGuvenlik => 'Agent de sécurité';

  @override
  String get kayitRolTesisGorevlisi => 'Agent d\'établissement';

  @override
  String get kayitTesisKodu => 'ID de l\'établissement';

  @override
  String get kayitTesisKoduIpucu =>
      'Le code fourni par votre gestion (ex. OLTU-260715)';

  @override
  String get kayitDaireNo => 'N° de logement';

  @override
  String get kayitBlok => 'Bloc (le cas échéant)';

  @override
  String get kayitDevam => 'Continuer';

  @override
  String get kayitKodBaslik => 'Code de vérification';

  @override
  String kayitKodAciklama(String tesis, String telefon) {
    return 'Un code a été envoyé au $telefon pour $tesis. Si le numéro n\'est pas enregistré, aucun code n\'arrivera.';
  }

  @override
  String get kayitKodAlani => 'Code à 6 chiffres';

  @override
  String get kayitTesisKoduGerekli => 'L\'ID de l\'établissement est requis.';

  @override
  String get kayitDaireGerekli => 'Le n° de logement est requis.';

  @override
  String get kayitKodGerekli => 'Saisissez le code.';

  @override
  String get kayitYontemBaslik => 'Comment vous connecterez-vous ?';

  @override
  String get kayitYontemParola => 'Créer un mot de passe';

  @override
  String get kayitGirisLinki => 'Vous avez déjà un compte ? Se connecter';

  @override
  String kayitAdim(String n, String toplam) {
    return 'Étape $n/$toplam';
  }

  @override
  String sosyalIleDevam(String saglayici) {
    return 'Continuer avec $saglayici';
  }

  @override
  String get sosyalBaslik => 'Associer votre compte';

  @override
  String sosyalEslesmeAciklama(String saglayici) {
    return 'Votre compte $saglayici est vérifié. Saisissez l\'identifiant du site et votre numéro de téléphone pour que nous trouvions votre compte.';
  }

  @override
  String get sosyalRelayUyari =>
      'Apple a masqué votre adresse e-mail ; aucun courrier ne peut y être envoyé.';

  @override
  String get sosyalTesisKodu => 'Identifiant du site';

  @override
  String get sosyalKodGonder => 'Envoyer le code de vérification';

  @override
  String sosyalKodAciklama(String tesis, String telefon) {
    return '$tesis — saisissez le code envoyé au $telefon.';
  }

  @override
  String get sosyalDogrula => 'Vérifier et se connecter';

  @override
  String get sosyalVazgec => 'Annuler';

  @override
  String get davetBaslik => 'Inscription';

  @override
  String get davetGecersizBaslik => 'Le lien ne fonctionne pas';

  @override
  String get davetSuresiDoldu => 'Ce lien d\'invitation a expiré.';

  @override
  String get davetKullanilmis => 'Cette invitation a déjà été utilisée.';

  @override
  String get davetBulunamadi => 'Ce lien d\'invitation n\'est pas valide.';

  @override
  String get davetYoneticinizeBasvurun =>
      'Contactez votre gestionnaire pour une nouvelle invitation.';

  @override
  String davetOzet(String tesis, String rol) {
    return '$tesis vous a invité en tant que $rol.';
  }

  @override
  String get kayitYontemEposta => 'S\'inscrire avec e-mail/téléphone';

  @override
  String get kayitYontemVeya => 'ou';

  @override
  String get kayitBilgilerBaslik => 'Vos informations';

  @override
  String get kayitAdSoyad => 'Nom et prénom';

  @override
  String get kayitAdGerekli => 'Le nom et prénom est obligatoire.';

  @override
  String get kayitParola => 'Mot de passe';

  @override
  String get kayitParolaGerekli =>
      'Le mot de passe doit comporter au moins 8 caractères.';

  @override
  String get kayitTesisAdBaslik => 'Créez votre résidence';

  @override
  String get kayitTesisAd => 'Saisissez le nom de la résidence';

  @override
  String get kayitTesisAdIpucu => 'p. ex. Résidence Oltu';

  @override
  String get kayitTesisAdGerekli => 'Le nom de la résidence est obligatoire.';

  @override
  String get kayitZatenSitemVar => 'J\'ai déjà une résidence';

  @override
  String get kayitTesisKoduBaslik => 'Votre code de résidence';

  @override
  String get kayitTesisKoduPaylas =>
      'Communiquez ce code à vos résidents et à votre personnel ; il leur permet de vous rejoindre.';

  @override
  String get kayitKopyala => 'Copier';

  @override
  String get kayitKopyalandi => 'Copié';

  @override
  String get kayitTamamla => 'Continuer';

  @override
  String get kayitSosyalAdNotu =>
      'Nom repris de votre compte ; vous pouvez le modifier.';

  @override
  String get binaYapisalAraclar => 'Outils structurels';

  @override
  String get binaKatSil => 'Supprimer l\'étage';

  @override
  String get binaTopluTip => 'Modifier le statut en lot';

  @override
  String get binaSiralama => 'Modifier l\'ordre';

  @override
  String binaKatSilOzet(int n) {
    return '$n logements seront supprimés';
  }

  @override
  String binaKatSilOnay(int kat) {
    return 'Tous les logements de l\'étage $kat seront définitivement supprimés. Action irréversible.';
  }

  @override
  String get binaAralikSec => 'Sélectionner par numéro';

  @override
  String get binaAralikUygula => 'Sélectionner';

  @override
  String binaSeciliSayisi(int n) {
    return '$n logements sélectionnés';
  }

  @override
  String binaAralikBulunamayan(String parca) {
    return 'Introuvable : $parca';
  }

  @override
  String get ortakEminMisiniz => 'Êtes-vous sûr ?';

  @override
  String get ortakDurum => 'Statut';

  @override
  String get ortakAktif => 'Actif';

  @override
  String get ortakPasif => 'Inactif';

  @override
  String get binaBaslangicKat => 'Étage de départ';

  @override
  String get binaBaslangicKatIpucu =>
      'Négatif pour les sous-sols : -2, -1, 0 (RDC), 1…';

  @override
  String get rezSekmeGecmis => 'Passées';

  @override
  String get rezGecmisYok => 'Aucune réservation passée.';

  @override
  String get rezGecmisTamam => 'Terminée';

  @override
  String rezIptalEden(String ad) {
    return 'Annulé par : $ad';
  }

  @override
  String get binaKatBos =>
      'Aucun logement à cet étage ; la suppression n\'affecte aucun enregistrement.';

  @override
  String binaKatOzet(int daire, int sakin, int talep) {
    return '$daire logements · $sakin résidents · $talep réclamations ouvertes';
  }

  @override
  String binaKatOzetMali(int tahakkuk, int odeme, int rezervasyon) {
    return '$tahakkuk appels de charges · $odeme paiements · $rezervasyon réservations';
  }

  @override
  String get binaKatMaliUyari =>
      'Cet étage comporte des données de charges. La suppression efface définitivement les appels et les paiements ; la piste comptable est irrécupérable. Envisagez plutôt de désactiver les logements.';

  @override
  String binaKatOnayYaz(int kat) {
    return 'Saisissez le numéro d\'étage pour confirmer ($kat)';
  }

  @override
  String binaKatSilOzetOnay(
    String blok,
    int kat,
    int daire,
    int sakin,
    int kayit,
  ) {
    return 'L\'étage $kat du bloc $blok sera supprimé : $daire logements, $sakin résidents et $kayit enregistrements liés seront définitivement effacés. Action irréversible.';
  }

  @override
  String get kurulumBaslik => 'Assistant de configuration';

  @override
  String get kurulumAlt =>
      'Terminez les étapes pour rendre votre site opérationnel.';

  @override
  String get kurulumIlerleme => 'Progression';

  @override
  String get kurulumTamamlandi => 'Configuration terminée';

  @override
  String kurulumAdimTamam(int sayi) {
    return '$sayi enregistrements';
  }

  @override
  String get kurulumAdimAtlandi => 'Ignoré';

  @override
  String get kurulumAdimBekliyor => 'En attente';

  @override
  String get kurulumGit => 'Aller';

  @override
  String get kurulumGoruntule => 'Voir';

  @override
  String get kurulumAtla => 'Ignorer';

  @override
  String get kurulumAtlamayiGeriAl => 'Annuler l\'omission';

  @override
  String kurulumSayac(int gecilen, int toplam) {
    return '$gecilen/$toplam étapes';
  }

  @override
  String get kurulumHata =>
      'Impossible de charger l\'état de la configuration.';

  @override
  String get kurulumBlok => 'Blocs';

  @override
  String get kurulumBlokAlt => 'Définissez les blocs du bâtiment.';

  @override
  String get kurulumDaire => 'Logements';

  @override
  String get kurulumDaireAlt => 'Créez les étages et logements en lot.';

  @override
  String get kurulumDaireTipi => 'Types de logement';

  @override
  String get kurulumDaireTipiAlt =>
      'Définissez les types et montants de charges par défaut.';

  @override
  String get kurulumSakin => 'Résidents';

  @override
  String get kurulumSakinAlt => 'Ajoutez les résidents aux logements.';

  @override
  String get kurulumPersonel => 'Personnel';

  @override
  String get kurulumPersonelAlt => 'Saisissez les fiches du personnel.';

  @override
  String get kurulumGorevAlani => 'Catégories de tâches';

  @override
  String get kurulumGorevAlaniAlt =>
      'Créez les catégories qui regrouperont vos tâches.';

  @override
  String get kurulumNfc => 'Points NFC';

  @override
  String get kurulumNfcAlt => 'Définissez les points de contrôle des rondes.';

  @override
  String get kurulumAidat => 'Appel de charges';

  @override
  String get kurulumAidatAlt => 'Émettez les charges de la première période.';

  @override
  String get kurulumAdimWebde =>
      'Cette étape n\'est possible que depuis le panneau web avec un compte administrateur de plateforme.';

  @override
  String get kurulumHatirlaticiBaslik => 'Terminer la configuration';

  @override
  String get kurulumHatirlaticiMetin =>
      'Quelques étapes restent avant que votre site soit prêt. L\'assistant vous conduit à chaque écran.';

  @override
  String get kurulumHatirlaticiGit => 'Ouvrir l\'assistant';

  @override
  String get kurulumHatirlaticiSonra => 'Plus tard';

  @override
  String get noktaYokAlt =>
      'Les points de contrôle sont les étiquettes NFC scannées pendant les rondes.';

  @override
  String get devriyePlanYokAlt =>
      'Un plan de ronde définit quels points sont scannés et quand.';

  @override
  String get personelYokAlt =>
      'Créez ici les comptes des agents de sécurité et d\'entretien.';

  @override
  String get sakinYokAlt =>
      'Les résidents ajoutés sont liés aux logements et peuvent se connecter.';

  @override
  String get ortakDahaFazlaSecenek => 'Plus d\'options';

  @override
  String get modulDokumanlar => 'Documents du site';

  @override
  String get dokumanBaslik => 'Documents du site';

  @override
  String get dokumanAra => 'Rechercher dans les noms de documents';

  @override
  String get dokumanYokSakin => 'Aucun document n\'a encore été partagé.';

  @override
  String get dokumanAramaSonucYok =>
      'Aucun document ne correspond à votre recherche.';

  @override
  String get dokumanAcilamadi => 'Le document n\'a pas pu être ouvert.';

  @override
  String dokumanBoyutKb(int kb) {
    return '$kb Ko';
  }

  @override
  String get kvkkYasalMetinler => 'Textes juridiques';

  @override
  String get kvkkTurAydinlatma => 'Note d\'information';

  @override
  String get kvkkTurAcikRiza => 'Consentement explicite';

  @override
  String get kvkkTurGizlilik => 'Politique de confidentialité';

  @override
  String get kvkkTurKullanim => 'Conditions d\'utilisation';

  @override
  String get kvkkTurCerez => 'Politique de cookies';

  @override
  String get kvkkMetinYayinlanmamis => 'Ce texte n\'a pas encore été publié.';

  @override
  String get kvkkOnaylanmadi => 'Vous n\'avez pas encore consenti à ce texte.';

  @override
  String get kvkkYenidenOnayBekleniyor =>
      'Votre consentement est attendu pour la version actuelle.';

  @override
  String kvkkSurumEtiketi(int n) {
    return 'Version $n';
  }

  @override
  String kvkkOnayladiginizSurum(int n) {
    return 'Version à laquelle vous avez consenti : $n';
  }

  @override
  String get kabukKisayollar => 'Raccourcis';

  @override
  String get ayarlarBildirimlerBaslik => 'Notifications';

  @override
  String get ayarlarBildirimTercih => 'Préférences de notification';

  @override
  String get ayarlarBildirimAciklama =>
      'Choisissez les canaux par lesquels vous recevez les notifications opérationnelles. C\'est distinct du consentement marketing.';

  @override
  String get ayarlarBildirimEposta => 'Notifications par e-mail';

  @override
  String get ayarlarBildirimSms => 'Notifications par SMS';

  @override
  String get ayarlarBildirimMobil => 'Notifications mobiles';

  @override
  String get ayarlarBildirimKaydedildi =>
      'Préférence de notification mise à jour';

  @override
  String get ayarlarBildirimYuklenemedi =>
      'Impossible de charger les préférences de notification';

  @override
  String get ayarlarBildirimIzinKapali =>
      'L\'autorisation de notification de l\'appareil est désactivée. Les notifications mobiles n\'apparaîtront pas sur le téléphone ; activez-la dans les réglages de l\'appareil.';

  @override
  String get ayarlarBildirimIzinBelirsiz =>
      'Une autorisation est nécessaire pour afficher les notifications.';

  @override
  String get ayarlarBildirimIzinIste => 'Demander l\'autorisation';
}
