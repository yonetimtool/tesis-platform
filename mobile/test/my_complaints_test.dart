import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/unit_complaints/data/unit_complaint_api.dart';
import 'package:mobile/src/features/unit_complaints/domain/unit_complaint_models.dart';
import 'package:mobile/src/features/unit_complaints/presentation/my_complaints_screen.dart';

/// Sahte istemci — /mine sabit doner (kendi sikayetlerim).
class _FakeApi extends UnitComplaintApi {
  _FakeApi(this._mine) : super(Dio());
  final List<UnitComplaint> _mine;

  @override
  Future<List<UnitComplaint>> fetchMine() async => _mine;
}

UnitComplaint _c({
  String id = 'c-1',
  String unitNo = 'A-12',
  UnitComplaintKategori kategori = UnitComplaintKategori.gurultu,
  String durum = 'acik',
}) =>
    UnitComplaint(
      id: id,
      targetUnitId: 'u-$id',
      unitNo: unitNo,
      kategori: kategori,
      durum: durum,
      createdAt: DateTime.utc(2026, 7, 12, 9),
    );

Widget _app(List<UnitComplaint> mine) => ProviderScope(
      overrides: [unitComplaintApiProvider.overrideWithValue(_FakeApi(mine))],
      child: const MaterialApp(home: MyComplaintsScreen()),
    );

void main() {
  testWidgets('kendi sikayetleri: daire + kategori + durum gorunur',
      (tester) async {
    await tester.pumpWidget(_app([
      _c(unitNo: 'A-12', kategori: UnitComplaintKategori.gurultu, durum: 'acik'),
      _c(id: 'c-2', unitNo: 'A-5', kategori: UnitComplaintKategori.zararVerme, durum: 'kapali'),
    ]));
    await tester.pumpAndSettle();
    expect(find.textContaining('Daire A-12'), findsOneWidget);
    expect(find.textContaining('Gürültü'), findsOneWidget);
    expect(find.textContaining('Daire A-5'), findsOneWidget);
    expect(find.textContaining('Zarar verme'), findsOneWidget);
    // durum rozetleri
    expect(find.text('Açık'), findsOneWidget);
    expect(find.text('Kapandı'), findsOneWidget);
    // yogunluk/renk YOK (kendi sikayetlerim listesi)
    expect(find.text('0–2'), findsNothing);
  });

  testWidgets('bos liste anlamli mesaj gosterir', (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pumpAndSettle();
    expect(find.textContaining('Henüz şikayet açmadınız'), findsOneWidget);
  });
}
