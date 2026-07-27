import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/error/api_exception.dart';
// Foto akisi GOREV KANITI ile ayni: ayni picker saglayicisi, ayni presign uc.
import '../../tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;
import '../data/etkinlik_api.dart';
import '../domain/etkinlik_models.dart';
import 'etk_etiket.dart';
import 'etkinlik_controller.dart';
import '../../../core/error/akis_hatasi.dart';

/// "Etkinlikler" — etkinlik + RSVP (auth.md §4 kesin kurali, UX aynasi):
///   * yonetim (admin/yonetici): "Yeni etkinlik" FAB'i + detayda duzenle/sil;
///     seffaf katilim sayilarini izler.
///   * resident: Katiliyorum/Katilmiyorum beyani — beyan KILITLI: bir kez
///     verilince butonlar gizlenir, yerine kayitli yanit ("Katiliminiz: ...")
///     gosterilir (secim kesin, degistirilemez). Sayac beyan sonrasi ANINDA
///     guncellenir.
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
          title: Text(baslikBuyuk(context.l10n.modulEtkinlikler, context.dilKodu)),
          actions: [
            IconButton(
              tooltip: context.l10n.ortakYenile,
              icon: const Icon(Icons.refresh),
              onPressed: state.loading ? null : controller.refresh,
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: context.l10n.etkSekmeYaklasan('${yaklasan.length}')),
              Tab(text: context.l10n.etkSekmeGecmis('${gecmis.length}')),
            ],
          ),
        ),
        floatingActionButton: state.canManage
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.celebration_outlined),
                label: Text(context.l10n.etkYeni),
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
                    ? context.l10n.etkYaklasanYokYonetim
                    : context.l10n.etkYaklasanYok,
              ),
            ),
            RefreshIndicator(
              onRefresh: controller.refresh,
              child: _Body(
                state: state,
                items: gecmis,
                emptyText: context.l10n.etkGecmisYok,
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
              ? context.l10n.etkDuyuruldu
              : context.l10n.etkGuncellendi),
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
    // Dar ekranda (kart/alt sayfa ici) iki sayac satiri tasmasin: metinler
    // esnek + kirpilabilir.
    return Row(
      children: [
        const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
        const SizedBox(width: 4),
        Flexible(
          child: Text(context.l10n.etkKatiliyorSayisi(etkinlik.katiliyorumSayisi),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
        const SizedBox(width: 4),
        Flexible(
          child: Text(context.l10n.etkKatilmiyorSayisi(etkinlik.katilmiyorumSayisi),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ),
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
                '${tarihSaatBicimi(e.tarih, context.dilKodu, ayirici: '')}'
                '${e.konum != null ? ' · ${e.konum}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(e.aciklama, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (e.fotoUrl != null) ...[
                const SizedBox(height: 8),
                _EtkinlikGorseli(url: e.fotoUrl!, yukseklik: 120),
              ],
              const SizedBox(height: 8),
              _SayacRow(etkinlik: e),
              if (canRsvp && !e.gecmis) ...[
                const SizedBox(height: 12),
                // Beyan KILITLI: cevaplanmamissa butonlar; cevaplanmissa
                // yalniz kayitli yanit (tekrar oy yok).
                if (e.benimDurumum == null)
                  _RsvpButtons(etkinlik: e)
                else
                  _RecordedAnswer(durum: e.benimDurumum!),
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
        katilimDurumAdi(context.l10n, durum),
        style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Kullanicinin kayitli (kilitli) yaniti — beyan verildikten sonra butonlarin
/// yerine gosterilir; tekrar oy YOK (secim kesin).
class _RecordedAnswer extends StatelessWidget {
  const _RecordedAnswer({required this.durum});

  final KatilimDurum durum;

  @override
  Widget build(BuildContext context) {
    final katiliyor = durum == KatilimDurum.katiliyorum;
    final renk = katiliyor ? Colors.green : Colors.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: renk.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(katiliyor ? Icons.check_circle : Icons.cancel, color: renk, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.etkKatiliminiz(katilimDurumAdi(context.l10n, durum)),
              style: TextStyle(color: renk, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Katiliyorum/Katilmiyorum beyan butonlari — YALNIZ henuz cevaplanmamis
/// etkinlikte gosterilir (beyan kilitli; verildikten sonra butonlar gizlenir).
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
    // Async bosluktan ONCE yakalanir (messenger ile ayni gerekce).
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(etkinlikControllerProvider.notifier)
          .rsvp(widget.etkinlik.id, durum);
      messenger.showSnackBar(
        SnackBar(
            content: Text(l10n.etkBeyanKaydedildi(katilimDurumAdi(l10n, durum)))),
      );
      widget.onAnswered?.call();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.etkBeyanGonderilemedi)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Butonlar yalniz cevaplanmamis etkinlikte cikar (parent kosulu); bu yuzden
    // ikisi de noturr (secili-vurgulu hali yoktur — kilitten once tek karar).
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.check, color: Colors.green),
            label: Text(context.l10n.etkKatiliyorum),
            onPressed: _busy ? null : () => _beyan(KatilimDurum.katiliyorum),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.close, color: Colors.red),
            label: Text(context.l10n.etkKatilmiyorum),
            onPressed: _busy ? null : () => _beyan(KatilimDurum.katilmiyorum),
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
              Text(context.l10n.etkZaman(_fmtAralik(e, context.dilKodu))),
              if (e.konum != null) ...[
                const SizedBox(height: 4),
                Text(context.l10n.etkYer(e.konum!)),
              ],
              if (e.fotoUrl != null) ...[
                const SizedBox(height: 12),
                _EtkinlikGorseli(url: e.fotoUrl!, yukseklik: 180),
              ],
              const SizedBox(height: 8),
              Text(e.aciklama),
              const SizedBox(height: 12),
              _SayacRow(etkinlik: e),
              if (e.olusturanAd != null) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.etkDuyuran(e.olusturanAd!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (canRsvp && !e.gecmis) ...[
                const SizedBox(height: 20),
                // Beyan KILITLI: cevaplanmamissa butonlar; cevaplanmissa
                // yalniz kayitli yanit (tekrar oy yok).
                if (e.benimDurumum == null)
                  _RsvpButtons(
                    etkinlik: e,
                    onAnswered: () => Navigator.of(sheetContext).pop(),
                  )
                else
                  _RecordedAnswer(durum: e.benimDurumum!),
              ],
              if (canManage) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(context.l10n.ortakDuzenle),
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
      label: Text(context.l10n.ortakSil),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        // Async bosluktan ONCE yakalanir (messenger ile ayni gerekce).
        final l10n = context.l10n;
        final onay = await showDialog<bool>(
          context: context,
          builder: (dctx) => AlertDialog(
            title: Text(context.l10n.etkSilinsinMi),
            content: Text(
              context.l10n.etkSilOnay(etkinlik.baslik),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dctx).pop(false),
                child: Text(context.l10n.ortakVazgec),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(dctx).pop(true),
                child: Text(context.l10n.ortakSil),
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
            SnackBar(content: Text(l10n.etkSilindi)),
          );
          onDeleted();
        } on ApiException catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
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
  /// `setState` yollarinda kullanilan yerellestirme (build disi).
  AppLocalizations get _l10n => AppLocalizations.of(context);

  final _formKey = GlobalKey<FormState>();
  late final _baslik = TextEditingController(text: widget.mevcut?.baslik);
  late final _aciklama = TextEditingController(text: widget.mevcut?.aciklama);
  late final _konum = TextEditingController(text: widget.mevcut?.konum);
  late DateTime _tarih = widget.mevcut?.tarih.toLocal() ??
      DateTime.now().add(const Duration(days: 1));
  late DateTime? _bitis = widget.mevcut?.bitisZamani?.toLocal();
  bool _busy = false;
  String? _hata;

  /// Gorsel akisi GOREV FOTO KANITININ AYNISI: cek/sec → presign → PUT →
  /// foto_key (ayni uc, ayni sikistirma/boyut kurallari).
  String? _photoPath;
  bool _photoBusy = false;
  String? _photoError;
  String? _fotoKey;

  /// Mevcut kaydin gorseli KALDIRILDI mi (PATCH'te acik null gonderilir).
  bool _fotoKaldirildi = false;

  bool get _fotoBekliyor => _photoPath != null && _fotoKey == null;

  /// Duzenlemede: kaldirilmadiysa ve yeni secim yoksa MEVCUT gorsel durur.
  String? get _mevcutFotoUrl =>
      (_fotoKaldirildi || _photoPath != null) ? null : widget.mevcut?.fotoUrl;

  @override
  void dispose() {
    _baslik.dispose();
    _aciklama.dispose();
    _konum.dispose();
    super.dispose();
  }

  Future<void> _fotoSecVeYukle(ImageSource source) async {
    if (_photoBusy) return;
    setState(() {
      _photoBusy = true;
      _photoError = null;
    });
    try {
      final file = await ref.read(imagePickerProvider).pickImage(
            source: source,
            // Gorev/duyuru akisiyla AYNI sikistirma: yukleme boyutu makul.
            maxWidth: 1600,
            imageQuality: 80,
          );
      if (!mounted) return;
      if (file == null) {
        setState(() => _photoBusy = false); // vazgecildi
        return;
      }
      setState(() {
        _photoPath = file.path;
        _fotoKey = null; // yeni secim: eski yukleme gecersiz
        _fotoKaldirildi = false;
      });
      await _fotoYukle(file);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _photoBusy = false;
        _photoError = _l10n.gorevFotoAlinamadi('$e');
      });
    }
  }

  Future<void> _fotoYukle(XFile file) async {
    final api = ref.read(etkinlikApiProvider);
    try {
      final contentType = _contentTypeFor(file);
      final ticket = await api.presignUpload(
        contentType: contentType,
        dosyaAdi: file.name,
      );
      final bytes = await file.readAsBytes();
      await api.uploadPhoto(
        ticket: ticket,
        bytes: bytes,
        contentType: contentType,
      );
      if (!mounted) return;
      setState(() {
        _photoBusy = false;
        _fotoKey = ticket.fotoKey;
        _photoError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _photoBusy = false;
        _photoError = e.kind == ApiErrorKind.network
            ? _l10n.gorevFotoOnlineGerekli
            : apiHataMetni(_l10n, e);
      });
    }
  }

  Future<void> _fotoTekrarYukle() async {
    final path = _photoPath;
    if (path == null || _photoBusy) return;
    setState(() {
      _photoBusy = true;
      _photoError = null;
    });
    await _fotoYukle(XFile(path));
  }

  void _fotoKaldir() {
    setState(() {
      _photoPath = null;
      _photoError = null;
      _fotoKey = null;
      // Duzenlemede mevcut gorselin SILINMESI istendi.
      _fotoKaldirildi = widget.mevcut?.fotoUrl != null;
    });
  }

  Future<void> _pickBitis() async {
    final gun = await showDatePicker(
      context: context,
      initialDate: _bitis ?? _tarih.add(const Duration(hours: 2)),
      firstDate: _tarih,
      lastDate: _tarih.add(const Duration(days: 30)),
    );
    if (gun == null || !mounted) return;
    final saat = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _bitis ?? _tarih.add(const Duration(hours: 2)),
      ),
    );
    if (saat == null) return;
    setState(() {
      _bitis = DateTime(gun.year, gun.month, gun.day, saat.hour, saat.minute);
    });
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
    if (_fotoBekliyor) {
      setState(() {
        _hata = _l10n.gorevFotoHenuzYuklenmedi;
      });
      return;
    }
    if (_bitis != null && !_bitis!.isAfter(_tarih)) {
      setState(() => _hata = _l10n.etkBitisSonra);
      return;
    }
    setState(() {
      _busy = true;
      _hata = null;
    });
    final draft = EtkinlikDraft(
      baslik: _baslik.text.trim(),
      aciklama: _aciklama.text.trim(),
      tarih: _tarih,
      bitisZamani: _bitis,
      konum: _konum.text.trim().isEmpty ? null : _konum.text.trim(),
      fotoKey: _fotoKey,
      fotoKeyKaldir: _fotoKaldirildi,
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
          _hata = apiHataMetni(_l10n, e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _hata = _l10n.etkKaydedilemedi;
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
                widget.mevcut == null ? context.l10n.etkYeni : context.l10n.etkDuzenleBaslik,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _baslik,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.l10n.etkBaslikAlan,
                  border: OutlineInputBorder(),
                ),
                maxLength: 200,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? context.l10n.etkBaslikGerekli : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _aciklama,
                decoration: InputDecoration(
                  labelText: context.l10n.etkAciklamaAlan,
                  border: OutlineInputBorder(),
                ),
                maxLength: 5000,
                minLines: 2,
                maxLines: 5,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.l10n.etkAciklamaGerekli
                    : null,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule, size: 18),
                label: Text(context.l10n.etkZamanSecim(
                  tarihSaatBicimi(_tarih, context.dilKodu, ayirici: ''))),
                onPressed: _busy ? null : _pickDateTime,
              ),
              const SizedBox(height: 8),
              // Opsiyonel BITIS: etkinlik bitene kadar "yaklasan" listesinde
              // kalir (sunucu ?aktif=true suzgeci COALESCE(bitis, tarih)).
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule_outlined, size: 18),
                      // Uzun etiket (tarih+saat) dar telefonda tasmasin.
                      label: Text(
                        _bitis == null
                            ? context.l10n.etkBitisEkle
                            : context.l10n.etkBitis(tarihSaatBicimi(
                                _bitis!, context.dilKodu, ayirici: '')),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _busy ? null : _pickBitis,
                    ),
                  ),
                  if (_bitis != null)
                    IconButton(
                      tooltip: context.l10n.etkBitisiKaldir,
                      icon: const Icon(Icons.close),
                      onPressed: _busy ? null : () => setState(() => _bitis = null),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _konum,
                decoration: InputDecoration(
                  labelText: context.l10n.etkYerAlan,
                  border: OutlineInputBorder(),
                ),
                maxLength: 500,
              ),
              // ---- Gorsel (opsiyonel) — gorev foto kaniti akisinin aynisi ----
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    (_fotoKey != null || _mevcutFotoUrl != null)
                        ? Icons.check_circle
                        : Icons.image_outlined,
                    color: (_fotoKey != null || _mevcutFotoUrl != null)
                        ? Colors.green
                        : null,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(context.l10n.etkGorselAlan),
                ],
              ),
              if (_photoPath != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_photoPath!),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                if (_photoBusy)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
              ] else if (_mevcutFotoUrl != null) ...[
                const SizedBox(height: 8),
                _EtkinlikGorseli(url: _mevcutFotoUrl!, yukseklik: 120),
              ],
              if (_photoError != null) ...[
                const SizedBox(height: 4),
                Text(_photoError!, style: const TextStyle(color: Colors.red)),
              ],
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _photoBusy || _busy
                        ? null
                        : () => _fotoSecVeYukle(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(_photoPath == null ? context.l10n.gorevKamera : context.l10n.gorevYenidenCek),
                  ),
                  TextButton.icon(
                    onPressed: _photoBusy || _busy
                        ? null
                        : () => _fotoSecVeYukle(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(context.l10n.gorevGaleridenSec),
                  ),
                  if (_fotoBekliyor)
                    TextButton.icon(
                      onPressed: _photoBusy || _busy ? null : _fotoTekrarYukle,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.gorevTekrarYukle),
                    ),
                  if (_photoPath != null || _mevcutFotoUrl != null)
                    TextButton.icon(
                      onPressed: _photoBusy || _busy ? null : _fotoKaldir,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(context.l10n.gorevKaldir),
                    ),
                ],
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
                      ? context.l10n.etkDuyurVeBildir
                      : context.l10n.ortakKaydet),
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

/// Etkinlik gorseli — kisa omurlu presigned GET URL; yuklenemezse SESSIZCE
/// yer tutucu (kart/detay bozulmaz). Dokunma tam ekran gorunum acar.
class _EtkinlikGorseli extends StatelessWidget {
  const _EtkinlikGorseli({required this.url, required this.yukseklik});

  final String url;
  final double yukseklik;

  @override
  Widget build(BuildContext context) {
    final yerTutucu = Container(
      height: yukseklik,
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.image_outlined)),
    );
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: InteractiveViewer(
            child: Image.network(url, errorBuilder: (_, _, _) => yerTutucu),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          height: yukseklik,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => yerTutucu,
        ),
      ),
    );
  }
}

/// image_picker mimeType vermezse uzantidan tahmin (gorev akisiyla ayni).
String _contentTypeFor(XFile file) {
  if (file.mimeType != null) return file.mimeType!;
  final lower = file.path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
  return 'image/jpeg';
}

/// Etkinlik zaman araligi — TARIH/SAAT aktif dile gore bicimlenir.
String _fmtAralikIc(DateTime dt, String dil) =>
    tarihSaatBicimi(dt, dil, ayirici: '');

/// "25.07.2026 18:00 – 21:00" (ayni gun) / "... – 26.07.2026 01:00" (gun asan)
/// / bitis yoksa yalniz baslangic.
String _fmtAralik(Etkinlik e, String dil) {
  final bas = e.tarih.toLocal();
  final bit = e.bitisZamani?.toLocal();
  if (bit == null) return _fmtAralikIc(e.tarih, dil);
  final ayniGun =
      bas.year == bit.year && bas.month == bit.month && bas.day == bit.day;
  return ayniGun
      ? '${_fmtAralikIc(e.tarih, dil)} – ${saatBicimi(e.bitisZamani!, dil)}'
      : '${_fmtAralikIc(e.tarih, dil)} – '
          '${_fmtAralikIc(e.bitisZamani!, dil)}';
}
