import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../data/kvkk_api.dart';

/// Aydinlatma metni SALT-OKUMA (P36).
///
/// Onay ekranindan AYRI: kullanici NEYI onayladigini sonradan gorebilmelidir.
/// Onayi bir kez alip metni saklamak, aydinlatmanin amacini bosa cikarirdi.
/// Burada kaydirma kilidi ve onay butonu YOKTUR — onay zaten verilmistir.
class KvkkMetinScreen extends ConsumerWidget {
  const KvkkMetinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.kvkkBaslik)),
      body: ref.watch(kvkkMetinProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.kvkkYuklenemedi, textAlign: TextAlign.center),
              ),
            ),
            data: (metin) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(metin.baslik,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  // Tenant icerigi: ORIJINAL dilinde gosterilir (hukuki
                  // metnin makine cevirisi yanlis bir taahhut uretirdi).
                  Text(metin.govde,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
    );
  }
}
