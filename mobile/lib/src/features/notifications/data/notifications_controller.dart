import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../domain/notification_models.dart';

/// GET /notifications + PATCH /notifications/{id} istemcisi.
/// RBAC: admin + yonetici + security (sakin/tesis gorevlisi ERISEMEZ —
/// inbox o rollerin ekranlarina baglanmaz).
class NotificationsApi {
  NotificationsApi(this._dio);
  final Dio _dio;

  Future<NotificationPage> fetch({
    bool? okundu,
    int limit = 50,
    int offset = 0,
    String? q,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/notifications',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        'okundu': ?okundu,
        // (P220 §3) ARAMA SUNUCUDA. Istemcide filtrelemek yalniz CEKILEN
        // sayfayi suzerdi: kullanici listede olmayan bir kaydi bulamaz ve
        // "yok" sanirdi. Ayrica bildirim metni kayitta DURMUYOR (okuma
        // aninda, istegin dilinde uretiliyor) — uc, kullanicinin GORDUGU
        // metinde ariyor.
        'q': ?q,
      },
    );
    return NotificationPage.fromJson(res.data ?? const {});
  }

  Future<void> markRead(String id) async {
    await _dio.patch<Map<String, dynamic>>(
      '/notifications/$id',
      data: {'okundu': true},
    );
  }

  // ------------------------------------------------------------------ //
  // (P220 §2) TOPLU ISLEMLER — web'de VARDI, mobilde YOKTU.
  // ------------------------------------------------------------------ //
  // Uclar zaten mevcuttu (`toplu-okundu`, `tumunu-okundu`, `toplu-sil`);
  // eksik olan yalnizca mobil yuzeydi. Yeni uc yazilmadi.

  /// Secilenleri okundu isaretler. Doner: etkilenen satir sayisi.
  Future<int> topluOkundu(List<String> idler) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/notifications/toplu-okundu',
      data: {'ids': idler, 'okundu': true},
    );
    return (res.data?['etkilenen'] as num?)?.toInt() ?? 0;
  }

  /// Kapsamdaki TUM okunmamislari okundu isaretler.
  Future<int> tumunuOkundu() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/notifications/tumunu-okundu',
      data: const <String, dynamic>{},
    );
    return (res.data?['etkilenen'] as num?)?.toInt() ?? 0;
  }

  /// Secilenleri siler (sunucuda YUMUSAK silme + denetim kaydi).
  Future<int> topluSil(List<String> idler) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/notifications/toplu-sil',
      data: {'ids': idler},
    );
    return (res.data?['etkilenen'] as num?)?.toInt() ?? 0;
  }
}

final notificationsApiProvider = Provider<NotificationsApi>((ref) {
  return NotificationsApi(ref.watch(dioProvider));
});

/// Okunmamis bildirim sayisi — HomeShell zil/sekme rozeti. okundu=false +
/// limit=1 sorgusunun meta.total'i; hata → izleyen ekran 0 varsayar (ana
/// ekran rozete rehin degil).
final unreadNotificationCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final page = await ref
      .watch(notificationsApiProvider)
      .fetch(okundu: false, limit: 1);
  return page.total;
});

/// (P220 §3) LISTE SUZGECI — sekme + arama.
///
/// Iki sekme var ve VARSAYILAN OKUNMAMIS. "Tumu" gorunumu YOK: bildirim
/// listesinin yanitlamasi gereken soru "NEYI KACIRDIM"; okunmuslarla
/// karisik bir liste o soruyu yanitlamiyor. Arama geldigi icin "Tumu"
/// gereksiz de: bir bildirimi metniyle ariyorsan hangi sekmede oldugunu
/// bilmen gerekmez, iki sekmede de arama var.
class BildirimSuzgeci {
  const BildirimSuzgeci({this.okundu = false, this.arama = ''});

  /// `false` = OKUNMAMIS sekmesi (varsayilan), `true` = OKUNMUS.
  final bool okundu;
  final String arama;

  /// Sunucu en az iki karakter istiyor; tek harf taranan satirlarin
  /// neredeyse tamamiyla eslesir ve arama bir ise yaramaz.
  bool get aramaGecerli => arama.trim().length >= 2;

  BildirimSuzgeci kopya({bool? okundu, String? arama}) => BildirimSuzgeci(
        okundu: okundu ?? this.okundu,
        arama: arama ?? this.arama,
      );

  @override
  bool operator ==(Object other) =>
      other is BildirimSuzgeci &&
      other.okundu == okundu &&
      other.arama == arama;

  @override
  int get hashCode => Object.hash(okundu, arama);
}

/// Suzgec durumu — `Notifier` (bu Riverpod surumunde `StateProvider` yok).
class BildirimSuzgeciController extends Notifier<BildirimSuzgeci> {
  @override
  BildirimSuzgeci build() => const BildirimSuzgeci();

  /// Sekme degistir. SECIM TEMIZLIGI arayuzun isi: burada tutmak, veri
  /// katmanini ekran durumuna baglardi.
  void sekme(bool okundu) => state = state.kopya(okundu: okundu);

  void ara(String metin) => state = state.kopya(arama: metin);
}

final bildirimSuzgeciProvider =
    NotifierProvider<BildirimSuzgeciController, BildirimSuzgeci>(
  BildirimSuzgeciController.new,
);

/// Bildirim listesi + okundu isaretleme + TOPLU ISLEMLER.
///
/// Isaretleme IYIMSER: satir hemen okunmus gorunur, rozet sayaci
/// tazelenir.
class NotificationsController extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    final s = ref.watch(bildirimSuzgeciProvider);
    final page = await ref.watch(notificationsApiProvider).fetch(
          okundu: s.okundu,
          q: s.aramaGecerli ? s.arama.trim() : null,
        );
    return page.items;
  }

  Future<void> markRead(String id) async {
    await ref.read(notificationsApiProvider).markRead(id);
    // OKUNDU ISARETLENEN SATIR SEKME DEGISTIRIR: okunmamis sekmesinde
    // artik yeri yok. Yerinde "okunmus" olarak birakmak, kullanicinin
    // temizledigi listede kaydin durmasi olurdu.
    _tazele();
  }

  // ------------------------------------------------------------------ //
  // (P220 §2) TOPLU ISLEMLER
  // ------------------------------------------------------------------ //
  // ROZET HER UCUNDE DE ANINDA TAZELENIR. P190'da web'de olculen kusur
  // buydu: toplu okundu deyince liste guncelleniyor ama ust bardaki sayi
  // duşmuyordu, cunku rozet AYRI bir sorgudan besleniyor. Ayni tuzak
  // mobilde de var — `unreadNotificationCountProvider` ayri bir
  // saglayici.

  /// Rozeti ve listeyi tazeler — SAGLAYICI HALA CANLIYSA.
  ///
  /// `ref.mounted` KONTROLU GEREKLI: bu saglayici `autoDispose` ve
  /// kullanici toplu islem sirasinda ekrandan CIKARSA (ag cagrisi
  /// surerken) dinleyici kalmaz, saglayici atilir ve `ref.invalidate`
  /// FIRLATIR. O firlatma, sunucuda BASARIYLA tamamlanmis bir islemi
  /// arayuzde "basarisiz" gostermek olurdu — kullanici islemi tekrar
  /// dener ve ikinci kez siler.
  ///
  /// Ekran zaten kapandigi icin tazelemeye de gerek yok: bir sonraki
  /// acilista liste yeniden cekiliyor.
  void _tazele() {
    if (!ref.mounted) return;
    ref.invalidate(unreadNotificationCountProvider);
    ref.invalidateSelf();
  }

  /// Doner: etkilenen satir sayisi (arayuz bunu kullaniciya soyler).
  Future<int> topluOkundu(List<String> idler) async {
    final n = await ref.read(notificationsApiProvider).topluOkundu(idler);
    _tazele();
    return n;
  }

  Future<int> tumunuOkundu() async {
    final n = await ref.read(notificationsApiProvider).tumunuOkundu();
    _tazele();
    return n;
  }

  Future<int> topluSil(List<String> idler) async {
    final n = await ref.read(notificationsApiProvider).topluSil(idler);
    // SILME DE ROZETI ETKILER: silinen satirlarin okunmamislari sayacta
    // duruyordu.
    _tazele();
    return n;
  }
}

final notificationsProvider = AsyncNotifierProvider.autoDispose<
    NotificationsController, List<AppNotification>>(
  NotificationsController.new,
);
