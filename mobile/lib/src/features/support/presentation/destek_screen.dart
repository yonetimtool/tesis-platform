import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/support_api.dart';
import '../domain/support_models.dart';

const _green = Color(0xFF16A34A);
const _amber = Color(0xFFD97706);

/// Destek (WP1) — yonetici -> Yonetio ekibi: taleplerim listesi (durum cipi +
/// admin cevabi) + "Yeni Talep" formu (konu + aciklama). Erisim: FAB
/// olusturma menusu (WP2.4).
class DestekScreen extends ConsumerWidget {
  const DestekScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myTicketsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Destek')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _yeniTalep(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Yeni Talep'),
      ),
      body: async.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('Henüz destek talebiniz yok'))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(myTicketsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _TicketCard(bilet: items[i]),
                ),
              ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child:
                Text('Talepler yüklenemedi.\n$e', textAlign: TextAlign.center),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _yeniTalep(BuildContext context, WidgetRef ref) async {
    final konuCtrl = TextEditingController();
    final aciklamaCtrl = TextEditingController();
    final gonderildi = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 4,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Yeni Destek Talebi',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: konuCtrl,
              decoration: const InputDecoration(
                  labelText: 'Konu', border: OutlineInputBorder()),
              maxLength: 200,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: aciklamaCtrl,
              decoration: const InputDecoration(
                  labelText: 'Açıklama', border: OutlineInputBorder()),
              maxLines: 4,
              maxLength: 4000,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                if (konuCtrl.text.trim().isEmpty ||
                    aciklamaCtrl.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Gönder'),
            ),
          ],
        ),
      ),
    );
    if (gonderildi != true) return;
    try {
      await ref.read(supportApiProvider).create(
          konu: konuCtrl.text.trim(), aciklama: aciklamaCtrl.text.trim());
      ref.invalidate(myTicketsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Talep gönderilemedi: $e')));
      }
    }
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.bilet});

  final SupportTicket bilet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cozuldu = bilet.durum == 'cozuldu';
    final renk = cozuldu ? _green : _amber;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(bilet.konu,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: renk.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(cozuldu ? 'Çözüldü' : 'Açık',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: renk, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(bilet.aciklama,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor)),
            if (bilet.adminCevap != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Yönetio Ekibi',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: _green, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(bilet.adminCevap!,
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
