import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile/src/core/girdi_siniri.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/bos_durum.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../../tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;
import '../data/bakim_api.dart';
import '../domain/bakim_models.dart';

/// (P241 §1) PERIYODIK BAKIM — mobil.
///
/// =========================================================================
/// TELEFONDA LISTE, IZGARA DEGIL
/// =========================================================================
/// Web'de tablo var; burada her ekipman bir satir. Tabloyu kucultmek,
/// bes sutunu 360dp'ye sikistirmak olurdu.
///
/// =========================================================================
/// RENK TEK BASINA ANLAM TASIMAZ
/// =========================================================================
/// Durum rozetinin YANINDA gun sayisi yazili. Renk korlugu bir yana,
/// sahada gunes altinda okunan bir ekranda renk farki da kaybolur.
///
/// SAHA PERSONELI DE GORUR (sunucu izin veriyor): kapida duran kisi
/// "bugun asansor firmasi gelecek" bilgisini kullanir. Ama YAZAMAZ —
/// kayit girme dugmesi yalniz yonetimde cizilir.
class BakimEkrani extends ConsumerStatefulWidget {
  const BakimEkrani({super.key, this.yonetim});

  /// Kayit girebilen rol mu. VERILMEZSE oturumdaki rolden cozulur;
  /// test bunu dogrudan verebilsin diye opsiyonel.
  ///
  /// Sunucu da ayni siniri koyuyor (403); burada YALNIZ dugme
  /// gizleniyor — calismayacak bir dugme gostermemek icin.
  final bool? yonetim;

  @override
  ConsumerState<BakimEkrani> createState() => _BakimEkraniState();
}

class _BakimEkraniState extends ConsumerState<BakimEkrani> {
  String _durum = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final durumlar = <String, String>{
      '': l10n.bakimFiltreTumu,
      'gecikti': l10n.bakimDurumGecikti,
      'bugun': l10n.bakimDurumBugun,
      'yaklasti': l10n.bakimDurumYaklasti,
      'planli': l10n.bakimDurumPlanli,
    };
    final liste = ref.watch(bakimEkipmanlariProvider);
    final rol = ref.watch(currentUserRoleProvider).asData?.value;
    // ROL COZULENE KADAR YAZMA DUGMESI CIZILMEZ: yanlislikla
    // gosterilen bir dugme, basildiginda 403 verirdi.
    final yonetim = widget.yonetim ??
        (rol == UserRole.admin || rol == UserRole.yonetici);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bakimBaslik)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: const ValueKey('bakim-durum-suzgeci'),
                    initialValue: _durum,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.bakimFiltreDurum,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final e in durumlar.entries)
                        DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _durum = v ?? ''),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: liste.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (hepsi) {
                // SUZGEC ISTEMCIDE: liste zaten tumuyle cekiliyor
                // (site basina ekipman sayisi onlarla olculur) ve her
                // suzgec degisiminde agi beklemek, sahada kopuk
                // baglantida kullanilamaz bir ekran uretirdi.
                final gorunen = _durum.isEmpty
                    ? hepsi
                    : hepsi.where((e) => e.durum == _durum).toList();
                if (gorunen.isEmpty) {
                  return BosDurum(
                    ikon: Icons.build_outlined,
                    baslik: l10n.bakimEkipmanYok,
                    aciklama: l10n.bakimEkipmanYokAlt,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(bakimEkipmanlariProvider),
                  child: ListView.separated(
                    itemCount: gorunen.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) => _EkipmanKarti(
                      e: gorunen[i],
                      yonetim: yonetim,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String bakimDurumAdi(AppLocalizations l10n, String durum) => switch (durum) {
      'gecikti' => l10n.bakimDurumGecikti,
      'bugun' => l10n.bakimDurumBugun,
      'yaklasti' => l10n.bakimDurumYaklasti,
      _ => l10n.bakimDurumPlanli,
    };

Color bakimDurumRengi(ColorScheme renkler, String durum) => switch (durum) {
      'gecikti' => renkler.error,
      'bugun' || 'yaklasti' => renkler.tertiary,
      _ => renkler.outline,
    };

class _EkipmanKarti extends ConsumerWidget {
  const _EkipmanKarti({required this.e, required this.yonetim});

  final BakimEkipmani e;
  final bool yonetim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final renkler = Theme.of(context).colorScheme;
    // GUN SAYISI HER ZAMAN YAZILI: renk tek basina anlam tasimamali.
    final gun = e.kalanGun < 0
        ? l10n.bakimGecikmeGun(-e.kalanGun)
        : l10n.bakimKalanGun(e.kalanGun);
    return ListTile(
      key: ValueKey('bakim-ekipman-${e.id}'),
      // (E2E 2026-09) SATIR GECMISI ACAR — kayitlar ve ekleri (TESIS-05).
      // Onceden mobilde gecmis ve ek HICBIR yerde yoktu.
      onTap: () => merkezSayfaAc<void>(
        context,
        builder: (_) => BakimGecmisi(ekipman: e),
      ),
      leading: Icon(Icons.build_outlined,
          color: bakimDurumRengi(renkler, e.durum)),
      title: Text(e.yasal ? '${e.ad} · ${l10n.bakimYasal}' : e.ad),
      subtitle: Text(
        '${e.sonrakiBakim} · ${bakimDurumAdi(l10n, e.durum)} · $gun',
      ),
      trailing: yonetim
          ? TextButton(
              key: ValueKey('bakim-kayit-${e.id}'),
              onPressed: () async {
                final eklendi = await merkezSayfaAc<bool>(
                  context,
                  builder: (_) => _KayitFormu(ekipman: e),
                );
                if (eklendi ?? false) {
                  ref.invalidate(bakimEkipmanlariProvider);
                }
              },
              child: Text(l10n.bakimKayitEkle),
            )
          : null,
    );
  }
}

class _KayitFormu extends ConsumerStatefulWidget {
  const _KayitFormu({required this.ekipman});

  final BakimEkipmani ekipman;

  @override
  ConsumerState<_KayitFormu> createState() => _KayitFormuState();
}

class _KayitFormuState extends ConsumerState<_KayitFormu> {
  final _yapan = TextEditingController();
  final _islem = TextEditingController();
  final _tutar = TextEditingController();
  bool _gidereYaz = true;
  bool _bekliyor = false;
  DateTime _tarih = DateTime.now();
  XFile? _foto;

  Future<void> _fotoSec() async {
    final secilen = await ref.read(imagePickerProvider).pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          imageQuality: 80,
        );
    if (secilen != null && mounted) setState(() => _foto = secilen);
  }

  @override
  void dispose() {
    _yapan.dispose();
    _islem.dispose();
    _tutar.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    setState(() => _bekliyor = true);
    try {
      final kurus = _tutar.text.trim().isEmpty
          ? null
          : (double.tryParse(_tutar.text.replaceAll(',', '.')) ?? 0) * 100;
      final api = ref.read(bakimApiProvider);
      final kayit = await api.kayitEkle(
            widget.ekipman.id,
            BakimKaydiTaslak(
              tarih: _tarih.toIso8601String().substring(0, 10),
              yapanAd: _yapan.text.trim(),
              islem: _islem.text.trim(),
              tutarKurus: kurus?.round(),
              gidereYaz: _gidereYaz,
            ),
          );
      // (E2E 2026-09) FOTOGRAF KAYDI KIRMAZ: bakim YAZILDI; fotograf
      // yuklenemezse kullaniciya soylenir ama kayit geri alinmaz (gider
      // fisindeki karar).
      if (_foto != null) {
        try {
          await api.fotoEkle(
            kayitId: kayit.id,
            baytlar: await _foto!.readAsBytes(),
          );
        } on ApiException {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.bakimFotoYuklenemedi)),
            );
          }
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _bekliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.bakimKayitEkle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.ekipman.ad,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ListTile(
            key: const ValueKey('bakim-kayit-tarih'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.bakimKayitTarihi),
            subtitle: Text(_tarih.toIso8601String().substring(0, 10)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final secilen = await showDatePicker(
                context: context,
                initialDate: _tarih,
                firstDate: DateTime(2000),
                // (E2E 2026-09) Gelecek tarih sunucuda 422 (TESIS-06):
                // secicide de sunulmaz. Bir gun pay: UTC/yerel gun farki.
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (secilen != null) setState(() => _tarih = secilen);
            },
          ),
          TextField(
            key: const ValueKey('bakim-kayit-yapan'),
            inputFormatters: GirdiSiniri.sinir(GirdiSiniri.baslik), // sunucu: BakimKaydiCreate.yapan_ad
            controller: _yapan,
            decoration: InputDecoration(labelText: l10n.bakimYapan),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('bakim-kayit-islem'),
            // tek satirlik alan: sayac gizli (yerlesim degismez)
            inputFormatters: GirdiSiniri.sinir(4000), // sunucu: BakimKaydiCreate.islem
            controller: _islem,
            decoration: InputDecoration(labelText: l10n.bakimIslem),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('bakim-kayit-tutar'),
            inputFormatters: GirdiSiniri.sinir(GirdiSiniri.tutar),
            controller: _tutar,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.bakimTutar),
          ),
          SwitchListTile(
            key: const ValueKey('bakim-kayit-gidere'),
            contentPadding: EdgeInsets.zero,
            value: _gidereYaz,
            onChanged: (v) => setState(() => _gidereYaz = v),
            title: Text(l10n.bakimGidereYaz),
            subtitle: Text(l10n.bakimGidereYazIpucu),
          ),
          OutlinedButton.icon(
            key: const ValueKey('bakim-kayit-foto'),
            onPressed: _bekliyor ? null : _fotoSec,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(_foto == null ? l10n.bakimFotoEkle : l10n.bakimFotoHazir),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('bakim-kayit-kaydet'),
            onPressed: _bekliyor ? null : _kaydet,
            child: Text(l10n.ortakKaydet),
          ),
        ],
      ),
    );
  }
}


/// (E2E 2026-09) BIR EKIPMANIN BAKIM GECMISI + KAYIT EKLERI (TESIS-05).
///
/// Web'de "Gecmis" sekmesi ve ek penceresi var; mobilde ikisi de YOKTU —
/// sahada muayene raporunu gormek isteyen gorevli (sunucu ona OKUMA izni
/// veriyor) hicbir yerden ulasamiyordu.
class BakimGecmisi extends ConsumerWidget {
  const BakimGecmisi({super.key, required this.ekipman});

  final BakimEkipmani ekipman;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final kayitlar = ref.watch(bakimKayitlariProvider(ekipman.id));
    return Scaffold(
      appBar: AppBar(title: Text('${ekipman.ad} · ${l10n.bakimGecmis}')),
      body: kayitlar.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (liste) => liste.isEmpty
            ? BosDurum(
                ikon: Icons.history,
                baslik: l10n.bakimGecmisYok,
                aciklama: l10n.bakimGecmisYokAlt,
              )
            : ListView.separated(
                itemCount: liste.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final k = liste[i];
                  return ExpansionTile(
                    key: ValueKey('bakim-gecmis-${k.id}'),
                    title: Text(k.tarih),
                    subtitle: Text(
                      [k.yapanAd, k.islem]
                          .whereType<String>()
                          .where((x) => x.isNotEmpty)
                          .join(' · '),
                    ),
                    children: [_KayitEkleri(kayitId: k.id)],
                  );
                },
              ),
      ),
    );
  }
}

class _KayitEkleri extends ConsumerWidget {
  const _KayitEkleri({required this.kayitId});

  final String kayitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ekler = ref.watch(bakimEkleriProvider(kayitId));
    return ekler.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text('$e'),
      ),
      data: (liste) => liste.isEmpty
          ? ListTile(title: Text(l10n.bakimEkYok))
          : Column(
              children: [
                for (final ek in liste)
                  ListTile(
                    key: ValueKey('bakim-ek-${ek.id}'),
                    leading: Icon(ek.tur == 'not'
                        ? Icons.notes_outlined
                        : Icons.attach_file),
                    title: Text(
                      ek.tur == 'not' ? (ek.metin ?? '') : (ek.dosyaAdi ?? ''),
                    ),
                    trailing: ek.dosyaUrl == null
                        ? null
                        : const Icon(Icons.open_in_new),
                    onTap: ek.dosyaUrl == null
                        ? null
                        : () => launchUrl(
                              Uri.parse(ek.dosyaUrl!),
                              mode: LaunchMode.externalApplication,
                            ),
                  ),
              ],
            ),
    );
  }
}
