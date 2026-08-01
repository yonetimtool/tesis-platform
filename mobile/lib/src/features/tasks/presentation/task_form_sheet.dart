import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/eksik_veri_uyarisi.dart';
import '../../auth/domain/user_role.dart';
import '../../checkpoints/data/checkpoint_api.dart';
import '../data/task_api.dart';
import '../data/task_category_api.dart';
import '../domain/task_category_models.dart';
import '../domain/task_models.dart';
import '../../auth/presentation/rol_adi.dart';
import 'tasks_controller.dart';
import '../../../core/error/akis_hatasi.dart';

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
  String? _atananUserId;
  String? _kategoriId;
  String? _checkpointId;
  late bool _fotoZorunlu;
  late bool _aktif;

  bool _saving = false;
  String? _error;

  /// Denetleyici/`setState` yollarinda kullanilan yerellestirme (build disi).
  AppLocalizations get _l10n => AppLocalizations.of(context);

  /// Atanabilir personel (bir kez yuklenir); null → yukleniyor.
  List<AssignableUser>? _personel;
  String? _personelError;

  /// Aktif gorev kategorileri (A6; bir kez yuklenir); null → yukleniyor.
  List<TaskCategory>? _kategoriler;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _adCtrl = TextEditingController(text: t?.ad);
    _aciklamaCtrl = TextEditingController(text: t?.aciklama);
    _periyotCtrl = TextEditingController(
      text: t?.periyotDakika == null ? '' : '${t!.periyotDakika}',
    );
    _atananUserId = t?.atananUserId;
    _kategoriId = t?.kategoriId;
    _checkpointId = t?.checkpointId;
    _fotoZorunlu = t?.fotoZorunlu ?? false;
    _aktif = t?.aktif ?? true;
    _loadPersonel();
    _loadKategoriler();
  }

  Future<void> _loadKategoriler() async {
    try {
      final list = await ref.read(taskCategoryApiProvider).fetchAll();
      if (!mounted) return;
      setState(() {
        _kategoriler = list;
        // Duzenlemede secili kategori pasiflestiyse listede olmayabilir —
        // secimi koru ama secenege "(silinmis)" olarak ekle.
        if (_kategoriId != null && !list.any((k) => k.id == _kategoriId)) {
          _kategoriler = [
            ...list,
            // Ad BOS: silinmis kategori etiketi cizim aninda cozulur
            // (l10n.gorevKategoriSilinmis) — domain metin tasimaz.
            TaskCategory(id: _kategoriId!, ad: '', aktif: false),
          ];
        }
      });
    } on ApiException catch (_) {
      if (!mounted) return;
      setState(() => _kategoriler = const []);
    }
  }

  Future<void> _loadPersonel() async {
    try {
      final users = await ref.read(taskApiProvider).fetchAssignableUsers();
      if (!mounted) return;
      setState(() {
        _personel = users;
        // Duzenlemede atanan kisi pasiflestiyse listede olmayabilir —
        // secimi koru ama secenege "(pasif/bilinmiyor)" olarak ekle.
        if (_atananUserId != null && !users.any((u) => u.id == _atananUserId)) {
          _personel = [
            ...users,
            // Ad BOS: "listede degil" etiketi cizim aninda cozulur.
            AssignableUser(id: _atananUserId!, ad: '', role: ''),
          ];
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _personel = const [];
        _personelError = apiHataMetni(_l10n, e);
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
      ad: _adCtrl.text.trim(),
      aciklama: _aciklamaCtrl.text.trim().isEmpty
          ? null
          : _aciklamaCtrl.text.trim(),
      atananUserId: _atananUserId,
      kategoriId: _kategoriId,
      checkpointId: _checkpointId,
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
          _error = apiHataMetni(_l10n, e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _l10n.ortakBeklenmeyenHata;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final editing = widget.task != null;
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
                editing ? l10n.gorevDuzenleBaslik : l10n.gorevYeni,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              // Gorev TIPI = yonetici-tanimli kategori; "Diğer" = tipsiz.
              // Sabit tip listesi kaldirildi (yonetici kendi tiplerini tanimlar).
              if (_kategoriler == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      // Uzun cevirilerde (ar/de) satir tasmasin.
                      Expanded(child: Text(l10n.gorevTipleriYukleniyor)),
                    ],
                  ),
                )
              else ...[
                DropdownButtonFormField<String?>(
                  initialValue: _kategoriId,
                  isExpanded: true, // uzun kategori adi/ceviri tasmasin
                  decoration: InputDecoration(
                    labelText: l10n.gorevTipi,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(l10n.gorevKategoriDiger),
                    ),
                    for (final k in _kategoriler!)
                      DropdownMenuItem<String?>(
                        value: k.id,
                        child: Text(
                          k.ad.isEmpty ? l10n.gorevKategoriSilinmis : k.ad,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _kategoriId = v),
                ),
                if (_kategoriler!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      l10n.gorevTipiYokUyari,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              TextFormField(
                controller: _adCtrl,
                decoration: InputDecoration(
                  labelText: l10n.gorevAdi,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.gorevAdiZorunlu
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _aciklamaCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.gorevAciklamaOpsiyonel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              if (_personel == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l10n.gorevPersonelYukleniyor)),
                    ],
                  ),
                )
              else ...[
                DropdownButtonFormField<String?>(
                  initialValue: _atananUserId,
                  isExpanded: true, // "ad (rol)" + uzun ceviri tasmasin
                  decoration: InputDecoration(
                    labelText: l10n.gorevAtananPersonel,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(l10n.gorevAtanmamisHavuz),
                    ),
                    for (final u in _personel!)
                      DropdownMenuItem<String?>(
                        value: u.id,
                        child: Text(
                          u.role.isEmpty
                              ? (u.ad.isEmpty
                                    ? l10n.gorevAtananListedeDegil
                                    : u.ad)
                              : '${u.ad} '
                                    '(${rolAdi(l10n, UserRole.fromClaim(u.role))})',
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
                      l10n.gorevPersonelAlinamadi(_personelError!),
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              // NFC kontrol noktasi (opsiyonel): baglanirsa gorev, atanan saha
              // calisani tarafindan ETIKET OKUTULARAK tamamlanir (backend zorlar).
              Builder(
                builder: (context) {
                  // (P59) HATA AYRI OKUNUR: `.value ?? []` bir hatayi da
                  // "hic kayit yok"a cevirirdi ve kullanici noktayi neden
                  // secemedigini anlamazdi.
                  final durum = ref.watch(checkpointsProvider);
                  final all = durum.value ?? const <Checkpoint>[];
                  final items = all.where((c) => c.aktif).toList();
                  // Secili nokta pasiflestiyse listede olmayabilir -> koru.
                  if (_checkpointId != null &&
                      !items.any((c) => c.id == _checkpointId)) {
                    final sel = all.where((c) => c.id == _checkpointId);
                    if (sel.isNotEmpty) items.add(sel.first);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EksikVeriUyarisi(goster: durum.hasError),
                      DropdownButtonFormField<String?>(
                        initialValue: items.any((c) => c.id == _checkpointId)
                            ? _checkpointId
                            : null,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.gorevKontrolNoktasiOpsiyonel,
                          helperText: l10n.gorevKontrolNoktasiYardim,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(l10n.gorevNfcYok),
                          ),
                          for (final c in items)
                            DropdownMenuItem<String?>(
                              value: c.id,
                              child: Text(
                                c.ad,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => _checkpointId = v),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _periyotCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.gorevPeriyotDakika,
                  helperText: l10n.gorevPeriyotYardim,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  final n = int.tryParse(t);
                  return (n == null || n <= 0) ? l10n.gorevPozitifSayi : null;
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.gorevFotoKanitiZorunlu),
                subtitle: Text(l10n.gorevFotoKanitiZorunluAlt),
                value: _fotoZorunlu,
                onChanged: (v) => setState(() => _fotoZorunlu = v),
              ),
              if (editing)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.cipAktif),
                  subtitle: Text(l10n.gorevPasifAciklama),
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
                        ? l10n.ortakKaydediliyor
                        : editing
                        ? l10n.ortakKaydet
                        : l10n.ortakOlustur,
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
