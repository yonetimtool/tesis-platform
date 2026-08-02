/// (P110) TEK SATIRLIK METIN ISTEYEN DIYALOG — denetleyiciyi KENDI atar.
///
/// NEDEN AYRI BIR WIDGET: uc cagri yeri `showDialog` icinde YEREL bir
/// `TextEditingController` uretiyor ve hicbiri atmiyordu (P109 olcumu:
/// 106 denetleyiciden 3'u). `await showDialog(...)` sonrasi atmak ise
/// COKUYOR — future rota pop edilince tamamlanir ama diyalogun CIKIS
/// ANIMASYONU hala `TextField`i cizer ve "used after being disposed"
/// hatasi alinir (P109'da tam suitte olculdu).
///
/// Cozum sahipligi tasimaktir: denetleyici diyalogun KENDI durumuna ait
/// olur ve widget agactan cikarken `dispose()` edilir — animasyon bittikten
/// SONRA, cunku `State.dispose` tam da o zaman cagrilir.
library;

import 'package:flutter/material.dart';

import '../i18n/l10n.dart';

class _MetinIsteGovde extends StatefulWidget {
  const _MetinIsteGovde({
    required this.baslik,
    required this.onayEtiketi,
    this.etiket,
    this.ipucu,
    this.baslangic,
    this.enFazla,
    this.satirlar = 1,
  });

  final String baslik;
  final String onayEtiketi;
  final String? etiket;
  final String? ipucu;
  final String? baslangic;
  final int? enFazla;
  final int satirlar;

  @override
  State<_MetinIsteGovde> createState() => _MetinIsteGovdeDurum();
}

class _MetinIsteGovdeDurum extends State<_MetinIsteGovde> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.baslangic ?? '');

  @override
  void dispose() {
    _ctrl.dispose(); // animasyon bitip widget agactan cikinca
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.baslik),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLength: widget.enFazla,
        maxLines: widget.satirlar,
        decoration: InputDecoration(
          labelText: widget.etiket,
          hintText: widget.ipucu,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.ortakVazgec),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: Text(widget.onayEtiketi),
        ),
      ],
    );
  }
}

/// Metin isteyen diyalogu acar. Iptalde `null`, onayda KIRPILMIS metin.
Future<String?> metinIste(
  BuildContext context, {
  required String baslik,
  required String onayEtiketi,
  String? etiket,
  String? ipucu,
  String? baslangic,
  int? enFazla,
  int satirlar = 1,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _MetinIsteGovde(
      baslik: baslik,
      onayEtiketi: onayEtiketi,
      etiket: etiket,
      ipucu: ipucu,
      baslangic: baslangic,
      enFazla: enFazla,
      satirlar: satirlar,
    ),
  );
}
