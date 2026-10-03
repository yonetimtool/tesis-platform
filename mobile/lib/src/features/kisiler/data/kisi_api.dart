import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// (P253 Asama 1) `GET /users/{id}` — kisi TANILAMA karti (web kisi
/// duzenleme penceresindeki "Bildirim tanilama" ile ayni alanlar).
///
/// SALT OKUNUR bildirim tercihleri: tercihi baskasi adina degistirmek
/// rizayi anlamsizlastirir (sunucu da yazdirmaz).
class KisiDetay {
  const KisiDetay({
    required this.id,
    required this.ad,
    required this.role,
    required this.isActive,
    this.email,
    this.telefon,
    this.aranabilir = false,
    this.kayitTamamlandi = false,
    this.epostaDogrulandi = false,
    this.bildirimEposta,
    this.bildirimSms,
    this.bildirimMobil,
    this.mobilCihazSayisi = 0,
    this.odemeKodu,
  });

  final String id;
  final String ad;
  final String role;
  final bool isActive;
  final String? email;
  final String? telefon;
  final bool aranabilir;
  final bool kayitTamamlandi;
  final bool epostaDogrulandi;
  final bool? bildirimEposta;
  final bool? bildirimSms;
  final bool? bildirimMobil;
  final int mobilCihazSayisi;
  final String? odemeKodu;

  /// "Mobil bildirim acik" ama kayitli cihaz yok: bildirim GITMEZ.
  bool get mobilCihazsiz => (bildirimMobil ?? false) && mobilCihazSayisi == 0;

  factory KisiDetay.fromJson(Map<String, dynamic> j) => KisiDetay(
    id: j['id'] as String? ?? '',
    ad: j['ad'] as String? ?? '',
    role: j['role'] as String? ?? '',
    isActive: (j['is_active'] as bool?) ?? true,
    email: j['email'] as String?,
    telefon: j['telefon'] as String?,
    aranabilir: (j['aranabilir'] as bool?) ?? false,
    kayitTamamlandi: (j['kayit_tamamlandi'] as bool?) ?? false,
    epostaDogrulandi: (j['eposta_dogrulandi'] as bool?) ?? false,
    bildirimEposta: j['bildirim_eposta'] as bool?,
    bildirimSms: j['bildirim_sms'] as bool?,
    bildirimMobil: j['bildirim_mobil'] as bool?,
    mobilCihazSayisi: (j['mobil_cihaz_sayisi'] as num?)?.toInt() ?? 0,
    odemeKodu: j['odeme_kodu'] as String?,
  );
}

class KisiApi {
  KisiApi(this._dio);

  final Dio _dio;

  Future<KisiDetay> detay(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/users/$id');
      return KisiDetay.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `DELETE /users/{id}` — sunucu AKILLI siler: gecmisi yoksa satir
  /// gider (`true`), varsa anonimlestirilir ve kayitlar korunur (`false`).
  Future<bool> sil(String id) async {
    try {
      final res = await _dio.delete<Map<String, dynamic>>('/users/$id');
      return (res.data?['deleted'] as bool?) ?? true;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /users/acilabilir-roller` — cagiranin ACABILECEGI ve
  /// duzenleyebilecegi roller. Liste istemcide SABITLENMEZ (P130).
  Future<Set<String>> acilabilirRoller() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/users/acilabilir-roller');
      return ((res.data?['roller'] as List?) ?? const []).whereType<String>().toSet();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `PATCH /users/{id}` — yalniz verilen alanlar (aktiflik, aranabilir).
  Future<void> guncelle(String id, {bool? aktif, bool? aranabilir}) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/users/$id',
        data: {'is_active': ?aktif, 'aranabilir': ?aranabilir},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final kisiApiProvider = Provider<KisiApi>((ref) => KisiApi(ref.watch(dioProvider)));

final kisiDetayProvider = FutureProvider.autoDispose.family<KisiDetay, String>(
  (ref, id) => ref.watch(kisiApiProvider).detay(id),
);

/// Cagiranin acabilecegi roller (bos kume = hicbiri).
final acilabilirRollerProvider = FutureProvider.autoDispose<Set<String>>(
  (ref) => ref.watch(kisiApiProvider).acilabilirRoller(),
);
