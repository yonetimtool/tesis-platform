import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../../profile/data/profile_api.dart';

/// (P243 §6d) ILK GIRIS TURU — MOBIL.
///
/// =========================================================================
/// NEDEN VAR
/// =========================================================================
/// Kurulum sihirbazi "NE YAPILACAGINI" soyluyordu ama "BU URUN NASIL
/// CALISIR"i hicbir yerde soylemiyordu. Yeni yonetici 19 adimlik bir
/// liste goruyor ve hangisinin gercekten gerektigini bilmiyordu (§6a).
///
/// =========================================================================
/// "BIR KEZ" NEREDE TUTULUR: HESAPTA, CIHAZDA DEGIL
/// =========================================================================
/// `KurulumHatirlatici`nin kapatma karari CIHAZDA durur ve bu dogrudur:
/// o bir "simdi degil" tercihidir. TUR BASKA BIR SEY — bir kez ogrenilen
/// bilgidir. Cihazda tutulsaydi telefonda turu atlayan yonetici, web
/// panelinde onu YENIDEN gorurdu. Isaret `app_user.tur_goruldu_at`
/// (goc 0148) ve KULLANICI BASINA: ayni tesise sonradan eklenen ikinci
/// yonetici turu kendi ilk girisinde gorur.
///
/// ATLAMAK DA "GORDU"DUR: atlama ile sonuna kadar izleme ayni isareti
/// yazar — aksi hâlde "atla" dugmesi hicbir sey yapmamis olurdu.
///
/// KIM GORUR: yalniz admin + yonetici (`canViewKurulum`). Sakine "once
/// bloklari girin" demek anlamsiz olurdu.
class IlkGirisTuru extends ConsumerStatefulWidget {
  const IlkGirisTuru({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<IlkGirisTuru> createState() => _IlkGirisTuruState();
}

/// Tur ekranlari — baslik + metin. Dort ekran: brief "3-4" diyor ve
/// dorduncusu kullaniciya GERI DONUS YOLUNU gosteriyor (turu kapatan
/// kisi bir daha nereye bakacagini bilmeli).
const _ekranSayisi = 4;

class _IlkGirisTuruState extends ConsumerState<IlkGirisTuru> {
  /// Bu oturumda bir kez acildi mi — arka planda bir saglayici
  /// tazelendiginde kullanicinin ustune ikinci bir diyalog binmesin.
  bool _gosterildi = false;

  Future<void> _belkiGoster() async {
    if (_gosterildi || !mounted) return;
    final rol = ref.read(currentUserRoleProvider).value ?? UserRole.unknown;
    if (!rol.canViewKurulum) return;
    final profil = ref.read(profileProvider).value;
    // Profil YUKLENMEDIYSE sessiz: bilmedigimiz bir sey hakkinda
    // kullaniciya pencere acmayiz.
    if (profil == null || profil.turGoruldu) return;
    _gosterildi = true;
    await turuGoster(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final rol = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    if (rol.canViewKurulum) {
      ref.watch(profileProvider);
      // Cizim sirasinda diyalog acilamaz; ilk kareden SONRAYA birakilir.
      WidgetsBinding.instance.addPostFrameCallback((_) => _belkiGoster());
    }
    return widget.child;
  }
}

/// Turu ACAR ve kapanista isareti yazar. Sihirbazdaki "tekrar goster"
/// dugmesi de bunu cagirir — "bir kez gosterilir" ile "bir daha asla
/// ulasilamaz" ayni sey degil.
Future<void> turuGoster(BuildContext context, WidgetRef ref) async {
  await showDialog<void>(
    context: context,
    builder: (_) => const _TurDiyalogu(),
  );
  try {
    await ref.read(profileApiProvider).turGoruldu();
    ref.invalidate(profileProvider);
  } catch (_) {
    // ISARET YAZILAMADIYSA SESSIZ KALINIR ve pencere yine kapanir.
    // Kullaniciyi bir ag hatasi yuzunden tanitim penceresinde tutmak,
    // hatanin kendisinden daha kotu olurdu; tur bir sonraki girisde
    // yeniden cikar (kabul edilen bedel).
  }
}

class _TurDiyalogu extends StatefulWidget {
  const _TurDiyalogu();

  @override
  State<_TurDiyalogu> createState() => _TurDiyaloguState();
}

class _TurDiyaloguState extends State<_TurDiyalogu> {
  int _sira = 0;

  String _baslik(AppLocalizations l) => switch (_sira) {
    0 => l.tur1Baslik,
    1 => l.tur2Baslik,
    2 => l.tur3Baslik,
    _ => l.tur4Baslik,
  };

  String _metin(AppLocalizations l) => switch (_sira) {
    0 => l.tur1Metin,
    1 => l.tur2Metin,
    2 => l.tur3Metin,
    _ => l.tur4Metin,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sonMu = _sira == _ekranSayisi - 1;
    return AlertDialog(
      title: Text(l10n.turBaslik),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.turSayac(_sira + 1, _ekranSayisi),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(_baslik(l10n), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(_metin(l10n), style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
      actions: [
        // ATLA HER EKRANDA: yalniz ilk ekranda olsaydi, ikinci ekranda
        // ilgisini kaybeden kisinin cikisi kalmazdi.
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.turAtla),
        ),
        if (_sira > 0)
          TextButton(
            onPressed: () => setState(() => _sira -= 1),
            child: Text(l10n.turGeri),
          ),
        FilledButton(
          onPressed: sonMu
              ? () => Navigator.of(context).pop()
              : () => setState(() => _sira += 1),
          child: Text(sonMu ? l10n.turBitir : l10n.turIleri),
        ),
      ],
    );
  }
}
