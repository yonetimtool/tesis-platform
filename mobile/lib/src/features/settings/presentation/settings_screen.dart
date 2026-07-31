import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../routing/app_router.dart';
import '../../auth/data/current_user_provider.dart';
import '../../kvkk/data/kvkk_api.dart';
import '../../kvkk/presentation/kvkk_onay_screen.dart'
    show PazarlamaAnahtarlari;
import '../../auth/domain/user_role.dart';
import '../../tenant/data/tenant_api.dart';
import '../../../core/error/akis_hatasi.dart';

/// Ayarlar — kullanici tercihleri (DIL + tema modu) + yonetici'ye ozel tesis
/// adlandirmasi. Iki tercih de kalicidir (guvenli depo) ve ANINDA uygulanir;
/// uygulama yeniden baslatilmaz.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final role = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.ayarlarBaslik, context.dilKodu)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tesis adini YALNIZ yonetici degistirir (backend RBAC zorlar).
          if (role == UserRole.yonetici) ...[
            Text(l10n.ayarlarTesis,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const _TesisAdiKarti(),
            const SizedBox(height: 24),
          ],
          // Kamera yonetimi — admin/yonetici (WP-F). security ana ekran
          // seridinden erisir; buradaki giris YONETIM icindir.
          if (role == UserRole.admin || role == UserRole.yonetici) ...[
            Text(l10n.ayarlarYonetim,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: Text(l10n.ayarlarKameralar),
                subtitle: Text(l10n.ayarlarKameralarAlt),
                // RTL: chevron Directionality ile kendiliginden aynalanir.
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.kameralar),
              ),
            ),
            const SizedBox(height: 24),
          ],
          // ------------------------------- DIL ------------------------- #
          Text(l10n.ayarlarGorunum,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const _DilKarti(),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.ayarlarTema,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    l10n.ayarlarTemaAciklama,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: const Icon(Icons.brightness_auto_outlined),
                          label: Text(l10n.ayarlarTemaSistem),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: const Icon(Icons.light_mode_outlined),
                          label: Text(l10n.ayarlarTemaAcik),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: const Icon(Icons.dark_mode_outlined),
                          label: Text(l10n.ayarlarTemaKoyu),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (s) =>
                          ref.read(themeModeProvider.notifier).set(s.first),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // -------------------- IZINLER + AYDINLATMA (P36) -------------- #
          // Listenin SONUNDA: gorunum/dil gunluk ayarlardir, izinler nadiren
          // ziyaret edilir. Ustte olsaydi her kullanici her acilista once
          // pazarlama anahtarlarini gorurdu — ve dil satirini ekrandan
          // asagi iterdi.
          //
          // Tercihler SONRADAN degistirilebilir olmali: riza her an geri
          // alinabilir (KVKK). Onay ekranindaki blokla AYNI widget kullanilir
          // — iki ayri liste, birinde eklenen kanalin digerinde unutulmasi
          // demekti.
          Text(l10n.kvkkAyarlarBaslik,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const _IzinlerKarti(),
        ],
      ),
    );
  }
}

/// DIL karti — "Dil / Language" satiri (TR disi dillerde de "Language"
/// gectigi icin kullanici anlamadigi bir dilde kalsa bile bulabilir).
/// Secim ANINDA uygulanir ve kalicidir.
class _DilKarti extends ConsumerWidget {
  const _DilKarti();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secili = ref.watch(localeControllerProvider);
    // Secim yoksa cihaz dili gecerlidir: satirda O AN gecerli dil gosterilir.
    final aktifKod = Localizations.localeOf(context).languageCode;
    final aktif = secili ?? AppDil.fromKod(aktifKod) ?? AppDil.tr;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.translate_outlined),
        title: Text(context.l10n.ayarlarDil),
        subtitle: Text(aktif.adKendiDilinde),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _dilSec(context, ref),
      ),
    );
  }

  Future<void> _dilSec(BuildContext context, WidgetRef ref) async {
    final secili = ref.read(localeControllerProvider);
    final aktifKod = Localizations.localeOf(context).languageCode;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 8),
              child: Text(
                sheetContext.l10n.dilSecBaslik,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            // Secim yoksa cihaz dilinin karsiligi isaretli gorunur.
            RadioGroup<AppDil>(
              groupValue: secili ?? AppDil.fromKod(aktifKod) ?? AppDil.tr,
              onChanged: (yeni) {
                if (yeni != null) {
                  ref.read(localeControllerProvider.notifier).sec(yeni);
                }
                Navigator.pop(sheetContext);
              },
              child: Column(
                children: [
                  for (final dil in AppDil.values)
                    RadioListTile<AppDil>(
                      // Her dil KENDI DILINDE yazilir (kullanici kendi dilini
                      // bulabilsin) ve kendi yonunde cizilir.
                      title: Text(
                        dil.adKendiDilinde,
                        textDirection:
                            dil.rtl ? TextDirection.rtl : TextDirection.ltr,
                      ),
                      value: dil,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tesis adi karti (yonetici) — `PATCH /tenant/settings {ad}`. Kaydedince
/// [tenantSettingsProvider] tazelenir → ana ekran app-bar'i guncellenir.
/// slug DEGISMEZ.
class _TesisAdiKarti extends ConsumerStatefulWidget {
  const _TesisAdiKarti();

  @override
  ConsumerState<_TesisAdiKarti> createState() => _TesisAdiKartiState();
}

class _TesisAdiKartiState extends ConsumerState<_TesisAdiKarti> {
  /// Sunucu-tarafi yer tutucu — kullaniciya gosterilmez, alan bos baslar.
  static const _placeholder = '(Kurulum bekliyor)';

  late final TextEditingController _adCtrl = TextEditingController(
    text: () {
      final ad = ref.read(tenantSettingsProvider).value?.ad ?? '';
      return ad == _placeholder ? '' : ad;
    }(),
  );
  bool _submitting = false;

  @override
  void dispose() {
    _adCtrl.dispose();
    super.dispose();
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  Future<void> _kaydet() async {
    FocusScope.of(context).unfocus();
    final ad = _adCtrl.text.trim();
    if (ad.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref.read(tenantApiProvider).updateAd(ad);
      ref.invalidate(tenantSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n.tesisAdiGuncellendi)),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiHataMetni(_l10n, e))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n.ortakBeklenmeyenHata)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.ayarlarTesisAdi,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              l10n.tesisAdiAciklama,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _adCtrl,
              enabled: !_submitting,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _kaydet(),
              decoration: InputDecoration(
                hintText: l10n.tesisAdiIpucu,
                prefixIcon: const Icon(Icons.business_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              // YON-DUYARLI: Arapca'da sola hizalanir.
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: (_submitting || _adCtrl.text.trim().isEmpty)
                    ? null
                    : _kaydet,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(l10n.ortakKaydet),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// (P36) Pazarlama izinleri + aydinlatma metnine erisim.
///
/// Metin baglantisi burada durur: kullanici NEYI onayladigini sonradan
/// gorebilmelidir — onayi bir kez alip metni saklamak, aydinlatmanin
/// amacini bosa cikarirdi.
class _IzinlerKarti extends ConsumerWidget {
  const _IzinlerKarti();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tercihAsync = ref.watch(pazarlamaTercihProvider);
    final durum = ref.watch(kvkkDurumProvider).value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(l10n.kvkkIzinBaslik,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              l10n.kvkkIzinAciklama,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            tercihAsync.when(
              // YUKLENIRKEN DONEN BIR HALKA YOK: Ayarlar listesinde
              // surekli donen bir gosterge hem gorsel gurultudur hem de
              // ekrani ASLA DURULMAYAN bir animasyona baglar (widget
              // testlerinde `pumpAndSettle` zaman asimina ugrar). Yerine
              // ayni yuksekliği tutan SESSIZ bir yer tutucu: anahtarlar
              // yuklenince yerinde belirir, liste zıplamaz.
              loading: () => const SizedBox(height: 168),
              // Yuklenemediyse anahtar GOSTERILMEZ: bilinmeyen bir durumu
              // "kapali" diye cizmek, verilmis bir rizayi yok gostermekti.
              error: (_, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(l10n.kvkkIzinKaydedilemedi),
              ),
              data: (tercih) => PazarlamaAnahtarlari(
                tercih: tercih,
                onDegis: (kanal, deger) async {
                  final api = ref.read(kvkkApiProvider);
                  try {
                    await api.tercihGuncelle({kanal: deger});
                  } finally {
                    ref.invalidate(pazarlamaTercihProvider);
                  }
                },
              ),
            ),
            if (durum?.metinVar ?? false)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text(l10n.kvkkMetniGoruntule),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.kvkkMetin),
              ),
          ],
        ),
      ),
    );
  }
}
