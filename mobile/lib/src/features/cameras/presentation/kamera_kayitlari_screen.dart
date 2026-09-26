import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/bos_durum.dart';
import '../../auth/data/token_storage.dart';
import '../data/cameras_api.dart';
import '../data/kamera_kayit_api.dart';
import '../domain/camera_models.dart';
import '../domain/kayit_penceresi.dart';
import 'kayit_oynatici_screen.dart';

/// (P248 §1-kamera) GECMIS KAMERA KAYDI — web `kamera-kayitlari` sayfasinin
/// mobil ikizi.
///
/// NEDEN MOBILDE: P213'te yalniz web'deydi; P248'de guvenlik amiri web'e
/// GIREMIYOR (mobil-yalniz rol). Kullanici karari "(a) Mobile getir".
///
/// SUNUCU AYNEN: rol kapisi (`admin/yonetici/guvenlik_amiri`), 24 saat
/// pencere siniri ve her arama/izlemenin denetim kaydi sunucuda. Ekran
/// yetki UYGULAMAZ; yalniz menu gorunurlugu ayni kumeye ayarlidir.
///
/// KAYITLAR SITENIN NVR'INDA: burada arama "hangi saatler dolu" sorusunu
/// NVR'a iletir. `arama_destekli=false` "KAYIT YOK" DEMEK DEGIL (`sablon`
/// saglayicisi arayamaz ama oynatir) — iki durum AYRI mesaj alir.
class KameraKayitlariScreen extends ConsumerStatefulWidget {
  const KameraKayitlariScreen({
    super.key,
    @visibleForTesting this.ilkBas,
    @visibleForTesting this.ilkBit,
    @visibleForTesting this.saat,
    @visibleForTesting this.tokenOkuyucu,
    @visibleForTesting this.controllerYapici,
  });

  /// Testte pencereyi secici acmadan kurmak icin (uretimde null: son 1 saat).
  final DateTime? ilkBas;
  final DateTime? ilkBit;

  /// "Simdi" kaynagi — testte sabit.
  final DateTime Function()? saat;

  /// Oynaticiya iletilir (bkz. [KayitOynaticiScreen]).
  final Future<String?> Function()? tokenOkuyucu;
  final KayitControllerYapici? controllerYapici;

  @override
  ConsumerState<KameraKayitlariScreen> createState() =>
      _KameraKayitlariScreenState();
}

/// Yalniz kaydi ACIK kameralar (web ile ayni suzgec). Sunucu listeyi rol
/// gorunurlugune gore zaten suzer; burada ek olarak `kayit_aktif`.
final kayitKameralariProvider =
    FutureProvider.autoDispose<List<Camera>>((ref) async {
  final liste = await ref.watch(camerasApiProvider).fetch();
  return [for (final k in liste) if (k.kayitAktif) k];
});

class _KameraKayitlariScreenState extends ConsumerState<KameraKayitlariScreen> {
  String? _kameraId;
  late DateTime _bas;
  late DateTime _bit;
  KayitPencereHatasi? _pencereHatasi;
  bool _araniyor = false;
  String? _aramaHatasi;
  KayitAramaSonucu? _sonuc;

  /// Aramanin YAPILDIGI pencere — serit bunu cizer. Kullanici arama
  /// sonrasinda saati degistirirse serit eski pencereye gore kalmamali;
  /// bu yuzden secim degisince sonuc temizlenir.
  DateTime? _arananBas;
  DateTime? _arananBit;

  DateTime _simdi() => (widget.saat ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final simdi = _simdi();
    // Varsayilan: SON BIR SAAT, dakikaya yuvarlanmis. Amirin en sik
    // sorusu "az once ne oldu"dur; web'in sabit 08:00-09:00'u mobilde
    // her acilista iki secim daha demekti.
    final yuvarlak = DateTime(
        simdi.year, simdi.month, simdi.day, simdi.hour, simdi.minute);
    _bit = widget.ilkBit ?? yuvarlak;
    _bas = widget.ilkBas ?? yuvarlak.subtract(const Duration(hours: 1));
  }

  Camera? _secili(List<Camera> liste) {
    if (liste.isEmpty) return null;
    return liste.firstWhere((k) => k.id == _kameraId,
        orElse: () => liste.first);
  }

  void _secimDegisti() {
    _sonuc = null;
    _aramaHatasi = null;
    _pencereHatasi = null;
  }

  Future<void> _zamanSec({required bool baslangic}) async {
    final ilk = baslangic ? _bas : _bit;
    final simdi = _simdi();
    final gun = await showDatePicker(
      context: context,
      initialDate: ilk.isAfter(simdi) ? simdi : ilk,
      firstDate: simdi.subtract(const Duration(days: 366)),
      lastDate: simdi,
    );
    if (gun == null || !mounted) return;
    final saat = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(ilk),
    );
    if (saat == null || !mounted) return;
    final yeni = DateTime(gun.year, gun.month, gun.day, saat.hour, saat.minute);
    setState(() {
      if (baslangic) {
        _bas = yeni;
      } else {
        _bit = yeni;
      }
      _secimDegisti();
    });
  }

  /// Pencere istemcide de denetlenir — sunucuya gidip 422 alacak bir
  /// istek icin kullaniciyi bekletmemek icin. Yetki/sinir SUNUCUDA.
  bool _pencereGecerli() {
    final h = kayitPenceresiDenetle(_bas, _bit, simdi: _simdi());
    setState(() => _pencereHatasi = h);
    return h == null;
  }

  Future<void> _ara(Camera kamera) async {
    if (!_pencereGecerli()) return;
    setState(() {
      _araniyor = true;
      _aramaHatasi = null;
      _sonuc = null;
    });
    try {
      final s = await ref
          .read(kameraKayitApiProvider)
          .araliklar(kamera.id, _bas, _bit);
      if (!mounted) return;
      setState(() {
        _sonuc = s;
        _arananBas = _bas;
        _arananBit = _bit;
      });
    } on ApiException catch (e) {
      // Sunucu TANILI mesaj doner ("cihaza ulasilamadi", "cihaz
      // beklenmeyen yanit verdi"); genel cumleye indirgemek amiri yanlis
      // yere bakmaya gonderirdi (web ile ayni karar).
      if (mounted) setState(() => _aramaHatasi = apiHataMetni(context.l10n, e));
    } finally {
      if (mounted) setState(() => _araniyor = false);
    }
  }

  Future<void> _izle(Camera kamera, DateTime bas, DateTime bit) async {
    if (kayitPenceresiDenetle(bas, bit, simdi: _simdi()) != null) {
      _pencereGecerli();
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => KayitOynaticiScreen(
        kamera: kamera,
        aralikBas: bas,
        aralikBit: bit,
        tokenOkuyucu: widget.tokenOkuyucu ??
            () => ref.read(tokenStorageProvider).readAccessToken(),
        controllerYapici: widget.controllerYapici,
      ),
    ));
  }

  String _pencereHataMetni(KayitPencereHatasi h) {
    final l10n = context.l10n;
    return switch (h) {
      KayitPencereHatasi.ters => l10n.kamKayitHataTers,
      KayitPencereHatasi.genis => l10n.kamKayitHataGenis,
      KayitPencereHatasi.gelecek => l10n.kamKayitHataGelecek,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(kayitKameralariProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.modulKameraKayitlari, context.dilKodu)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            BosDurum(
              ikon: Icons.error_outline,
              baslik: l10n.kameraListeHata,
              aciklama: e is ApiException ? apiHataMetni(l10n, e) : null,
            ),
          ],
        ),
        data: (liste) {
          final secili = _secili(liste);
          if (secili == null) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                BosDurum(
                  key: const Key('kayit-kamera-yok'),
                  ikon: Icons.video_library_outlined,
                  baslik: l10n.kamKayitKameraYok,
                  aciklama: l10n.kamKayitKameraYokAlt,
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(l10n.kamKayitAlt,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('kayit-kamera'),
                initialValue: secili.id,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.kamKayitKamera),
                items: [
                  for (final k in liste)
                    DropdownMenuItem(
                      value: k.id,
                      child: Text(k.ad, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _kameraId = v;
                  _secimDegisti();
                }),
              ),
              const SizedBox(height: 8),
              _ZamanSatiri(
                key: const Key('kayit-bas'),
                etiket: l10n.kamKayitBaslangic,
                zaman: _bas,
                onTap: () => _zamanSec(baslangic: true),
              ),
              _ZamanSatiri(
                key: const Key('kayit-bit'),
                etiket: l10n.kamKayitBitis,
                zaman: _bit,
                onTap: () => _zamanSec(baslangic: false),
              ),
              if (_pencereHatasi != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _pencereHataMetni(_pencereHatasi!),
                    key: const Key('kayit-pencere-hata'),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('kayit-ara'),
                    onPressed: _araniyor ? null : () => _ara(secili),
                    icon: const Icon(Icons.search),
                    label: Text(l10n.kamKayitAra),
                  ),
                  OutlinedButton.icon(
                    key: const Key('kayit-izle-tumu'),
                    onPressed: () => _izle(secili, _bas, _bit),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l10n.kamKayitTumunuIzle),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(l10n.kamKayitKvkkNot,
                  style: Theme.of(context).textTheme.bodySmall),
              if (_araniyor)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_aramaHatasi != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: BosDurum(
                    key: const Key('kayit-arama-hata'),
                    ikon: Icons.error_outline,
                    baslik: l10n.kamKayitAlinamadi,
                    aciklama: _aramaHatasi,
                  ),
                ),
              if (_sonuc != null) ..._sonucGovdesi(secili, _sonuc!),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _sonucGovdesi(Camera kamera, KayitAramaSonucu s) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    if (!s.aramaDestekli) {
      // "Arayamiyorum" ile "kayit yok" AYRI seyler.
      return [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: BosDurum(
            key: const Key('kayit-arama-yok'),
            ikon: Icons.help_outline,
            baslik: l10n.kamKayitAramaYok,
            aciklama: l10n.kamKayitAramaYokAciklama,
          ),
        ),
      ];
    }
    if (s.araliklar.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: BosDurum(
            key: const Key('kayit-bulunamadi'),
            ikon: Icons.videocam_off_outlined,
            baslik: l10n.kamKayitBulunamadi,
            aciklama: l10n.kamKayitBulunamadiAciklama,
          ),
        ),
      ];
    }
    final pb = _arananBas!;
    final ps = _arananBit!;
    final parcalar = kayitSeridi(pb, ps, [
      for (final a in s.araliklar) (bas: a.bas.toLocal(), bit: a.bit.toLocal()),
    ]);
    // Pencere birden fazla gune tasiyorsa saat yetmez; tarih de yazilir.
    final gunAsiyor = pb.day != ps.day || pb.month != ps.month;
    String bicim(DateTime t) =>
        gunAsiyor ? tarihSaatBicimi(t, dil) : saatBicimi(t, dil);
    return [
      const SizedBox(height: 16),
      _KayitSeridi(bas: pb, bit: ps, parcalar: parcalar),
      const SizedBox(height: 8),
      for (final (i, p) in parcalar.indexed)
        Card(
          key: Key('kayit-parca-$i'),
          margin: const EdgeInsets.only(bottom: 8),
          color: p.dolu
              ? null
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ListTile(
            leading: Icon(
              p.dolu ? Icons.play_circle_outline : Icons.block,
              color: p.dolu ? Theme.of(context).colorScheme.primary : null,
            ),
            title: Text(l10n.kamKayitAralik(bicim(p.bas), bicim(p.bit))),
            subtitle: Text(p.dolu ? l10n.kamKayitDolu : l10n.kamKayitBosluk),
            // Boslugu oynatmak anlamsiz: NVR orada bir sey bulamaz.
            onTap: p.dolu ? () => _izle(kamera, p.bas, p.bit) : null,
          ),
        ),
    ];
  }
}

class _ZamanSatiri extends StatelessWidget {
  const _ZamanSatiri({
    super.key,
    required this.etiket,
    required this.zaman,
    required this.onTap,
  });

  final String etiket;
  final DateTime zaman;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.schedule),
      title: Text(etiket),
      subtitle: Text(tarihSaatBicimi(zaman, context.dilKodu)),
      trailing: const Icon(Icons.edit_calendar_outlined),
      onTap: onTap,
    );
  }
}

/// Pencerenin ORANTILI zaman seridi: dolu parcalar birincil renk,
/// bosluklar soluk. Dokunulmaz — asagidaki liste eylemi tasir; serit
/// "gunun neresi dolu" sorusunu tek bakista yanitlar.
class _KayitSeridi extends StatelessWidget {
  const _KayitSeridi({
    required this.bas,
    required this.bit,
    required this.parcalar,
  });

  final DateTime bas;
  final DateTime bit;
  final List<KayitParcasi> parcalar;

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final toplam = bit.difference(bas).inSeconds;
    return ClipRRect(
      key: const Key('kayit-serit'),
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 14,
        child: Row(
          children: [
            for (final p in parcalar)
              Expanded(
                // En az 1: cok kisa bir parca da gorunur kalsin.
                flex: toplam <= 0
                    ? 1
                    : (p.bit.difference(p.bas).inSeconds * 1000 ~/ toplam)
                        .clamp(1, 1000),
                child: ColoredBox(
                  color: p.dolu ? renk.primary : renk.surfaceContainerHighest,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
