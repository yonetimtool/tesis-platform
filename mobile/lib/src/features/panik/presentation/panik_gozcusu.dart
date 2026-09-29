import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../../auth/data/current_user_provider.dart';
import '../../call/data/call_launcher.dart';
import '../../call/domain/tel_uri.dart';
import '../data/alarm_kanali.dart';
import '../data/panik_api.dart';
import '../domain/panik_models.dart';

/// (P240 §1) GELEN ALARM — TAM EKRAN, KAPATILAMAZ.
///
/// =========================================================================
/// NEREDE DURUYOR: `MaterialApp.builder` ZINCIRI
/// =========================================================================
/// `SurumKapisi` ile AYNI yerde ve ayni gerekceyle: tek bir ekrana
/// koymak, kullanicinin baska bir ekranda oldugu anda alarmi
/// KACIRMASI demekti. Builder zinciri cizilen HER ekranin ustune gecer.
///
/// NAVIGATOR KULLANILMAZ: builder Navigator'un USTUNDEDIR ve orada
/// `showDialog` cagirmak "No Navigator" hatasi verir (P237'de olculdu).
/// Bu yuzden uyari bir DIYALOG degil, agaca giren bir KATMANDIR.
///
/// =========================================================================
/// NEDEN KAPATILAMAZ
/// =========================================================================
/// Kapatilabilir bir uyari, yogun bir ekranda REFLEKSLE kapatilir ve
/// alarm hic okunmadan kaybolur. Ekran ancak bir KARAR verilince gider:
/// "gordum" ya da "gidiyorum". Ikisi de sunucuya yazilir ve takip olcumu
/// (kim gordu, kac saniyede mudahale edildi) bunlardan uretilir.
///
/// GERI TUSU DE KAPATMAZ (`PopScope`): Android'de geri tusu refleks
/// hareketidir ve uyariyi kapatmasi, "kapatilamaz" iddiasini bos
/// birakirdi.
///
/// =========================================================================
/// YOKLAMA: 15 SANIYE
/// =========================================================================
/// Push ZATEN aninda geliyor; bu katman push'un ULASMADIGI halleri
/// yakalar (uygulama acik ve on planda, bildirim izni kapali, ya da
/// FCM gecikmesi). 15 sn bir YEDEK yoldur, birincil yol degil — daha
/// sik yoklamak pil harcar ve kazandirdigi sure push'un yanında
/// anlamsizdir.
const Duration panikYoklamaAraligi = Duration(seconds: 15);

class PanikGozcusu extends ConsumerStatefulWidget {
  const PanikGozcusu({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PanikGozcusu> createState() => _PanikGozcusuState();
}

class _PanikGozcusuState extends ConsumerState<PanikGozcusu> {
  Timer? _zamanlayici;

  /// (P240 §1) YOKLAMA YALNIZ OTURUM VARKEN.
  ///
  /// Giris ekranindayken yoklamak iki sebeple yanlis: (a) uc 401 doner
  /// ve bos yere ag trafigi uretir; (b) uygulama daha ilk karesini
  /// cizerken arka planda calisan bir zamanlayici baslatir — acilista
  /// olculen titreme testleri bunu "bitmeyen is" olarak yakaladi
  /// (ilk yazimda tam olarak bu oldu ve test HAKLIYDI).
  void _zamanlayiciyiAyarla({required bool oturumVar}) {
    if (oturumVar && _zamanlayici == null) {
      _zamanlayici = Timer.periodic(panikYoklamaAraligi, (_) {
        if (mounted) ref.invalidate(panikAktifProvider);
      });
    } else if (!oturumVar && _zamanlayici != null) {
      _zamanlayici?.cancel();
      _zamanlayici = null;
    }
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // OTURUM YOKSA KATMAN HIC CALISMAZ: giris ekraninda alarm
    // gosterilecek bir kullanici yoktur.
    final oturumVar = ref.watch(currentUserIdProvider).value != null;
    _zamanlayiciyiAyarla(oturumVar: oturumVar);
    if (!oturumVar) return widget.child;

    // HATA SESSIZ: panik ucu 403 verirse (orn. denetci) ya da ag
    // kopmussa uygulama CALISMAYA DEVAM ETMELI. Uyari katmani bir
    // EKSTRADIR; onun hatasi uygulamayi rehin alamaz.
    final alarmlar = ref.watch(panikAktifProvider).value ?? const <PanikAlarm>[];
    final alarm = alarmlar.isEmpty ? null : alarmlar.first;
    return Stack(
      children: [
        widget.child,
        if (alarm != null)
          Positioned.fill(
            child: PanikAlarmKatmani(
              alarm: alarm,
              onKarar: () => ref.invalidate(panikAktifProvider),
            ),
          ),
      ],
    );
  }
}

class PanikAlarmKatmani extends ConsumerWidget {
  const PanikAlarmKatmani({
    super.key,
    required this.alarm,
    required this.onKarar,
  });

  final PanikAlarm alarm;
  final VoidCallback onKarar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      // GERI TUSU KAPATMAZ — "kapatilamaz" iddiasinin bedeli budur.
      canPop: false,
      child: PanikAlarmIcerigi(alarm: alarm, onKarar: onKarar),
    );
  }
}

/// (P249 §1b) ALARMIN KENDISI — tam ekran katman ve bildirimden acilan
/// ekran AYNI govdeyi cizer.
///
/// =========================================================================
/// IKI DENEYIM
/// =========================================================================
/// * TOPLU UYARI (deprem/yangin/gaz/tahliye): kimse "yardim" istemiyor;
///   herkese NE YAPACAGI soyleniyor. En ustte buyuk harfle kategori,
///   altinda ADIM ADIM talimat, yer ve saat. "Gidiyorum" burada
///   ANLAMSIZ; yerine GUVENDEYIM / YARDIMA IHTIYACIM VAR — tahliye
///   sayiminin kaynagi.
/// * YARDIM CAGRISI (saglik/guvenlik tehdidi/diger): bir kisi yardim
///   istiyor. Kim, nerede, telefon, kisa talimat; Gidiyorum / Gordum.
///
/// OLCULEN KUSUR (P243): model `kategori` alanini OKUMUYORDU ve bu ekran
/// sabit "ACIL DURUM CAGRISI" ciziyordu — deprem ile saglik acili ayni
/// ekrandi. Baslik ve talimat artik SUNUCUDAN gelir (tek kaynak).
///
/// KARAR VERILINCE ALARM SUSAR: Android'de alarm sesi dongude calar;
/// `AlarmKanali.sustur` olmadan karar verildikten sonra da calardi.
class PanikAlarmIcerigi extends ConsumerStatefulWidget {
  const PanikAlarmIcerigi({
    super.key,
    required this.alarm,
    required this.onKarar,
    this.eylemler = true,
  });

  final PanikAlarm alarm;
  final VoidCallback onKarar;

  /// Karar dugmeleri cizilsin mi (kapanmis alarmda cizilmez).
  final bool eylemler;

  @override
  ConsumerState<PanikAlarmIcerigi> createState() => _PanikAlarmIcerigiState();
}

class _PanikAlarmIcerigiState extends ConsumerState<PanikAlarmIcerigi> {
  bool _mesgul = false;

  Future<void> _isaretle(Future<PanikAlarm> Function() is_) async {
    setState(() => _mesgul = true);
    try {
      await is_();
      await ref.read(alarmKanaliProvider).sustur(widget.alarm.id);
      widget.onKarar();
    } catch (_) {
      // SESSIZ: karar sunucuya yazilamadiysa uyari EKRANDA KALIR —
      // kullanici tekrar dener. "Yazilamadi" diye kapatmak, alarmi
      // gormemis sayilan birinin ekranini temizlemek olurdu.
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alarm;
    final tema = Theme.of(context);
    final zemin = tema.colorScheme.error;
    final yazi = tema.colorScheme.onError;
    return Material(
      color: zemin.withValues(alpha: 0.97),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: yazi),
              child: a.toplu
                  ? _toplu(context, a, yazi)
                  : _yardimCagrisi(context, a, yazi),
            ),
          ),
        ),
      ),
    );
  }

  String _saat(DateTime? t) {
    if (t == null) return '';
    final y = t.toLocal();
    return '${y.hour.toString().padLeft(2, '0')}:${y.minute.toString().padLeft(2, '0')}';
  }

  Widget _baslik(BuildContext context, PanikAlarm a, Color yazi, {double? boy}) {
    return Text(
      a.baslik.isNotEmpty ? a.baslik : context.l10n.panikGelenAlarm,
      key: const Key('panik-tam-ekran'),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: yazi,
            fontWeight: FontWeight.w800,
            fontSize: boy,
          ),
    );
  }

  // ---------------------------- TOPLU UYARI ------------------------------ //
  Widget _toplu(BuildContext context, PanikAlarm a, Color yazi) {
    final l10n = context.l10n;
    final api = ref.read(panikApiProvider);
    final saat = _saat(a.gonderildiAt ?? a.createdAt);
    return Column(
      key: const Key('panik-toplu'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.warning_amber_rounded, size: 72, color: yazi),
        const SizedBox(height: 8),
        _baslik(context, a, yazi, boy: 34),
        const SizedBox(height: 8),
        Text(
          [a.yer, if (saat.isNotEmpty) l10n.panikAlarmSaati(saat)]
              .where((x) => x.isNotEmpty)
              .join(' · '),
          key: const Key('panik-toplu-yer'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: yazi),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.panikTalimatBaslik,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: yazi,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        for (final (i, adim) in a.talimat.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1}.',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: yazi,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    adim,
                    key: Key('panik-talimat-$i'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: yazi, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        if (a.benimYanitim != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              a.benimYanitim == 'guvende'
                  ? l10n.panikYanitGuvende
                  : l10n.panikYanitYardim,
              key: const Key('panik-benim-yanitim'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        if (widget.eylemler) ...[
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('panik-guvendeyim'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(64),
              backgroundColor: yazi,
              foregroundColor: Theme.of(context).colorScheme.error,
              textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            onPressed:
                _mesgul ? null : () => _isaretle(() => api.guvendeyim(a.id)),
            child: Text(l10n.panikGuvendeyim),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            key: const Key('panik-yardim'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              foregroundColor: yazi,
              side: BorderSide(color: yazi, width: 2),
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            onPressed: _mesgul ? null : () => _isaretle(() => api.yardim(a.id)),
            child: Text(l10n.panikYardimIstiyorum),
          ),
        ],
      ],
    );
  }

  // --------------------------- YARDIM CAGRISI ---------------------------- //
  Widget _yardimCagrisi(BuildContext context, PanikAlarm a, Color yazi) {
    final l10n = context.l10n;
    final api = ref.read(panikApiProvider);
    return Column(
      key: const Key('panik-yardim-cagrisi'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.emergency_share, size: 64, color: yazi),
        const SizedBox(height: 12),
        _baslik(context, a, yazi),
        const SizedBox(height: 8),
        Text(
          a.olusturanAd ?? '',
          key: const Key('panik-alarm-kim'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: yazi),
        ),
        if (a.yer.isNotEmpty)
          Text(
            a.yer,
            key: const Key('panik-alarm-yer'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: yazi),
          ),
        if (a.talimat.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              a.talimat.first,
              key: const Key('panik-talimat-0'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: yazi),
            ),
          ),
        if (a.aciklama != null && a.aciklama!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(a.aciklama!, textAlign: TextAlign.center),
          ),
        // SAYAC YALNIZ SUNUCU GONDERIRSE: sunucu onu yalniz guvenlik ve
        // yonetime, yalniz yardim cagrisinda dolduruyor (P249 §1b).
        if (a.son24sYanlisAlarm > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.panikYanlisAlarmSayaci(a.son24sYanlisAlarm),
              key: const Key('panik-alarm-yanlis-sayaci'),
            ),
          ),
        if (a.olusturanTelefon != null && a.olusturanTelefon!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              key: const Key('panik-alarm-ara'),
              style: OutlinedButton.styleFrom(foregroundColor: yazi),
              icon: const Icon(Icons.call),
              label: Text(a.olusturanTelefon!),
              onPressed: () {
                // ACIL DURUMDA NUMARA GOSTERILIR ve dogrudan aranir:
                // `/call-target` riza kapisindan AYRI bir karar.
                final uri = telUri(a.olusturanTelefon!);
                if (uri != null) {
                  ref.read(callLauncherProvider).dial(uri.toString());
                }
              },
            ),
          ),
        if (widget.eylemler) ...[
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('panik-mudahale'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
            onPressed:
                _mesgul ? null : () => _isaretle(() => api.mudahale(a.id)),
            child: Text(l10n.panikGidiyorum),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('panik-gordum'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              foregroundColor: yazi,
            ),
            onPressed: _mesgul ? null : () => _isaretle(() => api.gordum(a.id)),
            child: Text(l10n.panikGordum),
          ),
        ],
      ],
    );
  }
}
