import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../data/auth_repository_impl.dart';
import 'auth_controller.dart';

/// (P154 / Asama 4) SOSYAL GIRIS DUGMELERI — mobil.
///
/// SAGLAYICI LISTESI SUNUCUDAN gelir; yapilandirilmamis bir saglayiciyi
/// dugme olarak cizmek, kullaniciyi KESIN BASARISIZ bir yola sokmak
/// olurdu. Liste bos ya da alinamazsa HICBIR SEY cizilmez ve parola/kod
/// girisi etkilenmez (brief: "tikanirsa Asama 3 tek basina calissin").
///
/// GORUNEN AD SABIT: "Google"/"Microsoft"/"Apple" marka adlaridir ve
/// cevrilmez; cevrilen sey onlari saran cumledir (`sosyalIleDevam`).
const Map<String, String> kSaglayiciEtiketi = {
  'google': 'Google',
  'microsoft': 'Microsoft',
  'apple': 'Apple',
};

/// Saglayici listesi — ekran cizilirken BIR KEZ okunur.
final oauthSaglayicilarProvider = FutureProvider<List<String>>((ref) async {
  return ref.read(oauthRepositoryProvider).saglayicilar();
});

class SosyalGirisDugmeleri extends ConsumerWidget {
  const SosyalGirisDugmeleri({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final liste = ref.watch(oauthSaglayicilarProvider);
    final submitting = ref.watch(authControllerProvider).submitting;

    // HATA DA BOS DA AYNI: sosyal giris bir EK yoldur; alinamamasi
    // ekranda bir hata kutusu hak etmez.
    final saglayicilar = liste.value ?? const <String>[];
    if (saglayicilar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24),
        for (final s in saglayicilar) ...[
          OutlinedButton(
            key: Key('sosyal-$s'),
            onPressed: submitting
                ? null
                : () => ref.read(authControllerProvider.notifier).oauthAkisi(s),
            style: OutlinedButton.styleFrom(
              // 52 px — ekrandaki diger birincil dugmelerle AYNI; 44 pt
              // dokunma hedefi kuralinin uzerinde.
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(
              l10n.sosyalIleDevam(kSaglayiciEtiketi[s] ?? s),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
