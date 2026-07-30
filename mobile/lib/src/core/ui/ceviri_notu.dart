/// ICERIK CEVIRISI NOTU — makine cevirisi rozeti + "orijinali gör" gecisi.
///
/// Yayin icerigi (duyuru / site kurali / etkinlik) sunucuda YAZMA aninda
/// cevrilir ve `Accept-Language` ile servis edilir. Kullanici okudugu metnin
/// ne oldugunu BILMELIDIR: makine cevirisi mi, yoksa ceviri henuz hazir
/// olmadigi icin orijinal mi.
///
/// Uc hal (bkz. [IcerikCeviri]):
///   * `cevirildiMi` → "otomatik çevrilmiştir" + **orijinali gör** gecisi,
///   * `hazirlaniyor` → "çeviri hazırlanıyor, orijinal gösteriliyor" (gecis
///     YOK: govdede zaten orijinal var),
///   * `hataliCeviri` → "çeviri yapılamadı, orijinal gösteriliyor".
///
/// TASARIM KARARI — nerede gorunur:
///   * TAM metnin gosterildigi yerde (duyuru karti, kural/etkinlik detayi)
///     not + gecis birlikte,
///   * kirpilmis onizlemede (kural/etkinlik LISTE karti) yalniz kucuk bir
///     rozet: uc satirlik kirik metinde "orijinali gör" gurultudur ve
///     kullanici zaten detaya girecektir.
library;

import 'package:flutter/material.dart';

import '../i18n/icerik_ceviri.dart';
import '../i18n/l10n.dart';
import '../theme/home_tokens.dart';

/// Not satiri. [orijinalGoster] ve [onDegistir] YALNIZ makine cevirisi
/// halinde kullanilir; digerlerinde gecis cizilmez.
class CeviriNotu extends StatelessWidget {
  const CeviriNotu({
    super.key,
    required this.ceviri,
    this.orijinalGoster = false,
    this.onDegistir,
  });

  final IcerikCeviri? ceviri;
  final bool orijinalGoster;
  final ValueChanged<bool>? onDegistir;

  @override
  Widget build(BuildContext context) {
    final c = ceviri;
    if (c == null || !c.notVar) return const SizedBox.shrink();
    final l10n = context.l10n;
    final kucuk = Theme.of(context).textTheme.bodySmall;

    // Renk vurgusu ham degil `okunurVurgu`dan gecer (tur 57 dersi): tint
    // zemin + ham renk iki temada da WCAG esigini tutturmuyordu.
    final (ikon, metin, renk) = switch (c) {
      _ when c.hazirlaniyor => (
        Icons.hourglass_empty,
        l10n.ceviriHazirlaniyor,
        Colors.orange,
      ),
      _ when c.hataliCeviri => (
        Icons.translate_outlined,
        l10n.ceviriYapilamadi,
        Colors.orange,
      ),
      _ => (Icons.translate, l10n.ceviriOtomatik, Colors.blue),
    };
    final vurgu = okunurVurgu(context, renk);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 2,
        children: [
          Icon(ikon, size: 14, color: vurgu),
          Text(metin, style: kucuk?.copyWith(color: vurgu)),
          if (c.orijinaleDonulebilir && onDegistir != null)
            // `InkWell` degil `TextButton`: dokunma hedefi 48 dp'yi tutar ve
            // klavye/ekran okuyucu icin kendi `Focus`unu kurar (tur 33).
            TextButton(
              onPressed: () => onDegistir!(!orijinalGoster),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: VisualDensity.standard,
              ),
              child: Text(
                orijinalGoster
                    ? l10n.ceviriCeviriyiGor
                    : l10n.ceviriOrijinaliGor,
              ),
            ),
        ],
      ),
    );
  }
}

/// LISTE KARTI rozeti — gecissiz, tek satir, kirpilmis onizleme icin.
class CeviriRozeti extends StatelessWidget {
  const CeviriRozeti({super.key, required this.ceviri});

  final IcerikCeviri? ceviri;

  @override
  Widget build(BuildContext context) {
    final c = ceviri;
    if (c == null || !c.notVar) return const SizedBox.shrink();
    final l10n = context.l10n;
    final vurgu = okunurVurgu(
      context,
      c.cevirildiMi ? Colors.blue : Colors.orange,
    );
    final metin = c.hazirlaniyor
        ? l10n.ceviriHazirlaniyorKisa
        : c.hataliCeviri
        ? l10n.ceviriYapilamadiKisa
        : l10n.ceviriOtomatikKisa;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.translate, size: 12, color: vurgu),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              metin,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: vurgu),
            ),
          ),
        ],
      ),
    );
  }
}
