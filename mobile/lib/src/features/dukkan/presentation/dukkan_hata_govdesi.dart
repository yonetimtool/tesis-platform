import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../data/dukkan_oturum.dart';
import 'dukkan_telefon_screen.dart';

/// (DUKKAN F7 §2) DUKKAN EKRANLARININ ORTAK HATA GÖVDESİ.
///
/// ===========================================================================
/// NEDEN TEK YERDE
/// ===========================================================================
/// Beş ekran (`taleplerim`, `talep detayı`, `panel`, `bildirimler`,
/// `talep oluştur`) aynı iki hatayı ayırt etmek zorunda: **oturum**
/// hatası ile **ağ/sunucu** hatası. Kullanıcının yapacağı şey farklı, bu
/// yüzden metin de farklı olmalı — ama beş ayrı kopya, ileride birinin
/// eskimesi demekti (F4'te `telefon_gerekli` dalı beş yere elle yazılmıştı
/// ve hepsi kullanıcıyı **web'e** yolluyordu).
///
/// ===========================================================================
/// `telefon_gerekli` ARTIK ÇIKMAZ SOKAK DEĞİL
/// ===========================================================================
/// F4–F6 boyunca bu dal "dukkan.yonetiyor.com'a gidin" diyordu ve
/// ölçülen %27'lik kullanıcı kitlesi orada kayboluyordu. Artık aynı yerde
/// bir **düğme** var: telefonunu uygulama içinde doğrula, akışa geri dön.
class DukkanHataGovdesi extends StatelessWidget {
  const DukkanHataGovdesi({
    required this.hata,
    required this.onYenile,
    super.key,
  });

  final Object hata;

  /// Doğrulama başarılıysa VE tekrar-dene basıldığında çağrılır: çağıran
  /// kendi sağlayıcılarını tazeler. Doğrulamadan sonra tazelemeseydik,
  /// kullanıcı jetonu aldığı hâlde aynı hata ekranında kalırdı.
  final VoidCallback onYenile;

  bool get _telefonGerekli =>
      hata is DukkanOturumHatasi &&
      (hata as DukkanOturumHatasi).kod == 'telefon_gerekli';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _telefonGerekli ? t.dukkanTelefonAciklama : t.dukkanListeAlinamadi,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (_telefonGerekli)
              FilledButton(
                onPressed: () async {
                  final ok = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const DukkanTelefonScreen(),
                    ),
                  );
                  if (ok == true) onYenile();
                },
                child: Text(t.dukkanTelefonDogrula),
              )
            else
              OutlinedButton(
                onPressed: onYenile,
                child: Text(t.dukkanTekrarDene),
              ),
          ],
        ),
      ),
    );
  }
}
