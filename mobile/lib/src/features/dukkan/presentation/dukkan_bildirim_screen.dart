import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../data/dukkan_api.dart';
import 'dukkan_hata_govdesi.dart';
import '../data/dukkan_oturum.dart';
import '../domain/dukkan_push_yonlendirme.dart';

/// (DUKKAN F6-ek) DUKKAN BILDIRIMLERI — liste + tercih.
///
/// ===========================================================================
/// NEDEN YONETIYOR BILDIRIM EKRANINDAN AYRI
/// ===========================================================================
/// Uc sebep, ucu de olculebilir:
///   1. AYRI KIMLIK: liste `dukkan_kullanici`ya bagli ve Dukkan jetonu
///      ister. Yonetiyor'un bildirim ucu bu satirlari GOREMEZ
///      (`dukkan_app` rolu `public`e erisemiyor, goc 0113).
///   2. AYRI ACILIYET: "site su kesintisi" ile "teklif geldi" ayni yigina
///      dustugunde kullanici hangisine bakacagini secmek zorunda kalir.
///   3. AYRI KAPATMA: Dukkan bildirimleri ayri kapatilabiliyor (goc
///      0121). Kapatilmis bir urunun satirlari ortak listede kalsaydi,
///      "kapattim ama hâlâ geliyor" gorunurdu.
///
/// ===========================================================================
/// METIN ISTEMCIDE URETILIYOR
/// ===========================================================================
/// Sunucu `tip` + `veri` gonderiyor, METIN GONDERMIYOR. Boylece kullanici
/// dilini degistirdiginde ESKI bildirimler de yeni dilde okunur. Sunucuda
/// uretilmis metin, gonderildigi andaki dilde donardi.
class DukkanBildirimScreen extends ConsumerWidget {
  const DukkanBildirimScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final liste = ref.watch(dukkanBildirimlerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.dukkanBildirimler),
        actions: [
          IconButton(
            tooltip: t.dukkanBildirimAyari,
            icon: const Icon(Icons.settings_outlined),
            // MERKEZ DIYALOG (P22a): tum acilir pencereler ORTADAN.
            onPressed: () =>
                merkezSayfaAc<void>(context, builder: (_) => const _TercihSayfasi()),
          ),
        ],
      ),
      body: liste.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (h, _) => DukkanHataGovdesi(
          hata: h,
          onYenile: () => ref.invalidate(dukkanBildirimlerProvider),
        ),
        data: (sonuc) {
          if (sonuc.items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t.dukkanBildirimYok, textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            itemCount: sonuc.items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, n) {
              final x = sonuc.items[n];
              // HEDEF `tip`TEN CEVRILIYOR, sunucunun WEB yolundan DEGIL.
              // Sunucunun `hedef_yol`u web icindir; mobilde o yollar yok.
              final veri = <String, String>{
                'tip': x.tip,
                for (final e in x.veri.entries) e.key: '${e.value}',
              };
              final hedef = dukkanPushHedefi(veri);
              return ListTile(
                leading: Icon(
                  x.okundu
                      ? Icons.notifications_none
                      : Icons.notifications_active,
                  color: x.okundu
                      ? null
                      : Theme.of(context).colorScheme.primary,
                ),
                title: Text(_baslik(t, x.tip)),
                subtitle: Text(_govde(t, x)),
                // HEDEFI OLMAYAN BILDIRIM DOKUNULAMAZ (onTap null):
                // dokunup hicbir sey olmamasi, bozuk oldugu izlenimi
                // verir. Gri ve tepkisiz olmasi ise DOGRU bilgi.
                onTap: hedef == null
                    ? null
                    : () async {
                        final jeton =
                            await ref.read(dukkanOturumProvider).jetonAl();
                        await ref
                            .read(dukkanApiProvider)
                            .bildirimOkundu(jeton, bildirimId: x.id);
                        ref.invalidate(dukkanBildirimlerProvider);
                        if (context.mounted) context.push(hedef);
                      },
              );
            },
          );
        },
      ),
    );
  }
}

String _baslik(AppLocalizations t, String tip) => switch (tip) {
      'dukkan_teklif_geldi' => t.dukkanBildirimTeklifGeldi,
      'dukkan_yeni_talep' => t.dukkanBildirimYeniTalep,
      'dukkan_is_verildi' => t.dukkanBildirimIsVerildi,
      'dukkan_isletme_onaylandi' => t.dukkanBildirimIsletmeOnaylandi,
      'dukkan_isletme_reddedildi' => t.dukkanBildirimIsletmeReddedildi,
      'dukkan_isletme_askiya_alindi' => t.dukkanBildirimIsletmeAskida,
      'dukkan_yorum_yayinlandi' => t.dukkanBildirimYorumYayinlandi,
      // BILINMEYEN TIP: sunucu yeni bir tip eklemis ve mobil surum eski.
      // Bos satir yerine tipin KENDISI gosteriliyor — kullanici bir sey
      // oldugunu gorur, destek de neyin oldugunu okuyabilir.
      _ => tip,
    };

String _govde(AppLocalizations t, DukkanBildirim x) {
  final ad = x.veri['isletme_ad'];
  return ad is String && ad.isNotEmpty ? ad : t.dukkanBildirimDetayIcinDokun;
}

/// Tercih sayfasi — IKI AYRI ANAHTAR.
///
/// "Bildirim gelsin mi" ile "SESLI gelsin mi" ayri sorular. Tek anahtar
/// olsaydi, "gece caliyor" diyen kullanici bildirimin TAMAMINI kapatmak
/// zorunda kalirdi (P207'de birebir bu karar verildi).
class _TercihSayfasi extends ConsumerWidget {
  const _TercihSayfasi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tercih = ref.watch(dukkanBildirimTercihiProvider);

    Future<void> yaz({bool? acik, bool? sesli}) async {
      final jeton = await ref.read(dukkanOturumProvider).jetonAl();
      await ref
          .read(dukkanApiProvider)
          .tercihYaz(jeton, acik: acik, sesli: sesli);
      ref.invalidate(dukkanBildirimTercihiProvider);
    }

    return SafeArea(
      child: tercih.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t.dukkanListeAlinamadi),
        ),
        data: (v) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text(t.dukkanBildirimAcik),
              // KAPATMANIN NE YAPMADIGINI da soyluyor: kullanici
              // Yonetiyor bildirimlerinin de susacagini sanmamali.
              subtitle: Text(t.dukkanBildirimAcikIpucu),
              value: v.acik,
              onChanged: (y) => yaz(acik: y),
            ),
            SwitchListTile(
              title: Text(t.dukkanBildirimSesli),
              value: v.sesli,
              // BILDIRIM KAPALIYKEN SES ANAHTARI DA KAPALI: acik
              // birakmak, hicbir seyi degistirmeyen bir dugme olurdu.
              onChanged: v.acik ? (y) => yaz(sesli: y) : null,
            ),
          ],
        ),
      ),
    );
  }
}
