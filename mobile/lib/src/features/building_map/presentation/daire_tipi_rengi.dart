/// (P122) DAİRE TİPİNE BAĞLI RENK — bir kat bir bakışta okunsun.
///
/// Tasarımcıda tip atandıktan sonra bilgi yalnız **yan panelde** duruyordu;
/// ızgaraya bakan kişi hangi dairenin ne olduğunu ancak tek tek dokunarak
/// görebiliyordu. Kat planının işi tam olarak budur: **bakışta okunmak.**
///
/// RENK **AD'DAN TÜRETİLİR, KAYITTA TUTULMAZ.** Gerekçe: tipe bir renk
/// kolonu eklemek, yöneticinin doldurması gereken bir alan daha demekti
/// (ve doldurulmadığında yine renksiz kalırdı). Türetilen renk her zaman
/// vardır, tutarlıdır ve tanım yeniden adlandırılana kadar değişmez.
///
/// KİMLİK DEĞİL **AD** kullanılır: aynı adı taşıyan tip iki tesiste aynı
/// rengi alır ve ekran görüntüsü paylaşıldığında konuşulabilir olur
/// (kimlik UUID'dir; her tesiste farklı renk üretirdi).
///
/// PALET SABİT VE KÜÇÜK: sekiz ton. Sürekli bir renk çarkından üretmek
/// (hue = hash % 360) birbirine karışan tonlar üretir — "2+1" ile "3+1"in
/// ayırt edilemediği bir kat planı, renksiz olandan kötüdür.
library;

import 'package:flutter/material.dart';

/// Tip renkleri — koyu/açık temada da okunur tonlar.
///
/// Hepsi orta koyulukta seçildi: hücre dolgusu bu rengin düşük alfalı
/// hâlidir ve kenarlık tam tonudur; çok açık bir ton kenarlığı görünmez,
/// çok koyu bir ton koyu temada dolguyu siyaha çevirirdi.
const daireTipiPaleti = <Color>[
  Color(0xFF3949AB), // indigo   (mevcut varsayılan — tipsizle aynı aile)
  Color(0xFF00897B), // teal
  Color(0xFF8E24AA), // mor
  Color(0xFFEF6C00), // turuncu
  Color(0xFF43A047), // yeşil
  Color(0xFF00838F), // camgöbeği
  Color(0xFFC62828), // kırmızı
  Color(0xFF5D4037), // kahve
];

/// [tipAd] için kararlı bir renk. `null`/boş → varsayılan indigo.
///
/// Karma DETERMİNİSTİK olmalıdır: `String.hashCode` Dart'ta çalışmalar
/// arasında **değişebilir** (aynı süreçte tutarlıdır ama garanti edilmez).
/// Renk kayda girmese de ekran görüntüleri ve kullanıcı alışkanlığı bunu
/// bir "kimlik" gibi kullanır — koşumdan koşuma değişen bir renk, kullanıcı
/// açısından bozuk görünür. Bu yüzden basit ve sabit bir toplam kullanılır.
Color daireTipiRengi(String? tipAd) {
  final ad = (tipAd ?? '').trim();
  if (ad.isEmpty) return daireTipiPaleti.first;
  var toplam = 0;
  for (final birim in ad.toLowerCase().runes) {
    // 31 çarpanı ve 16 bit maske: taşmayı önler, dağılımı korur.
    toplam = (toplam * 31 + birim) & 0xFFFF;
  }
  return daireTipiPaleti[toplam % daireTipiPaleti.length];
}

/// Hücrede gösterilecek KISA tip etiketi.
///
/// Tip adları "2+1" gibi kısa olabildiği gibi "Dubleks Bahçe Katı" gibi
/// uzun da olabilir. Hücre 58 dp geniştir; uzun adı olduğu gibi yazmak ya
/// taşırır ya da tek harfe indirir. İlk kelime + varsa ilk harfler yerine
/// **kırpma** seçildi: "Dubleks…" okunabilir, "DBK" değildir.
String daireTipiKisa(String? tipAd, {int sinir = 7}) {
  final ad = (tipAd ?? '').trim();
  if (ad.isEmpty) return '';
  if (ad.length <= sinir) return ad;
  return '${ad.substring(0, sinir - 1)}…';
}
