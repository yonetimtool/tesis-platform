import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/support/data/support_api.dart';
import 'package:mobile/src/features/support/domain/support_models.dart';
import 'package:mobile/src/features/support/presentation/destek_screen.dart';

void main() {
  group('SupportTicket.fromJson', () {
    test('tam kayit + savunmaci parse', () {
      final t = SupportTicket.fromJson(const {
        'id': 's1',
        'konu': 'Panel bildirim gecikmesi',
        'aciklama': 'Detay',
        'durum': 'cozuldu',
        'admin_cevap': 'Güncelleme yayınlandı.',
        'created_at': '2026-07-24T09:00:00+03:00',
      });
      expect(t.konu, 'Panel bildirim gecikmesi');
      expect(t.durum, 'cozuldu');
      expect(t.adminCevap, 'Güncelleme yayınlandı.');
      expect(SupportTicket.fromJson(const {'id': 'x'}).durum, 'acik');
    });
  });

  group('DestekScreen — yonetici bilet listesi + form', () {
    testWidgets('listem: konu + durum cipi + admin cevabi gorunur',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          myTicketsProvider.overrideWith((ref) async => [
                SupportTicket(
                    id: 't1',
                    konu: 'Panel bildirim gecikmesi',
                    aciklama: 'x',
                    durum: 'cozuldu',
                    adminCevap: 'Güncelleme yayınlandı.',
                    createdAt: DateTime(2026, 7, 24)),
                SupportTicket(
                    id: 't2',
                    konu: 'Fatura sorusu',
                    aciklama: 'y',
                    durum: 'acik',
                    createdAt: DateTime(2026, 7, 23)),
              ]),
        ],
        child: const MaterialApp(home: DestekScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Destek'), findsOneWidget);
      expect(find.text('Panel bildirim gecikmesi'), findsOneWidget);
      expect(find.text('Çözüldü'), findsOneWidget);
      expect(find.text('Açık'), findsOneWidget);
      expect(find.textContaining('Güncelleme yayınlandı'), findsOneWidget);
      // Yeni talep butonu var (form akisina goturur).
      expect(find.text('Yeni Talep'), findsOneWidget);
    });

    testWidgets('bos liste: anlamli bos-durum + Yeni Talep', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [myTicketsProvider.overrideWith((ref) async => const [])],
        child: const MaterialApp(home: DestekScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Henüz destek talebiniz yok'), findsOneWidget);
      expect(find.text('Yeni Talep'), findsOneWidget);
    });
  });
}
