import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../../auth/data/current_user_provider.dart';
import '../../call/data/call_launcher.dart';
import '../../call/domain/tel_uri.dart';
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

class PanikAlarmKatmani extends ConsumerStatefulWidget {
  const PanikAlarmKatmani({
    super.key,
    required this.alarm,
    required this.onKarar,
  });

  final PanikAlarm alarm;
  final VoidCallback onKarar;

  @override
  ConsumerState<PanikAlarmKatmani> createState() => _PanikAlarmKatmaniState();
}

class _PanikAlarmKatmaniState extends ConsumerState<PanikAlarmKatmani> {
  bool _mesgul = false;

  Future<void> _isaretle(Future<PanikAlarm> Function() is_) async {
    setState(() => _mesgul = true);
    try {
      await is_();
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
    final l10n = context.l10n;
    final api = ref.read(panikApiProvider);
    final a = widget.alarm;
    final renk = Theme.of(context).colorScheme.error;

    return PopScope(
      // GERI TUSU KAPATMAZ — "kapatilamaz" iddiasinin bedeli budur.
      canPop: false,
      child: Material(
        color: renk.withValues(alpha: 0.96),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emergency_share,
                      size: 64, color: Theme.of(context).colorScheme.onError),
                  const SizedBox(height: 12),
                  Text(
                    l10n.panikGelenAlarm,
                    key: const Key('panik-tam-ekran'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onError,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    a.olusturanAd ?? '',
                    key: const Key('panik-alarm-kim'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onError,
                        ),
                  ),
                  if (a.yer.isNotEmpty)
                    Text(
                      a.yer,
                      key: const Key('panik-alarm-yer'),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onError),
                    ),
                  if (a.aciklama != null && a.aciklama!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(a.aciklama!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onError)),
                    ),
                  if (a.son24sYanlisAlarm > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.panikYanlisAlarmSayaci(a.son24sYanlisAlarm),
                        key: const Key('panik-alarm-yanlis-sayaci'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onError),
                      ),
                    ),
                  if (a.olusturanTelefon != null &&
                      a.olusturanTelefon!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton.icon(
                        key: const Key('panik-alarm-ara'),
                        icon: const Icon(Icons.call),
                        label: Text(a.olusturanTelefon!),
                        onPressed: () {
                          // ACIL DURUMDA NUMARA GOSTERILIR ve dogrudan
                          // aranir: `/call-target` riza kapisindan AYRI
                          // bir karar (bkz. routers/panik.py).
                          final uri = telUri(a.olusturanTelefon!);
                          if (uri != null) {
                            ref.read(callLauncherProvider).dial(uri.toString());
                          }
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('panik-mudahale'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                    ),
                    onPressed:
                        _mesgul ? null : () => _isaretle(() => api.mudahale(a.id)),
                    child: Text(l10n.panikGidiyorum),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('panik-gordum'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                    onPressed:
                        _mesgul ? null : () => _isaretle(() => api.gordum(a.id)),
                    child: Text(l10n.panikGordum),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
