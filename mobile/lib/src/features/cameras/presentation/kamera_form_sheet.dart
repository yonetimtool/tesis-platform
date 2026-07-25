import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/cameras_api.dart';
import '../domain/camera_models.dart';

/// Kamera ekle/duzenle formu (admin + yonetici) — alt sayfa.
///
/// Alanlar sozlesmeyle birebir: Ad, Konum (opsiyonel), Yayın URL'si, Tür
/// (HLS/MP4/RTSP), Aktif, "Site sakinleri görebilsin".
///
/// ISTEMCI DOGRULAMASI sunucudaki 422 kuralinin aynisidir
/// ([CameraDraft.urlHatasi]): hls/mp4 → http(s)://, rtsp → rtsp://. Tur
/// degistiginde URL alani YENIDEN dogrulanir (kullanici tutarsiz cifti
/// kaydete basmadan gorur). Sunucu yine de 422 dondurirse mesaji AYNEN
/// gosterilir — istemci kurali sunucununkinin yerine gecmez.
class KameraFormSheet extends ConsumerStatefulWidget {
  const KameraFormSheet({super.key, this.mevcut});

  /// null → yeni kamera; dolu → duzenleme.
  final Camera? mevcut;

  static Future<bool?> ac(BuildContext context, {Camera? mevcut}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => KameraFormSheet(mevcut: mevcut),
    );
  }

  @override
  ConsumerState<KameraFormSheet> createState() => _KameraFormSheetState();
}

class _KameraFormSheetState extends ConsumerState<KameraFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _adCtrl =
      TextEditingController(text: widget.mevcut?.ad ?? '');
  late final TextEditingController _konumCtrl =
      TextEditingController(text: widget.mevcut?.konum ?? '');
  late final TextEditingController _urlCtrl =
      TextEditingController(text: widget.mevcut?.streamUrl ?? '');

  late CameraTur _tur = widget.mevcut?.tur ?? CameraTur.hls;
  late bool _aktif = widget.mevcut?.aktif ?? true;
  late bool _sakinGorebilir = widget.mevcut?.sakinGorebilir ?? false;

  bool _kaydediyor = false;
  String? _hata;

  @override
  void dispose() {
    _adCtrl.dispose();
    _konumCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (!(_formKey.currentState?.validate() ?? false) || _kaydediyor) return;
    setState(() {
      _kaydediyor = true;
      _hata = null;
    });
    final draft = CameraDraft(
      ad: _adCtrl.text.trim(),
      konum: _konumCtrl.text.trim(),
      streamUrl: _urlCtrl.text.trim(),
      tur: _tur,
      aktif: _aktif,
      sakinGorebilir: _sakinGorebilir,
    );
    try {
      final api = ref.read(camerasApiProvider);
      if (widget.mevcut == null) {
        await api.create(draft);
      } else {
        await api.update(widget.mevcut!.id, draft);
      }
      // Kaydedilen kamera TUM listelerde (ana ekran seridi + izgara) gorunsun.
      ref.invalidate(camerasProvider);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      // Sunucu mesaji AYNEN gosterilir (orn. 409 ad cakismasi, 422 URL/tur).
      setState(() {
        _kaydediyor = false;
        _hata = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final duzenleme = widget.mevcut != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                duzenleme ? 'Kamerayı düzenle' : 'Yeni kamera',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _adCtrl,
                enabled: !_kaydediyor,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Ad *',
                  hintText: 'Ana Kapı',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Ad zorunludur' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _konumCtrl,
                enabled: !_kaydediyor,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Konum (opsiyonel)',
                  hintText: 'Ana Kapı - Giriş',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              // Tur secici: URL kuralini belirledigi icin URL alanindan ONCE.
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tür',
                  border: OutlineInputBorder(),
                ),
                child: SegmentedButton<CameraTur>(
                  segments: [
                    for (final t in CameraTur.values)
                      ButtonSegment(value: t, label: Text(t.label)),
                  ],
                  selected: {_tur},
                  showSelectedIcon: false,
                  onSelectionChanged: _kaydediyor
                      ? null
                      : (secim) => setState(() {
                            _tur = secim.first;
                            // Tur degisti → URL kurali degisti: alani yeniden
                            // dogrula (hata metni aninda guncellenir).
                            _formKey.currentState?.validate();
                          }),
                ),
              ),
              if (_tur == CameraTur.rtsp) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'RTSP yayınlar şu an uygulama içinde oynatılamaz. '
                        'Kayıt saklanır; oynatma desteği ileride eklenecek.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              TextFormField(
                controller: _urlCtrl,
                enabled: !_kaydediyor,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Yayın URL\'si *',
                  hintText: _tur.ornek,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => CameraDraft.urlHatasi(v ?? '', _tur),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif'),
                subtitle: const Text('Kapalıyken hiçbir listede görünmez'),
                value: _aktif,
                onChanged:
                    _kaydediyor ? null : (v) => setState(() => _aktif = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Site sakinleri görebilsin'),
                subtitle: const Text(
                  'Kapalıyken kamerayı yalnızca yönetim ve güvenlik görür',
                ),
                value: _sakinGorebilir,
                onChanged: _kaydediyor
                    ? null
                    : (v) => setState(() => _sakinGorebilir = v),
              ),
              if (_hata != null) ...[
                const SizedBox(height: 8),
                Text(_hata!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _kaydediyor ? null : _kaydet,
                icon: _kaydediyor
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_kaydediyor ? 'Kaydediliyor...' : 'Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
