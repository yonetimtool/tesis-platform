import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/announcements/domain/announcement_models.dart';
import 'package:mobile/src/features/home/presentation/duyurular_karti.dart';

Announcement _duyuru({String? fotoUrl}) => Announcement(
      id: 'a1',
      baslik: 'Bahçe Düzenlemesi',
      govde: 'Site bahçemizde peyzaj düzenlemesi yapılacaktır.',
      olusturanUserId: 'u1',
      createdAt: DateTime(2026, 7, 20),
      updatedAt: DateTime(2026, 7, 20),
      fotoUrl: fotoUrl,
    );

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final now = DateTime(2026, 7, 21);

  testWidgets('fotoUrl varsa thumbnail cizilir', (tester) async {
    await tester.pumpWidget(_wrap(DuyurularKarti(
      duyurular: [_duyuru(fotoUrl: 'https://example.com/foto.jpg')],
      now: now,
      onTumu: () {},
    )));
    // Thumbnail Image widget'i olarak render edilir (network yuklenmese de
    // widget agacinda bulunur).
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Bahçe Düzenlemesi'), findsOneWidget);
  });

  testWidgets('fotoUrl yoksa Image cizilmez (metin-only kart)', (tester) async {
    await tester.pumpWidget(_wrap(DuyurularKarti(
      duyurular: [_duyuru()],
      now: now,
      onTumu: () {},
    )));
    expect(find.byType(Image), findsNothing);
    expect(find.text('Bahçe Düzenlemesi'), findsOneWidget);
  });
}
