/// (P217) PUSH YONLENDIRMESI ROLE GORE.
///
/// ===========================================================================
/// OLCULEN KUSUR
/// ===========================================================================
/// Devriye alarmi backend'de HEM gorevliye KISI olarak HEM yonetim
/// rollerine gidiyor (`app/uzak_okutma.py: ALARM_ROLLERI = admin,
/// yonetici, guvenlik_amiri`). Mobil ikisini de "Turlarim"a (`/patrol`)
/// yolluyordu; o ekran yoneticinin menusunde YOK ve acilinca "yetkiniz
/// yok" cikiyordu. Bildirim dogru kisiye gidiyordu — YONLENDIRME
/// yanlisti.
///
/// ===========================================================================
/// BU DOSYA NE OLCER
/// ===========================================================================
/// 1. Istegin birebir iki senaryosu: yonetici -> Devriye takibi,
///    guvenlik -> Turlarim.
/// 2. ERISIM SUZGECI: hicbir tip, hicbir rolu erisemedigi bir ekrana
///    goturmez — TUM tipler x TUM roller taranarak.
/// 3. Suzgecin fazla genis olmadigi: gecerli hedefler KESILMIYOR.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/routing/app_router.dart';
import 'package:mobile/src/routing/push_yonlendirme.dart';

/// Backend'in gonderdigi TUM push tipleri (app/ taramasindan).
/// Yeni bir tip eklenip buraya yazilmazsa asagidaki kapsam testi bunu
/// SOYLEMEZ — o yuzden liste `docs/P217-push-yonlendirme.md` ile
/// birlikte guncellenmeli.
const tumTipler = <String>[
  'talep', 'talep_yanit', 'talep_is_emri', 'talep_cozuldu',
  'talep_reddedildi', 'sikayet_cozuldu', 'is_emri_atandi',
  'ziyaretci', 'kargo', 'erisim_talebi', 'erisim_sonuc',
  'rezervasyon', 'rezervasyon_karar', 'etkinlik', 'duyuru',
  'gecikmis_okutma', 'uzak_okutma', 'kacirilan_tur', 'eksik_checkpoint',
  'vardiya_ozeti', 'vardiya_hatirlatma', 'vardiya_baslamadi',
  'gorev_atandi', 'aidat_borc', 'aidat_odendi', 'aidat_hatirlatma',
  'gurultu_uyari_sakin', 'gurultu_uyarisi', 'gurultu_esik_yonetim',
  'gurultu_eskalasyon_guvenlik', 'gurultu_eskalasyon_yonetim',
  'tahsilat', 'tahsilat_toplu', 'iade', 'iptal', 'virman', 'acilis',
  'dogrulama', 'test',
];

void main() {
  // ==================== ISTEGIN BIREBIR SENARYOLARI ==================== //

  test('TUR ALARMI: yonetici -> DEVRIYE TAKIBI', () {
    for (final tip in ['uzak_okutma', 'gecikmis_okutma', 'kacirilan_tur']) {
      expect(
        pushHedefi({'tip': tip}, UserRole.yonetici),
        AppRoutes.patrolTracking,
        reason: '$tip yoneticiyi Turlarim\'a atiyordu (yetkiniz yok)',
      );
    }
  });

  test('TUR ALARMI: guvenlik -> TURLARIM', () {
    for (final tip in ['uzak_okutma', 'gecikmis_okutma']) {
      expect(pushHedefi({'tip': tip}, UserRole.security), AppRoutes.patrol,
          reason: '$tip gorevliyi aktif tur ekranina goturmeli');
    }
  });

  test('AYNI BILDIRIM, IKI ROL, IKI HEDEF', () {
    // Kusurun ozu tek satirda: ayni data, farkli rol -> farkli ekran.
    const data = {'tip': 'uzak_okutma', 'scan_id': 's-1'};
    expect(pushHedefi(data, UserRole.security), AppRoutes.patrol);
    expect(pushHedefi(data, UserRole.yonetici), AppRoutes.patrolTracking);
    expect(pushHedefi(data, UserRole.security) ==
        pushHedefi(data, UserRole.yonetici), isFalse);
  });

  test('SAKIN devriye alarmi ALMAZ — alsa bile hicbir yere gitmez', () {
    expect(pushHedefi({'tip': 'uzak_okutma'}, UserRole.resident), isNull);
    expect(pushHedefi({'tip': 'kacirilan_tur'}, UserRole.denetci), isNull);
  });

  // ==================== ERISIM SUZGECI (asil emniyet) ================== //

  test('HICBIR tip, HICBIR rolu ERISEMEDIGI ekrana goturmez', () {
    // Kusurun SINIFINI kapatan test: tek tek dogru hedef yazmak
    // yetmez, biri unutuldugunda da yanlis yere gidilmemeli.
    final ihlaller = <String>[];
    for (final rol in UserRole.values) {
      for (final tip in tumTipler) {
        final hedef = pushHedefi({'tip': tip}, rol);
        if (hedef == null) continue;
        if (!rotaErisilebilir(hedef, rol)) {
          ihlaller.add('${rol.name} + $tip -> $hedef');
        }
      }
    }
    expect(ihlaller, isEmpty,
        reason: 'yetkisiz ekrana yonlendirme:\n${ihlaller.join("\n")}');
  });

  test('ROL BILINMIYORSA yonlendirme YOK', () {
    // "Bilmiyorsak deneyelim" tam da duzeltilen davranisti.
    for (final tip in tumTipler) {
      expect(pushHedefi({'tip': tip}, null), isNull, reason: tip);
    }
    expect(pushHedefi({'tip': 'talep'}, UserRole.unknown), isNull);
  });

  // ==================== SUZGEC FAZLA GENIS DEGIL ======================= //

  test('GECERLI hedefler KESILMIYOR — her rol icin en az bir tip calisir',
      () {
    // Suzgec her seyi null yapsaydi yukaridaki test de gecerdi ve
    // olcum bosa duserdi. Her calisan rol icin EN AZ BIR yonlendirme
    // uretilebildigini gosteriyoruz.
    for (final rol in [UserRole.yonetici, UserRole.security,
                       UserRole.tesisGorevlisi, UserRole.resident,
                       UserRole.guvenlikAmiri, UserRole.admin]) {
      final calisan = tumTipler
          .map((t) => pushHedefi({'tip': t}, rol))
          .where((h) => h != null)
          .toList();
      expect(calisan, isNotEmpty, reason: '${rol.name} icin HICBIR hedef yok');
    }
  });

  test('SAKIN: talep/aidat/kargo hedefleri CALISIR', () {
    expect(pushHedefi({'tip': 'aidat_borc'}, UserRole.resident),
        AppRoutes.myDues);
    expect(pushHedefi({'tip': 'kargo', 'kargo_id': 'k1'}, UserRole.resident),
        '${AppRoutes.kargo}?kargo_id=k1');
    expect(pushHedefi({'tip': 'gurultu_uyari_sakin'}, UserRole.resident),
        AppRoutes.sikayetlerim);
  });

  test('DERIN BAGLANTI kimligi KORUNUR', () {
    expect(
      pushHedefi({'tip': 'talep', 'complaint_id': 'c-9'}, UserRole.yonetici),
      '${AppRoutes.complaints}?complaint_id=c-9',
    );
    // Kimlik bossa listeye gidilir (eskisi gibi).
    expect(pushHedefi({'tip': 'talep', 'complaint_id': ''}, UserRole.yonetici),
        AppRoutes.complaints);
  });

  // ==================== TESHIS/SESSIZ TIPLER =========================== //

  test('`dogrulama` ve `test` HICBIR yere goturmez', () {
    for (final rol in UserRole.values) {
      expect(pushHedefi({'tip': 'dogrulama'}, rol), isNull);
      expect(pushHedefi({'tip': 'test'}, rol), isNull);
    }
  });

  test('BILINMEYEN tip null (eski davranis korundu)', () {
    expect(pushHedefi({'tip': 'boyle_bir_tip_yok'}, UserRole.yonetici), isNull);
    expect(pushHedefi(const {}, UserRole.yonetici), isNull);
  });
}
