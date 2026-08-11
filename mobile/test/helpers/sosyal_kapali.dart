/// (P154 / Asama 4) SOSYAL GIRIS KAPALI — widget testleri icin gecersiz kilma.
///
/// NEDEN GEREKLI: giris ekrani cizilirken "hangi saglayicilar acik" diye
/// SUNUCUYA sorar. Testte sunucu yoktur; istek Dio'nun baglanti zaman
/// asimina kadar asili kalir ve `flutter_test` "A Timer is still pending"
/// ile DUSER — urun kusuru degil, testte gercek bir ag cagrisi kalmasi.
///
/// TEK SATIRLIK GECERSIZ KILMA: her test dosyasinda dort bos govdeli bir
/// sahte yazmak yerine burada BIR kez yazilir.
///
/// BOS LISTE DONER — yani "sosyal giris yapilandirilmamis" hâli. Mevcut
/// giris testlerinin olctugu sey budur zaten: ekran, saglayici yokken
/// bugunku gibi gorunmeli.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/features/auth/data/auth_repository_impl.dart';
import 'package:mobile/src/features/auth/domain/oauth_repository.dart';
import 'package:mobile/src/features/auth/domain/oauth_sonuc.dart';

class SosyalKapaliRepository implements OauthRepository {
  const SosyalKapaliRepository();

  @override
  Future<List<String>> saglayicilar() async => const [];

  @override
  Future<OauthSonuc?> akis(String saglayici) async => null;

  @override
  Future<({String tesisAd, String telefonMaskeli})> baglanBasla({
    required String baglamaJetonu,
    required String tesisKodu,
    required String telefon,
  }) async =>
      (tesisAd: '', telefonMaskeli: '');

  @override
  Future<void> baglanDogrula({
    required String baglamaJetonu,
    required String telefon,
    required String kod,
  }) async {}
}

/// `ProviderScope(overrides: [...sosyalKapali])` ile kullanilir.
final sosyalKapali = [
  oauthRepositoryProvider.overrideWithValue(const SosyalKapaliRepository()),
];
