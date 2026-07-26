/// Bellekte kalan sahte [FlutterSecureStorage] — "uygulama yeniden basladi"
/// (yeni ProviderContainer, AYNI depo) senaryolarini da tasir.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BellekDepo implements FlutterSecureStorage {
  BellekDepo([Map<String, String>? baslangic, this.gecikme = Duration.zero])
      : kutu = {...?baslangic};

  final Map<String, String> kutu;

  /// GERCEK depo bir platform kanali turudur (milisaniyeler). Acilis
  /// yarislarini olcen testler bunu taklit etmek icin gecikme verir.
  final Duration gecikme;

  /// Okuma sayaci — acilistaki es zamanli okumalari gozlemek icin.
  int okumaSayisi = 0;

  @override
  Future<String?> read({required String key, dynamic iOptions,
      dynamic aOptions, dynamic lOptions, dynamic webOptions,
      dynamic mOptions, dynamic wOptions}) async {
    okumaSayisi++;
    if (gecikme > Duration.zero) await Future<void>.delayed(gecikme);
    return kutu[key];
  }

  @override
  Future<void> write({required String key, required String? value,
      dynamic iOptions, dynamic aOptions, dynamic lOptions,
      dynamic webOptions, dynamic mOptions, dynamic wOptions}) async {
    if (value == null) {
      kutu.remove(key);
    } else {
      kutu[key] = value;
    }
  }

  @override
  Future<void> delete({required String key, dynamic iOptions,
      dynamic aOptions, dynamic lOptions, dynamic webOptions,
      dynamic mOptions, dynamic wOptions}) async {
    kutu.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('test disi kullanim: ${invocation.memberName}');
}
