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
  String get sekmeAyarlar => 'الإعدادات';

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
}
