/// (P253 A2) KENDI KARO DOSYAMIZLA HARITA — mobil.
///
/// Karolar ucuncu bir firmadan DEGIL, kendi depomuzdaki tek Turkiye
/// kesitinden (Protomaps PMTiles, `karo` kovasi, HTTP range) gelir; adres
/// `GET /ozellikler` `harita_karo_url`. Web AYNI dosyayi okur.
///
/// * KVKK: kullanicinin konumu/IP'si ucuncu tarafa gitmez.
/// * ONBELLEK: dosya adi SURUMLU (`turkiye-<tarih>.pmtiles`) ve sunucu
///   `immutable` diyor; karolar cihazda uzun sure saklanir
///   ([_onbellekSuresi]) — ayni karo tekrar tekrar inmez. Yeni surum yeni
///   ad oldugu icin bayat onbellek sorunu olmaz.
/// * ATIF ZORUNLU (ODbL): "© OpenStreetMap katkicilari" haritanin
///   kosesinde HER ZAMAN gorunur.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';

import '../i18n/l10n.dart';
import '../ozellikler/ozellik_bayraklari.dart';

const _onbellekSuresi = Duration(days: 365);
const _anaKaynak = 'protomaps';

/// PMTiles okuyucusu — adres basina BIR kez acilir (baslik + dizin).
final _pmtilesProvider =
    FutureProvider.family<VectorTileProvider, String>((ref, url) async {
  return PmTilesVectorTileProvider.fromSource(url);
});

/// Harita: kendi karolarimiz + verilen katmanlar + atif.
class KaroHaritasi extends ConsumerWidget {
  const KaroHaritasi({
    super.key,
    required this.merkez,
    this.zoom = 16,
    this.katmanlar = const [],
    this.controller,
    this.onDokun,
    this.onHareketBitti,
  });

  final LatLng merkez;
  final double zoom;
  final List<Widget> katmanlar;
  final MapController? controller;
  final void Function(LatLng nokta)? onDokun;

  /// Kullanici haritayi kaydirmayi/yakinlastirmayi BITIRINCE merkez.
  final void Function(LatLng merkez)? onHareketBitti;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final url = ref.watch(haritaKaroUrlProvider);
    if (url == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l10n.harKapali, key: const Key('harita-kapali'), textAlign: TextAlign.center),
        ),
      );
    }
    final koyu = Theme.of(context).brightness == Brightness.dark;
    final saglayici = ref.watch(_pmtilesProvider(url));
    return Stack(
      children: [
        FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: merkez,
            initialZoom: zoom,
            maxZoom: 19,
            onTap: onDokun == null ? null : (_, nokta) => onDokun!(nokta),
            onMapEvent: onHareketBitti == null
                ? null
                : (e) {
                    if (e is MapEventMoveEnd || e is MapEventFlingAnimationEnd ||
                        e is MapEventDoubleTapZoomEnd || e is MapEventScrollWheelZoom) {
                      onHareketBitti!(e.camera.center);
                    }
                  },
          ),
          children: [
            ...saglayici.when(
              data: (p) => [
                VectorTileLayer(
                  key: const Key('karo-katmani'),
                  theme: koyu ? ProtomapsThemes.dark() : ProtomapsThemes.light(),
                  tileProviders: TileProviders({_anaKaynak: p}),
                  fileCacheTtl: _onbellekSuresi,
                ),
              ],
              loading: () => const <Widget>[],
              error: (_, _) => const <Widget>[],
            ),
            ...katmanlar,
          ],
        ),
        if (saglayici.hasError)
          Center(child: Text(l10n.harYuklenemedi, key: const Key('harita-hata'))),
        Positioned(
          right: 4,
          bottom: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(l10n.harOsmAtif,
                  key: const Key('harita-atif'), style: const TextStyle(fontSize: 11)),
            ),
          ),
        ),
      ],
    );
  }
}
