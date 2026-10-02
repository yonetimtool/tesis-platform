/// (P252 §3) PERSONEL DETAYI — mobil (web `/kisiler/personel` ikizi).
///
/// Calisma bilgileri (maas karti), bu ay vardiya/devriye ozeti, bu yil
/// odenen ve odeme gecmisi (donem, tutar, kasa, maas / fazla mesai,
/// durum). YALNIZ yonetim: Personel listesinde satira dokunma amire
/// baglanmaz, sunucu da 403 doner.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../data/staff_api.dart';
import 'calisma_bilgileri.dart';

final personelDetayProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>(
  (ref, userId) => ref.watch(staffApiProvider).personelDetay(userId),
);

class PersonelDetayScreen extends ConsumerWidget {
  const PersonelDetayScreen({super.key, required this.kisi});

  final StaffMember kisi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final detay = ref.watch(personelDetayProvider(kisi.id));
    return Scaffold(
      appBar: AppBar(title: Text(kisi.ad)),
      body: detay.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(e is ApiException ? apiHataMetni(l10n, e) : l10n.ortakBeklenmeyenHata),
          ),
        ),
        data: (d) {
          final c = d['calisma'] as Map<String, dynamic>?;
          final buAy = (d['bu_ay'] as Map?) ?? const {};
          final odemeler = ((d['odemeler'] as List?) ?? const []).whereType<Map>().toList();
          String tarih(Object? iso) =>
              iso is String ? tarihBicimi(DateTime.parse(iso), dil) : '—';
          Widget satir(String etiket, String deger) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Expanded(child: Text(etiket)),
                  Flexible(
                    child: Text(deger,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ]),
              );
          final baslik = Theme.of(context).textTheme.titleSmall;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(personelDetayProvider(kisi.id)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  key: const Key('pd-calisma'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Expanded(child: Text(l10n.calismaBaslik, style: baslik)),
                          TextButton(
                            key: const Key('pd-duzenle'),
                            onPressed: () async {
                              await merkezSayfaAc<String?>(
                                context,
                                builder: (_) => CalismaSayfasi(kisi: kisi),
                              );
                              ref.invalidate(personelDetayProvider(kisi.id));
                            },
                            child: Text(l10n.calismaDugme),
                          ),
                        ]),
                        if (c == null)
                          Text(l10n.pdKartYok)
                        else ...[
                          satir(l10n.calismaGorev, (c['gorev'] as String?) ?? '—'),
                          satir(l10n.calismaGiris, tarih(c['giris_tarihi'])),
                          if (c['cikis_tarihi'] != null)
                            satir(l10n.pdCikis, tarih(c['cikis_tarihi'])),
                          satir(
                            l10n.calismaUcret,
                            c['maas_kurus'] == null
                                ? '—'
                                : tlIsaretli(c['maas_kurus'] as int, dil),
                          ),
                          satir(
                            l10n.calismaOdemeGunu,
                            c['odeme_gunu'] == null
                                ? '—'
                                : l10n.calismaOdemeGunuDeger(c['odeme_gunu'] as int),
                          ),
                          satir(l10n.calismaKasa,
                              (c['kasa_ad'] as String?) ?? l10n.calismaKasaVarsayilan),
                        ],
                      ],
                    ),
                  ),
                ),
                Card(
                  key: const Key('pd-bu-ay'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l10n.pdBuAy, style: baslik),
                        const SizedBox(height: 4),
                        Text(l10n.pdVardiya(
                            '${buAy['vardiya_sayisi'] ?? 0}', '${buAy['vardiya_saat'] ?? 0}')),
                        Text(l10n.pdDevriye(
                            '${buAy['devriye_tur'] ?? 0}', '${buAy['okutma_sayisi'] ?? 0}')),
                        const Divider(height: 24),
                        satir(l10n.pdYilOdenen,
                            tlIsaretli((d['yil_odenen_kurus'] as int?) ?? 0, dil)),
                      ],
                    ),
                  ),
                ),
                Card(
                  key: const Key('pd-odemeler'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l10n.pdOdemeGecmisi, style: baslik),
                        if (odemeler.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(l10n.calismaOdemeYok),
                          ),
                        for (final o in odemeler)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text([
                              odemeTuruAdi(l10n, o['tur'] as String?),
                              if (o['donem'] != null) o['donem'] as String,
                            ].join(' · ')),
                            subtitle: Text([
                              tarih(o['tarih']),
                              if (o['kasa_ad'] != null) o['kasa_ad'] as String,
                              if (o['durum'] == 'onay_bekliyor') l10n.calismaOnayBekliyor,
                            ].join(' · ')),
                            trailing: Text(tlIsaretli(o['tutar_kurus'] as int, dil)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
