import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../core/ozellikler/ozellik_bayraklari.dart';

/// (P221) DUKKAN KAPISI — bayrak kapaliyken "yakinda" ekrani.
///
/// ===========================================================================
/// SEKME YAYINDA, ICERIK HENUZ DEGIL
/// ===========================================================================
/// Sekme bu surumde MAGAZAYA cikiyor ki hazir oldugunda EKSTRA BIR
/// MAGAZA TURU gerekmesin. Ama bos bir pazar yeri gostermek kotu
/// izlenim birakir — o yuzden icerik yerine kisa bir "yakinda" ekrani
/// duruyor.
///
/// ===========================================================================
/// TARIH TAAHHUDU YOK
/// ===========================================================================
/// Metin ne zaman gelecegine dair SOZ VERMIYOR. Verilen bir tarih
/// tutmadiginda, ozelligin kendisinden daha buyuk bir guven sorunu
/// yaratir.
///
/// ===========================================================================
/// TUM DUKKAN ROTALARI BURADAN GECER
/// ===========================================================================
/// Yalniz giris ekranini sarmak YETMEZ: bildirime dokunma, derin
/// baglanti ve panel/taleplerim rotalari kapiyi ATLAYABILIRDI. Her
/// Dukkan rotasi bu sarmalayiciyi kullaniyor ve kilit
/// (`p221_dukkan_kapisi_test.dart`) bunu tariyor.
class DukkanKapisi extends ConsumerWidget {
  const DukkanKapisi({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // KAPALI VARSAYILAN: yukleme ve hata dallarinda da `false` doner
    // (bkz. `dukkanAcikProvider`).
    if (ref.watch(dukkanAcikProvider)) return child;
    return const _YakindaEkrani();
  }
}

class _YakindaEkrani extends StatelessWidget {
  const _YakindaEkrani();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.dukkanBaslik)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.storefront_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                t.dukkanYakindaBaslik,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                t.dukkanYakindaMetin,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
