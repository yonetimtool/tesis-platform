/// Ana ekranin TOPLAM/SAYAC sorgulari + birlesik "Son Hareketler" akislari.
///
/// Buradaki her cagri `contracts/openapi.yaml`'da VAR OLAN bir uca gider; uc
/// UYDURULMAZ. Sayaclar `?limit=1` ile cekilir ve YALNIZ `meta.total` okunur
/// (sayfa verisi tasinmaz — telefon icin en ucuz sorgu).
///
///   * `GET /units?aktif=true&limit=1`            → Toplam Daire
///   * `GET /tasks?aktif=true&limit=1`            → aktif gorev sayisi
///   * `GET /unit-complaints?durum=acik&limit=1`  → acik daire sikayeti (yonetim)
///   * `GET /unit-complaints/mine?durum=acik&limit=1` → sakinin acik sikayeti
///   * `GET /dues/payments?limit=5`               → son odemeler (yonetim)
///   * `GET /task-completions?limit=5`            → son gorev tamamlamalari
///
/// Rol siniri SUNUCUDA: sakin `/units`'e 403 alir, saha `/dues/payments`'e
/// 403 alir. Bu yuzden her sayac YALNIZ yetkili rolun ekraninda izlenir ve
/// akis birlestirici tek tek kaynak hatalarini yutar (bir uc kapaliysa akis
/// kalan kaynaklarla cizilir).
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../complaints/data/complaint_api.dart';
import '../../complaints/domain/complaint_models.dart';
import '../../dues/data/dues_api.dart';
import '../../dues/domain/dues_models.dart';
import '../../kargo/data/kargo_api.dart';
import '../../kargo/domain/kargo_models.dart';
import '../../notifications/data/notifications_controller.dart';
import '../../notifications/domain/notification_models.dart';
import '../../reports/domain/report_models.dart' show SonTamamlama;
import '../../visitors/data/visitor_api.dart';
import '../../visitors/domain/visitor_models.dart';
import '../domain/son_hareketler.dart';

/// Ana ekran toplamlarinin ince HTTP istemcisi.
class HomeApi {
  HomeApi(this._dio);

  final Dio _dio;

  /// Sayfali bir ucun `meta.total` degeri (sayfa ogeleri okunmaz).
  Future<int> _total(String path, Map<String, dynamic> query) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: {...query, 'limit': 1, 'offset': 0},
      );
      final meta = res.data?['meta'];
      return meta is Map ? (meta['total'] as num?)?.toInt() ?? 0 : 0;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /units?aktif=true` → tesisteki AKTIF daire sayisi.
  Future<int> toplamDaireSayisi() => _total('/units', {'aktif': true});

  /// `GET /tasks?aktif=true` → acik (aktif) gorev sayisi.
  Future<int> aktifGorevSayisi() => _total('/tasks', {'aktif': true});

  /// `GET /unit-complaints?durum=acik` → acik daire sikayeti (YALNIZ yonetim).
  Future<int> acikDaireSikayetSayisi() =>
      _total('/unit-complaints', {'durum': 'acik'});

  /// `GET /unit-complaints/mine?durum=acik` → sakinin KENDI acik sikayetleri.
  Future<int> kendiAcikDaireSikayetSayisi() =>
      _total('/unit-complaints/mine', {'durum': 'acik'});

  /// `GET /dues/payments` → son odemeler (yonetim; akis satiri).
  Future<List<DuesPayment>> sonOdemeler({int limit = 5}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/dues/payments',
        queryParameters: {'limit': limit, 'offset': 0},
      );
      final items = res.data?['items'];
      if (items is! List) return const [];
      return [
        for (final item in items)
          if (item is Map)
            DuesPayment.fromJson(Map<String, dynamic>.from(item)),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /task-completions` → son gorev tamamlamalari (akis satiri).
  Future<List<SonTamamlama>> sonGorevTamamlamalari({int limit = 5}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/task-completions',
        queryParameters: {'limit': limit, 'offset': 0},
      );
      final items = res.data?['items'];
      if (items is! List) return const [];
      return [
        for (final item in items)
          if (item is Map)
            SonTamamlama.fromJson(Map<String, dynamic>.from(item)),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final homeApiProvider = Provider<HomeApi>((ref) {
  return HomeApi(ref.watch(dioProvider));
});

// --------------------------------------------------------------- sayaclar

/// "Toplam Daire" (yonetim). RBAC: admin + yonetici + security; sakin 403 —
/// sakin ekraninda IZLENMEZ.
final toplamDaireSayisiProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(homeApiProvider).toplamDaireSayisi();
});

/// "Görevler" kart sayaci (yonetim) — aktif gorev adedi.
final aktifGorevSayisiProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(homeApiProvider).aktifGorevSayisi();
});

/// "Şikayetler" kart sayaci (yonetim) — acik DAIRE sikayeti adedi.
final acikDaireSikayetSayisiProvider =
    FutureProvider.autoDispose<int>((ref) {
  return ref.watch(homeApiProvider).acikDaireSikayetSayisi();
});

/// "Şikayetlerim" kart sayaci (sakin) — kendi actigi acik sikayet adedi.
final kendiDaireSikayetSayisiProvider =
    FutureProvider.autoDispose<int>((ref) {
  return ref.watch(homeApiProvider).kendiAcikDaireSikayetSayisi();
});

/// Son talepler (akis satiri). Sunucu rol suzer: sakin/saha KENDI actiklarini,
/// yonetim tenant'in tumunu gorur.
final sonTaleplerProvider =
    FutureProvider.autoDispose<List<Complaint>>((ref) async {
  final page = await ref.watch(complaintApiProvider).list(limit: 5);
  return page.items;
});

/// Son aidat odemeleri (YALNIZ yonetim; saha/sakin 403).
final sonOdemelerProvider =
    FutureProvider.autoDispose<List<DuesPayment>>((ref) {
  return ref.watch(homeApiProvider).sonOdemeler();
});

/// Son gorev tamamlamalari (yonetim + saha; sakin 403).
final sonGorevTamamlamalariProvider =
    FutureProvider.autoDispose<List<SonTamamlama>>((ref) {
  return ref.watch(homeApiProvider).sonGorevTamamlamalari();
});

// ------------------------------------------------------- birlesik akislar

/// Birlesik akisin TOPLU durumu — "en iyi caba":
///   * en az bir kaynak veri verdiyse → akis o kaynaklarla cizilir (kapali
///     uc bolumu karartmaz),
///   * hicbiri veri vermediyse ve en az biri hata verdiyse → HATA
///     ("Yüklenemedi" + yeniden dene),
///   * aksi halde → YUKLENIYOR.
///
/// Saglayicilar SENKRON okunur (`.future` beklenmez): Riverpod hatali bir
/// saglayiciyi otomatik yeniden dener ve bu sirada `.future` askida kalir —
/// o durumda bolum sonsuza kadar iskelet gosterirdi.
AsyncValue<List<Hareket>>? _birlesikDurum(List<AsyncValue<Object>> kaynaklar) {
  if (kaynaklar.any((k) => k.hasValue)) return null; // veriyle devam
  final hatali = kaynaklar.where((k) => k.hasError).firstOrNull;
  if (hatali != null) {
    return AsyncError(hatali.error!, hatali.stackTrace ?? StackTrace.empty);
  }
  return const AsyncLoading();
}

List<T> _liste<T>(AsyncValue<Object> kaynak) =>
    (kaynak.value as List?)?.cast<T>() ?? const [];

/// Sakin "Son Hareketler": kendi kargosu + kendine hedeflenen ziyaretciler +
/// kendi aidat odemeleri + kendi talepleri. Hepsi sunucuda sakin-suzgeclidir.
final residentHareketleriProvider =
    Provider.autoDispose<AsyncValue<List<Hareket>>>((ref) {
  final kargo = ref.watch(kargoListProvider);
  final ziyaretci = ref.watch(visitorsListProvider);
  final dues = ref.watch(myDuesProvider);
  final talep = ref.watch(sonTaleplerProvider);

  final durum = _birlesikDurum([kargo, ziyaretci, dues, talep]);
  if (durum != null) return durum;

  return AsyncData(residentHareketleri(
    kargolar: _liste<Kargo>(kargo),
    ziyaretciler: _liste<Visitor>(ziyaretci),
    duesUnits: _liste<MyDuesUnit>(dues),
    talepler: _liste<Complaint>(talep),
  ));
});

/// Yonetim "Son Hareketler": bildirim + talep + aidat odemesi + gorev
/// tamamlama tek akista.
final yonetimHareketleriProvider =
    Provider.autoDispose<AsyncValue<List<Hareket>>>((ref) {
  final bildirim = ref.watch(notificationsProvider);
  final talep = ref.watch(sonTaleplerProvider);
  final odeme = ref.watch(sonOdemelerProvider);
  final tamamlama = ref.watch(sonGorevTamamlamalariProvider);

  final durum = _birlesikDurum([bildirim, talep, odeme, tamamlama]);
  if (durum != null) return durum;

  return AsyncData(yonetimHareketleri(
    bildirimler: _liste<AppNotification>(bildirim),
    talepler: _liste<Complaint>(talep),
    odemeler: _liste<DuesPayment>(odeme),
    tamamlamalar: _liste<SonTamamlama>(tamamlama),
  ));
});

/// Saha "Son Hareketler". [guvenlik] false (tesis_gorevlisi) iken ziyaretci/
/// kargo/bildirim uclari RBAC disidir — hic izlenmez (403 uretecek istek
/// atilmaz), akis yalniz gorev tamamlamalarindan olusur.
final sahaHareketleriProvider = Provider.autoDispose
    .family<AsyncValue<List<Hareket>>, bool>((ref, guvenlik) {
  final tamamlama = ref.watch(sonGorevTamamlamalariProvider);
  if (!guvenlik) {
    final durum = _birlesikDurum([tamamlama]);
    return durum ??
        AsyncData(
            sahaHareketleri(tamamlamalar: _liste<SonTamamlama>(tamamlama)));
  }

  final ziyaretci = ref.watch(visitorsListProvider);
  final kargo = ref.watch(kargoListProvider);
  final bildirim = ref.watch(notificationsProvider);

  final durum = _birlesikDurum([tamamlama, ziyaretci, kargo, bildirim]);
  if (durum != null) return durum;

  return AsyncData(sahaHareketleri(
    ziyaretciler: _liste<Visitor>(ziyaretci),
    kargolar: _liste<Kargo>(kargo),
    tamamlamalar: _liste<SonTamamlama>(tamamlama),
    bildirimler: _liste<AppNotification>(bildirim),
  ));
});
