import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../data/izgara_tercihi.dart';
import '../domain/home_izgara.dart';
import '../domain/home_menu.dart';
import 'module_card_spec.dart';

// (P139.3) ANA EKRANI DUZENLE — kullanici kendi sik kullandiklarini secer.
//
// SECENEK KUMESI IZIN KATMANINDAN GELIR (`izgaraSecenekleri` ->
// `homeMenuForRole`). Yani listede kullanicinin ZATEN goremedigi hicbir
// bolum cikmaz ve "izin hatasina goturen karo" yapisal olarak imkânsizdir
// — kural UI'da tekrar yazilmaz, buradan OKUNUR.
//
// SINIR UI'DA DA GORUNUR: en cok [izgaraEnCokKaro] secilir. Sinira
// ulasildiginda secili OLMAYAN satirlar devre disi kalir — kullanici
// "neden secemiyorum" diye denemek zorunda kalmasin diye sayac da
// basliktadir.
class IzgaraDuzenleScreen extends ConsumerStatefulWidget {
  const IzgaraDuzenleScreen({super.key});

  @override
  ConsumerState<IzgaraDuzenleScreen> createState() =>
      _IzgaraDuzenleScreenState();
}

class _IzgaraDuzenleScreenState extends ConsumerState<IzgaraDuzenleScreen> {
  List<HomeMenuEntry>? _secim;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rol = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    final secenekler = izgaraSecenekleri(rol);
    // Secim yoksa (`null`) rolun VARSAYILAN kumesiyle baslanir — kullanici
    // sifirdan secmek zorunda kalmasin. Not: ana ekranin varsayilani
    // "bugunku kartlar"dir; duzenleme ekranindaki baslangic ise menu
    // girisleri kumesidir, cunku secim MENU GIRISI duzeyinde yapilir.
    final secim = _secim ??=
        List.of(ref.read(izgaraKarolariProvider(rol)) ?? varsayilanIzgara(rol));
    final doluMu = secim.length >= izgaraEnCokKaro;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.izgaraDuzenleBaslik),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(izgaraTercihiProvider.notifier).sifirla();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text(l10n.izgaraSifirla),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.izgaraDuzenleAciklama(izgaraEnCokKaro),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.izgaraSecim(secim.length, izgaraEnCokKaro),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: secenekler.length,
              itemBuilder: (context, i) {
                final giris = secenekler[i];
                final secili = secim.contains(giris);
                final spec = moduleCardSpec(giris);
                return CheckboxListTile(
                  value: secili,
                  // Sinir dolduysa SECILI OLMAYANLAR kapanir; secili olanlar
                  // her zaman kaldirilabilir (kullanici kilitlenmemeli).
                  onChanged: (!secili && doluMu)
                      ? null
                      : (v) => setState(() {
                            if (v == true) {
                              secim.add(giris);
                            } else {
                              secim.remove(giris);
                            }
                          }),
                  secondary: Icon(spec.icon, color: spec.accent),
                  title: Text(moduleBaslik(l10n, giris)),
                  // Dokunma hedefi >= 44pt: CheckboxListTile varsayilani 56.
                  controlAffinity: ListTileControlAffinity.trailing,
                );
              },
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                // BOS SECIM KAYDEDILEBILIR ve bu bilincli: `izgarayiCoz`
                // bos kumeyi varsayilana cevirir, yani kullanici bos bir
                // ana ekranla kalamaz.
                onPressed: () async {
                  await ref.read(izgaraTercihiProvider.notifier).kaydet(secim);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Text(l10n.izgaraKaydet),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
