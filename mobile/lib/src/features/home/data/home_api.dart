/// Ana ekranin TOPLAM/SAYAC sorgulari.
///
/// Buradaki her cagri `contracts/openapi.yaml`'da VAR OLAN bir uca gider; uc
/// UYDURULMAZ. Sayaclar `?limit=1` ile cekilir ve YALNIZ `meta.total` okunur
/// (sayfa verisi tasinmaz — telefon icin en ucuz sorgu).
///
///   * `GET /units?aktif=true&limit=1`            → Toplam Daire
///   * `GET /tasks?aktif=true&limit=1`            → aktif gorev sayisi
///   * `GET /unit-complaints?durum=acik&limit=1`  → acik daire sikayeti (yonetim)
///   * `GET /unit-complaints/mine?durum=acik&limit=1` → sakinin acik sikayeti
///   * `GET /unit-complaints/mine?kategori=gurultu&durum=acik&limit=1` → gurultu
///   * `GET /visitors?icerde=true&limit=1`        → halen ICERIDE ziyaretci
///   * `GET /vehicle-passes?baslangic=<gun basi>&limit=1` → bugunku arac girisi
///   * `GET /violations?durum=yeni&limit=1`       → yeni ihlal
///   * `GET /parking/occupancy`                   → otopark dolulugu (agregat)
///
/// Birlesik "Son Hareketler" akisi BURADA DEGIL: tek uc olarak
/// `data/activity_api.dart` (`GET /activity`) icindedir.
///
/// Rol siniri SUNUCUDA: sakin `/units`'e 403 alir, saha `/dues/payments`'e
/// 403 alir, `/vehicle-passes` yalniz admin+security'ye aciktir. Bu yuzden her
/// sayac YALNIZ yetkili rolun ekraninda izlenir — izinsiz rolde istek HIC
/// atilmaz (403 uretilmez), kart cizilmez.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/parking_occupancy.dart';

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

  /// `GET /unit-complaints/mine?kategori=<k>&durum=acik` (G6) → sakinin
  /// KENDI acik sikayetleri, KATEGORI suzgeci SUNUCUDA (istemci suzmez).
  Future<int> kendiKategoriSikayetSayisi(String kategori) =>
      _total('/unit-complaints/mine', {'kategori': kategori, 'durum': 'acik'});

  /// `GET /visitors?icerde=true` (G3) → cikisi damgalanMAMIS ziyaretci sayisi
  /// ("N İçeride"). RBAC: security (+ resident kendine hedeflenenler).
  Future<int> icerdekiZiyaretciSayisi() =>
      _total('/visitors', {'icerde': true});

  /// `GET /vehicle-passes?baslangic=<gun basi>` (G1) → BUGUN kaydedilen arac
  /// girisi sayisi ("N Giriş"). [gunBasi] cihazin YEREL gun basidir; sunucu
  /// `giris_zamani >= baslangic` uygular. RBAC: admin + security.
  Future<int> bugunkuAracGirisSayisi(DateTime gunBasi) => _total(
        '/vehicle-passes',
        {'baslangic': gunBasi.toUtc().toIso8601String()},
      );

  /// `GET /violations?durum=yeni` (G2) → henuz ele alinmamis ihlal sayisi
  /// ("N Yeni"). RBAC: admin + yonetici + security.
  Future<int> yeniIhlalSayisi() => _total('/violations', {'durum': 'yeni'});

  /// `GET /parking/occupancy` (G4) → `{kapasite, dolu, oran}`. Kapasite
  /// tanimsizsa `kapasite`/`oran` null gelir; kart/kutu bunu KENDI gosterir
  /// (uydurma kapasite/yuzde yok).
  Future<ParkingOccupancy> otoparkDoluluk() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/parking/occupancy');
      return ParkingOccupancy.fromJson(res.data ?? const {});
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

/// "Gürültü Şikayeti" kart sayaci (sakin) — kendi actigi ACIK gurultu
/// sikayetleri; kategori suzgeci SUNUCUDA (G6).
final kendiGurultuSikayetSayisiProvider =
    FutureProvider.autoDispose<int>((ref) {
  return ref.watch(homeApiProvider).kendiKategoriSikayetSayisi('gurultu');
});

/// "Ziyaretçi → N İçeride" (gorevli). RBAC: security; tesis_gorevlisi
/// ekraninda kart CIZILMEZ, saglayici izlenmez.
final icerdekiZiyaretciSayisiProvider =
    FutureProvider.autoDispose<int>((ref) {
  return ref.watch(homeApiProvider).icerdekiZiyaretciSayisi();
});

/// "Araç Plaka → N Giriş" (gorevli) — BUGUNKU giris sayisi. Gun basi
/// saglayici kurulurken cihaz saatinden alinir (ekran gun icinde yenilenir).
final bugunkuAracGirisSayisiProvider =
    FutureProvider.autoDispose<int>((ref) {
  final now = DateTime.now();
  return ref
      .watch(homeApiProvider)
      .bugunkuAracGirisSayisi(DateTime(now.year, now.month, now.day));
});

/// "İhlaller → N Yeni" (gorevli/security + yonetim).
final yeniIhlalSayisiProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(homeApiProvider).yeniIhlalSayisi();
});

/// "Otopark Kullanımı" karti + "Otopark Doluluk" kutusu AYNI yaniti kullanir
/// (tek istek).
final otoparkDolulukProvider =
    FutureProvider.autoDispose<ParkingOccupancy>((ref) {
  return ref.watch(homeApiProvider).otoparkDoluluk();
});
