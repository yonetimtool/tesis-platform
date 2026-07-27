import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
// imagePickerProvider YENIDEN kullanilir (kopya yok) — gorev/duyuru/talep
// foto akisiyla ayni saglayici (testlerde tek noktadan override edilir).
import '../../tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;
import '../data/kargo_api.dart';
import '../domain/kargo_models.dart';
import 'kargo_controller.dart';
import 'kargo_durum_adi.dart';

/// "Kargo" — paket takibi (auth.md §4 kesin kurali, UX aynasi):
///   * security: "Yeni kargo" FAB'i (daire no + firma + opsiyonel foto/not,
///     foto mevcut Kamera/Galeri presign akisiyla) + tenant'in tum kayitlari.
///   * resident: KENDI dairesinin paketleri; BEKLEYEN paket belirgin kart —
///     "Teslim aldim" butonu (ilk isaret gecerli; 409'da guncel durum cekilir).
///   * admin/yonetici: salt izleme (gecmis gorunumu).
///
/// [initialKargoId] push tiklamasindan gelir (?kargo_id=...): liste
/// yuklendiginde ilgili kaydin detayi BIR KEZ otomatik acilir; kayit listede
/// yoksa (yetki disi/silinmis) sessizce listede kalinir.
class KargoScreen extends ConsumerStatefulWidget {
  const KargoScreen({super.key, this.initialKargoId});

  final String? initialKargoId;

  @override
  ConsumerState<KargoScreen> createState() => _KargoScreenState();
}

class _KargoScreenState extends ConsumerState<KargoScreen> {
  bool _initialHandled = false;

  void _maybeOpenInitial(KargoState state) {
    if (_initialHandled || widget.initialKargoId == null) return;
    if (state.loading) return;
    _initialHandled = true;
    Kargo? hedef;
    for (final k in state.items) {
      if (k.id == widget.initialKargoId) {
        hedef = k;
        break;
      }
    }
    if (hedef == null) return; // listede yok — sessizce listede kal
    final k = hedef;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showDetail(context, k, canReceive: state.canReceive);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kargoControllerProvider);
    final controller = ref.read(kargoControllerProvider.notifier);
    ref.listen(kargoControllerProvider, (_, next) => _maybeOpenInitial(next));
    // Provider zaten yuklu geldiyse (listen tetiklenmez) mevcut durumu isle.
    _maybeOpenInitial(state);

    final bekleyen =
        state.items.where((k) => k.bekliyor).toList(growable: false);
    final teslim =
        state.items.where((k) => !k.bekliyor).toList(growable: false);
    final l10n = context.l10n;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(baslikBuyuk(l10n.karBaslik, context.dilKodu)),
          actions: [
            IconButton(
              tooltip: l10n.ortakYenile,
              icon: const Icon(Icons.refresh),
              onPressed: state.loading ? null : controller.refresh,
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.karSekmeBekleyen(bekleyen.length)),
              Tab(text: l10n.karSekmeTeslim(teslim.length)),
            ],
          ),
        ),
        floatingActionButton: state.canRegister
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.local_shipping_outlined),
                label: Text(l10n.karYeni),
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
                emptyText: state.canReceive
                    ? l10n.karBekleyenYokSakin
                    : l10n.karBekleyenYok,
              ),
            ),
            RefreshIndicator(
              onRefresh: controller.refresh,
              child: _Body(
                state: state,
                items: teslim,
                emptyText: l10n.karTeslimYok,
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
      builder: (_) => const _KargoForm(),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.karKaydedildi)),
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

  final KargoState state;

  /// Bu sekmenin kayitlari (Bekleyen / Teslim alinan).
  final List<Kargo> items;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final hata = akisHatasiCoz(
      context.l10n,
      state.hataKimligi,
      state.errorMessage,
    );
    if (hata != null && state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            hata,
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
      itemBuilder: (context, i) => _KargoCard(
        kargo: items[i],
        canReceive: state.canReceive,
      ),
    );
  }
}

/// Durum rozeti — renk kodu: bekliyor=turuncu, teslim_alindi=yesil.
class _DurumChip extends StatelessWidget {
  const _DurumChip({required this.durum});

  final KargoDurum durum;

  Color get _color => switch (durum) {
        KargoDurum.bekliyor => Colors.orange,
        KargoDurum.teslimAlindi => Colors.green,
        KargoDurum.unknown => Colors.grey,
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
        kargoDurumAdi(context.l10n, durum),
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _KargoCard extends ConsumerWidget {
  const _KargoCard({required this.kargo, required this.canReceive});

  final Kargo kargo;
  final bool canReceive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = kargo;
    final l10n = context.l10n;
    final dil = context.dilKodu;
    // Sakin icin BEKLEYEN paket belirgin: kapida kargo teslim bekliyor.
    final vurgulu = k.bekliyor && canReceive;
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
        onTap: () => _showDetail(context, k, canReceive: canReceive),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Foto varsa kucuk onizleme; yoksa paket ikonu.
                  if (k.fotoUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        k.fotoUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.inventory_2_outlined,
                          size: 32,
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.inventory_2_outlined, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      k.firma,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  _DurumChip(durum: k.durum),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l10n.karDaireTarih(
                  k.unitNo ?? '-',
                  tarihSaatBicimi(k.createdAt, dil),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (k.notlar != null && k.notlar!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(k.notlar!, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              if (!k.bekliyor) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _teslimSatiri(l10n, dil, k),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              if (vurgulu) ...[
                const SizedBox(height: 12),
                _ReceiveButton(kargoId: k.id),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Teslim aldim" butonu — sakinin bekleyen kartinda ve detayda kullanilir.
/// Istek sirasinda kilitlenir; 409 (es zaten teslim aldi) mesaji SnackBar'da
/// gosterilir, liste guncel duruma tazelenir (controller).
class _ReceiveButton extends ConsumerStatefulWidget {
  const _ReceiveButton({required this.kargoId, this.onReceived});

  final String kargoId;

  /// Detay sheet'inden cagrildiginda teslim sonrasi sheet'i kapatmak icin.
  final VoidCallback? onReceived;

  @override
  ConsumerState<_ReceiveButton> createState() => _ReceiveButtonState();
}

class _ReceiveButtonState extends ConsumerState<_ReceiveButton> {
  bool _busy = false;

  Future<void> _receive() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    // Async bosluktan ONCE yakala: sonrasinda context kullanilmaz.
    final l10n = context.l10n;
    try {
      await ref
          .read(kargoControllerProvider.notifier)
          .markReceived(widget.kargoId);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.karTeslimAlindiBildirim)),
      );
      widget.onReceived?.call();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
      widget.onReceived?.call();
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.karIsaretlenemedi)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: Colors.green),
        icon: const Icon(Icons.check),
        label: Text(context.l10n.karTeslimAldim),
        onPressed: _busy ? null : _receive,
      ),
    );
  }
}

/// Detay alt sayfasi — push tiklamasi ve kart dokunusuyla acilir. Sakin +
/// bekleyen pakette "Teslim aldim" burada da sunulur; foto buyuk gorunur.
void _showDetail(BuildContext context, Kargo k, {required bool canReceive}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      final dil = sheetContext.dilKodu;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      k.firma,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _DurumChip(durum: k.durum),
                ],
              ),
              const SizedBox(height: 12),
              Text(l10n.karDaire(k.unitNo ?? '-')),
              const SizedBox(height: 4),
              Text('${l10n.karKayit(tarihSaatBicimi(k.createdAt, dil))}'
                  '${k.kaydedenAd != null ? l10n.karAdEki(k.kaydedenAd!) : ''}'),
              if (k.notlar != null && k.notlar!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(l10n.karNot(k.notlar!)),
              ],
              if (!k.bekliyor) ...[
                const SizedBox(height: 4),
                Text(_teslimSatiri(l10n, dil, k)),
              ],
              if (k.fotoUrl != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    k.fotoUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : const SizedBox(
                                height: 180,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                    errorBuilder: (_, _, _) => Container(
                      height: 48,
                      // YON-DUYARLI: Arapca'da saga hizalanir.
                      alignment: AlignmentDirectional.centerStart,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Row(
                        children: [
                          const Icon(Icons.broken_image_outlined, size: 20),
                          const SizedBox(width: 8),
                          // Dar ekranda (320 dp) satira sigmiyor — sar.
                          Expanded(child: Text(l10n.talepGorselYuklenemedi)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (k.bekliyor && canReceive) ...[
                const SizedBox(height: 20),
                _ReceiveButton(
                  kargoId: k.id,
                  onReceived: () => Navigator.of(sheetContext).pop(),
                ),
              ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Teslim satiri: "Teslim alindi — {ad} · {zaman}" (ad/zaman opsiyonel).
String _teslimSatiri(AppLocalizations l10n, String dil, Kargo k) =>
    '${l10n.kargoDurumTeslimAlindi}'
    '${k.teslimAlanAd != null ? l10n.karAdEki(k.teslimAlanAd!) : ''}'
    '${k.teslimZamani != null ? l10n.karZamanEki(tarihSaatBicimi(k.teslimZamani!, dil)) : ''}';

/// Yeni kargo formu (yalniz guvenlik): daire no + firma + opsiyonel foto/not.
/// Foto akisi complaints/gorev formuyla AYNI: cek/sec → presign → PUT →
/// foto_key (yeni upload yolu yok).
class _KargoForm extends ConsumerStatefulWidget {
  const _KargoForm();

  @override
  ConsumerState<_KargoForm> createState() => _KargoFormState();
}

class _KargoFormState extends ConsumerState<_KargoForm> {
  final _formKey = GlobalKey<FormState>();
  final _firma = TextEditingController();
  final _unitNo = TextEditingController();
  final _notlar = TextEditingController();
  bool _busy = false;
  String? _hata;

  /// Secilen fotonun cihaz yolu (onizleme). [_fotoKey] dolu ise yukleme
  /// tamamlanmistir; secili olup yuklenmemisse gonderim beklemeli.
  String? _photoPath;
  bool _photoBusy = false;
  String? _photoError;
  String? _fotoKey;

  bool get _fotoBekliyor => _photoPath != null && _fotoKey == null;

  @override
  void dispose() {
    _firma.dispose();
    _unitNo.dispose();
    _notlar.dispose();
    super.dispose();
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    if (_photoBusy) return;
    setState(() {
      _photoBusy = true;
      _photoError = null;
    });
    try {
      final file = await ref.read(imagePickerProvider).pickImage(
            source: source,
            // Paket fotografi icin cozunurluk/kalite dusurulur (yukleme boyutu).
            maxWidth: 1600,
            imageQuality: 80,
          );
      if (!mounted) return;
      if (file == null) {
        // Kullanici vazgecti — mevcut secim korunur.
        setState(() => _photoBusy = false);
        return;
      }
      setState(() {
        _photoPath = file.path;
        // Eski yukleme gecersiz: yeni foto secildi.
        _fotoKey = null;
      });
      await _uploadPhoto(file);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _photoBusy = false;
        _photoError = _l10n.gorevFotoAlinamadi('$e');
      });
    }
  }

  Future<void> _retryUpload() async {
    final path = _photoPath;
    if (path == null || _photoBusy) return;
    setState(() {
      _photoBusy = true;
      _photoError = null;
    });
    await _uploadPhoto(XFile(path));
  }

  Future<void> _uploadPhoto(XFile file) async {
    final api = ref.read(kargoApiProvider);
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

  void _removePhoto() {
    setState(() {
      _photoPath = null;
      _photoError = null;
      _fotoKey = null;
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
    setState(() {
      _busy = true;
      _hata = null;
    });
    try {
      await ref.read(kargoControllerProvider.notifier).register(
            KargoDraft(
              firma: _firma.text.trim(),
              unitNo: _unitNo.text.trim(),
              fotoKey: _fotoKey,
              notlar: _notlar.text.trim().isEmpty ? null : _notlar.text.trim(),
            ),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      // 422 invalid_reference: daire numarasi bu tesiste yok — formda goster.
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
          _hata = _l10n.karGonderilemedi;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      // Klavye acilinca form yukari itilsin.
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + viewInsets.bottom),
      child: Form(
        key: _formKey,
        // Foto onizleme + klavye ile icerik uzayabilir — tasma yerine kaydir.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.karYeni,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _unitNo,
                decoration: InputDecoration(
                  labelText: l10n.karDaireNo,
                  border: const OutlineInputBorder(),
                ),
                maxLength: 50,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.karDaireNoGerekli
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _firma,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.karFirma,
                  border: const OutlineInputBorder(),
                ),
                maxLength: 200,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.karFirmaGerekli
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notlar,
                decoration: InputDecoration(
                  labelText: l10n.ortakNotOpsiyonel,
                  border: const OutlineInputBorder(),
                ),
                maxLength: 1000,
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _fotoKey != null
                        ? Icons.check_circle
                        : Icons.image_outlined,
                    color: _fotoKey != null ? Colors.green : null,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  // Dar ekranda (<= 360 dp) etiket satira sigmiyordu; sar.
                  Expanded(child: Text(l10n.karPaketFotografi)),
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
                        : () => _pickAndUploadPhoto(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(_photoPath == null
                        ? l10n.gorevKamera
                        : l10n.gorevYenidenCek),
                  ),
                  TextButton.icon(
                    onPressed: _photoBusy || _busy
                        ? null
                        : () => _pickAndUploadPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(l10n.gorevGaleridenSec),
                  ),
                  if (_photoPath != null && _fotoKey == null)
                    TextButton.icon(
                      onPressed: _photoBusy || _busy ? null : _retryUpload,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.gorevTekrarYukle),
                    ),
                  if (_photoPath != null)
                    TextButton.icon(
                      onPressed: _photoBusy || _busy ? null : _removePhoto,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n.gorevKaldir),
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
                      : const Icon(Icons.local_shipping_outlined),
                  label: Text(l10n.karKaydetVeBildir),
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

/// image_picker mimeType vermezse uzantidan tahmin (gorev/talep akisiyla ayni).
String _contentTypeFor(XFile file) {
  if (file.mimeType != null) return file.mimeType!;
  final lower = file.path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
    return 'image/heic';
  }
  return 'image/jpeg';
}
