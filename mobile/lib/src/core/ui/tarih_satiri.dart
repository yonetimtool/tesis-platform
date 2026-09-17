import 'package:flutter/material.dart';

import '../i18n/l10n.dart';

/// (P239 §4) TARIH SECIM SATIRI — ORTAK BILESEN.
///
/// =========================================================================
/// NEDEN TASINDI
/// =========================================================================
/// Bu satir P237'de anket formunun ICINDE ozel (private) bir widget olarak
/// yazilmisti. Ikinci tuketici cikinca (gorev SON TARIHI) iki secenek
/// vardi: kopyalamak ya da tasimak. Kopya, iki tarih secicinin zamanla
/// AYRISMASI demekti — birinde "temizle" olur, otekinde olmaz.
///
/// =========================================================================
/// GUN TEK BASINA YETMEZ
/// =========================================================================
/// [tarihSaatSec] once gun, sonra SAAT sorar. "12 Ekim'de bitsin" diyen
/// kullanici gun ICINDE bir an kastediyor; gunun 00:00'ini almak o anı
/// bir gun ONE ceker ve is daha baslamadan "gecikti" olur.
///
/// =========================================================================
/// TEMIZLE DUGMESI YALNIZ DEGER VARKEN
/// =========================================================================
/// Bos bir alanin yaninda "temizle" gostermek, kullaniciya yapacak bir
/// sey OLMAYAN bir dugme sunmaktir.
Future<DateTime?> tarihSaatSec(
  BuildContext context,
  DateTime? mevcut, {
  DateTime? enErken,
  DateTime? enGec,
}) async {
  final simdi = DateTime.now();
  final gun = await showDatePicker(
    context: context,
    initialDate: mevcut ?? simdi,
    firstDate: enErken ?? simdi.subtract(const Duration(days: 1)),
    lastDate: enGec ?? simdi.add(const Duration(days: 365)),
  );
  if (gun == null || !context.mounted) return null;
  final saat = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(mevcut ?? simdi),
  );
  if (saat == null) return null;
  return DateTime(gun.year, gun.month, gun.day, saat.hour, saat.minute);
}

class TarihSatiri extends StatelessWidget {
  const TarihSatiri({
    super.key,
    required this.anahtar,
    required this.etiket,
    required this.deger,
    required this.onSec,
    required this.onTemizle,
  });

  /// Widget anahtarinin TABANI: satir `anahtar`, temizle dugmesi
  /// `anahtar-temizle` olur (testler bunlari kullanir).
  final String anahtar;
  final String etiket;
  final DateTime? deger;
  final Future<void> Function() onSec;
  final VoidCallback onTemizle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: TextButton.icon(
            key: Key(anahtar),
            icon: const Icon(Icons.event_outlined),
            label: Text(
              deger == null
                  ? '$etiket — ${l10n.ortakTarihSec}'
                  : '$etiket: ${tarihSaatBicimi(deger!, context.dilKodu)}',
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: () => onSec(),
          ),
        ),
        if (deger != null)
          IconButton(
            key: Key('$anahtar-temizle'),
            icon: const Icon(Icons.close),
            tooltip: l10n.ortakTarihTemizle,
            onPressed: onTemizle,
          ),
      ],
    );
  }
}
