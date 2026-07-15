import 'package:flutter/material.dart';

/// Gorev tipinin (yonetici-tanimli KATEGORI) liste/detayda ortak gorunumu.
/// Sabit tip enum'u kaldirildi; renk kategori ADINDAN deterministik turer
/// (ayni kategori hep ayni renk). null/bos ad -> "Diğer" (notr).
({Color color, IconData icon, String label}) taskKategoriStyle(String? kategoriAd) {
  final ad = (kategoriAd == null || kategoriAd.isEmpty) ? 'Diğer' : kategoriAd;
  if (ad == 'Diğer') {
    return (
      color: Colors.blueGrey,
      icon: Icons.task_alt_outlined,
      label: 'Diğer',
    );
  }
  final hue = (ad.hashCode & 0x7fffffff) % 360;
  return (
    color: HSLColor.fromAHSL(1, hue.toDouble(), 0.5, 0.45).toColor(),
    icon: Icons.label_outline,
    label: ad,
  );
}
