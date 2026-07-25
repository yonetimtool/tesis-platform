// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get ortakKaydet => 'Сохранить';

  @override
  String sayacBekliyor(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ожидают',
      many: '$n ожидают',
      few: '$n ожидают',
      one: '$n ожидает',
    );
    return '$_temp0';
  }

  @override
  String get ortakKaydediliyor => 'Сохранение...';

  @override
  String get ortakVazgec => 'Отмена';

  @override
  String get ortakSil => 'Удалить';

  @override
  String get ortakDuzenle => 'Изменить';

  @override
  String get ortakEkle => 'Добавить';

  @override
  String get ortakTamam => 'ОК';

  @override
  String get ortakKapat => 'Закрыть';

  @override
  String get ortakTumunuGor => 'Показать все';

  @override
  String get ortakYuklenemedi => 'Не удалось загрузить';

  @override
  String get ortakYenidenDene => 'Повторить';

  @override
  String get ortakYakinda => 'Скоро';

  @override
  String get ortakBolumYakinda => 'Этот раздел скоро появится';

  @override
  String get ortakBeklenmeyenHata =>
      'Произошла непредвиденная ошибка. Попробуйте снова.';

  @override
  String ortakZorunluAlan(String alan) {
    return 'Заполните поле «$alan»';
  }

  @override
  String get ayarlarBaslik => 'Настройки';

  @override
  String get ayarlarTesis => 'Объект';

  @override
  String get ayarlarYonetim => 'Управление';

  @override
  String get ayarlarGorunum => 'Оформление';

  @override
  String get ayarlarTema => 'Тема';

  @override
  String get ayarlarTemaSistem => 'Системная';

  @override
  String get ayarlarTemaAcik => 'Светлая';

  @override
  String get ayarlarTemaKoyu => 'Тёмная';

  @override
  String get ayarlarTemaAciklama =>
      'Тёмная тема применяется ко всем экранам; «Системная» следует настройке устройства.';

  @override
  String get ayarlarTesisAdi => 'Название объекта';

  @override
  String get ayarlarTesisAdiAciklama =>
      'Название, отображаемое на главном экране и в отчётах.';

  @override
  String get ayarlarTesisAdiGuncellendi => 'Название объекта обновлено';

  @override
  String get ayarlarKameralar => 'Камеры';

  @override
  String get ayarlarKameralarAlt => 'Добавление, изменение и удаление камер';

  @override
  String get ayarlarDil => 'Язык / Language';

  @override
  String get dilSecBaslik => 'Язык приложения';

  @override
  String get kameraBaslik => 'Камеры';

  @override
  String get kameraEkle => 'Добавить камеру';

  @override
  String get kameraYeni => 'Новая камера';

  @override
  String get kameraDuzenleBaslik => 'Изменение камеры';

  @override
  String get kameraAd => 'Название';

  @override
  String get kameraKonum => 'Расположение (необязательно)';

  @override
  String get kameraTur => 'Тип';

  @override
  String get kameraUrl => 'URL потока';

  @override
  String get kameraAktif => 'Активна';

  @override
  String get kameraAktifAlt =>
      'Если выключено, не отображается ни в одном списке';

  @override
  String get kameraSakinGorebilir => 'Доступна жителям';

  @override
  String get kameraSakinGorebilirAlt =>
      'Если выключено, камеру видят только управление и охрана';

  @override
  String get kameraRtspFormUyari =>
      'Потоки RTSP пока нельзя воспроизвести в приложении. Запись сохраняется; поддержка появится позже.';

  @override
  String get kameraUrlZorunlu => 'Укажите адрес потока';

  @override
  String kameraUrlHataHttp(String tur) {
    return 'Адрес потока $tur должен начинаться с http:// или https://';
  }

  @override
  String get kameraUrlHataRtsp =>
      'Адрес потока RTSP должен начинаться с rtsp://';

  @override
  String get kameraSilBaslik => 'Удалить камеру';

  @override
  String kameraSilOnay(String ad) {
    return 'Удалить «$ad»?';
  }

  @override
  String get kameraBosYonetim =>
      'Камер пока нет. Добавьте камеру кнопкой снизу.';

  @override
  String get kameraBosSakin => 'Вам не открыта ни одна камера.';

  @override
  String get kameraListeHata => 'Не удалось загрузить камеры.';

  @override
  String get kameraCanli => 'В эфире';

  @override
  String get kameraOynatilamiyor => 'Воспроизведение недоступно';

  @override
  String get kameraYayinAcilamadi => 'Не удалось открыть поток';

  @override
  String get kameraYayinAcilamadiAlt =>
      'Камера может быть выключена, или сеть не может получить поток.';

  @override
  String kameraTurEtiket(String tur) {
    return 'Тип: $tur';
  }

  @override
  String get kameraRtspBilgi =>
      'Потоки RTSP сейчас нельзя воспроизвести в приложении. Запись хранится в системе; поддержка появится позже.';

  @override
  String get kameraSeritBaslik => 'Камера в реальном времени';
}
