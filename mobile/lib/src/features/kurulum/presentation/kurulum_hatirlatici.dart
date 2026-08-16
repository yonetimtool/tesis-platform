import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/l10n.dart';
import '../../../routing/app_router.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/data/token_storage.dart';
import '../../auth/domain/user_role.dart';
import '../data/kurulum_api.dart';

/// (P166 §8.2) ILK GIRISTE KURULUM HATIRLATICISI — mobil.
///
/// Web'deki `KurulumHatirlatici` ile AYNI DAVRANIS: kurulum bitmemisse bir
/// kez pop-up cikar, kapatilabilir, kapatma karari saklanir ve Ayarlardan
/// geri acilabilir.
///
/// =========================================================================
/// KENDI SIHIRBAZINI CIZMEZ
/// =========================================================================
/// Adim listesi `KurulumScreen`de. Burada iki dugme ve bir sayac var —
/// ikinci bir kopya tutmak, biri degistiginde otekini unutmak olurdu.
///
/// =========================================================================
/// KIME, NE ZAMAN
/// =========================================================================
///  * YALNIZ admin + yonetici (`canViewKurulum`). Oteki rollerde istek bile
///    ATILMAZ — uc 403 doner ve o 403 hicbir sey kazandirmaz.
///  * Kurulum BITTIYSE cikmaz. Biten bir isi hatirlatmak, pop-up'i "her
///    acilista kapatilan sey"e cevirirdi.
///  * Kullanici KAPATTIYSA cikmaz. Karar CIHAZDA ve ROL BASINA saklanir
///    (`menu_bolum_tercihi.dart` ile ayni depo); sunucuda bir alan acmak
///    kullanici basina degil TESIS basina bir tercih uretir ve bir yonetici
///    kapatinca oteki de gormezdi.
///  * Ag hatasinda cikmaz: durum bilinmiyorken hatirlatmak, yanlis bir sey
///    soylemekti.
///
/// TAMAMLANANLAR KALICI: sayac sunucudan gelir ve sunucu onu SAYAR,
/// saklamaz — uygulama silinse de ilerleme kaybolmaz.
class KurulumHatirlaticiKontrol {
  const KurulumHatirlaticiKontrol._();

  /// Kapatma tercihi anahtari — rol basina.
  static String anahtar(UserRole rol) => 'ui.kurulum_hatirlatici_kapali.${rol.name}';
}

/// Ayarlardan "tekrar goster": kapatma kaydini siler.
Future<void> kurulumHatirlaticiyiAc(WidgetRef ref) async {
  final rol = ref.read(currentUserRoleProvider).value ?? UserRole.unknown;
  if (rol == UserRole.unknown) return;
  await ref
      .read(secureStorageProvider)
      .delete(key: KurulumHatirlaticiKontrol.anahtar(rol));
}

/// Ana ekranin uzerine oturur; cizecek bir sey yoksa `SizedBox.shrink`.
///
/// WIDGET OLARAK DEGIL DIYALOG OLARAK gosterilir: ana ekranin duzenine
/// karismaz ve "modal" davranisi (arka plani kilitleme, geri tusuyla
/// kapanma) platformdan bedava gelir.
class KurulumHatirlatici extends ConsumerStatefulWidget {
  const KurulumHatirlatici({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KurulumHatirlatici> createState() => _KurulumHatirlaticiState();
}

class _KurulumHatirlaticiState extends ConsumerState<KurulumHatirlatici> {
  /// Bu oturumda bir kez gosterildi mi — her yeniden cizimde diyalog
  /// acmamak icin. Yoksa arka planda bir saglayici tazelendiginde
  /// kullanicinin ustune ikinci bir diyalog binerdi.
  bool _gosterildi = false;

  Future<void> _belkiGoster() async {
    if (_gosterildi || !mounted) return;
    final rol = ref.read(currentUserRoleProvider).value ?? UserRole.unknown;
    if (!rol.canViewKurulum) return;

    final durum = ref.read(kurulumDurumProvider).value;
    // Yuklenmediyse ya da hata verdiyse SESSIZ: bilmedigimiz bir sey
    // hakkinda kullaniciyi uyarmayiz.
    if (durum == null || durum.bitti) return;

    final depo = ref.read(secureStorageProvider);
    final anahtar = KurulumHatirlaticiKontrol.anahtar(rol);
    if (await depo.read(key: anahtar) == '1') return;
    if (!mounted) return;

    _gosterildi = true;
    final l10n = context.l10n;
    final git = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.kurulumHatirlaticiBaslik),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.kurulumHatirlaticiMetin),
            const SizedBox(height: 8),
            Text(
              l10n.kurulumSayac(durum.gecilen, durum.toplam),
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.kurulumHatirlaticiSonra),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.kurulumHatirlaticiGit),
          ),
        ],
      ),
    );

    // KAPATMA HER IKI YOLDA DA KAYDEDILIR (sihirbaza gitse bile): amac
    // "bir kez hatirlat"tir. Sihirbaza giden kullanici zaten gormustur;
    // ona her acilista tekrar sormak sitem olurdu.
    await depo.write(key: anahtar, value: '1');
    if (git == true && mounted) context.push(AppRoutes.kurulum);
  }

  @override
  Widget build(BuildContext context) {
    // Durum saglayicisini YALNIZ yetkili rolde dinle: saha/sakin icin
    // istek hic kurulmaz.
    final rol = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    if (rol.canViewKurulum) {
      ref.watch(kurulumDurumProvider);
      // Cizim sirasinda diyalog acilamaz; ilk kareden SONRAYA birakilir.
      WidgetsBinding.instance.addPostFrameCallback((_) => _belkiGoster());
    }
    return widget.child;
  }
}
