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
  String get sakinParolaSifirla => 'Сбросить пароль';

  @override
  String get sakinParolaSifirlaOnay => 'Сбросить пароль?';

  @override
  String sakinParolaSifirlaGovde(Object ad) {
    return 'Для \"$ad\" будет создан новый временный код; старый пароль перестанет работать. Пользователь входит по телефону + новому коду и задаёт пароль.';
  }

  @override
  String get sakinSifirla => 'Сбросить';

  @override
  String sakinYeniKodMesaji(Object ad) {
    return 'Новый временный код для \"$ad\". Передайте его жителю: он входит по телефону + этому коду и задаёт пароль.';
  }

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
  String get ortakCepTelefonu => 'Мобильный номер';

  @override
  String get ortakTelefonIpucu => 'напр. 0532 111 22 03';

  @override
  String get ortakTelefonZorunlu => 'Телефон обязателен';

  @override
  String get sakinGirisAnahtari => 'Ключ входа (глобально уникальный).';

  @override
  String get ortakDaireNoIpucu => 'напр. A-12';

  @override
  String get sakinDaireNoZorunlu => 'Номер квартиры обязателен';

  @override
  String get sakinParolaOpsiyonel => 'Пароль (необязательно)';

  @override
  String get sakinBosBirakKod => 'Оставьте пустым — будет создан временный код';

  @override
  String get sakinEklendiKod =>
      'Житель добавлен. Передайте ему этот код: он входит по телефону + этому коду и задаёт пароль.';

  @override
  String get sakinEklendi => 'Житель добавлен ✓';

  @override
  String get sakinYok => 'Жителей пока нет.\nДобавьте кнопкой справа снизу.';

  @override
  String get ortakGeciciKodBaslik => 'Временный код входа';

  @override
  String get ortakKopyala => 'Копировать';

  @override
  String get ortakKopyalandi => 'Скопировано';
}
