/// Kuyruk kaydinin hata KODU -> aktif dildeki metin.
///
/// KIMLIK / METIN AYRIMI (README §15): `OutboxEntry` DISKE yazilir, bu yuzden
/// TR cumle degil SOZLESME KODU tasir (bkz. `OutboxEntry.hataKodu`). NTAG424
/// SDM kodlari icin ozel metin; digerlerinde SUNUCU mesaji (zaten
/// yerellestirilmis) gosterilir.
///
/// Eski (tur 11 oncesi) kayitlarda kod null'dir; o zaman sunucu metnine, o da
/// yoksa genel "etiket eslesmedi" metnine duselir.
library;

import '../../../core/i18n/l10n.dart';
import '../domain/okutma_hata_kodu.dart';

String okutmaHataMetni(
  AppLocalizations l10n, {
  String? kod,
  String? sunucuMetni,
}) =>
    switch (kod) {
      'invalid_signature' => l10n.okutmaImzaGecersiz,
      'replay_detected' => l10n.okutmaTekrarEdilmis,
      okutmaAgZamanAsimiKod => l10n.hataZamanAsimi,
      okutmaAgUlasilamadiKod => l10n.hataSunucuyaUlasilamadi,
      okutmaBeklenmeyenKod => l10n.okutmaBeklenmeyenHata(
          (sunucuMetni?.isNotEmpty ?? false) ? sunucuMetni! : '-'),
      // Sunucu metni BOS olabilir (zarf var, mesaj yok) — o da kimlige duser.
      _ => (sunucuMetni?.isNotEmpty ?? false)
          ? sunucuMetni!
          : l10n.kuyrukEtiketEslesmedi,
    };
