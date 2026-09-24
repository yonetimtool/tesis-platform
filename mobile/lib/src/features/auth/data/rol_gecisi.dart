/// (P247 §2) PROFILDEN ROL GECISI — YONETICI <-> SAKIN (mobil istemci).
///
/// ===========================================================================
/// KARAR: GECIS = OTURUM KABININ YENIDEN KURULMASI
/// ===========================================================================
/// Sunucu gecisi YENI bir jeton ciftiyle yapar (yeni yetki baglami). Mobilde
/// yalniz `currentUserRoleProvider`i tazelemek YETMEZ: onlarca saglayici
/// (duyuru/gorev/kargo/talep denetleyicileri...) `autoDispose` DEGIL ve role
/// bakmiyor — yonetici modunda cekilmis bir duyuru listesi sakin moduna
/// TASINIRDI. "Ekranda karisik durum HICBIR AN olusmasin" sarti icin
/// `ProviderScope` yeni bir anahtarla yeniden kurulur ([OturumKoku]):
/// butun Riverpod onbellegi gider, yonlendirici acilistan baslar — iki
/// ayri hesaba gecmek gibi. Jetonlar guvenli depoda oldugu icin oturum
/// korunur; refresh jetonu modu (`arol`) tasidigindan uygulama yeniden
/// acildiginda da son mod gelir.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/branding/yonetio_logo.dart';
import '../domain/jwt_claims.dart';
import '../domain/token_pair.dart';
import '../domain/user_role.dart';
import '../presentation/auth_controller.dart';
import 'current_user_provider.dart';
import 'token_storage.dart';

/// `GET /me` `roller` — kisinin bu tesiste gecebilecegi roller (asil rol
/// ilk). Tek eleman ya da hata -> gecis menusu YOK.
///
/// `autoDispose` DEGIL: push dokunmasi (kok dinleyici) degeri beklemek
/// zorunda ve autoDispose bir saglayiciyi `ref.read(.future)` ile okumak
/// onu okuma bitmeden atabilirdi. Bayatlama riski yok: oturum durumu
/// degisince (giris/cikis) yeniden hesaplanir ve rol gecisi zaten butun
/// kabi yeniden kurar.
final rolSecenekleriProvider = FutureProvider<List<UserRole>>((ref) async {
  ref.watch(authControllerProvider.select((s) => s.status));
  final jeton = await ref.watch(tokenStorageProvider).readAccessToken();
  if (jeton == null) return const [];
  try {
    final res = await ref.watch(dioProvider).get<Map<String, dynamic>>('/me');
    final ham = res.data?['roller'];
    if (ham is! List) return const [];
    return [
      for (final r in ham)
        if (r is String && UserRole.fromClaim(r) != UserRole.unknown)
          UserRole.fromClaim(r),
    ];
  } catch (_) {
    // Menu bir KOLAYLIKTIR: uc dustugunde hesap menusunu kirmak yerine
    // gecis secenegi gizlenir.
    return const [];
  }
});

/// Gecisten sonra YENI kapta yapilacak isler (bildirim + hedef rota).
class BekleyenGecis {
  const BekleyenGecis({required this.hedef, this.rota, this.bildir = true});

  /// "Sakin moduna gecildi" gosterilsin mi? Soguk acilista son modun geri
  /// yuklenmesi (kullanici bir sey secmedi) SESSIZDIR.
  final bool bildir;

  /// Gecilen rol (SnackBar metni bundan).
  final UserRole hedef;

  /// Ana ekrandan sonra acilacak rota (push'tan gelen hedef); yoksa ana ekran.
  final String? rota;
}

/// Yeni kaba [OturumKoku] tarafindan verilir; ana ekran ([HomeShell]) ilk
/// cizimde tuketir.
class BekleyenGecisNotifier extends Notifier<BekleyenGecis?> {
  BekleyenGecisNotifier([this._ilk]);

  final BekleyenGecis? _ilk;

  @override
  BekleyenGecis? build() => _ilk;

  void ayarla(BekleyenGecis? deger) => state = deger;

  /// Degeri alir ve temizler (bir kez tuketilir).
  BekleyenGecis? tuket() {
    final d = state;
    state = null;
    return d;
  }
}

final bekleyenGecisProvider =
    NotifierProvider<BekleyenGecisNotifier, BekleyenGecis?>(
  BekleyenGecisNotifier.new,
);

/// Oturum kabini yeniden kurar ve [bekleyen]i yeni kaba tasir.
typedef OturumYenidenKur = Future<void> Function(BekleyenGecis bekleyen);

/// Varsayilan: kok ([OturumKoku]) yoksa (gomulu/test) YEDEK yol — rol
/// saglayicilari tazelenir ve bekleyen is ayni kapta birakilir. Uygulamada
/// [OturumKoku] bunu gercek yeniden kurmayla override eder.
final oturumYenidenKurProvider = Provider<OturumYenidenKur>((ref) {
  return (bekleyen) async {
    ref.invalidate(currentUserRoleProvider);
    ref.invalidate(rolSecenekleriProvider);
    ref.read(bekleyenGecisProvider.notifier).ayarla(bekleyen);
  };
});

/// `POST /me/rol-gecis` — tel.
class RolGecisApi {
  RolGecisApi(this._dio);

  final Dio _dio;

  Future<TokenPair> gec(UserRole hedef, {String? refreshToken}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/me/rol-gecis',
        data: {
          'rol': hedef.wire,
          // Verilirse eski refresh ailesi sunucuda KAPANIR: iki mod ayni
          // anda acik kalmaz.
          'refresh_token': ?refreshToken,
        },
      );
      return TokenPair.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final rolGecisApiProvider =
    Provider<RolGecisApi>((ref) => RolGecisApi(ref.watch(dioProvider)));

/// Saglayici okuyucu — `ProviderContainer.read`, `Ref.read` ya da
/// `WidgetRef.read` tear-off'u.
typedef SaglayiciOku = T Function<T>(ProviderListenable<T> saglayici);

/// Gecisin tamami: tel -> depo -> son modu hatirla -> kabi yeniden kur.
/// Hata FIRLATIR (UI perdeyi kapatip mesaj gosterir; jetonlar degismez).
///
/// [oku] bir `ProviderContainer`in okuyucusudur, bir widget'in `ref`i
/// DEGIL: gecisi baslatan widget (hesap menusu, bildirim satiri) istek
/// surerken kapanabilir ve kapanmis bir widget'in `ref`i kullanilamaz.
Future<void> rolGecisiYap(
  SaglayiciOku oku,
  UserRole hedef, {
  String? rota,
  bool bildir = true,
}) async {
  final depo = oku(tokenStorageProvider);
  final refresh = await depo.readRefreshToken();
  final jetonlar =
      await oku(rolGecisApiProvider).gec(hedef, refreshToken: refresh);
  await depo.save(jetonlar);
  await sonModuYaz(oku(secureStorageProvider), jetonlar.accessToken, hedef);
  await oku(oturumYenidenKurProvider)(
    BekleyenGecis(hedef: hedef, rota: rota, bildir: bildir),
  );
}

// --------------------------------------------------------------------------
// SON MOD — SOGUK ACILISTA GERI YUKLENIR
// --------------------------------------------------------------------------
// Mobilde soguk acilis HER ZAMAN login'e duser (WP2.3, auth_controller) ve
// giris ASIL rolle (yonetici) jeton verir: refresh'in tasidigi `arol`
// yeni oturuma ulasmaz. "Secilen mod hatirlansin" sarti icin son mod
// KULLANICI BASINA (jeton `sub`u) guvenli depoya yazilir; ayni cihazda
// baska bir hesap onu MIRAS ALMAZ.

String _sonModAnahtari(String sub) => 'rol.son_mod.$sub';

Future<void> sonModuYaz(
  FlutterSecureStorage depo,
  String erisim,
  UserRole mod,
) async {
  final sub = decodeJwtClaims(erisim)?['sub'] as String?;
  if (sub == null) return;
  try {
    await depo.write(key: _sonModAnahtari(sub), value: mod.wire);
  } catch (_) {
    // Hatirlama bir KOLAYLIKTIR; yazilamazsa gecis yine gecerli.
  }
}

/// Giristen sonra: son mod SAKIN ise ve kisi hala sakin olabiliyorsa
/// sessizce sakin moduna gecilir. `true` = geri yukleme SURUYOR (ana ekran
/// bu surede acilis ekrani gosterir — yonetici paneli bir an bile
/// etkilesimli gorunmesin).
///
/// Yalniz ASIL rolde (yonetici jetonu) calisir; sakin modundaki kapta
/// hicbir sey yapmaz.
final sonModGeriYukleProvider = FutureProvider<bool>((ref) async {
  ref.watch(authControllerProvider.select((s) => s.status));
  final erisim = await ref.watch(tokenStorageProvider).readAccessToken();
  if (erisim == null) return false;
  final iddia = decodeJwtClaims(erisim);
  final sub = iddia?['sub'] as String?;
  if (sub == null || UserRole.fromClaim(iddia?['role'] as String?) !=
      UserRole.yonetici) {
    return false;
  }
  String? son;
  try {
    son = await ref.read(secureStorageProvider).read(key: _sonModAnahtari(sub));
  } catch (_) {
    return false;
  }
  if (son != UserRole.resident.wire) return false;
  final roller = await ref.read(rolSecenekleriProvider.future);
  if (!roller.contains(UserRole.resident)) return false;
  try {
    await rolGecisiYap(ref.read, UserRole.resident, bildir: false);
    return true;
  } catch (_) {
    // Gecis olmadiysa yonetici modunda KALINIR (dogru ve guvenli varsayilan).
    return false;
  }
});

/// UI girisi: tam ekran gecis perdesi + gecis. Perde, eski modun ekrani
/// ile yenisi arasinda KARISIK bir kare cizilmesini onler — kullanici
/// eski ekrani etkilesimli olarak hic gormez; yeni kap kurulunca perde
/// agacla birlikte gider. Hata olursa perde kapanir, mesaj gosterilir.
Future<void> rolGecisiBaslat(
  BuildContext context,
  UserRole hedef, {
  String? rota,
}) async {
  final kap = ProviderScope.containerOf(context, listen: false);
  final l10n = AppLocalizations.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.maybeOf(context);
  navigator.push(RolGecisPerdesi.rota(hedef));
  try {
    await rolGecisiYap(kap.read, hedef, rota: rota);
    // Gercek yeniden kurmada eski gezgin agacla birlikte gider (mounted
    // false). YEDEK yolda (kok yok) ayni kap surer: perde kapanir ve
    // yigin ana ekrana indirilir — eski modun alt ekrani kalmasin.
    if (navigator.mounted) navigator.popUntil((r) => r.isFirst);
  } catch (_) {
    if (navigator.mounted && navigator.canPop()) navigator.pop();
    messenger?.showSnackBar(SnackBar(content: Text(l10n.rolGecisHata)));
  }
}

/// Tam ekran gecis durumu: logo + ilerleme + "Sakin moduna geciliyor...".
class RolGecisPerdesi extends StatelessWidget {
  const RolGecisPerdesi({super.key, required this.hedef});

  final UserRole hedef;

  static Route<void> rota(UserRole hedef) => PageRouteBuilder<void>(
        opaque: true,
        barrierDismissible: false,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => RolGecisPerdesi(hedef: hedef),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metin = hedef == UserRole.resident
        ? l10n.rolGecisSuruyorSakin
        : l10n.rolGecisSuruyorYonetici;
    return PopScope(
      canPop: false,
      child: Scaffold(
        key: const Key('rol-gecis-perdesi'),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const YonetioLogoVertical(iconSize: 84),
              const SizedBox(height: 24),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 16),
              Text(metin, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gecis sonrasi bildirim metni.
String rolGecildiMetni(AppLocalizations l10n, UserRole hedef) =>
    hedef == UserRole.resident ? l10n.rolGecildiSakin : l10n.rolGecildiYonetici;

/// Rol gecisli bir hedef karari: gidilecek rota + (gerekiyorsa) gecilecek rol.
typedef RolHedefi = ({String rota, UserRole? gecis});

/// (P247 §2) Bildirim/push dokunmasi icin ortak akis. Roller YALNIZ
/// dogrudan hedef yoksa sorulur: tek rollu kullanicinin her dokunusu bir
/// ag istegi beklemesin. [karar] verilen rol listesiyle karari verir
/// (`rolGecisliHedef` / `bildirimHedefiRolGecisli`).
///
/// [rollerSart]: bildirim aktif moddan BASKA bir moda ait (`hedef_rol`) —
/// dogrudan hedef olsa bile roller sorulur, cunku dogru mod o olabilir.
Future<RolHedefi?> rolGecisliKarar(
  ProviderContainer kap,
  RolHedefi? Function(List<UserRole> roller) karar, {
  bool rollerSart = false,
}) async {
  final dogrudan = karar(const []);
  if (dogrudan != null && !rollerSart) return dogrudan;
  final roller = await kap
      .read(rolSecenekleriProvider.future)
      .catchError((_) => const <UserRole>[]);
  return karar(roller);
}
