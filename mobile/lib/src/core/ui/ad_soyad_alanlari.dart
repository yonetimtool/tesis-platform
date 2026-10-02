/// (P250 §1) AD + SOYAD — iki ayrı, ikisi de zorunlu alan.
///
/// Kayıt, davet, personel, sakin ve profil ekranları BU bileşeni kullanır;
/// kural tek yerde (`core/kisi_adi.dart`). Yazarken biçimlenir (ad kelime
/// başı büyük, soyad tamamı büyük, Türkçe harf kuralıyla); gönderirken
/// çağıran `adBicimle`/`soyadBicimle` ile son biçimi (kırpma + tek boşluk)
/// uygular. Sunucu da aynı kuralı uygular.
library;

import 'package:flutter/material.dart';

import '../girdi_siniri.dart';
import '../i18n/l10n.dart';
import '../kisi_adi.dart';

class AdSoyadAlanlari extends StatelessWidget {
  const AdSoyadAlanlari({
    super.key,
    required this.adKtrl,
    required this.soyadKtrl,
    this.etkin = true,
    this.adSinir = 150,
    this.anahtarOneki = 'kisi',
  });

  final TextEditingController adKtrl;
  final TextEditingController soyadKtrl;
  final bool etkin;

  /// Sunucudaki `ad` sınırı — uca göre 120/150.
  final int adSinir;

  /// Widget anahtarları: `<onek>-ad`, `<onek>-soyad`.
  final String anahtarOneki;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String? zorunlu(String? v) =>
        (v == null || v.trim().isEmpty) ? l10n.kisiAdZorunlu : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: Key('$anahtarOneki-ad'),
          controller: adKtrl,
          enabled: etkin,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.givenName],
          inputFormatters: [
            ...GirdiSiniri.sinir(adSinir),
            const AdBicimlendirici(),
          ],
          validator: zorunlu,
          decoration: InputDecoration(
            labelText: l10n.kisiAd,
            prefixIcon: const Icon(Icons.badge_outlined),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: Key('$anahtarOneki-soyad'),
          controller: soyadKtrl,
          enabled: etkin,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.familyName],
          inputFormatters: [
            // sunucu: AdSoyadGirdisi.soyad (_G.AD)
            ...GirdiSiniri.sinir(GirdiSiniri.ad),
            const SoyadBicimlendirici(),
          ],
          validator: zorunlu,
          decoration: InputDecoration(
            labelText: l10n.kisiSoyad,
            prefixIcon: const Icon(Icons.badge_outlined),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
