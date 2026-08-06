/// (P141.5) BELIRGIN ACIKLAMA (prominent disclosure) — Play sarti.
///
/// Konum ve kamera izni ISTENMEDEN ONCE, verinin ne icin toplandigi EKRANDA
/// gosterilmeli. Gizlilik politikasina gomulu olmasi YETMEZ: Play, iznin
/// istendigi anda kullanicinin amaci gormesini sart kosar.
///
/// TASARIM: bu diyalog isletim sisteminin izin sorusundan ONCE cikar ve
/// kullanici "Devam" demezse izin HIC ISTENMEZ. Yani "once izni al, sonra
/// acikla" tuzagina dusulmez.
///
/// METIN KURALI: ne toplandigi + NE ICIN + ne zaman. Genel gecer
/// ("deneyiminizi iyilestirmek icin") ifadeler Play tarafinda reddedilir.
library;

import 'package:flutter/material.dart';

import '../i18n/l10n.dart';

/// Hangi izin icin aciklama gosterilecek.
enum IzinTuru {
  /// Devriye okutmasinda konum kanitı — YALNIZ okutma aninda, arka planda
  /// takip YOK.
  devriyeKonum,

  /// Talep/ariza bildiriminde fotograf — kullanicinin SECTIGI an.
  talepFotograf,
}

/// Aciklamayi gosterir; kullanici onayladiysa `true` doner.
///
/// `false` dondugunde CAGIRAN IZNI ISTEMEMELIDIR — testler bunu ayrica
/// olcer, cunku "diyalogu goster ama yine de izin iste" davranisi sarti
/// karsilamis gibi gorunup karsilamaz.
Future<bool> belirginAciklamaGoster(
  BuildContext context,
  IzinTuru tur,
) async {
  final l10n = context.l10n;
  final (baslik, govde, ikon) = switch (tur) {
    IzinTuru.devriyeKonum => (
        l10n.izinKonumBaslik,
        l10n.izinKonumGovde,
        Icons.location_on_outlined,
      ),
    IzinTuru.talepFotograf => (
        l10n.izinKameraBaslik,
        l10n.izinKameraGovde,
        Icons.photo_camera_outlined,
      ),
  };

  final onay = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      icon: Icon(ikon, size: 32),
      title: Text(baslik),
      content: Text(govde),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(d).pop(false),
          child: Text(l10n.ortakVazgec),
        ),
        FilledButton(
          onPressed: () => Navigator.of(d).pop(true),
          child: Text(l10n.izinDevam),
        ),
      ],
    ),
  );
  return onay ?? false;
}
