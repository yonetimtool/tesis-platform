import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/call_api.dart';
import '../data/call_launcher.dart';
import '../domain/call_models.dart';

/// Rol-bazli arama butonu (C1a). Verilen [userId] icin /call-target'i cozer:
///   * 200 (aranabilir) → etkin "Ara" butonu; dokununca cihaz ceviricisi (tel:).
///   * 403/404 (yetkisiz/rizasiz/numarasiz) → sessiz "Aranamıyor" durumu.
/// Numara EKRANDA GOSTERILMEZ; yalniz ceviriciye verilir (KVKK — amaç-sınırlı).
///
/// Cozum butonun goruldugu anda (tek hedef, toplu degil) yapilir; numara yalniz
/// yetkili+rizali hedef icin ve yalniz o an cekilir.
class CallButton extends ConsumerStatefulWidget {
  const CallButton({super.key, required this.userId, required this.label});

  final String userId;

  /// Buton etiketi (orn. "Sakini ara", "Güvenliği ara").
  final String label;

  @override
  ConsumerState<CallButton> createState() => _CallButtonState();
}

class _CallButtonState extends ConsumerState<CallButton> {
  bool _loading = true;
  CallTarget? _target; // 200 ise dolu; degilse aranamıyor
  bool _dialing = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final t = await ref.read(callApiProvider).resolve(widget.userId);
      if (!mounted) return;
      setState(() => _target = t);
    } on ApiException {
      // 403 (yetkisiz yon) / 404 (rizasiz/numarasiz) → aranamıyor.
      if (!mounted) return;
      setState(() => _target = null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _target = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dial() async {
    final t = _target;
    if (t == null || _dialing) return;
    setState(() => _dialing = true);
    try {
      final ok = await ref.read(callLauncherProvider).dial(t.telUri);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arama başlatılamadı')),
        );
      }
    } finally {
      if (mounted) setState(() => _dialing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_target == null) {
      // Sessiz "aranamıyor" durumu (numara yok/riza yok/yetki yok).
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.phone_disabled, size: 16, color: Colors.grey),
            SizedBox(width: 6),
            Text('Aranamıyor', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return FilledButton.icon(
      icon: _dialing
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.call),
      label: Text(widget.label),
      onPressed: _dialing ? null : _dial,
    );
  }
}
