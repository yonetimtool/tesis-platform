/// P7 — ICERIK CEVIRISI: model + not/rozet bileseni + ekran baglama.
///
/// Sunucu tarafi (yazma aninda ceviri, `Accept-Language` ile servis) TUR 14–16
/// zincirinde bitmisti; MOBIL tarafta ustveri HIC okunmuyordu: kullanici
/// Rusca arayuzde makine cevirisi bir duyuruyu okurken bunun ceviri oldugunu
/// bilmiyor, orijinaline de ULASAMIYORDU.
///
/// Olculenler:
///   1. MODEL — `CeviriAlanlari` cozumlemesi, eksik/bozuk alanlarda savunma,
///      ustveri HIC gelmezse `null` (eski sunucu davranisi bozulmaz).
///   2. METIN SECIMI — orijinale gecis, eksik alanda servis edilene DUSME.
///   3. BILESEN — uc hal (makine cevirisi / hazirlaniyor / hata) dogru metni
///      cizer; gecis YALNIZ makine cevirisinde gorunur.
///   4. EKRAN — duyuru kartinda "orijinali gör" gercekten ORIJINALI cizer.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/announcements/data/announcement_api.dart';
import 'package:mobile/src/features/announcements/presentation/announcements_screen.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/core/i18n/icerik_ceviri.dart';
import 'package:mobile/src/core/ui/ceviri_notu.dart';
import 'package:mobile/src/features/announcements/domain/announcement_models.dart';
import 'package:mobile/src/features/etkinlik/domain/etkinlik_models.dart';
import 'package:mobile/src/features/site_kurali/domain/site_kurali_models.dart';

import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';

Map<String, dynamic> _ustveri({
  String durum = 'hazir',
  bool cevirildi = true,
  String gosterilen = 'ru',
  Map<String, String> orijinal = const {
    'baslik': 'Su kesintisi',
    'govde': 'Yarin 10:00-12:00.',
  },
}) => {
  'orijinal_dil': 'tr',
  'gosterilen_dil': gosterilen,
  'ceviri_durumu': durum,
  'cevirildi_mi': cevirildi,
  'orijinal': orijinal,
};

void main() {
  group('MODEL', () {
    test('tam ustveri cozumlenir', () {
      final c = IcerikCeviri.fromJson(_ustveri())!;
      expect(c.orijinalDil, 'tr');
      expect(c.gosterilenDil, 'ru');
      expect(c.durum, CeviriDurumu.hazir);
      expect(c.cevirildiMi, isTrue);
      expect(c.orijinal['baslik'], 'Su kesintisi');
      expect(c.notVar, isTrue);
      expect(c.orijinaleDonulebilir, isTrue);
    });

    test('USTVERI YOKSA null — eski sunucu davranisi bozulmaz', () {
      expect(IcerikCeviri.fromJson({'id': 'x', 'baslik': 'a'}), isNull);
    });

    test('kaynak dili okuyan kullanici: NOT YOK', () {
      // tr istendi -> ceviri yok, cevirildi_mi false, durum hazir.
      final c = IcerikCeviri.fromJson(
        _ustveri(cevirildi: false, gosterilen: 'tr'),
      )!;
      expect(c.notVar, isFalse);
      expect(c.orijinaleDonulebilir, isFalse);
    });

    test('ELLE DUZELTILMIS ceviri makine ciktisi SAYILMAZ', () {
      final c = IcerikCeviri.fromJson(_ustveri(cevirildi: false))!;
      expect(c.cevirildiMi, isFalse);
      expect(c.notVar, isFalse, reason: 'duzeltilmis metinde rozet cikmamali');
    });

    test('bekliyor / hata: govde ORIJINALDIR, gecis yok', () {
      for (final d in ['bekliyor', 'hata']) {
        final c = IcerikCeviri.fromJson(_ustveri(durum: d, cevirildi: false))!;
        expect(c.notVar, isTrue, reason: d);
        expect(c.orijinaleDonulebilir, isFalse, reason: d);
      }
      expect(
        IcerikCeviri.fromJson(_ustveri(durum: 'bekliyor'))!.hazirlaniyor,
        isTrue,
      );
      expect(
        IcerikCeviri.fromJson(_ustveri(durum: 'hata'))!.hataliCeviri,
        isTrue,
      );
    });

    test('BILINMEYEN durum `hazir` sayilir (yanlis uyari gostermeyiz)', () {
      final c = IcerikCeviri.fromJson(_ustveri(durum: 'gelecekte_eklenen'))!;
      expect(c.durum, CeviriDurumu.hazir);
    });

    test('bozuk `orijinal` (liste / sayi degerler) COKERTMEZ', () {
      final c = IcerikCeviri.fromJson({
        'orijinal_dil': 'tr',
        'ceviri_durumu': 'hazir',
        'cevirildi_mi': true,
        'orijinal': ['bu bir liste'],
      })!;
      expect(c.orijinal, isEmpty);
      expect(
        c.orijinaleDonulebilir,
        isFalse,
        reason: 'orijinal metin yoksa gecis TEKLIF EDILMEMELI',
      );

      final c2 = IcerikCeviri.fromJson({
        'orijinal_dil': 'tr',
        'ceviri_durumu': 'hazir',
        'cevirildi_mi': true,
        'orijinal': {'baslik': 'Metin', 'sira': 3},
      })!;
      expect(c2.orijinal, {'baslik': 'Metin'});
    });
  });

  group('METIN SECIMI', () {
    final c = IcerikCeviri.fromJson(_ustveri())!;

    test('varsayilan: SERVIS EDILEN (cevrilmis) metin', () {
      expect(
        c.metin('baslik', 'Отключение воды', orijinalGoster: false),
        'Отключение воды',
      );
    });

    test('orijinal istendi: kaynak metin', () {
      expect(
        c.metin('baslik', 'Отключение воды', orijinalGoster: true),
        'Su kesintisi',
      );
    });

    test('orijinalde O ALAN yoksa servis edilene DUSER (bos ekran yok)', () {
      expect(c.metin('konum', 'Двор', orijinalGoster: true), 'Двор');
    });

    test('ustveri null: helper her zaman servis edileni verir', () {
      expect(
        ceviriMetni(null, 'baslik', 'Отключение воды', orijinalGoster: true),
        'Отключение воды',
      );
    });
  });

  group('MODEL BAGLAMA (uc entity)', () {
    test('Announcement ustveriyi tasir', () {
      final a = Announcement.fromJson({
        'id': 'a1',
        'baslik': 'Отключение воды',
        'govde': 'Завтра 10:00-12:00.',
        'olusturan_user_id': 'u1',
        'created_at': '2026-07-01T10:00:00Z',
        'updated_at': '2026-07-01T10:00:00Z',
        ..._ustveri(),
      });
      expect(a.ceviri, isNotNull);
      expect(a.ceviri!.metin('govde', a.govde, orijinalGoster: true),
          'Yarin 10:00-12:00.');
    });

    test('SiteKurali ustveriyi tasir', () {
      final k = SiteKurali.fromJson({
        'id': 'k1',
        'baslik': 'Правила',
        'icerik': 'Текст',
        'sira': 1,
        'olusturan_user_id': 'u1',
        'created_at': '2026-07-01T10:00:00Z',
        ..._ustveri(orijinal: {'baslik': 'Kurallar', 'icerik': 'Metin'}),
      });
      expect(k.ceviri!.metin('icerik', k.icerik, orijinalGoster: true), 'Metin');
    });

    test('Etkinlik ustveriyi tasir', () {
      final e = Etkinlik.fromJson({
        'id': 'e1',
        'baslik': 'Праздник',
        'aciklama': 'Описание',
        'tarih': '2026-08-01T18:00:00Z',
        'olusturan_user_id': 'u1',
        'katiliyorum_sayisi': 0,
        'katilmiyorum_sayisi': 0,
        'created_at': '2026-07-01T10:00:00Z',
        ..._ustveri(orijinal: {'baslik': 'Sölen', 'aciklama': 'Aciklama'}),
      });
      expect(
        e.ceviri!.metin('aciklama', e.aciklama, orijinalGoster: true),
        'Aciklama',
      );
    });

    test('ustverisiz JSON: ceviri null (regresyon kilidi)', () {
      final a = Announcement.fromJson({
        'id': 'a1',
        'baslik': 'Su kesintisi',
        'govde': 'Yarin.',
        'olusturan_user_id': 'u1',
        'created_at': '2026-07-01T10:00:00Z',
        'updated_at': '2026-07-01T10:00:00Z',
      });
      expect(a.ceviri, isNull);
    });
  });

  group('BILESEN', () {
    Widget kabuk(IcerikCeviri? c, {bool orijinal = false, String dil = 'tr'}) =>
        l10nApp(
          Scaffold(
            body: CeviriNotu(
              ceviri: c,
              orijinalGoster: orijinal,
              onDegistir: (_) {},
            ),
          ),
          locale: Locale(dil),
        );

    testWidgets('ustveri yok / not gerekmiyor: HICBIR SEY cizilmez', (
      tester,
    ) async {
      await tester.pumpWidget(kabuk(null));
      await tester.pumpAndSettle();
      expect(find.byType(Text), findsNothing);

      await tester.pumpWidget(
        kabuk(IcerikCeviri.fromJson(_ustveri(cevirildi: false))),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('makine cevirisi: not + GECIS', (tester) async {
      await tester.pumpWidget(kabuk(IcerikCeviri.fromJson(_ustveri())));
      await tester.pumpAndSettle();
      expect(find.text('Bu içerik otomatik çevrilmiştir'), findsOneWidget);
      expect(find.text('Orijinali gör'), findsOneWidget);
    });

    testWidgets('orijinal gosterilirken etiket TERSINIR', (tester) async {
      await tester.pumpWidget(
        kabuk(IcerikCeviri.fromJson(_ustveri()), orijinal: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Çeviriyi gör'), findsOneWidget);
    });

    testWidgets('hazirlaniyor / hata: not VAR, gecis YOK', (tester) async {
      await tester.pumpWidget(
        kabuk(IcerikCeviri.fromJson(_ustveri(durum: 'bekliyor', cevirildi: false))),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Çeviri hazırlanıyor — orijinal gösteriliyor'),
        findsOneWidget,
      );
      expect(find.byType(TextButton), findsNothing);

      await tester.pumpWidget(
        kabuk(IcerikCeviri.fromJson(_ustveri(durum: 'hata', cevirildi: false))),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Çeviri yapılamadı — orijinal gösteriliyor'),
        findsOneWidget,
      );
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('rozet (liste karti): gecissiz kisa metin', (tester) async {
      await tester.pumpWidget(
        l10nApp(
          Scaffold(
            body: CeviriRozeti(ceviri: IcerikCeviri.fromJson(_ustveri())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Otomatik çeviri'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('NOT: bes eksen (tasma / kontrast / okuyucu / klavye)', (
      tester,
    ) async {
      await tumEksenlerSurusu(
        tester,
        (dil) => l10nApp(
          Scaffold(
            body: CeviriNotu(
              ceviri: IcerikCeviri.fromJson(_ustveri()),
              onDegistir: (_) {},
            ),
          ),
          locale: Locale(dil),
        ),
        // Tek satirlik not: gezinme dongusu iki ogeden olusur, sira denetimi
        // anlamsiz (tek bant).
        sira: false,
      );
    });
  });

  group('EKRAN — duyuru kartinda gecis', () {
    testWidgets('"Orijinali gör" GERCEKTEN orijinali cizer, geri doner', (
      tester,
    ) async {
      final duyuru = Announcement.fromJson({
        'id': 'a1',
        // Sunucunun servis ettigi (cevrilmis) metin:
        'baslik': 'Отключение воды',
        'govde': 'Завтра 10:00-12:00.',
        'olusturan_user_id': 'u1',
        'olusturan_ad': 'Yonetici A',
        'created_at': '2026-07-01T10:00:00Z',
        'updated_at': '2026-07-01T10:00:00Z',
        ..._ustveri(),
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            announcementApiProvider.overrideWithValue(
              _SahteDuyuruApi([duyuru]),
            ),
            currentUserRoleProvider.overrideWith((ref) async =>
                UserRole.resident),
          ],
          child: l10nApp(const AnnouncementsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // 1) Once CEVIRI gorunur.
      expect(find.text('Отключение воды'), findsOneWidget);
      expect(find.text('Su kesintisi'), findsNothing);
      expect(find.text('Bu içerik otomatik çevrilmiştir'), findsOneWidget);

      // 2) Gecis -> ORIJINAL.
      await tester.tap(find.text('Orijinali gör'));
      await tester.pumpAndSettle();
      expect(find.text('Su kesintisi'), findsOneWidget);
      expect(find.text('Yarin 10:00-12:00.'), findsOneWidget);
      expect(find.text('Отключение воды'), findsNothing);

      // 3) Geri don -> yine CEVIRI (tek yonlu degil).
      await tester.tap(find.text('Çeviriyi gör'));
      await tester.pumpAndSettle();
      expect(find.text('Отключение воды'), findsOneWidget);
    });

    testWidgets('ustverisiz duyuru: hicbir not/gecis cizilmez', (tester) async {
      final duyuru = Announcement.fromJson({
        'id': 'a2',
        'baslik': 'Su kesintisi',
        'govde': 'Yarin.',
        'olusturan_user_id': 'u1',
        'created_at': '2026-07-01T10:00:00Z',
        'updated_at': '2026-07-01T10:00:00Z',
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            announcementApiProvider.overrideWithValue(
              _SahteDuyuruApi([duyuru]),
            ),
            currentUserRoleProvider.overrideWith((ref) async =>
                UserRole.resident),
          ],
          child: l10nApp(const AnnouncementsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Orijinali gör'), findsNothing);
      expect(find.text('Bu içerik otomatik çevrilmiştir'), findsNothing);
    });
  });
}

/// Aga cikmayan sahte istemci (mevcut `announcements_screen_test` deseni).
class _SahteDuyuruApi extends AnnouncementApi {
  _SahteDuyuruApi(this._items) : super(Dio());
  final List<Announcement> _items;

  @override
  Future<List<Announcement>> fetchAll() async => _items;
}
