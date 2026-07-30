/// TUR 64 — REZERVASYONDA ESZAMANLILIK / YARIS.
///
/// Ucuncu envanterin E maddesi: "iki sekmede ayni kaydi duzenleme (409) tur
/// 54'te PANELDE denendi ama MOBILDE hic: iki cihazdan ayni gorevi tamamlama,
/// AYNI SLOTU rezerve etme". Backend kurallari `reservations_timing.py`de ve
/// pytest ile kapli; **istemci tarafi** hic olculmedi.
///
/// Burada olculen sey su: iki kullanici ayni slotu istediginde ikinci istek
/// 409 alir. Istemci bu durumda
///   * hatayi SESSIZCE YUTMAMALI (cagirana firlatmali — ekran gosterecek),
///   * ve listeyi TAZELEMELI ki kullanici slotun artik dolu oldugunu gorsun.
///
/// `cancel` ozel bir dal: `finally` icinde tazeleme yapiyor, yani 409 (zaten
/// iptal edilmis) halinde de guncel durum cekilir. Bu davranis kayda geciyor.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/akis_hatasi.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/rezervasyon/data/rezervasyon_api.dart';
import 'package:mobile/src/features/rezervasyon/domain/rezervasyon_models.dart';
import 'package:mobile/src/features/rezervasyon/presentation/rezervasyon_controller.dart';

/// Ikinci istekte 409 doneren API — "baskasi kapti" yarisinin ta kendisi.
class _SahteRezApi extends RezervasyonApi {
  _SahteRezApi() : super(Dio());

  int istekCagrisi = 0;
  int listeCagrisi = 0;
  int iptalCagrisi = 0;
  Object? istekHatasi;
  Object? iptalHatasi;
  Object? listeHatasi;
  List<Slot> slotlar = const [];
  List<Rezervasyon> items = const [];

  @override
  Future<List<OrtakAlan>> fetchAreas() async {
    if (listeHatasi != null) throw listeHatasi!;
    return [
      OrtakAlan(
        id: 'al-1',
        ad: 'Havuz',
        aktif: true,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<List<Rezervasyon>> fetchReservations({RezervasyonDurum? durum}) async {
    listeCagrisi++;
    if (listeHatasi != null) throw listeHatasi!;
    return items;
  }

  @override
  Future<List<Slot>> fetchSlots(String alanId, String tarih) async => slotlar;

  @override
  Future<Rezervasyon> createReservation(RezervasyonDraft draft) async {
    istekCagrisi++;
    if (istekHatasi != null) throw istekHatasi!;
    return _rez();
  }

  @override
  Future<OrtakAlan> createArea(OrtakAlanDraft draft) async => (await fetchAreas()).first;

  @override
  Future<OrtakAlan> updateArea(String id, Map<String, dynamic> govde) async =>
      (await fetchAreas()).first;

  @override
  Future<Rezervasyon> cancel(String id) async {
    iptalCagrisi++;
    if (iptalHatasi != null) throw iptalHatasi!;
    return _rez(durum: RezervasyonDurum.iptal);
  }
}

Rezervasyon _rez({RezervasyonDurum durum = RezervasyonDurum.onaylandi}) =>
    Rezervasyon(
      id: 'r-1',
      alanId: 'al-1',
      unitId: 'd-1',
      tarih: '2026-08-01',
      baslangic: '10:00',
      bitis: '11:00',
      kisiSayisi: 2,
      durum: durum,
      talepEdenUserId: 'u-1',
      createdAt: DateTime(2026, 7, 30),
    );

const _taslak = RezervasyonDraft(
  alanId: 'al-1',
  tarih: '2026-08-01',
  baslangic: '10:00',
  bitis: '11:00',
  kisiSayisi: 2,
);

ProviderContainer _kap(
  _SahteRezApi api, {
  UserRole rol = UserRole.resident,
  String kullanici = 'u-1',
}) {
  final c = ProviderContainer(
    overrides: [
      rezervasyonApiProvider.overrideWithValue(api),
      currentUserRoleProvider.overrideWith((ref) async => rol),
      currentUserIdProvider.overrideWith((ref) async => kullanici),
    ],
  );
  c.listen(rezervasyonControllerProvider, (_, _) {});
  addTearDown(c.dispose);
  return c;
}

Future<void> beklet([int tur = 6]) async {
  for (var i = 0; i < tur; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('YARIS: ayni slotu iki kullanici isterse', () {
    test('409 cagirana FIRLATILIR (sessizce yutulmaz)', () async {
      final api = _SahteRezApi()
        ..istekHatasi = const ApiException(
          code: 'conflict',
          message: 'Bu saat aralig zaten dolu',
          statusCode: 409,
        );
      final c = _kap(api);
      final not = c.read(rezervasyonControllerProvider.notifier);
      await beklet();
      await expectLater(
        () => not.request(_taslak),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
      expect(api.istekCagrisi, 1);
    });

    test('409 sonrasi liste TAZELENIR (izgara dolu gorunsun)', () async {
      // BULUNAN TUTARSIZLIK (tur 64): `cancel` 409'da `finally` ile
      // tazeliyordu, `request` tazelemiyordu — yani yarisi KAYBEDEN kullanici
      // slotun doldugunu gormuyor, izgara eski haliyle kaliyordu. `request`
      // artik ayni deseni kullaniyor.
      final api = _SahteRezApi()
        ..istekHatasi = const ApiException(
          code: 'conflict',
          message: 'dolu',
          statusCode: 409,
        );
      final c = _kap(api);
      final not = c.read(rezervasyonControllerProvider.notifier);
      await beklet();
      final oncekiListe = api.listeCagrisi;
      await not.request(_taslak).catchError((_) {});
      expect(api.listeCagrisi, oncekiListe + 1,
          reason: 'yarisi kaybeden kullanici GUNCEL izgarayi gormeli');
    });

    test('BASARI: istek sonrasi liste tazelenir', () async {
      final api = _SahteRezApi();
      final c = _kap(api);
      final not = c.read(rezervasyonControllerProvider.notifier);
      await beklet();
      final oncekiListe = api.listeCagrisi;
      await not.request(_taslak);
      expect(api.listeCagrisi, oncekiListe + 1);
    });
  });

  group('IPTAL: 409 (zaten iptal) dali', () {
    test('HATA FIRLATILIR ama liste YINE DE tazelenir (finally)', () async {
      final api = _SahteRezApi()
        ..iptalHatasi = const ApiException(
          code: 'conflict',
          message: 'Zaten iptal edilmis',
          statusCode: 409,
        );
      final c = _kap(api);
      final not = c.read(rezervasyonControllerProvider.notifier);
      await beklet();
      final oncekiListe = api.listeCagrisi;
      await expectLater(() => not.cancel('r-1'), throwsA(isA<ApiException>()));
      expect(api.iptalCagrisi, 1);
      expect(api.listeCagrisi, oncekiListe + 1,
          reason: '`finally` tazelemesi kullaniciya GUNCEL durumu gostermeli');
    });

    test('BASARI: iptal sonrasi liste tazelenir', () async {
      final api = _SahteRezApi();
      final c = _kap(api);
      final not = c.read(rezervasyonControllerProvider.notifier);
      await beklet();
      final oncekiListe = api.listeCagrisi;
      await not.cancel('r-1');
      expect(api.listeCagrisi, oncekiListe + 1);
    });
  });

  group('refresh — rol ve hata dallari', () {
    test('SAHA ROLU: rezervasyon listesi CEKILMEZ (403 savunmasi)', () async {
      final api = _SahteRezApi();
      final c = _kap(api, rol: UserRole.security);
      final not = c.read(rezervasyonControllerProvider.notifier);
      api.listeCagrisi = 0;
      await not.refresh();
      expect(api.listeCagrisi, 0,
          reason: 'saha rolu /reservations goremez — istek hic atilmamali');
      expect(c.read(rezervasyonControllerProvider).items, isEmpty);
    });

    test('YONETICI: liste cekilir ve yetkiler duruma yazilir', () async {
      final api = _SahteRezApi()..items = [_rez()];
      final c = _kap(api, rol: UserRole.yonetici);
      await c.read(rezervasyonControllerProvider.notifier).refresh();
      final d = c.read(rezervasyonControllerProvider);
      expect(d.items, hasLength(1));
      expect(d.canManageAreas, isTrue);
      expect(d.alanlar, hasLength(1));
    });

    test('API HATASI: sunucu metni duruma yazilir', () async {
      final api = _SahteRezApi()
        ..listeHatasi = const ApiException(
          code: 'server_error',
          message: 'Sunucu hatasi',
          statusCode: 500,
        );
      final c = _kap(api);
      await c.read(rezervasyonControllerProvider.notifier).refresh();
      final d = c.read(rezervasyonControllerProvider);
      expect(d.loading, isFalse);
      expect(d.errorMessage, 'Sunucu hatasi');
    });

    test('BEKLENMEYEN hata: kimlik beklenmeyen, metin YOK', () async {
      final api = _SahteRezApi()..listeHatasi = StateError('bozuk');
      final c = _kap(api);
      await c.read(rezervasyonControllerProvider.notifier).refresh();
      final d = c.read(rezervasyonControllerProvider);
      expect(d.errorMessage, isNull);
      expect(d.hataKimligi, AkisHatasi.beklenmeyen);
    });

    test('YENIDEN GIRME kilidi: es zamanli iki tazeleme tek istek', () async {
      final api = _SahteRezApi();
      final c = _kap(api, rol: UserRole.yonetici);
      final not = c.read(rezervasyonControllerProvider.notifier);
      await beklet();
      api.listeCagrisi = 0;
      await Future.wait([not.refresh(), not.refresh()]);
      expect(api.listeCagrisi, 1);
    });
  });

  test('ALAN eylemleri: her biri sonrasinda liste tazelenir', () async {
    final api = _SahteRezApi();
    final c = _kap(api, rol: UserRole.yonetici);
    final not = c.read(rezervasyonControllerProvider.notifier);
    await beklet();
    var sayac = api.listeCagrisi;
    await not.createArea(const OrtakAlanDraft(ad: 'Yeni alan'));
    expect(api.listeCagrisi, ++sayac);
    await not.editArea('al-1', const OrtakAlanDraft(ad: 'Havuz 2'));
    expect(api.listeCagrisi, ++sayac);
    await not.setAreaActive('al-1', false);
    expect(api.listeCagrisi, ++sayac);
  });
}
