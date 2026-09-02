/// (P206 §4.1) MOBIL TAHSILAT — kapida elden alinan aidat.
///
/// ===========================================================================
/// TASARIM: AZ ADIM, BUYUK HEDEFLER
/// ===========================================================================
/// Bu ekranin kullanildigi an, yoneticinin kapida biriyle KONUSTUGU
/// andir. Web formunun (kisi, daire, yontem, kasa, tutar, tarih,
/// aciklama, belge no) telefona kopyalanmasi, o konusmayi sekiz alanlik
/// bir form doldurmaya cevirirdi.
///
/// Ekran DORT karara indirildi:
///   1. KIM (borclu listesinden — tutariyla birlikte),
///   2. NE KADAR (varsayilan: kalan borcun TAMAMI, tek dokunusla degisir),
///   3. HANGI KASA (tek kasa varsa SORULMAZ),
///   4. Kaydet.
/// Tarih BUGUN, yontem ELDEN (mobil tahsilatin tanimi bu); ikisi de
/// sunucunun varsayilani ve degistirilmesi gereken bir durum sahada
/// yok — gerekirse web'de duzeltilir.
///
/// ===========================================================================
/// CIFT TIKLAMA KORUMASI (P192 §6.2) — MOBILDE DE
/// ===========================================================================
/// `Idempotency-Key` FORM ORNEGI BASINA uretilir ve basarili kayittan
/// sonra yenilenir. Sahada baglanti kopar, kullanici "gitmedi" sanip
/// yeniden basar; anahtar olmasaydi kasada IKI hareket olusurdu ve bunu
/// ancak ay sonu mutabakatinda fark ederdi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/para.dart';
import '../data/finans_api.dart';
import '../domain/finans_models.dart';

final kasalarProvider =
    FutureProvider.autoDispose<List<Kasa>>((ref) async {
  return ref.watch(finansApiProvider).kasalar();
});

/// Borclular — tahsilat kisi secicinin kaynagi. Ozet DEGIL: kisi ve
/// tutar lazim.
final borclularProvider =
    FutureProvider.autoDispose<Yaslandirma>((ref) async {
  return ref.watch(finansApiProvider).yaslandirma();
});

class TahsilatScreen extends ConsumerStatefulWidget {
  const TahsilatScreen({super.key});

  @override
  ConsumerState<TahsilatScreen> createState() => _TahsilatScreenState();
}

class _TahsilatScreenState extends ConsumerState<TahsilatScreen> {
  Borclu? _secili;
  String? _kasaId;
  final _tutarCtrl = TextEditingController();
  final _aciklamaCtrl = TextEditingController();
  String _anahtar = _yeniAnahtar();
  String? _hata;
  bool _kaydediyor = false;

  static String _yeniAnahtar() =>
      'tahsilat-${DateTime.now().toUtc().microsecondsSinceEpoch}';

  @override
  void dispose() {
    _tutarCtrl.dispose();
    _aciklamaCtrl.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    final l10n = context.l10n;
    final kasalar = ref.read(kasalarProvider).value ?? const <Kasa>[];
    final kasaId = _kasaId ?? (kasalar.isNotEmpty ? kasalar.first.id : null);
    final kurus = tlMetniniKurusaCevir(_tutarCtrl.text);
    if (_secili == null) {
      setState(() => _hata = l10n.finansKisiGerekli);
      return;
    }
    if (kasaId == null) {
      setState(() => _hata = l10n.finansKasaGerekli);
      return;
    }
    if (kurus == null || kurus <= 0) {
      setState(() => _hata = l10n.finansTutarGerekli);
      return;
    }
    setState(() {
      _kaydediyor = true;
      _hata = null;
    });
    try {
      await ref.read(finansApiProvider).tahsilat(
            kasaId: kasaId,
            tutarKurus: kurus,
            idempotencyKey: _anahtar,
            userId: _secili!.userId,
            unitId: _secili!.unitId,
            aciklama: _aciklamaCtrl.text.trim().isEmpty
                ? null
                : _aciklamaCtrl.text.trim(),
          );
      if (!mounted) return;
      // ANAHTAR YENILENIR: bir sonraki tahsilat AYRI bir islemdir.
      setState(() {
        _anahtar = _yeniAnahtar();
        _secili = null;
        _tutarCtrl.clear();
        _aciklamaCtrl.clear();
        _kaydediyor = false;
      });
      ref.invalidate(borclularProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.finansTahsilatKaydedildi)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = apiHataMetni(l10n, e);
        _kaydediyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final borclular = ref.watch(borclularProvider);
    final kasalar = ref.watch(kasalarProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.finansTahsilatBaslik)),
      body: borclular.when(
        data: (y) {
          final liste = y.tumBorclular.where((b) => b.userId != null).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_hata != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _hata!,
                    key: const Key('tahsilat-hata'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              // BORCLU YOKSA EKRAN SESSIZ KALMAZ (kabul kriteri 6'nin
              // mobil karsiligi): bos bir liste, kullaniciya "sistem
              // bozuk mu" dedirtir.
              if (liste.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    l10n.finansBorcluYok,
                    key: const Key('tahsilat-borclu-yok'),
                  ),
                ),
              for (final b in liste)
                Card(
                  key: Key('tahsilat-borclu-${b.unitId}'),
                  color: _secili?.unitId == b.unitId
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : null,
                  child: ListTile(
                    title: Text('${b.ad ?? ''} · ${b.unitNo}'),
                    // TUTAR VE GECIKME BIRLIKTE: yonetici "ne kadar" ve
                    // "ne kadar zamandir" sorularini SECMEDEN ONCE
                    // gormeli.
                    subtitle: Text(
                      '${tlTutar(b.kalanKurus)} · ${l10n.finansGecikmeGun(b.enEskiGun)}',
                    ),
                    onTap: () => setState(() {
                      _secili = b;
                      // VARSAYILAN: KALAN BORCUN TAMAMI. Sahada en sik
                      // yapilan islem bu; bos birakmak her seferinde
                      // rakam yazdirirdi.
                      _tutarCtrl.text = tlTutar(b.kalanKurus);
                    }),
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('tahsilat-tutar'),
                controller: _tutarCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.finansAlanTutar),
              ),
              const SizedBox(height: 12),
              kasalar.when(
                data: (ks) {
                  // TEK KASA VARSA SORULMAZ: olmayan bir karari sormak,
                  // her tahsilata bir dokunus eklerdi.
                  if (ks.length < 2) return const SizedBox.shrink();
                  return DropdownButtonFormField<String>(
                    key: const Key('tahsilat-kasa'),
                    initialValue: _kasaId ?? ks.first.id,
                    decoration: InputDecoration(labelText: l10n.finansSutunKasa),
                    items: [
                      for (final k in ks)
                        DropdownMenuItem(value: k.id, child: Text(k.ad)),
                    ],
                    onChanged: (v) => setState(() => _kasaId = v),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => Text(l10n.ortakBeklenmeyenHata),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('tahsilat-aciklama'),
                controller: _aciklamaCtrl,
                decoration: InputDecoration(labelText: l10n.finansAlanAciklama),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('tahsilat-kaydet'),
                onPressed: _kaydediyor ? null : _kaydet,
                child: Text(
                  _kaydediyor ? l10n.ortakKaydediliyor : l10n.ortakKaydet,
                ),
              ),
              const SizedBox(height: 8),
              // MAKBUZ VE BILDIRIM SUNUCUDA: web ile AYNI yol
              // (`/finans/tahsilat`), yani makbuz numarasi ve sakine
              // giden bildirim ayni kodda uretilir. Mobil icin ikinci
              // bir yol acmak, ikisinin ayrisma riskini bedavaya
              // eklerdi.
              Text(
                l10n.finansMakbuzNotu,
                key: const Key('tahsilat-makbuz-notu'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              e is ApiException ? apiHataMetni(l10n, e) : l10n.ortakBeklenmeyenHata,
            ),
          ),
        ),
      ),
    );
  }
}
