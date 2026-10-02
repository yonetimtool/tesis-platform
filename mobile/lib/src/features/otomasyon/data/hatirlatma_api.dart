/// (P250 §7) Otomatik aidat hatırlatması — web ile AYNI uçlar ve AYNI ayar.
///
///   * `GET/PATCH /hatirlatma-ayari`        — ayar (tek kayıt, iki yüzey),
///   * `GET /finans/hatirlatma-epostalari`  — e-posta geçmişi + teslim durumu.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

class HatirlatmaAyari {
  const HatirlatmaAyari({
    required this.aktif,
    required this.vadeOncesiGun,
    required this.kademeler,
    required this.eposta,
    this.ilkGun,
    this.tekrarSayisi = 0,
    this.aralikGun,
  });

  final bool aktif;
  final int vadeOncesiGun;
  final List<int> kademeler;
  final bool eposta;
  final int? ilkGun;
  final int tekrarSayisi;
  final int? aralikGun;

  factory HatirlatmaAyari.fromJson(Map<String, dynamic> j) => HatirlatmaAyari(
    aktif: (j['aktif'] as bool?) ?? false,
    vadeOncesiGun: (j['vade_oncesi_gun'] as num?)?.toInt() ?? 0,
    kademeler: [
      for (final k in (j['kademeler'] as List? ?? const [])) (k as num).toInt(),
    ],
    eposta: (j['eposta'] as bool?) ?? true,
    ilkGun: (j['ilk_gun'] as num?)?.toInt(),
    tekrarSayisi: (j['tekrar_sayisi'] as num?)?.toInt() ?? 0,
    aralikGun: (j['aralik_gun'] as num?)?.toInt(),
  );
}

class HatirlatmaEpostasi {
  const HatirlatmaEpostasi({
    required this.ad,
    required this.zaman,
    required this.durum,
  });
  final String? ad;
  final DateTime zaman;
  final String durum;
}

class HatirlatmaApi {
  HatirlatmaApi(this._dio);
  final Dio _dio;

  Future<HatirlatmaAyari> ayar() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/hatirlatma-ayari');
      return HatirlatmaAyari.fromJson(r.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<HatirlatmaAyari> guncelle(Map<String, dynamic> govde) async {
    try {
      final r = await _dio.patch<Map<String, dynamic>>(
        '/hatirlatma-ayari',
        data: govde,
      );
      return HatirlatmaAyari.fromJson(r.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<HatirlatmaEpostasi>> epostalar() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '/finans/hatirlatma-epostalari',
        queryParameters: {'limit': 20},
      );
      return [
        for (final e in (r.data!['items'] as List))
          HatirlatmaEpostasi(
            ad: (e as Map<String, dynamic>)['ad'] as String?,
            zaman: DateTime.parse(e['gonderim_zamani'] as String).toLocal(),
            durum: e['durum'] as String,
          ),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final hatirlatmaApiProvider = Provider<HatirlatmaApi>(
  (ref) => HatirlatmaApi(ref.watch(dioProvider)),
);
final hatirlatmaAyariProvider = FutureProvider<HatirlatmaAyari>(
  (ref) => ref.watch(hatirlatmaApiProvider).ayar(),
);
final hatirlatmaEpostalariProvider = FutureProvider<List<HatirlatmaEpostasi>>(
  (ref) => ref.watch(hatirlatmaApiProvider).epostalar(),
);
