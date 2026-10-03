import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/l10n.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../home/domain/home_menu.dart';
import '../../home/presentation/denetci_yonlendirme_screen.dart';

/// Yalniz web'de kalan bir islem: web rotasi + adi + gruplandigi bolum.
class WebIslemi {
  const WebIslemi(this.webRota, this.grup, this.ad);
  final String webRota;
  final HomeMenuGrup grup;
  final String Function(AppLocalizations) ad;
}

/// (P251 §8) YALNIZ WEB'DE KALAN ISLEMLER — `contracts/menu-paritesi.tsv`
/// tablosundaki `yalniz_web` satirlarinin TAMAMI. Kilit
/// (`p251_menu_paritesi_test.dart`) iki listenin ayni oldugunu olcer:
/// web'e yeni bir yalniz-web sayfa eklenirse burada da gorunmek ZORUNDA —
/// mobil kullanici "telefonda yok" ile "hic yok" arasindaki farki gorsun.
///
/// Gerekceler tabloda (her satirda yazili); burada tekrarlanmaz.
final List<WebIslemi> webIslemleri = [
  WebIslemi('/dues', HomeMenuGrup.finans, (l) => l.webAidat),
  WebIslemi('/finans/borclandirmalar', HomeMenuGrup.finans, (l) => l.webBorclandirmalar),
  WebIslemi('/finans/virman', HomeMenuGrup.finans, (l) => l.webVirman),
  WebIslemi('/finans/iade', HomeMenuGrup.finans, (l) => l.webIade),
  WebIslemi('/finans/acilis', HomeMenuGrup.finans, (l) => l.webAcilis),
  WebIslemi('/finans/banka', HomeMenuGrup.finans, (l) => l.webBanka),
  WebIslemi('/finans/mesai', HomeMenuGrup.finans, (l) => l.webMesai),
  WebIslemi('/finans/maas-kartlari', HomeMenuGrup.finans, (l) => l.webMaasKartlari),
  WebIslemi('/icra', HomeMenuGrup.finans, (l) => l.webIcra),
  WebIslemi('/assets', HomeMenuGrup.tesis, (l) => l.webDemirbas),
  WebIslemi('/mesajlar', HomeMenuGrup.iletisim, (l) => l.webMesajlar),
  WebIslemi('/ice-aktarim', HomeMenuGrup.tanimlar, (l) => l.webIceAktarim),
  WebIslemi('/karar-defteri', HomeMenuGrup.yonetim, (l) => l.webKararDefteri),
];

/// (P251 §8) "Bilgisayardan yapilanlar" — onayli ilke 2: yalniz bir
/// yuzeyde kalan islem obur yuzeyde GORUNUR kalir ve nereden yapilacagini
/// soyler. Bolumlere gore gruplu; adres kopyalanabilir (denetci
/// yonlendirme ekraniyla ayni desen — tarayici acmak yerine adres).
class BilgisayardanScreen extends StatelessWidget {
  const BilgisayardanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const adres = DenetciYonlendirmeScreen.adres;
    return Scaffold(
      appBar: AppBar(title: Text(baslikBuyuk(l10n.modulBilgisayardan, context.dilKodu))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(l10n.bilgisayardanAciklama(adres),
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const Key('bilgisayardan-kopyala'),
              onPressed: () async {
                await Clipboard.setData(const ClipboardData(text: adres));
              },
              icon: const Icon(Icons.copy_all_outlined),
              label: Text(l10n.denetciWebKopyala),
            ),
          ),
          for (final g in HomeMenuGrup.values)
            if (webIslemleri.any((w) => w.grup == g)) ...[
              const SizedBox(height: 16),
              Text(homeMenuGrupBasligi(l10n, g),
                  style: Theme.of(context).textTheme.titleSmall),
              for (final w in webIslemleri.where((w) => w.grup == g))
                ListTile(
                  key: Key('webde-${w.webRota}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.desktop_windows_outlined),
                  title: Text(w.ad(l10n)),
                ),
            ],
        ],
      ),
    );
  }
}
