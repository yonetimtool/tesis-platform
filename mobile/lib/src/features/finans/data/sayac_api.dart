/// (P206 §4.5) MOBIL SAYAC OKUMA — sahada okunan degerler + fotograf.
///
/// ===========================================================================
/// MOBILDE NEDEN GEREKLI
/// ===========================================================================
/// Sayaclar SAHADADIR: bodrumda, daire kapisinda, kazan dairesinde. Web
/// sihirbazi (dort adim) masabasi icin tasarlandi ve okumayi yapan kisi
/// degerleri once KAGIDA yaziyor, sonra bilgisayarda giriyordu — iki kez
/// yazilan her sayi, bir kez yanlis yazilabilir.
///
/// ===========================================================================
/// FOTOGRAF: DEGERLENDIRME SONUCU EVET — AMA DAIREYE BAGLI
/// ===========================================================================
/// Sayac fotografi bir KANITTIR: "benim sayacim 145 gostermiyordu"
/// itirazi her donem cikar ve bugun yanitlanamiyor. Fotograf DAIRENIN
/// ekine yazilir (`varlik_tipi=unit`) cunku itiraz DAIRE uzerinden
/// gelir ve sayac okumasinin kendisi kalici bir kayit degil, bir
/// borclandirma girdisidir. Yeni tablo ACILMADI.
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../tasks/domain/task_models.dart' show PresignTicket;
import '../domain/sayac_models.dart';

class SayacApi {
  SayacApi(this._dio, {Dio? uploadDio}) : _uploadDio = uploadDio ?? Dio();

  final Dio _dio;
  final Dio _uploadDio;

  Future<List<AnaSayac>> anaSayaclar() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/sayaclar/ana',
        queryParameters: {'limit': 200},
      );
      return ((res.data?['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => AnaSayac.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<BolumSayaci>> bolumSayaclari(String anaSayacId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/sayaclar/bolum',
        queryParameters: {'ana_sayac_id': anaSayacId, 'limit': 500},
      );
      return ((res.data?['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => BolumSayaci.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<GiderTuruBasit>> kalemler() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/gelir-gider-tanimlari',
        queryParameters: {'limit': 200},
      );
      return ((res.data?['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => GiderTuruBasit.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Okumalari BORCLANDIRMAYA cevirir — web sihirbazinin son adimiyla
  /// AYNI uc (`POST /borclandirma/sayac`). Ikinci bir uc yazmak, dagitim
  /// kuralinin iki yerde ayrisma riski demekti.
  Future<int> borclandir({
    required String donem,
    required String kalemId,
    required String anaSayacId,
    required double anaTuketim,
    required int birimFiyatKurus,
    required Map<String, double> bolumTuketimleri,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/borclandirma/sayac',
        data: {
          'donem': donem,
          'gelir_gider_tanim_id': kalemId,
          'ana_sayac_id': anaSayacId,
          'ana_tuketim': anaTuketim,
          'birim_fiyat_kurus': birimFiyatKurus,
          'bolum_tuketimleri': bolumTuketimleri,
        },
      );
      return (res.data?['atlanan'] as int?) ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  // -------------------------- OKUMA FOTOGRAFI ---------------------------- #

  Future<PresignTicket> fotoPresign() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/uploads/presign',
        data: {'content_type': 'image/jpeg', 'dosya_adi': 'sayac.jpg'},
      );
      return PresignTicket.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> fotoYukle({
    required PresignTicket bilet,
    required Uint8List baytlar,
  }) async {
    try {
      await _uploadDio.put<void>(
        bilet.uploadUrl,
        data: Stream.value(baytlar),
        options: Options(headers: {
          Headers.contentTypeHeader: 'image/jpeg',
          Headers.contentLengthHeader: baytlar.length,
        }),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Fotografi DAIREYE bagla; metin okunan degeri tasir ki ek, tek
  /// basina bakildiginda da anlamli olsun ("hangi donem, kac").
  Future<void> okumaEkle({
    required String unitId,
    required String dosyaKey,
    required String metin,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/ekler',
        data: {
          'varlik_tipi': 'unit',
          'varlik_id': unitId,
          'tur': 'dosya',
          'dosya_key': dosyaKey,
          'dosya_adi': 'sayac.jpg',
          'metin': metin,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final sayacApiProvider =
    Provider<SayacApi>((ref) => SayacApi(ref.watch(dioProvider)));
