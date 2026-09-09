import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/auth_interceptor.dart';
import '../network/dio_provider.dart';

/// (P221) SUNUCUDAN GELEN OZELLIK BAYRAKLARI.
///
/// ===========================================================================
/// NEDEN SUNUCUDAN
/// ===========================================================================
/// Dukkan sekmesi bu surumde YAYINLANIYOR ama icerigi hazir degil.
/// Bayrak uygulamanin icinde olsaydi, acmak icin YENI SURUM ve MAGAZA
/// TURU gerekirdi — inceleme gunler surer. Sunucuda olunca yayina alma
/// gunu tek bir ortam degiskeni yetiyor.
///
/// ===========================================================================
/// VARSAYILAN KAPALI — HER HATA YOLUNDA
/// ===========================================================================
/// Ag hatasi, eski sunucu (uc yok), bozuk govde: hepsinde `false`.
/// "Bilmiyorsak acalim" demek, hazir olmayan bir pazar yerini
/// kullaniciya gostermek olurdu.
class OzellikBayraklari {
  const OzellikBayraklari({this.dukkan = false});

  /// Pazar yeri yuzeyi acik mi. VARSAYILAN FALSE.
  final bool dukkan;

  factory OzellikBayraklari.fromJson(Map<String, dynamic> j) =>
      OzellikBayraklari(
        // `as bool?` + `?? false`: sunucu alani hic gondermezse ya da
        // beklenmedik bir tip gonderirse KAPALI kalir.
        dukkan: j['dukkan'] as bool? ?? false,
      );
}

class OzellikApi {
  OzellikApi(this._dio);
  final Dio _dio;

  Future<OzellikBayraklari> getir() async {
    // KIMLIKSIZ: giris ekranindan ONCE cagriliyor. `dukkanJetonu` bos
    // dize ile isaretleniyor ki interceptor YONETIYOR jetonunu koymasin
    // ve olasi bir 401'i "oturum bitti" sanmasin (F7 §2'de ayni kalip).
    final r = await _dio.get<Map<String, dynamic>>(
      '/ozellikler',
      options: Options(extra: {AuthInterceptor.dukkanJetonu: ''}),
    );
    return OzellikBayraklari.fromJson(r.data ?? const {});
  }
}

final ozellikApiProvider =
    Provider<OzellikApi>((ref) => OzellikApi(ref.watch(dioProvider)));

/// Bayraklar — HATA DA KAPALI DONER.
///
/// Hata yakalanip varsayilana dusuyoruz: cagiran her yerde
/// `when(error: ...)` yazmak zorunda kalsaydi, bir yerde unutulan dal
/// ozelligi ACARDI.
final ozellikBayraklariProvider =
    FutureProvider<OzellikBayraklari>((ref) async {
  try {
    return await ref.watch(ozellikApiProvider).getir();
  } catch (_) {
    // SESSIZ DEGIL, KAPALI: hata yutuluyor ama sonuc "kapali" ve bu
    // gorunur bir davranis (kullanici "yakinda" ekranini gorur).
    return const OzellikBayraklari();
  }
});

/// Dukkan yuzeyi acik mi — ekranlarin okudugu TEK yer.
///
/// Yukleme sirasinda da `false`: bir an icin acilip sonra kapanan bir
/// ekran, kullaniciya "bozuk" gorunurdu.
final dukkanAcikProvider = Provider<bool>((ref) {
  return ref.watch(ozellikBayraklariProvider).value?.dukkan ?? false;
});
