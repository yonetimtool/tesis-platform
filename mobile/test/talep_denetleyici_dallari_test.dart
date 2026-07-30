/// TUR 63 — TALEP DENETLEYICILERININ DALLARI.
///
/// Ucuncu envanterin A maddesi: ekranlar suruluyor ama DENETLEYICI DALLARI
/// surulmuyor. Butun surus yardimcilari API'yi sahteleyip **basari** donuyor;
/// hata / iptal / yeniden dene / yeniden girme (re-entrancy) yollari
/// karanlikta kaliyordu. `complaints_controller` kapsami **%35**'ti.
///
/// Burada widget cizilmiyor: denetleyici `ProviderContainer` icinde dogrudan
/// surulur ve DURUM GECISLERI olculur. Olculen dallar:
///   * liste: ApiException (mesaj + kimlik kanallari), beklenmeyen hata,
///     yeniden-girme kilidi (`_refreshing`),
///   * eylemler (donustur/coz/reddet): hata YUKARI firlatilir, basari
///     listeyi tazeler,
///   * form: kategori yukleme iki hata dali + PASIF kategori suzgeci,
///   * foto yuvalari: 3 yuva siniri, secici patlamasi, iptal (null dosya),
///     yukleme hatasi (ag / ag-disi ayrimi), tekrar dene, sil.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/src/core/error/akis_hatasi.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/complaints/data/complaint_api.dart';
import 'package:mobile/src/features/complaints/domain/complaint_models.dart';
import 'package:mobile/src/features/complaints/domain/talep_hata.dart';
import 'package:mobile/src/features/complaints/presentation/complaints_controller.dart';
import 'package:mobile/src/features/tasks/data/task_category_api.dart';
import 'package:mobile/src/features/tasks/domain/task_category_models.dart';
import 'package:mobile/src/features/tasks/domain/task_models.dart';
import 'package:mobile/src/features/tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;

/// Davranisi TESTIN belirledigi API sahtesi.
class _SahteApi extends ComplaintApi {
  _SahteApi() : super(Dio(), TaskCategoryApi(Dio()));

  Object? listeHatasi;
  Object? kategoriHatasi;
  Object? presignHatasi;
  Object? yuklemeHatasi;
  Object? eylemHatasi;
  int listeCagrisi = 0;
  int createCagrisi = 0;
  List<TaskCategory> kategoriler = const [];
  List<Complaint> items = const [];

  @override
  Future<List<Complaint>> fetchAll({TalepDurum? durum}) async {
    listeCagrisi++;
    if (listeHatasi != null) throw listeHatasi!;
    return items;
  }

  @override
  Future<List<TaskCategory>> listTaskCategories() async {
    if (kategoriHatasi != null) throw kategoriHatasi!;
    return kategoriler;
  }

  @override
  Future<PresignTicket> presignUpload({
    required String contentType,
    String? dosyaAdi,
  }) async {
    if (presignHatasi != null) throw presignHatasi!;
    return const PresignTicket(
      fotoKey: 'tenant/talep/abc.jpg',
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
  Future<Complaint> create(ComplaintDraft draft) async {
    createCagrisi++;
    if (eylemHatasi != null) throw eylemHatasi!;
    return _talep();
  }

  @override
  Future<Complaint> convert(String id, ComplaintConvertDraft draft) async {
    if (eylemHatasi != null) throw eylemHatasi!;
    return _talep();
  }

  @override
  Future<Complaint> resolve(String id, ComplaintResolveDraft draft) async {
    if (eylemHatasi != null) throw eylemHatasi!;
    return _talep();
  }

  @override
  Future<Complaint> decline(String id, ComplaintDeclineDraft draft) async {
    if (eylemHatasi != null) throw eylemHatasi!;
    return _talep();
  }
}

/// Secim davranisini TESTIN belirledigi `ImagePicker`.
class _SahteSecici extends ImagePicker {
  _SahteSecici({this.patla = false, this.iptal = false, this.yol});
  final bool patla;
  final bool iptal;

  /// GERCEK bir dosya yolu. `retry` dosyayi YOLDAN yeniden okur; uydurma yol
  /// verilirse tekrar deneme her zaman `fotoYuklenemedi` ile duser (ilk
  /// kosumda tam bunu yasadi ve urun hakkinda bir sey ogretti: gecici dosya
  /// silinmisse "tekrar dene" genel hataya duser, "dosya yok" demez).
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
      // Kucuk ama gercek bayt dizisi: `readAsBytes` dosya sistemine gitmez.
      Uint8List.fromList(List<int>.filled(8, 1)),
      name: 'foto.jpg',
      path: yol ?? '/tmp/foto.jpg',
      mimeType: 'image/jpeg',
    );
  }
}



Complaint _talep() => Complaint(
  id: 't-1',
  acanUserId: 'u-1',
  baslik: 'Asansor arizasi',
  mesaj: 'Kabin 3. katta kaldi.',
  durum: TalepDurum.acik,
  fotograflar: const [],
  gecmis: const [],
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// Mikro gorevlerin ve `await` zincirlerinin BITMESINI bekler.
///
/// `build()` icinde `Future.microtask(_loadCategories)` var ve o da iki `await`
/// asar; tek `Duration.zero` gecikmesi YETMIYOR (ilk kosumda tam bunu
/// yasadi — `categoriesLoading` hala true idi).
Future<void> beklet([int tur = 6]) async {
  for (var i = 0; i < tur; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProviderContainer _kap(_SahteApi api, {UserRole rol = UserRole.yonetici, ImagePicker? secici}) {
  final c = ProviderContainer(
    overrides: [
      complaintApiProvider.overrideWithValue(api),
      currentUserRoleProvider.overrideWith((ref) async => rol),
      if (secici != null) imagePickerProvider.overrideWithValue(secici),
    ],
  );
  // DINLEYICI SART — iki sebeple:
  //  1. `build()` icindeki mikro gorev (`_loadCategories`) dinleyicisi olmayan
  //     saglayicida `ref.mounted == false` gorup DURUMU YAZMADAN donuyor;
  //  2. dinleyicisiz saglayici okumalar arasinda YENIDEN KURULABILIYOR ve
  //     durum sifirlaniyor — `retry` testinde foto yuvasi "kayboldu" sanildi.
  // Ikisini de ilk kosumda yasadi; bu yuzden kap her iki saglayiciyi dinler.
  c.listen(complaintsControllerProvider, (_, _) {});
  c.listen(complaintFormControllerProvider, (_, _) {});
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('ComplaintsController — liste dallari', () {
    test('BASARI: rol yetkileri duruma yazilir', () async {
      final api = _SahteApi()..items = [_talep()];
      final c = _kap(api, rol: UserRole.yonetici);
      final not = c.read(complaintsControllerProvider.notifier);
      await not.refresh();
      final d = c.read(complaintsControllerProvider);
      expect(d.loading, isFalse);
      expect(d.items, hasLength(1));
      expect(d.canRespond, isTrue, reason: 'yonetici yanit verebilir');
      expect(d.errorMessage, isNull);
      expect(d.refreshedAt, isNotNull);
    });

    test('API HATASI: sunucu mesaji ve hata KIMLIGI ayri kanallarda', () async {
      final api = _SahteApi()
        ..listeHatasi = const ApiException(
          code: 'forbidden',
          message: 'Yetkiniz yok',
          statusCode: 403,
        );
      final c = _kap(api);
      await c.read(complaintsControllerProvider.notifier).refresh();
      final d = c.read(complaintsControllerProvider);
      expect(d.loading, isFalse);
      expect(d.errorMessage, 'Yetkiniz yok');
      // 403 bir AG hatasi degil; `agHatasi` bos kalir ve SUNUCU metni gosterilir.
      expect(d.hataKimligi, isNull);
    });

    test('BEKLENMEYEN hata: mesaj YOK, kimlik beklenmeyen', () async {
      final api = _SahteApi()..listeHatasi = StateError('bozuk');
      final c = _kap(api);
      await c.read(complaintsControllerProvider.notifier).refresh();
      final d = c.read(complaintsControllerProvider);
      expect(d.loading, isFalse);
      expect(d.errorMessage, isNull,
          reason: 'sunucu metni yok — uydurma metin gosterilmemeli');
      expect(d.hataKimligi, AkisHatasi.beklenmeyen);
    });

    test('YENIDEN GIRME kilidi: es zamanli iki refresh tek istek yapar',
        () async {
      final api = _SahteApi();
      final c = _kap(api);
      final not = c.read(complaintsControllerProvider.notifier);
      api.listeCagrisi = 0;
      // Ikisi ayni anda: ikincisi kilide takilip donmeli.
      await Future.wait([not.refresh(), not.refresh()]);
      expect(api.listeCagrisi, 1,
          reason: '`_refreshing` kilidi ikinci istegi engellemeli');
    });
  });

  group('ComplaintsController — eylem dallari', () {
    test('BASARI: create sonrasi liste TAZELENIR', () async {
      final api = _SahteApi();
      final c = _kap(api);
      final not = c.read(complaintsControllerProvider.notifier);
      await not.refresh();
      final oncekiCagri = api.listeCagrisi;
      await not.create(const ComplaintDraft(baslik: 'k', mesaj: 'a'));
      expect(api.createCagrisi, 1);
      expect(api.listeCagrisi, oncekiCagri + 1, reason: 'tazeleme yapilmali');
    });

    test('HATA: eylem hatasi YUKARI firlatilir (ekranda gosterilecek)',
        () async {
      final api = _SahteApi()
        ..eylemHatasi = const ApiException(
          code: 'conflict',
          message: 'Bu talep zaten cozuldu',
          statusCode: 409,
        );
      final c = _kap(api);
      final not = c.read(complaintsControllerProvider.notifier);
      await not.refresh();
      // Dort eylemin DORDU de firlatmali (sessizce yutulmamali).
      await expectLater(
        () => not.create(const ComplaintDraft(baslik: 'k', mesaj: 'a')),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        () => not.convert('t-1', const ComplaintConvertDraft(atananUserId: 'u-2')),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        () => not.resolve('t-1', const ComplaintResolveDraft(cozumNotu: 'n')),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        () => not.decline('t-1', const ComplaintDeclineDraft(sebep: 's')),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('ComplaintFormController — kategori dallari', () {
    test('PASIF kategori suzulur', () async {
      final api = _SahteApi()
        ..kategoriler = const [
          TaskCategory(id: '1', ad: 'Temizlik', aktif: true),
          TaskCategory(id: '2', ad: 'Eski kategori', aktif: false),
        ];
      final c = _kap(api);
      await beklet();
      final d = c.read(complaintFormControllerProvider);
      expect(d.categoriesLoading, isFalse);
      expect(d.categories.map((e) => e.id), ['1'],
          reason: 'pasif kategoriye yeni talep yazilmamali');
    });

    test('API HATASI: mesaj + talep hata kimligi', () async {
      final api = _SahteApi()
        ..kategoriHatasi = const ApiException(
          code: 'server_error',
          message: 'Sunucu hatasi',
          statusCode: 500,
        );
      final c = _kap(api);
      await beklet();
      final d = c.read(complaintFormControllerProvider);
      expect(d.categoriesLoading, isFalse);
      expect(d.categoriesError, 'Sunucu hatasi');
      // 500 bir AG hatasi degil: kimlik BOS kalir, SUNUCU metni gosterilir
      // (iki kanal ayrimi — bkz. core/error/akis_hatasi.dart).
      expect(d.categoriesHata, isNull);
    });

    test('BEKLENMEYEN hata: kimlik kategorilerYuklenemedi', () async {
      final api = _SahteApi()..kategoriHatasi = StateError('bozuk');
      final c = _kap(api);
      await beklet();
      final d = c.read(complaintFormControllerProvider);
      expect(d.categoriesError, isNull);
      expect(d.categoriesHata, TalepAkisHatasi.kategorilerYuklenemedi);
    });
  });

  group('ComplaintFormController — foto yuvasi dallari', () {
    test('BASARI: yuva dolar ve fotoKey gelir', () async {
      final api = _SahteApi();
      final c = _kap(api, secici: _SahteSecici());
      final not = c.read(complaintFormControllerProvider.notifier);
      final hata = await not.addPhoto(ImageSource.gallery);
      expect(hata, isNull);
      final d = c.read(complaintFormControllerProvider);
      expect(d.photos, hasLength(1));
      expect(d.photos.single.fotoKey, 'tenant/talep/abc.jpg');
      expect(d.photos.single.busy, isFalse);
      expect(d.uploadPending, isFalse);
    });

    test('IPTAL: secim iptal edilirse yuva ACILMAZ', () async {
      final api = _SahteApi();
      final c = _kap(api, secici: _SahteSecici(iptal: true));
      final not = c.read(complaintFormControllerProvider.notifier);
      expect(await not.addPhoto(ImageSource.camera), isNull);
      expect(c.read(complaintFormControllerProvider).photos, isEmpty);
    });

    test('SECICI PATLARSA: ayrinti DONER, yuva acilmaz', () async {
      final api = _SahteApi();
      final c = _kap(api, secici: _SahteSecici(patla: true));
      final not = c.read(complaintFormControllerProvider.notifier);
      final ayrinti = await not.addPhoto(ImageSource.camera);
      expect(ayrinti, contains('kamera acilamadi'),
          reason: 'denetleyici GORUNEN metin uretmez, ayrinti doner');
      expect(c.read(complaintFormControllerProvider).photos, isEmpty);
    });

    test('UC YUVA SINIRI: dorduncu eklenmez', () async {
      final api = _SahteApi();
      final c = _kap(api, secici: _SahteSecici());
      final not = c.read(complaintFormControllerProvider.notifier);
      for (var i = 0; i < 3; i++) {
        await not.addPhoto(ImageSource.gallery);
      }
      expect(c.read(complaintFormControllerProvider).photos, hasLength(3));
      expect(c.read(complaintFormControllerProvider).canAddPhoto, isFalse);
      await not.addPhoto(ImageSource.gallery);
      expect(c.read(complaintFormControllerProvider).photos, hasLength(3),
          reason: 'sinir asilmamali');
    });

    test('AG HATASI: mesaj YOK, kimlik fotoOnlineGerekli', () async {
      final api = _SahteApi()
        ..presignHatasi = const ApiException(
          code: 'network_error',
          message: '',
        );
      final c = _kap(api, secici: _SahteSecici());
      final not = c.read(complaintFormControllerProvider.notifier);
      await not.addPhoto(ImageSource.gallery);
      final slot = c.read(complaintFormControllerProvider).photos.single;
      expect(slot.busy, isFalse);
      expect(slot.error, isNull, reason: 'ag hatasinda sunucu metni yok');
      expect(slot.hata, TalepAkisHatasi.fotoOnlineGerekli);
      expect(c.read(complaintFormControllerProvider).uploadPending, isTrue);
    });

    test('AG DISI API HATASI: sunucu mesaji yuvaya yazilir', () async {
      final api = _SahteApi()
        ..yuklemeHatasi = const ApiException(
          code: 'payload_too_large',
          message: 'Dosya cok buyuk',
          statusCode: 413,
        );
      final c = _kap(api, secici: _SahteSecici());
      final not = c.read(complaintFormControllerProvider.notifier);
      await not.addPhoto(ImageSource.gallery);
      final slot = c.read(complaintFormControllerProvider).photos.single;
      expect(slot.error, 'Dosya cok buyuk');
    });

    test('BEKLENMEYEN yukleme hatasi: kimlik fotoYuklenemedi', () async {
      final api = _SahteApi()..yuklemeHatasi = StateError('bozuk');
      final c = _kap(api, secici: _SahteSecici());
      final not = c.read(complaintFormControllerProvider.notifier);
      await not.addPhoto(ImageSource.gallery);
      final slot = c.read(complaintFormControllerProvider).photos.single;
      expect(slot.error, isNull);
      expect(slot.hata, TalepAkisHatasi.fotoYuklenemedi);
    });

    test('TEKRAR DENE: hata temizlenir ve yukleme basarili olur', () async {
      // GERCEK gecici dosya: `retry` yoldan yeniden okur.
      final dizin = Directory.systemTemp.createTempSync('talep_test');
      addTearDown(() => dizin.deleteSync(recursive: true));
      final dosya = File('${dizin.path}/foto.jpg')
        ..writeAsBytesSync(List<int>.filled(8, 1));
      final api = _SahteApi()..yuklemeHatasi = StateError('bozuk');
      final c = _kap(api, secici: _SahteSecici(yol: dosya.path));
      final not = c.read(complaintFormControllerProvider.notifier);
      await not.addPhoto(ImageSource.gallery);
      final id = c.read(complaintFormControllerProvider).photos.single.id;
      api.yuklemeHatasi = null; // ag geri geldi
      await not.retry(id);
      final slot = c.read(complaintFormControllerProvider).photos.single;
      expect(slot.hata, isNull);
      expect(slot.fotoKey, isNotNull);
    });

    test('TEKRAR DENE: dosya SILINMISSE genel hata (urun davranisi)',
        () async {
      // `retry` dosyayi yoldan okur; gecici dosya yoksa okuma patlar ve genel
      // `fotoYuklenemedi` kimligi yazilir. Bu davranis KAYDA GECIRILIYOR:
      // kullaniciya "dosya artik yok" demiyor, "yuklenemedi" diyor.
      final api = _SahteApi()..yuklemeHatasi = StateError('bozuk');
      final c = _kap(api, secici: _SahteSecici(yol: '/tmp/olmayan-dosya.jpg'));
      final not = c.read(complaintFormControllerProvider.notifier);
      await not.addPhoto(ImageSource.gallery);
      final id = c.read(complaintFormControllerProvider).photos.single.id;
      api.yuklemeHatasi = null;
      await not.retry(id);
      final slot = c.read(complaintFormControllerProvider).photos.single;
      expect(slot.fotoKey, isNull);
      expect(slot.hata, TalepAkisHatasi.fotoYuklenemedi);
      expect(slot.busy, isFalse, reason: 'yuva askida KALMAMALI');
    });

    test('TEKRAR DENE: BILINMEYEN yuva sessizce yok sayilir', () async {
      final api = _SahteApi();
      final c = _kap(api, secici: _SahteSecici());
      final not = c.read(complaintFormControllerProvider.notifier);
      await not.retry(999); // patlamamali
      expect(c.read(complaintFormControllerProvider).photos, isEmpty);
    });

    test('SIL: yalniz hedef yuva gider (kimlik ile, indeksle DEGIL)',
        () async {
      final api = _SahteApi();
      final c = _kap(api, secici: _SahteSecici());
      final not = c.read(complaintFormControllerProvider.notifier);
      await not.addPhoto(ImageSource.gallery);
      await not.addPhoto(ImageSource.gallery);
      final ilkId = c.read(complaintFormControllerProvider).photos.first.id;
      not.remove(ilkId);
      final kalan = c.read(complaintFormControllerProvider).photos;
      expect(kalan, hasLength(1));
      expect(kalan.single.id, isNot(ilkId));
    });

    test('KATEGORI secimi duruma yazilir', () async {
      final api = _SahteApi();
      final c = _kap(api);
      final not = c.read(complaintFormControllerProvider.notifier);
      not.setKategori('kat-1');
      expect(c.read(complaintFormControllerProvider).kategoriId, 'kat-1');
      not.setKategori(null);
      expect(c.read(complaintFormControllerProvider).kategoriId, isNull);
    });
  });
}
