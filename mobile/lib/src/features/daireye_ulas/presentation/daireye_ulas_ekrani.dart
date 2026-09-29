import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../../core/i18n/l10n.dart';
import '../../call/data/call_launcher.dart';
import '../../call/domain/tel_uri.dart';
import '../../visitors/data/visitor_api.dart';
import '../../visitors/domain/visitor_models.dart';
import '../../visitors/presentation/visitors_screen.dart' show ZiyaretciOnaySatiri;
import '../data/daireye_ulas_api.dart';
import '../data/ses_kaydedici.dart';

/// (P249 §3) DAIREYE ULAS — guvenlik daireyi secer, basamaklar YUKARIDAN
/// ASAGI denenir (docs/P249-kararlar.md §3.0):
///   1. ziyaretci onay talebi (3 dk),
///   2. sesli mesaj (basili tut, en fazla 60 sn),
///   3. telefon — YALNIZ sakin izin verdiyse; numara ekranda YAZILMAZ,
///      dugme dogrudan ceviriciyi acar ve acilis DENETIME yazilir.
/// Uygulama ici arama (§3c) onay bekleyen bir oneridir; bu ekranda YOK.
class DaireyeUlasEkrani extends ConsumerStatefulWidget {
  const DaireyeUlasEkrani({super.key});

  @override
  ConsumerState<DaireyeUlasEkrani> createState() => _DaireyeUlasEkraniState();
}

class _DaireyeUlasEkraniState extends ConsumerState<DaireyeUlasEkrani> {
  final _ara = TextEditingController();
  List<DaireArama> _sonuclar = const [];
  DaireArama? _secili;
  Timer? _gecikme;

  @override
  void dispose() {
    _ara.dispose();
    _gecikme?.cancel();
    super.dispose();
  }

  void _araDegisti(String q) {
    _gecikme?.cancel();
    _gecikme = Timer(const Duration(milliseconds: 300), () async {
      if (q.trim().isEmpty) {
        if (mounted) setState(() => _sonuclar = const []);
        return;
      }
      try {
        final l = await ref.read(visitorApiProvider).daireAra(q.trim());
        if (mounted) setState(() => _sonuclar = l);
      } on ApiException {
        if (mounted) setState(() => _sonuclar = const []);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.daireyeUlasBaslik)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('ulas-daire-ara'),
            controller: _ara,
            maxLength: 60,
            decoration: InputDecoration(
              labelText: l10n.daireyeUlasDaireAra,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onChanged: _araDegisti,
          ),
          if (_secili == null)
            for (final d in _sonuclar)
              ListTile(
                key: Key('ulas-sonuc-${d.id}'),
                leading: const Icon(Icons.door_front_door_outlined),
                title: Text(d.gorunenAd),
                subtitle: Text(d.sakinler.map((s) => s.ad).join(' · ')),
                onTap: () => setState(() => _secili = d),
              ),
          if (_secili != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.door_front_door),
              title: Text(_secili!.gorunenAd,
                  style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text('${l10n.daireyeUlasSakinler}: '
                  '${_secili!.sakinler.map((s) => s.ad).join(' · ')}'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _secili = null),
              ),
            ),
            _OnayAdimi(daire: _secili!),
            const Divider(height: 32),
            _SesAdimi(unitId: _secili!.id),
            const Divider(height: 32),
            _TelefonAdimi(unitId: _secili!.id),
          ],
        ],
      ),
    );
  }
}

// ------------------------------ 1. ONAY ----------------------------------- //
class _OnayAdimi extends ConsumerStatefulWidget {
  const _OnayAdimi({required this.daire});

  final DaireArama daire;

  @override
  ConsumerState<_OnayAdimi> createState() => _OnayAdimiState();
}

class _OnayAdimiState extends ConsumerState<_OnayAdimi> {
  final _ad = TextEditingController();
  Visitor? _kayit;
  Timer? _yoklama;
  bool _mesgul = false;
  String? _hata;

  @override
  void dispose() {
    _ad.dispose();
    _yoklama?.cancel();
    super.dispose();
  }

  Future<void> _iste() async {
    final sakinler = widget.daire.sakinler;
    if (_ad.text.trim().isEmpty || sakinler.isEmpty) return;
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      final v = await ref.read(visitorApiProvider).create(VisitorDraft(
            ziyaretciAd: _ad.text.trim(),
            unitNo: widget.daire.no,
            // Tek-hedef alani sema geregi; ONAY dairenin TUM sakinlerine gider.
            targetResidentUserId: sakinler.first.userId,
            onayIste: true,
          ));
      if (!mounted) return;
      setState(() => _kayit = v);
      // YOKLAMA 5 sn: yanit dakikalar icinde gelir, push guvenlige de gider.
      _yoklama = Timer.periodic(const Duration(seconds: 5), (_) async {
        final g = await ref.read(visitorApiProvider).getir(v.id);
        if (!mounted) return;
        setState(() => _kayit = g);
        if (!g.onayBekliyor) _yoklama?.cancel();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _hata = apiHataMetni(context.l10n, e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.daireyeUlasAdimOnay, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_kayit == null) ...[
          TextField(
            key: const Key('ulas-ziyaretci-ad'),
            controller: _ad,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: l10n.daireyeUlasZiyaretciAd,
              border: const OutlineInputBorder(),
            ),
          ),
          FilledButton.icon(
            key: const Key('ulas-onay-iste'),
            icon: const Icon(Icons.how_to_reg_outlined),
            label: Text(l10n.daireyeUlasOnayIste),
            onPressed: _mesgul ? null : _iste,
          ),
        ] else
          ZiyaretciOnaySatiri(visitor: _kayit!),
        if (_hata != null)
          Text(_hata!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    );
  }
}

// ------------------------------ 2. SES ------------------------------------ //
class _SesAdimi extends ConsumerStatefulWidget {
  const _SesAdimi({required this.unitId});

  final String unitId;

  @override
  ConsumerState<_SesAdimi> createState() => _SesAdimiState();
}

class _SesAdimiState extends ConsumerState<_SesAdimi> {
  static const _azami = Duration(seconds: 60);
  bool _kayitta = false;
  bool _gonderiliyor = false;
  bool _gonderildi = false;
  String? _hata;
  Timer? _sayac;
  /// Kayit suresi — 100 ms adimlarla sayilir (duvar saati degil: bir
  /// zaman dilimi degisikligi ya da saat esitlemesi sureyi bozmasin).
  int _ms = 0;
  int get _sn => _ms ~/ 1000;

  @override
  void dispose() {
    _sayac?.cancel();
    super.dispose();
  }

  Future<void> _basla() async {
    final k = ref.read(sesKaydediciProvider);
    if (!await k.izinVarMi()) {
      if (mounted) setState(() => _hata = context.l10n.sesliMesajMikrofonIzni);
      return;
    }
    await k.basla();
    if (!mounted) return;
    setState(() {
      _kayitta = true;
      _gonderildi = false;
      _hata = null;
      _ms = 0;
    });
    _sayac = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _ms += 100);
      // 60 SN SINIRI: kullanici birakmasa da kayit kesilir ve gonderilir.
      if (_ms >= _azami.inMilliseconds) _bitir();
    });
  }

  Future<void> _bitir() async {
    if (!_kayitta) return;
    _sayac?.cancel();
    final sure = Duration(milliseconds: _ms);
    setState(() {
      _kayitta = false;
      _gonderiliyor = true;
    });
    try {
      final ses = await ref.read(sesKaydediciProvider).bitir();
      // Yarim saniyeden kisa "basip birakma" gonderilmez.
      if (ses == null || sure.inMilliseconds < 500) return;
      final ms = sure > _azami ? _azami.inMilliseconds : sure.inMilliseconds;
      await ref.read(daireyeUlasApiProvider).sesGonder(widget.unitId, ses, ms);
      if (mounted) setState(() => _gonderildi = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _hata = apiHataMetni(context.l10n, e));
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.daireyeUlasAdimSes, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        // BASILI TUT (dokunma) + AC/KAPA (klavye). Ciplak GestureDetector
        // klavyeyle ulasilamazdi (klavye_kaynak_denetimi kilidi): dokunmada
        // parmak basinca kayit baslar, kalkinca gider; klavyede Enter/Bosluk
        // ilk basista baslatir, ikinci basista gonderir.
        FocusableActionDetector(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                if (_gonderiliyor) return null;
                _kayitta ? _bitir() : _basla();
                return null;
              },
            ),
          },
          child: Listener(
            key: const Key('ulas-ses-kaydet'),
            onPointerDown: (_) => _gonderiliyor || _kayitta ? null : _basla(),
            onPointerUp: (_) => _bitir(),
            onPointerCancel: (_) => _bitir(),
            child: Semantics(
              button: true,
              label: l10n.sesliMesajBasiliTut,
              child: Container(
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kayitta ? cs.error : cs.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_kayitta ? Icons.mic : Icons.mic_none,
                        color: _kayitta ? cs.onError : cs.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _kayitta ? l10n.sesliMesajKaydediliyor(_sn) : l10n.sesliMesajBasiliTut,
                        style: TextStyle(
                          color: _kayitta ? cs.onError : cs.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_gonderiliyor) const LinearProgressIndicator(),
        if (_gonderildi)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l10n.sesliMesajGonderildi,
                key: const Key('ulas-ses-gonderildi'),
                style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
          ),
        if (_hata != null)
          Text(_hata!, style: TextStyle(color: cs.error)),
      ],
    );
  }
}

// ----------------------------- 3. TELEFON --------------------------------- //
final _daireUlasProvider = FutureProvider.autoDispose.family<DaireUlas, String>(
  (ref, unitId) => ref.watch(daireyeUlasApiProvider).daire(unitId),
);

class _TelefonAdimi extends ConsumerWidget {
  const _TelefonAdimi({required this.unitId});

  final String unitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final durum = ref.watch(_daireUlasProvider(unitId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.daireyeUlasAdimTelefon, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        durum.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (d) {
            final izinli = d.sakinler.where((s) => s.telefonlaAranabilir).toList();
            if (izinli.isEmpty) return Text(l10n.daireyeUlasTelefonYok);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final s in izinli)
                  OutlinedButton.icon(
                    key: Key('ulas-telefon-${s.userId}'),
                    icon: const Icon(Icons.call),
                    // NUMARA YAZILMAZ: dugme dogrudan ceviriciyi acar.
                    label: Text(l10n.daireyeUlasTelefonAra(s.ad)),
                    onPressed: () async {
                      try {
                        final no = await ref
                            .read(daireyeUlasApiProvider)
                            .telefon(unitId, s.userId);
                        final uri = telUri(no);
                        if (uri != null) {
                          await ref.read(callLauncherProvider).dial(uri.toString());
                        }
                      } on ApiException catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(apiHataMetni(context.l10n, e))));
                        }
                      }
                    },
                  ),
                const SizedBox(height: 4),
                Text(l10n.daireyeUlasTelefonKayit,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            );
          },
        ),
      ],
    );
  }
}
