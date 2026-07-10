import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/site_kurali/domain/site_kurali_models.dart';

void main() {
  group('SiteKurali.fromJson', () {
    test('tam kayit (fotolu) parse edilir', () {
      final k = SiteKurali.fromJson(const {
        'id': 'k-1',
        'baslik': 'Havuz Saatleri',
        'icerik': 'Havuz 08:00-22:00 arasi aciktir.',
        'foto_key': 'tenant/uploads/havuz.jpg',
        'foto_url': 'https://minio/havuz.jpg?X-Amz-Signature=abc',
        'sira': 2,
        'olusturan_user_id': 'yon-1',
        'olusturan_ad': 'Acme Yonetici',
        'created_at': '2026-07-10T09:00:00Z',
        'updated_at': '2026-07-10T09:00:00Z',
      });
      expect(k.id, 'k-1');
      expect(k.baslik, 'Havuz Saatleri');
      expect(k.icerik, contains('08:00-22:00'));
      expect(k.fotoKey, 'tenant/uploads/havuz.jpg');
      expect(k.fotoUrl, contains('X-Amz-Signature'));
      expect(k.sira, 2);
      expect(k.olusturanAd, 'Acme Yonetici');
    });

    test('fotosuz kayit: opsiyonel alanlar null, sira varsayilan 0', () {
      final k = SiteKurali.fromJson(const {
        'id': 'k-2',
        'baslik': 'Otopark',
        'icerik': 'x',
        'olusturan_user_id': 'yon-1',
        'created_at': '2026-07-10T09:00:00Z',
        'updated_at': '2026-07-10T09:00:00Z',
      });
      expect(k.fotoKey, isNull);
      expect(k.fotoUrl, isNull);
      expect(k.sira, 0);
    });

    test('eksik/bozuk alanlarda COKMEZ (savunmaci parse)', () {
      final k = SiteKurali.fromJson(const {});
      expect(k.id, '');
      expect(k.baslik, '');
      expect(k.sira, 0);
    });
  });

  group('baslikEslesir (arama cubugu suzgeci — ILIKE ile ayni anlam)', () {
    final k = SiteKurali(
      id: 'k-1',
      baslik: 'Havuz Saatleri',
      icerik: 'x',
      sira: 1,
      olusturanUserId: 'u',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );

    test('buyuk/kucuk harf duyarsiz icerme', () {
      expect(k.baslikEslesir('hAvUz'), isTrue);
      expect(k.baslikEslesir('SAAT'), isTrue);
      expect(k.baslikEslesir('Havuz Saatleri'), isTrue);
    });

    test('eslesmeyen sorgu false; icerik metni ARANMAZ (baslik aramasi)', () {
      expect(k.baslikEslesir('otopark'), isFalse);
      expect(k.baslikEslesir('x'), isFalse); // icerikte var, baslikta yok
    });
  });

  group('SiteKuraliDraft.toJson', () {
    test('foto_key dolu ise yazilir', () {
      expect(
        const SiteKuraliDraft(
          baslik: 'Havuz',
          icerik: 'Metin',
          sira: 3,
          fotoKey: 't/uploads/p.jpg',
        ).toJson(),
        {
          'baslik': 'Havuz',
          'icerik': 'Metin',
          'sira': 3,
          'foto_key': 't/uploads/p.jpg',
        },
      );
    });

    test('foto_key yoksa alan HIC yazilmaz (PATCH: dokunulmaz)', () {
      expect(
        const SiteKuraliDraft(baslik: 'x', icerik: 'y', sira: 0).toJson(),
        {'baslik': 'x', 'icerik': 'y', 'sira': 0},
      );
    });

    test('fotoKeyKaldir=true acik null yazar (gorsel kaldirma sozlesmesi)',
        () {
      final json = const SiteKuraliDraft(
        baslik: 'x',
        icerik: 'y',
        sira: 0,
        fotoKeyKaldir: true,
      ).toJson();
      expect(json.containsKey('foto_key'), isTrue);
      expect(json['foto_key'], isNull);
    });
  });
}
