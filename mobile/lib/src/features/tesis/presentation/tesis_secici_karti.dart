/// (P203 §2) TESIS DEGISTIR KARTI — ayarlar ekraninda.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../../auth/data/token_storage.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/rol_adi.dart';
import '../data/tesis_api.dart';
import '../domain/tesis_uyeligi.dart';

/// Uyelikleri getirir. HATA SESSIZCE BOS LISTE olur: bu kart bir
/// KOLAYLIKTIR; uc dustugunde ayarlar ekraninin tamamini kirmasi
/// kullaniciya orantisiz bir bedel odetirdi.
final tesisUyelikleriProvider = FutureProvider<List<TesisUyeligi>>((ref) async {
  try {
    return await ref.read(tesisApiProvider).uyelikler();
  } catch (_) {
    return const [];
  }
});

class TesisSeciciKarti extends ConsumerStatefulWidget {
  const TesisSeciciKarti({super.key});

  @override
  ConsumerState<TesisSeciciKarti> createState() => _TesisSeciciKartiState();
}

class _TesisSeciciKartiState extends ConsumerState<TesisSeciciKarti> {
  bool _bekliyor = false;

  Future<void> _gec(TesisUyeligi hedef) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _bekliyor = true);
    try {
      final jetonlar = await ref.read(tesisApiProvider).degistir(hedef.tenantId);
      // JETONU SAKLA: bundan sonraki her istek YENI tesise gider.
      await ref.read(tokenStorageProvider).save(jetonlar);
      if (!mounted) return;
      // ROL VE TESIS SAGLAYICILARINI TAZELE: rol degismis OLABILIR
      // (birinde yonetici, otekinde sakin) ve menu/kabuk role gore
      // ciziliyor. Yalnizca jetonu degistirip ekranda kalmak, YENI
      // tesiste ESKI menuyu gostermek olurdu.
      ref.invalidate(currentUserRoleProvider);
      ref.invalidate(currentTenantIdProvider);
      ref.invalidate(tesisUyelikleriProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(hedef.ad)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ortakBeklenmeyenHata)),
      );
    } finally {
      if (mounted) setState(() => _bekliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final uyelikler = ref.watch(tesisUyelikleriProvider);
    final simdiki = ref.watch(currentTenantIdProvider).value;

    return uyelikler.maybeWhen(
      data: (liste) {
        // TEK TESISLIYE HIC CIZILMEZ: olmayan bir karar sunmak, ayarlar
        // ekranini gereksiz yere uzatirdi.
        if (liste.length < 2) return const SizedBox.shrink();
        return Card(
          key: const Key('tesis-secici-karti'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  l10n.tesisDegistirBaslik,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final u in liste)
                ListTile(
                  key: Key('tesis-sec-${u.tenantId}'),
                  leading: Icon(
                    u.tenantId == simdiki
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(u.ad),
                  // ROL GOSTERILIR: kisi hangi yetkiyle girecegini
                  // SECMEDEN ONCE bilmeli.
                  subtitle: Text(
                    u.tenantId == simdiki
                        ? l10n.tesisDegistirSecili
                        : rolAdi(l10n, UserRole.fromClaim(u.rol)),
                  ),
                  enabled: !_bekliyor && u.tenantId != simdiki,
                  onTap: u.tenantId == simdiki ? null : () => _gec(u),
                ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
