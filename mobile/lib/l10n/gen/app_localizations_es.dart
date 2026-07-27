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
  String devriyeNoktaSayaci(Object beklenen, Object okutulan) {
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
  String sureSaatDakika(Object dakika, Object saat) {
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
  String devriyeNoktaOkutuldu(Object beklenen, Object okutulan) {
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
}
