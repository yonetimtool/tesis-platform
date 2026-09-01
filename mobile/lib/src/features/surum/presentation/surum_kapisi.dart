/// (P202) GUNCELLEME KAPISI — zorunlu ekran ve onerilen uyari.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/i18n/l10n.dart';
import '../domain/surum_karari.dart';
import 'surum_denetleyici.dart';

/// Magazayi acar; ACILAMAZSA kullaniciya NE OLDUGUNU soyler.
///
/// SESSIZ BASARISIZLIK YASAK: kullanici "Guncelle"ye basar, hicbir sey
/// olmaz ve uygulamanin dondugunu sanir. Bu ekranda cikis yolu ZATEN tek
/// dugmedir — o dugme sessizce ise yaramazsa kullanici gercekten kapana
/// kisilir.
Future<void> magazayiAc(
  BuildContext context,
  String? url,
) async {
  final l10n = AppLocalizations.of(context);
  var acildi = false;
  if (url != null && url.isNotEmpty) {
    try {
      acildi = await launchUrl(
        Uri.parse(url),
        // Magaza uygulamasi varsa O acilir; yoksa tarayici devralir.
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      acildi = false;
    }
  }
  if (acildi || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(l10n.surumMagazaAcilamadi),
      duration: const Duration(seconds: 6),
    ),
  );
}

/// ZORUNLU EKRAN — ATLANAMAZ.
///
/// ===========================================================================
/// ATLAMA YOLLARI TEK TEK KAPATILDI
/// ===========================================================================
///  * `PopScope(canPop: false)` — geri dugmesi ve kaydirarak kapatma
///    (iOS kenar jesti) ISLEMEZ.
///  * `AppBar` YOK — geri oku cizilmez.
///  * Kapi UYGULAMANIN KOKUNDE durur (`MaterialApp.builder`), bir rota
///    olarak DEGIL: rota olsaydi derin baglanti, bildirime tiklama ya da
///    yonlendirme onu ustunden ATLAYABILIRDI.
///  * Arka plandan geri gelindiginde denetim YENIDEN kosar
///    (`SurumGozcusu`), yani ekran kendini yeniden kurar.
class ZorunluGuncellemeEkrani extends StatelessWidget {
  const ZorunluGuncellemeEkrani({required this.karar, super.key});

  final SurumKarari karar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.system_update, size: 56,
                      color: tema.colorScheme.primary),
                  const SizedBox(height: 20),
                  Text(
                    l10n.surumZorunluBaslik,
                    key: const Key('surum-zorunlu-baslik'),
                    style: tema.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    // Operator metni VARSA o gosterilir; yoksa
                    // uygulamanin kendi yerellestirilmis metni.
                    karar.mesaj ?? l10n.surumZorunluMetin,
                    style: tema.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('surum-guncelle'),
                      onPressed: () => magazayiAc(context, karar.magazaUrl),
                      child: Text(l10n.surumGuncelle),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ONERILEN UYARISI — kapatilabilir.
class OnerilenGuncellemeKarti extends ConsumerWidget {
  const OnerilenGuncellemeKarti({required this.karar, super.key});

  final SurumKarari karar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    return Material(
      color: tema.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.surumOnerilenBaslik,
                      key: const Key('surum-onerilen-baslik'),
                      style: tema.textTheme.titleSmall,
                    ),
                    Text(
                      karar.mesaj ?? l10n.surumOnerilenMetin,
                      style: tema.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('surum-sonra'),
                onPressed: () =>
                    ref.read(surumDenetleyiciProvider.notifier).sonra(),
                child: Text(l10n.surumSonra),
              ),
              FilledButton(
                key: const Key('surum-simdi-guncelle'),
                onPressed: () => magazayiAc(context, karar.magazaUrl),
                child: Text(l10n.surumSimdiGuncelle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Uygulamanin KOKUNE takilan kapi.
///
/// ZORUNLU durumda alttaki agac HIC CIZILMEZ — gizlenmez, CIZILMEZ.
/// Gizlemek (`Offstage`/`Visibility`) yeterli olmazdi: alttaki ekranlar
/// yasamaya, ag istegi atmaya ve odak almaya devam ederdi.
class SurumKapisi extends ConsumerWidget {
  const SurumKapisi({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final durum = ref.watch(surumDenetleyiciProvider);
    if (durum.zorunlu) {
      return ZorunluGuncellemeEkrani(karar: durum.karar);
    }
    if (!durum.onerilenGosterilsin) return child;
    return Column(
      children: [
        OnerilenGuncellemeKarti(karar: durum.karar),
        Expanded(child: child),
      ],
    );
  }
}
