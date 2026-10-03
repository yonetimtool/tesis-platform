/// (P253 §B, plan §2.5) COKLU SECIM — uzun bas, sec, alt cubukta eylem.
///
/// Her listede AYNI kalip: bir satira UZUN BASINCA secim kipi acilir; ust
/// cubukta "3 secili · Tumunu sec", altta ise ozel eylemler (borclularda
/// hatirlat / faiz affi, vardiyada sil, onay bekleyenlerde onayla / reddet).
/// Geri tusu ya da "Secimi bitir" kipi kapatir.
///
/// DENETLEYICI AYRI: `ListeEkrani` kullanir, ama secimi kendi ekraninda
/// yoneten (bildirimler gibi) bir ekran da ayni denetleyiciyi ve cubugu
/// kullanabilir — iki ayri secim davranisi buyumesin.
library;

import 'package:flutter/material.dart';

import '../i18n/l10n.dart';

class CokluSecim<K> extends ChangeNotifier {
  final Set<K> _secili = <K>{};
  bool _acik = false;

  bool get acik => _acik;
  Set<K> get secili => Set.unmodifiable(_secili);
  int get sayi => _secili.length;
  bool seciliMi(K k) => _secili.contains(k);

  /// Uzun bas: kipi ac ve o satiri sec.
  void baslat(K k) {
    _acik = true;
    _secili.add(k);
    notifyListeners();
  }

  /// Kip aciksa dokunma secimi degistirir; son secim kalkinca kip KAPANIR
  /// (bos bir secim kipi, kullaniciya "neden eylemler kapali" sordurur).
  void degistir(K k) {
    if (!_secili.remove(k)) _secili.add(k);
    if (_secili.isEmpty) _acik = false;
    notifyListeners();
  }

  void tumunu(Iterable<K> hepsi) {
    _acik = true;
    _secili
      ..clear()
      ..addAll(hepsi);
    notifyListeners();
  }

  void bitir() {
    _acik = false;
    _secili.clear();
    notifyListeners();
  }
}

/// Secim kipinde listedeki bir toplu eylem.
class TopluEylem<T> {
  const TopluEylem({
    required this.etiket,
    required this.ikon,
    required this.calistir,
    this.tehlikeli = false,
  });

  final String Function(AppLocalizations l10n) etiket;
  final IconData ikon;

  /// Secili ogeler. Tamamlaninca secim kipi kapanir ve liste tazelenir.
  final Future<void> Function(BuildContext context, List<T> secili) calistir;
  final bool tehlikeli;
}

/// Ust cubuk: "N secili", "Tumunu sec", "Secimi bitir".
class CokluSecimUstCubugu extends StatelessWidget implements PreferredSizeWidget {
  const CokluSecimUstCubugu({
    super.key,
    required this.sayi,
    required this.onTumunu,
    required this.onBitir,
  });

  final int sayi;
  final VoidCallback onTumunu;
  final VoidCallback onBitir;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppBar(
      key: const Key('coklu-secim-ust'),
      leading: IconButton(
        tooltip: l10n.listeSecimiBitir,
        icon: const Icon(Icons.close),
        onPressed: onBitir,
      ),
      title: Text(l10n.listeSecili(sayi)),
      actions: [
        TextButton(
          key: const Key('coklu-secim-tumu'),
          onPressed: onTumunu,
          child: Text(l10n.listeTumunuSec),
        ),
      ],
    );
  }
}

/// Alt cubuk: secime uygulanacak eylemler.
class CokluSecimAltCubugu<T> extends StatelessWidget {
  const CokluSecimAltCubugu({
    super.key,
    required this.eylemler,
    required this.secili,
    required this.onBitti,
  });

  final List<TopluEylem<T>> eylemler;
  final List<T> secili;
  final VoidCallback onBitti;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final renk = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Material(
        key: const Key('coklu-secim-alt'),
        elevation: 8,
        color: renk.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              for (final e in eylemler)
                TextButton.icon(
                  onPressed: secili.isEmpty
                      ? null
                      : () async {
                          await e.calistir(context, secili);
                          onBitti();
                        },
                  style: e.tehlikeli
                      ? TextButton.styleFrom(foregroundColor: renk.error)
                      : null,
                  icon: Icon(e.ikon),
                  label: Text(e.etiket(l10n)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
