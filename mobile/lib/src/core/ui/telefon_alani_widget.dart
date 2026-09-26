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
import 'package:flutter/services.dart';

import '../i18n/l10n.dart';
import 'merkez_diyalog.dart';
import 'telefon_alani.dart';
import 'telefon_hata_metni.dart';

/// (P248 §2) TEK WIDGET, ÜÇ KULLANIM — ikinci bir telefon alanı YAZILMAZ.
///
///  * VARSAYILAN: etiketli form alanı (sakin/personel/profil/kayıt...).
///  * [sabitHat]: firma/işletme numarası — TR cep ön eki (`5`) aranmaz.
///  * [kimlik]: tek alanlı giriş (P205) — "e-posta VEYA telefon". Alan
///    rakam/`+` ile başlayınca TELEFON moduna geçer (ülke kutusu belirir,
///    numara biçimlenir); harf ya da `@` görülünce e-posta modunda kalır.
///    Kural `telefon_alani.dart` `kimlikTelefonMu`da (panel ikiziyle aynı).
///
/// KİP DEĞİŞİRKEN NUMARA KUTUSU YENİDEN KURULMAZ: ülke kutusu soluna
/// eklenir, metin kutusu yerinde kalır (anahtarlı). Yeniden kurulsaydı
/// ilk rakamda odak ve klavye kaybolurdu.
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
    this.sabitHat = false,
    this.kimlik = false,
    this.varsayilanUlke,
    this.yardimMetni,
    this.dogrulayici,
    this.onGonder,
    this.textInputAction,
  });

  /// HAM değeri taşır: `(+90) 541 922 23 88`. Çağıran ekran bu denetleyiciyi
  /// `telefonNormalle` ile okumaya devam eder — göç sırasında hiçbir ekranın
  /// gönderim kodu değişmedi. (P248 §2) Kimlik kipinde e-posta ise HAM
  /// metin; gönderimde `kimlikGonderimDegeri` kullanılır.
  final TextEditingController ktrl;

  final String etiket;
  final bool zorunlu;
  final bool etkin;
  final String? ipucu;

  /// Testlerin numara kutusunu bulması için.
  final Key? alanAnahtari;

  /// Testlerin ülke kutusunu bulması için.
  final Key? ulkeAnahtari;

  /// (P248 §2) Sabit hat da geçerli (firma/işletme).
  final bool sabitHat;

  /// (P248 §2) "E-posta veya telefon" tek alanı (giriş).
  final bool kimlik;

  /// (P248 §2) Ülkesiz yazılan numaraya varsayılan ülke. YALNIZ giriş:
  /// giriş hiçbir şey SAKLAMAZ, yanlış tahmin yalnızca 401 üretir.
  final String? varsayilanUlke;

  final String? yardimMetni;

  /// (P248 §2) Kimlik kipinde çağıranın doğrulayıcısı (ör. "boş olamaz").
  final String? Function(String)? dogrulayici;

  final VoidCallback? onGonder;
  final TextInputAction? textInputAction;

  @override
  State<TelefonAlani> createState() => _TelefonAlaniState();
}

class _TelefonAlaniState extends State<TelefonAlani> {
  late final TextEditingController _ulusal;
  Ulke? _ulke;

  /// Bu widget'ın ktrl'a EN SON yazdığı metin. Dışarıdan gelen değişiklik
  /// (ön-doldurma, form sıfırlama) bundan farklıdır ve yeniden çözülür.
  String _sonYazilan = '';

  bool get _telefonModu =>
      !widget.kimlik || kimlikTelefonMu(widget.ktrl.text);

  /// SEÇİLEN ÜLKE AYRI TUTULUR çünkü `+1`i US ve CA, `+7`yi RU ve KZ
  /// paylaşır: değerden geri çözülen ülke HER ZAMAN listedeki ilki olur ve
  /// kullanıcının seçtiği CA bir sonraki çizimde US'e ATLARDI.
  @override
  void initState() {
    super.initState();
    _ulusal = TextEditingController();
    _disaridanYukle();
    widget.ktrl.addListener(_ktrlDegisti);
  }

  /// (P248 §2) DIŞARIDAN GELEN DEĞER: eskiden yalnız `initState`te
  /// okunuyordu; eşzamansız ön-doldurma (giriş "beni hatırla") kutuya HİÇ
  /// yansımıyordu.
  void _disaridanYukle() {
    final ham = widget.ktrl.text;
    _sonYazilan = ham;
    if (widget.kimlik && !kimlikTelefonMu(ham)) {
      _ulusal.text = ham;
      return;
    }
    final p = telefonParcala(ham);
    _ulke = p.ulke ??
        _ulke ??
        (widget.kimlik ? ulkeBul(widget.varsayilanUlke) : null);
    _ulusal.text = _ulke != null
        ? ulusalBicimle(_ulke!, telefonHaneleri(ham))
        : telefonUlusal(ham);
  }

  void _ktrlDegisti() {
    if (widget.ktrl.text == _sonYazilan) return;
    setState(_disaridanYukle);
  }

  @override
  void didUpdateWidget(covariant TelefonAlani eski) {
    super.didUpdateWidget(eski);
    if (eski.ktrl != widget.ktrl) {
      eski.ktrl.removeListener(_ktrlDegisti);
      widget.ktrl.addListener(_ktrlDegisti);
      _disaridanYukle();
    }
  }

  @override
  void dispose() {
    widget.ktrl.removeListener(_ktrlDegisti);
    _ulusal.dispose();
    super.dispose();
  }

  void _ktrlYaz(String metin) {
    _sonYazilan = metin;
    widget.ktrl.text = metin;
  }

  void _yaz() {
    final haneler = _ulusal.text.replaceAll(RegExp(r'\D'), '');
    _ktrlYaz(telefonBicimle(haneler, _ulke));
  }

  void _ulusalKoy(String metin) {
    _ulusal.value = TextEditingValue(
      text: metin,
      selection: TextSelection.collapsed(offset: metin.length),
    );
  }

  void _degisti(String v) {
    if (widget.kimlik) {
      // (P248 §2) TELEFON MODUNDA YALNIZ BOŞLUK: `+49 151` yazılırken `+49`
      // ülke kutusuna geçer ve numara kutusu BOŞALIR; ardından gelen boşluk
      // e-posta moduna düşürüp ülkeyi KAYBETTİRİYORDU (panelde ölçüldü).
      if (kimlikTelefonMu(widget.ktrl.text) &&
          v.isNotEmpty &&
          v.trim().isEmpty) {
        _ulusalKoy('');
        setState(() {});
        return;
      }
      // E-POSTA MODU: metin OLDUĞU GİBİ.
      // (P248 §2) `_ulke` SIFIRLANMAZ: kullanicinin sectigi ulke (DE),
      // numara silinip yeniden yazilinca TR'ye dusmesin (panelde olculdu).
      if (!kimlikTelefonMu(v)) {
        _ktrlYaz(v);
        setState(() {});
        return;
      }
      // E-postadan telefona İLK geçiş: ham metin çözülür (`0532...` -> TR).
      if (!kimlikTelefonMu(widget.ktrl.text)) {
        final p = telefonParcala(v);
        final u = p.ulke ?? _ulke ?? ulkeBul(widget.varsayilanUlke);
        _ulke = u;
        if (u != null) {
          var h = p.haneler.replaceAll(RegExp(r'^0+'), '');
          if (h.length > u.enCok) h = h.substring(0, u.enCok);
          _ulusalKoy(ulusalBicimle(u, h));
          _yaz();
        } else {
          _ktrlYaz(v);
        }
        setState(() {});
        return;
      }
      // Telefon modunda numara SİLİNDİ: alan boş (nötr) moda döner.
      if (v.replaceAll(RegExp(r'\D'), '').isEmpty && !v.contains('+')) {
        _ktrlYaz('');
        setState(() {});
        return;
      }
    }
    // YAPIŞTIRILAN METİN KENDİ ÜLKE KODUNU GETİRDİYSE o kazanır:
    // rehberden kopyalanan numara `+49 171...` diye gelir ve
    // kullanıcıdan ayrıca listeden Almanya'yı seçmesini beklemek,
    // bilgi elimizdeyken yapılan gereksiz bir istektir.
    if (v.contains('+') || v.trim().startsWith('00')) {
      final p = telefonParcala(v);
      if (p.ulke != null) {
        _ulke = p.ulke;
        _ulusalKoy(ulusalBicimle(p.ulke!, p.haneler));
      }
    }
    _yaz();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final telefonModu = _telefonModu;
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
        if (telefonModu) ...[
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
        ],
        Expanded(
          key: const ValueKey('telefon-numara-kutusu'),
          child: TextFormField(
            key: widget.alanAnahtari,
            controller: _ulusal,
            enabled: widget.etkin,
            // (P248 §2) Kimlik kipinde klavye `emailAddress`: telefon
            // klavyesinde harf yok, e-postaya dönmek imkânsız olurdu.
            keyboardType: widget.kimlik
                ? TextInputType.emailAddress
                : TextInputType.phone,
            autocorrect: !widget.kimlik,
            autofillHints:
                widget.kimlik ? const [AutofillHints.username] : null,
            textInputAction: widget.textInputAction,
            onFieldSubmitted:
                widget.onGonder == null ? null : (_) => widget.onGonder!(),
            // Biçimlendirici ÜLKEYİ ALIR: sınır ülkeye göre değişir.
            inputFormatters: [
              if (widget.kimlik)
                _KimlikBicimlendirici(
                  ulke: _ulke,
                  telefonModu: () => kimlikTelefonMu(widget.ktrl.text),
                )
              else
                TelefonBicimlendirici(_ulke),
            ],
            onChanged: _degisti,
            validator: (_) => widget.kimlik
                ? widget.dogrulayici?.call(widget.ktrl.text)
                : telefonHataMetni(
                    l10n,
                    widget.ktrl.text,
                    zorunlu: widget.zorunlu,
                    sabitHat: widget.sabitHat,
                  ),
            decoration: InputDecoration(
              labelText: widget.etiket,
              hintText: widget.ipucu ?? l10n.telefonUlusalYerTutucu,
              helperText: widget.yardimMetni,
              helperMaxLines: 2,
              prefixIcon: Icon(
                widget.kimlik && !telefonModu
                    ? Icons.person_outline
                    : Icons.phone_outlined,
              ),
              border: const OutlineInputBorder(),
              // Kimlik kipinde YAZARKEN telefon hatası gösterilmez: giriş
              // bilinçli olarak biçim denetimi yapmaz (P205 — belirsizlik
              // sunucuda).
              errorText: widget.kimlik
                  ? null
                  : telefonHataMetni(
                      l10n,
                      widget.ktrl.text,
                      // BOŞ ALAN YAZARKEN AZARLAMAZ: zorunluluk yalnızca
                      // GÖNDERİMDE (validator) sorulur.
                      zorunlu: false,
                      sabitHat: widget.sabitHat,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// (P248 §2) Kimlik kipinin biçimlendiricisi: e-posta yazılırken metne
/// DOKUNMAZ; telefon modundayken ortak [TelefonBicimlendirici]ya devreder.
/// Harf ya da `@` gelirse metin olduğu gibi geçer — alan e-postaya döner.
class _KimlikBicimlendirici extends TextInputFormatter {
  const _KimlikBicimlendirici({required this.ulke, required this.telefonModu});

  final Ulke? ulke;
  final bool Function() telefonModu;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue eski,
    TextEditingValue yeni,
  ) {
    if (!kimlikTelefonMu(yeni.text) || !telefonModu()) return yeni;
    return TelefonBicimlendirici(ulke).formatEditUpdate(eski, yeni);
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
          u == null ? l10n.telefonUlkeSec : u.etiket,
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
                  title: Text(liste[i].etiket),
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
