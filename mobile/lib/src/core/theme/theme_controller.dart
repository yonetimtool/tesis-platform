import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/token_storage.dart';

/// Kullanicinin sectigi tema modu (acik/koyu/sistem) — [FlutterSecureStorage]
/// ile kalici (uygulamanin mevcut yerel-saklama deseni; token'larla ayni
/// depo). Varsayilan: sistem. Depo okumasi async oldugundan, deger okunana
/// kadar gecici olarak sistem modu gecerlidir.
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'ui.theme_mode';

  @override
  ThemeMode build() {
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

  static ThemeMode? _decode(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
