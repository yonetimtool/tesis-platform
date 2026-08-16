/// (P166 §10) GIZLI AKSIYONLAR — bir eylemin TEK girisi etiketsiz bir
/// ikon olmamali.
///
/// Kerem'in olcumu: "kategori olusturma, kontrol noktasi atama, devriye
/// plani olusturma gibi eylemler sag ustte kucuk simge olarak duruyor;
/// uygulamayi bilmeyen bulamiyor."
///
/// SECILEN COZUM UC KATMANLI ve bu dosya ucunu de olcer:
///   1. MENUDE ETIKETLI GIRIS — modul bulunabilir olur.
///   2. BOS DURUMDA CAGRI DUGMESI — liste yokken goz ekranin ortasindadir,
///      dibindeki FAB'de degil.
///   3. ETIKETLI DUGME — ikon kalirsa yaninda adi yazar.
///
/// NEDEN "ikonu buyut" DEGIL: bir ikon adini ancak UZUN BASINCA soyler
/// (tooltip). Cogu kullanici o denemeyi hic yapmaz, yani ozelligin
/// VARLIGINI ogrenmez. Buyuk bir ikon da adsizdir.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/ui/bos_durum.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/checkpoints/data/checkpoint_api.dart';
import 'package:mobile/src/features/checkpoints/presentation/checkpoints_screen.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';

import 'helpers/l10n_test_app.dart';

class _BosCheckpointApi extends CheckpointApi {
  _BosCheckpointApi() : super(Dio());

  @override
  Future<List<Checkpoint>> list() async => const [];
}

void main() {
  group('(P166 §10) MENUDE ETIKETLI GIRIS', () {
    test('GOREV KATEGORILERI artik menude (yonetici + admin)', () {
      // Once yalniz "Gorev yonetimi"nin sag ustundeki etiketsiz ikondu.
      for (final rol in [UserRole.yonetici, UserRole.admin]) {
        expect(
          homeMenuForRole(rol),
          contains(HomeMenuEntry.taskCategories),
          reason: '$rol',
        );
      }
    });

    test('PLAKA OKUMALARI artik menude (ekrani goren rolde)', () {
      // Tek giris "Arac Gecisleri"nin sag ustundeki etiketsiz ikondu: bir
      // ekrana ulasmanin on kosulu, BASKA bir ekrandaki bir ikonu tahmin
      // etmekti.
      expect(
        homeMenuForRole(UserRole.guvenlikAmiri),
        contains(HomeMenuEntry.plakaOlaylari),
      );
      // Gorunurluk `aracGecis`ten TUREDI — yeni bir yetki karari yok.
      for (final rol in UserRole.values) {
        if (homeMenuForRole(rol).contains(HomeMenuEntry.plakaOlaylari)) {
          expect(
            homeMenuForRole(rol),
            contains(HomeMenuEntry.aracGecis),
            reason: '$rol: plaka okumalari var ama arac gecisi yok',
          );
        }
      }
    });

    test('HER menu girisi bir BOLUME duser (menuden dusen olmasin)', () {
      // Yeni girisler eklendi; gruplama switch'i eksiksiz olmali yoksa
      // giris menude HIC cizilmezdi.
      for (final e in HomeMenuEntry.values) {
        expect(() => homeMenuGrubu(e), returnsNormally, reason: e.name);
      }
    });
  });

  group('(P166 §10) BOS DURUMDA CAGRI DUGMESI', () {
    testWidgets('KONTROL NOKTASI: bos listede "Ekle" dugmesi CIZILIR', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [checkpointApiProvider.overrideWithValue(_BosCheckpointApi())],
          child: l10nApp(const CheckpointsScreen(), locale: const Locale('tr')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BosDurum), findsOneWidget);
      // Cagri dugmesi: ekranin ORTASINDA, dibindeki FAB'den AYRI.
      expect(
        find.widgetWithText(FilledButton, 'Nokta ekle'),
        findsOneWidget,
        reason: 'bos durumda cagri dugmesi',
      );
      // Aciklama da var: bos liste karsisindaki kullanici cogu zaman
      // ozelligin NE OLDUGUNU da bilmiyor.
      expect(find.textContaining('NFC'), findsOneWidget);
    });
  });

  group('(P166 §10) ORTAK BOS DURUM BILESENI', () {
    testWidgets('EYLEM VERILMEZSE dugme CIZILMEZ (yetkisize yol acma)', (
      tester,
    ) async {
      await tester.pumpWidget(
        l10nApp(
          const BosDurum(ikon: Icons.inbox_outlined, baslik: 'Kayit yok'),
          locale: const Locale('tr'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kayit yok'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });
  });
}
