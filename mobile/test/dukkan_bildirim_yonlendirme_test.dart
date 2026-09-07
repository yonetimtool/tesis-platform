/// (DUKKAN F6-ek) BILDIRIM YONLENDIRME KILIDI.
///
/// ===========================================================================
/// NE OLCULUYOR
/// ===========================================================================
/// P211'de olculen kusur suydu: bildirim DOGRU kisiye gidiyor, dokununca
/// YANLIS (ya da hic olmayan) ekrana goturuyordu. Bu dosya ayni kusurun
/// Dukkan'da tekrarlanmasini engelliyor ve UC AYRI seyi olcuyor:
///
///   1. Sunucudaki HER tipin mobil karsiligi VAR MI (`TIPLER` sozlugu
///      birebir kopyalandi; sunucu yeni tip eklerse test duser).
///   2. Uretilen her hedef ROUTER'DA TANIMLI MI — "hedef var ama rota
///      yok" tam olarak F4'te yasanan sey (bkz. asagidaki kusur notu).
///   3. Dukkan tipleri Yonetiyor'un ROL SUZGECINE TAKILMIYOR MU —
///      takilsalardi tum Dukkan bildirimleri dokunulamaz olurdu.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/dukkan/domain/dukkan_push_yonlendirme.dart';
import 'package:mobile/src/routing/app_router.dart';
import 'package:mobile/src/routing/push_yonlendirme.dart';

/// `backend/app/dukkan/bildirim.py: TIPLER` sozlugunun BIREBIR kopyasi.
///
/// ELLE KOPYA VE BU BILINCLI: mobil test sunucu kaynagini okuyamaz
/// (ayri depo dizini, konteynerde koşum). Kopya oldugu icin sunucu bir
/// tip eklediginde bu liste GUNCELLENMEK ZORUNDA — kilit tam da bunu
/// hatirlatmak icin var.
const _sunucuTipleri = <String>[
  'dukkan_teklif_geldi',
  'dukkan_is_verildi',
  'dukkan_isletme_onaylandi',
  'dukkan_isletme_reddedildi',
  'dukkan_isletme_askiya_alindi',
  'dukkan_yorum_yayinlandi',
  'dukkan_yeni_talep',
];

/// Router'da TANIMLI Dukkan yollari (app_router.dart ile ayni sabitler).
final _tanimliRotalar = <String>{
  AppRoutes.dukkanArama,
  AppRoutes.dukkanIsletme,
  AppRoutes.dukkanTalepOlustur,
  AppRoutes.dukkanTaleplerim,
  AppRoutes.dukkanTalepDetay,
  AppRoutes.dukkanSikayet,
  AppRoutes.dukkanPanel,
  AppRoutes.dukkanBildirim,
};

/// Uretilmis bir yolu (`/dukkan/taleplerim/abc`) rota DESENINE cevirir.
String _desene(String yol) {
  final temiz = yol.split('?').first;
  for (final desen in _tanimliRotalar) {
    if (!desen.contains(':')) {
      if (desen == temiz) return desen;
      continue;
    }
    // `:param` iceren deseni bolum sayisi + sabit bolumler uzerinden esle.
    final d = desen.split('/');
    final y = temiz.split('/');
    if (d.length != y.length) continue;
    var uyar = true;
    for (var i = 0; i < d.length; i++) {
      if (d[i].startsWith(':')) continue;
      if (d[i] != y[i]) {
        uyar = false;
        break;
      }
    }
    if (uyar) return desen;
  }
  return '(TANIMSIZ) $temiz';
}

void main() {
  group('Dukkan push yonlendirmesi', () {
    test('SUNUCUDAKI HER TIPIN mobil hedefi VAR', () {
      for (final tip in _sunucuTipleri) {
        final hedef = dukkanPushHedefi({
          'tip': tip,
          'talep_id': 't-1',
          'isletme_id': 'i-1',
          'isletme_slug': 'usta-ali',
        });
        expect(hedef, isNotNull,
            reason: '$tip icin mobil hedef yok — bildirim dokunulamaz olur');
      }
    });

    test('URETILEN HER HEDEF ROUTER\'DA TANIMLI', () {
      // ==============================================================
      // BU TEST BIR KUSURU YAKALADI (F6-ek olcumu)
      // ==============================================================
      // F4'te `dukkan_taleplerim_screen.dart`
      // `/dukkan/taleplerim/{id}` yoluna `push` ediyordu ama O ROTA
      // ROUTER'A HIC EKLENMEMISTI. Yani mobilde gelen teklifler
      // GORULEMIYORDU; kart'a dokunmak go_router hata ekrani aciyordu.
      // F6-ek'te hem rota hem ekran eklendi. Bu kilit, ayni sinifin
      // tekrarini imkansiz kiliyor.
      for (final tip in _sunucuTipleri) {
        final hedef = dukkanPushHedefi({
          'tip': tip,
          'talep_id': 't-1',
          'isletme_id': 'i-1',
          'isletme_slug': 'usta-ali',
        })!;
        expect(_desene(hedef), isNot(startsWith('(TANIMSIZ)')),
            reason: '$tip -> $hedef rotasi router\'da yok');
      }
    });

    test('KIMLIK YOKSA (id bos) LISTEYE duser, hata ekranina DEGIL', () {
      expect(dukkanPushHedefi({'tip': 'dukkan_teklif_geldi'}),
          AppRoutes.dukkanTaleplerim);
      expect(dukkanPushHedefi({'tip': 'dukkan_yeni_talep', 'isletme_id': ''}),
          AppRoutes.dukkanPanel);
    });

    test('SLUG YOKSA yorum bildirimi HICBIR YERE gitmez', () {
      // Kamu profili slug OLMADAN acilamaz. "Aramaya goturelim" demek,
      // kullaniciyi yayinlanan yorumundan uzaklastirmak olurdu.
      expect(dukkanPushHedefi({'tip': 'dukkan_yorum_yayinlandi'}), isNull);
    });

    test('BILINMEYEN tip null doner', () {
      expect(dukkanPushHedefi({'tip': 'dukkan_boyle_bir_sey_yok'}), isNull);
      expect(dukkanPushHedefi(const {}), isNull);
    });

    test('ONEK SUZGECI: yalniz dukkan_ onekli tipler Dukkan sayilir', () {
      expect(dukkanBildirimiMi({'tip': 'dukkan_teklif_geldi'}), isTrue);
      // Yonetiyor'da AYNI ADLA bir tip var (`yeni_talep`). Oneksiz hali
      // Dukkan sayilirsa, site sikayeti pazar yeri ekranina gotururdu.
      expect(dukkanBildirimiMi({'tip': 'yeni_talep'}), isFalse);
      expect(dukkanBildirimiMi(const {}), isFalse);
    });
  });

  group('Yonetiyor haritasiyla birlesim', () {
    test('DUKKAN HEDEFLERI ROL SUZGECINE TAKILMIYOR', () {
      // Dukkan ekranlari rol MENUSUNDE degil; suzgecten gecirilselerdi
      // HEPSI null donerdi. Her rol icin ayni hedefin uretildigini
      // olcuyoruz — Dukkan'in rolu yoktur.
      for (final rol in UserRole.values) {
        expect(
          pushHedefi({'tip': 'dukkan_teklif_geldi', 'talep_id': 't-1'}, rol),
          '/dukkan/taleplerim/t-1',
          reason: '$rol icin Dukkan hedefi kayboldu',
        );
      }
    });

    test('YONETIYOR TIPLERI DUKKAN DALINA DUSMUYOR', () {
      // Ters yon: Dukkan dali Yonetiyor'un davranisini DEGISTIRMEMELI.
      expect(pushHedefi({'tip': 'duyuru'}, UserRole.resident),
          AppRoutes.announcements);
      expect(pushHedefi({'tip': 'aidat_borc'}, UserRole.resident),
          AppRoutes.myDues);
    });

    test('ROL BILINMESE DE Dukkan hedefi uretilir', () {
      // Yonetiyor tarafinda rol bilinmiyorsa yonlendirme YOK (P217).
      // Dukkan'da yetki roldan degil JETONDAN geliyor; hedef ekran
      // jetonu kendisi istiyor. Rolun bilinmemesi hedefi silmemeli.
      expect(
        pushHedefi({'tip': 'dukkan_yeni_talep', 'isletme_id': 'i-9'}, null),
        '/dukkan/panel?isletme_id=i-9',
      );
      expect(pushHedefi({'tip': 'duyuru'}, null), isNull);
    });
  });
}
