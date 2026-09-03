/// (P206 §4) MOBIL FINANS — tahsilat, gider, borclular, sayac okuma.
///
/// ===========================================================================
/// NEDEN MOBILDE GEREKLI (OLCUM)
/// ===========================================================================
/// P204 paritesinde bu bes islev "web'de var, mobilde YOK" diye
/// isaretlenmisti; P206 §4'te tek tek olculdu ve dogrulandi: mobil
/// uygulamada `/finans/tahsilat`, `/finans/hareketler`,
/// `/finans/yaslandirma` ve `/borclandirma/sayac` uclarina giden HICBIR
/// cagri yoktu. Kapida elden aidat alan yonetici bilgisayara donmek
/// zorundaydi — ve pratikte kayit AKSAMA girmis oluyordu.
///
/// ===========================================================================
/// YETKI SUNUCUDA
/// ===========================================================================
/// Bu istemci hicbir rol kontrolu yapmaz. Kural sunucuda (P206 §1:
/// admin + yonetici) ve mobil ekran yalniz DUGME GOSTERMEME kararini
/// verir — reddedilecek bir dugme cizmemek icin.
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../tasks/domain/task_models.dart' show PresignTicket;
import '../domain/finans_models.dart';

class FinansApi {
  FinansApi(this._dio, {Dio? uploadDio}) : _uploadDio = uploadDio ?? Dio();

  final Dio _dio;

  /// Presigned PUT icin AUTH BASLIGI OLMAYAN temiz istemci: imzali URL'e
  /// `Authorization` gondermek bazi depolarda imzayi gecersiz kilar.
  final Dio _uploadDio;

  // ------------------------------ okuma ---------------------------------- #

  Future<List<Kasa>> kasalar() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/kasalar',
        queryParameters: {'limit': 200, 'aktif': true},
      );
      return ((res.data?['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Kasa.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<GiderTuru>> giderTurleri() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/gelir-gider-tanimlari',
        queryParameters: {'limit': 200},
      );
      return ((res.data?['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => GiderTuru.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Yaslandirma — borclular ekraninin ve tahsilat kisi seciciinin TEK
  /// kaynagi (P192). `ozet` true ise kova daireleri BOS doner.
  Future<Yaslandirma> yaslandirma({bool ozet = false, String? kova}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/finans/yaslandirma',
        queryParameters: {'ozet': ozet, 'kova': ?kova},
      );
      return Yaslandirma.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<TahsilatGostergesi> tahsilatGostergesi() async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>('/finans/tahsilat-gostergesi');
      return TahsilatGostergesi.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// (P211 §4) Bir dairenin sakinleri — TAHSILATTA "odeyen kim?" sorusu.
  ///
  /// `by-no` ucu KULLANILIYOR (yeni uc yazilmadi): yaslandirma satiri
  /// daire NUMARASINI zaten tasiyor ve bu uc tam da "hedef sakin secici"
  /// icin var (yonetici okuyabiliyor).
  ///
  /// HATA YUTULUR VE BOS LISTE DONER: bu cagri ekranin ANA isi degil,
  /// bir KOLAYLIK. Basarisiz olursa tahsilat yine borclunun adina
  /// kaydedilebilmeli — kolaylik ugruna asil isi kaybetmeyiz.
  Future<List<({String userId, String ad})>> daireSakinleri(
    String unitNo,
  ) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/units/by-no/$unitNo/residents',
      );
      return (res.data ?? const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .where((m) => m['user_id'] != null && (m['ad'] ?? m['user_ad']) != null)
          .map((m) => (
                userId: m['user_id'] as String,
                ad: (m['ad'] ?? m['user_ad']) as String,
              ))
          .toList();
    } on DioException {
      return const [];
    }
  }

  // ------------------------------ yazma ----------------------------------- #

  /// (§4.1) TEKIL TAHSILAT.
  ///
  /// `Idempotency-Key` ZORUNLU TASINIR: sahada baglanti kopar, kullanici
  /// "kaydedilmedi" sanip yeniden basar ve kasada IKI hareket olusurdu.
  /// Anahtari CAGIRAN uretir (form ornegi basina) — burada uretmek, her
  /// yeniden denemede YENI anahtar demek olurdu ki korumanin kendisini
  /// ortadan kaldirirdi.
  Future<void> tahsilat({
    required String kasaId,
    required int tutarKurus,
    required String idempotencyKey,
    String? userId,
    String? unitId,
    String? aciklama,
    String yontem = 'elden',
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/finans/tahsilat',
        data: {
          'kasa_id': kasaId,
          'tutar_kurus': tutarKurus,
          'user_id': ?userId,
          'unit_id': ?unitId,
          'aciklama': ?aciklama,
          'yontem': yontem,
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// (§4.3) GIDER FISI — presign + dogrudan PUT + eke baglama.
  ///
  /// NAKIT GIDER, site muhasebesinde EN COK TARTISILAN kalemdir ve
  /// "fis nerede" sorusu her denetimde sorulur. Fotograf sahada, telefonda
  /// duruyor; kaydin YANINA koymak icin dogru an tam da o an.
  Future<PresignTicket> fisPresign({required String contentType}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/uploads/presign',
        data: {'content_type': contentType, 'dosya_adi': 'gider-fisi.jpg'},
      );
      return PresignTicket.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> fisYukle({
    required PresignTicket bilet,
    required Uint8List baytlar,
    required String contentType,
  }) async {
    try {
      await _uploadDio.put<void>(
        bilet.uploadUrl,
        data: Stream.value(baytlar),
        options: Options(
          headers: {
            Headers.contentTypeHeader: contentType,
            Headers.contentLengthHeader: baytlar.length,
          },
        ),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Yuklenen fisi HAREKETE bagla (`varlik_tipi=finansal_hareket`).
  Future<void> fisEkle({
    required String hareketId,
    required String dosyaKey,
    String? dosyaAdi,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/ekler',
        data: {
          'varlik_tipi': 'finansal_hareket',
          'varlik_id': hareketId,
          'tur': 'dosya',
          'dosya_key': dosyaKey,
          'dosya_adi': dosyaAdi ?? 'gider-fisi.jpg',
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// (§4.3) GIDER KAYDI. Donus: olusan hareketin kimligi (fis eklemek
  /// icin gerekir).
  ///
  /// `durum` VARSAYILAN `onay_bekliyor` DEGIL, cagiran secer: P192'de
  /// onay bekleyen gider bakiyeyi DUSURMEZ ve bu ayrimi ekranda ACIKCA
  /// gostermek gerekiyor (sessiz bir varsayilan, yoneticinin "gideri
  /// yazdim" sanip bakiyeyi yanlis okumasina yol acardi).
  Future<String?> gider({
    required String kasaId,
    required int tutarKurus,
    required String durum,
    required String idempotencyKey,
    String? giderTuruId,
    String? aciklama,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/finans/hareketler',
        data: {
          'satirlar': [
            {
              'tip': 'gider',
              'kasa_id': kasaId,
              'tutar_kurus': tutarKurus,
              'durum': durum,
              'gelir_gider_tanim_id': ?giderTuruId,
              'aciklama': ?aciklama,
            }
          ],
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      final ilk = ((res.data?['items'] as List?) ?? const []).firstOrNull;
      return ilk is Map ? ilk['id'] as String? : null;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// (§4.4) Secili dairelere BORC HATIRLATMASI. Donus: gonderilen adet.
  Future<int> hatirlat(List<String> unitIds) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/finans/borclulara/hatirlat',
        data: {'unit_ids': unitIds},
      );
      return (res.data?['gonderilen'] as int?) ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final finansApiProvider =
    Provider<FinansApi>((ref) => FinansApi(ref.watch(dioProvider)));
