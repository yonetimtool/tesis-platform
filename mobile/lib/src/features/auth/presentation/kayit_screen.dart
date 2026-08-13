import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/startup/acilis_tercihleri.dart';
import '../../../core/ui/telefon_alani.dart';
import '../../../core/ui/telefon_hata_metni.dart';
import '../../../routing/app_router.dart';
import '../data/auth_api.dart';
import 'auth_controller.dart';
import 'sosyal_giris.dart';

/// (P155r2) ROL SECIMLI KAYIT — mobil yuzey, SARTNAME SIRASIYLA.
///
/// ===========================================================================
/// SIRA DEGISTI: rol -> YONTEM -> bilgiler -> ROLE OZEL
/// ===========================================================================
/// P154'te sira `rol -> tesis kodu+telefon -> yontem -> kod` idi. Sartname
/// §2 acikca yontemi ROL SECIMINDEN HEMEN SONRA istiyor ve gerekcesi
/// urun tarafinda: kullaniciya once "nasil giris yapacaksin" sorulur,
/// tesis bilgisi ondan SONRA gelir. Eski sirada sosyal hesapla kaydolmak
/// isteyen kisi once iki alan doldurmak zorundaydi.
///
/// ADIMLAR (sartname §2/§3):
///   1. ROL          — dort rol (web AYRI kume sunar: yonetici + denetci)
///   2. YONTEM       — once sosyal, sonra "E-posta/telefon ile kaydol"
///   3. BILGILER     — ad soyad + telefon (+ parola, elle kayitta)
///   4. ROLE OZEL    — yonetici: TESIS ADI · oteki roller: TESIS KODU
///   5. KOD          — yalniz eslesme yolunda (yonetici-yeni'de YOK)
///
/// ===========================================================================
/// YONETICI ICIN IKI CIKIS: yeni tesis VEYA var olana katilma
/// ===========================================================================
/// Sartname §3: "Tesis adini giriniz" alaninin ALTINDA "Zaten bir sitem
/// var" bagi; ikinci/ucuncu yonetici boyle katilir.
///
/// KATILMA, TESIS ACMA DEGIL BIR ROL ESLESMESIDIR ve bu KISITLAR'dan
/// geliyor: "Kod bilen biri kayit olamamali, yalniz onceden eklenmis
/// telefonla eslesen kaydolur." Yani ikinci yonetici de mevcut yonetici
/// tarafindan EKLENMIS olmali. Aksi tasarim (kodu bilen yonetici olur)
/// tesisin tamamen devralinmasi demekti — kod kamuya acik ve tahmin
/// edilebilir (goc 0037 guvenlik notu).
///
/// Bu yuzden "Zaten bir sitem var" yalnizca `_katil` bayragini kaldirir
/// ve akis oteki rollerle AYNI yola (tesis kodu + eslesme) duser.
///
/// ===========================================================================
/// PAROLA IKI KEZ SORULMAZ
/// ===========================================================================
/// Kullanici paroласini 3. adimda giriyor. Eslesme yolunda sunucu, kod
/// dogrulaninca bir `setup_token` doner ve normalde `/set-password`
/// ekrani acilirdi — kullaniciya AZ ONCE yazdigi parolayi tekrar
/// sordururdu. Bunun yerine jeton alinir alinmaz parola OTOMATIK
/// gonderilir; ekran hic gorunmez.
///
/// ===========================================================================
/// SMS NEDEN HÂLÂ VAR (eslesme yolunda)
/// ===========================================================================
/// Saglayici "bu Google hesabinin sahibisin" der; "bu telefonun
/// sahibisin" DEMEZ. Tesis kodu kamuya acik, telefon numarasi sir degil —
/// ikisi birlikte kimlik kaniti DEGILDIR. Var olan bir hesabi
/// SAHIPLENMEK icin telefon sahipligi kanitlanmali.
///
/// YONETICI-YENI yolunda SMS YOKTUR ve celiski degil: orada
/// sahiplenilecek bir hesap yok — hesap O ANDA yaratiliyor ve numara
/// bos olmak zorunda. Kanitlanacak bir sahiplik yok.
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

  /// YALNIZ sakinden daire istenir (sartname). Yoneticiye daire sormak,
  /// dairesi olmayan birine zorunlu alan gostermek olurdu.
  bool get daireIster => this == KayitRolu.sakin;
}

enum _Adim { rol, yontem, bilgiler, rolOzel, kod, sonuc }

/// Kimlik dogrulama yolu — hangi ucun kullanilacagini belirler.
enum _Yol { parola, sosyal }

class _KayitScreenState extends ConsumerState<KayitScreen> {
  final _bilgiFormKey = GlobalKey<FormState>();
  final _rolOzelFormKey = GlobalKey<FormState>();
  final _kodFormKey = GlobalKey<FormState>();

  final _adCtrl = TextEditingController();
  final _telefonCtrl = TextEditingController();
  final _parolaCtrl = TextEditingController();
  final _tesisAdCtrl = TextEditingController();
  final _tesisKoduCtrl = TextEditingController();
  final _daireCtrl = TextEditingController();
  final _blokCtrl = TextEditingController();
  final _kodCtrl = TextEditingController();

  _Adim _adim = _Adim.rol;
  KayitRolu _rol = KayitRolu.yonetici;
  _Yol _yol = _Yol.parola;

  /// Yonetici VAR OLAN bir tesise katiliyor mu ("Zaten bir sitem var")?
  bool _katil = false;

  String _tesisAd = '';
  String _telefonMaskeli = '';
  String _uretilenKod = '';
  String? _hata;
  bool _bekliyor = false;

  /// Yonetici YENI tesis aciyorsa SMS adimi yoktur → 4 adim; oteki her
  /// durumda eslesme + kod adimi var → 5.
  bool get _tesisAcar => _rol == KayitRolu.yonetici && !_katil;
  int get _toplamAdim => _tesisAcar ? 4 : 5;

  @override
  void initState() {
    super.initState();
    // (P154 / Asama 2) ROL LISTESI GORULDU. Bayrak EKRAN ACILIRKEN
    // yaziliyor, "kaydolma tamamlaninca" degil: sartname listeyi ILK
    // ACILISIN ekrani sayar, kaydolmanin odulu saymaz.
    //
    // `Future(...)` DEGIL `addPostFrameCallback`: ilki bir ZAMANLAYICI
    // kurar ve agac calismadan once atilirsa `flutter_test` "A Timer is
    // still pending" ile duser (olculdu). Kare geri cagrisi agacla
    // birlikte duser.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(rolSecimiBekliyorProvider.notifier).gosterildi());
    });
  }

  @override
  void dispose() {
    _adCtrl.dispose();
    _telefonCtrl.dispose();
    _parolaCtrl.dispose();
    _tesisAdCtrl.dispose();
    _tesisKoduCtrl.dispose();
    _daireCtrl.dispose();
    _blokCtrl.dispose();
    _kodCtrl.dispose();
    super.dispose();
  }

  String get _telefon => telefonNormalle(_telefonCtrl.text);

  // ======================= ADIM 2: YONTEM ================================= //

  void _parolaYolunuSec() {
    setState(() {
      _yol = _Yol.parola;
      _hata = null;
      _adim = _Adim.bilgiler;
    });
  }

  /// Sosyal yol: once tarayici akisi (saglayici kimligi kanitlar), sonra
  /// BILGILER adimi — ad soyad saglayicidan ON-DOLDURULUR.
  Future<void> _sosyalYolunuSec(String saglayici) async {
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    final denetleyici = ref.read(authControllerProvider.notifier);
    // ONCE TEMIZLE: onceki denemeden kalmis bir baglama jetonu olabilir
    // (Google secildi, hata alindi, bu kez Apple secildi). Temizlemezsek
    // ESKI saglayicinin jetonuyla devam ederdik.
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
      // SARTNAME §2: saglayicidan gelen ad soyad forma OTOMATIK DOLAR ve
      // kullanici duzeltebilir. Apple ad vermez → alan bos kalir,
      // kullanici yazar. Telefon HICBIR saglayicidan gelmez.
      //
      // KULLANICININ YAZDIGI EZILMEZ: geri donup baska bir saglayici
      // secen birinin duzelttigi ad korunur.
      if (_adCtrl.text.trim().isEmpty && (durum.oauthAd ?? '').isNotEmpty) {
        _adCtrl.text = durum.oauthAd!;
      }
      _bekliyor = false;
      _adim = _Adim.bilgiler;
    });
  }

  // ======================= ADIM 3: BILGILER =============================== //

  void _bilgileriGonder() {
    FocusScope.of(context).unfocus();
    if (!_bilgiFormKey.currentState!.validate()) return;
    setState(() {
      _hata = null;
      _adim = _Adim.rolOzel;
    });
  }

  // ======================= ADIM 4: ROLE OZEL ============================== //

  Future<void> _rolOzelGonder() async {
    FocusScope.of(context).unfocus();
    if (!_rolOzelFormKey.currentState!.validate()) return;
    if (_tesisAcar) {
      await _tesisiAc();
    } else {
      await _eslesmeyeBasla();
    }
  }

  /// Yonetici YENI tesis aciyor: tek istekte tesis + hesap + oturum.
  Future<void> _tesisiAc() async {
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    final sonuc = await ref.read(authControllerProvider.notifier).tesisOlustur(
          tesisAd: _tesisAdCtrl.text.trim(),
          ad: _adCtrl.text.trim(),
          telefon: _telefon,
          parola: _yol == _Yol.parola ? _parolaCtrl.text : null,
          sosyal: _yol == _Yol.sosyal,
        );
    if (!mounted) return;
    if (sonuc == null) {
      setState(() {
        _bekliyor = false;
        _hata = ref.read(authControllerProvider).errorMessage;
      });
      return;
    }
    // OTURUM ZATEN ACIK. Router'i hemen birakmiyoruz: kullaniciya TESIS
    // KODUNU gostermeliyiz (sartname §4 — SMS saglayicisi baglanana
    // kadar yonetici kodu ELLE iletecek). "Devam et" deyince ana ekrana
    // duser; `authenticated` oldugu icin yonlendirme kendiliginden olur.
    setState(() {
      _tesisAd = sonuc.tesisAd;
      _uretilenKod = sonuc.tesisKodu;
      _bekliyor = false;
      _adim = _Adim.sonuc;
    });
  }

  /// Oteki roller (+ katilan yonetici): tesis kodu + telefon eslesmesi.
  Future<void> _eslesmeyeBasla() async {
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    try {
      final ({String tesisAd, String telefonMaskeli}) sonuc;
      if (_yol == _Yol.sosyal) {
        final s = await ref
            .read(authControllerProvider.notifier)
            .oauthBaglanBasla(
              tesisKodu: _tesisKoduCtrl.text.trim(),
              telefon: _telefon,
            );
        if (s == null) {
          if (!mounted) return;
          setState(() {
            _bekliyor = false;
            _hata = ref.read(authControllerProvider).errorMessage;
          });
          return;
        }
        sonuc = s;
      } else {
        sonuc = await ref.read(authApiProvider).rolKayitBasla(
              rol: _rol.kimlik,
              tesisKodu: _tesisKoduCtrl.text.trim(),
              telefon: _telefon,
              daireNo: _rol.daireIster ? _daireCtrl.text.trim() : null,
              blok: _rol.daireIster ? _blokCtrl.text.trim() : null,
            );
      }
      if (!mounted) return;
      setState(() {
        _tesisAd = sonuc.tesisAd;
        _telefonMaskeli = sonuc.telefonMaskeli;
        _bekliyor = false;
        _adim = _Adim.kod;
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

  // ========================= ADIM 5: KOD ================================== //

  Future<void> _kodGonder() async {
    FocusScope.of(context).unfocus();
    if (!_kodFormKey.currentState!.validate()) return;
    setState(() {
      _bekliyor = true;
      _hata = null;
    });

    // SOSYAL YOL: kod dogrulanınca kimlik BAGLANIR ve oturum acilir —
    // parola yoktur (kullanici parola istemedigini zaten secti).
    if (_yol == _Yol.sosyal) {
      await ref.read(authControllerProvider.notifier).oauthBaglanDogrula(
            telefon: _telefon,
            kod: _kodCtrl.text.trim(),
          );
      if (!mounted) return;
      final durum = ref.read(authControllerProvider);
      if (durum.status != AuthStatus.authenticated) {
        setState(() {
          _hata = durum.errorMessage;
          _bekliyor = false;
        });
      }
      return;
    }

    try {
      final jeton = await ref.read(authApiProvider).rolKayitDogrula(
            telefon: _telefon,
            kod: _kodCtrl.text.trim(),
          );
      if (!mounted) return;
      // PAROLA IKI KEZ SORULMAZ: kullanici 3. adimda yazdi. Jetonu
      // denetleyiciye verip parolayi HEMEN gonderiyoruz; `/set-password`
      // ekrani hic gorunmez. (Ekran korunuyor — davet ve gecici kod
      // yollari onu hâlâ kullaniyor.)
      final denetleyici = ref.read(authControllerProvider.notifier);
      denetleyici.kayitKodunuOnayla(jeton);
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
    // GERI DONMEK yarim kalmis bir SOSYAL baglamayi da birakmali; aksi
    // halde jeton durumda asili kalir ve kullanici giris ekranina
    // dondugunde beklenmedik bir eslestirme formu bulurdu.
    //
    // KOSULSUZ CAGRILIYOR: jeton yalniz kod adiminda degil, sonraki her
    // adimda askida kalabilir. Bekleyen bir sey yokken zararsizdir.
    ref.read(authControllerProvider.notifier).oauthIptal();
    setState(() {
      _hata = null;
      _adim = switch (_adim) {
        _Adim.kod => _Adim.rolOzel,
        _Adim.rolOzel => _Adim.bilgiler,
        _Adim.bilgiler => _Adim.yontem,
        _ => _Adim.rol,
      };
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
      _Adim.yontem => 2,
      _Adim.bilgiler => 3,
      _Adim.rolOzel => 4,
      _Adim.kod => 5,
      _Adim.sonuc => _toplamAdim,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.kayitBaslik),
        // SONUC adiminda geri YOK: hesap ACILDI, geri donulecek bir
        // adim kalmadi.
        leading: (_adim == _Adim.rol || _adim == _Adim.sonuc)
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
                    l10n.kayitAdim('$adimNo', '$_toplamAdim'),
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
                  if (_adim == _Adim.yontem) _yontemSecimi(l10n),
                  if (_adim == _Adim.bilgiler) _bilgiFormu(l10n),
                  if (_adim == _Adim.rolOzel) _rolOzelFormu(l10n),
                  if (_adim == _Adim.kod) _kodFormu(l10n),
                  if (_adim == _Adim.sonuc) _sonucKarti(l10n),
                  const SizedBox(height: 24),
                  if (_adim != _Adim.sonuc)
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
                _katil = false;
                _adim = _Adim.yontem;
              }),
            ),
          ),
        ],
      ],
    );
  }

  // ============================ ADIM 2 ==================================== //

  /// KIMLIK YONTEMI — sartname §2: once SOSYAL onerilir, ayirac, sonra
  /// "E-posta/telefon ile kaydol".
  ///
  /// SOSYAL YALNIZ YAPILANDIRILMISSA: saglayici listesi sunucudan gelir
  /// (`oauthSaglayicilarProvider`) ve bos olabilir. Cizilmeyen bir dugme,
  /// kullaniciyi KESIN BASARISIZ bir yola sokmaktan iyidir —
  /// `SosyalGirisDugmeleri` ile AYNI kural; ikisi ayni provider'i okur
  /// ki liste tek yerden gelsin.
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

  // ============================ ADIM 3 ==================================== //

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
          if (_yol == _Yol.sosyal) ...[
            const SizedBox(height: 8),
            Text(
              l10n.kayitSosyalAdNotu,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
          TextFormField(
            controller: _telefonCtrl,
            key: const Key('kayit-telefon'),
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
          // PAROLA YALNIZ ELLE KAYITTA: sosyal yolda kimlik
          // saglayicidadir ve parola HIC yazilmaz (sunucu da kabul etmez).
          if (_yol == _Yol.parola) ...[
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
          ],
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

  // ============================ ADIM 4 ==================================== //

  Widget _rolOzelFormu(AppLocalizations l10n) {
    return Form(
      key: _rolOzelFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_tesisAcar) ...[
            Text(
              l10n.kayitTesisAdBaslik,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tesisAdCtrl,
              key: const Key('kayit-tesis-ad'),
              enabled: !_bekliyor,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.kayitTesisAd,
                helperText: l10n.kayitTesisAdIpucu,
                prefixIcon: const Icon(Icons.apartment_outlined),
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v ?? '').trim().length < 2 ? l10n.kayitTesisAdGerekli : null,
            ),
            const SizedBox(height: 8),
            // SARTNAME §3: "Tesis adini giriniz" alaninin ALTINDA.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: const Key('kayit-zaten-sitem-var'),
                onPressed: _bekliyor
                    ? null
                    : () => setState(() {
                          _katil = true;
                          _hata = null;
                        }),
                child: Text(l10n.kayitZatenSitemVar),
              ),
            ),
          ] else ...[
            TextFormField(
              controller: _tesisKoduCtrl,
              key: const Key('kayit-tesis-kodu'),
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
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? l10n.kayitDaireGerekli : null,
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
          ],
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('kayit-rol-ozel-gonder'),
            onPressed: _bekliyor ? null : _rolOzelGonder,
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

  // ============================ SONUC ===================================== //

  /// Tesis ACILDI — kod gosterilir ve KOPYALANABILIR.
  ///
  /// SARTNAME §4: "Yonetici tesis kodunu bu arada elle iletir; arayuzde
  /// tesis kodu gorunur ve kopyalanabilir olsun." SMS saglayicisi
  /// baglanana kadar bu ekran, kodun kullaniciya ulastigi TEK yerdir —
  /// bu yuzden ana ekrana atlamiyoruz.
  Widget _sonucKarti(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          _tesisAd,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        Text(
          l10n.kayitTesisKoduBaslik,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  // `SelectableText`: kod KOPYALANACAK bir kimliktir.
                  // Kopyala dugmesi calismasa da (pano izni) kullanici
                  // elle secebilmeli.
                  child: SelectableText(
                    _uretilenKod,
                    key: const Key('kayit-uretilen-kod'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const Key('kayit-kod-kopyala'),
                  tooltip: l10n.kayitKopyala,
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () async {
                    // Messenger `await`TEN ONCE yakalaniyor: sonrasinda
                    // `context`e dokunmak, agac bu arada soklulmusse
                    // hatadir (`use_build_context_synchronously`).
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: _uretilenKod));
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.kayitKopyalandi)),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.kayitTesisKoduPaylas,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('kayit-sonuc-devam'),
          // Oturum ZATEN acik; router `authenticated` durumunu gorunce
          // ana ekrana goturur. Buradan elle `context.go` cagirmak, ayni
          // karari iki yerde tutmak olurdu.
          onPressed: () => context.go(AppRoutes.home),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          child: Text(l10n.kayitTamamla),
        ),
      ],
    );
  }
}
