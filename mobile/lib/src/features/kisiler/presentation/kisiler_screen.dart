import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../../davetler/presentation/davetler_screen.dart';
import '../../residents/presentation/residents_screen.dart';
import '../../staff/presentation/staff_screen.dart';
import '../domain/kisiler_sekmeleri.dart';
import 'yonetici_listesi.dart';

/// (P251 §8) KISILER — TEK GIRIS, SEKMELER (web `/kisiler` ikizi).
///
/// Eskiden Tanimlar grubunda uc ayri satirdi: Saha Personeli, Site
/// Sakinleri, Davetler; yonetici ve denetci hesabi mobilde HIC
/// acilamiyordu. Hepsi ayni kayit (`app_user`, rolu farkli).
///
/// Her sekme mevcut ekrani GOMULU cizer (ust cubugu bu ekran verir, sekme
/// kendi "Ekle" dugmesini korur). Sekmeler role gore: guvenlik amiri yalniz
/// Personel'i gorur (bkz. `kisilerSekmeleri`).
///
/// Eski adresler (`/personel`, `/sakinler`, `/davetler`) buraya ilgili
/// sekmeyle yonlenir — bildirim derin baglantilari bozulmaz.
class KisilerScreen extends ConsumerWidget {
  const KisilerScreen({super.key, this.ilkSekme});

  /// Adresten gelen sekme (`?sekme=personel`).
  final KisilerSekmesi? ilkSekme;

  static String sekmeAdi(AppLocalizations l10n, KisilerSekmesi s) => switch (s) {
        KisilerSekmesi.sakinler => l10n.kisilerSekmeSakinler,
        KisilerSekmesi.personel => l10n.kisilerSekmePersonel,
        KisilerSekmesi.yoneticiler => l10n.kisilerSekmeYoneticiler,
        KisilerSekmesi.davetler => l10n.kisilerSekmeDavetler,
      };

  static Widget _govde(KisilerSekmesi s) => switch (s) {
        KisilerSekmesi.sakinler => const ResidentsScreen(gomulu: true),
        KisilerSekmesi.personel => const StaffScreen(gomulu: true),
        KisilerSekmesi.yoneticiler => const YoneticiListesi(),
        KisilerSekmesi.davetler => const DavetlerScreen(gomulu: true),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rol = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    final sekmeler = kisilerSekmeleri(rol);
    final baslik = Text(baslikBuyuk(l10n.modulKisiler, context.dilKodu));
    if (sekmeler.isEmpty) {
      return Scaffold(appBar: AppBar(title: baslik));
    }
    // Tek sekme (amir): sekme seridi cizilmez — tek secenekli serit
    // bilgi vermeden yer kaplardi.
    if (sekmeler.length == 1) {
      return Scaffold(appBar: AppBar(title: baslik), body: _govde(sekmeler.single));
    }
    final ilk = ilkSekme != null && sekmeler.contains(ilkSekme)
        ? sekmeler.indexOf(ilkSekme!)
        : 0;
    return DefaultTabController(
      length: sekmeler.length,
      initialIndex: ilk,
      child: Scaffold(
        appBar: AppBar(
          title: baslik,
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final s in sekmeler)
                Tab(key: Key('kisiler-sekme-${s.name}'), text: sekmeAdi(l10n, s)),
            ],
          ),
        ),
        body: TabBarView(children: [for (final s in sekmeler) _govde(s)]),
      ),
    );
  }
}
