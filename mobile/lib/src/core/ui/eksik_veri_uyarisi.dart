/// (P59) IKINCIL ARAMA DUSTUGUNDE gorunen uyari.
///
/// Form seciciler ayri bir istekle dolar (kontrol noktalari, kategoriler).
/// O istek dustugunde `AsyncValue.value` null olur ve ekranlar `?? const []`
/// ile BOS LISTEYE duserdi: kullanici acilir listeyi bos gorur, "kayit yok"
/// sanar ve isini yapamadigini ANLAMAZ. Panelde ayni sinif P58'de kapandi.
///
/// HATA KUTUSU DEGIL: islem basarisiz olmadi, eksik yuklendi. Bu yuzden
/// sari/yumusak gorunum — kirmizi bir hata kutusu olayi oldugundan agir
/// gosterirdi.
library;

import 'package:flutter/material.dart';

import '../i18n/l10n.dart';

class EksikVeriUyarisi extends StatelessWidget {
  const EksikVeriUyarisi({super.key, required this.goster});

  final bool goster;

  @override
  Widget build(BuildContext context) {
    if (!goster) return const SizedBox.shrink();
    final renk = Theme.of(context).brightness == Brightness.dark
        ? Colors.amber.shade200
        : Colors.amber.shade900;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: renk),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              context.l10n.ortakSecenekYuklenemedi,
              style: TextStyle(fontSize: 12, color: renk),
            ),
          ),
        ],
      ),
    );
  }
}
