import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/branding/yonetio_logo.dart';
import '../../../core/i18n/l10n.dart';
import '../data/auth_repository_impl.dart';
import 'auth_controller.dart';
import 'giris_hata_metni.dart';
import 'sosyal_giris.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../../tesis/domain/tesis_uyeligi.dart';
import '../domain/user_role.dart';
import 'rol_adi.dart';
import 'sifremi_unuttum.dart';
import '../../../routing/app_router.dart';

/// GIRIS EKRANI.
///
/// (P205 §1) TEK ALAN: "E-posta veya telefon numarasi". Eskiden yalniz
/// TELEFON kabul ediliyordu; P197'den beri e-posta zorunlu, telefon
/// OPSIYONEL oldugu icin telefonsuz kaydolmus bir yonetici mobile hic
/// giremiyordu. Girdinin hangisi oldugunu SUNUCU cozer (backend
/// `app/kimlik.py`) — burada yalnizca "@" var mi diye bakilir, cunku
/// telefon yolu ILK GIRIS (`setup_token`) akisini tasiyor.
///
/// Ilk giriste gecici parola girilince parola belirleme ekranina gecilir.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _kimlikCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  // (P247 §4) Varsayilan ISARETLI: telefon kisisel cihazdir ve oturum 30
  // gun surer. Ortak cihazda kullanici kutuyu kaldirir.
  bool _rememberMe = true;

  // (E2E 2026-09, YETKI-13) E-POSTA KODUYLA GIRIS — web'deki "Parola yerine
  // e-postaya kod gonder" akisinin ikizi. Mod ekranin ICINDE: ayri bir rota
  // acmak, geri tusuyla yarim kalmis bir duruma dusmek demekti.
  final _kodCtrl = TextEditingController();
  bool _kodModu = false;
  bool _kodGonderildi = false;

  /// Istemcide uretilen hata (sunucuya gitmeden once) — or. telefonla kod
  /// istemek. Sunucu hatalari `AuthState`te durur.
  String? _yerelHata;

  @override
  void initState() {
    super.initState();
    _prefillSavedCredentials();
  }

  /// "Beni hatirla" ile saklanmis giris bilgileri varsa alanlari ON-DOLDURUR.
  ///
  /// (P170 §1) CIKIS SONRASI ARTIK ON-DOLU GELMEZ: `logout` saklanan
  /// bilgileri de siliyor (bkz. `AuthRepositoryImpl.logout`). Bu yol
  /// uygulamanin yeniden acilisinda ve oturum suresi dolunca calisir.
  Future<void> _prefillSavedCredentials() async {
    final saved = await ref.read(authRepositoryProvider).readSavedCredentials();
    if (saved == null || !mounted) return;
    setState(() {
      _kimlikCtrl.text = saved.phone;
      _rememberMe = true;
    });
  }

  @override
  void dispose() {
    _kimlikCtrl.dispose();
    _passwordCtrl.dispose();
    _kodCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_kodModu) {
      await (_kodGonderildi ? _kodlaGir() : _kodIste());
      return;
    }
    final secim = await ref.read(authControllerProvider.notifier).girisYap(
          kimlik: _kimlikCtrl.text,
          password: _passwordCtrl.text,
          rememberMe: _rememberMe,
        );
    // (P205 §1) BIRDEN COK TESIS: kullanicidan bir KARAR isteniyor.
    // Rastgele birini secmek, onu bilmedigi bir tesise sokmak olurdu.
    if (secim != null && secim.length > 1 && mounted) {
      await _tesisSec(secim);
    }
  }

  /// (E2E 2026-09, YETKI-13) Kod iste. KOD YOLU E-POSTAYA BAGLI (web P212
  /// §1 ile ayni): telefon yazilmissa istekten ONCE ve ACIKCA soylenir.
  Future<void> _kodIste() async {
    final eposta = _kimlikCtrl.text.trim();
    if (!eposta.contains('@')) {
      setState(() => _yerelHata = context.l10n.girisKodYalnizEposta);
      return;
    }
    setState(() => _yerelHata = null);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .epostaGirisKoduIste(eposta);
    if (ok && mounted) setState(() => _kodGonderildi = true);
  }

  Future<void> _kodlaGir({String? tenantSlug}) async {
    final ctrl = ref.read(authControllerProvider.notifier);
    final sonuc = await ctrl.epostaKoduylaGir(
      eposta: _kimlikCtrl.text.trim(),
      kod: _kodCtrl.text.trim(),
      tenantSlug: tenantSlug,
    );
    if (sonuc != EpostaKodSonucu.tesisSecimiGerekli || !mounted) return;
    // BIRDEN COK TESIS: kodun tuttugu tesis listesini veren bir uc YOK
    // (`/auth/tesislerim` PAROLA ister). Kullanicidan tesis kodunu alip
    // AYNI kodla o tesise gireriz — web sifre sifirlamadaki alanin aynisi.
    final slug = await merkezSayfaAc<String>(
      context,
      builder: (_) => const TesisKoduSorusu(),
    );
    if (slug == null || !mounted) return;
    await _kodlaGir(tenantSlug: slug);
  }

  void _kodModunuDegistir() {
    ref.read(authControllerProvider.notifier).girisHatasiniTemizle();
    setState(() {
      _kodModu = !_kodModu;
      _kodGonderildi = false;
      _kodCtrl.clear();
      _yerelHata = null;
    });
  }

  Future<void> _sifremiUnuttum() async {
    // Parola sifirlama E-POSTAYLA calisir; telefon yazilmissa on-doldurma
    // YAPILMAZ (web ile ayni gerekce).
    final k = _kimlikCtrl.text.trim();
    final eposta = await merkezSayfaAc<String>(
      context,
      builder: (_) => SifremiUnuttumFormu(eposta: k.contains('@') ? k : null),
    );
    // Sifirlama tamamlandi: yeni parolayla giris icin adres on-dolar.
    if (eposta != null && mounted) {
      setState(() {
        _kimlikCtrl.text = eposta;
        _passwordCtrl.clear();
      });
    }
  }

  /// (P205 §1) COK TESISLI KULLANICI — SECIM.
  ///
  /// Sunucu 409 `tesis_secimi_gerekli` dedi. Liste `/auth/tesislerim`den
  /// geldi ve KAPANMAYAN bir sayfa olarak degil, KAPANABILIR bir sayfa
  /// olarak gosterilir: kullanici vazgecip baska bir hesapla girmek
  /// isteyebilir.
  Future<void> _tesisSec(List<TesisUyeligi> liste) async {
    final l10n = context.l10n;
    // MERKEZ DIYALOG (tur 31 karari): alt sayfa DEGIL — uygulamada tek
    // bir pencere bicimi var ve `merkez_diyalog_test` bunu kaynak
    // taramasiyla kilitliyor.
    final secilen = await merkezSayfaAc<TesisUyeligi>(
      context,
      builder: (c) => SafeArea(
        child: Column(
          key: const Key('giris-tesis-secimi'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                l10n.girisTesisSec,
                style: Theme.of(c).textTheme.titleMedium,
              ),
            ),
            for (final u in liste)
              ListTile(
                key: Key('giris-tesis-${u.slug}'),
                title: Text(u.ad),
                // ROL GORUNUR: ayni kisi birinde yonetici, otekinde
                // sakin olabilir — hangi yetkiyle girecegini SECMEDEN
                // ONCE bilmeli.
                subtitle: Text(rolAdi(l10n, UserRole.fromClaim(u.rol))),
                onTap: () => Navigator.of(c).pop(u),
              ),
          ],
        ),
      ),
    );
    if (secilen == null || !mounted) return;
    // IKINCI GIRIS: ayni kimlik + parola, bu kez SLUG ile. Jetonu ilk
    // istekte uretip beklemek, kullanici secmeden once bir tesise
    // baglanmak olurdu.
    await ref.read(authControllerProvider.notifier).girisYap(
          kimlik: _kimlikCtrl.text,
          password: _passwordCtrl.text,
          tenantSlug: secilen.slug,
          rememberMe: _rememberMe,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final submitting = auth.submitting;
    final l10n = context.l10n;
    final hata =
        _yerelHata ?? girisHatasiCoz(l10n, auth.hataKimligi, auth.errorMessage);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              // (P154 / Asama 4) SOSYAL HESAP DOGRULANDI AMA ESLESMEDI:
              // ekran eslestirme moduna gecer. Ayri bir rota DEGIL —
              // akis giristen ayrilmaz ve geri tusuyla yarim kalmis bir
              // duruma dusulmez.
              // (P211 §1) SSO SONRASI TESIS SECIMI — Tesis ID formundan
              // ONCE bakilir. Iki durum ayni ekranda ama AYRI mod:
              // biri "hangi tesise gireceksin" (secim), oteki "hesabini
              // Tesis ID ile bagla" (baglama). Sirasi onemli: cok
              // tesisli yonetici artik kod ezberlemez.
              child: auth.oauthSecimJetonu != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: YonetioLogoVertical(iconSize: 100)),
                        const SizedBox(height: 28),
                        Text(
                          l10n.girisTesisSec,
                          key: const Key('sso-tesis-secimi'),
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        for (final t in auth.oauthTesisler)
                          Card(
                            child: ListTile(
                              key: Key('sso-tesis-${t.slug}'),
                              title: Text(t.ad),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: submitting
                                  ? null
                                  : () => ref
                                      .read(authControllerProvider.notifier)
                                      .oauthTesisSec(t.tenantId),
                            ),
                          ),
                        if (hata != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              hata,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    )
                  // (P211-ek3) SSO KIMLIGI BIR HESABA BAGLI DEGIL.
                  //
                  // BURADA ARTIK TESIS ID SORULMUYOR. Kural: Tesis ID
                  // YALNIZ KAYIT akisinda sorulur (davet e-postasindaki
                  // kod), giriste ASLA. Eskiden bu dalda `SosyalBaglamaFormu`
                  // ciziliyor ve giris ekrani bir kayit formuna
                  // donusuyordu.
                  //
                  // Jeton STATE'TE DURUR: kayit ekrani onu bulunca
                  // tarayici akisini TEKRARLAMAZ, yalniz rol + Tesis ID
                  // sorar.
                  : auth.oauthBaglamaJetonu != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: YonetioLogoVertical(iconSize: 100)),
                        const SizedBox(height: 28),
                        Text(
                          l10n.girisHesapBagliDegil,
                          key: const Key('sso-hesap-bagli-degil'),
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.girisHesapBagliDegilAlt,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          key: const Key('sso-kayda-git'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: submitting
                              ? null
                              : () => context.go(AppRoutes.kayit),
                          child: Text(l10n.girisKayitBaglantisi),
                        ),
                        // "Zaten hesabim var" yolu: PAROLA ILE GIRIS.
                        // Sosyal hesabini kendi hesabina baglamak isteyen
                        // kullanici bunu web panelinden yapar (mobilde
                        // "bagli hesaplar" ekrani HENUZ YOK — acik madde,
                        // docs/P211-kararlar.md §8).
                        TextButton(
                          key: const Key('sso-vazgec'),
                          onPressed: submitting
                              ? null
                              : () => ref
                                  .read(authControllerProvider.notifier)
                                  .oauthIptal(),
                          child: Text(l10n.ortakVazgec),
                        ),
                      ],
                    )
                  : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: YonetioLogoVertical(iconSize: 100)),
                    const SizedBox(height: 28),
                    // (P205 §1) TEK ALAN — E-POSTA VEYA TELEFON.
                    //
                    // Eskiden yalniz TELEFON vardi ve bu OLCULEN bir
                    // kusurdu: P197'den beri e-posta ZORUNLU, telefon
                    // OPSIYONEL — web'den e-posta+parolayla kaydolmus,
                    // telefon girmemis bir yonetici mobile HIC
                    // GIREMIYORDU.
                    //
                    // `TelefonBicimlendirici` KALDIRILDI: rakam disini
                    // yutuyordu, yani e-posta YAZILAMIYORDU.
                    // `keyboardType` de `emailAddress` — iki kimlik
                    // icin de yazilabilir tek klavye.
                    TextFormField(
                      key: const Key('giris-kimlik'),
                      controller: _kimlikCtrl,
                      enabled: !submitting,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.username],
                      decoration: InputDecoration(
                        labelText: l10n.girisKimlik,
                        hintText: l10n.girisKimlikOrnek,
                        helperText: l10n.girisKimlikYardim,
                        helperMaxLines: 2,
                        prefixIcon: const Icon(Icons.person_outline),
                        border: const OutlineInputBorder(),
                      ),
                      // BICIM DENETIMI YOK (bos disinda): girdi telefon
                      // OLMAK ZORUNDA DEGIL ve "gecerli bir telefon
                      // girin" demek, e-posta yazan kullaniciyi
                      // engellerdi. Gecersiz kimlik SUNUCUDAN jenerik
                      // 401 alir — belirsizlik orada BILINCLI.
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? l10n.girisKimlikGerekli
                          : null,
                    ),
                    const SizedBox(height: 16),
                    // (E2E 2026-09, YETKI-13) KOD MODU: parola alani yerine
                    // (kod gonderildiyse) kod alani.
                    if (_kodModu) ...[
                      if (_kodGonderildi) ...[
                        Text(
                          l10n.girisEpostaKodGonderildi,
                          key: const Key('giris-kod-gonderildi'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('giris-eposta-kod'),
                          controller: _kodCtrl,
                          enabled: !submitting,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: l10n.girisKodAlani,
                            prefixIcon: const Icon(Icons.pin_outlined),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().length < 4)
                              ? l10n.girisKodAlani
                              : null,
                        ),
                      ],
                    ] else ...[
                    TextFormField(
                      controller: _passwordCtrl,
                      enabled: !submitting,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: l10n.girisParolaVeyaKod,
                        helperText: l10n.girisIlkKodIpucu,
                        helperMaxLines: 2,
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          // EKRAN OKUYUCU: etiketsiz dugme yalnizca "dugme"
                          // diye okunur (tur 29 surusu yakaladi). Etiket
                          // DURUMA gore degisir ki kullanici ne olacagini
                          // bilsin — ve elbette cevrilidir.
                          tooltip: _obscure
                              ? l10n.ortakParolayiGoster
                              : l10n.ortakParolayiGizle,
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v ?? '').isEmpty ? l10n.ortakParolaZorunlu : null,
                    ),
                    const SizedBox(height: 8),
                    // Isaretliyse oturum kalici saklanir → sonraki acilista
                    // sifre sorulmadan dogrudan ana ekran.
                    CheckboxListTile(
                      key: const Key('remember_me_checkbox'),
                      value: _rememberMe,
                      onChanged: submitting
                          ? null
                          : (v) => setState(() => _rememberMe = v ?? false),
                      title: Text(l10n.girisBeniHatirla),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    ],
                    if (hata != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBanner(message: hata),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: submitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : Text(
                              _kodModu && !_kodGonderildi
                                  ? l10n.girisEpostaKodGonder
                                  : l10n.girisYap,
                            ),
                    ),
                    // (E2E 2026-09, YETKI-13) Web'deki iki yol: "Parola
                    // yerine e-postaya kod gonder" ve "Sifremi unuttum".
                    TextButton(
                      key: const Key('giris-kod-modu'),
                      onPressed: submitting ? null : _kodModunuDegistir,
                      child: Text(
                        _kodModu ? l10n.girisParolaylaDon : l10n.girisKodIleEposta,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (!_kodModu)
                      TextButton(
                        key: const Key('giris-sifremi-unuttum'),
                        onPressed: submitting ? null : _sifremiUnuttum,
                        child: Text(l10n.girisSifremiUnuttum),
                      ),
                    // (P184) PAROLASIZ (SMS) GIRIS KALDIRILDI: SMS kapali.
                    // (E2E 2026-09) E-posta kodu artik tesis kodu ISTEMIYOR
                    // (P205 §1) ve yukaridaki "kod gonder" yolu onu kullanir;
                    // giris ekraninda SMS vaadi yine YOK (kabul 1).
                    //
                    // (P211-ek3) SIRA DEGISTI: SSO dugmeleri PAROLANIN
                    // HEMEN ALTINDA, kayit baglantisi EN ALTTA. Eskiden
                    // araya kayit baglantisi giriyordu; "giris yollari"
                    // ile "hesabim yok" ayni oburde gorunuyordu.
                    const SosyalGirisDugmeleri(),
                    // (P154 / Asama 3) KAYIT KAPISI. Hesabi yonetici
                    // aciyor ama kisi onu SAHIPLENMEDEN giremiyor; bu
                    // baglanti olmadan kayit ekranina ulasilamazdi.
                    //
                    // (P211-ek3) ETIKET DUZELTILDI. `kayitBaslik` metni
                    // "Tesis ID ile giris" idi ve bu YANLIS iki sey
                    // soyluyordu: (a) burasi bir GIRIS yolu degil KAYIT
                    // yolu, (b) giriste Tesis ID SORULMAZ. Kullanici
                    // haklı olarak "giris ekraninda Tesis ID baglantisi
                    // var" diye bildirdi.
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('login-kayit-baglantisi'),
                      onPressed:
                          submitting ? null : () => context.go(AppRoutes.kayit),
                      child: Text(l10n.girisKayitBaglantisi),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
