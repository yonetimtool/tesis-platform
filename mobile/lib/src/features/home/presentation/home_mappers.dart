/// GERCEK API verisi → ana ekran gorunum modelleri. SAF fonksiyonlar
/// (widget/provider yok) — mock taban ile gercek veri arasindaki TEK kopru.
///
/// Kural: bir bolumun gercek verisi VARSA burada donusturulur ve mock tabani
/// EZER; yoksa ekran mock tabanini kullanir (bkz. [HomeRepository]).
library;

import 'package:flutter/material.dart';

import '../../announcements/domain/announcement_models.dart';
import '../../budget/domain/budget_models.dart';
import '../../etkinlik/domain/etkinlik_models.dart';
import '../../site_kurali/domain/site_kurali_models.dart';
import '../../dues/domain/dues_models.dart';
import '../../shifts/domain/shift_models.dart';
import '../../weather/domain/weather_models.dart';
import '../../../core/theme/home_tokens.dart';
import '../domain/activity_models.dart';
import '../domain/home_view_models.dart';

/// GET /weather → baslik hava blogu.
HomeHava havaOzeti(Weather w) => HomeHava(
      sicaklik: w.tempLabel,
      sehir: w.konumAd,
      ikon: weatherIcon(w.durum),
    );

/// GET /shifts → vardiya serisi kartlari. [now] disaridan → AKTİF/PLANLANDI
/// hesabi deterministik. [yoneticiAd] verilirse referans gorseldeki gibi
/// serinin SONUNA "Yönetici" karti eklenir.
List<VardiyaKart> vardiyaKartlari({
  required List<Shift> vardiyalar,
  required DateTime now,
  String? yoneticiAd,
  String? yoneticiAvatarUrl,
}) {
  // Vardiya YOKSA bolum hic cizilmez — yalniz "Yönetici" karti tasiyan bir
  // serit referansta yoktur ve "vardiya durumu" bilgisi vermez.
  if (vardiyalar.isEmpty) return const [];
  return [
      for (final v in vardiyalar)
        VardiyaKart(
          baslik: v.ad,
          altBaslik: '${v.baslangicSaat} - ${v.bitisSaat}',
          durum:
              v.aktifMi(now) ? VardiyaDurum.aktif : VardiyaDurum.planlandi,
          // Atanan personel varsa ilkinin avatari + "N Görevli"; yoksa gun
          // tipi etiketi (vardiya tanimi personelsiz de yayinlanabilir).
          avatarUrl:
              v.personel.isNotEmpty ? v.personel.first.avatarUrl : null,
          altBilgi: v.personel.isNotEmpty
              ? '${v.personel.length} Görevli'
              : gunTipiLabel(v.gunTipi),
        ),
      if (yoneticiAd != null && yoneticiAd.isNotEmpty)
        VardiyaKart(
          baslik: 'Yönetici',
          altBaslik: yoneticiAd,
          durum: VardiyaDurum.yonetici,
          altBilgi: 'Online',
          online: true,
          avatarUrl: yoneticiAvatarUrl,
        ),
  ];
}

/// `GET /activity` sayfasi → "Son Hareketler" satirlari.
///
/// Metinler SUNUCUDAN gelir (baslik / alt_metin); istemci yalnizca ikon,
/// modul rengi ve zaman etiketini ekler. Ikon MODULUN rengini, nokta OLAYIN
/// durum rengini (`renk_ipucu`) tasir (referans gorseller).
List<HareketSatiri> hareketSatirlari(
  List<ActivityItem> olaylar,
  DateTime now,
) =>
    [
      for (final o in olaylar)
        HareketSatiri(
          ikon: _ikon(o.tur),
          baslik: o.baslik,
          altBaslik: o.altMetin ?? '',
          zaman: hareketZamanEtiketi(o.zaman, now),
          ikonAccent: _ikonAccent(o.tur),
          noktaRengi: _nokta(o.renk),
        ),
    ];

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

/// GET /site-rules → sakin ana ekraninin "Site Kuralları" bolumu.
/// Gorsel varsa presigned `foto_url` kullanilir; yoksa yer tutucu.
List<IcerikOzeti> kuralOzetleri(List<SiteKurali> kurallar) => [
      for (final k in kurallar)
        IcerikOzeti(
          id: k.id,
          baslik: k.baslik,
          altMetin: k.icerik,
          ikon: Icons.menu_book_outlined,
          fotoUrl: k.fotoUrl,
        ),
    ];

/// GET /events?aktif=true → "Etkinlikler" bolumu (yaklasan/suren).
/// Cip: suren etkinlikte "Sürüyor" (yesil), yaklasanda "Yaklaşan" (mavi).
List<IcerikOzeti> etkinlikOzetleri(List<Etkinlik> etkinlikler) => [
      for (final e in etkinlikler)
        IcerikOzeti(
          id: e.id,
          baslik: e.baslik,
          altMetin: e.konum == null || e.konum!.isEmpty
              ? e.aciklama
              : '${e.konum} · ${e.aciklama}',
          ikon: Icons.event_available_outlined,
          fotoUrl: e.fotoUrl,
          tarih: _tarihSaat(e.tarih.toLocal()),
          cip: e.suruyor ? 'Sürüyor' : 'Yaklaşan',
          cipAccent: e.suruyor ? HomeTokens.green : HomeTokens.primary,
        ),
    ];

/// En yeni duyuru → duyuru karti. 3 gunden yeni ise "Yeni" cipi.
DuyuruOzeti duyuruOzeti(Announcement d, DateTime now) => DuyuruOzeti(
      baslik: d.baslik,
      govde: d.govde,
      tarih: '${d.createdAt.day.toString().padLeft(2, '0')}.'
          '${d.createdAt.month.toString().padLeft(2, '0')}.'
          '${d.createdAt.year} – '
          '${d.createdAt.hour.toString().padLeft(2, '0')}:'
          '${d.createdAt.minute.toString().padLeft(2, '0')}',
      yeni: now.difference(d.createdAt) <= const Duration(days: 3),
      fotoUrl: d.fotoUrl,
    );

/// GET /me/dues → "Ödeme ve Aidat Durumu". Daire yoksa null (kart cizilmez,
/// mock taban kullanilir).
///
/// "Bu ayki aidat" en son tahakkuk, "gelecek ödeme" ondan sonraki son-odeme
/// tarihidir; borc yoksa "Ödendi" cipi yanar. Tutar bicimlendirmesi
/// [formatKurusAsTl] ile sunucu kurusundan turer.
OdemeOzeti? odemeOzeti(List<MyDuesUnit> units) {
  if (units.isEmpty) return null;

  final tahakkuklar = [for (final u in units) ...u.assessments]
    ..sort((a, b) => b.donem.compareTo(a.donem));
  final odemeler = [
    for (final u in units)
      for (final p in u.payments)
        if (p.durum == 'basarili') p,
  ]..sort((a, b) => b.odemeZamani.compareTo(a.odemeZamani));

  if (tahakkuklar.isEmpty) return null;
  final sonTahakkuk = tahakkuklar.first;
  final borc = units.fold<int>(
      0, (t, u) => t + (u.bakiyeKurus > 0 ? u.bakiyeKurus : 0));

  return OdemeOzeti(
    buAyTutar: '₺${formatKurusAsTl(sonTahakkuk.tutarKurus)}',
    odendi: borc == 0,
    sonOdeme: odemeler.isEmpty ? '—' : _tarih(odemeler.first.odemeZamani),
    gelecekTarih: sonTahakkuk.sonOdemeTarihi == null
        ? '—'
        : _tarih(sonTahakkuk.sonOdemeTarihi!),
    gelecekTutar: '₺${formatKurusAsTl(sonTahakkuk.tutarKurus)}',
  );
}

String _tarih(DateTime t) => '${t.day.toString().padLeft(2, '0')}.'
    '${t.month.toString().padLeft(2, '0')}.${t.year}';

/// "28.07.2026 · 12:51" — etkinlik satirinin tarih/saat etiketi.
String _tarihSaat(DateTime t) => '${_tarih(t)} · '
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

/// Olay turu → modul ikonu. Taninmayan tur (sunucu yeni tur eklerse) NOTR
/// zil ikonu alir — satir akistan DUSMEZ.
IconData _ikon(ActivityTur tur) => switch (tur) {
      ActivityTur.kargo ||
      ActivityTur.kargoTeslim =>
        Icons.inventory_2_outlined,
      ActivityTur.ziyaretciGiris ||
      ActivityTur.ziyaretciCikis =>
        Icons.person_outline,
      ActivityTur.aidatOdeme => Icons.account_balance_wallet,
      ActivityTur.talep => Icons.mode_comment_outlined,
      ActivityTur.daireSikayeti => Icons.description_outlined,
      ActivityTur.gorevTamamlama => Icons.assignment_turned_in_outlined,
      ActivityTur.devriyeOkutma => Icons.directions_walk,
      ActivityTur.aracGiris || ActivityTur.aracCikis => Icons.directions_car,
      ActivityTur.ihlal => Icons.error_outline,
      ActivityTur.alarm => Icons.error_outline,
      ActivityTur.bilinmeyen => Icons.notifications_outlined,
    };

/// Ikon rengi = modulun rengi (kargo yesil, ziyaretci mor, aidat mavi...) —
/// hizli erisim kartlarindaki accent'lerle ayni kume.
Color _ikonAccent(ActivityTur tur) => switch (tur) {
      ActivityTur.kargo => HomeTokens.orange,
      ActivityTur.kargoTeslim => HomeTokens.green,
      ActivityTur.ziyaretciGiris ||
      ActivityTur.ziyaretciCikis =>
        HomeTokens.purple,
      ActivityTur.aidatOdeme => HomeTokens.primary,
      ActivityTur.talep => HomeTokens.purple,
      ActivityTur.daireSikayeti => HomeTokens.purple,
      ActivityTur.gorevTamamlama => HomeTokens.green,
      ActivityTur.devriyeOkutma => HomeTokens.primary,
      ActivityTur.aracGiris || ActivityTur.aracCikis => HomeTokens.purple,
      ActivityTur.ihlal => HomeTokens.red,
      ActivityTur.alarm => HomeTokens.red,
      ActivityTur.bilinmeyen => HomeTokens.primary,
    };

/// Nokta rengi = olayin DURUMU — sunucunun `renk_ipucu` alani (olumlu yesil,
/// uyari turuncu, alarm kirmizi, notr mavi). Istemci durum TAHMIN ETMEZ.
Color _nokta(ActivityRenk renk) => switch (renk) {
      ActivityRenk.olumlu => HomeTokens.green,
      ActivityRenk.uyari => HomeTokens.orange,
      ActivityRenk.alarm => HomeTokens.red,
      ActivityRenk.notr => HomeTokens.primary,
    };
