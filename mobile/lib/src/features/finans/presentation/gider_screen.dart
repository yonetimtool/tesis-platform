/// (P206 §4.3) MOBIL GIDER KAYDI — fis fotografiyla.
///
/// ===========================================================================
/// ONAY BEKLEYEN GIDER BAKIYEYI DUSURMEZ (P192) — VE BU EKRANDA YAZAR
/// ===========================================================================
/// `durum` alani sessiz bir varsayilan DEGIL, gorunur bir SECIMDIR:
/// yonetici "gideri yazdim" deyip bakiyeyi yanlis okumasin. Ekran iki
/// secenegin ne yaptigini ACIKCA soyler.
///
/// ===========================================================================
/// FIS FOTOGRAFI — DEGERLENDIRME SONUCU: EVET
/// ===========================================================================
/// Nakit gider, site muhasebesinde en cok tartisilan kalemdir ve "fis
/// nerede" sorusu her denetimde sorulur. Fis sahada, telefonda; onu
/// kaydin yanina koymak icin dogru an TAM DA O AN. Ek mekanizmasi
/// mevcut (`/ekler`, varlik_tipi=finansal_hareket) — yeni tablo
/// acilmadi.
///
/// FOTOGRAF ZORUNLU DEGIL: zorunlu kilmak, fisi olmayan mesru gideri
/// (kapici avansı, banka masrafi) kaydedilemez yapardi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/para.dart';
import '../../tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;
import '../data/finans_api.dart';
import '../domain/finans_models.dart';
import 'tahsilat_screen.dart' show kasalarProvider;

final giderTurleriProvider =
    FutureProvider.autoDispose<List<GiderTuru>>((ref) async {
  return ref.watch(finansApiProvider).giderTurleri();
});

class GiderScreen extends ConsumerStatefulWidget {
  const GiderScreen({super.key});

  @override
  ConsumerState<GiderScreen> createState() => _GiderScreenState();
}

class _GiderScreenState extends ConsumerState<GiderScreen> {
  String? _kasaId;
  String? _turId;
  bool _onayBekliyor = false;
  XFile? _fis;
  final _tutarCtrl = TextEditingController();
  final _aciklamaCtrl = TextEditingController();
  String _anahtar = _yeniAnahtar();
  String? _hata;
  bool _kaydediyor = false;

  static String _yeniAnahtar() =>
      'gider-${DateTime.now().toUtc().microsecondsSinceEpoch}';

  @override
  void dispose() {
    _tutarCtrl.dispose();
    _aciklamaCtrl.dispose();
    super.dispose();
  }

  Future<void> _fotoSec() async {
    final secilen = await ref.read(imagePickerProvider).pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          imageQuality: 80,
        );
    if (secilen != null && mounted) setState(() => _fis = secilen);
  }

  Future<void> _kaydet() async {
    final l10n = context.l10n;
    final kasalar = ref.read(kasalarProvider).value ?? const <Kasa>[];
    final kasaId = _kasaId ?? (kasalar.isNotEmpty ? kasalar.first.id : null);
    final kurus = tlMetniniKurusaCevir(_tutarCtrl.text);
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
      final api = ref.read(finansApiProvider);
      final hareketId = await api.gider(
        kasaId: kasaId,
        tutarKurus: kurus,
        durum: _onayBekliyor ? 'onay_bekliyor' : 'odendi',
        idempotencyKey: _anahtar,
        giderTuruId: _turId,
        aciklama: _aciklamaCtrl.text.trim().isEmpty
            ? null
            : _aciklamaCtrl.text.trim(),
      );
      // FIS YUKLEME KAYDI KIRMAZ: gider YAZILDI; fotograf yuklenemezse
      // kullaniciya soylenir ama kayit geri alinmaz — para hareketi
      // gercek, fotograf onun kanitidir.
      if (_fis != null && hareketId != null) {
        try {
          final baytlar = await _fis!.readAsBytes();
          final bilet = await api.fisPresign(contentType: 'image/jpeg');
          await api.fisYukle(
            bilet: bilet, baytlar: baytlar, contentType: 'image/jpeg');
          await api.fisEkle(hareketId: hareketId, dosyaKey: bilet.fotoKey);
        } on ApiException {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.finansFisYuklenemedi)),
            );
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _anahtar = _yeniAnahtar();
        _tutarCtrl.clear();
        _aciklamaCtrl.clear();
        _fis = null;
        _kaydediyor = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.finansGiderKaydedildi)),
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
    final kasalar = ref.watch(kasalarProvider);
    final turler = ref.watch(giderTurleriProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.finansGiderBaslik)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_hata != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _hata!,
                key: const Key('gider-hata'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          TextField(
            key: const Key('gider-tutar'),
            controller: _tutarCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.finansAlanTutar),
          ),
          const SizedBox(height: 12),
          turler.when(
            data: (ts) => DropdownButtonFormField<String>(
              key: const Key('gider-tur'),
              initialValue: _turId,
              decoration: InputDecoration(labelText: l10n.finansGiderTuru),
              items: [
                for (final t in ts)
                  DropdownMenuItem(value: t.id, child: Text(t.ad)),
              ],
              onChanged: (v) => setState(() => _turId = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => Text(l10n.ortakBeklenmeyenHata),
          ),
          const SizedBox(height: 12),
          kasalar.when(
            data: (ks) {
              if (ks.length < 2) return const SizedBox.shrink();
              return DropdownButtonFormField<String>(
                key: const Key('gider-kasa'),
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
            key: const Key('gider-aciklama'),
            controller: _aciklamaCtrl,
            decoration: InputDecoration(labelText: l10n.finansAlanAciklama),
          ),
          const SizedBox(height: 12),
          // (P192) ONAY BEKLEYEN GIDER BAKIYEYI DUSURMEZ — ekranda YAZAR.
          SwitchListTile(
            key: const Key('gider-onay-bekliyor'),
            value: _onayBekliyor,
            title: Text(l10n.finansOnayBekliyor),
            subtitle: Text(l10n.finansOnayBekliyorNotu),
            onChanged: (v) => setState(() => _onayBekliyor = v),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('gider-fis'),
            onPressed: _fotoSec,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(_fis == null ? l10n.finansFisEkle : l10n.finansFisEklendi),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('gider-kaydet'),
            onPressed: _kaydediyor ? null : _kaydet,
            child: Text(_kaydediyor ? l10n.ortakKaydediliyor : l10n.ortakKaydet),
          ),
        ],
      ),
    );
  }
}
