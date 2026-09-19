// (P147) Bildirime dokununca ILGILI ekrana gitmeli.
//
// Kerem'in sarti: "kargonuz geldi bildirimine tiklayinca kargo sayfasina,
// talebiniz cozuldu bildirimine tiklayinca talep/ariza sayfasina".
// Burada olculen sey tam olarak bu esleme — ve bir de esleme YOKKEN
// uydurma hedef verilmedigi.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/notifications/domain/notification_models.dart';
import 'package:mobile/src/features/notifications/presentation/bildirim_rotasi.dart';
import 'package:mobile/src/routing/app_router.dart';

AppNotification _b(String tip) => AppNotification.fromJson({
      'id': 'n1',
      'tip': tip,
      'mesaj': 'metin',
      'okundu': false,
      'created_at': '2026-08-06T09:00:00Z',
    });

void main() {
  test('sakinin olaylari ILGILI ekrana gider', () {
    expect(bildirimRotasi(_b('kargo')), AppRoutes.kargo);
    expect(bildirimRotasi(_b('ziyaretci')), AppRoutes.visitors);
    expect(bildirimRotasi(_b('rezervasyon')), AppRoutes.rezervasyon);
    expect(bildirimRotasi(_b('sikayet_cozuldu')), AppRoutes.sikayetlerim);
  });

  test('talep akisi talep/ariza sayfasina gider (P22b korunuyor)', () {
    for (final t in ['talep_is_emri', 'talep_cozuldu', 'talep_reddedildi']) {
      expect(bildirimRotasi(_b(t)), AppRoutes.complaints, reason: t);
    }
  });

  test('(P241) P240 bildirim aileleri KENDI ekranina gider', () {
    // PAKET OLCUMUNDE YAKALANDI: P240'ta uc bildirim ailesi eklendi ama
    // yonlendirme beyaz listesi guncellenmemisti — panik push'una dokunan
    // kullanici alarm ekranina GITMIYORDU. Acil durumda en pahali
    // sessiz kusur, ve kaynak testi degil PAKET SONDASI gosterdi.
    for (final t in ['panik_alarm', 'panik_yanlis_alarm', 'panik_kapandi']) {
      expect(bildirimRotasi(_b(t)), AppRoutes.panikTakip, reason: t);
    }
    for (final t in ['akilli_ev_kacak', 'akilli_ev_yangin']) {
      expect(bildirimRotasi(_b(t)), AppRoutes.akilliEv, reason: t);
    }
    expect(bildirimRotasi(_b('entegrasyon_koptu')), AppRoutes.integrations);
  });

  test('(P241) BAKIM ve VARDIYA YAYINI kendi ekranina gider', () {
    // P240'takinin AYNISI: yeni bildirim ailesi eklenip beyaz liste
    // guncellenmezse push'a dokunan kullanici HICBIR YERE gitmez ve
    // kaynak testleri bunu goremez ("bilinmeyen tipe null" TASARIM).
    for (final t in ['bakim_yaklasti', 'bakim_bugun', 'bakim_gecikti']) {
      expect(bildirimRotasi(_b(t)), AppRoutes.bakim, reason: t);
    }
    expect(bildirimRotasi(_b('vardiya_yayinlandi')), AppRoutes.vardiyaPlani);
  });

  test('bilinmeyen tip UYDURMA hedefe gitmez — null doner', () {
    expect(bildirimRotasi(_b('bir_gun_eklenecek')), isNull);
  });
}
