import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../data/panik_api.dart';
import 'panik_gozcusu.dart';

/// (P249 §1b) BILDIRIMDEN ACILAN ALARM EKRANI — `/panik-alarm/:id`.
///
/// OLCULEN KUSUR: panik push'una dokunus TAKIP LISTESINE gidiyordu. Sakin
/// o listede yalniz KENDI actigi alarmlari gorur; deprem alarmina dokunan
/// sakin BOS bir liste goruyordu. Simdi dokunus o alarmin kendisini acar:
/// alici govdesi (baslik + talimat + karar dugmeleri) ve — yonetim ve
/// guvenlik icin — daire bazinda durum.
class PanikAlarmEkrani extends ConsumerWidget {
  const PanikAlarmEkrani({super.key, required this.alarmId});

  final String alarmId;

  /// Durumu gorebilen roller — sunucu `panik.LISTE_ROLLERI` ile AYNI.
  static const durumRolleri = {
    UserRole.security,
    UserRole.guvenlikAmiri,
    UserRole.yonetici,
    UserRole.admin,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final alarm = ref.watch(panikDetayProvider(alarmId));
    final rol = ref.watch(currentUserRoleProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.panikDetayBaslik)),
      body: alarm.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (a) {
          void yenile() {
            ref.invalidate(panikDetayProvider(alarmId));
            ref.invalidate(panikDurumProvider(alarmId));
            ref.invalidate(panikAktifProvider);
          }

          return RefreshIndicator(
            onRefresh: () async => yenile(),
            child: ListView(
              children: [
                PanikAlarmIcerigi(
                  alarm: a,
                  onKarar: yenile,
                  eylemler: a.acik,
                ),
                if (a.toplu && durumRolleri.contains(rol))
                  PanikDurumPaneli(alarmId: alarmId),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// (P249 §1b) DAIRE BAZINDA DURUM — kim guvende, kim yardim istiyor,
/// kim yanit vermedi. Sunucu siralar: once `yardim`, sonra `yanitsiz`.
class PanikDurumPaneli extends ConsumerWidget {
  const PanikDurumPaneli({super.key, required this.alarmId});

  final String alarmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tema = Theme.of(context);
    return ref.watch(panikDurumProvider(alarmId)).when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('$e'),
          ),
          data: (d) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              key: const Key('panik-durum'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.panikDurumBaslik, style: tema.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  l10n.panikDurumSayilar(d.alici, d.guvende, d.yardim, d.yanitsiz),
                  key: const Key('panik-durum-sayilar'),
                ),
                if (d.ortalamaYanitSn != null)
                  Text(l10n.panikOrtalamaYanit(d.ortalamaYanitSn!)),
                const SizedBox(height: 12),
                for (final daire in d.daireler)
                  Card(
                    key: Key('panik-durum-daire-${daire.ad}'),
                    child: ListTile(
                      leading: _durumIkonu(context, daire.durum),
                      title: Text(daire.ad),
                      subtitle: Text(
                        daire.kisiler
                            .map((k) => '${k.ad} — ${_yanitAdi(context, k.yanit)}')
                            .join('\n'),
                      ),
                    ),
                  ),
                if (d.personel.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(l10n.panikDurumPersonel, style: tema.textTheme.titleMedium),
                  for (final k in d.personel)
                    ListTile(
                      dense: true,
                      leading: _durumIkonu(context, k.yanit ?? 'yanitsiz'),
                      title: Text(k.ad),
                      subtitle: Text(_yanitAdi(context, k.yanit)),
                    ),
                ],
              ],
            ),
          ),
        );
  }

  static String _yanitAdi(BuildContext context, String? yanit) {
    final l10n = context.l10n;
    return switch (yanit) {
      'guvende' => l10n.panikDurumGuvende,
      'yardim' => l10n.panikDurumYardim,
      _ => l10n.panikDurumYanitsiz,
    };
  }

  static Widget _durumIkonu(BuildContext context, String durum) {
    final cs = Theme.of(context).colorScheme;
    return switch (durum) {
      'yardim' => Icon(Icons.sos, color: cs.error),
      'guvende' => Icon(Icons.check_circle, color: cs.primary),
      _ => Icon(Icons.help_outline, color: cs.onSurfaceVariant),
    };
  }
}
