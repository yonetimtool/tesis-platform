import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

/// (P239 §1) KELIME ORTASINDAN BOLUNMEYI ONLEYEN PUNTO SECIMI.
///
/// =========================================================================
/// KUSUR VE KOK NEDENI
/// =========================================================================
/// Ana ekran izgarasinda "Görüntüleme İzni" karti metni "Görüntülem / e
/// İzni" diye KELIME ORTASINDAN bolunuyordu. Sebep Flutter'in satir sonu
/// kurali degil, `AutoSizeText`in SECIM OLCUTU: o, metnin TAMAMININ
/// `maxLines` icine sigdigi EN BUYUK puntoyu secer. Bir kelime satira
/// sigmiyorsa Flutter onu ICINDEN boler ve metin yine iki satira "sigmis"
/// olur — yani AutoSizeText'e gore SORUN YOKTUR.
///
/// Olcut yanlis: punto METNIN TAMAMINA degil, EN UZUN KELIMEYE gore
/// secilmeli. Kelime satira sigiyorsa Flutter onu ASLA bolmez.
///
/// =========================================================================
/// KULLANICININ ISTEDIGI SIRA
/// =========================================================================
///  (a) kelime butunlugu korunacak sekilde sar  -> [kartBaslikPuntosu]
///      taban puntodan asagi inerek en uzun kelimenin sigdigi puntoyu bulur
///  (b) sigmiyorsa metni kucult                  -> ayni dongu, [enKucukPunto]e kadar
///  (c) yine sigmiyorsa SONDAN kes + uc nokta    -> `null` doner; cagiran
///      TEK SATIR + ellipsis cizer (iki satira BOLMEZ)
///  (d) tam metin erisilebilirlikte ve ipucunda  -> cagiranin isi
const double kKartBaslikTaban = 14;
const double kKartBaslikEnKucuk = 8;

/// TIRE VE EGIK CIZGI MESRU BOLUNME YERIDIR.
///
/// "Site-Budget" -> "Site-" / "Budget" bir HECE bolunmesi degil; Unicode
/// satir sonu kurali bunu zaten bir firsat sayar ve tipografik olarak
/// dogrudur. Kilit bunlari ihlal saymaz, bu yuzden punto secimi de
/// bunlari kelime siniri kabul eder.
const _bolunebilir = {'-', '/', '‐', '–', '—'};

/// Metni BOLUNMEZ parcalara ayirir: boslukta VE tire/egik cizgiden sonra.
List<String> bolunmezParcalar(String metin) {
  final parcalar = <String>[];
  final tampon = StringBuffer();
  for (final ch in metin.split('')) {
    if (ch.trim().isEmpty) {
      if (tampon.isNotEmpty) parcalar.add(tampon.toString());
      tampon.clear();
      continue;
    }
    tampon.write(ch);
    if (_bolunebilir.contains(ch)) {
      parcalar.add(tampon.toString());
      tampon.clear();
    }
  }
  if (tampon.isNotEmpty) parcalar.add(tampon.toString());
  return parcalar;
}

/// (P247 §7) OLCUM PAYI (mantiksal piksel). Olcum ve cizim ayni motorla
/// yapilir ama izgara hucresi kesirli genislikte olabilir ve alt piksel
/// yuvarlamasi kelimeyi tam sinirda tasirabilir. Bir piksellik pay,
/// tam sinirdaki kelimeyi yarim punto asagi iter.
const double _olcumPayi = 1.0;

double _genislik(String s, double punto, TextScaler olcek, TextStyle stil) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: stil.copyWith(fontSize: punto)),
    textDirection: TextDirection.ltr,
    textScaler: olcek,
  )..layout();
  final w = tp.width;
  tp.dispose();
  return w;
}

/// En uzun BOLUNMEZ parcanin [enGenislik]e sigdigi en buyuk punto.
///
/// (P247 §7) [stil] CIZILECEK stilin TAMAMIDIR (aile + agirlik + harf
/// araligi) — cagiran `DefaultTextStyle` ile birlestirip verir. Eskiden
/// olcum `TextStyle(fontSize: p)` ile yapiliyordu: iOS'ta bu SF Pro
/// REGULAR, harf araliksiz demekti; kart ise SEMIBOLD (w600) ve temadan
/// miras `letterSpacing: 0.25` ile ciziliyordu. "Rezervasyon" olcumde
/// sigip cizimde tasiyor, son "n" alt satira dusuyordu. Olculen ile
/// cizilen AYNI stil olmadikca bu fonksiyonun verdigi soz tutmaz.
///
/// Hicbiri sigmiyorsa `null` — cagiran TEK SATIR + ellipsis cizmeli.
/// Yarim punto adimlariyla inilir: tam punto adimi 320dp'de gorunur bir
/// sicrama uretiyordu (olculdu), daha ince adim gereksiz hesap.
double? kartBaslikPuntosu(
  String metin,
  double enGenislik, {
  double taban = kKartBaslikTaban,
  double enKucuk = kKartBaslikEnKucuk,
  TextScaler olcek = TextScaler.noScaling,
  TextStyle stil = const TextStyle(),
}) {
  final parcalar = bolunmezParcalar(metin);
  if (parcalar.isEmpty) return taban;
  for (var p = taban; p >= enKucuk; p -= 0.5) {
    var hepsiSigdi = true;
    for (final parca in parcalar) {
      if (_genislik(parca, p, olcek, stil) > enGenislik - _olcumPayi) {
        hepsiSigdi = false;
        break;
      }
    }
    if (hepsiSigdi) return p;
  }
  return null;
}

/// (P247 §7) KART ETIKETI — ana ekran kartlarinin TEK etiket bileseni.
///
/// KURAL: tek kelime ASLA bolunmez. Sira:
///  1. en uzun kelime satira sigana kadar KUCULT ([kartBaslikPuntosu]),
///  2. [enKucukPunto]da bile sigmiyorsa TEK SATIR + sondan kes (ellipsis),
///  3. tam metin ipucunda ve ekran okuyucuda.
///
/// NEDEN TEK BILESEN: P239 kurali yalniz hizli erisim kartinin icine
/// yazilmisti; "Hizli Ozet" kutusu (`StatTile`) duz `AutoSizeText`
/// kullaniyordu ve Almancada "Gesamteinnahme / n" diye bolunuyordu
/// (P247 §7 kilidi yakaladi). Kural bir bilesende durunca yeni bir kart
/// onu "unutamaz".
///
/// OLCUM CIZILEN STILLE: `DefaultTextStyle` (tema ailesi, `letterSpacing`)
/// + [stil] (agirlik) birlestirilip olculur — iOS kusurunun kok nedeni
/// olcum ile cizimin farkli stil kullanmasiydi.
///
/// IKINCI EMNIYET: `AutoSizeText.wrapWords: false` — paket, her kelimenin
/// satira sigdigi puntoya kadar kendisi de iner. Gruplu (ortak punto)
/// kartlarda grup yalniz DAHA KUCUGE indirebilir; kucukte de kelime
/// bolunmez.
class KartEtiketi extends StatelessWidget {
  const KartEtiketi(
    this.metin, {
    super.key,
    required this.stil,
    this.maxLines = 2,
    this.grup,
    this.enKucukPunto = kKartBaslikEnKucuk,
  });

  final String metin;
  final TextStyle stil;
  final int maxLines;
  final AutoSizeGroup? grup;
  final double enKucukPunto;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, kisit) {
        final etkin = DefaultTextStyle.of(context).style.merge(stil);
        final taban = etkin.fontSize ?? kKartBaslikTaban;
        // Tek satirlik etikette sarma yoktur: AutoSizeText kucultur, yine
        // sigmazsa sondan keser. Punto hesabi yalniz cok satirda gerekir.
        final punto = maxLines > 1
            ? kartBaslikPuntosu(
                metin,
                kisit.maxWidth,
                taban: taban,
                enKucuk: enKucukPunto,
                olcek: MediaQuery.textScalerOf(context),
                stil: etkin,
              )
            : taban;
        final sigdi = punto != null;
        return Tooltip(
          message: metin,
          child: AutoSizeText(
            metin,
            group: grup,
            maxLines: sigdi ? maxLines : 1,
            minFontSize: enKucukPunto,
            wrapWords: false,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            semanticsLabel: metin,
            style: stil.copyWith(fontSize: punto ?? enKucukPunto),
          ),
        );
      },
    );
  }
}
