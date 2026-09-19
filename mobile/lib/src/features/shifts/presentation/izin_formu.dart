import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../data/vardiya_plani_api.dart';
import 'vardiya_plani_screen.dart' show vardiyaPersonelProvider;

/// (P241 §2) IZIN FORMU — mobil.
///
/// =========================================================================
/// ONAY KARARI SUNUCUDA, ISTEMCIDE DEGIL
/// =========================================================================
/// Form "onayli mi talep mi" diye SORMAZ ve TAHMIN ETMEZ: sunucu,
/// cagiranin rolune gore karar verir (yonetim -> onayli, personel ->
/// talep) ve yanitta `durum` doner. Istemcide tahmin etmek, iki yuzeyde
/// iki farkli kural yazmak olurdu.
///
/// =========================================================================
/// PERSONEL YALNIZ KENDISI ICIN
/// =========================================================================
/// Saha rolunde kisi secici CIZILMEZ — sunucu zaten baskasi adina
/// girisi 403 ile reddediyor; secici gostermek, reddedilecek bir eylemi
/// davet etmek olurdu.
class IzinFormu extends ConsumerStatefulWidget {
  const IzinFormu({super.key});

  @override
  ConsumerState<IzinFormu> createState() => _IzinFormuState();
}

/// Izin turleri — sunucudaki enum ile AYNI sira ve kodlar.
const izinTurleri = <String>[
  'yillik',
  'mazeret',
  'hastalik',
  'ucretsiz',
  'resmi_tatil',
];

String izinTuruAdi(AppLocalizations l10n, String kod) => switch (kod) {
      'yillik' => l10n.vardiyaIzinYillik,
      'mazeret' => l10n.vardiyaIzinMazeret,
      'hastalik' => l10n.vardiyaIzinHastalik,
      'ucretsiz' => l10n.vardiyaIzinUcretsiz,
      _ => l10n.vardiyaIzinResmiTatil,
    };

class _IzinFormuState extends ConsumerState<IzinFormu> {
  String? _userId;
  String _tur = izinTurleri.first;
  DateTime _bas = DateTime.now();
  DateTime _bit = DateTime.now();
  bool _bekliyor = false;
  String? _hata;

  String _g(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _kaydet() async {
    final l10n = context.l10n;
    // KENDI KIMLIGI BEKLENIR: `currentUserIdProvider` bir
    // FutureProvider ve `asData` ILK okumada bos olabilir. Bos gecmek,
    // formun sessizce hicbir sey yapmamasi demekti — kullanici
    // "kaydet"e basip hicbir sey olmadigini gorurdu.
    final kimlik = await ref.read(currentUserIdProvider.future);
    final hedef = _userId ?? kimlik;
    if (hedef == null) return;
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    try {
      final sonuc = await ref.read(vardiyaPlaniApiProvider).izinEkle(
            userId: hedef,
            tur: _tur,
            baslangic: _g(_bas),
            bitis: _g(_bit),
          );
      if (!mounted) return;
      // MESAJ SUNUCUNUN DONDURDUGU DURUMDAN: "onaya gonderildi" ile
      // "kaydedildi" ayri seylerdir ve hangisinin oldugunu SUNUCU bilir.
      final talep = sonuc['durum'] == 'onay_bekliyor';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            talep ? l10n.vardiyaIzinTalepGonderildi : l10n.vardiyaIzinKaydedildi,
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _hata = apiHataMetni(l10n, e));
    } finally {
      if (mounted) setState(() => _bekliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rol = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    final yonetim = rol == UserRole.admin ||
        rol == UserRole.yonetici ||
        rol == UserRole.guvenlikAmiri;
    final personel = ref.watch(vardiyaPersonelProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vardiyaIzinEkle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_hata != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _hata!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (yonetim)
            personel.when(
              data: (liste) => DropdownButtonFormField<String>(
                key: const Key('izin-kisi'),
                initialValue: _userId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.vardiyaPersonel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final p in liste)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(p.ad, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _userId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('izin-tur'),
            initialValue: _tur,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.vardiyaIzinTuru,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final k in izinTurleri)
                DropdownMenuItem(
                  value: k,
                  child: Text(izinTuruAdi(l10n, k),
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _tur = v ?? _tur),
          ),
          const SizedBox(height: 12),
          ListTile(
            key: const Key('izin-bas'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.vardiyaBaslangicTarihi),
            subtitle: Text(_g(_bas)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final s = await showDatePicker(
                context: context,
                initialDate: _bas,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (s != null) {
                setState(() {
                  _bas = s;
                  // BITIS GERIDE KALAMAZ: sunucu da reddediyor, ama
                  // kullaniciya once burada duzeltmek daha az surtunme.
                  if (_bit.isBefore(s)) _bit = s;
                });
              }
            },
          ),
          ListTile(
            key: const Key('izin-bit'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.vardiyaBitisTarihi),
            subtitle: Text(_g(_bit)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final s = await showDatePicker(
                context: context,
                initialDate: _bit,
                firstDate: _bas,
                lastDate: DateTime(2100),
              );
              if (s != null) setState(() => _bit = s);
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('izin-kaydet'),
            onPressed: _bekliyor ? null : _kaydet,
            child: Text(l10n.ortakKaydet),
          ),
        ],
      ),
    );
  }
}
