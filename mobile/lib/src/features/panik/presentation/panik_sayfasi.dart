import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../data/panik_api.dart';
import '../domain/panik_models.dart';

/// (P240 §1) PANIK TETIKLEME SAYFASI.
///
/// =========================================================================
/// ROL BASINA FARKLI DUGMELER
/// =========================================================================
/// Tek bir "panik" dugmesi, uc farkli olayi tek alici kumesine
/// gonderirdi. Sunucudaki `TETIKLEYEBILIR` tablosunun aynasi burada;
/// gorunmeyen bir dugme, basinca 403 alacagi bir yol sunmamak icin.
///
/// =========================================================================
/// GERI SAYIM ISTEMCIDE, YAYIN SUNUCUDA
/// =========================================================================
/// Dugmeye basilinca alarm SUNUCUDA hemen yazilir (`beklemede`) ve
/// istemci geri sayar. Sayim bitince ISTEMCI HICBIR SEY YAPMAZ — yayini
/// sunucudaki gecikmeli gorev yapar. Boylece uygulama kapansa, ekran
/// sonse ya da ag kopsa bile alarm GIDER.
List<PanikTip> tetiklenebilirTipler(UserRole rol) => switch (rol) {
      UserRole.resident => const [PanikTip.sakin],
      UserRole.security ||
      UserRole.tesisGorevlisi =>
        const [PanikTip.guvenlik],
      UserRole.guvenlikAmiri => const [PanikTip.guvenlik],
      // Yoneticinin dairesi yoktur: `sakin` tipi gidilecek ADRES tasimaz.
      UserRole.yonetici ||
      UserRole.admin =>
        const [PanikTip.guvenlik, PanikTip.yoneticiAnons],
      UserRole.denetci || UserRole.unknown => const [],
    };

/// (P243 §5c) Kategori adi — aktif dilden.
String panikKategoriAdi(AppLocalizations l10n, PanikKategori k) =>
    switch (k) {
      PanikKategori.deprem => l10n.panikKategoriDeprem,
      PanikKategori.yangin => l10n.panikKategoriYangin,
      PanikKategori.gaz => l10n.panikKategoriGaz,
      PanikKategori.tahliye => l10n.panikKategoriTahliye,
      PanikKategori.saglik => l10n.panikKategoriSaglik,
      PanikKategori.guvenlikTehdidi => l10n.panikKategoriGuvenlikTehdidi,
      PanikKategori.diger => l10n.panikKategoriDiger,
    };

/// Kategorinin SIMGESI — metin okunmadan once taninsin.
IconData panikKategoriIkonu(PanikKategori k) => switch (k) {
      PanikKategori.deprem => Icons.vibration,
      PanikKategori.yangin => Icons.local_fire_department_outlined,
      PanikKategori.gaz => Icons.gas_meter_outlined,
      PanikKategori.tahliye => Icons.directions_run_outlined,
      PanikKategori.saglik => Icons.medical_services_outlined,
      PanikKategori.guvenlikTehdidi => Icons.shield_outlined,
      PanikKategori.diger => Icons.report_outlined,
    };

/// Kategori KIME gidiyor — secim aninda YAZILI.
///
/// Kullanici "deprem" derken tum siteye seslendigini BILMELI; bunu
/// gondermeden once soylemek, gonderdikten sonra soylemekten baska bir
/// seydir.
bool panikSiteGeneli(PanikKategori k) => const {
      PanikKategori.deprem,
      PanikKategori.yangin,
      PanikKategori.gaz,
      PanikKategori.tahliye,
    }.contains(k);

/// Rol SOS girisini gorur mu — `tetiklenebilirTipler`in tek satirlik
/// aynasi. Ayri bir liste tutmak, birinin guncellenip otekinin eskimesi
/// demekti (denetci ve bilinmeyen rol tetikleyemez).
bool panikGorunur(UserRole rol) => tetiklenebilirTipler(rol).isNotEmpty;

String panikTipAdi(AppLocalizations l10n, PanikTip tip) => switch (tip) {
      PanikTip.sakin => l10n.panikTipSakin,
      PanikTip.guvenlik => l10n.panikTipGuvenlik,
      PanikTip.yoneticiAnons => l10n.panikTipAnons,
    };

class PanikSayfasi extends ConsumerStatefulWidget {
  const PanikSayfasi({super.key});

  @override
  ConsumerState<PanikSayfasi> createState() => _PanikSayfasiState();
}

class _PanikSayfasiState extends ConsumerState<PanikSayfasi> {
  PanikAlarm? _alarm;
  int _kalan = 0;
  Timer? _sayac;
  bool _mesgul = false;
  String? _hata;

  @override
  void dispose() {
    _sayac?.cancel();
    super.dispose();
  }

  /// (P243 §5c) SECILI KATEGORI — tetiklemeden ONCE secilir.
  PanikKategori? _kategori;

  Future<void> _tetikle(PanikTip tip) async {
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      final alarm =
          await ref.read(panikApiProvider).tetikle(tip, kategori: _kategori);
      if (!mounted) return;
      // (E2E 2026-09) ZATEN ACIK ALARM: sunucu tekrar basista YENI alarm
      // uretmez, mevcudunu doner. O alarm coktan yayinlanmistir — 5 sn
      // geri sayim gostermek (ve "iptal"e bastirip yanlis alarm uretmek)
      // yaniltici. Kullaniciya durumu soyle, sayaci baslatma.
      if (alarm.durum != 'beklemede') {
        setState(() {
          _alarm = null;
          _kalan = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.panikZatenAcik)),
        );
        return;
      }
      setState(() {
        _alarm = alarm;
        _kalan = alarm.iptalPenceresiSn;
      });
      _sayac?.cancel();
      _sayac = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _kalan = _kalan > 0 ? _kalan - 1 : 0);
        if (_kalan == 0) t.cancel();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _hata = apiHataMetni(context.l10n, e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _iptal() async {
    final alarm = _alarm;
    if (alarm == null) return;
    setState(() => _mesgul = true);
    final l10n = context.l10n;
    final mesajci = ScaffoldMessenger.of(context);
    try {
      final y = await ref.read(panikApiProvider).iptal(alarm.id);
      if (!mounted) return;
      _sayac?.cancel();
      setState(() {
        _alarm = null;
        _kalan = 0;
      });
      mesajci.showSnackBar(SnackBar(
        content: Text(y.durum == 'iptal'
            ? l10n.panikIptalEdildi
            : l10n.panikYanlisAlarmGonderildi),
      ));
    } on ApiException catch (e) {
      if (mounted) setState(() => _hata = apiHataMetni(l10n, e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rol = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    final tipler = tetiklenebilirTipler(rol);
    final alarm = _alarm;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.panikBaslik)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_hata != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_hata!,
                    key: const Key('panik-hata'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (alarm == null) ...[
              // YASAL SINIR — DUGMELERDEN ONCE.
              //
              // "Bu sistem 112/155 yerine gecmez" cumlesi alarmi
              // BASTIKTAN SONRA gosterilseydi, en kritik anda okunmazdi.
              Text(
                l10n.panikYasalUyari,
                key: const Key('panik-yasal'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              // (P243 §5c) KATEGORI SECIMI — TIPLERDEN ONCE.
              //
              // Once "ne oluyor" sorulur, sonra alarm basilir. Tersi
              // olsaydi (once bas, sonra kategori sor) alarm ZATEN
              // gitmis olurdu ve kategori metni artik kimseye
              // ulasmazdi.
              Text(
                l10n.panikKategoriSec,
                key: const Key('panik-kategori-baslik'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                l10n.panikKategoriSecAciklama,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in PanikKategori.values)
                    ChoiceChip(
                      key: Key('panik-kategori-${k.kimlik}'),
                      avatar: Icon(panikKategoriIkonu(k), size: 18),
                      label: Text(panikKategoriAdi(l10n, k)),
                      selected: _kategori == k,
                      onSelected: (secildi) =>
                          setState(() => _kategori = secildi ? k : null),
                    ),
                ],
              ),
              if (_kategori != null) ...[
                const SizedBox(height: 8),
                // KIME GIDECEGI SECIM ANINDA YAZILI: gonderdikten sonra
                // soylemek, kullaniciyi bilmedigi bir karara ortak
                // etmekti.
                Text(
                  panikSiteGeneli(_kategori!)
                      ? l10n.panikKategoriSiteGeneli
                      : l10n.panikKategoriEkip,
                  key: const Key('panik-kategori-kapsam'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              for (final tip in tipler)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FilledButton(
                    key: Key('panik-tip-${tip.kimlik}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                      // DOKUNMA HEDEFI BUYUK: acil durumda titreyen bir
                      // parmak kucuk bir dugmeyi isabet ettiremez.
                      minimumSize: const Size.fromHeight(64),
                    ),
                    onPressed: _mesgul ? null : () => _tetikle(tip),
                    child: Text(panikTipAdi(l10n, tip)),
                  ),
                ),
              if (tipler.isEmpty)
                Text(l10n.panikYetkiYok, key: const Key('panik-yetki-yok')),
            ] else ...[
              Text(
                _kalan > 0
                    ? l10n.panikGonderiliyor(_kalan)
                    : l10n.panikGonderildi,
                key: const Key('panik-geri-sayim'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(l10n.panikIptalAciklama),
              const SizedBox(height: 16),
              OutlinedButton(
                key: const Key('panik-iptal'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: _mesgul ? null : _iptal,
                child: Text(l10n.panikIptalEt),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
