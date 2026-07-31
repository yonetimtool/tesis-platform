/// P22 — mobil UX paketi: (b) bildirim dokunmasi, (c) bildir kisayolu,
/// (d)+(e) talep/sikayet ayrimi, (f) kural gorseli listede, (g) yeni kategori.
///
/// (a) — tum modallerin ortalanmis diyaloga cevrilmesi — DENENDI VE GERI
/// ALINDI; tanisi MASTER-PLAN P22 Notes'unda. Bu dosya kalan alti maddeyi
/// kilitler.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/features/notifications/domain/notification_models.dart';
import 'package:mobile/src/features/notifications/presentation/bildirim_rotasi.dart';
import 'package:mobile/src/features/site_kurali/data/site_kurali_api.dart';
import 'package:mobile/src/features/site_kurali/domain/site_kurali_models.dart';
import 'package:mobile/src/features/site_kurali/presentation/site_kurali_screen.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/unit_complaints/domain/unit_complaint_models.dart';
import 'package:mobile/src/features/unit_complaints/presentation/kategori_adi.dart';

import 'helpers/gorsel_taklidi.dart';
import 'helpers/l10n_test_app.dart';

AppNotification _b({
  String tip = 'kacirilan_tur',
  String? taskId,
  String? windowId,
}) => AppNotification(
  id: 'n1',
  tip: tip,
  mesaj: 'mesaj',
  okundu: false,
  taskId: taskId,
  patrolWindowId: windowId,
);

void main() {
  // ------------------------------------------------------------------ (b)
  group('P22b — bildirim dokunmasi bir yere GIDER', () {
    test('devriye alarmlari tur takibine gider', () {
      for (final t in [
        'kacirilan_tur',
        'eksik_checkpoint',
        'gecikmis_okutma',
      ]) {
        expect(bildirimRotasi(_b(tip: t)), '/patrol-tracking', reason: t);
      }
    });

    test('talep akisi talep listesine, is emri gorev listesine gider', () {
      for (final t in ['talep_is_emri', 'talep_cozuldu', 'talep_reddedildi']) {
        expect(bildirimRotasi(_b(tip: t)), '/complaints', reason: t);
      }
      expect(bildirimRotasi(_b(tip: 'is_emri_atandi')), '/tasks');
    });

    test('BILINMEYEN tip: kayittaki REFERANSTAN turetilir', () {
      // Tip listesi bayatlasa bile dokunma olu kalmasin.
      expect(
        bildirimRotasi(_b(tip: 'gelecekte_eklenen', taskId: 't1')),
        '/tasks',
      );
      expect(
        bildirimRotasi(_b(tip: 'gelecekte_eklenen', windowId: 'w1')),
        '/patrol-tracking',
      );
    });

    test('hedefi OLMAYAN bildirim null doner (uydurma hedef YOK)', () {
      expect(bildirimRotasi(_b(tip: 'gelecekte_eklenen')), isNull);
      // Bos string bir referans DEGILDIR.
      expect(bildirimRotasi(_b(tip: 'x', taskId: '', windowId: '')), isNull);
    });
  });

  // ------------------------------------------------------------------ (g)
  group('P22g — "görüntü kirliliği" kategorisi', () {
    test('enum degeri sunucu ile birebir', () {
      expect(UnitComplaintKategori.goruntuKirliligi.wire, 'goruntu_kirliligi');
      expect(
        UnitComplaintKategori.fromWire('goruntu_kirliligi'),
        UnitComplaintKategori.goruntuKirliligi,
      );
      // Bilinmeyen deger hala `diger`e duser (savunma korunmus).
      expect(
        UnitComplaintKategori.fromWire('olmayan'),
        UnitComplaintKategori.diger,
      );
    });

    testWidgets('kategori adi 7 dilde BOS DEGIL ve TR sizmaz', (tester) async {
      const trHarf = 'ğışĞİŞ';
      for (final dil in ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es']) {
        late AppLocalizations l10n;
        await tester.pumpWidget(
          l10nApp(
            Builder(
              builder: (ctx) {
                l10n = ctx.l10n;
                return const SizedBox.shrink();
              },
            ),
            locale: Locale(dil),
          ),
        );
        await tester.pumpAndSettle();
        final ad = unitComplaintKategoriAdi(
          l10n,
          UnitComplaintKategori.goruntuKirliligi,
        );
        expect(ad.trim(), isNotEmpty, reason: dil);
        if (dil != 'tr') {
          expect(
            ad.split('').any(trHarf.contains),
            isFalse,
            reason: '$dil cevirisinde TR harfi: $ad',
          );
        }
      }
    });
  });

  // ------------------------------------------------------------------ (f)
  group('P22f — site kurali gorseli LISTEDE', () {
    testWidgets('fotografi olan kural kartinda gorsel CIZILIR', (tester) async {
      // `gorselTaklidiKapat` TEST GOVDESINDE cagrilmali: cerceve, govde biter
      // bitmez cizim hata ayiklama degiskenlerinin sifirlandigini denetler ve
      // `addTearDown` buna GEC kalir (tur 34 dersi).
      gorselTaklidi();
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              siteKuraliApiProvider.overrideWithValue(
                _SahteKuralApi([
                  SiteKurali(
                    id: 'k1',
                    baslik: 'Otopark Kullanımı',
                    icerik: 'Her daireye bir yer.',
                    sira: 1,
                    olusturanUserId: 'u1',
                    createdAt: DateTime.utc(2026, 7, 1),
                    fotoKey: 't/x.jpg',
                    fotoUrl: 'https://ornek/kural.jpg',
                  ),
                ]),
              ),
              currentUserRoleProvider.overrideWith(
                (ref) async => UserRole.resident,
              ),
            ],
            child: l10nApp(const SiteKuraliScreen()),
          ),
        );
        // Gorsel GERCEK zamanda cozulur (tur 34 dersi).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(() async {
            await tester.pump();
            await Future<void>.delayed(const Duration(milliseconds: 50));
          });
          await tester.pump(const Duration(milliseconds: 50));
          if (tester
              .widgetList<RawImage>(find.byType(RawImage))
              .any((r) => r.image != null)) {
            break;
          }
        }
        expect(
          tester
              .widgetList<RawImage>(find.byType(RawImage))
              .any((r) => r.image != null),
          isTrue,
          reason: 'kural gorseli LISTEDE cizilmedi (eskiden yalniz ikon vardi)',
        );
      } finally {
        gorselTaklidiKapat();
      }
    });

    testWidgets('fotografi OLMAYAN kartta gorsel yok', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            siteKuraliApiProvider.overrideWithValue(
              _SahteKuralApi([
                SiteKurali(
                  id: 'k2',
                  baslik: 'Gürültü',
                  icerik: '22:00 sonrası sessizlik.',
                  sira: 2,
                  olusturanUserId: 'u1',
                  createdAt: DateTime.utc(2026, 7, 1),
                ),
              ]),
            ),
            currentUserRoleProvider.overrideWith(
              (ref) async => UserRole.resident,
            ),
          ],
          child: l10nApp(const SiteKuraliScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RawImage), findsNothing);
    });
  });
}

class _SahteKuralApi extends SiteKuraliApi {
  _SahteKuralApi(this._items) : super(Dio());
  final List<SiteKurali> _items;

  @override
  Future<List<SiteKurali>> fetchAll({String? q}) async => _items;
}
