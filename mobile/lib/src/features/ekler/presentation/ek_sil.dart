import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../auth/domain/user_role.dart';
import '../data/ek_api.dart';

/// (P253 Asama 1) Eki silebilen roller — eylem tablosundaki
/// `DELETE /ekler/{ek_id}` satirinin `roller` sutunu. Karar sunucuda
/// (sahip ya da ust kayda yazan); bu kume yalniz dugmenin cizilip
/// cizilmeyecegini belirler.
bool ekSilebilir(UserRole? rol) =>
    rol == UserRole.admin || rol == UserRole.yonetici || rol == UserRole.guvenlikAmiri;

/// Onay diyalogu (ekin ADI yazili) -> `DELETE /ekler/{id}`. Silindiyse true.
/// Hata SnackBar'a yazilir; sessiz basarisizlik yok.
Future<bool> ekSilOnayli(
  BuildContext context,
  WidgetRef ref, {
  required String ekId,
  required String ad,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final onay = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(l10n.kisEkSilBaslik),
      content: Text(l10n.kisEkSilOnay(ad)),
      actions: [
        TextButton(onPressed: () => Navigator.of(d).pop(false), child: Text(l10n.ortakVazgec)),
        FilledButton(
          key: const Key('ek-sil-onay'),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(d).colorScheme.error),
          onPressed: () => Navigator.of(d).pop(true),
          child: Text(l10n.ortakSil),
        ),
      ],
    ),
  );
  if (onay != true) return false;
  try {
    await ref.read(ekApiProvider).sil(ekId);
    messenger.showSnackBar(SnackBar(content: Text(l10n.kisEkSilindi)));
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    return false;
  }
}
