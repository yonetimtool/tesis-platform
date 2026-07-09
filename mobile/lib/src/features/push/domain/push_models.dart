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

/// On planda yakalanan tek bir push mesaji (FCM notification blogu + data).
class PushMessageEvent {
  const PushMessageEvent({this.title, this.body, this.data = const {}});

  final String? title;
  final String? body;

  /// FCM data payload (string→string; orn. {"tip": "acil_durum"}).
  final Map<String, String> data;

  /// SnackBar/banner icin tek satirlik metin.
  String get displayText {
    final parts = [title, body].whereType<String>().where((s) => s.isNotEmpty);
    return parts.isEmpty ? 'Yeni bildirim' : parts.join(' — ');
  }
}

/// Push kayit akisinin anlik durumu (UI + teshis).
class PushState {
  const PushState({
    this.durum = PushDurum.baslatilmadi,
    this.kayitliToken,
    this.sonBildirim,
    this.sonTiklanan,
  });

  final PushDurum durum;

  /// Backend'e en son basariyla kaydedilen FCM token (yoksa null).
  final String? kayitliToken;

  /// On planda yakalanan son mesaj — UI (main) dinleyip SnackBar gosterir.
  final PushMessageEvent? sonBildirim;

  /// Kullanicinin TIKLADIGI son bildirim (sistem tepsisinden — arka plan
  /// `onMessageOpenedApp` veya kapali durum `getInitialMessage`). UI (main)
  /// dinleyip data'daki tip'e gore ilgili ekrana yonlendirir.
  final PushMessageEvent? sonTiklanan;

  PushState copyWith({
    PushDurum? durum,
    Object? kayitliToken = _sentinel,
    Object? sonBildirim = _sentinel,
    Object? sonTiklanan = _sentinel,
  }) {
    return PushState(
      durum: durum ?? this.durum,
      kayitliToken: kayitliToken == _sentinel
          ? this.kayitliToken
          : kayitliToken as String?,
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
