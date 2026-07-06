import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/scan/domain/outbox_entry.dart';
import 'package:mobile/src/features/scan/domain/scan.dart';

const _picc = 'EF963FF7828658A599F3041510671E88';
const _cmac = '94EED9EE65337086';

ScanDraft _draft({String? picc, String? cmac}) => ScanDraft(
      nfcTagUid: '04:A3:B2:C1:90:00',
      okutmaZamani: DateTime.utc(2026, 7, 6, 10),
      sdmPiccData: picc,
      sdmCmac: cmac,
    );

void main() {
  group('ScanDraft SDM govdesi (ScanCreate)', () {
    test('iki SDM alani da varsa govdeye girer', () {
      final json = _draft(picc: _picc, cmac: _cmac).toJson();
      expect(json['sdm_picc_data'], _picc);
      expect(json['sdm_cmac'], _cmac);
    });

    test('alanlardan biri eksikse IKISI de gonderilmez (sozlesme: birlikte)',
        () {
      final yalnizPicc = _draft(picc: _picc).toJson();
      expect(yalnizPicc.containsKey('sdm_picc_data'), isFalse);
      expect(yalnizPicc.containsKey('sdm_cmac'), isFalse);

      final yalnizCmac = _draft(cmac: _cmac).toJson();
      expect(yalnizCmac.containsKey('sdm_picc_data'), isFalse);
      expect(yalnizCmac.containsKey('sdm_cmac'), isFalse);
    });

    test('SDM alanlari yoksa govde eski haliyle ayni (NTAG21x akisi)', () {
      final json = _draft().toJson();
      expect(json.keys, unorderedEquals(['nfc_tag_uid', 'okutma_zamani']));
    });

    test('deprecated imza_dogrulandi ASLA gonderilmez', () {
      final json = _draft(picc: _picc, cmac: _cmac).toJson();
      expect(json.containsKey('imza_dogrulandi'), isFalse);
    });

    test('SDM alanlari idempotency-key\'i degistirmez', () {
      expect(
        _draft(picc: _picc, cmac: _cmac).idempotencyKey,
        _draft().idempotencyKey,
      );
    });
  });

  group('OutboxEntry SDM kaliciligi (offline kaybolmaz)', () {
    test('fromDraft → toDraft SDM alanlarini korur', () {
      final entry = OutboxEntry.fromDraft(
        _draft(picc: _picc, cmac: _cmac),
        now: DateTime.utc(2026, 7, 6, 10, 1),
      );
      final geriDraft = entry.toDraft();
      expect(geriDraft.sdmPiccData, _picc);
      expect(geriDraft.sdmCmac, _cmac);
    });

    test('JSON gidis-donus SDM alanlarini korur', () {
      final entry = OutboxEntry.fromDraft(
        _draft(picc: _picc, cmac: _cmac),
        now: DateTime.utc(2026, 7, 6, 10, 1),
      );
      final restored = OutboxEntry.fromJson(entry.toJson());
      expect(restored.sdmPiccData, _picc);
      expect(restored.sdmCmac, _cmac);
      expect(restored.toDraft().toJson()['sdm_picc_data'], _picc);
    });

    test('SDM alansiz eski JSON kaydi sorunsuz okunur (geriye uyum)', () {
      final eski = OutboxEntry.fromDraft(
        _draft(),
        now: DateTime.utc(2026, 7, 6, 10, 1),
      ).toJson();
      expect(eski.containsKey('sdm_picc_data'), isFalse);

      final restored = OutboxEntry.fromJson(eski);
      expect(restored.sdmPiccData, isNull);
      expect(restored.sdmCmac, isNull);
    });
  });
}
