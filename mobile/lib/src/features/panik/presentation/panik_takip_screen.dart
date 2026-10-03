import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/ui/bos_durum.dart';
import '../../../routing/app_router.dart';
import '../data/panik_api.dart';
import '../domain/panik_models.dart';
import 'panik_sayfasi.dart' show panikTipAdi;

/// (P240 §1) ACIL DURUM CAGRILARI — TAKIP.
///
/// Bu ekran olmadan sistem "bir sey oldu" demekten ibaret kalir:
/// kim bastı, kac kisi gordu, kac saniyede mudahale edildi, kim kapatti.
class PanikTakipScreen extends ConsumerStatefulWidget {
  const PanikTakipScreen({super.key});

  @override
  ConsumerState<PanikTakipScreen> createState() => _PanikTakipState();
}

/// (P251 §1) Bilinmeyen durum ham kodla degil, "Acik" yedegiyle yazilmaz:
/// sunucu yeni bir durum eklerse kod gorunsun ki eksik ceviri fark edilsin.
String panikAlarmDurumAdi(AppLocalizations l10n, String d) => switch (d) {
  'beklemede' => l10n.panikAlarmDurumBeklemede,
  'acik' => l10n.panikAlarmDurumAcik,
  'mudahale' => l10n.panikAlarmDurumMudahale,
  'kapandi' => l10n.panikAlarmDurumKapandi,
  'iptal' => l10n.panikAlarmDurumIptal,
  'yanlis_alarm' => l10n.panikAlarmDurumYanlisAlarm,
  _ => d,
};

class _PanikTakipState extends ConsumerState<PanikTakipScreen> {
  // Varsayilan GERCEK alarmlar (web ile ayni): tatbikatin kendi ekrani var.
  PanikSuzgec _suzgec = (durum: null, tatbikat: false);

  /// Son bilinen durum listesi. Suzgec degisince yeni istek YUKLENIRKEN
  /// liste bosalirsa secili deger acilir listede kalmaz (assert). Ilk
  /// yuklemede de yedek kullanilir (web `PANIK_DURUMLARI_YEDEK` ile ayni).
  List<String> _durumlar = const [
    'beklemede', 'acik', 'mudahale', 'kapandi', 'iptal', 'yanlis_alarm',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final durum = ref.watch(panikTakipProvider(_suzgec));
    final veri = durum.value;
    if (veri != null && veri.durumlar.isNotEmpty) _durumlar = veri.durumlar;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.panikTakipBaslik),
        actions: [
          // (P249 §2) TATBIKATLAR — takip ekraninin rolleri (yonetim +
          // guvenlik) raporu okur; yonetim planlar.
          TextButton.icon(
            key: const Key('panik-takip-tatbikat'),
            icon: const Icon(Icons.campaign_outlined),
            label: Text(l10n.tatbikatBaslik),
            onPressed: () => context.push(AppRoutes.tatbikat),
          ),
        ],
      ),
      body: Column(
        children: [
          // (P251 §1) SERIT — SUNUCUNUN sayilari, suzgecten bagimsiz.
          if (veri != null) _Serit(ozet: veri.ozet),
          _Suzgecler(
            suzgec: _suzgec,
            durumlar: _durumlar,
            onDegis: (s) => setState(() => _suzgec = s),
          ),
          Expanded(child: _liste(context, durum)),
        ],
      ),
    );
  }

  Widget _liste(BuildContext context, AsyncValue<PanikListe> durum) {
    final l10n = context.l10n;
    return durum.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (veri) {
          final liste = veri.items;
          if (liste.isEmpty) {
            return BosDurum(
              ikon: Icons.emergency_outlined,
              baslik: l10n.panikAlarmYok,
              aciklama: l10n.panikAlarmYokAlt,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(panikTakipProvider(_suzgec)),
            child: ListView.separated(
              itemCount: liste.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final a = liste[i];
                final goren = a.alicilar.where((x) => x.goruldu != null).length;
                return ListTile(
                  key: Key('panik-satir-${a.id}'),
                  leading: Icon(
                    Icons.emergency_outlined,
                    color: a.acik ? Theme.of(context).colorScheme.error : null,
                  ),
                  title: Text(panikTipAdi(
                    l10n,
                    PanikTip.values.firstWhere(
                      (t) => t.kimlik == a.tip,
                      orElse: () => PanikTip.guvenlik,
                    ),
                  )),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text([a.olusturanAd ?? '', a.yer]
                          .where((x) => x.isNotEmpty)
                          .join(' · ')),
                      // (P251 §1) DURUM YAZILIR — eskiden yalniz ikon
                      // rengi vardi; "yanlis alarm" ile "kapandi" ayni
                      // gorunuyordu.
                      Wrap(
                        spacing: 6,
                        children: [
                          Text(
                            panikAlarmDurumAdi(l10n, a.durum),
                            key: Key('panik-durum-${a.id}'),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: a.acik
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                            ),
                          ),
                          if (a.tatbikat)
                            Text(
                              '· ${l10n.panikRozetTatbikat}',
                              key: Key('panik-tatbikat-${a.id}'),
                            ),
                        ],
                      ),
                      Text(l10n.panikGorenSayisi(goren, a.alicilar.length)),
                      // SURE YOKSA SATIR HIC CIZILMEZ: "0 sn" yazmak,
                      // mudahale edilmemis bir alarmi aninda mudahale
                      // edilmis gibi gosterirdi.
                      if (a.mudahaleSuresiSn != null)
                        Text(l10n.panikMudahaleSuresi(a.mudahaleSuresiSn!)),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: a.acik
                      ? TextButton(
                          key: Key('panik-kapat-${a.id}'),
                          // (P253 Asama 1) NOTLA KAPAT — web gibi kapanis
                          // notu (opsiyonel): "ne oldu, kim gitti".
                          onPressed: () async {
                            final not = await showDialog<String>(
                              context: context,
                              builder: (_) => const _KapanisNotuDiyalogu(),
                            );
                            if (not == null) return;
                            await ref.read(panikApiProvider).kapat(
                                  a.id,
                                  not: not.isEmpty ? null : not,
                                );
                            ref.invalidate(panikTakipProvider(_suzgec));
                          },
                          child: Text(l10n.panikKapat),
                        )
                      : null,
                );
              },
            ),
          );
        },
      );
  }
}

class _Serit extends StatelessWidget {
  const _Serit({required this.ozet});
  final PanikOzet ozet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tema = Theme.of(context);
    Widget kart(String anahtar, String etiket, int deger, {String? alt, Color? renk}) =>
        Expanded(
          child: Card(
            key: Key(anahtar),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(etiket, style: tema.textTheme.bodySmall),
                  Text('$deger',
                      style: tema.textTheme.titleLarge?.copyWith(color: renk)),
                  if (alt != null)
                    Text(alt,
                        style: tema.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kart('panik-ozet-acik', l10n.panikOzetAcik, ozet.acik,
              renk: ozet.acik > 0 ? tema.colorScheme.error : null),
          kart('panik-ozet-bugun', l10n.panikOzetBugun, ozet.bugun),
          kart('panik-ozet-kapanan', l10n.panikOzetKapanan, ozet.kapanan,
              alt: ozet.yanlisAlarm + ozet.iptal > 0
                  ? l10n.panikOzetKapananAlt(
                      '${ozet.yanlisAlarm}', '${ozet.iptal}')
                  : null),
        ],
      ),
    );
  }
}

class _Suzgecler extends StatelessWidget {
  const _Suzgecler({
    required this.suzgec,
    required this.durumlar,
    required this.onDegis,
  });
  final PanikSuzgec suzgec;
  final List<String> durumlar;
  final ValueChanged<PanikSuzgec> onDegis;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // `tatbikat`: false = gercek, true = tatbikat, null = hepsi.
    const kaynaklar = <bool?>[false, true, null];
    String kaynakAdi(bool? k) => switch (k) {
      false => l10n.panikKaynakGercek,
      true => l10n.panikKaynakTatbikat,
      null => l10n.panikKaynakHepsi,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<bool?>(
              key: const Key('panik-kaynak'),
              initialValue: suzgec.tatbikat,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.panikKaynakSuzgec),
              items: [
                for (final k in kaynaklar)
                  DropdownMenuItem(value: k, child: Text(kaynakAdi(k))),
              ],
              onChanged: (k) => onDegis((durum: suzgec.durum, tatbikat: k)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String?>(
              key: const Key('panik-durum-suzgec'),
              initialValue: suzgec.durum,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.panikDurumSuzgec),
              items: [
                DropdownMenuItem(
                    value: null, child: Text(l10n.panikAlarmDurumHepsi)),
                for (final d in durumlar)
                  DropdownMenuItem(
                    value: d,
                    child: Text(panikAlarmDurumAdi(l10n, d),
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (d) => onDegis((durum: d, tatbikat: suzgec.tatbikat)),
            ),
          ),
        ],
      ),
    );
  }
}


/// (P253 Asama 1) Kapanis notu — opsiyonel; bos birakilip kapatilabilir.
/// Vazgec `null` doner (alarm acik kalir).
class _KapanisNotuDiyalogu extends StatefulWidget {
  const _KapanisNotuDiyalogu();

  @override
  State<_KapanisNotuDiyalogu> createState() => _KapanisNotuDiyaloguState();
}

class _KapanisNotuDiyaloguState extends State<_KapanisNotuDiyalogu> {
  final _not = TextEditingController();

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.panikKapat),
      content: TextField(
        key: const Key('panik-kapanis-notu'),
        controller: _not,
        maxLength: 2000,
        minLines: 2,
        maxLines: 5,
        decoration: InputDecoration(labelText: l10n.kisPanikKapanisNotu),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.ortakVazgec),
        ),
        FilledButton(
          key: const Key('panik-kapat-onay'),
          onPressed: () => Navigator.of(context).pop(_not.text.trim()),
          child: Text(l10n.panikKapat),
        ),
      ],
    );
  }
}
