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
import 'package:mobile/src/core/girdi_siniri.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/izin/belirgin_aciklama.dart';
import '../../../core/para.dart';
import '../../tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;
import '../data/finans_api.dart';
import '../domain/finans_models.dart';
import 'belge_alanlari.dart';
import 'tahsilat_screen.dart' show kasalarProvider;

/// (P253 Asama 1) Firma secici — web hareket formuyla AYNI liste.
final firmalarProvider = FutureProvider.autoDispose<List<Firma>>((ref) async {
  return ref.watch(finansApiProvider).firmalar();
});

/// (P253 Asama 1) GELIR GIRISI GIDER EKRANINDA: ayni defter, ayni uc
/// (`POST /finans/hareketler`, `tip`). Web'de ayri sayfalar; mobilde tek
/// form ve tip secimi.
const tipGider = 'gider';
const tipGelir = 'gelir';

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
  String? _firmaId;
  String _tip = tipGider;
  DateTime _tarih = DateTime.now();
  final _belgeCtrl = TextEditingController();
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
    _belgeCtrl.dispose();
    super.dispose();
  }

  Future<void> _fotoSec() async {
    // (E2E 2026-09) MOBIL-7: kamera cagrisi try/catch'SIZDI — izin reddinde
    // PlatformException yakalanmiyor, dugme tepkisiz kaliyordu. Diger foto
    // akislariyla AYNI desen: once belirgin aciklama, sonra korunakli cagri
    // + gorunur hata metni.
    final l10n = context.l10n;
    final onay = await belirginAciklamaGoster(context, IzinTuru.talepFotograf);
    if (!onay || !mounted) return;
    final XFile? secilen;
    try {
      secilen = await ref.read(imagePickerProvider).pickImage(
            source: ImageSource.camera,
            maxWidth: 1600,
            imageQuality: 80,
          );
    } catch (e) {
      if (mounted) setState(() => _hata = l10n.gorevFotoAlinamadi('$e'));
      return;
    }
    final foto = secilen;
    if (foto != null && mounted) setState(() => _fis = foto);
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
        // Onay akisi GIDERE ozgudur; gelir gerceklesmis yazilir.
        durum: _tip == tipGider && _onayBekliyor ? 'onay_bekliyor' : 'odendi',
        tip: _tip,
        tarih: _tarih,
        belgeNo: bosIseNull(_belgeCtrl.text),
        firmaId: _firmaId,
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
        _belgeCtrl.clear();
        _fis = null;
        _kaydediyor = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tip == tipGelir ? l10n.finGelirKaydedildi : l10n.finansGiderKaydedildi,
          ),
        ),
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
    final firmalar = ref.watch(firmalarProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.finGiderGelirBaslik)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            key: const Key('gider-tip'),
            segments: [
              ButtonSegment(value: tipGider, label: Text(l10n.finTipGider)),
              ButtonSegment(value: tipGelir, label: Text(l10n.finTipGelir)),
            ],
            selected: {_tip},
            onSelectionChanged: (s) => setState(() => _tip = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('gider-tutar'),
            controller: _tutarCtrl,
            inputFormatters: GirdiSiniri.sinir(GirdiSiniri.tutar),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.finansAlanTutar),
          ),
          const SizedBox(height: 12),
          turler.when(
            data: (ts) => DropdownButtonFormField<String>(
              key: const Key('gider-tur'),
              initialValue: _turId,
              decoration: InputDecoration(
                labelText: _tip == tipGelir ? l10n.finGelirTuru : l10n.finansGiderTuru,
              ),
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
            inputFormatters: GirdiSiniri.sinir(500), // sunucu: HareketSatir.aciklama
            decoration: InputDecoration(labelText: l10n.finansAlanAciklama),
          ),
          const SizedBox(height: 12),
          firmalar.when(
            data: (fs) => fs.isEmpty
                ? const SizedBox.shrink()
                : DropdownButtonFormField<String?>(
                    key: const Key('gider-firma'),
                    isExpanded: true,
                    initialValue: _firmaId,
                    decoration: InputDecoration(labelText: l10n.finFirma),
                    items: [
                      DropdownMenuItem<String?>(value: null, child: Text(l10n.finFirmaYok)),
                      for (final f in fs)
                        DropdownMenuItem<String?>(value: f.id, child: Text(f.ad)),
                    ],
                    onChanged: (v) => setState(() => _firmaId = v),
                  ),
            loading: () => const LinearProgressIndicator(),
            // Firma listesi bir KOLAYLIK: okunamazsa form yine kaydeder.
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          TarihBelgeAlanlari(
            anahtarOnEki: 'gider',
            tarih: _tarih,
            onTarih: (t) => setState(() => _tarih = t),
            belgeNo: _belgeCtrl,
          ),
          const SizedBox(height: 12),
          // (P192) ONAY BEKLEYEN GIDER BAKIYEYI DUSURMEZ — ekranda YAZAR.
          if (_tip == tipGider)
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
          // (P253 Asama 1) HATA DUGMENIN USTUNDE: form uzadi; listenin
          // basindaki hata, kaydet'e basan kullanicinin ekraninda degildi.
          if (_hata != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _hata!,
                key: const Key('gider-hata'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
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
