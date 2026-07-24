/// GERCEK API verisi → ana ekran gorunum modelleri. SAF fonksiyonlar
/// (widget/provider yok) — mock taban ile gercek veri arasindaki TEK kopru.
///
/// Kural: bir bolumun gercek verisi VARSA burada donusturulur ve mock tabani
/// EZER; yoksa ekran mock tabanini kullanir (bkz. [HomeRepository]).
library;

import 'package:flutter/material.dart';

import '../../announcements/domain/announcement_models.dart';
import '../../budget/domain/budget_models.dart';
import '../../cameras/domain/camera_models.dart';
import '../../dues/domain/dues_models.dart';
import '../../shifts/domain/shift_models.dart';
import '../../weather/domain/weather_models.dart';
import '../../../core/theme/home_tokens.dart';
import '../domain/son_hareketler.dart';
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
}) =>
    [
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

/// Istemcide birlestirilen [Hareket] akisi → "Son Hareketler" satirlari.
/// Ikon MODULUN rengini, nokta OLAYIN durum rengini tasir (referans).
List<HareketSatiri> hareketSatirlari(List<Hareket> hareketler, DateTime now) =>
    [
      for (final h in hareketler)
        HareketSatiri(
          ikon: _ikon(h.tip),
          baslik: h.baslik,
          altBaslik: h.altBaslik,
          zaman: hareketZamanEtiketi(h.zaman, now),
          ikonAccent: _ikonAccent(h.tip),
          noktaRengi: _nokta(h.tip),
        ),
    ];

/// GET /cameras → canli kamera seridi.
List<KameraOzeti> kameraOzetleri(List<Camera> kameralar) => [
      for (final k in kameralar)
        KameraOzeti(ad: k.ad, streamUrl: k.streamUrl),
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

IconData _ikon(HareketTip tip) => switch (tip) {
      HareketTip.kargoKayit ||
      HareketTip.kargoTeslim =>
        Icons.inventory_2_outlined,
      HareketTip.ziyaretci => Icons.person_outline,
      HareketTip.aidatOdeme => Icons.account_balance_wallet,
      HareketTip.alarm => Icons.error_outline,
      HareketTip.uyari => Icons.schedule_outlined,
      HareketTip.bilgi => Icons.notifications_outlined,
    };

/// Ikon rengi = modulun rengi (kargo yesil, ziyaretci mor, aidat mavi...).
Color _ikonAccent(HareketTip tip) => switch (tip) {
      HareketTip.kargoKayit => HomeTokens.orange,
      HareketTip.kargoTeslim => HomeTokens.green,
      HareketTip.ziyaretci => HomeTokens.purple,
      HareketTip.aidatOdeme => HomeTokens.primary,
      HareketTip.alarm => HomeTokens.red,
      HareketTip.uyari => HomeTokens.orange,
      HareketTip.bilgi => HomeTokens.primary,
    };

/// Nokta rengi = olayin durumu (tamamlanan yesil, uyari turuncu, ihlal
/// kirmizi).
Color _nokta(HareketTip tip) => switch (tip) {
      HareketTip.kargoKayit => HomeTokens.orange,
      HareketTip.kargoTeslim => HomeTokens.green,
      HareketTip.ziyaretci => HomeTokens.purple,
      HareketTip.aidatOdeme => HomeTokens.green,
      HareketTip.alarm => HomeTokens.red,
      HareketTip.uyari => HomeTokens.orange,
      HareketTip.bilgi => HomeTokens.primary,
    };
