import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../data/cameras_api.dart';
import '../domain/camera_models.dart';
import '../../../core/error/akis_hatasi.dart';

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
  late final TextEditingController _adCtrl = TextEditingController(
    text: widget.mevcut?.ad ?? '',
  );
  late final TextEditingController _konumCtrl = TextEditingController(
    text: widget.mevcut?.konum ?? '',
  );
  late final TextEditingController _urlCtrl = TextEditingController(
    text: widget.mevcut?.streamUrl ?? '',
  );
  // P17: RTSP kamerayi oynatilabilir yapan HLS gecidi (Frigate/go2rtc).
  late final TextEditingController _restreamCtrl = TextEditingController(
    text: widget.mevcut?.restreamUrl ?? '',
  );

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
    _restreamCtrl.dispose();
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
      restreamUrl: _restreamCtrl.text.trim(),
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
      // SUNUCU mesaji AYNEN gosterilir (tur 14: istegin dilinde gelir; orn. 409
      // ad cakismasi, 422 URL/tur) — su an TR. Istemci cevirmez.
      setState(() {
        _kaydediyor = false;
        _hata = apiHataMetni(context.l10n, e);
      });
    }
  }

  /// Adres sifrelenmemis mi (uyari gosterilsin mi).
  static bool _sifrelenmemis(String url) =>
      url.trim().toLowerCase().startsWith('http://');

  /// Domain'den gelen hata TURUNU aktif dildeki metne cevirir (metin domain
  /// katmaninda tutulmaz — bkz. [CameraDraft.urlHatasi]).
  String? _urlHataMetni(AppLocalizations l10n, String url) {
    return switch (CameraDraft.urlHatasi(url, _tur)) {
      null => null,
      CameraUrlHatasi.bos => l10n.kameraUrlZorunlu,
      CameraUrlHatasi.rtspSemasiGerekli => l10n.kameraUrlHataRtsp,
      CameraUrlHatasi.httpSemasiGerekli => l10n.kameraUrlHataHttp(_tur.label),
      CameraUrlHatasi.cokUzun => l10n.kameraUrlCokUzun(kCameraUrlUstSinir),
    };
  }

  @override
  Widget build(BuildContext context) {
    final duzenleme = widget.mevcut != null;
    final l10n = context.l10n;
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
                duzenleme ? l10n.kameraDuzenleBaslik : l10n.kameraYeni,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _adCtrl,
                enabled: !_kaydediyor,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: '${l10n.kameraAd} *',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? l10n.ortakZorunluAlan(l10n.kameraAd)
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _konumCtrl,
                enabled: !_kaydediyor,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: l10n.kameraKonum,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              // Tur secici: URL kuralini belirledigi icin URL alanindan ONCE.
              InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.kameraTur,
                  border: const OutlineInputBorder(),
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
                        l10n.kameraRtspFormUyari,
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
                  labelText: '${l10n.kameraUrl} *',
                  // Ipucu bir URL ORNEGIDIR (dile bagli degil).
                  hintText: _tur.ornek,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => _urlHataMetni(l10n, v ?? ''),
                // Sifrelenmemis adres UYARISI (P25b): hata DEGIL — http
                // yayinlar artik oynatiliyor, ama kullanici sifresiz
                // gonderdigini bilmeli.
                onChanged: (_) => setState(() {}),
              ),
              if (_sifrelenmemis(_urlCtrl.text)) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_open_outlined, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.kameraUrlSifrelenmemisUyari,
                        key: const Key('kamera-http-uyari'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              // RESTREAM — YALNIZ rtsp turunde anlamlidir; hls/mp4 zaten
              // oynatilabilir oldugu icin alan GOSTERILMEZ (gereksiz alan
              // formu uzatir ve "bunu da doldurayim mi" tereddudu yaratir).
              if (_tur == CameraTur.rtsp) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _restreamCtrl,
                  enabled: !_kaydediyor,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.kameraRestream,
                    helperText: l10n.kameraRestreamAlt,
                    helperMaxLines: 3,
                    hintText: 'https://... .m3u8',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => switch (CameraDraft.restreamHatasi(v)) {
                    null => null,
                    // Uzunluk asimi ayri metin ister: "http(s) ile baslamali"
                    // demek, zaten https ile baslayan 3 KB'lik bir adreste
                    // yaniltici olurdu.
                    CameraUrlHatasi.cokUzun =>
                      l10n.kameraUrlCokUzun(kCameraUrlUstSinir),
                    CameraUrlHatasi.bos ||
                    CameraUrlHatasi.httpSemasiGerekli ||
                    CameraUrlHatasi.rtspSemasiGerekli =>
                      l10n.kameraRestreamHata,
                  },
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.kameraAktif),
                subtitle: Text(l10n.kameraAktifAlt),
                value: _aktif,
                onChanged: _kaydediyor
                    ? null
                    : (v) => setState(() => _aktif = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.kameraSakinGorebilir),
                subtitle: Text(l10n.kameraSakinGorebilirAlt),
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
                label: Text(
                  _kaydediyor ? l10n.ortakKaydediliyor : l10n.ortakKaydet,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
