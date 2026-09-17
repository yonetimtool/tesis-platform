/// (P239 §4) GOREVE SON TARIH — mobil form artik onu GONDERIYOR.
///
/// OLCULEN KUSUR: `son_tarih` kolonu P230 §4'te eklendi, arka uc kabul
/// ediyor, gorev detayi onu OKUYUP yaziyordu — ama FORM ONU HIC
/// GONDERMIYORDU. Yani "gecikti" durumu arayuzden kurulamiyordu.
///
/// TARIH SECICI ORTAK BILESEN (`core/ui/tarih_satiri.dart`): anket
/// formundaki ozel kopya BURAYA tasindi; ikinci tuketici cikinca iki
/// kopyanin zamanla ayrismasi istenmedi.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/tasks/domain/task_models.dart';

void main() {
  group('TaskDraft govdesi', () {
    test('SON TARIH govdeye UTC ISO olarak girer', () {
      final draft = TaskDraft(
        ad: 'Is',
        sonTarih: DateTime.utc(2026, 9, 20, 17, 30),
      );
      expect(draft.toJson()['son_tarih'], '2026-09-20T17:30:00.000Z');
    });

    test('BOSSA null gider — bugun VARSAYILMAZ', () {
      // Varsayilan bir tarih koymak, kullanicinin vermedigi bir sozu
      // kaydetmek ve her gorevi bir sure sonra "gecikti" yapmak olurdu.
      expect(const TaskDraft(ad: 'Is').toJson()['son_tarih'], isNull);
    });

    test('ANAHTAR HER ZAMAN VAR: PATCH ile son tarih KALDIRILABILIR', () {
      // Alan govdeden dusseydi, "son tarihi sil" istegi sunucuya
      // hic ulasmazdi (tam-govde PATCH kurali).
      expect(const TaskDraft(ad: 'Is').toJson().containsKey('son_tarih'),
          isTrue);
    });

    test('DUZENLEME TASLAGI mevcut son tarihi TASIR', () {
      // Tasimasaydi, kaydet'e basmak var olan son tarihi SESSIZCE
      // silerdi.
      final task = Task(
        id: 'g1',
        ad: 'Is',
        aktif: true,
        sonTarih: DateTime.utc(2026, 9, 20, 17, 30),
      );
      expect(TaskDraft.fromTask(task).sonTarih, task.sonTarih);
      expect(TaskDraft.fromTask(task).toJson()['son_tarih'],
          '2026-09-20T17:30:00.000Z');
    });
  });
}
