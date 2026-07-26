// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get cipYeni => 'Nuevo';

  @override
  String get cipAktif => 'Activo';

  @override
  String get bolumVardiyaDurumu => 'Estado de turnos';

  @override
  String get bolumSonHareketler => 'Actividad reciente';

  @override
  String get bolumHizliOzet => 'Resumen rápido';

  @override
  String get bolumDuyurular => 'Anuncios';

  @override
  String get bolumSiteKurallari => 'Normas del complejo';

  @override
  String get bolumEtkinlikler => 'Eventos';

  @override
  String get bolumOdemeAidat => 'Pagos y cuotas';

  @override
  String get bolumTumModuller => 'Todos los módulos';

  @override
  String get kartVardiyaDurum => 'Turno';

  @override
  String get kartKargo => 'Paquetes';

  @override
  String get kartZiyaretci => 'Visitantes';

  @override
  String get kartAracPlaka => 'Vehículos';

  @override
  String get kartIhlaller => 'Infracciones';

  @override
  String get kartGorevlerim => 'Mis tareas';

  @override
  String get kartDemirbas => 'Inventario';

  @override
  String get kartTurlarim => 'Mis rondas';

  @override
  String get kartTalepAriza => 'Solicitudes';

  @override
  String get kartZiyaretciler => 'Visitantes';

  @override
  String get kartKargolarim => 'Mis paquetes';

  @override
  String get kartAidatBilgileri => 'Cuotas';

  @override
  String get kartGurultuSikayeti => 'Queja por ruido';

  @override
  String get kartGeriBildirim => 'Comentarios';

  @override
  String get kartSikayetlerim => 'Mis quejas';

  @override
  String get kartSiteRaporlari => 'Informes del complejo';

  @override
  String get kartGorevler => 'Tareas';

  @override
  String get kartAidatDurumu => 'Estado de cuotas';

  @override
  String get kartOtoparkKullanimi => 'Uso del aparcamiento';

  @override
  String get kartSikayetler => 'Quejas';

  @override
  String get kartRaporlar => 'Informes';

  @override
  String get kartYonetici => 'Administrador';

  @override
  String get kartGonderimKuyrugu => 'Cola de envío';

  @override
  String get etiketAylikOzet => 'Resumen mensual';

  @override
  String get etiketDevriye => 'Ronda';

  @override
  String get etiketKurallar => 'Normas';

  @override
  String get etiketIletisim => 'Contacto';

  @override
  String sayacAktif(num n) {
    return '$n activos';
  }

  @override
  String sayacIceride(num n) {
    return '$n dentro';
  }

  @override
  String sayacGiris(num n) {
    return '$n entradas';
  }

  @override
  String sayacYeni(num n) {
    return '$n nuevos';
  }

  @override
  String sayacAcik(num n) {
    return '$n abiertos';
  }

  @override
  String sayacZimmetli(num n) {
    return '$n en préstamo';
  }

  @override
  String sayacKayit(num n) {
    return '$n registros';
  }

  @override
  String sayacYaklasan(num n) {
    return '$n próximos';
  }

  @override
  String sayacDaire(num n) {
    return '$n viviendas';
  }

  @override
  String sayacArac(num n) {
    return '$n vehículos';
  }

  @override
  String sayacGorevli(num n) {
    return '$n agentes';
  }

  @override
  String sayacBekleyen(num n) {
    return '$n en espera';
  }

  @override
  String get ozetToplamDaire => 'Viviendas totales';

  @override
  String get ozetToplamTahsilat => 'Total recaudado';

  @override
  String get ozetTahsilatOrani => 'Tasa de cobro';

  @override
  String get ozetOtoparkDoluluk => 'Ocupación del aparcamiento';

  @override
  String get ozetTumSite => 'Todo el complejo';

  @override
  String get ozetBuAy => 'Este mes';

  @override
  String get ozetSuAn => 'Ahora';

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
    return 'Hola, $ad';
  }

  @override
  String get anaYoneticiPaneli => 'Panel del administrador';

  @override
  String anaDaireAltBaslik(Object daireler, Object rol) {
    return 'Vivienda $daireler  •  $rol';
  }

  @override
  String get anaDun => 'Ayer';

  @override
  String get anaOnline => 'En línea';

  @override
  String get anaVardiyaAktif => 'Activo';

  @override
  String get anaVardiyaPlanlandi => 'Programado';

  @override
  String get anaEtkinlikSuruyor => 'En curso';

  @override
  String get anaEtkinlikYaklasan => 'Próximo';

  @override
  String get anaOdendi => 'Pagado';

  @override
  String get anaOdenmedi => 'Sin pagar';

  @override
  String get anaBorcVar => 'Saldo pendiente';

  @override
  String get anaBorcYok => 'Sin saldo';

  @override
  String get anaBuAykiAidat => 'Cuotas de este mes';

  @override
  String anaSonOdemeTarih(Object tarih) {
    return 'Último pago: $tarih';
  }

  @override
  String get anaGelecekOdeme => 'Próximo pago';

  @override
  String get anaGecmisOdemeler => 'Historial de pagos';

  @override
  String get anaAidatKaydiYok => 'No se encontraron cuotas';

  @override
  String get anaBildirimlerYakinda => 'Notificaciones próximamente';

  @override
  String get anaBildirimlerRolYok =>
      'Las notificaciones no están disponibles para este rol';

  @override
  String get anaRaporlarYakinda => 'Informes próximamente';

  @override
  String get sekmeAnaSayfa => 'Inicio';

  @override
  String get sekmeBildirimler => 'Notificaciones';

  @override
  String get sekmeRaporlar => 'Informes';

  @override
  String get sekmeAyarlar => 'Ajustes';

  @override
  String get kabukProfil => 'Perfil';

  @override
  String get kabukCikisYap => 'Cerrar sesión';

  @override
  String get fabOlayBildir => 'Reportar incidencia';

  @override
  String get fabTalepBildir => 'Solicitud / aviso';

  @override
  String get fabTalepArizaBildir => 'Reportar solicitud o avería';

  @override
  String get fabRezervasyonYap => 'Reservar';

  @override
  String get fabDuyuruYayinla => 'Publicar anuncio';

  @override
  String get fabGorevOlustur => 'Crear tarea';

  @override
  String get fabDestekTalebi => 'Solicitud de soporte';

  @override
  String get modulDuyurular => 'Anuncios';

  @override
  String get modulTurlarim => 'Mis rondas';

  @override
  String get modulDevriyeTakibi => 'Seguimiento de rondas';

  @override
  String get modulGorevlerim => 'Mis tareas';

  @override
  String get modulGorevYonetimi => 'Gestión de tareas';

  @override
  String get modulDemirbas => 'Inventario';

  @override
  String get modulNfcOkutma => 'Lectura NFC';

  @override
  String get modulGonderimKuyrugu => 'Cola de envío';

  @override
  String get modulAylikRaporlar => 'Informes mensuales';

  @override
  String get modulButce => 'Presupuesto';

  @override
  String get modulFinansalOzet => 'Resumen financiero';

  @override
  String get modulSeffaflik => 'Transparencia';

  @override
  String get modulSiteButcesi => 'Presupuesto del complejo';

  @override
  String get modulAidatim => 'Mis cuotas';

  @override
  String get modulSikayetOneri => 'Queja / sugerencia';

  @override
  String get modulZiyaretciler => 'Visitantes';

  @override
  String get modulKargo => 'Paquetes';

  @override
  String get modulGoruntulemeIzni => 'Permiso de visualización';

  @override
  String get modulRezervasyon => 'Reservas';

  @override
  String get modulEtkinlikler => 'Eventos';

  @override
  String get modulSiteKurallari => 'Normas del complejo';

  @override
  String get modulDisHizmetler => 'Servicios externos';

  @override
  String get modulEntegrasyonlar => 'Integraciones';

  @override
  String get modulPersonel => 'Personal de campo';

  @override
  String get modulSakinler => 'Residentes';

  @override
  String get modulBinaYapisi => 'Estructura del edificio';

  @override
  String get modulSikayetHaritasi => 'Mapa de quejas';

  @override
  String get modulSikayetlerim => 'Mis quejas';

  @override
  String get modulYoneticiIletisim => 'Contacto del administrador';

  @override
  String get ortakKaydet => 'Guardar';

  @override
  String sayacBekliyor(num n) {
    return '$n pendientes';
  }

  @override
  String get ortakKaydediliyor => 'Guardando...';

  @override
  String get ortakVazgec => 'Cancelar';

  @override
  String get ortakSil => 'Eliminar';

  @override
  String get ortakDuzenle => 'Editar';

  @override
  String get ortakEkle => 'Añadir';

  @override
  String get ortakTamam => 'Aceptar';

  @override
  String get ortakKapat => 'Cerrar';

  @override
  String get ortakTumunuGor => 'Ver todo';

  @override
  String get ortakYuklenemedi => 'No se pudo cargar';

  @override
  String get ortakYenidenDene => 'Reintentar';

  @override
  String get ortakYakinda => 'Próximamente';

  @override
  String get ortakBolumYakinda => 'Esta sección estará disponible pronto';

  @override
  String get ortakBeklenmeyenHata =>
      'Se produjo un error inesperado. Inténtalo de nuevo.';

  @override
  String ortakZorunluAlan(Object alan) {
    return '$alan es obligatorio';
  }

  @override
  String get ayarlarBaslik => 'Ajustes';

  @override
  String get ayarlarTesis => 'Instalación';

  @override
  String get ayarlarYonetim => 'Administración';

  @override
  String get ayarlarGorunum => 'Apariencia';

  @override
  String get ayarlarTema => 'Tema';

  @override
  String get ayarlarTemaSistem => 'Sistema';

  @override
  String get ayarlarTemaAcik => 'Claro';

  @override
  String get ayarlarTemaKoyu => 'Oscuro';

  @override
  String get ayarlarTemaAciklama =>
      'El tema oscuro se aplica a todas las pantallas; «Sistema» sigue el ajuste del dispositivo.';

  @override
  String get ayarlarTesisAdi => 'Nombre de la instalación';

  @override
  String get ayarlarTesisAdiAciklama =>
      'El nombre que aparece en la pantalla de inicio y en los informes.';

  @override
  String get ayarlarTesisAdiGuncellendi =>
      'Nombre de la instalación actualizado';

  @override
  String get ayarlarKameralar => 'Cámaras';

  @override
  String get ayarlarKameralarAlt => 'Añadir, editar y eliminar cámaras';

  @override
  String get ayarlarDil => 'Idioma / Language';

  @override
  String get dilSecBaslik => 'Idioma de la aplicación';

  @override
  String get kameraBaslik => 'Cámaras';

  @override
  String get kameraEkle => 'Añadir cámara';

  @override
  String get kameraYeni => 'Nueva cámara';

  @override
  String get kameraDuzenleBaslik => 'Editar cámara';

  @override
  String get kameraAd => 'Nombre';

  @override
  String get kameraKonum => 'Ubicación (opcional)';

  @override
  String get kameraTur => 'Tipo';

  @override
  String get kameraUrl => 'URL de emisión';

  @override
  String get kameraAktif => 'Activa';

  @override
  String get kameraAktifAlt =>
      'Si está desactivada, no aparece en ninguna lista';

  @override
  String get kameraSakinGorebilir => 'Visible para los residentes';

  @override
  String get kameraSakinGorebilirAlt =>
      'Si está desactivada, solo la ven la administración y seguridad';

  @override
  String get kameraRtspFormUyari =>
      'Las emisiones RTSP todavía no se pueden reproducir en la aplicación. El registro se conserva; la reproducción se añadirá más adelante.';

  @override
  String get kameraUrlZorunlu => 'La dirección de emisión es obligatoria';

  @override
  String kameraUrlHataHttp(Object tur) {
    return 'La dirección de emisión $tur debe empezar por http:// o https://';
  }

  @override
  String get kameraUrlHataRtsp => 'La dirección RTSP debe empezar por rtsp://';

  @override
  String get kameraSilBaslik => 'Eliminar cámara';

  @override
  String kameraSilOnay(Object ad) {
    return '¿Eliminar «$ad»?';
  }

  @override
  String get kameraBosYonetim =>
      'No hay cámaras. Añade una desde abajo a la derecha.';

  @override
  String get kameraBosSakin => 'No hay cámaras disponibles para ti.';

  @override
  String get kameraListeHata => 'No se pudieron cargar las cámaras.';

  @override
  String get kameraCanli => 'En directo';

  @override
  String get kameraOynatilamiyor => 'No reproducible';

  @override
  String get kameraYayinAcilamadi => 'No se pudo abrir la emisión';

  @override
  String get kameraYayinAcilamadiAlt =>
      'La cámara puede estar apagada o la red no alcanza la emisión.';

  @override
  String kameraTurEtiket(Object tur) {
    return 'Tipo: $tur';
  }

  @override
  String get kameraRtspBilgi =>
      'Las emisiones RTSP no se pueden reproducir ahora en la aplicación. El registro se conserva en el sistema; la reproducción se añadirá más adelante.';

  @override
  String get kameraSeritBaslik => 'Cámara en directo';

  @override
  String anaKarsilama(String ad) {
    return 'Hola, $ad';
  }
}
