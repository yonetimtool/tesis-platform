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
}
