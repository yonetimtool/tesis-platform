import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';

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
import '../../kurulum/presentation/kurulum_hatirlatici.dart';
import '../../tenant/data/tenant_api.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../../core/theme/home_tokens.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/data/profile_api.dart';

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
            const SizedBox(height: 8),
            // (P166 §8.2) KURULUM SIHIRBAZI — ayarlardan erisim.
            //
            // Brief: "kapatilabilsin, sonra ayarlardan tekrar acilabilsin."
            // Iki ayri sey sunuluyor: SIHIRBAZI ACMAK (dokun) ve ILK
            // GIRISTEKI HATIRLATICIYI GERI GETIRMEK (yenile ikonu). Biri
            // kullaniciyi bir kez goturur, oteki hatirlatmayi surdurur.
            Card(
              child: ListTile(
                leading: const Icon(Icons.checklist_outlined),
                title: Text(l10n.kurulumBaslik),
                subtitle: Text(l10n.kurulumAlt),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.kurulumHatirlaticiBaslik,
                  onPressed: () async {
                    await kurulumHatirlaticiyiAc(ref);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.kurulumHatirlaticiBaslik)),
                    );
                  },
                ),
                onTap: () => context.push(AppRoutes.kurulum),
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
          const SizedBox(height: 24),
          // ----------------------- HESAP (P112) ------------------------- #
          // App Store 5.1.1(v): hesap acilabiliyorsa UYGULAMA ICINDEN
          // silinebilmeli. Destege yazdirmak ya da web sitesine
          // yonlendirmek REDDEDILME sebebidir.
          //
          // EN ALTTA ve YIKICI RENKTE: gunluk kullanilan bir ayar degil,
          // geri donusu olmayan bir islem. Ustte olsaydi dil satirini
          // ararken yanlislikla dokunulabilirdi.
          Text(l10n.hesapSilBolum,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const _HesapSilKarti(),
          const SizedBox(height: 24),
          // ------------------------ YASAL (P113) ------------------------ #
          // App Store denetimi gizlilik politikasina ULASILABILIR bir
          // baglanti ARAR; yalniz App Store Connect alanina URL yazmak
          // yetmez. Belgeler tarayicida acilir (uygulama ici WebView
          // DEGIL): guncellenen bir politika, uygulama guncellemesi
          // beklemeden gecerli olmali.
          Text(l10n.ayarlarHukuki,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const _YasalKarti(),
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
    await merkezSayfaAc<void>(
      context,
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


/// HESAP SILME karti (P112) — App Store 5.1.1(v).
///
/// Uc kademe: (1) liste satiri, (2) NE SILINIP ne kalacagini ACIKCA yazan
/// onay penceresi + parola, (3) sonuc. Tek dokunuslu silme YOK: geri
/// donusu olmayan bir islem icin onay + yeniden kimlik dogrulama sarttir.
class _HesapSilKarti extends ConsumerWidget {
  const _HesapSilKarti();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final renk = Theme.of(context).colorScheme.error;
    return Card(
      child: ListTile(
        leading: Icon(Icons.person_remove_outlined, color: renk),
        title: Text(l10n.hesapSilBaslik, style: TextStyle(color: renk)),
        subtitle: Text(l10n.hesapSilAlt),
        onTap: () => _onayAc(context, ref),
      ),
    );
  }

  Future<void> _onayAc(BuildContext context, WidgetRef ref) async {
    final silindi = await merkezSayfaAc<bool>(
      context,
      builder: (_) => const _HesapSilDiyalogu(),
    );
    if (silindi == null || !context.mounted) return;
    // Hesap artik yok (ya da anonim): OTURUMU KAPAT. Ekranda birakmak,
    // her istegi 401 alan bir arayuz gostermek olurdu.
    await ref.read(authControllerProvider.notifier).logout();
  }
}

class _HesapSilDiyalogu extends ConsumerStatefulWidget {
  const _HesapSilDiyalogu();

  @override
  ConsumerState<_HesapSilDiyalogu> createState() => _HesapSilDiyaloguState();
}

class _HesapSilDiyaloguState extends ConsumerState<_HesapSilDiyalogu> {
  final _parola = TextEditingController();

  /// (P149) Parolasiz kullanicinin onay kodu.
  final _kod = TextEditingController();

  /// Ekran KOD MODUNDA mi. Girise eklenen desenin aynisi: gecis
  /// KULLANICININ ACIK secimiyle olur. Otomatik gecemeyiz cunku istemci
  /// kullanicinin parolasi olup olmadigini BILMEZ — bunu sunucu bilir ve
  /// tahmin etmek yanlis alani gostermek olurdu.
  bool _kodModu = false;
  bool _kodGonderildi = false;
  bool _calisiyor = false;
  String? _hata;

  @override
  void dispose() {
    _parola.dispose();
    _kod.dispose();
    super.dispose();
  }

  /// (P149) Parolasiz kullanici icin onay kodu iste.
  Future<void> _koduIste() async {
    setState(() {
      _calisiyor = true;
      _hata = null;
    });
    try {
      await ref.read(profileApiProvider).hesapSilmeKoduIste();
      if (mounted) {
        setState(() {
          _calisiyor = false;
          _kodGonderildi = true;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _calisiyor = false;
          _hata = e.message;
        });
      }
    }
  }

  Future<void> _sil() async {
    final l10n = context.l10n;
    // Hangi alanin dolu olmasi gerektigi MODA bagli; sunucu da zaten
    // hangisini kabul edecegini kendisi secer.
    if (_kodModu ? _kod.text.isEmpty : _parola.text.isEmpty) {
      setState(() => _hata =
          _kodModu ? l10n.hesapSilKodGerekli : l10n.hesapSilParolaGerekli);
      return;
    }
    setState(() {
      _calisiyor = true;
      _hata = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final tamSilindi = await ref
          .read(profileApiProvider)
          .deleteAccount(
            currentPassword: _kodModu ? null : _parola.text,
            kod: _kodModu ? _kod.text.trim() : null,
          );
      // IKI SONUC DA OLUMLUDUR. `false` "silinemedi" demek DEGIL, "yasal
      // olarak saklanmasi gereken kayitlar anonimlestirildi" demektir;
      // kullaniciya bunu soylemek, sonradan "verim duruyor mu" sorusunu
      // dogurmamak icin gerekli.
      messenger.showSnackBar(SnackBar(
        content: Text(tamSilindi
            ? l10n.hesapSilSonucSilindi
            : l10n.hesapSilSonucAnonim),
      ));
      navigator.pop(true);
    } on ApiException catch (e) {
      // Sunucu metni AYNEN gosterilir: son-yonetici engeli (409) NE
      // YAPILACAGINI soyleyen bir cumledir ve istemcide yeniden yazmak
      // onu iki yerde tutmak olurdu.
      setState(() {
        _calisiyor = false;
        _hata = apiHataMetni(l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final renk = Theme.of(context).colorScheme.error;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.hesapSilOnayBaslik,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              // NE SILINIP NE KALACAGI ACIKCA YAZAR. "Hesabiniz silinecek"
              // demek yetmezdi: aidat kaydinin kaldigini sonradan ogrenen
              // kullanici kandirildigini dusunurdu.
              Text(l10n.hesapSilOnayGovde),
              const SizedBox(height: 16),
              Text(
                l10n.hesapSilParolaAciklama,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (!_kodModu) ...[
                TextField(
                  controller: _parola,
                  obscureText: true,
                  enabled: !_calisiyor,
                  decoration: InputDecoration(
                    labelText: l10n.hesapSilParolaEtiket,
                    border: const OutlineInputBorder(),
                  ),
                ),
                // (P149) Kendi kaydolan sakinin PAROLASI YOKTUR; bu yol
                // olmadan hesabini SILEMEZDI (Play sartinin ihlali).
                TextButton(
                  onPressed: _calisiyor
                      ? null
                      : () => setState(() {
                            _kodModu = true;
                            _hata = null;
                          }),
                  child: Text(l10n.hesapSilKodlaOnayla),
                ),
              ] else if (!_kodGonderildi) ...[
                Text(l10n.hesapSilKodAciklama,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _calisiyor ? null : _koduIste,
                  child: Text(l10n.girisKoduGonder),
                ),
              ] else
                TextField(
                  controller: _kod,
                  keyboardType: TextInputType.number,
                  enabled: !_calisiyor,
                  decoration: InputDecoration(
                    labelText: l10n.girisKodAlani,
                    border: const OutlineInputBorder(),
                  ),
                ),
              if (_hata != null) ...[
                const SizedBox(height: 12),
                Text(_hata!, style: TextStyle(color: renk)),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _calisiyor ? null : () => Navigator.of(context).pop(),
                      child: Text(l10n.ortakVazgec),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: yikiciDugmeStili(context),
                      onPressed: _calisiyor ? null : _sil,
                      child: Text(
                        _calisiyor ? l10n.hesapSilSiliniyor : l10n.hesapSilOnayla,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// YASAL BELGELER karti (P113) — gizlilik politikasi + kullanim kosullari.
///
/// Adresler `AppConfig`te SABITTIR: ayni URL'ler App Store Connect ve
/// Google Play'e de girilir.
class _YasalKarti extends StatelessWidget {
  const _YasalKarti();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.ayarlarGizlilik),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _ac(context, AppConfig.gizlilikUrl),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: Text(l10n.ayarlarKosullar),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _ac(context, AppConfig.kosullarUrl),
          ),
        ],
      ),
    );
  }

  Future<void> _ac(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final mesaj = context.l10n.ayarlarBelgeAcilamadi;
    // SESSIZ BASARISIZLIK YOK: tarayici acilamazsa kullanici dokundugunu
    // ama hicbir sey olmadigini gorurdu — denetimde "olu dugme" sayilir.
    final acildi = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!acildi) messenger.showSnackBar(SnackBar(content: Text(mesaj)));
  }
}
