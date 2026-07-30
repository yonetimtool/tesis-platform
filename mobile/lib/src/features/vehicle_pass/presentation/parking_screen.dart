import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/theme/home_tokens.dart';
import '../../../routing/app_router.dart';
import '../../auth/data/current_user_provider.dart';
import 'vehicle_pass_controller.dart';

/// "Otopark" (G4) — AGREGAT doluluk; TUM kimlikli roller.
///
/// Ana ekrandaki "Otopark Kullanımı" karti + "Hızlı Özet" Otopark kutusu
/// buraya gelir. Plaka/daire ICERMEZ, bu yuzden yonetici ve sakine de
/// aciktir; gecis LISTESINE gecis yalniz yetkili rolde gorunur.
///
/// KAPASITE TANIMSIZSA UYDURMA YUZDE URETILMEZ: sunucu `oran: null` doner,
/// ekran yalniz gercek arac sayisini ve aciklayici bir not gosterir.
class ParkingScreen extends ConsumerWidget {
  const ParkingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final doluluk = ref.watch(otoparkDolulukProvider);
    final rol = ref.watch(currentUserRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.modulOtopark, context.dilKodu)),
        actions: [
          IconButton(
            tooltip: l10n.ortakYenile,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(otoparkDolulukProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(otoparkDolulukProvider),
        child: doluluk.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                e is ApiException
                    ? apiHataMetni(l10n, e)
                    : l10n.ortakBeklenmeyenHata,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
          data: (d) {
            final kapasiteVar = d.kapasite != null && d.kapasite! > 0;
            final bos = kapasiteVar ? (d.kapasite! - d.dolu) : null;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.local_parking,
                          size: 40,
                          color: okunurVurgu(context, Colors.blue),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          kapasiteVar
                              ? l10n.otoparkDoluKapasite(
                                  '${d.dolu}',
                                  '${d.kapasite}',
                                )
                              : l10n.sayacArac(d.dolu),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (d.oran != null) ...[
                          const SizedBox(height: 12),
                          // Oran SUNUCUDAN gelir; istemci hesaplamaz
                          // (kapasite null iken bolme yapilmaz).
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: d.oran! / 100,
                              minHeight: 10,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(l10n.yuzdeDeger('${d.oran}')),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Kutu(
                        etiket: l10n.otoparkDoluEtiket,
                        deger: '${d.dolu}',
                        renk: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Kutu(
                        etiket: kapasiteVar
                            ? l10n.otoparkBosEtiket
                            : l10n.otoparkKapasiteEtiket,
                        // Kapasite yoksa "—": uydurma sayi uretilmez.
                        deger: bos != null
                            ? '$bos'
                            : (d.kapasite != null ? '${d.kapasite}' : '—'),
                        renk: Colors.green,
                      ),
                    ),
                  ],
                ),
                if (!kapasiteVar) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.otoparkKapasiteTanimsiz,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                // Gecis listesi yalniz YETKILI role acilir (admin+security);
                // digerlerine dugme HIC gosterilmez (403 duvarina carpmasin).
                if (rol.asData?.value.canViewVehiclePasses ?? false) ...[
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.list_alt_outlined),
                    label: Text(l10n.otoparkAracListesi),
                    onPressed: () => context.push(AppRoutes.aracGecis),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Kutu extends StatelessWidget {
  const _Kutu({required this.etiket, required this.deger, required this.renk});

  final String etiket;
  final String deger;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    final vurgu = okunurVurgu(context, renk);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Text(
              deger,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: vurgu,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              etiket,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
