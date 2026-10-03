import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/l10n.dart';
import '../../../routing/app_router.dart';
import '../domain/defter_tanimi.dart';

const _ikonlar = <String, IconData>{
  'kasalar': Icons.account_balance_wallet_outlined,
  'gelir-gider-gruplari': Icons.folder_outlined,
  'gelir-gider-tanimlari': Icons.receipt_long_outlined,
  'firmalar': Icons.store_outlined,
  'arac-kayitlari': Icons.directions_car_outlined,
  'sayaclar-ana': Icons.speed_outlined,
  'sayaclar-bolum': Icons.water_drop_outlined,
};

/// (P251 §8) TANIMLAR MERKEZI — web'deki tek "Tanimlar" girisinin ikizi.
///
/// Web'de Tanimlar tek giris ve defterler sayfanin SEKMELERI (P251 §7).
/// Mobilde Daire tipleri ve Gorev kategorileri iki ayri menu satiriydi;
/// artik bu ekranin girisleri. (P253 Asama 2) Muhasebe defterleri (kasa,
/// gelir/gider, firma, sayac, arac) ve muhasebe ayarlari da burada — tek
/// genel defter ekrani (`genel_defter_screen.dart`).
class TanimlarScreen extends StatelessWidget {
  const TanimlarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(baslikBuyuk(l10n.modulTanimlar, context.dilKodu))),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            key: const Key('tanimlar-daire-tipleri'),
            leading: const Icon(Icons.home_work_outlined),
            title: Text(l10n.modulDaireTanimlari),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.daireTanimlari),
          ),
          ListTile(
            key: const Key('tanimlar-gorev-kategorileri'),
            leading: const Icon(Icons.category_outlined),
            title: Text(l10n.kurulumGorevAlani),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.taskCategories),
          ),
          const Divider(),
          // (P253 Asama 2) Muhasebe defterleri artik mobilde de: TEK
          // genel defter ekrani, web `?defter=` adlariyla.
          for (final d in defterler)
            ListTile(
              key: Key('tanimlar-defter-${d.kimlik}'),
              leading: Icon(_ikonlar[d.kimlik] ?? Icons.list_alt_outlined),
              title: Text(d.baslik(l10n)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('${AppRoutes.genelDefter}?defter=${d.kimlik}'),
            ),
          ListTile(
            key: const Key('tanimlar-muhasebe-ayarlari'),
            leading: const Icon(Icons.tune_outlined),
            title: Text(l10n.tnmAyarlar),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.muhasebeAyarlari),
          ),
        ],
      ),
    );
  }
}
