/// P113 — YAPAY ZEKÂ / OTOMATİK ÇEVİRİ ŞEFFAFLIĞI KİLİDİ.
///
/// Bu, App Store denetiminde anlattığımız hikâyenin kod tarafındaki
/// dayanağıdır: uygulamada **üretken yapay zekâ yok**; tek otomatik işlem
/// makine çevirisi ve **çevrilen her içerik bunu söylüyor**.
///
/// İkinci cümle bir İDDİADIR ve çürütülebilir olmalı. Bu dosya onu üç
/// ayrı ölçümle bağlar:
///   1. KAYNAK TARAMASI — `ceviriMetni(` çağıran her ekran, aynı dosyada
///      `CeviriNotu` ya da `CeviriRozeti` de çizmeli. Yeni bir ekran
///      çevrilmiş metin göstermeye başlayıp göstergeyi unutursa DÜŞER.
///   2. DAVRANIŞ — gösterge çevrilmiş içerikte GÖRÜNÜR, çevrilmemişte
///      görünmez (her karta "otomatik çeviri" yazmak da yanlış olurdu).
///   3. GERİ DÖNÜŞ — "orijinali gör" gerçekten ORİJİNAL metni gösterir.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/icerik_ceviri.dart';
import 'package:mobile/src/core/ui/ceviri_notu.dart';

import 'helpers/l10n_test_app.dart';

/// Çeviri gösteren ekranların bulunduğu kaynak ağacı.
const _kaynak = 'lib/src';

void main() {
  test('KAYNAK: cevrilmis metin gosteren her ekran GOSTERGEYI de cizer', () {
    final eksikler = <String>[];
    for (final e in Directory(_kaynak).listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      // YORUMLAR ATILIR — SATIR SONUNDAKILER DE. Ilk yazimda hic
      // atilmiyordu; mutasyon denetimi yakaladi: `CeviriNotu(` cagrisini
      // yoruma almak tarama acisindan hicbir sey degistirmiyordu, yani
      // kilit cizimi degil "dosyada bu harfler geciyor mu"yu olcuyordu.
      // Ikinci yazimda yalniz SATIR BASI yorumlari atildi — bu da yetmedi
      // (`const SizedBox(), // CeviriNotu(` hala sayiliyordu). Panelin
      // tarayicilariyla ayni kural: `split('//').first`.
      final govde = e
          .readAsStringSync()
          .split('\n')
          .map((l) => l.split('//').first)
          .join('\n');
      // Ceviri YARDIMCISININ KENDISI haric: orada cagri var, cizim yok.
      if (e.path.endsWith('icerik_ceviri.dart')) continue;
      if (!govde.contains('ceviriMetni(')) continue;
      final gosterge =
          govde.contains('CeviriNotu(') || govde.contains('CeviriRozeti(');
      if (!gosterge) eksikler.add(e.path);
    }
    expect(
      eksikler,
      isEmpty,
      reason:
          'Cevrilmis metin gosterip "otomatik cevrilmistir" gostergesini '
          'CIZMEYEN ekran(lar): ${eksikler.join(", ")}. Bu, App Store '
          'denetim notlarindaki seffaflik beyanini gecersiz kilar.',
    );
  });

  testWidgets('GOSTERGE: cevrilmis icerikte GORUNUR', (tester) async {
    const ceviri = IcerikCeviri(
      orijinalDil: 'tr',
      gosterilenDil: 'en',
      durum: CeviriDurumu.hazir,
      cevirildiMi: true,
      orijinal: {'baslik': 'Havuz saatleri'},
    );
    await tester.pumpWidget(
      l10nApp(
        Scaffold(
          body: CeviriNotu(
            ceviri: ceviri,
            orijinalGoster: false,
            onDegistir: (_) {},
          ),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('automatically'), findsOneWidget);
    expect(find.text('View original'), findsOneWidget);
  });

  testWidgets('GOSTERGE: cevrilmemis icerikte GORUNMEZ', (tester) async {
    // Her karta "otomatik ceviri" yazmak, cevrilmemis icerigi de suphe
    // altinda birakmak olurdu — gosterge ancak AYIRT ETTIGI zaman bilgi.
    await tester.pumpWidget(
      l10nApp(
        const Scaffold(
          body: CeviriNotu(ceviri: null, orijinalGoster: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextButton), findsNothing);
  });

  test('GERI DONUS: "orijinali gor" gercekten ORIJINALI verir', () {
    const ceviri = IcerikCeviri(
      orijinalDil: 'tr',
      gosterilenDil: 'en',
      durum: CeviriDurumu.hazir,
      cevirildiMi: true,
      orijinal: {'baslik': 'Havuz saatleri'},
    );
    // Ceviri gosterimi: govdedeki metin (zaten cevrilmis olarak gelir).
    expect(
      ceviriMetni(ceviri, 'baslik', 'Pool hours', orijinalGoster: false),
      'Pool hours',
    );
    // ORIJINALE donus — baglayici metin budur (gizlilik politikasi §5).
    expect(
      ceviriMetni(ceviri, 'baslik', 'Pool hours', orijinalGoster: true),
      'Havuz saatleri',
    );
  });
}
