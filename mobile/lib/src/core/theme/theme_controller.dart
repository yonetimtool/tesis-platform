import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/token_storage.dart';
import '../startup/acilis_tercihleri.dart';

/// Kullanicinin sectigi tema modu (acik/koyu/sistem) — [FlutterSecureStorage]
/// ile kalici (uygulamanin mevcut yerel-saklama deseni; token'larla ayni
/// depo). Varsayilan: sistem.
///
/// ILK KARE: tercih `runApp`'ten ONCE okunur ([acilisTercihleriProvider]) →
/// acilista acik/koyu tema CAKMASI olmaz. Tohum yoksa (widget testleri) eski
/// asenkron yol calisir.
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'ui.theme_mode';

  @override
  ThemeMode build() {
    final onOkuma = ref.read(acilisTercihleriProvider);
    if (onOkuma != null) return onOkuma.temaModu ?? ThemeMode.system;
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final raw = await ref.read(secureStorageProvider).read(key: _key);
    final mode = _decode(raw);
    if (mode != null) state = mode;
  }

  /// Modu degistir + kalici yaz. UI aninda tepki verir; yazma arka planda.
  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(secureStorageProvider).write(key: _key, value: mode.name);
  }

  // Cozumleme acilis on-okumasiyla PAYLASILIR (tek kaynak).
  static ThemeMode? _decode(String? raw) => temaModuCoz(raw);
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
