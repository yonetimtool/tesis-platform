import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/src/core/girdi_siniri.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/theme/home_tokens.dart';
import '../../../core/ui/gorsel_cozme.dart';
import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/task_api.dart';
import '../data/task_category_api.dart';
import '../domain/task_models.dart';
import 'gorev_hata_metni.dart';
import 'task_complete_controller.dart';
import 'task_form_sheet.dart';
import 'task_ticket_widgets.dart';
import 'task_tip_style.dart';
import 'tasks_controller.dart';
import '../../nfc/presentation/nfc_hata_metni.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../../core/izin/belirgin_aciklama.dart';
import 'durum_rozeti.dart';

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
    final controller = ref.read(
      taskCompleteControllerProvider(task.id).notifier,
    );
    // Gorev tipi = kategori adi (kategori_id -> ad, listeden cozulur); null = Diğer.
    final kategoriler = ref.watch(taskCategoriesProvider).value;
    final adlar = (kategoriler ?? const [])
        .where((k) => k.id == task.kategoriId)
        .map((k) => k.ad);
    final style = taskKategoriStyle(
      task.kategoriId == null || adlar.isEmpty ? null : adlar.first,
    );
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
                child: Text(hata, style: const TextStyle(color: Colors.red)),
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
                state.submitting ? l10n.gorevGonderiliyor : l10n.gorevTamamla,
              ),
            ),
          ],
          // (P230 §4) ZAMAN CIZELGESI + "BASLA".
          //
          // Onceden yalniz IKI hal vardi (atanmis / tamamlanmis) ve
          // yonetici, arada isin ELE ALINDIGINI mi yoksa OYLECE
          // DURDUGUNU mu bilmiyordu.
          const SizedBox(height: 16),
          _TakipKarti(task: task, baslatabilir: canComplete || canManage),
          // (P229 §3) TAMAMLAMA GECMISI — KIM, NE ZAMAN, FOTO, NOT.
          //
          // OLCULEN KUSUR: yukaridaki `_ResultCard` YALNIZ o oturumda
          // yapilan POST'un yanitindan cizilir; ekrani kapatinca
          // kaybolur ve baska kimse gormez. `GET /tasks/{id}/completions`
          // sunucuda VARDI ama HICBIR ISTEMCIDEN cagrilmiyordu.
          // (P237 §2) ALT ADIMLAR — tamamlama gecmisinin USTUNDE.
          //
          // Acik gorevde sorulan soru "nerede kaldi"; tamamlanma gecmisi
          // ise gorev BITTIKTEN sonra bakilan yer.
          const SizedBox(height: 16),
          _AdimlarKarti(
            task: task,
            tamamlayabilir: canComplete || canManage,
            yonetebilir: canManage,
          ),
          const SizedBox(height: 16),
          _TamamlamaGecmisi(taskId: task.id, yonetebilir: canManage),
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
      messenger.showSnackBar(SnackBar(content: Text(l10n.gorevGuncellendi)));
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
        messenger.showSnackBar(SnackBar(content: Text(l10n.gorevSilindi)));
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
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
    final currentUserId = ref.watch(
      tasksControllerProvider.select((s) => s.currentUserId),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // `Row` + `Spacer` 320 dp'de 238 px tasiyordu (tur 37): iki cip
            // ayni satira sigmiyor. `Wrap` dar ekranda alt satira gecirir,
            // genis ekranda gorunum aynidir.
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(style.icon, color: okunurVurgu(context, style.color)),
                Chip(
                  label: Text(style.ad ?? l10n.gorevKategoriDiger),
                  backgroundColor: style.color.withValues(alpha: 0.15),
                  // Koyu temada ham vurgu 2.58:1 kaliyordu (tur 37).
                  labelStyle: TextStyle(
                    color: okunurVurgu(context, style.color),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
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
                  tarihSaatBicimi(task.sonrakiPlanlanan!, dil),
                ),
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
                // Almanca baslik 320 dp'de 47 px tasiriyordu (tur 39);
                // adim 2 basligi tur 37'de zaten esnetilmisti.
                Expanded(
                  child: Text(
                    l10n.gorevAdim1Etiket,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (state.nfcOkundu)
              Text(
                l10n.gorevOkundu(ltrIzole('${state.draft.nfcTagUid}')),
                style: const TextStyle(color: Colors.green),
              ),
            // NFC servisinin KIMLIGI varsa onu ciz (tur 9); yoksa gorev
            // akisinin kimligi / sunucu metni.
            if (state.nfcKimlik != null)
              Text(
                nfcHataMetni(
                  l10n,
                  state.nfcKimlik!,
                  detay: state.nfcKimlikDetay,
                ),
                style: const TextStyle(color: Colors.red),
              )
            else if (gorevHatasiCoz(l10n, state.nfcHata, state.nfcError)
                case final hata?)
              Text(hata, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: state.nfcReading
                  ? null
                  : () => controller.readNfc(nfcIosMetinleri(l10n)),
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
            // Baslik + "foto zorunlu" cipi 320 dp'de tek satira sigmiyordu
            // (tur 37: 238 px tasma). `Wrap` dar ekranda alt satira gecirir.
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  state.fotoYuklendi
                      ? Icons.check_circle
                      : Icons.photo_camera_outlined,
                  color: state.fotoYuklendi ? Colors.green : null,
                ),
                Text(
                  fotoZorunlu
                      ? l10n.gorevAdim2Foto
                      : l10n.gorevAdim2FotoOpsiyonel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (fotoZorunlu)
                  Chip(
                    label: Text(l10n.gorevFotoZorunlu),
                    labelStyle: const TextStyle(
                      color: Colors.deepOrange,
                      fontSize: 12,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
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
                    // "Yukleniyor..." satiri da esnek olmali: Almanca metin
                    // 320 dp'de 47 px tasiriyordu (tur 39). Bu satir YALNIZ
                    // yukleme SURERKEN cizilir — kisa omurlu oldugu icin
                    // hicbir eski suruste gorunmemisti.
                    Expanded(child: Text(l10n.gorevYukleniyorNokta)),
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
                child: Text(hata, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: state.photoBusy
                      ? null
                      : () => controller.pickAndUploadPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: Text(
                    state.photoPath == null
                        ? l10n.gorevKamera
                        : l10n.gorevYenidenCek,
                    // Almanca "Erneut aufnehmen" 320 dp'de 47 px tasiriyordu
                    // (tur 39). Kardes dugmelerde bu zaten yapilmisti.
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: state.photoBusy
                      ? null
                      : () =>
                            controller.pickAndUploadPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(
                    l10n.gorevGaleridenSec,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (state.photoPath != null && !state.fotoYuklendi)
                  OutlinedButton.icon(
                    onPressed: state.photoBusy ? null : controller.retryUpload,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      l10n.gorevTekrarYukle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (state.photoPath != null)
                  TextButton.icon(
                    onPressed: state.photoBusy ? null : controller.removePhoto,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(
                      l10n.gorevKaldir,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
              // sayac gizli: gorev_detay yerlesim kilidi (saha_akisi_surus_test)
              inputFormatters: GirdiSiniri.sinir(GirdiSiniri.not_), // sunucu: TaskCompletionCreate.notlar
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
                l10n.gorevZaman(
                  tarihSaatBicimi(result.completion.tamamlanmaZamani, dil),
                ),
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


/// (P229 §3) Gorevin tamamlama gecmisi: KIM, NE ZAMAN, FOTO, NOT.
///
/// Yonetim rolleri her kaydi GERI ALABILIR (sunucu `_REOPENER` ile de
/// korur — yetki kurali istemcide DEGIL sunucudadir; buradaki kosul
/// yalnizca gosterim).
class _TamamlamaGecmisi extends ConsumerWidget {
  const _TamamlamaGecmisi({required this.taskId, required this.yonetebilir});

  final String taskId;
  final bool yonetebilir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final gecmis = ref.watch(gorevTamamlamalariProvider(taskId));

    return gecmis.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      // HATA SESSIZ GECILMEZ ama EKRANI DA KIRMAZ: gecmis yuklenemezse
      // tamamlama akisi calismaya devam etmeli.
      error: (_, _) => Card(
        child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: Text(l10n.gorevGecmisYuklenemedi),
        ),
      ),
      data: (liste) {
        if (liste.isEmpty) {
          return Card(
            child: ListTile(
              key: const Key('gorev-gecmis-bos'),
              leading: const Icon(Icons.pending_outlined),
              title: Text(l10n.gorevHenuzTamamlanmadi),
            ),
          );
        }
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  l10n.gorevTamamlamaGecmisi,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              for (final c in liste)
                ListTile(
                  key: Key('gorev-tamamlama-${c.id}'),
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(c.tamamlayanAd ?? l10n.ortakBilinmiyor),
                  subtitle: Text(
                    [
                      tarihSaatBicimi(c.tamamlanmaZamani, dil),
                      if (c.notlar != null && c.notlar!.isNotEmpty) c.notlar!,
                    ].join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (c.fotoUrl != null)
                        IconButton(
                          key: Key('gorev-tamamlama-foto-${c.id}'),
                          icon: const Icon(Icons.photo_outlined),
                          tooltip: l10n.gorevFotoKanitiVar,
                          onPressed: () => showDialog<void>(
                            context: context,
                            // COZME SINIRI ZORUNLU: tam cozunurlukte
                            // acilan bir saha fotografi (12 MP) bellekte
                            // ~48 MB tutar ve eski cihazda uygulamayi
                            // oldururdu (`gorsel_cozme_denetimi_test`
                            // bunu STATIK olarak kilitliyor).
                            builder: (ctx) => Dialog(
                              child: InteractiveViewer(
                                child: Image(
                                  image: sinirliGorsel(ctx, NetworkImage(c.fotoUrl!), 1080),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (yonetebilir)
                        IconButton(
                          key: Key('gorev-tamamlama-geri-al-${c.id}'),
                          icon: const Icon(Icons.undo),
                          tooltip: l10n.gorevTamamlamayiGeriAl,
                          onPressed: () async {
                            await ref
                                .read(taskApiProvider)
                                .deleteCompletion(taskId, c.id);
                            ref.invalidate(
                                gorevTamamlamalariProvider(taskId));
                          },
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// (P237 §2) ALT ADIMLAR KARTI — kim, ne zaman, fotografiyla.
///
/// =========================================================================
/// NEDEN AYRI KART, TAMAMLAMA AKISINA GOMULU DEGIL
/// =========================================================================
/// `_PhotoStep`/`_NoteStep` GOREVIN TAMAMINI kapatan tek bir kanit toplar.
/// Adim, isin BIR PARCASINI kapatir ve gorev acik kalir. Ikisini ayni
/// akista birlestirmek, "fotograf yukledim" eyleminin hangi seyi
/// kapattigini belirsizlestirirdi.
class _AdimlarKarti extends ConsumerStatefulWidget {
  const _AdimlarKarti({
    required this.task,
    required this.tamamlayabilir,
    required this.yonetebilir,
  });

  final Task task;
  final bool tamamlayabilir;
  final bool yonetebilir;

  @override
  ConsumerState<_AdimlarKarti> createState() => _AdimlarKartiState();
}

class _AdimlarKartiState extends ConsumerState<_AdimlarKarti> {
  final _yeniAdim = TextEditingController();
  String? _mesgulAdim;
  String? _hata;

  @override
  void dispose() {
    _yeniAdim.dispose();
    super.dispose();
  }

  // (E2E 2026-09) TESIS-03: SON adim gorevi sunucuda KAPATIR (tamamlama
  // kaydi uretilir). Yalniz adimlari tazelemek, ekranda gecmisi "henuz
  // tamamlanmadi" ve listede rozeti "atandi" birakiyordu.
  Future<void> _tazele() async {
    ref.invalidate(gorevAdimlariProvider(widget.task.id));
    ref.invalidate(gorevTamamlamalariProvider(widget.task.id));
    await ref.read(tasksControllerProvider.notifier).refresh(silent: true);
  }

  Future<void> _sar(Future<void> Function() is_, {String? adimId}) async {
    setState(() {
      _mesgulAdim = adimId ?? '';
      _hata = null;
    });
    try {
      await is_();
      await _tazele();
    } on ApiException catch (e) {
      if (mounted) setState(() => _hata = e.message);
    } finally {
      if (mounted) setState(() => _mesgulAdim = null);
    }
  }

  /// FOTOGRAFLI TAMAMLAMA: presign -> PUT -> foto_key (tamamlama akisiyla
  /// AYNI desen; kopyalanan sey yalnizca uc adi).
  Future<void> _fotoylaTamamla(TaskStep adim) async {
    final api = ref.read(taskApiProvider);
    final secici = ref.read(imagePickerProvider);
    // (E2E 2026-09) MOBIL-7: kamera cagrisi try/catch'SIZDI — iOS'ta izin
    // reddinde `camera_access_denied` PlatformException yakalanmiyor, dugme
    // tepkisiz kaliyordu. Diger foto akislariyla AYNI desen: once belirgin
    // aciklama (P141.5), sonra korunakli cagri + gorunur hata metni.
    final l10n = context.l10n;
    final onay = await belirginAciklamaGoster(context, IzinTuru.talepFotograf);
    if (!onay || !mounted) return;
    final XFile? secilen;
    try {
      secilen = await secici.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 80,
      );
    } catch (e) {
      if (mounted) setState(() => _hata = l10n.gorevFotoAlinamadi('$e'));
      return;
    }
    if (secilen == null) return;
    final XFile dosya = secilen;
    await _sar(
      adimId: adim.id,
      () async {
        final tip = dosya.mimeType ?? 'image/jpeg';
        final bilet = await api.presignUpload(
          contentType: tip,
          dosyaAdi: dosya.name,
        );
        await api.uploadPhoto(
          ticket: bilet,
          bytes: await dosya.readAsBytes(),
          contentType: tip,
        );
        await api.completeStep(
          widget.task.id,
          adim.id,
          fotoKey: bilet.fotoKey,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final api = ref.read(taskApiProvider);
    final adimlar = ref.watch(gorevAdimlariProvider(widget.task.id));

    return adimlar.when(
      loading: () => const Card(
        child: ListTile(
          leading: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text(''),
        ),
      ),
      // HATA EKRANI KIRMAZ: adimlar yuklenemese de tamamlama akisi surer.
      error: (_, _) => Card(
        child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: Text(l10n.gorevAdimYuklenemedi),
        ),
      ),
      data: (liste) {
        final tamam = liste.where((a) => a.tamamlandi).length;
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                // BASLIK VE ILERLEME ALT ALTA, yan yana DEGIL.
                //
                // Ilk deneme `Row` idi ve YERLESIM KILIDI curuttu: uzun
                // ceviriler (ru/de) ilerleme metnini buyutunce baslik
                // 47 piksele sikisip DORT SATIRA kiriliyordu. Olcum:
                // `mobile/test/yerlesim/gorev_detay.txt` "47x80".
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.gorevAdimlar,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (liste.isNotEmpty)
                      Text(
                        key: const Key('gorev-adim-ilerleme'),
                        l10n.gorevAdimIlerleme('$tamam', '${liste.length}'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (widget.task.adimSirali && liste.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(
                    l10n.gorevAdimSirali,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (liste.isEmpty)
                ListTile(
                  key: const Key('gorev-adim-bos'),
                  leading: const Icon(Icons.checklist_outlined),
                  title: Text(l10n.gorevAdimYok),
                ),
              for (final a in liste)
                ListTile(
                  key: Key('gorev-adim-${a.id}'),
                  leading: Icon(
                    a.tamamlandi
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: a.tamamlandi ? Colors.green : null,
                  ),
                  title: Text(a.ad),
                  subtitle: a.tamamlandi
                      ? Text([
                          a.tamamlayanAd ?? l10n.ortakBilinmiyor,
                          if (a.tamamlanmaZamani != null)
                            tarihSaatBicimi(a.tamamlanmaZamani!, dil),
                          if (a.notlar != null && a.notlar!.isNotEmpty)
                            a.notlar!,
                        ].join(' · '))
                      : (a.fotoZorunlu
                          ? Text(l10n.gorevAdimFotoZorunlu)
                          : null),
                  trailing: _mesgulAdim == a.id
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (a.fotoUrl != null)
                              IconButton(
                                key: Key('gorev-adim-foto-${a.id}'),
                                icon: const Icon(Icons.photo_outlined),
                                tooltip: l10n.gorevFotoKanitiVar,
                                onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (ctx) => Dialog(
                                    child: InteractiveViewer(
                                      // TEK SATIR BILINCLI: kilit
                                      // (`gorsel_cozme_denetimi_test`)
                                      // `NetworkImage(` oncesindeki 60
                                      // karaktere bakiyor; cok satira
                                      // yayilan sarmalayici o pencereye
                                      // girmiyor ve sahte ihlal uretiyor.
                                      child: Image(image: sinirliGorsel(ctx, NetworkImage(a.fotoUrl!), 1080)),
                                    ),
                                  ),
                                ),
                              ),
                            if (!a.tamamlandi && widget.tamamlayabilir)
                              IconButton(
                                key: Key('gorev-adim-tamamla-${a.id}'),
                                icon: Icon(
                                  a.fotoZorunlu
                                      ? Icons.photo_camera_outlined
                                      : Icons.check,
                                ),
                                tooltip: l10n.gorevAdimTamamla,
                                onPressed: () => a.fotoZorunlu
                                    ? _fotoylaTamamla(a)
                                    : _sar(
                                        adimId: a.id,
                                        () => api
                                            .completeStep(widget.task.id, a.id)
                                            .then((_) {}),
                                      ),
                              ),
                            if (a.tamamlandi && widget.yonetebilir)
                              IconButton(
                                key: Key('gorev-adim-geri-al-${a.id}'),
                                icon: const Icon(Icons.undo),
                                tooltip: l10n.gorevAdimGeriAl,
                                onPressed: () => _sar(
                                  adimId: a.id,
                                  () => api
                                      .reopenStep(widget.task.id, a.id)
                                      .then((_) {}),
                                ),
                              ),
                            if (widget.yonetebilir)
                              IconButton(
                                key: Key('gorev-adim-sil-${a.id}'),
                                icon: const Icon(Icons.delete_outline),
                                tooltip: l10n.gorevAdimSil,
                                onPressed: () => _sar(
                                  adimId: a.id,
                                  () =>
                                      api.deleteStep(widget.task.id, a.id),
                                ),
                              ),
                          ],
                        ),
                ),
              if (_hata != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    _hata!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              // ADIM EKLEME YALNIZ YONETIMDE: adim isin TANIMIDIR; paydayi
              // isi yapan belirleseydi ilerleme olcusu denetlenemez olurdu.
              if (widget.yonetebilir)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  // ALAN VE DUGME ALT ALTA: yan yana `Row` 320dp'de
                  // Almanca'da 68 piksel TASTI (olcum: bes eksen dar
                  // ekran surusu). Etiketi kisaltmak yerine yerlesimi
                  // degistirmek, uzun ceviri gelen her dilde calisir.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const Key('gorev-adim-yeni'),
                        inputFormatters: GirdiSiniri.sinir(200), // sunucu: TaskStepCreate.ad
                        controller: _yeniAdim,
                        decoration: InputDecoration(
                          labelText: l10n.gorevAdimAd,
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        key: const Key('gorev-adim-ekle'),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.gorevAdimEkle),
                        onPressed: () {
                          final ad = _yeniAdim.text.trim();
                          if (ad.isEmpty) return;
                          _sar(() async {
                            await api.addStep(
                              widget.task.id,
                              ad,
                              sira: liste.length,
                            );
                            _yeniAdim.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// (P237 §2) Gorevin alt adimlari — `GET /tasks/{id}/adimlar`.
final gorevAdimlariProvider =
    FutureProvider.autoDispose.family<List<TaskStep>, String>(
  (ref, taskId) => ref.watch(taskApiProvider).fetchSteps(taskId),
);

/// (P229 §3) Gorevin tamamlama gecmisi — `GET /tasks/{id}/completions`.
final gorevTamamlamalariProvider =
    FutureProvider.autoDispose.family<List<TaskCompletion>, String>(
  (ref, taskId) => ref.watch(taskApiProvider).fetchCompletions(taskId),
);


/// (P230 §4) TAKIP KARTI — durum, zaman cizelgesi, "Basla".
class _TakipKarti extends ConsumerStatefulWidget {
  const _TakipKarti({required this.task, required this.baslatabilir});

  final Task task;
  final bool baslatabilir;

  @override
  ConsumerState<_TakipKarti> createState() => _TakipKartiState();
}

class _TakipKartiState extends ConsumerState<_TakipKarti> {
  late Task _task = widget.task;
  bool _bekliyor = false;

  Future<void> _basla() async {
    setState(() => _bekliyor = true);
    try {
      final yeni = await ref.read(taskApiProvider).basla(_task.id);
      if (!mounted) return;
      setState(() {
        _task = yeni;
        _bekliyor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _bekliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final t = _task;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DurumRozeti(durum: t.durum, gecikmeGun: t.gecikmeGun),
            const SizedBox(height: 8),
            if (t.olusturanAd != null)
              Text(l10n.gorevAtayanBilgi(t.olusturanAd!)),
            if (t.sonTarih != null)
              Text(l10n.gorevSonTarihi(tarihSaatBicimi(t.sonTarih!, dil))),
            if (t.baslamaZamani != null)
              Text(
                l10n.gorevBaslandiBilgi(
                  tarihSaatBicimi(t.baslamaZamani!, dil),
                ),
              ),
            // BASLA YALNIZ HENUZ BASLANMAMISKEN: baslamis bir gorevde
            // dugmeyi birakmak, ikinci dokunusun ne yapacagini belirsiz
            // yapardi (sunucu idempotent ama kullanici bunu bilmez).
            if (widget.baslatabilir &&
                t.baslamaZamani == null &&
                !t.tamamlandi) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                key: const Key('gorev-basla'),
                onPressed: _bekliyor ? null : _basla,
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.gorevBaslaDugme),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
