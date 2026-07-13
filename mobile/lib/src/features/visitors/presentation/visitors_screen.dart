import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../call/presentation/call_button.dart';
import '../data/visitor_api.dart';
import '../domain/visitor_models.dart';
import 'visitors_controller.dart';

/// "Ziyaretciler" — kapi ZIYARETCI KAYDI (LOG-ONLY, auth.md §4 UX aynasi):
///   * security: "Yeni ziyaretci" FAB'i (ad + daire no + hedef sakin + not) +
///     tenant'in tum kayit gecmisi.
///   * resident: KENDINE hedeflenen ziyaretci kayitlari — BILGILENDIRME
///     (kaydedildi bilgisi). Onay/red YOKTUR.
///   * admin/yonetici: tek-seferlik izinle daire kayitlari (salt izleme).
///
/// [initialVisitorId] push tiklamasindan gelir (?visitor_id=...): liste
/// yuklendiginde ilgili kaydin detayi BIR KEZ otomatik acilir; kayit listede
/// yoksa (yetki disi/silinmis) sessizce listede kalinir.
class VisitorsScreen extends ConsumerStatefulWidget {
  const VisitorsScreen({super.key, this.initialVisitorId});

  final String? initialVisitorId;

  @override
  ConsumerState<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends ConsumerState<VisitorsScreen> {
  bool _initialHandled = false;

  void _maybeOpenInitial(VisitorsState state) {
    if (_initialHandled || widget.initialVisitorId == null) return;
    if (state.loading) return;
    _initialHandled = true;
    Visitor? hedef;
    for (final v in state.items) {
      if (v.id == widget.initialVisitorId) {
        hedef = v;
        break;
      }
    }
    if (hedef == null) return; // listede yok — sessizce listede kal
    final v = hedef;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showDetail(context, v, canRegister: state.canRegister);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(visitorsControllerProvider);
    final controller = ref.read(visitorsControllerProvider.notifier);
    ref.listen(visitorsControllerProvider, (_, next) => _maybeOpenInitial(next));
    _maybeOpenInitial(state);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ziyaretçiler'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: state.loading ? null : controller.refresh,
          ),
        ],
      ),
      floatingActionButton: state.canRegister
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Yeni ziyaretçi'),
              onPressed: () => _openForm(context),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: _Body(state: state),
      ),
    );
  }

  Future<void> _openForm(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _VisitorForm(),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ziyaretçi kaydedildi — daire sakinine bildirildi ✓'),
        ),
      );
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final VisitorsState state;

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
    if (state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Text(
              state.canRegister
                  ? 'Henüz ziyaretçi kaydı yok.'
                  : 'Size iletilen ziyaretçi kaydı yok.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: state.items.length,
      itemBuilder: (context, i) => _VisitorCard(
        visitor: state.items[i],
        canRegister: state.canRegister,
      ),
    );
  }
}

class _VisitorCard extends ConsumerWidget {
  const _VisitorCard({required this.visitor, required this.canRegister});

  final Visitor visitor;
  final bool canRegister;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = visitor;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context, v, canRegister: canRegister),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      v.ziyaretciAd,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Daire: ${v.unitNo ?? '-'} · ${_fmtDateTime(v.createdAt.toLocal())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (v.targetResidentAd != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Bildirilen sakin: ${v.targetResidentAd}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (v.notlar != null && v.notlar!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(v.notlar!, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Detay alt sayfasi — push tiklamasi ve kart dokunusuyla acilir. Log-only:
/// onay/red YOK; yalniz kayit bilgisi + rol-bazli arama (rıza kapısıyla).
void _showDetail(
  BuildContext context,
  Visitor v, {
  required bool canRegister,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    v.ziyaretciAd,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Daire: ${v.unitNo ?? '-'}'),
            const SizedBox(height: 4),
            Text('Kayıt: ${_fmtDateTime(v.createdAt.toLocal())}'
                '${v.kaydedenAd != null ? ' — ${v.kaydedenAd}' : ''}'),
            if (v.notlar != null && v.notlar!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Not: ${v.notlar}'),
            ],
            // Rol-bazli arama (C1a): güvenlik → HEDEF sakini arar; sakin →
            // kaydı açan GÜVENLİĞİ arar. Buton yalnız aranabilir (rıza) ise
            // etkinleşir; numara ekranda gösterilmez (/call-target kapısı).
            if (canRegister && v.targetResidentUserId.isNotEmpty) ...[
              const SizedBox(height: 12),
              CallButton(userId: v.targetResidentUserId, label: 'Sakini ara'),
            ],
            if (!canRegister && v.kaydedenUserId.isNotEmpty) ...[
              const SizedBox(height: 12),
              CallButton(userId: v.kaydedenUserId, label: 'Güvenliği ara'),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Yeni ziyaretci formu (yalniz guvenlik): ad + daire no + hedef sakin + not.
class _VisitorForm extends ConsumerStatefulWidget {
  const _VisitorForm();

  @override
  ConsumerState<_VisitorForm> createState() => _VisitorFormState();
}

class _VisitorFormState extends ConsumerState<_VisitorForm> {
  final _formKey = GlobalKey<FormState>();
  final _ad = TextEditingController();
  final _unitNo = TextEditingController();
  final _notlar = TextEditingController();
  bool _busy = false;
  String? _hata;

  /// Hedef sakin secicisi (tek hedef modeli): once daire sakinleri cekilir.
  List<UnitResidentBrief>? _residents;
  bool _loadingResidents = false;
  String? _residentsError;
  String? _targetId;

  @override
  void dispose() {
    _ad.dispose();
    _unitNo.dispose();
    _notlar.dispose();
    super.dispose();
  }

  /// Girilen daire NO'su icin AKTIF sakinleri getir (hedef secicisini doldur).
  Future<void> _loadResidents() async {
    final unitNo = _unitNo.text.trim();
    if (unitNo.isEmpty) {
      setState(() => _residentsError = 'Önce daire no girin');
      return;
    }
    setState(() {
      _loadingResidents = true;
      _residentsError = null;
      _residents = null;
      _targetId = null;
    });
    try {
      final list =
          await ref.read(visitorApiProvider).fetchUnitResidents(unitNo);
      if (!mounted) return;
      setState(() {
        _residents = list;
        if (list.isEmpty) {
          _residentsError = 'Bu dairede aktif sakin yok';
        } else if (list.length == 1) {
          _targetId = list.first.userId; // tek sakin -> otomatik secili
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _residentsError = e.message);
    } finally {
      if (mounted) setState(() => _loadingResidents = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    if (_targetId == null) {
      setState(() => _hata = 'Bildirilecek sakini seçin');
      return;
    }
    setState(() {
      _busy = true;
      _hata = null;
    });
    try {
      await ref.read(visitorsControllerProvider.notifier).register(
            VisitorDraft(
              ziyaretciAd: _ad.text.trim(),
              unitNo: _unitNo.text.trim(),
              targetResidentUserId: _targetId!,
              notlar: _notlar.text.trim().isEmpty ? null : _notlar.text.trim(),
            ),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      // 422 invalid_reference: daire yok / hedef o dairenin sakini degil.
      if (mounted) setState(() => _hata = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _hata = 'Kayıt gönderilemedi. Tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      // Klavye acilinca form yukari itilsin.
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yeni ziyaretçi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sakine yalnızca bilgilendirme gider (onay istenmez).',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ad,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Ziyaretçi adı *',
                border: OutlineInputBorder(),
              ),
              maxLength: 200,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ziyaretçi adı gerekli' : null,
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _unitNo,
                    decoration: const InputDecoration(
                      labelText: 'Daire no * (örn. A-12)',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 50,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Daire no gerekli'
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton(
                    onPressed: _loadingResidents ? null : _loadResidents,
                    child: _loadingResidents
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sakinleri getir'),
                  ),
                ),
              ],
            ),
            // Hedef sakin secicisi — daire sakinleri cekilince gorunur.
            if (_residentsError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _residentsError!,
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
            if (_residents != null && _residents!.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _targetId,
                decoration: const InputDecoration(
                  labelText: 'Bildirilecek sakin *',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final r in _residents!)
                    DropdownMenuItem(value: r.userId, child: Text(r.ad)),
                ],
                onChanged: (v) => setState(() => _targetId = v),
              ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notlar,
              decoration: const InputDecoration(
                labelText: 'Not (opsiyonel)',
                border: OutlineInputBorder(),
              ),
              maxLength: 1000,
              maxLines: 2,
            ),
            if (_hata != null) ...[
              const SizedBox(height: 8),
              Text(_hata!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1),
                label: const Text('Kaydet ve sakine bildir'),
                onPressed: _busy ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtDateTime(DateTime dt) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(dt.day)}.${p(dt.month)}.${dt.year} ${p(dt.hour)}:${p(dt.minute)}';
}
