// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get ortakKaydet => 'Guardar';

  @override
  String sayacBekliyor(int n) {
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
  String ortakZorunluAlan(String alan) {
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
  String kameraUrlHataHttp(String tur) {
    return 'La dirección de emisión $tur debe empezar por http:// o https://';
  }

  @override
  String get kameraUrlHataRtsp => 'La dirección RTSP debe empezar por rtsp://';

  @override
  String get kameraSilBaslik => 'Eliminar cámara';

  @override
  String kameraSilOnay(String ad) {
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
  String kameraTurEtiket(String tur) {
    return 'Tipo: $tur';
  }

  @override
  String get kameraRtspBilgi =>
      'Las emisiones RTSP no se pueden reproducir ahora en la aplicación. El registro se conserva en el sistema; la reproducción se añadirá más adelante.';

  @override
  String get kameraSeritBaslik => 'Cámara en directo';
}
