/// (P217) `routeForPushData` KALDIRILDI, yerine ROL ALAN `pushHedefi`.
///
/// Bu dosyadaki iddialar KORUNDU — hicbiri yanlis degildi, eksikti:
/// hedefin ROLE bagli olabilecegini hesaba katmiyorlardi. Her cagri
/// artik acik bir rolle yapiliyor; boylece "hangi rol icin dogru"
/// sorusu testin kendisinde de gorunur oluyor.
///
/// Rol-ayrimi ve erisim suzgeci ayrica `p217_push_yonlendirme_test.dart`
/// dosyasinda olculuyor.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/routing/push_yonlendirme.dart';

/// Testlerin cogu YONETIM bakisini olcuyordu; varsayilan rol o.
/// Sakine ozel hedefler kendi testlerinde acikca belirtiliyor.
const _rol = UserRole.yonetici;

void main() {
  group('pushHedefi (push tiklama yonlendirmesi)', () {
    test('tip=talep -> ilgili talep (complaint_id ile)', () {
      expect(
        pushHedefi({'tip': 'talep', 'complaint_id': 'c-1'}, _rol),
        '/complaints?complaint_id=c-1',
      );
    });

    test('tip=talep_yanit -> ilgili talep (sakine yanit push\'u)', () {
      expect(
        pushHedefi({'tip': 'talep_yanit', 'complaint_id': 'c-2'}, _rol),
        '/complaints?complaint_id=c-2',
      );
    });

    test('complaint_id yoksa/bossa talep LISTESI acilir', () {
      expect(pushHedefi({'tip': 'talep'}, _rol), '/complaints');
      expect(
        pushHedefi({'tip': 'talep_yanit', 'complaint_id': ''}, _rol),
        '/complaints',
      );
    });

    test('tip=duyuru -> duyurular', () {
      expect(pushHedefi({'tip': 'duyuru'}, _rol), '/announcements');
    });

    test('tip=ziyaretci -> ilgili ziyaretci (sakine bilgilendirme push\'u)',
        () {
      // (P217) ROL SAKIN: bu bildirimler SAKINE gider ve hedef
      // ekranlar (kargo/ziyaretci/aidatim) yalniz onun menusunde var.
      // Yonetici rolüyle olcmek, gercekte olmayan bir akisi olcmekti.
      expect(
        pushHedefi({'tip': 'ziyaretci', 'visitor_id': 'v-1'}, UserRole.resident),
        '/visitors?visitor_id=v-1',
      );
    });

    test('tip=ziyaretci_sonuc KALDIRILDI -> null (artik onay/red push\'u yok)',
        () {
      expect(
        pushHedefi({'tip': 'ziyaretci_sonuc', 'visitor_id': 'v-2'}, _rol),
        isNull,
      );
    });

    test('tip=kargo -> ilgili kargo (sakine kargonuz-geldi push\'u)', () {
      // (P217) ROL SAKIN: bu bildirimler SAKINE gider ve hedef
      // ekranlar (kargo/ziyaretci/aidatim) yalniz onun menusunde var.
      // Yonetici rolüyle olcmek, gercekte olmayan bir akisi olcmekti.
      expect(
        pushHedefi({'tip': 'kargo', 'kargo_id': 'k-1'}, UserRole.resident),
        '/kargo?kargo_id=k-1',
      );
    });

    test('kargo_id yoksa/bossa kargo LISTESI acilir', () {
      // (P217) ROL SAKIN: bu bildirimler SAKINE gider ve hedef
      // ekranlar (kargo/ziyaretci/aidatim) yalniz onun menusunde var.
      // Yonetici rolüyle olcmek, gercekte olmayan bir akisi olcmekti.
      expect(pushHedefi({'tip': 'kargo'}, UserRole.resident), '/kargo');
      expect(
        pushHedefi({'tip': 'kargo', 'kargo_id': ''}, UserRole.resident),
        '/kargo',
      );
    });

    test('visitor_id yoksa/bossa ziyaretci LISTESI acilir', () {
      // (P217) ROL SAKIN: bu bildirimler SAKINE gider ve hedef
      // ekranlar (kargo/ziyaretci/aidatim) yalniz onun menusunde var.
      // Yonetici rolüyle olcmek, gercekte olmayan bir akisi olcmekti.
      expect(pushHedefi({'tip': 'ziyaretci'}, UserRole.resident), '/visitors');
      expect(
        pushHedefi({'tip': 'ziyaretci', 'visitor_id': ''}, UserRole.resident),
        '/visitors',
      );
    });

    test('tip=erisim_talebi (sakine) / erisim_sonuc (talep edene) -> '
        'goruntuleme izni ekrani', () {
      expect(
        pushHedefi({'tip': 'erisim_talebi', 'request_id': 'q-1'}, _rol),
        '/unit-access',
      );
      expect(
        pushHedefi({'tip': 'erisim_sonuc', 'request_id': 'q-1'}, _rol),
        '/unit-access',
      );
    });

    test('tip=rezervasyon / rezervasyon_karar -> ilgili rezervasyon', () {
      expect(
        pushHedefi({'tip': 'rezervasyon', 'rezervasyon_id': 'r-1'}, _rol),
        '/rezervasyon?rezervasyon_id=r-1',
      );
      expect(
        pushHedefi({'tip': 'rezervasyon_karar', 'rezervasyon_id': 'r-2'}, _rol),
        '/rezervasyon?rezervasyon_id=r-2',
      );
    });

    test('rezervasyon_id yoksa/bossa rezervasyon LISTESI acilir', () {
      expect(pushHedefi({'tip': 'rezervasyon'}, _rol), '/rezervasyon');
      expect(
        pushHedefi({'tip': 'rezervasyon_karar', 'rezervasyon_id': ''}, _rol),
        '/rezervasyon',
      );
    });

    test('tip=etkinlik -> ilgili etkinlik (sakine yeni-etkinlik push\'u)', () {
      expect(
        pushHedefi({'tip': 'etkinlik', 'etkinlik_id': 'e-1'}, _rol),
        '/etkinlik?etkinlik_id=e-1',
      );
    });

    test('etkinlik_id yoksa/bossa etkinlik LISTESI acilir', () {
      expect(pushHedefi({'tip': 'etkinlik'}, _rol), '/etkinlik');
      expect(
        pushHedefi({'tip': 'etkinlik', 'etkinlik_id': ''}, _rol),
        '/etkinlik',
      );
    });

    test('(Böl.10.1 / P217) devriye alarmlari ROLE GORE ayrisir', () {
      // ESKI IDDIA: hepsi `/patrol`, `kacirilan_tur` ise `/patrol-plans`.
      // Rol hesaba katilmadigi icin YONETICI de `/patrol`e gidiyordu ve
      // o ekran onun menusunde YOK — "yetkiniz yok" cikiyordu.
      //
      // Saha rolu icin hedef DEGISMEDI (aktif tur ekrani); yonetim icin
      // DEVRIYE TAKIBI (bugunun pencereleri + gecmis, salt izleme).
      // `patrol-plans` (plan TANIMLAMA) bilerek secilmedi: kacirilan bir
      // tur hakkinda sorulan sey "ne oldu", "plani nasil kurarim" degil.
      for (final tip in ['gecikmis_okutma', 'uzak_okutma', 'kacirilan_tur']) {
        expect(pushHedefi({'tip': tip, 'patrol_window_id': 'w-1'},
            UserRole.security), '/patrol', reason: tip);
        expect(pushHedefi({'tip': tip, 'patrol_window_id': 'w-1'},
            UserRole.yonetici), '/patrol-tracking', reason: tip);
      }
    });

    test('(Böl.10.2) vardiya ozeti -> vardiyalar ekrani', () {
      expect(
        pushHedefi({'tip': 'vardiya_ozeti', 'shift_id': 's-1'}, _rol),
        '/vardiyalar',
      );
    });

    test('(P191 §2) gorev atama -> Gorevlerim listesi', () {
      // `taskDetail` DEGIL: o rota Task nesnesini `extra` ile bekler ve
      // nesnesiz gelindiginde zaten listeye yonlendirir. Push'tan nesne
      // tasinamaz.
      expect(
        pushHedefi({'tip': 'gorev_atandi', 'task_id': 't-1'}, _rol),
        '/tasks',
      );
      expect(pushHedefi({'tip': 'gorev_atandi'}, _rol), '/tasks');
    });

    test('(P191 §2/§4) aidat borcu ve odeme -> Aidatim', () {
      // (P217) ROL SAKIN: bu bildirimler SAKINE gider ve hedef
      // ekranlar (kargo/ziyaretci/aidatim) yalniz onun menusunde var.
      // Yonetici rolüyle olcmek, gercekte olmayan bir akisi olcmekti.
      expect(pushHedefi({'tip': 'aidat_borc'}, UserRole.resident), '/my-dues');
      expect(
        pushHedefi({'tip': 'aidat_odendi', 'receipt_id': 'r-1'}, UserRole.resident),
        '/my-dues',
      );
    });

    test('bilinmeyen/eksik tip -> null (yonlendirme yok)', () {
      expect(pushHedefi({'tip': 'bilinmeyen_tip'}, _rol), isNull);
      expect(pushHedefi(const {}, _rol), isNull);
    });
  });
}
