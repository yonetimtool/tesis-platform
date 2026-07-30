import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/l10n.dart';

/// Geçici giriş kodu dialog'u — kod SelectableText + "Kopyala" (panoya) ile
/// gösterilir (iletme kolaylığı). Sakin/personel ekleme + parola sıfırlamada
/// ortak kullanılır. [message] koda dair açıklama satırıdır — ÇAĞIRAN taraf
/// yerelleştirir (metin bağlama göre değişir); dialog kendi metinlerini
/// `l10n`'dan alır.
Future<void> showTempCodeDialog(
  BuildContext context, {
  required String code,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      var copied = false;
      return StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(ctx.l10n.ortakGeciciKodBaslik),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                // `height: 2.2` KASITLIDIR (tur 79). `SelectableText` uzun
                // basmayla secilebilir, yani ANDROID icin bir dokunma
                // hedefidir; 22 punto tek satir 31 dp kutu veriyordu ve
                // `androidTapTargetGuideline` (48x48) burada dusuyordu.
                // Satir yuksekligi carpani kutuyu 48 dp'ye cikarir, yaziyi
                // dikeyde ortalar ve yazi olcegiyle birlikte buyur.
                child: SelectableText(
                  code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 2.2,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                setLocal(() => copied = true);
              },
              icon: Icon(copied ? Icons.check : Icons.copy, size: 18),
              label: Text(
                copied ? ctx.l10n.ortakKopyalandi : ctx.l10n.ortakKopyala,
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(ctx.l10n.ortakTamam),
            ),
          ],
        ),
      );
    },
  );
}
