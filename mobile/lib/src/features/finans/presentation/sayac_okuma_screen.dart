/// (P206 §4.5) MOBIL SAYAC OKUMA — sahada oku, oracikta borclandir.
///
/// ===========================================================================
/// WEB SIHIRBAZINDAN FARKI
/// ===========================================================================
/// Web dort adimli bir sihirbaz (kalem -> ana sayac -> tuketimler ->
/// borclandirma) ve masabasi icin dogru. Sahada ise kisi bodrumda,
/// elinde telefonla ve TEK ELLE calisiyor: ekran TEK LISTE — ustte kalem
/// ve ana sayac, altinda daire daire deger alanlari. Adimlara bolmek,
/// her sayacta ileri-geri gitmek demekti.
///
/// ONCEKI OKUMA HER SATIRDA YAZAR: sahada en sik yapilan hata, degeri
/// oncekinin ALTINA yazmaktir (yeni sayac, yanlis hane). Ekran bunu
/// ANINDA soyler — gonderdikten sonra degil.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/para.dart';
import '../../../core/sayi.dart';
import '../../tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;
import '../data/sayac_api.dart';
import '../domain/sayac_models.dart';

final anaSayaclarProvider =
    FutureProvider.autoDispose<List<AnaSayac>>((ref) async {
  return ref.watch(sayacApiProvider).anaSayaclar();
});

final sayacKalemleriProvider =
    FutureProvider.autoDispose<List<GiderTuruBasit>>((ref) async {
  return ref.watch(sayacApiProvider).kalemler();
});

final bolumSayaclariProvider = FutureProvider.autoDispose
    .family<List<BolumSayaci>, String>((ref, anaId) async {
  return ref.watch(sayacApiProvider).bolumSayaclari(anaId);
});

class SayacOkumaScreen extends ConsumerStatefulWidget {
  const SayacOkumaScreen({super.key});

  @override
  ConsumerState<SayacOkumaScreen> createState() => _SayacOkumaScreenState();
}

class _SayacOkumaScreenState extends ConsumerState<SayacOkumaScreen> {
  String? _kalemId;
  String? _anaId;
  final _donemCtrl = TextEditingController(
    text: '${DateTime.now().year}-'
        '${DateTime.now().month.toString().padLeft(2, '0')}',
  );
  final _anaTuketimCtrl = TextEditingController();
  final _birimCtrl = TextEditingController();
  final _degerler = <String, TextEditingController>{};
  final _fotolar = <String, XFile>{};
  String? _hata;
  bool _gonderiyor = false;

  @override
  void dispose() {
    _donemCtrl.dispose();
    _anaTuketimCtrl.dispose();
    _birimCtrl.dispose();
    for (final c in _degerler.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String id) =>
      _degerler.putIfAbsent(id, TextEditingController.new);

  Future<void> _foto(BolumSayaci b) async {
    final secilen = await ref.read(imagePickerProvider).pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          imageQuality: 80,
        );
    if (secilen != null && mounted) setState(() => _fotolar[b.id] = secilen);
  }

  Future<void> _gonder(List<BolumSayaci> bolumler) async {
    final l10n = context.l10n;
    final anaTuketim = sayiCoz(_anaTuketimCtrl.text);
    final birim = tlMetniniKurusaCevir(_birimCtrl.text);
    if (_kalemId == null || _anaId == null) {
      setState(() => _hata = l10n.sayacKalemGerekli);
      return;
    }
    if (anaTuketim.tur != SayiTuru.sayi || (anaTuketim.deger ?? 0) <= 0) {
      setState(() => _hata = l10n.sayacAnaTuketimGerekli);
      return;
    }
    if (birim == null || birim <= 0) {
      setState(() => _hata = l10n.sayacBirimFiyatGerekli);
      return;
    }
    // GERI SAYAN OKUMA ANINDA REDDEDILIR: yeni deger oncekinin ALTINDA
    // olamaz. Sunucuya gonderip 422 beklemek, sahada duran kisiyi bir
    // gidis-donus daha bekletirdi.
    final tuketimler = <String, double>{};
    for (final b in bolumler) {
      final metin = _ctrl(b.id).text.trim();
      if (metin.isEmpty) continue;
      final s = sayiCoz(metin);
      final deger = s.deger;
      if (s.tur != SayiTuru.sayi || deger == null || deger < 0) {
        setState(() => _hata = l10n.sayacDegerGecersiz(b.unitNo ?? ''));
        return;
      }
      if (b.ilkOkuma != null && deger < b.ilkOkuma!) {
        setState(() => _hata = l10n.sayacGeriSayiyor(b.unitNo ?? ''));
        return;
      }
      tuketimler[b.id] = deger;
    }
    if (tuketimler.isEmpty) {
      setState(() => _hata = l10n.sayacDegerYok);
      return;
    }
    setState(() {
      _gonderiyor = true;
      _hata = null;
    });
    try {
      final api = ref.read(sayacApiProvider);
      final atlanan = await api.borclandir(
        donem: _donemCtrl.text.trim(),
        kalemId: _kalemId!,
        anaSayacId: _anaId!,
        anaTuketim: anaTuketim.deger!,
        birimFiyatKurus: birim,
        bolumTuketimleri: tuketimler,
      );
      // FOTOGRAFLAR BORCLANDIRMADAN SONRA: yukleme basarisiz olsa bile
      // borclandirma GECERLIDIR. Once fotograf yukleyip sonra
      // borclandirsaydik, yarim kalan bir akis daireye "sahipsiz" ek
      // birakirdi.
      for (final girdi in _fotolar.entries) {
        final b = bolumler.firstWhere((x) => x.id == girdi.key);
        try {
          final bilet = await api.fotoPresign();
          await api.fotoYukle(
              bilet: bilet, baytlar: await girdi.value.readAsBytes());
          await api.okumaEkle(
            unitId: b.unitId,
            dosyaKey: bilet.fotoKey,
            metin: '${_donemCtrl.text.trim()} · ${_ctrl(b.id).text.trim()}',
          );
        } on ApiException {
          // Tek fotograf yuklenemedi: akisi kirma, sonda soyle.
        }
      }
      if (!mounted) return;
      setState(() {
        _gonderiyor = false;
        for (final c in _degerler.values) {
          c.clear();
        }
        _fotolar.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sayacBorclandirildi(atlanan))),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = apiHataMetni(l10n, e);
        _gonderiyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kalemler = ref.watch(sayacKalemleriProvider);
    final anaSayaclar = ref.watch(anaSayaclarProvider);
    final bolumler = _anaId == null
        ? const AsyncValue<List<BolumSayaci>>.data([])
        : ref.watch(bolumSayaclariProvider(_anaId!));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sayacOkumaBaslik)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_hata != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _hata!,
                key: const Key('sayac-hata'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          kalemler.when(
            data: (ks) => DropdownButtonFormField<String>(
              key: const Key('sayac-kalem'),
              initialValue: _kalemId,
              decoration: InputDecoration(labelText: l10n.sayacKalem),
              items: [
                for (final k in ks)
                  DropdownMenuItem(value: k.id, child: Text(k.ad)),
              ],
              onChanged: (v) => setState(() => _kalemId = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => Text(l10n.ortakBeklenmeyenHata),
          ),
          const SizedBox(height: 12),
          anaSayaclar.when(
            data: (as_) => DropdownButtonFormField<String>(
              key: const Key('sayac-ana'),
              initialValue: _anaId,
              decoration: InputDecoration(labelText: l10n.sayacAnaSayac),
              items: [
                for (final a in as_)
                  DropdownMenuItem(value: a.id, child: Text(a.ad)),
              ],
              onChanged: (v) => setState(() => _anaId = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => Text(l10n.ortakBeklenmeyenHata),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('sayac-donem'),
            controller: _donemCtrl,
            decoration: InputDecoration(labelText: l10n.sayacDonem),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('sayac-ana-tuketim'),
            controller: _anaTuketimCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.sayacAnaTuketim),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('sayac-birim'),
            controller: _birimCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.sayacBirimFiyat),
          ),
          const Divider(height: 32),
          bolumler.when(
            data: (bs) => Column(
              children: [
                for (final b in bs)
                  ListTile(
                    key: Key('sayac-bolum-${b.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(b.unitNo ?? ''),
                    // ONCEKI OKUMA GORUNUR: sahada en sik yapilan hata,
                    // degeri oncekinin altina yazmak.
                    subtitle: b.ilkOkuma == null
                        ? null
                        : Text(l10n.sayacOncekiOkuma(b.ilkOkuma!.toString())),
                    trailing: SizedBox(
                      width: 150,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: Key('sayac-deger-${b.id}'),
                              controller: _ctrl(b.id),
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: const InputDecoration(isDense: true),
                            ),
                          ),
                          IconButton(
                            key: Key('sayac-foto-${b.id}'),
                            tooltip: l10n.sayacFotoEkle,
                            icon: Icon(
                              _fotolar.containsKey(b.id)
                                  ? Icons.photo_camera
                                  : Icons.photo_camera_outlined,
                            ),
                            onPressed: () => _foto(b),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (bs.isEmpty && _anaId != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.sayacBolumYok,
                      key: const Key('sayac-bolum-yok'),
                    ),
                  ),
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => Text(l10n.ortakBeklenmeyenHata),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('sayac-gonder'),
            onPressed: _gonderiyor
                ? null
                : () => _gonder(bolumler.value ?? const []),
            child: Text(
              _gonderiyor ? l10n.ortakKaydediliyor : l10n.sayacBorclandir,
            ),
          ),
        ],
      ),
    );
  }
}
