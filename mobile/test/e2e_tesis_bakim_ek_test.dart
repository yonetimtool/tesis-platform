/// (E2E 2026-09) BAKIM KAYDI EKLERI + GECMIS — mobil yuzey (TESIS-05/06).
///
/// OLCULEN (uctan uca tur): sunucu `bakim_kaydi` ekini kabul ediyordu ama
/// mobilde ne gecmis ne ek vardi; kayit formu fotograf alamiyordu ve tarih
/// secici 2100'e kadar gelecek tarih sunuyordu.
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/bakim/data/bakim_api.dart';
import 'package:mobile/src/features/bakim/domain/bakim_models.dart';
import 'package:mobile/src/features/bakim/presentation/bakim_ekrani.dart';
import 'package:mobile/src/features/tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;

import 'helpers/l10n_test_app.dart';

class _SahteApi extends BakimApi {
  _SahteApi({this.fotoPatlar = false}) : super(Dio());

  final bool fotoPatlar;
  String? fotoKayit;
  int? fotoBoyut;

  @override
  Future<List<BakimEkipmani>> ekipmanlar({String? durum}) async => [
        const BakimEkipmani(
          id: 'e1',
          ad: 'Asansör',
          tur: 'asansor',
          periyot: 'aylik',
          sonrakiBakim: '2026-10-01',
          durum: 'planli',
          kalanGun: 8,
          yasal: true,
        ),
      ];

  @override
  Future<List<BakimKaydi>> kayitlar({String? ekipmanId}) async => [
        const BakimKaydi(
            id: 'k1', ekipmanId: 'e1', tarih: '2026-09-20', islem: 'Kontrol'),
      ];

  @override
  Future<List<BakimEki>> ekler(String kayitId) async => [
        const BakimEki(
          id: 'x1',
          tur: 'dosya',
          dosyaAdi: 'muayene.pdf',
          dosyaUrl: 'https://depo.ornek/muayene.pdf',
        ),
      ];

  @override
  Future<BakimKaydi> kayitEkle(String ekipmanId, BakimKaydiTaslak t) async =>
      BakimKaydi(id: 'yeni', ekipmanId: ekipmanId, tarih: t.tarih);

  @override
  Future<void> fotoEkle({
    required String kayitId,
    required Uint8List baytlar,
    String contentType = 'image/jpeg',
    String dosyaAdi = 'bakim.jpg',
  }) async {
    if (fotoPatlar) {
      throw const ApiException(code: 'x', message: 'yuklenemedi');
    }
    fotoKayit = kayitId;
    fotoBoyut = baytlar.length;
  }
}

class _SahteSecici extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async =>
      XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'f.jpg');
}

Widget _ekran(_SahteApi api) => ProviderScope(
      overrides: [
        bakimApiProvider.overrideWithValue(api),
        imagePickerProvider.overrideWithValue(_SahteSecici()),
      ],
      child: l10nApp(const BakimEkrani(yonetim: true)),
    );

void main() {
  testWidgets('SATIR GECMISI ACAR, kaydin EKI acilabilir gorunur',
      (tester) async {
    await tester.pumpWidget(_ekran(_SahteApi()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bakim-ekipman-e1')));
    await tester.pumpAndSettle();
    expect(find.text('2026-09-20'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bakim-gecmis-k1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bakim-ek-x1')), findsOneWidget);
    expect(find.text('muayene.pdf'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
  });

  testWidgets('KAYIT FORMU fotografi YENI KAYDA baglar', (tester) async {
    final api = _SahteApi();
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bakim-kayit-e1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('bakim-kayit-foto')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bakim-kayit-foto')));
    await tester.pumpAndSettle();
    expect(find.text('Fotoğraf kayıtla birlikte yüklenecek'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('bakim-kayit-kaydet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bakim-kayit-kaydet')));
    await tester.pumpAndSettle();
    expect(api.fotoKayit, 'yeni');
    expect(api.fotoBoyut, 3);
  });

  testWidgets('FOTOGRAF YUKLENEMEZSE kayit YINE kaydedilir, kullaniciya soylenir',
      (tester) async {
    final api = _SahteApi(fotoPatlar: true);
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bakim-kayit-e1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('bakim-kayit-foto')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bakim-kayit-foto')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('bakim-kayit-kaydet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bakim-kayit-kaydet')));
    await tester.pumpAndSettle();
    expect(find.text('Bakım kaydedildi ama fotoğraf yüklenemedi.'),
        findsOneWidget);
    // Form kapandi (kayit yazildi).
    expect(find.byKey(const ValueKey('bakim-kayit-kaydet')), findsNothing);
  });
}
