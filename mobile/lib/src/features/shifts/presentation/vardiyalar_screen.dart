import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/text/tr_upper.dart';
import '../../auth/domain/user_role.dart';
import '../../profile/data/profile_api.dart';
import '../data/shifts_api.dart';
import '../domain/shift_models.dart';

/// Vardiyalar ekrani (WP-E) — tum vardiya tanimlari + atanan personel.
/// admin/yonetici her vardiyaya "Personel Ata" ile saha personeli atar
/// (tam-liste degistirme); diger roller salt-okur. Hata ekrani DUSURMEZ.
class VardiyalarScreen extends ConsumerWidget {
  const VardiyalarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftsAsync = ref.watch(shiftsProvider);
    final rol = UserRole.fromClaim(ref.watch(profileProvider).value?.role ?? '');
    final atayabilir =
        rol == UserRole.admin || rol == UserRole.yonetici;

    return Scaffold(
      appBar: AppBar(title: Text(trUpper('Vardiyalar'))),
      body: shiftsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e is ApiException ? e.message : 'Vardiyalar yüklenemedi.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (vardiyalar) {
          if (vardiyalar.isEmpty) {
            return const Center(child: Text('Vardiya tanımı yok'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: vardiyalar.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final v = vardiyalar[i];
              final personelAdlari = v.personel.map((p) => p.ad).join(', ');
              return Card(
                child: ListTile(
                  title: Text(v.ad),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${v.baslangicSaat} - ${v.bitisSaat}'
                          ' • ${gunTipiLabel(v.gunTipi)}'),
                      if (v.personel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            personelAdlari,
                            style: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                  isThreeLine: v.personel.isNotEmpty,
                  trailing: atayabilir
                      ? TextButton(
                          onPressed: () => _atamaSheet(context, ref, v),
                          child: const Text('Personel Ata'),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _atamaSheet(BuildContext context, WidgetRef ref, Shift vardiya) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AtamaSheet(vardiya: vardiya),
    );
  }
}

class _AtamaSheet extends ConsumerStatefulWidget {
  const _AtamaSheet({required this.vardiya});

  final Shift vardiya;

  @override
  ConsumerState<_AtamaSheet> createState() => _AtamaSheetState();
}

class _AtamaSheetState extends ConsumerState<_AtamaSheet> {
  late final Set<String> _secili = {
    for (final p in widget.vardiya.personel) p.userId,
  };
  bool _kaydediyor = false;

  Future<void> _kaydet() async {
    if (_kaydediyor) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _kaydediyor = true);
    try {
      await ref
          .read(shiftsApiProvider)
          .updateAssignments(widget.vardiya.id, _secili.toList());
      ref.invalidate(shiftsProvider);
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Vardiya personeli güncellendi ✓')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _kaydediyor = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final personelAsync = ref.watch(atanabilirPersonelProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${widget.vardiya.ad} — Personel',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ],
              ),
            ),
            Flexible(
              child: personelAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                      e is ApiException ? e.message : 'Personel yüklenemedi.'),
                ),
                data: (personel) {
                  if (personel.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Atanabilir personel yok'),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in personel)
                        CheckboxListTile(
                          value: _secili.contains(p.userId),
                          title: Text(p.ad),
                          onChanged: _kaydediyor
                              ? null
                              : (v) => setState(() {
                                    if (v == true) {
                                      _secili.add(p.userId);
                                    } else {
                                      _secili.remove(p.userId);
                                    }
                                  }),
                        ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _kaydediyor ? null : _kaydet,
                style:
                    FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: _kaydediyor
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
