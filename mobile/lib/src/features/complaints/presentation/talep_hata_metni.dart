/// Talep akisi hata KIMLIGI -> aktif dildeki metin.
///
/// `default` dali YOKTUR: yeni kimlik eklenince derleyici ceviriyi zorlar.
/// [ek] yalnizca ayrinti tasiyan kimlikte (foto secim hatasi) kullanilir.
library;

import '../../../core/i18n/l10n.dart';
import '../domain/talep_hata.dart';

String talepHataMetni(
  AppLocalizations l10n,
  TalepAkisHatasi hata, [
  String? ek,
]) =>
    switch (hata) {
      TalepAkisHatasi.kategorilerYuklenemedi => l10n.talepKategorilerYuklenemedi,
      // Foto akisi gorev tamamlama ile AYNI metinleri paylasir (tek sozluk).
      TalepAkisHatasi.fotoAlinamadi => l10n.gorevFotoAlinamadi(ek ?? ''),
      TalepAkisHatasi.fotoOnlineGerekli => l10n.gorevFotoOnlineGerekli,
      TalepAkisHatasi.fotoYuklenemedi => l10n.talepFotoYuklenemedi,
    };

/// Kimlik ONCE, yoksa SUNUCU metni, o da yoksa null.
String? talepHatasiCoz(
  AppLocalizations l10n,
  TalepAkisHatasi? kimlik,
  String? sunucuMetni,
) =>
    kimlik != null
        ? talepHataMetni(l10n, kimlik, sunucuMetni)
        : sunucuMetni;
