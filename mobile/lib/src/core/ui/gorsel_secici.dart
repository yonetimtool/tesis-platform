/// (P251 §5) ORTAK GORSEL SECICI — cek/sec → presign → PUT → foto_key.
///
/// Etkinlik ve duyuru formlari bu akisi KENDI ICLERINDE tasiyordu (gorev
/// foto kaniti deseni). Rezervasyon alani gorsel alinca ucuncu kopya
/// olacakti; yeni formlar bu bileseni kullanir. Web ikizi
/// `components/gorsel/gorsel-secici.tsx`.
///
/// Durum ust bilesene [GorselSecim] ile bildirilir:
///   * `fotoKey`   : yeni yukleme tamamlandi -> govdeye anahtar,
///   * `kaldirildi`: mevcut gorsel ACIKCA kaldirildi -> govdeye null,
///   * `bekliyor`  : yukleme suruyor ya da dustu -> kaydetme engellenir.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/tasks/domain/task_models.dart' show PresignTicket;
import '../../features/tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;
import '../error/akis_hatasi.dart';
import '../error/api_exception.dart';
import '../i18n/l10n.dart';
import '../network/dio_provider.dart';
import 'icerik_gorseli.dart';

class GorselSecim {
  const GorselSecim({this.fotoKey, this.kaldirildi = false, this.bekliyor = false});
  final String? fotoKey;
  final bool kaldirildi;
  final bool bekliyor;

  /// PATCH/POST govdesine yazar: yeni -> anahtar, kaldir -> null,
  /// dokunulmadi -> alan HIC yazilmaz (sunucu mevcudu korur).
  void govdeye(Map<String, dynamic> govde) {
    if (fotoKey != null) {
      govde['foto_key'] = fotoKey;
    } else if (kaldirildi) {
      govde['foto_key'] = null;
    }
  }
}

/// Gorsel yukleme cagrisi — testte taklit edilebilsin diye saglayici.
final gorselYukleyiciProvider = Provider<GorselYukleyici>(
  (ref) => GorselYukleyici(ref.watch(dioProvider)),
);

class GorselYukleyici {
  GorselYukleyici(this._dio, {Dio? yuklemeDio}) : _yukleme = yuklemeDio ?? Dio();
  final Dio _dio;

  /// Imzali PUT'a `Authorization` gitmemeli (bazi depolarda imzayi bozar).
  final Dio _yukleme;

  Future<String> yukle(XFile dosya) async {
    final tur = _icerikTuru(dosya);
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/uploads/presign',
        data: {'content_type': tur, 'dosya_adi': dosya.name},
      );
      final bilet = PresignTicket.fromJson(r.data ?? const {});
      final bytes = await dosya.readAsBytes();
      await _yukleme.put<void>(
        bilet.uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(headers: {
          Headers.contentTypeHeader: tur,
          Headers.contentLengthHeader: bytes.length,
        }),
      );
      return bilet.fotoKey;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

String _icerikTuru(XFile f) {
  if (f.mimeType != null) return f.mimeType!;
  final k = f.path.toLowerCase();
  if (k.endsWith('.png')) return 'image/png';
  if (k.endsWith('.webp')) return 'image/webp';
  if (k.endsWith('.heic') || k.endsWith('.heif')) return 'image/heic';
  return 'image/jpeg';
}

class GorselSecici extends ConsumerStatefulWidget {
  const GorselSecici({
    super.key,
    required this.mevcutUrl,
    required this.tur,
    required this.onDegisti,
    this.devreDisi = false,
  });

  /// Duzenlenen kaydin mevcut gorseli (imzali adres).
  final String? mevcutUrl;
  final IcerikTuru tur;
  final ValueChanged<GorselSecim> onDegisti;
  final bool devreDisi;

  @override
  ConsumerState<GorselSecici> createState() => _GorselSeciciState();
}

class _GorselSeciciState extends ConsumerState<GorselSecici> {
  String? _yol;
  String? _anahtar;
  bool _mesgul = false;
  bool _kaldirildi = false;
  String? _hata;

  void _bildir() => widget.onDegisti(GorselSecim(
    fotoKey: _anahtar,
    kaldirildi: _kaldirildi,
    bekliyor: _mesgul || (_yol != null && _anahtar == null),
  ));

  Future<void> _sec(ImageSource kaynak) async {
    final l10n = context.l10n;
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    _bildir();
    try {
      final dosya = await ref
          .read(imagePickerProvider)
          .pickImage(source: kaynak, maxWidth: 1600, imageQuality: 80);
      if (!mounted) return;
      if (dosya == null) {
        setState(() => _mesgul = false);
        _bildir();
        return;
      }
      setState(() {
        _yol = dosya.path;
        _anahtar = null;
        _kaldirildi = false;
      });
      final anahtar = await ref.read(gorselYukleyiciProvider).yukle(dosya);
      if (!mounted) return;
      setState(() {
        _anahtar = anahtar;
        _mesgul = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _mesgul = false;
        _hata = e.kind == ApiErrorKind.network
            ? l10n.gorevFotoOnlineGerekli
            : apiHataMetni(l10n, e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mesgul = false;
        _hata = l10n.gorevFotoAlinamadi('$e');
      });
    }
    _bildir();
  }

  void _kaldir() {
    setState(() {
      _yol = null;
      _anahtar = null;
      _hata = null;
      _kaldirildi = widget.mevcutUrl != null;
    });
    _bildir();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kilitli = _mesgul || widget.devreDisi;
    final mevcut = _kaldirildi ? null : widget.mevcutUrl;
    return Column(
      key: const Key('gorsel-secici'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.etkGorselAlan),
        const SizedBox(height: 8),
        if (_yol != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.file(
                File(_yol!),
                fit: BoxFit.cover,
                // Gecici dosya silinmisse onizleme kirik kalmasin.
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          )
        else
          IcerikGorseli(url: mevcut, boy: IcerikGorseliBoy.buyuk, tur: widget.tur),
        if (_mesgul)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
        if (_hata != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_hata!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              key: const Key('gorsel-kamera'),
              onPressed: kilitli ? null : () => _sec(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l10n.gorevKamera),
            ),
            TextButton.icon(
              key: const Key('gorsel-galeri'),
              onPressed: kilitli ? null : () => _sec(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(l10n.gorevGaleridenSec,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (_yol != null || mevcut != null)
              TextButton.icon(
                key: const Key('gorsel-kaldir'),
                onPressed: kilitli ? null : _kaldir,
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.gorevKaldir,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ],
    );
  }
}
