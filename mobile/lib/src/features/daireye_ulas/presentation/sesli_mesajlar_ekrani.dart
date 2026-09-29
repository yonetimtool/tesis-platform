import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../../core/i18n/l10n.dart';
import '../data/daireye_ulas_api.dart';

/// (P249 §3b) SESLI MESAJLAR — sakin: dairesine gelenler (dinle, sil);
/// guvenlik: gonderdikleri (dinlendi mi).
///
/// OYNATICI `video_player`: yalniz ses dosyasini da oynatir; yeni bir ses
/// bagimliligi eklemek gerekmedi. Adres kisa omurludur ve her dinlemede
/// yeniden alinir (dosya herkese acik degil).
class SesliMesajlarEkrani extends ConsumerWidget {
  const SesliMesajlarEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sesliMesajlarBaslik)),
      body: ref.watch(sesliMesajlarProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (l) => l.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l10n.sesliMesajYok, textAlign: TextAlign.center),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(sesliMesajlarProvider),
                    child: ListView.separated(
                      itemCount: l.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) => _Satir(m: l[i]),
                    ),
                  ),
          ),
    );
  }
}

class _Satir extends ConsumerStatefulWidget {
  const _Satir({required this.m});

  final SesliMesaj m;

  @override
  ConsumerState<_Satir> createState() => _SatirState();
}

class _SatirState extends ConsumerState<_Satir> {
  VideoPlayerController? _oynatici;
  bool _yukleniyor = false;

  @override
  void dispose() {
    _oynatici?.dispose();
    super.dispose();
  }

  Future<void> _dinle() async {
    setState(() => _yukleniyor = true);
    try {
      final url = await ref.read(daireyeUlasApiProvider).dinle(widget.m.id);
      await _oynatici?.dispose();
      final o = VideoPlayerController.networkUrl(Uri.parse(url));
      await o.initialize();
      await o.play();
      if (!mounted) {
        await o.dispose();
        return;
      }
      setState(() => _oynatici = o);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiHataMetni(context.l10n, e))));
      }
    } catch (_) {
      // Oynatilamadi (ag/bicim): sessiz degil — kullanici tekrar dener.
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _sil() async {
    try {
      await _oynatici?.pause();
      await ref.read(daireyeUlasApiProvider).sil(widget.m.id);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiHataMetni(context.l10n, e))));
      }
    }
    ref.invalidate(sesliMesajlarProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final m = widget.m;
    final t = m.createdAt.toLocal();
    String iki(int n) => n.toString().padLeft(2, '0');
    final zaman = '${iki(t.day)}.${iki(t.month)} ${iki(t.hour)}:${iki(t.minute)}';
    return ListTile(
      key: Key('sesli-mesaj-${m.id}'),
      leading: const Icon(Icons.voicemail),
      title: Text([m.daire, if (m.gonderenAd != null) m.gonderenAd!].join(' · ')),
      subtitle: Text([
        zaman,
        l10n.sesliMesajSure((m.sureMs / 1000).ceil()),
        if (m.dinlendiAt != null) l10n.sesliMesajDinlendi,
      ].join(' · ')),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            key: Key('sesli-mesaj-dinle-${m.id}'),
            tooltip: l10n.sesliMesajDinle,
            icon: _yukleniyor
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow),
            onPressed: _yukleniyor ? null : _dinle,
          ),
          IconButton(
            key: Key('sesli-mesaj-sil-${m.id}'),
            tooltip: l10n.sesliMesajSil,
            icon: const Icon(Icons.delete_outline),
            onPressed: _sil,
          ),
        ],
      ),
    );
  }
}
