// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get cipYeni => 'Новое';

  @override
  String get cipAktif => 'Активна';

  @override
  String get bolumVardiyaDurumu => 'Смены';

  @override
  String get bolumSonHareketler => 'Последние события';

  @override
  String get bolumHizliOzet => 'Сводка';

  @override
  String get bolumDuyurular => 'Объявления';

  @override
  String get bolumSiteKurallari => 'Правила комплекса';

  @override
  String get bolumEtkinlikler => 'Мероприятия';

  @override
  String get bolumOdemeAidat => 'Платежи и взносы';

  @override
  String get bolumTumModuller => 'Все разделы';

  @override
  String get kartVardiyaDurum => 'Смена';

  @override
  String get kartKargo => 'Посылки';

  @override
  String get kartZiyaretci => 'Посетители';

  @override
  String get kartAracPlaka => 'Автомобили';

  @override
  String get kartIhlaller => 'Нарушения';

  @override
  String get kartGorevlerim => 'Мои задачи';

  @override
  String get kartDemirbas => 'Инвентарь';

  @override
  String get kartTurlarim => 'Мои обходы';

  @override
  String get kartTalepAriza => 'Заявки';

  @override
  String get kartZiyaretciler => 'Посетители';

  @override
  String get kartKargolarim => 'Мои посылки';

  @override
  String get kartAidatBilgileri => 'Взносы';

  @override
  String get kartGurultuSikayeti => 'Жалоба на шум';

  @override
  String get kartGeriBildirim => 'Обращения';

  @override
  String get kartSikayetlerim => 'Мои жалобы';

  @override
  String get kartSiteRaporlari => 'Отчёты комплекса';

  @override
  String get kartGorevler => 'Задачи';

  @override
  String get kartAidatDurumu => 'Состояние взносов';

  @override
  String get kartOtoparkKullanimi => 'Парковка';

  @override
  String get kartSikayetler => 'Жалобы';

  @override
  String get kartRaporlar => 'Отчёты';

  @override
  String get kartYonetici => 'Управляющий';

  @override
  String get kartGonderimKuyrugu => 'Очередь отправки';

  @override
  String get etiketAylikOzet => 'Сводка за месяц';

  @override
  String get etiketDevriye => 'Обход';

  @override
  String get etiketKurallar => 'Правила';

  @override
  String get etiketIletisim => 'Контакты';

  @override
  String sayacAktif(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n активных',
      many: '$n активных',
      few: '$n активные',
      one: '$n активная',
    );
    return '$_temp0';
  }

  @override
  String sayacIceride(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n внутри',
      many: '$n внутри',
      few: '$n внутри',
      one: '$n внутри',
    );
    return '$_temp0';
  }

  @override
  String sayacGiris(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n въездов',
      many: '$n въездов',
      few: '$n въезда',
      one: '$n въезд',
    );
    return '$_temp0';
  }

  @override
  String sayacYeni(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n новых',
      many: '$n новых',
      few: '$n новых',
      one: '$n новая',
    );
    return '$_temp0';
  }

  @override
  String sayacAcik(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n открытых',
      many: '$n открытых',
      few: '$n открытые',
      one: '$n открытая',
    );
    return '$_temp0';
  }

  @override
  String sayacZimmetli(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n на руках',
      many: '$n на руках',
      few: '$n на руках',
      one: '$n на руках',
    );
    return '$_temp0';
  }

  @override
  String sayacKayit(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n записей',
      many: '$n записей',
      few: '$n записи',
      one: '$n запись',
    );
    return '$_temp0';
  }

  @override
  String sayacYaklasan(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n предстоящих',
      many: '$n предстоящих',
      few: '$n предстоящих',
      one: '$n предстоящее',
    );
    return '$_temp0';
  }

  @override
  String sayacDaire(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n квартир',
      many: '$n квартир',
      few: '$n квартиры',
      one: '$n квартира',
    );
    return '$_temp0';
  }

  @override
  String sayacArac(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n автомобилей',
      many: '$n автомобилей',
      few: '$n автомобиля',
      one: '$n автомобиль',
    );
    return '$_temp0';
  }

  @override
  String sayacGorevli(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n сотрудников',
      many: '$n сотрудников',
      few: '$n сотрудника',
      one: '$n сотрудник',
    );
    return '$_temp0';
  }

  @override
  String sayacBekleyen(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n в очереди',
      many: '$n в очереди',
      few: '$n в очереди',
      one: '$n в очереди',
    );
    return '$_temp0';
  }

  @override
  String get ozetToplamDaire => 'Всего квартир';

  @override
  String get ozetToplamTahsilat => 'Всего собрано';

  @override
  String get ozetTahsilatOrani => 'Собираемость взносов';

  @override
  String get ozetOtoparkDoluluk => 'Занятость парковки';

  @override
  String get ozetTumSite => 'Весь комплекс';

  @override
  String get ozetBuAy => 'Этот месяц';

  @override
  String get ozetSuAn => 'Сейчас';

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
    return 'Здравствуйте, $ad';
  }

  @override
  String get anaYoneticiPaneli => 'Панель управляющего';

  @override
  String anaDaireAltBaslik(Object daireler, Object rol) {
    return 'Квартира $daireler  •  $rol';
  }

  @override
  String get anaDun => 'Вчера';

  @override
  String get anaOnline => 'На связи';

  @override
  String get anaVardiyaAktif => 'Активна';

  @override
  String get anaVardiyaPlanlandi => 'Запланирована';

  @override
  String get anaEtkinlikSuruyor => 'Идёт';

  @override
  String get anaEtkinlikYaklasan => 'Предстоит';

  @override
  String get anaOdendi => 'Оплачено';

  @override
  String get anaOdenmedi => 'Не оплачено';

  @override
  String get anaBorcVar => 'Есть задолженность';

  @override
  String get anaBorcYok => 'Задолженности нет';

  @override
  String get anaBuAykiAidat => 'Взносы за месяц';

  @override
  String anaSonOdemeTarih(Object tarih) {
    return 'Последний платёж: $tarih';
  }

  @override
  String get anaGelecekOdeme => 'Следующий платёж';

  @override
  String get anaGecmisOdemeler => 'История платежей';

  @override
  String get anaAidatKaydiYok => 'Записей по взносам нет';

  @override
  String get anaBildirimlerYakinda => 'Уведомления скоро';

  @override
  String get anaBildirimlerRolYok => 'Уведомления недоступны для этой роли';

  @override
  String get anaRaporlarYakinda => 'Отчёты скоро';

  @override
  String get sekmeAnaSayfa => 'Главная';

  @override
  String get sekmeBildirimler => 'Уведомления';

  @override
  String get sekmeRaporlar => 'Отчёты';

  @override
  String get sekmeAyarlar => 'Настройки';

  @override
  String get kabukProfil => 'Профиль';

  @override
  String get kabukCikisYap => 'Выйти';

  @override
  String get fabOlayBildir => 'Сообщить о событии';

  @override
  String get fabTalepBildir => 'Заявка / сообщение';

  @override
  String get fabTalepArizaBildir => 'Заявка или неисправность';

  @override
  String get fabRezervasyonYap => 'Забронировать';

  @override
  String get fabDuyuruYayinla => 'Опубликовать объявление';

  @override
  String get fabGorevOlustur => 'Создать задачу';

  @override
  String get fabDestekTalebi => 'Обращение в поддержку';

  @override
  String get modulDuyurular => 'Объявления';

  @override
  String get modulTurlarim => 'Мои обходы';

  @override
  String get modulDevriyeTakibi => 'Контроль обходов';

  @override
  String get modulGorevlerim => 'Мои задачи';

  @override
  String get modulGorevYonetimi => 'Управление задачами';

  @override
  String get modulDemirbas => 'Инвентарь';

  @override
  String get modulNfcOkutma => 'Сканирование NFC';

  @override
  String get modulGonderimKuyrugu => 'Очередь отправки';

  @override
  String get modulAylikRaporlar => 'Ежемесячные отчёты';

  @override
  String get modulButce => 'Бюджет';

  @override
  String get modulFinansalOzet => 'Финансовая сводка';

  @override
  String get modulSeffaflik => 'Прозрачность';

  @override
  String get modulSiteButcesi => 'Бюджет комплекса';

  @override
  String get modulAidatim => 'Мои взносы';

  @override
  String get modulSikayetOneri => 'Жалоба / предложение';

  @override
  String get modulZiyaretciler => 'Посетители';

  @override
  String get modulKargo => 'Посылки';

  @override
  String get modulGoruntulemeIzni => 'Разрешение на просмотр';

  @override
  String get modulRezervasyon => 'Бронирование';

  @override
  String get modulEtkinlikler => 'Мероприятия';

  @override
  String get modulSiteKurallari => 'Правила комплекса';

  @override
  String get modulDisHizmetler => 'Внешние услуги';

  @override
  String get modulEntegrasyonlar => 'Интеграции';

  @override
  String get modulPersonel => 'Персонал';

  @override
  String get modulSakinler => 'Жители';

  @override
  String get modulBinaYapisi => 'Структура здания';

  @override
  String get modulSikayetHaritasi => 'Карта жалоб';

  @override
  String get modulSikayetlerim => 'Мои жалобы';

  @override
  String get modulYoneticiIletisim => 'Связь с управляющим';

  @override
  String get ortakKaydet => 'Сохранить';

  @override
  String sayacBekliyor(num n) {
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
  String ortakZorunluAlan(Object alan) {
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
  String kameraUrlHataHttp(Object tur) {
    return 'Адрес потока $tur должен начинаться с http:// или https://';
  }

  @override
  String get kameraUrlHataRtsp =>
      'Адрес потока RTSP должен начинаться с rtsp://';

  @override
  String get kameraSilBaslik => 'Удалить камеру';

  @override
  String kameraSilOnay(Object ad) {
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
  String kameraTurEtiket(Object tur) {
    return 'Тип: $tur';
  }

  @override
  String get kameraRtspBilgi =>
      'Потоки RTSP сейчас нельзя воспроизвести в приложении. Запись хранится в системе; поддержка появится позже.';

  @override
  String get kameraSeritBaslik => 'Камера в реальном времени';
}
