// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get ortakKaydet => 'حفظ';

  @override
  String sayacBekliyor(int n) {
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
  String ortakZorunluAlan(String alan) {
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
  String kameraUrlHataHttp(String tur) {
    return 'يجب أن يبدأ رابط بث $tur بـ http:// أو https://';
  }

  @override
  String get kameraUrlHataRtsp => 'يجب أن يبدأ رابط بث RTSP بـ rtsp://';

  @override
  String get kameraSilBaslik => 'حذف الكاميرا';

  @override
  String kameraSilOnay(String ad) {
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
  String kameraTurEtiket(String tur) {
    return 'النوع: $tur';
  }

  @override
  String get kameraRtspBilgi =>
      'لا يمكن تشغيل بثوث RTSP داخل التطبيق حالياً. السجل محفوظ في النظام، وستُضاف إمكانية التشغيل لاحقاً.';

  @override
  String get kameraSeritBaslik => 'كاميرا مباشرة';
}
