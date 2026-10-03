/// (P253 §C) MOBIL FINANS ONAY DIYALOGU — ortak bilesen.
///
/// Telefonda yanlis dokunma kolay, finans hatasi pahali. Onayla / reddet /
/// iptal gibi her finans eylemi bu diyalogdan gecer:
///
///  1. TUTAR ve HEDEF acikca yazili ("A-12 · Ahmet YILMAZ · GDR-2026-0012"
///     + "1.250,00 ₺"); genel "Emin misiniz?" YOK.
///  2. Sebep gereken eylemde (red, iptal) alan ZORUNLU: en az
///     [sebepAsgari] karakter, bosken onay dugmesi PASIF. Sunucu da ayni
///     esikle reddeder (`backend/app/routers/finans.py SEBEP_ASGARI`,
///     web `onay-kullan.SEBEP_ASGARI`).
///  3. Geri alinamayan sonuc diyalogda ONCEDEN yazar ([sonuc] metni).
///
/// Merkez diyalogdur (alt sayfa degil — `merkez_diyalog` kilidi).
library;

import 'package:flutter/material.dart';

import '../girdi_siniri.dart';
import '../i18n/l10n.dart';

/// Sebep alt siniri — sunucu ve web ile AYNI.
const sebepAsgari = 3;

/// Sunucu `HareketOnayIstek.aciklama` / `IptalIstek.aciklama`: 500.
const _sebepAzami = 500;

/// Vazgecilirse `null`; onaylanirsa kirpilmis sebep (sebepsiz eylemde '').
Future<String?> finansOnayla(
  BuildContext context, {
  required String baslik,
  required String hedef,
  required String tutar,
  required String sonuc,
  required String onayMetni,
  bool sebepZorunlu = false,
  bool tehlikeli = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _FinansOnayDiyalogu(
      baslik: baslik,
      hedef: hedef,
      tutar: tutar,
      sonuc: sonuc,
      onayMetni: onayMetni,
      sebepZorunlu: sebepZorunlu,
      tehlikeli: tehlikeli,
    ),
  );
}

class _FinansOnayDiyalogu extends StatefulWidget {
  const _FinansOnayDiyalogu({
    required this.baslik,
    required this.hedef,
    required this.tutar,
    required this.sonuc,
    required this.onayMetni,
    required this.sebepZorunlu,
    required this.tehlikeli,
  });

  final String baslik, hedef, tutar, sonuc, onayMetni;
  final bool sebepZorunlu, tehlikeli;

  @override
  State<_FinansOnayDiyalogu> createState() => _FinansOnayDiyaloguState();
}

class _FinansOnayDiyaloguState extends State<_FinansOnayDiyalogu> {
  final _sebep = TextEditingController();

  @override
  void dispose() {
    _sebep.dispose();
    super.dispose();
  }

  bool get _hazir => !widget.sebepZorunlu || _sebep.text.trim().length >= sebepAsgari;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tema = Theme.of(context);
    return AlertDialog(
      key: const Key('finans-onay'),
      title: Text(widget.baslik),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.hedef.isNotEmpty)
              Text(widget.hedef,
                  key: const Key('finans-onay-hedef'),
                  style: tema.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text(widget.tutar,
                key: const Key('finans-onay-tutar'),
                style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(widget.sonuc, key: const Key('finans-onay-sonuc')),
            if (widget.sebepZorunlu) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('finans-onay-sebep'),
                controller: _sebep,
                maxLength: _sebepAzami,
                inputFormatters: GirdiSiniri.sinir(_sebepAzami),
                minLines: 2,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.finSebepEtiket,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.ortakVazgec),
        ),
        FilledButton(
          key: const Key('finans-onay-dugme'),
          style: widget.tehlikeli
              ? FilledButton.styleFrom(backgroundColor: tema.colorScheme.error)
              : null,
          onPressed: _hazir ? () => Navigator.of(context).pop(_sebep.text.trim()) : null,
          child: Text(widget.onayMetni),
        ),
      ],
    );
  }
}
