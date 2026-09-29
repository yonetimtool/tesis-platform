/// (P249 §1) SOS — ALICININ GORDUGU.
///
/// =========================================================================
/// NEDEN BU DOSYA
/// =========================================================================
/// P243'te mobil test yalniz GONDEREN ucu olctu (kategori istek govdesinde
/// gidiyor mu). Alici modeli `kategori` alanini OKUMUYORDU ve tam ekran
/// sabit "ACIL DURUM CAGRISI" ciziyordu — hicbir test kirmizi olmadi.
/// Buradaki her test alarmi ALAN kisinin ekranini olcer.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/panik/data/alarm_kanali.dart';
import 'package:mobile/src/features/panik/data/panik_api.dart';
import 'package:mobile/src/features/panik/domain/panik_models.dart';
import 'package:mobile/src/features/panik/presentation/panik_gozcusu.dart';
import 'package:mobile/src/routing/app_router.dart';
import 'package:mobile/src/routing/push_yonlendirme.dart';

import 'helpers/l10n_test_app.dart';

class _SahteApi extends PanikApi {
  _SahteApi(this.aktif) : super(Dio());

  final List<PanikAlarm> aktif;
  final cagrilar = <String>[];

  @override
  Future<List<PanikAlarm>> aktifler() async => aktif;

  @override
  Future<PanikAlarm> guvendeyim(String id) async {
    cagrilar.add('guvendeyim:$id');
    return aktif.first;
  }

  @override
  Future<PanikAlarm> yardim(String id) async {
    cagrilar.add('yardim:$id');
    return aktif.first;
  }

  @override
  Future<PanikAlarm> gordum(String id) async {
    cagrilar.add('gordum:$id');
    return aktif.first;
  }

  @override
  Future<PanikAlarm> mudahale(String id) async {
    cagrilar.add('mudahale:$id');
    return aktif.first;
  }
}

class _SahteKanal extends AlarmKanali {
  _SahteKanal() : super(const MethodChannel('test/alarm'));

  final susturulan = <String>[];

  @override
  Future<void> sustur(String panikId) async => susturulan.add(panikId);
}

final _deprem = PanikAlarm.fromJson(const {
  'id': 'd1',
  'tip': 'yonetici_anons',
  'kategori': 'deprem',
  'durum': 'acik',
  'toplu': true,
  'baslik': 'DEPREM ALARMI',
  'talimat': [
    'Sarsıntı sürerken ÇÖK, KAPAN, TUTUN.',
    'Pencerelerden uzak durun.',
    'Asansör kullanmayın.',
    'Toplanma alanına gidin.',
  ],
  'son_24s_yanlis_alarm': 0,
  'created_at': '2026-09-29T11:04:00Z',
});

final _saglik = PanikAlarm.fromJson(const {
  'id': 's1',
  'tip': 'sakin',
  'kategori': 'saglik',
  'durum': 'acik',
  'toplu': false,
  'baslik': 'SAĞLIK ACİLİ',
  'talimat': ['112 arandı mı kontrol edin; ambulans ekibini kapıda karşılayın.'],
  'olusturan_ad': 'Ayşe Yılmaz',
  'daire_no': 'A-12',
  'blok': 'A',
  'son_24s_yanlis_alarm': 2,
});

Widget _gozcu(_SahteApi api, _SahteKanal kanal) => ProviderScope(
      overrides: [
        panikApiProvider.overrideWithValue(api),
        alarmKanaliProvider.overrideWithValue(kanal),
        currentUserIdProvider.overrideWith((ref) async => 'ben'),
      ],
      child: l10nApp(
        PanikGozcusu(child: const Scaffold(body: Text('altta'))),
      ),
    );

void main() {
  group('MODEL — sunucunun gonderdigini OKUR', () {
    test('kategori, toplu, baslik, talimat, benim_yanitim', () {
      final a = PanikAlarm.fromJson(const {
        'id': 'x',
        'tip': 'guvenlik',
        'durum': 'acik',
        'kategori': 'yangin',
        'toplu': true,
        'baslik': 'YANGIN ALARMI',
        'talimat': ['112', 'Asansör yok'],
        'benim_yanitim': 'guvende',
      });
      expect(a.kategori, 'yangin');
      expect(a.toplu, isTrue);
      expect(a.baslik, 'YANGIN ALARMI');
      expect(a.talimat, hasLength(2));
      expect(a.benimYanitim, 'guvende');
    });
  });

  group('TOPLU UYARI — talimat + GUVENDEYIM, "Gidiyorum" YOK', () {
    testWidgets('baslik ve ADIM ADIM talimat cizilir', (tester) async {
      await tester.pumpWidget(_gozcu(_SahteApi([_deprem]), _SahteKanal()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('panik-toplu')), findsOneWidget);
      expect(find.text('DEPREM ALARMI'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(Key('panik-talimat-$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('panik-guvendeyim')), findsOneWidget);
      expect(find.byKey(const Key('panik-yardim')), findsOneWidget);
      // "Gidiyorum" toplu uyarida ANLAMSIZ.
      expect(find.byKey(const Key('panik-mudahale')), findsNothing);
      // YANLIS ALARM SAYACI toplu uyarida YOK.
      expect(find.byKey(const Key('panik-alarm-yanlis-sayaci')), findsNothing);
    });

    testWidgets('GUVENDEYIM sunucuya gider ve ALARMI SUSTURUR', (tester) async {
      final api = _SahteApi([_deprem]);
      final kanal = _SahteKanal();
      await tester.pumpWidget(_gozcu(api, kanal));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('panik-guvendeyim')));
      await tester.tap(find.byKey(const Key('panik-guvendeyim')));
      await tester.pump();
      expect(api.cagrilar, contains('guvendeyim:d1'));
      expect(kanal.susturulan, ['d1'],
          reason: 'Android dongulu alarm sesi karardan sonra da calardi');
    });

    testWidgets('YARDIMA IHTIYACIM VAR sunucuya gider', (tester) async {
      final api = _SahteApi([_deprem]);
      await tester.pumpWidget(_gozcu(api, _SahteKanal()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('panik-yardim')));
      await tester.tap(find.byKey(const Key('panik-yardim')));
      await tester.pump();
      expect(api.cagrilar, contains('yardim:d1'));
    });
  });

  group('YARDIM CAGRISI — kim, nerede, Gidiyorum/Gordum', () {
    testWidgets('kategori basligi + tek cumle talimat', (tester) async {
      await tester.pumpWidget(_gozcu(_SahteApi([_saglik]), _SahteKanal()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('panik-yardim-cagrisi')), findsOneWidget);
      expect(find.text('SAĞLIK ACİLİ'), findsOneWidget);
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.byKey(const Key('panik-talimat-0')), findsOneWidget);
      expect(find.byKey(const Key('panik-mudahale')), findsOneWidget);
      expect(find.byKey(const Key('panik-guvendeyim')), findsNothing);
      // Sayac SUNUCU gonderdiyse (guvenlik/yonetim) gorunur.
      expect(find.byKey(const Key('panik-alarm-yanlis-sayaci')), findsOneWidget);
    });

    testWidgets('GORDUM alarmi susturur', (tester) async {
      final api = _SahteApi([_saglik]);
      final kanal = _SahteKanal();
      await tester.pumpWidget(_gozcu(api, kanal));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('panik-gordum')));
      await tester.tap(find.byKey(const Key('panik-gordum')));
      await tester.pump();
      expect(api.cagrilar, contains('gordum:s1'));
      expect(kanal.susturulan, ['s1']);
    });
  });

  group('BILDIRIME DOKUNUS alarmin KENDISINI acar', () {
    test('sakin deprem push\'una dokununca bos takip listesine GITMEZ', () {
      final data = {'tip': 'panik_alarm', 'panik_id': 'd1'};
      expect(pushHedefi(data, UserRole.resident), AppRoutes.panikAlarmDetay('d1'));
      expect(pushHedefi(data, UserRole.security), AppRoutes.panikAlarmDetay('d1'));
      expect(pushHedefi(data, UserRole.yonetici), AppRoutes.panikAlarmDetay('d1'));
      // Denetci alarm almaz — yonlendirme de yok.
      expect(pushHedefi(data, UserRole.denetci), isNull);
    });

    test('yardim talebi de alarma gider', () {
      final data = {'tip': 'panik_yardim_talebi', 'panik_id': 'd1'};
      expect(pushHedefi(data, UserRole.security), AppRoutes.panikAlarmDetay('d1'));
    });
  });
}
