/// "Bugun" sekmesinin ozet sayilari — SAF fonksiyon (birim testli).
/// `GET /dashboard/live` bugune ait TUM pencereleri doner (durum dahil);
/// siniflama zaman + duruma gore yapilir.
library;

import 'patrol_models.dart';

class TrackingOzet {
  const TrackingOzet({
    this.aktif = 0,
    this.yaklasan = 0,
    this.tamamlandi = 0,
    this.kacirildi = 0,
  });

  /// Su an icinde olunan bekliyor-durumlu pencereler (devriye SAHADA olmali).
  final int aktif;

  /// Bugun henuz baslamamis pencereler.
  final int yaklasan;

  final int tamamlandi;
  final int kacirildi;

  int get toplam => aktif + yaklasan + tamamlandi + kacirildi;
}

TrackingOzet trackingOzet(List<ActivePatrolWindow> windows, DateTime now) {
  var aktif = 0, yaklasan = 0, tamamlandi = 0, kacirildi = 0;
  for (final w in windows) {
    if (w.durum == PatrolWindowDurum.tamamlandi) {
      tamamlandi++;
    } else if (w.durum == PatrolWindowDurum.kacirildi) {
      kacirildi++;
    } else if (w.isActiveAt(now)) {
      aktif++;
    } else if (w.isUpcomingAt(now)) {
      yaklasan++;
    } else {
      // bekliyor + suresi gecmis (henuz kacirildi'ya cekilmemis) →
      // kacirilmis say: yonetici icin dogru sinyal, scheduler birazdan
      // durumu zaten cevirecek.
      kacirildi++;
    }
  }
  return TrackingOzet(
    aktif: aktif,
    yaklasan: yaklasan,
    tamamlandi: tamamlandi,
    kacirildi: kacirildi,
  );
}
