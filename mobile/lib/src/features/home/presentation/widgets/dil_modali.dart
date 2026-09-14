import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/l10n.dart';
import '../../../../core/i18n/locale_controller.dart';
import '../../../../core/ui/merkez_diyalog.dart';

// (P140.4) DIL SECICI — ana ekranin SAG USTUNDE, ortada acilan modal.
//
// NEDEN MODAL: dil bir AYARDIR ama nadiren degistirilir ve degistirildiginde
// SONUCU aninda gorulmelidir. Cekmecenin dibinde durdugunda bulunmasi zordu;
// ust cubukta bir SIMGE hem gorunur hem de bir karo harcamaz.
//
// SECIM ANINDA UYGULANIR VE KALICIDIR: `LocaleController.sec` hem durumu
// hem de guvenli depoyu gunceller (tema modunun kullandigi depo).

/// Ust cubuktaki ceviri simgesi. Dokununca [dilModaliniAc] cagrilir.
// (P233 §2) `DilButonu` KALDIRILDI — ust bardaki yerini arama aldi.
//
// Dil ZATEN Ayarlar'dan degistirilebiliyor (`settings_screen`de kendi
// karti var) ve bir kez secilip bir daha dokunulmayan bir tercih; ust
// barda kalici yer kaplamasi orantisizdi.
//
// `dilModaliniAc` DURUYOR: modalin kendisi hala cagrilabiliyor, yalnizca
// ust bardaki GIRISI kalkti. Modali silmek, ileride baska bir yerden
// (ornegin ilk acilis) acmak isteyeni sifirdan yazmaya zorlardi.

/// Dil secenekleri — ekranin ORTASINDA modal.
///
/// Klavye ile kapanir: `showDialog` ESC'i (ve Android geri tusunu) zaten
/// isler; ayrica her satir odaklanabilir bir `ListTile`dir.
Future<void> dilModaliniAc(BuildContext context) {
  return merkezSayfaAc<void>(
    context,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final secili = ref.watch(localeControllerProvider);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  ctx.l10n.dilSeciciBaslik,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              for (final dil in AppDil.values)
                ListTile(
                  key: Key('dil-${dil.kod}'),
                  // Ad HER ZAMAN kendi dilinde: kullanici bilmedigi bir
                  // dilde yazilmis kendi dilini bulamaz.
                  title: Text(dil.adKendiDilinde),
                  trailing: secili == dil
                      ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
                      : null,
                  selected: secili == dil,
                  onTap: () {
                    // ONCE KAPAT, SONRA YAZ.
                    //
                    // `sec` durumu hemen gunceller (dil ANINDA uygulanir)
                    // ve ardindan guvenli depoya yazar. Kapanisi o yazmanin
                    // ARDINA koymak iki hata uretiyordu: (1) disk yavassa
                    // modal takili kaliyor, (2) yazma hata firlatirsa
                    // modal HIC kapanmiyor — testte tam bu oldu.
                    // Kapanis bir GORUNUM isidir, kalicilik degil.
                    Navigator.of(ctx).pop();
                    // Hata yutulmaz ama ekrani da rehin almaz: kullanici
                    // dili gorur, kalicilik denemesi arka planda surer.
                    unawaited(
                      ref.read(localeControllerProvider.notifier).sec(dil),
                    );
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ),
  );
}
