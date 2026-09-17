import 'package:flutter/material.dart';

import '../../../core/i18n/l10n.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/rol_adi.dart';
import '../../call/presentation/call_button.dart';

/// (P239 §5) KISI SAYFASI — vardiya kartindan acilir.
///
/// =========================================================================
/// NEDEN AYRI BIR EKRAN, KARTIN UZERINDE "ARA" DEGIL
/// =========================================================================
/// Vardiya seridi DAR bir seritte yan yana kartlardir; her kartin uzerine
/// bir de arama dugmesi koymak, 320dp'de adi bastirirdi. Ustelik arama
/// hakki SUNUCUDAN cozuluyor (`/call-target`) — yani her kart icin AYRI
/// bir istek demekti; serit acilir acilmaz N istek.
///
/// =========================================================================
/// VERI ROTAYLA TASINIR, YENIDEN CEKILMEZ
/// =========================================================================
/// Ad/rol zaten `/vardiya-plani/simdi` yanitinda geldi. Ekran acilirken
/// ikinci bir `GET /users/{id}` atmak, ayni veriyi iki kez istemek ve
/// saha rollerine kapali bir ucu zorlamak olurdu (o uc yonetim icindir).
///
/// =========================================================================
/// TELEFON EKRANDA YAZMAZ
/// =========================================================================
/// [CallButton] numarayi GOSTERMEZ, yalniz cihaz ceviricisine verir
/// (KVKK — amac-sinirli). Yetki/riza kapisi sunucuda: yetkisiz ya da
/// rizasiz hedefte dugme "aranamiyor" halinde kalir. Bu ekran o karari
/// TAKLIT ETMEZ, yalnizca sonucunu cizer.
class KisiArgs {
  const KisiArgs({
    required this.userId,
    required this.ad,
    required this.rol,
    this.altSatir,
  });

  final String userId;
  final String ad;

  /// Sunucu rol kimligi (`security`, `yonetici`, ...).
  final String rol;

  /// Orn. vardiya saat araligi — kisinin SU AN neden burada oldugunu
  /// soyler; yoksa satir hic cizilmez.
  final String? altSatir;
}

class KisiSayfasi extends StatelessWidget {
  const KisiSayfasi({super.key, required this.args});

  final KisiArgs args;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rol = rolAdi(l10n, UserRole.fromClaim(args.rol));
    return Scaffold(
      appBar: AppBar(title: Text(args.ad)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 36,
              child: Text(
                _bashafler(args.ad),
                key: const Key('kisi-bas-harf'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              args.ad,
              key: const Key('kisi-ad'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              rol,
              key: const Key('kisi-rol'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (args.altSatir != null && args.altSatir!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                args.altSatir!,
                key: const Key('kisi-alt-satir'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: CallButton(
              key: const Key('kisi-ara'),
              userId: args.userId,
              label: l10n.kisiAra,
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar yoksa BAS HARFLER — bos bir daire "veri yok" gibi gorunur.
/// Tek kelimelik adda tek harf; bos adda bos dize (soru isareti gibi
/// uydurma bir simge yazmaktansa bosluk dogru).
String _bashafler(String ad) {
  final parcalar =
      ad.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (parcalar.isEmpty) return '';
  if (parcalar.length == 1) return parcalar.first.characters.take(1).toString();
  return (parcalar.first.characters.take(1).toString() +
      parcalar.last.characters.take(1).toString());
}
