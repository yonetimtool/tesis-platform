import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../domain/integration_models.dart';
import '../../../core/ui/merkez_diyalog.dart';
import 'integrations_controller.dart';

/// Entegrasyon yonetim ekrani (C1b) — YONETICI (mobil). Liste + ekle/duzenle/
/// sil/aktif + "Test" (tetikler; SSRF sonucu gosterilir). admin panelden yonetir.
class IntegrationsScreen extends ConsumerWidget {
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(integrationsControllerProvider);
    final controller = ref.read(integrationsControllerProvider.notifier);
    final l10n = context.l10n;
    final hata = akisHatasiCoz(l10n, state.hataKimligi, state.errorMessage);

    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.modulEntegrasyonlar, context.dilKodu)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.entegYeni),
        onPressed: () => _openForm(context, ref),
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: state.loading && state.items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (hata != null)
                    Card(
                      color: Colors.red.withValues(alpha: 0.08),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          hata,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  if (state.items.isEmpty && hata == null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.entegYokMesaj,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  for (final it in state.items)
                    _IntegrationCard(integration: it),
                ],
              ),
      ),
    );
  }

  static Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    Integration? edit,
  }) {
    return merkezSayfaAc<void>(
      context,
      builder: (_) => _IntegrationForm(edit: edit),
    );
  }
}

class _IntegrationCard extends ConsumerStatefulWidget {
  const _IntegrationCard({required this.integration});

  final Integration integration;

  @override
  ConsumerState<_IntegrationCard> createState() => _IntegrationCardState();
}

class _IntegrationCardState extends ConsumerState<_IntegrationCard> {
  TriggerResult? _result;
  bool _testing = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  Future<void> _test() async {
    setState(() => _testing = true);
    // Test yuku DIS sisteme gider; metni yoneticinin dilinde uretiriz
    // (denetleyicide `BuildContext` yok — cizimden gecirilir).
    final mesaj = _l10n.entegTestMesaji;
    final baslik = _l10n.entegTest;
    try {
      final r = await ref
          .read(integrationsControllerProvider.notifier)
          .trigger(widget.integration.id, mesaj: mesaj, baslik: baslik);
      if (mounted) setState(() => _result = r);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _result = TriggerResult(ok: false, error: apiHataMetni(_l10n, e)));
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _delete() async {
    final l10n = _l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.entegSilOnay),
        content: Text(l10n.entegSilGovde(widget.integration.ad)),
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
    if (ok != true) return;
    try {
      await ref
          .read(integrationsControllerProvider.notifier)
          .delete(widget.integration.id);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.entegSilinemedi(apiHataMetni(l10n, e)))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.integration;
    final r = _result;
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    it.ad,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  it.aktif ? l10n.entegAktifKisa : l10n.entegPasifKisa,
                  style: TextStyle(
                    color: it.aktif ? Colors.green : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${it.channelType} · ${it.httpMethod} ${it.endpointUrl}',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              l10n.entegKimlikSatir(
                  it.authType, it.authSecretSet ? ' 🔒' : ''),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (r != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  r.ok
                      ? l10n.entegTestBasarili('${r.status ?? '—'}')
                      : l10n.entegTestBasarisiz(
                          r.error ?? l10n.entegBasarisiz,
                          r.status != null ? ' (${r.status})' : '',
                        ),
                  style: TextStyle(
                    color: r.ok ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: _testing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow, size: 18),
                  label: Text(l10n.entegTest),
                  onPressed: _testing ? null : _test,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(l10n.ortakDuzenle),
                  onPressed: () =>
                      IntegrationsScreen._openForm(context, ref, edit: it),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(l10n.ortakSil),
                  onPressed: _delete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IntegrationForm extends ConsumerStatefulWidget {
  const _IntegrationForm({this.edit});

  final Integration? edit;

  @override
  ConsumerState<_IntegrationForm> createState() => _IntegrationFormState();
}

class _IntegrationFormState extends ConsumerState<_IntegrationForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ad;
  late final TextEditingController _url;
  late final TextEditingController _secret;
  late final TextEditingController _template;
  String _channel = 'webhook';
  String _method = 'POST';
  String _authType = 'none';
  bool _aktif = true;
  bool _saving = false;
  String? _error;

  static const _channels = ['webhook', 'megaphone', 'smarthome'];
  static const _methods = ['POST', 'PUT', 'PATCH', 'GET'];
  static const _authTypes = ['none', 'bearer', 'api_key'];

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _ad = TextEditingController(text: e?.ad);
    _url = TextEditingController(text: e?.endpointUrl);
    _secret = TextEditingController();
    _template = TextEditingController(text: e?.payloadTemplate);
    _channel = e?.channelType ?? 'webhook';
    _method = e?.httpMethod ?? 'POST';
    _authType = e?.authType ?? 'none';
    _aktif = e?.aktif ?? true;
  }

  @override
  void dispose() {
    _ad.dispose();
    _url.dispose();
    _secret.dispose();
    _template.dispose();
    super.dispose();
  }

  void _applyPreset(IntegrationPreset p) {
    setState(() {
      _channel = p.channelType;
      _method = p.httpMethod;
      _template.text = p.payloadTemplate;
    });
  }

  Future<void> _submit() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final draft = IntegrationDraft(
      ad: _ad.text.trim(),
      channelType: _channel,
      endpointUrl: _url.text.trim(),
      httpMethod: _method,
      authType: _authType,
      authSecret: _secret.text.isEmpty ? null : _secret.text,
      payloadTemplate: _template.text,
      aktif: _aktif,
    );
    try {
      final ctrl = ref.read(integrationsControllerProvider.notifier);
      if (widget.edit == null) {
        await ctrl.create(draft);
      } else {
        await ctrl.update(widget.edit!.id, draft);
      }
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = apiHataMetni(context.l10n, e));
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = AppLocalizations.of(context).devriyeKaydedilemedi);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.edit != null;
    final presets = ref.watch(integrationsControllerProvider).presets;
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editing ? l10n.entegDuzenleBaslik : l10n.entegYeniBaslik,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (!editing && presets.isNotEmpty)
                DropdownButtonFormField<String>(
                  // Uzun teknik degerler ("megaphone_generic") dar ekranda
                  // satiri tasiriyordu (tur 9 ay secici emsali).
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.entegPreset,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final p in presets)
                      DropdownMenuItem(
                        value: p.key,
                        child: Text(p.key, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) {
                    final p = presets.where((x) => x.key == v).firstOrNull;
                    if (p != null) _applyPreset(p);
                  },
                ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _ad,
                decoration: InputDecoration(
                  labelText: l10n.kameraAd,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.ortakAdGerekli : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _channel,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.entegKanalTipi,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final c in _channels)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _channel = v ?? _channel),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _url,
                decoration: InputDecoration(
                  labelText: l10n.entegUrl,
                  hintText: 'https://...',
                  helperText: l10n.entegUrlHelper,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (!t.startsWith('http://') && !t.startsWith('https://')) {
                    return l10n.entegUrlHata;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _method,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.entegHttpMetodu,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final m in _methods)
                    DropdownMenuItem(value: m, child: Text(m)),
                ],
                onChanged: (v) => setState(() => _method = v ?? _method),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _authType,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.entegKimlikDogrulama,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final a in _authTypes)
                    DropdownMenuItem(value: a, child: Text(a)),
                ],
                onChanged: (v) => setState(() => _authType = v ?? _authType),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _secret,
                obscureText: true,
                enabled: _authType != 'none',
                decoration: InputDecoration(
                  labelText: l10n.entegSir,
                  helperText: editing && widget.edit!.authSecretSet
                      ? l10n.entegSirKayitli
                      : l10n.entegSirYazmaOzel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _template,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.entegPayload,
                  // Teknik yer tutucular ARGUMAN olarak girer: ICU'da '{{'
                  // kacisi kirilgan.
                  helperText:
                      l10n.entegPayloadHelper('{{message}} / {{title}}'),
                  border: const OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.cipAktif),
                value: _aktif,
                onChanged: (v) => setState(() => _aktif = v),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: Text(
                      _saving ? l10n.ortakKaydediliyor : l10n.ortakKaydet),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
