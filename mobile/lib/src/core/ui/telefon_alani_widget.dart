/// (P233 §3) TELEFON ALANI — ülke kodu SEÇİLİR, numara yazılır.
///
/// =========================================================================
/// NEDEN BİR WİDGET, NEDEN "her ekrana dropdown ekle" YETMEDİ
/// =========================================================================
/// Telefon mobilde YEDİ ekranda giriliyordu ve yedisi de kendi
/// `TextField`ini kuruyordu; ortak olan yalnızca `TelefonBicimlendirici`ydi.
/// Web'de bu ders P166 §9'da alınmıştı (orada `TelefonAlani` bileşeni var);
/// mobilde alınmamıştı. Ülke seçicisi yedi yere ELLE eklenirse sekizinci
/// ekran onu unutur — ve unutulan ekran, numarayı sessizce ülkesiz
/// kaydeden ekran olur.
///
/// =========================================================================
/// ÜLKE KUTUSU BOŞ BAŞLAR
/// =========================================================================
/// Önceden seçili bir `+90`, kutuya hiç bakmadan yabancı numara yazan
/// kullanıcının numarasını SESSİZCE Türk numarasına çevirirdi — ve telefon
/// GLOBAL BENZERSİZ anahtar olduğu için bu, ya başkasının numarasıyla
/// çakışma ya da erişilemez bir hesap demektir. Bir kerelik tek dokunuşun
/// karşılığı budur; TR listenin BAŞINDA.
///
/// MEVCUT KAYITTA kutu boş DEĞİL: değer E.164 geldiği için ülke ondan
/// çözülür (`telefonParcala`).
library;

import 'package:flutter/material.dart';

import '../i18n/l10n.dart';
import 'merkez_diyalog.dart';
import 'telefon_alani.dart';
import 'telefon_hata_metni.dart';

class TelefonAlani extends StatefulWidget {
  const TelefonAlani({
    super.key,
    required this.ktrl,
    required this.etiket,
    this.zorunlu = true,
    this.etkin = true,
    this.ipucu,
    this.alanAnahtari,
    this.ulkeAnahtari,
  });

  /// HAM değeri taşır: `(+90) 541 922 23 88`. Çağıran ekran bu denetleyiciyi
  /// `telefonNormalle` ile okumaya devam eder — göç sırasında hiçbir ekranın
  /// gönderim kodu değişmedi.
  final TextEditingController ktrl;

  final String etiket;
  final bool zorunlu;
  final bool etkin;
  final String? ipucu;

  /// Testlerin numara kutusunu bulması için.
  final Key? alanAnahtari;

  /// Testlerin ülke kutusunu bulması için.
  final Key? ulkeAnahtari;

  @override
  State<TelefonAlani> createState() => _TelefonAlaniState();
}

class _TelefonAlaniState extends State<TelefonAlani> {
  late final TextEditingController _ulusal;
  Ulke? _ulke;

  /// SEÇİLEN ÜLKE AYRI TUTULUR çünkü `+1`i US ve CA, `+7`yi RU ve KZ
  /// paylaşır: değerden geri çözülen ülke HER ZAMAN listedeki ilki olur ve
  /// kullanıcının seçtiği CA bir sonraki çizimde US'e ATLARDI.
  @override
  void initState() {
    super.initState();
    final p = telefonParcala(widget.ktrl.text);
    _ulke = p.ulke;
    _ulusal = TextEditingController(text: telefonUlusal(widget.ktrl.text));
  }

  @override
  void dispose() {
    _ulusal.dispose();
    super.dispose();
  }

  void _yaz() {
    final haneler = _ulusal.text.replaceAll(RegExp(r'\D'), '');
    widget.ktrl.text = telefonBicimle(haneler, _ulke);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // (P233 §3) `DropdownButtonFormField` DEGIL, ACILIR SAYFA.
        //
        // Dropdown KAPALIYKEN DE elli seceneginin hepsini agaca kuruyor
        // (`IndexedStack`): yerlesim kilitleri o elli satiri dokume
        // yaziyordu ve kilit, EKRAN YERLESIMINI degil ULKE TABLOSUNU
        // olcmeye baslamisti — tabloya bir ulke eklemek alakasiz iki
        // kilidi kirardi. Ayrica elli maddelik bir dropdown telefonda
        // zaten kotu bir liste; alt sayfada ARAMA kutusu var.
        SizedBox(
          width: 132,
          child: _UlkeKutusu(
            anahtar: widget.ulkeAnahtari,
            secili: _ulke,
            etkin: widget.etkin,
            onSec: (u) {
              setState(() => _ulke = u);
              // HANE KIRPMA: yeni ülkenin sınırı daha kısaysa fazla
              // haneler DÜŞER; sessizce bırakmak, kaydedilemeyen bir
              // numarayı geçerli göstermek olurdu.
              final h = _ulusal.text.replaceAll(RegExp(r'\D'), '');
              final k = h.length > u.enCok ? h.substring(0, u.enCok) : h;
              _ulusal.text = ulusalBicimle(u, k);
              _yaz();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            key: widget.alanAnahtari,
            controller: _ulusal,
            enabled: widget.etkin,
            keyboardType: TextInputType.phone,
            // Biçimlendirici ÜLKEYİ ALIR: sınır ülkeye göre değişir.
            inputFormatters: [TelefonBicimlendirici(_ulke)],
            onChanged: (v) {
              // YAPIŞTIRILAN METİN KENDİ ÜLKE KODUNU GETİRDİYSE o kazanır:
              // rehberden kopyalanan numara `+49 171...` diye gelir ve
              // kullanıcıdan ayrıca listeden Almanya'yı seçmesini beklemek,
              // bilgi elimizdeyken yapılan gereksiz bir istektir.
              if (v.contains('+') || v.trim().startsWith('00')) {
                final p = telefonParcala(v);
                if (p.ulke != null) {
                  setState(() => _ulke = p.ulke);
                  _ulusal.text = ulusalBicimle(p.ulke!, p.haneler);
                }
              }
              _yaz();
              setState(() {});
            },
            validator: (_) => telefonHataMetni(
              l10n,
              widget.ktrl.text,
              zorunlu: widget.zorunlu,
            ),
            decoration: InputDecoration(
              labelText: widget.etiket,
              hintText: widget.ipucu ?? l10n.telefonUlusalYerTutucu,
              prefixIcon: const Icon(Icons.phone_outlined),
              border: const OutlineInputBorder(),
              errorText: telefonHataMetni(
                l10n,
                widget.ktrl.text,
                // BOŞ ALAN YAZARKEN AZARLAMAZ: zorunluluk yalnızca
                // GÖNDERİMDE (validator) sorulur.
                zorunlu: false,
              ),
            ),
          ),
        ),
      ],
    );
  }
}


/// Ülke kodu kutusu: kapalıyken TEK satır çizer, dokununca alt sayfa açar.
class _UlkeKutusu extends StatelessWidget {
  const _UlkeKutusu({
    required this.secili,
    required this.onSec,
    required this.etkin,
    this.anahtar,
  });

  final Ulke? secili;
  final ValueChanged<Ulke> onSec;
  final bool etkin;
  final Key? anahtar;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final u = secili;
    return InkWell(
      // VARSAYILAN ANAHTAR: cagiran ekran ayrica anahtar vermek zorunda
      // kalmasin — testler ulke kutusunu her ekranda ayni adla bulur.
      key: anahtar ?? const Key('telefon-ulke'),
      onTap: etkin ? () => _ac(context) : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.telefonUlkeEtiket,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          enabled: etkin,
        ),
        child: Text(
          u == null ? l10n.telefonUlkeSec : '${u.bayrak} ${u.etiket}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _ac(BuildContext context) async {
    // `showModalBottomSheet` DEGIL `merkezSayfaAc`: alt sayfa cagrisi
    // depoda YASAK (merkez_diyalog_test kilidi) — kabuk tek yerde kuruluyor
    // ki klavye dolgusu, yuzey rengi ve kapatma davranisi her yerde ayni
    // olsun.
    final secim = await merkezSayfaAc<Ulke>(
      context,
      builder: (_) => const _UlkeSayfasi(),
    );
    if (secim != null) onSec(secim);
  }
}

class _UlkeSayfasi extends StatefulWidget {
  const _UlkeSayfasi();

  @override
  State<_UlkeSayfasi> createState() => _UlkeSayfasiState();
}

class _UlkeSayfasiState extends State<_UlkeSayfasi> {
  String _sorgu = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // ARAMA: elli ulkede kaydirmak yerine yazip bulmak. Hem ISO kodu hem
    // arama kodu eslesir — kullanici "90" da yazabilir "TR" de.
    final q = _sorgu.trim().toUpperCase();
    final liste = q.isEmpty
        ? kUlkeler
        : [
            for (final u in kUlkeler)
              if (u.kod.contains(q) || u.arama.contains(q)) u,
          ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                key: const Key('telefon-ulke-ara'),
                autofocus: false,
                decoration: InputDecoration(
                  labelText: l10n.aramaBaslik,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _sorgu = v),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: liste.length,
                itemBuilder: (_, i) => ListTile(
                  key: Key('telefon-ulke-${liste[i].kod}'),
                  title: Text('${liste[i].bayrak} ${liste[i].etiket}'),
                  onTap: () => Navigator.of(context).pop(liste[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
