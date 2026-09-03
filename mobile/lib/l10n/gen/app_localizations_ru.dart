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
  String get sekmeSeffaflik => 'Прозрачность';

  @override
  String get sekmeGorevlerim => 'Мои задачи';

  @override
  String get sekmeAyarlar => 'Настройки';

  @override
  String get kabukGrupGuvenlik => 'Безопасность';

  @override
  String get kabukGrupTesis => 'Объект';

  @override
  String get kabukGrupFinans => 'Финансы';

  @override
  String get kabukGrupIletisim => 'Коммуникация';

  @override
  String get kabukGrupTanimlar => 'Справочники';

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
  String get kameraKareYok => 'Изображение недоступно';

  @override
  String get kameraBaglantiYok => 'Нет соединения';

  @override
  String get kameraUrlWebSayfasi =>
      'Это адрес веб-страницы. Приложение воспроизводит только прямые адреса потока: .m3u8 (HLS) или .mp4.';

  @override
  String get kameraKaynakYardim =>
      'Воспроизводятся только прямые медиа-адреса: HLS (.m3u8) и MP4. Веб-страницы (YouTube, Vimeo, муниципальные страницы просмотра) воспроизвести нельзя. RTSP сохраняется, но для воспроизведения нужен HLS-шлюз.';

  @override
  String get kameraSnapshot => 'Адрес снимка';

  @override
  String get kameraSnapshotAlt =>
      'Необязательно. Если задано, в списке камер показывается живой стоп-кадр (один JPEG).';

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

  @override
  String anaKarsilama(String ad) {
    return 'Здравствуйте, $ad';
  }

  @override
  String get gorevKategorilerTooltip => 'Категории';

  @override
  String get gorevYeni => 'Новая задача';

  @override
  String get gorevOlusturuldu => 'Задача создана ✓';

  @override
  String get gorevListesiYetkiYok =>
      'У вас нет прав на просмотр списка задач. Этот экран доступен ролям уборки и охраны.';

  @override
  String get gorevBuFiltredeYok => 'С этим фильтром активных задач нет.';

  @override
  String get gorevCipBanaAtanan => 'Назначено мне';

  @override
  String get gorevCipTumGorevler => 'Все задачи';

  @override
  String get gorevCipTumu => 'Все';

  @override
  String get gorevKategoriDiger => 'Другое';

  @override
  String gorevPlanlanan(Object zaman) {
    return 'Запланировано: $zaman';
  }

  @override
  String get gorevSanaAtanmis => 'Назначено вам';

  @override
  String get gorevFotoZorunlu => 'Требуется фото';

  @override
  String get gorevTamamlandiZatenKayitli => 'Выполнено ✓ (уже было записано)';

  @override
  String get gorevTamamlandiBuOturumda => 'Выполнено ✓ (в этом сеансе)';

  @override
  String get gorevIslemleriTooltip => 'Действия с задачей';

  @override
  String get gorevTakipGorunumu => 'Режим наблюдения';

  @override
  String get gorevTakipGorunumuAlt =>
      'Выполнение производится сотрудниками на месте (охрана / техник). Этот экран — для наблюдения.';

  @override
  String get gorevGonderiliyor => 'Отправка...';

  @override
  String get gorevTamamla => 'Завершить';

  @override
  String get gorevGuncellendi => 'Задача обновлена ✓';

  @override
  String get gorevSilinsinMi => 'Удалить задачу?';

  @override
  String get gorevSilindi => 'Задача удалена ✓';

  @override
  String get gorevNfcAciklama =>
      'Эта задача с NFC-подтверждением: перед завершением отсканируйте метку в точке задачи.';

  @override
  String get gorevAdim1Etiket => '1. Отсканируйте метку';

  @override
  String gorevOkundu(Object uid) {
    return 'Считано: $uid';
  }

  @override
  String get gorevEtiketBekleniyor => 'Ожидание метки...';

  @override
  String get gorevYenidenOkut => 'Считать снова';

  @override
  String get gorevEtiketiOkut => 'Считать метку';

  @override
  String get gorevAdim2Foto => '2. Фотоподтверждение';

  @override
  String get gorevAdim2FotoOpsiyonel => '2. Фотоподтверждение (необязательно)';

  @override
  String get gorevYukleniyorNokta => 'Загрузка...';

  @override
  String get gorevYuklendi => 'Загружено ✓';

  @override
  String get gorevKamera => 'Камера';

  @override
  String get gorevYenidenCek => 'Снять заново';

  @override
  String get gorevGaleridenSec => 'Выбрать из галереи';

  @override
  String get gorevTekrarYukle => 'Загрузить снова';

  @override
  String get gorevKaldir => 'Удалить';

  @override
  String get gorevAdim3Not => '3. Примечание (необязательно)';

  @override
  String get gorevNotIpucu => 'Напр. мусорные контейнеры опорожнены';

  @override
  String get gorevZatenKayitliydi =>
      'Это выполнение уже было записано (повторная отправка — дубликат не создан).';

  @override
  String get gorevTamamlandiKayit => 'Задача выполнена — запись создана.';

  @override
  String gorevZaman(Object zaman) {
    return 'Время: $zaman';
  }

  @override
  String get gorevFotoKanitiVar => 'есть фотоподтверждение';

  @override
  String get gorevNfcDogrulandi => 'NFC подтверждён';

  @override
  String get gorevYeniTamamlamaBaslat => 'Начать новое выполнение';

  @override
  String get gorevDuzenleBaslik => 'Изменить задачу';

  @override
  String get gorevKategoriSilinmis => 'Категория (удалена)';

  @override
  String get gorevAtananListedeDegil => 'Исполнитель (нет в списке)';

  @override
  String get gorevTipleriYukleniyor => 'Загрузка типов задач...';

  @override
  String get gorevTipi => 'Тип задачи';

  @override
  String get gorevTipiYokUyari =>
      'Вы ещё не задали типы задач. Свои типы можно добавить на экране «Категории» выше; пока используется «Другое».';

  @override
  String get gorevAdi => 'Название задачи';

  @override
  String get gorevAdiZorunlu => 'Название задачи обязательно';

  @override
  String get gorevAciklamaOpsiyonel => 'Описание (необязательно)';

  @override
  String get gorevPersonelYukleniyor => 'Загрузка списка сотрудников...';

  @override
  String get gorevAtananPersonel => 'Назначенный сотрудник';

  @override
  String get gorevAtanmamisHavuz => '— не назначено (общая задача) —';

  @override
  String gorevPersonelAlinamadi(Object hata) {
    return 'Не удалось получить список сотрудников: $hata';
  }

  @override
  String get gorevKontrolNoktasiOpsiyonel =>
      'Контрольная точка (NFC) — необязательно';

  @override
  String get gorevKontrolNoktasiYardim =>
      'Если привязано, задача завершается сканированием NFC';

  @override
  String get gorevNfcYok => '— без NFC —';

  @override
  String get gorevPeriyotDakika => 'Период в минутах (необязательно)';

  @override
  String get gorevPeriyotYardim =>
      'Для повторяющихся задач; пусто = однократно';

  @override
  String get gorevPozitifSayi => 'Введите положительное целое число';

  @override
  String get gorevFotoKanitiZorunlu => 'Требуется фотоподтверждение';

  @override
  String get gorevFotoKanitiZorunluAlt => 'Выполнение без фото не принимается';

  @override
  String get gorevPasifAciklama => 'Неактивная задача не отображается в списке';

  @override
  String get gorevKategorileriBaslik => 'Категории задач';

  @override
  String get gorevKategoriYeni => 'Новая категория';

  @override
  String get gorevKategoriAdi => 'Название категории';

  @override
  String get gorevKategoriAdiIpucu => 'напр. Обслуживание бассейна';

  @override
  String gorevKategoriEklendi(Object ad) {
    return '«$ad» добавлена';
  }

  @override
  String gorevKategoriEklenemedi(Object hata) {
    return 'Не удалось добавить: $hata';
  }

  @override
  String get gorevKategoriSilinsinMi => 'Удалить категорию?';

  @override
  String gorevKategoriSilOnay(Object ad) {
    return '«$ad» будет деактивирована; история существующих задач сохраняется, но выбрать её для новых задач нельзя.';
  }

  @override
  String gorevKategoriSilindi(Object ad) {
    return '«$ad» удалена';
  }

  @override
  String gorevKategoriSilinemedi(Object hata) {
    return 'Не удалось удалить: $hata';
  }

  @override
  String gorevKategoriListeAlinamadi(Object hata) {
    return 'Не удалось получить список: $hata';
  }

  @override
  String get gorevKategoriYokBos =>
      'Категорий пока нет. Добавьте её через «Новая категория», чтобы её можно было выбрать при создании задачи.';

  @override
  String get gorevOncelikDusuk => 'Низкий';

  @override
  String get gorevOncelikOrta => 'Средний';

  @override
  String get gorevOncelikYuksek => 'Высокий';

  @override
  String get gorevOncelik => 'Приоритет';

  @override
  String get gorevTaleptenGeldi => 'Из заявки';

  @override
  String get gorevBagliTalep => 'Связанная заявка';

  @override
  String gorevDaireEtiket(Object daire) {
    return 'Квартира $daire';
  }

  @override
  String get talepDurumAcik => 'Открыт';

  @override
  String get talepDurumIsEmri => 'Наряд';

  @override
  String get talepDurumCozuldu => 'Решён';

  @override
  String get talepDurumReddedildi => 'Отклонён';

  @override
  String get gorevEtiketOkunamadi => 'Не удалось считать метку.';

  @override
  String get gorevFotoOnlineGerekli =>
      'Для загрузки фото нужно интернет-соединение (адрес загрузки кратковременный). При появлении связи нажмите «Загрузить снова».';

  @override
  String gorevFotoAlinamadi(Object hata) {
    return 'Не удалось получить фото: $hata';
  }

  @override
  String get gorevFotoOnlineGerekliKisa =>
      'Для загрузки фото нужно интернет-соединение.';

  @override
  String get gorevFotoZorunluUyari =>
      'Для этой задачи ОБЯЗАТЕЛЬНО фотоподтверждение. Сделайте и загрузите фото перед завершением.';

  @override
  String get gorevFotoHenuzYuklenmedi =>
      'Фото ещё не загружено. Дождитесь окончания загрузки, попробуйте «Загрузить снова» или удалите фото.';

  @override
  String get gorevTamamlamaOfflineUyari =>
      'Не удалось отправить выполнение — нужно интернет-соединение. При появлении связи снова нажмите «Завершить»; та же запись не продублируется (Idempotency-Key фиксирован). Выполнение с фото офлайн не поддерживается (известное ограничение).';

  @override
  String get rolAdmin => 'Администратор платформы';

  @override
  String get rolYonetici => 'Управляющий объектом';

  @override
  String get rolGuvenlik => 'Охрана';

  @override
  String get rolTesisGorevlisi => 'Техник объекта';

  @override
  String get rolSakin => 'Житель';

  @override
  String get rolBilinmeyen => 'Неизвестная роль';

  @override
  String get ortakOlustur => 'Создать';

  @override
  String get ortakGuncelle => 'Обновить';

  @override
  String get ortakYenile => 'Обновить';

  @override
  String get devriyeGonderimKuyruguTooltip => 'Очередь отправки';

  @override
  String get sekmeGecmis => 'История';

  @override
  String get devriyeYetkiYok =>
      'У вас нет прав на данные этого экрана. Отслеживание обходов доступно роли охраны (и управляющего).';

  @override
  String devriyeSonGuncelleme(Object saat) {
    return 'Последнее обновление: $saat (автообновление: 60 с)';
  }

  @override
  String get devriyeTuru => 'Обход';

  @override
  String devriyeBitisEtiket(Object saat) {
    return 'конец $saat';
  }

  @override
  String devriyePencere(Object baslangic, Object bitis) {
    return 'Окно: $baslangic – $bitis';
  }

  @override
  String devriyeNoktaSayaci(Object okutulan, Object beklenen) {
    return '$okutulan/$beklenen точек';
  }

  @override
  String get devriyeTumNoktalarOkutuldu =>
      'Все точки отсканированы — обход завершается. ✓';

  @override
  String devriyeSunucudaOkutma(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          'На сервере записано $n сканирований (могут быть включены сканирования других устройств).',
      many:
          'На сервере записано $n сканирований (могут быть включены сканирования других устройств).',
      few:
          'На сервере записано $n сканирования (могут быть включены сканирования других устройств).',
      one:
          'На сервере записано $n сканирование (могут быть включены сканирования других устройств).',
    );
    return '$_temp0';
  }

  @override
  String get devriyeNoktaOkutNfc => 'Сканировать точку (NFC)';

  @override
  String get devriyeBugununDigerTurlari => 'Другие обходы сегодня';

  @override
  String get devriyeBugununTurlari => 'Обходы сегодня';

  @override
  String get devriyeDurumTamamlandi => 'Выполнен';

  @override
  String get devriyeDurumKacirildi => 'Пропущен';

  @override
  String get devriyeDurumSimdiAktif => 'Активен сейчас';

  @override
  String get devriyeDurumYaklasan => 'Предстоящий';

  @override
  String get devriyeDurumBitti => 'Завершён';

  @override
  String get devriyeDurumBekliyor => 'Ожидает';

  @override
  String get devriyeDurumBilinmiyor => 'Неизвестно';

  @override
  String get devriyeDurumSuresiGecti => 'Время истекло';

  @override
  String get devriyeBugunTurYok => 'На сегодня обходов нет.';

  @override
  String get devriyeNoktaListesiYok =>
      'Не удалось получить список точек этого плана либо точки не назначены.';

  @override
  String get devriyeKontrolNoktalari => 'Контрольные точки';

  @override
  String get devriyeNoktaDurumAciklama =>
      'Статусы точек приходят с сервера; сканирования всех сотрудников отображаются как ✓. Строки «Отправляется» — сканирования этого устройства, ещё не отправленные.';

  @override
  String devriyeNoktaAdiYedek(Object kisaId) {
    return 'Точка $kisaId';
  }

  @override
  String get devriyeOkutuldu => 'Отсканировано ✓';

  @override
  String devriyeOkutulduZamanli(Object saat) {
    return 'Отсканировано ✓ · $saat';
  }

  @override
  String get devriyeOkutulduGonderiliyor =>
      'Отсканировано ✓ — отправляется (в очереди)';

  @override
  String get devriyePencereSuresiDoldu => 'Время окна истекло.';

  @override
  String devriyeKalanSure(Object sure) {
    return 'Осталось: $sure';
  }

  @override
  String sureSaatDakika(Object saat, Object dakika) {
    return '$saat ч $dakika мин';
  }

  @override
  String sureDakikaSaniye(Object dakika, Object saniye) {
    return '$dakika мин $saniye с';
  }

  @override
  String sureSaniye(Object saniye) {
    return '$saniye с';
  }

  @override
  String get devriyeGecmisYetkiYok =>
      'У вас нет прав на историю обходов. Этот список доступен ролям охраны и управляющего.';

  @override
  String get devriyeGecmisBos => 'Записей окон обходов пока нет.';

  @override
  String get devriyeOzetToplam => 'Всего';

  @override
  String get devriyePlanlariBaslik => 'Планы обходов';

  @override
  String get devriyePlanEkle => 'Добавить план';

  @override
  String get devriyePlanlarListelenemedi =>
      'Не удалось получить список планов.';

  @override
  String devriyePlanAralik(Object baslangic, Object bitis, Object dakika) {
    return '$baslangic–$bitis · каждые $dakika мин';
  }

  @override
  String get devriyePasif => 'Неактивен';

  @override
  String get devriyePlanSilinsinMi => 'Удалить план?';

  @override
  String devriyePlanSilOnay(Object ad) {
    return 'План обхода «$ad» будет удалён.';
  }

  @override
  String get devriyePlanSilindi => 'План удалён ✓';

  @override
  String get devriyePlanDuzenleBaslik => 'Изменить план обхода';

  @override
  String get devriyePlanYeniBaslik => 'Новый план обхода';

  @override
  String get devriyePlanAdi => 'Название плана';

  @override
  String get devriyePlanAdiIpucu => 'напр. Ночной обход';

  @override
  String get devriyeAdZorunlu => 'Название обязательно';

  @override
  String devriyeBaslangicSaat(Object saat) {
    return 'Начало $saat';
  }

  @override
  String devriyeBitisSaat(Object saat) {
    return 'Конец $saat';
  }

  @override
  String get devriyeTurSikligi => 'Частота обхода (минуты)';

  @override
  String get devriyeTurSikligiYardim => 'напр. 60 = один обход в час';

  @override
  String get devriyeTurSikligiPozitif =>
      'Частота обхода (мин) должна быть положительной.';

  @override
  String get devriyeTumunuKaldir => 'Снять все';

  @override
  String get devriyeTumunuSec => 'Выбрать все';

  @override
  String get devriyeAktifNoktaYok =>
      'Активных контрольных точек нет. Сначала добавьте их в «Контрольные точки».';

  @override
  String devriyeUidEtiket(Object uid) {
    return 'UID: $uid';
  }

  @override
  String get devriyeKaydedilemedi => 'Не удалось сохранить. Попробуйте снова.';

  @override
  String get devriyePlanYokBos =>
      'Планов обходов пока нет.\nДобавьте план справа снизу (часы + точки).';

  @override
  String get devriyeTakibiBaslik => 'Отслеживание обходов';

  @override
  String get sekmeBugun => 'Сегодня';

  @override
  String get sekmeTaramaGunlugu => 'Журнал сканирований';

  @override
  String get devriyeTakibiYetkiYok =>
      'У вас нет прав на отслеживание обходов. Этот экран доступен ролям управляющего и охраны.';

  @override
  String get devriyeBugunPencereYok =>
      'На сегодня окно обхода не запланировано.';

  @override
  String devriyeNoktaOkutuldu(Object okutulan, Object beklenen) {
    return 'Отсканировано точек: $okutulan/$beklenen';
  }

  @override
  String get devriyeTaramaGunluguAlinamadi =>
      'Не удалось получить журнал сканирований.';

  @override
  String get devriyeGunOkutmaYok => 'За этот день сканирований нет.';

  @override
  String get devriyeImzali => 'подписано ✓';

  @override
  String devriyeOkutmaBekliyor(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n сканирований ожидают отправки',
      many: '$n сканирований ожидают отправки',
      few: '$n сканирования ожидают отправки',
      one: '$n сканирование ожидает отправки',
    );
    return '$_temp0';
  }

  @override
  String get ortakIptal => 'Отмена';

  @override
  String get ortakNotOpsiyonel => 'Примечание (необязательно)';

  @override
  String get binaDuzenlemeBaslik => 'Планировка здания';

  @override
  String get binaBlokTile => 'Блок';

  @override
  String get binaBlokAtanmamis => 'Блок не назначен';

  @override
  String binaBlokEtiket(Object ad) {
    return 'Блок $ad';
  }

  @override
  String get binaSaltGoruntulemeAciklama =>
      'Структура здания (только просмотр). Нажмите на плитку блока, чтобы увидеть размещение этажей и квартир.';

  @override
  String get binaDuzenlemeAciklama =>
      'Добавьте блок, нажмите на плитку и разместите внутри этажи и квартиры. Каждая квартира принадлежит блоку. Карта жалоб отражает эту структуру.';

  @override
  String binaDaireSayisi(num n) {
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
  String get binaKayitsiz => 'не зарегистрировано';

  @override
  String get binaBloksuzDairelerSalt => 'Квартиры без блока (только просмотр).';

  @override
  String binaBlokYerlesimSalt(Object ad) {
    return 'Блок $ad — размещение этажей и квартир (только просмотр).';
  }

  @override
  String get binaBloksuzUyari =>
      'Эти квартиры не привязаны к блоку (старые записи). Они отображаются, их можно изменить или удалить; для новой квартиры выберите или создайте блок.';

  @override
  String binaBlokYerlesimYardim(Object ad) {
    return 'Блок $ad — добавьте этажи, затем добавляйте квартиры кнопкой \"+\" каждого этажа. Квартиры одного этажа выстраиваются в ряд.';
  }

  @override
  String get binaKatEkle => 'Добавить этаж';

  @override
  String get binaTopluDaireEkle => 'Массовое добавление квартир';

  @override
  String get binaBloktaDaireYok => 'В этом блоке пока нет квартир.';

  @override
  String get binaKatYokBos =>
      'Этажей пока нет. Начните с «Добавить этаж», затем добавляйте квартиры кнопкой «+» на этаже.';

  @override
  String get binaKatYok => 'Без этажа';

  @override
  String binaKatEtiket(Object kat) {
    return 'Этаж $kat';
  }

  @override
  String binaBlokDuzenleBaslik(Object ad) {
    return 'Блок $ad — изменить';
  }

  @override
  String get binaBloguSil => 'Удалить блок';

  @override
  String binaBloguSilAlt(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Удаляется вместе с $n квартирами (нужно подтверждение)',
      many: 'Удаляется вместе с $n квартирами (нужно подтверждение)',
      few: 'Удаляется вместе с $n квартирами (нужно подтверждение)',
      one: 'Удаляется вместе с $n квартирой (нужно подтверждение)',
    );
    return '$_temp0';
  }

  @override
  String binaBlokSilinsinMi(Object ad) {
    return 'Удалить блок $ad?';
  }

  @override
  String binaBlokVeDaireSilindi(Object ad, Object n) {
    return 'Блок $ad и квартиры ($n) удалены.';
  }

  @override
  String binaBlokSilindi(Object ad) {
    return 'Блок $ad удалён.';
  }

  @override
  String binaBlokSilinemedi(Object hata) {
    return 'Не удалось удалить блок: $hata';
  }

  @override
  String get binaBlokSilinemediGenel =>
      'Не удалось удалить блок. Попробуйте снова.';

  @override
  String binaKaliciSilmeUyari(Object n) {
    return 'Этот блок и $n квартир в нём будут УДАЛЕНЫ БЕЗВОЗВРАТНО вместе с записями взносов, посетителей, посылок, бронирований и жалоб. Отменить это нельзя.';
  }

  @override
  String get binaOnayIcinBlokAdi => 'Введите название блока для подтверждения';

  @override
  String binaSilNDaire(Object n) {
    return 'Удалить ($n кв.)';
  }

  @override
  String get binaBlokEtiketiGerekli => 'Требуется метка блока (напр. A, B1).';

  @override
  String get binaBlokEtiketiZatenVar => 'Такая метка блока уже существует.';

  @override
  String get binaBlokDuzenle => 'Изменить блок';

  @override
  String get binaYeniBlok => 'Новый блок';

  @override
  String get binaBlokEtiketi => 'Метка блока';

  @override
  String get binaBlokEtiketiYardim =>
      'Короткий буквенно-цифровой код (напр. A, B1) — без дефиса';

  @override
  String get binaDaireNoGerekli => 'Требуется номер квартиры (напр. A-12, 12).';

  @override
  String get binaKatSiraTamSayi => 'Этаж и позиция должны быть целыми числами.';

  @override
  String get binaDaireNoZatenVar => 'Такой номер квартиры уже существует.';

  @override
  String binaDaireDuzenleBaslik(Object no) {
    return 'Квартира $no — изменить';
  }

  @override
  String binaYeniDaire(Object blok) {
    return 'Новая квартира · $blok';
  }

  @override
  String get binaDaireNo => 'Номер квартиры';

  @override
  String get binaDaireNoYardim => 'Буквы/цифры + дефис (напр. A-12, B3, 12)';

  @override
  String get binaSira => 'Позиция';

  @override
  String get binaSiraYardim => 'Место на этаже';

  @override
  String binaEnFazla500(Object n) {
    return 'Не более 500 квартир (сейчас $n).';
  }

  @override
  String binaTopluOnizleme(
    Object bas,
    Object bitis,
    Object toplam,
    Object kat,
    Object adet,
  ) {
    return '$bas … $bitis  ($toplam кв., $kat этаж × $adet)';
  }

  @override
  String get binaTopluAlanlarGerekli =>
      'Требуются число этажей, квартир на этаж и начальный номер.';

  @override
  String get binaTekSeferde500 => 'Не более 500 квартир за один раз.';

  @override
  String binaAtlananEk(Object n) {
    return ' ($n уже были, пропущены)';
  }

  @override
  String binaDaireEklendi(Object n, Object ek) {
    return 'Добавлено квартир: $n ✓$ek';
  }

  @override
  String get binaEklenemedi => 'Не удалось добавить. Попробуйте снова.';

  @override
  String binaTopluBaslik(Object blok) {
    return 'Массовое добавление — Блок $blok';
  }

  @override
  String get binaTopluBaslikBloksuz => 'Массовое добавление — без блока';

  @override
  String get binaTopluAciklama =>
      'Номера идут последовательно от начального, заполняя этаж за этажом. Существующие пропускаются.';

  @override
  String get binaKatSayisi => 'Число этажей';

  @override
  String get binaKatBasinaDaire => 'Квартир на этаж';

  @override
  String get binaBaslangicNo => 'Начальный номер';

  @override
  String get binaBaslangicNoIpucu => 'напр. 101';

  @override
  String get binaDaireleriOlustur => 'Создать квартиры';

  @override
  String get binaSilinemedi => 'Не удалось удалить. Попробуйте снова.';

  @override
  String get binaKaydedilemedi => 'Не удалось сохранить. Попробуйте снова.';

  @override
  String get semaDaireYok => 'Квартир пока нет.';

  @override
  String get semaYogunluk => 'Плотность:';

  @override
  String get semaYerlesimAciklama =>
      'Планировка здания. Плотность жалоб видна только руководству.';

  @override
  String get semaYerlesimGirilmemis => 'Размещение на карте не задано';

  @override
  String semaDaireEtiket(Object no) {
    return 'Квартира $no';
  }

  @override
  String semaAcikSikayet(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n открытых жалоб',
      many: '$n открытых жалоб',
      few: '$n открытые жалобы',
      one: '$n открытая жалоба',
    );
    return '$_temp0';
  }

  @override
  String get semaBuDaireSikayetlerim => 'Ваши жалобы по этой квартире';

  @override
  String get semaYogunlukYonetim => 'Плотность жалоб видна только руководству.';

  @override
  String get semaBuDaireyiSikayetEt => 'Пожаловаться на эту квартиру';

  @override
  String get semaSikayetIletildi => 'Ваша жалоба отправлена.';

  @override
  String get semaSikayetlerYuklenemedi => 'Не удалось загрузить жалобы.';

  @override
  String get semaAcikSikayetYok => 'По этой квартире нет открытых жалоб.';

  @override
  String get semaSikayetlerimYuklenemedi => 'Не удалось загрузить ваши жалобы.';

  @override
  String get semaSikayetimYok => 'У вас нет жалоб на эту квартиру.';

  @override
  String get semaYonetimeIletildi => 'Отправлено руководству';

  @override
  String get semaKapatildi => 'Закрыто';

  @override
  String get semaHaftalikSinir =>
      'По этой теме для этой квартиры можно подать не более 1 жалобы в неделю.';

  @override
  String get semaKendiBlok =>
      'Жаловаться можно только на квартиры в своём блоке.';

  @override
  String get semaGonderilemedi => 'Не удалось отправить. Попробуйте снова.';

  @override
  String semaSikayetEtBaslik(Object no) {
    return 'Квартира $no — жалоба';
  }

  @override
  String get semaSikayetAnonimNot =>
      'Ваша жалоба поступает руководству; соседям она не показывается.';

  @override
  String get semaSikayetiGonder => 'Отправить жалобу';

  @override
  String get kategoriGurultu => 'Шум';

  @override
  String get kategoriKapiOnuAyakkabi => 'Перед дверью / обувь';

  @override
  String get kategoriZararVerme => 'Порча имущества';

  @override
  String talepSekmeAcik(Object n) {
    return 'Открытые ($n)';
  }

  @override
  String talepSekmeIsEmri(Object n) {
    return 'Наряды ($n)';
  }

  @override
  String talepSekmeCozulen(Object n) {
    return 'Решённые ($n)';
  }

  @override
  String talepSekmeReddedilen(Object n) {
    return 'Отклонённые ($n)';
  }

  @override
  String get talepYeni => 'Новая заявка';

  @override
  String get talepAcikYokSakin =>
      'У вас нет открытых заявок. Через «Новая заявка» можно сообщить о заявке или неисправности.';

  @override
  String get talepAcikYok => 'Открытых заявок нет.';

  @override
  String get talepIsEmriYok => 'Нет заявок, преобразованных в наряд.';

  @override
  String get talepCozulenYok => 'Решённых заявок пока нет.';

  @override
  String get talepReddedilenYok => 'Отклонённых заявок нет.';

  @override
  String get talepIletildi => 'Ваша заявка отправлена ✓';

  @override
  String get talepDurumGecmisi => 'История статусов';

  @override
  String get talepGorselYuklenemedi => 'Не удалось загрузить изображение';

  @override
  String get talepIsEmriAtandi => 'Назначен';

  @override
  String get talepIsEmriTamamlandi => 'Завершён';

  @override
  String get talepIsEmriDurumBilinmiyor => 'Статус неизвестен';

  @override
  String get talepIsEmri => 'Наряд';

  @override
  String get talepYeniBaslik => 'Новая заявка / неисправность';

  @override
  String get talepBaslikAlan => 'Заголовок';

  @override
  String get talepBaslikZorunlu => 'Заголовок обязателен';

  @override
  String get talepAciklamaAlan => 'Описание';

  @override
  String get talepAciklamaZorunlu => 'Описание обязательно';

  @override
  String get talepGonder => 'Отправить';

  @override
  String get talepKategoriOpsiyonel => 'Категория (необязательно)';

  @override
  String get talepKategoriYok =>
      'Категории не заданы; заявка будет открыта как «Другое».';

  @override
  String get talepGorseller => 'Изображения (необязательно, до 3)';

  @override
  String get talepYoneticiIslemleri => 'Действия управляющего';

  @override
  String get talepIsEmrineDonusturuldu => 'Заявка преобразована в наряд ✓';

  @override
  String get talepIsEmrineDonusturBuyuk => 'Преобразовать в наряд';

  @override
  String get talepCozuldu => 'Заявка решена ✓';

  @override
  String get talepCoz => 'Решить';

  @override
  String get talepReddedildiBildirim => 'Заявка отклонена ✓';

  @override
  String get talepReddet => 'Отклонить';

  @override
  String get talepReddediliyor => 'Отклонение...';

  @override
  String get talepPersonelAlinamadiKisa =>
      'Не удалось получить список сотрудников.';

  @override
  String get talepIsEmrineDonustur => 'Преобразовать в наряд';

  @override
  String get talepAtanabilirPersonelYok =>
      'Нет активных сотрудников для назначения. Чтобы преобразовать, сначала добавьте охрану или техника.';

  @override
  String get talepDonusturuluyor => 'Преобразование...';

  @override
  String get talepDonustur => 'Преобразовать';

  @override
  String get talepReddetBaslik => 'Отклонить заявку';

  @override
  String get talepRetSebebiNot =>
      'Причина отклонения видна заявителю в истории статусов.';

  @override
  String get talepRetSebebi => 'Причина отклонения';

  @override
  String get talepCozBaslik => 'Решить заявку';

  @override
  String get talepCozNot =>
      'Заявка помечается решённой сразу, без создания наряда.';

  @override
  String get talepCozumNotu => 'Примечание к решению (необязательно)';

  @override
  String get talepKategorilerYuklenemedi => 'Не удалось загрузить категории.';

  @override
  String get talepFotoYuklenemedi => 'Не удалось загрузить фото.';

  @override
  String get binaKat => 'Этаж';

  @override
  String get binaKatYardim => '0 = первый этаж';

  @override
  String get binaBloksuz => 'Без блока';

  @override
  String get talepAcanSakin => 'Житель';

  @override
  String rezSekmeRezervasyonlar(Object n) {
    return 'Брони ($n)';
  }

  @override
  String rezSekmeAlanlar(Object n) {
    return 'Зоны ($n)';
  }

  @override
  String get rezYokSakin =>
      'У вас нет брони. Выберите зону на вкладке «Зоны» и займите свободный слот.';

  @override
  String get rezYok => 'Брони нет.';

  @override
  String get rezYeniAlan => 'Новая зона';

  @override
  String get rezAlanEklendi => 'Общая зона добавлена ✓';

  @override
  String get rezAlanGuncellendi => 'Зона обновлена ✓';

  @override
  String get rezOrtakAlan => 'Общая зона';

  @override
  String rezSatirOzet(
    Object tarih,
    Object baslangic,
    Object bitis,
    Object kisi,
  ) {
    return '$tarih · $baslangic-$bitis · $kisi чел.';
  }

  @override
  String get rezIptalEdildi => 'Отменено';

  @override
  String get rezIptalEdilsinMi => 'Отменить бронь?';

  @override
  String get rezIptalUyari =>
      'Слот снова станет свободным; отменить это нельзя.';

  @override
  String get rezEvetIptalEt => 'Да, отменить';

  @override
  String get rezIptalEdildiBildirim => 'Бронь отменена';

  @override
  String get rezIptalGonderilemedi =>
      'Не удалось отправить отмену. Попробуйте снова.';

  @override
  String get rezIptalEt => 'Отменить';

  @override
  String rezDetayTarih(Object tarih, Object baslangic, Object bitis) {
    return 'Дата: $tarih · $baslangic-$bitis';
  }

  @override
  String rezDetayKisi(Object n) {
    return 'Количество человек: $n';
  }

  @override
  String rezDetayRezerve(Object zaman) {
    return 'Забронировано: $zaman';
  }

  @override
  String rezDetayNot(Object not) {
    return 'Примечание: $not';
  }

  @override
  String get rezAlanYokYonetim =>
      'Общих зон пока нет. Добавьте через «Новая зона».';

  @override
  String get rezAlanYokGoruntuleme => 'Нет общих зон для показа.';

  @override
  String get rezAlanYokSakin => 'Нет зон для бронирования.';

  @override
  String rezMusait(Object ozet) {
    return 'Доступно: $ozet';
  }

  @override
  String rezMusaitOzeti(Object acilis, Object kapanis, Object dakika) {
    return '$acilis–$kapanis · слот $dakika мин';
  }

  @override
  String get rezAcikDuzenle => 'Открыто · нажмите для изменения';

  @override
  String get rezKapaliDuzenle => 'Закрыто · нажмите для изменения';

  @override
  String rezMusaitSlotlariGor(Object ozet) {
    return 'Доступно: $ozet · нажмите, чтобы увидеть слоты';
  }

  @override
  String get rezPasifAlan => 'Неактивно (нельзя бронировать)';

  @override
  String get rezKapanisSonra =>
      'Время закрытия должно быть позже времени открытия.';

  @override
  String get rezAlanEklenemedi => 'Не удалось добавить зону. Попробуйте снова.';

  @override
  String get rezAlanDuzenle => 'Изменить зону';

  @override
  String get rezYeniOrtakAlan => 'Новая общая зона';

  @override
  String get rezAlanAdi => 'Название зоны * (напр. Бассейн)';

  @override
  String get rezAlanAdiGerekli => 'Название зоны обязательно';

  @override
  String get rezMusaitlikHerGun => 'Доступность (каждый день)';

  @override
  String rezAcilis(Object saat) {
    return 'Открытие: $saat';
  }

  @override
  String rezKapanis(Object saat) {
    return 'Закрытие: $saat';
  }

  @override
  String get rezSlotUzunlugu => 'Длительность слота';

  @override
  String rezSlotDakika(Object n) {
    return '$n минут';
  }

  @override
  String get rezAlaniEkle => 'Добавить зону';

  @override
  String get rezSlotlarYuklenemedi =>
      'Не удалось загрузить слоты. Попробуйте снова.';

  @override
  String get rezOnaylandi => 'Ваша бронь подтверждена ✓';

  @override
  String rezTarihEtiket(Object tarih) {
    return 'Дата: $tarih';
  }

  @override
  String get rezSlotKurali =>
      'Слот открывается только менее чем за 24 часа до начала; не более одной брони в день.';

  @override
  String get rezSlotYok => 'Для этой зоны слоты не заданы.';

  @override
  String get rezBenimAktif => 'Моя бронь (активна)';

  @override
  String get rezBenimGecti => 'Моя бронь (прошла)';

  @override
  String get rezDoluBaskasi => 'Занято (другим)';

  @override
  String get rezSizinGecti => 'Ваша бронь (прошла)';

  @override
  String rezKisiEki(Object n) {
    return ' · $n чел.';
  }

  @override
  String rezDoluDaire(Object daire, Object kisi) {
    return 'Занято · Кв. $daire$kisi';
  }

  @override
  String get rezBos => 'Свободно';

  @override
  String get rezDolu => 'Занято';

  @override
  String rezSlotAralik(Object baslangic, Object bitis) {
    return '$baslangic – $bitis';
  }

  @override
  String get rezSec => 'Выбрать';

  @override
  String get rezGonderilemedi => 'Не удалось отправить. Попробуйте снова.';

  @override
  String rezEtBaslik(Object ad) {
    return '$ad — забронировать';
  }

  @override
  String get rezKisiSayisiEtiket => 'Количество человек:';

  @override
  String get rezEt => 'Забронировать';

  @override
  String get rezDurumOnayli => 'Подтверждено';

  @override
  String get rezSebepDolu => 'занято';

  @override
  String get rezSebepGecti => 'прошло';

  @override
  String get rezSebepCokErken => 'откроется в течение 24 ч';

  @override
  String get rezSebepGunluk => 'дневной лимит исчерпан';

  @override
  String etkSekmeYaklasan(Object n) {
    return 'Предстоящие ($n)';
  }

  @override
  String etkSekmeGecmis(Object n) {
    return 'Прошедшие ($n)';
  }

  @override
  String get etkYeni => 'Новое событие';

  @override
  String get etkYaklasanYokYonetim =>
      'Предстоящих событий нет. Объявите через «Новое событие».';

  @override
  String get etkYaklasanYok => 'Предстоящих событий нет.';

  @override
  String get etkGecmisYok => 'Прошедших событий нет.';

  @override
  String get etkDuyuruldu =>
      'Событие объявлено — жителям отправлено уведомление ✓';

  @override
  String get etkGuncellendi => 'Событие обновлено ✓';

  @override
  String etkKatiliyorSayisi(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n придут',
      many: '$n придут',
      few: '$n придут',
      one: '$n придёт',
    );
    return '$_temp0';
  }

  @override
  String etkKatilmiyorSayisi(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n не придут',
      many: '$n не придут',
      few: '$n не придут',
      one: '$n не придёт',
    );
    return '$_temp0';
  }

  @override
  String etkKatiliminiz(Object durum) {
    return 'Ваш ответ: $durum';
  }

  @override
  String etkBeyanKaydedildi(Object durum) {
    return 'Ваш ответ сохранён: $durum ✓';
  }

  @override
  String get etkBeyanGonderilemedi =>
      'Не удалось отправить ответ. Попробуйте снова.';

  @override
  String get etkKatiliyorum => 'Приду';

  @override
  String get etkKatilmiyorum => 'Не приду';

  @override
  String etkZaman(Object aralik) {
    return 'Время: $aralik';
  }

  @override
  String etkYer(Object konum) {
    return 'Место: $konum';
  }

  @override
  String etkDuyuran(Object ad) {
    return 'Объявил: $ad';
  }

  @override
  String get etkSilinsinMi => 'Удалить событие?';

  @override
  String etkSilOnay(Object baslik) {
    return '«$baslik» и все ответы будут удалены.';
  }

  @override
  String get etkSilindi => 'Событие удалено ✓';

  @override
  String get etkBitisSonra => 'Окончание должно быть позже начала';

  @override
  String get etkKaydedilemedi => 'Не удалось сохранить. Попробуйте снова.';

  @override
  String get etkDuzenleBaslik => 'Изменить событие';

  @override
  String get etkBaslikAlan => 'Заголовок * (напр. Вечер просмотра матча)';

  @override
  String get etkBaslikGerekli => 'Заголовок обязателен';

  @override
  String get etkAciklamaAlan => 'Описание *';

  @override
  String get etkAciklamaGerekli => 'Описание обязательно';

  @override
  String etkZamanSecim(Object zaman) {
    return 'Время: $zaman';
  }

  @override
  String get etkBitisEkle => 'Добавить окончание (необязательно)';

  @override
  String etkBitis(Object zaman) {
    return 'Окончание: $zaman';
  }

  @override
  String get etkBitisiKaldir => 'Убрать окончание';

  @override
  String get etkYerAlan => 'Место (необязательно)';

  @override
  String get etkGorselAlan => 'Изображение (необязательно)';

  @override
  String get etkDuyurVeBildir => 'Объявить и уведомить жителей';

  @override
  String get izinBaslik => 'Разрешение на просмотр';

  @override
  String get izinTumDairelere => 'Запросить доступ ко всем квартирам';

  @override
  String get izinYeniIstek => 'Новый запрос';

  @override
  String get izinIstekYokYonetim =>
      'У вас пока нет запросов. Через «Новый запрос» — для одной квартиры, через «Все квартиры» выше — для всех.';

  @override
  String get izinIstekYokSakin => 'Для вашей квартиры запросов нет.';

  @override
  String get izinTumDaireUyari =>
      'Запрос на просмотр будет отправлен по каждой квартире с жителем. Каждая зависит от согласия своего жителя — вы увидите записи только одобривших квартир.';

  @override
  String izinAtlandiEki(Object n) {
    return ' ($n уже открыто)';
  }

  @override
  String izinTopluGonderildi(Object n, Object atlandi) {
    return 'Запросы отправлены по $n квартирам$atlandi — ожидаются согласия жителей';
  }

  @override
  String izinGonderilemedi(Object hata) {
    return 'Не удалось отправить: $hata';
  }

  @override
  String get izinIsteBaslik => 'Запросить разрешение на просмотр';

  @override
  String get izinDaireNo => 'Номер квартиры (напр. A-12)';

  @override
  String get izinIstekGonder => 'Отправить запрос';

  @override
  String get izinIstekGonderildi =>
      'Запрос отправлен — ожидается согласие жителя';

  @override
  String izinDaireIstegi(Object daire) {
    return 'Запрос на просмотр квартиры$daire';
  }

  @override
  String izinIsteyen(Object ad) {
    return 'Запросил: $ad';
  }

  @override
  String get izinKullanildiUyari =>
      'Разрешение использовано (однократное). Чтобы посмотреть снова, создайте новый запрос.';

  @override
  String izinGoruntulenebilirDaireler(Object n) {
    return 'Доступные квартиры ($n)';
  }

  @override
  String get izinKullanildi => 'Использовано';

  @override
  String get izinOnayli => 'Одобрено';

  @override
  String get izinVerildi => 'Разрешение выдано';

  @override
  String get izinOnayla => 'Одобрить';

  @override
  String get izinKargolar => 'Посылки';

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
      'Разрешение использовано или истекло (однократное). Создайте новый запрос, чтобы посмотреть снова.';

  @override
  String get izinTekSeferlikUyari =>
      'Просмотр по однократному разрешению — при обновлении доступ закроется.';

  @override
  String get izinKayitYok => 'По этой квартире записей нет.';

  @override
  String izinHedef(Object ad) {
    return 'Получатель: $ad';
  }

  @override
  String izinKaydeden(Object ad) {
    return 'Записал: $ad';
  }

  @override
  String izinDurumEtiket(Object durum) {
    return 'Статус: $durum';
  }

  @override
  String get izinDurumOnaylandi => 'Одобрено';

  @override
  String get kargoDurumTeslimAlindi => 'Получено';

  @override
  String get rezSizin => 'Ваша бронь';

  @override
  String get butBaslik => 'Бюджет';

  @override
  String get butSekmeOzet => 'Сводка';

  @override
  String get butSekmeHareketler => 'Операции';

  @override
  String get butSekmeKategoriler => 'Категории';

  @override
  String get butTumZamanlar => 'За всё время';

  @override
  String get butDonem => 'Период';

  @override
  String get butGelir => 'Доходы';

  @override
  String get butGider => 'Расходы';

  @override
  String get butKasa => 'Касса';

  @override
  String get butKategoriKirilimi => 'Разбивка по категориям';

  @override
  String get butYeniHareket => 'Новая операция';

  @override
  String get butHareketYok => 'Операций пока нет.';

  @override
  String get butKategori => 'Категория';

  @override
  String get butOtomatik => 'Автоматически';

  @override
  String get butKategoriSecin => 'Выберите категорию';

  @override
  String get butTutar => 'Сумма (TL)';

  @override
  String get butTutarIpucu => 'напр. 1.250,50';

  @override
  String get butTutarGecersiz => 'Введите корректную сумму (напр. 1.250,50)';

  @override
  String butTarih(Object tarih) {
    return 'Дата: $tarih';
  }

  @override
  String get butYeniKategori => 'Новая категория';

  @override
  String get butKategoriYok => 'Категорий пока нет.';

  @override
  String get butKategoriAdi => 'Название категории';

  @override
  String get butKategoriAdiIpucu => 'напр. Уход за садом';

  @override
  String get butAdZorunlu => 'Название обязательно';

  @override
  String butKategoriTip(Object ad, Object tip) {
    return '$ad ($tip)';
  }

  @override
  String get butPasifEki => ' · неактивна (новые записи закрыты)';

  @override
  String get butBeklenmeyenKisa =>
      'Произошла непредвиденная ошибка. Попробуйте снова.';

  @override
  String get butFinansalOzet => 'Финансовая сводка';

  @override
  String get butAidatTahsilati => 'Сбор взносов';

  @override
  String get butEnYuksekGiderler => 'Крупнейшие расходы';

  @override
  String butTahsilatYuzde(Object yuzde) {
    return 'Сбор $yuzde%';
  }

  @override
  String get butTahakkukYok => 'За этот период начислений нет.';

  @override
  String get butSiteBaslik => 'Бюджет объекта';

  @override
  String get butKategoriToplamlari => 'Итоги по категориям';

  @override
  String get butSeffaflikNotu =>
      'Этот экран показывает доходы и расходы управления объектом в виде сводки — для прозрачности. Данные по людям и квартирам не показываются; с вопросами обращайтесь к управлению.';

  @override
  String get demBaslik => 'Инвентарь';

  @override
  String get demEtiketOkut => 'Считать метку';

  @override
  String get demBaskaEtiketOkut => 'Считать другую метку';

  @override
  String demUzerimdekiler(Object ek) {
    return 'На мне$ek';
  }

  @override
  String get demNfcAciklama =>
      'Сканируйте NFC-метку на предмете при получении или возврате. Приложение опознает предмет и покажет, у кого он.';

  @override
  String get demTaniniyor => 'Опознание предмета...';

  @override
  String get demKimsedeDegil => 'Ни у кого — можно взять.';

  @override
  String demSende(Object sure) {
    return 'У ВАС — $sure.';
  }

  @override
  String demBaskasinda(Object ad, Object sure) {
    return 'У другого: $ad — $sure.';
  }

  @override
  String get demBaskasininUzerinde => 'Похоже, он у другого сотрудника.';

  @override
  String get demBakimda => 'На обслуживании — сейчас выдать нельзя.';

  @override
  String get demZorlaDevralmaYok =>
      'Принудительная передача невозможна — предмет должен вернуть текущий владелец.';

  @override
  String get demZimmetineAl => 'Взять на себя';

  @override
  String get demBirak => 'Вернуть';

  @override
  String get demBirakKisa => 'Вернуть';

  @override
  String get demSonHareketler => 'Последние операции';

  @override
  String demAldi(Object ad, Object zaman) {
    return '$ad взял — $zaman (всё ещё у него)';
  }

  @override
  String get demListeYetkiYok => 'У вас нет прав на список инвентаря.';

  @override
  String get demUzerindeYok => 'Сейчас за вами нет предметов.';

  @override
  String demAldin(Object zaman, Object sure) {
    return 'Взято: $zaman ($sure)';
  }

  @override
  String get demSureBelirsiz => 'уже некоторое время';

  @override
  String get demSureAzOnce => 'только что';

  @override
  String demSureDakika(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n минут',
      many: '$n минут',
      few: '$n минуты',
      one: '$n минуту',
    );
    return '$_temp0';
  }

  @override
  String demSureSaat(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n часов',
      many: '$n часов',
      few: '$n часа',
      one: '$n час',
    );
    return '$_temp0';
  }

  @override
  String demSureGun(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n дней',
      many: '$n дней',
      few: '$n дня',
      one: '$n день',
    );
    return '$_temp0';
  }

  @override
  String get demOfflineUyari =>
      'Требуется интернет-соединение. Владение предметом — запись в реальном времени; офлайн не обрабатывается (очередь была бы обманчивой).';

  @override
  String demEtiketEslesmiyor(Object uid) {
    return 'Эта метка ($uid) не соответствует зарегистрированному предмету. Метку нужно привязать к предмету в панели.';
  }

  @override
  String get demZatenZimmetinde =>
      'Уже был за вами ✓ (повторная отправка — без дубликата)';

  @override
  String get demZimmetineAlindi => 'Взято ✓';

  @override
  String get demBirakildi => 'Возвращено ✓ — запись закрыта.';

  @override
  String demIslemYapilamadi(Object hata) {
    return 'Не удалось выполнить: $hata Статус обновлён — посмотрите карточку снова.';
  }

  @override
  String demHataSatiri(Object ad, Object hata) {
    return '$ad: $hata';
  }

  @override
  String get karBaslik => 'Посылки';

  @override
  String karSekmeBekleyen(Object n) {
    return 'Ожидают ($n)';
  }

  @override
  String karSekmeTeslim(Object n) {
    return 'Полученные ($n)';
  }

  @override
  String get karYeni => 'Новая посылка';

  @override
  String get karBekleyenYokSakin => 'У вас нет посылок к получению.';

  @override
  String get karBekleyenYok => 'Посылок к получению нет.';

  @override
  String get karTeslimYok => 'Записей о полученных посылках пока нет.';

  @override
  String get karKaydedildi => 'Посылка записана — жители квартиры уведомлены ✓';

  @override
  String karDaireTarih(Object daire, Object zaman) {
    return 'Кв.: $daire · $zaman';
  }

  @override
  String karDaire(Object daire) {
    return 'Кв.: $daire';
  }

  @override
  String karKayit(Object zaman) {
    return 'Запись: $zaman';
  }

  @override
  String karNot(Object not) {
    return 'Примечание: $not';
  }

  @override
  String get karTeslimAlindiBildirim => 'Посылка получена ✓';

  @override
  String get karIsaretlenemedi => 'Не удалось отметить. Попробуйте снова.';

  @override
  String get karTeslimAldim => 'Я получил';

  @override
  String get karGonderilemedi =>
      'Не удалось отправить запись. Попробуйте снова.';

  @override
  String get karDaireNo => 'Номер квартиры * (напр. A-12)';

  @override
  String get karDaireNoGerekli => 'Номер квартиры обязателен';

  @override
  String get karFirma => 'Служба доставки *';

  @override
  String get karFirmaGerekli => 'Служба доставки обязательна';

  @override
  String get karPaketFotografi => 'Фото посылки (необязательно)';

  @override
  String get karKaydetVeBildir => 'Сохранить и уведомить жителей';

  @override
  String get ortakTekrarDene => 'Повторить';

  @override
  String get butTahakkuk => 'Начислено';

  @override
  String get butTahsilat => 'Собрано';

  @override
  String get butGeciken => 'Просрочено';

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
  String get kuralBaslik => 'Правила объекта';

  @override
  String get kuralYeni => 'Новое правило';

  @override
  String get kuralAramaIpucu => 'Поиск по заголовкам (напр. бассейн)';

  @override
  String get kuralEklendi => 'Правило добавлено ✓';

  @override
  String get kuralGuncellendi => 'Правило обновлено ✓';

  @override
  String get kuralAramaBos => 'Нет правил, подходящих под поиск.';

  @override
  String get kuralYokYonetim =>
      'Правил пока нет. Добавьте через \"Новое правило\".';

  @override
  String get kuralYokSakin => 'Правила пока не опубликованы.';

  @override
  String get kuralSilOnayBaslik => 'Удалить правило?';

  @override
  String kuralSilOnayGovde(Object baslik) {
    return '\"$baslik\" будет удалено безвозвратно.';
  }

  @override
  String get kuralSilindi => 'Правило удалено ✓';

  @override
  String get kuralDuzenleBaslik => 'Изменить правило';

  @override
  String get kuralBaslikAlan => 'Заголовок * (напр. Часы бассейна)';

  @override
  String get kuralBaslikGerekli => 'Заголовок обязателен';

  @override
  String get kuralMetni => 'Текст правила *';

  @override
  String get kuralMetniGerekli => 'Текст правила обязателен';

  @override
  String get kuralSira => 'Порядок (меньше — раньше)';

  @override
  String get kuralSiraGecersiz =>
      'Порядок должен быть 0 или положительным целым';

  @override
  String get kuralMevcutGorsel => 'Текущее изображение сохраняется';

  @override
  String get kuralEkleButon => 'Добавить правило';

  @override
  String get ortakFotoOnlineTekrarDene =>
      'Для загрузки фото нужно интернет-соединение. Повторите попытку, когда связь вернётся.';

  @override
  String get ortakFotoBekleyinVeyaKaldir =>
      'Фото ещё не загружено. Дождитесь окончания загрузки или удалите фото.';

  @override
  String get duyuruYeni => 'Новое объявление';

  @override
  String get duyuruYayinlandi => 'Объявление опубликовано ✓';

  @override
  String get duyuruGuncellendi => 'Объявление обновлено ✓';

  @override
  String get duyuruYok => 'Объявлений пока нет.';

  @override
  String get duyuruYonetim => 'Управление';

  @override
  String duyuruMeta(Object ad, Object zaman, Object duzenlendi) {
    return '$ad · $zaman$duzenlendi';
  }

  @override
  String get duyuruDuzenlendiEki => ' · изменено';

  @override
  String get duyuruSilOnay => 'Удалить объявление?';

  @override
  String get duyuruSilindi => 'Объявление удалено ✓';

  @override
  String get duyuruDuzenleBaslik => 'Изменить объявление';

  @override
  String get duyuruBaslikZorunlu => 'Заголовок обязателен';

  @override
  String get duyuruMetniAlan => 'Текст объявления';

  @override
  String get duyuruMetniZorunlu => 'Текст объявления обязателен';

  @override
  String get duyuruYayinla => 'Опубликовать';

  @override
  String get ortakIslemler => 'Действия';

  @override
  String get sakinBaslik => 'Жители объекта';

  @override
  String get sakinEkle => 'Добавить жителя';

  @override
  String get sakinListelenemedi => 'Не удалось загрузить список жителей.';

  @override
  String get sakinDaireYok => 'Квартира не назначена';

  @override
  String get sakinIslemleri => 'Действия с жителем';

  @override
  String get sakinSilOnay => 'Удалить жителя?';

  @override
  String sakinSilGovde(Object ad) {
    return '\"$ad\" будет удалён. Если истории нет — запись удаляется полностью, иначе становится неактивной. В любом случае номер телефона освобождается (его можно зарегистрировать снова).';
  }

  @override
  String sakinSilindi(Object ad) {
    return '\"$ad\" удалён (номер освобождён)';
  }

  @override
  String sakinPasiflestirildi(Object ad) {
    return '\"$ad\" деактивирован — есть история (номер освобождён)';
  }

  @override
  String get sakinDuzenleBaslik => 'Изменить жителя';

  @override
  String get sakinYeniTelefon => 'Новый мобильный номер';

  @override
  String get sakinBosBirakDegismez => 'Оставьте пустым — не изменится';

  @override
  String get sakinGuncellendi => 'Обновлено ✓';

  @override
  String get ortakAdSoyad => 'Имя и фамилия';

  @override
  String get telefonHataEksik =>
      'Номер неполный — введите 10 цифр (например, 0543 199 29 04).';

  @override
  String get telefonHataOnEk =>
      'Мобильный номер должен начинаться с 5 (например, 0543…). Стационарные не принимаются.';

  @override
  String get ortakCepTelefonu => 'Мобильный номер';

  @override
  String get ortakTelefonIpucu => 'напр. 0532 111 22 03';

  @override
  String get ortakTelefonZorunlu => 'Телефон обязателен';

  @override
  String get sakinGirisAnahtari => 'Только для связи (необязательно).';

  @override
  String get ortakDaireNoIpucu => 'напр. A-12';

  @override
  String get sakinDaireNoZorunlu => 'Номер квартиры обязателен';

  @override
  String get sakinEklendi => 'Житель добавлен ✓';

  @override
  String get sakinYok => 'Жителей пока нет.\nДобавьте кнопкой справа снизу.';

  @override
  String get girisParolaVeyaKod => 'Пароль или временный код';

  @override
  String get girisIlkKodIpucu =>
      'При первом входе введите временный код, полученный от управления.';

  @override
  String get girisKimlik => 'Эл. почта или номер телефона';

  @override
  String get girisKimlikOrnek => 'name@example.com или 5XX XXX XX XX';

  @override
  String get girisKimlikYardim =>
      'Войдите по адресу эл. почты или номеру телефона';

  @override
  String get girisKimlikGerekli => 'Введите адрес эл. почты или номер телефона';

  @override
  String get girisTesisSec => 'В какой объект вы хотите войти?';

  @override
  String get girisBeniHatirla => 'Запомнить меня';

  @override
  String get girisYap => 'Войти';

  @override
  String get girisOturumSonaErdi => 'Сеанс истёк. Пожалуйста, войдите снова.';

  @override
  String get parolaBelirleBaslik => 'Задайте пароль';

  @override
  String get parolaBelirleAciklama =>
      'Вы вошли впервые по временному коду. Чтобы продолжить, создайте постоянный пароль; в дальнейшем вы будете входить по номеру квартиры и этому паролю.';

  @override
  String get parolaBelirleButon => 'Задать пароль';

  @override
  String get parolaGiriseDon => 'Вернуться к входу';

  @override
  String get ortakParolaZorunlu => 'Пароль обязателен';

  @override
  String get ortakYeniParola => 'Новый пароль';

  @override
  String get ortakYeniParolaTekrar => 'Новый пароль (повторно)';

  @override
  String get ortakYeniParolaZorunlu => 'Новый пароль обязателен';

  @override
  String get ortakParolalarEslesmiyor => 'Пароли не совпадают';

  @override
  String get parolaKuraliKisa => 'Не менее 8 символов';

  @override
  String get parolaKuraliBuyukHarf =>
      'Должен содержать хотя бы одну заглавную букву';

  @override
  String get parolaKuraliRakam => 'Должен содержать хотя бы одну цифру';

  @override
  String get parolaKuraliSembol =>
      'Должен содержать хотя бы один символ (! ? @ # . -)';

  @override
  String get profilYuklenemedi => 'Не удалось загрузить профиль.';

  @override
  String get profilNumaraYok => 'Номер не указан';

  @override
  String get profilFotoBaslik => 'Фото профиля';

  @override
  String get profilFotoSec => 'Выбрать фото';

  @override
  String get profilFotoGuncellendi => 'Фото профиля обновлено ✓';

  @override
  String get profilFotoKaldirildi => 'Фото профиля удалено';

  @override
  String get ortakGaleri => 'Галерея';

  @override
  String get profilParolaDegistir => 'Смена пароля';

  @override
  String get profilMevcutParola => 'Текущий пароль';

  @override
  String get profilMevcutParolaZorunlu => 'Текущий пароль обязателен';

  @override
  String get profilParolaGuncelle => 'Обновить пароль';

  @override
  String get profilParolaGuncellendi => 'Пароль обновлён ✓';

  @override
  String get profilTelefon => 'Телефон';

  @override
  String get profilTelefonIpucu => 'напр. +905551112233';

  @override
  String get profilAranabilir => 'Доступен для звонка';

  @override
  String get profilAranabilirAlt =>
      'Уполномоченные роли (звонок по согласию) смогут увидеть ваш номер';

  @override
  String get profilIletisimKaydet => 'Сохранить контакт';

  @override
  String get profilIletisimGuncellendi => 'Контактные данные обновлены ✓';

  @override
  String get personelEkle => 'Добавить сотрудника';

  @override
  String get personelDuzenle => 'Изменить сотрудника';

  @override
  String get personelListelenemedi =>
      'Не удалось загрузить список сотрудников.';

  @override
  String get personelPasiflestir => 'Деактивировать';

  @override
  String get personelAktiflestir => 'Активировать';

  @override
  String get personelPasiflestirildi => 'Деактивирован ✓';

  @override
  String get personelAktiflestirildi => 'Активирован ✓';

  @override
  String get personelGuncellendi => 'Сотрудник обновлён ✓';

  @override
  String get personelEklendi => 'Сотрудник добавлен ✓';

  @override
  String get personelFoto => 'Фото';

  @override
  String get personelTelefonOpsiyonel => 'Мобильный номер (необязательно)';

  @override
  String get personelBosBirakDegismezNokta => 'Оставьте пустым — не изменится.';

  @override
  String get personelYok =>
      'Сотрудников пока нет.\nДобавьте кнопкой справа снизу.';

  @override
  String get disKisiEkle => 'Добавить контакт';

  @override
  String get disListeAlinamadi => 'Не удалось загрузить список.';

  @override
  String get disKayitYokYonetim =>
      'Записей пока нет. Добавьте мастера, которому доверяете, кнопкой справа снизу.';

  @override
  String get disKayitYok => 'Записей о внешних услугах пока нет.';

  @override
  String get disNotEkleyin =>
      'Добавьте примечание (изменять может только управление).';

  @override
  String get disNotuDuzenle => 'Изменить примечание';

  @override
  String get disBolumNotu => 'Примечание к разделу';

  @override
  String get disNotIpucu =>
      'напр. Мастера, которым мы доверяем годами; ради безопасности объекта не впускайте посторонних.';

  @override
  String get disNotGuncellendi => 'Примечание обновлено ✓';

  @override
  String get disAra => 'Позвонить';

  @override
  String get disSilOnay => 'Удалить запись?';

  @override
  String disSilGovde(Object ad) {
    return '\"$ad\" будет удалён.';
  }

  @override
  String get disSilindi => 'Удалено ✓';

  @override
  String get disYeniKisi => 'Новый внешний контакт';

  @override
  String get disKisiDuzenle => 'Изменить контакт';

  @override
  String get disTur => 'Вид услуги';

  @override
  String get disTurIpucu => 'напр. Слесарь, Электрика, Сантехника';

  @override
  String get disTurZorunlu => 'Вид услуги обязателен';

  @override
  String get disAd => 'Имя';

  @override
  String get disSoyad => 'Фамилия';

  @override
  String get disAdGerekli => 'Имя обязательно';

  @override
  String get disSoyadGerekli => 'Фамилия обязательна';

  @override
  String get nfcBaslik => 'Чтение NFC-метки';

  @override
  String get nfcHazir => 'Готово к чтению. Нажмите «Начать».';

  @override
  String get nfcYaklastirBekliyor =>
      'Поднесите метку к задней части телефона...';

  @override
  String get nfcOkundu => 'Метка прочитана.';

  @override
  String get nfcOkumayaBasla => 'Начать чтение';

  @override
  String get nfcTekrarOku => 'Прочитать снова';

  @override
  String nfcKuyrukBekleyen(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n сканирований ожидают отправки',
      many: '$n сканирований ожидают отправки',
      few: '$n сканирования ожидают отправки',
      one: '$n сканирование ожидает отправки',
    );
    return '$_temp0';
  }

  @override
  String get nfcKuyruk => 'Очередь отправки';

  @override
  String get nfcKaydedildiBekliyor =>
      'Сохранено ✓ — будет отправлено автоматически при появлении связи.';

  @override
  String get nfcKaydedildiGonderiliyor => 'Сохранено ✓ — отправка...';

  @override
  String get nfcGonderildiZatenVar =>
      'Отправлено ✓ — это сканирование уже было записано.';

  @override
  String get nfcGonderildi => 'Отправлено ✓ — сканирование записано.';

  @override
  String get nfcEslesmeYok =>
      'Эта метка не соответствует ни одной контрольной точке.';

  @override
  String get nfcSdmBaslik => 'SDM (сырой, не проверен)';

  @override
  String get nfcTipEtiket => 'Тип';

  @override
  String nfcNoktalarAlinamadi(Object hata) {
    return 'Не удалось загрузить точки: $hata';
  }

  @override
  String get nfcTestBaslik => 'ТЕСТ: какую точку сканируем?';

  @override
  String get nfcTestAlt => 'Имитирует сканирование без физической метки.';

  @override
  String get nfcAktifNoktaYok => 'Активных контрольных точек нет.';

  @override
  String get nfcAktifNoktaYokAlt =>
      'Сначала добавьте её в разделе «Контрольные точки».';

  @override
  String get nfcManuelOkut => 'Ручное сканирование (тест)';

  @override
  String get nfcTestGorunur => 'Виден только в тестовой сборке.';

  @override
  String nfcUidSatir(Object uid) {
    return 'UID: $uid';
  }

  @override
  String get nfcHataKapali =>
      'NFC отключён. Включите NFC в настройках устройства.';

  @override
  String get nfcHataDesteklenmiyor => 'Это устройство не поддерживает NFC.';

  @override
  String get nfcHataUidOkunamadi => 'Не удалось прочитать UID метки.';

  @override
  String nfcHataCozumlenemedi(Object detay) {
    return 'Не удалось разобрать метку: $detay';
  }

  @override
  String nfcHataOturum(Object detay) {
    return 'Не удалось начать NFC-сессию: $detay';
  }

  @override
  String nfcHataOkumaIptal(Object detay) {
    return 'Чтение отменено: $detay';
  }

  @override
  String nfcHataYapilandirma(Object detay) {
    return 'NFC недоступен в этой сборке: $detay. Требуется обновление приложения; повторная попытка не поможет.';
  }

  @override
  String get nfcHataBilinmeyen => 'Произошла неизвестная ошибка.';

  @override
  String get nfcIosYaklastir => 'Поднесите метку к задней части телефона.';

  @override
  String get nfcIosOkundu => 'Прочитано';

  @override
  String get nfcIosIptal => 'Отменено';

  @override
  String get nfcIosOkunamadi => 'Не удалось прочитать';

  @override
  String get seffafYuklenemedi => 'Не удалось загрузить. Попробуйте снова.';

  @override
  String get seffafAyYayinlandi => 'Месяц опубликован.';

  @override
  String get seffafYayinGeriAlindi => 'Публикация отозвана.';

  @override
  String get seffafVeriYokYonetim =>
      'Финансовых данных пока нет. Месяцы появятся здесь после ввода доходов/расходов или взносов.';

  @override
  String get seffafVeriYok => 'Управление ещё не опубликовало сводку.';

  @override
  String get seffafTaslakEki => ' • черновик';

  @override
  String get seffafYayinla => 'Опубликовать этот месяц';

  @override
  String get seffafYayindaAlt => 'Жители видят эту сводку.';

  @override
  String get seffafOnizlemeAlt => 'Видно только управлению (предпросмотр).';

  @override
  String get seffafOnizlemeUyari => 'Предпросмотр — ещё не опубликовано.';

  @override
  String seffafOzetBaslik(Object ay) {
    return '$ay — сводка';
  }

  @override
  String get seffafToplamGelir => 'Всего доходов';

  @override
  String get seffafToplamGider => 'Всего расходов';

  @override
  String get seffafNet => 'Итого';

  @override
  String seffafOncekiAyNet(Object tutar) {
    return 'Итого за прошлый месяц: $tutar';
  }

  @override
  String get seffafGiderDagilimi => 'Структура расходов';

  @override
  String get seffafGiderYok => 'В этом месяце расходов нет.';

  @override
  String get seffafAidatToplama => 'Сбор взносов';

  @override
  String get seffafTahakkukYok => 'За этот месяц начислений нет.';

  @override
  String seffafOdeyenDaire(Object odeyen, Object toplam) {
    return 'Оплатили квартир: $odeyen/$toplam';
  }

  @override
  String seffafTahsilatSatir(Object tahsilat, Object tahakkuk, Object yuzde) {
    return 'Собрано: $tahsilat / $tahakkuk  (сумма: $yuzde%)';
  }

  @override
  String seffafGecikmede(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n квартир просрочено',
      many: '$n квартир просрочено',
      few: '$n квартиры просрочены',
      one: '$n квартира просрочена',
    );
    return '$_temp0';
  }

  @override
  String ortakYuzde(Object yuzde) {
    return '$yuzde%';
  }

  @override
  String get entegYeni => 'Новая';

  @override
  String get entegYokMesaj =>
      'Интеграций нет. Добавьте внешнюю систему (громкая связь/умный дом/webhook) кнопкой «Новая».';

  @override
  String get entegSilOnay => 'Удалить?';

  @override
  String entegSilGovde(Object ad) {
    return 'Интеграция \"$ad\" будет удалена.';
  }

  @override
  String entegSilinemedi(Object hata) {
    return 'Не удалось удалить: $hata';
  }

  @override
  String get entegAktifKisa => 'активна';

  @override
  String get entegPasifKisa => 'неактивна';

  @override
  String entegKimlikSatir(Object tip, Object kilit) {
    return 'Аутентификация: $tip$kilit';
  }

  @override
  String get entegTest => 'Тест';

  @override
  String entegTestBasarili(Object durum) {
    return '✓ Успешно ($durum)';
  }

  @override
  String entegTestBasarisiz(Object hata, Object durum) {
    return '✗ $hata$durum';
  }

  @override
  String get entegBasarisiz => 'Ошибка';

  @override
  String get entegDuzenleBaslik => 'Изменить интеграцию';

  @override
  String get entegYeniBaslik => 'Новая интеграция';

  @override
  String get entegPreset => 'Готовый шаблон (preset)';

  @override
  String get entegKanalTipi => 'Тип канала';

  @override
  String get entegUrl => 'URL эндпоинта (http/https)';

  @override
  String get entegUrlHelper =>
      'Внутренние/частные адреса блокируются при вызове';

  @override
  String get entegUrlHata => 'Должен начинаться с http(s)';

  @override
  String get entegHttpMetodu => 'HTTP-метод';

  @override
  String get entegKimlikDogrulama => 'Аутентификация';

  @override
  String get entegSir => 'Секрет (bearer token / API key)';

  @override
  String get entegSirKayitli =>
      'Сохранён — введите новое значение, чтобы изменить';

  @override
  String get entegSirYazmaOzel =>
      'Только запись; сервер его никогда не возвращает';

  @override
  String get entegPayload => 'Шаблон payload';

  @override
  String entegPayloadHelper(Object sablonlar) {
    return 'Заменители $sablonlar';
  }

  @override
  String get entegTestMesaji => 'Тестовое сообщение';

  @override
  String get ortakAdGerekli => 'Название обязательно';

  @override
  String get ziyaretYeni => 'Новый посетитель';

  @override
  String get ziyaretKaydedildi => 'Посетитель записан — житель уведомлён ✓';

  @override
  String get ziyaretYokGuvenlik => 'Записей о посетителях пока нет.';

  @override
  String get ziyaretYokSakin => 'Вам не передавали записей о посетителях.';

  @override
  String ziyaretBildirilenSakin(Object ad) {
    return 'Уведомлённый житель: $ad';
  }

  @override
  String get ziyaretSakiniAra => 'Позвонить жителю';

  @override
  String get ziyaretGuvenligiAra => 'Позвонить охране';

  @override
  String get ziyaretBilgileriDuzenle => 'Изменить данные';

  @override
  String get ziyaretGuncellendi => 'Данные посетителя обновлены ✓';

  @override
  String get ziyaretOnceDaireNo => 'Сначала введите номер квартиры';

  @override
  String get ziyaretSakiniSecin => 'Выберите жителя для уведомления';

  @override
  String get ziyaretDuzenleBaslik => 'Изменить посетителя';

  @override
  String get ziyaretDuzenleAlt =>
      'Можно изменить имя, квартиру, уведомлённого жителя и примечание.';

  @override
  String get ziyaretYeniAlt =>
      'Жителю уходит только уведомление (согласие не запрашивается).';

  @override
  String get ziyaretAdAlan => 'Имя посетителя *';

  @override
  String get ziyaretAdGerekli => 'Имя посетителя обязательно';

  @override
  String get ziyaretSakinleriGetir => 'Загрузить жителей';

  @override
  String get ziyaretBildirilecekSakin => 'Кого уведомить *';

  @override
  String get ziyaretKaydetVeBildir => 'Сохранить и уведомить жителя';

  @override
  String get raporBaslik => 'Месячные отчёты';

  @override
  String get raporOncekiAy => 'Предыдущий месяц';

  @override
  String get raporSonrakiAy => 'Следующий месяц';

  @override
  String raporAyBaslik(Object ay, Object yil) {
    return '$ay $yil';
  }

  @override
  String get raporYetkiYok =>
      'У вас нет прав на месячные отчёты. Этот экран доступен управляющему объектом.';

  @override
  String get raporGorevTamamlama => 'Выполнение задач';

  @override
  String get raporAidat => 'Взносы';

  @override
  String get raporSonTamamlamalar => 'Последние выполнения (первые 10)';

  @override
  String get raporPlanlananPencere => 'Запланированные окна';

  @override
  String raporTamamlanmaYuzde(Object yuzde) {
    return 'Выполнение $yuzde%';
  }

  @override
  String get raporPencereYok => 'В этом месяце обходы не планировались.';

  @override
  String get raporGorevYok => 'В этом месяце задачи не выполнялись.';

  @override
  String get raporToplamTamamlama => 'Всего выполнено';

  @override
  String get raporAidatKayitYok => 'За этот период нет начислений и платежей.';

  @override
  String raporTahakkukDaire(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Начислено ($n квартир)',
      many: 'Начислено ($n квартир)',
      few: 'Начислено ($n квартиры)',
      one: 'Начислено ($n квартира)',
    );
    return '$_temp0';
  }

  @override
  String raporTahsilatOdeme(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Собрано ($n платежей)',
      many: 'Собрано ($n платежей)',
      few: 'Собрано ($n платежа)',
      one: 'Собрано ($n платёж)',
    );
    return '$_temp0';
  }

  @override
  String get raporKalanBakiye => 'Остаток';

  @override
  String get aidatBaslik => 'Мои взносы';

  @override
  String get aidatYetkiYok => 'Информация о взносах доступна только жителям.';

  @override
  String get aidatDaireYok =>
      'На вас не зарегистрирована квартира. Обратитесь к управлению.';

  @override
  String get aidatToplamBakiye => 'Общий остаток (все квартиры)';

  @override
  String get aidatBorcVar => 'Есть долг';

  @override
  String get aidatBorcYok => 'Долга нет';

  @override
  String get aidatToplamTahakkuk => 'Всего начислено';

  @override
  String get aidatToplamOdenen => 'Всего оплачено';

  @override
  String get aidatBakiye => 'Остаток';

  @override
  String aidatHesapSatiri(Object tahakkuk, Object odenen, Object bakiye) {
    return 'Начислено $tahakkuk - оплачено $odenen = $bakiye';
  }

  @override
  String aidatTahakkuklar(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Начислений ($n)',
      many: 'Начислений ($n)',
      few: 'Начисления ($n)',
      one: 'Начисление ($n)',
    );
    return '$_temp0';
  }

  @override
  String aidatOdemeler(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Платежей ($n)',
      many: 'Платежей ($n)',
      few: 'Платежа ($n)',
      one: 'Платёж ($n)',
    );
    return '$_temp0';
  }

  @override
  String aidatSonOdeme(Object tarih) {
    return 'Срок оплаты: $tarih';
  }

  @override
  String aidatMakbuz(Object no) {
    return 'Квитанция: $no';
  }

  @override
  String get aidatOdemeDurumuNotu =>
      'Статус платежа обновляется только по подтверждению от платёжного провайдера; с вопросами обращайтесь к управлению.';

  @override
  String get aidatYontemElden => 'Наличными';

  @override
  String get aidatYontemHavale => 'Банковский перевод';

  @override
  String get aidatYontemKart => 'Карта';

  @override
  String get aidatYontemDiger => 'Другое';

  @override
  String get aidatDurumBasarili => 'Успешно';

  @override
  String get aidatDurumIptal => 'Отменён';

  @override
  String get noktaBaslik => 'Контрольные точки';

  @override
  String get noktaEkle => 'Добавить точку';

  @override
  String get noktaListelenemedi => 'Не удалось загрузить точки.';

  @override
  String get noktaSilOnay => 'Удалить точку?';

  @override
  String noktaSilGovde(Object ad) {
    return 'Контрольная точка \"$ad\" будет удалена.';
  }

  @override
  String get noktaSilindi => 'Точка удалена ✓';

  @override
  String get noktaUidZatenVar => 'Эта NFC-метка уже зарегистрирована.';

  @override
  String get noktaDuzenleBaslik => 'Изменить точку';

  @override
  String get noktaYeniBaslik => 'Новая контрольная точка';

  @override
  String get noktaAdIpucu => 'напр. Главный вход';

  @override
  String get noktaUidAlan => 'UID NFC-метки';

  @override
  String get noktaUidIpucu => 'напр. 04A2B3C4D5';

  @override
  String get noktaUidHelper => 'Уникальный идентификатор метки (hex).';

  @override
  String get noktaEnlem => 'Широта (опц.)';

  @override
  String get noktaKonumGecersiz => 'Неверные координаты. Пример: 41,0082';

  @override
  String get ortakSecenekYuklenemedi =>
      'Некоторые варианты не загрузились — список может быть неполным.';

  @override
  String get noktaBoylam => 'Долгота (опц.)';

  @override
  String get noktaPasifAlt =>
      'Неактивная точка не сопоставляется при сканировании';

  @override
  String get noktaYok => 'Точек обхода пока нет.';

  @override
  String get kuyrukHatalariTemizle => 'Очистить постоянные ошибки';

  @override
  String get kuyrukBos => 'Очередь пуста.';

  @override
  String kuyrukOzet(Object bekleyen, Object hatali) {
    return '$bekleyen в очереди · $hatali постоянных ошибок';
  }

  @override
  String get kuyrukSenkronla => 'Синхронизировать';

  @override
  String get kuyrukBekliyor => 'Ожидает';

  @override
  String kuyrukBekliyorDeneme(Object n) {
    return 'Ожидает (попытка: $n)';
  }

  @override
  String get kuyrukGonderiliyor => 'Отправка...';

  @override
  String get kuyrukGonderildiZatenVar => 'Отправлено (уже было записано)';

  @override
  String get kuyrukGonderildiYeni => 'Отправлено (новая запись)';

  @override
  String kuyrukKaliciHata(Object hata) {
    return 'Постоянная ошибка: $hata';
  }

  @override
  String get kuyrukEtiketEslesmedi => 'метка не совпала';

  @override
  String get okutmaImzaGecersiz =>
      'Не удалось проверить подпись метки — возможно, она поддельная или неверная.';

  @override
  String get okutmaTekrarEdilmis => 'Это сканирование уже обработано.';

  @override
  String okutmaBeklenmeyenHata(Object detay) {
    return 'Непредвиденная ошибка: $detay';
  }

  @override
  String get noktaUidZorunlu => 'UID NFC обязателен';

  @override
  String get hataZamanAsimi => 'Истекло время ожидания подключения к серверу.';

  @override
  String get hataSunucuyaUlasilamadi =>
      'Не удалось связаться с сервером. Проверьте подключение к сети и адрес сервера.';

  @override
  String get destekBaslik => 'Поддержка';

  @override
  String get destekYeniTalep => 'Новая заявка';

  @override
  String get destekTalepYok => 'У вас пока нет заявок в поддержку';

  @override
  String destekYuklenemedi(Object hata) {
    return 'Не удалось загрузить заявки.\n$hata';
  }

  @override
  String destekGonderilemedi(Object hata) {
    return 'Не удалось отправить заявку: $hata';
  }

  @override
  String get destekYeniTalepBaslik => 'Новая заявка в поддержку';

  @override
  String get destekKonu => 'Тема';

  @override
  String get destekGorselEkle => 'Добавить изображение';

  @override
  String get destekGorseliDegistir => 'Заменить изображение';

  @override
  String get destekEkip => 'Команда Yönetiyor';

  @override
  String get tesisKurulumBaslik => 'Опишите ваш объект';

  @override
  String get tesisKurulumAciklama =>
      'Вы впервые вошли как управляющий. Чтобы продолжить, введите название объекта; позже его можно изменить в настройках.';

  @override
  String get tesisAdiIpucu => 'напр. ЖК Пример';

  @override
  String get tesisAdiKisa =>
      'Название объекта должно содержать минимум 2 символа';

  @override
  String get tesisOlustur => 'Создать объект';

  @override
  String get tesisAdiGuncellendi => 'Название объекта обновлено';

  @override
  String get tesisAdiAciklama =>
      'Отображается в заголовке главного экрана; его видят все пользователи.';

  @override
  String get sikayetYokSakin =>
      'Вы ещё не подавали жалоб.\nВыберите квартиру на карте жалоб, чтобы подать.';

  @override
  String sikayetSatirBaslik(Object daire, Object kategori) {
    return 'Кв. $daire · $kategori';
  }

  @override
  String get sikayetDurumKapandi => 'Закрыта';

  @override
  String get vardiyaBaslik => 'Смены';

  @override
  String get vardiyaYuklenemedi => 'Не удалось загрузить смены.';

  @override
  String get vardiyaTanimYok => 'Смены не заданы';

  @override
  String vardiyaSaatAraligi(Object baslangic, Object bitis, Object gunTipi) {
    return '$baslangic - $bitis • $gunTipi';
  }

  @override
  String get vardiyaPersonelAta => 'Назначить сотрудников';

  @override
  String vardiyaPersonelBaslik(Object ad) {
    return '$ad — сотрудники';
  }

  @override
  String get vardiyaPersonelGuncellendi => 'Состав смены обновлён ✓';

  @override
  String get vardiyaPersonelYuklenemedi => 'Не удалось загрузить сотрудников.';

  @override
  String get vardiyaAtanabilirYok => 'Нет сотрудников для назначения';

  @override
  String get gunTipiHaftaIci => 'По будням';

  @override
  String get gunTipiHaftaSonu => 'По выходным';

  @override
  String get gunTipiResmiTatil => 'Государственные праздники';

  @override
  String get gunTipiHerGun => 'Каждый день';

  @override
  String get yonIletisimBaslik => 'Контакты управления';

  @override
  String get yonIletisimAlinamadi => 'Не удалось получить данные управления.';

  @override
  String get yonIletisimTanimliDegil =>
      'Контактные данные управления не заданы.';

  @override
  String get yonIletisimMail => 'Почта управления';

  @override
  String get yonIletisimAra => 'Позвонить управляющему';

  @override
  String get aramaBaslatilamadi => 'Не удалось начать звонок';

  @override
  String get aramaYapilamiyor => 'Звонок недоступен';

  @override
  String get bildirimYok => 'Уведомлений нет';

  @override
  String bildirimYuklenemedi(Object hata) {
    return 'Не удалось загрузить уведомления.\n$hata';
  }

  @override
  String get bildirimYeniPush => 'Новое уведомление';

  @override
  String get akisDevriyeOkutma => 'Сканирование обхода';

  @override
  String get akisGorevTamamlandi => 'Задача выполнена';

  @override
  String get akisAidatOdemesi => 'Оплата взносов';

  @override
  String get akisTalepAcildi => 'Заявка открыта';

  @override
  String get akisTalepIsEmri => 'Заявка стала нарядом';

  @override
  String get akisTalepCozuldu => 'Заявка решена';

  @override
  String get akisTalepReddedildi => 'Заявка отклонена';

  @override
  String get akisDaireSikayeti => 'Жалоба на квартиру';

  @override
  String get akisAlarmKacirilanTur => 'Пропущенный обход';

  @override
  String get akisAlarmEksikCheckpoint => 'Пропущенная контрольная точка';

  @override
  String get akisAlarmGecikmisOkutma => 'Позднее сканирование';

  @override
  String get akisZiyaretciGirisi => 'Вход посетителя';

  @override
  String get akisZiyaretciCikisi => 'Выход посетителя';

  @override
  String get akisKargoKaydedildi => 'Посылка зарегистрирована';

  @override
  String get akisKargoTeslimEdildi => 'Посылка выдана';

  @override
  String get akisAracGirisi => 'Въезд автомобиля';

  @override
  String get akisAracCikisi => 'Выезд автомобиля';

  @override
  String get akisIhlalKaydi => 'Запись о нарушении';

  @override
  String akisAltDaireTutar(Object daire, Object tutar) {
    return 'Кв. $daire — $tutar';
  }

  @override
  String akisAltDaireKategori(Object daire, Object kategori) {
    return 'Кв. $daire — $kategori';
  }

  @override
  String akisAltAdDaire(Object ad, Object daire) {
    return '$ad — кв. $daire';
  }

  @override
  String akisAltPlakaDaire(Object plaka, Object daire) {
    return '$plaka — кв. $daire';
  }

  @override
  String akisAltPlakaTanim(Object plaka, Object tanim) {
    return '$plaka ($tanim)';
  }

  @override
  String akisAltPlakaDaireTanim(Object plaka, Object daire, Object tanim) {
    return '$plaka — кв. $daire ($tanim)';
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
  String get ortakParolayiGoster => 'Показать пароль';

  @override
  String get ortakParolayiGizle => 'Скрыть пароль';

  @override
  String get ortakFotograf => 'Фото';

  @override
  String get ortakFotografiBuyut => 'Увеличить фото';

  @override
  String get ortakGoster => 'Открыть';

  @override
  String get talepRedBaslik => 'Отклонить обращение';

  @override
  String get ziyaretciDaireSakinYok => 'В этой квартире нет активных жильцов';

  @override
  String get ceviriOtomatik => 'Этот текст переведён автоматически';

  @override
  String get ceviriOtomatikKisa => 'Автоперевод';

  @override
  String get ceviriOrijinaliGor => 'Показать оригинал';

  @override
  String get ceviriCeviriyiGor => 'Показать перевод';

  @override
  String get ceviriHazirlaniyor => 'Перевод готовится — показан оригинал';

  @override
  String get ceviriHazirlaniyorKisa => 'Перевод готовится';

  @override
  String get ceviriYapilamadi => 'Не удалось перевести — показан оригинал';

  @override
  String get ceviriYapilamadiKisa => 'Ошибка перевода';

  @override
  String get modulAracGecis => 'Проезды автомобилей';

  @override
  String get modulOtopark => 'Парковка';

  @override
  String get modulIhlaller => 'Нарушения';

  @override
  String get aracSuzgecTumu => 'Все';

  @override
  String get aracSuzgecIceride => 'Внутри';

  @override
  String get aracSuzgecCikmis => 'Выехали';

  @override
  String get aracPlakaAra => 'Поиск по номеру';

  @override
  String get aracListeBos => 'Нет записей о проездах';

  @override
  String get aracAramaBos => 'Нет проездов с таким номером';

  @override
  String get aracRozetIceride => 'Внутри';

  @override
  String get aracRozetCikti => 'Выехал';

  @override
  String get aracRozetZiyaretci => 'Гость';

  @override
  String aracGirisZamani(Object zaman) {
    return 'Въезд: $zaman';
  }

  @override
  String aracCikisZamani(Object zaman) {
    return 'Выезд: $zaman';
  }

  @override
  String aracDaire(Object no) {
    return 'Квартира $no';
  }

  @override
  String get aracCikisVer => 'Отметить выезд';

  @override
  String get aracCikisOnayBaslik => 'Отметить выезд автомобиля?';

  @override
  String get aracCikisVerildi => 'Выезд записан';

  @override
  String get aracZatenKapali => 'Этот проезд уже закрыт';

  @override
  String get aracYeniGiris => 'Новый въезд';

  @override
  String get aracGirisKaydedildi => 'Въезд автомобиля записан';

  @override
  String get aracPlaka => 'Номер';

  @override
  String get aracPlakaZorunlu => 'Номер обязателен';

  @override
  String get aracTanimAlani => 'Описание автомобиля (необязательно)';

  @override
  String get aracDaireAlani => 'Номер квартиры (необязательно)';

  @override
  String get aracZiyaretciMi => 'Автомобиль гостя';

  @override
  String get aracZatenIceride =>
      'У этого номера уже есть открытый проезд (автомобиль внутри)';

  @override
  String get aracErisimYok =>
      'Список проездов доступен только администрации и охране';

  @override
  String aracKaydeden(Object ad) {
    return 'Записал: $ad';
  }

  @override
  String get otoparkDoluEtiket => 'Занято';

  @override
  String get otoparkBosEtiket => 'Свободно';

  @override
  String get otoparkKapasiteEtiket => 'Вместимость';

  @override
  String get otoparkKapasiteTanimsiz =>
      'Вместимость не задана — показано только число автомобилей внутри';

  @override
  String get otoparkAracListesi => 'Открыть проезды';

  @override
  String get ihlalDurumYeni => 'Новое';

  @override
  String get ihlalDurumInceleniyor => 'На рассмотрении';

  @override
  String get ihlalDurumKapatildi => 'Закрыто';

  @override
  String get ihlalKaynakKamera => 'Камера';

  @override
  String get ihlalKaynakManuel => 'Вручную';

  @override
  String get ihlalKaynakDevriye => 'Обход';

  @override
  String get ihlalListeBos => 'Нет записей о нарушениях';

  @override
  String get ihlalYeni => 'Новое нарушение';

  @override
  String get ihlalAcildi => 'Запись о нарушении создана';

  @override
  String get ihlalBaslikAlani => 'Заголовок';

  @override
  String get ihlalBaslikZorunlu => 'Заголовок обязателен';

  @override
  String get ihlalAciklamaAlani => 'Описание (необязательно)';

  @override
  String get ihlalKonumAlani => 'Место (необязательно)';

  @override
  String get ihlalKaynakAlani => 'Источник обнаружения';

  @override
  String get ihlalIncelemeyeAl => 'Взять на рассмотрение';

  @override
  String get ihlalKapat => 'Закрыть запись';

  @override
  String get ihlalDurumGuncellendi => 'Статус нарушения обновлён';

  @override
  String get ihlalKapatmaOnay =>
      'Закрыть запись? Закрытое нарушение нельзя открыть снова.';

  @override
  String get ihlalKapaliDegistirilemez =>
      'Закрытое нарушение нельзя открыть снова';

  @override
  String get ihlalErisimYok =>
      'Записи о нарушениях доступны только администрации и охране';

  @override
  String ihlalKaydeden(Object ad) {
    return 'Открыл: $ad';
  }

  @override
  String get kameraRestream => 'Адрес рестрима (необязательно)';

  @override
  String get kameraRestreamAlt =>
      'Делает RTSP-камеру воспроизводимой. HLS-адрес шлюза Frigate/go2rtc.';

  @override
  String get kameraRestreamHata =>
      'Адрес рестрима должен начинаться с http:// или https://';

  @override
  String get kameraRestreamRozet => 'Через шлюз';

  @override
  String get modulPlakaOlaylari => 'Считывания номеров';

  @override
  String get anprDurumIslendi => 'Обработано';

  @override
  String get anprDurumOnayBekliyor => 'Ожидает подтверждения';

  @override
  String get anprDurumYokSayildi => 'Пропущено';

  @override
  String get anprDurumHata => 'Ошибка';

  @override
  String get anprYonGiris => 'Въезд';

  @override
  String get anprYonCikis => 'Выезд';

  @override
  String get anprYonBilinmiyor => 'Направление неизвестно';

  @override
  String get anprListeBos => 'Нет считываний номеров';

  @override
  String get anprErisimYok =>
      'Считывания номеров доступны только администрации и охране';

  @override
  String anprGuven(Object oran) {
    return 'Точность $oran%';
  }

  @override
  String get anprOnayla => 'Подтвердить';

  @override
  String get anprReddet => 'Отклонить';

  @override
  String get anprOnayBaslik => 'Подтвердить считывание';

  @override
  String get anprOnayAciklama =>
      'Если номер распознан неверно, его можно исправить. Подтверждение откроет или закроет проезд.';

  @override
  String get anprKararUygulandi => 'Решение применено';

  @override
  String get anprOnayBeklemiyor =>
      'Это считывание больше не ожидает подтверждения';

  @override
  String get anprNedenDusukGuven => 'Низкая точность';

  @override
  String get anprNedenZatenIceride => 'Автомобиль уже внутри';

  @override
  String get anprNedenAcikGecisYok => 'Нет открытого проезда';

  @override
  String get anprNedenOtomatikCikisKapali => 'Автовыезд отключён';

  @override
  String get anprNedenElleReddedildi => 'Отклонено вручную';

  @override
  String get anprNedenPlakaBicimi => 'Номер не распознан';

  @override
  String get aracPlakaOkumalari => 'Считывания номеров';

  @override
  String get kategoriGoruntuKirliligi => 'Визуальный мусор';

  @override
  String get fabSikayetBildir => 'Пожаловаться на соседа';

  @override
  String get sakinRolTipi => 'Тип отношения';

  @override
  String get sakinRolMalik => 'Собственник';

  @override
  String get sakinRolKiraci => 'Арендатор';

  @override
  String get sakinRolDegisme => 'Не менять';

  @override
  String get sakinRolAlt =>
      'Взносы начисляются арендатору, инвестиционные расходы — собственнику.';

  @override
  String get sakinEposta => 'Эл. почта';

  @override
  String get sakinEpostaTemizle => 'Удалить эл. почту';

  @override
  String get sakinRolBagYok =>
      'Чтобы задать тип отношения, житель должен быть привязан к квартире';

  @override
  String get sikayetKuyruguBaslik => 'Очередь жалоб';

  @override
  String get sikayetSekmeYeni => 'Новые';

  @override
  String get sikayetSekmeTumu => 'Все';

  @override
  String get sikayetOkunmamisYok => 'Непрочитанных жалоб нет.';

  @override
  String get sikayetYokYonetim => 'Жалоб пока нет.';

  @override
  String get sikayetOkunduIsaretle => 'Отметить прочитанным';

  @override
  String sikayetOkunmamisRozet(int sayi) {
    return '$sayi непрочитанных жалоб';
  }

  @override
  String get kameraHataAdresBozuk =>
      'Адрес потока недействителен. Возможно, в нём остался пробел или перенос строки.';

  @override
  String get kameraHataSemaDesteklenmiyor =>
      'Этот тип адреса нельзя воспроизвести напрямую. Задайте адрес рестрима для камеры.';

  @override
  String get kameraHataSifrelenmemis =>
      'Незашифрованный (http) поток заблокирован устройством. Возможно, его запрещает рабочий профиль или VPN.';

  @override
  String kameraUrlCokUzun(int sinir) {
    return 'Адрес потока слишком длинный (максимум $sinir символов).';
  }

  @override
  String get kameraUrlSifrelenmemisUyari =>
      'Этот адрес не зашифрован (http). По возможности используйте https.';

  @override
  String get modulDaireTanimlari => 'Типы квартир';

  @override
  String get daireTanimSekmeTipler => 'Типы';

  @override
  String get daireTanimSekmeGruplar => 'Группы';

  @override
  String get daireTanimAd => 'Название';

  @override
  String get daireTanimAdIpucu => 'Напр. 2+1, дуплекс, вилла';

  @override
  String get daireTanimVarsayilanAidat => 'Взнос по умолчанию';

  @override
  String get daireTanimAidatBos => 'Не задано';

  @override
  String get daireTanimAidatAlt =>
      'Пустое поле — не задано; 0 означает освобождение.';

  @override
  String daireTanimDaireSayisi(int sayi) {
    return '$sayi помещений';
  }

  @override
  String daireTanimSilOnay(int sayi) {
    return 'Удалить это определение? Связанные помещения ($sayi) НЕ удаляются — очищается только их классификация.';
  }

  @override
  String daireTanimSilindiEtki(int sayi) {
    return 'Удалено. Классификация $sayi помещений очищена.';
  }

  @override
  String get daireTanimYok => 'Определений пока нет.';

  @override
  String get daireTanimYeni => 'Новое определение';

  @override
  String get daireTipiSecici => 'Тип помещения';

  @override
  String get daireGrubuSecici => 'Группа помещений';

  @override
  String get daireTanimSecilmedi => 'Не выбрано';

  @override
  String get odeBaslik => 'Оплатить';

  @override
  String get odeBorcunuz => 'Непогашенная сумма';

  @override
  String get odeHavaleBaslik => 'Банковский перевод';

  @override
  String get odeHavaleAdim =>
      'Переведите на IBAN и укажите код ниже в назначении платежа. Без кода платёж может не сопоставиться.';

  @override
  String get odeKodBaslik => 'Ваш код платежа';

  @override
  String get odeKopyala => 'Копировать';

  @override
  String get odeKopyalandi => 'Скопировано';

  @override
  String get odeKartBaslik => 'Оплата картой';

  @override
  String get odeKartKapali =>
      'Оплата картой пока не включена. Пока используйте банковский перевод.';

  @override
  String get odeHavaleKapali =>
      'Для комплекса ещё не задан банковский счёт. Обратитесь в управление.';

  @override
  String get odeBorcYok => 'У вас нет задолженности.';

  @override
  String get odeBasarili => 'Ваш платёж получен.';

  @override
  String get nfcFotoGerekli => 'Для начала обхода требуется фото.';

  @override
  String get nfcFotoCek => 'Сделать фото и отправить';

  @override
  String get nfcFotoYukleniyor => 'Загрузка фото...';

  @override
  String nfcFotoYuklenemedi(String hata) {
    return 'Не удалось загрузить фото: $hata';
  }

  @override
  String get nfcKonumYok =>
      'Местоположение недоступно — отметка сохранена без него.';

  @override
  String get nfcKonumIzinYok =>
      'Доступ к местоположению запрещён — отметка сохранена без него.';

  @override
  String get nfcKonumServisKapali =>
      'Службы геолокации выключены — отметка сохранена без них.';

  @override
  String get rolGuvenlikAmiri => 'Начальник охраны';

  @override
  String get rolDenetci => 'Аудитор';

  @override
  String get kvkkBaslik => 'Уведомление о конфиденциальности';

  @override
  String get kvkkSonaKaydir => 'Прокрутите текст до конца, чтобы принять.';

  @override
  String get kvkkOnayliyorum => 'Прочитал(а) и принимаю';

  @override
  String get kvkkYuklenemedi => 'Не удалось загрузить уведомление.';

  @override
  String get kvkkTekrarDene => 'Повторить';

  @override
  String get kvkkSurumDegisti =>
      'Текст обновлён; пожалуйста, прочитайте новую версию.';

  @override
  String get kvkkIzinBaslik => 'Персональные кампании и предложения';

  @override
  String get kvkkIzinAciklama =>
      'Полностью по желанию; можно продолжить без согласия. Изменить можно в любой момент в настройках.';

  @override
  String get kvkkIzinEposta => 'Хочу получать электронные письма';

  @override
  String get kvkkIzinSms => 'Хочу получать SMS';

  @override
  String get kvkkIzinArama => 'Хочу принимать звонки';

  @override
  String get kvkkIzinKaydedilemedi => 'Не удалось сохранить настройку.';

  @override
  String get kvkkAyarlarBaslik => 'Разрешения и уведомление';

  @override
  String get kvkkMetniGoruntule => 'Открыть уведомление';

  @override
  String get anketBaslik => 'Опросы';

  @override
  String get anketYok => 'Сейчас нет открытых опросов.';

  @override
  String get anketKapali => 'Закрыт';

  @override
  String get anketOyVerdiniz => 'Ваш голос учтён';

  @override
  String get anketOyVer => 'Голосовать';

  @override
  String anketToplamOy(int sayi) {
    return '$sayi голосов';
  }

  @override
  String anketOyHatasi(String hata) {
    return 'Не удалось отправить голос: $hata';
  }

  @override
  String get anketSonucKapali => 'Результаты появятся после закрытия опроса.';

  @override
  String get modulAnketler => 'Опросы';

  @override
  String get hesapSilBolum => 'Учётная запись';

  @override
  String get hesapSilBaslik => 'Удалить мою учётную запись';

  @override
  String get hesapSilAlt =>
      'Безвозвратно удалить учётную запись и личные данные';

  @override
  String get hesapSilOnayBaslik => 'Удалить учётную запись?';

  @override
  String get hesapSilOnayGovde =>
      'Ваше имя, номер телефона, адрес электронной почты и записи об устройствах будут удалены, и вы больше не сможете войти. Записи о взносах и платежах удалить нельзя: закон обязывает нас их хранить. Они останутся в системе анонимно и больше не будут связаны с вашим именем.';

  @override
  String get hesapSilParolaEtiket => 'Ваш пароль';

  @override
  String get hesapSilParolaAciklama =>
      'В целях безопасности введите пароль ещё раз.';

  @override
  String get hesapSilOnayla => 'Удалить учётную запись навсегда';

  @override
  String get hesapSilSonucSilindi => 'Ваша учётная запись удалена.';

  @override
  String get hesapSilSonucAnonim =>
      'Ваша учётная запись удалена. Записи, которые мы обязаны хранить по закону, обезличены.';

  @override
  String get hesapSilParolaGerekli => 'Введите пароль, чтобы продолжить.';

  @override
  String get hesapSilSiliniyor => 'Удаление...';

  @override
  String get ayarlarHukuki => 'Правовая информация';

  @override
  String get ayarlarGizlilik => 'Политика конфиденциальности';

  @override
  String get ayarlarKosullar => 'Условия использования';

  @override
  String get ayarlarBelgeAcilamadi =>
      'Не удалось открыть страницу. Проверьте подключение к интернету.';

  @override
  String get demoSimuleOkutma => 'Имитация отметки';

  @override
  String demoSimuleOkutmaBasarili(String nokta) {
    return 'Имитация отметки записана: $nokta';
  }

  @override
  String get demoSimuleOkutmaHata => 'Не удалось записать имитацию отметки.';

  @override
  String get denetciWebBaslik => 'Экраны аудита — в веб-версии';

  @override
  String denetciWebGovde(String adres) {
    return 'Отчёты аудита и финансовый надзор рассчитаны на настольную версию. Откройте $adres на компьютере.';
  }

  @override
  String get denetciWebKopyala => 'Скопировать адрес';

  @override
  String get modulVardiyalar => 'Смены';

  @override
  String get izgaraDuzenleBaslik => 'Настроить главный экран';

  @override
  String izgaraDuzenleAciklama(int enCok) {
    return 'Выберите до $enCok часто используемых разделов.';
  }

  @override
  String get izgaraSifirla => 'Сбросить по умолчанию';

  @override
  String get izgaraKaydet => 'Сохранить';

  @override
  String izgaraSecim(int secili, int enCok) {
    return 'Выбрано: $secili/$enCok';
  }

  @override
  String izgaraTavanUyarisi(int enCok) {
    return 'Достигнут предел. Уберите один, чтобы добавить другой (плиток: $enCok).';
  }

  @override
  String get dilSeciciBaslik => 'Язык';

  @override
  String get talepGeriAl => 'Отозвать';

  @override
  String get talepGeriAlOnay =>
      'Отозвать эту заявку? Отозванная заявка не передаётся управляющей компании, и это действие необратимо.';

  @override
  String get talepGeriAlindi => 'Заявка отозвана';

  @override
  String get talepDurumGeriAlindi => 'Отозвана';

  @override
  String get sikayetGeriAl => 'Отозвать жалобу';

  @override
  String get sikayetGeriAlindi => 'Жалоба отозвана';

  @override
  String get izinDevam => 'Продолжить';

  @override
  String get izinKonumBaslik => 'Зачем нужен доступ к геолокации?';

  @override
  String get izinKonumGovde =>
      'При сканировании контрольной точки записывается ваше местоположение в этот момент, чтобы подтвердить, что обход действительно выполнен на объекте. Местоположение фиксируется ТОЛЬКО в момент сканирования; приложение не отслеживает вас в фоновом режиме.';

  @override
  String get izinKameraBaslik => 'Зачем нужен доступ к камере?';

  @override
  String get izinKameraGovde =>
      'Камера нужна, чтобы вы могли приложить фотографию при сообщении о заявке или неисправности. Фото делается только вами и отправляется управляющей компании.';

  @override
  String get girisKodlaBaslik => 'Нет пароля — вход по коду';

  @override
  String get girisKodlaAciklama =>
      'Мы отправим шестизначный код подтверждения на ваш телефон.';

  @override
  String get girisKoduGonder => 'Отправить код';

  @override
  String get girisKodAlani => 'Код подтверждения';

  @override
  String get hesapSilKodlaOnayla => 'Нет пароля — подтвердить кодом';

  @override
  String get hesapSilKodAciklama =>
      'Мы отправим шестизначный код на вашу электронную почту для подтверждения удаления.';

  @override
  String get hesapSilKodGerekli => 'Введите код подтверждения';

  @override
  String get kayitBaslik => 'Вход по ID объекта';

  @override
  String get kayitAltBaslik => 'Выберите подходящий вариант';

  @override
  String get kayitRolYonetici => 'Управляющий';

  @override
  String get kayitRolSakin => 'Житель';

  @override
  String get kayitRolGuvenlik => 'Сотрудник охраны';

  @override
  String get kayitRolTesisGorevlisi => 'Сотрудник объекта';

  @override
  String get kayitTesisKodu => 'ID объекта';

  @override
  String get kayitTesisKoduIpucu =>
      'Код, который выдало управление (напр. OLTU-260715)';

  @override
  String get kayitDaireNo => 'Номер квартиры';

  @override
  String get kayitBlok => 'Блок (если есть)';

  @override
  String get kayitDevam => 'Продолжить';

  @override
  String get kayitKodBaslik => 'Код подтверждения';

  @override
  String kayitKodAciklama(String tesis, String telefon) {
    return 'Код отправлен на $telefon для «$tesis». Если номер не зарегистрирован, код не придёт.';
  }

  @override
  String get kayitKodAlani => '6-значный код';

  @override
  String get kayitTesisKoduGerekli => 'Требуется ID объекта.';

  @override
  String get kayitDaireGerekli => 'Требуется номер квартиры.';

  @override
  String get kayitKodGerekli => 'Введите код.';

  @override
  String get kayitYontemBaslik => 'Как вы будете входить?';

  @override
  String get kayitYontemParola => 'Создать пароль';

  @override
  String get kayitGirisLinki => 'Уже есть аккаунт? Войти';

  @override
  String kayitAdim(String n, String toplam) {
    return 'Шаг $n/$toplam';
  }

  @override
  String sosyalIleDevam(String saglayici) {
    return 'Продолжить через $saglayici';
  }

  @override
  String get sosyalBaslik => 'Сопоставьте учётную запись';

  @override
  String sosyalEslesmeAciklama(String saglayici) {
    return 'Аккаунт $saglayici подтверждён. Введите ID объекта и номер телефона, чтобы мы нашли вашу учётную запись.';
  }

  @override
  String get sosyalRelayUyari =>
      'Apple скрыл ваш адрес e-mail; письма на него не доходят.';

  @override
  String get sosyalTesisKodu => 'ID объекта';

  @override
  String get sosyalKodGonder => 'Отправить код подтверждения';

  @override
  String sosyalKodAciklama(String tesis, String telefon) {
    return '$tesis — введите код, отправленный на $telefon.';
  }

  @override
  String get sosyalDogrula => 'Подтвердить и войти';

  @override
  String get sosyalVazgec => 'Отмена';

  @override
  String get davetBaslik => 'Регистрация';

  @override
  String get davetGecersizBaslik => 'Ссылка не работает';

  @override
  String get davetSuresiDoldu => 'Срок действия ссылки истёк.';

  @override
  String get davetKullanilmis => 'Это приглашение уже использовано.';

  @override
  String get davetBulunamadi => 'Эта ссылка-приглашение недействительна.';

  @override
  String get davetYoneticinizeBasvurun =>
      'Обратитесь к управляющему за новым приглашением.';

  @override
  String davetOzet(String tesis, String rol) {
    return '$tesis пригласил вас как $rol.';
  }

  @override
  String get kayitYontemEposta => 'Продолжить по эл. почте';

  @override
  String get kayitYontemVeya => 'или';

  @override
  String get kayitBilgilerBaslik => 'Ваши данные';

  @override
  String get kayitAdSoyad => 'Имя и фамилия';

  @override
  String get kayitAdGerekli => 'Укажите имя и фамилию.';

  @override
  String get kayitParola => 'Пароль';

  @override
  String get kayitParolaGerekli =>
      'Пароль должен содержать не менее 8 символов.';

  @override
  String get kayitTesisAdBaslik => 'Создайте свой объект';

  @override
  String get kayitTesisAd => 'Введите название объекта';

  @override
  String get kayitTesisAdIpucu => 'напр. ЖК «Олту»';

  @override
  String get kayitTesisAdGerekli => 'Укажите название объекта.';

  @override
  String get kayitZatenSitemVar => 'У меня уже есть объект';

  @override
  String get kayitTesisKoduBaslik => 'Код вашего объекта';

  @override
  String get kayitTesisKoduPaylas =>
      'Передайте этот код жильцам и сотрудникам — по нему они присоединятся.';

  @override
  String get kayitKopyala => 'Копировать';

  @override
  String get kayitKopyalandi => 'Скопировано';

  @override
  String get kayitTamamla => 'Продолжить';

  @override
  String get kayitSosyalAdNotu =>
      'Имя взято из вашей учётной записи; его можно изменить.';

  @override
  String get kayitEposta => 'Эл. почта';

  @override
  String get kayitEpostaGerekli => 'Требуется адрес электронной почты.';

  @override
  String get kayitEpostaGecersiz =>
      'Введите действительный адрес электронной почты.';

  @override
  String get kayitTelefonIletisim => 'Телефон (необязательно)';

  @override
  String get kayitTelefonNotu =>
      'Телефон используется только для связи; проверка выполняется по электронной почте.';

  @override
  String get kayitTesisKoduGir => 'Введите ваш ID объекта';

  @override
  String kayitKodAciklamaEposta(String tesis) {
    return 'Мы отправили код подтверждения на вашу электронную почту для $tesis. Если ваш адрес не зарегистрирован, код не придёт.';
  }

  @override
  String get kayitOnayBekliyorBaslik => 'Ожидается одобрение руководителя';

  @override
  String get kayitOnayBekliyorAciklama =>
      'Ваши данные не удалось проверить, и они были направлены вашему руководителю на одобрение. Проверьте ваш ID объекта; если проблема сохраняется, обратитесь к руководителю. После одобрения вы сможете войти.';

  @override
  String get kayitGiriseDon => 'Вернуться ко входу';

  @override
  String get sosyalTamamlaBaslik => 'Завершить с ID объекта';

  @override
  String sosyalTamamlaAciklama(String saglayici) {
    return 'Ваша учётная запись $saglayici подтверждена. Чтобы завершить, введите вашу роль и ID объекта.';
  }

  @override
  String get sosyalRol => 'Ваша роль';

  @override
  String get sosyalTamamla => 'Завершить';

  @override
  String get sosyalOtpAciklama =>
      'Введите код подтверждения, отправленный на вашу электронную почту.';

  @override
  String get binaYapisalAraclar => 'Структурные инструменты';

  @override
  String get binaKatSil => 'Удалить этаж';

  @override
  String get binaTopluTip => 'Массово изменить статус';

  @override
  String get binaSiralama => 'Изменить порядок';

  @override
  String binaKatSilOzet(int n) {
    return 'Будет удалено квартир: $n';
  }

  @override
  String binaKatSilOnay(int kat) {
    return 'Все квартиры на этаже $kat будут удалены навсегда. Отменить нельзя.';
  }

  @override
  String get binaAralikSec => 'Выбрать по номеру';

  @override
  String get binaAralikUygula => 'Выбрать';

  @override
  String binaSeciliSayisi(int n) {
    return 'Выбрано квартир: $n';
  }

  @override
  String binaAralikBulunamayan(String parca) {
    return 'Не найдено: $parca';
  }

  @override
  String get ortakEminMisiniz => 'Вы уверены?';

  @override
  String get ortakDurum => 'Статус';

  @override
  String get ortakAktif => 'Активен';

  @override
  String get ortakPasif => 'Неактивен';

  @override
  String get binaBaslangicKat => 'Начальный этаж';

  @override
  String get binaBaslangicKatIpucu =>
      'Отрицательные для подвалов: -2, -1, 0 (первый), 1…';

  @override
  String get rezSekmeGecmis => 'Прошедшие';

  @override
  String get rezGecmisYok => 'Прошедших броней нет.';

  @override
  String get rezGecmisTamam => 'Завершена';

  @override
  String rezIptalEden(String ad) {
    return 'Отменил: $ad';
  }

  @override
  String get binaKatBos =>
      'На этом этаже нет квартир; удаление не затронет записи.';

  @override
  String binaKatOzet(int daire, int sakin, int talep) {
    return '$daire квартир · $sakin жильцов · $talep открытых жалоб';
  }

  @override
  String binaKatOzetMali(int tahakkuk, int odeme, int rezervasyon) {
    return '$tahakkuk начислений · $odeme платежей · $rezervasyon броней';
  }

  @override
  String get binaKatMaliUyari =>
      'На этаже есть записи по взносам. При удалении начисления и платежи исчезнут навсегда; бухгалтерский след восстановить нельзя. Рассмотрите деактивацию квартир.';

  @override
  String binaKatOnayYaz(int kat) {
    return 'Введите номер этажа для подтверждения ($kat)';
  }

  @override
  String binaKatSilOzetOnay(
    String blok,
    int kat,
    int daire,
    int sakin,
    int kayit,
  ) {
    return 'Этаж $kat блока $blok будет удалён: $daire квартир, $sakin жильцов и $kayit связанных записей исчезнут навсегда. Отменить нельзя.';
  }

  @override
  String get kurulumBaslik => 'Мастер настройки';

  @override
  String get kurulumAlt => 'Выполните шаги, чтобы подготовить объект к работе.';

  @override
  String get kurulumIlerleme => 'Прогресс';

  @override
  String get kurulumTamamlandi => 'Настройка завершена';

  @override
  String kurulumAdimTamam(int sayi) {
    return 'записей: $sayi';
  }

  @override
  String get kurulumAdimAtlandi => 'Пропущено';

  @override
  String get kurulumAdimBekliyor => 'Ожидает';

  @override
  String get kurulumGit => 'Перейти';

  @override
  String get kurulumGoruntule => 'Открыть';

  @override
  String get kurulumAtla => 'Пропустить';

  @override
  String get kurulumAtlamayiGeriAl => 'Отменить пропуск';

  @override
  String kurulumSayac(int gecilen, int toplam) {
    return '$gecilen/$toplam шагов';
  }

  @override
  String get kurulumHata => 'Не удалось загрузить состояние настройки.';

  @override
  String get kurulumBlok => 'Блоки';

  @override
  String get kurulumBlokAlt => 'Определите блоки здания.';

  @override
  String get kurulumDaire => 'Квартиры';

  @override
  String get kurulumDaireAlt => 'Создайте этажи и квартиры пакетно.';

  @override
  String get kurulumDaireTipi => 'Типы квартир';

  @override
  String get kurulumDaireTipiAlt =>
      'Задайте типы и суммы взносов по умолчанию.';

  @override
  String get kurulumSakin => 'Жители';

  @override
  String get kurulumSakinAlt => 'Добавьте жителей в квартиры.';

  @override
  String get kurulumPersonel => 'Персонал';

  @override
  String get kurulumPersonelAlt => 'Введите записи сотрудников.';

  @override
  String get kurulumGorevAlani => 'Категории задач';

  @override
  String get kurulumGorevAlaniAlt =>
      'Создайте категории для группировки задач.';

  @override
  String get kurulumNfc => 'NFC-точки';

  @override
  String get kurulumNfcAlt => 'Определите точки обхода.';

  @override
  String get kurulumAidat => 'Начисление взносов';

  @override
  String get kurulumAidatAlt => 'Начислите взносы за первый период.';

  @override
  String get kurulumAdimWebde =>
      'Этот шаг пока доступен только в веб-панели под учётной записью администратора платформы.';

  @override
  String get kurulumHatirlaticiBaslik => 'Завершите настройку';

  @override
  String get kurulumHatirlaticiMetin =>
      'До готовности объекта осталось несколько шагов. Мастер проведёт вас по каждому экрану.';

  @override
  String get kurulumHatirlaticiGit => 'Открыть мастер';

  @override
  String get kurulumHatirlaticiSonra => 'Позже';

  @override
  String get noktaYokAlt =>
      'Точки обхода — это NFC-метки, которые сканируют во время обходов.';

  @override
  String get devriyePlanYokAlt =>
      'План обхода определяет, какие точки и когда сканируются.';

  @override
  String get personelYokAlt =>
      'Здесь создаются учётные записи охраны и обслуживающего персонала.';

  @override
  String get sakinYokAlt =>
      'Добавленные жители привязываются к квартирам и могут входить в приложение.';

  @override
  String get ortakDahaFazlaSecenek => 'Другие параметры';

  @override
  String get modulDokumanlar => 'Документы объекта';

  @override
  String get dokumanBaslik => 'Документы объекта';

  @override
  String get dokumanAra => 'Поиск по названию документа';

  @override
  String get dokumanYokSakin => 'Пока не опубликовано ни одного документа.';

  @override
  String get dokumanAramaSonucYok => 'Нет документов, соответствующих запросу.';

  @override
  String get dokumanAcilamadi => 'Не удалось открыть документ.';

  @override
  String dokumanBoyutKb(int kb) {
    return '$kb КБ';
  }

  @override
  String get kvkkYasalMetinler => 'Правовые тексты';

  @override
  String get kvkkTurAydinlatma => 'Уведомление';

  @override
  String get kvkkTurAcikRiza => 'Явное согласие';

  @override
  String get kvkkTurGizlilik => 'Политика конфиденциальности';

  @override
  String get kvkkTurKullanim => 'Условия использования';

  @override
  String get kvkkTurCerez => 'Политика cookie';

  @override
  String get kvkkMetinYayinlanmamis => 'Этот текст ещё не опубликован.';

  @override
  String get kvkkOnaylanmadi => 'Вы ещё не согласились с этим текстом.';

  @override
  String get kvkkYenidenOnayBekleniyor =>
      'Ожидается ваше согласие с текущей версией.';

  @override
  String kvkkSurumEtiketi(int n) {
    return 'Версия $n';
  }

  @override
  String kvkkOnayladiginizSurum(int n) {
    return 'Версия, с которой вы согласились: $n';
  }

  @override
  String get kabukKisayollar => 'Ярлыки';

  @override
  String get ayarlarBildirimlerBaslik => 'Уведомления';

  @override
  String get ayarlarBildirimTercih => 'Настройки уведомлений';

  @override
  String get ayarlarBildirimAciklama =>
      'Выберите, по каким каналам получать рабочие уведомления. Это отдельно от согласия на маркетинг.';

  @override
  String get ayarlarBildirimEposta => 'Уведомления по эл. почте';

  @override
  String get ayarlarBildirimSms => 'SMS-уведомления';

  @override
  String get ayarlarBildirimMobil => 'Мобильные уведомления';

  @override
  String get ayarlarBildirimKaydedildi => 'Настройка уведомлений обновлена';

  @override
  String get ayarlarBildirimYuklenemedi =>
      'Не удалось загрузить настройки уведомлений';

  @override
  String get ayarlarBildirimIzinKapali =>
      'Разрешение на уведомления на устройстве отключено. Мобильные уведомления не будут отображаться на телефоне; включите их в настройках устройства.';

  @override
  String get ayarlarBildirimIzinBelirsiz =>
      'Для показа уведомлений нужно разрешение.';

  @override
  String get ayarlarBildirimIzinIste => 'Запросить разрешение';

  @override
  String get surumZorunluBaslik => 'Требуется обновление';

  @override
  String get surumZorunluMetin =>
      'Эта версия больше не работает. Обновите приложение, чтобы продолжить.';

  @override
  String get surumOnerilenBaslik => 'Доступна новая версия';

  @override
  String get surumOnerilenMetin =>
      'Обновите приложение, чтобы работать удобнее.';

  @override
  String get surumGuncelle => 'Обновить';

  @override
  String get surumSimdiGuncelle => 'Обновить сейчас';

  @override
  String get surumSonra => 'Позже';

  @override
  String get surumMagazaAcilamadi =>
      'Не удалось открыть магазин. Обновите приложение вручную в магазине приложений на телефоне.';

  @override
  String get tesisDegistirBaslik => 'Сменить объект';

  @override
  String get tesisDegistirSecili => 'Вы здесь';

  @override
  String get ziyaretDaireAra => 'Квартира';

  @override
  String get ziyaretDaireAraIpucu => 'Введите номер квартиры или имя жильца';

  @override
  String get vardiyaPlaniBaslik => 'План смен';

  @override
  String get vardiyaSuAnGorevde => 'Сейчас на смене';

  @override
  String get vardiyaSuAnKimseYok => 'Сейчас никто не запланирован.';

  @override
  String get vardiyaSiradaki => 'Следующая смена';

  @override
  String get vardiyaSiradakiYok => 'Следующая смена не запланирована.';

  @override
  String get vardiyaBos => 'Не закрыта';

  @override
  String get vardiyaYeni => 'Новая смена';

  @override
  String get vardiyaKayitYok => 'На этой неделе смен не запланировано.';

  @override
  String get vardiyaPersonel => 'Сотрудник';

  @override
  String get vardiyaBaslangicTarihi => 'Дата начала';

  @override
  String get vardiyaBitisTarihi => 'Дата окончания';

  @override
  String get vardiyaBaslangicSaati => 'Время начала';

  @override
  String get vardiyaBitisSaati => 'Время окончания';

  @override
  String get vardiyaNot => 'Заметка';

  @override
  String get vardiyaEkleBilgi =>
      'Если указать диапазон дат, смена создаётся на каждый день диапазона. Если время окончания раньше времени начала (22:00–05:00), смена переходит на следующий день.';

  @override
  String get vardiyaEkleGonder => 'Добавить смены';

  @override
  String get vardiyaCakisanHaric => 'Добавить без конфликтных дней';

  @override
  String vardiyaCakisanGunler(int n) {
    return 'Конфликты в $n днях';
  }

  @override
  String get finansTahsilatBaslik => 'Приём оплаты';

  @override
  String get finansKisiGerekli => 'Выберите человека.';

  @override
  String get finansKasaGerekli => 'Выберите кассу.';

  @override
  String get finansTutarGerekli => 'Введите корректную сумму.';

  @override
  String get finansTahsilatKaydedildi => 'Оплата записана.';

  @override
  String get finansBorcluYok => 'Сейчас должников нет.';

  @override
  String get finansAlanTutar => 'Сумма';

  @override
  String get finansSutunKasa => 'Касса';

  @override
  String get finansAlanAciklama => 'Описание';

  @override
  String get finansMakbuzNotu =>
      'Номер квитанции и уведомление жильцу формируются на сервере — как и в веб-версии.';

  @override
  String finansGecikmeGun(int n) {
    return 'просрочка $n дн.';
  }

  @override
  String get finansGiderBaslik => 'Запись расхода';

  @override
  String get finansGiderKaydedildi => 'Расход записан.';

  @override
  String get finansGiderTuru => 'Тип расхода';

  @override
  String get finansOnayBekliyor => 'Отправить на утверждение';

  @override
  String get finansOnayBekliyorNotu =>
      'Расход, ожидающий утверждения, НЕ уменьшает остаток; уменьшит после утверждения.';

  @override
  String get finansFisEkle => 'Добавить фото чека';

  @override
  String get finansFisEklendi => 'Чек добавлен';

  @override
  String get finansFisYuklenemedi =>
      'Расход записан, но чек не удалось загрузить. Его можно добавить в веб-версии.';

  @override
  String get finansBorclularBaslik => 'Должники';

  @override
  String get finansTahsilatOrani => 'Собираемость';

  @override
  String get finansOranYok => 'За этот период начислений нет.';

  @override
  String finansOranDegeri(int oran, String donem) {
    return '$oran% · $donem';
  }

  @override
  String finansKovaDaire(int n) {
    return '$n помещ.';
  }

  @override
  String finansHatirlat(int n) {
    return 'Напомнить $n';
  }

  @override
  String finansHatirlatmaGonderildi(int n) {
    return 'Отправлено напоминаний: $n.';
  }

  @override
  String get personelEposta => 'Эл. почта';

  @override
  String get personelEpostaYardim =>
      'Приглашение и ссылка для пароля отправляются на этот адрес.';

  @override
  String get personelEpostaGerekli => 'Эл. почта обязательна.';

  @override
  String get personelEpostaGecersiz => 'Введите корректный адрес эл. почты.';

  @override
  String get sayacOkumaBaslik => 'Показания счётчиков';

  @override
  String get sayacKalem => 'Статья начисления';

  @override
  String get sayacAnaSayac => 'Главный счётчик';

  @override
  String get sayacDonem => 'Период (ГГГГ-ММ)';

  @override
  String get sayacAnaTuketim => 'Расход по главному счётчику';

  @override
  String get sayacBirimFiyat => 'Цена за единицу';

  @override
  String get sayacBorclandir => 'Начислить';

  @override
  String get sayacFotoEkle => 'Фото счётчика';

  @override
  String get sayacBolumYok =>
      'К этому главному счётчику не привязаны счётчики помещений.';

  @override
  String get sayacKalemGerekli => 'Выберите статью и главный счётчик.';

  @override
  String get sayacAnaTuketimGerekli => 'Введите расход по главному счётчику.';

  @override
  String get sayacBirimFiyatGerekli => 'Введите цену за единицу.';

  @override
  String get sayacDegerYok => 'Введите показание хотя бы для одного помещения.';

  @override
  String sayacDegerGecersiz(String daire) {
    return 'Значение для $daire некорректно.';
  }

  @override
  String sayacGeriSayiyor(String daire) {
    return '$daire: новое показание не может быть меньше предыдущего.';
  }

  @override
  String sayacOncekiOkuma(String deger) {
    return 'Предыдущее: $deger';
  }

  @override
  String sayacBorclandirildi(int n) {
    return 'Начисление выполнено. Пропущено помещений: $n';
  }

  @override
  String get ayarlarBildirimSesi => 'Звуковые уведомления';

  @override
  String get ayarlarBildirimSesiAciklama =>
      'Уведомления о жалобах и сменах приходят со звуком.';

  @override
  String get ayarlarBildirimSesiUyari =>
      'Звук отключён: вы можете не услышать напоминания о смене и уведомления о жалобах.';

  @override
  String get vardiyaCikar => 'Убрать';

  @override
  String get vardiyaCikarSebep => 'Причина снятия (болезнь, отпуск, срочность)';
}
