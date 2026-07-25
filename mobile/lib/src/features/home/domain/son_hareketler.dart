/// "Son Hareketler" birlesik akisi — SAF fonksiyonlar (widget/provider yok).
///
/// SOZLESME BOSLUGU: backend'de BIRLESIK bir aktivite/olay akisi ucu YOKTUR
/// (README "CONTRACT GAPS" → `GET /activity`). Akis bu yuzden, her rolun
/// ZATEN erisebildigi uclardan ISTEMCIDE birlestirilir:
///
///   * sakin    → /kargo + /visitors + /me/dues(payments) + /complaints
///   * yonetim  → /notifications + /complaints + /dues/payments +
///                /task-completions
///   * saha     → /visitors + /kargo + /task-completions + /notifications
///                (tesis_gorevlisi: yalniz /task-completions — digerleri
///                 KVKK/RBAC geregi kapali)
///
/// KVKK: her uc kendi rol suzgecini SUNUCUDA uygular; istemci yalniz
/// birlestirir — baska daire/kisi verisi sizmaz.
library;

import '../../budget/domain/budget_models.dart' show formatKurusAsTl;
import '../../complaints/domain/complaint_models.dart';
import '../../dues/domain/dues_models.dart';
import '../../kargo/domain/kargo_models.dart';
import '../../notifications/domain/notification_models.dart';
import '../../reports/domain/report_models.dart' show SonTamamlama;
import '../../visitors/domain/visitor_models.dart';

/// Akistaki tek satirin turu — ikon/renk eslemesi sunumda. Sakin tipleri +
/// yonetim (bildirim-tabanli) tipleri: alarm (kirmizi), uyari (amber),
/// bilgi (notr).
enum HareketTip {
  kargoKayit,
  kargoTeslim,
  ziyaretci,
  aidatOdeme,
  talep,
  gorevTamamlama,
  alarm,
  uyari,
  bilgi,
}

/// Birlesik akisin tek satiri.
class Hareket {
  const Hareket({
    required this.tip,
    required this.baslik,
    required this.altBaslik,
    required this.zaman,
  });

  final HareketTip tip;
  final String baslik;
  final String altBaslik;
  final DateTime zaman;
}

/// Satir zaman etiketi — [now] DISARIDAN (deterministik test; saat-flake yok).
/// Ayni gun "HH:mm", dun "Dün", daha eski "dd.MM".
String hareketZamanEtiketi(DateTime t, DateTime now) {
  bool ayniGun(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  if (ayniGun(t, now)) {
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }
  if (ayniGun(t, now.subtract(const Duration(days: 1)))) return 'Dün';
  return '${t.day.toString().padLeft(2, '0')}.'
      '${t.month.toString().padLeft(2, '0')}';
}

/// Sakin akisi: kaynaklari Hareket'e esler, zamana gore DESC siralar, en
/// yeni [limit] taneyi doner. Kargo teslimlerinde teslim zamani esastir;
/// yalniz 'basarili' aidat odemeleri akisa girer.
List<Hareket> residentHareketleri({
  required List<Kargo> kargolar,
  required List<Visitor> ziyaretciler,
  required List<MyDuesUnit> duesUnits,
  List<Complaint> talepler = const [],
  int limit = 5,
}) {
  final hareketler = <Hareket>[
    for (final k in kargolar)
      if (k.durum == KargoDurum.teslimAlindi)
        Hareket(
          tip: HareketTip.kargoTeslim,
          baslik: 'Kargo Teslim Edildi',
          altBaslik: '${k.firma}${k.unitNo != null ? ' - Daire ${k.unitNo}' : ''}',
          zaman: k.teslimZamani ?? k.createdAt,
        )
      else
        Hareket(
          tip: HareketTip.kargoKayit,
          baslik: 'Kargo Kaydedildi',
          altBaslik: '${k.firma}${k.unitNo != null ? ' - Daire ${k.unitNo}' : ''}',
          zaman: k.createdAt,
        ),
    for (final z in ziyaretciler)
      Hareket(
        tip: HareketTip.ziyaretci,
        baslik: 'Ziyaretçi Girişi',
        altBaslik:
            '${z.ziyaretciAd}${z.unitNo != null ? ' - Daire ${z.unitNo}' : ''}',
        zaman: z.createdAt,
      ),
    for (final u in duesUnits)
      for (final p in u.payments)
        if (p.durum == 'basarili')
          Hareket(
            tip: HareketTip.aidatOdeme,
            baslik: 'Aidat Ödemesi',
            altBaslik:
                '₺${formatKurusAsTl(p.tutarKurus)}${p.donem != null ? ' - ${p.donem}' : ''}',
            zaman: p.odemeZamani,
          ),
    ...talepler.map(_talepHareketi),
  ]..sort((a, b) => b.zaman.compareTo(a.zaman));

  return hareketler.take(limit).toList();
}

/// Yonetim akisi: bildirim (kacirilan tur vb.) + talep + aidat odemesi +
/// gorev tamamlama tek listede. Kaynaklarin biri bos/erisilemez ise akis
/// kalanlarla cizilir (cagiran katman 403/hatayi bos liste olarak gecirir).
/// createdAt NULL bildirim akisa GIRMEZ (siralanamaz). DESC, en yeni [limit].
List<Hareket> yonetimHareketleri({
  List<AppNotification> bildirimler = const [],
  List<Complaint> talepler = const [],
  List<DuesPayment> odemeler = const [],
  List<SonTamamlama> tamamlamalar = const [],
  int limit = 5,
}) {
  final hareketler = <Hareket>[
    ...bildirimler.map(_bildirimHareketi).nonNulls,
    ...talepler.map(_talepHareketi),
    for (final p in odemeler)
      if (p.durum == 'basarili')
        Hareket(
          tip: HareketTip.aidatOdeme,
          baslik: 'Aidat Ödemesi',
          altBaslik: '₺${formatKurusAsTl(p.tutarKurus)}'
              '${p.donem != null ? ' - ${p.donem}' : ''}',
          zaman: p.odemeZamani,
        ),
    ...tamamlamalar.map(_tamamlamaHareketi),
  ]..sort((a, b) => b.zaman.compareTo(a.zaman));

  return hareketler.take(limit).toList();
}

/// Saha akisi (gorevli ana ekrani). tesis_gorevlisi ziyaretci/kargo/bildirim
/// UCLARINA ERISEMEZ (KVKK/RBAC) — o rolde cagiran katman o listeleri BOS
/// gecer ve akis yalniz gorev tamamlamalarindan olusur.
List<Hareket> sahaHareketleri({
  List<Visitor> ziyaretciler = const [],
  List<Kargo> kargolar = const [],
  List<SonTamamlama> tamamlamalar = const [],
  List<AppNotification> bildirimler = const [],
  int limit = 5,
}) {
  final hareketler = <Hareket>[
    for (final z in ziyaretciler)
      Hareket(
        tip: HareketTip.ziyaretci,
        baslik: 'Ziyaretçi Girişi',
        altBaslik:
            '${z.ziyaretciAd}${z.unitNo != null ? ' - Daire ${z.unitNo}' : ''}',
        zaman: z.createdAt,
      ),
    for (final k in kargolar)
      if (k.durum == KargoDurum.teslimAlindi)
        Hareket(
          tip: HareketTip.kargoTeslim,
          baslik: 'Kargo Teslim Edildi',
          altBaslik:
              '${k.firma}${k.unitNo != null ? ' - Daire ${k.unitNo}' : ''}',
          zaman: k.teslimZamani ?? k.createdAt,
        )
      else
        Hareket(
          tip: HareketTip.kargoKayit,
          baslik: 'Kargo Kaydedildi',
          altBaslik:
              '${k.firma}${k.unitNo != null ? ' - Daire ${k.unitNo}' : ''}',
          zaman: k.createdAt,
        ),
    ...tamamlamalar.map(_tamamlamaHareketi),
    ...bildirimler.map(_bildirimHareketi).nonNulls,
  ]..sort((a, b) => b.zaman.compareTo(a.zaman));

  return hareketler.take(limit).toList();
}

/// GET /complaints ogesi → akis satiri. Baslik DURUMDAN turer (talep acildi /
/// is emri / cozuldu), alt baslik talebin kendi basligidir.
Hareket _talepHareketi(Complaint c) => Hareket(
      tip: HareketTip.talep,
      baslik: switch (c.durum) {
        TalepDurum.acik => 'Yeni Talep',
        TalepDurum.isEmri => 'İş Emri Açıldı',
        TalepDurum.cozuldu => 'Talep Çözüldü',
        TalepDurum.reddedildi => 'Talep Reddedildi',
        TalepDurum.unknown => 'Talep',
      },
      altBaslik: c.kategoriAd == null
          ? c.baslik
          : '${c.baslik} - ${c.kategoriAd}',
      // Durum degisimi updated_at'e yansir; akis "son hareket" gosterir.
      zaman: c.updatedAt,
    );

/// GET /task-completions ogesi → akis satiri.
Hareket _tamamlamaHareketi(SonTamamlama t) => Hareket(
      tip: HareketTip.gorevTamamlama,
      baslik: 'Görev Tamamlandı',
      altBaslik: t.taskAdi == null || t.taskAdi!.isEmpty
          ? t.kategoriAd
          : '${t.taskAdi} - ${t.kategoriAd}',
      zaman: t.tamamlanmaZamani,
    );

/// GET /notifications ogesi → akis satiri. created_at YOKSA null (siralanamaz).
Hareket? _bildirimHareketi(AppNotification b) {
  final zaman = b.createdAt;
  if (zaman == null) return null;
  return Hareket(
    tip: switch (b.tip) {
      'kacirilan_tur' || 'eksik_checkpoint' => HareketTip.alarm,
      'gecikmis_okutma' => HareketTip.uyari,
      _ => HareketTip.bilgi,
    },
    baslik: switch (b.tip) {
      'kacirilan_tur' => 'Kaçırılan Tur',
      'eksik_checkpoint' => 'Eksik Nokta',
      'gecikmis_okutma' => 'Gecikmiş Okutma',
      _ => 'Bildirim',
    },
    altBaslik: b.mesaj,
    zaman: zaman,
  );
}
