import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/l10n.dart';

/// (P139.2) DENETCI MOBIL GIRISI — cikisi olan bir ekran.
///
/// ONCEDEN: `home_gate` denetciyi hicbir dala sokmuyor, `role != yonetici`
/// dalina dusuruyor ve KALICI OLARAK SplashScreen ciziyordu. Rol
/// cozulmustu, veri bekleyen bir sey yoktu — ekran hicbir zaman
/// degismiyordu. Kullanicinin gordugu sey "uygulama acilmiyor"du.
///
/// P128/P129 kararinin KENDISI dogruydu ve notta soyle yaziyordu:
/// "Ekran, giris yapan denetciye web adresini soyler (home_gate)."
/// Kod bunu YAPMIYORDU — karar yazilmis, uygulamasi eksik kalmisti.
///
/// Denetimin isi masabasi isidir (rapor okumak, tablo indirmek) ve urun
/// karari `app.*` web yuzeyi yonunde verildi. Mobilde "birkac kart"
/// gostermek, tasarlanmamis bir deneyimi varmis gibi sunmak olurdu. Dogru
/// davranis: NEDENINI soylemek ve adresi vermek.
class DenetciYonlendirmeScreen extends StatelessWidget {
  const DenetciYonlendirmeScreen({super.key});

  /// Tesis yuzeyinin adresi. Sabit metin degil MARKA ADRESIDIR; cevrilmez.
  static const String adres = 'app.yonetiyor.com';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final renk = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.desktop_windows_outlined,
                    size: 56, color: renk.primary),
                const SizedBox(height: 20),
                Text(
                  l10n.denetciWebBaslik,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.denetciWebGovde(adres),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: renk.onSurfaceVariant, height: 1.6),
                ),
                const SizedBox(height: 20),
                // Adres KOPYALANABILIR: telefonda yazmak yerine bilgisayara
                // gonderebilsin. Dokunma hedefi >= 44pt (FilledButton'un
                // varsayilan yuksekligi 48'dir).
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(const ClipboardData(text: adres));
                  },
                  icon: const Icon(Icons.copy_all_outlined),
                  label: Text(l10n.denetciWebKopyala),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
