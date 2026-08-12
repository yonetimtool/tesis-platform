import 'dart:async';

import 'package:flutter/material.dart';
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
/// DORT ADIM: rol -> kimlik -> YONTEM -> kod. Parola ekrani YAZILMADI
/// — `setupToken` dolunca router zaten `/set-password`e goturuyor ve o
/// ekran parola kuralini, gosterme/gizlemeyi ve 401'de kurulumu iptal
/// etmeyi coktan cozmus (bkz. `AuthController.kayitKodunuOnayla`).
///
/// (P154 duzeltme turu) YONTEM ADIMI SONRADAN EKLENDI. Brief'in sirasi
/// "tesis ID -> telefon -> kimlik dogrulama yontemi" ve yontem
/// KULLANICININ SECIMI: parola · Google · Microsoft · Apple. Onceki surum
/// dogrudan paroladan devam ediyordu; sosyal hesapla kaydolmak yalnizca
/// GIRIS ekranindan mumkundu, yani kaydolmaya gelen kullanici once "giris
/// yap" demek zorundaydi.
///
/// SMS NEDEN HÂLÂ VAR: brief onu saymiyor ama saglayici "bu telefonun
/// sahibisin" DEMEZ (bkz. routers/oauth.py basligi). Iki yolda da telefon
/// sahipligini kanitlayan sey SMS'tir; yontem secimi onun YERINE degil,
/// ONUNE kondu.
///
/// SMS ARTIK KIMLIK ADIMINDA DEGIL YONTEMDEN SONRA GONDERILIYOR: aksi
/// halde "Google" secen kullaniciya once bir `amac=kayit` SMS'i gider,
/// ardindan sosyal yol kendi kodunu gonderirdi — iki kod, tek telefon.
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

enum _Adim { rol, kimlik, yontem, kod }

/// Kod adimina HANGI yoldan gelindi — dogrulama ucu buna gore secilir.
enum _Yol { parola, sosyal }

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
  _Yol _yol = _Yol.parola;
  String _tesisAd = '';
  String _telefonMaskeli = '';
  String? _hata;
  bool _bekliyor = false;

  @override
  void initState() {
    super.initState();
    // (P154 / Asama 2) ROL LISTESI GORULDU. Bayrak EKRAN ACILIRKEN
    // yaziliyor, "kaydolma tamamlaninca" degil: brief listeyi ILK ACILISIN
    // ekrani sayar, kaydolmanin odulu saymaz. Kaydolmadan cikan kullanici
    // bir dahaki acilista girise duser ve oradaki `login-kayit-baglantisi`
    // ile buraya geri donebilir.
    // ERTELEME ZORUNLU: Riverpod bir provider'in `initState` icinde
    // degistirilmesini yasaklar (agac insa edilirken iki dinleyici farkli
    // durum gorebilirdi).
    //
    // `Future(...)` DEGIL `addPostFrameCallback`: ilki bir ZAMANLAYICI
    // kurar ve agac calismadan once atilirsa `flutter_test` "A Timer is
    // still pending" ile duser (olculdu — `acilis_dil_titremesi_test`
    // boyle kirildi). Kare geri cagrisi agacla birlikte duser.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(rolSecimiBekliyorProvider.notifier).gosterildi());
    });
  }

  @override
  void dispose() {
    _tesisCtrl.dispose();
    _telefonCtrl.dispose();
    _daireCtrl.dispose();
    _blokCtrl.dispose();
    _kodCtrl.dispose();
    super.dispose();
  }

  /// Kimlik adimi ARTIK AG CAGIRMIYOR: yalniz formu dogrulayip yontem
  /// adimina gecer. Cagriyi yontem secimi baslatir (bkz. sinif basligi).
  void _kimlikGonder() {
    FocusScope.of(context).unfocus();
    if (!_kimlikFormKey.currentState!.validate()) return;
    setState(() {
      _hata = null;
      _adim = _Adim.yontem;
    });
  }

  String get _telefon => telefonNormalle(_telefonCtrl.text);

  /// (a) Parola olustur — kayit ucu SMS gonderir, kod adimina gecilir.
  Future<void> _parolaYolu() async {
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    try {
      final sonuc = await ref.read(authApiProvider).rolKayitBasla(
            rol: _rol.kimlik,
            tesisKodu: _tesisCtrl.text.trim(),
            telefon: _telefon,
            daireNo: _rol.daireIster ? _daireCtrl.text.trim() : null,
            blok: _rol.daireIster ? _blokCtrl.text.trim() : null,
          );
      if (!mounted) return;
      setState(() {
        _tesisAd = sonuc.tesisAd;
        _telefonMaskeli = sonuc.telefonMaskeli;
        _yol = _Yol.parola;
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

  /// (b/c/d) Google · Microsoft · Apple.
  ///
  /// IKI ASAMA: once tarayici akisi (saglayici kimligi kanitlar), sonra
  /// ZATEN GIRILMIS tesis kodu + telefon ile eslesme (SMS). Giris
  /// ekranindaki `SosyalBaglamaFormu` ikinciyi kullaniciya YENIDEN
  /// sordurur; burada sormaya gerek yok, cunku brief bu iki alani
  /// yontemden ONCE istiyor ve elimizde duruyorlar.
  Future<void> _sosyalYol(String saglayici) async {
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    final denetleyici = ref.read(authControllerProvider.notifier);
    // ONCE TEMIZLE: onceki denemeden kalmis bir baglama jetonu olabilir
    // (ornegin Google secildi, eslesme adimi hata verdi, kullanici bu kez
    // Apple'i secti). Temizlemezsek ve kullanici bu akisi yarida birakirsa
    // ESKI saglayicinin jetonuyla devam ederdik.
    denetleyici.oauthIptal();
    await denetleyici.oauthAkisi(saglayici);
    if (!mounted) return;

    final durum = ref.read(authControllerProvider);
    // Kimlik ZATEN bagliysa oturum acildi; router devrali r.
    if (durum.status == AuthStatus.authenticated) return;
    // Kullanici tarayiciyi kapatti (jeton yok, hata da yok) → sessizce
    // yontem adiminda kal.
    if (durum.oauthBaglamaJetonu == null) {
      setState(() {
        _bekliyor = false;
        _hata = durum.errorMessage;
      });
      return;
    }

    final sonuc = await denetleyici.oauthBaglanBasla(
      tesisKodu: _tesisCtrl.text.trim(),
      telefon: _telefon,
    );
    if (!mounted) return;
    if (sonuc == null) {
      setState(() {
        _bekliyor = false;
        _hata = ref.read(authControllerProvider).errorMessage;
      });
      return;
    }
    setState(() {
      _tesisAd = sonuc.tesisAd;
      _telefonMaskeli = sonuc.telefonMaskeli;
      _yol = _Yol.sosyal;
      _adim = _Adim.kod;
      _bekliyor = false;
    });
  }

  Future<void> _kodGonder() async {
    FocusScope.of(context).unfocus();
    if (!_kodFormKey.currentState!.validate()) return;
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    // SOSYAL YOL: kod dogrulanınca hesap BAGLANIR ve oturum acilir —
    // parola ekrani YOKTUR (kullanici parola istemedigini zaten secti).
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
    // GERI DONMEK yarim kalmis bir SOSYAL baglamayi da birakmali; aksi
    // halde jeton durumda asili kalir ve kullanici giris ekranina
    // dondugunde beklenmedik bir eslestirme formu bulurdu.
    //
    // KOSULSUZ CAGRILIYOR: jeton yalniz kod adiminda degil, YONTEM
    // adiminda da askida kalabilir (tarayici akisi bitti ama eslesme
    // adimi hata verdi). Bekleyen bir sey yokken zararsizdir.
    ref.read(authControllerProvider.notifier).oauthIptal();
    setState(() {
      _hata = null;
      _adim = switch (_adim) {
        _Adim.kod => _Adim.yontem,
        _Adim.yontem => _Adim.kimlik,
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
      _Adim.kimlik => 2,
      _Adim.yontem => 3,
      _Adim.kod => 4,
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
                  if (_adim == _Adim.yontem) _yontemSecimi(l10n),
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

  /// (P154 / Asama 3) KIMLIK DOGRULAMA YONTEMI — kullanicinin secimi.
  ///
  /// PAROLA HER ZAMAN VAR, SOSYAL YALNIZ YAPILANDIRILMISSA: saglayici
  /// listesi sunucudan gelir (`oauthSaglayicilarProvider`) ve bos ya da
  /// alinamaz olabilir. Cizilmeyen bir dugme, kullaniciyi KESIN
  /// BASARISIZ bir yola sokmaktan iyidir — `SosyalGirisDugmeleri` ile
  /// AYNI kural; ikisi ayni provider'i okur ki liste tek yerden gelsin.
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
        FilledButton(
          key: const Key('kayit-yontem-parola'),
          onPressed: _bekliyor ? null : _parolaYolu,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          child: _bekliyor
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Text(l10n.kayitYontemParola),
        ),
        for (final s in saglayicilar) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            key: Key('kayit-yontem-$s'),
            onPressed: _bekliyor ? null : () => _sosyalYol(s),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(l10n.sosyalIleDevam(kSaglayiciEtiketi[s] ?? s)),
          ),
        ],
      ],
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
