/// `/activity` satirlarinin METNI — kimlikten cizim aninda uretilir (tur 15).
///
/// ONCESI: baslik ve alt metin SUNUCUDAN Turkce geliyordu (13 SQL kaynagi);
/// Arapca arayuzde bile "Kargo Teslim Edildi" yaziyordu. Sunucu artik
/// `baslik_kimlik` (kimlik) + `veri` (degisken alanlar) gonderiyor.
///
/// KURALLAR (README §15):
///   * `switch`lerde **`default` YOK** — sunucu yeni bir kimlik eklerse
///     derleyici ceviriyi zorlar. Tek istisna [AkisBaslik.bilinmeyen]: eski
///     istemcinin cokmemesi icin sozlesmede birakilan deprecated sunucu
///     metnine duser.
///   * PARA istemcide bicimlenir (`tlIsaretli`) — sunucu "₺1.234,50" uretmez;
///     kurus tam sayi gelir, gruplama/izolasyon karari para politikasindadir.
///   * SAAT istemcide bicimlenir (`saatBicimi`) — 24s/12s karari dile baglidir.
///   * `veri` alanlari OPSIYONELDIR; yoklugu bicimi degistirir (orn. plakaya
///     daire eklenmez). Eskiden bu karar SQL'de `COALESCE` ile veriliyordu.
library;

import '../../../core/i18n/l10n.dart';
import '../../unit_complaints/domain/unit_complaint_models.dart';
import '../../unit_complaints/presentation/kategori_adi.dart';
import '../domain/activity_models.dart';

/// Satir basligi — kimlikten aktif dilde.
String akisBaslikMetni(AppLocalizations l10n, ActivityItem olay) =>
    switch (olay.baslikKimlik) {
      AkisBaslik.devriyeOkutma => l10n.akisDevriyeOkutma,
      AkisBaslik.gorevTamamlama => l10n.akisGorevTamamlandi,
      AkisBaslik.aidatOdeme => l10n.akisAidatOdemesi,
      AkisBaslik.talepAcik => l10n.akisTalepAcildi,
      AkisBaslik.talepIsEmri => l10n.akisTalepIsEmri,
      AkisBaslik.talepCozuldu => l10n.akisTalepCozuldu,
      AkisBaslik.talepReddedildi => l10n.akisTalepReddedildi,
      AkisBaslik.daireSikayeti => l10n.akisDaireSikayeti,
      AkisBaslik.alarmKacirilanTur => l10n.akisAlarmKacirilanTur,
      AkisBaslik.alarmEksikCheckpoint => l10n.akisAlarmEksikCheckpoint,
      AkisBaslik.alarmGecikmisOkutma => l10n.akisAlarmGecikmisOkutma,
      AkisBaslik.ziyaretciGiris => l10n.akisZiyaretciGirisi,
      AkisBaslik.ziyaretciCikis => l10n.akisZiyaretciCikisi,
      AkisBaslik.kargo => l10n.akisKargoKaydedildi,
      AkisBaslik.kargoTeslim => l10n.akisKargoTeslimEdildi,
      AkisBaslik.aracGiris => l10n.akisAracGirisi,
      AkisBaslik.aracCikis => l10n.akisAracCikisi,
      AkisBaslik.ihlal => l10n.akisIhlalKaydi,
      // Sozlesmede olmayan yeni kimlik: sunucunun deprecated metni.
      AkisBaslik.bilinmeyen => olay.sunucuBaslik,
    };

String? _metin(Map<String, dynamic> veri, String alan) {
  final deger = veri[alan];
  if (deger == null) return null;
  final s = deger.toString();
  return s.isEmpty ? null : s;
}

/// Satir alt metni — `veri`den aktif dilde kurulur. Veri yoksa `null`
/// (satir yalniz baslikla cizilir; UYDURMA metin yok).
String? akisAltMetni(AppLocalizations l10n, String dil, ActivityItem olay) {
  final v = olay.veri;
  if (v.isEmpty) return olay.sunucuAltMetin;

  switch (olay.tur) {
    case ActivityTur.devriyeOkutma:
    case ActivityTur.gorevTamamlama:
      // Kontrol noktasi / gorev ADI: kullanicinin girdigi VERI, cevrilmez.
      return _metin(v, 'ad');

    case ActivityTur.aidatOdeme:
      final daire = _metin(v, 'daire');
      final kurus = v['tutar_kurus'];
      if (daire == null || kurus is! num) return _metin(v, 'daire');
      // Para POLITIKASI: TL + Turkce gruplama; Arapcada LTR izolasyonu.
      return l10n.akisAltDaireTutar(daire, tlIsaretli(kurus.toInt(), dil));

    case ActivityTur.talep:
      return _metin(v, 'baslik');

    case ActivityTur.daireSikayeti:
      final daire = _metin(v, 'daire');
      // `kategori` SOZLESME KIMLIGIDIR — gorunen ad istemcide cozulur.
      final kategori = unitComplaintKategoriAdi(
        l10n,
        UnitComplaintKategori.fromWire(_metin(v, 'kategori')),
      );
      return daire == null ? kategori : l10n.akisAltDaireKategori(daire, kategori);

    case ActivityTur.alarm:
      final plan = _metin(v, 'plan');
      final aralik = _aralik(v, dil);
      if (plan != null && aralik != null) return l10n.akisAltPlanAralik(plan, aralik);
      return plan ?? aralik;

    case ActivityTur.ziyaretciGiris:
    case ActivityTur.ziyaretciCikis:
      return _adDaire(l10n, _metin(v, 'ad'), _metin(v, 'daire'));

    case ActivityTur.kargo:
    case ActivityTur.kargoTeslim:
      return _adDaire(l10n, _metin(v, 'firma'), _metin(v, 'daire'));

    case ActivityTur.aracGiris:
    case ActivityTur.aracCikis:
      return _arac(l10n, v);

    case ActivityTur.ihlal:
      final baslik = _metin(v, 'baslik');
      final konum = _metin(v, 'konum');
      if (baslik == null) return konum;
      return konum == null ? baslik : l10n.akisAltMetinKonum(baslik, konum);

    case ActivityTur.bilinmeyen:
      return olay.sunucuAltMetin;
  }
}

String? _adDaire(AppLocalizations l10n, String? ad, String? daire) {
  if (ad == null) return daire == null ? null : l10n.gorevDaireEtiket(daire);
  if (daire == null) return ad;
  return l10n.akisAltAdDaire(ad, daire);
}

String? _arac(AppLocalizations l10n, Map<String, dynamic> v) {
  final plaka = _metin(v, 'plaka');
  if (plaka == null) return null;
  final daire = _metin(v, 'daire');
  final tanim = _metin(v, 'tanim');
  // Dort bicim: plaka / plaka+daire / plaka+tanim / plaka+daire+tanim.
  // Bicimi ALANIN VARLIGI secer (SQL COALESCE'unun karsiligi).
  if (daire != null && tanim != null) {
    return l10n.akisAltPlakaDaireTanim(plaka, daire, tanim);
  }
  if (daire != null) return l10n.akisAltPlakaDaire(plaka, daire);
  if (tanim != null) return l10n.akisAltPlakaTanim(plaka, tanim);
  return plaka;
}

String? _aralik(Map<String, dynamic> v, String dil) {
  final bas = DateTime.tryParse(_metin(v, 'baslangic') ?? '');
  final bit = DateTime.tryParse(_metin(v, 'bitis') ?? '');
  if (bas == null || bit == null) return null;
  // Sunucu UTC gonderir; kullanici YEREL saatini bekler.
  return '${saatBicimi(bas.toLocal(), dil)}–${saatBicimi(bit.toLocal(), dil)}';
}
