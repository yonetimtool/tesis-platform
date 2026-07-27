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
  String get sakinParolaSifirla => 'Restablecer contraseña';

  @override
  String get sakinParolaSifirlaOnay => '¿Restablecer la contraseña?';

  @override
  String sakinParolaSifirlaGovde(Object ad) {
    return 'Se genera un nuevo código temporal para \"$ad\"; la contraseña anterior deja de ser válida. La persona entra con teléfono + el nuevo código y luego define su contraseña.';
  }

  @override
  String get sakinSifirla => 'Restablecer';

  @override
  String sakinYeniKodMesaji(Object ad) {
    return 'Nuevo código temporal para \"$ad\". Entrégueselo al residente; entra con teléfono + este código y luego define su contraseña.';
  }

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
  String get ortakCepTelefonu => 'Móvil';

  @override
  String get ortakTelefonIpucu => 'ej. 0532 111 22 03';

  @override
  String get ortakTelefonZorunlu => 'El teléfono es obligatorio';

  @override
  String get sakinGirisAnahtari => 'Clave de acceso (única globalmente).';

  @override
  String get ortakDaireNoIpucu => 'ej. A-12';

  @override
  String get sakinDaireNoZorunlu => 'El número de unidad es obligatorio';

  @override
  String get sakinParolaOpsiyonel => 'Contraseña (opcional)';

  @override
  String get sakinBosBirakKod => 'Déjelo vacío para generar un código temporal';

  @override
  String get sakinEklendiKod =>
      'Residente añadido. Entréguele este código; entra con teléfono + este código y luego define su contraseña.';

  @override
  String get sakinEklendi => 'Residente añadido ✓';

  @override
  String get sakinYok =>
      'Aún no hay residentes.\nAñada uno desde abajo a la derecha.';

  @override
  String get ortakGeciciKodBaslik => 'Código de acceso temporal';

  @override
  String get ortakKopyala => 'Copiar';

  @override
  String get ortakKopyalandi => 'Copiado';
}
