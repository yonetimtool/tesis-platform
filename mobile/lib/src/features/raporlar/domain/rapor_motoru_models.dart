/// (P253 Asama 2) RAPOR MOTORU — mobil modeller + alan sozlugu.
///
/// Web `admin-web/lib/rapor-alanlari.ts` ile AYNI gorev bolumu: sunucu
/// katalogda her raporun HANGI alanlari anlamlandirdigini soyler
/// (`alanlar`), istemci her alanin NASIL cizilecegini bilir. Rapor ya da
/// alan listesi burada TEKRARLANMAZ.
///
/// TANIMSIZ ALAN SESSIZCE ATLANMAZ: katalogdaki her alan adinin burada bir
/// karsiligi olmali — `test/p253_raporlar_denetci_test.dart` backend
/// katalogunu (`rapor_motoru.py`) tarar ve eksik alani KIRMIZI yapar.
library;

import '../../../../l10n/gen/app_localizations.dart';

/// Alanin ekranda aldigi bicim (web `AlanTuru` ile ayni adlar).
enum AlanTuru {
  tarih, metin, sayi, kurus, onay, ay, yil,
  kasa, firma, kisi, daire, tanim, tanimCoklu, personel, secim,
}

class AlanSecenegi {
  const AlanSecenegi(this.id, this.etiket);
  final String id;
  final String Function(AppLocalizations) etiket;
}

class AlanTanimi {
  const AlanTanimi(this.tur, this.etiket, {this.secenekler = const [], this.varsayilanAcik = false});
  final AlanTuru tur;
  final String Function(AppLocalizations) etiket;
  final List<AlanSecenegi> secenekler;

  /// Varsayilan `true` olan onay kutulari (KVKK anahtarlari gibi).
  final bool varsayilanAcik;
}

/// `RaporParametre` alan adi -> ekran tanimi. Anahtarlar backend alan
/// adlariyla BIREBIR ayni; govde dogrudan bu adlarla kurulur.
final Map<String, AlanTanimi> alanTanimlari = {
  'baslangic': AlanTanimi(AlanTuru.tarih, (l) => l.rprBaslangic),
  'bitis': AlanTanimi(AlanTuru.tarih, (l) => l.rprBitis),
  'tazminat_tarihi': AlanTanimi(AlanTuru.tarih, (l) => l.rprTazminatTarihi),
  'blok': AlanTanimi(AlanTuru.metin, (l) => l.rprBlok),
  'kasa_id': AlanTanimi(AlanTuru.kasa, (l) => l.rprKasa),
  'firma_id': AlanTanimi(AlanTuru.firma, (l) => l.rprFirma),
  'user_id': AlanTanimi(AlanTuru.kisi, (l) => l.rprKisi),
  'unit_id': AlanTanimi(AlanTuru.daire, (l) => l.rprDaire),
  'olusturan_user_id': AlanTanimi(AlanTuru.kisi, (l) => l.rprOlusturan),
  'gelir_gider_tanim_id': AlanTanimi(AlanTuru.tanim, (l) => l.rprTanim),
  'personel_kayit_id': AlanTanimi(AlanTuru.personel, (l) => l.rprPersonel),
  'gelir_gider_tanim_idler': AlanTanimi(AlanTuru.tanimCoklu, (l) => l.rprTanimlar),
  'bolum': AlanTanimi(AlanTuru.metin, (l) => l.rprBolum),
  'min_tutar_kurus': AlanTanimi(AlanTuru.kurus, (l) => l.rprMinTutar),
  'max_tutar_kurus': AlanTanimi(AlanTuru.kurus, (l) => l.rprMaxTutar),
  'baslangic_ay': AlanTanimi(AlanTuru.ay, (l) => l.rprBaslangicAy),
  'baslangic_yil': AlanTanimi(AlanTuru.yil, (l) => l.rprBaslangicYil),
  'bitis_ay': AlanTanimi(AlanTuru.ay, (l) => l.rprBitisAy),
  'bitis_yil': AlanTanimi(AlanTuru.yil, (l) => l.rprBitisYil),
  'ismi_goster': AlanTanimi(AlanTuru.onay, (l) => l.rprIsmiGoster, varsayilanAcik: true),
  'icradakileri_goster': AlanTanimi(AlanTuru.onay, (l) => l.rprIcradakiler, varsayilanAcik: true),
  'aciklamalari_goster': AlanTanimi(AlanTuru.onay, (l) => l.rprAciklamalar, varsayilanAcik: true),
  'evrak_bilgisi_goster': AlanTanimi(AlanTuru.onay, (l) => l.rprEvrakBilgisi, varsayilanAcik: true),
  'grup_goster': AlanTanimi(AlanTuru.onay, (l) => l.rprGrupla),
  // VARSAYILAN KAPALI: telefon/e-posta kisisel veridir (web ile ayni).
  'iletisim_goster': AlanTanimi(AlanTuru.onay, (l) => l.rprIletisimGoster),
  'imza': AlanTanimi(AlanTuru.onay, (l) => l.rprImza),
  'listeleme_tipi': AlanTanimi(AlanTuru.secim, (l) => l.rprListelemeTipi, secenekler: [
    AlanSecenegi('borclu', (l) => l.rprTipBorclu),
    AlanSecenegi('alacakli', (l) => l.rprTipAlacakli),
  ]),
  'ekstre_turu': AlanTanimi(AlanTuru.secim, (l) => l.rprEkstreTuru, secenekler: [
    AlanSecenegi('ozet', (l) => l.rprEkstreOzet),
    AlanSecenegi('detay', (l) => l.rprEkstreDetay),
  ]),
  'evrak_tipi': AlanTanimi(AlanTuru.secim, (l) => l.rprEvrakTipi, secenekler: [
    AlanSecenegi('makbuz', (l) => l.rprEvrakMakbuz),
    AlanSecenegi('fatura', (l) => l.rprEvrakFatura),
  ]),
  'calisma_sekli': AlanTanimi(AlanTuru.secim, (l) => l.rprCalismaSekli, secenekler: [
    AlanSecenegi('tahakkuk', (l) => l.rprCalismaTahakkuk),
    AlanSecenegi('nakit', (l) => l.rprCalismaNakit),
  ]),
  'siralama': AlanTanimi(AlanTuru.secim, (l) => l.rprSiralama, secenekler: [
    AlanSecenegi('unit', (l) => l.rprSiraDaire),
    AlanSecenegi('ad', (l) => l.rprSiraAd),
    AlanSecenegi('bakiye', (l) => l.rprSiraBakiye),
  ]),
};

/// Kategori -> bolum basligi. Sira SUNUCUDAN gelir (`kategoriler`).
String kategoriBasligi(AppLocalizations l, String kategori) => switch (kategori) {
      'listeler' => l.rprKatListeler,
      'ekstreler' => l.rprKatEkstreler,
      _ => l.rprKatDokumler,
    };

/// Is durumu -> etiket (web `DURUM_ETIKETI`).
String isDurumu(AppLocalizations l, String durum) => switch (durum) {
      'hazir' => l.rprIsHazir,
      'uretiliyor' => l.rprIsUretiliyor,
      'hata' => l.rprIsHata,
      _ => l.rprIsBekliyor,
    };

class RaporKatalogOgesi {
  const RaporKatalogOgesi({
    required this.kod,
    required this.baslik,
    required this.aciklama,
    required this.kategori,
    required this.alanlar,
    required this.agir,
  });

  final String kod;
  final String baslik;
  final String aciklama;
  final String kategori;
  final List<String> alanlar;

  /// Tum defteri tarayan rapor: Excel/PDF KUYRUGA gider (sunucu bilir).
  final bool agir;

  factory RaporKatalogOgesi.fromJson(Map<String, dynamic> j) => RaporKatalogOgesi(
        kod: j['kod'] as String? ?? '',
        baslik: j['baslik'] as String? ?? '',
        aciklama: j['aciklama'] as String? ?? '',
        kategori: j['kategori'] as String? ?? 'dokumler',
        alanlar: [for (final a in (j['alanlar'] as List? ?? const [])) '$a'],
        agir: j['agir'] as bool? ?? false,
      );
}

class RaporKatalog {
  const RaporKatalog({required this.items, required this.kategoriler});
  final List<RaporKatalogOgesi> items;
  final List<String> kategoriler;

  factory RaporKatalog.fromJson(Map<String, dynamic> j) => RaporKatalog(
        items: [
          for (final m in (j['items'] as List? ?? const []))
            if (m is Map) RaporKatalogOgesi.fromJson(Map<String, dynamic>.from(m)),
        ],
        kategoriler: [for (final k in (j['kategoriler'] as List? ?? const [])) '$k'],
      );
}

class RaporSutun {
  const RaporSutun(this.anahtar, this.baslik, this.tip);
  final String anahtar;
  final String baslik;
  final String tip;
}

/// "Goster" ciktisi — Excel/PDF ile AYNI satirlardan uretilir.
class RaporTablo {
  const RaporTablo({
    required this.kod,
    required this.baslik,
    required this.sutunlar,
    required this.satirlar,
    this.metin,
  });

  final String kod;
  final String baslik;
  final List<RaporSutun> sutunlar;
  final List<Map<String, dynamic>> satirlar;
  final String? metin;

  factory RaporTablo.fromJson(Map<String, dynamic> j) => RaporTablo(
        kod: j['kod'] as String? ?? '',
        baslik: j['baslik'] as String? ?? '',
        sutunlar: [
          for (final s in (j['sutunlar'] as List? ?? const []))
            if (s is Map)
              RaporSutun('${s['anahtar']}', '${s['baslik']}', s['tip'] as String? ?? 'metin'),
        ],
        satirlar: [
          for (final s in (j['satirlar'] as List? ?? const []))
            if (s is Map) Map<String, dynamic>.from(s),
        ],
        metin: j['metin'] as String?,
      );
}

/// Arka plan rapor isi (kuyruk).
class RaporIsi {
  const RaporIsi({
    required this.id,
    required this.kod,
    required this.bicim,
    required this.durum,
    required this.createdAt,
    this.dosyaAdi,
    this.hata,
  });

  final String id;
  final String kod;
  final String bicim;
  final String durum;
  final DateTime createdAt;
  final String? dosyaAdi;
  final String? hata;

  bool get hazir => durum == 'hazir';
  bool get bekliyor => durum == 'bekliyor' || durum == 'uretiliyor';

  factory RaporIsi.fromJson(Map<String, dynamic> j) => RaporIsi(
        id: j['id'] as String? ?? '',
        kod: j['kod'] as String? ?? '',
        bicim: j['bicim'] as String? ?? '',
        durum: j['durum'] as String? ?? 'bekliyor',
        dosyaAdi: j['dosya_adi'] as String?,
        hata: j['hata'] as String?,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

/// Secimli alanlarin kaynagi (kasa, firma, kisi, daire, tanim, personel).
class SecimOgesi {
  const SecimOgesi(this.id, this.ad);
  final String id;
  final String ad;
}

/// Icra dosyasi — salt okuma liste satiri.
class IcraDosyasi {
  const IcraDosyasi({
    required this.id,
    required this.dosyaNo,
    required this.durum,
    required this.acikBorcKurus,
    this.userAd,
    this.avukat,
    this.verisTarihi,
    this.aciklama,
  });

  final String id;
  final String dosyaNo;
  final String durum;
  final int acikBorcKurus;
  final String? userAd;
  final String? avukat;
  final DateTime? verisTarihi;
  final String? aciklama;

  factory IcraDosyasi.fromJson(Map<String, dynamic> j) => IcraDosyasi(
        id: j['id'] as String? ?? '',
        dosyaNo: j['dosya_no'] as String? ?? '',
        durum: j['durum'] as String? ?? '',
        acikBorcKurus: (j['acik_borc_kurus'] as num?)?.toInt() ?? 0,
        userAd: j['user_ad'] as String?,
        avukat: j['avukat'] as String?,
        verisTarihi: DateTime.tryParse(j['veris_tarihi'] as String? ?? ''),
        aciklama: j['aciklama'] as String?,
      );
}

/// Icra durumu -> etiket (sunucu `icra_durum` enum'u).
String icraDurumu(AppLocalizations l, String durum) => switch (durum) {
      'baginiz' => l.rprIcraDurumbaginiz,
      'beklemede' => l.rprIcraDurumbeklemede,
      'avukatta' => l.rprIcraDurumavukatta,
      'mahkemede' => l.rprIcraDurummahkemede,
      'kapandi' => l.rprIcraDurumkapandi,
      _ => durum,
    };

const icraDurumlari = ['baginiz', 'beklemede', 'avukatta', 'mahkemede', 'kapandi'];

/// Form durumunu `RaporParametre` govdesine cevirir (web `govdeyeCevir`).
///
/// BOS ALAN GONDERILMEZ — ama `false` GONDERILIR: `ismi_goster: false`
/// KVKK'nin kendisidir; "bos" sayilip dusurulseydi ad sutunu basilirdi.
Map<String, dynamic> govdeyeCevir(Map<String, Object?> durum) {
  final govde = <String, dynamic>{};
  for (final e in durum.entries) {
    final tanim = alanTanimlari[e.key];
    final deger = e.value;
    if (tanim == null || deger == null) continue;
    if (deger is bool) {
      govde[e.key] = deger;
      continue;
    }
    if (deger is List) {
      if (deger.isNotEmpty) govde[e.key] = deger;
      continue;
    }
    final metin = '$deger'.trim();
    if (metin.isEmpty) continue;
    switch (tanim.tur) {
      case AlanTuru.kurus:
        // TL girilir, KURUS gonderilir.
        final sayi = double.tryParse(metin.replaceAll('.', '').replaceAll(',', '.'));
        if (sayi != null) govde[e.key] = (sayi * 100).round();
      case AlanTuru.ay || AlanTuru.yil || AlanTuru.sayi:
        final sayi = int.tryParse(metin);
        if (sayi != null) govde[e.key] = sayi;
      default:
        govde[e.key] = metin;
    }
  }
  return govde;
}

/// Baslangic degeri (web `baslangicDegeri`): Ilk Tarih = YILBASI, Son
/// Tarih = BUGUN; `tazminat_tarihi` BOS (sunucu `bitis`i kullanir).
Object? baslangicDegeri(String ad, {DateTime? simdi}) {
  final tanim = alanTanimlari[ad];
  if (tanim == null) return null;
  if (tanim.tur == AlanTuru.onay) return tanim.varsayilanAcik;
  if (tanim.tur == AlanTuru.tanimCoklu) return <String>[];
  final s = simdi ?? DateTime.now();
  String gun(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  if (ad == 'baslangic') return gun(DateTime(s.year, 1, 1));
  if (ad == 'bitis') return gun(s);
  return null;
}

/// CSV hucresi — web `lib/csv.ts csvHucresi` ile AYNI kural:
///  * FORMUL ENJEKSIYONU (OWASP): `=`, `+`, `-`, `@`, sekme ya da CR ile
///    baslayan metnin basina `'` konur; SAF SAYI (`-12,50`) dokunulmaz;
///  * virgul, tirnak ya da satir sonu varsa tirnaklanir.
String csvHucre(String v) {
  var metin = v;
  if (RegExp(r'^[=+\-@\t\r]').hasMatch(metin) && !RegExp(r'^-?\d+([.,]\d+)?$').hasMatch(metin)) {
    metin = "'$metin";
  }
  final kacmali = metin.contains('"') || metin.contains(',') || RegExp(r'[\r\n]').hasMatch(metin);
  return kacmali ? '"${metin.replaceAll('"', '""')}"' : metin;
}

/// Gorev gecmisi CSV'si — web `/reports/tasks` ile AYNI sutunlar ve sira:
/// gorev, tip, tamamlayan, zaman, foto, NFC, not. Tamamlayan adi
/// [adlar]dan (yoksa kisa kimlik), zaman sunucunun ISO degeri.
String gorevGecmisiCsv(
  AppLocalizations l,
  List<Map<String, dynamic>> satirlar,
  Map<String, String> adlar,
) {
  final b = StringBuffer();
  // Satir sonu `\n` — web `csvMetni` ile ayni.
  void satir(List<String> h) => b.write('${h.map(csvHucre).join(',')}\n');
  satir([l.rprGorev, l.rprTabloTip, l.rprTabloTamamlayan, l.rprTabloZaman,
      l.rprTabloFoto, l.rprTabloNfc, l.rprNot]);
  for (final c in satirlar) {
    final uid = '${c['tamamlayan_user_id'] ?? ''}';
    satir([
      '${c['task_adi'] ?? ''}',
      '${c['kategori_ad'] ?? ''}',
      adlar[uid] ?? (uid.length > 8 ? uid.substring(0, 8) : uid),
      '${c['tamamlanma_zamani'] ?? ''}',
      c['foto_var'] == true ? l.rprVar : l.rprYok,
      c['nfc_dogrulandi'] == true ? l.rprEvet : l.rprHayir,
      '${c['notlar'] ?? ''}',
    ]);
  }
  return b.toString();
}
