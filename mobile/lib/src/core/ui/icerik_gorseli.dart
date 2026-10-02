/// (P251 §5c) ORTAK ICERIK GORSELI — duyuru, etkinlik, rezervasyon alani.
///
/// Web `components/gorsel/icerik-gorseli.tsx` ikizi; iki boy:
///   * [IcerikGorseliBoy.kucuk]: listede satir basinda kare kucuk resim.
///   * [IcerikGorseliBoy.buyuk]: ayrintida 16:9 kapak; dokununca tam
///     ekran + yakinlastirma.
///
/// GORSEL YOKSA (ya da yuklenemezse) BOS CERCEVE CIZILMEZ (§5d):
///   * kucuk: icerik turunu soyleyen sakin bir ikon kutusu (liste hizasi
///     korunur, "kirik gorsel" izlenimi verilmez),
///   * buyuk: HIC cizilmez; ayrinti metinle baslar.
library;

import 'package:flutter/material.dart';

import '../i18n/l10n.dart';
import 'gorsel_cozme.dart';

enum IcerikGorseliBoy { kucuk, buyuk }

enum IcerikTuru { duyuru, etkinlik, alan }

IconData _ikon(IcerikTuru t) => switch (t) {
  IcerikTuru.duyuru => Icons.campaign_outlined,
  IcerikTuru.etkinlik => Icons.event_outlined,
  IcerikTuru.alan => Icons.meeting_room_outlined,
};

class IcerikGorseli extends StatelessWidget {
  const IcerikGorseli({
    super.key,
    required this.url,
    required this.boy,
    required this.tur,
    this.kucukBoyut = 56,
  });

  final String? url;
  final IcerikGorseliBoy boy;
  final IcerikTuru tur;
  final double kucukBoyut;

  Widget _ikonKutusu(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        key: const Key('icerik-gorseli-yok'),
        width: kucukBoyut,
        height: kucukBoyut,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(_ikon(tur), color: cs.onSurfaceVariant),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (boy == IcerikGorseliBoy.kucuk) {
      if (u == null || u.isEmpty) return _ikonKutusu(context);
      return ClipRRect(
        key: const Key('icerik-gorseli-kucuk'),
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          u,
          semanticLabel: context.l10n.ortakFotograf,
          width: kucukBoyut,
          height: kucukBoyut,
          cacheWidth: cozmeSiniri(context, kucukBoyut),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _ikonKutusu(context),
        ),
      );
    }
    if (u == null || u.isEmpty) return const SizedBox.shrink();
    return _BuyukGorsel(url: u);
  }
}

class _BuyukGorsel extends StatefulWidget {
  const _BuyukGorsel({required this.url});
  final String url;

  @override
  State<_BuyukGorsel> createState() => _BuyukGorselState();
}

class _BuyukGorselState extends State<_BuyukGorsel> {
  bool _hata = false;

  @override
  Widget build(BuildContext context) {
    if (_hata) return const SizedBox.shrink();
    final l10n = context.l10n;
    void hataOldu() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hata) setState(() => _hata = true);
      });
    }

    // Klavyeyle de acilabilmeli; ekran okuyucuda ADLI (tur 33/34).
    return MergeSemantics(
      child: Semantics(
        label: l10n.ortakFotografiBuyut,
        child: InkWell(
          key: const Key('icerik-gorseli-buyuk'),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => Dialog(
              insetPadding: const EdgeInsets.all(12),
              child: InteractiveViewer(
                child: Image.network(
                  widget.url,
                  cacheWidth: cozmeSiniri(
                    context,
                    MediaQuery.sizeOf(context).width * 2,
                  ),
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                widget.url,
                semanticLabel: l10n.ortakFotograf,
                width: double.infinity,
                cacheWidth: cozmeSiniri(context, MediaQuery.sizeOf(context).width),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) {
                  hataOldu();
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
