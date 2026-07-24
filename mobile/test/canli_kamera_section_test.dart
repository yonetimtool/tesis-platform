import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';
import 'package:mobile/src/features/cameras/presentation/canli_kamera_section.dart';

void main() {
  const kamera = Camera(id: 'c1', ad: 'Ana Giriş', streamUrl: 'https://x/s.m3u8');

  testWidgets('kameralar yatay kartlarla listelenir; dokunma onIzle cagirir',
      (tester) async {
    Camera? izlenen;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CanliKameraSection(
            kameralar: const [kamera], onIzle: (c) => izlenen = c),
      ),
    ));
    expect(find.text('Canlı Kamera'), findsOneWidget);
    expect(find.text('Ana Giriş'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    await tester.tap(find.text('Ana Giriş'));
    expect(izlenen?.id, 'c1');
  });

  testWidgets('bos listede bolum HIC cizilmez', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CanliKameraSection(kameralar: const [], onIzle: (_) {}),
      ),
    ));
    expect(find.text('Canlı Kamera'), findsNothing);
  });
}
