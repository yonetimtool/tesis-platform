import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../domain/rezervasyon_models.dart';
import 'rezervasyon_controller.dart';

/// "Rezervasyon" — ortak alan rezervasyonu (auth.md §4 kesin kurali, UX aynasi):
///   * resident: aktif alanlari gorur, "Yeni rezervasyon" ile slot talep eder
///     (alan + tarih + saat araligi + kisi + not); kendi dairesinin taleplerini
///     durumlariyla izler. Cakisma 409'u formda acikca gosterilir.
///   * admin/yonetici: alan olustur/duzenle/pasiflestir; bekleyen talepleri
///     Onayla/Reddet (cakisan onay 409 — DB kisiti); "Takvim" sekmesi alan
///     bazli ONAYLI slotlarin gun-sirali listesi (gun gorunumu).
///
/// [initialRezervasyonId] push tiklamasindan gelir (?rezervasyon_id=...):
/// liste yuklendiginde ilgili kaydin detayi BIR KEZ otomatik acilir; kayit
/// listede yoksa (yetki disi/silinmis) sessizce listede kalinir.
class RezervasyonScreen extends ConsumerStatefulWidget {
  const RezervasyonScreen({super.key, this.initialRezervasyonId});

  final String? initialRezervasyonId;

  @override
  ConsumerState<RezervasyonScreen> createState() => _RezervasyonScreenState();
}

class _RezervasyonScreenState extends ConsumerState<RezervasyonScreen> {
  bool _initialHandled = false;

  void _maybeOpenInitial(RezervasyonState state) {
    if (_initialHandled || widget.initialRezervasyonId == null) return;
    if (state.loading) return;
    _initialHandled = true;
    Rezervasyon? hedef;
    for (final r in state.items) {
      if (r.id == widget.initialRezervasyonId) {
        hedef = r;
        break;
      }
    }
    if (hedef == null) return; // listede yok — sessizce listede kal
    final r = hedef;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showDetail(context, r, canDecide: state.canDecide);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rezervasyonControllerProvider);
    final controller = ref.read(rezervasyonControllerProvider.notifier);
    ref.listen(
        rezervasyonControllerProvider, (_, next) => _maybeOpenInitial(next));
    // Provider zaten yuklu geldiyse (listen tetiklenmez) mevcut durumu isle.
    _maybeOpenInitial(state);

    final bekleyen =
        state.items.where((r) => r.bekliyor).toList(growable: false);
    final sonuclanan =
        state.items.where((r) => !r.bekliyor).toList(growable: false);
    // "Takvim": ONAYLI slotlar gun + saat sirali (gun gorunumu listesi).
    final onayli = state.items
        .where((r) => r.durum == RezervasyonDurum.onaylandi)
        .toList(growable: false)
      ..sort((a, b) {
        final gun = a.tarih.compareTo(b.tarih);
        return gun != 0 ? gun : a.baslangic.compareTo(b.baslangic);
      });

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rezervasyon'),
          actions: [
            IconButton(
              tooltip: 'Yenile',
              icon: const Icon(Icons.refresh),
              onPressed: state.loading ? null : controller.refresh,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Bekleyen (${bekleyen.length})'),
              Tab(text: 'Sonuclanan (${sonuclanan.length})'),
              Tab(text: 'Takvim (${onayli.length})'),
              Tab(text: 'Alanlar (${state.alanlar.length})'),
            ],
          ),
        ),
        floatingActionButton: _fab(context, state),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: controller.refresh,
              child: _ReservationList(
                state: state,
                items: bekleyen,
                emptyText: state.canRequest
                    ? 'Bekleyen talebiniz yok. "Yeni rezervasyon" ile '
                        'ortak alan icin slot isteyin.'
                    : 'Bekleyen talep yok.',
              ),
            ),
            RefreshIndicator(
              onRefresh: controller.refresh,
              child: _ReservationList(
                state: state,
                items: sonuclanan,
                emptyText: 'Henuz sonuclanan talep yok.',
              ),
            ),
            RefreshIndicator(
              onRefresh: controller.refresh,
              child: _ReservationList(
                state: state,
                items: onayli,
                emptyText: 'Onayli rezervasyon yok.',
                takvim: true,
              ),
            ),
            RefreshIndicator(
              onRefresh: controller.refresh,
              child: _AreaList(state: state),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _fab(BuildContext context, RezervasyonState state) {
    if (state.canRequest) {
      return FloatingActionButton.extended(
        icon: const Icon(Icons.event_available_outlined),
        label: const Text('Yeni rezervasyon'),
        onPressed: state.aktifAlanlar.isEmpty
            ? null
            : () => _openRequestForm(context, state.aktifAlanlar),
      );
    }
    if (state.canManageAreas) {
      return FloatingActionButton.extended(
        icon: const Icon(Icons.add_home_outlined),
        label: const Text('Yeni alan'),
        onPressed: () => _openAreaForm(context),
      );
    }
    return null;
  }

  Future<void> _openRequestForm(
      BuildContext context, List<OrtakAlan> alanlar) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RequestForm(alanlar: alanlar),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Talebiniz iletildi — yonetim onayi bekleniyor ✓')),
      );
    }
  }

  Future<void> _openAreaForm(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AreaForm(),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ortak alan eklendi ✓')),
      );
    }
  }
}

// --------------------------- rezervasyon listesi --------------------------- //
class _ReservationList extends ConsumerWidget {
  const _ReservationList({
    required this.state,
    required this.items,
    required this.emptyText,
    this.takvim = false,
  });

  final RezervasyonState state;
  final List<Rezervasyon> items;
  final String emptyText;

  /// Takvim gorunumu: gun basliklariyla gruplu (onayli slotlar).
  final bool takvim;

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
    if (!takvim) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: items.length,
        itemBuilder: (context, i) => _ReservationCard(
          rezervasyon: items[i],
          canDecide: state.canDecide,
        ),
      );
    }
    // Takvim: gun basligi + o gunun slotlari (items zaten gun+saat sirali).
    final children = <Widget>[];
    String? gun;
    for (final r in items) {
      if (r.tarih != gun) {
        gun = r.tarih;
        children.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            gun,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ));
      }
      children.add(
        _ReservationCard(rezervasyon: r, canDecide: state.canDecide),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
      children: children,
    );
  }
}

/// Durum rozeti — bekliyor=turuncu, onaylandi=yesil, reddedildi=kirmizi.
class _DurumChip extends StatelessWidget {
  const _DurumChip({required this.durum});

  final RezervasyonDurum durum;

  Color get _color => switch (durum) {
        RezervasyonDurum.bekliyor => Colors.orange,
        RezervasyonDurum.onaylandi => Colors.green,
        RezervasyonDurum.reddedildi => Colors.red,
        RezervasyonDurum.unknown => Colors.grey,
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

class _ReservationCard extends ConsumerWidget {
  const _ReservationCard({required this.rezervasyon, required this.canDecide});

  final Rezervasyon rezervasyon;
  final bool canDecide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = rezervasyon;
    // Yonetim icin BEKLEYEN talep belirgin: karar kuyrugu.
    final vurgulu = r.bekliyor && canDecide;
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
        onTap: () => _showDetail(context, r, canDecide: canDecide),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_outlined, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      r.alanAd ?? 'Ortak alan',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  _DurumChip(durum: r.durum),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${r.tarih} · ${r.baslangic}-${r.bitis} · ${r.kisiSayisi} kisi'
                '${r.unitNo != null ? ' · Daire: ${r.unitNo}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (r.notlar != null && r.notlar!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(r.notlar!, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              if (!r.bekliyor) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      r.durum == RezervasyonDurum.onaylandi
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      size: 16,
                      color: r.durum == RezervasyonDurum.onaylandi
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${r.durum.label}'
                        '${r.onaylayanAd != null ? ' — ${r.onaylayanAd}' : ''}'
                        '${r.kararZamani != null ? ' · ${_fmtDateTime(r.kararZamani!.toLocal())}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              if (vurgulu) ...[
                const SizedBox(height: 12),
                _DecideButtons(rezervasyonId: r.id),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Onayla/Reddet butonlari — yonetimin bekleyen kartinda ve detayda.
/// Cakisma 409'u (DB kisiti) mesajiyla SnackBar'da gosterilir; liste
/// guncel duruma tazelenir (controller).
class _DecideButtons extends ConsumerStatefulWidget {
  const _DecideButtons({required this.rezervasyonId, this.onDecided});

  final String rezervasyonId;

  /// Detay sheet'inden cagrildiginda karar sonrasi sheet'i kapatmak icin.
  final VoidCallback? onDecided;

  @override
  ConsumerState<_DecideButtons> createState() => _DecideButtonsState();
}

class _DecideButtonsState extends ConsumerState<_DecideButtons> {
  bool _busy = false;

  Future<void> _decide(bool onayla) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(rezervasyonControllerProvider.notifier)
          .decide(widget.rezervasyonId, onayla: onayla);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            onayla ? 'Rezervasyon onaylandi ✓' : 'Rezervasyon reddedildi',
          ),
        ),
      );
      widget.onDecided?.call();
    } on ApiException catch (e) {
      // 409: cakisan onay (DB kisiti) veya zaten karara baglandi.
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      widget.onDecided?.call();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Karar gonderilemedi. Tekrar deneyin.')),
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
            onPressed: _busy ? null : () => _decide(true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.close),
            label: const Text('Reddet'),
            onPressed: _busy ? null : () => _decide(false),
          ),
        ),
      ],
    );
  }
}

/// Detay alt sayfasi — push tiklamasi ve kart dokunusuyla acilir.
void _showDetail(BuildContext context, Rezervasyon r,
    {required bool canDecide}) {
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
                const Icon(Icons.event_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.alanAd ?? 'Ortak alan',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _DurumChip(durum: r.durum),
              ],
            ),
            const SizedBox(height: 12),
            Text('Tarih: ${r.tarih} · ${r.baslangic}-${r.bitis}'),
            const SizedBox(height: 4),
            Text('Kisi sayisi: ${r.kisiSayisi}'
                '${r.unitNo != null ? ' · Daire: ${r.unitNo}' : ''}'),
            const SizedBox(height: 4),
            Text('Talep: ${_fmtDateTime(r.createdAt.toLocal())}'
                '${r.talepEdenAd != null ? ' — ${r.talepEdenAd}' : ''}'),
            if (r.notlar != null && r.notlar!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Not: ${r.notlar}'),
            ],
            if (!r.bekliyor) ...[
              const SizedBox(height: 4),
              Text(
                'Karar: ${r.durum.label}'
                '${r.onaylayanAd != null ? ' — ${r.onaylayanAd}' : ''}'
                '${r.kararZamani != null ? ' · ${_fmtDateTime(r.kararZamani!.toLocal())}' : ''}',
              ),
            ],
            if (r.bekliyor && canDecide) ...[
              const SizedBox(height: 20),
              _DecideButtons(
                rezervasyonId: r.id,
                onDecided: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

// ------------------------------ alan listesi ------------------------------- //
class _AreaList extends ConsumerWidget {
  const _AreaList({required this.state});

  final RezervasyonState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading && state.alanlar.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.alanlar.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Text(
              state.canManageAreas
                  ? 'Henuz ortak alan yok. "Yeni alan" ile ekleyin.'
                  : 'Rezerve edilebilir alan yok.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: state.alanlar.length,
      itemBuilder: (context, i) {
        final alan = state.alanlar[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              alan.aktif ? Icons.meeting_room_outlined : Icons.block,
              color: alan.aktif ? null : Colors.grey,
            ),
            title: Text(alan.ad),
            subtitle: alan.aciklama == null && alan.aktif
                ? null
                : Text(
                    '${alan.aciklama ?? ''}'
                    '${alan.aktif ? '' : '${alan.aciklama == null ? '' : ' · '}Pasif (rezerve edilemez)'}',
                  ),
            // Yonetim: aktiflik anahtari (soft-delete / yeniden aktive).
            trailing: state.canManageAreas
                ? Switch(
                    value: alan.aktif,
                    onChanged: (v) async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await ref
                            .read(rezervasyonControllerProvider.notifier)
                            .setAreaActive(alan.id, v);
                      } on ApiException catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(e.message)),
                        );
                      }
                    },
                  )
                : null,
          ),
        );
      },
    );
  }
}

/// Yeni alan formu (yonetim): ad + opsiyonel aciklama.
class _AreaForm extends ConsumerStatefulWidget {
  const _AreaForm();

  @override
  ConsumerState<_AreaForm> createState() => _AreaFormState();
}

class _AreaFormState extends ConsumerState<_AreaForm> {
  final _formKey = GlobalKey<FormState>();
  final _ad = TextEditingController();
  final _aciklama = TextEditingController();
  bool _busy = false;
  String? _hata;

  @override
  void dispose() {
    _ad.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _hata = null;
    });
    try {
      await ref.read(rezervasyonControllerProvider.notifier).createArea(
            OrtakAlanDraft(
              ad: _ad.text.trim(),
              aciklama:
                  _aciklama.text.trim().isEmpty ? null : _aciklama.text.trim(),
            ),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      // 409: ayni adla alan zaten var.
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
          _hata = 'Alan eklenemedi. Tekrar deneyin.';
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yeni ortak alan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ad,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Alan adi * (orn. Havuz)',
                border: OutlineInputBorder(),
              ),
              maxLength: 200,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Alan adi gerekli' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _aciklama,
              decoration: const InputDecoration(
                labelText: 'Aciklama (opsiyonel)',
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
                    : const Icon(Icons.add_home_outlined),
                label: const Text('Alani ekle'),
                onPressed: _busy ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yeni rezervasyon formu (sakin): alan secimi + tarih + saat araligi +
/// kisi sayisi + opsiyonel not. Cakisma 409'u formda gosterilir.
class _RequestForm extends ConsumerStatefulWidget {
  const _RequestForm({required this.alanlar});

  /// Secilebilir (aktif) alanlar.
  final List<OrtakAlan> alanlar;

  @override
  ConsumerState<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends ConsumerState<_RequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _notlar = TextEditingController();
  late String _alanId = widget.alanlar.first.id;
  DateTime _tarih = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _baslangic = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _bitis = const TimeOfDay(hour: 12, minute: 0);
  int _kisi = 2;
  bool _busy = false;
  String? _hata;

  @override
  void dispose() {
    _notlar.dispose();
    super.dispose();
  }

  String get _tarihStr =>
      '${_tarih.year}-${_tarih.month.toString().padLeft(2, '0')}-${_tarih.day.toString().padLeft(2, '0')}';

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  bool get _aralikGecerli {
    final b = _baslangic.hour * 60 + _baslangic.minute;
    final e = _bitis.hour * 60 + _bitis.minute;
    return e > b;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tarih,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _tarih = picked);
  }

  Future<void> _pickTime(bool baslangic) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: baslangic ? _baslangic : _bitis,
    );
    if (picked != null) {
      setState(() {
        if (baslangic) {
          _baslangic = picked;
        } else {
          _bitis = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_aralikGecerli) {
      // Sunucu da 422 doner; istemcide erken ve acik uyari.
      setState(() => _hata = 'Bitis saati baslangictan sonra olmali.');
      return;
    }
    setState(() {
      _busy = true;
      _hata = null;
    });
    try {
      await ref.read(rezervasyonControllerProvider.notifier).request(
            RezervasyonDraft(
              alanId: _alanId,
              tarih: _tarihStr,
              baslangic: _hhmm(_baslangic),
              bitis: _hhmm(_bitis),
              kisiSayisi: _kisi,
              notlar: _notlar.text.trim().isEmpty ? null : _notlar.text.trim(),
            ),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      // 409: onayli rezervasyonla cakisma — kullaniciya acikca gosterilir.
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
          _hata = 'Talep gonderilemedi. Tekrar deneyin.';
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
              const Text(
                'Yeni rezervasyon',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _alanId,
                decoration: const InputDecoration(
                  labelText: 'Ortak alan',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final a in widget.alanlar)
                    DropdownMenuItem(value: a.id, child: Text(a.ad)),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _alanId = v ?? _alanId),
              ),
              const SizedBox(height: 12),
              // Tarih + saat secimleri (yerel picker'lar).
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text('Tarih: $_tarihStr'),
                onPressed: _busy ? null : _pickDate,
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text('Baslangic: ${_hhmm(_baslangic)}'),
                      onPressed: _busy ? null : () => _pickTime(true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text('Bitis: ${_hhmm(_bitis)}'),
                      onPressed: _busy ? null : () => _pickTime(false),
                    ),
                  ),
                ],
              ),
              if (!_aralikGecerli)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Bitis saati baslangictan sonra olmali.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Kisi sayisi:'),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _busy || _kisi <= 1
                        ? null
                        : () => setState(() => _kisi--),
                  ),
                  Text('$_kisi',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _busy ? null : () => setState(() => _kisi++),
                  ),
                ],
              ),
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
                      : const Icon(Icons.event_available_outlined),
                  label: const Text('Talep gonder'),
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
