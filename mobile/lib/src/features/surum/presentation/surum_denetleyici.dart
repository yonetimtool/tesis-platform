/// (P202) GUNCELLEME DENETIMI — ne zaman sorulur, ne zaman susturulur.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../auth/data/token_storage.dart' show secureStorageProvider;
import '../data/surum_api.dart';
import '../data/surum_erteleme.dart';
import '../domain/surum_karari.dart';


/// Denetimin sonucu — arayuz bunu izler.
class SurumDurumState {
  const SurumDurumState({
    this.karar = const SurumKarari(durum: SurumDurumu.guncel),
    this.onerilenGosterilsin = false,
  });

  final SurumKarari karar;

  /// ONERILEN uyarisi SU AN gosterilmeli mi (erteleme penceresi disinda).
  final bool onerilenGosterilsin;

  bool get zorunlu => karar.durum == SurumDurumu.zorunlu;
}

class SurumDenetleyici extends Notifier<SurumDurumState> {
  @override
  SurumDurumState build() => const SurumDurumState();

  /// Ayni anda iki kontrol kosmasin (acilis + on plana gelme cakisabilir).
  bool _kosuyor = false;

  /// Platform kimligi. Bilinmeyen yuzeyde ('web', masaustu) sunucu zaten
  /// "guncel" doner; yine de burada da bos gecmek yerine acikca yazilir.
  static String platformKodu() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    return 'diger';
  }

  Future<void> kontrolEt() async {
    if (_kosuyor) return;
    _kosuyor = true;
    try {
      final bilgi = await PackageInfo.fromPlatform();
      final karar = await ref.read(surumApiProvider).kontrol(
            platform: platformKodu(),
            surum: bilgi.version,
          );
      var goster = karar.durum == SurumDurumu.onerilen;
      if (goster && await _erteleme.ertelenmisMi()) goster = false;
      state = SurumDurumState(karar: karar, onerilenGosterilsin: goster);
    } catch (_) {
      // PAKET BILGISI OKUNAMAZSA da uygulama CALISIR. Bu dal testte ve
      // beklenmedik platformlarda gercek: kullaniciyi kendi
      // altyapimizin bir eksigi yuzunden kilitlemeyiz.
      state = const SurumDurumState();
    } finally {
      _kosuyor = false;
    }
  }

  /// "Sonra" — ONERILEN uyarisini [kOnerilenErteleme] kadar sustur.
  Future<void> sonra() async {
    state = SurumDurumState(karar: state.karar, onerilenGosterilsin: false);
    await _erteleme.ertele();
  }

  SurumErteleme get _erteleme =>
      SurumErteleme(ref.read(secureStorageProvider));
}

final surumDenetleyiciProvider =
    NotifierProvider<SurumDenetleyici, SurumDurumState>(SurumDenetleyici.new);

/// Acilista ve ON PLANA GELINCE kontrol eder.
///
/// ===========================================================================
/// NEDEN ON PLANA GELINCE DE
/// ===========================================================================
/// Kullanici uygulamayi GUNLERCE acik birakabilir (mobilde normaldir).
/// Yalniz acilista bakan bir kontrol, tam da en uzun sure guncellenmemis
/// cihazlari atlardi — yani hedef kitlesini kaciran bir kontrol olurdu.
class SurumGozcusu extends ConsumerStatefulWidget {
  const SurumGozcusu({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SurumGozcusu> createState() => _SurumGozcusuState();
}

class _SurumGozcusuState extends ConsumerState<SurumGozcusu>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(surumDenetleyiciProvider.notifier).kontrolEt());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState durum) {
    if (durum == AppLifecycleState.resumed) {
      unawaited(ref.read(surumDenetleyiciProvider.notifier).kontrolEt());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
