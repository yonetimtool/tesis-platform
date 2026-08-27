/// Push (FCM) ozelliginin domain modelleri. Firebase tipleri buraya sizmaz;
/// servis katmani [PushMessageEvent] gibi sade tiplere cevirir.
library;

/// Push ozelliginin calisma durumu.
enum PushDurum {
  /// Henuz baslatilmadi (login bekleniyor / ilk acilis).
  baslatilmadi,

  /// Firebase baslatilamadi (google-services.json'siz build vb.) —
  /// push SESSIZCE devre disi; uygulamanin geri kalani normal calisir.
  devreDisi,

  /// Firebase hazir; token kaydi yapilabilir/yapildi.
  hazir,
}

/// (P183 §2) CIHAZ bildirim izninin durumu (OS katmani; sunucu tercihi
/// `bildirim_mobil`den AYRIDIR). Ayarlar ekraninda gorunur — izin kapaliysa
/// sunucu tercihi acik olsa bile bildirim tepsiye DUSMEZ, kullanici bunu
/// gorebilmeli. FCM `AuthorizationStatus`in sade karsiligidir.
enum PushIzinDurumu {
  /// Henuz sorulmadi (iOS notDetermined). Istem gosterilebilir.
  belirsiz,

  /// Verildi (authorized).
  verildi,

  /// Reddedildi (denied). iOS'ta yeniden istem CIKMAZ — cihaz ayarlarindan
  /// acilir; UI kullaniciyi buna yonlendirir.
  reddedildi,

  /// Kismi / sessiz (iOS provisional): bildirim sessizce gelir.
  kismi,

  /// Durum okunamadi (Firebase devre disi / platform hatasi).
  bilinmiyor,
}

/// On planda yakalanan tek bir push mesaji (FCM notification blogu + data).
class PushMessageEvent {
  const PushMessageEvent({this.title, this.body, this.data = const {}});

  final String? title;
  final String? body;

  /// FCM data payload (string→string; orn. {"tip": "duyuru"}).
  final Map<String, String> data;

  /// SnackBar/banner icin tek satirlik metin — SUNUCU yukundan kurulur.
  ///
  /// KIMLIK / METIN AYRIMI (README §15): push yuku bos gelirse gosterilecek
  /// varsayilan metni domain URETMEZ (tur 12'ye kadar TR sabit 'Yeni bildirim'
  /// duruyordu); bos doner ve cizim katmani `l10n.bildirimYeniPush` yazar.
  String get displayText =>
      [title, body].whereType<String>().where((s) => s.isNotEmpty).join(' — ');
}

/// Push kayit akisinin anlik durumu (UI + teshis).
class PushState {
  const PushState({
    this.durum = PushDurum.baslatilmadi,
    this.izinDurumu = PushIzinDurumu.belirsiz,
    this.kayitliToken,
    this.kayitliDil,
    this.sonBildirim,
    this.sonTiklanan,
  });

  final PushDurum durum;

  /// (P183 §2) CIHAZ bildirim izni — Ayarlar ekraninda gosterilir. Reddedilmis
  /// veya belirsizse kullanici uyarilir/istem sunulur (bkz. PushRegistrar).
  final PushIzinDurumu izinDurumu;

  /// Backend'e en son basariyla kaydedilen FCM token (yoksa null).
  final String? kayitliToken;

  /// Cihaz kaydiyla birlikte sunucuya yazilan UI dili (tur 16). Kullanici
  /// dili degistirince bu deger eskir ve cihaz YENIDEN kaydedilir — yoksa
  /// push eski dilde gelmeye devam ederdi (sunucu istek basligini goremez).
  final String? kayitliDil;

  /// On planda yakalanan son mesaj — UI (main) dinleyip SnackBar gosterir.
  final PushMessageEvent? sonBildirim;

  /// Kullanicinin TIKLADIGI son bildirim (sistem tepsisinden — arka plan
  /// `onMessageOpenedApp` veya kapali durum `getInitialMessage`). UI (main)
  /// dinleyip data'daki tip'e gore ilgili ekrana yonlendirir.
  final PushMessageEvent? sonTiklanan;

  PushState copyWith({
    PushDurum? durum,
    PushIzinDurumu? izinDurumu,
    Object? kayitliToken = _sentinel,
    Object? kayitliDil = _sentinel,
    Object? sonBildirim = _sentinel,
    Object? sonTiklanan = _sentinel,
  }) {
    return PushState(
      durum: durum ?? this.durum,
      izinDurumu: izinDurumu ?? this.izinDurumu,
      kayitliToken: kayitliToken == _sentinel
          ? this.kayitliToken
          : kayitliToken as String?,
      kayitliDil:
          kayitliDil == _sentinel ? this.kayitliDil : kayitliDil as String?,
      sonBildirim: sonBildirim == _sentinel
          ? this.sonBildirim
          : sonBildirim as PushMessageEvent?,
      sonTiklanan: sonTiklanan == _sentinel
          ? this.sonTiklanan
          : sonTiklanan as PushMessageEvent?,
    );
  }

  static const Object _sentinel = Object();
}
