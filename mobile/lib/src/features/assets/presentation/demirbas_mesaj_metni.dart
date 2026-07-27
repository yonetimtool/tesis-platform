/// [DemirbasMesaj] -> aktif dildeki metin (bkz. gorev_hata_metni emsali).
///
/// `default` dali YOK: yeni bir kimlik/varyant eklenirse derleyici ceviriyi
/// zorlar.
library;

import '../../../core/i18n/l10n.dart';
import '../../nfc/presentation/nfc_hata_metni.dart';
import '../domain/demirbas_mesaj.dart';

String demirbasMesajMetni(AppLocalizations l10n, DemirbasMesaj mesaj) =>
    switch (mesaj) {
      DemirbasKimlikMesaji(kimlik: final k) => switch (k) {
          DemirbasMesajKimlik.beklenmeyen => l10n.ortakBeklenmeyenHata,
          DemirbasMesajKimlik.offline => l10n.demOfflineUyari,
          DemirbasMesajKimlik.etiketOkunamadi => l10n.gorevEtiketOkunamadi,
          DemirbasMesajKimlik.listeYetkiYok => l10n.demListeYetkiYok,
          DemirbasMesajKimlik.zatenZimmetinde => l10n.demZatenZimmetinde,
          DemirbasMesajKimlik.zimmetineAlindi => l10n.demZimmetineAlindi,
          DemirbasMesajKimlik.birakildi => l10n.demBirakildi,
        },
      DemirbasEtiketEslesmiyor(uid: final uid) => l10n.demEtiketEslesmiyor(uid),
      DemirbasCakismaMesaji(sunucuMetni: final m) => l10n.demIslemYapilamadi(m),
      DemirbasAdliHata(ad: final ad, sunucuMetni: final m) =>
        l10n.demHataSatiri(ad, m),
      DemirbasNfcHatasi(kimlik: final k, detay: final d) =>
        nfcHataMetni(l10n, k, detay: d),
      DemirbasSunucuMetni(metin: final m) => m,
    };

/// Mesaj varsa coz, yoksa null (kosullu cizim icin).
String? demirbasMesajCoz(AppLocalizations l10n, DemirbasMesaj? mesaj) =>
    mesaj == null ? null : demirbasMesajMetni(l10n, mesaj);
