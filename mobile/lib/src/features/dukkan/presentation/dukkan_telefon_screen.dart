import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../core/ui/telefon_alani.dart';
import '../data/dukkan_api.dart';
import '../data/dukkan_oturum.dart';

/// (DUKKAN F7 §2) MOBIL TELEFON-OTP — %27'lik duvarı kaldırır.
///
/// ===========================================================================
/// NEDEN VAR: ÖLÇÜLEN BİR ENGEL
/// ===========================================================================
/// Yönetiyor'daki 3104 kullanıcının **837'sinde (%27) telefon yok.** SSO
/// köprüsü onlara 409 `telefon_gerekli` dönüyor — çünkü Dukkan kimliği
/// telefona çapalı (`dukkan_kullanici.telefon` UNIQUE) ve köprü
/// **salt okunur**: Yönetiyor'a telefon YAZAMAZ (sınır testle kilitli).
///
/// F4–F6 boyunca bu kullanıcılara "dukkan.yonetiyor.com'a gidin" deniyordu.
/// Yani her dört kullanıcıdan biri, akışın ortasında tarayıcıya
/// gönderiliyor ve pratikte orada kayboluyordu. Onlar için mobil Dukkan
/// **arama ekranından ibaretti**: talep açamıyor, teklif göremiyor,
/// panele giremiyorlardı.
///
/// Bu ekran o dalı akışın **normal bir parçası** hâline getiriyor.
///
/// ===========================================================================
/// SMS BAŞLIĞI GELMEDEN ÇALIŞMAZ — VE BUNU AÇIKÇA SÖYLÜYOR
/// ===========================================================================
/// Onaylı SMS başlığı olmadan uç 503 `sms_baslik_yok` dönüyor. Ekran bunu
/// "bir hata oluştu" diye göstermiyor: **beklemekten başka yapılacak bir
/// şey olmadığını** söylüyor. Üç SMS hatasının metni ayrı, çünkü
/// kullanıcının yapacağı şey farklı:
///   * `baslik_yok`    → beklemek (onay süreci)
///   * `basarisiz`     → tekrar denemek MANTIKLI (geçici)
///   * `saglayici_yok` → tekrar denemek işe yaramaz (yapılandırma)
class DukkanTelefonScreen extends ConsumerStatefulWidget {
  const DukkanTelefonScreen({super.key});

  @override
  ConsumerState<DukkanTelefonScreen> createState() => _DukkanTelefonState();
}

enum _Adim { telefon, kod }

class _DukkanTelefonState extends ConsumerState<DukkanTelefonScreen> {
  final _telefonKtrl = TextEditingController();
  final _kodKtrl = TextEditingController();
  final _adKtrl = TextEditingController();

  _Adim _adim = _Adim.telefon;
  bool _islemde = false;
  String? _hataKodu;

  @override
  void dispose() {
    _telefonKtrl.dispose();
    _kodKtrl.dispose();
    _adKtrl.dispose();
    super.dispose();
  }

  String get _telefon => telefonNormalle(_telefonKtrl.text);

  Future<void> _kodIste() async {
    if (telefonHaneleri(_telefonKtrl.text).length != 10) {
      setState(() => _hataKodu = 'telefon_bicimi_gecersiz');
      return;
    }
    setState(() {
      _islemde = true;
      _hataKodu = null;
    });
    try {
      await ref.read(dukkanApiProvider).otpKodIste(_telefon);
      // ADIM YALNIZ GONDERIM BASARILIYSA ILERLER. Uç gönderemediğinde
      // 503 dönüyor; yine de kod ekranına geçseydik kullanıcı
      // GELMEYECEK bir kodu beklerdi.
      if (mounted) setState(() => _adim = _Adim.kod);
    } on DukkanOtpHatasi catch (h) {
      if (mounted) setState(() => _hataKodu = h.kod);
    } finally {
      if (mounted) setState(() => _islemde = false);
    }
  }

  Future<void> _dogrula() async {
    setState(() {
      _islemde = true;
      _hataKodu = null;
    });
    try {
      final jeton = await ref.read(dukkanApiProvider).otpDogrula(
            telefon: _telefon,
            kod: _kodKtrl.text.trim(),
            adSoyad: _adKtrl.text.trim(),
          );
      // JETONU YERLESTIR: oturum artık bellekte VE cihazda. Cihazda
      // olmasaydı kullanıcı her açılışta yeniden OTP'ye girerdi — yani
      // her gün bir SMS (bkz. dukkan_jeton_deposu.dart).
      await ref.read(dukkanOturumProvider).jetonKur(jeton);
      if (mounted) Navigator.of(context).pop(true);
    } on DukkanOtpHatasi catch (h) {
      if (mounted) setState(() => _hataKodu = h.kod);
    } finally {
      if (mounted) setState(() => _islemde = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.dukkanTelefonBaslik)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _adim == _Adim.telefon
                ? t.dukkanTelefonAciklama
                : t.dukkanKodAciklama,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          if (_adim == _Adim.telefon) ...[
            TextField(
              controller: _telefonKtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: const [TelefonBicimlendirici()],
              decoration: InputDecoration(
                labelText: t.dukkanTelefonAlani,
                prefixText: '+90 ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _adKtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: t.dukkanAdSoyadAlani,
                // İSTEĞE BAĞLI: zorunlu kılmak, kimliği doğrulanmış bir
                // kullanıcıyı akışın ortasında bir form alanı yüzünden
                // durdurmak olurdu. Sunucu da zorunlu tutmuyor.
                helperText: t.dukkanAdSoyadIpucu,
              ),
            ),
          ] else ...[
            TextField(
              controller: _kodKtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: t.dukkanKodAlani),
            ),
          ],
          if (_hataKodu != null) ...[
            const SizedBox(height: 12),
            Text(
              _hataMetni(t, _hataKodu!),
              // `role="alert"` karşılığı: ekran okuyucu hatayı DUYURSUN.
              semanticsLabel: _hataMetni(t, _hataKodu!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _islemde
                ? null
                : (_adim == _Adim.telefon ? _kodIste : _dogrula),
            child: Text(_adim == _Adim.telefon
                ? t.dukkanKodGonder
                : t.dukkanKodDogrula),
          ),
          if (_adim == _Adim.kod)
            TextButton(
              onPressed: _islemde
                  ? null
                  : () => setState(() {
                        _adim = _Adim.telefon;
                        _kodKtrl.clear();
                        _hataKodu = null;
                      }),
              child: Text(t.dukkanNumarayiDegistir),
            ),
        ],
      ),
    );
  }
}

/// Hata kodunu KULLANICI METNINE çevirir.
///
/// `dukkan-web/lib/istemci.ts` ile **aynı ayrımlar**: iki istemcinin aynı
/// koda farklı şey demesi, destek konuşmasını imkânsız kılardı.
String _hataMetni(AppLocalizations t, String kod) => switch (kod) {
      'sms_baslik_yok' => t.dukkanSmsBaslikYok,
      'sms_basarisiz' => t.dukkanSmsBasarisiz,
      'sms_saglayici_yok' => t.dukkanSmsSaglayiciYok,
      'kod_istegi_cok_sik' => t.dukkanKodCokSik,
      'telefon_bicimi_gecersiz' => t.dukkanTelefonGecersiz,
      'kod_hatali' => t.dukkanKodHatali,
      'kod_suresi_doldu' => t.dukkanKodSuresiDoldu,
      'kod_kullanilmis' => t.dukkanKodKullanilmis,
      'kod_bulunamadi' => t.dukkanKodBulunamadi,
      'cok_fazla_deneme' => t.dukkanCokFazlaDeneme,
      'hesap_askida' => t.dukkanHesapAskida,
      'ag' => t.dukkanAgHatasi,
      _ => t.dukkanListeAlinamadi,
    };
