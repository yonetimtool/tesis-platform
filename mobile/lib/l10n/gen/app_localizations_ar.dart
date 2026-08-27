// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get cipYeni => 'جديد';

  @override
  String get cipAktif => 'نشطة';

  @override
  String get bolumVardiyaDurumu => 'حالة الورديات';

  @override
  String get bolumSonHareketler => 'آخر الأنشطة';

  @override
  String get bolumHizliOzet => 'ملخص سريع';

  @override
  String get bolumDuyurular => 'الإعلانات';

  @override
  String get bolumSiteKurallari => 'قواعد المجمع';

  @override
  String get bolumEtkinlikler => 'الأنشطة';

  @override
  String get bolumOdemeAidat => 'المدفوعات والرسوم';

  @override
  String get bolumTumModuller => 'جميع الوحدات';

  @override
  String get kartVardiyaDurum => 'الوردية';

  @override
  String get kartKargo => 'الشحنات';

  @override
  String get kartZiyaretci => 'الزوار';

  @override
  String get kartAracPlaka => 'المركبات';

  @override
  String get kartIhlaller => 'المخالفات';

  @override
  String get kartGorevlerim => 'مهامي';

  @override
  String get kartDemirbas => 'العهدة';

  @override
  String get kartTurlarim => 'دورياتي';

  @override
  String get kartTalepAriza => 'الطلبات';

  @override
  String get kartZiyaretciler => 'الزوار';

  @override
  String get kartKargolarim => 'شحناتي';

  @override
  String get kartAidatBilgileri => 'الرسوم';

  @override
  String get kartGurultuSikayeti => 'شكوى ضجيج';

  @override
  String get kartGeriBildirim => 'الملاحظات';

  @override
  String get kartSikayetlerim => 'شكاواي';

  @override
  String get kartSiteRaporlari => 'تقارير المجمع';

  @override
  String get kartGorevler => 'المهام';

  @override
  String get kartAidatDurumu => 'حالة الرسوم';

  @override
  String get kartOtoparkKullanimi => 'استخدام المواقف';

  @override
  String get kartSikayetler => 'الشكاوى';

  @override
  String get kartRaporlar => 'التقارير';

  @override
  String get kartYonetici => 'المدير';

  @override
  String get kartGonderimKuyrugu => 'قائمة الإرسال';

  @override
  String get etiketAylikOzet => 'ملخص شهري';

  @override
  String get etiketDevriye => 'دورية';

  @override
  String get etiketKurallar => 'القواعد';

  @override
  String get etiketIletisim => 'التواصل';

  @override
  String sayacAktif(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n وردية نشطة',
      many: '$n وردية نشطة',
      few: '$n ورديات نشطة',
      two: 'ورديتان نشطتان',
      one: 'وردية نشطة',
      zero: 'لا وردية نشطة',
    );
    return '$_temp0';
  }

  @override
  String sayacIceride(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n بالداخل',
      many: '$n شخصاً بالداخل',
      few: '$n أشخاص بالداخل',
      two: 'شخصان بالداخل',
      one: 'شخص واحد بالداخل',
      zero: 'لا أحد بالداخل',
    );
    return '$_temp0';
  }

  @override
  String sayacGiris(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n دخول',
      many: '$n دخولاً',
      few: '$n دخولات',
      two: 'دخولان',
      one: 'دخول واحد',
      zero: 'لا دخول',
    );
    return '$_temp0';
  }

  @override
  String sayacYeni(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n جديد',
      many: '$n جديداً',
      few: '$n جديدة',
      two: 'اثنان جديدان',
      one: 'واحد جديد',
      zero: 'لا جديد',
    );
    return '$_temp0';
  }

  @override
  String sayacAcik(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n مفتوح',
      many: '$n مفتوحاً',
      few: '$n مفتوحة',
      two: 'مفتوحان',
      one: 'مفتوح واحد',
      zero: 'لا يوجد مفتوح',
    );
    return '$_temp0';
  }

  @override
  String sayacZimmetli(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n عهدة',
      many: '$n عهدة',
      few: '$n عُهَد',
      two: 'عهدتان',
      one: 'عهدة واحدة',
      zero: 'لا عهدة',
    );
    return '$_temp0';
  }

  @override
  String sayacKayit(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n سجل',
      many: '$n سجلاً',
      few: '$n سجلات',
      two: 'سجلان',
      one: 'سجل واحد',
      zero: 'لا سجلات',
    );
    return '$_temp0';
  }

  @override
  String sayacYaklasan(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n قادم',
      many: '$n قادماً',
      few: '$n قادمة',
      two: 'اثنان قادمان',
      one: 'واحد قادم',
      zero: 'لا قادم',
    );
    return '$_temp0';
  }

  @override
  String sayacDaire(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n شقة',
      many: '$n شقة',
      few: '$n شقق',
      two: 'شقتان',
      one: 'شقة واحدة',
      zero: 'لا شقق',
    );
    return '$_temp0';
  }

  @override
  String sayacArac(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n مركبة',
      many: '$n مركبة',
      few: '$n مركبات',
      two: 'مركبتان',
      one: 'مركبة واحدة',
      zero: 'لا مركبات',
    );
    return '$_temp0';
  }

  @override
  String sayacGorevli(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n موظف',
      many: '$n موظفاً',
      few: '$n موظفين',
      two: 'موظفان',
      one: 'موظف واحد',
      zero: 'لا موظفين',
    );
    return '$_temp0';
  }

  @override
  String sayacBekleyen(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n بالانتظار',
      many: '$n بالانتظار',
      few: '$n بالانتظار',
      two: 'اثنان بالانتظار',
      one: 'واحد بالانتظار',
      zero: 'لا شيء بالانتظار',
    );
    return '$_temp0';
  }

  @override
  String get ozetToplamDaire => 'إجمالي الشقق';

  @override
  String get ozetToplamTahsilat => 'إجمالي المُحصَّل';

  @override
  String get ozetTahsilatOrani => 'نسبة تحصيل الرسوم';

  @override
  String get ozetOtoparkDoluluk => 'إشغال المواقف';

  @override
  String get ozetTumSite => 'المجمع بالكامل';

  @override
  String get ozetBuAy => 'هذا الشهر';

  @override
  String get ozetSuAn => 'الآن';

  @override
  String otoparkDoluKapasite(Object dolu, Object kapasite) {
    return '$dolu / $kapasite';
  }

  @override
  String yuzdeDeger(Object oran) {
    return '$oran٪';
  }

  @override
  String anaSelam(Object ad) {
    return 'مرحباً، $ad';
  }

  @override
  String get anaYoneticiPaneli => 'لوحة الإدارة';

  @override
  String anaDaireAltBaslik(Object daireler, Object rol) {
    return 'شقة $daireler  •  $rol';
  }

  @override
  String get anaDun => 'أمس';

  @override
  String get anaOnline => 'متصل';

  @override
  String get anaVardiyaAktif => 'نشطة';

  @override
  String get anaVardiyaPlanlandi => 'مجدولة';

  @override
  String get anaEtkinlikSuruyor => 'جارٍ';

  @override
  String get anaEtkinlikYaklasan => 'قادم';

  @override
  String get anaOdendi => 'مدفوع';

  @override
  String get anaOdenmedi => 'غير مدفوع';

  @override
  String get anaBorcVar => 'يوجد مستحق';

  @override
  String get anaBorcYok => 'لا مستحقات';

  @override
  String get anaBuAykiAidat => 'رسوم هذا الشهر';

  @override
  String anaSonOdemeTarih(Object tarih) {
    return 'آخر دفعة: $tarih';
  }

  @override
  String get anaGelecekOdeme => 'الدفعة القادمة';

  @override
  String get anaGecmisOdemeler => 'سجل المدفوعات';

  @override
  String get anaAidatKaydiYok => 'لا يوجد سجل رسوم';

  @override
  String get anaBildirimlerYakinda => 'الإشعارات قريباً';

  @override
  String get anaBildirimlerRolYok => 'الإشعارات غير متاحة لهذا الدور';

  @override
  String get anaRaporlarYakinda => 'التقارير قريباً';

  @override
  String get sekmeAnaSayfa => 'الرئيسية';

  @override
  String get sekmeBildirimler => 'الإشعارات';

  @override
  String get sekmeRaporlar => 'التقارير';

  @override
  String get sekmeSeffaflik => 'الشفافية';

  @override
  String get sekmeGorevlerim => 'مهامي';

  @override
  String get sekmeAyarlar => 'الإعدادات';

  @override
  String get kabukGrupGuvenlik => 'الأمن';

  @override
  String get kabukGrupTesis => 'المنشأة';

  @override
  String get kabukGrupFinans => 'المالية';

  @override
  String get kabukGrupIletisim => 'التواصل';

  @override
  String get kabukGrupTanimlar => 'التعريفات';

  @override
  String get kabukProfil => 'الملف الشخصي';

  @override
  String get kabukCikisYap => 'تسجيل الخروج';

  @override
  String get fabOlayBildir => 'الإبلاغ عن حادث';

  @override
  String get fabTalepBildir => 'طلب / إبلاغ';

  @override
  String get fabTalepArizaBildir => 'الإبلاغ عن طلب أو خلل';

  @override
  String get fabRezervasyonYap => 'إجراء حجز';

  @override
  String get fabDuyuruYayinla => 'نشر إعلان';

  @override
  String get fabGorevOlustur => 'إنشاء مهمة';

  @override
  String get fabDestekTalebi => 'طلب دعم';

  @override
  String get modulDuyurular => 'الإعلانات';

  @override
  String get modulTurlarim => 'دورياتي';

  @override
  String get modulDevriyeTakibi => 'متابعة الدوريات';

  @override
  String get modulGorevlerim => 'مهامي';

  @override
  String get modulGorevYonetimi => 'إدارة المهام';

  @override
  String get modulDemirbas => 'العهدة';

  @override
  String get modulNfcOkutma => 'قراءة NFC';

  @override
  String get modulGonderimKuyrugu => 'قائمة الإرسال';

  @override
  String get modulAylikRaporlar => 'التقارير الشهرية';

  @override
  String get modulButce => 'الموازنة';

  @override
  String get modulFinansalOzet => 'الملخص المالي';

  @override
  String get modulSeffaflik => 'الشفافية';

  @override
  String get modulSiteButcesi => 'موازنة المجمع';

  @override
  String get modulAidatim => 'رسومي';

  @override
  String get modulSikayetOneri => 'شكوى / اقتراح';

  @override
  String get modulZiyaretciler => 'الزوار';

  @override
  String get modulKargo => 'الشحنات';

  @override
  String get modulGoruntulemeIzni => 'إذن الاطّلاع';

  @override
  String get modulRezervasyon => 'الحجوزات';

  @override
  String get modulEtkinlikler => 'الأنشطة';

  @override
  String get modulSiteKurallari => 'قواعد المجمع';

  @override
  String get modulDisHizmetler => 'خدمات خارجية';

  @override
  String get modulEntegrasyonlar => 'التكاملات';

  @override
  String get modulPersonel => 'موظفو الميدان';

  @override
  String get modulSakinler => 'سكان المجمع';

  @override
  String get modulBinaYapisi => 'هيكل المبنى';

  @override
  String get modulSikayetHaritasi => 'خريطة الشكاوى';

  @override
  String get modulSikayetlerim => 'شكاواي';

  @override
  String get modulYoneticiIletisim => 'التواصل مع الإدارة';

  @override
  String get ortakKaydet => 'حفظ';

  @override
  String sayacBekliyor(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n بالانتظار',
      many: '$n عنصراً بالانتظار',
      few: '$n عناصر بالانتظار',
      two: 'عنصران بالانتظار',
      one: 'عنصر واحد بالانتظار',
      zero: 'لا شيء بالانتظار',
    );
    return '$_temp0';
  }

  @override
  String get ortakKaydediliyor => 'جارٍ الحفظ...';

  @override
  String get ortakVazgec => 'إلغاء';

  @override
  String get ortakSil => 'حذف';

  @override
  String get ortakDuzenle => 'تعديل';

  @override
  String get ortakEkle => 'إضافة';

  @override
  String get ortakTamam => 'حسناً';

  @override
  String get ortakKapat => 'إغلاق';

  @override
  String get ortakTumunuGor => 'عرض الكل';

  @override
  String get ortakYuklenemedi => 'تعذّر التحميل';

  @override
  String get ortakYenidenDene => 'إعادة المحاولة';

  @override
  String get ortakYakinda => 'قريباً';

  @override
  String get ortakBolumYakinda => 'هذا القسم قريباً';

  @override
  String get ortakBeklenmeyenHata =>
      'حدث خطأ غير متوقع. يُرجى المحاولة مرة أخرى.';

  @override
  String ortakZorunluAlan(Object alan) {
    return '$alan مطلوب';
  }

  @override
  String get ayarlarBaslik => 'الإعدادات';

  @override
  String get ayarlarTesis => 'المنشأة';

  @override
  String get ayarlarYonetim => 'الإدارة';

  @override
  String get ayarlarGorunum => 'المظهر';

  @override
  String get ayarlarTema => 'السمة';

  @override
  String get ayarlarTemaSistem => 'النظام';

  @override
  String get ayarlarTemaAcik => 'فاتح';

  @override
  String get ayarlarTemaKoyu => 'داكن';

  @override
  String get ayarlarTemaAciklama =>
      'تُطبَّق السمة الداكنة على جميع الشاشات؛ وخيار «النظام» يتبع إعداد الجهاز.';

  @override
  String get ayarlarTesisAdi => 'اسم المنشأة';

  @override
  String get ayarlarTesisAdiAciklama =>
      'الاسم الذي يظهر في الشاشة الرئيسية والتقارير.';

  @override
  String get ayarlarTesisAdiGuncellendi => 'تم تحديث اسم المنشأة';

  @override
  String get ayarlarKameralar => 'الكاميرات';

  @override
  String get ayarlarKameralarAlt => 'إضافة الكاميرات وتعديلها وحذفها';

  @override
  String get ayarlarDil => 'اللغة / Language';

  @override
  String get dilSecBaslik => 'لغة التطبيق';

  @override
  String get kameraBaslik => 'الكاميرات';

  @override
  String get kameraEkle => 'إضافة كاميرا';

  @override
  String get kameraYeni => 'كاميرا جديدة';

  @override
  String get kameraDuzenleBaslik => 'تعديل الكاميرا';

  @override
  String get kameraAd => 'الاسم';

  @override
  String get kameraKonum => 'الموقع (اختياري)';

  @override
  String get kameraTur => 'النوع';

  @override
  String get kameraUrl => 'رابط البث';

  @override
  String get kameraAktif => 'نشِطة';

  @override
  String get kameraAktifAlt => 'عند الإيقاف لا تظهر في أي قائمة';

  @override
  String get kameraSakinGorebilir => 'مرئية للسكان';

  @override
  String get kameraSakinGorebilirAlt => 'عند الإيقاف تراها الإدارة والأمن فقط';

  @override
  String get kameraRtspFormUyari =>
      'لا يمكن تشغيل بثوث RTSP داخل التطبيق حالياً. يُحفظ السجل، وستُضاف إمكانية التشغيل لاحقاً.';

  @override
  String get kameraUrlZorunlu => 'رابط البث مطلوب';

  @override
  String kameraUrlHataHttp(Object tur) {
    return 'يجب أن يبدأ رابط بث $tur بـ http:// أو https://';
  }

  @override
  String get kameraUrlHataRtsp => 'يجب أن يبدأ رابط بث RTSP بـ rtsp://';

  @override
  String get kameraSilBaslik => 'حذف الكاميرا';

  @override
  String kameraSilOnay(Object ad) {
    return 'هل تريد حذف «$ad»؟';
  }

  @override
  String get kameraBosYonetim =>
      'لا توجد كاميرات. يمكنك الإضافة من الأسفل يميناً.';

  @override
  String get kameraBosSakin => 'لا توجد كاميرات متاحة لك.';

  @override
  String get kameraListeHata => 'تعذّر تحميل الكاميرات.';

  @override
  String get kameraCanli => 'مباشر';

  @override
  String get kameraKareYok => 'تعذّر الحصول على الصورة';

  @override
  String get kameraUrlWebSayfasi =>
      'هذا عنوان صفحة ويب. يشغّل التطبيق روابط البث المباشرة فقط: ‎.m3u8‎ (HLS) أو ‎.mp4‎.';

  @override
  String get kameraKaynakYardim =>
      'تُشغَّل روابط الوسائط المباشرة فقط: HLS ‏(.m3u8) وMP4. صفحات الويب (يوتيوب، فيميو، صفحات العرض البلدية) لا يمكن تشغيلها. يُحفظ RTSP لكنه يحتاج بوابة HLS للتشغيل.';

  @override
  String get kameraSnapshot => 'عنوان اللقطة';

  @override
  String get kameraSnapshotAlt =>
      'اختياري. إذا حُدِّد، تعرض قائمة الكاميرات لقطة حيّة (إطار JPEG واحد).';

  @override
  String get kameraOynatilamiyor => 'غير قابلة للتشغيل';

  @override
  String get kameraYayinAcilamadi => 'تعذّر فتح البث';

  @override
  String get kameraYayinAcilamadiAlt =>
      'قد تكون الكاميرا مطفأة أو أن الشبكة لا تصل إلى البث.';

  @override
  String kameraTurEtiket(Object tur) {
    return 'النوع: $tur';
  }

  @override
  String get kameraRtspBilgi =>
      'لا يمكن تشغيل بثوث RTSP داخل التطبيق حالياً. السجل محفوظ في النظام، وستُضاف إمكانية التشغيل لاحقاً.';

  @override
  String get kameraSeritBaslik => 'كاميرا مباشرة';

  @override
  String anaKarsilama(String ad) {
    return 'مرحبًا، $ad';
  }

  @override
  String get gorevKategorilerTooltip => 'الفئات';

  @override
  String get gorevYeni => 'مهمة جديدة';

  @override
  String get gorevOlusturuldu => 'تم إنشاء المهمة ✓';

  @override
  String get gorevListesiYetkiYok =>
      'ليست لديك صلاحية لعرض قائمة المهام. هذه الشاشة متاحة لدوري النظافة والأمن.';

  @override
  String get gorevBuFiltredeYok => 'لا توجد مهام نشطة بهذا التصفية.';

  @override
  String get gorevCipBanaAtanan => 'المُسندة إليّ';

  @override
  String get gorevCipTumGorevler => 'كل المهام';

  @override
  String get gorevCipTumu => 'الكل';

  @override
  String get gorevKategoriDiger => 'أخرى';

  @override
  String gorevPlanlanan(Object zaman) {
    return 'المُقرَّر: $zaman';
  }

  @override
  String get gorevSanaAtanmis => 'مُسندة إليك';

  @override
  String get gorevFotoZorunlu => 'الصورة إلزامية';

  @override
  String get gorevTamamlandiZatenKayitli => 'تم الإنجاز ✓ (كان مسجّلاً بالفعل)';

  @override
  String get gorevTamamlandiBuOturumda => 'تم الإنجاز ✓ (في هذه الجلسة)';

  @override
  String get gorevIslemleriTooltip => 'إجراءات المهمة';

  @override
  String get gorevTakipGorunumu => 'عرض المتابعة';

  @override
  String get gorevTakipGorunumuAlt =>
      'يتم الإنجاز بواسطة العاملين الميدانيين (الأمن / مسؤول المنشأة). هذه الشاشة للمتابعة فقط.';

  @override
  String get gorevGonderiliyor => 'جارٍ الإرسال...';

  @override
  String get gorevTamamla => 'إنجاز';

  @override
  String get gorevGuncellendi => 'تم تحديث المهمة ✓';

  @override
  String get gorevSilinsinMi => 'هل تُحذف المهمة؟';

  @override
  String get gorevSilindi => 'تم حذف المهمة ✓';

  @override
  String get gorevNfcAciklama =>
      'هذه المهمة موثّقة بـ NFC: امسح الوسم عند نقطة المهمة قبل الإنجاز.';

  @override
  String get gorevAdim1Etiket => '١. امسح الوسم';

  @override
  String gorevOkundu(Object uid) {
    return 'تم المسح: $uid';
  }

  @override
  String get gorevEtiketBekleniyor => 'في انتظار الوسم...';

  @override
  String get gorevYenidenOkut => 'امسح مرة أخرى';

  @override
  String get gorevEtiketiOkut => 'امسح الوسم';

  @override
  String get gorevAdim2Foto => '٢. إثبات بالصورة';

  @override
  String get gorevAdim2FotoOpsiyonel => '٢. إثبات بالصورة (اختياري)';

  @override
  String get gorevYukleniyorNokta => 'جارٍ التحميل...';

  @override
  String get gorevYuklendi => 'تم التحميل ✓';

  @override
  String get gorevKamera => 'الكاميرا';

  @override
  String get gorevYenidenCek => 'أعد التصوير';

  @override
  String get gorevGaleridenSec => 'اختر من المعرض';

  @override
  String get gorevTekrarYukle => 'أعد التحميل';

  @override
  String get gorevKaldir => 'إزالة';

  @override
  String get gorevAdim3Not => '٣. ملاحظة (اختياري)';

  @override
  String get gorevNotIpucu => 'مثال: تم تفريغ حاويات النفايات';

  @override
  String get gorevZatenKayitliydi =>
      'هذا الإنجاز كان مسجّلاً بالفعل (إعادة إرسال — لم يُنشأ سجل مكرّر).';

  @override
  String get gorevTamamlandiKayit => 'تم إنجاز المهمة — أُنشئ السجل.';

  @override
  String gorevZaman(Object zaman) {
    return 'الوقت: $zaman';
  }

  @override
  String get gorevFotoKanitiVar => 'يوجد إثبات بالصورة';

  @override
  String get gorevNfcDogrulandi => 'تم التحقق بـ NFC';

  @override
  String get gorevYeniTamamlamaBaslat => 'بدء إنجاز جديد';

  @override
  String get gorevDuzenleBaslik => 'تعديل المهمة';

  @override
  String get gorevKategoriSilinmis => 'الفئة (محذوفة)';

  @override
  String get gorevAtananListedeDegil => 'المستخدم المُسند إليه (غير مدرج)';

  @override
  String get gorevTipleriYukleniyor => 'جارٍ تحميل أنواع المهام...';

  @override
  String get gorevTipi => 'نوع المهمة';

  @override
  String get gorevTipiYokUyari =>
      'لم تُعرّف أي نوع مهمة بعد. يمكنك إضافة أنواعك من شاشة \"الفئات\" أعلاه؛ يُستخدم \"أخرى\" في الوقت الحالي.';

  @override
  String get gorevAdi => 'اسم المهمة';

  @override
  String get gorevAdiZorunlu => 'اسم المهمة مطلوب';

  @override
  String get gorevAciklamaOpsiyonel => 'الوصف (اختياري)';

  @override
  String get gorevPersonelYukleniyor => 'جارٍ تحميل قائمة العاملين...';

  @override
  String get gorevAtananPersonel => 'العامل المُسند';

  @override
  String get gorevAtanmamisHavuz => '— غير مُسندة (مهمة مشتركة) —';

  @override
  String gorevPersonelAlinamadi(Object hata) {
    return 'تعذّر جلب قائمة العاملين: $hata';
  }

  @override
  String get gorevKontrolNoktasiOpsiyonel => 'نقطة تفتيش (NFC) — اختياري';

  @override
  String get gorevKontrolNoktasiYardim =>
      'إذا تم الربط، تُنجَز المهمة بمسح NFC';

  @override
  String get gorevNfcYok => '— بدون NFC —';

  @override
  String get gorevPeriyotDakika => 'الدورية بالدقائق (اختياري)';

  @override
  String get gorevPeriyotYardim => 'للمهام الدورية؛ فارغ = مرة واحدة';

  @override
  String get gorevPozitifSayi => 'أدخل عدداً صحيحاً موجباً';

  @override
  String get gorevFotoKanitiZorunlu => 'إثبات بالصورة إلزامي';

  @override
  String get gorevFotoKanitiZorunluAlt => 'لا يُقبل الإنجاز بدون صورة';

  @override
  String get gorevPasifAciklama => 'المهمة غير النشطة لا تظهر في القائمة';

  @override
  String get gorevKategorileriBaslik => 'فئات المهام';

  @override
  String get gorevKategoriYeni => 'فئة جديدة';

  @override
  String get gorevKategoriAdi => 'اسم الفئة';

  @override
  String get gorevKategoriAdiIpucu => 'مثال: صيانة المسبح';

  @override
  String gorevKategoriEklendi(Object ad) {
    return 'تمت إضافة \"$ad\"';
  }

  @override
  String gorevKategoriEklenemedi(Object hata) {
    return 'تعذّرت الإضافة: $hata';
  }

  @override
  String get gorevKategoriSilinsinMi => 'هل تُحذف الفئة؟';

  @override
  String gorevKategoriSilOnay(Object ad) {
    return 'سيتم تعطيل \"$ad\"؛ يُحفظ سجل المهام الحالية، ولا يمكن اختيارها للمهام الجديدة.';
  }

  @override
  String gorevKategoriSilindi(Object ad) {
    return 'تم حذف \"$ad\"';
  }

  @override
  String gorevKategoriSilinemedi(Object hata) {
    return 'تعذّر الحذف: $hata';
  }

  @override
  String gorevKategoriListeAlinamadi(Object hata) {
    return 'تعذّر جلب القائمة: $hata';
  }

  @override
  String get gorevKategoriYokBos =>
      'لا توجد فئات بعد. أضف واحدة عبر \"فئة جديدة\" حتى يمكن اختيارها عند إنشاء مهمة.';

  @override
  String get gorevOncelikDusuk => 'منخفضة';

  @override
  String get gorevOncelikOrta => 'متوسطة';

  @override
  String get gorevOncelikYuksek => 'عالية';

  @override
  String get gorevOncelik => 'الأولوية';

  @override
  String get gorevTaleptenGeldi => 'من طلب';

  @override
  String get gorevBagliTalep => 'الطلب المرتبط';

  @override
  String gorevDaireEtiket(Object daire) {
    return 'الوحدة $daire';
  }

  @override
  String get talepDurumAcik => 'مفتوح';

  @override
  String get talepDurumIsEmri => 'أمر عمل';

  @override
  String get talepDurumCozuldu => 'تم الحل';

  @override
  String get talepDurumReddedildi => 'مرفوض';

  @override
  String get gorevEtiketOkunamadi => 'تعذّر قراءة الوسم.';

  @override
  String get gorevFotoOnlineGerekli =>
      'يلزم اتصال بالإنترنت لتحميل الصورة (عنوان التحميل قصير الأجل). عند عودة الاتصال، استخدم \"أعد التحميل\".';

  @override
  String gorevFotoAlinamadi(Object hata) {
    return 'تعذّر الحصول على الصورة: $hata';
  }

  @override
  String get gorevFotoOnlineGerekliKisa =>
      'يلزم اتصال بالإنترنت لتحميل الصورة.';

  @override
  String get gorevFotoZorunluUyari =>
      'الإثبات بالصورة إلزامي لهذه المهمة. صوّر وحمّل الصورة قبل الإنجاز.';

  @override
  String get gorevFotoHenuzYuklenmedi =>
      'لم تُحمَّل الصورة بعد. انتظر انتهاء التحميل، أو جرّب \"أعد التحميل\"، أو أزل الصورة.';

  @override
  String get gorevTamamlamaOfflineUyari =>
      'تعذّر إرسال الإنجاز — يلزم اتصال بالإنترنت. عند عودة الاتصال اضغط \"إنجاز\" مرة أخرى؛ لن يتكرر السجل نفسه (مفتاح Idempotency ثابت). الإنجاز مع صورة غير مدعوم دون اتصال (قيد معروف).';

  @override
  String get rolAdmin => 'مدير المنصة';

  @override
  String get rolYonetici => 'مدير الموقع';

  @override
  String get rolGuvenlik => 'الأمن';

  @override
  String get rolTesisGorevlisi => 'مسؤول المنشأة';

  @override
  String get rolSakin => 'ساكن';

  @override
  String get rolBilinmeyen => 'دور غير معروف';

  @override
  String get ortakOlustur => 'إنشاء';

  @override
  String get ortakGuncelle => 'تحديث';

  @override
  String get ortakYenile => 'تحديث';

  @override
  String get devriyeGonderimKuyruguTooltip => 'قائمة الإرسال';

  @override
  String get sekmeGecmis => 'السجل';

  @override
  String get devriyeYetkiYok =>
      'ليست لديك صلاحية للبيانات في هذه الشاشة. متابعة الدورية متاحة لدور الأمن (والمدير).';

  @override
  String devriyeSonGuncelleme(Object saat) {
    return 'آخر تحديث: $saat (تحديث تلقائي: ٦٠ ثانية)';
  }

  @override
  String get devriyeTuru => 'دورية';

  @override
  String devriyeBitisEtiket(Object saat) {
    return 'الانتهاء $saat';
  }

  @override
  String devriyePencere(Object baslangic, Object bitis) {
    return 'النافذة: $baslangic – $bitis';
  }

  @override
  String devriyeNoktaSayaci(Object okutulan, Object beklenen) {
    return '$okutulan/$beklenen نقطة';
  }

  @override
  String get devriyeTumNoktalarOkutuldu =>
      'تم مسح جميع النقاط — الدورية تُستكمل. ✓';

  @override
  String devriyeSunucudaOkutma(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n عملية مسح مسجّلة على الخادم (قد تتضمن مسح أجهزة أخرى).',
      many: '$n عملية مسح مسجّلة على الخادم (قد تتضمن مسح أجهزة أخرى).',
      few: '$n عمليات مسح مسجّلة على الخادم (قد تتضمن مسح أجهزة أخرى).',
      two: 'عمليتا مسح مسجّلتان على الخادم (قد تتضمن مسح أجهزة أخرى).',
      one: 'عملية مسح واحدة مسجّلة على الخادم (قد تتضمن مسح أجهزة أخرى).',
      zero: 'لا توجد عمليات مسح مسجّلة على الخادم.',
    );
    return '$_temp0';
  }

  @override
  String get devriyeNoktaOkutNfc => 'امسح نقطة (NFC)';

  @override
  String get devriyeBugununDigerTurlari => 'دوريات اليوم الأخرى';

  @override
  String get devriyeBugununTurlari => 'دوريات اليوم';

  @override
  String get devriyeDurumTamamlandi => 'مُنجزة';

  @override
  String get devriyeDurumKacirildi => 'فائتة';

  @override
  String get devriyeDurumSimdiAktif => 'نشطة الآن';

  @override
  String get devriyeDurumYaklasan => 'قادمة';

  @override
  String get devriyeDurumBitti => 'انتهت';

  @override
  String get devriyeDurumBekliyor => 'بالانتظار';

  @override
  String get devriyeDurumBilinmiyor => 'غير معروف';

  @override
  String get devriyeDurumSuresiGecti => 'انقضى الوقت';

  @override
  String get devriyeBugunTurYok => 'لا توجد دورية لهذا اليوم.';

  @override
  String get devriyeNoktaListesiYok =>
      'تعذّر جلب قائمة نقاط هذه الخطة أو لم تُسند نقاط للخطة.';

  @override
  String get devriyeKontrolNoktalari => 'نقاط التفتيش';

  @override
  String get devriyeNoktaDurumAciklama =>
      'حالات النقاط تأتي من الخادم؛ تظهر عمليات مسح جميع العاملين بعلامة ✓. الصفوف \"قيد الإرسال\" هي عمليات مسح من هذا الجهاز لم تُرسل بعد.';

  @override
  String devriyeNoktaAdiYedek(Object kisaId) {
    return 'النقطة $kisaId';
  }

  @override
  String get devriyeOkutuldu => 'تم المسح ✓';

  @override
  String devriyeOkutulduZamanli(Object saat) {
    return 'تم المسح ✓ · $saat';
  }

  @override
  String get devriyeOkutulduGonderiliyor =>
      'تم المسح ✓ — قيد الإرسال (في القائمة)';

  @override
  String get devriyePencereSuresiDoldu => 'انقضت مدة النافذة.';

  @override
  String devriyeKalanSure(Object sure) {
    return 'الوقت المتبقي: $sure';
  }

  @override
  String sureSaatDakika(Object saat, Object dakika) {
    return '$saat س $dakika د';
  }

  @override
  String sureDakikaSaniye(Object dakika, Object saniye) {
    return '$dakika د $saniye ث';
  }

  @override
  String sureSaniye(Object saniye) {
    return '$saniye ث';
  }

  @override
  String get devriyeGecmisYetkiYok =>
      'ليست لديك صلاحية لسجل الدوريات. هذه القائمة متاحة لدوري الأمن والمدير.';

  @override
  String get devriyeGecmisBos => 'لا توجد سجلات نوافذ دوريات بعد.';

  @override
  String get devriyeOzetToplam => 'الإجمالي';

  @override
  String get devriyePlanlariBaslik => 'خطط الدوريات';

  @override
  String get devriyePlanEkle => 'إضافة خطة';

  @override
  String get devriyePlanlarListelenemedi => 'تعذّر عرض الخطط.';

  @override
  String devriyePlanAralik(Object baslangic, Object bitis, Object dakika) {
    return '$baslangic–$bitis · كل $dakika د';
  }

  @override
  String get devriyePasif => 'غير نشط';

  @override
  String get devriyePlanSilinsinMi => 'هل تُحذف الخطة؟';

  @override
  String devriyePlanSilOnay(Object ad) {
    return 'سيتم حذف خطة الدورية \"$ad\".';
  }

  @override
  String get devriyePlanSilindi => 'تم حذف الخطة ✓';

  @override
  String get devriyePlanDuzenleBaslik => 'تعديل خطة الدورية';

  @override
  String get devriyePlanYeniBaslik => 'خطة دورية جديدة';

  @override
  String get devriyePlanAdi => 'اسم الخطة';

  @override
  String get devriyePlanAdiIpucu => 'مثال: دورية ليلية';

  @override
  String get devriyeAdZorunlu => 'الاسم مطلوب';

  @override
  String devriyeBaslangicSaat(Object saat) {
    return 'البداية $saat';
  }

  @override
  String devriyeBitisSaat(Object saat) {
    return 'النهاية $saat';
  }

  @override
  String get devriyeTurSikligi => 'تكرار الدورية (دقائق)';

  @override
  String get devriyeTurSikligiYardim => 'مثال: ٦٠ = دورية كل ساعة';

  @override
  String get devriyeTurSikligiPozitif =>
      'يجب أن يكون تكرار الدورية (د) موجباً.';

  @override
  String get devriyeTumunuKaldir => 'إزالة الكل';

  @override
  String get devriyeTumunuSec => 'تحديد الكل';

  @override
  String get devriyeAktifNoktaYok =>
      'لا توجد نقاط تفتيش نشطة. أضف واحدة من \"نقاط التفتيش\" أولاً.';

  @override
  String devriyeUidEtiket(Object uid) {
    return 'المعرّف: $uid';
  }

  @override
  String get devriyeKaydedilemedi => 'تعذّر الحفظ. حاول مرة أخرى.';

  @override
  String get devriyePlanYokBos =>
      'لا توجد خطط دوريات بعد.\nأضف واحدة من أسفل اليمين (الساعات + النقاط).';

  @override
  String get devriyeTakibiBaslik => 'متابعة الدوريات';

  @override
  String get sekmeBugun => 'اليوم';

  @override
  String get sekmeTaramaGunlugu => 'سجل المسح';

  @override
  String get devriyeTakibiYetkiYok =>
      'ليست لديك صلاحية لمتابعة الدوريات. هذه الشاشة متاحة لدوري المدير والأمن.';

  @override
  String get devriyeBugunPencereYok => 'لا توجد نافذة دورية مجدولة لهذا اليوم.';

  @override
  String devriyeNoktaOkutuldu(Object okutulan, Object beklenen) {
    return 'تم مسح $okutulan/$beklenen نقطة';
  }

  @override
  String get devriyeTaramaGunluguAlinamadi => 'تعذّر جلب سجل المسح.';

  @override
  String get devriyeGunOkutmaYok => 'لا توجد عمليات مسح لهذا اليوم.';

  @override
  String get devriyeImzali => 'موقَّع ✓';

  @override
  String devriyeOkutmaBekliyor(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n عملية مسح بانتظار الإرسال',
      many: '$n عملية مسح بانتظار الإرسال',
      few: '$n عمليات مسح بانتظار الإرسال',
      two: 'عمليتا مسح بانتظار الإرسال',
      one: 'عملية مسح واحدة بانتظار الإرسال',
      zero: 'لا توجد عمليات مسح بانتظار الإرسال',
    );
    return '$_temp0';
  }

  @override
  String get ortakIptal => 'إلغاء';

  @override
  String get ortakNotOpsiyonel => 'ملاحظة (اختياري)';

  @override
  String get binaDuzenlemeBaslik => 'تخطيط المبنى';

  @override
  String get binaBlokTile => 'مبنى';

  @override
  String get binaBlokAtanmamis => 'لم يُعيَّن مبنى';

  @override
  String binaBlokEtiket(Object ad) {
    return 'المبنى $ad';
  }

  @override
  String get binaSaltGoruntulemeAciklama =>
      'هيكل المبنى (للعرض فقط). اضغط على مربّع المبنى لرؤية توزيع الطوابق والوحدات.';

  @override
  String get binaDuzenlemeAciklama =>
      'أضف مبنى، ثم اضغط على المربّع وضع الطوابق والوحدات داخله. كل وحدة مرتبطة بمبنى. تعكس خريطة الشكاوى هذا الهيكل.';

  @override
  String binaDaireSayisi(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n وحدة',
      many: '$n وحدة',
      few: '$n وحدات',
      two: 'وحدتان',
      one: 'وحدة واحدة',
      zero: 'لا وحدات',
    );
    return '$_temp0';
  }

  @override
  String get binaKayitsiz => 'غير مسجّل';

  @override
  String get binaBloksuzDairelerSalt => 'وحدات غير معيَّنة لمبنى (للعرض فقط).';

  @override
  String binaBlokYerlesimSalt(Object ad) {
    return 'المبنى $ad — توزيع الطوابق والوحدات (للعرض فقط).';
  }

  @override
  String get binaBloksuzUyari =>
      'هذه الوحدات غير معيَّنة لمبنى (سجلات قديمة). تُعرض ويمكن تعديلها أو حذفها؛ لوحدة جديدة اختر مبنى أو أنشئه.';

  @override
  String binaBlokYerlesimYardim(Object ad) {
    return 'المبنى $ad — أضف طوابق ثم أضف وحدات بزر \"+\" لكل طابق. تُصفّ وحدات الطابق نفسه جنباً إلى جنب.';
  }

  @override
  String get binaKatEkle => 'إضافة طابق';

  @override
  String get binaTopluDaireEkle => 'إضافة وحدات بالجملة';

  @override
  String get binaBloktaDaireYok => 'لا توجد وحدات في هذا المبنى بعد.';

  @override
  String get binaKatYokBos =>
      'لا توجد طوابق بعد. ابدأ بـ \"إضافة طابق\"، ثم أضف وحدات بـ \"+\" في الطابق.';

  @override
  String get binaKatYok => 'بدون طابق';

  @override
  String binaKatEtiket(Object kat) {
    return 'الطابق $kat';
  }

  @override
  String binaBlokDuzenleBaslik(Object ad) {
    return 'المبنى $ad — تعديل';
  }

  @override
  String get binaBloguSil => 'حذف المبنى';

  @override
  String binaBloguSilAlt(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'يُحذف مع $n وحدة (يلزم تأكيد)',
      many: 'يُحذف مع $n وحدة (يلزم تأكيد)',
      few: 'يُحذف مع $n وحدات (يلزم تأكيد)',
      two: 'يُحذف مع وحدتين (يلزم تأكيد)',
      one: 'يُحذف مع وحدة واحدة (يلزم تأكيد)',
      zero: 'يُحذف (يلزم تأكيد)',
    );
    return '$_temp0';
  }

  @override
  String binaBlokSilinsinMi(Object ad) {
    return 'هل يُحذف المبنى $ad؟';
  }

  @override
  String binaBlokVeDaireSilindi(Object ad, Object n) {
    return 'تم حذف المبنى $ad و$n وحدة.';
  }

  @override
  String binaBlokSilindi(Object ad) {
    return 'تم حذف المبنى $ad.';
  }

  @override
  String binaBlokSilinemedi(Object hata) {
    return 'تعذّر حذف المبنى: $hata';
  }

  @override
  String get binaBlokSilinemediGenel => 'تعذّر حذف المبنى. حاول مرة أخرى.';

  @override
  String binaKaliciSilmeUyari(Object n) {
    return 'سيُحذف هذا المبنى و$n وحدة داخله نهائياً مع سجلات الرسوم والزوار والشحنات والحجوزات والشكاوى. لا يمكن التراجع عن هذه العملية.';
  }

  @override
  String get binaOnayIcinBlokAdi => 'اكتب اسم المبنى للتأكيد';

  @override
  String binaSilNDaire(Object n) {
    return 'حذف ($n وحدة)';
  }

  @override
  String get binaBlokEtiketiGerekli => 'مطلوب رمز المبنى (مثال: A، B1).';

  @override
  String get binaBlokEtiketiZatenVar => 'رمز المبنى هذا مسجّل بالفعل.';

  @override
  String get binaBlokDuzenle => 'تعديل المبنى';

  @override
  String get binaYeniBlok => 'مبنى جديد';

  @override
  String get binaBlokEtiketi => 'رمز المبنى';

  @override
  String get binaBlokEtiketiYardim =>
      'أحرف وأرقام قصيرة (مثال: A، B1) — بدون شرطة';

  @override
  String get binaDaireNoGerekli => 'مطلوب رقم الوحدة (مثال: A-12، 12).';

  @override
  String get binaKatSiraTamSayi => 'يجب أن يكون الطابق والترتيب أعداداً صحيحة.';

  @override
  String get binaDaireNoZatenVar => 'رقم الوحدة هذا مسجّل بالفعل.';

  @override
  String binaDaireDuzenleBaslik(Object no) {
    return 'الوحدة $no — تعديل';
  }

  @override
  String binaYeniDaire(Object blok) {
    return 'وحدة جديدة · $blok';
  }

  @override
  String get binaDaireNo => 'رقم الوحدة';

  @override
  String get binaDaireNoYardim => 'أحرف وأرقام + شرطة (مثال: A-12، B3، 12)';

  @override
  String get binaSira => 'الترتيب';

  @override
  String get binaSiraYardim => 'الموضع في الطابق';

  @override
  String binaEnFazla500(Object n) {
    return '٥٠٠ وحدة كحد أقصى (حالياً $n).';
  }

  @override
  String binaTopluOnizleme(
    Object bas,
    Object bitis,
    Object toplam,
    Object kat,
    Object adet,
  ) {
    return '$bas … $bitis  ($toplam وحدة، $kat طابق × $adet)';
  }

  @override
  String get binaTopluAlanlarGerekli =>
      'مطلوب عدد الطوابق وعدد الوحدات لكل طابق ورقم البداية.';

  @override
  String get binaTekSeferde500 => '٥٠٠ وحدة كحد أقصى في المرة.';

  @override
  String binaAtlananEk(Object n) {
    return ' ($n موجودة مسبقاً، تم تخطيها)';
  }

  @override
  String binaDaireEklendi(Object n, Object ek) {
    return 'تمت إضافة $n وحدة ✓$ek';
  }

  @override
  String get binaEklenemedi => 'تعذّرت الإضافة. حاول مرة أخرى.';

  @override
  String binaTopluBaslik(Object blok) {
    return 'إضافة وحدات بالجملة — المبنى $blok';
  }

  @override
  String get binaTopluBaslikBloksuz => 'إضافة وحدات بالجملة — بدون مبنى';

  @override
  String get binaTopluAciklama =>
      'تتسلسل الأرقام من البداية وتُملأ طابقاً بطابق. تُتخطّى الأرقام الموجودة.';

  @override
  String get binaKatSayisi => 'عدد الطوابق';

  @override
  String get binaKatBasinaDaire => 'وحدات لكل طابق';

  @override
  String get binaBaslangicNo => 'رقم البداية';

  @override
  String get binaBaslangicNoIpucu => 'مثال: ١٠١';

  @override
  String get binaDaireleriOlustur => 'إنشاء الوحدات';

  @override
  String get binaSilinemedi => 'تعذّر الحذف. حاول مرة أخرى.';

  @override
  String get binaKaydedilemedi => 'تعذّر الحفظ. حاول مرة أخرى.';

  @override
  String get semaDaireYok => 'لا توجد وحدات بعد.';

  @override
  String get semaYogunluk => 'الكثافة:';

  @override
  String get semaYerlesimAciklama =>
      'توزيع المبنى. تُعرض كثافة الشكاوى للإدارة فقط.';

  @override
  String get semaYerlesimGirilmemis => 'لم يُدخل التوزيع على الخريطة';

  @override
  String semaDaireEtiket(Object no) {
    return 'الوحدة $no';
  }

  @override
  String semaAcikSikayet(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n شكوى مفتوحة',
      many: '$n شكوى مفتوحة',
      few: '$n شكاوى مفتوحة',
      two: 'شكويان مفتوحتان',
      one: 'شكوى مفتوحة واحدة',
      zero: 'لا شكاوى مفتوحة',
    );
    return '$_temp0';
  }

  @override
  String get semaBuDaireSikayetlerim => 'شكاواك بشأن هذه الوحدة';

  @override
  String get semaYogunlukYonetim => 'تُعرض كثافة الشكاوى للإدارة فقط.';

  @override
  String get semaBuDaireyiSikayetEt => 'الإبلاغ عن هذه الوحدة';

  @override
  String get semaSikayetIletildi => 'تم إرسال شكواك.';

  @override
  String get semaSikayetlerYuklenemedi => 'تعذّر تحميل الشكاوى.';

  @override
  String get semaAcikSikayetYok => 'لا توجد شكاوى مفتوحة لهذه الوحدة.';

  @override
  String get semaSikayetlerimYuklenemedi => 'تعذّر تحميل شكاواك.';

  @override
  String get semaSikayetimYok => 'ليست لديك شكاوى بشأن هذه الوحدة.';

  @override
  String get semaYonetimeIletildi => 'أُرسلت إلى الإدارة';

  @override
  String get semaKapatildi => 'مُغلقة';

  @override
  String get semaHaftalikSinir =>
      'يمكنك تقديم شكوى واحدة كحد أقصى أسبوعياً بهذا الشأن لهذه الوحدة.';

  @override
  String get semaKendiBlok => 'يمكنك الإبلاغ عن وحدات في مبناك فقط.';

  @override
  String get semaGonderilemedi => 'تعذّر الإرسال. حاول مرة أخرى.';

  @override
  String semaSikayetEtBaslik(Object no) {
    return 'الوحدة $no — إبلاغ';
  }

  @override
  String get semaSikayetAnonimNot =>
      'تُرسل شكواك إلى الإدارة؛ ولا تُعرض على جيرانك.';

  @override
  String get semaSikayetiGonder => 'إرسال الشكوى';

  @override
  String get kategoriGurultu => 'ضجيج';

  @override
  String get kategoriKapiOnuAyakkabi => 'أمام الباب / أحذية';

  @override
  String get kategoriZararVerme => 'إحداث ضرر';

  @override
  String talepSekmeAcik(Object n) {
    return 'مفتوح ($n)';
  }

  @override
  String talepSekmeIsEmri(Object n) {
    return 'أمر عمل ($n)';
  }

  @override
  String talepSekmeCozulen(Object n) {
    return 'محلولة ($n)';
  }

  @override
  String talepSekmeReddedilen(Object n) {
    return 'مرفوضة ($n)';
  }

  @override
  String get talepYeni => 'طلب جديد';

  @override
  String get talepAcikYokSakin =>
      'ليست لديك طلبات مفتوحة. استخدم \"طلب جديد\" لإرسال طلبك أو عطلك.';

  @override
  String get talepAcikYok => 'لا توجد طلبات مفتوحة.';

  @override
  String get talepIsEmriYok => 'لا توجد طلبات حُوّلت إلى أمر عمل.';

  @override
  String get talepCozulenYok => 'لا توجد طلبات محلولة بعد.';

  @override
  String get talepReddedilenYok => 'لا توجد طلبات مرفوضة.';

  @override
  String get talepIletildi => 'تم إرسال طلبك ✓';

  @override
  String get talepDurumGecmisi => 'سجل الحالة';

  @override
  String get talepGorselYuklenemedi => 'تعذّر تحميل الصورة';

  @override
  String get talepIsEmriAtandi => 'مُسند';

  @override
  String get talepIsEmriTamamlandi => 'مُنجز';

  @override
  String get talepIsEmriDurumBilinmiyor => 'الحالة غير معروفة';

  @override
  String get talepIsEmri => 'أمر عمل';

  @override
  String get talepYeniBaslik => 'طلب / عطل جديد';

  @override
  String get talepBaslikAlan => 'العنوان';

  @override
  String get talepBaslikZorunlu => 'العنوان مطلوب';

  @override
  String get talepAciklamaAlan => 'الوصف';

  @override
  String get talepAciklamaZorunlu => 'الوصف مطلوب';

  @override
  String get talepGonder => 'إرسال';

  @override
  String get talepKategoriOpsiyonel => 'الفئة (اختياري)';

  @override
  String get talepKategoriYok =>
      'لا توجد فئات معرّفة؛ سيُفتح الطلب كـ \"أخرى\".';

  @override
  String get talepGorseller => 'الصور (اختياري، ٣ كحد أقصى)';

  @override
  String get talepYoneticiIslemleri => 'إجراءات المدير';

  @override
  String get talepIsEmrineDonusturuldu => 'تم تحويل الطلب إلى أمر عمل ✓';

  @override
  String get talepIsEmrineDonusturBuyuk => 'تحويل إلى أمر عمل';

  @override
  String get talepCozuldu => 'تم حل الطلب ✓';

  @override
  String get talepCoz => 'حل';

  @override
  String get talepReddedildiBildirim => 'تم رفض الطلب ✓';

  @override
  String get talepReddet => 'رفض';

  @override
  String get talepReddediliyor => 'جارٍ الرفض...';

  @override
  String get talepPersonelAlinamadiKisa => 'تعذّر جلب قائمة العاملين.';

  @override
  String get talepIsEmrineDonustur => 'تحويل إلى أمر عمل';

  @override
  String get talepAtanabilirPersonelYok =>
      'لا يوجد عاملون ميدانيون نشطون للإسناد. أضف أولاً أمناً أو مسؤول منشأة لتتمكن من التحويل.';

  @override
  String get talepDonusturuluyor => 'جارٍ التحويل...';

  @override
  String get talepDonustur => 'تحويل';

  @override
  String get talepReddetBaslik => 'رفض الطلب';

  @override
  String get talepRetSebebiNot => 'يظهر سبب الرفض لمقدّم الطلب في سجل الحالة.';

  @override
  String get talepRetSebebi => 'سبب الرفض';

  @override
  String get talepCozBaslik => 'حل الطلب';

  @override
  String get talepCozNot => 'يُعلَّم الطلب كمحلول مباشرة دون إنشاء أمر عمل.';

  @override
  String get talepCozumNotu => 'ملاحظة الحل (اختياري)';

  @override
  String get talepKategorilerYuklenemedi => 'تعذّر تحميل الفئات.';

  @override
  String get talepFotoYuklenemedi => 'تعذّر تحميل الصورة.';

  @override
  String get binaKat => 'الطابق';

  @override
  String get binaKatYardim => '٠ = الطابق الأرضي';

  @override
  String get binaBloksuz => 'بدون مبنى';

  @override
  String get talepAcanSakin => 'ساكن';

  @override
  String rezSekmeRezervasyonlar(Object n) {
    return 'الحجوزات ($n)';
  }

  @override
  String rezSekmeAlanlar(Object n) {
    return 'المناطق ($n)';
  }

  @override
  String get rezYokSakin =>
      'ليست لديك حجوزات. اختر منطقة من تبويب \"المناطق\" واحجز فترة متاحة.';

  @override
  String get rezYok => 'لا توجد حجوزات.';

  @override
  String get rezYeniAlan => 'منطقة جديدة';

  @override
  String get rezAlanEklendi => 'تمت إضافة منطقة مشتركة ✓';

  @override
  String get rezAlanGuncellendi => 'تم تحديث المنطقة ✓';

  @override
  String get rezOrtakAlan => 'منطقة مشتركة';

  @override
  String rezSatirOzet(
    Object tarih,
    Object baslangic,
    Object bitis,
    Object kisi,
  ) {
    return '$tarih · $baslangic-$bitis · $kisi أشخاص';
  }

  @override
  String get rezIptalEdildi => 'أُلغيت';

  @override
  String get rezIptalEdilsinMi => 'هل يُلغى الحجز؟';

  @override
  String get rezIptalUyari =>
      'تعود الفترة متاحة؛ لا يمكن التراجع عن هذه العملية.';

  @override
  String get rezEvetIptalEt => 'نعم، إلغاء';

  @override
  String get rezIptalEdildiBildirim => 'تم إلغاء الحجز';

  @override
  String get rezIptalGonderilemedi => 'تعذّر إرسال الإلغاء. حاول مرة أخرى.';

  @override
  String get rezIptalEt => 'إلغاء';

  @override
  String rezDetayTarih(Object tarih, Object baslangic, Object bitis) {
    return 'التاريخ: $tarih · $baslangic-$bitis';
  }

  @override
  String rezDetayKisi(Object n) {
    return 'عدد الأشخاص: $n';
  }

  @override
  String rezDetayRezerve(Object zaman) {
    return 'تم الحجز: $zaman';
  }

  @override
  String rezDetayNot(Object not) {
    return 'ملاحظة: $not';
  }

  @override
  String get rezAlanYokYonetim =>
      'لا توجد مناطق مشتركة بعد. أضف واحدة عبر \"منطقة جديدة\".';

  @override
  String get rezAlanYokGoruntuleme => 'لا توجد مناطق مشتركة للعرض.';

  @override
  String get rezAlanYokSakin => 'لا توجد مناطق قابلة للحجز.';

  @override
  String rezMusait(Object ozet) {
    return 'متاح: $ozet';
  }

  @override
  String rezMusaitOzeti(Object acilis, Object kapanis, Object dakika) {
    return '$acilis–$kapanis · فترة $dakika د';
  }

  @override
  String get rezAcikDuzenle => 'مفتوح · اضغط للتعديل';

  @override
  String get rezKapaliDuzenle => 'مغلق · اضغط للتعديل';

  @override
  String rezMusaitSlotlariGor(Object ozet) {
    return 'متاح: $ozet · اضغط لعرض الفترات';
  }

  @override
  String get rezPasifAlan => 'غير نشط (غير قابل للحجز)';

  @override
  String get rezKapanisSonra => 'يجب أن يكون وقت الإغلاق بعد وقت الافتتاح.';

  @override
  String get rezAlanEklenemedi => 'تعذّرت إضافة المنطقة. حاول مرة أخرى.';

  @override
  String get rezAlanDuzenle => 'تعديل المنطقة';

  @override
  String get rezYeniOrtakAlan => 'منطقة مشتركة جديدة';

  @override
  String get rezAlanAdi => 'اسم المنطقة * (مثال: المسبح)';

  @override
  String get rezAlanAdiGerekli => 'اسم المنطقة مطلوب';

  @override
  String get rezMusaitlikHerGun => 'التوفر (كل يوم)';

  @override
  String rezAcilis(Object saat) {
    return 'الافتتاح: $saat';
  }

  @override
  String rezKapanis(Object saat) {
    return 'الإغلاق: $saat';
  }

  @override
  String get rezSlotUzunlugu => 'طول الفترة';

  @override
  String rezSlotDakika(Object n) {
    return '$n دقيقة';
  }

  @override
  String get rezAlaniEkle => 'إضافة المنطقة';

  @override
  String get rezSlotlarYuklenemedi => 'تعذّر تحميل الفترات. حاول مرة أخرى.';

  @override
  String get rezOnaylandi => 'تم تأكيد حجزك ✓';

  @override
  String rezTarihEtiket(Object tarih) {
    return 'التاريخ: $tarih';
  }

  @override
  String get rezSlotKurali =>
      'تُفتح الفترة فقط قبل بدايتها بأقل من ٢٤ ساعة؛ ويمكنك حجز واحد كحد أقصى يومياً.';

  @override
  String get rezSlotYok => 'لا توجد فترات معرّفة لهذه المنطقة.';

  @override
  String get rezBenimAktif => 'حجزي (نشط)';

  @override
  String get rezBenimGecti => 'حجزي (منتهٍ)';

  @override
  String get rezDoluBaskasi => 'محجوز (شخص آخر)';

  @override
  String get rezSizinGecti => 'حجزك (منتهٍ)';

  @override
  String rezKisiEki(Object n) {
    return ' · $n أشخاص';
  }

  @override
  String rezDoluDaire(Object daire, Object kisi) {
    return 'محجوز · الوحدة $daire$kisi';
  }

  @override
  String get rezBos => 'متاح';

  @override
  String get rezDolu => 'محجوز';

  @override
  String rezSlotAralik(Object baslangic, Object bitis) {
    return '$baslangic – $bitis';
  }

  @override
  String get rezSec => 'اختر';

  @override
  String get rezGonderilemedi => 'تعذّر الإرسال. حاول مرة أخرى.';

  @override
  String rezEtBaslik(Object ad) {
    return '$ad — احجز';
  }

  @override
  String get rezKisiSayisiEtiket => 'عدد الأشخاص:';

  @override
  String get rezEt => 'احجز';

  @override
  String get rezDurumOnayli => 'مؤكَّد';

  @override
  String get rezSebepDolu => 'محجوز';

  @override
  String get rezSebepGecti => 'منتهٍ';

  @override
  String get rezSebepCokErken => 'يُفتح خلال ٢٤ ساعة';

  @override
  String get rezSebepGunluk => 'استُنفد حقك اليومي';

  @override
  String etkSekmeYaklasan(Object n) {
    return 'قادمة ($n)';
  }

  @override
  String etkSekmeGecmis(Object n) {
    return 'السابقة ($n)';
  }

  @override
  String get etkYeni => 'حدث جديد';

  @override
  String get etkYaklasanYokYonetim =>
      'لا توجد أحداث قادمة. أعلن عن حدث عبر \"حدث جديد\".';

  @override
  String get etkYaklasanYok => 'لا توجد أحداث قادمة.';

  @override
  String get etkGecmisYok => 'لا توجد أحداث سابقة.';

  @override
  String get etkDuyuruldu => 'تم الإعلان عن الحدث — أُبلغ السكان ✓';

  @override
  String get etkGuncellendi => 'تم تحديث الحدث ✓';

  @override
  String etkKatiliyorSayisi(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n سيحضرون',
      many: '$n سيحضرون',
      few: '$n سيحضرون',
      two: 'شخصان سيحضران',
      one: 'شخص واحد سيحضر',
      zero: 'لا أحد سيحضر',
    );
    return '$_temp0';
  }

  @override
  String etkKatilmiyorSayisi(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n لن يحضروا',
      many: '$n لن يحضروا',
      few: '$n لن يحضروا',
      two: 'شخصان لن يحضرا',
      one: 'شخص واحد لن يحضر',
      zero: 'لا أحد لن يحضر',
    );
    return '$_temp0';
  }

  @override
  String etkKatiliminiz(Object durum) {
    return 'مشاركتك: $durum';
  }

  @override
  String etkBeyanKaydedildi(Object durum) {
    return 'تم حفظ مشاركتك: $durum ✓';
  }

  @override
  String get etkBeyanGonderilemedi => 'تعذّر إرسال المشاركة. حاول مرة أخرى.';

  @override
  String get etkKatiliyorum => 'سأحضر';

  @override
  String get etkKatilmiyorum => 'لن أحضر';

  @override
  String etkZaman(Object aralik) {
    return 'الوقت: $aralik';
  }

  @override
  String etkYer(Object konum) {
    return 'المكان: $konum';
  }

  @override
  String etkDuyuran(Object ad) {
    return 'المُعلن: $ad';
  }

  @override
  String get etkSilinsinMi => 'هل يُحذف الحدث؟';

  @override
  String etkSilOnay(Object baslik) {
    return 'سيتم حذف \"$baslik\" وجميع المشاركات.';
  }

  @override
  String get etkSilindi => 'تم حذف الحدث ✓';

  @override
  String get etkBitisSonra => 'يجب أن تكون النهاية بعد البداية';

  @override
  String get etkKaydedilemedi => 'تعذّر الحفظ. حاول مرة أخرى.';

  @override
  String get etkDuzenleBaslik => 'تعديل الحدث';

  @override
  String get etkBaslikAlan => 'العنوان * (مثال: أمسية مشاهدة مباراة)';

  @override
  String get etkBaslikGerekli => 'العنوان مطلوب';

  @override
  String get etkAciklamaAlan => 'الوصف *';

  @override
  String get etkAciklamaGerekli => 'الوصف مطلوب';

  @override
  String etkZamanSecim(Object zaman) {
    return 'الوقت: $zaman';
  }

  @override
  String get etkBitisEkle => 'إضافة وقت انتهاء (اختياري)';

  @override
  String etkBitis(Object zaman) {
    return 'النهاية: $zaman';
  }

  @override
  String get etkBitisiKaldir => 'إزالة وقت الانتهاء';

  @override
  String get etkYerAlan => 'المكان (اختياري)';

  @override
  String get etkGorselAlan => 'صورة (اختياري)';

  @override
  String get etkDuyurVeBildir => 'أعلن وأبلغ السكان';

  @override
  String get izinBaslik => 'إذن العرض';

  @override
  String get izinTumDairelere => 'طلب إذن لجميع الوحدات';

  @override
  String get izinYeniIstek => 'طلب جديد';

  @override
  String get izinIstekYokYonetim =>
      'ليست لديك طلبات إذن بعد. استخدم \"طلب جديد\" لوحدة واحدة، أو \"جميع الوحدات\" أعلاه للجميع.';

  @override
  String get izinIstekYokSakin => 'لا توجد طلبات عرض لوحدتك.';

  @override
  String get izinTumDaireUyari =>
      'سيُرسل طلب إذن عرض لكل وحدة لديها ساكن. كل وحدة تعتمد على موافقة ساكنها — ولن ترى سوى سجلات الوحدات الموافقة.';

  @override
  String izinAtlandiEki(Object n) {
    return ' ($n مفتوح بالفعل)';
  }

  @override
  String izinTopluGonderildi(Object n, Object atlandi) {
    return 'أُرسلت طلبات لـ $n وحدة$atlandi — في انتظار موافقات السكان';
  }

  @override
  String izinGonderilemedi(Object hata) {
    return 'تعذّر الإرسال: $hata';
  }

  @override
  String get izinIsteBaslik => 'طلب إذن العرض';

  @override
  String get izinDaireNo => 'رقم الوحدة (مثال: A-12)';

  @override
  String get izinIstekGonder => 'إرسال الطلب';

  @override
  String get izinIstekGonderildi => 'أُرسل الطلب — في انتظار موافقة الساكن';

  @override
  String izinDaireIstegi(Object daire) {
    return 'طلب عرض الوحدة$daire';
  }

  @override
  String izinIsteyen(Object ad) {
    return 'الطالب: $ad';
  }

  @override
  String get izinKullanildiUyari =>
      'تم استخدام الإذن (لمرة واحدة). افتح طلباً جديداً لتعرض مرة أخرى.';

  @override
  String izinGoruntulenebilirDaireler(Object n) {
    return 'الوحدات القابلة للعرض ($n)';
  }

  @override
  String get izinKullanildi => 'مُستخدم';

  @override
  String get izinOnayli => 'موافَق عليه';

  @override
  String get izinVerildi => 'تم منح الإذن';

  @override
  String get izinOnayla => 'موافقة';

  @override
  String get izinKargolar => 'الشحنات';

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
      'تم استخدام الإذن أو انتهت صلاحيته (لمرة واحدة). افتح طلب إذن جديداً لتعرض مرة أخرى.';

  @override
  String get izinTekSeferlikUyari =>
      'يتم العرض بإذن لمرة واحدة — يُغلق الوصول عند التحديث.';

  @override
  String get izinKayitYok => 'لا توجد سجلات لهذه الوحدة.';

  @override
  String izinHedef(Object ad) {
    return 'المستلم: $ad';
  }

  @override
  String izinKaydeden(Object ad) {
    return 'المُسجِّل: $ad';
  }

  @override
  String izinDurumEtiket(Object durum) {
    return 'الحالة: $durum';
  }

  @override
  String get izinDurumOnaylandi => 'تمت الموافقة';

  @override
  String get kargoDurumTeslimAlindi => 'تم التسليم';

  @override
  String get rezSizin => 'حجزك';

  @override
  String get butBaslik => 'الميزانية';

  @override
  String get butSekmeOzet => 'الملخص';

  @override
  String get butSekmeHareketler => 'الحركات';

  @override
  String get butSekmeKategoriler => 'الفئات';

  @override
  String get butTumZamanlar => 'كل الأوقات';

  @override
  String get butDonem => 'الفترة';

  @override
  String get butGelir => 'الإيرادات';

  @override
  String get butGider => 'المصروفات';

  @override
  String get butKasa => 'الرصيد';

  @override
  String get butKategoriKirilimi => 'التوزيع حسب الفئة';

  @override
  String get butYeniHareket => 'حركة جديدة';

  @override
  String get butHareketYok => 'لا توجد حركات بعد.';

  @override
  String get butKategori => 'الفئة';

  @override
  String get butOtomatik => 'تلقائي';

  @override
  String get butKategoriSecin => 'اختر فئة';

  @override
  String get butTutar => 'المبلغ (ليرة)';

  @override
  String get butTutarIpucu => 'مثال: 1.250,50';

  @override
  String get butTutarGecersiz => 'أدخل مبلغاً صحيحاً (مثال: 1.250,50)';

  @override
  String butTarih(Object tarih) {
    return 'التاريخ: $tarih';
  }

  @override
  String get butYeniKategori => 'فئة جديدة';

  @override
  String get butKategoriYok => 'لا توجد فئات بعد.';

  @override
  String get butKategoriAdi => 'اسم الفئة';

  @override
  String get butKategoriAdiIpucu => 'مثال: صيانة الحديقة';

  @override
  String get butAdZorunlu => 'الاسم مطلوب';

  @override
  String butKategoriTip(Object ad, Object tip) {
    return '$ad ($tip)';
  }

  @override
  String get butPasifEki => ' · غير نشط (لا قيود جديدة)';

  @override
  String get butBeklenmeyenKisa => 'حدث خطأ غير متوقع. حاول مرة أخرى.';

  @override
  String get butFinansalOzet => 'الملخص المالي';

  @override
  String get butAidatTahsilati => 'تحصيل الرسوم';

  @override
  String get butEnYuksekGiderler => 'أكبر المصروفات';

  @override
  String butTahsilatYuzde(Object yuzde) {
    return 'التحصيل $yuzde٪';
  }

  @override
  String get butTahakkukYok => 'لا توجد استحقاقات مسجّلة لهذه الفترة.';

  @override
  String get butSiteBaslik => 'ميزانية الموقع';

  @override
  String get butKategoriToplamlari => 'مجاميع الفئات';

  @override
  String get butSeffaflikNotu =>
      'تعرض هذه الشاشة إيرادات ومصروفات إدارة الموقع كملخص بهدف الشفافية. لا تُعرض التفاصيل على مستوى الأشخاص والوحدات؛ راجع الإدارة لأي أسئلة.';

  @override
  String get demBaslik => 'الأصول';

  @override
  String get demEtiketOkut => 'امسح الوسم';

  @override
  String get demBaskaEtiketOkut => 'امسح وسماً آخر';

  @override
  String demUzerimdekiler(Object ek) {
    return 'ما بحوزتي$ek';
  }

  @override
  String get demNfcAciklama =>
      'امسح وسم NFC الموجود على الأصل عند أخذه أو إعادته. يتعرّف التطبيق على الأصل ويُظهر من يحوزه.';

  @override
  String get demTaniniyor => 'جارٍ التعرّف على الأصل...';

  @override
  String get demKimsedeDegil => 'ليس بحوزة أحد — متاح.';

  @override
  String demSende(Object sure) {
    return 'بحوزتك — $sure.';
  }

  @override
  String demBaskasinda(Object ad, Object sure) {
    return 'بحوزة $ad — $sure.';
  }

  @override
  String get demBaskasininUzerinde => 'يبدو أنه بحوزة شخص آخر.';

  @override
  String get demBakimda => 'تحت الصيانة — لا يمكن تسليمه الآن.';

  @override
  String get demZorlaDevralmaYok =>
      'لا استيلاء قسري — يجب أن يعيده حائزه الحالي.';

  @override
  String get demZimmetineAl => 'استلام';

  @override
  String get demBirak => 'إعادة';

  @override
  String get demBirakKisa => 'إعادة';

  @override
  String get demSonHareketler => 'الحركات الأخيرة';

  @override
  String demAldi(Object ad, Object zaman) {
    return 'أخذه $ad — $zaman (لا يزال بحوزته)';
  }

  @override
  String get demListeYetkiYok => 'ليست لديك صلاحية لقائمة الأصول.';

  @override
  String get demUzerindeYok => 'لا توجد أصول بحوزتك حالياً.';

  @override
  String demAldin(Object zaman, Object sure) {
    return 'أُخذ: $zaman ($sure)';
  }

  @override
  String get demSureBelirsiz => 'منذ فترة';

  @override
  String get demSureAzOnce => 'قبل لحظات';

  @override
  String demSureDakika(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n دقيقة',
      many: 'منذ $n دقيقة',
      few: 'منذ $n دقائق',
      two: 'منذ دقيقتين',
      one: 'منذ دقيقة',
      zero: 'منذ $n دقيقة',
    );
    return '$_temp0';
  }

  @override
  String demSureSaat(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n ساعة',
      many: 'منذ $n ساعة',
      few: 'منذ $n ساعات',
      two: 'منذ ساعتين',
      one: 'منذ ساعة',
      zero: 'منذ $n ساعة',
    );
    return '$_temp0';
  }

  @override
  String demSureGun(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n يوم',
      many: 'منذ $n يوماً',
      few: 'منذ $n أيام',
      two: 'منذ يومين',
      one: 'منذ يوم',
      zero: 'منذ $n يوم',
    );
    return '$_temp0';
  }

  @override
  String get demOfflineUyari =>
      'يلزم اتصال بالإنترنت. حيازة الأصل سجل فوري؛ ولا تُعالج دون اتصال (الانتظار في قائمة سيكون مضلّلاً).';

  @override
  String demEtiketEslesmiyor(Object uid) {
    return 'هذا الوسم ($uid) لا يطابق أي أصل مسجّل. يجب ربط الوسم بأصل من اللوحة.';
  }

  @override
  String get demZatenZimmetinde =>
      'كان بحوزتك بالفعل ✓ (إعادة إرسال — بلا تكرار)';

  @override
  String get demZimmetineAlindi => 'تم الاستلام ✓';

  @override
  String get demBirakildi => 'تمت الإعادة ✓ — أُغلق التسليم.';

  @override
  String demIslemYapilamadi(Object hata) {
    return 'تعذّر تنفيذ العملية: $hata تم تحديث الحالة — راجع البطاقة.';
  }

  @override
  String demHataSatiri(Object ad, Object hata) {
    return '$ad: $hata';
  }

  @override
  String get karBaslik => 'الشحنات';

  @override
  String karSekmeBekleyen(Object n) {
    return 'قيد الانتظار ($n)';
  }

  @override
  String karSekmeTeslim(Object n) {
    return 'المستلمة ($n)';
  }

  @override
  String get karYeni => 'شحنة جديدة';

  @override
  String get karBekleyenYokSakin => 'لا توجد شحنات في انتظار استلامك.';

  @override
  String get karBekleyenYok => 'لا توجد شحنات في انتظار الاستلام.';

  @override
  String get karTeslimYok => 'لا توجد شحنات مستلمة مسجّلة بعد.';

  @override
  String get karKaydedildi => 'تم تسجيل الشحنة — أُبلغ سكان الوحدة ✓';

  @override
  String karDaireTarih(Object daire, Object zaman) {
    return 'الوحدة: $daire · $zaman';
  }

  @override
  String karDaire(Object daire) {
    return 'الوحدة: $daire';
  }

  @override
  String karKayit(Object zaman) {
    return 'التسجيل: $zaman';
  }

  @override
  String karNot(Object not) {
    return 'ملاحظة: $not';
  }

  @override
  String get karTeslimAlindiBildirim => 'تم استلام الشحنة ✓';

  @override
  String get karIsaretlenemedi => 'تعذّر التأشير. حاول مرة أخرى.';

  @override
  String get karTeslimAldim => 'لقد استلمتها';

  @override
  String get karGonderilemedi => 'تعذّر إرسال السجل. حاول مرة أخرى.';

  @override
  String get karDaireNo => 'رقم الوحدة * (مثال: A-12)';

  @override
  String get karDaireNoGerekli => 'رقم الوحدة مطلوب';

  @override
  String get karFirma => 'شركة الشحن *';

  @override
  String get karFirmaGerekli => 'شركة الشحن مطلوبة';

  @override
  String get karPaketFotografi => 'صورة الشحنة (اختياري)';

  @override
  String get karKaydetVeBildir => 'احفظ وأبلغ السكان';

  @override
  String get ortakTekrarDene => 'حاول مرة أخرى';

  @override
  String get butTahakkuk => 'المستحق';

  @override
  String get butTahsilat => 'المُحصّل';

  @override
  String get butGeciken => 'متأخر';

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
  String get kuralBaslik => 'قواعد المجمّع';

  @override
  String get kuralYeni => 'قاعدة جديدة';

  @override
  String get kuralAramaIpucu => 'ابحث في العناوين (مثال: المسبح)';

  @override
  String get kuralEklendi => 'تمت إضافة القاعدة ✓';

  @override
  String get kuralGuncellendi => 'تم تحديث القاعدة ✓';

  @override
  String get kuralAramaBos => 'لا توجد قواعد مطابقة للبحث.';

  @override
  String get kuralYokYonetim =>
      'لا توجد قواعد بعد. أضف واحدة عبر \"قاعدة جديدة\".';

  @override
  String get kuralYokSakin => 'لم تُنشر أي قواعد بعد.';

  @override
  String get kuralSilOnayBaslik => 'حذف هذه القاعدة؟';

  @override
  String kuralSilOnayGovde(Object baslik) {
    return 'سيتم حذف \"$baslik\" نهائياً.';
  }

  @override
  String get kuralSilindi => 'تم حذف القاعدة ✓';

  @override
  String get kuralDuzenleBaslik => 'تعديل القاعدة';

  @override
  String get kuralBaslikAlan => 'العنوان * (مثال: أوقات المسبح)';

  @override
  String get kuralBaslikGerekli => 'العنوان مطلوب';

  @override
  String get kuralMetni => 'نص القاعدة *';

  @override
  String get kuralMetniGerekli => 'نص القاعدة مطلوب';

  @override
  String get kuralSira => 'الترتيب (الأصغر أولاً)';

  @override
  String get kuralSiraGecersiz =>
      'يجب أن يكون الترتيب 0 أو عدداً صحيحاً موجباً';

  @override
  String get kuralMevcutGorsel => 'يتم الإبقاء على الصورة الحالية';

  @override
  String get kuralEkleButon => 'أضف القاعدة';

  @override
  String get ortakFotoOnlineTekrarDene =>
      'يلزم اتصال بالإنترنت لتحميل الصورة. أعد المحاولة عند عودة الاتصال.';

  @override
  String get ortakFotoBekleyinVeyaKaldir =>
      'لم يتم تحميل الصورة بعد. انتظر انتهاء التحميل أو أزل الصورة.';

  @override
  String get duyuruYeni => 'إعلان جديد';

  @override
  String get duyuruYayinlandi => 'تم نشر الإعلان ✓';

  @override
  String get duyuruGuncellendi => 'تم تحديث الإعلان ✓';

  @override
  String get duyuruYok => 'لا توجد إعلانات بعد.';

  @override
  String get duyuruYonetim => 'الإدارة';

  @override
  String duyuruMeta(Object ad, Object zaman, Object duzenlendi) {
    return '$ad · $zaman$duzenlendi';
  }

  @override
  String get duyuruDuzenlendiEki => ' · مُعدَّل';

  @override
  String get duyuruSilOnay => 'حذف هذا الإعلان؟';

  @override
  String get duyuruSilindi => 'تم حذف الإعلان ✓';

  @override
  String get duyuruDuzenleBaslik => 'تعديل الإعلان';

  @override
  String get duyuruBaslikZorunlu => 'العنوان إلزامي';

  @override
  String get duyuruMetniAlan => 'نص الإعلان';

  @override
  String get duyuruMetniZorunlu => 'نص الإعلان إلزامي';

  @override
  String get duyuruYayinla => 'نشر';

  @override
  String get ortakIslemler => 'الإجراءات';

  @override
  String get sakinBaslik => 'سكان المجمّع';

  @override
  String get sakinEkle => 'إضافة ساكن';

  @override
  String get sakinListelenemedi => 'تعذّر إدراج السكان.';

  @override
  String get sakinDaireYok => 'لم تُخصَّص وحدة';

  @override
  String get sakinIslemleri => 'إجراءات الساكن';

  @override
  String get sakinParolaSifirla => 'إعادة تعيين كلمة المرور';

  @override
  String get sakinParolaSifirlaOnay => 'إعادة تعيين كلمة المرور؟';

  @override
  String sakinParolaSifirlaGovde(Object ad) {
    return 'سيتم إنشاء رمز مؤقت جديد لـ \"$ad\"؛ وتصبح كلمة المرور القديمة غير صالحة. يسجّل المستخدم الدخول بالهاتف + الرمز الجديد ثم يحدّد كلمة المرور.';
  }

  @override
  String get sakinSifirla => 'إعادة تعيين';

  @override
  String sakinYeniKodMesaji(Object ad) {
    return 'رمز مؤقت جديد لـ \"$ad\". سلّمه للساكن؛ يسجّل الدخول بالهاتف + هذا الرمز ثم يحدّد كلمة المرور.';
  }

  @override
  String get sakinSilOnay => 'حذف الساكن؟';

  @override
  String sakinSilGovde(Object ad) {
    return 'سيُحذف \"$ad\". إذا لم يكن له سجل يُحذف نهائياً؛ وإلا يصبح غير نشط. في كل الحالات يُحرَّر رقم الهاتف (يمكن التسجيل به مجدداً).';
  }

  @override
  String sakinSilindi(Object ad) {
    return 'تم حذف \"$ad\" (تم تحرير الرقم)';
  }

  @override
  String sakinPasiflestirildi(Object ad) {
    return 'تم تعطيل \"$ad\" — لديه سجل (تم تحرير الرقم)';
  }

  @override
  String get sakinDuzenleBaslik => 'تعديل الساكن';

  @override
  String get sakinYeniTelefon => 'رقم جوال جديد';

  @override
  String get sakinBosBirakDegismez => 'اتركه فارغاً ليبقى كما هو';

  @override
  String get sakinGuncellendi => 'تم التحديث ✓';

  @override
  String get ortakAdSoyad => 'الاسم الكامل';

  @override
  String get telefonHataEksik =>
      'الرقم غير مكتمل — أدخل ١٠ أرقام (مثال: 0543 199 29 04).';

  @override
  String get telefonHataOnEk =>
      'يجب أن يبدأ رقم الجوال بـ 5 (مثال: 0543…). الخطوط الأرضية غير مقبولة.';

  @override
  String get ortakCepTelefonu => 'رقم الجوال';

  @override
  String get ortakTelefonIpucu => 'مثال: 0532 111 22 03';

  @override
  String get ortakTelefonZorunlu => 'الهاتف إلزامي';

  @override
  String get sakinGirisAnahtari => 'مفتاح تسجيل الدخول (فريد عالمياً).';

  @override
  String get ortakDaireNoIpucu => 'مثال: A-12';

  @override
  String get sakinDaireNoZorunlu => 'رقم الوحدة إلزامي';

  @override
  String get sakinParolaOpsiyonel => 'كلمة المرور (اختياري)';

  @override
  String get sakinBosBirakKod => 'اتركه فارغاً ليتم إنشاء رمز مؤقت';

  @override
  String get sakinEklendiKod =>
      'تمت إضافة الساكن. سلّمه هذا الرمز؛ يسجّل الدخول بالهاتف + هذا الرمز ثم يحدّد كلمة المرور.';

  @override
  String get sakinEklendi => 'تمت إضافة الساكن ✓';

  @override
  String get sakinYok => 'لا يوجد سكان بعد.\nيمكنك الإضافة من أسفل اليمين.';

  @override
  String get ortakGeciciKodBaslik => 'رمز الدخول المؤقت';

  @override
  String get ortakKopyala => 'نسخ';

  @override
  String get ortakKopyalandi => 'تم النسخ';

  @override
  String get girisParolaVeyaKod => 'كلمة المرور أو الرمز المؤقت';

  @override
  String get girisIlkKodIpucu =>
      'في أول تسجيل دخول، أدخل الرمز المؤقت الذي حصلت عليه من الإدارة.';

  @override
  String get girisBeniHatirla => 'تذكّرني';

  @override
  String get girisYap => 'تسجيل الدخول';

  @override
  String get girisOturumSonaErdi =>
      'انتهت صلاحية جلستك. الرجاء تسجيل الدخول مرة أخرى.';

  @override
  String get parolaBelirleBaslik => 'حدّد كلمة المرور';

  @override
  String get parolaBelirleAciklama =>
      'لقد سجّلت الدخول لأول مرة برمز مؤقت. للمتابعة، أنشئ كلمة مرور دائمة خاصة بك؛ وستستخدم رقم الوحدة + كلمة المرور هذه في المرات القادمة.';

  @override
  String get parolaBelirleButon => 'تعيين كلمة المرور';

  @override
  String get parolaGiriseDon => 'العودة لتسجيل الدخول';

  @override
  String get ortakParolaZorunlu => 'كلمة المرور إلزامية';

  @override
  String get ortakYeniParola => 'كلمة مرور جديدة';

  @override
  String get ortakYeniParolaTekrar => 'كلمة المرور الجديدة (مرة أخرى)';

  @override
  String get ortakYeniParolaZorunlu => 'كلمة المرور الجديدة إلزامية';

  @override
  String get ortakParolalarEslesmiyor => 'كلمتا المرور غير متطابقتين';

  @override
  String get parolaKuraliKisa => 'يجب أن تكون 8 أحرف على الأقل';

  @override
  String get parolaKuraliBuyukHarf =>
      'يجب أن تحتوي على حرف كبير واحد على الأقل';

  @override
  String get parolaKuraliRakam => 'يجب أن تحتوي على رقم واحد على الأقل';

  @override
  String get parolaKuraliSembol =>
      'يجب أن تحتوي على رمز واحد على الأقل (! ? @ # . -)';

  @override
  String get profilYuklenemedi => 'تعذّر تحميل الملف الشخصي.';

  @override
  String get profilNumaraYok => 'لم يُدخل رقم';

  @override
  String get profilFotoBaslik => 'صورة الملف الشخصي';

  @override
  String get profilFotoSec => 'اختر صورة';

  @override
  String get profilFotoGuncellendi => 'تم تحديث صورة الملف الشخصي ✓';

  @override
  String get profilFotoKaldirildi => 'تمت إزالة صورة الملف الشخصي';

  @override
  String get ortakGaleri => 'المعرض';

  @override
  String get profilParolaDegistir => 'تغيير كلمة المرور';

  @override
  String get profilMevcutParola => 'كلمة المرور الحالية';

  @override
  String get profilMevcutParolaZorunlu => 'كلمة المرور الحالية إلزامية';

  @override
  String get profilParolaGuncelle => 'تحديث كلمة المرور';

  @override
  String get profilParolaGuncellendi => 'تم تحديث كلمة المرور ✓';

  @override
  String get profilTelefon => 'الهاتف';

  @override
  String get profilTelefonIpucu => 'مثال: +905551112233';

  @override
  String get profilAranabilir => 'قابل للاتصال';

  @override
  String get profilAranabilirAlt =>
      'يمكن للأدوار المصرّح لها (اتصال يستلزم الموافقة) الوصول إلى رقمك';

  @override
  String get profilIletisimKaydet => 'حفظ معلومات الاتصال';

  @override
  String get profilIletisimGuncellendi => 'تم تحديث معلومات الاتصال ✓';

  @override
  String get personelEkle => 'إضافة موظف';

  @override
  String get personelDuzenle => 'تعديل الموظف';

  @override
  String get personelListelenemedi => 'تعذّر إدراج الموظفين.';

  @override
  String get personelPasiflestir => 'تعطيل';

  @override
  String get personelAktiflestir => 'تنشيط';

  @override
  String get personelPasiflestirildi => 'تم التعطيل ✓';

  @override
  String get personelAktiflestirildi => 'تم التنشيط ✓';

  @override
  String personelSifirlaGovde(Object ad) {
    return 'سيتم إنشاء رمز مؤقت جديد لـ $ad؛ وتصبح كلمة المرور القديمة غير صالحة.';
  }

  @override
  String get personelYeniKodMesaji =>
      'رمز مؤقت جديد. سلّمه للموظف؛ يسجّل الدخول بالهاتف + هذا الرمز ثم يحدّد كلمة المرور.';

  @override
  String get personelGuncellendi => 'تم تحديث الموظف ✓';

  @override
  String get personelEklendi => 'تمت إضافة الموظف ✓';

  @override
  String get personelEklendiKod =>
      'تمت إضافة الموظف. سلّمه هذا الرمز؛ يسجّل الدخول بالهاتف + هذا الرمز ثم يحدّد كلمة المرور.';

  @override
  String get personelFoto => 'صورة';

  @override
  String get personelTelefonOpsiyonel => 'رقم الجوال (اختياري)';

  @override
  String get personelBosBirakDegismezNokta => 'اتركه فارغاً ليبقى كما هو.';

  @override
  String get personelYok =>
      'لا يوجد موظفو ميدان بعد.\nيمكنك الإضافة من أسفل اليمين.';

  @override
  String get disKisiEkle => 'إضافة جهة اتصال';

  @override
  String get disListeAlinamadi => 'تعذّر تحميل القائمة.';

  @override
  String get disKayitYokYonetim =>
      'لا توجد سجلات بعد. أضف من أسفل اليمين حرفياً تثق به.';

  @override
  String get disKayitYok => 'لا توجد سجلات خدمات خارجية بعد.';

  @override
  String get disNotEkleyin => 'أضف ملاحظة (الإدارة فقط يمكنها التعديل).';

  @override
  String get disNotuDuzenle => 'تعديل الملاحظة';

  @override
  String get disBolumNotu => 'ملاحظة القسم';

  @override
  String get disNotIpucu =>
      'مثال: حرفيون نثق بهم منذ سنوات؛ لأمن المجمّع لا تُدخل الغرباء.';

  @override
  String get disNotGuncellendi => 'تم تحديث الملاحظة ✓';

  @override
  String get disAra => 'اتصال';

  @override
  String get disSilOnay => 'حذف هذا السجل؟';

  @override
  String disSilGovde(Object ad) {
    return 'سيتم حذف \"$ad\".';
  }

  @override
  String get disSilindi => 'تم الحذف ✓';

  @override
  String get disYeniKisi => 'جهة اتصال خارجية جديدة';

  @override
  String get disKisiDuzenle => 'تعديل جهة الاتصال';

  @override
  String get disTur => 'نوع الخدمة';

  @override
  String get disTurIpucu => 'مثال: أقفال، كهرباء، سباكة';

  @override
  String get disTurZorunlu => 'النوع إلزامي';

  @override
  String get disAd => 'الاسم';

  @override
  String get disSoyad => 'اسم العائلة';

  @override
  String get disAdGerekli => 'الاسم مطلوب';

  @override
  String get disSoyadGerekli => 'اسم العائلة مطلوب';

  @override
  String get nfcBaslik => 'قراءة وسم NFC';

  @override
  String get nfcHazir => 'جاهز للقراءة. اضغط ابدأ.';

  @override
  String get nfcYaklastirBekliyor => 'قرّب الوسم من ظهر الهاتف...';

  @override
  String get nfcOkundu => 'تم قراءة الوسم.';

  @override
  String get nfcOkumayaBasla => 'ابدأ القراءة';

  @override
  String get nfcTekrarOku => 'اقرأ مرة أخرى';

  @override
  String nfcKuyrukBekleyen(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n مسح في انتظار الإرسال',
      many: '$n مسحاً في انتظار الإرسال',
      few: '$n مسحات في انتظار الإرسال',
      two: 'مسحان في انتظار الإرسال',
      one: 'مسح واحد في انتظار الإرسال',
      zero: 'لا مسحات في الانتظار',
    );
    return '$_temp0';
  }

  @override
  String get nfcKuyruk => 'قائمة الإرسال';

  @override
  String get nfcKaydedildiBekliyor =>
      'تم الحفظ ✓ — سيُرسل تلقائياً عند توفر الاتصال.';

  @override
  String get nfcKaydedildiGonderiliyor => 'تم الحفظ ✓ — جارٍ الإرسال...';

  @override
  String get nfcGonderildiZatenVar =>
      'تم الإرسال ✓ — هذا المسح كان مسجّلاً بالفعل.';

  @override
  String get nfcGonderildi => 'تم الإرسال ✓ — تم تسجيل المسح.';

  @override
  String get nfcEslesmeYok => 'هذا الوسم لا يطابق أي نقطة تفتيش.';

  @override
  String get nfcSdmBaslik => 'SDM (خام، غير مُتحقَّق)';

  @override
  String get nfcTipEtiket => 'النوع';

  @override
  String nfcNoktalarAlinamadi(Object hata) {
    return 'تعذّر تحميل النقاط: $hata';
  }

  @override
  String get nfcTestBaslik => 'اختبار: أي نقطة نمسح؟';

  @override
  String get nfcTestAlt => 'يحاكي المسح بدون وسم مادي.';

  @override
  String get nfcAktifNoktaYok => 'لا توجد نقاط تفتيش نشطة.';

  @override
  String get nfcAktifNoktaYokAlt => 'أضف واحدة أولاً من \"نقاط التفتيش\".';

  @override
  String get nfcManuelOkut => 'مسح يدوي (اختبار)';

  @override
  String get nfcTestGorunur => 'يظهر في نسخ الاختبار فقط.';

  @override
  String nfcUidSatir(Object uid) {
    return 'UID: $uid';
  }

  @override
  String get nfcHataKapali => 'NFC مغلق. الرجاء تشغيل NFC من إعدادات الجهاز.';

  @override
  String get nfcHataDesteklenmiyor => 'هذا الجهاز لا يدعم NFC.';

  @override
  String get nfcHataUidOkunamadi => 'تعذّر قراءة معرّف الوسم (UID).';

  @override
  String nfcHataCozumlenemedi(Object detay) {
    return 'تعذّر تحليل الوسم: $detay';
  }

  @override
  String nfcHataOturum(Object detay) {
    return 'تعذّر بدء جلسة NFC: $detay';
  }

  @override
  String nfcHataOkumaIptal(Object detay) {
    return 'أُلغيت القراءة: $detay';
  }

  @override
  String nfcHataYapilandirma(Object detay) {
    return 'لا يمكن استخدام NFC في هذه النسخة: $detay. يلزم تحديث التطبيق؛ إعادة المحاولة لن تُجدي.';
  }

  @override
  String get nfcHataBilinmeyen => 'حدث خطأ غير معروف.';

  @override
  String get nfcIosYaklastir => 'قرّب الوسم من ظهر الهاتف.';

  @override
  String get nfcIosOkundu => 'تم القراءة';

  @override
  String get nfcIosIptal => 'أُلغي';

  @override
  String get nfcIosOkunamadi => 'تعذّرت القراءة';

  @override
  String get seffafYuklenemedi => 'تعذّر التحميل. الرجاء المحاولة مرة أخرى.';

  @override
  String get seffafAyYayinlandi => 'تم نشر الشهر.';

  @override
  String get seffafYayinGeriAlindi => 'تم سحب النشر.';

  @override
  String get seffafVeriYokYonetim =>
      'لا توجد بيانات مالية بعد. تظهر الأشهر هنا بعد إدخال الإيرادات/المصروفات أو الرسوم.';

  @override
  String get seffafVeriYok => 'لم تنشر الإدارة ملخصاً بعد.';

  @override
  String get seffafTaslakEki => ' • مسودة';

  @override
  String get seffafYayinla => 'انشر هذا الشهر';

  @override
  String get seffafYayindaAlt => 'السكان يرون هذا الملخص.';

  @override
  String get seffafOnizlemeAlt => 'الإدارة فقط تراه (معاينة).';

  @override
  String get seffafOnizlemeUyari => 'معاينة — لم يُنشر بعد.';

  @override
  String seffafOzetBaslik(Object ay) {
    return '$ay — الملخص';
  }

  @override
  String get seffafToplamGelir => 'إجمالي الإيرادات';

  @override
  String get seffafToplamGider => 'إجمالي المصروفات';

  @override
  String get seffafNet => 'الصافي';

  @override
  String seffafOncekiAyNet(Object tutar) {
    return 'صافي الشهر السابق: $tutar';
  }

  @override
  String get seffafGiderDagilimi => 'توزيع المصروفات';

  @override
  String get seffafGiderYok => 'لا مصروفات مسجّلة هذا الشهر.';

  @override
  String get seffafAidatToplama => 'تحصيل الرسوم';

  @override
  String get seffafTahakkukYok => 'لا استحقاق لهذا الشهر.';

  @override
  String seffafOdeyenDaire(Object odeyen, Object toplam) {
    return 'الوحدات الدافعة: $odeyen/$toplam';
  }

  @override
  String seffafTahsilatSatir(Object tahsilat, Object tahakkuk, Object yuzde) {
    return 'المُحصّل: $tahsilat / $tahakkuk  (المبلغ: $yuzde٪)';
  }

  @override
  String seffafGecikmede(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n وحدة متأخرة',
      many: '$n وحدة متأخرة',
      few: '$n وحدات متأخرة',
      two: 'وحدتان متأخرتان',
      one: 'وحدة واحدة متأخرة',
      zero: 'لا وحدات متأخرة',
    );
    return '$_temp0';
  }

  @override
  String ortakYuzde(Object yuzde) {
    return '$yuzde٪';
  }

  @override
  String get entegYeni => 'جديد';

  @override
  String get entegYokMesaj =>
      'لا توجد تكاملات. أضف نظاماً خارجياً (مكبر صوت/منزل ذكي/webhook) عبر \"جديد\".';

  @override
  String get entegSilOnay => 'حذفه؟';

  @override
  String entegSilGovde(Object ad) {
    return 'سيتم حذف التكامل \"$ad\".';
  }

  @override
  String entegSilinemedi(Object hata) {
    return 'تعذّر الحذف: $hata';
  }

  @override
  String get entegAktifKisa => 'نشط';

  @override
  String get entegPasifKisa => 'غير نشط';

  @override
  String entegKimlikSatir(Object tip, Object kilit) {
    return 'المصادقة: $tip$kilit';
  }

  @override
  String get entegTest => 'اختبار';

  @override
  String entegTestBasarili(Object durum) {
    return '✓ نجح ($durum)';
  }

  @override
  String entegTestBasarisiz(Object hata, Object durum) {
    return '✗ $hata$durum';
  }

  @override
  String get entegBasarisiz => 'فشل';

  @override
  String get entegDuzenleBaslik => 'تعديل التكامل';

  @override
  String get entegYeniBaslik => 'تكامل جديد';

  @override
  String get entegPreset => 'قالب جاهز (preset)';

  @override
  String get entegKanalTipi => 'نوع القناة';

  @override
  String get entegUrl => 'عنوان Endpoint (http/https)';

  @override
  String get entegUrlHelper => 'تُحجب العناوين الداخلية/الخاصة عند التشغيل';

  @override
  String get entegUrlHata => 'يجب أن يبدأ بـ http(s)';

  @override
  String get entegHttpMetodu => 'طريقة HTTP';

  @override
  String get entegKimlikDogrulama => 'المصادقة';

  @override
  String get entegSir => 'السر (bearer token / API key)';

  @override
  String get entegSirKayitli => 'مُخزَّن — أدخل قيمة جديدة لتغييره';

  @override
  String get entegSirYazmaOzel => 'للكتابة فقط؛ لا يعيده الخادم أبداً';

  @override
  String get entegPayload => 'قالب الحمولة';

  @override
  String entegPayloadHelper(Object sablonlar) {
    return 'عناصر بديلة $sablonlar';
  }

  @override
  String get entegTestMesaji => 'رسالة اختبار';

  @override
  String get ortakAdGerekli => 'الاسم مطلوب';

  @override
  String get ziyaretYeni => 'زائر جديد';

  @override
  String get ziyaretKaydedildi => 'تم تسجيل الزائر — أُبلغ ساكن الوحدة ✓';

  @override
  String get ziyaretYokGuvenlik => 'لا توجد سجلات زوار بعد.';

  @override
  String get ziyaretYokSakin => 'لا توجد سجلات زوار مُبلَّغة إليك.';

  @override
  String ziyaretBildirilenSakin(Object ad) {
    return 'الساكن المُبلَّغ: $ad';
  }

  @override
  String get ziyaretSakiniAra => 'اتصل بالساكن';

  @override
  String get ziyaretGuvenligiAra => 'اتصل بالأمن';

  @override
  String get ziyaretBilgileriDuzenle => 'تعديل البيانات';

  @override
  String get ziyaretGuncellendi => 'تم تحديث بيانات الزائر ✓';

  @override
  String get ziyaretOnceDaireNo => 'أدخل رقم الوحدة أولاً';

  @override
  String get ziyaretSakiniSecin => 'اختر الساكن المراد إبلاغه';

  @override
  String get ziyaretDuzenleBaslik => 'تعديل الزائر';

  @override
  String get ziyaretDuzenleAlt =>
      'يمكنك تحديث الاسم والوحدة والساكن المُبلَّغ والملاحظة.';

  @override
  String get ziyaretYeniAlt => 'يُرسل للساكن إشعار فقط (لا يُطلب أي موافقة).';

  @override
  String get ziyaretAdAlan => 'اسم الزائر *';

  @override
  String get ziyaretAdGerekli => 'اسم الزائر مطلوب';

  @override
  String get ziyaretSakinleriGetir => 'إحضار السكان';

  @override
  String get ziyaretBildirilecekSakin => 'الساكن المراد إبلاغه *';

  @override
  String get ziyaretKaydetVeBildir => 'احفظ وأبلغ الساكن';

  @override
  String get raporBaslik => 'التقارير الشهرية';

  @override
  String get raporOncekiAy => 'الشهر السابق';

  @override
  String get raporSonrakiAy => 'الشهر التالي';

  @override
  String raporAyBaslik(Object ay, Object yil) {
    return '$ay $yil';
  }

  @override
  String get raporYetkiYok =>
      'ليست لديك صلاحية للتقارير الشهرية. هذه الشاشة متاحة لدور مدير الموقع.';

  @override
  String get raporGorevTamamlama => 'إنجاز المهام';

  @override
  String get raporAidat => 'الرسوم';

  @override
  String get raporSonTamamlamalar => 'آخر الإنجازات (أول 10)';

  @override
  String get raporPlanlananPencere => 'النوافذ المخططة';

  @override
  String raporTamamlanmaYuzde(Object yuzde) {
    return 'الإنجاز $yuzde٪';
  }

  @override
  String get raporPencereYok => 'لا نوافذ دوريات مخططة هذا الشهر.';

  @override
  String get raporGorevYok => 'لا إنجازات مهام هذا الشهر.';

  @override
  String get raporToplamTamamlama => 'إجمالي الإنجازات';

  @override
  String get raporAidatKayitYok => 'لا سجلات استحقاق/دفع لهذه الفترة.';

  @override
  String raporTahakkukDaire(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'المستحق ($n وحدة)',
      many: 'المستحق ($n وحدة)',
      few: 'المستحق ($n وحدات)',
      two: 'المستحق (وحدتان)',
      one: 'المستحق (وحدة واحدة)',
      zero: 'المستحق (لا وحدات)',
    );
    return '$_temp0';
  }

  @override
  String raporTahsilatOdeme(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'المُحصّل ($n دفعة)',
      many: 'المُحصّل ($n دفعة)',
      few: 'المُحصّل ($n دفعات)',
      two: 'المُحصّل (دفعتان)',
      one: 'المُحصّل (دفعة واحدة)',
      zero: 'المُحصّل (لا مدفوعات)',
    );
    return '$_temp0';
  }

  @override
  String get raporKalanBakiye => 'الرصيد المتبقي';

  @override
  String get aidatBaslik => 'رسومي';

  @override
  String get aidatYetkiYok => 'معلومات الرسوم متاحة لحسابات السكان فقط.';

  @override
  String get aidatDaireYok => 'لا توجد وحدة مسجّلة باسمك. تواصل مع الإدارة.';

  @override
  String get aidatToplamBakiye => 'الرصيد الإجمالي (كل الوحدات)';

  @override
  String get aidatBorcVar => 'يوجد دين';

  @override
  String get aidatBorcYok => 'لا يوجد دين';

  @override
  String get aidatToplamTahakkuk => 'إجمالي المستحق';

  @override
  String get aidatToplamOdenen => 'إجمالي المدفوع';

  @override
  String get aidatBakiye => 'الرصيد';

  @override
  String aidatHesapSatiri(Object tahakkuk, Object odenen, Object bakiye) {
    return 'المستحق $tahakkuk - المدفوع $odenen = $bakiye';
  }

  @override
  String aidatTahakkuklar(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'استحقاقات ($n)',
      many: 'استحقاقات ($n)',
      few: 'استحقاقات ($n)',
      two: 'استحقاقان ($n)',
      one: 'استحقاق ($n)',
      zero: 'الاستحقاقات ($n)',
    );
    return '$_temp0';
  }

  @override
  String aidatOdemeler(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'مدفوعات ($n)',
      many: 'مدفوعات ($n)',
      few: 'مدفوعات ($n)',
      two: 'دفعتان ($n)',
      one: 'دفعة ($n)',
      zero: 'المدفوعات ($n)',
    );
    return '$_temp0';
  }

  @override
  String aidatSonOdeme(Object tarih) {
    return 'آخر موعد للدفع: $tarih';
  }

  @override
  String aidatMakbuz(Object no) {
    return 'الإيصال: $no';
  }

  @override
  String get aidatOdemeDurumuNotu =>
      'تُحدَّث حالة الدفع فقط بتأكيد من مزوّد الدفع؛ راجع الإدارة لأي أسئلة.';

  @override
  String get aidatYontemElden => 'نقداً';

  @override
  String get aidatYontemHavale => 'حوالة بنكية';

  @override
  String get aidatYontemKart => 'بطاقة';

  @override
  String get aidatYontemDiger => 'أخرى';

  @override
  String get aidatDurumBasarili => 'ناجح';

  @override
  String get aidatDurumIptal => 'ملغى';

  @override
  String get noktaBaslik => 'نقاط التفتيش';

  @override
  String get noktaEkle => 'إضافة نقطة';

  @override
  String get noktaListelenemedi => 'تعذّر إدراج النقاط.';

  @override
  String get noktaSilOnay => 'حذف هذه النقطة؟';

  @override
  String noktaSilGovde(Object ad) {
    return 'سيتم حذف نقطة التفتيش \"$ad\".';
  }

  @override
  String get noktaSilindi => 'تم حذف النقطة ✓';

  @override
  String get noktaUidZatenVar => 'وسم NFC هذا مسجّل بالفعل.';

  @override
  String get noktaDuzenleBaslik => 'تعديل النقطة';

  @override
  String get noktaYeniBaslik => 'نقطة تفتيش جديدة';

  @override
  String get noktaAdIpucu => 'مثال: البوابة الرئيسية';

  @override
  String get noktaUidAlan => 'معرّف وسم NFC';

  @override
  String get noktaUidIpucu => 'مثال: 04A2B3C4D5';

  @override
  String get noktaUidHelper => 'المعرّف الفريد للوسم (hex).';

  @override
  String get noktaEnlem => 'خط العرض (اختياري)';

  @override
  String get noktaKonumGecersiz => 'الموقع غير صالح. مثال: 41,0082';

  @override
  String get ortakSecenekYuklenemedi =>
      'تعذّر تحميل بعض الخيارات — قد تكون القائمة ناقصة.';

  @override
  String get noktaBoylam => 'خط الطول (اختياري)';

  @override
  String get noktaPasifAlt => 'النقطة غير النشطة لا تُطابق أي مسح';

  @override
  String get noktaYok => 'لا توجد نقاط تفتيش بعد.';

  @override
  String get kuyrukHatalariTemizle => 'امسح الأخطاء الدائمة';

  @override
  String get kuyrukBos => 'القائمة فارغة.';

  @override
  String kuyrukOzet(Object bekleyen, Object hatali) {
    return '$bekleyen في الانتظار · $hatali أخطاء دائمة';
  }

  @override
  String get kuyrukSenkronla => 'زامن الآن';

  @override
  String get kuyrukBekliyor => 'في الانتظار';

  @override
  String kuyrukBekliyorDeneme(Object n) {
    return 'في الانتظار (محاولة: $n)';
  }

  @override
  String get kuyrukGonderiliyor => 'جارٍ الإرسال...';

  @override
  String get kuyrukGonderildiZatenVar => 'تم الإرسال (كان مسجّلاً)';

  @override
  String get kuyrukGonderildiYeni => 'تم الإرسال (سجل جديد)';

  @override
  String kuyrukKaliciHata(Object hata) {
    return 'خطأ دائم: $hata';
  }

  @override
  String get kuyrukEtiketEslesmedi => 'الوسم غير مطابق';

  @override
  String get okutmaImzaGecersiz =>
      'تعذّر التحقق من توقيع الوسم — قد يكون وسماً مزيفاً أو خاطئاً.';

  @override
  String get okutmaTekrarEdilmis => 'تمت معالجة هذا المسح سابقاً.';

  @override
  String okutmaBeklenmeyenHata(Object detay) {
    return 'خطأ غير متوقع: $detay';
  }

  @override
  String get noktaUidZorunlu => 'معرّف NFC إلزامي';

  @override
  String get hataZamanAsimi => 'انتهت المهلة أثناء الاتصال بالخادم.';

  @override
  String get hataSunucuyaUlasilamadi =>
      'تعذّر الوصول إلى الخادم. تحقّق من اتصال الشبكة وعنوان الخادم.';

  @override
  String get destekBaslik => 'الدعم';

  @override
  String get destekYeniTalep => 'طلب جديد';

  @override
  String get destekTalepYok => 'لا توجد لديك طلبات دعم بعد';

  @override
  String destekYuklenemedi(Object hata) {
    return 'تعذّر تحميل الطلبات.\n$hata';
  }

  @override
  String destekGonderilemedi(Object hata) {
    return 'تعذّر إرسال الطلب: $hata';
  }

  @override
  String get destekYeniTalepBaslik => 'طلب دعم جديد';

  @override
  String get destekKonu => 'الموضوع';

  @override
  String get destekGorselEkle => 'أضف صورة';

  @override
  String get destekGorseliDegistir => 'تغيير الصورة';

  @override
  String get destekEkip => 'فريق Yönetiyor';

  @override
  String get tesisKurulumBaslik => 'عرّف مجمّعك';

  @override
  String get tesisKurulumAciklama =>
      'لقد سجّلت الدخول كمدير لأول مرة. للمتابعة، أدخل اسم مجمّعك؛ ويمكنك تغييره لاحقاً من الإعدادات.';

  @override
  String get tesisAdiIpucu => 'مثال: مجمّع نموذجي';

  @override
  String get tesisAdiKisa => 'يجب أن يكون اسم المجمّع حرفين على الأقل';

  @override
  String get tesisOlustur => 'إنشاء المجمّع';

  @override
  String get tesisAdiGuncellendi => 'تم تحديث اسم المجمّع';

  @override
  String get tesisAdiAciklama =>
      'يظهر في عنوان الشاشة الرئيسية؛ يراه جميع المستخدمين.';

  @override
  String get sikayetYokSakin =>
      'لم تفتح أي شكوى بعد.\nاختر وحدة من خريطة الشكاوى لتقديم شكوى.';

  @override
  String sikayetSatirBaslik(Object daire, Object kategori) {
    return 'الوحدة $daire · $kategori';
  }

  @override
  String get sikayetDurumKapandi => 'مغلقة';

  @override
  String get vardiyaBaslik => 'الورديات';

  @override
  String get vardiyaYuklenemedi => 'تعذّر تحميل الورديات.';

  @override
  String get vardiyaTanimYok => 'لا توجد ورديات معرّفة';

  @override
  String vardiyaSaatAraligi(Object baslangic, Object bitis, Object gunTipi) {
    return '$baslangic - $bitis • $gunTipi';
  }

  @override
  String get vardiyaPersonelAta => 'تعيين موظفين';

  @override
  String vardiyaPersonelBaslik(Object ad) {
    return '$ad — الموظفون';
  }

  @override
  String get vardiyaPersonelGuncellendi => 'تم تحديث موظفي الوردية ✓';

  @override
  String get vardiyaPersonelYuklenemedi => 'تعذّر تحميل الموظفين.';

  @override
  String get vardiyaAtanabilirYok => 'لا يوجد موظفون قابلون للتعيين';

  @override
  String get gunTipiHaftaIci => 'أيام الأسبوع';

  @override
  String get gunTipiHaftaSonu => 'عطلة نهاية الأسبوع';

  @override
  String get gunTipiResmiTatil => 'العطل الرسمية';

  @override
  String get gunTipiHerGun => 'كل يوم';

  @override
  String get yonIletisimBaslik => 'التواصل مع الإدارة';

  @override
  String get yonIletisimAlinamadi => 'تعذّر جلب بيانات الإدارة.';

  @override
  String get yonIletisimTanimliDegil => 'لم تُعرَّف بيانات تواصل الإدارة.';

  @override
  String get yonIletisimMail => 'بريد الإدارة';

  @override
  String get yonIletisimAra => 'اتصل بالمدير';

  @override
  String get aramaBaslatilamadi => 'تعذّر بدء الاتصال';

  @override
  String get aramaYapilamiyor => 'غير قابل للاتصال';

  @override
  String get bildirimYok => 'لا توجد إشعارات';

  @override
  String bildirimYuklenemedi(Object hata) {
    return 'تعذّر تحميل الإشعارات.\n$hata';
  }

  @override
  String get bildirimYeniPush => 'إشعار جديد';

  @override
  String get akisDevriyeOkutma => 'مسح الدورية';

  @override
  String get akisGorevTamamlandi => 'اكتملت المهمة';

  @override
  String get akisAidatOdemesi => 'دفع الرسوم';

  @override
  String get akisTalepAcildi => 'تم فتح الطلب';

  @override
  String get akisTalepIsEmri => 'تحوّل الطلب إلى أمر عمل';

  @override
  String get akisTalepCozuldu => 'تم حل الطلب';

  @override
  String get akisTalepReddedildi => 'تم رفض الطلب';

  @override
  String get akisDaireSikayeti => 'شكوى بشأن وحدة';

  @override
  String get akisAlarmKacirilanTur => 'جولة فائتة';

  @override
  String get akisAlarmEksikCheckpoint => 'نقطة تفتيش ناقصة';

  @override
  String get akisAlarmGecikmisOkutma => 'مسح متأخر';

  @override
  String get akisZiyaretciGirisi => 'دخول زائر';

  @override
  String get akisZiyaretciCikisi => 'خروج زائر';

  @override
  String get akisKargoKaydedildi => 'تم تسجيل الطرد';

  @override
  String get akisKargoTeslimEdildi => 'تم تسليم الطرد';

  @override
  String get akisAracGirisi => 'دخول مركبة';

  @override
  String get akisAracCikisi => 'خروج مركبة';

  @override
  String get akisIhlalKaydi => 'سجل مخالفة';

  @override
  String akisAltDaireTutar(Object daire, Object tutar) {
    return 'الوحدة $daire — $tutar';
  }

  @override
  String akisAltDaireKategori(Object daire, Object kategori) {
    return 'الوحدة $daire — $kategori';
  }

  @override
  String akisAltAdDaire(Object ad, Object daire) {
    return '$ad — الوحدة $daire';
  }

  @override
  String akisAltPlakaDaire(Object plaka, Object daire) {
    return '$plaka — الوحدة $daire';
  }

  @override
  String akisAltPlakaTanim(Object plaka, Object tanim) {
    return '$plaka ($tanim)';
  }

  @override
  String akisAltPlakaDaireTanim(Object plaka, Object daire, Object tanim) {
    return '$plaka — الوحدة $daire ($tanim)';
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
  String get ortakParolayiGoster => 'إظهار كلمة المرور';

  @override
  String get ortakParolayiGizle => 'إخفاء كلمة المرور';

  @override
  String get ortakFotograf => 'صورة';

  @override
  String get ortakFotografiBuyut => 'تكبير الصورة';

  @override
  String get ortakGoster => 'عرض';

  @override
  String get talepRedBaslik => 'رفض الطلب';

  @override
  String get ziyaretciDaireSakinYok => 'لا يوجد ساكن نشط في هذه الوحدة';

  @override
  String get ceviriOtomatik => 'تمت ترجمة هذا المحتوى تلقائيًا';

  @override
  String get ceviriOtomatikKisa => 'ترجمة تلقائية';

  @override
  String get ceviriOrijinaliGor => 'عرض النص الأصلي';

  @override
  String get ceviriCeviriyiGor => 'عرض الترجمة';

  @override
  String get ceviriHazirlaniyor => 'جارٍ إعداد الترجمة — يتم عرض النص الأصلي';

  @override
  String get ceviriHazirlaniyorKisa => 'جارٍ الترجمة';

  @override
  String get ceviriYapilamadi => 'تعذّرت الترجمة — يتم عرض النص الأصلي';

  @override
  String get ceviriYapilamadiKisa => 'تعذّرت الترجمة';

  @override
  String get modulAracGecis => 'مرور المركبات';

  @override
  String get modulOtopark => 'مواقف السيارات';

  @override
  String get modulIhlaller => 'المخالفات';

  @override
  String get aracSuzgecTumu => 'الكل';

  @override
  String get aracSuzgecIceride => 'بالداخل';

  @override
  String get aracSuzgecCikmis => 'غادرت';

  @override
  String get aracPlakaAra => 'البحث عن لوحة';

  @override
  String get aracListeBos => 'لا توجد حركات مرور مسجّلة';

  @override
  String get aracAramaBos => 'لا توجد حركة مطابقة لهذه اللوحة';

  @override
  String get aracRozetIceride => 'بالداخل';

  @override
  String get aracRozetCikti => 'غادرت';

  @override
  String get aracRozetZiyaretci => 'زائر';

  @override
  String aracGirisZamani(Object zaman) {
    return 'الدخول: $zaman';
  }

  @override
  String aracCikisZamani(Object zaman) {
    return 'الخروج: $zaman';
  }

  @override
  String aracDaire(Object no) {
    return 'الشقة $no';
  }

  @override
  String get aracCikisVer => 'تسجيل الخروج';

  @override
  String get aracCikisOnayBaslik => 'هل تُسجَّل مغادرة المركبة؟';

  @override
  String get aracCikisVerildi => 'تم تسجيل الخروج';

  @override
  String get aracZatenKapali => 'تم إغلاق هذه الحركة مسبقًا';

  @override
  String get aracYeniGiris => 'دخول جديد';

  @override
  String get aracGirisKaydedildi => 'تم تسجيل دخول المركبة';

  @override
  String get aracPlaka => 'اللوحة';

  @override
  String get aracPlakaZorunlu => 'اللوحة مطلوبة';

  @override
  String get aracTanimAlani => 'وصف المركبة (اختياري)';

  @override
  String get aracDaireAlani => 'رقم الشقة (اختياري)';

  @override
  String get aracZiyaretciMi => 'مركبة زائر';

  @override
  String get aracZatenIceride =>
      'لهذه اللوحة حركة مفتوحة بالفعل (المركبة بالداخل)';

  @override
  String get aracErisimYok => 'قائمة مرور المركبات مخصّصة للإدارة والأمن فقط';

  @override
  String aracKaydeden(Object ad) {
    return 'سجّلها: $ad';
  }

  @override
  String get otoparkDoluEtiket => 'مشغول';

  @override
  String get otoparkBosEtiket => 'شاغر';

  @override
  String get otoparkKapasiteEtiket => 'السعة';

  @override
  String get otoparkKapasiteTanimsiz =>
      'لم تُحدَّد السعة — يُعرض عدد المركبات بالداخل فقط';

  @override
  String get otoparkAracListesi => 'فتح حركات المركبات';

  @override
  String get ihlalDurumYeni => 'جديد';

  @override
  String get ihlalDurumInceleniyor => 'قيد المراجعة';

  @override
  String get ihlalDurumKapatildi => 'مغلق';

  @override
  String get ihlalKaynakKamera => 'كاميرا';

  @override
  String get ihlalKaynakManuel => 'يدوي';

  @override
  String get ihlalKaynakDevriye => 'دورية';

  @override
  String get ihlalListeBos => 'لا توجد سجلات مخالفات';

  @override
  String get ihlalYeni => 'مخالفة جديدة';

  @override
  String get ihlalAcildi => 'تم إنشاء سجل المخالفة';

  @override
  String get ihlalBaslikAlani => 'العنوان';

  @override
  String get ihlalBaslikZorunlu => 'العنوان مطلوب';

  @override
  String get ihlalAciklamaAlani => 'الوصف (اختياري)';

  @override
  String get ihlalKonumAlani => 'الموقع (اختياري)';

  @override
  String get ihlalKaynakAlani => 'مصدر الرصد';

  @override
  String get ihlalIncelemeyeAl => 'بدء المراجعة';

  @override
  String get ihlalKapat => 'إغلاق السجل';

  @override
  String get ihlalDurumGuncellendi => 'تم تحديث حالة المخالفة';

  @override
  String get ihlalKapatmaOnay =>
      'هل تُغلق هذا السجل؟ لا يمكن إعادة فتح المخالفة المغلقة.';

  @override
  String get ihlalKapaliDegistirilemez => 'لا يمكن إعادة فتح مخالفة مغلقة';

  @override
  String get ihlalErisimYok => 'سجلات المخالفات مخصّصة للإدارة والأمن فقط';

  @override
  String ihlalKaydeden(Object ad) {
    return 'فتحها: $ad';
  }

  @override
  String get kameraRestream => 'عنوان إعادة البث (اختياري)';

  @override
  String get kameraRestreamAlt =>
      'يجعل كاميرا RTSP قابلة للتشغيل. عنوان HLS لبوابة Frigate/go2rtc.';

  @override
  String get kameraRestreamHata =>
      'يجب أن يبدأ عنوان إعادة البث بـ http:// أو https://';

  @override
  String get kameraRestreamRozet => 'عبر البوابة';

  @override
  String get modulPlakaOlaylari => 'قراءات اللوحات';

  @override
  String get anprDurumIslendi => 'تمت المعالجة';

  @override
  String get anprDurumOnayBekliyor => 'بانتظار الموافقة';

  @override
  String get anprDurumYokSayildi => 'تم التجاهل';

  @override
  String get anprDurumHata => 'خطأ';

  @override
  String get anprYonGiris => 'دخول';

  @override
  String get anprYonCikis => 'خروج';

  @override
  String get anprYonBilinmiyor => 'الاتجاه غير معروف';

  @override
  String get anprListeBos => 'لا توجد قراءات لوحات';

  @override
  String get anprErisimYok => 'قراءات اللوحات مخصّصة للإدارة والأمن فقط';

  @override
  String anprGuven(Object oran) {
    return 'الثقة $oran%';
  }

  @override
  String get anprOnayla => 'موافقة';

  @override
  String get anprReddet => 'رفض';

  @override
  String get anprOnayBaslik => 'الموافقة على القراءة';

  @override
  String get anprOnayAciklama =>
      'يمكنك تصحيح اللوحة إذا قُرئت خطأً. الموافقة تفتح أو تغلق حركة المركبة.';

  @override
  String get anprKararUygulandi => 'تم تطبيق القرار';

  @override
  String get anprOnayBeklemiyor => 'لم تعد هذه القراءة بانتظار الموافقة';

  @override
  String get anprNedenDusukGuven => 'ثقة منخفضة';

  @override
  String get anprNedenZatenIceride => 'المركبة بالداخل بالفعل';

  @override
  String get anprNedenAcikGecisYok => 'لا توجد حركة مفتوحة';

  @override
  String get anprNedenOtomatikCikisKapali => 'الخروج التلقائي مُعطَّل';

  @override
  String get anprNedenElleReddedildi => 'رُفضت يدويًا';

  @override
  String get anprNedenPlakaBicimi => 'تعذّرت قراءة اللوحة';

  @override
  String get aracPlakaOkumalari => 'قراءات اللوحات';

  @override
  String get kategoriGoruntuKirliligi => 'تلوّث بصري';

  @override
  String get fabSikayetBildir => 'الإبلاغ عن شكوى جار';

  @override
  String get sakinRolTipi => 'نوع العلاقة';

  @override
  String get sakinRolMalik => 'المالك';

  @override
  String get sakinRolKiraci => 'مستأجر';

  @override
  String get sakinRolDegisme => 'دون تغيير';

  @override
  String get sakinRolAlt =>
      'تُحمّل الرسوم على المستأجر ونفقات الاستثمار على المالك.';

  @override
  String get sakinEposta => 'البريد الإلكتروني';

  @override
  String get sakinEpostaTemizle => 'إزالة البريد الإلكتروني';

  @override
  String get sakinRolBagYok => 'يجب ربط الساكن بشقة لتحديد نوع العلاقة';

  @override
  String get sikayetKuyruguBaslik => 'قائمة الشكاوى';

  @override
  String get sikayetSekmeYeni => 'جديد';

  @override
  String get sikayetSekmeTumu => 'الكل';

  @override
  String get sikayetOkunmamisYok => 'لا توجد شكاوى غير مقروءة.';

  @override
  String get sikayetYokYonetim => 'لا توجد شكاوى بعد.';

  @override
  String get sikayetOkunduIsaretle => 'وضع علامة كمقروء';

  @override
  String sikayetOkunmamisRozet(int sayi) {
    return '$sayi شكاوى غير مقروءة';
  }

  @override
  String get kameraHataAdresBozuk =>
      'عنوان البث غير صالح. قد يحتوي على مسافة أو سطر جديد زائد.';

  @override
  String get kameraHataSemaDesteklenmiyor =>
      'لا يمكن تشغيل هذا النوع من العناوين مباشرة. حدّد عنوان إعادة بث للكاميرا.';

  @override
  String get kameraHataSifrelenmemis =>
      'حظر الجهاز البث غير المشفّر (http). قد يمنعه ملف تعريف العمل أو شبكة VPN.';

  @override
  String kameraUrlCokUzun(int sinir) {
    return 'عنوان البث طويل جدًا (بحد أقصى $sinir حرفًا).';
  }

  @override
  String get kameraUrlSifrelenmemisUyari =>
      'هذا العنوان غير مشفّر (http). استخدم https إن أمكن.';

  @override
  String get modulDaireTanimlari => 'أنواع الوحدات';

  @override
  String get daireTanimSekmeTipler => 'الأنواع';

  @override
  String get daireTanimSekmeGruplar => 'المجموعات';

  @override
  String get daireTanimAd => 'الاسم';

  @override
  String get daireTanimAdIpucu => 'مثال: 2+1، دوبلكس، فيلا';

  @override
  String get daireTanimVarsayilanAidat => 'الرسوم الافتراضية';

  @override
  String get daireTanimAidatBos => 'غير محدد';

  @override
  String get daireTanimAidatAlt =>
      'تركه فارغًا يعني غير محدد؛ وكتابة 0 تعني معفى.';

  @override
  String daireTanimDaireSayisi(int sayi) {
    return '$sayi وحدة';
  }

  @override
  String daireTanimSilOnay(int sayi) {
    return 'حذف هذا التعريف؟ لن تُحذف الوحدات المرتبطة ($sayi)، بل يُمسح تصنيفها فقط.';
  }

  @override
  String daireTanimSilindiEtki(int sayi) {
    return 'تم الحذف. فقدت $sayi وحدة تصنيفها.';
  }

  @override
  String get daireTanimYok => 'لا توجد تعريفات بعد.';

  @override
  String get daireTanimYeni => 'تعريف جديد';

  @override
  String get daireTipiSecici => 'نوع الوحدة';

  @override
  String get daireGrubuSecici => 'مجموعة الوحدة';

  @override
  String get daireTanimSecilmedi => 'لم يتم الاختيار';

  @override
  String get odeBaslik => 'ادفع';

  @override
  String get odeBorcunuz => 'المبلغ المستحق';

  @override
  String get odeHavaleBaslik => 'حوالة بنكية';

  @override
  String get odeHavaleAdim =>
      'حوّل إلى الآيبان واكتب الرمز أدناه في الوصف. بدون الرمز قد لا تتم مطابقة دفعتك.';

  @override
  String get odeKodBaslik => 'رمز المرجع الخاص بك';

  @override
  String get odeKopyala => 'نسخ';

  @override
  String get odeKopyalandi => 'تم النسخ';

  @override
  String get odeKartBaslik => 'الدفع بالبطاقة';

  @override
  String get odeKartKapali =>
      'الدفع بالبطاقة غير مفعّل بعد. يمكنك استخدام الحوالة البنكية حاليًا.';

  @override
  String get odeHavaleKapali =>
      'لم يحدد المجمع حسابًا بنكيًا بعد. يرجى مراجعة الإدارة.';

  @override
  String get odeBorcYok => 'ليس لديك دين مستحق.';

  @override
  String get odeBasarili => 'تم استلام دفعتك.';

  @override
  String get nfcFotoGerekli => 'الصورة مطلوبة لبدء الجولة.';

  @override
  String get nfcFotoCek => 'التقاط صورة وإرسال';

  @override
  String get nfcFotoYukleniyor => 'جارٍ رفع الصورة...';

  @override
  String nfcFotoYuklenemedi(String hata) {
    return 'فشل رفع الصورة: $hata';
  }

  @override
  String get nfcKonumYok => 'تعذّر تحديد الموقع — تم تسجيل المسح بدون موقع.';

  @override
  String get nfcKonumIzinYok =>
      'لم يُمنح إذن الموقع — تم تسجيل المسح بدون موقع.';

  @override
  String get nfcKonumServisKapali =>
      'خدمة الموقع مغلقة — تم تسجيل المسح بدون موقع.';

  @override
  String get rolGuvenlikAmiri => 'رئيس الأمن';

  @override
  String get rolDenetci => 'مدقق الحسابات';

  @override
  String get kvkkBaslik => 'إشعار الخصوصية';

  @override
  String get kvkkSonaKaydir => 'مرّر إلى نهاية النص للموافقة.';

  @override
  String get kvkkOnayliyorum => 'قرأت وأوافق';

  @override
  String get kvkkYuklenemedi => 'تعذّر تحميل إشعار الخصوصية.';

  @override
  String get kvkkTekrarDene => 'حاول مجددًا';

  @override
  String get kvkkSurumDegisti => 'تم تحديث النص؛ يرجى قراءة الإصدار الجديد.';

  @override
  String get kvkkIzinBaslik => 'الحملات والعروض الخاصة بي';

  @override
  String get kvkkIzinAciklama =>
      'اختياري تمامًا؛ يمكنك المتابعة دون الموافقة. يمكنك تغييره في أي وقت من الإعدادات.';

  @override
  String get kvkkIzinEposta => 'أرغب في تلقي البريد الإلكتروني';

  @override
  String get kvkkIzinSms => 'أرغب في تلقي الرسائل النصية';

  @override
  String get kvkkIzinArama => 'أرغب في تلقي المكالمات';

  @override
  String get kvkkIzinKaydedilemedi => 'تعذّر حفظ التفضيل.';

  @override
  String get kvkkAyarlarBaslik => 'الأذونات وإشعار الخصوصية';

  @override
  String get kvkkMetniGoruntule => 'عرض إشعار الخصوصية';

  @override
  String get anketBaslik => 'الاستطلاعات';

  @override
  String get anketYok => 'لا يوجد استطلاع مفتوح حاليًا.';

  @override
  String get anketKapali => 'مغلق';

  @override
  String get anketOyVerdiniz => 'تم تسجيل صوتك';

  @override
  String get anketOyVer => 'صوّت';

  @override
  String anketToplamOy(int sayi) {
    return '$sayi صوت';
  }

  @override
  String anketOyHatasi(String hata) {
    return 'تعذّر إرسال التصويت: $hata';
  }

  @override
  String get anketSonucKapali => 'تظهر النتائج عند إغلاق الاستطلاع.';

  @override
  String get modulAnketler => 'الاستطلاعات';

  @override
  String get hesapSilBolum => 'الحساب';

  @override
  String get hesapSilBaslik => 'حذف حسابي';

  @override
  String get hesapSilAlt => 'احذف حسابك وبياناتك الشخصية نهائيًا';

  @override
  String get hesapSilOnayBaslik => 'هل تريد حذف حسابك؟';

  @override
  String get hesapSilOnayGovde =>
      'سيتم حذف اسمك ورقم هاتفك وبريدك الإلكتروني وسجلات أجهزتك، ولن تتمكن من تسجيل الدخول مرة أخرى. لا يمكن حذف سجلات الرسوم والمدفوعات لأننا ملزمون قانونًا بحفظها؛ ستبقى مخزَّنة بشكل مجهول الهوية وغير مرتبطة باسمك.';

  @override
  String get hesapSilParolaEtiket => 'كلمة المرور';

  @override
  String get hesapSilParolaAciklama =>
      'أدخل كلمة المرور مرة أخرى للتحقق من هويتك.';

  @override
  String get hesapSilOnayla => 'احذف حسابي نهائيًا';

  @override
  String get hesapSilSonucSilindi => 'تم حذف حسابك.';

  @override
  String get hesapSilSonucAnonim =>
      'تم حذف حسابك. تم جعل السجلات التي يلزمنا القانون بحفظها مجهولة الهوية.';

  @override
  String get hesapSilParolaGerekli => 'أدخل كلمة المرور للمتابعة.';

  @override
  String get hesapSilSiliniyor => 'جارٍ الحذف...';

  @override
  String get ayarlarHukuki => 'قانوني';

  @override
  String get ayarlarGizlilik => 'سياسة الخصوصية';

  @override
  String get ayarlarKosullar => 'شروط الاستخدام';

  @override
  String get ayarlarBelgeAcilamadi =>
      'تعذّر فتح الصفحة. تحقّق من اتصالك بالإنترنت.';

  @override
  String get demoSimuleOkutma => 'مسح محاكى';

  @override
  String demoSimuleOkutmaBasarili(String nokta) {
    return 'تم تسجيل المسح المحاكى: $nokta';
  }

  @override
  String get demoSimuleOkutmaHata => 'تعذّر تسجيل المسح المحاكى.';

  @override
  String get denetciWebBaslik => 'شاشات التدقيق على الويب';

  @override
  String denetciWebGovde(String adres) {
    return 'تقارير التدقيق والإشراف المالي مصمَّمة لسطح المكتب. افتح $adres على حاسوبك.';
  }

  @override
  String get denetciWebKopyala => 'نسخ العنوان';

  @override
  String get modulVardiyalar => 'الورديات';

  @override
  String get izgaraDuzenleBaslik => 'تعديل الشاشة الرئيسية';

  @override
  String izgaraDuzenleAciklama(int enCok) {
    return 'اختر حتى $enCok أقسام تستخدمها كثيرًا.';
  }

  @override
  String get izgaraSifirla => 'استعادة الإعدادات الافتراضية';

  @override
  String get izgaraKaydet => 'حفظ';

  @override
  String izgaraSecim(int secili, int enCok) {
    return '$secili/$enCok محدد';
  }

  @override
  String izgaraTavanUyarisi(int enCok) {
    return 'لقد وصلت إلى الحد. أزل واحدًا لإضافة آخر ($enCok مربعات).';
  }

  @override
  String get dilSeciciBaslik => 'اللغة';

  @override
  String get talepGeriAl => 'سحب';

  @override
  String get talepGeriAlOnay =>
      'هل تريد سحب هذا الطلب؟ الطلب المسحوب لا يُرسل إلى الإدارة ولا يمكن التراجع عن هذا الإجراء.';

  @override
  String get talepGeriAlindi => 'تم سحب الطلب';

  @override
  String get talepDurumGeriAlindi => 'مسحوب';

  @override
  String get sikayetGeriAl => 'سحب الشكوى';

  @override
  String get sikayetGeriAlindi => 'تم سحب الشكوى';

  @override
  String get izinDevam => 'متابعة';

  @override
  String get izinKonumBaslik => 'لماذا نحتاج إذن الموقع؟';

  @override
  String get izinKonumGovde =>
      'عند مسح نقطة الدورية، يُسجَّل موقعك في تلك اللحظة للتأكد من أن الجولة تمت فعليًا في الموقع. يُلتقط الموقع فقط لحظة المسح؛ التطبيق لا يتتبعك في الخلفية.';

  @override
  String get izinKameraBaslik => 'لماذا نحتاج إذن الكاميرا؟';

  @override
  String get izinKameraGovde =>
      'تُستخدم الكاميرا لتتمكن من إرفاق صورة عند الإبلاغ عن طلب أو عطل. لا تُلتقط الصورة إلا عندما تلتقطها أنت، وتُرسل إلى إدارة المجمع.';

  @override
  String get girisKodlaBaslik => 'لا كلمة مرور — سجّل الدخول برمز';

  @override
  String get girisKodlaAciklama => 'سنرسل رمز تحقق من ستة أرقام إلى هاتفك.';

  @override
  String get girisKoduGonder => 'إرسال الرمز';

  @override
  String get girisKodAlani => 'رمز التحقق';

  @override
  String get hesapSilKodlaOnayla => 'لا كلمة مرور — أكّد برمز';

  @override
  String get hesapSilKodAciklama =>
      'سنرسل رمزًا مكوّنًا من ستة أرقام إلى بريدك الإلكتروني لتأكيد الحذف.';

  @override
  String get hesapSilKodGerekli => 'أدخل رمز التأكيد';

  @override
  String get kayitBaslik => 'تسجيل الدخول بمعرّف المنشأة';

  @override
  String get kayitAltBaslik => 'اختر ما ينطبق عليك';

  @override
  String get kayitRolYonetici => 'مدير';

  @override
  String get kayitRolSakin => 'ساكن';

  @override
  String get kayitRolGuvenlik => 'ضابط أمن';

  @override
  String get kayitRolTesisGorevlisi => 'موظف المنشأة';

  @override
  String get kayitTesisKodu => 'معرّف المنشأة';

  @override
  String get kayitTesisKoduIpucu =>
      'الرمز الذي أعطته لك الإدارة (مثل OLTU-260715)';

  @override
  String get kayitDaireNo => 'رقم الوحدة';

  @override
  String get kayitBlok => 'المبنى (إن وجد)';

  @override
  String get kayitDevam => 'متابعة';

  @override
  String get kayitKodBaslik => 'رمز التحقق';

  @override
  String kayitKodAciklama(String tesis, String telefon) {
    return 'تم إرسال رمز إلى $telefon من أجل $tesis. إذا لم يكن الرقم مسجّلاً فلن يصل رمز.';
  }

  @override
  String get kayitKodAlani => 'رمز من 6 أرقام';

  @override
  String get kayitTesisKoduGerekli => 'معرّف المنشأة مطلوب.';

  @override
  String get kayitDaireGerekli => 'رقم الوحدة مطلوب.';

  @override
  String get kayitKodGerekli => 'أدخل الرمز.';

  @override
  String get kayitYontemBaslik => 'كيف ستسجّل الدخول؟';

  @override
  String get kayitYontemParola => 'إنشاء كلمة مرور';

  @override
  String get kayitGirisLinki => 'لديك حساب بالفعل؟ سجّل الدخول';

  @override
  String kayitAdim(String n, String toplam) {
    return 'الخطوة $n/$toplam';
  }

  @override
  String sosyalIleDevam(String saglayici) {
    return 'المتابعة عبر $saglayici';
  }

  @override
  String get sosyalBaslik => 'طابق حسابك';

  @override
  String sosyalEslesmeAciklama(String saglayici) {
    return 'تم التحقق من حساب $saglayici. أدخل معرّف المنشأة ورقم هاتفك لنتمكن من العثور على حسابك.';
  }

  @override
  String get sosyalRelayUyari =>
      'أخفت Apple عنوان بريدك؛ لا يمكن إرسال بريد إليه.';

  @override
  String get sosyalTesisKodu => 'معرّف المنشأة';

  @override
  String get sosyalKodGonder => 'إرسال رمز التحقق';

  @override
  String sosyalKodAciklama(String tesis, String telefon) {
    return '$tesis — أدخل الرمز المُرسل إلى $telefon.';
  }

  @override
  String get sosyalDogrula => 'تحقق وسجّل الدخول';

  @override
  String get sosyalVazgec => 'إلغاء';

  @override
  String get davetBaslik => 'التسجيل';

  @override
  String get davetGecersizBaslik => 'الرابط لا يعمل';

  @override
  String get davetSuresiDoldu => 'انتهت صلاحية رابط الدعوة هذا.';

  @override
  String get davetKullanilmis => 'تم استخدام هذه الدعوة بالفعل.';

  @override
  String get davetBulunamadi => 'رابط الدعوة هذا غير صالح.';

  @override
  String get davetYoneticinizeBasvurun =>
      'تواصل مع المسؤول للحصول على دعوة جديدة.';

  @override
  String davetOzet(String tesis, String rol) {
    return 'دعاك $tesis بصفة $rol.';
  }

  @override
  String get kayitYontemEposta => 'المتابعة بالبريد الإلكتروني';

  @override
  String get kayitYontemVeya => 'أو';

  @override
  String get kayitBilgilerBaslik => 'بياناتك';

  @override
  String get kayitAdSoyad => 'الاسم الكامل';

  @override
  String get kayitAdGerekli => 'الاسم الكامل مطلوب.';

  @override
  String get kayitParola => 'كلمة المرور';

  @override
  String get kayitParolaGerekli => 'يجب ألا تقل كلمة المرور عن ٨ أحرف.';

  @override
  String get kayitTesisAdBaslik => 'أنشئ مجمّعك';

  @override
  String get kayitTesisAd => 'أدخل اسم المجمّع';

  @override
  String get kayitTesisAdIpucu => 'مثال: مجمّع أولتو';

  @override
  String get kayitTesisAdGerekli => 'اسم المجمّع مطلوب.';

  @override
  String get kayitZatenSitemVar => 'لديّ مجمّع بالفعل';

  @override
  String get kayitTesisKoduBaslik => 'رمز مجمّعك';

  @override
  String get kayitTesisKoduPaylas =>
      'شارك هذا الرمز مع السكان والموظفين؛ به ينضمّون إلى التطبيق.';

  @override
  String get kayitKopyala => 'نسخ';

  @override
  String get kayitKopyalandi => 'تم النسخ';

  @override
  String get kayitTamamla => 'متابعة';

  @override
  String get kayitSosyalAdNotu => 'تم أخذ الاسم من حسابك، ويمكنك تغييره.';

  @override
  String get kayitEposta => 'البريد الإلكتروني';

  @override
  String get kayitEpostaGerekli => 'عنوان البريد الإلكتروني مطلوب.';

  @override
  String get kayitEpostaGecersiz => 'أدخل بريدًا إلكترونيًا صالحًا.';

  @override
  String get kayitTelefonIletisim => 'الهاتف (اختياري)';

  @override
  String get kayitTelefonNotu =>
      'الهاتف للتواصل فقط؛ يتم التحقق عبر البريد الإلكتروني.';

  @override
  String get kayitTesisKoduGir => 'أدخل معرّف المنشأة الخاص بك';

  @override
  String kayitKodAciklamaEposta(String tesis) {
    return 'أرسلنا رمز تحقق إلى بريدك الإلكتروني للمنشأة $tesis. إذا لم يكن عنوانك مسجلًا، فلن يصل أي رمز.';
  }

  @override
  String get kayitOnayBekliyorBaslik => 'في انتظار موافقة المدير';

  @override
  String get kayitOnayBekliyorAciklama =>
      'تعذّر التحقق من بياناتك وتم إرسالها إلى مديرك للموافقة. تحقق من معرّف المنشأة الخاص بك؛ وإذا استمرت المشكلة، فاستشر مديرك. بعد الموافقة يمكنك تسجيل الدخول.';

  @override
  String get kayitGiriseDon => 'العودة إلى تسجيل الدخول';

  @override
  String get sosyalTamamlaBaslik => 'الإكمال بمعرّف المنشأة';

  @override
  String sosyalTamamlaAciklama(String saglayici) {
    return 'تم التحقق من حساب $saglayici الخاص بك. للإكمال، أدخل دورك ومعرّف المنشأة الخاص بك.';
  }

  @override
  String get sosyalRol => 'دورك';

  @override
  String get sosyalTamamla => 'إكمال';

  @override
  String get sosyalOtpAciklama =>
      'أدخل رمز التحقق المُرسَل إلى بريدك الإلكتروني.';

  @override
  String get binaYapisalAraclar => 'أدوات هيكلية';

  @override
  String get binaKatSil => 'حذف الطابق';

  @override
  String get binaTopluTip => 'تغيير الحالة دفعة واحدة';

  @override
  String get binaSiralama => 'تعديل الترتيب';

  @override
  String binaKatSilOzet(int n) {
    return 'سيتم حذف $n شقة';
  }

  @override
  String binaKatSilOnay(int kat) {
    return 'سيتم حذف جميع شقق الطابق $kat نهائيًا. لا يمكن التراجع.';
  }

  @override
  String get binaAralikSec => 'اختيار بالرقم';

  @override
  String get binaAralikUygula => 'اختيار';

  @override
  String binaSeciliSayisi(int n) {
    return '$n شقة محددة';
  }

  @override
  String binaAralikBulunamayan(String parca) {
    return 'غير موجود: $parca';
  }

  @override
  String get ortakEminMisiniz => 'هل أنت متأكد؟';

  @override
  String get ortakDurum => 'الحالة';

  @override
  String get ortakAktif => 'نشط';

  @override
  String get ortakPasif => 'غير نشط';

  @override
  String get binaBaslangicKat => 'الطابق الأول';

  @override
  String get binaBaslangicKatIpucu => 'سالب للأقبية: -2، -1، 0 (الأرضي)، 1…';

  @override
  String get rezSekmeGecmis => 'السابقة';

  @override
  String get rezGecmisYok => 'لا توجد حجوزات سابقة.';

  @override
  String get rezGecmisTamam => 'مكتمل';

  @override
  String rezIptalEden(String ad) {
    return 'ألغاه: $ad';
  }

  @override
  String get binaKatBos =>
      'لا توجد شقق في هذا الطابق؛ الحذف لن يؤثر على أي سجل.';

  @override
  String binaKatOzet(int daire, int sakin, int talep) {
    return '$daire شقة · $sakin ساكن · $talep شكوى مفتوحة';
  }

  @override
  String binaKatOzetMali(int tahakkuk, int odeme, int rezervasyon) {
    return '$tahakkuk استحقاق · $odeme تحصيل · $rezervasyon حجز';
  }

  @override
  String get binaKatMaliUyari =>
      'يحتوي هذا الطابق على سجلات رسوم. الحذف يزيل الاستحقاقات والتحصيلات نهائيًا ولا يمكن استرجاع الأثر المحاسبي. فكّر في إلغاء تنشيط الشقق بدلًا من ذلك.';

  @override
  String binaKatOnayYaz(int kat) {
    return 'اكتب رقم الطابق للتأكيد ($kat)';
  }

  @override
  String binaKatSilOzetOnay(
    String blok,
    int kat,
    int daire,
    int sakin,
    int kayit,
  ) {
    return 'سيتم حذف الطابق $kat من المبنى $blok: $daire شقة و$sakin ساكن و$kayit سجلًا مرتبطًا نهائيًا. لا يمكن التراجع.';
  }

  @override
  String get kurulumBaslik => 'معالج الإعداد';

  @override
  String get kurulumAlt => 'أكمل الخطوات لتجهيز مرفقك للاستخدام.';

  @override
  String get kurulumIlerleme => 'التقدم';

  @override
  String get kurulumTamamlandi => 'اكتمل الإعداد';

  @override
  String kurulumAdimTamam(int sayi) {
    return '$sayi سجل';
  }

  @override
  String get kurulumAdimAtlandi => 'تم التخطي';

  @override
  String get kurulumAdimBekliyor => 'قيد الانتظار';

  @override
  String get kurulumGit => 'انتقال';

  @override
  String get kurulumGoruntule => 'عرض';

  @override
  String get kurulumAtla => 'تخطٍ';

  @override
  String get kurulumAtlamayiGeriAl => 'تراجع عن التخطي';

  @override
  String kurulumSayac(int gecilen, int toplam) {
    return '$gecilen/$toplam خطوة';
  }

  @override
  String get kurulumHata => 'تعذر تحميل حالة الإعداد.';

  @override
  String get kurulumBlok => 'الكتل';

  @override
  String get kurulumBlokAlt => 'عرّف كتل المبنى.';

  @override
  String get kurulumDaire => 'الوحدات';

  @override
  String get kurulumDaireAlt => 'أنشئ الطوابق والوحدات دفعةً واحدة.';

  @override
  String get kurulumDaireTipi => 'أنواع الوحدات';

  @override
  String get kurulumDaireTipiAlt => 'عرّف الأنواع ومبالغ الرسوم الافتراضية.';

  @override
  String get kurulumSakin => 'السكان';

  @override
  String get kurulumSakinAlt => 'أضف السكان إلى الوحدات.';

  @override
  String get kurulumPersonel => 'الموظفون';

  @override
  String get kurulumPersonelAlt => 'أدخل سجلات الموظفين.';

  @override
  String get kurulumGorevAlani => 'فئات المهام';

  @override
  String get kurulumGorevAlaniAlt => 'أنشئ الفئات التي ستُجمَّع المهام ضمنها.';

  @override
  String get kurulumNfc => 'نقاط NFC';

  @override
  String get kurulumNfcAlt => 'عرّف نقاط تفتيش الدوريات.';

  @override
  String get kurulumAidat => 'تحميل الرسوم';

  @override
  String get kurulumAidatAlt => 'حمّل رسوم الفترة الأولى على الوحدات.';

  @override
  String get kurulumAdimWebde =>
      'يمكن تنفيذ هذه الخطوة حاليًا من لوحة الويب فقط وبحساب مسؤول المنصة.';

  @override
  String get kurulumHatirlaticiBaslik => 'أكمل الإعداد';

  @override
  String get kurulumHatirlaticiMetin =>
      'بقيت بضع خطوات حتى يصبح مرفقك جاهزًا. سيأخذك المعالج إلى كل شاشة.';

  @override
  String get kurulumHatirlaticiGit => 'فتح المعالج';

  @override
  String get kurulumHatirlaticiSonra => 'لاحقًا';

  @override
  String get noktaYokAlt =>
      'نقاط التفتيش هي بطاقات NFC التي تُقرأ أثناء جولات الدورية.';

  @override
  String get devriyePlanYokAlt => 'تحدد خطة الدورية أي النقاط تُقرأ ومتى.';

  @override
  String get personelYokAlt => 'من هنا تُنشئ حسابات الأمن وموظفي المرفق.';

  @override
  String get sakinYokAlt =>
      'يُربط السكان المضافون بالوحدات ويمكنهم تسجيل الدخول إلى التطبيق.';

  @override
  String get ortakDahaFazlaSecenek => 'خيارات إضافية';

  @override
  String get modulDokumanlar => 'مستندات المجمع';

  @override
  String get dokumanBaslik => 'مستندات المجمع';

  @override
  String get dokumanAra => 'ابحث في أسماء المستندات';

  @override
  String get dokumanYokSakin => 'لم تتم مشاركة أي مستندات بعد.';

  @override
  String get dokumanAramaSonucYok => 'لا يوجد مستند يطابق بحثك.';

  @override
  String get dokumanAcilamadi => 'تعذّر فتح المستند.';

  @override
  String dokumanBoyutKb(int kb) {
    return '$kb كيلوبايت';
  }

  @override
  String get kvkkYasalMetinler => 'النصوص القانونية';

  @override
  String get kvkkTurAydinlatma => 'نص الإفصاح';

  @override
  String get kvkkTurAcikRiza => 'الموافقة الصريحة';

  @override
  String get kvkkTurGizlilik => 'سياسة الخصوصية';

  @override
  String get kvkkTurKullanim => 'شروط الاستخدام';

  @override
  String get kvkkTurCerez => 'سياسة ملفات الارتباط';

  @override
  String get kvkkMetinYayinlanmamis => 'لم يُنشر هذا النص بعد.';

  @override
  String get kvkkOnaylanmadi => 'لم توافق على هذا النص بعد.';

  @override
  String get kvkkYenidenOnayBekleniyor =>
      'في انتظار موافقتك على الإصدار الحالي.';

  @override
  String kvkkSurumEtiketi(int n) {
    return 'الإصدار $n';
  }

  @override
  String kvkkOnayladiginizSurum(int n) {
    return 'الإصدار الذي وافقت عليه: $n';
  }

  @override
  String get kabukKisayollar => 'الاختصارات';

  @override
  String get ayarlarBildirimlerBaslik => 'الإشعارات';

  @override
  String get ayarlarBildirimTercih => 'تفضيلات الإشعارات';

  @override
  String get ayarlarBildirimAciklama =>
      'اختر القنوات التي تصلك منها الإشعارات التشغيلية. هذا منفصل عن موافقة التسويق.';

  @override
  String get ayarlarBildirimEposta => 'إشعارات البريد الإلكتروني';

  @override
  String get ayarlarBildirimSms => 'إشعارات الرسائل النصية';

  @override
  String get ayarlarBildirimMobil => 'الإشعارات على الجوال';

  @override
  String get ayarlarBildirimKaydedildi => 'تم تحديث تفضيل الإشعارات';

  @override
  String get ayarlarBildirimYuklenemedi => 'تعذّر تحميل تفضيلات الإشعارات';

  @override
  String get ayarlarBildirimIzinKapali =>
      'إذن الإشعارات على الجهاز مغلق. لن تظهر إشعارات الجوال على الهاتف؛ فعّله من إعدادات الجهاز.';

  @override
  String get ayarlarBildirimIzinBelirsiz => 'يلزم إذن لعرض الإشعارات.';

  @override
  String get ayarlarBildirimIzinIste => 'طلب الإذن';
}
