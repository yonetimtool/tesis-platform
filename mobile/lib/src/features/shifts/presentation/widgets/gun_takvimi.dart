import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/l10n.dart';

/// (P229 §2) VARDIYA ICIN GUN SECIMI — ay izgarasi, coklu secim.
///
/// =========================================================================
/// NEDEN YENI BIR BILESEN, `showDatePicker` DEGIL
/// =========================================================================
/// Material'in aralik secicisi (`showDateRangePicker`) yalniz BITISIK
/// gunler verir. Istenen ise "ayin 3'u, 7'si ve 19'u" gibi BITISIK OLMAYAN
/// secim. Aralik secici ile bu, ucuncu gunu AYRI bir istekle eklemek
/// demekti — ve her istek ayri bir cakisma diyalogu acardi.
///
/// =========================================================================
/// DOKUNMATIK SECIM KARARI: DOKUN = TEKIL, UZUN BAS = ARALIGA TAMAMLA
/// =========================================================================
/// Masaustunde (P214) aralik `Shift`, tekil ekleme `Ctrl` ile yapiliyor.
/// Dokunmatikte degistirici tus YOKTUR; uc secenek degerlendirildi:
///
///  1. SURUKLE-SEC (web'de var). REDDEDILDI: dialog KAYDIRILABILIR bir
///     govdede duruyor; suruklemeyi kaydirmadan ayirmak jest catismasi
///     uretir — kullanici ayi kaydirmaya calisirken gun secer.
///  2. "BASLANGIC SEC / BITIS SEC" KIPI. REDDEDILDI: gorunmez bir kip
///     yaratir; kullanici hangi asamada oldugunu unutur.
///  3. DOKUN = tekil ac/kapa, UZUN BAS = "son secilenden buraya kadar".
///     SECILEN BU. Tekil secim en sik yapilan istir ve TEK dokunusta
///     olur; aralik, alisilmis bir jest olan uzun basmayla gelir. Kip
///     yoktur: her dokunus kendi basina anlamlidir.
///
/// Hicbir gun secili degilken uzun bas TEKIL secim gibi davranir — yoksa
/// jest sessizce hicbir sey yapmazdi.
///
/// =========================================================================
/// GUN ADLARI CEVIRI SOZLUGUNDEN DEGIL, YERELDEN
/// =========================================================================
/// `DateFormat.E(dil)` yedi dilin gun adlarini zaten biliyor. Sozluge 7x7
/// = 49 yeni anahtar eklemek, her birinin cevrilmesi gereken ve
/// yanlislikla Turkce kalabilecek 49 satir demekti.
///
/// =========================================================================
/// DOKUNMA HEDEFI 48x48 (P220 kilidi)
/// =========================================================================
/// Hucre YUKSEKLIGI `kMinInteractiveDimension`dan (48) kucuk olamaz.
/// 320dp'de 7 sutun ~45dp'ye duser; genislik daralabilir ama dokunma
/// alani tum hucreyi kaplar ve yukseklik 48'de sabittir.
class GunTakvimi extends StatefulWidget {
  const GunTakvimi({
    super.key,
    required this.ay,
    required this.secili,
    required this.onDegisti,
    this.enErken,
    this.enGec,
  });

  /// Gosterilen ayin herhangi bir gunu.
  final DateTime ay;

  /// Secili gunler — `yyyy-MM-dd`.
  final Set<String> secili;

  final ValueChanged<Set<String>> onDegisti;
  final DateTime? enErken;
  final DateTime? enGec;

  @override
  State<GunTakvimi> createState() => _GunTakvimiState();
}

String gunAnahtari(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class _GunTakvimiState extends State<GunTakvimi> {
  late DateTime _ay = DateTime(widget.ay.year, widget.ay.month);
  String? _sonSecilen;

  bool _kapali(DateTime g) =>
      (widget.enErken != null && g.isBefore(widget.enErken!)) ||
      (widget.enGec != null && g.isAfter(widget.enGec!));

  void _tekil(DateTime g) {
    final a = gunAnahtari(g);
    final y = Set<String>.from(widget.secili);
    if (!y.remove(a)) {
      y.add(a);
      _sonSecilen = a;
    }
    widget.onDegisti(y);
  }

  void _araliga(DateTime g) {
    if (_sonSecilen == null) {
      _tekil(g);
      return;
    }
    final bas = DateTime.parse(_sonSecilen!);
    final ilk = bas.isBefore(g) ? bas : g;
    final son = bas.isBefore(g) ? g : bas;
    final y = Set<String>.from(widget.secili);
    for (var d = ilk; !d.isAfter(son); d = d.add(const Duration(days: 1))) {
      if (!_kapali(d)) y.add(gunAnahtari(d));
    }
    _sonSecilen = gunAnahtari(g);
    widget.onDegisti(y);
  }

  /// "Tum pazartesiler" — P207'de web'de vardi, mobile de geliyor.
  ///
  /// NEDEN GEREKLI: vardiya duzenleri haftalik tekrar eder; onsuz yonetici
  /// ayin dort pazartesisini TEK TEK dokunarak secerdi.
  void _haftaGunu(int haftaGunu) {
    final y = Set<String>.from(widget.secili);
    final sonGun = DateTime(_ay.year, _ay.month + 1, 0).day;
    for (var i = 1; i <= sonGun; i++) {
      final d = DateTime(_ay.year, _ay.month, i);
      if (d.weekday == haftaGunu && !_kapali(d)) y.add(gunAnahtari(d));
    }
    widget.onDegisti(y);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dil = Localizations.localeOf(context).languageCode;
    final renk = Theme.of(context).colorScheme;
    final ilkGun = DateTime(_ay.year, _ay.month, 1);
    final sonGun = DateTime(_ay.year, _ay.month + 1, 0).day;
    // Pazartesi = 1 ... Pazar = 7 (web ile ayni siralama).
    final bosluk = ilkGun.weekday - 1;
    final kisaGun = DateFormat.E(dil);
    final ayBasligi = DateFormat.yMMMM(dil).format(_ay);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('vardiya-takvim-onceki'),
              icon: const Icon(Icons.chevron_left),
              tooltip: l10n.vardiyaOncekiAy,
              onPressed: () =>
                  setState(() => _ay = DateTime(_ay.year, _ay.month - 1)),
            ),
            Expanded(
              child: Text(
                ayBasligi,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              key: const Key('vardiya-takvim-sonraki'),
              icon: const Icon(Icons.chevron_right),
              tooltip: l10n.vardiyaSonrakiAy,
              onPressed: () =>
                  setState(() => _ay = DateTime(_ay.year, _ay.month + 1)),
            ),
          ],
        ),
        // HAFTA GUNU BASLIKLARI AYNI ZAMANDA KALIP DUGMESIDIR: basliga
        // dokunmak o gunun ay icindeki TUM tekrarlarini secer. Ayri bir
        // dugme siraSI eklemek dar ekranda ikinci bir tasma kaynagi
        // olurdu (P229 §1'de olculen kusurun aynisi).
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  label: l10n.vardiyaTumGunleriSec(
                      kisaGun.format(DateTime(2024, 1, 1 + i))),
                  child: InkWell(
                    key: Key('vardiya-takvim-haftagunu-${i + 1}'),
                    onTap: () => _haftaGunu(i + 1),
                    child: SizedBox(
                      height: kMinInteractiveDimension,
                      child: Center(
                        child: Text(
                          // 2024-01-01 PAZARTESIDIR: haftanin ilk gunu
                          // sabit bir tarihe cengellenmezse `DateFormat`
                          // bugune gore kayar.
                          kisaGun.format(DateTime(2024, 1, 1 + i)),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: renk.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (var satir = 0; satir < ((bosluk + sonGun + 6) ~/ 7); satir++)
          Row(
            children: [
              for (var sutun = 0; sutun < 7; sutun++)
                Expanded(
                  child: Builder(builder: (context) {
                    final gunNo = satir * 7 + sutun - bosluk + 1;
                    if (gunNo < 1 || gunNo > sonGun) {
                      return const SizedBox(height: kMinInteractiveDimension);
                    }
                    final d = DateTime(_ay.year, _ay.month, gunNo);
                    final a = gunAnahtari(d);
                    final seciliMi = widget.secili.contains(a);
                    final kapaliMi = _kapali(d);
                    return Semantics(
                      selected: seciliMi,
                      button: true,
                      child: InkWell(
                        key: Key('vardiya-takvim-gun-$a'),
                        onTap: kapaliMi ? null : () => _tekil(d),
                        onLongPress: kapaliMi ? null : () => _araliga(d),
                        child: Container(
                          height: kMinInteractiveDimension,
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: seciliMi ? renk.primary : null,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '$gunNo',
                              style: TextStyle(
                                color: kapaliMi
                                    ? renk.onSurface.withValues(alpha: 0.3)
                                    : seciliMi
                                        ? renk.onPrimary
                                        : renk.onSurface,
                                fontWeight: seciliMi ? FontWeight.w700 : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
            ],
          ),
      ],
    );
  }
}
