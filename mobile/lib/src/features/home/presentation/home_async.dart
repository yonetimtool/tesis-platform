/// [AsyncValue] → ana ekran gorunumu, Riverpod'un OTOMATIK YENIDEN DENEME
/// davranisina dayanikli.
///
/// Neden ayri bir yardimci: bir saglayici hata verdiginde Riverpod hatayi
/// tasiyan yeni bir `AsyncLoading` uretir (arka planda yeniden dener). Bu
/// yuzden duz `when(...)` hata dalini CALISTIRMAZ ve ekran sonsuza kadar
/// iskelet gosterir. Burada sira bilincli olarak **veri → hata → yukleme**
/// seklindedir: ilk basarisizlikta kullanici "Yüklenemedi"yi gorur, yeniden
/// deneme basarili olunca gorunum kendiliginden veriye doner.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

extension HomeAsyncDurum<T> on AsyncValue<T> {
  R durum<R>({
    required R Function(T veri) veri,
    required R Function() yukleniyor,
    required R Function() hata,
  }) {
    if (hasValue) return veri(value as T);
    if (hasError) return hata();
    return yukleniyor();
  }

  /// Sayac/deger metni: veri → bicimlendirilmis, hata → '—', yukleniyor →
  /// null (cagiran iskelet cizer). UYDURMA DEGER URETMEZ.
  String? metin(String Function(T veri) bicim) => durum(
        veri: bicim,
        yukleniyor: () => null,
        hata: () => '—',
      );

  /// "N Etiket" bicimli sayac ([metin] ile ayni yukleniyor/hata sozlesmesi).
  String? sayac(int Function(T veri) sayi, String etiket) =>
      metin((v) => '${sayi(v)} $etiket');
}
