import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/eposta_alani_widget.dart';
import '../../../core/validators/password_rule.dart';
import '../data/auth_api.dart';

/// (E2E 2026-09, YETKI-13) Tesis kodu (slug) bicimi — web
/// `sifremi-unuttum/page.tsx` `SLUG_RE` ile AYNI. Yalniz BICIM denetimi:
/// tesisin var olup olmadigini SIZDIRMAZ (o denetim sunucuda ve sessiz).
final _slugBicimi = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

bool tesisKoduGecerli(String v) => _slugBicimi.hasMatch(v.trim());

/// (E2E 2026-09, YETKI-13) SIFREMI UNUTTUM — web akisinin ikizi.
///
/// UC ADIM: (1) tesis kodu + e-posta -> `sifre/kod-iste` (SIZINTISIZ: hesap
/// var/yok/dogrulanmamis AYNI yanit; yalniz 429 hata), (2) kod + yeni
/// parola -> `sifre/dogrula-ve-ayarla`, (3) bitti -> girise don. OTURUM
/// ACMAZ: kullanici yeni parolasiyla girer (sunucu karari).
///
/// TESIS KODU NEDEN SORULUYOR: sunucu semasi `tenant_slug`u zorunlu tutuyor
/// (e-posta tesis ICINDE benzersiz) ve parolasiz tesis listesi veren bir uc
/// yok — `tesislerim` parola ister. Web de ayni alani soruyor.
///
/// Merkez diyalog olarak acilir; basarida girilen e-postayla kapanir ki
/// giris ekrani onu on-doldursun.
class SifremiUnuttumFormu extends ConsumerStatefulWidget {
  const SifremiUnuttumFormu({super.key, this.eposta});

  final String? eposta;

  @override
  ConsumerState<SifremiUnuttumFormu> createState() =>
      _SifremiUnuttumFormuState();
}

enum _Adim { iste, ayarla, bitti }

class _SifremiUnuttumFormuState extends ConsumerState<SifremiUnuttumFormu> {
  final _formKey = GlobalKey<FormState>();
  final _tesisCtrl = TextEditingController();
  late final TextEditingController _epostaCtrl =
      TextEditingController(text: widget.eposta ?? '');
  final _kodCtrl = TextEditingController();
  final _parolaCtrl = TextEditingController();
  final _tekrarCtrl = TextEditingController();
  _Adim _adim = _Adim.iste;
  bool _mesgul = false;
  bool _gizli = true;
  String? _hata;

  @override
  void dispose() {
    _tesisCtrl.dispose();
    _epostaCtrl.dispose();
    _kodCtrl.dispose();
    _parolaCtrl.dispose();
    _tekrarCtrl.dispose();
    super.dispose();
  }

  Future<void> _kodIste() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = context.l10n;
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      await ref.read(authApiProvider).sifreKodIste(
            tenantSlug: _tesisCtrl.text.trim(),
            eposta: _epostaCtrl.text.trim(),
          );
      if (mounted) setState(() => _adim = _Adim.ayarla);
    } on ApiException catch (e) {
      // SIZINTISIZ: kod-iste yalniz hiz sinirinda (429) gercek hata verir.
      // Diger durumlarda da ikinci adima gecilir (web ile ayni).
      if (!mounted) return;
      if (e.statusCode == 429 || e.kind == ApiErrorKind.network) {
        setState(() => _hata = apiHataMetni(l10n, e));
      } else {
        setState(() => _adim = _Adim.ayarla);
      }
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _parolayiKur() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = context.l10n;
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      await ref.read(authApiProvider).sifreDogrulaVeAyarla(
            tenantSlug: _tesisCtrl.text.trim(),
            eposta: _epostaCtrl.text.trim(),
            kod: _kodCtrl.text.trim(),
            yeniParola: _parolaCtrl.text,
          );
      if (mounted) setState(() => _adim = _Adim.bitti);
    } on ApiException catch (e) {
      if (mounted) setState(() => _hata = apiHataMetni(l10n, e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            key: const Key('sifremi-unuttum'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.sifreSifirlaBaslik,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ..._govde(context),
              if (_hata != null) ...[
                const SizedBox(height: 8),
                Text(
                  _hata!,
                  key: const Key('sifre-hata'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _govde(BuildContext context) {
    final l10n = context.l10n;
    switch (_adim) {
      case _Adim.iste:
        return [
          Text(l10n.sifreSifirlaAciklama,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('sifre-tesis'),
            controller: _tesisCtrl,
            enabled: !_mesgul,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.girisTesisKodu,
              border: const OutlineInputBorder(),
            ),
            validator: (v) =>
                tesisKoduGecerli(v ?? '') ? null : l10n.girisSlugGecersiz,
          ),
          const SizedBox(height: 12),
          // Paylasilan e-posta alani (P233): bicim + uzunluk kurali tek yerde.
          EpostaAlani(
            alanAnahtari: const Key('sifre-eposta'),
            ktrl: _epostaCtrl,
            etiket: l10n.kayitEposta,
            etkin: !_mesgul,
            otomatikSonraki: false,
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('sifre-kod-gonder'),
            onPressed: _mesgul ? null : _kodIste,
            child: Text(l10n.girisEpostaKodGonder),
          ),
          TextButton(
            onPressed: _mesgul ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.sifreSifirlaGirise),
          ),
        ];
      case _Adim.ayarla:
        return [
          Text(l10n.sifreSifirlaGonderildi,
              key: const Key('sifre-kod-gonderildi'),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('sifre-kod'),
            controller: _kodCtrl,
            enabled: !_mesgul,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: InputDecoration(
              labelText: l10n.girisKodAlani,
              border: const OutlineInputBorder(),
            ),
            validator: (v) =>
                (v ?? '').trim().length < 4 ? l10n.girisKodAlani : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('sifre-yeni'),
            controller: _parolaCtrl,
            enabled: !_mesgul,
            obscureText: _gizli,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: l10n.ortakYeniParola,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _gizli
                    ? l10n.ortakParolayiGoster
                    : l10n.ortakParolayiGizle,
                icon: Icon(_gizli
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _gizli = !_gizli),
              ),
            ),
            // Sunucu ile AYNI kural (8+, buyuk harf, rakam, sembol).
            validator: (v) => (v ?? '').isEmpty
                ? l10n.ortakParolaZorunlu
                : parolaHataMetni(l10n, v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('sifre-tekrar'),
            controller: _tekrarCtrl,
            enabled: !_mesgul,
            obscureText: _gizli,
            decoration: InputDecoration(
              labelText: l10n.ortakYeniParolaTekrar,
              border: const OutlineInputBorder(),
            ),
            validator: (v) =>
                v == _parolaCtrl.text ? null : l10n.ortakParolalarEslesmiyor,
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('sifre-kur'),
            onPressed: _mesgul ? null : _parolayiKur,
            child: Text(l10n.sifreSifirlaKur),
          ),
          TextButton(
            onPressed: _mesgul ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.sifreSifirlaGirise),
          ),
        ];
      case _Adim.bitti:
        return [
          Text(l10n.sifreSifirlaBasarili, key: const Key('sifre-bitti')),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('sifre-girise-don'),
            onPressed: () =>
                Navigator.of(context).pop(_epostaCtrl.text.trim()),
            child: Text(l10n.sifreSifirlaGirise),
          ),
        ];
    }
  }
}

/// (E2E 2026-09, YETKI-13) E-posta koduyla giriste 409 `tesis_secimi_gerekli`
/// — hangi tesise girilecegi.
///
/// NEDEN LISTE DEGIL, ALAN: kodun tuttugu tesisleri donduren bir uc YOK;
/// `/auth/tesislerim` PAROLA ister ve kod yolunda parola yoktur. Sunucu
/// 409 yanitinda aday listesini tasirsa bu diyalog parola yolundaki SECIM
/// listesine cevrilmeli (acik madde, bkz. docs/web-mobil-esitlik.md).
class TesisKoduSorusu extends StatefulWidget {
  const TesisKoduSorusu({super.key});

  @override
  State<TesisKoduSorusu> createState() => _TesisKoduSorusuState();
}

class _TesisKoduSorusuState extends State<TesisKoduSorusu> {
  final _ctrl = TextEditingController();
  String? _hata;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _gonder() {
    final v = _ctrl.text.trim();
    if (!tesisKoduGecerli(v)) {
      setState(() => _hata = context.l10n.girisSlugGecersiz);
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        key: const Key('giris-kod-tesis-sorusu'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.girisTesisSec, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l10n.girisKodTesisKoduAciklama,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            key: const Key('giris-kod-tesis'),
            controller: _ctrl,
            autocorrect: false,
            autofocus: true,
            onSubmitted: (_) => _gonder(),
            decoration: InputDecoration(
              labelText: l10n.girisTesisKodu,
              errorText: _hata,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('giris-kod-tesis-gir'),
            onPressed: _gonder,
            child: Text(l10n.girisYap),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.ortakVazgec),
          ),
        ],
      ),
    );
  }
}
