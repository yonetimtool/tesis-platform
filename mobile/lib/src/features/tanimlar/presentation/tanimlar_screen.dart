import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/l10n.dart';
import '../../../routing/app_router.dart';

/// (P251 §8) TANIMLAR MERKEZI — web'deki tek "Tanimlar" girisinin ikizi.
///
/// Web'de Tanimlar tek giris ve defterler sayfanin SEKMELERI (P251 §7).
/// Mobilde Daire tipleri ve Gorev kategorileri iki ayri menu satiriydi;
/// artik bu ekranin girisleri. Muhasebe defterleri (kasa, gelir/gider,
/// firma, sayac, arac) mobilde YOK — gerekce `contracts/menu-paritesi.tsv`;
/// ekran bunu sakli birakmaz, notla soyler.
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
          ListTile(
            key: const Key('tanimlar-webde'),
            leading: const Icon(Icons.desktop_windows_outlined),
            title: Text(l10n.tanimlarWebNotu),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.bilgisayardan),
          ),
        ],
      ),
    );
  }
}
