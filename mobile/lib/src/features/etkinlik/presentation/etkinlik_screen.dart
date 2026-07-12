import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../domain/etkinlik_models.dart';
import 'etkinlik_controller.dart';

/// "Etkinlikler" — etkinlik + RSVP (auth.md §4 kesin kurali, UX aynasi):
///   * yonetim (admin/yonetici): "Yeni etkinlik" FAB'i + detayda duzenle/sil;
///     seffaf katilim sayilarini izler.
///   * resident: Katiliyorum/Katilmiyorum beyani (degistirilebilir; secim
///     vurgulu gosterilir), sayac beyan sonrasi ANINDA guncellenir.
///   * herkes: yaklasan/gecmis listeleri + SEFFAF sayilar (kim-katiliyor
///     listesi yok — urun karari; yalniz sayi).
///
/// [initialEtkinlikId] push tiklamasindan gelir (?etkinlik_id=...): liste
/// yuklendiginde ilgili etkinligin detayi BIR KEZ otomatik acilir; kayit
/// listede yoksa sessizce listede kalinir.
class EtkinlikScreen extends ConsumerStatefulWidget {
  const EtkinlikScreen({super.key, this.initialEtkinlikId});

  final String? initialEtkinlikId;

  @override
  ConsumerState<EtkinlikScreen> createState() => _EtkinlikScreenState();
}

class _EtkinlikScreenState extends ConsumerState<EtkinlikScreen> {
  bool _initialHandled = false;

  void _maybeOpenInitial(EtkinlikState state) {
    if (_initialHandled || widget.initialEtkinlikId == null) return;
    if (state.loading) return;
    _initialHandled = true;
    Etkinlik? hedef;
    for (final e in state.items) {
      if (e.id == widget.initialEtkinlikId) {
        hedef = e;
        break;
      }
    }
    if (hedef == null) return; // listede yok — sessizce listede kal
    final e = hedef;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showDetail(context, e,
            canRsvp: state.canRsvp, canManage: state.canManage);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(etkinlikControllerProvider);
    final controller = ref.read(etkinlikControllerProvider.notifier);
    ref.listen(etkinlikControllerProvider, (_, next) => _maybeOpenInitial(next));
    // Provider zaten yuklu geldiyse (listen tetiklenmez) mevcut durumu isle.
    _maybeOpenInitial(state);

    // Yaklasan: en yakin onde (ASC); Gecmis: en yeni onde (sunucu DESC).
    final yaklasan = state.items.where((e) => !e.gecmis).toList(growable: false)
      ..sort((a, b) => a.tarih.compareTo(b.tarih));
    final gecmis = state.items.where((e) => e.gecmis).toList(growable: false);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Etkinlikler'),
          actions: [
            IconButton(
              tooltip: 'Yenile',
              icon: const Icon(Icons.refresh),
              onPressed: state.loading ? null : controller.refresh,
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Yaklaşan (${yaklasan.length})'),
              Tab(text: 'Geçmiş (${gecmis.length})'),
            ],
          ),
        ),
        floatingActionButton: state.canManage
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.celebration_outlined),
                label: const Text('Yeni etkinlik'),
                onPressed: () => _openForm(context),
              )
            : null,
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: controller.refresh,
              child: _Body(
                state: state,
                items: yaklasan,
                emptyText: state.canManage
                    ? 'Yaklaşan etkinlik yok. "Yeni etkinlik" ile duyurun.'
                    : 'Yaklaşan etkinlik yok.',
              ),
            ),
            RefreshIndicator(
              onRefresh: controller.refresh,
              child: _Body(
                state: state,
                items: gecmis,
                emptyText: 'Geçmiş etkinlik yok.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, {Etkinlik? mevcut}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EtkinlikForm(mevcut: mevcut),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mevcut == null
              ? 'Etkinlik duyuruldu — sakinlere bildirildi ✓'
              : 'Etkinlik güncellendi ✓'),
        ),
      );
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.state,
    required this.items,
    required this.emptyText,
  });

  final EtkinlikState state;
  final List<Etkinlik> items;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            state.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      );
    }
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(child: Text(emptyText, textAlign: TextAlign.center)),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: items.length,
      itemBuilder: (context, i) => _EtkinlikCard(
        etkinlik: items[i],
        canRsvp: state.canRsvp,
        canManage: state.canManage,
      ),
    );
  }
}

/// SEFFAF sayac satiri: ✓ n katiliyor · ✗ m katilmiyor (herkes gorur).
class _SayacRow extends StatelessWidget {
  const _SayacRow({required this.etkinlik});

  final Etkinlik etkinlik;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
        const SizedBox(width: 4),
        Text('${etkinlik.katiliyorumSayisi} katılıyor',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 12),
        const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
        const SizedBox(width: 4),
        Text('${etkinlik.katilmiyorumSayisi} katılmıyor',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _EtkinlikCard extends ConsumerWidget {
  const _EtkinlikCard({
    required this.etkinlik,
    required this.canRsvp,
    required this.canManage,
  });

  final Etkinlik etkinlik;
  final bool canRsvp;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = etkinlik;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            _showDetail(context, e, canRsvp: canRsvp, canManage: canManage),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.celebration_outlined, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      e.baslik,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (e.benimDurumum != null)
                    _BeyanChip(durum: e.benimDurumum!),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_fmtDateTime(e.tarih.toLocal())}'
                '${e.konum != null ? ' · ${e.konum}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(e.aciklama, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              _SayacRow(etkinlik: e),
              if (canRsvp && !e.gecmis) ...[
                const SizedBox(height: 12),
                _RsvpButtons(etkinlik: e),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Kullanicinin kendi beyaninin rozeti (kartta secim gorunur).
class _BeyanChip extends StatelessWidget {
  const _BeyanChip({required this.durum});

  final KatilimDurum durum;

  @override
  Widget build(BuildContext context) {
    final renk =
        durum == KatilimDurum.katiliyorum ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        durum.label,
        style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Katiliyorum/Katilmiyorum beyan butonlari — mevcut secim VURGULU; tekrar
/// basmak beyani degistirir (upsert; sayac aninda guncellenir).
class _RsvpButtons extends ConsumerStatefulWidget {
  const _RsvpButtons({required this.etkinlik, this.onAnswered});

  final Etkinlik etkinlik;

  /// Detay sheet'inden cagrildiginda beyan sonrasi sheet'i kapatmak icin.
  final VoidCallback? onAnswered;

  @override
  ConsumerState<_RsvpButtons> createState() => _RsvpButtonsState();
}

class _RsvpButtonsState extends ConsumerState<_RsvpButtons> {
  bool _busy = false;

  Future<void> _beyan(KatilimDurum durum) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(etkinlikControllerProvider.notifier)
          .rsvp(widget.etkinlik.id, durum);
      messenger.showSnackBar(
        SnackBar(content: Text('Beyanınız kaydedildi: ${durum.label} ✓')),
      );
      widget.onAnswered?.call();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Beyan gönderilemedi. Tekrar deneyin.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final secim = widget.etkinlik.benimDurumum;
    return Row(
      children: [
        Expanded(
          child: secim == KatilimDurum.katiliyorum
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  icon: const Icon(Icons.check),
                  label: const Text('Katılıyorum'),
                  onPressed: _busy
                      ? null
                      : () => _beyan(KatilimDurum.katiliyorum),
                )
              : OutlinedButton.icon(
                  icon: const Icon(Icons.check, color: Colors.green),
                  label: const Text('Katılıyorum'),
                  onPressed: _busy
                      ? null
                      : () => _beyan(KatilimDurum.katiliyorum),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: secim == KatilimDurum.katilmiyorum
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  icon: const Icon(Icons.close),
                  label: const Text('Katılmıyorum'),
                  onPressed: _busy
                      ? null
                      : () => _beyan(KatilimDurum.katilmiyorum),
                )
              : OutlinedButton.icon(
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text('Katılmıyorum'),
                  onPressed: _busy
                      ? null
                      : () => _beyan(KatilimDurum.katilmiyorum),
                ),
        ),
      ],
    );
  }
}

/// Detay alt sayfasi — push tiklamasi ve kart dokunusuyla acilir. Sakin +
/// yaklasan etkinlikte beyan butonlari; yonetimde duzenle/sil.
void _showDetail(
  BuildContext context,
  Etkinlik e, {
  required bool canRsvp,
  required bool canManage,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.celebration_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.baslik,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (e.benimDurumum != null)
                    _BeyanChip(durum: e.benimDurumum!),
                ],
              ),
              const SizedBox(height: 12),
              Text('Zaman: ${_fmtDateTime(e.tarih.toLocal())}'),
              if (e.konum != null) ...[
                const SizedBox(height: 4),
                Text('Yer: ${e.konum}'),
              ],
              const SizedBox(height: 8),
              Text(e.aciklama),
              const SizedBox(height: 12),
              _SayacRow(etkinlik: e),
              if (e.olusturanAd != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Duyuran: ${e.olusturanAd}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (canRsvp && !e.gecmis) ...[
                const SizedBox(height: 20),
                _RsvpButtons(
                  etkinlik: e,
                  onAnswered: () => Navigator.of(sheetContext).pop(),
                ),
              ],
              if (canManage) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Düzenle'),
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => _EtkinlikForm(mevcut: e),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DeleteButton(
                        etkinlik: e,
                        onDeleted: () => Navigator.of(sheetContext).pop(),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// Sil butonu — onay dialogu ister (RSVP'ler etkinlikle birlikte silinir).
class _DeleteButton extends ConsumerWidget {
  const _DeleteButton({required this.etkinlik, required this.onDeleted});

  final Etkinlik etkinlik;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
      icon: const Icon(Icons.delete_outline),
      label: const Text('Sil'),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final onay = await showDialog<bool>(
          context: context,
          builder: (dctx) => AlertDialog(
            title: const Text('Etkinlik silinsin mi?'),
            content: Text(
              '"${etkinlik.baslik}" ve tüm katılım beyanları silinecek.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dctx).pop(false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(dctx).pop(true),
                child: const Text('Sil'),
              ),
            ],
          ),
        );
        if (onay != true) return;
        try {
          await ref
              .read(etkinlikControllerProvider.notifier)
              .delete(etkinlik.id);
          messenger.showSnackBar(
            const SnackBar(content: Text('Etkinlik silindi ✓')),
          );
          onDeleted();
        } on ApiException catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(e.message)));
        }
      },
    );
  }
}

/// Etkinlik olustur/duzenle formu (yonetim): baslik + aciklama +
/// tarih/saat + opsiyonel konum.
class _EtkinlikForm extends ConsumerStatefulWidget {
  const _EtkinlikForm({this.mevcut});

  /// Dolu ise DUZENLEME modu (alanlar on-dolu gelir).
  final Etkinlik? mevcut;

  @override
  ConsumerState<_EtkinlikForm> createState() => _EtkinlikFormState();
}

class _EtkinlikFormState extends ConsumerState<_EtkinlikForm> {
  final _formKey = GlobalKey<FormState>();
  late final _baslik = TextEditingController(text: widget.mevcut?.baslik);
  late final _aciklama = TextEditingController(text: widget.mevcut?.aciklama);
  late final _konum = TextEditingController(text: widget.mevcut?.konum);
  late DateTime _tarih = widget.mevcut?.tarih.toLocal() ??
      DateTime.now().add(const Duration(days: 1));
  bool _busy = false;
  String? _hata;

  @override
  void dispose() {
    _baslik.dispose();
    _aciklama.dispose();
    _konum.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final gun = await showDatePicker(
      context: context,
      initialDate: _tarih,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (gun == null || !mounted) return;
    final saat = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_tarih),
    );
    if (saat == null) return;
    setState(() {
      _tarih = DateTime(gun.year, gun.month, gun.day, saat.hour, saat.minute);
    });
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _hata = null;
    });
    final draft = EtkinlikDraft(
      baslik: _baslik.text.trim(),
      aciklama: _aciklama.text.trim(),
      tarih: _tarih,
      konum: _konum.text.trim().isEmpty ? null : _konum.text.trim(),
    );
    try {
      final controller = ref.read(etkinlikControllerProvider.notifier);
      if (widget.mevcut == null) {
        await controller.create(draft);
      } else {
        await controller.update(widget.mevcut!.id, draft);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _hata = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _hata = 'Kaydedilemedi. Tekrar deneyin.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.mevcut == null ? 'Yeni etkinlik' : 'Etkinliği düzenle',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _baslik,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Başlık * (örn. Maç izleme akşamı)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 200,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Başlık gerekli' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _aciklama,
                decoration: const InputDecoration(
                  labelText: 'Açıklama *',
                  border: OutlineInputBorder(),
                ),
                maxLength: 5000,
                minLines: 2,
                maxLines: 5,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Açıklama gerekli'
                    : null,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule, size: 18),
                label: Text('Zaman: ${_fmtDateTime(_tarih)}'),
                onPressed: _busy ? null : _pickDateTime,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _konum,
                decoration: const InputDecoration(
                  labelText: 'Yer (opsiyonel)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 500,
              ),
              if (_hata != null) ...[
                const SizedBox(height: 8),
                Text(_hata!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.celebration_outlined),
                  label: Text(widget.mevcut == null
                      ? 'Duyur ve sakinlere bildir'
                      : 'Kaydet'),
                  onPressed: _busy ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtDateTime(DateTime dt) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(dt.day)}.${p(dt.month)}.${dt.year} ${p(dt.hour)}:${p(dt.minute)}';
}
