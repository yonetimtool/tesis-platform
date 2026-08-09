import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/telefon_alani.dart';
import '../../../core/ui/telefon_hata_metni.dart';
import '../../../routing/app_router.dart';
import '../data/auth_api.dart';
import 'auth_controller.dart';

/// (P154 / Asama 3) ROL SECIMLI KAYIT — mobil yuzey.
///
/// BRIEF: mobilde dort rol (Yonetici · Site sakini · Guvenlik gorevlisi ·
/// Tesis gorevlisi). Web AYRI bir kume sunar (yonetici + denetci) cunku
/// denetcinin isi raporlarda, sahada degil.
///
/// KUME NEDEN ISTEMCIDE: sunucu bes rolu de kabul eder ve GERCEK kapi
/// "tesis ID + telefon onceden tanimli kayitla eslesiyor mu" kontroludur.
/// Bir sakin buradan `yonetici` secse bile eslesmedigi icin kod ALAMAZ.
/// Yani bu liste bir GUVENLIK siniri degil, bir URUN karari.
///
/// UC ADIM, DORDUNCUSU YOK: rol -> kimlik -> kod. Parola ekrani YAZILMADI
/// — `setupToken` dolunca router zaten `/set-password`e goturuyor ve o
/// ekran parola kuralini, gosterme/gizlemeyi ve 401'de kurulumu iptal
/// etmeyi coktan cozmus (bkz. `AuthController.kayitKodunuOnayla`).
class KayitScreen extends ConsumerStatefulWidget {
  const KayitScreen({super.key});

  @override
  ConsumerState<KayitScreen> createState() => _KayitScreenState();
}

/// Sunucunun kabul ettigi rol kimligi + ekranda gosterilecek etiket.
enum KayitRolu {
  yonetici('yonetici'),
  sakin('resident'),
  guvenlik('security'),
  tesisGorevlisi('tesis_gorevlisi');

  const KayitRolu(this.kimlik);

  /// Sunucuya giden deger — ekran etiketinden AYRI. Etiket cevrilir,
  /// kimlik ASLA cevrilmez.
  final String kimlik;

  /// YALNIZ sakinden daire istenir (brief). Yoneticiye daire sormak,
  /// dairesi olmayan birine zorunlu alan gostermek olurdu.
  bool get daireIster => this == KayitRolu.sakin;
}

enum _Adim { rol, kimlik, kod }

class _KayitScreenState extends ConsumerState<KayitScreen> {
  final _kimlikFormKey = GlobalKey<FormState>();
  final _kodFormKey = GlobalKey<FormState>();
  final _tesisCtrl = TextEditingController();
  final _telefonCtrl = TextEditingController();
  final _daireCtrl = TextEditingController();
  final _blokCtrl = TextEditingController();
  final _kodCtrl = TextEditingController();

  _Adim _adim = _Adim.rol;
  KayitRolu _rol = KayitRolu.yonetici;
  String _tesisAd = '';
  String _telefonMaskeli = '';
  String? _hata;
  bool _bekliyor = false;

  @override
  void dispose() {
    _tesisCtrl.dispose();
    _telefonCtrl.dispose();
    _daireCtrl.dispose();
    _blokCtrl.dispose();
    _kodCtrl.dispose();
    super.dispose();
  }

  Future<void> _kimlikGonder() async {
    FocusScope.of(context).unfocus();
    if (!_kimlikFormKey.currentState!.validate()) return;
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    try {
      final sonuc = await ref.read(authApiProvider).rolKayitBasla(
            rol: _rol.kimlik,
            tesisKodu: _tesisCtrl.text.trim(),
            telefon: telefonNormalle(_telefonCtrl.text),
            daireNo: _rol.daireIster ? _daireCtrl.text.trim() : null,
            blok: _rol.daireIster ? _blokCtrl.text.trim() : null,
          );
      if (!mounted) return;
      setState(() {
        _tesisAd = sonuc.tesisAd;
        _telefonMaskeli = sonuc.telefonMaskeli;
        _adim = _Adim.kod;
        _bekliyor = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // SUNUCU METNI AYNEN: "adimlari ayirt ETTIRMEYEN" cumleyi burada
      // yeniden yazmak, sunucunun bilincli belirsizligini bozardi.
      setState(() {
        _hata = e.message;
        _bekliyor = false;
      });
    }
  }

  Future<void> _kodGonder() async {
    FocusScope.of(context).unfocus();
    if (!_kodFormKey.currentState!.validate()) return;
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    try {
      final jeton = await ref.read(authApiProvider).rolKayitDogrula(
            telefon: telefonNormalle(_telefonCtrl.text),
            kod: _kodCtrl.text.trim(),
          );
      if (!mounted) return;
      // Jetonu denetleyiciye birak: router `setupToken` dolunca parola
      // ekranina KENDISI goturur. Buradan elle `context.go` cagirmak,
      // ayni karari iki yerde tutmak olurdu.
      ref.read(authControllerProvider.notifier).kayitKodunuOnayla(jeton);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = e.message;
        _bekliyor = false;
      });
    }
  }

  void _geri() {
    setState(() {
      _hata = null;
      _adim = _adim == _Adim.kod ? _Adim.kimlik : _Adim.rol;
    });
  }

  String _rolEtiketi(KayitRolu rol) {
    final l10n = context.l10n;
    return switch (rol) {
      KayitRolu.yonetici => l10n.kayitRolYonetici,
      KayitRolu.sakin => l10n.kayitRolSakin,
      KayitRolu.guvenlik => l10n.kayitRolGuvenlik,
      KayitRolu.tesisGorevlisi => l10n.kayitRolTesisGorevlisi,
    };
  }

  IconData _rolSimgesi(KayitRolu rol) => switch (rol) {
        KayitRolu.yonetici => Icons.apartment_outlined,
        KayitRolu.sakin => Icons.home_outlined,
        KayitRolu.guvenlik => Icons.shield_outlined,
        KayitRolu.tesisGorevlisi => Icons.handyman_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final adimNo = switch (_adim) {
      _Adim.rol => 1,
      _Adim.kimlik => 2,
      _Adim.kod => 3,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.kayitBaslik),
        leading: _adim == _Adim.rol
            ? null
            : BackButton(onPressed: _bekliyor ? null : _geri),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.kayitAdim('$adimNo'),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 16),
                  if (_hata != null) ...[
                    // `SelectableText` DEGIL `Text`: hata metni kopyalanacak
                    // bir kimlik degil, okunacak bir cumle.
                    Text(
                      _hata!,
                      key: const Key('kayit-hata'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_adim == _Adim.rol) _rolSecimi(l10n),
                  if (_adim == _Adim.kimlik) _kimlikFormu(l10n),
                  if (_adim == _Adim.kod) _kodFormu(l10n),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed:
                        _bekliyor ? null : () => context.go(AppRoutes.login),
                    child: Text(l10n.kayitGirisLinki),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rolSecimi(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.kayitAltBaslik),
        const SizedBox(height: 12),
        for (final rol in KayitRolu.values) ...[
          // `ListTile` varsayilan yuksekligi 56dp — 44pt dokunma hedefinin
          // uzerinde (erisilebilirlik kurali).
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              key: Key('kayit-rol-${rol.kimlik}'),
              leading: Icon(_rolSimgesi(rol)),
              title: Text(_rolEtiketi(rol)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() {
                _rol = rol;
                _adim = _Adim.kimlik;
              }),
            ),
          ),
        ],
      ],
    );
  }

  Widget _kimlikFormu(AppLocalizations l10n) {
    return Form(
      key: _kimlikFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _tesisCtrl,
            enabled: !_bekliyor,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: l10n.kayitTesisKodu,
              helperText: l10n.kayitTesisKoduIpucu,
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.qr_code_2_outlined),
              border: const OutlineInputBorder(),
            ),
            validator: (v) => (v ?? '').trim().length < 4
                ? l10n.kayitTesisKoduGerekli
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _telefonCtrl,
            enabled: !_bekliyor,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.phone,
            // (P123) TEK bicimlendirici — giris ekraniyla AYNI, yoksa iki
            // ekran ayni numarayi farkli kabul ederdi.
            inputFormatters: const [TelefonBicimlendirici()],
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.ortakCepTelefonu,
              hintText: l10n.ortakTelefonIpucu,
              prefixIcon: const Icon(Icons.phone_outlined),
              border: const OutlineInputBorder(),
            ),
            validator: (v) => telefonHataMetni(l10n, v ?? ''),
          ),
          if (_rol.daireIster) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _daireCtrl,
              enabled: !_bekliyor,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.kayitDaireNo,
                prefixIcon: const Icon(Icons.meeting_room_outlined),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? l10n.kayitDaireGerekli
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _blokCtrl,
              enabled: !_bekliyor,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.kayitBlok,
                prefixIcon: const Icon(Icons.domain_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('kayit-kimlik-gonder'),
            onPressed: _bekliyor ? null : _kimlikGonder,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: _bekliyor
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(l10n.kayitDevam),
          ),
        ],
      ),
    );
  }

  Widget _kodFormu(AppLocalizations l10n) {
    return Form(
      key: _kodFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.kayitKodBaslik,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          // METIN BILEREK BELIRSIZ: sunucu numaranin kayitli olup
          // olmadigini SOYLEMIYOR (tarama araci olmasin diye). Ekranin
          // "kod gonderildi" demesi o korumayi bozardi; bunun yerine
          // kodun GELMEYEBILECEGI yaziyor.
          Text(l10n.kayitKodAciklama(_tesisAd, _telefonMaskeli)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _kodCtrl,
            enabled: !_bekliyor,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _kodGonder(),
            decoration: InputDecoration(
              labelText: l10n.kayitKodAlani,
              prefixIcon: const Icon(Icons.sms_outlined),
              border: const OutlineInputBorder(),
            ),
            validator: (v) => (v ?? '').trim().isEmpty
                ? l10n.kayitKodGerekli
                : null,
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('kayit-kod-gonder'),
            onPressed: _bekliyor ? null : _kodGonder,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: _bekliyor
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(l10n.kayitDevam),
          ),
        ],
      ),
    );
  }
}
