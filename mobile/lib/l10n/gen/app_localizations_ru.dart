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
  String devriyeNoktaSayaci(Object beklenen, Object okutulan) {
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
  String sureSaatDakika(Object dakika, Object saat) {
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
  String devriyeNoktaOkutuldu(Object beklenen, Object okutulan) {
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
}
