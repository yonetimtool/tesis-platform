import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../data/alarm_kanali.dart';

/// (P249 §1c) SOS ALARM AYARLARI — telefonun alarmi GERCEKTEN calabilmesi
/// icin gereken izinler ve durumlari.
///
/// NEDEN AYRI KART: bu izinlerin hicbirini uygulama kendisi veremez
/// (Android 14 tam ekran, Rahatsiz Etmeyin erisimi, iOS kritik uyari);
/// kullanici sistem ayarinda acar. Durumu gostermeden "sessizde de calar"
/// demek, calmayan bir soz vermek olurdu. Her satir durumu ACIKCA yazar
/// ve kapaliysa ilgili sistem ekranina goturur.
final alarmIzinProvider = FutureProvider.autoDispose<AlarmIzinDurumu?>(
  (ref) => ref.watch(alarmKanaliProvider).izinDurumu(),
);

class SosAlarmAyarKarti extends ConsumerWidget {
  const SosAlarmAyarKarti({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final durum = ref.watch(alarmIzinProvider).value;
    // Kopru yoksa (test, masaustu) kart CIZILMEZ: bilinmeyen bir durumu
    // "kapali" diye gostermek yanlis alarm olurdu.
    if (durum == null) return const SizedBox.shrink();
    final kanal = ref.read(alarmKanaliProvider);

    Widget satir(String anahtar, String baslik, bool? acik, {VoidCallback? ac, String? not}) {
      if (acik == null) return const SizedBox.shrink();
      return ListTile(
        key: Key('sos-ayar-$anahtar'),
        leading: Icon(
          acik ? Icons.check_circle : Icons.error_outline,
          color: acik
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
        ),
        title: Text(baslik),
        subtitle: Text([
          acik ? l10n.panikAyarAcik : l10n.panikAyarKapali,
          ?not,
        ].join('\n')),
        trailing: (!acik && ac != null)
            ? TextButton(onPressed: ac, child: Text(l10n.panikAyarAc))
            : null,
      );
    }

    return Card(
      key: const Key('sos-alarm-ayar'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(l10n.panikAlarmAyarBaslik),
              subtitle: Text(l10n.panikAlarmAyarAciklama),
            ),
            satir('bildirim', l10n.panikAyarBildirim, durum.bildirimAcik),
            if (durum.android) ...[
              satir('kanal', l10n.panikAyarKanal, durum.kanalAcik,
                  ac: kanal.kanalAyari),
              if (durum.tamEkranSorulur)
                satir('tam-ekran', l10n.panikAyarTamEkran, durum.tamEkran,
                    ac: kanal.tamEkranAyari),
              satir('dnd', l10n.panikAyarDnd, durum.dndErisimi,
                  ac: kanal.dndAyari),
            ] else ...[
              satir('zaman-hassas', l10n.panikAyarZamanHassas, durum.zamanHassas),
              // KRITIK UYARI KAPALIYKEN SOZ VERILMEZ: "sessizde calmaz"
              // acikca yazilir.
              satir('kritik', l10n.panikAyarKritik, durum.kritikUyari,
                  not: (durum.kritikUyari ?? false)
                      ? null
                      : l10n.panikAyarKritikBekliyor),
            ],
          ],
        ),
      ),
    );
  }
}
