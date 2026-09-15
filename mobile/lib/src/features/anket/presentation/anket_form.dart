import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../../tasks/data/task_api.dart';
import '../../tasks/presentation/task_complete_controller.dart';
import '../data/anket_api.dart';
import '../domain/anket_models.dart';

/// (P237 §3) MOBILDE ANKET OLUSTURMA.
///
/// =========================================================================
/// NEDEN ARTIK VAR (P38'de bilincli olarak YOKTU)
/// =========================================================================
/// P38'de mobil anket ekrani salt-okumaydi: "olusturma/kapatma YONETIM
/// isidir ve panele aittir". P235'te yazilan KALICI PARITE KURALI bunu
/// gecersiz kilar — bir ozellik iki yuzeyde de bulunur. Yetki yine
/// SUNUCUDA (admin + yonetici); buradaki kapi yalniz UX.
///
/// =========================================================================
/// MADDELER: SATIR BASINA BIR MADDE
/// =========================================================================
/// Web'le AYNI desen. Ayri bir "+ ile ekle" listesi yerine cok satirli
/// metin: yonetici maddeleri pesi sira yazar; her madde icin ayri alan
/// acmak ayni isi uc dokunusa cikarirdi. EN AZ IKI madde sarti burada da
/// sorulur — sunucuya sorup 422 almak, yapilabilecek bir uyariyi aga
/// havale etmek olurdu.
///
/// =========================================================================
/// GORSEL YUKLEME: TASK API'NIN PRESIGN'I
/// =========================================================================
/// `TaskApi.presignUpload`/`uploadPhoto` genel `/uploads/presign` ucunu
/// sariyor ve goreve OZGU bir sey yapmiyor. Ikinci bir kopya yazmak, ayni
/// akisin iki yerde ayrisabilmesi demekti.
class AnketFormSayfasi extends ConsumerStatefulWidget {
  const AnketFormSayfasi({super.key});

  @override
  ConsumerState<AnketFormSayfasi> createState() => _AnketFormSayfasiState();
}

/// Hedeflenebilir roller — arka uctaki `ANKET_HEDEF_ROLLER` ile AYNI.
const _hedefRoller = [
  'resident',
  'security',
  'guvenlik_amiri',
  'tesis_gorevlisi',
  'yonetici',
  'admin',
];

class _AnketFormSayfasiState extends ConsumerState<AnketFormSayfasi> {
  final _baslik = TextEditingController();
  final _aciklama = TextEditingController();
  final _maddeler = TextEditingController();
  final Set<String> _secilenRoller = {};
  bool _anonim = false;
  String? _gorselKey;
  bool _mesgul = false;
  String? _hata;

  @override
  void dispose() {
    _baslik.dispose();
    _aciklama.dispose();
    _maddeler.dispose();
    super.dispose();
  }

  Future<void> _gorselSec() async {
    final secici = ref.read(imagePickerProvider);
    final dosya = await secici.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (dosya == null) return;
    setState(() => _mesgul = true);
    try {
      final api = ref.read(taskApiProvider);
      final tip = dosya.mimeType ?? 'image/jpeg';
      final bilet = await api.presignUpload(
        contentType: tip,
        dosyaAdi: dosya.name,
      );
      await api.uploadPhoto(
        ticket: bilet,
        bytes: await dosya.readAsBytes(),
        contentType: tip,
      );
      if (mounted) setState(() => _gorselKey = bilet.fotoKey);
    } catch (e) {
      if (mounted) setState(() => _hata = '$e');
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _kaydet() async {
    final l10n = context.l10n;
    final maddeler = _maddeler.text
        .split('\n')
        .map((x) => x.trim())
        .where((x) => x.isNotEmpty)
        .toList();
    if (_baslik.text.trim().isEmpty || maddeler.length < 2) {
      setState(() => _hata = l10n.anketEnAzIki);
      return;
    }
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    final navigator = Navigator.of(context);
    try {
      await ref.read(anketApiProvider).olustur(AnketTaslak(
            baslik: _baslik.text.trim(),
            aciklama:
                _aciklama.text.trim().isEmpty ? null : _aciklama.text.trim(),
            gorselKey: _gorselKey,
            maddeler: maddeler,
            hedefRoller: _secilenRoller.toList(),
            anonim: _anonim,
          ));
      ref.invalidate(anketlerProvider);
      navigator.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hata = '$e';
          _mesgul = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.anketYeni,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              key: const Key('anket-baslik'),
              controller: _baslik,
              decoration: InputDecoration(labelText: l10n.anketBaslik),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _aciklama,
              decoration:
                  InputDecoration(labelText: l10n.anketAciklamaOpsiyonel),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('anket-maddeler'),
              controller: _maddeler,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: l10n.anketMaddeler,
                helperText: l10n.anketMaddeIpucu,
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('anket-gorsel'),
                icon: const Icon(Icons.image_outlined),
                label: Text(l10n.anketGorselSec),
                onPressed: _mesgul ? null : _gorselSec,
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.anketHedefKitle,
                style: Theme.of(context).textTheme.labelLarge),
            Text(l10n.anketHedefHerkes,
                style: Theme.of(context).textTheme.bodySmall),
            Wrap(
              spacing: 8,
              children: [
                for (final r in _hedefRoller)
                  FilterChip(
                    key: Key('anket-hedef-$r'),
                    label: Text(rolAdiKisa(l10n, r)),
                    selected: _secilenRoller.contains(r),
                    onSelected: (s) => setState(() {
                      if (s) {
                        _secilenRoller.add(r);
                      } else {
                        _secilenRoller.remove(r);
                      }
                    }),
                  ),
              ],
            ),
            // ANONIMLIK — KAYDEDILDIKTEN SONRA DEGISTIRILEMEZ. Uyari
            // KAYDETMEDEN ONCE: sonradan gosterilen bir uyarinin degeri yok.
            SwitchListTile(
              key: const Key('anket-anonim'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.anketAnonimSecim),
              subtitle: Text(l10n.anketAnonimUyari),
              value: _anonim,
              onChanged: (v) => setState(() => _anonim = v),
            ),
            if (_hata != null)
              Text(_hata!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('anket-kaydet'),
                onPressed: _mesgul ? null : _kaydet,
                child: Text(l10n.ortakKaydet),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rol adi — anket formundaki kisa etiket. Sozlukteki rol adlari
/// TEK KAYNAK; burada ikinci bir liste tutulmuyor.
String rolAdiKisa(AppLocalizations l10n, String rol) => switch (rol) {
      'resident' => l10n.rolSakin,
      'security' => l10n.rolGuvenlik,
      'guvenlik_amiri' => l10n.rolGuvenlikAmiri,
      'tesis_gorevlisi' => l10n.rolTesisGorevlisi,
      'yonetici' => l10n.rolYonetici,
      'admin' => l10n.rolAdmin,
      _ => rol,
    };

/// Formu MERKEZ SAYFADA acar (`showModalBottomSheet` depoda yasak).
Future<bool?> anketFormuAc(BuildContext context) => merkezSayfaAc<bool>(
      context,
      builder: (_) => const AnketFormSayfasi(),
    );
