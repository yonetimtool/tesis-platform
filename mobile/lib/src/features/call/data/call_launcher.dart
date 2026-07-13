import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Cihaz ceviricisini `tel:` ile acan soyutlama. CALL_PHONE izni GEREKMEZ —
/// tel: yalniz ceviriciyi ACAR (otomatik arama degil; kullanici baslatir).
/// Testlerde sahte launcher ile override edilir.
abstract class CallLauncher {
  /// [telUri] = 'tel:+90...'; ceviriciyi acar. Basari/basarisizlik doner.
  Future<bool> dial(String telUri);
}

class UrlCallLauncher implements CallLauncher {
  const UrlCallLauncher();

  @override
  Future<bool> dial(String telUri) {
    return launchUrl(Uri.parse(telUri), mode: LaunchMode.externalApplication);
  }
}

final callLauncherProvider = Provider<CallLauncher>((ref) {
  return const UrlCallLauncher();
});
