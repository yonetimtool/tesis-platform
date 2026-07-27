import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../patrol/presentation/patrol_history_view.dart'
    show PatrolErrorBanner;
// NOT: `dues` modulu tur 10'un KAPSAMINDA DEGIL; asagidaki tutar cagrilari
// tur 10'un ZORUNLU uyarlamasidir — para gruplamasinin ucuncu uygulamasi
// (`report_models.kurusToTl`) kaldirilip tek kaynaga (`tlSonEkli`) gecildi.
import '../domain/dues_models.dart';
import 'aidat_etiket.dart';
import 'my_dues_controller.dart';

/// "Aidatim" — sakinin KENDI dairelerinin borc durumu (salt okuma).
/// Odeme bu ekrandan YAPILAMAZ: odeme durumu yalnizca odeme saglayicisi
/// webhook'uyla degisir (auth.md §4) — ekran yonetime odenen tutarlari ve
/// tahakkuklari seffaf gosterir.
class MyDuesScreen extends ConsumerWidget {
  const MyDuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myDuesControllerProvider);
    final controller = ref.read(myDuesControllerProvider.notifier);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.aidatBaslik, context.dilKodu)),
        actions: [
          IconButton(
            tooltip: l10n.ortakYenile,
            icon: const Icon(Icons.refresh),
            onPressed: state.loading ? null : controller.refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: _Body(state: state, controller: controller),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.controller});

  final MyDuesState state;
  final MyDuesController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hata = akisHatasiCoz(l10n, state.hataKimligi, state.errorMessage);
    if (state.loading && state.units.isEmpty && hata == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (hata != null)
          PatrolErrorBanner(
            message: state.forbidden ? l10n.aidatYetkiYok : hata,
            onRetry: state.forbidden ? null : controller.refresh,
          ),
        if (state.units.isEmpty && hata == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.aidatDaireYok,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (state.units.length > 1) ...[
          _ToplamBakiyeCard(bakiyeKurus: state.toplamBakiyeKurus),
          const SizedBox(height: 12),
        ],
        for (final unit in state.units) _UnitCard(unit: unit),
      ],
    );
  }
}

class _ToplamBakiyeCard extends StatelessWidget {
  const _ToplamBakiyeCard({required this.bakiyeKurus});

  final int bakiyeKurus;

  @override
  Widget build(BuildContext context) {
    final borc = bakiyeKurus > 0;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          borc ? Icons.account_balance_wallet_outlined : Icons.check_circle,
          color: borc ? Colors.red : Colors.green,
        ),
        title: Text(context.l10n.aidatToplamBakiye),
        trailing: Text(
          tlSonEkli(bakiyeKurus, context.dilKodu),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: borc ? Colors.red : Colors.green,
          ),
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.unit});

  final MyDuesUnit unit;

  @override
  Widget build(BuildContext context) {
    final borc = unit.borcVar;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.home_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    // 'Daire {no}' TR sabitti ve diyakritigi olmadigi icin §15
                    // grep'ine GORUNMUYORDU (kayitli kor nokta).
                    context.l10n.gorevDaireEtiket(unit.no),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Cip de kucultulebilir: uzun ceviriler ("Offener Betrag")
                // dar ekranda satiri tasiriyordu.
                Flexible(
                  child: Chip(
                    label: Text(
                      borc
                          ? context.l10n.aidatBorcVar
                          : context.l10n.aidatBorcYok,
                      overflow: TextOverflow.ellipsis,
                    ),
                    labelStyle:
                        TextStyle(color: borc ? Colors.red : Colors.green),
                    backgroundColor: (borc ? Colors.red : Colors.green)
                        .withValues(alpha: 0.12),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _row(context.l10n.aidatToplamTahakkuk,
                tlSonEkli(unit.tahakkukKurus, context.dilKodu)),
            _row(context.l10n.aidatToplamOdenen,
                tlSonEkli(unit.odenenKurus, context.dilKodu),
                valueColor: Colors.green),
            _row(context.l10n.aidatBakiye,
                tlSonEkli(unit.bakiyeKurus, context.dilKodu),
                valueColor: borc ? Colors.red : Colors.green, bold: true),
            // Hesap seffaf: bakiye nasil bulundu tek satirda gorunur.
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                context.l10n.aidatHesapSatiri(
                  tlSonEkli(unit.tahakkukKurus, context.dilKodu),
                  tlSonEkli(unit.odenenKurus, context.dilKodu),
                  tlSonEkli(unit.bakiyeKurus, context.dilKodu),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (unit.assessments.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  context.l10n.aidatTahakkuklar(unit.assessments.length),
                  style: const TextStyle(fontSize: 14),
                ),
                children: [
                  for (final a in unit.assessments)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text('${a.donem}'
                          '${a.aciklama == null ? '' : ' — ${a.aciklama}'}'),
                      subtitle: a.sonOdemeTarihi == null
                          ? null
                          : Text(context.l10n.aidatSonOdeme(
                              tarihBicimi(a.sonOdemeTarihi!, context.dilKodu),
                            )),
                      trailing: Text(
                        tlSonEkli(a.tutarKurus, context.dilKodu),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ],
            if (unit.payments.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  context.l10n.aidatOdemeler(unit.payments.length),
                  style: const TextStyle(fontSize: 14),
                ),
                children: [
                  for (final p in unit.payments) _PaymentTile(payment: p),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              context.l10n.aidatOdemeDurumuNotu,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value,
      {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Etiket kucultulebilir; DEGER kirpilmaz, gerekirse kuculur
          // (tur 6/9/10 emsali).
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});

  final DuesPayment payment;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final l10n = context.l10n;
    final (color, icon) = switch (p.durum) {
      'basarili' => (Colors.green, Icons.check_circle_outline),
      'bekliyor' => (Colors.orange, Icons.hourglass_top),
      'iptal' => (Colors.red, Icons.cancel_outlined),
      _ => (Colors.grey, Icons.help_outline),
    };
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        '${tarihBicimi(p.odemeZamani, context.dilKodu)} '
        '${saatBicimi(p.odemeZamani, context.dilKodu)} · '
        '${odemeYontemiAdi(l10n, p.yontem)}'
        '${p.donem == null ? '' : ' · ${p.donem}'}',
      ),
      subtitle: p.makbuzNo == null
          ? null
          : Text(l10n.aidatMakbuz(p.makbuzNo!)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            tlSonEkli(p.tutarKurus, context.dilKodu),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(odemeDurumuAdi(l10n, p.durum),
              style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
