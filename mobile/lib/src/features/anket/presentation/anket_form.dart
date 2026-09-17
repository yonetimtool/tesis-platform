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
/// (P239 §7) MADDELER: HER SECENEK AYRI KUTU
/// =========================================================================
/// ESKIDEN cok satirli TEK metin alaniydi ("satir basina bir madde") ve
/// gerekcesi "ayri alan acmak ayni isi uc dokunusa cikarirdi" idi. O
/// gerekce YANLIS cikti: kullanici kac secenek yazdigini goremiyor, bos
/// satir sessizce yutuluyor, bir secenegi silmek satiri isaretleyip
/// silmeyi gerektiriyor ve mobil klavyede satir sonu koymak zaten fazladan
/// bir dokunus. Iki kutu ACIK BASLAR; "+" ucuncuyu ekler.
///
/// SILME IKI KUTUDA KAPALI — gizli degil. Gizlenen dugme "neden yok"
/// sorusunu dogurur; kapali dugme kurali soyler.
///
/// SUNUCUYA GIDEN GOVDE DEGISMEDI (madde metinleri listesi), bu yuzden
/// MEVCUT ANKETLER etkilenmez.
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
  /// (P239 §7) HER SECENEK BIR DENETLEYICI — en az iki.
  final List<TextEditingController> _maddeler = [
    TextEditingController(),
    TextEditingController(),
  ];
  final Set<String> _secilenRoller = {};
  DateTime? _baslangic;
  DateTime? _bitis;
  String? _sakinTipi;
  bool _anonim = false;
  String? _gorselKey;
  bool _mesgul = false;
  String? _hata;

  @override
  void dispose() {
    _baslik.dispose();
    _aciklama.dispose();
    for (final c in _maddeler) {
      c.dispose();
    }
    super.dispose();
  }

  /// TARIH + SAAT — etkinlik formundaki desen (`showDatePicker` ->
  /// `showTimePicker`). Gun tek basina yetmez: "12 Ekim'de kapansin"
  /// diyen yonetici gun ICINDE bir an kastediyor ve gunun 00:00'i o anı
  /// bir gun ONE cekerdi.
  Future<DateTime?> _tarihSec(DateTime? mevcut) async {
    final simdi = DateTime.now();
    final gun = await showDatePicker(
      context: context,
      initialDate: mevcut ?? simdi,
      firstDate: simdi.subtract(const Duration(days: 1)),
      lastDate: simdi.add(const Duration(days: 365)),
    );
    if (gun == null || !mounted) return null;
    final saat = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(mevcut ?? simdi),
    );
    if (saat == null) return null;
    return DateTime(gun.year, gun.month, gun.day, saat.hour, saat.minute);
  }

  /// MALIK/KIRACI AYRIMI YALNIZ SAKIN HEDEFLENDIGINDE ANLAMLI.
  ///
  /// Bos secim = HERKES (sakinler dahil). Roller secilmisse ve `resident`
  /// aralarinda degilse ayrim gosterilmez: "yalniz guvenlik ekibi" +
  /// "yalniz malikler" birlikte anlamsizdir ve sunucu da ayrimi personele
  /// UYGULAMAZ (`_hedef_kisi_sayisi`: rol != resident olanlar elenmez).
  bool get _sakinAyrimiAnlamli =>
      _secilenRoller.isEmpty || _secilenRoller.contains('resident');

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
    final maddeler = _maddeler
        .map((c) => c.text.trim())
        .where((x) => x.isNotEmpty)
        .toList();
    if (_baslik.text.trim().isEmpty || maddeler.length < 2) {
      setState(() => _hata = l10n.anketEnAzIki);
      return;
    }
    // TARIH SIRASI ISTEMCIDE DE SORULUR: sunucu 422 veriyor ama
    // yapilabilecek bir uyariyi aga havale etmek, kullaniciyi bekletip
    // sonra reddetmek olurdu.
    if (_baslangic != null &&
        _bitis != null &&
        !_bitis!.isAfter(_baslangic!)) {
      setState(() => _hata = l10n.anketTarihAraligiGecersiz);
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
            baslangicAt: _baslangic,
            kapanisAt: _bitis,
            maddeler: maddeler,
            hedefRoller: _secilenRoller.toList(),
            // AYRIM GORUNMUYORSA GONDERILMEZ: gizli kalmis bir deger
            // sunucuya gitseydi kullanicinin gormedigi bir suzgec
            // uygulanirdi.
            hedefSakinTipi: _sakinAyrimiAnlamli ? _sakinTipi : null,
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
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(l10n.anketMaddeler,
                  style: Theme.of(context).textTheme.labelLarge),
            ),
            for (var i = 0; i < _maddeler.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: Key('anket-madde-$i'),
                        controller: _maddeler[i],
                        decoration: InputDecoration(
                          labelText: l10n.anketSecenekNo('${i + 1}'),
                        ),
                      ),
                    ),
                    IconButton(
                      key: Key('anket-madde-sil-$i'),
                      icon: const Icon(Icons.close),
                      tooltip: _maddeler.length <= 2
                          ? l10n.anketEnAzIki
                          : l10n.anketSecenekSil,
                      onPressed: _maddeler.length <= 2 || _mesgul
                          ? null
                          : () => setState(() => _maddeler.removeAt(i).dispose()),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const Key('anket-madde-ekle'),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.anketSecenekEkle),
                  onPressed: _mesgul
                      ? null
                      : () => setState(
                          () => _maddeler.add(TextEditingController())),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l10n.anketMaddeIpucu,
                  style: Theme.of(context).textTheme.bodySmall),
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
            // TARIH ARALIGI — IKISI DE OPSIYONEL. Bos = hemen acik,
            // suresiz; en sik kullanilan hal budur, bu yuzden zorunlu
            // degil ve varsayilan da doldurulmuyor.
            _TarihSatiri(
              anahtar: 'anket-baslangic',
              etiket: l10n.anketBaslangic,
              deger: _baslangic,
              onSec: () async {
                final t = await _tarihSec(_baslangic);
                if (t != null) setState(() => _baslangic = t);
              },
              onTemizle: () => setState(() => _baslangic = null),
            ),
            _TarihSatiri(
              anahtar: 'anket-bitis',
              etiket: l10n.anketBitis,
              deger: _bitis,
              onSec: () async {
                final t = await _tarihSec(_bitis);
                if (t != null) setState(() => _bitis = t);
              },
              onTemizle: () => setState(() => _bitis = null),
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
            // MALIK/KIRACI AYRIMI — yalniz sakin hedeflendiginde cizilir.
            if (_sakinAyrimiAnlamli)
              DropdownButtonFormField<String>(
                key: const Key('anket-sakin-tipi'),
                initialValue: _sakinTipi,
                isExpanded: true,
                decoration:
                    InputDecoration(labelText: l10n.anketHedefSakinTipi),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.anketSakinHepsi)),
                  DropdownMenuItem(value: 'malik', child: Text(l10n.anketMalik)),
                  DropdownMenuItem(
                      value: 'kiraci', child: Text(l10n.anketKiraci)),
                ],
                onChanged: (v) => setState(() => _sakinTipi = v),
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

/// Tarih satiri — SECILMEMISSE "Tarih seç", secilmisse deger + temizle.
///
/// Ayri widget: ayni yerlesim iki kez (baslangic/bitis) ciziliyor ve
/// kopyalamak, birinde yapilan bir duzeltmenin otekinde unutulmasi
/// demekti.
class _TarihSatiri extends StatelessWidget {
  const _TarihSatiri({
    required this.anahtar,
    required this.etiket,
    required this.deger,
    required this.onSec,
    required this.onTemizle,
  });

  final String anahtar;
  final String etiket;
  final DateTime? deger;
  final Future<void> Function() onSec;
  final VoidCallback onTemizle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: TextButton.icon(
            key: Key(anahtar),
            icon: const Icon(Icons.event_outlined),
            label: Text(
              deger == null
                  ? '$etiket — ${l10n.anketTarihSec}'
                  : '$etiket: ${tarihSaatBicimi(deger!, context.dilKodu)}',
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: () => onSec(),
          ),
        ),
        if (deger != null)
          IconButton(
            key: Key('$anahtar-temizle'),
            icon: const Icon(Icons.close),
            tooltip: l10n.anketTarihTemizle,
            onPressed: onTemizle,
          ),
      ],
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
