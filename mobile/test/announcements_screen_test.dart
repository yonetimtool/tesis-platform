import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/announcements/data/announcement_api.dart';
import 'package:mobile/src/features/announcements/domain/announcement_models.dart';
import 'package:mobile/src/features/announcements/presentation/announcements_screen.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';

/// Aga cikmayan sahte istemci — liste sabit doner (widget testi).
class _FakeAnnouncementApi extends AnnouncementApi {
  _FakeAnnouncementApi(this._items) : super(Dio());

  final List<Announcement> _items;

  @override
  Future<List<Announcement>> fetchAll() async => _items;
}

Announcement _a({String? fotoUrl}) => Announcement(
      id: 'a-1',
      baslik: 'Su kesintisi',
      govde: 'Yarin 10:00-12:00.',
      olusturanUserId: 'u-1',
      olusturanAd: 'Yonetici A',
      fotoKey: fotoUrl == null ? null : 't/tasks/x.jpg',
      fotoUrl: fotoUrl,
      createdAt: DateTime.utc(2026, 7, 8, 10),
      updatedAt: DateTime.utc(2026, 7, 8, 10),
    );

Widget _app(UserRole role, {List<Announcement> items = const []}) =>
    ProviderScope(
      overrides: [
        announcementApiProvider
            .overrideWithValue(_FakeAnnouncementApi(items)),
        currentUserRoleProvider.overrideWith((ref) async => role),
      ],
      child: const MaterialApp(home: AnnouncementsScreen()),
    );

void main() {
  group('"Yeni duyuru" butonu rol gorunurlugu (auth.md §4 UX aynasi)', () {
    testWidgets('yonetici: FAB GORUNUR (duyuru site yonetiminin agzi)',
        (tester) async {
      await tester.pumpWidget(_app(UserRole.yonetici, items: [_a()]));
      await tester.pumpAndSettle();
      expect(find.text('Yeni duyuru'), findsOneWidget);
    });

    for (final role in [
      UserRole.admin, // canli test karari: admin mobilde salt okur
      UserRole.security,
      UserRole.tesisGorevlisi,
      UserRole.resident,
    ]) {
      testWidgets('${role.name}: FAB YOK — yalniz liste okunur',
          (tester) async {
        await tester.pumpWidget(_app(role, items: [_a()]));
        await tester.pumpAndSettle();
        expect(find.text('Yeni duyuru'), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
        // liste yine gorunur (okuma herkese acik)
        expect(find.text('Su kesintisi'), findsOneWidget);
      });
    }
  });

  group('duyuru gorseli', () {
    testWidgets('foto_url yoksa gorsel alani cizilmez (geriye uyumlu)',
        (tester) async {
      await tester.pumpWidget(_app(UserRole.resident, items: [_a()]));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('Su kesintisi'), findsOneWidget);
    });

    testWidgets('foto_url varsa gorsel alani cizilir (okuyan her rol)',
        (tester) async {
      await tester.pumpWidget(_app(
        UserRole.resident,
        items: [_a(fotoUrl: 'http://minio.local/x.jpg?X-Amz-Signature=s')],
      ));
      await tester.pumpAndSettle();
      // Test ortaminda ag yok — Image.network errorBuilder'a duser; onemli
      // olan gorsel alaninin CIZILMESI ve cokme olmamasi.
      expect(
        find.text('Gorsel yuklenemedi').evaluate().isNotEmpty ||
            find.byType(Image).evaluate().isNotEmpty,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('yonetici formu acar: gorsel opsiyonel alani gorunur',
      (tester) async {
    await tester.pumpWidget(_app(UserRole.yonetici, items: [_a()]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeni duyuru'));
    await tester.pumpAndSettle();
    expect(find.text('Gorsel (opsiyonel)'), findsOneWidget);
    expect(find.text('Foto cek'), findsOneWidget);
    expect(find.text('Galeriden sec'), findsOneWidget);
    // foto'suz da yayinlanabilir — buton aktif
    expect(find.text('Yayinla'), findsOneWidget);
  });
}
