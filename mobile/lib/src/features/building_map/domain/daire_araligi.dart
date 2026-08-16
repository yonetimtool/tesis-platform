/// (P164) DAIRE NUMARASI ARALIK IFADESI — "3,5,7-12".
///
/// =========================================================================
/// WEB'DEKI `lib/aralik.ts` ILE AYNI KURAL
/// =========================================================================
/// Bu dosya webdeki ayristiricinin BIREBIR karsiligidir. Iki yuzeyin ayni
/// ifadeye ayni cevabi vermesi sarttir: kullanici webde "7-12" yazip 6
/// daire seciyorsa, mobilde de 6 daire secmeli. Ayrisirlarsa toplu islem
/// YANLIS DAIRELERE uygulanir ve bu geri alinmasi zor bir hatadir.
///
/// `test/daire_araligi_test.dart` webdeki `aralik.test.ts` ile AYNI
/// senaryolari kosar.
///
/// =========================================================================
/// NEDEN YALNIZ SAYISAL KUYRUK
/// =========================================================================
/// Daire numaralari onek tasir (`A-1`, `B-12`). Kullaniciya "A-7 - A-12"
/// yazdirmak is cikarmakti; kullanici "7-12" yazar, onek EKRANDAKI
/// LISTEDEN gelir.
///
/// =========================================================================
/// NEDEN ISTEMCIDE, SUNUCUDA DEGIL
/// =========================================================================
/// Ifade kullanicinin EKRANDA GORDUGU listeye gore anlam kazanir — blok
/// suzgeci acikken "7-12" baska daireleri gosterir. Sunucuda cozmek,
/// istemcinin gordugu kume ile sunucunun anladigi kumenin AYRISMASI
/// demekti. Sunucuya KESINLESMIS kimlikler gider.
library;

/// Aralik cozumleme sonucu.
class AralikSonucu {
  const AralikSonucu({
    required this.idler,
    required this.bulunamayan,
    required this.gecersiz,
  });

  /// Ifadeye uyan satirlarin kimlikleri (ekrandaki sirayla).
  final List<String> idler;

  /// Ifadede gecen ama listede KARSILIGI OLMAYAN parcalar.
  ///
  /// SESSIZCE DUSMEZ: cagiran bunu kullaniciya gosterir — "12 daire
  /// sectim" deyip 9'unu islemek en kotu sonuctur.
  final List<String> bulunamayan;

  /// Ifade hic ayristirilamadiysa (bos ya da tumuyle gecersiz).
  final bool gecersiz;
}

/// Aralik cozumune giren tek satir.
class AralikSatiri {
  const AralikSatiri({required this.id, required this.no});

  final String id;
  final String no;
}

/// `A-7` -> 7 · `12` -> 12 · `zemin` -> null (sayisal kuyruk yok).
int? sayisalKuyruk(String no) {
  final m = RegExp(r'(\d+)\s*$').firstMatch(no.trim());
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// Ifadeyi ekrandaki satirlara uygular.
AralikSonucu aralikCoz(String ifade, List<AralikSatiri> satirlar) {
  final parcalar = ifade
      .split(',')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (parcalar.isEmpty) {
    return const AralikSonucu(idler: [], bulunamayan: [], gecersiz: true);
  }

  // Ekrandaki numaralarin sayisal kuyruklari. AYNI KUYRUK BIRDEN FAZLA
  // SATIRA denk gelebilir (A-7 ve B-7): ikisi de secilir, cunku kullanici
  // suzgeci daraltmadiysa ikisini de goruyordur.
  final kuyruklar = [
    for (final s in satirlar) (id: s.id, n: sayisalKuyruk(s.no)),
  ];

  final secilen = <String>[];
  final bulunamayan = <String>[];
  final aralikKalibi = RegExp(r'^(\d+)\s*-\s*(\d+)$');

  for (final p in parcalar) {
    final m = aralikKalibi.firstMatch(p);
    if (m != null) {
      final bas = int.parse(m.group(1)!);
      final son = int.parse(m.group(2)!);
      // TERS ARALIK DA CALISIR ("12-7"): kullanicinin niyeti belli ve
      // "gecersiz" demek, duzeltilecek bir sey olmayan bir hata olurdu.
      final alt = bas <= son ? bas : son;
      final ust = bas <= son ? son : bas;
      final eslesen = kuyruklar.where(
        (k) => k.n != null && k.n! >= alt && k.n! <= ust,
      );
      if (eslesen.isEmpty) {
        bulunamayan.add(p);
      } else {
        secilen.addAll(eslesen.map((k) => k.id));
      }
      continue;
    }

    // TEK DEGER — SIRA WEBDEKININ AYNISI: once SAYI olarak, sonra TAM
    // NUMARA olarak. Sirayi ters cevirmek iki yuzeyi ayirirdi: "7" yazan
    // kullanici webde hem `7` hem `A-7` secerken mobilde yalniz `7`
    // secmis olurdu.
    //
    // BUYUK/KUCUK HARF: web `toLocaleLowerCase("tr")` kullaniyor. Daire
    // numarasi kalibi `^[A-Za-z0-9-]+$` oldugu icin Turkce'ye ozgu I/i
    // ayrimi bu alanda OLUSAMAZ; sade `toLowerCase` ayni sonucu verir.
    final sayiMi = RegExp(r'^\d+$').hasMatch(p);
    final n = sayiMi ? int.parse(p) : null;
    final eslesen = <String>[
      if (n != null)
        for (var i = 0; i < kuyruklar.length; i++)
          if (kuyruklar[i].n == n) kuyruklar[i].id,
      if (n == null)
        for (final s in satirlar)
          if (s.no.toLowerCase() == p.toLowerCase()) s.id,
    ];
    if (eslesen.isEmpty) bulunamayan.add(p);
    secilen.addAll(eslesen);
  }

  // TEKRARLAR ATILIR ama SIRA KORUNUR: "5,3-7" yazan kullanici 5'i iki
  // kez secmis olmaz. Webdeki `[...new Set(secilen)]` ile ayni davranis.
  final gorulen = <String>{};
  final idler = [
    for (final id in secilen)
      if (gorulen.add(id)) id,
  ];

  return AralikSonucu(
    idler: idler,
    bulunamayan: bulunamayan,
    // WEBDEKI KOSULUN AYNISI: hicbir sey secilmedi VE her parca
    // bulunamadi. "Bos ifade" durumu yukarida ayrica ele alindi.
    gecersiz: secilen.isEmpty && bulunamayan.length == parcalar.length,
  );
}
