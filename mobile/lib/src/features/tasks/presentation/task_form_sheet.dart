import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/task_api.dart';
import '../domain/task_models.dart';
import 'task_tip_style.dart';
import 'tasks_controller.dart';

/// Gorev olustur/duzenle formu (bottom sheet) — admin + yonetici.
/// Atama secicisi YALNIZ aktif saha personelini listeler (security +
/// tesis_gorevlisi); backend yonetici icin bunu zaten zorlar (422).
/// Kaydedince `true` ile kapanir (cagiran snackbar gosterir).
Future<bool?> showTaskFormSheet(BuildContext context, {Task? edit}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TaskFormSheet(task: edit),
  );
}

class _TaskFormSheet extends ConsumerStatefulWidget {
  const _TaskFormSheet({this.task});

  /// null → yeni gorev; dolu → duzenleme.
  final Task? task;

  @override
  ConsumerState<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends ConsumerState<_TaskFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _adCtrl;
  late final TextEditingController _aciklamaCtrl;
  late final TextEditingController _periyotCtrl;
  late TaskTip _tip;
  String? _atananUserId;
  late bool _fotoZorunlu;
  late bool _aktif;

  bool _saving = false;
  String? _error;

  /// Atanabilir personel (bir kez yuklenir); null → yukleniyor.
  List<AssignableUser>? _personel;
  String? _personelError;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _adCtrl = TextEditingController(text: t?.ad);
    _aciklamaCtrl = TextEditingController(text: t?.aciklama);
    _periyotCtrl = TextEditingController(
      text: t?.periyotDakika == null ? '' : '${t!.periyotDakika}',
    );
    _tip = t?.tip ?? TaskTip.temizlik;
    _atananUserId = t?.atananUserId;
    _fotoZorunlu = t?.fotoZorunlu ?? false;
    _aktif = t?.aktif ?? true;
    _loadPersonel();
  }

  Future<void> _loadPersonel() async {
    try {
      final users = await ref.read(taskApiProvider).fetchAssignableUsers();
      if (!mounted) return;
      setState(() {
        _personel = users;
        // Duzenlemede atanan kisi pasiflestiyse listede olmayabilir —
        // secimi koru ama secenege "(pasif/bilinmiyor)" olarak ekle.
        if (_atananUserId != null &&
            !users.any((u) => u.id == _atananUserId)) {
          _personel = [
            ...users,
            AssignableUser(
              id: _atananUserId!,
              ad: 'Atanan kullanici (listede degil)',
              role: '',
            ),
          ];
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _personel = const [];
        _personelError = e.message;
      });
    }
  }

  @override
  void dispose() {
    _adCtrl.dispose();
    _aciklamaCtrl.dispose();
    _periyotCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final periyotText = _periyotCtrl.text.trim();
    final draft = TaskDraft(
      tip: _tip,
      ad: _adCtrl.text.trim(),
      aciklama: _aciklamaCtrl.text.trim().isEmpty
          ? null
          : _aciklamaCtrl.text.trim(),
      atananUserId: _atananUserId,
      periyotDakika: periyotText.isEmpty ? null : int.parse(periyotText),
      fotoZorunlu: _fotoZorunlu,
      aktif: _aktif,
    );
    final controller = ref.read(tasksControllerProvider.notifier);
    try {
      if (widget.task == null) {
        await controller.createTask(draft);
      } else {
        await controller.updateTask(widget.task!.id, draft);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Beklenmeyen bir hata olustu. Lutfen tekrar deneyin.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.task != null;
    const tipler = [
      TaskTip.temizlik,
      TaskTip.kontrol,
      TaskTip.ilaclama,
      TaskTip.bakim,
      TaskTip.peyzaj,
      TaskTip.diger,
    ];
    return Padding(
      // Klavye acildiginda formun gorunur kalmasi icin.
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
                editing ? 'Gorev duzenle' : 'Yeni gorev',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TaskTip>(
                initialValue: _tip,
                decoration: const InputDecoration(
                  labelText: 'Tip',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final tip in tipler)
                    DropdownMenuItem(
                      value: tip,
                      child: Row(
                        children: [
                          Icon(
                            taskTipStyle(tip).icon,
                            size: 18,
                            color: taskTipStyle(tip).color,
                          ),
                          const SizedBox(width: 8),
                          Text(taskTipStyle(tip).label),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _tip = v ?? _tip),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _adCtrl,
                decoration: const InputDecoration(
                  labelText: 'Gorev adi',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Gorev adi zorunludur'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _aciklamaCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Aciklama (opsiyonel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              if (_personel == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Personel listesi yukleniyor...'),
                    ],
                  ),
                )
              else ...[
                DropdownButtonFormField<String?>(
                  initialValue: _atananUserId,
                  decoration: const InputDecoration(
                    labelText: 'Atanan personel',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— atanmamis (havuz gorevi) —'),
                    ),
                    for (final u in _personel!)
                      DropdownMenuItem<String?>(
                        value: u.id,
                        child: Text(
                          u.role.isEmpty
                              ? u.ad
                              : '${u.ad} (${u.role == 'security' ? 'Guvenlik' : 'Tesis Gorevlisi'})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _atananUserId = v),
                ),
                if (_personelError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Personel listesi alinamadi: $_personelError',
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              TextFormField(
                controller: _periyotCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Periyot dakika (opsiyonel)',
                  helperText: 'Periyodik gorevler icin; bos = tek seferlik',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  final n = int.tryParse(t);
                  return (n == null || n <= 0)
                      ? 'Pozitif tam sayi girin'
                      : null;
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Foto kaniti zorunlu'),
                subtitle: const Text(
                  'Tamamlama foto olmadan kabul edilmez',
                ),
                value: _fotoZorunlu,
                onChanged: (v) => setState(() => _fotoZorunlu = v),
              ),
              if (editing)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktif'),
                  subtitle: const Text('Pasif gorev listede gorunmez'),
                  value: _aktif,
                  onChanged: (v) => setState(() => _aktif = v),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _saving
                        ? 'Kaydediliyor...'
                        : editing
                            ? 'Kaydet'
                            : 'Olustur',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
