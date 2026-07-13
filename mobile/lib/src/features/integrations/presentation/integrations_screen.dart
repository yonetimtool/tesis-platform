import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../domain/integration_models.dart';
import 'integrations_controller.dart';

/// Entegrasyon yonetim ekrani (C1b) — YONETICI (mobil). Liste + ekle/duzenle/
/// sil/aktif + "Test" (tetikler; SSRF sonucu gosterilir). admin panelden yonetir.
class IntegrationsScreen extends ConsumerWidget {
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(integrationsControllerProvider);
    final controller = ref.read(integrationsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Entegrasyonlar')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Yeni'),
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
                  if (state.errorMessage != null)
                    Card(
                      color: Colors.red.withValues(alpha: 0.08),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  if (state.items.isEmpty && state.errorMessage == null)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Entegrasyon yok. "Yeni" ile bir dış sistem (megafon/'
                          'akıllı ev/webhook) ekleyin.',
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      final r = await ref
          .read(integrationsControllerProvider.notifier)
          .trigger(widget.integration.id);
      if (mounted) setState(() => _result = r);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _result = TriggerResult(ok: false, error: e.message));
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: Text('"${widget.integration.ad}" entegrasyonu silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
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
          SnackBar(content: Text('Silinemedi: ${e.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.integration;
    final r = _result;
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
                  it.aktif ? 'aktif' : 'pasif',
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
              'Kimlik: ${it.authType}${it.authSecretSet ? ' 🔒' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (r != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  r.ok
                      ? '✓ Başarılı (${r.status ?? '—'})'
                      : '✗ ${r.error ?? 'Başarısız'}${r.status != null ? ' (${r.status})' : ''}',
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
                  label: const Text('Test'),
                  onPressed: _testing ? null : _test,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Düzenle'),
                  onPressed: () =>
                      IntegrationsScreen._openForm(context, ref, edit: it),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Sil'),
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
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Kaydedilemedi. Tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.edit != null;
    final presets = ref.watch(integrationsControllerProvider).presets;
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
                editing ? 'Entegrasyon düzenle' : 'Yeni entegrasyon',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (!editing && presets.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Hazır şablon (preset)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final p in presets)
                      DropdownMenuItem(value: p.key, child: Text(p.key)),
                  ],
                  onChanged: (v) {
                    final p = presets.where((x) => x.key == v).firstOrNull;
                    if (p != null) _applyPreset(p);
                  },
                ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _ad,
                decoration: const InputDecoration(
                  labelText: 'Ad',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ad gerekli' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _channel,
                decoration: const InputDecoration(
                  labelText: 'Kanal tipi',
                  border: OutlineInputBorder(),
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
                decoration: const InputDecoration(
                  labelText: 'Endpoint URL (http/https)',
                  hintText: 'https://...',
                  helperText: 'İç/özel adresler tetikte engellenir',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (!t.startsWith('http://') && !t.startsWith('https://')) {
                    return 'http(s) ile başlamalı';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: const InputDecoration(
                  labelText: 'HTTP metodu',
                  border: OutlineInputBorder(),
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
                decoration: const InputDecoration(
                  labelText: 'Kimlik doğrulama',
                  border: OutlineInputBorder(),
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
                  labelText: 'Sır (bearer token / API key)',
                  helperText: editing && widget.edit!.authSecretSet
                      ? 'Kayıtlı — değiştirmek için yeni değer girin'
                      : 'Yazma-özel; sunucudan asla dönmez',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _template,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Payload şablonu',
                  helperText: '{{message}} / {{title}} yer tutucuları',
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif'),
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
                  child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
