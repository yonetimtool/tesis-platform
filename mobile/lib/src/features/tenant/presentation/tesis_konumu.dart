/// (P253 A2) TESIS KONUMU — mobil (web `KonumSecici` ile ayni akis).
///
/// 1. Yer adi aranir (`GET /konum/ara`); sunucu aday LISTESI doner — ilk
///    sonuc otomatik secilmez ("Oltu" Erzurum'da da Artvin'de de var).
/// 2. Secilen aday haritada gosterilir; igne EKRANIN ORTASINDA sabittir,
///    yonetici haritayi kaydirarak (ya da dokunarak) binanin uzerine getirir.
/// 3. Deger ayarlar formunun bir parcasidir: "Kaydet" ile diger ayarlarla
///    birlikte `PATCH /tenant/settings` (konum_ad/lat/lon) gider.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/girdi_siniri.dart';
import '../../../core/harita/karo_haritasi.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/network/dio_provider.dart';

class KonumAdayi {
  const KonumAdayi({required this.ad, required this.aciklama, required this.lat, required this.lon});
  final String ad;
  final String aciklama;
  final double lat;
  final double lon;

  factory KonumAdayi.fromJson(Map<String, dynamic> j) => KonumAdayi(
        ad: j['ad'] as String? ?? '',
        aciklama: j['aciklama'] as String? ?? '',
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
      );
}

class KonumApi {
  KonumApi(this._dio);
  final Dio _dio;

  Future<List<KonumAdayi>> ara(String q) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/konum/ara', queryParameters: {'q': q});
      final items = r.data?['items'];
      if (items is! List) return const [];
      return [for (final m in items.whereType<Map>()) KonumAdayi.fromJson(Map<String, dynamic>.from(m))];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final konumApiProvider = Provider<KonumApi>((ref) => KonumApi(ref.watch(dioProvider)));

/// Secilen konum (ad + koordinat).
typedef SeciliKonum = ({String ad, double lat, double lon});

class TesisKonumuBolumu extends ConsumerStatefulWidget {
  const TesisKonumuBolumu({super.key, required this.mevcut, required this.onDegisti});

  final SeciliKonum? mevcut;
  final void Function(SeciliKonum konum) onDegisti;

  @override
  ConsumerState<TesisKonumuBolumu> createState() => _TesisKonumuBolumuState();
}

class _TesisKonumuBolumuState extends ConsumerState<TesisKonumuBolumu> {
  final _sorgu = TextEditingController();
  final _harita = MapController();
  List<KonumAdayi>? _adaylar;
  bool _ariyor = false;
  String? _hata;
  late SeciliKonum? _konum = widget.mevcut;

  @override
  void dispose() {
    _sorgu.dispose();
    _harita.dispose();
    super.dispose();
  }

  Future<void> _ara() async {
    final q = _sorgu.text.trim();
    if (q.length < 2) return;
    setState(() {
      _ariyor = true;
      _hata = null;
    });
    try {
      final sonuc = await ref.read(konumApiProvider).ara(q);
      if (!mounted) return;
      setState(() => _adaylar = sonuc);
    } on ApiException {
      // Bos liste DEGIL: "boyle bir yer yok" demek servis coktugunde yanlis.
      if (mounted) setState(() => _hata = context.l10n.harAramaHata);
    } finally {
      if (mounted) setState(() => _ariyor = false);
    }
  }

  void _sec(SeciliKonum k) {
    setState(() {
      _konum = k;
      _adaylar = null;
    });
    widget.onDegisti(k);
  }

  void _tasi(LatLng p) {
    final k = _konum;
    if (k == null) return;
    final yeni = (ad: k.ad, lat: double.parse(p.latitude.toStringAsFixed(6)), lon: double.parse(p.longitude.toStringAsFixed(6)));
    if (yeni.lat == k.lat && yeni.lon == k.lon) return;
    setState(() => _konum = yeni);
    widget.onDegisti(yeni);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ikincil = Theme.of(context).colorScheme.onSurfaceVariant;
    final k = _konum;
    return Column(
      key: const Key('tesis-konumu'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.harTesisKonumu, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('konum-ara'),
                controller: _sorgu,
                maxLength: GirdiSiniri.arama,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _ara(),
                decoration: InputDecoration(
                  labelText: l10n.harYerAdi,
                  hintText: k?.ad,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('konum-ara-dugme'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _ariyor ? null : _ara,
              child: Text(l10n.harAra),
            ),
          ],
        ),
        if (_hata != null) ...[
          const SizedBox(height: 6),
          Text(_hata!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        if (_adaylar != null && _adaylar!.isEmpty) ...[
          const SizedBox(height: 6),
          Text(l10n.harSonucYok, style: TextStyle(color: ikincil)),
        ],
        if (_adaylar != null && _adaylar!.isNotEmpty)
          for (final a in _adaylar!)
            ListTile(
              key: Key('konum-aday-${a.lat}'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined),
              title: Text(a.ad),
              subtitle: Text(a.aciklama),
              onTap: () => _sec((ad: a.ad, lat: a.lat, lon: a.lon)),
            ),
        if (k != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  KaroHaritasi(
                    key: ValueKey('${k.ad}'),
                    controller: _harita,
                    merkez: LatLng(k.lat, k.lon),
                    onHareketBitti: _tasi,
                    onDokun: (p) {
                      _harita.move(p, _harita.camera.zoom);
                      _tasi(p);
                    },
                  ),
                  // Igne ORTADA SABIT: harita kayar, igne kalir.
                  IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 36),
                        child: Icon(Icons.location_on, size: 40,
                            color: Theme.of(context).colorScheme.primary, key: const Key('konum-igne')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(l10n.harIgneIpucu, style: TextStyle(fontSize: 12, color: ikincil)),
          Text(l10n.harSecili(k.ad, k.lat.toStringAsFixed(5), k.lon.toStringAsFixed(5)),
              key: const Key('konum-secili'), style: TextStyle(fontSize: 12, color: ikincil)),
        ],
      ],
    );
  }
}
