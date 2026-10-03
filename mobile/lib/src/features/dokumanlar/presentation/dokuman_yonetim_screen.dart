import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/dosya/dosya_secici.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/girdi_siniri.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/liste_ekrani.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../../../core/ui/olustur_paylas.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../../tasks/presentation/task_complete_controller.dart' show imagePickerProvider;
import '../data/dokuman_yonetim_api.dart';
import '../domain/dokuman_models.dart';
import 'dokuman_screen.dart';

/// (P253 A1) "Dokümanlar" girisi ROLE GORE ayrilir: yonetim TUM arsivi
/// yonetir (web `/dokumanlar` ikizi), sakin yalniz kendisine acilanlari
/// gorur ([DokumanScreen]). Rol jetondan (aktif mod) okunur; rol gecisi
/// zaten butun kabi yeniden kurar.
class DokumanlarGirisi extends ConsumerWidget {
  const DokumanlarGirisi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rol = ref.watch(currentUserRoleProvider).value;
    if (rol == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return rol == UserRole.admin || rol == UserRole.yonetici
        ? const DokumanYonetimScreen()
        : const DokumanScreen();
  }
}

/// (P253 A1) DOKUMAN ARSIVI — YONETIM.
///
/// Web ile AYNI eylemler: liste, yukle, indir (burada PAYLAS: dosya
/// telefona inip sistemin paylas menusune verilir), sakine ac/kapat, sil.
/// Duzenlenebilir tek alan GORUNURLUKTUR (sunucu sozlesmesi): adi
/// degistirmek sakinin indirdigi dosyayla listedeki adi ayristirirdi.
class DokumanYonetimScreen extends ConsumerStatefulWidget {
  const DokumanYonetimScreen({super.key});

  @override
  ConsumerState<DokumanYonetimScreen> createState() => _DokumanYonetimScreenState();
}

class _DokumanYonetimScreenState extends ConsumerState<DokumanYonetimScreen> {
  final _liste = GlobalKey<ListeEkraniState<YonetimDokumani>>();

  DokumanYonetimApi get _api => ref.read(dokumanYonetimApiProvider);

  void _bildir(String metin) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(metin)));

  String _hata(Object e) {
    final l10n = context.l10n;
    return e is ApiException ? apiHataMetni(l10n, e) : akisHataMetni(l10n, AkisHatasi.beklenmeyen);
  }

  Future<void> _paylas(YonetimDokumani d) async {
    await olusturVePaylas(
      context,
      konu: d.ad,
      olustur: () async {
        final b = await _api.baglanti(d.id);
        final baytlar = await _api.baytlar(b.url);
        return PaylasimDosyasi(
          baytlar: baytlar,
          dosyaAdi: b.dosyaAdi ?? d.ad,
          mimeTuru: d.icerikTipi ?? dokumanVarsayilanTur,
        );
      },
    );
  }

  Future<void> _gorunurluk(YonetimDokumani d) async {
    final l10n = context.l10n;
    try {
      await _api.gorunurluk(d.id, sakineAcik: !d.sakineAcik);
      _bildir(d.sakineAcik ? l10n.dokSakineKapatildi : l10n.dokSakineAcildi);
      await _liste.currentState?.yenile();
    } catch (e) {
      _bildir(_hata(e));
    }
  }

  Future<void> _sil(YonetimDokumani d) async {
    final l10n = context.l10n;
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        key: const Key('dok-sil-onay'),
        title: Text(l10n.dokSilBaslik),
        content: Text(l10n.dokSilOnay(d.ad)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.ortakVazgec)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l10n.ortakSil),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    try {
      await _api.sil(d.id);
      _bildir(l10n.dokSilindi);
      await _liste.currentState?.yenile();
    } catch (e) {
      _bildir(_hata(e));
    }
  }

  Future<void> _yukle() async {
    final yuklendi = await merkezSayfaAc<bool>(
      context,
      builder: (_) => const DokumanYukleFormu(),
    );
    if (yuklendi == true && mounted) {
      _bildir(context.l10n.dokYuklendi);
      await _liste.currentState?.yenile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListeEkrani<YonetimDokumani>(
      key: _liste,
      baslik: l10n.dokumanBaslik,
      kimlik: (d) => d.id,
      bosMetin: (l) => l.dokYonetimBos,
      yukle: (s) async {
        final (ogeler, toplam) = await _api.liste(offset: s.offset, limit: s.limit);
        return ListeSayfasi(ogeler, toplam: toplam);
      },
      fab: FloatingActionButton.extended(
        key: const Key('dok-yukle'),
        onPressed: _yukle,
        icon: const Icon(Icons.upload_file),
        label: Text(l10n.dokYukle),
      ),
      kart: (context, d, _) => ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(d.ad),
        subtitle: Text([
          tarihBicimi(d.createdAt.toLocal(), context.dilKodu),
          if (d.boyutBayt != null) l10n.dokumanBoyutKb((d.boyutBayt! / 1024).ceil()),
          d.sakineAcik ? l10n.dokSakineAcik : l10n.dokYalnizYonetim,
        ].join(' · ')),
        trailing: PopupMenuButton<String>(
          key: Key('dok-menu-${d.id}'),
          onSelected: (s) => switch (s) {
            'paylas' => _paylas(d),
            'gorunurluk' => _gorunurluk(d),
            _ => _sil(d),
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'paylas', child: Text(l10n.dokPaylas)),
            PopupMenuItem(
              value: 'gorunurluk',
              child: Text(d.sakineAcik ? l10n.dokSakineKapat : l10n.dokSakineAc),
            ),
            PopupMenuItem(value: 'sil', child: Text(l10n.ortakSil)),
          ],
        ),
      ),
    );
  }
}

/// Yukleme formu (merkez pencere). Dosya: FOTOGRAF (kamera ya da galeri)
/// ya da (P253 Asama 2) telefondaki bir PDF (`core/dosya/dosya_secici.dart`).
/// Secici yalniz sunucunun kabul ettigi turleri gosterir: belge bileti
/// PDF ve gorsel kabul eder (`PresignRequest`), baska tur 422 olurdu.
class DokumanYukleFormu extends ConsumerStatefulWidget {
  const DokumanYukleFormu({super.key});

  @override
  ConsumerState<DokumanYukleFormu> createState() => _DokumanYukleFormuState();
}

class _DokumanYukleFormuState extends ConsumerState<DokumanYukleFormu> {
  final _ad = TextEditingController();
  final _aciklama = TextEditingController();
  YuklenecekDosya? _dosya;
  bool _sakineAcik = false;
  bool _mesgul = false;
  String? _hata;

  @override
  void dispose() {
    _ad.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  static String _tur(String ad) {
    final u = ad.toLowerCase();
    if (u.endsWith('.png')) return 'image/png';
    if (u.endsWith('.webp')) return 'image/webp';
    if (u.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  Future<void> _sec(ImageSource kaynak) async {
    final l10n = context.l10n;
    final f = await ref.read(imagePickerProvider).pickImage(source: kaynak, imageQuality: 85);
    if (f == null) return;
    final baytlar = await f.readAsBytes();
    if (!mounted) return;
    if (baytlar.length > dokumanAzamiBayt) {
      setState(() => _hata = l10n.dokCokBuyuk);
      return;
    }
    setState(() {
      _hata = null;
      _dosya = YuklenecekDosya(baytlar: baytlar, icerikTipi: f.mimeType ?? _tur(f.name), dosyaAdi: f.name);
      if (_ad.text.trim().isEmpty) _ad.text = f.name;
    });
  }

  /// (P253 Asama 2) Telefondaki PDF.
  Future<void> _dosyaSec() async {
    final l10n = context.l10n;
    final f = await ref.read(dosyaSeciciProvider).sec(uzantilar: const ['pdf']);
    if (f == null || !mounted) return;
    if (f.baytlar.length > dokumanAzamiBayt) {
      setState(() => _hata = l10n.dokCokBuyuk);
      return;
    }
    setState(() {
      _hata = null;
      _dosya = YuklenecekDosya(baytlar: f.baytlar, icerikTipi: f.icerikTipi, dosyaAdi: f.ad);
      if (_ad.text.trim().isEmpty) _ad.text = f.ad;
    });
  }

  Future<void> _gonder() async {
    final d = _dosya;
    if (d == null) return;
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      await ref.read(dokumanYonetimApiProvider).yukle(
            dosya: d,
            ad: _ad.text.trim().isEmpty ? d.dosyaAdi : _ad.text.trim(),
            aciklama: _aciklama.text.trim().isEmpty ? null : _aciklama.text.trim(),
            sakineAcik: _sakineAcik,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final l10n = context.l10n;
      setState(() {
        _mesgul = false;
        _hata = e is ApiException ? apiHataMetni(l10n, e) : akisHataMetni(l10n, AkisHatasi.beklenmeyen);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ikincil = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.dokYukle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(l10n.dokYukleNot, style: TextStyle(fontSize: 12, color: ikincil)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('dok-kamera'),
                onPressed: _mesgul ? null : () => _sec(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(l10n.dokKamera),
              ),
              OutlinedButton.icon(
                key: const Key('dok-galeri'),
                onPressed: _mesgul ? null : () => _sec(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(l10n.dokGaleri),
              ),
              OutlinedButton.icon(
                key: const Key('dok-dosya'),
                onPressed: _mesgul ? null : _dosyaSec,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(l10n.dsyDosyaSec),
              ),
            ],
          ),
          if (_dosya != null) ...[
            const SizedBox(height: 8),
            Text(
              l10n.dokSecilen(_dosya!.dosyaAdi, (_dosya!.baytlar.length / 1024).ceil()),
              key: const Key('dok-secilen'),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            key: const Key('dok-ad'),
            controller: _ad,
            maxLength: GirdiSiniri.baslik,
            decoration: InputDecoration(labelText: l10n.dokAd, border: const OutlineInputBorder()),
          ),
          TextField(
            key: const Key('dok-aciklama'),
            controller: _aciklama,
            maxLength: 1000,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(labelText: l10n.dokAciklama, border: const OutlineInputBorder()),
          ),
          SwitchListTile(
            key: const Key('dok-sakine-acik'),
            contentPadding: EdgeInsets.zero,
            value: _sakineAcik,
            onChanged: _mesgul ? null : (v) => setState(() => _sakineAcik = v),
            title: Text(l10n.dokSakineAcik),
            subtitle: Text(l10n.dokSakineAcikIpucu),
          ),
          if (_hata != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_hata!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _mesgul ? null : () => Navigator.of(context).pop(false),
                child: Text(l10n.ortakVazgec),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('dok-gonder'),
                onPressed: _mesgul || _dosya == null ? null : _gonder,
                child: Text(l10n.dokYukle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
