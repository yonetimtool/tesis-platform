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

/// `tel:` semali gecerli bir URI ise onu, degilse null doner.
///
/// AYRI FONKSIYON, cunku karar PLATFORMDAN BAGIMSIZDIR ve oyle test
/// edilmelidir: `dial` uzerinden test etmek `launchUrl`u cagirir, o da
/// MethodChannel'a gider ve baglama bagli olarak "Binding has not yet
/// been initialized" ile duser — yani testin konusu (sema karari) degil,
/// test ortami olculur. Ilk yazimda tam bu oldu: dosya tek basina gecti,
/// tam suitte dustu.
Uri? telSemasi(String girdi) {
  final uri = Uri.tryParse(girdi);
  if (uri == null || uri.scheme != 'tel') return null;
  if (uri.path.isEmpty) return null; // `tel:` tek basina aranacak sey degil
  return uri;
}
