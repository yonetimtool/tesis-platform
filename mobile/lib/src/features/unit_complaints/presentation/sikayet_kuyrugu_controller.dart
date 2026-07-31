import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../data/unit_complaint_api.dart';
import '../domain/unit_complaint_models.dart';

/// Sikayet TRIYAJ kuyrugu durumu (P24) — "Yeni / Okunmamis" + "Tumu".
///
/// IKI LISTE AYRI TUTULUR (tek liste + istemci suzgeci DEGIL): "Yeni" sekmesi
/// sunucudan `okunmamis=true` ile gelir, cunku okuma durumu KISI BASINADIR ve
/// sayfalama sunucudadir — istemcide suzmek 200'luk sayfanin disinda kalan
/// okunmamislari GIZLERDI.
class SikayetKuyruguState {
  const SikayetKuyruguState({
    this.loading = false,
    this.errorMessage,
    this.hataKimligi,
    this.yeni = const [],
    this.tumu = const [],
    this.okunmamisSayisi = 0,
  });

  final bool loading;

  /// Hata KANALI ikilidir (README §15): sunucu metni + yerellestirilebilir
  /// kimlik.
  final String? errorMessage;
  final AkisHatasi? hataKimligi;

  /// Okunmamis sikayetler (sunucudan `okunmamis=true`).
  final List<UnitComplaint> yeni;

  /// Tum sikayetler (okuma durumundan bagimsiz) — "Yeni" bir ARSIV degildir,
  /// okunanlar burada kalir.
  final List<UnitComplaint> tumu;

  /// ROZET — sunucunun `meta.total` degeri; sayfa uzunlugu DEGIL.
  final int okunmamisSayisi;

  SikayetKuyruguState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    Object? hataKimligi = _sentinel,
    List<UnitComplaint>? yeni,
    List<UnitComplaint>? tumu,
    int? okunmamisSayisi,
  }) {
    return SikayetKuyruguState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      hataKimligi:
          hataKimligi == _sentinel ? this.hataKimligi : hataKimligi as AkisHatasi?,
      yeni: yeni ?? this.yeni,
      tumu: tumu ?? this.tumu,
      okunmamisSayisi: okunmamisSayisi ?? this.okunmamisSayisi,
    );
  }

  static const Object _sentinel = Object();
}

class SikayetKuyruguController extends Notifier<SikayetKuyruguState> {
  bool _refreshing = false;

  @override
  SikayetKuyruguState build() {
    Future.microtask(refresh);
    return const SikayetKuyruguState(loading: true);
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    state = state.copyWith(loading: true, errorMessage: null, hataKimligi: null);
    try {
      final api = ref.read(unitComplaintApiProvider);
      // Iki cagri PARALEL: sirali olsalardi kuyruk acilisi iki gidis-donuse
      // maloluyordu.
      final sonuc = await Future.wait([
        api.fetchYonetim(okunmamis: true),
        api.fetchYonetim(),
      ]);
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        hataKimligi: null,
        yeni: sonuc[0].items,
        tumu: sonuc[1].items,
        okunmamisSayisi: sonuc[0].toplam,
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: e.message,
        hataKimligi: e.agHatasi,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        hataKimligi: AkisHatasi.beklenmeyen,
      );
    } finally {
      _refreshing = false;
    }
  }

  /// Sikayeti okundu isaretler ve kuyrugu YERINDE gunceller.
  ///
  /// Sunucu yaniti beklenir (iyimser guncelleme YOK): istek duserse rozet
  /// gercekte okunmamis bir kaydi okunmus gostermis olurdu ve triyaj kuyrugu
  /// SESSIZCE eksilirdi. Tam tazeleme de yapilmaz — kullanici listeyi
  /// kaydirmisken liste altindan kaymasin.
  Future<bool> okunduIsaretle(String id) async {
    try {
      await ref.read(unitComplaintApiProvider).markRead(id);
    } on ApiException catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(errorMessage: e.message, hataKimligi: e.agHatasi);
      return false;
    } catch (_) {
      if (!ref.mounted) return false;
      state = state.copyWith(hataKimligi: AkisHatasi.beklenmeyen);
      return false;
    }
    if (!ref.mounted) return true;
    final zatenOkunmus = !state.yeni.any((c) => c.id == id);
    state = state.copyWith(
      yeni: state.yeni.where((c) => c.id != id).toList(),
      tumu: [
        for (final c in state.tumu)
          if (c.id == id) c.okunduKopya() else c,
      ],
      // Idempotent: ayni satir iki kez isaretlenirse rozet EKSIYE dusmemeli.
      okunmamisSayisi: zatenOkunmus
          ? state.okunmamisSayisi
          : (state.okunmamisSayisi - 1).clamp(0, 1 << 31),
    );
    return true;
  }
}

final sikayetKuyruguControllerProvider =
    NotifierProvider<SikayetKuyruguController, SikayetKuyruguState>(
  SikayetKuyruguController.new,
);
