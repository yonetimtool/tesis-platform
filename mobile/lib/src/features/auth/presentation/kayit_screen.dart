import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/startup/acilis_tercihleri.dart';
import '../../../core/ui/telefon_alani.dart';
import '../../../routing/app_router.dart';
import '../data/auth_api.dart';
import 'auth_controller.dart';
import 'sosyal_giris.dart';

/// (P184) TESIS ID ILE GIRIS/TAMAMLAMA — mobil yuzey.
///
/// ===========================================================================
/// "KAYIT" DEGIL "TAMAMLAMA" — ve bu bilincli
/// ===========================================================================
/// Yonetici sakini/gorevliyi panelden ekler; kisinin `app_user` satiri ZATEN
/// vardir (aktif, rolu belli, parolasi belirlenmemis). Kisi burada hesabi
/// sifirdan ACMAZ, VAR OLANI SAHIPLENIR: e-posta sahipligini (OTP ya da SSO
/// `email_verified`) + Tesis ID ile kanitlar. Metinler bu yuzden "kayit" degil
/// "tamamlama" dilini kullanir.
///
/// ===========================================================================
/// SMS YOK — DOGRULAMA E-POSTA ILE
/// ===========================================================================
/// `SMS_AKTIF=false` ve baslik onayi alinmadi. Telefon alani KALIR ama yalniz
/// ILETISIM bilgisidir; dogrulama e-posta koduyla (parola yolu) ya da
/// saglayicinin `email_verified` bayragiyla (SSO yolu) yapilir. Telefonlu
/// (SMS) kardes uclar backend'de DURUR ama mobil ARTIK CAGIRMAZ.
///
/// ===========================================================================
/// YONETICI MOBILDEN KAYDOLMAZ
/// ===========================================================================
/// Yonetici web'den (`yonetiyor.com`) kaydolur; mobilde yoneticiye yalniz
/// GIRIS vardir. Bu yuzden rol listesinde yonetici YOK — yalniz sakin,
/// guvenlik ve tesis gorevlisi.
///
/// ADIMLAR:
///   1. ROL        — sakin | guvenlik | tesis gorevlisi
///   2. YONTEM     — once sosyal (SSO), sonra "E-posta ile devam"
///   3. BILGILER   — YALNIZ parola yolunda: ad + e-posta(zorunlu) +
///                   telefon(istege bagli) + parola
///   4. TESIS ID   — tesis kodu
///   5. KOD        — parola: e-posta OTP · SSO: yalniz email_verified=false
///                   ise e-posta OTP; email_verified=true'da bu adim ATLANIR
class KayitScreen extends ConsumerStatefulWidget {
  const KayitScreen({super.key});

  @override
  ConsumerState<KayitScreen> createState() => _KayitScreenState();
}

/// Sunucunun kabul ettigi rol kimligi + ekranda gosterilecek etiket.
///
/// (P184) YONETICI YOK: mobilde yonetici KAYDOLMAZ (web'den kaydolur).
enum KayitRolu {
  sakin('resident'),
  guvenlik('security'),
  tesisGorevlisi('tesis_gorevlisi');

  const KayitRolu(this.kimlik);

  /// Sunucuya giden deger — ekran etiketinden AYRI. Etiket cevrilir,
  /// kimlik ASLA cevrilmez. (P184) DB `user_role` enum'uyla birebir:
  /// `tesis_gorevlisi` (kisa "gorevli" DEGIL).
  final String kimlik;
}

enum _Adim { rol, yontem, bilgiler, tesisKodu, kod, onayBekliyor }

/// Kimlik dogrulama yolu — hangi ucun kullanilacagini belirler.
enum _Yol { parola, sosyal }

class _KayitScreenState extends ConsumerState<KayitScreen> {
  final _bilgiFormKey = GlobalKey<FormState>();
  final _tesisKoduFormKey = GlobalKey<FormState>();
  final _kodFormKey = GlobalKey<FormState>();

  final _adCtrl = TextEditingController();
  final _epostaCtrl = TextEditingController();
  final _telefonCtrl = TextEditingController();
  final _parolaCtrl = TextEditingController();
  final _tesisKoduCtrl = TextEditingController();
  final _kodCtrl = TextEditingController();

  _Adim _adim = _Adim.rol;
  KayitRolu _rol = KayitRolu.sakin;
  _Yol _yol = _Yol.parola;

  String _tesisAd = '';
  String? _hata;
  bool _bekliyor = false;

  @override
  void initState() {
    super.initState();
    // (P154 / Asama 2) ROL LISTESI GORULDU — bayrak EKRAN ACILIRKEN yazilir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(rolSecimiBekliyorProvider.notifier).gosterildi());
      // (P211-ek3) GIRISTEN DEVREDILEN SSO KIMLIGI.
      //
      // Giris ekraninda ARTIK Tesis ID SORULMUYOR: sosyal kimlik bir
      // hesaba bagli degilse kullanici BURAYA gelir. Jeton state'te
      // hazirsa tarayici akisini TEKRARLAMAYIZ — yalniz rol sorulur,
      // ardindan Tesis ID adimina gecilir (kayit akisinin dogal yeri).
      if (ref.read(authControllerProvider).oauthBaglamaJetonu != null) {
        setState(() => _yol = _Yol.sosyal);
      }
    });
  }

  @override
  void dispose() {
    _adCtrl.dispose();
    _epostaCtrl.dispose();
    _telefonCtrl.dispose();
    _parolaCtrl.dispose();
    _tesisKoduCtrl.dispose();
    _kodCtrl.dispose();
    super.dispose();
  }

  String get _telefon => telefonNormalle(_telefonCtrl.text);

  /// Sosyal yolda BILGILER adimi ATLANIR (kimlik + e-posta saglayicidan
  /// gelir), o yuzden toplam adim bir eksiktir.
  int get _toplamAdim => _yol == _Yol.sosyal ? 4 : 5;

  // ======================= ADIM 2: YONTEM ================================= //

  void _parolaYolunuSec() {
    setState(() {
      _yol = _Yol.parola;
      _hata = null;
      _adim = _Adim.bilgiler;
    });
  }

  /// Sosyal yol: once tarayici akisi (saglayici kimligi + e-postayi kanitlar),
  /// sonra DOGRUDAN tesis kodu adimi — ad/e-posta/parola SORULMAZ.
  Future<void> _sosyalYolunuSec(String saglayici) async {
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    final denetleyici = ref.read(authControllerProvider.notifier);
    // ONCE TEMIZLE: onceki denemeden kalmis bir baglama jetonu olabilir.
    denetleyici.oauthIptal();
    await denetleyici.oauthAkisi(saglayici);
    if (!mounted) return;

    final durum = ref.read(authControllerProvider);
    // Kimlik ZATEN bagliysa oturum acildi; router devralir.
    if (durum.status == AuthStatus.authenticated) return;
    // Kullanici tarayiciyi kapatti → sessizce yontem adiminda kal.
    if (durum.oauthBaglamaJetonu == null) {
      setState(() {
        _bekliyor = false;
        _hata = durum.errorMessage;
      });
      return;
    }

    setState(() {
      _yol = _Yol.sosyal;
      _bekliyor = false;
      _adim = _Adim.tesisKodu;
    });
  }

  // ======================= ADIM 3: BILGILER (parola) ====================== //

  void _bilgileriGonder() {
    FocusScope.of(context).unfocus();
    if (!_bilgiFormKey.currentState!.validate()) return;
    setState(() {
      _hata = null;
      _adim = _Adim.tesisKodu;
    });
  }

  // ======================= ADIM 4: TESIS ID ============================== //

  Future<void> _tesisKoduGonder() async {
    FocusScope.of(context).unfocus();
    if (!_tesisKoduFormKey.currentState!.validate()) return;
    setState(() {
      _bekliyor = true;
      _hata = null;
    });

    if (_yol == _Yol.sosyal) {
      await _sosyalTamamla();
    } else {
      await _epostaBasla();
    }
  }

  /// Parola yolu: e-postaya kod gonder, KOD adimina gec.
  Future<void> _epostaBasla() async {
    try {
      final tesisAd = await ref.read(authApiProvider).rolEpostaBasla(
            rol: _rol.kimlik,
            tesisKodu: _tesisKoduCtrl.text.trim(),
            eposta: _epostaCtrl.text.trim(),
            ad: _adCtrl.text.trim(),
            telefon: _telefonCtrl.text.trim().isEmpty ? null : _telefon,
          );
      if (!mounted) return;
      setState(() {
        _tesisAd = tesisAd;
        _bekliyor = false;
        _adim = _Adim.kod;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = e.message;
        _bekliyor = false;
      });
    }
  }

  /// Sosyal yol: SSO kimligini rol hesabina bagla.
  ///   giris        → oturum (router devralir)
  ///   otp_gerekli  → e-postaya kod gitti, KOD adimi
  ///   onay_bekliyor→ ONAY BEKLIYOR adimi
  Future<void> _sosyalTamamla() async {
    final sonuc = await ref.read(authControllerProvider.notifier).oauthRolTamamla(
          tesisKodu: _tesisKoduCtrl.text.trim(),
          rol: _rol.kimlik,
        );
    if (!mounted) return;
    if (sonuc == null) {
      setState(() {
        _hata = ref.read(authControllerProvider).errorMessage;
        _bekliyor = false;
      });
      return;
    }
    if (sonuc.durum == 'giris') {
      return; // authenticated — router yonlendirir.
    }
    if (sonuc.durum == 'otp_gerekli') {
      setState(() {
        _tesisAd = sonuc.tesisAd ?? '';
        _bekliyor = false;
        _adim = _Adim.kod;
      });
      return;
    }
    // onay_bekliyor
    setState(() {
      _bekliyor = false;
      _adim = _Adim.onayBekliyor;
    });
  }

  // ========================= ADIM 5: KOD ================================== //

  Future<void> _kodGonder() async {
    FocusScope.of(context).unfocus();
    if (!_kodFormKey.currentState!.validate()) return;
    setState(() {
      _bekliyor = true;
      _hata = null;
    });

    if (_yol == _Yol.sosyal) {
      // SSO + email_verified=false yolu: e-posta OTP dogrula, kimligi bagla.
      final durum = await ref
          .read(authControllerProvider.notifier)
          .oauthRolTamamlaDogrula(
            tesisKodu: _tesisKoduCtrl.text.trim(),
            rol: _rol.kimlik,
            kod: _kodCtrl.text.trim(),
          );
      if (!mounted) return;
      if (durum == 'giris') return; // authenticated — router devralir.
      if (durum == 'onay_bekliyor') {
        setState(() {
          _bekliyor = false;
          _adim = _Adim.onayBekliyor;
        });
        return;
      }
      // Hata (kod yanlis/suresi dolmus): mesaj state'te, kod adiminda kal.
      setState(() {
        _hata = ref.read(authControllerProvider).errorMessage;
        _bekliyor = false;
      });
      return;
    }

    // Parola yolu: e-posta OTP dogrula.
    try {
      final r = await ref.read(authApiProvider).rolEpostaDogrula(
            tesisKodu: _tesisKoduCtrl.text.trim(),
            eposta: _epostaCtrl.text.trim(),
            kod: _kodCtrl.text.trim(),
          );
      if (!mounted) return;
      if (r.durum != 'hazir' || r.setupToken == null) {
        // onay_bekliyor: uc sart tutmadi — hesap acilmaz.
        setState(() {
          _bekliyor = false;
          _adim = _Adim.onayBekliyor;
        });
        return;
      }
      // PAROLA IKI KEZ SORULMAZ: kullanici 3. adimda yazdi. Jetonu
      // denetleyiciye verip parolayi HEMEN gonderiyoruz; `/set-password`
      // ekrani hic gorunmez.
      final denetleyici = ref.read(authControllerProvider.notifier);
      denetleyici.kayitKodunuOnayla(r.setupToken!);
      await denetleyici.submitNewPassword(_parolaCtrl.text);
      if (!mounted) return;
      final durum = ref.read(authControllerProvider);
      if (durum.status != AuthStatus.authenticated) {
        setState(() {
          _hata = durum.errorMessage;
          _bekliyor = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = e.message;
        _bekliyor = false;
      });
    }
  }

  void _geri() {
    // GERI DONMEK yarim kalmis bir SOSYAL baglamayi da birakmali.
    ref.read(authControllerProvider.notifier).oauthIptal();
    setState(() {
      _hata = null;
      _adim = switch (_adim) {
        _Adim.kod => _Adim.tesisKodu,
        _Adim.tesisKodu => _yol == _Yol.sosyal ? _Adim.yontem : _Adim.bilgiler,
        _Adim.bilgiler => _Adim.yontem,
        _ => _Adim.rol,
      };
    });
  }

  String _rolEtiketi(KayitRolu rol) {
    final l10n = context.l10n;
    return switch (rol) {
      KayitRolu.sakin => l10n.kayitRolSakin,
      KayitRolu.guvenlik => l10n.kayitRolGuvenlik,
      KayitRolu.tesisGorevlisi => l10n.kayitRolTesisGorevlisi,
    };
  }

  IconData _rolSimgesi(KayitRolu rol) => switch (rol) {
        KayitRolu.sakin => Icons.home_outlined,
        KayitRolu.guvenlik => Icons.shield_outlined,
        KayitRolu.tesisGorevlisi => Icons.handyman_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final adimNo = switch (_adim) {
      _Adim.rol => 1,
      _Adim.yontem => 2,
      _Adim.bilgiler => 3,
      _Adim.tesisKodu => _yol == _Yol.sosyal ? 3 : 4,
      _Adim.kod => _toplamAdim,
      _Adim.onayBekliyor => _toplamAdim,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.kayitBaslik),
        // ONAY BEKLIYOR terminal adimdir; geri donulecek adim yok.
        leading: (_adim == _Adim.rol || _adim == _Adim.onayBekliyor)
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
                  if (_adim != _Adim.onayBekliyor) ...[
                    Text(
                      l10n.kayitAdim('$adimNo', '$_toplamAdim'),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_hata != null) ...[
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
                  if (_adim == _Adim.yontem) _yontemSecimi(l10n),
                  if (_adim == _Adim.bilgiler) _bilgiFormu(l10n),
                  if (_adim == _Adim.tesisKodu) _tesisKoduFormu(l10n),
                  if (_adim == _Adim.kod) _kodFormu(l10n),
                  if (_adim == _Adim.onayBekliyor) _onayBekliyorKarti(l10n),
                  const SizedBox(height: 24),
                  if (_adim != _Adim.onayBekliyor)
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

  // ============================ ADIM 1 ==================================== //

  Widget _rolSecimi(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.kayitAltBaslik),
        const SizedBox(height: 12),
        for (final rol in KayitRolu.values) ...[
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              key: Key('kayit-rol-${rol.kimlik}'),
              leading: Icon(_rolSimgesi(rol)),
              title: Text(_rolEtiketi(rol)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() {
                _rol = rol;
                // (P211-ek3) SSO KIMLIGI ZATEN ELIMIZDE (giristen
                // devredildi): tarayici akisini TEKRARLAMAYIZ, dogrudan
                // Tesis ID adimina geceriz. Yontem adimini gostermek
                // kullaniciya "Google ile devam et"i IKINCI kez
                // sordurmak olurdu.
                _adim = ref.read(authControllerProvider).oauthBaglamaJetonu != null
                    ? _Adim.tesisKodu
                    : _Adim.yontem;
              }),
            ),
          ),
        ],
      ],
    );
  }

  // ============================ ADIM 2 ==================================== //

  Widget _yontemSecimi(AppLocalizations l10n) {
    final saglayicilar =
        ref.watch(oauthSaglayicilarProvider).value ?? const <String>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.kayitYontemBaslik,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        for (final s in saglayicilar) ...[
          FilledButton.tonal(
            key: Key('kayit-yontem-$s'),
            onPressed: _bekliyor ? null : () => _sosyalYolunuSec(s),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(l10n.sosyalIleDevam(kSaglayiciEtiketi[s] ?? s)),
          ),
          const SizedBox(height: 8),
        ],
        if (saglayicilar.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  l10n.kayitYontemVeya,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
        ],
        OutlinedButton(
          key: const Key('kayit-yontem-parola'),
          onPressed: _bekliyor ? null : _parolaYolunuSec,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          child: _bekliyor
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Text(l10n.kayitYontemEposta),
        ),
      ],
    );
  }

  // ============================ ADIM 3 (parola) ========================== //

  Widget _bilgiFormu(AppLocalizations l10n) {
    return Form(
      key: _bilgiFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.kayitBilgilerBaslik,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _adCtrl,
            key: const Key('kayit-ad'),
            enabled: !_bekliyor,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l10n.kayitAdSoyad,
              prefixIcon: const Icon(Icons.person_outline),
              border: const OutlineInputBorder(),
            ),
            validator: (v) =>
                (v ?? '').trim().length < 2 ? l10n.kayitAdGerekli : null,
          ),
          const SizedBox(height: 16),
          // E-POSTA ZORUNLU: dogrulama kanali budur.
          TextFormField(
            controller: _epostaCtrl,
            key: const Key('kayit-eposta'),
            enabled: !_bekliyor,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.kayitEposta,
              prefixIcon: const Icon(Icons.mail_outline),
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return l10n.kayitEpostaGerekli;
              if (!_epostaGecerli(s)) return l10n.kayitEpostaGecersiz;
              return null;
            },
          ),
          const SizedBox(height: 16),
          // TELEFON ISTEGE BAGLI — yalniz iletisim; dogrulama araci DEGIL.
          TextFormField(
            controller: _telefonCtrl,
            key: const Key('kayit-telefon'),
            enabled: !_bekliyor,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.phone,
            inputFormatters: const [TelefonBicimlendirici()],
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.kayitTelefonIletisim,
              hintText: l10n.ortakTelefonIpucu,
              helperText: l10n.kayitTelefonNotu,
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.phone_outlined),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _parolaCtrl,
            key: const Key('kayit-parola'),
            enabled: !_bekliyor,
            obscureText: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.kayitParola,
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
            ),
            validator: (v) =>
                (v ?? '').length < 8 ? l10n.kayitParolaGerekli : null,
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('kayit-bilgi-gonder'),
            onPressed: _bekliyor ? null : _bilgileriGonder,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(l10n.kayitDevam),
          ),
        ],
      ),
    );
  }

  bool _epostaGecerli(String s) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);

  // ============================ ADIM 4 ==================================== //

  Widget _tesisKoduFormu(AppLocalizations l10n) {
    return Form(
      key: _tesisKoduFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.kayitTesisKoduGir,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _tesisKoduCtrl,
            key: const Key('kayit-tesis-kodu'),
            enabled: !_bekliyor,
            textInputAction: TextInputAction.done,
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
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('kayit-rol-ozel-gonder'),
            onPressed: _bekliyor ? null : _tesisKoduGonder,
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

  // ============================ ADIM 5 ==================================== //

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
          // METIN BILEREK BELIRSIZ: sunucu adresin kayitli olup olmadigini
          // SOYLEMIYOR (tarama araci olmasin diye). "Kod gonderildi" demek o
          // korumayi bozardi; bunun yerine kodun GELMEYEBILECEGI yaziyor.
          Text(l10n.kayitKodAciklamaEposta(_tesisAd)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _kodCtrl,
            enabled: !_bekliyor,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _kodGonder(),
            decoration: InputDecoration(
              labelText: l10n.kayitKodAlani,
              // E-POSTA kodu: SMS simgesi DEGIL.
              prefixIcon: const Icon(Icons.mail_outline),
              border: const OutlineInputBorder(),
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? l10n.kayitKodGerekli : null,
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

  // ========================= ONAY BEKLIYOR =============================== //

  /// (P184) Uc sart tutmadi (liste disi e-posta VEYA gecersiz Tesis ID —
  /// AYNI mesaj, sizdirmama). Hesap ACILMADI; kullaniciya ne olacagi soylenir.
  Widget _onayBekliyorKarti(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.hourglass_top_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.kayitOnayBekliyorBaslik,
          key: const Key('kayit-onay-bekliyor'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.kayitOnayBekliyorAciklama,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('kayit-onay-girise-don'),
          onPressed: () => context.go(AppRoutes.login),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          child: Text(l10n.kayitGiriseDon),
        ),
      ],
    );
  }
}
