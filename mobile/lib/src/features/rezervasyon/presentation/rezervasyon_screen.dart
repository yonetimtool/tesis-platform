import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../domain/rezervasyon_models.dart';
import 'rezervasyon_controller.dart';

/// "Rezervasyon" — ortak alan rezervasyonu (auth.md §4 kesin kurali, UX aynasi):
///   * resident: aktif alanlari gorur, "Yeni rezervasyon" ile BOS slotu ANINDA
///     rezerve eder (onay YOK). Slot secimi rezerve-edilebilirligi yansitir
///     (24s penceresi + gunluk kota + son-dakika istisnasi; sunucu hesaplar).
///     Kendi rezervasyonlarini gorur ve KENDI rezervasyonunu iptal edebilir.
///   * admin/yonetici: alan olustur/duzenle/pasiflestir; tum rezervasyonlari
///     gorur (onay YOK — yalniz izleme) ve gerekirse iptal eder; "Takvim"
///     sekmesi alan bazli ONAYLI slotlarin gun-sirali listesi.
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
      if (mounted) _showDetail(context, r, canCancel: state.canCancel(r));
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

    // Iki sekme: "Rezervasyonlar" (kendi/tum kayitlar) + "Alanlar" (alan-once
    // rezervasyon akisi). "Takvim" sekmesi kaldirildi (alan-detay slotlari onun
    // yerini alir).
    return DefaultTabController(
      length: 2,
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
            tabs: [
              Tab(text: 'Rezervasyonlar (${state.items.length})'),
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
                items: state.items,
                emptyText: state.canRequest
                    ? 'Rezervasyonunuz yok. "Alanlar" sekmesinden bir alan '
                        'seçip boş bir slotu ayırtın.'
                    : 'Rezervasyon yok.',
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

  // Rezervasyon "alanlar-once" akisla yapilir (alan sec → slot sec); ayri
  // "Yeni rezervasyon" FAB yok. Yalniz yonetim "Yeni alan" ekler.
  Widget? _fab(BuildContext context, RezervasyonState state) {
    if (state.canManageAreas) {
      return FloatingActionButton.extended(
        icon: const Icon(Icons.add_home_outlined),
        label: const Text('Yeni alan'),
        onPressed: () => _openAreaForm(context),
      );
    }
    return null;
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
  });

  final RezervasyonState state;
  final List<Rezervasyon> items;
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
      itemBuilder: (context, i) => _ReservationCard(
        rezervasyon: items[i],
        canCancel: state.canCancel(items[i]),
      ),
    );
  }
}

/// Durum rozeti — onaylandi=yesil, iptal=gri.
class _DurumChip extends StatelessWidget {
  const _DurumChip({required this.durum});

  final RezervasyonDurum durum;

  Color get _color => switch (durum) {
        RezervasyonDurum.onaylandi => Colors.green,
        RezervasyonDurum.iptal => Colors.grey,
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
  const _ReservationCard({required this.rezervasyon, required this.canCancel});

  final Rezervasyon rezervasyon;
  final bool canCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = rezervasyon;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context, r, canCancel: canCancel),
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
                '${r.tarih} · ${r.baslangic}-${r.bitis} · ${r.kisiSayisi} kişi'
                '${r.unitNo != null ? ' · Daire: ${r.unitNo}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (r.notlar != null && r.notlar!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(r.notlar!, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              if (r.iptalEdildi) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.cancel_outlined,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'İptal edildi'
                        '${r.iptalEdenAd != null ? ' — ${r.iptalEdenAd}' : ''}'
                        '${r.iptalZamani != null ? ' · ${_fmtDateTime(r.iptalZamani!.toLocal())}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              if (canCancel) ...[
                const SizedBox(height: 12),
                _CancelButton(rezervasyonId: r.id),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// İptal butonu — rezerve eden sakinin (kendi) ve yonetimin kartinda/detayinda.
/// 409 (zaten iptal) mesajla gosterilir; liste guncel duruma tazelenir.
class _CancelButton extends ConsumerStatefulWidget {
  const _CancelButton({required this.rezervasyonId, this.onCancelled});

  final String rezervasyonId;

  /// Detay sheet'inden cagrildiginda iptal sonrasi sheet'i kapatmak icin.
  final VoidCallback? onCancelled;

  @override
  ConsumerState<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends ConsumerState<_CancelButton> {
  bool _busy = false;

  Future<void> _cancel() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final onay = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Rezervasyon iptal edilsin mi?'),
        content: const Text('Slot yeniden boşa çıkar; bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Evet, iptal et'),
          ),
        ],
      ),
    );
    if (onay != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(rezervasyonControllerProvider.notifier)
          .cancel(widget.rezervasyonId);
      messenger.showSnackBar(
        const SnackBar(content: Text('Rezervasyon iptal edildi')),
      );
      widget.onCancelled?.call();
    } on ApiException catch (e) {
      // 409: zaten iptal edilmis.
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      widget.onCancelled?.call();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('İptal gönderilemedi. Tekrar deneyin.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('İptal et'),
        onPressed: _busy ? null : _cancel,
      ),
    );
  }
}

/// Detay alt sayfasi — push tiklamasi ve kart dokunusuyla acilir.
void _showDetail(BuildContext context, Rezervasyon r,
    {required bool canCancel}) {
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
            Text('Kişi sayısı: ${r.kisiSayisi}'
                '${r.unitNo != null ? ' · Daire: ${r.unitNo}' : ''}'),
            const SizedBox(height: 4),
            Text('Rezerve: ${_fmtDateTime(r.createdAt.toLocal())}'
                '${r.talepEdenAd != null ? ' — ${r.talepEdenAd}' : ''}'),
            if (r.notlar != null && r.notlar!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Not: ${r.notlar}'),
            ],
            if (r.iptalEdildi) ...[
              const SizedBox(height: 4),
              Text(
                'İptal'
                '${r.iptalEdenAd != null ? ' — ${r.iptalEdenAd}' : ''}'
                '${r.iptalZamani != null ? ' · ${_fmtDateTime(r.iptalZamani!.toLocal())}' : ''}',
              ),
            ],
            if (canCancel) ...[
              const SizedBox(height: 20),
              _CancelButton(
                rezervasyonId: r.id,
                onCancelled: () => Navigator.of(sheetContext).pop(),
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
                  ? 'Henüz ortak alan yok. "Yeni alan" ile ekleyin.'
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
            subtitle: Text(
              [
                if (alan.aciklama != null && alan.aciklama!.isNotEmpty)
                  alan.aciklama!,
                alan.aktif
                    ? 'Müsait: ${alan.musaitlikOzeti} · dokunup slotları gör'
                    : 'Pasif (rezerve edilemez)',
              ].join('\n'),
            ),
            // ALANLAR-ONCE: alana dokun → o alanin gunluk slotlari (dolu/bos);
            // sakin bos slotu buradan rezerve eder.
            onTap: () => _openAmenitySlots(context, alan),
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
                : const Icon(Icons.chevron_right),
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
  // Musaitlik: her gun [acilis, kapanis) araligi, _slot dk slot uzunlugu.
  TimeOfDay _acilis = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _kapanis = const TimeOfDay(hour: 22, minute: 0);
  int _slot = 60;
  bool _busy = false;
  String? _hata;

  static const _slotSecenekleri = [30, 45, 60, 90, 120];

  @override
  void dispose() {
    _ad.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  bool get _saatGecerli =>
      _kapanis.hour * 60 + _kapanis.minute >
      _acilis.hour * 60 + _acilis.minute;

  Future<void> _pickSaat(bool acilis) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: acilis ? _acilis : _kapanis,
    );
    if (picked != null) {
      setState(() {
        if (acilis) {
          _acilis = picked;
        } else {
          _kapanis = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    if (!_saatGecerli) {
      setState(() => _hata = 'Kapanış saati açılıştan sonra olmalı.');
      return;
    }
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
              acilis: _hhmm(_acilis),
              kapanis: _hhmm(_kapanis),
              slotDakika: _slot,
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
        child: SingleChildScrollView(
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
                  labelText: 'Alan adı * (örn. Havuz)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 200,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Alan adı gerekli' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _aciklama,
                decoration: const InputDecoration(
                  labelText: 'Açıklama (opsiyonel)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 1000,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              // Musaitlik: acilis/kapanis + slot uzunlugu (slotlar bundan uretilir).
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Müsaitlik (her gün)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.wb_sunny_outlined, size: 18),
                      label: Text('Açılış: ${_hhmm(_acilis)}'),
                      onPressed: _busy ? null : () => _pickSaat(true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.nightlight_outlined, size: 18),
                      label: Text('Kapanış: ${_hhmm(_kapanis)}'),
                      onPressed: _busy ? null : () => _pickSaat(false),
                    ),
                  ),
                ],
              ),
              if (!_saatGecerli)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Kapanış saati açılıştan sonra olmalı.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _slot,
                decoration: const InputDecoration(
                  labelText: 'Slot uzunluğu',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final s in _slotSecenekleri)
                    DropdownMenuItem(value: s, child: Text('$s dakika')),
                ],
                onChanged:
                    _busy ? null : (v) => setState(() => _slot = v ?? _slot),
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
                  label: const Text('Alanı ekle'),
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

/// Alan-detay slot listesi (ALANLAR-ONCE akisin merkezi): secilen alanin bir
/// gunune ait slotlari dolu/bos gosterir. Sunucu ROL-FARKINDA doner —
///   * resident: dolu slot yalniz "Dolu" (kim/kac kisi GIZLI); bos + rezerve
///     edilebilir slotu buradan rezerve eder (kisi sayisi + not).
///   * admin/yonetici: dolu slotta rezerve eden DAIRE + kisi sayisi (denetim);
///     rezerve etmez (yalniz izler).
void _openAmenitySlots(BuildContext context, OrtakAlan alan) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AmenitySlotsSheet(alan: alan),
  );
}

class _AmenitySlotsSheet extends ConsumerStatefulWidget {
  const _AmenitySlotsSheet({required this.alan});

  final OrtakAlan alan;

  @override
  ConsumerState<_AmenitySlotsSheet> createState() => _AmenitySlotsSheetState();
}

class _AmenitySlotsSheetState extends ConsumerState<_AmenitySlotsSheet> {
  DateTime _tarih = DateTime.now();
  List<Slot> _slots = const [];
  bool _yukleniyor = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  String get _tarihStr =>
      '${_tarih.year}-${_tarih.month.toString().padLeft(2, '0')}-${_tarih.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final slots = await ref
          .read(rezervasyonControllerProvider.notifier)
          .slots(widget.alan.id, _tarihStr);
      if (!mounted) return;
      setState(() {
        _slots = slots;
        _yukleniyor = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata = 'Slotlar yüklenemedi. Tekrar deneyin.';
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tarih,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _tarih = picked);
      await _load();
    }
  }

  Future<void> _book(Slot s) async {
    final booked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BookSlotSheet(alan: widget.alan, tarih: _tarihStr, slot: s),
    );
    if (booked == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rezervasyonunuz onaylandı ✓')),
      );
      await _load(); // slot artik dolu — izgarayi tazele
    }
  }

  /// Slotun bu tarih icin BITIS anini yerel DateTime'a cevirir (gecmis karari).
  /// tenant yerel saati cihaz yerel saati kabul edilir (renk UX; sunucu benim
  /// isaretini verir, gecmis/aktif ayrimini istemci yapar).
  DateTime? _bitisAni(Slot s) {
    final g = _tarihStr.split('-');
    final t = s.bitis.split(':');
    if (g.length != 3 || t.length < 2) return null;
    final y = int.tryParse(g[0]);
    final mo = int.tryParse(g[1]);
    final d = int.tryParse(g[2]);
    final h = int.tryParse(t[0]);
    final mi = int.tryParse(t[1]);
    if (y == null || mo == null || d == null || h == null || mi == null) {
      return null;
    }
    return DateTime(y, mo, d, h, mi);
  }

  /// Kendi (benim) rezervasyonu gecmis mi (bitis simdiyi gecti mi) → kirmizi.
  bool _gecti(Slot s) {
    final end = _bitisAni(s);
    return end != null && DateTime.now().isAfter(end);
  }

  @override
  Widget build(BuildContext context) {
    final canRequest =
        ref.watch(rezervasyonControllerProvider).canRequest;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.meeting_room_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.alan.ad,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Müsait: ${widget.alan.musaitlikOzeti}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text('Tarih: $_tarihStr'),
              onPressed: _yukleniyor ? null : _pickDate,
            ),
            if (canRequest) ...[
              const SizedBox(height: 4),
              const Text(
                'Slot yalnızca başlangıcına 24 saatten az kala açılır; '
                'günde en fazla bir rezervasyon yapabilirsiniz.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 8),
            Flexible(child: _slotListesi(canRequest)),
          ],
        ),
      ),
    );
  }

  Widget _slotListesi(bool canRequest) {
    if (_yukleniyor) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_hata != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(_hata!, style: const TextStyle(color: Colors.red)),
      );
    }
    if (_slots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Bu alan için tanımlı slot yok.'),
      );
    }
    // Slot IZGARASI: renkli hucreler. Renk kademesi rol-farkinda (_SlotCell).
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canRequest) const _SlotLegend(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _slots)
                _SlotCell(
                  slot: s,
                  canRequest: canRequest,
                  gecti: _gecti(s),
                  onBook: () => _book(s),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// Slot renkleri (yesil=benim aktif, kirmizi=benim gecti; blueGrey=baskasi/dolu).
const Color _slotYesil = Color(0xFF2E7D32);
const Color _slotKirmizi = Color(0xFFC62828);
const Color _slotAmber = Color(0xFFF9A825); // yonetim: dolu (denetim)

/// Resident icin renk gostergesi (yesil=aktif rezervasyonum, kirmizi=gecmis).
class _SlotLegend extends StatelessWidget {
  const _SlotLegend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(spacing: 12, runSpacing: 4, children: [
        item(_slotYesil, 'Rezervasyonum (aktif)'),
        item(_slotKirmizi, 'Rezervasyonum (geçti)'),
        item(Colors.blueGrey, 'Dolu (başkası)'),
      ]),
    );
  }
}

/// Tek slot hucresi — ROL-FARKINDA renk kademesi:
///   * resident bos+rezerve edilebilir → "Boş" (yesil kenar, dokunulur → Seç)
///   * resident bos+edilemez → gri + sebep (24s/kota/geçti)
///   * resident KENDI aktif → YESIL dolgu "Rezervasyonunuz"
///   * resident KENDI gecmis → KIRMIZI dolgu "Rezervasyonunuz (geçti)"
///   * resident BASKASI → notr gri "Dolu" (kimlik/kisi YOK — gizlilik)
///   * yonetim dolu → amber "Dolu · Daire X · n kişi" (denetim)
class _SlotCell extends StatelessWidget {
  const _SlotCell({
    required this.slot,
    required this.canRequest,
    required this.gecti,
    required this.onBook,
  });

  final Slot slot;
  final bool canRequest;
  final bool gecti;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final s = slot;
    Color renk;
    String durum;
    bool secilebilir = false;

    if (s.dolu) {
      if (canRequest && s.benim) {
        renk = gecti ? _slotKirmizi : _slotYesil;
        durum = gecti ? 'Rezervasyonunuz (geçti)' : 'Rezervasyonunuz';
      } else if (s.unitNo != null) {
        // Yonetim: rezerve eden daire + kisi (denetim).
        renk = _slotAmber;
        final kisi = s.kisiSayisi != null ? ' · ${s.kisiSayisi} kişi' : '';
        durum = 'Dolu · Daire ${s.unitNo}$kisi';
      } else {
        // Resident: baskasinin rezervasyonu — ANONIM (kimlik/kisi yok).
        renk = Colors.blueGrey;
        durum = 'Dolu';
      }
    } else if (canRequest && s.rezerveEdilebilir) {
      renk = _slotYesil;
      durum = 'Boş';
      secilebilir = true;
    } else {
      renk = Colors.blueGrey;
      durum = s.sebepEtiketi ?? 'Boş';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cell = Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: isDark ? 0.28 : 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: renk, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${s.baslangic} – ${s.bitis}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(durum,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? null : renk,
                        fontWeight: FontWeight.w600)),
              ),
              if (secilebilir)
                const Text('Seç',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _slotYesil)),
            ],
          ),
        ],
      ),
    );
    if (!secilebilir) return cell;
    return InkWell(
      onTap: onBook,
      borderRadius: BorderRadius.circular(10),
      child: cell,
    );
  }
}

/// Bos slotu rezerve etme formu (sakin): kisi sayisi + opsiyonel not.
/// Cakisma/24s/kota hatasi (409/422) formda gosterilir.
class _BookSlotSheet extends ConsumerStatefulWidget {
  const _BookSlotSheet({
    required this.alan,
    required this.tarih,
    required this.slot,
  });

  final OrtakAlan alan;
  final String tarih;
  final Slot slot;

  @override
  ConsumerState<_BookSlotSheet> createState() => _BookSlotSheetState();
}

class _BookSlotSheetState extends ConsumerState<_BookSlotSheet> {
  final _notlar = TextEditingController();
  int _kisi = 2;
  bool _busy = false;
  String? _hata;

  @override
  void dispose() {
    _notlar.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _hata = null;
    });
    try {
      await ref.read(rezervasyonControllerProvider.notifier).request(
            RezervasyonDraft(
              alanId: widget.alan.id,
              tarih: widget.tarih,
              baslangic: widget.slot.baslangic,
              bitis: widget.slot.bitis,
              kisiSayisi: _kisi,
              notlar: _notlar.text.trim().isEmpty ? null : _notlar.text.trim(),
            ),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      // 409 (cakisma/kota) veya 422 (24s/pencere) — net mesaj formda.
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
          _hata = 'Gönderilemedi. Tekrar deneyin.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.alan.ad} — rezerve et',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${widget.tarih} · ${widget.slot.baslangic}–${widget.slot.bitis}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Kişi sayısı:'),
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
          TextField(
            controller: _notlar,
            maxLength: 1000,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Not (opsiyonel)',
              border: OutlineInputBorder(),
            ),
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
              label: const Text('Rezerve et'),
              onPressed: _busy ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtDateTime(DateTime dt) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(dt.day)}.${p(dt.month)}.${dt.year} ${p(dt.hour)}:${p(dt.minute)}';
}
