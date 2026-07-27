/// [NfcHatasi] -> aktif dildeki metin + [NfcIosMetinleri] uretici.
///
/// `default` dali YOK: yeni kimlik eklenince derleyici ceviriyi zorlar.
library;

import '../../../core/i18n/l10n.dart';
import '../domain/nfc_hatasi.dart';

/// [detay] yalniz platform mesaji tasiyan kimliklerde kullanilir; bos
/// gelirse teknik parca atlanmaz (sozlesme sabit kalsin diye '-' yazilir).
String nfcHataMetni(AppLocalizations l10n, NfcHatasi hata, {String? detay}) {
  final d = (detay == null || detay.isEmpty) ? '-' : detay;
  return switch (hata) {
    NfcHatasi.kapali => l10n.nfcHataKapali,
    NfcHatasi.desteklenmiyor => l10n.nfcHataDesteklenmiyor,
    NfcHatasi.uidOkunamadi => l10n.nfcHataUidOkunamadi,
    NfcHatasi.cozumlenemedi => l10n.nfcHataCozumlenemedi(d),
    NfcHatasi.oturumBaslatilamadi => l10n.nfcHataOturum(d),
    NfcHatasi.okumaIptal => l10n.nfcHataOkumaIptal(d),
    NfcHatasi.bilinmeyen => l10n.nfcHataBilinmeyen,
  };
}

/// iOS sistem sayfasinin metinleri — CIZIM katmaninda uretilir, servise
/// parametre olarak gecer (bkz. `nfc_hatasi.dart` basligi).
NfcIosMetinleri nfcIosMetinleri(AppLocalizations l10n) => NfcIosMetinleri(
      yaklastir: l10n.nfcIosYaklastir,
      okundu: l10n.nfcIosOkundu,
      okunamadi: l10n.nfcIosOkunamadi,
      iptal: l10n.nfcIosIptal,
    );
