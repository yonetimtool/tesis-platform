import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// (P171) SUNUCUDA TEMIZLENMIS ZENGIN METNI CIZER.
///
/// =========================================================================
/// NEDEN `flutter_html` DEGIL
/// =========================================================================
/// Sunucu govdeyi YAZMA ANINDA beyaz listeyle temizliyor
/// (`backend/app/temizleme.py`): geriye YALNIZ su 13 etiket kaliyor —
/// `p br strong em u s h1 h2 h3 h4 ul ol li a blockquote hr` — ve iki
/// oznitelik (`a[href]`, `a[title]`).
///
/// `flutter_html` genel bir HTML+CSS motorudur: onlarca etiket, CSS
/// ayristirma, tablo/medya destegi. Bizim dilbilgimiz 13 etiket. Genel
/// motoru getirmenin bedeli paket boyutu ve — daha onemlisi — BAKIM
/// YUZEYI: kutuphane surumu atladiginda ya da bakim araligina girdiginde
/// (gecmiste oldu) yasal metin ekrani ona bagli kalirdi.
///
/// =========================================================================
/// ELLE AYRISTIRMA BURADA NEDEN KABUL EDILEBILIR (sunucuda DEGILDI)
/// =========================================================================
/// Sunucuda elle temizleyici yazmayi acikca reddettik: orada ayristirici
/// GUVENLIK SINIRIDIR ve bir kose durumu XSS demektir.
///
/// Burada oyle degil. Govde bu noktaya gelmeden ONCE temizlenmis oluyor;
/// bu dosya yalniz bir GORUNTULEME isi yapiyor. En kotu hata bicimi
/// "bir etiketi yanlis cizmek"tir, "kod calistirmak" degil. Sinir
/// SUNUCUDA; burada sinir yok, bu yuzden kucuk ve okunur bir ayristirici
/// dogru olcu.
///
/// SAVUNMA KATMANI YINE DE VAR: baglanti acilirken sema TEKRAR denetlenir
/// (`http`/`https`/`mailto`). Sunucu zaten reddediyor; buradaki denetim,
/// bu bilesenin bir gun baska bir kaynakla kullanilmasi ihtimaline karsi.
class ZenginGovde extends StatelessWidget {
  const ZenginGovde(this.html, {super.key, this.temelStil});

  final String html;

  /// Paragraf metninin temel stili; basliklar ve vurgular bunun uzerine biner.
  final TextStyle? temelStil;

  @override
  Widget build(BuildContext context) {
    final temel = temelStil ?? Theme.of(context).textTheme.bodyMedium!;
    final kok = _ayristir(html);
    final bloklar = <Widget>[];
    _bloklariTopla(context, kok, temel, bloklar);
    if (bloklar.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: bloklar,
    );
  }
}

// =========================================================================
// AGAC
// =========================================================================

class _Dugum {
  _Dugum(this.etiket, {this.metin, this.href});

  final String etiket; // '' => metin dugumu
  final String? metin;
  final String? href;
  final List<_Dugum> cocuklar = [];
}

const _blokEtiketler = {
  'p', 'h1', 'h2', 'h3', 'h4', 'ul', 'ol', 'li', 'blockquote', 'hr',
};

/// Kapanisi olmayan etiketler.
const _tekilEtiketler = {'br', 'hr'};

final _etiketDeseni = RegExp(r'<\s*(/?)\s*([a-zA-Z][a-zA-Z0-9]*)([^>]*)>');
final _hrefDeseni = RegExp(r'''href\s*=\s*["']([^"']*)["']''');

_Dugum _ayristir(String kaynak) {
  final kok = _Dugum('kok');
  final yigin = <_Dugum>[kok];
  var konum = 0;

  void metinEkle(String ham) {
    if (ham.isEmpty) return;
    final cozulmus = _varlikCoz(ham);
    if (cozulmus.isEmpty) return;
    yigin.last.cocuklar.add(_Dugum('', metin: cozulmus));
  }

  for (final e in _etiketDeseni.allMatches(kaynak)) {
    metinEkle(kaynak.substring(konum, e.start));
    konum = e.end;

    final kapanis = e.group(1) == '/';
    final ad = e.group(2)!.toLowerCase();

    if (_tekilEtiketler.contains(ad)) {
      if (!kapanis) yigin.last.cocuklar.add(_Dugum(ad));
      continue;
    }
    if (kapanis) {
      // YIGINDA ARA, KORU KORUNE ATMA: eslesmeyen bir kapanis etiketi
      // (sunucu temizledigi icin beklenmez ama) butun agaci cokertmemeli.
      final indeks = yigin.lastIndexWhere((d) => d.etiket == ad);
      if (indeks > 0) yigin.removeRange(indeks, yigin.length);
      continue;
    }
    final yeni = _Dugum(ad, href: _hrefDeseni.firstMatch(e.group(3)!)?.group(1));
    yigin.last.cocuklar.add(yeni);
    yigin.add(yeni);
  }
  metinEkle(kaynak.substring(konum));
  return kok;
}

/// nh3 metni KACIRIR (`&amp;`, `&lt;`); cozmezsek kullanici ham varlik gorur.
String _varlikCoz(String s) => s
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&#x27;', "'")
    // `&amp;` EN SONA: once cozersek "&amp;lt;" -> "<" olurdu.
    .replaceAll('&amp;', '&');

// =========================================================================
// CIZIM
// =========================================================================

void _bloklariTopla(
  BuildContext context,
  _Dugum dugum,
  TextStyle temel,
  List<Widget> cikti, {
  bool siraliMi = false,
  int derinlik = 0,
}) {
  final satirIci = <_Dugum>[];

  void satirIciBosalt() {
    if (satirIci.isEmpty) return;
    final parcalar = <InlineSpan>[];
    for (final c in satirIci) {
      _satirIciTopla(context, c, temel, parcalar);
    }
    satirIci.clear();
    if (parcalar.isEmpty) return;
    cikti.add(Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SelectableText.rich(TextSpan(children: parcalar)),
    ));
  }

  var sira = 0;
  for (final c in dugum.cocuklar) {
    if (!_blokEtiketler.contains(c.etiket)) {
      satirIci.add(c);
      continue;
    }
    satirIciBosalt();

    switch (c.etiket) {
      case 'hr':
        cikti.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1),
        ));
      case 'ul':
      case 'ol':
        _bloklariTopla(context, c, temel, cikti,
            siraliMi: c.etiket == 'ol', derinlik: derinlik + 1);
      case 'li':
        sira++;
        final isaret = siraliMi ? '$sira.' : '•';
        final parcalar = <InlineSpan>[];
        for (final ic in c.cocuklar) {
          _satirIciTopla(context, ic, temel, parcalar);
        }
        cikti.add(Padding(
          padding: EdgeInsets.only(left: 8.0 * derinlik, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 22, child: Text(isaret, style: temel)),
              Expanded(
                child: SelectableText.rich(TextSpan(children: parcalar)),
              ),
            ],
          ),
        ));
      case 'blockquote':
        final ic = <Widget>[];
        _bloklariTopla(context, c, temel, ic);
        cikti.add(Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                width: 3,
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: ic,
          ),
        ));
      default:
        // p, h1-h4
        final stil = _blokStili(context, c.etiket, temel);
        final parcalar = <InlineSpan>[];
        for (final ic in c.cocuklar) {
          _satirIciTopla(context, ic, stil, parcalar);
        }
        if (parcalar.isEmpty) break;
        cikti.add(Padding(
          padding: EdgeInsets.only(
            top: c.etiket == 'p' ? 0 : 10,
            bottom: 8,
          ),
          child: SelectableText.rich(TextSpan(children: parcalar)),
        ));
    }
  }
  satirIciBosalt();
}

TextStyle _blokStili(BuildContext context, String etiket, TextStyle temel) {
  final t = Theme.of(context).textTheme;
  return switch (etiket) {
    'h1' => t.titleLarge ?? temel,
    'h2' => t.titleMedium ?? temel,
    'h3' || 'h4' => (t.titleSmall ?? temel),
    _ => temel,
  };
}

void _satirIciTopla(
  BuildContext context,
  _Dugum dugum,
  TextStyle stil,
  List<InlineSpan> cikti,
) {
  if (dugum.etiket.isEmpty) {
    if ((dugum.metin ?? '').trim().isEmpty && cikti.isEmpty) return;
    cikti.add(TextSpan(text: dugum.metin, style: stil));
    return;
  }
  if (dugum.etiket == 'br') {
    cikti.add(const TextSpan(text: '\n'));
    return;
  }

  var yeni = stil;
  switch (dugum.etiket) {
    case 'strong' || 'b':
      yeni = stil.copyWith(fontWeight: FontWeight.w600);
    case 'em' || 'i':
      yeni = stil.copyWith(fontStyle: FontStyle.italic);
    case 'u':
      yeni = stil.copyWith(decoration: TextDecoration.underline);
    case 's':
      yeni = stil.copyWith(decoration: TextDecoration.lineThrough);
    case 'a':
      yeni = stil.copyWith(
        color: Theme.of(context).colorScheme.primary,
        decoration: TextDecoration.underline,
      );
  }

  final ic = <InlineSpan>[];
  for (final c in dugum.cocuklar) {
    _satirIciTopla(context, c, yeni, ic);
  }
  if (ic.isEmpty) return;

  if (dugum.etiket == 'a' && dugum.href != null) {
    cikti.add(TextSpan(
      children: ic,
      recognizer: _baglantiTanicisi(dugum.href!),
    ));
    return;
  }
  cikti.add(TextSpan(children: ic));
}

/// Baglanti acici — SEMA BURADA TEKRAR DENETLENIR.
///
/// Sunucu `javascript:`/`data:` semalarini zaten reddediyor. Buradaki
/// denetim ikinci katmandir: bu bilesen bir gun baska bir kaynakla
/// (temizlenmemis bir govdeyle) kullanilirsa, sessizce tehlikeli bir
/// semayi acmasin.
TapGestureRecognizer? _baglantiTanicisi(String href) {
  final adres = Uri.tryParse(href);
  if (adres == null) return null;
  if (!const {'http', 'https', 'mailto'}.contains(adres.scheme)) return null;
  return TapGestureRecognizer()
    ..onTap = () {
      launchUrl(adres, mode: LaunchMode.externalApplication);
    };
}
