/// (P253 Asama 2) TAHAKKUK AYRINTISI + TERS KAYIT.
///
/// Ters kayit §C kuralina tabidir: onay diyalogu HEDEF (daire · kisi ·
/// tur · donem) ve TUTARI yazar, SEBEP ZORUNLU (en az 3 karakter; sunucu
/// da 422 `sebep_zorunlu` verir), geri alinamazligi ONCEDEN soyler.
/// Kayit silinmez; deftere ters bir satir eklenir (web ile ayni).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/finans_onay.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../data/borclandirma_api.dart';
import '../domain/borclandirma_models.dart';
import 'borc_etiketleri.dart';

/// Tahakkukun hedef metni: "A-12 · Ahmet YILMAZ · Eylul aidati · Donem 2026-09".
String tahakkukHedefi(AppLocalizations l10n, Tahakkuk t, String? daireNo) => hedefMetni([
      daireNo,
      t.hedefAd,
      t.tanimAd ?? kalemTipiAdi(l10n, t.kalemTipi),
      l10n.brcDonem(t.donem),
    ]);

/// Ters kayit yap; yapildiysa `true`.
Future<bool> tahakkukTersKayit(
  BuildContext context,
  WidgetRef ref,
  Tahakkuk t, {
  String? daireNo,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final sebep = await finansOnayla(
    context,
    baslik: l10n.brcTersKayit,
    hedef: tahakkukHedefi(l10n, t, daireNo),
    tutar: tlTutar(t.tutarKurus),
    sonuc: l10n.brcTersKayitSonuc,
    onayMetni: l10n.brcTersKayit,
    sebepZorunlu: true,
    tehlikeli: true,
  );
  if (sebep == null) return false;
  try {
    await ref.read(borclandirmaApiProvider).tersKayit(t.id, sebep);
    messenger.showSnackBar(SnackBar(content: Text(l10n.brcTersKayitYapildi)));
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(e.message.isNotEmpty ? e.message : l10n.ortakBeklenmeyenHata)),
    );
    return false;
  }
}

/// Ayrinti penceresi; bir degisiklik yapildiysa `true`.
Future<bool?> tahakkukAyrintisi(BuildContext context, Tahakkuk t, {String? daireNo}) =>
    merkezSayfaAc<bool>(context, builder: (_) => _Ayrinti(t: t, daireNo: daireNo));

class _Ayrinti extends ConsumerWidget {
  const _Ayrinti({required this.t, this.daireNo});

  final Tahakkuk t;
  final String? daireNo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ikincil = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget satir(String etiket, String deger) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(etiket, style: TextStyle(color: ikincil))),
              const SizedBox(width: 8),
              Flexible(child: Text(deger, textAlign: TextAlign.end)),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(hedefMetni([daireNo, t.hedefAd]), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(tlTutar(t.tutarKurus), style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          satir(l10n.brcTur, t.tanimAd ?? kalemTipiAdi(l10n, t.kalemTipi)),
          satir(l10n.brcDonemEtiket, t.donem),
          if (t.sonOdeme != null) satir(l10n.brcSonOdemeEtiket, tarihBicimi(t.sonOdeme!, context.dilKodu)),
          if (t.gecikmeKurus > 0) satir(l10n.brcGecikme, tlTutar(t.gecikmeKurus)),
          if ((t.aciklama ?? '').isNotEmpty) satir(l10n.brcAciklama, t.aciklama!),
          if (t.tersKayitId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Chip(key: const Key('brc-duzeltme'), label: Text(l10n.brcDuzeltme)),
            ),
          if (t.iptalEdildi)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Chip(key: const Key('brc-duzeltildi'), label: Text(l10n.brcDuzeltildi)),
            ),
          if (t.tersKayitlanabilir) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('brc-ters-kayit'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.undo),
              label: Text(l10n.brcTersKayit),
              onPressed: () async {
                final oldu = await tahakkukTersKayit(context, ref, t, daireNo: daireNo);
                if (oldu && context.mounted) Navigator.of(context).pop(true);
              },
            ),
          ],
        ],
      ),
    );
  }
}
