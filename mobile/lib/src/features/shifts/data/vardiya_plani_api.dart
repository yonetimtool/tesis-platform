/// (P203 §4) VARDIYA PLANI — mobil okuma.
///
/// ===========================================================================
/// MOBILDE OKUMA + BASIT DEGISIKLIK
/// ===========================================================================
/// Istek "mobilde EN AZINDAN goruntuleme ve basit degisiklik" diyor.
/// Sunucu okumayi saha rollerine de aciyor: "bir sonraki vardiyada kim
/// var" tam da sahanin sorusudur ve WEB YUZEYI onlara KAPALIDIR (P129:
/// saha rollerinin urunu mobil uygulamadir). Yani plani gorebilmelerinin
/// TEK yolu burasi.
///
/// YAZMA (atama/cikarma) sunucuda admin+yonetici ile sinirli; mobil
/// yonetici de o uclari cagirabilir.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/vardiya_plani_models.dart';

class VardiyaPlaniApi {
  VardiyaPlaniApi(this._dio);

  final Dio _dio;

  Future<VardiyaHafta> hafta(DateTime baslangic, {int gun = 7}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/vardiya-plani',
        queryParameters: {
          'baslangic': _tarih(baslangic),
          'gun': gun,
        },
      );
      return VardiyaHafta.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// (P205 §2) KISI x SAAT cizelgesi.
  ///
  /// MOBIL ARTIK BUNU KULLANIYOR: `GET /vardiya-plani` izgarasi
  /// SABLONA bagli slotlari doner ve SERBEST (sablonsuz) vardiyalar
  /// orada HIC GORUNMEZ — web'den hizli eklenen bir vardiya sahada
  /// gorunmezdi. Izgara ucu duruyor (varsayilan kadro tohumlamasi ona
  /// dayaniyor), ekran ondan koptu.
  Future<VardiyaCizelge> cizelge(DateTime baslangic, {int gun = 7}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/vardiya-plani/cizelge',
        queryParameters: {'baslangic': _tarih(baslangic), 'gun': gun},
      );
      return VardiyaCizelge.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// (P205 §2) Tarih araligindaki HER GUN icin vardiya.
  ///
  /// `cakisanlariAtla` VARSAYILAN FALSE: cakisan gunler kullaniciya
  /// SORULMADAN atlanmaz (istegin acik sarti).
  Future<VardiyaTopluSonuc> topluEkle({
    required String userId,
    required DateTime baslangic,
    required DateTime bitis,
    required String baslangicSaat,
    required String bitisSaat,
    String? not,
    bool cakisanlariAtla = false,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/vardiya-plani/toplu',
        data: {
          'user_id': userId,
          'baslangic_tarih': _tarih(baslangic),
          'bitis_tarih': _tarih(bitis),
          'baslangic_saat': baslangicSaat,
          'bitis_saat': bitisSaat,
          'not_metni': not,
          'cakisanlari_atla': cakisanlariAtla,
        },
      );
      return VardiyaTopluSonuc.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<VardiyaSimdi> simdi() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/vardiya-plani/simdi');
      return VardiyaSimdi.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Atamayi kaldir — SILMEZ, iptal isaretler. `not_metni` SORGUDA:
  /// DELETE govdesi bazi yiginlarda sessizce dusuyor ve sebep alani
  /// kaybolsaydi denetim kaydi "neden" sorusunu yanitlayamazdi.
  Future<void> cikar(String planId, {String? sebep}) async {
    try {
      await _dio.delete<Map<String, dynamic>>(
        '/vardiya-plani/$planId',
        queryParameters: {if (sebep != null && sebep.isNotEmpty) 'not_metni': sebep},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  static String _tarih(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final vardiyaPlaniApiProvider =
    Provider<VardiyaPlaniApi>((ref) => VardiyaPlaniApi(ref.watch(dioProvider)));
