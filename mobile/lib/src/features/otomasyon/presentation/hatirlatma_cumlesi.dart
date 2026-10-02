/// (P250 §7/§9) Hatırlatma ayarının DÜZ CÜMLESİ — web `hatirlatmaCumlesi`
/// ikizi. Gerçek kademelerden kurulur (eski düzensiz {3,10,30} de doğru
/// söylenir).
library;

import '../../../../l10n/gen/app_localizations.dart';
import '../data/hatirlatma_api.dart';

String hatirlatmaCumlesi(AppLocalizations l10n, HatirlatmaAyari a) {
  if (!a.aktif || a.kademeler.isEmpty) return l10n.otoHatirlatmaKapali;
  final gunler = a.kademeler.join(', ');
  final kanal = a.eposta ? l10n.otoKanalBildirimEposta : l10n.otoKanalBildirim;
  final ana = l10n.otoHatirlatmaCumle(gunler, kanal);
  return a.vadeOncesiGun > 0
      ? '$ana ${l10n.otoHatirlatmaVadeOncesiCumle('${a.vadeOncesiGun}')}'
      : ana;
}
