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

/// Istemci tarafinda uretilen kod (sozlesmede yok).
const okutmaBeklenmeyenKod = 'client_unexpected';

String okutmaHataMetni(
  AppLocalizations l10n, {
  String? kod,
  String? sunucuMetni,
}) =>
    switch (kod) {
      'invalid_signature' => l10n.okutmaImzaGecersiz,
      'replay_detected' => l10n.okutmaTekrarEdilmis,
      okutmaBeklenmeyenKod =>
        l10n.okutmaBeklenmeyenHata(sunucuMetni ?? '-'),
      _ => sunucuMetni ?? l10n.kuyrukEtiketEslesmedi,
    };
