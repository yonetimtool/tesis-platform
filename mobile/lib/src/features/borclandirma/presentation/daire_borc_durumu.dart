/// (P253 Asama 2) DAIRE BORC DURUMU — web daire ayrintisi (`UnitDetail`)
/// karsiligi: `GET /units/{id}/dues` ozeti + borc kalemleri + odemeler,
/// "Borclandir" (tekil, daire secili) ve "Odeme kaydet" (`POST
/// /dues/payments`, Idempotency-Key ile).
///
/// Odeme kaydi da §C onayindan gecer (tutar + hedef); geri almasi finans
/// defterindeki iade/iptal yoluyladir ve diyalog bunu ONCEDEN yazar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/girdi_siniri.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/para.dart';
import '../../../core/ui/finans_onay.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../data/borclandirma_api.dart';
import '../domain/borclandirma_models.dart';
import 'borc_etiketleri.dart';
import 'tahakkuk_islemleri.dart';
import 'tekil_borclandirma.dart';

final daireBorcuProvider = FutureProvider.autoDispose.family<DaireBorcu, String>(
  (ref, unitId) => ref.watch(borclandirmaApiProvider).daireBorcu(unitId),
);

Future<void> daireBorcDurumuAc(BuildContext context, {required String unitId}) =>
    merkezSayfaAc<void>(context, builder: (_) => DaireBorcDurumu(unitId: unitId));

class DaireBorcDurumu extends ConsumerWidget {
  const DaireBorcDurumu({super.key, required this.unitId});

  final String unitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final veri = ref.watch(daireBorcuProvider(unitId));
    void tazele() => ref.invalidate(daireBorcuProvider(unitId));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: veri.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(
          e is ApiException && e.message.isNotEmpty ? e.message : l10n.ortakBeklenmeyenHata,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        data: (d) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(hedefMetni([d.no, l10n.brcDaireBorcu]),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _Ozet(etiket: l10n.brcToplamTahakkuk, kurus: d.toplamTahakkukKurus),
              _Ozet(etiket: l10n.brcToplamOdenen, kurus: d.toplamOdenenKurus),
              _Ozet(etiket: l10n.brcBakiye, kurus: d.bakiyeKurus, vurgu: true),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('brc-daire-borclandir'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                      icon: const Icon(Icons.post_add_outlined),
                      label: Text(l10n.brcBorclandir),
                      onPressed: () async {
                        final oldu = await tekilBorclandirmaAc(context, unitId: unitId);
                        if (oldu == true) tazele();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('brc-daire-odeme'),
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                      icon: const Icon(Icons.payments_outlined),
                      label: Text(l10n.brcOdemeKaydet),
                      onPressed: () async {
                        final oldu = await merkezSayfaAc<bool>(
                          context,
                          builder: (_) => OdemeFormu(borc: d),
                        );
                        if (oldu == true) tazele();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(l10n.brcTahakkuklar, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (d.tahakkuklar.isEmpty)
                Text(l10n.brcTahakkukYok)
              else
                for (final t in d.tahakkuklar)
                  ListTile(
                    key: Key('brc-daire-tahakkuk-${t.id}'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(t.tanimAd ?? kalemTipiAdi(l10n, t.kalemTipi)),
                    subtitle: Text(hedefMetni([
                      l10n.brcDonem(t.donem),
                      if (t.iptalEdildi) l10n.brcDuzeltildi,
                      if (t.tersKayitId != null) l10n.brcDuzeltme,
                    ])),
                    trailing: Text(tlTutar(t.tutarKurus)),
                    onTap: () async {
                      final oldu = await tahakkukAyrintisi(context, t, daireNo: d.no);
                      if (oldu == true) tazele();
                    },
                  ),
              const SizedBox(height: 12),
              Text(l10n.brcOdemeler, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (d.odemeler.isEmpty)
                Text(l10n.brcOdemeYok)
              else
                for (final o in d.odemeler)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(tlTutar(o.tutarKurus)),
                    subtitle: Text(hedefMetni([
                      tarihBicimi(o.zaman, context.dilKodu),
                      odemeYontemiAdi(l10n, o.yontem),
                      if (o.donem != null) l10n.brcDonem(o.donem!),
                    ])),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ozet extends StatelessWidget {
  const _Ozet({required this.etiket, required this.kurus, this.vurgu = false});

  final String etiket;
  final int kurus;
  final bool vurgu;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(etiket)),
            Text(tlTutar(kurus),
                style: vurgu ? const TextStyle(fontWeight: FontWeight.w700) : null),
          ],
        ),
      );
}

/// Daire odemesi formu — web `UnitDetail` "tahsilat" ile ayni alanlar.
class OdemeFormu extends ConsumerStatefulWidget {
  const OdemeFormu({super.key, required this.borc});

  final DaireBorcu borc;

  @override
  ConsumerState<OdemeFormu> createState() => _OdemeState();
}

class _OdemeState extends ConsumerState<OdemeFormu> {
  final _tutar = TextEditingController();
  final _makbuz = TextEditingController();
  final _donem = TextEditingController();
  // Ayni odeme niyetinin tekrarinda SABIT: cift dokunusta cift kayit yok.
  final String _anahtar = 'odeme-${DateTime.now().toUtc().microsecondsSinceEpoch}';
  String _yontem = 'elden';
  String? _kalemId;
  bool _mesgul = false;
  String? _hata;

  @override
  void dispose() {
    _tutar.dispose();
    _makbuz.dispose();
    _donem.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    final l10n = context.l10n;
    final kurus = tlMetniniKurusaCevir(_tutar.text);
    if (kurus == null || kurus <= 0) return setState(() => _hata = l10n.brcTutarGecersiz);
    setState(() => _hata = null);
    final kalem = widget.borc.tahakkuklar.where((t) => t.id == _kalemId).firstOrNull;
    final onay = await finansOnayla(
      context,
      baslik: l10n.brcOdemeKaydet,
      hedef: hedefMetni([
        widget.borc.no,
        odemeYontemiAdi(l10n, _yontem),
        if (kalem != null) kalem.tanimAd ?? kalemTipiAdi(l10n, kalem.kalemTipi),
      ]),
      tutar: tlTutar(kurus),
      sonuc: l10n.brcOdemeOnaySonuc,
      onayMetni: l10n.brcOdemeKaydet,
    );
    if (onay == null || !mounted) return;
    setState(() => _mesgul = true);
    try {
      await ref.read(borclandirmaApiProvider).odeme(
            unitId: widget.borc.unitId,
            tutarKurus: kurus,
            yontem: _yontem,
            idempotencyKey: _anahtar,
            assessmentId: _kalemId,
            makbuzNo: _makbuz.text.trim().isEmpty ? null : _makbuz.text.trim(),
            donem: _donem.text.trim().isEmpty ? null : _donem.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.brcOdemeKaydedildi)));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _mesgul = false;
        _hata = e.message.isNotEmpty ? e.message : l10n.ortakBeklenmeyenHata;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final acik = [for (final t in widget.borc.tahakkuklar) if (t.tersKayitlanabilir) t];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(hedefMetni([widget.borc.no, l10n.brcOdemeKaydet]),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              key: const Key('brc-odeme-tutar'),
              controller: _tutar,
              enabled: !_mesgul,
              maxLength: GirdiSiniri.tutar,
              inputFormatters: GirdiSiniri.sinir(GirdiSiniri.tutar),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.brcTutar, border: const OutlineInputBorder()),
            ),
            DropdownButtonFormField<String>(
              key: const Key('brc-odeme-yontem'),
              isExpanded: true,
              initialValue: _yontem,
              decoration: InputDecoration(labelText: l10n.brcYontem, border: const OutlineInputBorder()),
              items: [
                for (final y in odemeYontemleri)
                  DropdownMenuItem(value: y, child: Text(odemeYontemiAdi(l10n, y))),
              ],
              onChanged: _mesgul ? null : (v) => setState(() => _yontem = v ?? 'elden'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const Key('brc-odeme-kalem'),
              isExpanded: true,
              initialValue: _kalemId,
              decoration: InputDecoration(labelText: l10n.brcOdenenKalem, border: const OutlineInputBorder()),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(l10n.brcKalemSecimsiz)),
                for (final t in acik)
                  DropdownMenuItem<String?>(
                    value: t.id,
                    child: Text(
                      hedefMetni([t.tanimAd ?? kalemTipiAdi(l10n, t.kalemTipi), t.donem, tlTutar(t.tutarKurus)]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _mesgul ? null : (v) => setState(() => _kalemId = v),
            ),
            const SizedBox(height: 12),
            if (_kalemId == null)
              TextField(
                key: const Key('brc-odeme-donem'),
                controller: _donem,
                enabled: !_mesgul,
                maxLength: 7,
                inputFormatters: GirdiSiniri.sinir(7),
                decoration: InputDecoration(labelText: l10n.brcDonemAlan, border: const OutlineInputBorder()),
              ),
            TextField(
              key: const Key('brc-odeme-makbuz'),
              controller: _makbuz,
              enabled: !_mesgul,
              maxLength: GirdiSiniri.kod,
              inputFormatters: GirdiSiniri.sinir(GirdiSiniri.kod),
              decoration: InputDecoration(labelText: l10n.brcMakbuzNo, border: const OutlineInputBorder()),
            ),
            if (_hata != null) ...[
              Text(_hata!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 8),
            ],
            FilledButton(
              key: const Key('brc-odeme-kaydet'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _mesgul ? null : _kaydet,
              child: Text(l10n.brcOdemeKaydet),
            ),
          ],
        ),
      ),
    );
  }
}
