/// (P233 §4) E-POSTA ALANI — biçim ve uzunluk denetimi ALANIN İÇİNDE.
///
/// `TelefonAlani` widget'ının ikizi ve aynı gerekçeyle var: e-posta dört
/// ekranda giriliyordu (sakin, personel, kayıt, giriş) ve doğrulama ya
/// yoktu ya da her ekranın kendi regex'iydi — `kayit_screen` içinde
/// `^[^@\s]+@[^@\s]+\.[^@\s]+$` vardı ve uzunluk sınırlarını bilmiyordu,
/// yani sunucunun reddettiği bir adres orada geçerli görünüyordu.
///
/// SUNUCU ZATEN REDDEDİYORDU (`EmailStr`, ölçüldü); eksik olan kuralın
/// KULLANICIYA SÖYLENMESİYDİ.
library;

import 'package:flutter/material.dart';

import '../i18n/l10n.dart';
import 'eposta.dart';
import 'eposta_hata_metni.dart';

export 'eposta.dart';

class EpostaAlani extends StatefulWidget {
  const EpostaAlani({
    super.key,
    required this.ktrl,
    required this.etiket,
    this.zorunlu = true,
    this.etkin = true,
    this.ipucu,
    this.alanAnahtari,
    this.otomatikSonraki = true,
  });

  final TextEditingController ktrl;
  final String etiket;
  final bool zorunlu;
  final bool etkin;
  final String? ipucu;
  final Key? alanAnahtari;

  /// `TextInputAction.next` — çok alanlı formlarda klavye "ileri" göstersin.
  final bool otomatikSonraki;

  @override
  State<EpostaAlani> createState() => _EpostaAlaniState();
}

class _EpostaAlaniState extends State<EpostaAlani> {
  /// HATA YAZARKEN DEĞİL, ALANDAN ÇIKINCA görünür: `a@` yazan kullanıcıya
  /// ikinci harfte "biçim geçersiz" demek, adresini yazmasını bitirmeden
  /// azarlamaktır.
  bool _dokunuldu = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Focus(
      onFocusChange: (odakta) {
        if (!odakta && !_dokunuldu) setState(() => _dokunuldu = true);
        if (!odakta) setState(() {});
      },
      child: TextFormField(
        key: widget.alanAnahtari,
        controller: widget.ktrl,
        enabled: widget.etkin,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        textInputAction:
            widget.otomatikSonraki ? TextInputAction.next : TextInputAction.done,
        // SINIR SESSİZ DEĞİL: `maxLength` fazlasını yutar ama kullanıcı
        // 254'e pratikte hiç ulaşmaz; ulaşırsa `cokUzun` hatası önce
        // görünür (doğrulama kırpılmamış değeri okur). Sayaç GİZLİ —
        // 254/254 sayacı her e-posta alanının altında gürültüdür.
        maxLength: kEpostaSinir + 2,
        buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
            null,
        onChanged: (_) => setState(() {}),
        validator: (v) =>
            epostaHataMetni(l10n, v ?? '', zorunlu: widget.zorunlu),
        decoration: InputDecoration(
          labelText: widget.etiket,
          hintText: widget.ipucu,
          prefixIcon: const Icon(Icons.mail_outline),
          border: const OutlineInputBorder(),
          errorText: _dokunuldu
              ? epostaHataMetni(l10n, widget.ktrl.text, zorunlu: widget.zorunlu)
              : null,
        ),
      ),
    );
  }
}
