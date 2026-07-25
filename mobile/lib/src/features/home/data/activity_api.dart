/// "Son Hareketler" — TEK uc: `GET /activity` (G5).
///
/// Onceden akis rol basina 3-4 ayri uctan (kargo/ziyaretci/odeme/bildirim/
/// gorev) cekilip ISTEMCIDE birlestiriliyordu. Artik birlestirme, siralama ve
/// rol/KVKK suzgeci SUNUCUDA yapilir; burada tek istek + tek esleme kalir.
///
/// Sayfalama BILESIK IMLEC ile yapilir (`meta.next_cursor`): `offset` yoktur —
/// araya yeni olay girse bile sayfa kaymaz, satir tekrarlamaz. Imlec OPAK'tir,
/// istemci icerigini ayristirmaz.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/activity_models.dart';

class ActivityApi {
  ActivityApi(this._dio);

  final Dio _dio;

  /// Akisin bir sayfasi. [cursor] verilmezse EN YENI sayfa doner; sonraki
  /// sayfa icin onceki yanitin `nextCursor`'i gecilir (null ise akis bitti).
  Future<ActivityPage> sayfa({int limit = 20, String? cursor}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/activity',
        queryParameters: {'limit': limit, 'cursor': ?cursor},
      );
      return ActivityPage.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final activityApiProvider = Provider<ActivityApi>((ref) {
  return ActivityApi(ref.watch(dioProvider));
});

/// Ana ekran "Son Hareketler" karti — akisin EN YENI sayfasi.
///
/// TEK saglayici, UC ROL: sunucu rolu token'dan bilir ve olaylari kendisi
/// suzer. Kart 5 satir cizer, bu yuzden 5 kayit istenir (sayfa verisi bosa
/// tasinmaz). Hata → bolum "Yüklenemedi" + yeniden dene gosterir.
final sonHareketlerProvider =
    FutureProvider.autoDispose<List<ActivityItem>>((ref) async {
  final sayfa = await ref.watch(activityApiProvider).sayfa(limit: 5);
  return sayfa.items;
});
