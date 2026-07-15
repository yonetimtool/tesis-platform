import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Geçici giriş kodu dialog'u — kod SelectableText + "Kopyala" (panoya) ile
/// gösterilir (iletme kolaylığı). Sakin/personel ekleme + parola sıfırlamada
/// ortak kullanılır. [message] koda dair açıklama satırıdır.
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
          title: const Text('Geçici giriş kodu'),
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
                child: SelectableText(
                  code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
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
              label: Text(copied ? 'Kopyalandı' : 'Kopyala'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    },
  );
}
