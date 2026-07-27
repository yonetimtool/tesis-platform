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
}
