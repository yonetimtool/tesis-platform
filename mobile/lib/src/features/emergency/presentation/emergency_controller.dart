import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/error/api_exception.dart';
import '../data/emergency_api.dart';
import '../domain/emergency_models.dart';

/// Panik akisinin asamasi.
enum EmergencyPhase {
  /// Buton hazir; taslak yok.
  idle,

  /// Butona basildi, onay bekleniyor (Idempotency-Key SABITLENDI).
  armed,

  /// Onaylandi; GPS (best-effort) + POST /emergency suruyor.
  sending,

  /// Alarm backend'e ulasti (201 yeni / 200 zaten kayitli).
  sent,

  /// Gonderim BASARISIZ — kullaniciya durust soylenir (kuyruklama YOK),
  /// ayni taslakla "tekrar dene" sunulur.
  failed,
}

class EmergencyState {
  const EmergencyState({
    this.phase = EmergencyPhase.idle,
    this.draft,
    this.result,
    this.errorMessage,
    this.offline = false,
    this.phone,
  });

  final EmergencyPhase phase;

  /// Basis aninda sabitlenen taslak ([EmergencyDraft.idempotencyKey] dahil).
  final EmergencyDraft? draft;

  final EmergencySubmitResult? result;
  final String? errorMessage;

  /// Hata ag kaynakli mi (baglanti yok) — UI daha net uyari gosterir.
  final bool offline;

  /// Yonetim numarasi (`acil_durum_telefon`) — bir kez cekilip oturum boyunca
  /// onbellekte tutulur; alinamazsa null (arama butonu gizlenir).
  final String? phone;

  EmergencyState copyWith({
    EmergencyPhase? phase,
    Object? draft = _sentinel,
    Object? result = _sentinel,
    Object? errorMessage = _sentinel,
    bool? offline,
    Object? phone = _sentinel,
  }) {
    return EmergencyState(
      phase: phase ?? this.phase,
      draft: draft == _sentinel ? this.draft : draft as EmergencyDraft?,
      result:
          result == _sentinel ? this.result : result as EmergencySubmitResult?,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      offline: offline ?? this.offline,
      phone: phone == _sentinel ? this.phone : phone as String?,
    );
  }

  static const Object _sentinel = Object();
}

/// Panik butonu controller'i.
///
///   * [arm] — butona basis ANINDA taslak olusur, Idempotency-Key sabitlenir
///     (cift dokunus / onay sonrasi tekrar → backend 200 ile ayni alarmi
///     doner, cift kayit yok).
///   * [confirm] — GPS best-effort eklenir (ALINAMAZSA ALARM BEKLETILMEZ,
///     konumsuz gider) ve POST atilir.
///   * OFFLINE KARARI: gonderilemezse sessizce kuyruklamak YANILTICIDIR
///     (kullanici "iletildi" sanir) — acikca "iletilemedi" denir, ayni
///     taslakla [retry] sunulur; yonetim numarasi yine gosterilir (arama
///     sebeke uzerinden calisabilir).
class EmergencyController extends Notifier<EmergencyState> {
  @override
  EmergencyState build() {
    Future.microtask(_loadPhone);
    return const EmergencyState();
  }

  EmergencyApi get _api => ref.read(emergencyApiProvider);

  /// Yonetim numarasini onbellege alir; hata alarmi ETKILEMEZ (buton
  /// gizlenir, alarm akisi calismaya devam eder).
  Future<void> _loadPhone() async {
    try {
      final settings = await _api.fetchSettings();
      if (!ref.mounted) return;
      state = state.copyWith(phone: settings.acilDurumTelefon);
    } on ApiException {
      // Numara sonra tekrar denenir (bir sonraki arm'da).
    }
  }

  /// Panik butonuna basildi → taslagi SABITLE, onay dialoguna gec.
  void arm(String? notlar) {
    if (state.phase == EmergencyPhase.sending) return;
    final trimmed = notlar?.trim();
    state = state.copyWith(
      phase: EmergencyPhase.armed,
      draft: EmergencyDraft(
        basisAni: DateTime.now().toUtc(),
        notlar: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      ),
      result: null,
      errorMessage: null,
      offline: false,
    );
    if (state.phone == null) _loadPhone();
  }

  /// Onay dialogunda vazgecildi.
  void disarm() {
    if (state.phase != EmergencyPhase.armed) return;
    state = state.copyWith(phase: EmergencyPhase.idle, draft: null);
  }

  /// Onaylandi → gonder.
  Future<void> confirm() async {
    final draft = state.draft;
    if (draft == null || state.phase == EmergencyPhase.sending) return;
    state = state.copyWith(phase: EmergencyPhase.sending, errorMessage: null);

    // GPS best-effort: izin/servis/timeout sorunlarinda ALARM BEKLEMEZ.
    final gps = await _tryGetLocation();
    final toSend = gps == null
        ? draft
        : draft.copyWith(gpsLat: gps.$1, gpsLng: gps.$2);
    if (!ref.mounted) return;
    // Konum taslakta kalsin ki "tekrar dene" ayni govdeyi gondersin
    // (ayni Idempotency-Key farkli govde → 409).
    state = state.copyWith(draft: toSend);

    await _submit(toSend);
  }

  /// Basarisiz gonderimi AYNI taslakla tekrarlar (ayni Idempotency-Key —
  /// ilk deneme sunucuya ulasmis olsa bile cift alarm olusmaz).
  Future<void> retry() async {
    final draft = state.draft;
    if (draft == null || state.phase == EmergencyPhase.sending) return;
    state = state.copyWith(phase: EmergencyPhase.sending, errorMessage: null);
    await _submit(draft);
  }

  Future<void> _submit(EmergencyDraft draft) async {
    try {
      final result = await _api.submit(draft);
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: EmergencyPhase.sent,
        result: result,
        errorMessage: null,
        offline: false,
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      final offline = e.kind == ApiErrorKind.network;
      state = state.copyWith(
        phase: EmergencyPhase.failed,
        offline: offline,
        errorMessage: offline
            ? 'ALARM İLETİLEMEDİ — internet bağlantısı yok. Alarm '
                'KUYRUĞA ALINMADI; bağlantı gelince "Tekrar dene"ye basın. '
                'Yönetimi telefonla aramak şebeke üzerinden ÇALIŞABİLİR.'
            : e.message,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: EmergencyPhase.failed,
        errorMessage:
            'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.',
      );
    }
  }

  /// Sonuc ekranindan cikis — yeni bir panik icin sifirlar.
  void reset() {
    state = EmergencyState(phone: state.phone);
  }

  /// Cihaz konumunu KISA sure icinde almayi dener; her turlu hata/ret/
  /// zaman asiminda null doner (alarm konumsuz gider, GECIKMEZ).
  Future<(double, double)?> _tryGetLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return (pos.latitude, pos.longitude);
    } catch (_) {
      // Zaman asimi vb. → son bilinen konum varsa o da olur.
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return (last.latitude, last.longitude);
      } catch (_) {
        // Konumsuz devam.
      }
      return null;
    }
  }
}

final emergencyControllerProvider =
    NotifierProvider<EmergencyController, EmergencyState>(
  EmergencyController.new,
);
