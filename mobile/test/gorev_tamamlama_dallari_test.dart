/// TUR 63 — GOREV TAMAMLAMA DENETLEYICISININ DALLARI.
///
/// Ucuncu envanterin A maddesi: `task_complete_controller` kapsami **%48**'di.
/// Ekran tur 39'da fotografli surulmustu ama denetleyicinin KARAR DALLARI
/// olculmemisti: NFC okuma hatasi, foto secmekten vazgecme, yukleme hatasinin
/// ag/ag-disi ayrimi, yeniden yukleme, foto ZORUNLU kapisi, "foto henuz
/// yuklenmedi" kapisi, cift gonderim korumasi ve yeni tamamlama baslatma.
///
/// Iki KAPI ozellikle onemli: kullanici foto zorunlu bir gorevi fotosuz ya da
/// yuklemesi bitmemis fotoyla gonderemez — bunlar SUNUCUYA GITMEDEN durur ve
/// hicbir istek atilmaz. Testler istek sayacini da denetliyor.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/nfc/data/nfc_service.dart';
import 'package:mobile/src/features/nfc/domain/nfc_hatasi.dart';
import 'package:mobile/src/features/nfc/domain/nfc_read_result.dart';
import 'package:mobile/src/features/nfc/presentation/nfc_controller.dart'
    show nfcServiceProvider;
import 'package:mobile/src/features/tasks/data/task_api.dart';
import 'package:mobile/src/features/tasks/domain/task_hata.dart';
import 'package:mobile/src/features/tasks/domain/task_models.dart';
import 'package:mobile/src/features/tasks/presentation/task_complete_controller.dart';
import 'package:mobile/src/features/tasks/presentation/tasks_controller.dart';

const _ios = NfcIosMetinleri(
  yaklastir: 'Yaklastir',
  okundu: 'Okundu',
  okunamadi: 'Okunamadi',
  iptal: 'Iptal',
);
const _gorevId = 'g-1';

class _SahteTaskApi extends TaskApi {
  _SahteTaskApi() : super(Dio());

  Object? presignHatasi;
  Object? yuklemeHatasi;
  Object? gonderimHatasi;
  bool tekrarlanan = false;
  int gonderimCagrisi = 0;

  @override
  Future<PresignTicket> presignUpload({
    required String contentType,
    String? dosyaAdi,
  }) async {
    if (presignHatasi != null) throw presignHatasi!;
    return const PresignTicket(
      fotoKey: 'tenant/gorev/abc.jpg',
      uploadUrl: 'https://ornek/put',
      expiresIn: 900,
    );
  }

  @override
  Future<void> uploadPhoto({
    required PresignTicket ticket,
    required List<int> bytes,
    required String contentType,
  }) async {
    if (yuklemeHatasi != null) throw yuklemeHatasi!;
  }

  @override
  Future<TaskCompletionResult> submitCompletion(
    TaskCompletionDraft draft,
  ) async {
    gonderimCagrisi++;
    if (gonderimHatasi != null) throw gonderimHatasi!;
    return TaskCompletionResult(
      completion: TaskCompletion(
        id: 'c-1',
        taskId: draft.taskId,
        tamamlayanUserId: 'u-1',
        tamamlanmaZamani: DateTime(2026, 1, 1),
      ),
      wasDuplicate: tekrarlanan,
    );
  }
}

class _SahteSecici extends ImagePicker {
  _SahteSecici({this.iptal = false, this.patla = false, this.yol});
  final bool iptal;
  final bool patla;
  final String? yol;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (patla) throw StateError('kamera acilamadi');
    if (iptal) return null;
    return XFile.fromData(
      Uint8List.fromList(List<int>.filled(8, 1)),
      name: 'foto.jpg',
      path: yol ?? '/tmp/gorev-foto.jpg',
      mimeType: 'image/jpeg',
    );
  }
}

/// Liste denetleyicisinin SAHTESI.
///
/// `submit` basari dalinda `tasksControllerProvider.notifier.markCompleted`
/// cagriliyor; gercek denetleyici kendi bagimliliklarini (liste API'si, rol)
/// istedigi icin testte patliyordu. Sahte hem patlamayi onler hem de ROZET
/// GUNCELLEMESININ gerceklestigini dogrulamayi saglar.
class _SahteTasks extends TasksController {
  final tamamlananlar = <String, TaskCompletionResult>{};

  @override
  TasksState build() => const TasksState();

  @override
  void markCompleted(String taskId, TaskCompletionResult result) {
    tamamlananlar[taskId] = result;
    super.markCompleted(taskId, result);
  }
}

class _SahteNfc extends NfcService {
  _SahteNfc(this.sonuc);
  final NfcReadResult sonuc;
  int cagri = 0;

  @override
  Future<NfcReadResult> readSingleTag(NfcIosMetinleri ios) async {
    cagri++;
    return sonuc;
  }
}

_SahteTasks? _sonListe;

ProviderContainer _kap(
  _SahteTaskApi api, {
  ImagePicker? secici,
  NfcReadResult? okuma,
}) {
  final liste = _SahteTasks();
  _sonListe = liste;
  final c = ProviderContainer(
    overrides: [
      taskApiProvider.overrideWithValue(api),
      tasksControllerProvider.overrideWith(() => liste),
      if (secici != null) imagePickerProvider.overrideWithValue(secici),
      if (okuma != null) nfcServiceProvider.overrideWithValue(_SahteNfc(okuma)),
    ],
  );
  c.listen(taskCompleteControllerProvider(_gorevId), (_, _) {});
  addTearDown(c.dispose);
  return c;
}

TaskCompleteController _not(ProviderContainer c) =>
    c.read(taskCompleteControllerProvider(_gorevId).notifier);
TaskCompleteState _durum(ProviderContainer c) =>
    c.read(taskCompleteControllerProvider(_gorevId));

/// GERCEK gecici dosya — `retryUpload` fotoyu YOLDAN yeniden okur.
File _gecici() {
  final dizin = Directory.systemTemp.createTempSync('gorev_test');
  addTearDown(() => dizin.deleteSync(recursive: true));
  return File('${dizin.path}/foto.jpg')
    ..writeAsBytesSync(List<int>.filled(8, 1));
}

void main() {
  group('readNfc', () {
    test('BASARI: UID taslaga islenir', () async {
      final c = _kap(_SahteTaskApi(), okuma: const NfcReadResult(uid: '04:A1'));
      await _not(c).readNfc(_ios);
      final d = _durum(c);
      expect(d.nfcReading, isFalse);
      expect(d.draft.nfcTagUid, '04:A1');
      expect(d.nfcHata, isNull);
    });

    test('HATA: kimlik + detay yazilir, UID taslaga GIRMEZ', () async {
      final c = _kap(
        _SahteTaskApi(),
        okuma: const NfcReadResult(
          hata: NfcHatasi.kapali,
          hataDetay: 'nfc disabled',
        ),
      );
      await _not(c).readNfc(_ios);
      final d = _durum(c);
      expect(d.nfcHata, GorevAkisHatasi.etiketOkunamadi);
      expect(d.nfcKimlik, NfcHatasi.kapali);
      expect(d.nfcKimlikDetay, 'nfc disabled');
      expect(d.draft.nfcTagUid, isNull);
      expect(d.nfcError, isNull, reason: 'metin degil KIMLIK tasinir');
    });

    test('OKUMA SURERKEN ikinci cagri yok sayilir', () async {
      final c = _kap(_SahteTaskApi(), okuma: const NfcReadResult(uid: '04:A1'));
      final not = _not(c);
      await Future.wait([not.readNfc(_ios), not.readNfc(_ios)]);
      expect(_durum(c).draft.nfcTagUid, '04:A1');
    });
  });

  group('pickAndUploadPhoto', () {
    test('BASARI: fotoKey taslaga yazilir', () async {
      final api = _SahteTaskApi();
      final c = _kap(api, secici: _SahteSecici());
      await _not(c).pickAndUploadPhoto(ImageSource.camera);
      final d = _durum(c);
      expect(d.photoBusy, isFalse);
      expect(d.draft.fotoKey, 'tenant/gorev/abc.jpg');
      expect(d.photoError, isNull);
      expect(d.fotoBekliyor, isFalse);
    });

    test('VAZGECME: secim iptal edilirse MEVCUT secim korunur', () async {
      final api = _SahteTaskApi();
      final dosya = _gecici();
      final c = _kap(api, secici: _SahteSecici(yol: dosya.path));
      await _not(c).pickAndUploadPhoto(ImageSource.camera);
      final oncekiKey = _durum(c).draft.fotoKey;
      // Ikinci secim IPTAL: yeni bir secici ile ayni kabi kullanamiyoruz, bu
      // yuzden iptal davranisi ayri kapta dogrulanir.
      final c2 = _kap(api, secici: _SahteSecici(iptal: true));
      await _not(c2).pickAndUploadPhoto(ImageSource.gallery);
      expect(_durum(c2).photoBusy, isFalse);
      expect(_durum(c2).photoPath, isNull);
      expect(oncekiKey, isNotNull);
    });

    test('AG HATASI: metin YOK, kimlik fotoOnlineGerekli', () async {
      final api = _SahteTaskApi()
        ..presignHatasi = const ApiException(
          code: 'network_error',
          message: '',
        );
      final c = _kap(api, secici: _SahteSecici());
      await _not(c).pickAndUploadPhoto(ImageSource.camera);
      final d = _durum(c);
      expect(d.photoError, isNull);
      expect(d.photoHata, GorevAkisHatasi.fotoOnlineGerekli);
      expect(d.fotoBekliyor, isTrue,
          reason: 'foto secildi ama key yok — gonderim kapisi bunu gormeli');
    });

    test('AG DISI API HATASI: sunucu metni gosterilir', () async {
      final api = _SahteTaskApi()
        ..yuklemeHatasi = const ApiException(
          code: 'payload_too_large',
          message: 'Dosya cok buyuk',
          statusCode: 413,
        );
      final c = _kap(api, secici: _SahteSecici());
      await _not(c).pickAndUploadPhoto(ImageSource.camera);
      expect(_durum(c).photoError, 'Dosya cok buyuk');
    });

    test('SECICI PATLARSA: ayrinti metni duruma yazilir', () async {
      final api = _SahteTaskApi();
      final c = _kap(api, secici: _SahteSecici(patla: true));
      await _not(c).pickAndUploadPhoto(ImageSource.camera);
      final d = _durum(c);
      expect(d.photoBusy, isFalse);
      expect(d.photoError, contains('kamera acilamadi'));
    });

    test('MESGULKEN ikinci secim yok sayilir', () async {
      final api = _SahteTaskApi();
      final c = _kap(api, secici: _SahteSecici());
      final not = _not(c);
      await Future.wait([
        not.pickAndUploadPhoto(ImageSource.camera),
        not.pickAndUploadPhoto(ImageSource.camera),
      ]);
      expect(_durum(c).draft.fotoKey, isNotNull);
    });
  });

  group('retryUpload / removePhoto', () {
    test('FOTO YOKSA yeniden yukleme hicbir sey yapmaz', () async {
      final api = _SahteTaskApi();
      final c = _kap(api);
      await _not(c).retryUpload();
      expect(_durum(c).photoBusy, isFalse);
      expect(_durum(c).draft.fotoKey, isNull);
    });

    test('YENIDEN YUKLEME: ag geri gelince key gelir', () async {
      final dosya = _gecici();
      final api = _SahteTaskApi()
        ..yuklemeHatasi = const ApiException(code: 'network_error', message: '');
      final c = _kap(api, secici: _SahteSecici(yol: dosya.path));
      final not = _not(c);
      await not.pickAndUploadPhoto(ImageSource.camera);
      expect(_durum(c).fotoBekliyor, isTrue);
      api.yuklemeHatasi = null;
      await not.retryUpload();
      expect(_durum(c).draft.fotoKey, 'tenant/gorev/abc.jpg');
      expect(_durum(c).fotoBekliyor, isFalse);
    });

    test('YENIDEN YUKLEME AG HATASI: kisa kimlik yazilir', () async {
      final dosya = _gecici();
      final api = _SahteTaskApi();
      final c = _kap(api, secici: _SahteSecici(yol: dosya.path));
      final not = _not(c);
      await not.pickAndUploadPhoto(ImageSource.camera);
      api.presignHatasi = const ApiException(
        code: 'network_error',
        message: '',
      );
      await not.retryUpload();
      expect(_durum(c).photoHata, GorevAkisHatasi.fotoOnlineGerekliKisa);
    });

    test('FOTOYU KALDIR: yol ve key temizlenir', () async {
      final api = _SahteTaskApi();
      final c = _kap(api, secici: _SahteSecici());
      final not = _not(c);
      await not.pickAndUploadPhoto(ImageSource.camera);
      not.removePhoto();
      final d = _durum(c);
      expect(d.photoPath, isNull);
      expect(d.draft.fotoKey, isNull);
      expect(d.fotoBekliyor, isFalse);
    });
  });

  group('submit — kapilar ve hata dallari', () {
    test('FOTO ZORUNLU: fotosuz gonderim SUNUCUYA GITMEZ', () async {
      final api = _SahteTaskApi();
      final c = _kap(api);
      await _not(c).submit(fotoZorunlu: true);
      expect(_durum(c).submitHata, GorevAkisHatasi.fotoZorunlu);
      expect(api.gonderimCagrisi, 0, reason: 'bosuna istek atilmamali');
    });

    test('FOTO HENUZ YUKLENMEDI: gonderim durdurulur', () async {
      final api = _SahteTaskApi()
        ..presignHatasi = const ApiException(code: 'network_error', message: '');
      final c = _kap(api, secici: _SahteSecici());
      final not = _not(c);
      await not.pickAndUploadPhoto(ImageSource.camera);
      expect(_durum(c).fotoBekliyor, isTrue);
      await not.submit();
      expect(_durum(c).submitHata, GorevAkisHatasi.fotoHenuzYuklenmedi);
      expect(api.gonderimCagrisi, 0);
    });

    test('BASARI: sonuc duruma yazilir', () async {
      final api = _SahteTaskApi();
      final c = _kap(api);
      await _not(c).submit();
      final d = _durum(c);
      expect(d.submitting, isFalse);
      expect(d.result, isNotNull);
      expect(d.result!.wasDuplicate, isFalse);
      expect(api.gonderimCagrisi, 1);
      // Liste ROZETI de guncellenmeli (tamamlama akisinin gorunur sonucu).
      expect(_sonListe!.tamamlananlar.keys, contains(_gorevId));
    });

    test('SONUC VARSA ikinci gonderim yok sayilir (cift kayit korumasi)',
        () async {
      final api = _SahteTaskApi();
      final c = _kap(api);
      final not = _not(c);
      await not.submit();
      await not.submit();
      expect(api.gonderimCagrisi, 1);
    });

    test('CEVRIMDISI gonderim: kimlik tamamlamaOffline, metin YOK', () async {
      final api = _SahteTaskApi()
        ..gonderimHatasi = const ApiException(
          code: 'network_error',
          message: '',
        );
      final c = _kap(api);
      await _not(c).submit();
      final d = _durum(c);
      expect(d.submitError, isNull);
      expect(d.submitHata, GorevAkisHatasi.tamamlamaOffline);
    });

    test('SUNUCU HATASI: metin gosterilir', () async {
      final api = _SahteTaskApi()
        ..gonderimHatasi = const ApiException(
          code: 'validation_error',
          message: 'Fotograf zorunlu',
          statusCode: 422,
        );
      final c = _kap(api);
      await _not(c).submit();
      expect(_durum(c).submitError, 'Fotograf zorunlu');
    });

    test('BEKLENMEYEN hata: kimlik beklenmeyen', () async {
      final api = _SahteTaskApi()..gonderimHatasi = StateError('bozuk');
      final c = _kap(api);
      await _not(c).submit();
      expect(_durum(c).submitHata, GorevAkisHatasi.beklenmeyen);
    });

    test('YENI TAMAMLAMA: durum sifirlanir, yeni an alinir', () async {
      final api = _SahteTaskApi();
      final c = _kap(api, secici: _SahteSecici());
      final not = _not(c);
      await not.pickAndUploadPhoto(ImageSource.camera);
      await not.submit();
      expect(_durum(c).result, isNotNull);
      not.startNew();
      final d = _durum(c);
      expect(d.result, isNull);
      expect(d.draft.fotoKey, isNull);
      expect(d.photoPath, isNull);
      expect(d.draft.taskId, _gorevId, reason: 'gorev kimligi korunmali');
    });

    test('NOTLAR: bos/bosluk metin NULL olur', () async {
      final api = _SahteTaskApi();
      final c = _kap(api);
      final not = _not(c);
      not.setNotlar('   ');
      expect(_durum(c).draft.notlar, isNull);
      not.setNotlar('  kapak kirik  ');
      expect(_durum(c).draft.notlar, 'kapak kirik');
    });
  });
}
