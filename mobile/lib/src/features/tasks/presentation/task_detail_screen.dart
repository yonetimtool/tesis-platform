import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/task_category_api.dart';
import '../domain/task_models.dart';
import 'gorev_hata_metni.dart';
import 'task_complete_controller.dart';
import 'task_form_sheet.dart';
import 'task_ticket_widgets.dart';
import 'task_tip_style.dart';
import 'tasks_controller.dart';

/// Gorev detayi + tamamlama akisi: NFC (gorevde etiket tanimliysa) → foto
/// kaniti (opsiyonel; cek → presign → PUT) → not → "Tamamla".
/// 201 "kaydedildi" / 200 "zaten kayitliydi" ayrimi sonuc kartinda gorunur.
class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final state = ref.watch(taskCompleteControllerProvider(task.id));
    final controller =
        ref.read(taskCompleteControllerProvider(task.id).notifier);
    // Gorev tipi = kategori adi (kategori_id -> ad, listeden cozulur); null = Diğer.
    final kategoriler = ref.watch(taskCategoriesProvider).value;
    final adlar = (kategoriler ?? const [])
        .where((k) => k.id == task.kategoriId)
        .map((k) => k.ad);
    final style = taskKategoriStyle(
        task.kategoriId == null || adlar.isEmpty ? null : adlar.first);
    // Tamamlama akisi yalniz saha rollerinde (auth.md §4: POST completion
    // admin/security/tesis_gorevlisi). Rol cozulene kadar (kisa storage
    // okumasi) akis gosterilir — backend yine de 403 ile korur.
    final role = ref.watch(currentUserRoleProvider).value;
    final canComplete = role == null || role.isFieldWorker;
    final canManage = role?.canManageTasks ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(task.ad, dil)),
        actions: [
          if (canManage)
            PopupMenuButton<String>(
              tooltip: l10n.gorevIslemleriTooltip,
              onSelected: (v) {
                if (v == 'edit') _edit(context, ref);
                if (v == 'delete') _delete(context, ref);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(l10n.ortakDuzenle)),
                PopupMenuItem(value: 'delete', child: Text(l10n.ortakSil)),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(task: task, style: style),
          // Bagli talep baglam karti (kategori + kisa aciklama + daire + durum).
          if (task.ticket != null) TicketBaglamKarti(ticket: task.ticket!),
          const SizedBox(height: 16),
          if (!canComplete)
            Card(
              child: ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: Text(l10n.gorevTakipGorunumu),
                subtitle: Text(l10n.gorevTakipGorunumuAlt),
              ),
            )
          else if (state.result != null)
            _ResultCard(state: state, onNew: controller.startNew)
          else ...[
            if (task.checkpointId != null) ...[
              _NfcStep(state: state, controller: controller),
              const SizedBox(height: 12),
            ],
            _PhotoStep(
              state: state,
              controller: controller,
              fotoZorunlu: task.fotoZorunlu,
            ),
            const SizedBox(height: 12),
            _NoteStep(controller: controller),
            const SizedBox(height: 16),
            if (gorevHatasiCoz(l10n, state.submitHata, state.submitError)
                case final hata?)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  hata,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            FilledButton.icon(
              onPressed: state.submitting || state.photoBusy
                  ? null
                  : () => controller.submit(fotoZorunlu: task.fotoZorunlu),
              icon: state.submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(
                  state.submitting ? l10n.gorevGonderiliyor : l10n.gorevTamamla),
            ),
          ],
        ],
      ),
    );
  }

  /// Duzenleme formu; kaydedilirse detay KAPANIR (elimizdeki [task] kopyasi
  /// bayatladi — guncel hali tazelenmis listededir).
  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showTaskFormSheet(context, edit: task);
    if (saved == true && context.mounted) {
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.gorevGuncellendi)),
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.gorevSilinsinMi),
        content: Text(task.ad),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.ortakVazgec),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.ortakSil),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(tasksControllerProvider.notifier).deleteTask(task.id);
      if (context.mounted) {
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.gorevSilindi)),
        );
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _InfoCard extends ConsumerWidget {
  const _InfoCard({required this.task, required this.style});

  final Task task;
  final ({Color color, IconData icon, String? ad}) style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final currentUserId =
        ref.watch(tasksControllerProvider.select((s) => s.currentUserId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(style.icon, color: style.color),
                const SizedBox(width: 8),
                Chip(
                  label: Text(style.ad ?? l10n.gorevKategoriDiger),
                  backgroundColor: style.color.withValues(alpha: 0.15),
                  labelStyle: TextStyle(color: style.color),
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                if (task.isAssignedTo(currentUserId))
                  Chip(
                    label: Text(l10n.gorevSanaAtanmis),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            // Talepten gelen is emri: "Talepten geldi" chip + oncelik rozeti.
            if (task.fromTicket) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  const TalepGeldiChip(),
                  OncelikBadge(oncelik: task.oncelik),
                ],
              ),
            ],
            if (task.aciklama != null) ...[
              const SizedBox(height: 8),
              Text(task.aciklama!),
            ],
            if (task.sonrakiPlanlanan != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.gorevPlanlanan(
                    tarihSaatBicimi(task.sonrakiPlanlanan!, dil)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (task.checkpointId != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.gorevNfcAciklama,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Adim 1 — NFC kaniti (gorevde checkpoint tanimliysa). Okunan UID
/// completion'a gider; ESLESME DOGRULAMASI BACKEND'DEDIR: etiket gorevin
/// noktasiyla uyusmazsa 422 doner ve mesaj gonderim hatasi olarak gosterilir.
class _NfcStep extends StatelessWidget {
  const _NfcStep({required this.state, required this.controller});

  final TaskCompleteState state;
  final TaskCompleteController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  state.nfcOkundu ? Icons.check_circle : Icons.nfc,
                  color: state.nfcOkundu ? Colors.green : null,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.gorevAdim1Etiket,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (state.nfcOkundu)
              Text(
                l10n.gorevOkundu(ltrIzole('${state.draft.nfcTagUid}')),
                style: const TextStyle(color: Colors.green),
              ),
            if (gorevHatasiCoz(l10n, state.nfcHata, state.nfcError)
                case final hata?)
              Text(
                hata,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: state.nfcReading ? null : controller.readNfc,
              icon: state.nfcReading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.nfc),
              label: Text(
                state.nfcReading
                    ? l10n.gorevEtiketBekleniyor
                    : state.nfcOkundu
                        ? l10n.gorevYenidenOkut
                        : l10n.gorevEtiketiOkut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Adim 2 — foto kaniti: cek/sec → presign → PUT → foto_key. Online
/// gerektirir; baglanti hatasi kullaniciya net soylenir. [fotoZorunlu]
/// gorevde isaretliyse rozet gosterilir (foto'suz tamamlama backend'de 422;
/// istemci zaten erken uyarir).
class _PhotoStep extends StatelessWidget {
  const _PhotoStep({
    required this.state,
    required this.controller,
    required this.fotoZorunlu,
  });

  final TaskCompleteState state;
  final TaskCompleteController controller;
  final bool fotoZorunlu;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  state.fotoYuklendi
                      ? Icons.check_circle
                      : Icons.photo_camera_outlined,
                  color: state.fotoYuklendi ? Colors.green : null,
                ),
                const SizedBox(width: 8),
                Text(
                  fotoZorunlu
                      ? l10n.gorevAdim2Foto
                      : l10n.gorevAdim2FotoOpsiyonel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (fotoZorunlu) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(l10n.gorevFotoZorunlu),
                    labelStyle: const TextStyle(
                        color: Colors.deepOrange, fontSize: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (state.photoPath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(state.photoPath!),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
              if (state.photoBusy)
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(l10n.gorevYukleniyorNokta),
                  ],
                )
              else if (state.fotoYuklendi)
                Text(
                  l10n.gorevYuklendi,
                  style: const TextStyle(color: Colors.green),
                ),
            ],
            if (gorevHatasiCoz(l10n, state.photoHata, state.photoError)
                case final hata?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  hata,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: state.photoBusy
                      ? null
                      : () =>
                          controller.pickAndUploadPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: Text(
                    state.photoPath == null
                        ? l10n.gorevKamera
                        : l10n.gorevYenidenCek,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: state.photoBusy
                      ? null
                      : () =>
                          controller.pickAndUploadPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(l10n.gorevGaleridenSec),
                ),
                if (state.photoPath != null && !state.fotoYuklendi)
                  OutlinedButton.icon(
                    onPressed:
                        state.photoBusy ? null : controller.retryUpload,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.gorevTekrarYukle),
                  ),
                if (state.photoPath != null)
                  TextButton.icon(
                    onPressed:
                        state.photoBusy ? null : controller.removePhoto,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.gorevKaldir),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Adim 3 — opsiyonel not.
class _NoteStep extends StatelessWidget {
  const _NoteStep({required this.controller});

  final TaskCompleteController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.gorevAdim3Not,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: controller.setNotlar,
              maxLines: 3,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: l10n.gorevNotIpucu,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Basari karti: 201 → "kaydedildi", 200 → "zaten kayitliydi" (idempotent
/// tekrar; ayni Idempotency-Key ile cift kayit olusmaz).
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.state, required this.onNew});

  final TaskCompleteState state;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final result = state.result!;
    return Card(
      color: Colors.green.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 8),
            Text(
              result.wasDuplicate
                  ? l10n.gorevZatenKayitliydi
                  : l10n.gorevTamamlandiKayit,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              [
                l10n.gorevZaman(tarihSaatBicimi(
                    result.completion.tamamlanmaZamani, dil)),
                if (result.completion.fotoKey != null) l10n.gorevFotoKanitiVar,
                if (result.completion.nfcTagUid != null)
                  l10n.gorevNfcDogrulandi,
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onNew,
              child: Text(l10n.gorevYeniTamamlamaBaslat),
            ),
          ],
        ),
      ),
    );
  }
}
