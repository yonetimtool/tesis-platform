/// (P247 §2) HESAP MENUSUNDE MOD SECIMI — "Yonetici" / "Sakin".
///
/// Yalniz iki rolu olan kisi gorur (`GET /me` `roller` iki eleman: yonetici
/// + aktif daire bagi). Tek rolde, yuklenirken ve hata durumunda HICBIR SEY
/// cizilmez — olmayan bir karar sunulmaz. Aktif mod isaretli ve
/// dokunulamaz; otekine dokunmak gecisi baslatir ([rolGecisiBaslat]).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/l10n.dart';
import '../../../auth/data/current_user_provider.dart';
import '../../../auth/data/rol_gecisi.dart';
import '../../../auth/domain/user_role.dart';

class RolGecisSecenekleri extends ConsumerWidget {
  const RolGecisSecenekleri({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roller = ref.watch(rolSecenekleriProvider).value ?? const [];
    final aktif = ref.watch(currentUserRoleProvider).value;
    if (roller.length < 2 || aktif == null) return const SizedBox.shrink();
    final l10n = context.l10n;

    Widget secenek(UserRole rol, String etiket, IconData ikon, Key key) {
      final secili = rol == aktif;
      return ListTile(
        key: key,
        leading: Icon(ikon),
        title: Text(etiket),
        trailing: secili ? const Icon(Icons.check) : null,
        selected: secili,
        onTap: secili ? null : () => rolGecisiBaslat(context, rol),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 4),
          child: Text(
            l10n.rolGecisBaslik,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        for (final rol in roller)
          if (rol == UserRole.yonetici)
            secenek(rol, l10n.rolGecisYonetici,
                Icons.admin_panel_settings_outlined,
                const Key('rol-gecis-yonetici'))
          else if (rol == UserRole.resident)
            secenek(rol, l10n.rolGecisSakin, Icons.home_outlined,
                const Key('rol-gecis-sakin')),
        const Divider(height: 1),
      ],
    );
  }
}
