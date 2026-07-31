/// Okutma konumu (P34) — GPS'i ALIR ama okutmayi ASLA ENGELLEMEZ.
///
/// Kural: konum bir KANITTIR, bir ON KOSUL DEGIL. Izin reddedildiginde veya
/// sinyal gelmediginde okutmayi durdurmak, gorevlinin isini yapmasini
/// engellerdi; sessizce konumsuz gondermek ise BOSLUGU GIZLERDI. Bu yuzden
/// her sonuc bir DURUM tasir ve sunucuya o durum yazilir.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Sunucudaki `konum_durumu` enum'unun istemci karsiligi (bkz.
/// `contracts/openapi.yaml` → ScanCreate.konum_durumu).
enum KonumDurumu { var_, izinYok, servisKapali, zamanAsimi, bilinmiyor }

/// Sozlesme degeri (wire ASCII, UI degil).
const konumDurumuKodu = {
  KonumDurumu.var_: 'var',
  KonumDurumu.izinYok: 'izin_yok',
  KonumDurumu.servisKapali: 'servis_kapali',
  KonumDurumu.zamanAsimi: 'zaman_asimi',
  KonumDurumu.bilinmiyor: 'bilinmiyor',
};

KonumDurumu konumDurumuCoz(String? kod) => konumDurumuKodu.entries
    .firstWhere((e) => e.value == kod,
        orElse: () => const MapEntry(KonumDurumu.bilinmiyor, 'bilinmiyor'))
    .key;

/// Tek bir konum denemesinin sonucu.
class KonumSonucu {
  const KonumSonucu(this.durum, {this.lat, this.lng, this.dogrulukM});

  const KonumSonucu.yok(KonumDurumu durum) : this(durum);

  final KonumDurumu durum;
  final double? lat;
  final double? lng;

  /// Metre. Sunucu bunu AYRI tutar: 5 m ile 2 km dogruluk ekranda ayni
  /// gorunurdu ve ikincisi "gorevli noktadaydi" kanit degeri tasimaz.
  final double? dogrulukM;

  bool get konumVar => durum == KonumDurumu.var_;
}

/// Konum kaynagi — testte sahtelenebilsin diye arayuz.
abstract class KonumKaynagi {
  Future<KonumSonucu> al({Duration zamanAsimi});
}

/// Izin/servis durumundan SONUC uretir — eklenti CAGRISI YOK, saf esleme.
///
/// Ayri fonksiyon: eslemenin dogrulugu (ozellikle "kalici ret de izin_yok"
/// ve "servis kapali izin_yok DEGIL") eklentisiz test edilebilmeli.
KonumSonucu konumEngeli({
  required bool servisAcik,
  required LocationPermission izin,
}) {
  if (!servisAcik) return const KonumSonucu.yok(KonumDurumu.servisKapali);
  if (izin == LocationPermission.denied ||
      izin == LocationPermission.deniedForever) {
    return const KonumSonucu.yok(KonumDurumu.izinYok);
  }
  return const KonumSonucu.yok(KonumDurumu.bilinmiyor);
}

class GeolocatorKonumKaynagi implements KonumKaynagi {
  const GeolocatorKonumKaynagi();

  @override
  Future<KonumSonucu> al({Duration zamanAsimi = const Duration(seconds: 6)}) async {
    try {
      final servis = await Geolocator.isLocationServiceEnabled();
      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }
      final engel = konumEngeli(servisAcik: servis, izin: izin);
      if (engel.durum != KonumDurumu.bilinmiyor) return engel;

      final konum = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: zamanAsimi,
        ),
      );
      return KonumSonucu(
        KonumDurumu.var_,
        lat: konum.latitude,
        lng: konum.longitude,
        dogrulukM: konum.accuracy,
      );
    } on TimeoutException {
      return const KonumSonucu.yok(KonumDurumu.zamanAsimi);
    } catch (_) {
      // Eklenti/platform hatasi okutmayi DUSURMEZ: konum kaniti eksik
      // kalir, tur kaydi durur. Hangi hata oldugu kullaniciya bir sey
      // ifade etmez; onemli olan BOSLUGUN GORUNMESIDIR.
      return const KonumSonucu.yok(KonumDurumu.bilinmiyor);
    }
  }
}

final konumKaynagiProvider = Provider<KonumKaynagi>(
  (ref) => const GeolocatorKonumKaynagi(),
);
