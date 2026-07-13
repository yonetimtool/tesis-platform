import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/visitor_api.dart';
import '../domain/visitor_models.dart';
import 'visitors_controller.dart';

/// "Ziyaretciler" — kapi onay akisi (auth.md §4 kesin kurali, UX aynasi):
///   * security: "Yeni ziyaretci" FAB'i (ad + daire no + not) + tenant'in
///     tum kayitlari canli durumla (bekliyor/onaylandi/reddedildi).
///   * resident: KENDI dairesinin kayitlari; BEKLEYEN kayit belirgin kart —
///     Onayla/Reddet butonlari (ilk yanit gecerli; 409'da guncel durum cekilir).
///   * admin/yonetici: salt izleme (gecmis gorunumu).
///
/// [initialVisitorId] push tiklamasindan gelir (?visitor_id=...): liste
/// yuklendiginde ilgili kaydin detayi BIR KEZ otomatik acilir; kayit listede
/// yoksa (yetki disi/silinmis) sessizce listede kalinir. Ileride GSM arama
/// adimi eklendiginde sakinin "gelen cagri" ekrani bu akisin yerini alir —
/// kart/detay yapisi kanaldan bagimsiz tutuldu.
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
      if (mounted) _showDetail(context, v, canAnswer: state.canAnswer);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(visitorsControllerProvider);
    final controller = ref.read(visitorsControllerProvider.notifier);
    ref.listen(visitorsControllerProvider, (_, next) => _maybeOpenInitial(next));
    // Provider zaten yuklu geldiyse (listen tetiklenmez) mevcut durumu isle.
    _maybeOpenInitial(state);

    final bekleyen =
        state.items.where((v) => v.bekliyor).toList(growable: false);
    final gecmis =
        state.items.where((v) => !v.bekliyor).toList(growable: false);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ziyaretçiler'),
          actions: [
            IconButton(
              tooltip: 'Yenile',
              icon: const Icon(Icons.refresh),
              onPressed: state.loading ? null : controller.refresh,
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Bekleyen (${bekleyen.length})'),
              Tab(text: 'Geçmiş (${gecmis.length})'),
            ],
          ),
        ),
        floatingActionButton: state.canRegister
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Yeni ziyaretçi'),
                onPressed: () => _openForm(context),
              )
            : null,
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: controller.refresh,
              child: _Body(
                state: state,
                items: bekleyen,
                emptyText: state.canAnswer
                    ? 'Onay bekleyen ziyaretçiniz yok.'
                    : 'Onay bekleyen ziyaretçi yok.',
              ),
            ),
            RefreshIndicator(
              onRefresh: controller.refresh,
              child: _Body(
                state: state,
                items: gecmis,
                emptyText: 'Henüz sonuçlanan ziyaretçi kaydı yok.',
              ),
            ),
          ],
        ),
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
          content: Text('Ziyaretçi kaydedildi — daire sakinlerine bildirildi ✓'),
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

  final VisitorsState state;

  /// Bu sekmenin kayitlari (Bekleyen / Gecmis).
  final List<Visitor> items;
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
      itemBuilder: (context, i) => _VisitorCard(
        visitor: items[i],
        canAnswer: state.canAnswer,
      ),
    );
  }
}

/// Durum rozeti — renk kodu: bekliyor=turuncu, onaylandi=yesil,
/// reddedildi=kirmizi.
class _DurumChip extends StatelessWidget {
  const _DurumChip({required this.durum});

  final VisitorDurum durum;

  Color get _color => switch (durum) {
        VisitorDurum.bekliyor => Colors.orange,
        VisitorDurum.onaylandi => Colors.green,
        VisitorDurum.reddedildi => Colors.red,
        VisitorDurum.unknown => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        durum.label,
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _VisitorCard extends ConsumerWidget {
  const _VisitorCard({required this.visitor, required this.canAnswer});

  final Visitor visitor;
  final bool canAnswer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = visitor;
    // Sakin icin BEKLEYEN kayit belirgin: kapida biri cevap bekliyor.
    final vurgulu = v.bekliyor && canAnswer;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: vurgulu
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.orange.shade400, width: 2),
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context, v, canAnswer: canAnswer),
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
                  _DurumChip(durum: v.durum),
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
              if (!v.bekliyor) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      v.durum == VisitorDurum.onaylandi
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      size: 16,
                      color: v.durum == VisitorDurum.onaylandi
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${v.durum.label}'
                        '${v.yanitlayanAd != null ? ' — ${v.yanitlayanAd}' : ''}'
                        '${v.yanitZamani != null ? ' · ${_fmtDateTime(v.yanitZamani!.toLocal())}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              if (vurgulu) ...[
                const SizedBox(height: 12),
                _AnswerButtons(visitorId: v.id),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Onayla/Reddet butonlari — sakinin bekleyen kartinda ve detayda kullanilir.
/// Yanit sirasinda kilitlenir; 409 (baska sakin once yanitladi) mesaji
/// SnackBar'da gosterilir, liste guncel duruma tazelenir (controller).
class _AnswerButtons extends ConsumerStatefulWidget {
  const _AnswerButtons({required this.visitorId, this.onAnswered});

  final String visitorId;

  /// Detay sheet'inden cagrildiginda yanit sonrasi sheet'i kapatmak icin.
  final VoidCallback? onAnswered;

  @override
  ConsumerState<_AnswerButtons> createState() => _AnswerButtonsState();
}

class _AnswerButtonsState extends ConsumerState<_AnswerButtons> {
  bool _busy = false;

  Future<void> _answer(bool onayla) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(visitorsControllerProvider.notifier)
          .answer(widget.visitorId, onayla: onayla);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            onayla ? 'Ziyaretçi onaylandı ✓' : 'Ziyaretçi reddedildi',
          ),
        ),
      );
      widget.onAnswered?.call();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      widget.onAnswered?.call();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Yanıt gönderilemedi. Tekrar deneyin.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            icon: const Icon(Icons.check),
            label: const Text('Onayla'),
            onPressed: _busy ? null : () => _answer(true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.close),
            label: const Text('Reddet'),
            onPressed: _busy ? null : () => _answer(false),
          ),
        ),
      ],
    );
  }
}

/// Detay alt sayfasi — push tiklamasi ve kart dokunusuyla acilir. Sakin +
/// bekleyen kayitta Onayla/Reddet burada da sunulur (belirgin akis).
void _showDetail(BuildContext context, Visitor v, {required bool canAnswer}) {
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
                _DurumChip(durum: v.durum),
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
            if (!v.bekliyor) ...[
              const SizedBox(height: 4),
              Text(
                'Sonuç: ${v.durum.label}'
                '${v.yanitlayanAd != null ? ' — ${v.yanitlayanAd}' : ''}'
                '${v.yanitZamani != null ? ' · ${_fmtDateTime(v.yanitZamani!.toLocal())}' : ''}',
              ),
            ],
            if (v.bekliyor && canAnswer) ...[
              const SizedBox(height: 20),
              _AnswerButtons(
                visitorId: v.id,
                onAnswered: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Yeni ziyaretci formu (yalniz guvenlik): ad + daire no + opsiyonel not.
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
