/// SITE KURALI + DUYURULAR + SAKINLER i18n (tur 7) — dil degistirme ornegi,
/// KIMLIK/METIN ayrimi ve RTL (Arapca) denetimi.
///
/// Kritik iddialar:
///   * Uc modulde de gorunen metin ARB'den gelir; denetleyiciler hata
///     KIMLIGI dondurur (`AkisHatasi`) — sunucu metni ayri kanaldir.
///   * Kullanici verisi (kural basligi, sakin adi) cevrilmez ama cumleye
///     PLACEHOLDER olarak girer; tirnaklar korunur.
///   * Ortak `showTempCodeDialog` kendi metinlerini `l10n`'dan alir; ACIKLAMA
///     satirini CAGIRAN yerellestirir (baglama gore degisir).
///   * Cok-parametreli `duyuruMeta` MESAJ sirasinda uretilir (tur 5 bulgusu).
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/features/announcements/data/announcement_api.dart';
import 'package:mobile/src/features/announcements/domain/announcement_models.dart';
import 'package:mobile/src/features/announcements/presentation/announcements_screen.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/residents/data/residents_api.dart';
import 'package:mobile/src/features/residents/presentation/residents_screen.dart';
import 'package:mobile/src/features/site_kurali/data/site_kurali_api.dart';
import 'package:mobile/src/features/site_kurali/domain/site_kurali_models.dart';
import 'package:mobile/src/features/site_kurali/presentation/site_kurali_screen.dart';

import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';

// --------------------------------------------------------------------------
// Sahteler (ag YOK)
// --------------------------------------------------------------------------
class _FakeKuralApi extends SiteKuraliApi {
  _FakeKuralApi(this._items) : super(Dio());
  final List<SiteKurali> _items;

  @override
  Future<List<SiteKurali>> fetchAll({String? q}) async => _items;
}

class _FakeDuyuruApi extends AnnouncementApi {
  _FakeDuyuruApi(this._items) : super(Dio());
  final List<Announcement> _items;

  @override
  Future<List<Announcement>> fetchAll() async => _items;
}

SiteKurali _kural({String baslik = 'Havuz Saatleri', String? fotoUrl}) =>
    SiteKurali(
      id: 'k-1',
      baslik: baslik,
      icerik: 'Havuz 08:00-22:00 arasi aciktir.',
      fotoKey: fotoUrl == null ? null : 't/kural/x.jpg',
      fotoUrl: fotoUrl,
      sira: 1,
      olusturanUserId: 'yon-1',
      olusturanAd: 'Acme Yonetici',
      createdAt: DateTime.utc(2026, 7, 10, 9),
    );

Announcement _duyuru({bool duzenlendi = false, String? fotoUrl}) =>
    Announcement(
      id: 'a-1',
      baslik: 'Su kesintisi',
      govde: 'Yarin 10:00-12:00.',
      olusturanUserId: 'u-1',
      // null: "Yonetim" varsayilanina duser (cevrilen metin).
      olusturanAd: null,
      fotoKey: fotoUrl == null ? null : 't/duyuru/x.jpg',
      fotoUrl: fotoUrl,
      createdAt: DateTime.utc(2026, 7, 8, 10),
      updatedAt: duzenlendi
          ? DateTime.utc(2026, 7, 9, 11)
          : DateTime.utc(2026, 7, 8, 10),
    );

ResidentMember _sakin({String? unitNo = 'A-12', bool aktif = true}) =>
    ResidentMember(
      userId: 'u-1',
      ad: 'Ayse Sakin',
      unitNo: unitNo,
      isActive: aktif,
    );

Widget _kuralEkrani(Locale locale,
        {UserRole role = UserRole.yonetici, String? fotoUrl}) =>
    ProviderScope(
      overrides: [
        siteKuraliApiProvider
            .overrideWithValue(_FakeKuralApi([_kural(fotoUrl: fotoUrl)])),
        currentUserRoleProvider.overrideWith((ref) async => role),
      ],
      child: l10nApp(const SiteKuraliScreen(), locale: locale),
    );

Widget _duyuruEkrani(
  Locale locale, {
  bool duzenlendi = false,
  String? fotoUrl,
}) =>
    ProviderScope(
      overrides: [
        announcementApiProvider.overrideWithValue(
          _FakeDuyuruApi([_duyuru(duzenlendi: duzenlendi, fotoUrl: fotoUrl)]),
        ),
        currentUserRoleProvider.overrideWith((ref) async => UserRole.yonetici),
      ],
      child: l10nApp(const AnnouncementsScreen(), locale: locale),
    );

Widget _sakinEkrani(Locale locale, {List<ResidentMember>? items}) =>
    ProviderScope(
      overrides: [
        residentsProvider.overrideWith((ref) async => items ?? [_sakin()]),
      ],
      child: l10nApp(const ResidentsScreen(), locale: locale),
    );

/// Ayni `ProviderScope` tipini ust uste pump etmek KABI YENILEMEZ: Riverpod
/// override'lari YERINDE guncellemeye calisir (denetleyici zaten yuklenmis
/// durumu korur, hatta "provider was not overridden" firlatir). Iki senaryo
/// arasinda BOS bir agac cizip kabi soktururuz.
Future<void> _sifirla(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void _ekran(WidgetTester tester, {double g = 430, double h = 1400}) {
  tester.view.physicalSize = Size(g, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  // ============================== SITE KURALI =============================
  testWidgets('KURAL: tr → en → ru dil degisimi (baslik + FAB + arama ipucu)',
      (tester) async {
    _ekran(tester);
    for (final (locale, baslik, yeni, ipucu) in [
      (
        const Locale('tr'),
        'SİTE KURALLARI',
        'Yeni kural',
        'Başlıkta ara (örn. havuz)'
      ),
      (
        const Locale('en'),
        'SITE RULES',
        'New rule',
        'Search titles (e.g. pool)'
      ),
      (
        const Locale('ru'),
        'ПРАВИЛА ОБЪЕКТА',
        'Новое правило',
        'Поиск по заголовкам (напр. бассейн)'
      ),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(_kuralEkrani(locale));
      await tester.pumpAndSettle();

      expect(find.text(baslik), findsOneWidget, reason: '$locale AppBar');
      expect(find.text(yeni), findsOneWidget, reason: '$locale FAB');
      expect(find.text(ipucu), findsOneWidget, reason: '$locale arama');
      // SUNUCU verisi cevrilmez.
      expect(find.text('Havuz Saatleri'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('KURAL: bos liste metni ROLE gore secilir ve cevrilir',
      (tester) async {
    _ekran(tester);
    for (final (locale, role, beklenen) in [
      (
        const Locale('tr'),
        UserRole.yonetici,
        'Henüz kural yok. "Yeni kural" ile ekleyin.'
      ),
      (const Locale('tr'), UserRole.resident, 'Henüz kural yayınlanmamış.'),
      (const Locale('de'), UserRole.resident, 'Noch keine Regeln veröffentlicht.'),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            siteKuraliApiProvider.overrideWithValue(_FakeKuralApi(const [])),
            currentUserRoleProvider.overrideWith((ref) async => role),
          ],
          child: l10nApp(const SiteKuraliScreen(), locale: locale),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(beklenen), findsOneWidget, reason: '$locale/$role');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('KURAL: silme onayi kullanici verisini PLACEHOLDER ile kurar',
      (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_kuralEkrani(const Locale('en')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Havuz Saatleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this rule?'), findsOneWidget);
    expect(
      find.text('"Havuz Saatleri" will be permanently deleted.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  // =============================== DUYURULAR ==============================
  testWidgets('DUYURU: tr → en → fr dil degisimi (baslik + FAB + bos durum)',
      (tester) async {
    _ekran(tester);
    for (final (locale, baslik, yeni) in [
      (const Locale('tr'), 'DUYURULAR', 'Yeni duyuru'),
      (const Locale('en'), 'ANNOUNCEMENTS', 'New announcement'),
      (const Locale('fr'), 'ANNONCES', 'Nouvelle annonce'),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(_duyuruEkrani(locale));
      await tester.pumpAndSettle();
      expect(find.text(baslik), findsOneWidget, reason: '$locale AppBar');
      expect(find.text(yeni), findsOneWidget, reason: '$locale FAB');
      expect(find.text('Su kesintisi'), findsOneWidget); // sunucu verisi
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('DUYURU: yazar bos ise "Yonetim" cevirisine duser + duzenlendi eki',
      (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_duyuruEkrani(const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Management · '), findsOneWidget);
    expect(find.textContaining('· edited'), findsNothing);

    await _sifirla(tester);
    await tester.pumpWidget(_duyuruEkrani(const Locale('en'), duzenlendi: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('· edited'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ================================ SAKINLER ==============================
  testWidgets('SAKIN: tr → en → es dil degisimi (baslik + FAB + daire etiketi)',
      (tester) async {
    _ekran(tester);
    for (final (locale, baslik, ekle, daire) in [
      (const Locale('tr'), 'SİTE SAKİNLERİ', 'Sakin ekle', 'Daire A-12'),
      (const Locale('en'), 'RESIDENTS', 'Add resident', 'Unit A-12'),
      (
        const Locale('es'),
        'RESIDENTES DEL SITIO',
        'Añadir residente',
        'Unidad A-12'
      ),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(_sakinEkrani(locale));
      await tester.pumpAndSettle();
      expect(find.text(baslik), findsOneWidget, reason: '$locale AppBar');
      expect(find.text(ekle), findsOneWidget, reason: '$locale FAB');
      expect(find.text(daire), findsOneWidget, reason: '$locale daire');
      expect(find.text('Ayse Sakin'), findsOneWidget); // sunucu verisi
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('SAKIN: daire atanmamis + pasif cipi cevrilir', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(
      _sakinEkrani(
        const Locale('de'),
        items: [_sakin(unitNo: null, aktif: false)],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Keine Wohnung zugewiesen'), findsOneWidget);
    expect(find.text('Inaktiv'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SAKIN: bos liste + silme onayi (ad PLACEHOLDER)', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_sakinEkrani(const Locale('en'), items: const []));
    await tester.pumpAndSettle();
    expect(
      find.text('No residents yet.\nAdd one from the bottom right.'),
      findsOneWidget,
    );

    await _sifirla(tester);
    await tester.pumpWidget(_sakinEkrani(const Locale('en')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Delete resident?'), findsOneWidget);
    expect(find.textContaining('"Ayse Sakin" will be removed.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ============================ SAF CEVIRI KILIDI =========================
  test('duyuruMeta: parametreler MESAJ sirasinda (alfabetik DEGIL)', () async {
    final tr = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(
      tr.duyuruMeta('Yönetim', '08.07.2026 · 10:00', ' · düzenlendi'),
      'Yönetim · 08.07.2026 · 10:00 · düzenlendi',
    );
    expect(
      tr.kuralSilOnayGovde('Havuz Saatleri'),
      '"Havuz Saatleri" kalıcı olarak silinecek.',
    );
    expect(tr.sakinSilindi('Ayse'), '"Ayse" silindi (numara serbest)');
  });

  test('gecici kod dialogu + sakin metinleri 7 dilde var', () async {
    for (final kod in ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es']) {
      final l10n = await AppLocalizations.delegate.load(Locale(kod));
      for (final metin in [
        l10n.ortakGeciciKodBaslik,
        l10n.ortakKopyala,
        l10n.ortakKopyalandi,
        l10n.sakinEkle,
        l10n.sakinParolaSifirla,
        l10n.kuralYeni,
        l10n.duyuruYayinla,
      ]) {
        expect(metin.trim(), isNotEmpty, reason: kod);
      }
      // Placeholder tasiyan metinler ADI GERCEKTEN yerlestirmeli.
      expect(l10n.sakinYeniKodMesaji('Ayse'), contains('Ayse'), reason: kod);
      expect(l10n.sakinParolaSifirlaGovde('Ayse'), contains('Ayse'),
          reason: kod);
    }
  });

  // ================================= RTL =================================
  testWidgets('RTL: KURAL Arapca (form-yogun) — kural formu TASMAZ',
      (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_kuralEkrani(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('قواعد المجمّع'))),
        TextDirection.rtl);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('نص القاعدة *'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'kural formu Arapca metinlerle tasmamali');
  });

  testWidgets('RTL: DUYURU Arapca — kart + form TASMAZ', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_duyuruEkrani(const Locale('ar'), duzenlendi: true));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('الإعلانات'))),
        TextDirection.rtl);
    expect(tester.takeException(), isNull, reason: 'duyuru karti');

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('نص الإعلان'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'duyuru formu Arapca metinlerle tasmamali');
  });

  testWidgets('RTL: SAKIN Arapca — liste + ekleme formu TASMAZ', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_sakinEkrani(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('سكان المجمّع'))),
        TextDirection.rtl);
    expect(tester.takeException(), isNull, reason: 'sakin listesi');

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('رقم الجوال'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'sakin ekleme formu Arapca metinlerle tasmamali');
  });

  // Tur 7 taramasinin buldugu TASMA: gorsel yuklenemedigindeki
  // "Görsel yüklenemedi" satiri dar ekranda sigmiyordu (TR'de de). Ayni desen
  // kargo detayinda da vardi — tur 6 sondasinda fotoUrl bos oldugu icin
  // yakalanmamisti; ucu birlikte duzeltildi.
  testWidgets('DAR EKRAN 320 dp: kirik gorsel satiri TASMAZ', (tester) async {
    _ekran(tester, g: 320, h: 1800);
    await tester.pumpWidget(
      _duyuruEkrani(const Locale('tr'), fotoUrl: 'https://example.invalid/x.jpg'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Görsel yüklenemedi'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'kirik gorsel satiri 320 dp sigmali');
  });

  // Dar ekran (320 dp): en uzun ceviriler + yardimci metinler.
  testWidgets('DAR EKRAN 320 dp: uc ekran ve formlari TASMAZ', (tester) async {
    _ekran(tester, g: 320, h: 1800);
    for (final (etiket, ekran, formAlani) in [
      ('kural', _kuralEkrani(const Locale('ar')), 'نص القاعدة *'),
      ('duyuru', _duyuruEkrani(const Locale('ar')), 'نص الإعلان'),
      ('sakin', _sakinEkrani(const Locale('tr')), 'Cep telefonu'),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(ekran);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$etiket listesi 320');

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text(formAlani), findsOneWidget, reason: '$etiket formu');
      expect(tester.takeException(), isNull, reason: '$etiket formu 320');
    }
  });

  // ---- TUR 24: EKRAN SURUSU (bkz. README — sozluk degil EKRAN olcumu) ----
  testWidgets('SURUS: site kurali ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_kuralEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });

  testWidgets('SURUS: sakinler ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_sakinEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });



  // ---- TUR 26: DAR EKRAN SURUSU (320 dp x 6 dil) ----
  testWidgets('DAR 320dp: site kurali ekrani 6 dilde TASMAZ', (tester) async {
    await darEkranSurusu(tester, (dil) => _kuralEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('DAR 320dp: sakinler ekrani 6 dilde TASMAZ', (tester) async {
    await darEkranSurusu(tester, (dil) => _sakinEkrani(Locale(dil)),
        veri: surusVerisi);
  });

  // ---- TUR 27: YAZI OLCEGI SURUSU (2.0x x 6 dil) ----
  testWidgets('OLCEK 2x: kural ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _kuralEkrani(Locale(dil)), veri: surusVerisi);
  });
  testWidgets('OLCEK 2x: sakin ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _sakinEkrani(Locale(dil)), veri: surusVerisi);
  });

  // ---- TUR 29: EKRAN OKUYUCU SURUSU ----
  testWidgets('OKUYUCU: kural ekrani (etiket + dokunma hedefi + dil)',
      (tester) async {
    await ekranOkuyucuSurusu(tester, (dil) => _kuralEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('OKUYUCU: sakin ekrani (etiket + dokunma hedefi + dil)',
      (tester) async {
    await ekranOkuyucuSurusu(tester, (dil) => _sakinEkrani(Locale(dil)),
        veri: surusVerisi);
  });

  // ---- TUR 32: KOYU TEMA ----
  testWidgets('KOYU TEMA: kuralEkrani 7 dilde (kontrast + tasma)',
      (tester) async {
    await koyuTemaSurusu(tester, (dil) => _kuralEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('KOYU TEMA: sakinEkrani 7 dilde (kontrast + tasma)',
      (tester) async {
    await koyuTemaSurusu(tester, (dil) => _sakinEkrani(Locale(dil)),
        veri: surusVerisi);
  });

  // ---- TUR 33: KLAVYE ----
  testWidgets('KLAVYE: kuralEkrani (odak sirasi + tuzak + dokunma-yalniz)',
      (tester) async {
    await klavyeSurusu(tester, (dil) => _kuralEkrani(Locale(dil)));
  });
  testWidgets('KLAVYE: sakinEkrani (odak sirasi + tuzak + dokunma-yalniz)',
      (tester) async {
    await klavyeSurusu(tester, (dil) => _sakinEkrani(Locale(dil)));
  });

  // ---- TUR 34: FOTOGRAFLI VERI ----
  testWidgets('FOTOGRAFLI: duyuru ekrani (bes eksen birden)', (tester) async {
    await fotografliSurus(
      tester,
      (dil) => _duyuruEkrani(Locale(dil), fotoUrl: 'https://ornek/duyuru.jpg'),
      veri: surusVerisi,
    );
  });
  testWidgets('FOTOGRAFLI: site kurali DETAYI (bes eksen birden)',
      (tester) async {
    // Kural gorseli LISTEDE degil DETAYDA cizilir (listede yalniz kucuk bir
    // ikon vardir). Bulucu dilden bagimsiz: kuralin BASLIGI sunucu verisi.
    await fotografliSurus(
      tester,
      (dil) => _kuralEkrani(Locale(dil), fotoUrl: 'https://ornek/kural.jpg'),
      veri: surusVerisi,
      hazirla: (t) async {
        await t.tap(find.text('Havuz Saatleri').first);
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
      },
    );
  });

  // ---- TUR 38: FORMLAR VE ALT SAYFALAR ----
  // Tur 36 envanteri: surusler listeyi ciziyor, FORMU ACMIYORDU. Olusturma
  // formlari `FAB -> showModalBottomSheet` deseniyle acilir; `fabAc` bunu
  // dilden bagimsiz yapar.
  testWidgets('FORM: duyuru olusturma alt sayfasi (bes eksen)', (tester) async {
    await tumEksenlerSurusu(tester, (dil) => _duyuruEkrani(Locale(dil)),
        veri: surusVerisi, hazirla: fabAc);
  });
  testWidgets('FORM: site kurali olusturma alt sayfasi (bes eksen)',
      (tester) async {
    await tumEksenlerSurusu(tester, (dil) => _kuralEkrani(Locale(dil)),
        veri: surusVerisi, hazirla: fabAc);
  });
}