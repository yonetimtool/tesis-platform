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
  String get sekmeSeffaflik => 'Transparencia';

  @override
  String get sekmeGorevlerim => 'Mis tareas';

  @override
  String get sekmeAyarlar => 'Ajustes';

  @override
  String get kabukGrupGuvenlik => 'Seguridad';

  @override
  String get kabukGrupTesis => 'Instalación';

  @override
  String get kabukGrupFinans => 'Finanzas';

  @override
  String get kabukGrupIletisim => 'Comunicación';

  @override
  String get kabukGrupTanimlar => 'Definiciones';

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
  String get kameraKareYok => 'Imagen no disponible';

  @override
  String get kameraBaglantiYok => 'Sin conexión';

  @override
  String get kameraUrlWebSayfasi =>
      'Esta es la dirección de una página web. La aplicación solo reproduce URL de emisión directas: .m3u8 (HLS) o .mp4.';

  @override
  String get kameraKaynakYardim =>
      'Solo se reproducen URL de medios directas: HLS (.m3u8) y MP4. Las páginas web (YouTube, Vimeo, páginas de visor municipales) no se pueden reproducir. El RTSP se guarda, pero necesita una pasarela HLS para reproducirse.';

  @override
  String get kameraSnapshot => 'Dirección de la instantánea';

  @override
  String get kameraSnapshotAlt =>
      'Opcional. Si se indica, la lista de cámaras muestra un fotograma en vivo (un JPEG).';

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

  @override
  String get gorevKategorilerTooltip => 'Categorías';

  @override
  String get gorevYeni => 'Nueva tarea';

  @override
  String get gorevOlusturuldu => 'Tarea creada ✓';

  @override
  String get gorevListesiYetkiYok =>
      'No tiene permiso para ver la lista de tareas. Esta pantalla está abierta a los roles de limpieza y seguridad.';

  @override
  String get gorevBuFiltredeYok => 'No hay tareas activas con este filtro.';

  @override
  String get gorevCipBanaAtanan => 'Asignadas a mí';

  @override
  String get gorevCipTumGorevler => 'Todas las tareas';

  @override
  String get gorevCipTumu => 'Todos';

  @override
  String get gorevKategoriDiger => 'Otros';

  @override
  String gorevPlanlanan(Object zaman) {
    return 'Programado: $zaman';
  }

  @override
  String get gorevSanaAtanmis => 'Asignada a ti';

  @override
  String get gorevFotoZorunlu => 'Foto obligatoria';

  @override
  String get gorevTamamlandiZatenKayitli =>
      'Completada ✓ (ya estaba registrada)';

  @override
  String get gorevTamamlandiBuOturumda => 'Completada ✓ (en esta sesión)';

  @override
  String get gorevIslemleriTooltip => 'Acciones de tarea';

  @override
  String get gorevTakipGorunumu => 'Vista de seguimiento';

  @override
  String get gorevTakipGorunumuAlt =>
      'La finalización la realiza el personal de campo (seguridad / operario de instalaciones). Esta pantalla es de seguimiento.';

  @override
  String get gorevGonderiliyor => 'Enviando...';

  @override
  String get gorevTamamla => 'Completar';

  @override
  String get gorevGuncellendi => 'Tarea actualizada ✓';

  @override
  String get gorevSilinsinMi => '¿Eliminar la tarea?';

  @override
  String get gorevSilindi => 'Tarea eliminada ✓';

  @override
  String get gorevNfcAciklama =>
      'Esta tarea se verifica por NFC: escanee la etiqueta en el punto de la tarea antes de completar.';

  @override
  String get gorevAdim1Etiket => '1. Escanee la etiqueta';

  @override
  String gorevOkundu(Object uid) {
    return 'Leído: $uid';
  }

  @override
  String get gorevEtiketBekleniyor => 'Esperando la etiqueta...';

  @override
  String get gorevYenidenOkut => 'Escanear de nuevo';

  @override
  String get gorevEtiketiOkut => 'Escanear etiqueta';

  @override
  String get gorevAdim2Foto => '2. Prueba fotográfica';

  @override
  String get gorevAdim2FotoOpsiyonel => '2. Prueba fotográfica (opcional)';

  @override
  String get gorevYukleniyorNokta => 'Subiendo...';

  @override
  String get gorevYuklendi => 'Subido ✓';

  @override
  String get gorevKamera => 'Cámara';

  @override
  String get gorevYenidenCek => 'Volver a tomar';

  @override
  String get gorevGaleridenSec => 'Elegir de la galería';

  @override
  String get gorevTekrarYukle => 'Subir de nuevo';

  @override
  String get gorevKaldir => 'Quitar';

  @override
  String get gorevAdim3Not => '3. Nota (opcional)';

  @override
  String get gorevNotIpucu => 'Ej. contenedores de basura vaciados';

  @override
  String get gorevZatenKayitliydi =>
      'Esta finalización ya estaba registrada (reenvío — no se creó ningún duplicado).';

  @override
  String get gorevTamamlandiKayit => 'Tarea completada — registro creado.';

  @override
  String gorevZaman(Object zaman) {
    return 'Hora: $zaman';
  }

  @override
  String get gorevFotoKanitiVar => 'con prueba fotográfica';

  @override
  String get gorevNfcDogrulandi => 'NFC verificado';

  @override
  String get gorevYeniTamamlamaBaslat => 'Iniciar una nueva finalización';

  @override
  String get gorevDuzenleBaslik => 'Editar tarea';

  @override
  String get gorevKategoriSilinmis => 'Categoría (eliminada)';

  @override
  String get gorevAtananListedeDegil =>
      'Usuario asignado (no está en la lista)';

  @override
  String get gorevTipleriYukleniyor => 'Cargando tipos de tarea...';

  @override
  String get gorevTipi => 'Tipo de tarea';

  @override
  String get gorevTipiYokUyari =>
      'Aún no ha definido tipos de tarea. Puede añadir los suyos desde la pantalla \"Categorías\" de arriba; por ahora se usa \"Otros\".';

  @override
  String get gorevAdi => 'Nombre de la tarea';

  @override
  String get gorevAdiZorunlu => 'El nombre de la tarea es obligatorio';

  @override
  String get gorevAciklamaOpsiyonel => 'Descripción (opcional)';

  @override
  String get gorevPersonelYukleniyor => 'Cargando la lista de personal...';

  @override
  String get gorevAtananPersonel => 'Personal asignado';

  @override
  String get gorevAtanmamisHavuz => '— sin asignar (tarea común) —';

  @override
  String gorevPersonelAlinamadi(Object hata) {
    return 'No se pudo obtener la lista de personal: $hata';
  }

  @override
  String get gorevKontrolNoktasiOpsiyonel =>
      'Punto de control (NFC) — opcional';

  @override
  String get gorevKontrolNoktasiYardim =>
      'Si se vincula, la tarea se completa escaneando NFC';

  @override
  String get gorevNfcYok => '— sin NFC —';

  @override
  String get gorevPeriyotDakika => 'Periodo en minutos (opcional)';

  @override
  String get gorevPeriyotYardim =>
      'Para tareas periódicas; vacío = una sola vez';

  @override
  String get gorevPozitifSayi => 'Introduzca un número entero positivo';

  @override
  String get gorevFotoKanitiZorunlu => 'Prueba fotográfica obligatoria';

  @override
  String get gorevFotoKanitiZorunluAlt =>
      'La finalización no se acepta sin foto';

  @override
  String get gorevPasifAciklama => 'Una tarea inactiva no aparece en la lista';

  @override
  String get gorevKategorileriBaslik => 'Categorías de tareas';

  @override
  String get gorevKategoriYeni => 'Nueva categoría';

  @override
  String get gorevKategoriAdi => 'Nombre de la categoría';

  @override
  String get gorevKategoriAdiIpucu => 'ej. Mantenimiento de la piscina';

  @override
  String gorevKategoriEklendi(Object ad) {
    return '\"$ad\" añadida';
  }

  @override
  String gorevKategoriEklenemedi(Object hata) {
    return 'No se pudo añadir: $hata';
  }

  @override
  String get gorevKategoriSilinsinMi => '¿Eliminar la categoría?';

  @override
  String gorevKategoriSilOnay(Object ad) {
    return '\"$ad\" se desactivará; se conserva el historial de las tareas existentes, pero no podrá seleccionarse en tareas nuevas.';
  }

  @override
  String gorevKategoriSilindi(Object ad) {
    return '\"$ad\" eliminada';
  }

  @override
  String gorevKategoriSilinemedi(Object hata) {
    return 'No se pudo eliminar: $hata';
  }

  @override
  String gorevKategoriListeAlinamadi(Object hata) {
    return 'No se pudo obtener la lista: $hata';
  }

  @override
  String get gorevKategoriYokBos =>
      'Aún no hay categorías. Añada una con \"Nueva categoría\" para poder elegirla al crear una tarea.';

  @override
  String get gorevOncelikDusuk => 'Baja';

  @override
  String get gorevOncelikOrta => 'Media';

  @override
  String get gorevOncelikYuksek => 'Alta';

  @override
  String get gorevOncelik => 'Prioridad';

  @override
  String get gorevTaleptenGeldi => 'Desde una solicitud';

  @override
  String get gorevBagliTalep => 'Solicitud vinculada';

  @override
  String gorevDaireEtiket(Object daire) {
    return 'Unidad $daire';
  }

  @override
  String get talepDurumAcik => 'Abierto';

  @override
  String get talepDurumIsEmri => 'Orden de trabajo';

  @override
  String get talepDurumCozuldu => 'Resuelto';

  @override
  String get talepDurumReddedildi => 'Rechazado';

  @override
  String get gorevEtiketOkunamadi => 'No se pudo leer la etiqueta.';

  @override
  String get gorevFotoOnlineGerekli =>
      'Se necesita conexión a Internet para subir la foto (la dirección de subida es de corta duración). Cuando vuelva la conexión, use \"Subir de nuevo\".';

  @override
  String gorevFotoAlinamadi(Object hata) {
    return 'No se pudo obtener la foto: $hata';
  }

  @override
  String get gorevFotoOnlineGerekliKisa =>
      'Se necesita conexión a Internet para subir la foto.';

  @override
  String get gorevFotoZorunluUyari =>
      'Para esta tarea la PRUEBA FOTOGRÁFICA ES OBLIGATORIA. Tome y suba una foto antes de completar.';

  @override
  String get gorevFotoHenuzYuklenmedi =>
      'La foto aún no se ha subido. Espere a que termine la subida, pruebe \"Subir de nuevo\" o quite la foto.';

  @override
  String get gorevTamamlamaOfflineUyari =>
      'No se pudo enviar la finalización — se necesita conexión a Internet. Cuando vuelva la conexión, pulse \"Completar\" de nuevo; el mismo registro no se duplicará (la Idempotency-Key es fija). La finalización con foto no se admite sin conexión (limitación conocida).';

  @override
  String get rolAdmin => 'Administrador de la plataforma';

  @override
  String get rolYonetici => 'Administrador del sitio';

  @override
  String get rolGuvenlik => 'Seguridad';

  @override
  String get rolTesisGorevlisi => 'Operario de instalaciones';

  @override
  String get rolSakin => 'Residente';

  @override
  String get rolBilinmeyen => 'Rol desconocido';

  @override
  String get ortakOlustur => 'Crear';

  @override
  String get ortakGuncelle => 'Actualizar';

  @override
  String get ortakYenile => 'Recargar';

  @override
  String get devriyeGonderimKuyruguTooltip => 'Cola de envío';

  @override
  String get sekmeGecmis => 'Historial';

  @override
  String get devriyeYetkiYok =>
      'No tiene permiso para los datos de esta pantalla. El seguimiento de rondas está abierto al rol de seguridad (y administrador).';

  @override
  String devriyeSonGuncelleme(Object saat) {
    return 'Última actualización: $saat (actualización automática: 60 s)';
  }

  @override
  String get devriyeTuru => 'Ronda de patrulla';

  @override
  String devriyeBitisEtiket(Object saat) {
    return 'fin $saat';
  }

  @override
  String devriyePencere(Object baslangic, Object bitis) {
    return 'Ventana: $baslangic – $bitis';
  }

  @override
  String devriyeNoktaSayaci(Object okutulan, Object beklenen) {
    return '$okutulan/$beklenen puntos';
  }

  @override
  String get devriyeTumNoktalarOkutuldu =>
      'Todos los puntos escaneados — la ronda se está completando. ✓';

  @override
  String devriyeSunucudaOkutma(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          'Hay $n escaneos registrados en el servidor (pueden incluirse escaneos de otros dispositivos).',
      one:
          'Hay $n escaneo registrado en el servidor (pueden incluirse escaneos de otros dispositivos).',
    );
    return '$_temp0';
  }

  @override
  String get devriyeNoktaOkutNfc => 'Escanear punto (NFC)';

  @override
  String get devriyeBugununDigerTurlari => 'Las otras rondas de hoy';

  @override
  String get devriyeBugununTurlari => 'Las rondas de hoy';

  @override
  String get devriyeDurumTamamlandi => 'Completada';

  @override
  String get devriyeDurumKacirildi => 'Perdida';

  @override
  String get devriyeDurumSimdiAktif => 'Activa ahora';

  @override
  String get devriyeDurumYaklasan => 'Próxima';

  @override
  String get devriyeDurumBitti => 'Finalizada';

  @override
  String get devriyeDurumBekliyor => 'Pendiente';

  @override
  String get devriyeDurumBilinmiyor => 'Desconocido';

  @override
  String get devriyeDurumSuresiGecti => 'Plazo vencido';

  @override
  String get devriyeBugunTurYok => 'No hay ronda de patrulla para hoy.';

  @override
  String get devriyeNoktaListesiYok =>
      'No se pudo obtener la lista de puntos de este plan o el plan no tiene puntos asignados.';

  @override
  String get devriyeKontrolNoktalari => 'Puntos de control';

  @override
  String get devriyeNoktaDurumAciklama =>
      'Los estados de los puntos vienen del servidor; los escaneos de todos los agentes aparecen con ✓. Las filas «Enviando» son escaneos de este dispositivo que aún no se han enviado.';

  @override
  String devriyeNoktaAdiYedek(Object kisaId) {
    return 'Punto $kisaId';
  }

  @override
  String get devriyeOkutuldu => 'Escaneado ✓';

  @override
  String devriyeOkutulduZamanli(Object saat) {
    return 'Escaneado ✓ · $saat';
  }

  @override
  String get devriyeOkutulduGonderiliyor => 'Escaneado ✓ — enviando (en cola)';

  @override
  String get devriyePencereSuresiDoldu => 'La ventana ha expirado.';

  @override
  String devriyeKalanSure(Object sure) {
    return 'Tiempo restante: $sure';
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
      'No tiene permiso para el historial de rondas. Esta lista está abierta a los roles de seguridad y administrador.';

  @override
  String get devriyeGecmisBos => 'Aún no hay registros de ventanas de ronda.';

  @override
  String get devriyeOzetToplam => 'Total';

  @override
  String get devriyePlanlariBaslik => 'Planes de patrulla';

  @override
  String get devriyePlanEkle => 'Añadir plan';

  @override
  String get devriyePlanlarListelenemedi => 'No se pudieron listar los planes.';

  @override
  String devriyePlanAralik(Object baslangic, Object bitis, Object dakika) {
    return '$baslangic–$bitis · cada $dakika min';
  }

  @override
  String get devriyePasif => 'Inactivo';

  @override
  String get devriyePlanSilinsinMi => '¿Eliminar el plan?';

  @override
  String devriyePlanSilOnay(Object ad) {
    return 'Se eliminará el plan de patrulla \"$ad\".';
  }

  @override
  String get devriyePlanSilindi => 'Plan eliminado ✓';

  @override
  String get devriyePlanDuzenleBaslik => 'Editar plan de patrulla';

  @override
  String get devriyePlanYeniBaslik => 'Nuevo plan de patrulla';

  @override
  String get devriyePlanAdi => 'Nombre del plan';

  @override
  String get devriyePlanAdiIpucu => 'ej. Patrulla nocturna';

  @override
  String get devriyeAdZorunlu => 'El nombre es obligatorio';

  @override
  String devriyeBaslangicSaat(Object saat) {
    return 'Inicio $saat';
  }

  @override
  String devriyeBitisSaat(Object saat) {
    return 'Fin $saat';
  }

  @override
  String get devriyeTurSikligi => 'Frecuencia de ronda (minutos)';

  @override
  String get devriyeTurSikligiYardim => 'ej. 60 = una ronda por hora';

  @override
  String get devriyeTurSikligiPozitif =>
      'La frecuencia de ronda (min) debe ser positiva.';

  @override
  String get devriyeTumunuKaldir => 'Quitar todo';

  @override
  String get devriyeTumunuSec => 'Seleccionar todo';

  @override
  String get devriyeAktifNoktaYok =>
      'No hay puntos de control activos. Añada uno primero desde «Puntos de control».';

  @override
  String devriyeUidEtiket(Object uid) {
    return 'UID: $uid';
  }

  @override
  String get devriyeKaydedilemedi => 'No se pudo guardar. Inténtelo de nuevo.';

  @override
  String get devriyePlanYokBos =>
      'Aún no hay planes de patrulla.\nAñada uno abajo a la derecha (horas + puntos).';

  @override
  String get devriyeTakibiBaslik => 'Seguimiento de patrullas';

  @override
  String get sekmeBugun => 'Hoy';

  @override
  String get sekmeTaramaGunlugu => 'Registro de escaneos';

  @override
  String get devriyeTakibiYetkiYok =>
      'No tiene permiso para el seguimiento de patrullas. Esta pantalla está abierta a los roles de administrador y seguridad.';

  @override
  String get devriyeBugunPencereYok =>
      'No hay ventana de patrulla programada para hoy.';

  @override
  String devriyeNoktaOkutuldu(Object okutulan, Object beklenen) {
    return '$okutulan/$beklenen puntos escaneados';
  }

  @override
  String get devriyeTaramaGunluguAlinamadi =>
      'No se pudo obtener el registro de escaneos.';

  @override
  String get devriyeGunOkutmaYok => 'No hay escaneos para este día.';

  @override
  String get devriyeImzali => 'firmado ✓';

  @override
  String devriyeOkutmaBekliyor(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n escaneos pendientes de envío',
      one: '$n escaneo pendiente de envío',
    );
    return '$_temp0';
  }

  @override
  String get ortakIptal => 'Cancelar';

  @override
  String get ortakNotOpsiyonel => 'Nota (opcional)';

  @override
  String get binaDuzenlemeBaslik => 'Estructura del edificio';

  @override
  String get binaBlokTile => 'Bloque';

  @override
  String get binaBlokAtanmamis => 'Sin bloque asignado';

  @override
  String binaBlokEtiket(Object ad) {
    return 'Bloque $ad';
  }

  @override
  String get binaSaltGoruntulemeAciklama =>
      'Estructura del edificio (solo lectura). Toque el mosaico de un bloque para ver la distribución de plantas y unidades.';

  @override
  String get binaDuzenlemeAciklama =>
      'Añada un bloque, toque el mosaico y coloque plantas y unidades dentro. Cada unidad pertenece a un bloque. El mapa de quejas refleja esta estructura.';

  @override
  String binaDaireSayisi(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n unidades',
      one: '$n unidad',
    );
    return '$_temp0';
  }

  @override
  String get binaKayitsiz => 'sin registrar';

  @override
  String get binaBloksuzDairelerSalt =>
      'Unidades sin bloque asignado (solo lectura).';

  @override
  String binaBlokYerlesimSalt(Object ad) {
    return 'Bloque $ad — distribución de plantas y unidades (solo lectura).';
  }

  @override
  String get binaBloksuzUyari =>
      'Estas unidades no están asignadas a ningún bloque (registros antiguos). Se muestran y pueden editarse o eliminarse; para una unidad nueva elija o cree un bloque.';

  @override
  String binaBlokYerlesimYardim(Object ad) {
    return 'Bloque $ad — añada plantas y luego unidades con el botón \"+\" de cada planta. Las unidades de la misma planta se alinean.';
  }

  @override
  String get binaKatEkle => 'Añadir planta';

  @override
  String get binaTopluDaireEkle => 'Añadir unidades en lote';

  @override
  String get binaBloktaDaireYok => 'Aún no hay unidades en este bloque.';

  @override
  String get binaKatYokBos =>
      'Aún no hay plantas. Empiece con «Añadir planta» y luego añada unidades con el «+» de la planta.';

  @override
  String get binaKatYok => 'Sin planta';

  @override
  String binaKatEtiket(Object kat) {
    return 'Planta $kat';
  }

  @override
  String binaBlokDuzenleBaslik(Object ad) {
    return 'Bloque $ad — editar';
  }

  @override
  String get binaBloguSil => 'Eliminar bloque';

  @override
  String binaBloguSilAlt(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Se elimina junto con $n unidades (requiere confirmación)',
      one: 'Se elimina junto con $n unidad (requiere confirmación)',
    );
    return '$_temp0';
  }

  @override
  String binaBlokSilinsinMi(Object ad) {
    return '¿Eliminar el bloque $ad?';
  }

  @override
  String binaBlokVeDaireSilindi(Object ad, Object n) {
    return 'Bloque $ad y $n unidades eliminados.';
  }

  @override
  String binaBlokSilindi(Object ad) {
    return 'Bloque $ad eliminado.';
  }

  @override
  String binaBlokSilinemedi(Object hata) {
    return 'No se pudo eliminar el bloque: $hata';
  }

  @override
  String get binaBlokSilinemediGenel =>
      'No se pudo eliminar el bloque. Inténtelo de nuevo.';

  @override
  String binaKaliciSilmeUyari(Object n) {
    return 'Este bloque y sus $n unidades se eliminarán DE FORMA PERMANENTE junto con sus registros de cuotas, visitantes, paquetes, reservas y quejas. Esta acción no se puede deshacer.';
  }

  @override
  String get binaOnayIcinBlokAdi =>
      'Escriba el nombre del bloque para confirmar';

  @override
  String binaSilNDaire(Object n) {
    return 'Eliminar ($n unidades)';
  }

  @override
  String get binaBlokEtiketiGerekli =>
      'Se requiere una etiqueta de bloque (ej. A, B1).';

  @override
  String get binaBlokEtiketiZatenVar =>
      'Esta etiqueta de bloque ya está registrada.';

  @override
  String get binaBlokDuzenle => 'Editar bloque';

  @override
  String get binaYeniBlok => 'Nuevo bloque';

  @override
  String get binaBlokEtiketi => 'Etiqueta del bloque';

  @override
  String get binaBlokEtiketiYardim =>
      'Alfanumérico corto (ej. A, B1) — sin guiones';

  @override
  String get binaDaireNoGerekli =>
      'Se requiere el número de unidad (ej. A-12, 12).';

  @override
  String get binaKatSiraTamSayi =>
      'La planta y la posición deben ser números enteros.';

  @override
  String get binaDaireNoZatenVar => 'Este número de unidad ya está registrado.';

  @override
  String binaDaireDuzenleBaslik(Object no) {
    return 'Unidad $no — editar';
  }

  @override
  String binaYeniDaire(Object blok) {
    return 'Nueva unidad · $blok';
  }

  @override
  String get binaDaireNo => 'Número de unidad';

  @override
  String get binaDaireNoYardim => 'Alfanumérico + guion (ej. A-12, B3, 12)';

  @override
  String get binaSira => 'Posición';

  @override
  String get binaSiraYardim => 'Posición en la planta';

  @override
  String binaEnFazla500(Object n) {
    return 'Máximo 500 unidades (ahora $n).';
  }

  @override
  String binaTopluOnizleme(
    Object bas,
    Object bitis,
    Object toplam,
    Object kat,
    Object adet,
  ) {
    return '$bas … $bitis  ($toplam unidades, $kat plantas × $adet)';
  }

  @override
  String get binaTopluAlanlarGerekli =>
      'Se requieren número de plantas, unidades por planta y número inicial.';

  @override
  String get binaTekSeferde500 => 'Máximo 500 unidades por vez.';

  @override
  String binaAtlananEk(Object n) {
    return ' ($n ya existían, omitidas)';
  }

  @override
  String binaDaireEklendi(Object n, Object ek) {
    return '$n unidades añadidas ✓$ek';
  }

  @override
  String get binaEklenemedi => 'No se pudo añadir. Inténtelo de nuevo.';

  @override
  String binaTopluBaslik(Object blok) {
    return 'Añadir en lote — Bloque $blok';
  }

  @override
  String get binaTopluBaslikBloksuz => 'Añadir en lote — sin bloque';

  @override
  String get binaTopluAciklama =>
      'Los números son consecutivos desde el inicio, planta por planta. Los existentes se omiten.';

  @override
  String get binaKatSayisi => 'Número de plantas';

  @override
  String get binaKatBasinaDaire => 'Unidades por planta';

  @override
  String get binaBaslangicNo => 'Número inicial';

  @override
  String get binaBaslangicNoIpucu => 'ej. 101';

  @override
  String get binaDaireleriOlustur => 'Crear unidades';

  @override
  String get binaSilinemedi => 'No se pudo eliminar. Inténtelo de nuevo.';

  @override
  String get binaKaydedilemedi => 'No se pudo guardar. Inténtelo de nuevo.';

  @override
  String get semaDaireYok => 'Aún no hay unidades.';

  @override
  String get semaYogunluk => 'Densidad:';

  @override
  String get semaYerlesimAciklama =>
      'Distribución del edificio. La densidad de quejas solo se muestra a la administración.';

  @override
  String get semaYerlesimGirilmemis => 'Distribución no indicada en el mapa';

  @override
  String semaDaireEtiket(Object no) {
    return 'Unidad $no';
  }

  @override
  String semaAcikSikayet(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n quejas abiertas',
      one: '$n queja abierta',
    );
    return '$_temp0';
  }

  @override
  String get semaBuDaireSikayetlerim => 'Sus quejas sobre esta unidad';

  @override
  String get semaYogunlukYonetim =>
      'La densidad de quejas solo se muestra a la administración.';

  @override
  String get semaBuDaireyiSikayetEt => 'Denunciar esta unidad';

  @override
  String get semaSikayetIletildi => 'Su queja ha sido enviada.';

  @override
  String get semaSikayetlerYuklenemedi => 'No se pudieron cargar las quejas.';

  @override
  String get semaAcikSikayetYok => 'No hay quejas abiertas para esta unidad.';

  @override
  String get semaSikayetlerimYuklenemedi => 'No se pudieron cargar sus quejas.';

  @override
  String get semaSikayetimYok => 'No tiene quejas sobre esta unidad.';

  @override
  String get semaYonetimeIletildi => 'Enviado a la administración';

  @override
  String get semaKapatildi => 'Cerrado';

  @override
  String get semaHaftalikSinir =>
      'Puede abrir como máximo 1 queja por semana sobre este tema para esta unidad.';

  @override
  String get semaKendiBlok =>
      'Solo puede denunciar unidades de su propio bloque.';

  @override
  String get semaGonderilemedi => 'No se pudo enviar. Inténtelo de nuevo.';

  @override
  String semaSikayetEtBaslik(Object no) {
    return 'Unidad $no — denunciar';
  }

  @override
  String get semaSikayetAnonimNot =>
      'Su queja se envía a la administración; no se muestra a sus vecinos.';

  @override
  String get semaSikayetiGonder => 'Enviar queja';

  @override
  String get kategoriGurultu => 'Ruido';

  @override
  String get kategoriKapiOnuAyakkabi => 'Entrada / zapatos';

  @override
  String get kategoriZararVerme => 'Daños';

  @override
  String talepSekmeAcik(Object n) {
    return 'Abiertos ($n)';
  }

  @override
  String talepSekmeIsEmri(Object n) {
    return 'Orden de trabajo ($n)';
  }

  @override
  String talepSekmeCozulen(Object n) {
    return 'Resueltos ($n)';
  }

  @override
  String talepSekmeReddedilen(Object n) {
    return 'Rechazados ($n)';
  }

  @override
  String get talepYeni => 'Nueva solicitud';

  @override
  String get talepAcikYokSakin =>
      'No tiene solicitudes abiertas. Use «Nueva solicitud» para comunicar una solicitud o avería.';

  @override
  String get talepAcikYok => 'No hay solicitudes abiertas.';

  @override
  String get talepIsEmriYok =>
      'No hay solicitudes convertidas en orden de trabajo.';

  @override
  String get talepCozulenYok => 'Aún no hay solicitudes resueltas.';

  @override
  String get talepReddedilenYok => 'No hay solicitudes rechazadas.';

  @override
  String get talepIletildi => 'Su solicitud ha sido enviada ✓';

  @override
  String get talepDurumGecmisi => 'Historial de estados';

  @override
  String get talepGorselYuklenemedi => 'No se pudo cargar la imagen';

  @override
  String get talepIsEmriAtandi => 'Asignado';

  @override
  String get talepIsEmriTamamlandi => 'Completado';

  @override
  String get talepIsEmriDurumBilinmiyor => 'Estado desconocido';

  @override
  String get talepIsEmri => 'Orden de trabajo';

  @override
  String get talepYeniBaslik => 'Nueva solicitud / avería';

  @override
  String get talepBaslikAlan => 'Título';

  @override
  String get talepBaslikZorunlu => 'El título es obligatorio';

  @override
  String get talepAciklamaAlan => 'Descripción';

  @override
  String get talepAciklamaZorunlu => 'La descripción es obligatoria';

  @override
  String get talepGonder => 'Enviar';

  @override
  String get talepKategoriOpsiyonel => 'Categoría (opcional)';

  @override
  String get talepKategoriYok =>
      'No hay categorías definidas; la solicitud se abrirá como «Otros».';

  @override
  String get talepGorseller => 'Imágenes (opcional, máx. 3)';

  @override
  String get talepYoneticiIslemleri => 'Acciones del administrador';

  @override
  String get talepIsEmrineDonusturuldu =>
      'Solicitud convertida en orden de trabajo ✓';

  @override
  String get talepIsEmrineDonusturBuyuk => 'Convertir en orden de trabajo';

  @override
  String get talepCozuldu => 'Solicitud resuelta ✓';

  @override
  String get talepCoz => 'Resolver';

  @override
  String get talepReddedildiBildirim => 'Solicitud rechazada ✓';

  @override
  String get talepReddet => 'Rechazar';

  @override
  String get talepReddediliyor => 'Rechazando...';

  @override
  String get talepPersonelAlinamadiKisa =>
      'No se pudo obtener la lista de personal.';

  @override
  String get talepIsEmrineDonustur => 'Convertir en orden de trabajo';

  @override
  String get talepAtanabilirPersonelYok =>
      'No hay personal de campo activo para asignar. Para convertir, añada primero seguridad u operario de instalaciones.';

  @override
  String get talepDonusturuluyor => 'Convirtiendo...';

  @override
  String get talepDonustur => 'Convertir';

  @override
  String get talepReddetBaslik => 'Rechazar la solicitud';

  @override
  String get talepRetSebebiNot =>
      'El motivo del rechazo es visible para el solicitante en el historial de estados.';

  @override
  String get talepRetSebebi => 'Motivo del rechazo';

  @override
  String get talepCozBaslik => 'Resolver la solicitud';

  @override
  String get talepCozNot =>
      'La solicitud se marca como resuelta directamente, sin orden de trabajo.';

  @override
  String get talepCozumNotu => 'Nota de resolución (opcional)';

  @override
  String get talepKategorilerYuklenemedi =>
      'No se pudieron cargar las categorías.';

  @override
  String get talepFotoYuklenemedi => 'No se pudo subir la foto.';

  @override
  String get binaKat => 'Planta';

  @override
  String get binaKatYardim => '0 = planta baja';

  @override
  String get binaBloksuz => 'Sin bloque';

  @override
  String get talepAcanSakin => 'Residente';

  @override
  String rezSekmeRezervasyonlar(Object n) {
    return 'Reservas ($n)';
  }

  @override
  String rezSekmeAlanlar(Object n) {
    return 'Espacios ($n)';
  }

  @override
  String get rezYokSakin =>
      'No tiene reservas. Elija un espacio en la pestaña «Espacios» y reserve una franja libre.';

  @override
  String get rezYok => 'No hay reservas.';

  @override
  String get rezYeniAlan => 'Nuevo espacio';

  @override
  String get rezAlanEklendi => 'Espacio común añadido ✓';

  @override
  String get rezAlanGuncellendi => 'Espacio actualizado ✓';

  @override
  String get rezOrtakAlan => 'Espacio común';

  @override
  String rezSatirOzet(
    Object tarih,
    Object baslangic,
    Object bitis,
    Object kisi,
  ) {
    return '$tarih · $baslangic-$bitis · $kisi personas';
  }

  @override
  String get rezIptalEdildi => 'Cancelada';

  @override
  String get rezIptalEdilsinMi => '¿Cancelar la reserva?';

  @override
  String get rezIptalUyari =>
      'La franja vuelve a quedar libre; esta acción no se puede deshacer.';

  @override
  String get rezEvetIptalEt => 'Sí, cancelar';

  @override
  String get rezIptalEdildiBildirim => 'Reserva cancelada';

  @override
  String get rezIptalGonderilemedi =>
      'No se pudo enviar la cancelación. Inténtelo de nuevo.';

  @override
  String get rezIptalEt => 'Cancelar';

  @override
  String rezDetayTarih(Object tarih, Object baslangic, Object bitis) {
    return 'Fecha: $tarih · $baslangic-$bitis';
  }

  @override
  String rezDetayKisi(Object n) {
    return 'Número de personas: $n';
  }

  @override
  String rezDetayRezerve(Object zaman) {
    return 'Reservado: $zaman';
  }

  @override
  String rezDetayNot(Object not) {
    return 'Nota: $not';
  }

  @override
  String get rezAlanYokYonetim =>
      'Aún no hay espacios comunes. Añada uno con «Nuevo espacio».';

  @override
  String get rezAlanYokGoruntuleme => 'No hay espacios comunes que mostrar.';

  @override
  String get rezAlanYokSakin => 'No hay espacios reservables.';

  @override
  String rezMusait(Object ozet) {
    return 'Disponible: $ozet';
  }

  @override
  String rezMusaitOzeti(Object acilis, Object kapanis, Object dakika) {
    return '$acilis–$kapanis · franjas de $dakika min';
  }

  @override
  String get rezAcikDuzenle => 'Abierto · toque para editar';

  @override
  String get rezKapaliDuzenle => 'Cerrado · toque para editar';

  @override
  String rezMusaitSlotlariGor(Object ozet) {
    return 'Disponible: $ozet · toque para ver las franjas';
  }

  @override
  String get rezPasifAlan => 'Inactivo (no reservable)';

  @override
  String get rezKapanisSonra =>
      'La hora de cierre debe ser posterior a la de apertura.';

  @override
  String get rezAlanEklenemedi =>
      'No se pudo añadir el espacio. Inténtelo de nuevo.';

  @override
  String get rezAlanDuzenle => 'Editar espacio';

  @override
  String get rezYeniOrtakAlan => 'Nuevo espacio común';

  @override
  String get rezAlanAdi => 'Nombre del espacio * (ej. Piscina)';

  @override
  String get rezAlanAdiGerekli => 'El nombre del espacio es obligatorio';

  @override
  String get rezMusaitlikHerGun => 'Disponibilidad (cada día)';

  @override
  String rezAcilis(Object saat) {
    return 'Apertura: $saat';
  }

  @override
  String rezKapanis(Object saat) {
    return 'Cierre: $saat';
  }

  @override
  String get rezSlotUzunlugu => 'Duración de la franja';

  @override
  String rezSlotDakika(Object n) {
    return '$n minutos';
  }

  @override
  String get rezAlaniEkle => 'Añadir espacio';

  @override
  String get rezSlotlarYuklenemedi =>
      'No se pudieron cargar las franjas. Inténtelo de nuevo.';

  @override
  String get rezOnaylandi => 'Su reserva está confirmada ✓';

  @override
  String rezTarihEtiket(Object tarih) {
    return 'Fecha: $tarih';
  }

  @override
  String get rezSlotKurali =>
      'Una franja se abre solo cuando faltan menos de 24 horas para su inicio; puede hacer como máximo una reserva al día.';

  @override
  String get rezSlotYok => 'No hay franjas definidas para este espacio.';

  @override
  String get rezBenimAktif => 'Mi reserva (activa)';

  @override
  String get rezBenimGecti => 'Mi reserva (pasada)';

  @override
  String get rezDoluBaskasi => 'Ocupado (otra persona)';

  @override
  String get rezSizinGecti => 'Su reserva (pasada)';

  @override
  String rezKisiEki(Object n) {
    return ' · $n personas';
  }

  @override
  String rezDoluDaire(Object daire, Object kisi) {
    return 'Ocupado · Unidad $daire$kisi';
  }

  @override
  String get rezBos => 'Libre';

  @override
  String get rezDolu => 'Ocupado';

  @override
  String rezSlotAralik(Object baslangic, Object bitis) {
    return '$baslangic – $bitis';
  }

  @override
  String get rezSec => 'Seleccionar';

  @override
  String get rezGonderilemedi => 'No se pudo enviar. Inténtelo de nuevo.';

  @override
  String rezEtBaslik(Object ad) {
    return '$ad — reservar';
  }

  @override
  String get rezKisiSayisiEtiket => 'Número de personas:';

  @override
  String get rezEt => 'Reservar';

  @override
  String get rezDurumOnayli => 'Confirmada';

  @override
  String get rezSebepDolu => 'ocupado';

  @override
  String get rezSebepGecti => 'pasado';

  @override
  String get rezSebepCokErken => 'abre en 24 h';

  @override
  String get rezSebepGunluk => 'límite diario alcanzado';

  @override
  String etkSekmeYaklasan(Object n) {
    return 'Próximos ($n)';
  }

  @override
  String etkSekmeGecmis(Object n) {
    return 'Pasados ($n)';
  }

  @override
  String get etkYeni => 'Nuevo evento';

  @override
  String get etkYaklasanYokYonetim =>
      'No hay eventos próximos. Anuncie uno con «Nuevo evento».';

  @override
  String get etkYaklasanYok => 'No hay eventos próximos.';

  @override
  String get etkGecmisYok => 'No hay eventos pasados.';

  @override
  String get etkDuyuruldu => 'Evento anunciado — residentes notificados ✓';

  @override
  String get etkGuncellendi => 'Evento actualizado ✓';

  @override
  String etkKatiliyorSayisi(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n asisten',
      one: '$n asiste',
    );
    return '$_temp0';
  }

  @override
  String etkKatilmiyorSayisi(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n no asisten',
      one: '$n no asiste',
    );
    return '$_temp0';
  }

  @override
  String etkKatiliminiz(Object durum) {
    return 'Su respuesta: $durum';
  }

  @override
  String etkBeyanKaydedildi(Object durum) {
    return 'Su respuesta se ha guardado: $durum ✓';
  }

  @override
  String get etkBeyanGonderilemedi =>
      'No se pudo enviar la respuesta. Inténtelo de nuevo.';

  @override
  String get etkKatiliyorum => 'Asisto';

  @override
  String get etkKatilmiyorum => 'No asisto';

  @override
  String etkZaman(Object aralik) {
    return 'Hora: $aralik';
  }

  @override
  String etkYer(Object konum) {
    return 'Lugar: $konum';
  }

  @override
  String etkDuyuran(Object ad) {
    return 'Anunciado por: $ad';
  }

  @override
  String get etkSilinsinMi => '¿Eliminar el evento?';

  @override
  String etkSilOnay(Object baslik) {
    return 'Se eliminarán \"$baslik\" y todas las respuestas.';
  }

  @override
  String get etkSilindi => 'Evento eliminado ✓';

  @override
  String get etkBitisSonra => 'El fin debe ser posterior al inicio';

  @override
  String get etkKaydedilemedi => 'No se pudo guardar. Inténtelo de nuevo.';

  @override
  String get etkDuzenleBaslik => 'Editar evento';

  @override
  String get etkBaslikAlan => 'Título * (ej. Noche de partido)';

  @override
  String get etkBaslikGerekli => 'El título es obligatorio';

  @override
  String get etkAciklamaAlan => 'Descripción *';

  @override
  String get etkAciklamaGerekli => 'La descripción es obligatoria';

  @override
  String etkZamanSecim(Object zaman) {
    return 'Hora: $zaman';
  }

  @override
  String get etkBitisEkle => 'Añadir fin (opcional)';

  @override
  String etkBitis(Object zaman) {
    return 'Fin: $zaman';
  }

  @override
  String get etkBitisiKaldir => 'Quitar el fin';

  @override
  String get etkYerAlan => 'Lugar (opcional)';

  @override
  String get etkGorselAlan => 'Imagen (opcional)';

  @override
  String get etkDuyurVeBildir => 'Anunciar y notificar a los residentes';

  @override
  String get izinBaslik => 'Permiso de visualización';

  @override
  String get izinTumDairelere => 'Solicitar permiso para todas las unidades';

  @override
  String get izinYeniIstek => 'Nueva solicitud';

  @override
  String get izinIstekYokYonetim =>
      'Aún no tiene solicitudes de permiso. Use «Nueva solicitud» para una unidad, o «Todas las unidades» arriba para todas.';

  @override
  String get izinIstekYokSakin =>
      'No hay solicitudes de visualización para su unidad.';

  @override
  String get izinTumDaireUyari =>
      'Se enviará una solicitud de visualización por cada unidad con residente. Cada unidad depende de la aprobación de su residente: solo verá los registros de las que aprueben.';

  @override
  String izinAtlandiEki(Object n) {
    return ' ($n ya abiertos)';
  }

  @override
  String izinTopluGonderildi(Object n, Object atlandi) {
    return 'Solicitudes enviadas para $n unidades$atlandi — esperando aprobaciones de los residentes';
  }

  @override
  String izinGonderilemedi(Object hata) {
    return 'No se pudo enviar: $hata';
  }

  @override
  String get izinIsteBaslik => 'Solicitar permiso de visualización';

  @override
  String get izinDaireNo => 'Número de unidad (ej. A-12)';

  @override
  String get izinIstekGonder => 'Enviar solicitud';

  @override
  String get izinIstekGonderildi =>
      'Solicitud enviada — esperando la aprobación del residente';

  @override
  String izinDaireIstegi(Object daire) {
    return 'Solicitud de visualización de unidad$daire';
  }

  @override
  String izinIsteyen(Object ad) {
    return 'Solicitado por: $ad';
  }

  @override
  String get izinKullanildiUyari =>
      'El permiso se ha usado (de un solo uso). Abra una nueva solicitud para volver a ver.';

  @override
  String izinGoruntulenebilirDaireler(Object n) {
    return 'Unidades visibles ($n)';
  }

  @override
  String get izinKullanildi => 'Usado';

  @override
  String get izinOnayli => 'Aprobado';

  @override
  String get izinVerildi => 'Permiso concedido';

  @override
  String get izinOnayla => 'Aprobar';

  @override
  String get izinKargolar => 'Paquetes';

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
      'El permiso se usó o ha caducado (de un solo uso). Abra una nueva solicitud para volver a ver.';

  @override
  String get izinTekSeferlikUyari =>
      'Visualización con permiso de un solo uso: el acceso se cierra al actualizar.';

  @override
  String get izinKayitYok => 'No hay registros para esta unidad.';

  @override
  String izinHedef(Object ad) {
    return 'Destinatario: $ad';
  }

  @override
  String izinKaydeden(Object ad) {
    return 'Registrado por: $ad';
  }

  @override
  String izinDurumEtiket(Object durum) {
    return 'Estado: $durum';
  }

  @override
  String get izinDurumOnaylandi => 'Aprobada';

  @override
  String get kargoDurumTeslimAlindi => 'Entregado';

  @override
  String get rezSizin => 'Su reserva';

  @override
  String get butBaslik => 'Presupuesto';

  @override
  String get butSekmeOzet => 'Resumen';

  @override
  String get butSekmeHareketler => 'Movimientos';

  @override
  String get butSekmeKategoriler => 'Categorías';

  @override
  String get butTumZamanlar => 'Todo el tiempo';

  @override
  String get butDonem => 'Periodo';

  @override
  String get butGelir => 'Ingresos';

  @override
  String get butGider => 'Gastos';

  @override
  String get butKasa => 'Caja';

  @override
  String get butKategoriKirilimi => 'Desglose por categoría';

  @override
  String get butYeniHareket => 'Nuevo movimiento';

  @override
  String get butHareketYok => 'Aún no hay movimientos.';

  @override
  String get butKategori => 'Categoría';

  @override
  String get butOtomatik => 'Automático';

  @override
  String get butKategoriSecin => 'Seleccione una categoría';

  @override
  String get butTutar => 'Importe (TL)';

  @override
  String get butTutarIpucu => 'ej. 1.250,50';

  @override
  String get butTutarGecersiz => 'Introduzca un importe válido (ej. 1.250,50)';

  @override
  String butTarih(Object tarih) {
    return 'Fecha: $tarih';
  }

  @override
  String get butYeniKategori => 'Nueva categoría';

  @override
  String get butKategoriYok => 'Aún no hay categorías.';

  @override
  String get butKategoriAdi => 'Nombre de la categoría';

  @override
  String get butKategoriAdiIpucu => 'ej. Mantenimiento del jardín';

  @override
  String get butAdZorunlu => 'El nombre es obligatorio';

  @override
  String butKategoriTip(Object ad, Object tip) {
    return '$ad ($tip)';
  }

  @override
  String get butPasifEki => ' · inactiva (sin nuevos movimientos)';

  @override
  String get butBeklenmeyenKisa =>
      'Se ha producido un error inesperado. Inténtelo de nuevo.';

  @override
  String get butFinansalOzet => 'Resumen financiero';

  @override
  String get butAidatTahsilati => 'Cobro de cuotas';

  @override
  String get butEnYuksekGiderler => 'Mayores gastos';

  @override
  String butTahsilatYuzde(Object yuzde) {
    return 'Cobro $yuzde %';
  }

  @override
  String get butTahakkukYok => 'No hay devengos registrados para este periodo.';

  @override
  String get butSiteBaslik => 'Presupuesto del sitio';

  @override
  String get butKategoriToplamlari => 'Totales por categoría';

  @override
  String get butSeffaflikNotu =>
      'Esta pantalla muestra los ingresos y gastos de la administración del sitio como resumen, por transparencia. No se muestran detalles por persona ni por unidad; consulte a su administración.';

  @override
  String get demBaslik => 'Activos';

  @override
  String get demEtiketOkut => 'Escanear etiqueta';

  @override
  String get demBaskaEtiketOkut => 'Escanear otra etiqueta';

  @override
  String demUzerimdekiler(Object ek) {
    return 'En mi poder$ek';
  }

  @override
  String get demNfcAciklama =>
      'Escanee la etiqueta NFC del activo al retirarlo o devolverlo. La app lo identifica y muestra quién lo tiene.';

  @override
  String get demTaniniyor => 'Identificando el activo...';

  @override
  String get demKimsedeDegil => 'Nadie lo tiene — disponible.';

  @override
  String demSende(Object sure) {
    return 'LO TIENES — $sure.';
  }

  @override
  String demBaskasinda(Object ad, Object sure) {
    return 'Lo tiene $ad — $sure.';
  }

  @override
  String get demBaskasininUzerinde => 'Parece estar en poder de otra persona.';

  @override
  String get demBakimda => 'En mantenimiento — no se puede asignar ahora.';

  @override
  String get demZorlaDevralmaYok =>
      'No hay toma forzada — el poseedor actual debe devolver el activo.';

  @override
  String get demZimmetineAl => 'Asignarme';

  @override
  String get demBirak => 'Devolver';

  @override
  String get demBirakKisa => 'Devolver';

  @override
  String get demSonHareketler => 'Movimientos recientes';

  @override
  String demAldi(Object ad, Object zaman) {
    return '$ad lo tomó — $zaman (aún lo tiene)';
  }

  @override
  String get demListeYetkiYok => 'No tiene permiso para la lista de activos.';

  @override
  String get demUzerindeYok => 'Actualmente no tiene activos.';

  @override
  String demAldin(Object zaman, Object sure) {
    return 'Tomado: $zaman ($sure)';
  }

  @override
  String get demSureBelirsiz => 'desde hace un rato';

  @override
  String get demSureAzOnce => 'hace un instante';

  @override
  String demSureDakika(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'desde hace $n minutos',
      one: 'desde hace $n minuto',
    );
    return '$_temp0';
  }

  @override
  String demSureSaat(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'desde hace $n horas',
      one: 'desde hace $n hora',
    );
    return '$_temp0';
  }

  @override
  String demSureGun(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'desde hace $n días',
      one: 'desde hace $n día',
    );
    return '$_temp0';
  }

  @override
  String get demOfflineUyari =>
      'Se necesita conexión a Internet. La custodia es un registro en tiempo real; no se procesa sin conexión (encolarlo sería engañoso).';

  @override
  String demEtiketEslesmiyor(Object uid) {
    return 'Esta etiqueta ($uid) no coincide con ningún activo registrado. Debe asignarse a un activo desde el panel.';
  }

  @override
  String get demZatenZimmetinde =>
      'Ya estaba asignado a usted ✓ (reenvío — sin duplicado)';

  @override
  String get demZimmetineAlindi => 'Asignado ✓';

  @override
  String get demBirakildi => 'Devuelto ✓ — la asignación se ha cerrado.';

  @override
  String demIslemYapilamadi(Object hata) {
    return 'No se pudo realizar: $hata Estado actualizado — vuelva a mirar la tarjeta.';
  }

  @override
  String demHataSatiri(Object ad, Object hata) {
    return '$ad: $hata';
  }

  @override
  String get karBaslik => 'Paquetes';

  @override
  String karSekmeBekleyen(Object n) {
    return 'Pendientes ($n)';
  }

  @override
  String karSekmeTeslim(Object n) {
    return 'Recogidos ($n)';
  }

  @override
  String get karYeni => 'Nuevo paquete';

  @override
  String get karBekleyenYokSakin => 'No tiene paquetes pendientes de recogida.';

  @override
  String get karBekleyenYok => 'No hay paquetes pendientes de recogida.';

  @override
  String get karTeslimYok => 'Aún no hay paquetes recogidos registrados.';

  @override
  String get karKaydedildi =>
      'Paquete registrado — se ha notificado a los residentes ✓';

  @override
  String karDaireTarih(Object daire, Object zaman) {
    return 'Unidad: $daire · $zaman';
  }

  @override
  String karDaire(Object daire) {
    return 'Unidad: $daire';
  }

  @override
  String karKayit(Object zaman) {
    return 'Registro: $zaman';
  }

  @override
  String karNot(Object not) {
    return 'Nota: $not';
  }

  @override
  String get karTeslimAlindiBildirim => 'Paquete marcado como recogido ✓';

  @override
  String get karIsaretlenemedi => 'No se pudo marcar. Inténtelo de nuevo.';

  @override
  String get karTeslimAldim => 'Lo he recogido';

  @override
  String get karGonderilemedi =>
      'No se pudo enviar el registro. Inténtelo de nuevo.';

  @override
  String get karDaireNo => 'Número de unidad * (ej. A-12)';

  @override
  String get karDaireNoGerekli => 'El número de unidad es obligatorio';

  @override
  String get karFirma => 'Empresa de transporte *';

  @override
  String get karFirmaGerekli => 'La empresa de transporte es obligatoria';

  @override
  String get karPaketFotografi => 'Foto del paquete (opcional)';

  @override
  String get karKaydetVeBildir => 'Guardar y notificar a los residentes';

  @override
  String get ortakTekrarDene => 'Reintentar';

  @override
  String get butTahakkuk => 'Devengado';

  @override
  String get butTahsilat => 'Cobrado';

  @override
  String get butGeciken => 'Vencido';

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
  String get kuralBaslik => 'Normas del sitio';

  @override
  String get kuralYeni => 'Nueva norma';

  @override
  String get kuralAramaIpucu => 'Buscar en títulos (ej. piscina)';

  @override
  String get kuralEklendi => 'Norma añadida ✓';

  @override
  String get kuralGuncellendi => 'Norma actualizada ✓';

  @override
  String get kuralAramaBos => 'Ninguna norma coincide con la búsqueda.';

  @override
  String get kuralYokYonetim =>
      'Aún no hay normas. Añada una con \"Nueva norma\".';

  @override
  String get kuralYokSakin => 'Aún no se han publicado normas.';

  @override
  String get kuralSilOnayBaslik => '¿Eliminar esta norma?';

  @override
  String kuralSilOnayGovde(Object baslik) {
    return '\"$baslik\" se eliminará de forma permanente.';
  }

  @override
  String get kuralSilindi => 'Norma eliminada ✓';

  @override
  String get kuralDuzenleBaslik => 'Editar norma';

  @override
  String get kuralBaslikAlan => 'Título * (ej. Horario de piscina)';

  @override
  String get kuralBaslikGerekli => 'El título es obligatorio';

  @override
  String get kuralMetni => 'Texto de la norma *';

  @override
  String get kuralMetniGerekli => 'El texto de la norma es obligatorio';

  @override
  String get kuralSira => 'Orden (menor primero)';

  @override
  String get kuralSiraGecersiz => 'El orden debe ser 0 o un entero positivo';

  @override
  String get kuralMevcutGorsel => 'Se conserva la imagen actual';

  @override
  String get kuralEkleButon => 'Añadir norma';

  @override
  String get ortakFotoOnlineTekrarDene =>
      'Se necesita conexión a Internet para subir una foto. Inténtelo de nuevo cuando vuelva a estar en línea.';

  @override
  String get ortakFotoBekleyinVeyaKaldir =>
      'La foto aún no se ha subido. Espere a que termine la subida o quite la foto.';

  @override
  String get duyuruYeni => 'Nuevo anuncio';

  @override
  String get duyuruYayinlandi => 'Anuncio publicado ✓';

  @override
  String get duyuruGuncellendi => 'Anuncio actualizado ✓';

  @override
  String get duyuruYok => 'Aún no hay anuncios.';

  @override
  String get duyuruYonetim => 'Administración';

  @override
  String duyuruMeta(Object ad, Object zaman, Object duzenlendi) {
    return '$ad · $zaman$duzenlendi';
  }

  @override
  String get duyuruDuzenlendiEki => ' · editado';

  @override
  String get duyuruSilOnay => '¿Eliminar este anuncio?';

  @override
  String get duyuruSilindi => 'Anuncio eliminado ✓';

  @override
  String get duyuruDuzenleBaslik => 'Editar anuncio';

  @override
  String get duyuruBaslikZorunlu => 'El título es obligatorio';

  @override
  String get duyuruMetniAlan => 'Texto del anuncio';

  @override
  String get duyuruMetniZorunlu => 'El texto del anuncio es obligatorio';

  @override
  String get duyuruYayinla => 'Publicar';

  @override
  String get ortakIslemler => 'Acciones';

  @override
  String get sakinBaslik => 'Residentes del sitio';

  @override
  String get sakinEkle => 'Añadir residente';

  @override
  String get sakinListelenemedi => 'No se pudo listar a los residentes.';

  @override
  String get sakinDaireYok => 'Sin unidad asignada';

  @override
  String get sakinIslemleri => 'Acciones del residente';

  @override
  String get sakinSilOnay => '¿Eliminar al residente?';

  @override
  String sakinSilGovde(Object ad) {
    return '\"$ad\" se eliminará. Sin historial, el registro se borra por completo; si lo tiene, pasa a inactivo. En cualquier caso el número de teléfono queda libre (puede registrarse de nuevo).';
  }

  @override
  String sakinSilindi(Object ad) {
    return '\"$ad\" eliminado (número liberado)';
  }

  @override
  String sakinPasiflestirildi(Object ad) {
    return '\"$ad\" desactivado — tiene historial (número liberado)';
  }

  @override
  String get sakinDuzenleBaslik => 'Editar residente';

  @override
  String get sakinYeniTelefon => 'Nuevo móvil';

  @override
  String get sakinBosBirakDegismez => 'Déjelo vacío para no cambiarlo';

  @override
  String get sakinGuncellendi => 'Actualizado ✓';

  @override
  String get ortakAdSoyad => 'Nombre y apellidos';

  @override
  String get telefonHataEksik =>
      'El número está incompleto: introduzca 10 dígitos (p. ej. 0543 199 29 04).';

  @override
  String get telefonHataOnEk =>
      'Un número móvil debe empezar por 5 (p. ej. 0543…). No se aceptan fijos.';

  @override
  String get ortakCepTelefonu => 'Móvil';

  @override
  String get ortakTelefonIpucu => 'ej. 0532 111 22 03';

  @override
  String get ortakTelefonZorunlu => 'El teléfono es obligatorio';

  @override
  String get sakinGirisAnahtari => 'Solo para contacto (opcional).';

  @override
  String get ortakDaireNoIpucu => 'ej. A-12';

  @override
  String get sakinDaireNoZorunlu => 'El número de unidad es obligatorio';

  @override
  String get sakinEklendi => 'Residente añadido ✓';

  @override
  String get sakinYok =>
      'Aún no hay residentes.\nAñada uno desde abajo a la derecha.';

  @override
  String get girisParolaVeyaKod => 'Contraseña o código temporal';

  @override
  String get girisIlkKodIpucu =>
      'En el primer acceso, introduzca el código temporal que le dio la administración.';

  @override
  String get girisKimlik => 'Correo electrónico o número de teléfono';

  @override
  String get girisKimlikOrnek => 'nombre@ejemplo.com o 5XX XXX XX XX';

  @override
  String get girisKimlikYardim =>
      'Inicie sesión con su correo electrónico o número de teléfono';

  @override
  String get girisKimlikGerekli =>
      'Escriba su correo electrónico o número de teléfono';

  @override
  String get girisTesisSec => '¿En qué instalación desea iniciar sesión?';

  @override
  String get girisBeniHatirla => 'Recordarme';

  @override
  String get girisYap => 'Iniciar sesión';

  @override
  String get girisOturumSonaErdi =>
      'Su sesión ha caducado. Vuelva a iniciar sesión.';

  @override
  String get parolaBelirleBaslik => 'Establezca su contraseña';

  @override
  String get parolaBelirleAciklama =>
      'Ha iniciado sesión por primera vez con un código temporal. Para continuar, cree su propia contraseña permanente; en adelante entrará con su número de unidad + esta contraseña.';

  @override
  String get parolaBelirleButon => 'Establecer contraseña';

  @override
  String get parolaGiriseDon => 'Volver al acceso';

  @override
  String get ortakParolaZorunlu => 'La contraseña es obligatoria';

  @override
  String get ortakYeniParola => 'Nueva contraseña';

  @override
  String get ortakYeniParolaTekrar => 'Nueva contraseña (de nuevo)';

  @override
  String get ortakYeniParolaZorunlu => 'La nueva contraseña es obligatoria';

  @override
  String get ortakParolalarEslesmiyor => 'Las contraseñas no coinciden';

  @override
  String get parolaKuraliKisa => 'Debe tener al menos 8 caracteres';

  @override
  String get parolaKuraliBuyukHarf => 'Debe contener al menos una mayúscula';

  @override
  String get parolaKuraliRakam => 'Debe contener al menos un dígito';

  @override
  String get parolaKuraliSembol =>
      'Debe contener al menos un símbolo (! ? @ # . -)';

  @override
  String get profilYuklenemedi => 'No se pudo cargar el perfil.';

  @override
  String get profilNumaraYok => 'Sin número';

  @override
  String get profilFotoBaslik => 'Foto de perfil';

  @override
  String get profilFotoSec => 'Elegir foto';

  @override
  String get profilFotoGuncellendi => 'Foto de perfil actualizada ✓';

  @override
  String get profilFotoKaldirildi => 'Foto de perfil eliminada';

  @override
  String get ortakGaleri => 'Galería';

  @override
  String get profilParolaDegistir => 'Cambiar contraseña';

  @override
  String get profilMevcutParola => 'Contraseña actual';

  @override
  String get profilMevcutParolaZorunlu => 'La contraseña actual es obligatoria';

  @override
  String get profilParolaGuncelle => 'Actualizar contraseña';

  @override
  String get profilParolaGuncellendi => 'Contraseña actualizada ✓';

  @override
  String get profilTelefon => 'Teléfono';

  @override
  String get profilTelefonIpucu => 'ej. +905551112233';

  @override
  String get profilAranabilir => 'Se puede llamar';

  @override
  String get profilAranabilirAlt =>
      'Los roles autorizados (llamada con consentimiento) pueden acceder a su número';

  @override
  String get profilIletisimKaydet => 'Guardar contacto';

  @override
  String get profilIletisimGuncellendi => 'Datos de contacto actualizados ✓';

  @override
  String get personelEkle => 'Añadir personal';

  @override
  String get personelDuzenle => 'Editar personal';

  @override
  String get personelListelenemedi => 'No se pudo listar al personal.';

  @override
  String get personelPasiflestir => 'Desactivar';

  @override
  String get personelAktiflestir => 'Activar';

  @override
  String get personelPasiflestirildi => 'Desactivado ✓';

  @override
  String get personelAktiflestirildi => 'Activado ✓';

  @override
  String get personelGuncellendi => 'Personal actualizado ✓';

  @override
  String get personelEklendi => 'Personal añadido ✓';

  @override
  String get personelFoto => 'Foto';

  @override
  String get personelTelefonOpsiyonel => 'Móvil (opcional)';

  @override
  String get personelBosBirakDegismezNokta => 'Déjelo vacío para no cambiarlo.';

  @override
  String get personelYok =>
      'Aún no hay personal de campo.\nAñada uno desde abajo a la derecha.';

  @override
  String get disKisiEkle => 'Añadir contacto';

  @override
  String get disListeAlinamadi => 'No se pudo cargar la lista.';

  @override
  String get disKayitYokYonetim =>
      'Aún no hay registros. Añada un profesional de confianza desde abajo a la derecha.';

  @override
  String get disKayitYok => 'Aún no hay servicios externos registrados.';

  @override
  String get disNotEkleyin =>
      'Añada una nota (solo la administración puede editar).';

  @override
  String get disNotuDuzenle => 'Editar nota';

  @override
  String get disBolumNotu => 'Nota de la sección';

  @override
  String get disNotIpucu =>
      'ej. Profesionales de confianza desde años; por seguridad del sitio, no deje entrar a desconocidos.';

  @override
  String get disNotGuncellendi => 'Nota actualizada ✓';

  @override
  String get disAra => 'Llamar';

  @override
  String get disSilOnay => '¿Eliminar este registro?';

  @override
  String disSilGovde(Object ad) {
    return '\"$ad\" se eliminará.';
  }

  @override
  String get disSilindi => 'Eliminado ✓';

  @override
  String get disYeniKisi => 'Nuevo contacto externo';

  @override
  String get disKisiDuzenle => 'Editar contacto';

  @override
  String get disTur => 'Tipo de servicio';

  @override
  String get disTurIpucu => 'ej. Cerrajero, Electricidad, Fontanería';

  @override
  String get disTurZorunlu => 'El tipo es obligatorio';

  @override
  String get disAd => 'Nombre';

  @override
  String get disSoyad => 'Apellidos';

  @override
  String get disAdGerekli => 'El nombre es obligatorio';

  @override
  String get disSoyadGerekli => 'Los apellidos son obligatorios';

  @override
  String get nfcBaslik => 'Lectura de etiqueta NFC';

  @override
  String get nfcHazir => 'Listo para leer. Pulse Iniciar.';

  @override
  String get nfcYaklastirBekliyor =>
      'Acerque la etiqueta a la parte trasera del teléfono...';

  @override
  String get nfcOkundu => 'Etiqueta leída.';

  @override
  String get nfcOkumayaBasla => 'Iniciar lectura';

  @override
  String get nfcTekrarOku => 'Leer de nuevo';

  @override
  String nfcKuyrukBekleyen(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n lecturas pendientes de envío',
      one: '$n lectura pendiente de envío',
    );
    return '$_temp0';
  }

  @override
  String get nfcKuyruk => 'Cola de envío';

  @override
  String get nfcKaydedildiBekliyor =>
      'Guardado ✓ — se enviará automáticamente cuando haya conexión.';

  @override
  String get nfcKaydedildiGonderiliyor => 'Guardado ✓ — enviando...';

  @override
  String get nfcGonderildiZatenVar =>
      'Enviado ✓ — esta lectura ya estaba registrada.';

  @override
  String get nfcGonderildi => 'Enviado ✓ — lectura registrada.';

  @override
  String get nfcEslesmeYok =>
      'Esta etiqueta no coincide con ningún punto de control.';

  @override
  String get nfcSdmBaslik => 'SDM (bruto, sin verificar)';

  @override
  String get nfcTipEtiket => 'Tipo';

  @override
  String nfcNoktalarAlinamadi(Object hata) {
    return 'No se pudieron cargar los puntos: $hata';
  }

  @override
  String get nfcTestBaslik => 'PRUEBA: ¿qué punto escaneamos?';

  @override
  String get nfcTestAlt => 'Simula una lectura sin etiqueta física.';

  @override
  String get nfcAktifNoktaYok => 'No hay puntos de control activos.';

  @override
  String get nfcAktifNoktaYokAlt =>
      'Añada uno primero desde «Puntos de control».';

  @override
  String get nfcManuelOkut => 'Lectura manual (prueba)';

  @override
  String get nfcTestGorunur => 'Visible solo en compilaciones de prueba.';

  @override
  String nfcUidSatir(Object uid) {
    return 'UID: $uid';
  }

  @override
  String get nfcHataKapali =>
      'El NFC está desactivado. Actívelo en los ajustes del dispositivo.';

  @override
  String get nfcHataDesteklenmiyor => 'Este dispositivo no admite NFC.';

  @override
  String get nfcHataUidOkunamadi => 'No se pudo leer el UID de la etiqueta.';

  @override
  String nfcHataCozumlenemedi(Object detay) {
    return 'No se pudo interpretar la etiqueta: $detay';
  }

  @override
  String nfcHataOturum(Object detay) {
    return 'No se pudo iniciar la sesión NFC: $detay';
  }

  @override
  String nfcHataOkumaIptal(Object detay) {
    return 'Lectura cancelada: $detay';
  }

  @override
  String nfcHataYapilandirma(Object detay) {
    return 'NFC no está disponible en esta compilación: $detay. La aplicación necesita una actualización; reintentar no servirá.';
  }

  @override
  String get nfcHataBilinmeyen => 'Se ha producido un error desconocido.';

  @override
  String get nfcIosYaklastir =>
      'Acerque la etiqueta a la parte trasera del teléfono.';

  @override
  String get nfcIosOkundu => 'Leída';

  @override
  String get nfcIosIptal => 'Cancelado';

  @override
  String get nfcIosOkunamadi => 'No se pudo leer';

  @override
  String get seffafYuklenemedi => 'No se pudo cargar. Inténtelo de nuevo.';

  @override
  String get seffafAyYayinlandi => 'El mes se ha publicado.';

  @override
  String get seffafYayinGeriAlindi => 'Publicación retirada.';

  @override
  String get seffafVeriYokYonetim =>
      'Aún no hay datos financieros. Los meses aparecerán al registrar ingresos/gastos o cuotas.';

  @override
  String get seffafVeriYok =>
      'La administración aún no ha publicado un resumen.';

  @override
  String get seffafTaslakEki => ' • borrador';

  @override
  String get seffafYayinla => 'Publicar este mes';

  @override
  String get seffafYayindaAlt => 'Los residentes ven este resumen.';

  @override
  String get seffafOnizlemeAlt =>
      'Solo lo ve la administración (vista previa).';

  @override
  String get seffafOnizlemeUyari => 'Vista previa — aún sin publicar.';

  @override
  String seffafOzetBaslik(Object ay) {
    return '$ay — Resumen';
  }

  @override
  String get seffafToplamGelir => 'Ingresos totales';

  @override
  String get seffafToplamGider => 'Gastos totales';

  @override
  String get seffafNet => 'Neto';

  @override
  String seffafOncekiAyNet(Object tutar) {
    return 'Neto del mes anterior: $tutar';
  }

  @override
  String get seffafGiderDagilimi => 'Distribución de gastos';

  @override
  String get seffafGiderYok => 'No hay gastos registrados este mes.';

  @override
  String get seffafAidatToplama => 'Cobro de cuotas';

  @override
  String get seffafTahakkukYok => 'No hay devengo para este mes.';

  @override
  String seffafOdeyenDaire(Object odeyen, Object toplam) {
    return 'Unidades pagadas: $odeyen/$toplam';
  }

  @override
  String seffafTahsilatSatir(Object tahsilat, Object tahakkuk, Object yuzde) {
    return 'Cobrado: $tahsilat / $tahakkuk  (importe: $yuzde %)';
  }

  @override
  String seffafGecikmede(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n unidades vencidas',
      one: '$n unidad vencida',
    );
    return '$_temp0';
  }

  @override
  String ortakYuzde(Object yuzde) {
    return '$yuzde %';
  }

  @override
  String get entegYeni => 'Nueva';

  @override
  String get entegYokMesaj =>
      'No hay integraciones. Añada un sistema externo (megafonía/domótica/webhook) con «Nueva».';

  @override
  String get entegSilOnay => '¿Eliminar?';

  @override
  String entegSilGovde(Object ad) {
    return 'Se eliminará la integración \"$ad\".';
  }

  @override
  String entegSilinemedi(Object hata) {
    return 'No se pudo eliminar: $hata';
  }

  @override
  String get entegAktifKisa => 'activa';

  @override
  String get entegPasifKisa => 'inactiva';

  @override
  String entegKimlikSatir(Object tip, Object kilit) {
    return 'Auth: $tip$kilit';
  }

  @override
  String get entegTest => 'Probar';

  @override
  String entegTestBasarili(Object durum) {
    return '✓ Correcto ($durum)';
  }

  @override
  String entegTestBasarisiz(Object hata, Object durum) {
    return '✗ $hata$durum';
  }

  @override
  String get entegBasarisiz => 'Fallido';

  @override
  String get entegDuzenleBaslik => 'Editar integración';

  @override
  String get entegYeniBaslik => 'Nueva integración';

  @override
  String get entegPreset => 'Plantilla lista (preset)';

  @override
  String get entegKanalTipi => 'Tipo de canal';

  @override
  String get entegUrl => 'URL del endpoint (http/https)';

  @override
  String get entegUrlHelper =>
      'Las direcciones internas/privadas se bloquean al disparar';

  @override
  String get entegUrlHata => 'Debe empezar por http(s)';

  @override
  String get entegHttpMetodu => 'Método HTTP';

  @override
  String get entegKimlikDogrulama => 'Autenticación';

  @override
  String get entegSir => 'Secreto (bearer token / API key)';

  @override
  String get entegSirKayitli =>
      'Guardado — introduzca un valor nuevo para cambiarlo';

  @override
  String get entegSirYazmaOzel =>
      'Solo escritura; el servidor nunca lo devuelve';

  @override
  String get entegPayload => 'Plantilla de payload';

  @override
  String entegPayloadHelper(Object sablonlar) {
    return 'Marcadores $sablonlar';
  }

  @override
  String get entegTestMesaji => 'Mensaje de prueba';

  @override
  String get ortakAdGerekli => 'El nombre es obligatorio';

  @override
  String get ziyaretYeni => 'Nueva visita';

  @override
  String get ziyaretKaydedildi =>
      'Visita registrada — se ha notificado al residente ✓';

  @override
  String get ziyaretYokGuvenlik => 'Aún no hay registros de visitas.';

  @override
  String get ziyaretYokSakin => 'No se le han comunicado registros de visitas.';

  @override
  String ziyaretBildirilenSakin(Object ad) {
    return 'Residente notificado: $ad';
  }

  @override
  String get ziyaretSakiniAra => 'Llamar al residente';

  @override
  String get ziyaretGuvenligiAra => 'Llamar a seguridad';

  @override
  String get ziyaretBilgileriDuzenle => 'Editar datos';

  @override
  String get ziyaretGuncellendi => 'Datos de la visita actualizados ✓';

  @override
  String get ziyaretOnceDaireNo => 'Introduzca primero el número de unidad';

  @override
  String get ziyaretSakiniSecin => 'Seleccione el residente a notificar';

  @override
  String get ziyaretDuzenleBaslik => 'Editar visita';

  @override
  String get ziyaretDuzenleAlt =>
      'Puede actualizar el nombre, la unidad, el residente notificado y la nota.';

  @override
  String get ziyaretYeniAlt =>
      'El residente solo recibe un aviso (no se pide aprobación).';

  @override
  String get ziyaretAdAlan => 'Nombre de la visita *';

  @override
  String get ziyaretAdGerekli => 'El nombre de la visita es obligatorio';

  @override
  String get ziyaretSakinleriGetir => 'Cargar residentes';

  @override
  String get ziyaretBildirilecekSakin => 'Residente a notificar *';

  @override
  String get ziyaretKaydetVeBildir => 'Guardar y notificar al residente';

  @override
  String get raporBaslik => 'Informes mensuales';

  @override
  String get raporOncekiAy => 'Mes anterior';

  @override
  String get raporSonrakiAy => 'Mes siguiente';

  @override
  String raporAyBaslik(Object ay, Object yil) {
    return '$ay $yil';
  }

  @override
  String get raporYetkiYok =>
      'No tiene permiso para los informes mensuales. Esta pantalla es para el rol de administrador del sitio.';

  @override
  String get raporGorevTamamlama => 'Finalización de tareas';

  @override
  String get raporAidat => 'Cuotas';

  @override
  String get raporSonTamamlamalar => 'Últimas finalizaciones (primeras 10)';

  @override
  String get raporPlanlananPencere => 'Ventanas planificadas';

  @override
  String raporTamamlanmaYuzde(Object yuzde) {
    return 'Finalización $yuzde %';
  }

  @override
  String get raporPencereYok =>
      'No hay ventanas de ronda planificadas este mes.';

  @override
  String get raporGorevYok => 'No hay tareas finalizadas este mes.';

  @override
  String get raporToplamTamamlama => 'Total de finalizaciones';

  @override
  String get raporAidatKayitYok => 'No hay devengos/pagos para este periodo.';

  @override
  String raporTahakkukDaire(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Devengado ($n unidades)',
      one: 'Devengado ($n unidad)',
    );
    return '$_temp0';
  }

  @override
  String raporTahsilatOdeme(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Cobrado ($n pagos)',
      one: 'Cobrado ($n pago)',
    );
    return '$_temp0';
  }

  @override
  String get raporKalanBakiye => 'Saldo pendiente';

  @override
  String get aidatBaslik => 'Mis cuotas';

  @override
  String get aidatYetkiYok =>
      'La información de cuotas solo está disponible para residentes.';

  @override
  String get aidatDaireYok =>
      'No tiene ninguna unidad registrada. Contacte con la administración.';

  @override
  String get aidatToplamBakiye => 'Saldo total (todas las unidades)';

  @override
  String get aidatBorcVar => 'Con deuda';

  @override
  String get aidatBorcYok => 'Sin deuda';

  @override
  String get aidatToplamTahakkuk => 'Total devengado';

  @override
  String get aidatToplamOdenen => 'Total pagado';

  @override
  String get aidatBakiye => 'Saldo';

  @override
  String aidatHesapSatiri(Object tahakkuk, Object odenen, Object bakiye) {
    return 'Devengado $tahakkuk - pagado $odenen = $bakiye';
  }

  @override
  String aidatTahakkuklar(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Devengos ($n)',
      one: 'Devengo ($n)',
    );
    return '$_temp0';
  }

  @override
  String aidatOdemeler(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Pagos ($n)',
      one: 'Pago ($n)',
    );
    return '$_temp0';
  }

  @override
  String aidatSonOdeme(Object tarih) {
    return 'Vencimiento: $tarih';
  }

  @override
  String aidatMakbuz(Object no) {
    return 'Recibo: $no';
  }

  @override
  String get aidatOdemeDurumuNotu =>
      'El estado del pago solo se actualiza con la confirmación del proveedor de pago; consulte a su administración.';

  @override
  String get aidatYontemElden => 'Efectivo';

  @override
  String get aidatYontemHavale => 'Transferencia';

  @override
  String get aidatYontemKart => 'Tarjeta';

  @override
  String get aidatYontemDiger => 'Otro';

  @override
  String get aidatDurumBasarili => 'Correcto';

  @override
  String get aidatDurumIptal => 'Cancelado';

  @override
  String get noktaBaslik => 'Puntos de control';

  @override
  String get noktaEkle => 'Añadir punto';

  @override
  String get noktaListelenemedi => 'No se pudieron listar los puntos.';

  @override
  String get noktaSilOnay => '¿Eliminar este punto?';

  @override
  String noktaSilGovde(Object ad) {
    return 'Se eliminará el punto de control \"$ad\".';
  }

  @override
  String get noktaSilindi => 'Punto eliminado ✓';

  @override
  String get noktaUidZatenVar => 'Esta etiqueta NFC ya está registrada.';

  @override
  String get noktaDuzenleBaslik => 'Editar punto';

  @override
  String get noktaYeniBaslik => 'Nuevo punto de control';

  @override
  String get noktaAdIpucu => 'ej. Puerta principal';

  @override
  String get noktaUidAlan => 'UID de etiqueta NFC';

  @override
  String get noktaUidIpucu => 'ej. 04A2B3C4D5';

  @override
  String get noktaUidHelper => 'Identificador único de la etiqueta (hex).';

  @override
  String get noktaEnlem => 'Latitud (opc.)';

  @override
  String get noktaKonumGecersiz => 'Ubicación no válida. Ejemplo: 41,0082';

  @override
  String get ortakSecenekYuklenemedi =>
      'No se pudieron cargar algunas opciones: la lista puede estar incompleta.';

  @override
  String get noktaBoylam => 'Longitud (opc.)';

  @override
  String get noktaPasifAlt => 'Un punto inactivo no coincide al escanear';

  @override
  String get noktaYok => 'Todavía no hay puntos de control.';

  @override
  String get kuyrukHatalariTemizle => 'Borrar errores permanentes';

  @override
  String get kuyrukBos => 'La cola está vacía.';

  @override
  String kuyrukOzet(Object bekleyen, Object hatali) {
    return '$bekleyen pendientes · $hatali errores permanentes';
  }

  @override
  String get kuyrukSenkronla => 'Sincronizar ahora';

  @override
  String get kuyrukBekliyor => 'Pendiente';

  @override
  String kuyrukBekliyorDeneme(Object n) {
    return 'Pendiente (intento: $n)';
  }

  @override
  String get kuyrukGonderiliyor => 'Enviando...';

  @override
  String get kuyrukGonderildiZatenVar => 'Enviado (ya estaba registrado)';

  @override
  String get kuyrukGonderildiYeni => 'Enviado (registro nuevo)';

  @override
  String kuyrukKaliciHata(Object hata) {
    return 'Error permanente: $hata';
  }

  @override
  String get kuyrukEtiketEslesmedi => 'la etiqueta no coincide';

  @override
  String get okutmaImzaGecersiz =>
      'No se pudo verificar la firma de la etiqueta — puede ser falsa o incorrecta.';

  @override
  String get okutmaTekrarEdilmis => 'Esta lectura ya fue procesada.';

  @override
  String okutmaBeklenmeyenHata(Object detay) {
    return 'Error inesperado: $detay';
  }

  @override
  String get noktaUidZorunlu => 'El UID NFC es obligatorio';

  @override
  String get hataZamanAsimi =>
      'Se agotó el tiempo al conectar con el servidor.';

  @override
  String get hataSunucuyaUlasilamadi =>
      'No se pudo contactar con el servidor. Compruebe su conexión y la dirección del servidor.';

  @override
  String get destekBaslik => 'Soporte';

  @override
  String get destekYeniTalep => 'Nueva solicitud';

  @override
  String get destekTalepYok => 'Aún no tiene solicitudes de soporte';

  @override
  String destekYuklenemedi(Object hata) {
    return 'No se pudieron cargar las solicitudes.\n$hata';
  }

  @override
  String destekGonderilemedi(Object hata) {
    return 'No se pudo enviar la solicitud: $hata';
  }

  @override
  String get destekYeniTalepBaslik => 'Nueva solicitud de soporte';

  @override
  String get destekKonu => 'Asunto';

  @override
  String get destekGorselEkle => 'Añadir imagen';

  @override
  String get destekGorseliDegistir => 'Cambiar imagen';

  @override
  String get destekEkip => 'El equipo de Yönetiyor';

  @override
  String get tesisKurulumBaslik => 'Configure su sitio';

  @override
  String get tesisKurulumAciklama =>
      'Ha iniciado sesión como administrador por primera vez. Para continuar, introduzca el nombre de su sitio; podrá cambiarlo después en los ajustes.';

  @override
  String get tesisAdiIpucu => 'ej. Residencial Ejemplo';

  @override
  String get tesisAdiKisa =>
      'El nombre del sitio debe tener al menos 2 caracteres';

  @override
  String get tesisOlustur => 'Crear sitio';

  @override
  String get tesisAdiGuncellendi => 'Nombre del sitio actualizado';

  @override
  String get tesisAdiAciklama =>
      'Aparece en el título de la pantalla de inicio; lo ven todos los usuarios.';

  @override
  String get sikayetYokSakin =>
      'Aún no ha abierto ninguna queja.\nElija una unidad en el mapa de quejas para presentarla.';

  @override
  String sikayetSatirBaslik(Object daire, Object kategori) {
    return 'Unidad $daire · $kategori';
  }

  @override
  String get sikayetDurumKapandi => 'Cerrada';

  @override
  String get vardiyaBaslik => 'Turnos';

  @override
  String get vardiyaYuklenemedi => 'No se pudieron cargar los turnos.';

  @override
  String get vardiyaTanimYok => 'No hay turnos definidos';

  @override
  String vardiyaSaatAraligi(Object baslangic, Object bitis, Object gunTipi) {
    return '$baslangic - $bitis • $gunTipi';
  }

  @override
  String get vardiyaPersonelAta => 'Asignar personal';

  @override
  String vardiyaPersonelBaslik(Object ad) {
    return '$ad — Personal';
  }

  @override
  String get vardiyaPersonelGuncellendi => 'Personal del turno actualizado ✓';

  @override
  String get vardiyaPersonelYuklenemedi => 'No se pudo cargar el personal.';

  @override
  String get vardiyaAtanabilirYok => 'No hay personal asignable';

  @override
  String get gunTipiHaftaIci => 'Días laborables';

  @override
  String get gunTipiHaftaSonu => 'Fines de semana';

  @override
  String get gunTipiResmiTatil => 'Días festivos';

  @override
  String get gunTipiHerGun => 'Todos los días';

  @override
  String get yonIletisimBaslik => 'Contactos de administración';

  @override
  String get yonIletisimAlinamadi =>
      'No se pudieron obtener los datos de administración.';

  @override
  String get yonIletisimTanimliDegil =>
      'No hay datos de contacto de administración definidos.';

  @override
  String get yonIletisimMail => 'Correo de administración';

  @override
  String get yonIletisimAra => 'Llamar al administrador';

  @override
  String get aramaBaslatilamadi => 'No se pudo iniciar la llamada';

  @override
  String get aramaYapilamiyor => 'No se puede llamar';

  @override
  String get bildirimYok => 'Sin notificaciones';

  @override
  String bildirimYuklenemedi(Object hata) {
    return 'No se pudieron cargar las notificaciones.\n$hata';
  }

  @override
  String get bildirimYeniPush => 'Nueva notificación';

  @override
  String get akisDevriyeOkutma => 'Escaneo de ronda';

  @override
  String get akisGorevTamamlandi => 'Tarea completada';

  @override
  String get akisAidatOdemesi => 'Pago de cuotas';

  @override
  String get akisTalepAcildi => 'Solicitud abierta';

  @override
  String get akisTalepIsEmri => 'Solicitud convertida en orden de trabajo';

  @override
  String get akisTalepCozuldu => 'Solicitud resuelta';

  @override
  String get akisTalepReddedildi => 'Solicitud rechazada';

  @override
  String get akisDaireSikayeti => 'Queja sobre una vivienda';

  @override
  String get akisAlarmKacirilanTur => 'Ronda perdida';

  @override
  String get akisAlarmEksikCheckpoint => 'Punto de control faltante';

  @override
  String get akisAlarmGecikmisOkutma => 'Escaneo tardío';

  @override
  String get akisZiyaretciGirisi => 'Entrada de visitante';

  @override
  String get akisZiyaretciCikisi => 'Salida de visitante';

  @override
  String get akisKargoKaydedildi => 'Paquete registrado';

  @override
  String get akisKargoTeslimEdildi => 'Paquete entregado';

  @override
  String get akisAracGirisi => 'Entrada de vehículo';

  @override
  String get akisAracCikisi => 'Salida de vehículo';

  @override
  String get akisIhlalKaydi => 'Registro de infracción';

  @override
  String akisAltDaireTutar(Object daire, Object tutar) {
    return 'Vivienda $daire — $tutar';
  }

  @override
  String akisAltDaireKategori(Object daire, Object kategori) {
    return 'Vivienda $daire — $kategori';
  }

  @override
  String akisAltAdDaire(Object ad, Object daire) {
    return '$ad — vivienda $daire';
  }

  @override
  String akisAltPlakaDaire(Object plaka, Object daire) {
    return '$plaka — vivienda $daire';
  }

  @override
  String akisAltPlakaTanim(Object plaka, Object tanim) {
    return '$plaka ($tanim)';
  }

  @override
  String akisAltPlakaDaireTanim(Object plaka, Object daire, Object tanim) {
    return '$plaka — vivienda $daire ($tanim)';
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
  String get ortakParolayiGoster => 'Mostrar contraseña';

  @override
  String get ortakParolayiGizle => 'Ocultar contraseña';

  @override
  String get ortakFotograf => 'Foto';

  @override
  String get ortakFotografiBuyut => 'Ampliar la foto';

  @override
  String get ortakGoster => 'Ver';

  @override
  String get talepRedBaslik => 'Rechazar solicitud';

  @override
  String get ziyaretciDaireSakinYok => 'No hay residente activo en esta unidad';

  @override
  String get ceviriOtomatik => 'Este contenido se tradujo automáticamente';

  @override
  String get ceviriOtomatikKisa => 'Traducción automática';

  @override
  String get ceviriOrijinaliGor => 'Ver el original';

  @override
  String get ceviriCeviriyiGor => 'Ver la traducción';

  @override
  String get ceviriHazirlaniyor =>
      'Traducción en curso: se muestra el original';

  @override
  String get ceviriHazirlaniyorKisa => 'Traduciendo';

  @override
  String get ceviriYapilamadi => 'No se pudo traducir: se muestra el original';

  @override
  String get ceviriYapilamadiKisa => 'Error de traducción';

  @override
  String get modulAracGecis => 'Pasos de vehículos';

  @override
  String get modulOtopark => 'Aparcamiento';

  @override
  String get modulIhlaller => 'Infracciones';

  @override
  String get aracSuzgecTumu => 'Todos';

  @override
  String get aracSuzgecIceride => 'Dentro';

  @override
  String get aracSuzgecCikmis => 'Salidos';

  @override
  String get aracPlakaAra => 'Buscar matrícula';

  @override
  String get aracListeBos => 'No hay pasos de vehículos registrados';

  @override
  String get aracAramaBos => 'Ningún paso coincide con esa matrícula';

  @override
  String get aracRozetIceride => 'Dentro';

  @override
  String get aracRozetCikti => 'Salió';

  @override
  String get aracRozetZiyaretci => 'Visitante';

  @override
  String aracGirisZamani(Object zaman) {
    return 'Entrada: $zaman';
  }

  @override
  String aracCikisZamani(Object zaman) {
    return 'Salida: $zaman';
  }

  @override
  String aracDaire(Object no) {
    return 'Vivienda $no';
  }

  @override
  String get aracCikisVer => 'Registrar salida';

  @override
  String get aracCikisOnayBaslik => '¿Registrar la salida?';

  @override
  String get aracCikisVerildi => 'Salida registrada';

  @override
  String get aracZatenKapali => 'Este paso ya está cerrado';

  @override
  String get aracYeniGiris => 'Nueva entrada';

  @override
  String get aracGirisKaydedildi => 'Entrada del vehículo registrada';

  @override
  String get aracPlaka => 'Matrícula';

  @override
  String get aracPlakaZorunlu => 'La matrícula es obligatoria';

  @override
  String get aracTanimAlani => 'Descripción del vehículo (opcional)';

  @override
  String get aracDaireAlani => 'N.º de vivienda (opcional)';

  @override
  String get aracZiyaretciMi => 'Vehículo de visitante';

  @override
  String get aracZatenIceride =>
      'Esta matrícula ya tiene un paso abierto (vehículo dentro)';

  @override
  String get aracErisimYok =>
      'La lista de pasos está reservada a la administración y la seguridad';

  @override
  String aracKaydeden(Object ad) {
    return 'Registrado por: $ad';
  }

  @override
  String get otoparkDoluEtiket => 'Ocupadas';

  @override
  String get otoparkBosEtiket => 'Libres';

  @override
  String get otoparkKapasiteEtiket => 'Capacidad';

  @override
  String get otoparkKapasiteTanimsiz =>
      'Capacidad no definida: solo se muestra el número de vehículos dentro';

  @override
  String get otoparkAracListesi => 'Abrir los pasos de vehículos';

  @override
  String get ihlalDurumYeni => 'Nueva';

  @override
  String get ihlalDurumInceleniyor => 'En revisión';

  @override
  String get ihlalDurumKapatildi => 'Cerrada';

  @override
  String get ihlalKaynakKamera => 'Cámara';

  @override
  String get ihlalKaynakManuel => 'Manual';

  @override
  String get ihlalKaynakDevriye => 'Ronda';

  @override
  String get ihlalListeBos => 'No hay infracciones registradas';

  @override
  String get ihlalYeni => 'Nueva infracción';

  @override
  String get ihlalAcildi => 'Infracción registrada';

  @override
  String get ihlalBaslikAlani => 'Título';

  @override
  String get ihlalBaslikZorunlu => 'El título es obligatorio';

  @override
  String get ihlalAciklamaAlani => 'Descripción (opcional)';

  @override
  String get ihlalKonumAlani => 'Ubicación (opcional)';

  @override
  String get ihlalKaynakAlani => 'Fuente de detección';

  @override
  String get ihlalIncelemeyeAl => 'Iniciar revisión';

  @override
  String get ihlalKapat => 'Cerrar registro';

  @override
  String get ihlalDurumGuncellendi => 'Estado de la infracción actualizado';

  @override
  String get ihlalKapatmaOnay =>
      '¿Cerrar el registro? Una infracción cerrada no puede reabrirse.';

  @override
  String get ihlalKapaliDegistirilemez =>
      'Una infracción cerrada no puede reabrirse';

  @override
  String get ihlalErisimYok =>
      'Las infracciones están reservadas a la administración y la seguridad';

  @override
  String ihlalKaydeden(Object ad) {
    return 'Abierta por: $ad';
  }

  @override
  String get kameraRestream => 'URL de retransmisión (opcional)';

  @override
  String get kameraRestreamAlt =>
      'Hace reproducible una cámara RTSP. La dirección HLS de la pasarela Frigate/go2rtc.';

  @override
  String get kameraRestreamHata =>
      'La dirección de retransmisión debe empezar por http:// o https://';

  @override
  String get kameraRestreamRozet => 'Vía pasarela';

  @override
  String get modulPlakaOlaylari => 'Lecturas de matrículas';

  @override
  String get anprDurumIslendi => 'Procesada';

  @override
  String get anprDurumOnayBekliyor => 'Pendiente de aprobación';

  @override
  String get anprDurumYokSayildi => 'Ignorada';

  @override
  String get anprDurumHata => 'Error';

  @override
  String get anprYonGiris => 'Entrada';

  @override
  String get anprYonCikis => 'Salida';

  @override
  String get anprYonBilinmiyor => 'Dirección desconocida';

  @override
  String get anprListeBos => 'No hay lecturas de matrículas';

  @override
  String get anprErisimYok =>
      'Las lecturas de matrículas están reservadas a la administración y la seguridad';

  @override
  String anprGuven(Object oran) {
    return 'Confianza $oran %';
  }

  @override
  String get anprOnayla => 'Aprobar';

  @override
  String get anprReddet => 'Rechazar';

  @override
  String get anprOnayBaslik => 'Aprobar la lectura';

  @override
  String get anprOnayAciklama =>
      'Puede corregir la matrícula si se leyó mal. Al aprobar se abre o cierra el paso del vehículo.';

  @override
  String get anprKararUygulandi => 'Decisión aplicada';

  @override
  String get anprOnayBeklemiyor =>
      'Esta lectura ya no está pendiente de aprobación';

  @override
  String get anprNedenDusukGuven => 'Confianza baja';

  @override
  String get anprNedenZatenIceride => 'El vehículo ya está dentro';

  @override
  String get anprNedenAcikGecisYok => 'No hay paso abierto';

  @override
  String get anprNedenOtomatikCikisKapali => 'Salida automática desactivada';

  @override
  String get anprNedenElleReddedildi => 'Rechazada manualmente';

  @override
  String get anprNedenPlakaBicimi => 'No se pudo leer la matrícula';

  @override
  String get aracPlakaOkumalari => 'Lecturas de matrículas';

  @override
  String get kategoriGoruntuKirliligi => 'Contaminación visual';

  @override
  String get fabSikayetBildir => 'Informar de una queja vecinal';

  @override
  String get sakinRolTipi => 'Tipo de relación';

  @override
  String get sakinRolMalik => 'Propietario';

  @override
  String get sakinRolKiraci => 'Inquilino';

  @override
  String get sakinRolDegisme => 'Sin cambios';

  @override
  String get sakinRolAlt =>
      'Las cuotas se cargan al inquilino y las inversiones al propietario.';

  @override
  String get sakinEposta => 'Correo electrónico';

  @override
  String get sakinEpostaTemizle => 'Eliminar el correo';

  @override
  String get sakinRolBagYok =>
      'El residente debe estar vinculado a una vivienda para definir el tipo de relación';

  @override
  String get sikayetKuyruguBaslik => 'Cola de quejas';

  @override
  String get sikayetSekmeYeni => 'Nuevas';

  @override
  String get sikayetSekmeTumu => 'Todas';

  @override
  String get sikayetOkunmamisYok => 'No hay quejas sin leer.';

  @override
  String get sikayetYokYonetim => 'Aún no hay quejas.';

  @override
  String get sikayetOkunduIsaretle => 'Marcar como leída';

  @override
  String sikayetOkunmamisRozet(int sayi) {
    return '$sayi quejas sin leer';
  }

  @override
  String get kameraHataAdresBozuk =>
      'La dirección de emisión no es válida. Puede contener un espacio o un salto de línea.';

  @override
  String get kameraHataSemaDesteklenmiyor =>
      'Este tipo de dirección no se puede reproducir directamente. Defina una dirección de retransmisión para la cámara.';

  @override
  String get kameraHataSifrelenmemis =>
      'El dispositivo bloqueó la emisión sin cifrar (http). Un perfil de trabajo o una VPN puede estar impidiéndolo.';

  @override
  String kameraUrlCokUzun(int sinir) {
    return 'La dirección de emisión es demasiado larga (máximo $sinir caracteres).';
  }

  @override
  String get kameraUrlSifrelenmemisUyari =>
      'Esta dirección no está cifrada (http). Use https si es posible.';

  @override
  String get modulDaireTanimlari => 'Tipos de vivienda';

  @override
  String get daireTanimSekmeTipler => 'Tipos';

  @override
  String get daireTanimSekmeGruplar => 'Grupos';

  @override
  String get daireTanimAd => 'Nombre';

  @override
  String get daireTanimAdIpucu => 'p. ej. 2+1, dúplex, Villa';

  @override
  String get daireTanimVarsayilanAidat => 'Cuota predeterminada';

  @override
  String get daireTanimAidatBos => 'Sin definir';

  @override
  String get daireTanimAidatAlt =>
      'Vacío significa sin definir; 0 significa exento.';

  @override
  String daireTanimDaireSayisi(int sayi) {
    return '$sayi unidades';
  }

  @override
  String daireTanimSilOnay(int sayi) {
    return '¿Eliminar esta definición? Las $sayi unidades vinculadas NO se eliminan; solo se borra su clasificación.';
  }

  @override
  String daireTanimSilindiEtki(int sayi) {
    return 'Eliminado. $sayi unidades perdieron su clasificación.';
  }

  @override
  String get daireTanimYok => 'Aún no hay definiciones.';

  @override
  String get daireTanimYeni => 'Nueva definición';

  @override
  String get daireTipiSecici => 'Tipo de unidad';

  @override
  String get daireGrubuSecici => 'Grupo de unidades';

  @override
  String get daireTanimSecilmedi => 'Sin seleccionar';

  @override
  String get odeBaslik => 'Pagar';

  @override
  String get odeBorcunuz => 'Importe pendiente';

  @override
  String get odeHavaleBaslik => 'Transferencia bancaria';

  @override
  String get odeHavaleAdim =>
      'Transfiera al IBAN e indique el código de abajo en el concepto. Sin el código su pago puede no conciliarse.';

  @override
  String get odeKodBaslik => 'Su código de referencia';

  @override
  String get odeKopyala => 'Copiar';

  @override
  String get odeKopyalandi => 'Copiado';

  @override
  String get odeKartBaslik => 'Pagar con tarjeta';

  @override
  String get odeKartKapali =>
      'El pago con tarjeta aún no está habilitado. Puede usar una transferencia bancaria.';

  @override
  String get odeHavaleKapali =>
      'La comunidad aún no ha definido una cuenta bancaria. Contacte con la administración.';

  @override
  String get odeBorcYok => 'No tiene deudas pendientes.';

  @override
  String get odeBasarili => 'Se ha recibido su pago.';

  @override
  String get nfcFotoGerekli => 'Se requiere una foto para iniciar la ronda.';

  @override
  String get nfcFotoCek => 'Hacer foto y enviar';

  @override
  String get nfcFotoYukleniyor => 'Subiendo la foto...';

  @override
  String nfcFotoYuklenemedi(String hata) {
    return 'No se pudo subir la foto: $hata';
  }

  @override
  String get nfcKonumYok =>
      'Ubicación no disponible — el escaneo se registró sin ella.';

  @override
  String get nfcKonumIzinYok =>
      'Permiso de ubicación denegado — el escaneo se registró sin ella.';

  @override
  String get nfcKonumServisKapali =>
      'Los servicios de ubicación están desactivados — escaneo sin ubicación.';

  @override
  String get rolGuvenlikAmiri => 'Jefe de seguridad';

  @override
  String get rolDenetci => 'Auditor';

  @override
  String get kvkkBaslik => 'Aviso de privacidad';

  @override
  String get kvkkSonaKaydir =>
      'Desplácese hasta el final del texto para aprobar.';

  @override
  String get kvkkOnayliyorum => 'He leído y apruebo';

  @override
  String get kvkkYuklenemedi => 'No se pudo cargar el aviso de privacidad.';

  @override
  String get kvkkTekrarDene => 'Reintentar';

  @override
  String get kvkkSurumDegisti => 'El texto se actualizó; lea la nueva versión.';

  @override
  String get kvkkIzinBaslik => 'Campañas y ofertas para mí';

  @override
  String get kvkkIzinAciklama =>
      'Totalmente opcional; puede continuar sin aprobar. Puede cambiarlo cuando quiera en Ajustes.';

  @override
  String get kvkkIzinEposta => 'Quiero recibir correos electrónicos';

  @override
  String get kvkkIzinSms => 'Quiero recibir SMS';

  @override
  String get kvkkIzinArama => 'Quiero recibir llamadas';

  @override
  String get kvkkIzinKaydedilemedi => 'No se pudo guardar la preferencia.';

  @override
  String get kvkkAyarlarBaslik => 'Permisos y aviso de privacidad';

  @override
  String get kvkkMetniGoruntule => 'Ver el aviso de privacidad';

  @override
  String get anketBaslik => 'Encuestas';

  @override
  String get anketYok => 'No hay encuestas abiertas ahora.';

  @override
  String get anketKapali => 'Cerrada';

  @override
  String get anketOyVerdiniz => 'Su voto fue registrado';

  @override
  String get anketOyVer => 'Votar';

  @override
  String anketToplamOy(int sayi) {
    return '$sayi votos';
  }

  @override
  String anketOyHatasi(String hata) {
    return 'No se pudo enviar el voto: $hata';
  }

  @override
  String get anketSonucKapali =>
      'Los resultados aparecen al cerrar la encuesta.';

  @override
  String get modulAnketler => 'Encuestas';

  @override
  String get hesapSilBolum => 'Cuenta';

  @override
  String get hesapSilBaslik => 'Eliminar mi cuenta';

  @override
  String get hesapSilAlt =>
      'Elimine su cuenta y sus datos personales de forma permanente';

  @override
  String get hesapSilOnayBaslik => '¿Eliminar su cuenta?';

  @override
  String get hesapSilOnayGovde =>
      'Se eliminarán su nombre, su teléfono, su correo electrónico y los registros de sus dispositivos, y ya no podrá iniciar sesión. Los registros de cuotas y pagos no se pueden eliminar porque la ley nos obliga a conservarlos; seguirán almacenados de forma anónima y dejarán de estar vinculados a su nombre.';

  @override
  String get hesapSilParolaEtiket => 'Su contraseña';

  @override
  String get hesapSilParolaAciklama =>
      'Introduzca su contraseña de nuevo por seguridad.';

  @override
  String get hesapSilOnayla => 'Eliminar mi cuenta permanentemente';

  @override
  String get hesapSilSonucSilindi => 'Su cuenta ha sido eliminada.';

  @override
  String get hesapSilSonucAnonim =>
      'Su cuenta ha sido eliminada. Los registros que la ley nos obliga a conservar se han anonimizado.';

  @override
  String get hesapSilParolaGerekli =>
      'Introduzca su contraseña para continuar.';

  @override
  String get hesapSilSiliniyor => 'Eliminando...';

  @override
  String get ayarlarHukuki => 'Legal';

  @override
  String get ayarlarGizlilik => 'Política de privacidad';

  @override
  String get ayarlarKosullar => 'Condiciones de uso';

  @override
  String get ayarlarBelgeAcilamadi =>
      'No se pudo abrir la página. Compruebe su conexión a Internet.';

  @override
  String get demoSimuleOkutma => 'Escaneo simulado';

  @override
  String demoSimuleOkutmaBasarili(String nokta) {
    return 'Escaneo simulado registrado: $nokta';
  }

  @override
  String get demoSimuleOkutmaHata =>
      'No se pudo registrar el escaneo simulado.';

  @override
  String get denetciWebBaslik => 'Las pantallas de auditoría están en la web';

  @override
  String denetciWebGovde(String adres) {
    return 'Los informes de auditoría y la supervisión financiera están diseñados para el escritorio. Abra $adres en su ordenador.';
  }

  @override
  String get denetciWebKopyala => 'Copiar dirección';

  @override
  String get modulVardiyalar => 'Turnos';

  @override
  String get izgaraDuzenleBaslik => 'Editar pantalla de inicio';

  @override
  String izgaraDuzenleAciklama(int enCok) {
    return 'Elija hasta $enCok secciones que más use.';
  }

  @override
  String get izgaraSifirla => 'Restablecer valores predeterminados';

  @override
  String get izgaraKaydet => 'Guardar';

  @override
  String izgaraSecim(int secili, int enCok) {
    return '$secili/$enCok seleccionados';
  }

  @override
  String izgaraTavanUyarisi(int enCok) {
    return 'Ha alcanzado el límite. Quite uno para añadir otro ($enCok mosaicos).';
  }

  @override
  String get dilSeciciBaslik => 'Idioma';

  @override
  String get talepGeriAl => 'Retirar';

  @override
  String get talepGeriAlOnay =>
      '¿Retirar esta solicitud? Una solicitud retirada no se envía a la administración y esta acción no se puede deshacer.';

  @override
  String get talepGeriAlindi => 'Solicitud retirada';

  @override
  String get talepDurumGeriAlindi => 'Retirada';

  @override
  String get sikayetGeriAl => 'Retirar la queja';

  @override
  String get sikayetGeriAlindi => 'Queja retirada';

  @override
  String get izinDevam => 'Continuar';

  @override
  String get izinKonumBaslik => '¿Por qué se necesita la ubicación?';

  @override
  String get izinKonumGovde =>
      'Al escanear un punto de control, se registra su ubicación en ese momento para confirmar que la ronda se realizó realmente en el sitio. La ubicación se obtiene SOLO en el momento del escaneo; la aplicación no le rastrea en segundo plano.';

  @override
  String get izinKameraBaslik => '¿Por qué se necesita la cámara?';

  @override
  String get izinKameraGovde =>
      'La cámara se usa para que pueda adjuntar una foto al informar una solicitud o avería. La foto solo se toma cuando usted la hace y se envía a la administración.';

  @override
  String get girisKodlaBaslik => 'Sin contraseña: iniciar sesión con un código';

  @override
  String get girisKodlaAciklama =>
      'Enviaremos un código de verificación de seis dígitos a su teléfono.';

  @override
  String get girisKoduGonder => 'Enviar código';

  @override
  String get girisKodAlani => 'Código de verificación';

  @override
  String get hesapSilKodlaOnayla => 'Sin contraseña: confirmar con un código';

  @override
  String get hesapSilKodAciklama =>
      'Enviaremos un código de seis dígitos a su dirección de correo electrónico para confirmar la eliminación.';

  @override
  String get hesapSilKodGerekli => 'Introduzca el código de confirmación';

  @override
  String get kayitBaslik => 'Iniciar sesión con ID de instalación';

  @override
  String get kayitAltBaslik => 'Elija lo que le corresponde';

  @override
  String get kayitRolYonetici => 'Administrador';

  @override
  String get kayitRolSakin => 'Residente';

  @override
  String get kayitRolGuvenlik => 'Agente de seguridad';

  @override
  String get kayitRolTesisGorevlisi => 'Personal de la instalación';

  @override
  String get kayitTesisKodu => 'ID de la instalación';

  @override
  String get kayitTesisKoduIpucu =>
      'El código que le dio su administración (p. ej. OLTU-260715)';

  @override
  String get kayitDaireNo => 'N.º de vivienda';

  @override
  String get kayitBlok => 'Bloque (si lo hay)';

  @override
  String get kayitDevam => 'Continuar';

  @override
  String get kayitKodBaslik => 'Código de verificación';

  @override
  String kayitKodAciklama(String tesis, String telefon) {
    return 'Se envió un código al $telefon para $tesis. Si el número no está registrado, no llegará ningún código.';
  }

  @override
  String get kayitKodAlani => 'Código de 6 dígitos';

  @override
  String get kayitTesisKoduGerekli => 'El ID de la instalación es obligatorio.';

  @override
  String get kayitDaireGerekli => 'El n.º de vivienda es obligatorio.';

  @override
  String get kayitKodGerekli => 'Introduzca el código.';

  @override
  String get kayitYontemBaslik => '¿Cómo iniciará sesión?';

  @override
  String get kayitYontemParola => 'Crear una contraseña';

  @override
  String get kayitGirisLinki => '¿Ya tiene una cuenta? Iniciar sesión';

  @override
  String kayitAdim(String n, String toplam) {
    return 'Paso $n/$toplam';
  }

  @override
  String sosyalIleDevam(String saglayici) {
    return 'Continuar con $saglayici';
  }

  @override
  String get sosyalBaslik => 'Vincule su cuenta';

  @override
  String sosyalEslesmeAciklama(String saglayici) {
    return 'Su cuenta de $saglayici está verificada. Introduzca el ID de la finca y su número de teléfono para localizar su cuenta.';
  }

  @override
  String get sosyalRelayUyari =>
      'Apple ocultó su dirección de correo; no se puede enviar correo a ella.';

  @override
  String get sosyalTesisKodu => 'ID de la finca';

  @override
  String get sosyalKodGonder => 'Enviar código de verificación';

  @override
  String sosyalKodAciklama(String tesis, String telefon) {
    return '$tesis — introduzca el código enviado al $telefon.';
  }

  @override
  String get sosyalDogrula => 'Verificar y acceder';

  @override
  String get sosyalVazgec => 'Cancelar';

  @override
  String get davetBaslik => 'Registro';

  @override
  String get davetGecersizBaslik => 'El enlace no funciona';

  @override
  String get davetSuresiDoldu => 'Este enlace de invitación ha caducado.';

  @override
  String get davetKullanilmis => 'Esta invitación ya se ha utilizado.';

  @override
  String get davetBulunamadi => 'Este enlace de invitación no es válido.';

  @override
  String get davetYoneticinizeBasvurun =>
      'Solicite una nueva invitación a su administrador.';

  @override
  String davetOzet(String tesis, String rol) {
    return '$tesis le invitó como $rol.';
  }

  @override
  String get kayitYontemEposta => 'Continuar con correo';

  @override
  String get kayitYontemVeya => 'o';

  @override
  String get kayitBilgilerBaslik => 'Sus datos';

  @override
  String get kayitAdSoyad => 'Nombre y apellidos';

  @override
  String get kayitAdGerekli => 'El nombre y apellidos es obligatorio.';

  @override
  String get kayitParola => 'Contraseña';

  @override
  String get kayitParolaGerekli =>
      'La contraseña debe tener al menos 8 caracteres.';

  @override
  String get kayitTesisAdBaslik => 'Cree su comunidad';

  @override
  String get kayitTesisAd => 'Introduzca el nombre de la comunidad';

  @override
  String get kayitTesisAdIpucu => 'p. ej. Residencial Oltu';

  @override
  String get kayitTesisAdGerekli => 'El nombre de la comunidad es obligatorio.';

  @override
  String get kayitZatenSitemVar => 'Ya tengo una comunidad';

  @override
  String get kayitTesisKoduBaslik => 'Su código de comunidad';

  @override
  String get kayitTesisKoduPaylas =>
      'Comparta este código con sus residentes y personal; lo usan para unirse.';

  @override
  String get kayitKopyala => 'Copiar';

  @override
  String get kayitKopyalandi => 'Copiado';

  @override
  String get kayitTamamla => 'Continuar';

  @override
  String get kayitSosyalAdNotu =>
      'Nombre obtenido de su cuenta; puede cambiarlo.';

  @override
  String get kayitEposta => 'Correo electrónico';

  @override
  String get kayitEpostaGerekli =>
      'La dirección de correo electrónico es obligatoria.';

  @override
  String get kayitEpostaGecersiz => 'Introduzca un correo electrónico válido.';

  @override
  String get kayitTelefonIletisim => 'Teléfono (opcional)';

  @override
  String get kayitTelefonNotu =>
      'El teléfono es solo para contacto; la verificación se realiza por correo electrónico.';

  @override
  String get kayitTesisKoduGir => 'Introduzca su ID de instalación';

  @override
  String kayitKodAciklamaEposta(String tesis) {
    return 'Enviamos un código de verificación a su correo electrónico para $tesis. Si su dirección no está registrada, no llegará ningún código.';
  }

  @override
  String get kayitOnayBekliyorBaslik =>
      'Esperando la aprobación del administrador';

  @override
  String get kayitOnayBekliyorAciklama =>
      'No se pudieron verificar sus datos y se enviaron a su administrador para su aprobación. Compruebe su ID de instalación; si el problema persiste, consulte a su administrador. Una vez aprobado, podrá iniciar sesión.';

  @override
  String get kayitGiriseDon => 'Volver al inicio de sesión';

  @override
  String get sosyalTamamlaBaslik => 'Completar con ID de instalación';

  @override
  String sosyalTamamlaAciklama(String saglayici) {
    return 'Su cuenta de $saglayici está verificada. Para completar, introduzca su rol y su ID de instalación.';
  }

  @override
  String get sosyalRol => 'Su rol';

  @override
  String get sosyalTamamla => 'Completar';

  @override
  String get sosyalOtpAciklama =>
      'Introduzca el código de verificación enviado a su correo electrónico.';

  @override
  String get binaYapisalAraclar => 'Herramientas estructurales';

  @override
  String get binaKatSil => 'Eliminar planta';

  @override
  String get binaTopluTip => 'Cambiar estado en lote';

  @override
  String get binaSiralama => 'Editar orden';

  @override
  String binaKatSilOzet(int n) {
    return 'Se eliminarán $n viviendas';
  }

  @override
  String binaKatSilOnay(int kat) {
    return 'Todas las viviendas de la planta $kat se eliminarán permanentemente. No se puede deshacer.';
  }

  @override
  String get binaAralikSec => 'Seleccionar por número';

  @override
  String get binaAralikUygula => 'Seleccionar';

  @override
  String binaSeciliSayisi(int n) {
    return '$n viviendas seleccionadas';
  }

  @override
  String binaAralikBulunamayan(String parca) {
    return 'No encontrado: $parca';
  }

  @override
  String get ortakEminMisiniz => '¿Está seguro?';

  @override
  String get ortakDurum => 'Estado';

  @override
  String get ortakAktif => 'Activo';

  @override
  String get ortakPasif => 'Inactivo';

  @override
  String get binaBaslangicKat => 'Planta inicial';

  @override
  String get binaBaslangicKatIpucu =>
      'Negativo para sótanos: -2, -1, 0 (baja), 1…';

  @override
  String get rezSekmeGecmis => 'Pasadas';

  @override
  String get rezGecmisYok => 'No hay reservas pasadas.';

  @override
  String get rezGecmisTamam => 'Completada';

  @override
  String rezIptalEden(String ad) {
    return 'Cancelado por: $ad';
  }

  @override
  String get binaKatBos =>
      'No hay viviendas en esta planta; eliminarla no afecta a ningún registro.';

  @override
  String binaKatOzet(int daire, int sakin, int talep) {
    return '$daire viviendas · $sakin residentes · $talep quejas abiertas';
  }

  @override
  String binaKatOzetMali(int tahakkuk, int odeme, int rezervasyon) {
    return '$tahakkuk cuotas · $odeme cobros · $rezervasyon reservas';
  }

  @override
  String get binaKatMaliUyari =>
      'Esta planta tiene registros de cuotas. Al eliminarla se borran permanentemente cuotas y cobros; el rastro contable no se puede recuperar. Considere desactivar las viviendas en su lugar.';

  @override
  String binaKatOnayYaz(int kat) {
    return 'Escriba el número de planta para confirmar ($kat)';
  }

  @override
  String binaKatSilOzetOnay(
    String blok,
    int kat,
    int daire,
    int sakin,
    int kayit,
  ) {
    return 'Se eliminará la planta $kat del bloque $blok: $daire viviendas, $sakin residentes y $kayit registros vinculados se borrarán permanentemente. No se puede deshacer.';
  }

  @override
  String get kurulumBaslik => 'Asistente de configuración';

  @override
  String get kurulumAlt =>
      'Complete los pasos para dejar sus instalaciones listas.';

  @override
  String get kurulumIlerleme => 'Progreso';

  @override
  String get kurulumTamamlandi => 'Configuración completada';

  @override
  String kurulumAdimTamam(int sayi) {
    return '$sayi registros';
  }

  @override
  String get kurulumAdimAtlandi => 'Omitido';

  @override
  String get kurulumAdimBekliyor => 'Pendiente';

  @override
  String get kurulumGit => 'Ir';

  @override
  String get kurulumGoruntule => 'Ver';

  @override
  String get kurulumAtla => 'Omitir';

  @override
  String get kurulumAtlamayiGeriAl => 'Deshacer omisión';

  @override
  String kurulumSayac(int gecilen, int toplam) {
    return '$gecilen/$toplam pasos';
  }

  @override
  String get kurulumHata => 'No se pudo cargar el estado de la configuración.';

  @override
  String get kurulumBlok => 'Bloques';

  @override
  String get kurulumBlokAlt => 'Defina los bloques del edificio.';

  @override
  String get kurulumDaire => 'Viviendas';

  @override
  String get kurulumDaireAlt => 'Cree pisos y viviendas en lote.';

  @override
  String get kurulumDaireTipi => 'Tipos de vivienda';

  @override
  String get kurulumDaireTipiAlt =>
      'Defina tipos e importes de cuota predeterminados.';

  @override
  String get kurulumSakin => 'Residentes';

  @override
  String get kurulumSakinAlt => 'Añada residentes a las viviendas.';

  @override
  String get kurulumPersonel => 'Personal';

  @override
  String get kurulumPersonelAlt => 'Introduzca los registros de empleados.';

  @override
  String get kurulumGorevAlani => 'Categorías de tareas';

  @override
  String get kurulumGorevAlaniAlt =>
      'Cree las categorías que agruparán sus tareas.';

  @override
  String get kurulumNfc => 'Puntos NFC';

  @override
  String get kurulumNfcAlt => 'Defina los puntos de control de ronda.';

  @override
  String get kurulumAidat => 'Emisión de cuotas';

  @override
  String get kurulumAidatAlt => 'Emita las cuotas del primer periodo.';

  @override
  String get kurulumAdimWebde =>
      'Este paso solo puede realizarse desde el panel web con una cuenta de administrador de la plataforma.';

  @override
  String get kurulumHatirlaticiBaslik => 'Complete la configuración';

  @override
  String get kurulumHatirlaticiMetin =>
      'Faltan algunos pasos para dejar sus instalaciones listas. El asistente le lleva a cada pantalla.';

  @override
  String get kurulumHatirlaticiGit => 'Abrir el asistente';

  @override
  String get kurulumHatirlaticiSonra => 'Más tarde';

  @override
  String get noktaYokAlt =>
      'Los puntos de control son las etiquetas NFC que se leen durante las rondas.';

  @override
  String get devriyePlanYokAlt =>
      'Un plan de ronda define qué puntos se leen y cuándo.';

  @override
  String get personelYokAlt =>
      'Aquí crea las cuentas de seguridad y personal de instalaciones.';

  @override
  String get sakinYokAlt =>
      'Los residentes añadidos se vinculan a viviendas y pueden iniciar sesión.';

  @override
  String get ortakDahaFazlaSecenek => 'Más opciones';

  @override
  String get modulDokumanlar => 'Documentos del recinto';

  @override
  String get dokumanBaslik => 'Documentos del recinto';

  @override
  String get dokumanAra => 'Buscar en nombres de documentos';

  @override
  String get dokumanYokSakin => 'Todavía no se ha compartido ningún documento.';

  @override
  String get dokumanAramaSonucYok =>
      'Ningún documento coincide con su búsqueda.';

  @override
  String get dokumanAcilamadi => 'No se pudo abrir el documento.';

  @override
  String dokumanBoyutKb(int kb) {
    return '$kb KB';
  }

  @override
  String get kvkkYasalMetinler => 'Textos legales';

  @override
  String get kvkkTurAydinlatma => 'Aviso de privacidad';

  @override
  String get kvkkTurAcikRiza => 'Consentimiento expreso';

  @override
  String get kvkkTurGizlilik => 'Política de privacidad';

  @override
  String get kvkkTurKullanim => 'Condiciones de uso';

  @override
  String get kvkkTurCerez => 'Política de cookies';

  @override
  String get kvkkMetinYayinlanmamis => 'Este texto aún no se ha publicado.';

  @override
  String get kvkkOnaylanmadi => 'Aún no ha aceptado este texto.';

  @override
  String get kvkkYenidenOnayBekleniyor =>
      'Se espera su consentimiento para la versión actual.';

  @override
  String kvkkSurumEtiketi(int n) {
    return 'Versión $n';
  }

  @override
  String kvkkOnayladiginizSurum(int n) {
    return 'Versión que aceptó: $n';
  }

  @override
  String get kabukKisayollar => 'Accesos directos';

  @override
  String get ayarlarBildirimlerBaslik => 'Notificaciones';

  @override
  String get ayarlarBildirimTercih => 'Preferencias de notificación';

  @override
  String get ayarlarBildirimAciklama =>
      'Elige por qué canales recibir notificaciones operativas. Es distinto del consentimiento de marketing.';

  @override
  String get ayarlarBildirimEposta => 'Notificaciones por correo';

  @override
  String get ayarlarBildirimSms => 'Notificaciones por SMS';

  @override
  String get ayarlarBildirimMobil => 'Notificaciones móviles';

  @override
  String get ayarlarBildirimKaydedildi =>
      'Preferencia de notificación actualizada';

  @override
  String get ayarlarBildirimYuklenemedi =>
      'No se pudieron cargar las preferencias de notificación';

  @override
  String get ayarlarBildirimIzinKapali =>
      'El permiso de notificaciones del dispositivo está desactivado. Las notificaciones móviles no aparecerán en el teléfono; actívalo en los ajustes del dispositivo.';

  @override
  String get ayarlarBildirimIzinBelirsiz =>
      'Se necesita permiso para mostrar notificaciones.';

  @override
  String get ayarlarBildirimIzinIste => 'Solicitar permiso';

  @override
  String get surumZorunluBaslik => 'Actualización necesaria';

  @override
  String get surumZorunluMetin =>
      'Esta versión ya no se puede usar. Actualice la aplicación para continuar.';

  @override
  String get surumOnerilenBaslik => 'Hay una versión nueva';

  @override
  String get surumOnerilenMetin =>
      'Actualice la aplicación para una mejor experiencia.';

  @override
  String get surumGuncelle => 'Actualizar';

  @override
  String get surumSimdiGuncelle => 'Actualizar ahora';

  @override
  String get surumSonra => 'Más tarde';

  @override
  String get surumMagazaAcilamadi =>
      'No se pudo abrir la tienda. Puede actualizar la aplicación manualmente desde la tienda de su teléfono.';

  @override
  String get tesisDegistirBaslik => 'Cambiar de comunidad';

  @override
  String get tesisDegistirSecili => 'Está aquí';

  @override
  String get ziyaretDaireAra => 'Vivienda';

  @override
  String get ziyaretDaireAraIpucu =>
      'Escriba el número de vivienda o el nombre de un residente';

  @override
  String get vardiyaPlaniBaslik => 'Plan de turnos';

  @override
  String get vardiyaSuAnGorevde => 'De servicio ahora';

  @override
  String get vardiyaSuAnKimseYok => 'Ahora mismo no hay nadie programado.';

  @override
  String get vardiyaSiradaki => 'Próximo turno';

  @override
  String get vardiyaSiradakiYok => 'No hay un próximo turno planificado.';

  @override
  String get vardiyaBos => 'Sin cubrir';

  @override
  String get vardiyaYeni => 'Nuevo turno';

  @override
  String get vardiyaKayitYok => 'No hay turnos planificados esta semana.';

  @override
  String get vardiyaPersonel => 'Personal';

  @override
  String get vardiyaBaslangicTarihi => 'Fecha de inicio';

  @override
  String get vardiyaBitisTarihi => 'Fecha de fin';

  @override
  String get vardiyaBaslangicSaati => 'Hora de inicio';

  @override
  String get vardiyaBitisSaati => 'Hora de fin';

  @override
  String get vardiyaNot => 'Nota';

  @override
  String get vardiyaEkleBilgi =>
      'Si indica un intervalo de fechas, se crea un turno para cada día. Si la hora de fin es anterior a la de inicio (22:00–05:00), el turno pasa al día siguiente.';

  @override
  String get vardiyaEkleGonder => 'Añadir turnos';

  @override
  String get vardiyaCakisanHaric => 'Añadir excluyendo los conflictos';

  @override
  String vardiyaCakisanGunler(int n) {
    return 'Hay conflictos en $n días';
  }

  @override
  String get finansTahsilatBaslik => 'Cobro';

  @override
  String get finansKisiGerekli => 'Seleccione una persona.';

  @override
  String get finansKasaGerekli => 'Seleccione una caja.';

  @override
  String get finansTutarGerekli => 'Introduzca un importe válido.';

  @override
  String get finansTahsilatKaydedildi => 'Cobro registrado.';

  @override
  String get finansBorcluYok => 'Ahora mismo no hay deudores.';

  @override
  String get finansAlanTutar => 'Importe';

  @override
  String get finansSutunKasa => 'Caja';

  @override
  String get finansAlanAciklama => 'Descripción';

  @override
  String get finansMakbuzNotu =>
      'El número de recibo y el aviso al residente se generan en el servidor, igual que en la web.';

  @override
  String finansGecikmeGun(int n) {
    return '$n días de retraso';
  }

  @override
  String get finansGiderBaslik => 'Registro de gasto';

  @override
  String get finansGiderKaydedildi => 'Gasto registrado.';

  @override
  String get finansGiderTuru => 'Tipo de gasto';

  @override
  String get finansOnayBekliyor => 'Enviar a aprobación';

  @override
  String get finansOnayBekliyorNotu =>
      'Un gasto pendiente de aprobación NO reduce el saldo; lo hace al aprobarse.';

  @override
  String get finansFisEkle => 'Añadir foto del recibo';

  @override
  String get finansFisEklendi => 'Recibo añadido';

  @override
  String get finansFisYuklenemedi =>
      'El gasto se registró pero no se pudo subir el recibo. Puede añadirlo desde la web.';

  @override
  String get finansBorclularBaslik => 'Deudores';

  @override
  String get finansTahsilatOrani => 'Tasa de cobro';

  @override
  String get finansOranYok => 'No hay cargos para este periodo.';

  @override
  String finansOranDegeri(int oran, String donem) {
    return '$oran % · $donem';
  }

  @override
  String finansKovaDaire(int n) {
    return '$n unidades';
  }

  @override
  String finansHatirlat(int n) {
    return 'Recordar a $n personas';
  }

  @override
  String finansHatirlatmaGonderildi(int n) {
    return '$n recordatorios enviados.';
  }

  @override
  String get personelEposta => 'Correo electrónico';

  @override
  String get personelEpostaYardim =>
      'La invitación y el enlace de contraseña se envían a esta dirección.';

  @override
  String get personelEpostaGerekli => 'El correo electrónico es obligatorio.';

  @override
  String get personelEpostaGecersiz =>
      'Escriba una dirección de correo válida.';

  @override
  String get sayacOkumaBaslik => 'Lectura de contador';

  @override
  String get sayacKalem => 'Concepto de cargo';

  @override
  String get sayacAnaSayac => 'Contador principal';

  @override
  String get sayacDonem => 'Periodo (AAAA-MM)';

  @override
  String get sayacAnaTuketim => 'Consumo del contador principal';

  @override
  String get sayacBirimFiyat => 'Precio unitario';

  @override
  String get sayacBorclandir => 'Generar cargos';

  @override
  String get sayacFotoEkle => 'Foto del contador';

  @override
  String get sayacBolumYok =>
      'No hay contadores de unidad vinculados a este contador principal.';

  @override
  String get sayacKalemGerekli =>
      'Seleccione un concepto y un contador principal.';

  @override
  String get sayacAnaTuketimGerekli =>
      'Introduzca el consumo del contador principal.';

  @override
  String get sayacBirimFiyatGerekli => 'Introduzca el precio unitario.';

  @override
  String get sayacDegerYok =>
      'Introduzca una lectura para al menos una unidad.';

  @override
  String sayacDegerGecersiz(String daire) {
    return 'El valor introducido para $daire no es válido.';
  }

  @override
  String sayacGeriSayiyor(String daire) {
    return '$daire: la nueva lectura no puede ser menor que la anterior.';
  }

  @override
  String sayacOncekiOkuma(String deger) {
    return 'Anterior: $deger';
  }

  @override
  String sayacBorclandirildi(int n) {
    return 'Cargos creados. Unidades omitidas: $n';
  }

  @override
  String get ayarlarBildirimSesi => 'Alertas con sonido';

  @override
  String get ayarlarBildirimSesiAciklama =>
      'Las notificaciones de quejas y turnos llegan con sonido.';

  @override
  String get ayarlarBildirimSesiUyari =>
      'Ha desactivado las alertas con sonido: puede que no oiga los recordatorios de turno ni los avisos de quejas.';

  @override
  String get vardiyaCikar => 'Quitar';

  @override
  String get vardiyaCikarSebep =>
      'Motivo de la retirada (enfermedad, permiso, emergencia)';
}
