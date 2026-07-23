import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
// PresignTicket YENIDEN kullanilir (kopya yok) — presign yaniti gorev/duyuru
// akisindakiyle ayni sozlesme semasidir (PresignResponse).
import '../../tasks/domain/task_models.dart' show PresignTicket;
// TaskCategory/TaskCategoryApi YENIDEN kullanilir (kopya yok) — talep
// kategorisi = yonetici-tanimli gorev kategorisi (ayni /task-categories ucu).
import '../../tasks/data/task_category_api.dart'
    show TaskCategoryApi, taskCategoryApiProvider;
import '../../tasks/domain/task_category_models.dart' show TaskCategory;
import '../domain/complaint_models.dart';

/// `GET /complaints` yaniti: sayfa ogeleri + toplam sayim (PageMeta).
class ComplaintPage {
  const ComplaintPage({
    required this.items,
    this.total = 0,
    this.limit = 0,
    this.offset = 0,
  });

  final List<Complaint> items;
  final int total;
  final int limit;
  final int offset;
}

/// Talep/Arıza (İş Emri) modulunun HTTP istemcisi:
///
///   * `GET  /complaints`                → liste (acan roller KENDI; yonetim
///                                          TUMU; DESC; durum ile filtrelenebilir)
///   * `POST /complaints`                → talep ac (security/tesis_gorevlisi/resident)
///   * `GET  /complaints/{id}`           → detay (acan roller KENDI; yonetim TUMU)
///   * `POST /complaints/{id}/convert`   → is emrine donustur (admin + yonetici)
///   * `POST /complaints/{id}/resolve`   → dogrudan coz (admin + yonetici)
///   * `POST /complaints/{id}/decline`   → reddet (admin + yonetici)
///   * `POST /uploads/presign`           → opsiyonel talep gorseli(leri) icin PUT URL
///   * presigned URL'e HTTP PUT          → dosya dogrudan MinIO'ya
class ComplaintApi {
  ComplaintApi(this._dio, this._taskCategoryApi, {Dio? uploadDio})
      : _uploadDio = uploadDio ?? Dio();

  final Dio _dio;
  final TaskCategoryApi _taskCategoryApi;

  /// Presigned PUT icin TEMIZ istemci: Authorization header'i ve API
  /// base-url'u TASINMAZ (presigned imza baska header'la bozulur; URL mutlak
  /// gelir). Gorev/duyuru foto akisiyla ayni desen.
  final Dio _uploadDio;

  /// `GET /complaints` — TUM sayfalari toplayip donerir (sunucu sirasi:
  /// created_at DESC). Acan roller icin sunucu zaten YALNIZ kendi
  /// actiklarini doner.
  Future<List<Complaint>> fetchAll({TalepDurum? durum}) async {
    final out = <Complaint>[];
    var offset = 0;
    const limit = 200;
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/complaints',
          queryParameters: {
            'limit': limit,
            'offset': offset,
            if (durum != null && durum != TalepDurum.unknown)
              'durum': durum.wire,
          },
        );
        final items = res.data?['items'];
        if (items is! List || items.isEmpty) break;
        for (final item in items) {
          if (item is Map) {
            out.add(Complaint.fromJson(Map<String, dynamic>.from(item)));
          }
        }
        if (items.length < limit) break;
        offset += limit;
      }
      return out;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /complaints` — TEK sayfa (meta.total dahil); liste ekraninin
  /// sayfalama/filtre ihtiyaci icin [fetchAll]'a alternatif.
  Future<ComplaintPage> list({
    TalepDurum? durum,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/complaints',
        queryParameters: {
          'limit': limit,
          'offset': offset,
          if (durum != null && durum != TalepDurum.unknown)
            'durum': durum.wire,
        },
      );
      final data = res.data ?? const <String, dynamic>{};
      final rawItems = data['items'];
      final meta = data['meta'];
      return ComplaintPage(
        items: [
          for (final item in rawItems is List ? rawItems : const [])
            if (item is Map)
              Complaint.fromJson(Map<String, dynamic>.from(item)),
        ],
        total: meta is Map ? (meta['total'] as num?)?.toInt() ?? 0 : 0,
        limit: meta is Map ? (meta['limit'] as num?)?.toInt() ?? limit : limit,
        offset:
            meta is Map ? (meta['offset'] as num?)?.toInt() ?? offset : offset,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /complaints/{id}` — detay (fotograflar[], gecmis[], bagli is emri
  /// varsa is_emri_id/is_emri_durum ile birlikte).
  Future<Complaint> get(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/complaints/$id');
      return Complaint.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /complaints` — talep ac. [draft.fotoKeys] ONCESINDE her biri icin
  /// [presignUpload] + [uploadPhoto] ile alinmis olmali (en fazla 3).
  Future<Complaint> create(ComplaintDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/complaints',
        data: draft.toJson(),
      );
      return Complaint.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /complaints/{id}/convert` — talebi is emrine donustur (admin +
  /// yonetici). Gecerli gecis YALNIZ acik -> is_emri (aksi 422
  /// invalid_transition); atanan kullanici security/tesis_gorevlisi olmali
  /// (aksi 422 invalid_assignee).
  Future<Complaint> convert(String id, ComplaintConvertDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/complaints/$id/convert',
        data: draft.toJson(),
      );
      return Complaint.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /complaints/{id}/resolve` — talebi dogrudan coz (admin +
  /// yonetici). Gecerli gecis acik -> cozuldu VEYA is_emri -> cozuldu.
  Future<Complaint> resolve(String id, ComplaintResolveDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/complaints/$id/resolve',
        data: draft.toJson(),
      );
      return Complaint.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /complaints/{id}/decline` — talebi reddet (admin + yonetici).
  /// Gecerli gecis YALNIZ acik -> reddedildi; [draft.sebep] ZORUNLU.
  Future<Complaint> decline(String id, ComplaintDeclineDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/complaints/$id/decline',
        data: draft.toJson(),
      );
      return Complaint.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /uploads/presign` — talep gorseli icin obje anahtari + kisa
  /// omurlu PUT URL (gorev/duyuru foto akisiyla ayni uc; acan roller
  /// yetkili). En fazla 3 gorsel icin bagimsiz cagrilir.
  Future<PresignTicket> presignUpload({
    required String contentType,
    String? dosyaAdi,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/uploads/presign',
        data: {
          'content_type': contentType,
          'dosya_adi': ?dosyaAdi,
        },
      );
      return PresignTicket.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Presigned URL'e dosyayi PUT eder (dogru Content-Type ile — imza buna
  /// gore atilmis olabilir). Basari sonrasi [PresignTicket.fotoKey]
  /// talep acmada `foto_keys` dizisine eklenir.
  Future<void> uploadPhoto({
    required PresignTicket ticket,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      await _uploadDio.put<void>(
        ticket.uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            Headers.contentTypeHeader: contentType,
            Headers.contentLengthHeader: bytes.length,
          },
        ),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /task-categories` — talep acma formundaki kategori secici icin.
  /// Talep kategorisi = yonetici-tanimli gorev kategorisi; ayri bir uc/model
  /// YOKTUR, mevcut [TaskCategoryApi] dogrudan yeniden kullanilir.
  Future<List<TaskCategory>> listTaskCategories() =>
      _taskCategoryApi.fetchAll();
}

final complaintApiProvider = Provider<ComplaintApi>((ref) {
  return ComplaintApi(
    ref.watch(dioProvider),
    ref.watch(taskCategoryApiProvider),
  );
});

/// Acik sikayet sayisi — yonetici ana ekran "Şikayet / Öneri" kart sayaci
/// ("N Açık"). durum=acik + limit=1 sorgusunun meta.total'i; hata → sayac
/// gizli (ana ekran rehin degil).
final acikSikayetSayisiProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final page = await ref
      .watch(complaintApiProvider)
      .list(durum: TalepDurum.acik, limit: 1);
  return page.total;
});
