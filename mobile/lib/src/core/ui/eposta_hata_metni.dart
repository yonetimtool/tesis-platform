/// (P233 §4) [EpostaHatasi] -> aktif dildeki cümle.
///
/// KİMLİK / METİN AYRIMI (README §15): `eposta.dart` domain katmanıdır,
/// `BuildContext` görmez ve cümle üretemez. Çeviri burada çözülür;
/// `default` dalı YOKTUR — yeni bir hata kimliği eklenince derleyici bu
/// dosyayı gösterir ve çeviriyi zorlar (telefon ikizindeki kural).
library;

import '../i18n/l10n.dart';
import 'eposta.dart';

/// Form doğrulayıcılarının doğrudan verebileceği metin; `null` = geçerli.
String? epostaHataMetni(
  AppLocalizations l10n,
  String ham, {
  bool zorunlu = true,
}) {
  return switch (epostaHatasi(ham, zorunlu: zorunlu)) {
    null => null,
    EpostaHatasi.bos => l10n.epostaHataBos,
    EpostaHatasi.bicim => l10n.epostaHataBicim,
    EpostaHatasi.yerelUzun => l10n.epostaHataYerelUzun,
    EpostaHatasi.cokUzun => l10n.epostaHataCokUzun,
  };
}
