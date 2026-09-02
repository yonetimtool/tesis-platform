/// (P203 §4) VARDIYA PLANI — mobil.
///
/// ===========================================================================
/// MOBILDE NEDEN GEREKLI
/// ===========================================================================
/// Saha rolleri (`security`, `tesis_gorevlisi`) WEB'DE HICBIR SAYFA
/// GORMEZ — P129 karari, urunleri mobil uygulamadir. Yani "bu hafta ne
/// zaman calisiyorum" ve "siradaki vardiyada kim var" sorularini
/// yanitlayabilecekleri TEK yer burasi.
///
/// GUNLUK LISTE, HAFTALIK TABLO DEGIL: yedi gun x vardiya izgarasi bir
/// telefon ekranina sigmaz ve yatay kaydirma, en cok ihtiyac duyulan
/// bilgiyi (BUGUN) gorunmez yapardi. Gunler ALT ALTA, bugun en ustte.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../../core/i18n/l10n.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../data/vardiya_plani_api.dart';
import '../domain/vardiya_plani_models.dart';

/// Bu haftanin PAZARTESISI (TR takvimi).
DateTime _haftaBasi(DateTime t) =>
    DateTime(t.year, t.month, t.day).subtract(Duration(days: t.weekday - 1));

final vardiyaHaftaProvider = FutureProvider<VardiyaHafta>((ref) async {
  return ref.read(vardiyaPlaniApiProvider).hafta(_haftaBasi(DateTime.now()));
});

final vardiyaSimdiProvider = FutureProvider<VardiyaSimdi>((ref) async {
  return ref.read(vardiyaPlaniApiProvider).simdi();
});

class VardiyaPlaniScreen extends ConsumerWidget {
  const VardiyaPlaniScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final hafta = ref.watch(vardiyaHaftaProvider);
    final simdi = ref.watch(vardiyaSimdiProvider);
    final rol = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    final yonetici = rol == UserRole.admin || rol == UserRole.yonetici;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vardiyaPlaniBaslik)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(vardiyaHaftaProvider);
          ref.invalidate(vardiyaSimdiProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---------------- 4.2 ANLIK DURUM ----------------
            simdi.when(
              data: (d) => Card(
                key: const Key('vardiya-simdi'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.vardiyaSuAnGorevde,
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        d.gorevdekiVardiya == null
                            ? l10n.vardiyaSuAnKimseYok
                            : '${d.gorevdekiVardiya!.shiftAd} '
                                '${d.gorevdekiVardiya!.saatAraligi}\n'
                                '${d.gorevdekiler.map((k) => k.ad).join(', ')}',
                      ),
                      const SizedBox(height: 12),
                      Text(l10n.vardiyaSiradaki,
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        d.sonrakiVardiya == null
                            ? l10n.vardiyaSiradakiYok
                            : '${d.sonrakiVardiya!.shiftAd} '
                                '${d.sonrakiVardiya!.saatAraligi}\n'
                                '${d.sonrakiler.map((k) => k.ad).join(', ')}',
                      ),
                    ],
                  ),
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              // ANLIK DURUM DUSERSE HAFTA YINE CIZILIR: kart bir
              // KOLAYLIKTIR, ekranin tamamini kirmasi orantisiz olurdu.
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // ---------------- 4.1 HAFTALIK PLAN ----------------
            hafta.when(
              data: (h) => Column(
                children: [
                  for (final g in h.gunler)
                    Card(
                      key: Key('vardiya-gun-${g.tarih}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Text(
                              g.tarih,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          for (final s in g.slotlar)
                            ListTile(
                              key: Key('vardiya-slot-${g.tarih}-${s.shiftId}'),
                              dense: true,
                              // BOS VARDIYA GORSEL OLARAK AYRI: telefonda
                              // liste uzun; "kimse yok" metnini okumak
                              // icin her satiri okumak gerekirdi.
                              leading: Icon(
                                s.bos
                                    ? Icons.error_outline
                                    : Icons.check_circle_outline,
                                color: s.bos
                                    ? Theme.of(context).colorScheme.error
                                    : null,
                              ),
                              title: Text('${s.shiftAd}  ${s.saatAraligi}'),
                              subtitle: Text(
                                s.bos
                                    ? l10n.vardiyaBos
                                    : s.kisiler.map((k) => k.ad).join(', '),
                              ),
                              // BASIT DEGISIKLIK: yalniz YONETICI ve
                              // yalniz CIKARMA. Atama personel listesi +
                              // cakisma geri bildirimi ister; telefonda
                              // yarim bir atama akisi, yoneticiyi
                              // yanlis atama yapip web'de duzeltmeye
                              // zorlardi. Cikarma ise acil durumun ta
                              // kendisi (hastalik/izin) ve sahada
                              // gerekir.
                              trailing: (yonetici && s.kisiler.isNotEmpty)
                                  ? IconButton(
                                      key: Key('vardiya-cikar-${s.shiftId}'),
                                      icon: const Icon(Icons.person_remove_outlined),
                                      tooltip: l10n.vardiyaCikar,
                                      onPressed: () =>
                                          _cikarSor(context, ref, s.kisiler.first),
                                    )
                                  : null,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  e is ApiException ? apiHataMetni(l10n, e) : l10n.ortakBeklenmeyenHata,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cikarSor(
    BuildContext context,
    WidgetRef ref,
    VardiyaKisi kisi,
  ) async {
    final l10n = context.l10n;
    final ctrl = TextEditingController();
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(kisi.ad),
        // SEBEP SORULUR: gun ici degisiklik denetime yaziliyor ve
        // "neden" bos kalirsa kayit sonradan hicbir soruyu
        // yanitlayamaz.
        content: TextField(
          key: const Key('vardiya-cikar-sebep'),
          controller: ctrl,
          decoration: InputDecoration(labelText: l10n.vardiyaCikarSebep),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(l10n.ortakVazgec),
          ),
          FilledButton(
            key: const Key('vardiya-cikar-onayla'),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(l10n.vardiyaCikar),
          ),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await ref
          .read(vardiyaPlaniApiProvider)
          .cikar(kisi.planId, sebep: ctrl.text.trim());
      ref.invalidate(vardiyaHaftaProvider);
      ref.invalidate(vardiyaSimdiProvider);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    }
  }
}
